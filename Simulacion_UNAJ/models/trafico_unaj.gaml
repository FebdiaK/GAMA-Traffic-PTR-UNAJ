model trafico_unaj

global {
    // Esta parte carga los archivos shapefile del mapa
    file shape_file_buildings <- file("../includes/map (1)/multipolygons.shp");
    file shape_file_roads <- file("../includes/map (2)/LINESTRING.shp");

    // Define el área de simulación como el perímetro del archivo de calles
    geometry shape <- envelope(shape_file_roads);

    // Parámetros de la simulación
    int nb_autos <- 50;
    float min_speed <- 15.0 #km/#h;
    float max_speed <- 20.0 #km/#h;
    float desgaste <- 0.02;
    int tiempo_reparacion <- 3;

    graph the_graph;
    
    // Variables para calcular densidad de tráfico
    float densidad_promedio <- 0.0;
    float densidad_maxima <- 0.0;
    int autos_en_movimiento <- 0;

    //Se ejecuta una sola vez al comenzar la simulación
    init {
        // Crea los edificios desde el shapefile
        create edificio from: shape_file_buildings;
        
        // Crea las calles desde el shapefile
        create road from: shape_file_roads;

        map<road,float> pesos_caminos <- road as_map(each:: (each.deterioro * each.shape.perimeter));
        the_graph <- as_edge_graph(road) with_weights pesos_caminos;

        // Crea 50 autos con velocidad aleatoria y posición inicial en una calle
        create auto number: nb_autos {
            velocidad <- rnd(min_speed, max_speed);
            velocidad_original <- velocidad;
            location <- any_location_in(one_of(road));
            destino <- nil;
        }
    }

    // Este reflex se ejecuta cada ciclo de la simulación
    reflex actualizar_grafo {
        map<road,float> pesos_caminos <- road as_map(each:: (each.deterioro * each.shape.perimeter));
        the_graph <- the_graph with_weights pesos_caminos;
    }

    // Este reflex se ejecuta cada 3 horas simuladas
    // Busca la calle más dañada y la repara (deterioro vuelve a 1.0)
    reflex reparar when: every(tiempo_reparacion #hour) {
        road mas_danado <- road with_max_of(each.deterioro);
        ask mas_danado {
            deterioro <- 1.0;
        }
    }
    
    // Calcula la densidad de tráfico en cada calle
    reflex calcular_densidad_trafico {
        float total_densidad <- 0.0;
        densidad_maxima <- 0.0;
        

        loop cada_calle over: road {
            // Cuenta cuántos autos hay a menos de 2 unidades de esa calle
            int autos_en_calle <- auto count (each distance_to cada_calle < 2);
            
            // Calcula la densidad como autos / longitud de la calle
            float densidad_calle <- autos_en_calle / max(cada_calle.shape.perimeter, 1.0);
            total_densidad <- total_densidad + densidad_calle;
            densidad_maxima <- max([densidad_maxima, densidad_calle]);
        }
        densidad_promedio <- total_densidad / max(length(road), 1);
        autos_en_movimiento <- auto count (each.destino != nil);
    }
}

// Representa los edificios del mapa (es solo visual, no lo usamos)
species edificio {
    rgb color <- #gray;
    aspect base {
        draw shape color: color;
    }
}

// Representa las calles del mapa
species road {
    // Deterioro inicial aleatorio entre 1.0 (bueno) y 2.0 (malo)
    float deterioro <- rnd(1.0, 2.0) max: 2.0;
    
    // Calcula un valor entre 0 y 255 para el color según el deterioro
    int colorValue <- int(255 * (deterioro - 1)) update: int(255 * (deterioro - 1));
    
    // Color que va de amarillo (bueno) a rojo (deteriorado)
    rgb color <- rgb(min([255, colorValue]), max([0, 255 - colorValue]), 0) 
                     update: rgb(min([255, colorValue]), max([0, 255 - colorValue]), 0);
    
    // tipo de circulación (hay que arreglarlo)
    string tipo_circulacion <- "dos_manos";
    
    aspect base {
        draw shape color: color width: 2;
    }
}

//vehículos
species auto skills: [moving] {
	//caracteristicas
    rgb color <- #yellow;
    point destino <- nil;
    point ubicacion_anterior <- nil;
    list<point> historial_ubicaciones <- [];
    float velocidad;
    float velocidad_original;
    int ciclos_sin_movimiento <- 0;

    // Elige un destino aleatorio en una calle cuando no tiene destino
    reflex elegir_destino when: destino = nil {
        destino <- any_location_in(one_of(road));
        ciclos_sin_movimiento <- 0;
        historial_ubicaciones <- [];
    }

    //Detecta si hay otros autos cercanos y reduce velocidad si es necesario (No funciona, Hay que arreglarlo)
    reflex detectar_colisiones when: destino != nil {
        list<auto> autos_cercanos <- auto where (each distance_to self.location < 5 and each != self);
        
        // Si hay autos cercanos, reduce velocidad a 50%
        if (length(autos_cercanos) > 0) {
            velocidad <- velocidad_original * 0.5;
        } else {
            velocidad <- velocidad_original;
        }
    }

    //controla el movimiento del auto
    reflex mover when: destino != nil {
        // Guarda la posición actual antes de moverse
        ubicacion_anterior <- location;
        
        // Se mueve hacia el destino usando el grafo de calles y la velocidad actual
        do goto target: destino on: the_graph speed: velocidad;

        // Si llegó al destino (distancia menor a 1 unidad), elige nuevo destino
        if (location distance_to destino < 1) { 
            destino <- nil; 
            ciclos_sin_movimiento <- 0;
            historial_ubicaciones <- [];
        }

        // Agrega la posición actual al historial
        historial_ubicaciones <- historial_ubicaciones + [location];
       
        if (length(historial_ubicaciones) > 3) {
            historial_ubicaciones <- [];
        }

        //Cuenta cuántas veces la posición actual aparece en el historial
        int repeticiones <- 0;
        if (length(historial_ubicaciones) > 1) {
            loop i from: 0 to: length(historial_ubicaciones) - 1 {
                if (i < length(historial_ubicaciones) and historial_ubicaciones[i] distance_to location < 0.5) {
                    repeticiones <- repeticiones + 1;
                }
            }
        }
        
        // Si el auto está circulando en un loop, cambia de ubicación (no funciona como debería)
        if (repeticiones > 8) {
            destino <- nil;
            historial_ubicaciones <- [];
        }

        if (location distance_to ubicacion_anterior < 0.5) {
            ciclos_sin_movimiento <- ciclos_sin_movimiento + 1;
            
            // Si lleva más de 15 ciclos sin moverse,cambia de ubicación
            if (ciclos_sin_movimiento > 3) {
                destino <- nil;
                ciclos_sin_movimiento <- 0;
                historial_ubicaciones <- [];
            }
        } else {
            // Si se movió, reinicia el contador
            ciclos_sin_movimiento <- 0;
        }

    
        list<road> calles_cercanas <- road where (each distance_to self.location < 2);
        if (length(calles_cercanas) > 0) {
            // Aumenta el deterioro de esa calle
            ask calles_cercanas[0] {
                deterioro <- deterioro + desgaste;
                
                // El deterioro no puede superar 2.0
                if (deterioro > 2.0) { 
                    deterioro <- 2.0; 
                }
            }
        }
    }

    aspect base {
        draw circle(8) color: color border: #black;
    }
}

//Define la interfaz gráfica y los parámetros de la simulación
experiment simulacion_trafico type: gui {
    parameter "Shapefile edificios" var: shape_file_buildings category: "GIS";
    parameter "Shapefile calles" var: shape_file_roads category: "GIS";
    parameter "Número de autos" var: nb_autos category: "Autos";
    parameter "Velocidad mínima" var: min_speed category: "Autos" min: 1.0 max: 20.0;
    parameter "Velocidad máxima" var: max_speed category: "Autos" min: 1.0 max: 50.0;
    parameter "Desgaste de las calles" var: desgaste category: "Calles";
    parameter "Horas entre reparaciones" var: tiempo_reparacion category: "Calles";

     //Define lo se muestra en pantalla
    output {
        display city_display type: opengl {
            species edificio aspect: base;
            species road aspect: base;
            species auto aspect: base;
        }

        //Gráfico que monitorea la densidad de tráfico vehicular
        display grafico_densidad_trafico type: 2d refresh: every(10 #cycles) {
            chart "Densidad de Tráfico Vehicular" type: series {
                data "Densidad Promedio" value: densidad_promedio;
                data "Densidad Máxima" value: densidad_maxima;
                data "Autos en Movimiento" value: autos_en_movimiento;
            }
        }
    }
}
    