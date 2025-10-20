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
    geometry shape <- envelope(shape_file_roads);

    int nb_autos <- 200;
    int nb_autos_max <- 250;
    float min_speed <- 1 #km/#h;
    float max_speed <- 4 #km/#h;

    date starting_date <- date("2025-10-10-00-00-00");
    float step <- 0.5 #mn;

    int hora_apertura <- 7;
    int hora_cierre <- 22;

    graph the_graph;

    float densidad_promedio <- 0.0;
    float densidad_maxima <- 0.0;
    int autos_en_movimiento <- 0;

    init {
        create universidad from: shape_file_uni;
        create road from: shape_file_roads;
        create punto1 from: shape_file_point1;
        create punto2 from: shape_file_point2;

        the_graph <- as_edge_graph(road);

        create auto number: nb_autos {
            velocidad <- rnd(min_speed, max_speed);
            velocidad_original <- velocidad;
            location <- any_location_in(one_of(road));
            estacionado <- false;
            tiempo_estacionado <- 0;
            ciclos_sin_movimiento <- 0;

            if rnd(1.0) < 0.5 {
                tipo_uni <- true;
                yendo_a_uni <- false;
                color <- #yellow;
                hora_llegada <- rnd(hora_apertura, 19);
                destino <- nil;
            } else {
                tipo_uni <- false;
                yendo_a_uni <- false;
                color <- #orange;

                // Destino aleatorio inicial válido
                point new_dest <- nil;
                loop while:true {
                    new_dest <- any_location_in(one_of(road));
                    if distance_to(location, new_dest) > 0.5 { break; }
                }
                destino <- new_dest;
            }
        }
    }

    reflex avanzar_tiempo {
        current_date <- current_date + step #hour;
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

    reflex gestionar_autos_no_uni {
	    // 🔻 Reducción progresiva del tráfico entre 23:00 y 5:00
	    if current_date.hour >= 23 or current_date.hour < 5 {
	        loop a over: auto {
	            if not a.tipo_uni and rnd(1.0) < 0.005 { // 0.5% chance de desaparecer por ciclo
	                ask a { do die; }
	            }
	            if a.tipo_uni and rnd(1.0) < 0.002 { // 0.2% chance: autos amarillos
	                ask a { do die; }
	            }
	        }
	    }
	
	    // 🔸 Generación gradual de tráfico desde las 5:00 hasta las 7:00
	    if current_date.hour >= 5 and current_date.hour < 7 {
	        int autos_actuales <- length(auto);
	        if autos_actuales < nb_autos_max {
	            // entre más cerca de las 7, más probabilidad de que aparezcan autos
	            float factor <- (current_date.hour - 5) / 2.0; // 0 a 1 entre 5 y 7
	            if rnd(1.0) < factor { // al principio lento, luego más frecuente
	                create auto number: rnd(1,2) {
	                    velocidad <- rnd(min_speed, max_speed);
	                    velocidad_original <- velocidad;
	                    location <- any_location_in(one_of(road));
	                    tipo_uni <- false;
	                    yendo_a_uni <- false;
	                    estacionado <- false;
	                    color <- #orange;
	
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
	    
	    // 🏫 Generación gradual de autos amarillos (universitarios) entre 6:00 y 8:00
	    if current_date.hour >= 6 and current_date.hour < 8 {
	        int autos_actuales <- length(auto);
	        if autos_actuales < nb_autos_max {
	            float factor <- (current_date.hour - 6) / 2.0; // 0 → 1 entre 6 y 8
	            if rnd(1.0) < factor * 0.7 { // un poco menos frecuente que el tráfico
	                create auto number: rnd(1,2) {
	                    velocidad <- rnd(min_speed, max_speed);
	                    velocidad_original <- velocidad;
	                    location <- any_location_in(one_of(road));
	                    tipo_uni <- true;
	                    yendo_a_uni <- false;
	                    estacionado <- false;
	                    hora_llegada <- rnd(hora_apertura, 19);
	                    color <- #yellow;
	                    destino <- nil;
	                }
	            }
	        }
	        
	    }
	
	    // 🔺 Horarios pico (7–9 y 17–19): aumento más fuerte del tráfico
	    if ((current_date.hour >= 7 and current_date.hour <= 9) or (current_date.hour >= 17 and current_date.hour <= 19)) {
	        int autos_actuales <- length(auto);
	        if autos_actuales < nb_autos_max {
	            create auto number: rnd(1,2) {
	                velocidad <- rnd(min_speed, max_speed);
	                velocidad_original <- velocidad;
	                location <- any_location_in(one_of(road));
	                tipo_uni <- false;
	                yendo_a_uni <- false;
	                estacionado <- false;
	                color <- #orange;
	
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

species punto1 { rgb color <- #red; aspect base { draw circle(8) color: color; } }
species punto2 { rgb color <- #red; aspect base { draw circle(8) color: color; } }
species universidad { rgb color <- #aqua; aspect base { draw shape color: color; } }
species road { rgb color <- #gray; aspect base { draw shape color: color width: 2; } }

species auto skills: [moving] {
    rgb color <- #yellow;
    point destino <- nil;
    point ubicacion_anterior <- nil;
    list<point> historial_ubicaciones <- [];
    float velocidad;
    float velocidad_original;
    int ciclos_sin_movimiento <- 0;
    bool yendo_a_uni <- false;
    bool estacionado <- false;
    int tiempo_estacionado <- 0;
    bool tipo_uni <- false;
    int hora_llegada <- 0;

	// Ir a la universidad
    reflex ir_a_la_uni when: tipo_uni and (current_date.hour >= hora_llegada and current_date.hour < 21) and not yendo_a_uni and not estacionado {
        yendo_a_uni <- true;
        if rnd(1.0) < 0.5 {destino <- one_of(punto1).shape.centroid;} 
        else {destino <- one_of(punto2).shape.centroid;}
    }
	// Irse de la universidad a las 22
    reflex irse_de_la_uni when: tipo_uni and current_date.hour >= 22 and estacionado {
        estacionado <- false;
        yendo_a_uni <- false;
        velocidad <- velocidad_original;
        color <- #yellow;
		// Generar un destino aleatorio en la red vial
        point new_dest <- nil;
        loop while:true {
            new_dest <- any_location_in(one_of(road));
            if distance_to(location, new_dest) > 0.5 { break; }
        }
        destino <- new_dest;
    }
	//movimiento
    reflex mover when: destino != nil and (not estacionado or tipo_uni) {
        ubicacion_anterior <- location;
        do goto target: destino speed: velocidad on: the_graph;
		// Llegada al destino
        if distance_to(location, destino) < 0.001 {
            if tipo_uni and yendo_a_uni {
                estacionado <- true;
                velocidad <- 0.0;
                color <- #blue;
                destino <- nil;
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
        if distance_to(location, ubicacion_anterior) < 0.01 {
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
    parameter "Número de autos" var: nb_autos category: "Autos";

    output {
        display city_display type: opengl {
            species road aspect: base;
            species universidad aspect: base;
            species punto1 aspect: base;
            species punto2 aspect: base;
            species auto aspect: base;
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
