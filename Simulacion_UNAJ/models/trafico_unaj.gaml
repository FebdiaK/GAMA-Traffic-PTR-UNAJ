/**
* Name: trafico_unaj
* Author: fede_
*/

model trafico_unaj

global {
    file shape_file_uni <- file("../includes/universidad.shp");
    file shape_file_roads <- file("../includes/calles/roadsNew.shp");
    file shape_file_point1 <- file("../includes/entradaCalchaqui.shp");
    file shape_file_point2 <- file("../includes/entradaBelgrano.shp");
    file shape_file_semaforos <- file("../includes/semaforos/semaforos2.shp");
    geometry shape <- envelope(shape_file_roads);

    date starting_date <- date("2025-10-10-00-00-00");
    float step <- 0.3 #mn;
    
    int nb_autos <- 200;
    int nb_autos_max <- 350;
    float min_speed <- 0.5 #km/#h;
    float max_speed <- 2 #km/#h;
    int autos_en_movimiento <- 0;
    int autos_en_uni <-0;
    int autos_amarillos_actuales;
    int autosAmaFueraDeUni;
    int autosVolviendoACasa;

    int hora_apertura <- 8;
    int hora_cierre <- 22;

    int sema_ciclo <- 0;
    list<semaforo> sema_id3 <- [];
    list<semaforo> sema_id4 <- [];
	
    graph the_graph;
	 // ================= Inicialización =================
    init {
        create universidad from: shape_file_uni;
        create road from: shape_file_roads;
        create punto1 from: shape_file_point1;
        create punto2 from: shape_file_point2;
        create semaforo from: shape_file_semaforos;

        // Separarlos en listas según el ID
        loop s over: semaforo {
            if (s.id = 3) { add item:s to: sema_id3; }
            if (s.id = 4) { add item:s to: sema_id4; }
        }

        the_graph <- as_edge_graph(road);

        create auto number: nb_autos {
            velocidad <- rnd(min_speed, max_speed);
            velocidad_original <- velocidad;
            location <- any_location_in(one_of(road));
            estacionado <- false;
             
            if rnd(1.0) < 0.4 {
                // Autos amarillos (universitarios) con camino garantizado
                tipo_uni <- true;
                yendo_a_uni <- false;
                color <- #yellow;
                hora_llegada <- rnd(hora_apertura, 19);
                // Asignar una hora de salida dinámica
				int llegada_segura <- min(hora_llegada, hora_cierre - 1);
				hora_salida <- rnd(llegada_segura + 1, hora_cierre);

                // Ubicación inicial válida
                point loc_in_road <- any_location_in(one_of(road));
                point uni_dest <- nil;
                if rnd(1.0) < 0.5 { 
                    uni_dest <- one_of(punto1).shape.centroid; 
                } else { 
                    uni_dest <- one_of(punto2).shape.centroid; 
                }
                path camino <- path_between(the_graph, loc_in_road, uni_dest);

                loop while: camino = nil {
                    loc_in_road <- any_location_in(one_of(road));
                    camino <- path_between(the_graph, loc_in_road, uni_dest);
                }

                location <- loc_in_road;
                ubicacion_anteriorUni <- location;
                destino <- nil;

            } else {
                // Autos naranjas con camino válido hacia la universidad
                tipo_uni <- false;
                yendo_a_uni <- false;
                color <- #orange;

                point loc_in_road <- any_location_in(one_of(road));
                point uni_dest <- nil;
                if rnd(1.0) < 0.5 { 
                    uni_dest <- one_of(punto1).shape.centroid; 
                } else { 
                    uni_dest <- one_of(punto2).shape.centroid; 
                }

                path camino <- path_between(the_graph, loc_in_road, uni_dest);
                loop while: camino = nil {
                    loc_in_road <- any_location_in(one_of(road));
                    camino <- path_between(the_graph, loc_in_road, uni_dest);
                }

                location <- loc_in_road;
                destino <- loc_in_road; // empieza en el primer punto del camino
            }
        }
    }
	
	// ================= Reflexs =================
    reflex avanzar_tiempo {
        current_date <- current_date + step #hour;
    }

    reflex cambiar_estado_semaforos { // cada 200 ciclos
        sema_ciclo <- sema_ciclo + 1;
        if (sema_ciclo >= 50) {  // cada 200 ciclos aprox.
            sema_ciclo <- 0;

            bool estado_actual <- sema_id3[0].en_verde; // suponemos que todos del grupo tienen el mismo estado

            // Cambiar los estados
            loop s over: sema_id3 { s.en_verde <- not estado_actual; }
            loop s over: sema_id4 { s.en_verde <- estado_actual; }
        }
    }

    reflex calcular_densidad_trafico {
        
        autos_en_movimiento <- auto count (each.estacionado != true);
    }
    
    reflex calcularAutosEnUni{
        
        autos_en_uni <- auto count (each.estacionado = true and each.color=#blue);
    }
    

    reflex gestionar_densidad_autos {
        // 🔻 Reducción progresiva del tráfico entre 23:00 y 5:00
    	if current_date.hour >= 23 or current_date.hour < 5 {
	        list<auto> autos_a_eliminar <- [];
	        loop a over: auto {
	            if rnd(1.0) < 0.003 { add a to: autos_a_eliminar; }
        	}
        ask autos_a_eliminar { do die; }
    	}

        // 🔸 Generación gradual de tráfico desde las 4:00 hasta las 7:00
        if current_date.hour >= 4 and current_date.hour < 7 {

            int autos_actuales <- length(auto);
            int autos_naranjas_actuales <- (list(auto) count (each.tipo_uni=false));
            float factor <- (current_date.hour - 4) / 3.0; // 0 a 1 entre 5 y 7

            if (autos_naranjas_actuales < (nb_autos_max * 2 / 3)) and (rnd(1.0) < factor) {
                create auto number: rnd(1,2) {
                    velocidad <- rnd(min_speed, max_speed);
                    velocidad_original <- velocidad;
                    tipo_uni <- false;
                    yendo_a_uni <- false;
                    estacionado <- false;
                    color <- #orange;

                    // Generar ubicación y destino válidos
                    point loc_in_road <- any_location_in(one_of(road));
                    point uni_dest <- nil;
                    if rnd(1.0) < 0.5 { uni_dest <- one_of(punto1).shape.centroid; } 
                    else { uni_dest <- one_of(punto2).shape.centroid; }

                    path camino <- path_between(the_graph, loc_in_road, uni_dest);
                    loop while: camino = nil {
                        loc_in_road <- any_location_in(one_of(road));
                        camino <- path_between(the_graph, loc_in_road, uni_dest);
                    }

                    location <- loc_in_road;
                    destino <- loc_in_road;
                }
            }
        }

        autos_amarillos_actuales <- (list(auto) count (each.tipo_uni=true));
        autosAmaFueraDeUni <- (list(auto) count (each.tipo_uni=true and each.estacionado=false and each.volviendo_de_uni=false));
        autosVolviendoACasa<- (list(auto) count (each.tipo_uni=true and each.volviendo_de_uni=true or each.en_casa));

        // 🏫 Generación gradual de autos amarillos (universitarios) entre 6:00 y 8:00
        if current_date.hour >= 5 and current_date.hour < 8 {
            float factorAma <- (current_date.hour - 5) / 1.2; // 0 → 1 entre 6 y 8

            if (autos_amarillos_actuales < nb_autos_max/3) and (rnd(1.0) < factorAma) {
                point loc_in_road <- any_location_in(one_of(road));
                point uni_dest <- nil;
                if rnd(1.0) < 0.5 { uni_dest <- one_of(punto1).shape.centroid; } 
                else { uni_dest <- one_of(punto2).shape.centroid; }

                path camino <- path_between(the_graph, loc_in_road, uni_dest);
                loop while: camino = nil {
                    loc_in_road <- any_location_in(one_of(road));
                    camino <- path_between(the_graph, loc_in_road, uni_dest);
                }

                create auto number: 1 {
                    color <- #yellow;
                    velocidad <- rnd(min_speed, max_speed);
                    velocidad_original <- velocidad;
                    tipo_uni <- true;
                    yendo_a_uni <- false;
                    estacionado <- false;
                    hora_llegada <- rnd(hora_apertura, 19);
                    int llegada_segura <- min(hora_llegada, hora_cierre - 1);
                    hora_salida <- rnd(llegada_segura + 1, hora_cierre);
                    location <- loc_in_road;
                    ubicacion_anteriorUni <- location;
                    destino <- nil;
                }
            }
        }

        // 🔺 Horarios pico (7–9 y 17–19): aumento más fuerte del tráfico
        if ((current_date.hour >= 7 and current_date.hour <= 9) or (current_date.hour >= 17 and current_date.hour <= 19)) {
            int autos_actuales <- length(auto);
            int autos_naranjas <- (list(auto) count (each.tipo_uni=false));
            int max_naranjas <- int(nb_autos_max * 2 / 3);

            if autos_actuales < nb_autos_max and autos_naranjas < max_naranjas {
                create auto number: rnd(1,2) {
                    color <- #orange;
                    velocidad <- rnd(min_speed, max_speed);
                    velocidad_original <- velocidad;
                    tipo_uni <- false;
                    yendo_a_uni <- false;
                    estacionado <- false;
                    
                    // Generar ubicación y destino válidos
                    point loc_in_road <- any_location_in(one_of(road));
                    point uni_dest <- nil;
                    if rnd(1.0) < 0.5 { uni_dest <- one_of(punto1).shape.centroid; } 
                    else { uni_dest <- one_of(punto2).shape.centroid; }

                    path camino <- path_between(the_graph, loc_in_road, uni_dest);
                    loop while: camino = nil {
                        loc_in_road <- any_location_in(one_of(road));
                        camino <- path_between(the_graph, loc_in_road, uni_dest);
                    }

                    location <- loc_in_road;
                    destino <- loc_in_road;
                }
            }
        }
    }
}

// ================= Species =================

species punto1 { 
    rgb color <- #brown; 
    aspect base { draw square(8) color: color; } 
}
species punto2 { 
    rgb color <- #brown; 
    aspect base { draw square(8) color: color; } 
}
species universidad { 
    rgb color <- #aqua; 
    aspect base { draw shape color: color; } 
}
species road {
    rgb color <- #gray; 
    aspect base { draw shape color: color width: 2; } 
}

species semaforo {
    int id;
    bool en_verde <- false;

    aspect base {
        draw circle(6) color: (en_verde ? #green : #red) border: #black;
    }
}


species auto skills: [moving] {
    rgb color <- #yellow;
    point destino <- nil;
    point ubicacion_anteriorUni <- nil;

    point ubicacion_anterior <- nil;
    float velocidad;
    float velocidad_original;
    
    bool volviendo_de_uni <- false;
    bool yendo_a_uni <- false;

    bool estacionado <- false;
    
    bool en_casa <- false;
    int tiempo_en_casa <- 0;

    bool tipo_uni <- false;
    int hora_llegada <- 0;
    int hora_salida <- 0;

    // Ir a la universidad
    reflex ir_a_la_uni when: tipo_uni and (current_date.hour >= hora_llegada and current_date.hour < 21) and not yendo_a_uni and not estacionado and not en_casa
    {
        yendo_a_uni <- true;
        if rnd(1.0) < 0.5 { destino <- one_of(punto1).shape.centroid; } 
        else { destino <- one_of(punto2).shape.centroid; }
    }

    // Irse de la universidad en su respectivo horario de salida
    reflex irse_de_la_uni when: tipo_uni and (current_date.hour >= hora_salida) {
        estacionado <- false;
        yendo_a_uni <- false;
        volviendo_de_uni <- true;

        velocidad <- velocidad_original;
        color <- #blueviolet;

        // Calcular camino válido de regreso
        path camino_retorno <- path_between(the_graph, location, ubicacion_anteriorUni );
        loop while: camino_retorno = nil {
            camino_retorno <- path_between(the_graph, ubicacion_anteriorUni, location);
        }
        destino <- ubicacion_anteriorUni;
    }

    reflex eliminar_si_llego_a_casa when: en_casa{
 
        tiempo_en_casa <- tiempo_en_casa + 1;

        // Paso de simulación = 0.3 minutos
	    // 1 hora = 200 ciclos
	    if tiempo_en_casa > 200 {
	        do die;
	    }
    }

    // movimiento
    reflex mover when: destino != nil and (not estacionado) {
    	
    	if en_casa {
	        velocidad <- 0.0;
	        destino <- nil;
	        color <- #gray;
	        return;
    	}
    	
        semaforo semaforo_cercano <- one_of(semaforo where (distance_to(location, each) < 3));

        bool puede_avanzar <- true;

        if semaforo_cercano != nil {
            // Si el semáforo está en rojo, detenerse
            if not semaforo_cercano.en_verde {
                velocidad <- 0.0;
                puede_avanzar <- false;
            } else {
                velocidad <- velocidad_original;
            }
        }

        // Solo se mueve si puede avanzar (verde o sin semáforo cerca)
        if puede_avanzar {
            ubicacion_anterior <- location;
            do goto target: destino speed: velocidad on: the_graph;
        }

        // Llegada al destino
        if destino != nil and distance_to(location,destino) < 0.001 {
            if tipo_uni and yendo_a_uni {
                estacionado <- true;
                velocidad <- 0.0;
                color <- #blue;
                destino <- nil;
            } else if tipo_uni and volviendo_de_uni {
                estacionado <- true;
                volviendo_de_uni <- false;
                en_casa <- true;
                velocidad <- 0.0;
                color <- #gray;
                destino <- nil;
                tiempo_en_casa <- 0; // empezar a contar tiempo estacionado en casa
            } else {
                // Autos naranjas siempre generan nuevo destino
                point new_dest <- nil;
                loop while:true {
                    new_dest <- any_location_in(one_of(road));
                    if distance_to(location, new_dest) > 0.5 { break; }
                }
                destino <- new_dest;
            }
        }

        // Evitar autos pegados
        if not en_casa and ubicacion_anterior != nil and distance_to(location,ubicacion_anterior) < 0.3 {
            point new_dest <- nil;
            loop while:true {
                new_dest <- any_location_in(one_of(road));
                if distance_to(location, new_dest) > 0.5 { break; }
            }
            destino <- new_dest;
        }
    }

    aspect base { draw circle(8) color: color border: #black; }
}

// ================= Experiment =================

experiment simulacion_trafico type: gui {
    parameter "Número de autos" var: nb_autos_max category: "Autos";
    float minimum_cycle_duration <- 0.01#s;

    output {
        display city_display type: opengl {
            species road aspect: base;
            species universidad aspect: base;
            species punto1 aspect: base;
            species punto2 aspect: base;
            species auto aspect: base;
            species semaforo aspect: base;
        }

        display grafico_densidad_trafico type: 2d refresh: every(10 #cycles) {
            chart "Densidad de Tráfico Vehicular" type: series  
            	x_label: "Hora del Día (200 ciclos / hr)"
            	y_label: "Autos en Movimiento"
            	lines: true
            	color: #black
            	background: #white 
            	{	

                data "Densidad de Autos" 
                	value: autos_en_movimiento 
                	color:#green
                	;
            	}
            	
    	}
    	
    	display grafico_autosEnUni type: 2d refresh: every(10#cycles){
    		chart "Cantidad de Autos en la Universidad" type: pie
    			{
    				data "Autos Estacionados en la UNAJ" value: autos_en_uni color: #blue;
    				data "Autos por ir a la UNAJ" value: autosAmaFueraDeUni color: #yellow;
    				data "Autos yéndose de la UNAJ" value: autosVolviendoACasa color: #gray;
    		}
    	}
	}
}