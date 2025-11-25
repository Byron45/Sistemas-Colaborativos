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
	
	// Declaramos el grafo
	graph road_network;

	// --- 3. PARÁMETROS ---
	int num_vehiculos_iniciales <- 200; // Subimos un poco la cantidad
	bool lluvia_activa <- false;

	// --- 4. INICIO (INIT) ---
	init {
		create barrio from: barrios_shapefile with: [nombre::string(read("NOMBRE"))];
		create via from: red_vial_shapefile;

		// Creamos el grafo de navegación
		road_network <- as_edge_graph(via);

		create Controlador_de_trafico number: 1;

		ask first(Controlador_de_trafico) {
			loop i from: 1 to: num_vehiculos_iniciales {
				do crear_un_vehiculo;
			}
		}
	}
}

// --- ESPECIES DEL ENTORNO ---

species via {
	bool es_principal <- name = "Avenida Simón Bolívar";
	aspect default {
		if es_principal {
			draw shape color: #springgreen width: 4.0; 
		} else {
			draw shape color: #white width: 1.5; 
		}
	}
}

species barrio {
	string nombre;
	aspect default {
		draw shape border: #dimgray color: #black; 
	}
}

// --- ESPECIES DE TRÁFICO ---

species Vehiculo skills: [moving] { 
	float velocidad_base;   
	rgb color_vehiculo;
	float tamano;

	reflex moverse {
		float velocidad_actual <- velocidad_base;
		
		// Si llueve, frenamos
		if (lluvia_activa) { velocidad_actual <- velocidad_base * 0.5; }

		// --- SOLUCIÓN AL MOVIMIENTO ---
		// 'wander': Muévete aleatoriamente por las calles conectadas
		// 'amplitude': Qué tanto giran en las curvas (0 a 360)
		do wander on: road_network speed: velocidad_actual amplitude: 90.0;
	}
}

// --- SUBESPECIES (TAMAÑOS AJUSTADOS) ---

species Auto parent: Vehiculo {
	init {
		velocidad_base <- rnd(60.0, 100.0) #km/#h;
		color_vehiculo <- #cyan; 
		tamano <- 60.0; // Tamaño visible pero no gigante
	}
	aspect default {
		draw circle(tamano) color: color_vehiculo border: #white;
	}
}

species Moto parent: Vehiculo {
	init {
		velocidad_base <- rnd(80.0, 120.0) #km/#h; 
		color_vehiculo <- #orange; 
		tamano <- 40.0; 
	}
	aspect default {
		draw circle(tamano) color: color_vehiculo border: #white;
	}
}

species Camion parent: Vehiculo {
	init {
		velocidad_base <- rnd(40.0, 70.0) #km/#h; 
		color_vehiculo <- #magenta; 
		tamano <- 90.0; 
	}
	aspect default {
		draw circle(tamano) color: color_vehiculo border: #white;
	}
}

// --- CONTROLADOR ---

species Controlador_de_trafico {
	action crear_un_vehiculo {
		float dado <- rnd(1.0);
		// Nota: Quitamos la asignación de 'destino' porque 'wander' no lo necesita
		if (dado < 0.2) { 
			create Moto number: 1 { location <- one_of(via).location; }
		} else if (dado < 0.4) { 
			create Camion number: 1 { location <- one_of(via).location; }
		} else { 
			create Auto number: 1 { location <- one_of(via).location; }
		}
	}
}

// --- EXPERIMENTO ---

experiment simulacion_completa type: gui {
	parameter "Activar Lluvia" var: lluvia_activa category: "Clima";

	output {
		// 'type: opengl' hace que la simulación vaya más fluida y se vea mejor
		display mapa background: #black type: opengl {
			species barrio;   
			species via;      
			species Auto;
			species Moto;
			species Camion;
		}
	}
}