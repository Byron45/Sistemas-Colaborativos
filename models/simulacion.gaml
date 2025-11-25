/**
* Name: simulacion
* Based on the internal empty template. 
* Author: Jordi, Byron
* Tags: Sistemas Colaborativos, Trafico Quito
*/

model simulacion

global {
	// --- 1. ARCHIVOS ---
	file red_vial_shapefile <- file("../includes/red_vial_unificada.shp");
	file barrios_shapefile <- file("../includes/Barrios_Final.shp");

	// --- 2. DEFINICIÓN DEL MUNDO ---
	geometry shape <- envelope(red_vial_shapefile);
	graph road_network;

	// --- 3. PARÁMETROS ---
	// Mantenemos 1000 para que se vea lleno, pero son más "prudentes" ahora
	int num_vehiculos_iniciales <- 1000; 
	bool lluvia_activa <- false;
	
	// Variables Estadísticas
	int total_accidentes <- 0; 
	int acc_alcohol <- 0;
	int acc_clima <- 0;
	int acc_normal <- 0;

	// --- 4. TIEMPO Y ENTORNO ---
	int hora_actual <- 12; 
	int minuto_actual <- 0;
	rgb color_fondo <- #gray; 
	
	// Datos Sociales
	float porcentaje_ebrios <- 0.10; 
	bool es_noche <- false;

	init {
		create barrio from: barrios_shapefile with: [nombre::string(read("NOMBRE"))];
		create via from: red_vial_shapefile;
		road_network <- as_edge_graph(via);
		create Controlador_de_trafico number: 1;

		ask first(Controlador_de_trafico) {
			loop i from: 1 to: num_vehiculos_iniciales {
				do crear_un_vehiculo;
			}
		}
	}

	reflex paso_del_tiempo {
		minuto_actual <- minuto_actual + 5; 
		if (minuto_actual >= 60) {
			minuto_actual <- 0;
			hora_actual <- hora_actual + 1;
			if (hora_actual >= 24) { hora_actual <- 0; }
		}

		if (hora_actual >= 19 or hora_actual <= 5) {
			es_noche <- true;
			color_fondo <- #black; 
		} else {
			es_noche <- false;
			color_fondo <- rgb(80,80,80); 
		}
	}
}

// --- VISUALIZACIÓN ---

species via {
	bool es_principal <- name = "Avenida Simón Bolívar";
	aspect default {
		if es_principal {
			draw shape color: es_noche ? #springgreen : #green width: es_noche ? 4.0 : 3.0; 
		} else {
			draw shape color: #white width: 1.5; 
		}
	}
}

species barrio {
	string nombre;
	aspect default {
		draw shape color: rgb(40,40,40) border: #gray; 
	}
}

// --- LÓGICA DE TRÁFICO (CALIBRADA) ---

species Vehiculo skills: [moving] { 
	float velocidad_base;   
	rgb color_vehiculo;
	float tamano;
	bool es_ebrio <- false; 
	float prob_choque_base;    
	bool chocado <- false; 

	reflex moverse {
		if (chocado) { velocidad_base <- 0.0; return; }

		float velocidad_actual <- velocidad_base;
		
		if (lluvia_activa) { velocidad_actual <- velocidad_base * 0.6; }
		if (es_ebrio) { velocidad_actual <- velocidad_base * 1.5; }

		do wander on: road_network speed: velocidad_actual amplitude: es_ebrio ? 120.0 : 45.0;
	}

	reflex verificar_riesgo {
		if (chocado) { return; } 

		bool va_a_chocar <- false;
		string tipo_accidente <- "";

		// 1. RIESGO EN SOLITARIO (CALIBRADO)
		// Antes era 0.005 (0.5%). Ahora es 0.0001 (0.01%).
		// Esto significa que chocar solo es MUY raro, a menos que pasen muchas horas.
		if (es_ebrio) {
			if (flip(0.0001)) { 
				va_a_chocar <- true;
				tipo_accidente <- "alcohol";
			}
		}

		// 2. RIESGO POR COLISIÓN (CALIBRADO)
		if (!va_a_chocar) {
			// Radio bajado a 200m (Antes 1000m)
			// Solo interactúan si están relativamente cerca
			list<Vehiculo> cercanos <- Vehiculo at_distance 200.0;
			
			if (!empty(cercanos)) {
				float probabilidad_final <- prob_choque_base;

				// Multiplicadores más suaves
				if (lluvia_activa) { probabilidad_final <- probabilidad_final * 2.5; } // Antes x5
				if (es_noche) { probabilidad_final <- probabilidad_final * 1.5; }      // Antes x2
				if (es_ebrio) { probabilidad_final <- probabilidad_final * 8.0; }      // Antes x20

				if (flip(probabilidad_final)) {
					va_a_chocar <- true;
					if (es_ebrio) { tipo_accidente <- "alcohol"; }
					else if (lluvia_activa) { tipo_accidente <- "clima"; }
					else { tipo_accidente <- "normal"; }
				}
			}
		}

		if (va_a_chocar) {
			chocado <- true;
			total_accidentes <- total_accidentes + 1;
			color_vehiculo <- #red; 
			
			if (tipo_accidente = "alcohol") { acc_alcohol <- acc_alcohol + 1; }
			else if (tipo_accidente = "clima") { acc_clima <- acc_clima + 1; }
			else { acc_normal <- acc_normal + 1; }
			
			write "Accidente (" + tipo_accidente + ") a las " + hora_actual + ":" + minuto_actual;
		}
	}
}

// --- SUBESPECIES (Probabilidades base muy bajas) ---

species Auto parent: Vehiculo {
	init {
		velocidad_base <- rnd(60.0, 90.0) #km/#h;
		color_vehiculo <- #cyan; 
		tamano <- 60.0;
		// Probabilidad base minúscula (0.05% por ciclo)
		prob_choque_base <- 0.0005; 
	}
	aspect default {
		rgb color_final <- es_ebrio ? #yellow : color_vehiculo;
		if (chocado) { color_final <- #red; }
		draw circle(tamano) color: color_final border: #white;
	}
}

species Moto parent: Vehiculo {
	init {
		velocidad_base <- rnd(80.0, 110.0) #km/#h; 
		color_vehiculo <- #orange; 
		tamano <- 40.0; 
		// Las motos tienen el doble de riesgo que los autos, pero sigue siendo bajo
		prob_choque_base <- 0.001; 
	}
	aspect default {
		rgb color_final <- es_ebrio ? #yellow : color_vehiculo;
		if (chocado) { color_final <- #red; }
		draw circle(tamano) color: color_final border: #white;
	}
}

species Camion parent: Vehiculo {
	init {
		velocidad_base <- rnd(40.0, 70.0) #km/#h; 
		color_vehiculo <- #magenta; 
		tamano <- 90.0; 
		prob_choque_base <- 0.0008; 
	}
	aspect default {
		rgb color_final <- es_ebrio ? #yellow : color_vehiculo;
		if (chocado) { color_final <- #red; }
		draw circle(tamano) color: color_final border: #white;
	}
}

// --- CONTROLADOR ---

species Controlador_de_trafico {
	action crear_un_vehiculo {
		float dado_tipo <- rnd(1.0);
		Vehiculo nuevo_vehiculo <- nil;

		if (dado_tipo < 0.2) { 
			create Moto number: 1 returns: creados { location <- one_of(via).location; }
			nuevo_vehiculo <- creados at 0;
		} else if (dado_tipo < 0.4) { 
			create Camion number: 1 returns: creados { location <- one_of(via).location; }
			nuevo_vehiculo <- creados at 0;
		} else { 
			create Auto number: 1 returns: creados { location <- one_of(via).location; }
			nuevo_vehiculo <- creados at 0;
		}

		if (flip(porcentaje_ebrios)) {
			ask nuevo_vehiculo { es_ebrio <- true; }
		}
	}
}

// --- EXPERIMENTO ---

experiment simulacion_completa type: gui {
	parameter "Activar Lluvia" var: lluvia_activa category: "Clima";
	parameter "% Conductores Ebrios" var: porcentaje_ebrios min: 0.0 max: 1.0 category: "Social";

	output {
		monitor "Hora del Día" value: string(hora_actual) + ":" + (minuto_actual < 10 ? "0" + string(minuto_actual) : string(minuto_actual));
		monitor "Total Choques" value: total_accidentes;

		layout #split; 

		display mapa background: color_fondo type: opengl {     
			species barrio;   
			species via;      
			species Auto;
			species Moto;
			species Camion;
		}

		display estadisticas background: #white {
			chart "Evolución de Accidentes" type: series size: {1, 0.5} position: {0, 0} {
				data "Acumulado" value: total_accidentes color: #red marker: false style: line;
			}
			
			chart "Causas de Accidentes" type: pie size: {1, 0.5} position: {0, 0.5} {
				data "Alcohol" value: acc_alcohol color: #yellow;
				data "Clima (Lluvia)" value: acc_clima color: #blue;
				data "Normal/Azar" value: acc_normal color: #green;
			}
		}
	}
}