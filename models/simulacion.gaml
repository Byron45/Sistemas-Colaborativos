/**
* Name: simulacion
* Based on the internal empty template. 
* Author: Jordi
* Tags: 
*/


model simulacion

global {
	// La ruta "../includes/" significa "sube un nivel desde la carpeta 'models' y entra en 'includes'".
	file red_vial_shapefile <- file("../includes/red_vial_unificada.shp");
	file barrios_shapefile <- file("../includes/Barrios_Final.shp");

	// --- 2. DEFINICIÓN DEL MUNDO ---
	// Creamos la "caja" de nuestra simulación, cuyo tamaño se ajusta al de nuestro mapa de calles.
	geometry shape <- envelope(red_vial_shapefile);
	
	// Creamos un "GPS" vacío. Más tarde lo llenaremos con nuestras calles.
	graph road_network;

	// --- 3. PARÁMETROS DE LA SIMULACIÓN ---
	// Una variable para controlar fácilmente cuántos autos queremos al inicio.
	int num_vehiculos_iniciales <- 150;

	// --- 4. ACCIÓN DE INICIO (init) ---
	init {
		// Creamos los agentes 'barrio' a partir del shapefile.
		// Con 'with', le decimos que lea la columna "NOMBRE" del archivo y la guarde en el atributo 'nombre' de cada agente.
		create barrio from: barrios_shapefile with: [nombre::string(read("NOMBRE"))];

		// Creamos los agentes 'via' a partir del shapefile de la red vial.
		create via from: red_vial_shapefile;

		// Ahora llenamos el "GPS": convertimos todos los agentes 'via' en una red navegable.
		road_network <- as_edge_graph(via);

		// Creamos 1 agente 'Controlador_de_trafico', que será nuestro "director de orquesta".
		create Controlador_de_trafico number: 1;

		// Le pedimos a nuestro controlador que cree la población inicial de vehículos.
		ask first(Controlador_de_trafico) {
			loop i from: 1 to: num_vehiculos_iniciales {
				do crear_un_vehiculo;
			}
		}
	}
}

// --- ESPECIES DEL ENTORNO (AGENTES ESTÁTICOS) ---

species via {
	// GAMA lee automáticamente los atributos del shapefile, como 'name'.
	// Creamos una variable 'es_principal' que es verdadera solo si el nombre es "Avenida Simón Bolívar".
	bool es_principal <- name = "Avenida Simón Bolívar";

	// El 'aspect' define cómo se ve el agente.
	aspect default {
		// Usamos la variable 'es_principal' para dibujar la avenida de forma diferente.
		if es_principal {
			draw shape color: #white width: 3; // Más gruesa y blanca
		} else {
			draw shape color: #gray; // Las demás, grises
		}
	}
}

species barrio {
	// Declaramos el atributo 'nombre' que llenamos en el 'init'.
	string nombre;

	aspect default {
		draw shape color: #yellow; // Dibuja el polígono

		// --- ESTA ES LA CORRECCIÓN ---
		// Solo intenta dibujar el texto si la variable 'nombre' NO es nula Y NO está vacía.
		if (nombre != nil and nombre != "") {
			draw nombre at: location color: #white font: font("Arial", 10);
		}
	}
}


// --- ESPECIES DE TRÁFICO (AGENTES ACTIVOS) ---

species Vehiculo skills: [moving] { // 'skills: [moving]' le da la habilidad de usar el "GPS" (road_network).
	// Atributos del vehículo
	point destino;
	float speed <- rnd(40, 70) #km / #h; // Velocidad aleatoria en km/h

	// Un 'reflex' es un comportamiento que el agente intenta ejecutar en cada paso de la simulación.
	reflex moverse {
		// Si está a menos de 50 metros de su destino...
		if (location distance_to destino < 50 #m) {
			// ...se autodestruye para no saturar la simulación...
			do die;
			// ...y le pedimos al controlador que cree uno nuevo para mantener el flujo constante.
			ask first(Controlador_de_trafico) {
				do crear_un_vehiculo;
			}
		} else {
			// Si no ha llegado, simplemente sigue su camino.
			do goto target: destino on: road_network;
		}
	}

	aspect default {
		draw circle(8) color: #cyan border: #black; // Se verá como un círculo cian con borde negro.
	}
}

species Controlador_de_trafico {
	// Una 'action' es una habilidad que debe ser llamada por otro agente. No se ejecuta sola.
	action crear_un_vehiculo {
		create Vehiculo number: 1 {
			// Nace en un punto aleatorio de CUALQUIER vía.
			location <- one_of(via).location;
			// Se le asigna un destino aleatorio en CUALQUIER otra vía.
			destino <- one_of(via).location;
		}
	}
}

experiment simulacion_completa type: gui {
	// 'output' define lo que se muestra en la pantalla.
	output {
		// Creamos una ventana de visualización llamada 'mapa'.
		display mapa background: #black {
			// El orden importa: lo que se dibuja primero queda al fondo.
			species barrio;   // 1. Dibuja los barrios
			species via;      // 2. Dibuja las calles encima de los barrios
			species Vehiculo; // 3. Dibuja los vehículos encima de todo
		}
	}
}


