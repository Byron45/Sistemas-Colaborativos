/**
* Name: Simulacion Av Simon Bolivar - FINAL VISUAL HD
* Author: Jordi, Byron
* Description: Lógica exacta anterior + Mejora gráfica sustancial de la carretera.
*/

model simulacion_realista

global {
	// --- 1. ARCHIVOS (IGUAL) ---
	file archivo_toda_la_red <- file("../includes/red_vial_unificada.shp");
	file archivo_simon_bolivar <- file("../includes/eje_simon_bolivar.shp"); 
	file barrios_shapefile <- file("../includes/Barrios_Final.shp");

	// --- 2. MUNDO (IGUAL) ---
	geometry shape <- envelope(archivo_toda_la_red);
	graph road_network;

	// --- 3. DATOS DE RIESGO (IGUAL) ---
	list<list<float>> matriz_riesgo_semanal <- [
		[1.0, 0.5, 0.5, 0.5, 0.5, 1.5, 2.0, 2.0, 2.0, 1.0, 1.5, 1.5, 1.0, 2.0, 1.0, 1.0, 2.0, 2.5, 2.0, 1.0, 1.0, 1.0, 0.5, 1.0],
		[0.5, 0.5, 0.5, 0.5, 0.5, 1.0, 2.5, 2.5, 3.0, 2.0, 1.0, 1.0, 1.0, 1.0, 2.0, 2.5, 2.0, 1.5, 2.5, 1.0, 0.5, 0.5, 0.5, 1.5],
		[1.0, 1.0, 0.5, 0.5, 0.5, 1.5, 2.0, 1.0, 2.5, 1.0, 1.0, 1.0, 1.0, 2.0, 2.5, 1.0, 1.0, 2.0, 1.5, 2.0, 1.0, 0.5, 0.5, 1.0],
		[1.0, 1.0, 1.5, 0.5, 0.5, 2.5, 2.0, 2.5, 2.0, 1.0, 0.5, 1.5, 1.0, 0.5, 1.0, 1.0, 2.0, 2.5, 2.0, 1.5, 0.5, 0.5, 0.5, 2.0],
		[2.0, 1.5, 1.5, 1.0, 0.5, 1.5, 1.0, 2.5, 1.5, 1.0, 1.0, 1.0, 3.0, 1.0, 0.5, 2.0, 2.5, 3.0, 1.0, 1.5, 2.5, 2.0, 3.0, 2.5],
		[2.0, 2.0, 2.0, 1.0, 3.0, 3.0, 2.5, 1.5, 3.0, 1.5, 1.5, 2.5, 3.0, 1.0, 0.5, 2.5, 1.0, 0.5, 1.0, 2.0, 1.5, 2.0, 0.5, 1.0],
		[2.0, 1.5, 5.0, 1.0, 1.5, 2.5, 4.0, 2.5, 1.5, 1.5, 1.0, 1.5, 2.0, 2.0, 2.5, 2.5, 1.0, 2.5, 1.5, 1.5, 4.0, 1.0, 2.0, 0.5]
	];
	list<string> nombres_dias <- ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"];
	list<float> riesgo_mensual <- [4.96, 7.52, 11.04, 7.84, 9.76, 8.48, 10.40, 12.16, 9.44, 10.24, 8.16, 9.18];
	list<float> prob_lluvia_mes <- [0.6, 0.7, 0.8, 0.8, 0.5, 0.2, 0.1, 0.1, 0.4, 0.6, 0.7, 0.7];

	// --- 4. CONFIGURACIÓN (IGUAL) ---
	int mes_simulacion <- 3 min: 1 max: 12; 
	int num_vehiculos <- 1500; 
	bool lluvia_activa <- false;
	
	// TIEMPO
	int hora_actual <- 6; 
	int minuto_actual <- 0;
	int dias_simulados <- 0; 
	int dia_semana <- 0;
	rgb color_fondo <- rgb(60,60,60); // Fondo un poco más oscuro para contraste
	bool es_noche <- false;

	// ESTADÍSTICAS
	int total_accidentes <- 0;
	int acc_velocidad <- 0; int acc_distancia <- 0; int acc_alcohol <- 0; int acc_clima <- 0; int acc_normal <- 0;    

	// PROYECCIÓN 
	float promedio_diario <- 0.0;
	float proyeccion_8_meses <- 0.0;

	// PUNTOS CRÍTICOS Y EXTREMOS
	point punto_ruminahui <- {6391.94, 24177.32};
	point punto_bautista <- {4820.37, 24729.05};
	point punto_interoceanica <- {9644.12, 18905.70};
	point extremo_norte <- {11457.18, 501.91}; 
	point extremo_sur <- {704.03, 37538.77};

	init {
		create barrio from: barrios_shapefile with: [nombre::string(read("NOMBRE"))];
		create via_decorativa from: archivo_toda_la_red;
		create via_principal from: archivo_simon_bolivar;
		road_network <- as_edge_graph(via_principal); 
		do crear_trafico_inicial;
	}

	action crear_trafico_inicial {
		create Moto number: num_vehiculos * 0.12;        
		create Auto number: num_vehiculos * 0.60;        
		create Camioneta number: num_vehiculos * 0.20;   
		create Transporte_Pesado number: num_vehiculos * 0.04; 
		create Bus number: num_vehiculos * 0.035;        
		create Bicicleta number: num_vehiculos * 0.005;  
	}

	reflex control_tiempo_y_clima {
		minuto_actual <- minuto_actual + 5;
		
		if (minuto_actual >= 60) {
			minuto_actual <- 0;
			hora_actual <- hora_actual + 1;
			
			if (hora_actual >= 24) { 
				hora_actual <- 0; 
				dias_simulados <- dias_simulados + 1; 
				dia_semana <- dia_semana + 1;
				if (dia_semana > 6) { dia_semana <- 0; }

				if (dias_simulados = 243) {
					write "---------------------------------------------------";
					write "FIN DEL PERIODO DE ESTUDIO (Enero - Agosto)";
					write "Total Accidentes Simulados: " + total_accidentes;
					write "Total Real Esperado: 268";
					write "Precisión del Modelo: " + (total_accidentes / 268.0) * 100 + "%";
					write "---------------------------------------------------";
					do pause; 
				}

				if (dias_simulados > 0) {
					promedio_diario <- total_accidentes / dias_simulados;
					proyeccion_8_meses <- promedio_diario * 243;
				}
			}
			if (flip(prob_lluvia_mes at (mes_simulacion - 1))) { lluvia_activa <- true; } else { lluvia_activa <- false; }
		}
		if (hora_actual >= 19 or hora_actual <= 5) { es_noche <- true; color_fondo <- #black; } 
		else { es_noche <- false; color_fondo <- lluvia_activa ? #dimgray : rgb(60,60,60); }
	}
}

// --- MEJORA VISUAL DEL ENTORNO ---

species via_decorativa { 
	aspect default { 
		// Vías secundarias más sutiles (gris oscuro)
		draw shape color: rgb(30,30,30) width: 0.5; 
	} 
}

// --- ¡AQUÍ ESTÁ LA MAGIA VISUAL! ---
species via_principal { 
	aspect default { 
		// 1. Capa Base (Asfalto oscuro ancho)
		draw shape color: rgb(40,40,40) width: 30.0; 
		
		// 2. Capa Superior (Un gris un poco más claro para textura)
		draw shape color: rgb(70,70,70) width: 22.0;
		
		// 3. Línea Divisoria Central (Blanca y delgada)
		draw shape color: #white width: 0.8;
	} 
}

species barrio { 
	string nombre;
	aspect default { 
		// Barrios más oscuros para que resalte la vía
		draw shape color: rgb(15,15,15) border: rgb(40,40,40); 
	} 
}

// --- AGENTES DE TRÁFICO (Lógica Idéntica) ---
species Vehiculo skills: [moving] {
	float velocidad_base; float velocidad_real; rgb color_base; point objetivo; float tamano_dibujo; 
	bool es_imprudente <- flip(0.40); bool no_respeta_distancia <- flip(0.20); bool es_ebrio <- false; bool chocado <- false;
	point last_location; int cont_atascado <- 0;

	init {
		location <- one_of(via_principal).location;
		last_location <- location;
		if (location distance_to extremo_norte < location distance_to extremo_sur) { objetivo <- extremo_sur; } 
		else { objetivo <- extremo_norte; }
		heading <- (location towards objetivo);
		if (dia_semana >= 4) { if (flip(0.05)) { es_ebrio <- true; } } else { if (flip(0.01)) { es_ebrio <- true; } }
	}

	reflex moverse {
		if (chocado) { velocidad_real <- 0.0; return; }
		velocidad_real <- velocidad_base;
		if (es_imprudente) { velocidad_real <- velocidad_real * 1.3; } 
		if (es_ebrio) { velocidad_real <- velocidad_real * 1.5; } 
		if (lluvia_activa) { velocidad_real <- velocidad_real * 0.7; } 
		do goto target: objetivo on: road_network speed: velocidad_real;

		if (last_location != nil) {
			if (location distance_to last_location < 1.0) { cont_atascado <- cont_atascado + 1; } 
			else { cont_atascado <- 0; }
		}
		last_location <- location;
		if (cont_atascado > 10) { do respawn; }
		if (location distance_to objetivo < 500.0) { do respawn; }
	}
	
	action respawn {
		cont_atascado <- 0;
		location <- one_of(via_principal).location;
		last_location <- location;
		if (location distance_to extremo_norte < location distance_to extremo_sur) { objetivo <- extremo_sur; } 
		else { objetivo <- extremo_norte; }
	}

	reflex calcular_accidente {
		if (chocado) { return; }
		
		via_principal via_cercana <- via_principal closest_to location;
		if (via_cercana = nil) { return; }
		if (location distance_to via_cercana > 50.0) { return; }

		float probabilidad_base <- 0.0000005; 

		float factor_mes <- (riesgo_mensual at (mes_simulacion - 1)) / 8.0; 
		float factor_hora_dia <- (matriz_riesgo_semanal at dia_semana) at hora_actual;
		float probabilidad <- probabilidad_base * factor_mes * factor_hora_dia;

		if (lluvia_activa) {
			probabilidad <- probabilidad * 1.20; 
			if (es_imprudente) { probabilidad <- probabilidad * 2.0; } 
		}

		if (location distance_to punto_ruminahui < 300.0 or location distance_to punto_bautista < 300.0 or location distance_to punto_interoceanica < 300.0) {
			probabilidad <- probabilidad * 3.5; 
		}

		if (es_imprudente) { probabilidad <- probabilidad * 1.5; }
		if (no_respeta_distancia and !empty(Vehiculo at_distance 50.0)) { probabilidad <- probabilidad * 2.0; } 
		if (es_ebrio) { probabilidad <- probabilidad * 4.0; }

		if (flip(probabilidad)) { do registrar_choque; }
	}

	action registrar_choque {
		chocado <- true; total_accidentes <- total_accidentes + 1;
		if (lluvia_activa and !es_ebrio) { acc_clima <- acc_clima + 1; }
		else if (es_ebrio) { acc_alcohol <- acc_alcohol + 1; }
		else if (es_imprudente) { acc_velocidad <- acc_velocidad + 1; }
		else if (no_respeta_distancia) { acc_distancia <- acc_distancia + 1; }
		else { acc_normal <- acc_normal + 1; }
		write "ACCIDENTE #" + total_accidentes + " (" + species(self) + ") - " + (nombres_dias at dia_semana) + " " + hora_actual + ":00";
	}
	
	// --- DIBUJO DEL VEHÍCULO CON DESPLAZAMIENTO (IGUAL) ---
	aspect default {
		// Calculamos el punto a la derecha
		point pos_visual <- location + {cos(heading + 90) * 8.0, sin(heading + 90) * 8.0};

		if (chocado) { 
			draw circle(120) color: #red border: #white at: pos_visual; 
		} else { 
			// Dibujamos el vehículo en la posición desplazada
			draw circle(tamano_dibujo) color: color_base at: pos_visual; 
			draw triangle(tamano_dibujo * 0.8) color: #white rotate: heading + 90 border: #black at: pos_visual;
		}
	}
}

// --- TIPOS DE VEHÍCULOS (IGUAL) ---

species Auto parent: Vehiculo { 
	init { velocidad_base <- 90.0 #km/#h; color_base <- #cyan; tamano_dibujo <- 80.0; } 
}
species Moto parent: Vehiculo { 
	init { velocidad_base <- 90.0 #km/#h; color_base <- #orange; tamano_dibujo <- 50.0; } 
}
species Camioneta parent: Vehiculo { 
	init { velocidad_base <- 90.0 #km/#h; color_base <- #blue; tamano_dibujo <- 100.0; } 
}
species Bus parent: Vehiculo { 
	init { velocidad_base <- 70.0 #km/#h; color_base <- #yellow; tamano_dibujo <- 150.0; } 
}
species Transporte_Pesado parent: Vehiculo { 
	init { velocidad_base <- 70.0 #km/#h; color_base <- #purple; tamano_dibujo <- 160.0; } 
}
species Bicicleta parent: Vehiculo { 
	init { velocidad_base <- 30.0 #km/#h; color_base <- #white; tamano_dibujo <- 30.0; } 
}

// --- EXPERIMENTO ---
experiment Simulacion_Calibrada type: gui {
	parameter "Mes del Año" var: mes_simulacion category: "Escenario";
	parameter "Densidad Tráfico" var: num_vehiculos category: "Tráfico";

	output {
		monitor "Día Semana" value: nombres_dias at dia_semana;
		monitor "Hora" value: hora_actual;
		monitor "Total Accidentes" value: total_accidentes;
		monitor "Proyección 8 meses" value: int(proyeccion_8_meses);

		layout #split;

		display mapa type: opengl background: color_fondo {
			species barrio; species via_decorativa; species via_principal;
			species Auto; species Moto; species Camioneta; species Bus; species Bicicleta; species Transporte_Pesado;
			
			graphics "Puntos Negros" {
				draw circle(300) color: rgb(0,0,0,0) border: #red at: punto_ruminahui;
				draw circle(300) color: rgb(0,0,0,0) border: #red at: punto_bautista;
				draw circle(300) color: rgb(0,0,0,0) border: #red at: punto_interoceanica;
				draw "Int. Rumiñahui" at: punto_ruminahui color: #red font: font("Arial", 6, #bold);
				draw "J.B. Aguirre" at: punto_bautista color: #red font: font("Arial", 6, #bold);
				draw "Interoceánica" at: punto_interoceanica color: #red font: font("Arial", 6, #bold);
			}
		}

		display Datos_Analiticos background: #white {
			chart "Causas del Siniestro" type: pie size: {1.0, 0.5} position: {0, 0} {
				data "Velocidad" value: acc_velocidad color: #blue;
				data "Distancia" value: acc_distancia color: #skyblue;
				data "Alcohol" value: acc_alcohol color: #orange;
				data "Clima" value: acc_clima color: #gray;
				data "Azar" value: acc_normal color: #green;
			}
			
			chart "Acumulado vs Meta (268)" type: series size: {1.0, 0.5} position: {0, 0.5} y_range: {0, 300} {
				data "Simulación" value: total_accidentes color: #red style: line thickness: 2.0;
				data "Meta Real" value: 268 color: #green style: line;
			}
		}
	}
}