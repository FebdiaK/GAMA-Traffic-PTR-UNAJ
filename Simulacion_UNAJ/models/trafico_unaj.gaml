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

    int nb_autos <- 200;
    int nb_autos_max <- 350;
    float min_speed <- 1 #km/#h;
    float max_speed <- 2 #km/#h;

    int sema_ciclo <- 0;
    date starting_date <- date("2025-10-10-00-00-00");
    float step <- 0.3 #mn;

    int hora_apertura <- 8;
    int hora_cierre <- 22;

    graph the_graph;
    list<semaforo> sema_id3 <- [];
    list<semaforo> sema_id4 <- [];

    float densidad_promedio <- 0.0;
    float densidad_maxima <- 0.0;
    int autos_en_movimiento <- 0;

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
            tiempo_estacionado <- 0;
            ciclos_sin_movimiento <- 0;

            if rnd(1.0) < 0.4 {
                // Autos amarillos (universitarios) con camino garantizado
                tipo_uni <- true;
                yendo_a_uni <- false;
                color <- #yellow;
                hora_llegada <- rnd(hora_apertura, 19);

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
        float total_densidad <- 0.0;
        densidad_maxima <- 0.0;

        loop calle over: road {
            int autos_en_calle <- auto count (each distance_to calle < 3);
            float densidad_calle <- autos_en_calle / max(calle.shape.perimeter, 1.0);
            total_densidad <- total_densidad + densidad_calle;
            densidad_maxima <- max([densidad_maxima, densidad_calle]);
        }

        densidad_promedio <- total_densidad / max(length(road), 1);
        autos_en_movimiento <- auto count (each.destino != nil);
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

        int autos_amarillos_actuales <- (list(auto) count (each.tipo_uni=true));

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
                    location <- any_location_in(one_of(road));

                    // Destino inicial válido
                    point new_dest <- nil;
                    loop while:true {
                        new_dest <- any_location_in(one_of(road));
                        if distance_to(location, new_dest) > 0.5 { break; }
                    }
                    destino <- new_dest;
                }
            }
        }
    }
}


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
    list<point> historial_ubicaciones <- [];
    float velocidad;
    float velocidad_original;
    int ciclos_sin_movimiento <- 0;

    bool volviendo_de_uni <- false;
    bool yendo_a_uni <- false;

    bool estacionado <- false;
    int tiempo_estacionado <- 0;

    int tiempo_en_casa <- 0;

    bool tipo_uni <- false;
    int hora_llegada <- 0;

    // Ir a la universidad
    reflex ir_a_la_uni when: tipo_uni and (current_date.hour >= hora_llegada and current_date.hour < 21) and not yendo_a_uni and not estacionado {
        yendo_a_uni <- true;
        if rnd(1.0) < 0.5 { destino <- one_of(punto1).shape.centroid; } 
        else { destino <- one_of(punto2).shape.centroid; }
    }

    // Irse de la universidad a las 22
    reflex irse_de_la_uni when: tipo_uni and current_date.hour >= 22 and estacionado {
        estacionado <- false;
        yendo_a_uni <- false;
        volviendo_de_uni <- true;

        velocidad <- velocidad_original;
        color <- #yellow;

        // Calcular camino válido de regreso
        path camino_retorno <- path_between(the_graph, location, ubicacion_anteriorUni );
        loop while: camino_retorno = nil {
            camino_retorno <- path_between(the_graph, ubicacion_anteriorUni, location);
        }
        destino <- ubicacion_anteriorUni;
    }

    reflex eliminar_si_llego_a_casa when: estacionado and color = #gray {
        tiempo_en_casa <- tiempo_en_casa + 1;

        // Cada ciclo equivale a un paso de simulación (step = 0.3 minutos)
        // 1 hora = 60 minutos → 60 / 0.3 ≈ 200 ciclos
        if tiempo_en_casa > 50 {
            do die;
        }
    }

    // movimiento
    reflex mover when: destino != nil and (not estacionado or tipo_uni) {
        semaforo semaforo_cercano <- one_of(semaforo where (distance_to(location, each) < 5));

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
        if ubicacion_anterior != nil and distance_to(location,ubicacion_anterior) < 0.3 {
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


experiment simulacion_trafico type: gui {
    parameter "Número de autos" var: nb_autos_max category: "Autos";

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
            chart "Densidad de Tráfico Vehicular" type: series {
                data "Densidad Promedio" value: densidad_promedio;
                data "Densidad Máxima" value: densidad_maxima;
                data "Autos en Movimiento" value: autos_en_movimiento;
            }
        }
    }
}
