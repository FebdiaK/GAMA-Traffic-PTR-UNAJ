/**
* Name: trafico_unaj
* Based on the internal empty template. 
* Author: fede_
* Tags: 
*/

model trafico_unaj

/* Insert your model definition here */

//global {
//    file roads_shapefile <- file("../includes/unaj_map.osm");
//    geometry shape <- envelope(roads_shapefile); 
//    graph road_network <- roads_shapefile;
//    int nm_car <- 200; // cantidad de autos
//    int tiempo_en_universidad <- 200; // pasos que esperan dentro
//    
//}
//
//species road {
//    aspect base {
//        draw shape color: #gray;
//    }
//}
//
//species auto skills:[moving] {
//    point destino;
//    aspect base {
//        draw circle(10) color: #red;
//    }
//    reflex moverse {
//        if (destino = nil or destino = location) {
//            destino <- any_location_in (one_of(road));
//        }
//        do goto target: destino on: road_network recompute_path: true;
//    }
//}
//
//experiment simulacion_trafico type: gui {
//    output {
//        display "Tránsito UNAJ" type: opengl {
//            species road aspect: base;
//            species auto aspect: base;
//        }
//    }
//
//    init {
//        create road from: roads_shapefile;
//        create auto number: nm_car {
//            location <- any_location_in (one_of(road));
//        }
//        road_network <- as_edge_graph(road);
//    }
//}

global {
    file roads_shapefile <- file("../includes/map (2).osm");
    geometry shape <- envelope(roads_shapefile); 
    
    graph road_network <- roads_shapefile;
    int nm_car <- 50; // cantidad de autos
}

species road {
    aspect base {
        draw shape color: #gray;
    }
}

species auto skills:[moving] {
    point destino;
    aspect base {
        draw circle(10) color: #red;
    }
    reflex moverse {
        if (destino = nil or destino = location) {
            destino <- any_location_in (one_of(road));
        }
        do goto target: destino on: road_network recompute_path: true;
    }
}

experiment simulacion_trafico type: gui {
    output {
        display "Tránsito UNAJ" type: opengl {
            species road aspect: base;
            species auto aspect: base;
        }
    }

    init {
        create road from: roads_shapefile;
        create auto number: nm_car {
            location <- any_location_in (one_of(road));
        }
        road_network <- as_edge_graph(road);
    }
}

    