@tool
extends Node

## Database delle stanze standard per l'editor delle navi.
## Contiene definizioni di dimensioni minime e dispositivi predefiniti.

const ROOMS = {
	"ponte_comando": {
		"name": "Ponte di comando",
		"min_size": Vector2(30, 30),
		"default_devices": ["pod_piloti"],
		"color": Color(0.2, 0.4, 0.6, 0.5),
		"category": "command"
	},
	"supporto_vitale_min": {
		"name": "Supporto vitale minimale",
		"min_size": Vector2(60, 60),
		"default_devices": ["purificatore", "caldaia"],
		"color": Color(0.2, 0.6, 0.2, 0.5),
		"category": "life_support"
	},
	"supporto_vitale_adv": {
		"name": "Supporto vitale avanzato",
		"min_size": Vector2(100, 100),
		"default_devices": ["purificatore", "caldaia", "serra_idroponica"],
		"color": Color(0.1, 0.7, 0.1, 0.5),
		"category": "life_support"
	},
	"mainframe": {
		"name": "Mainframe",
		"min_size": Vector2(30, 30),
		"default_devices": ["mainframe"],
		"color": Color(0.4, 0.2, 0.6, 0.5),
		"category": "utility"
	},
	"comunicazioni": {
		"name": "Sistemi di comunicazione",
		"min_size": Vector2(60, 60),
		"default_devices": ["matrice_comunicazione"],
		"color": Color(0.6, 0.4, 0.2, 0.5),
		"category": "utility"
	},
	"reattore_fusione": {
		"name": "Reattore a fusione",
		"min_size": Vector2(200, 200),
		"default_devices": ["reattore"],
		"color": Color(0.8, 0.2, 0.2, 0.5),
		"category": "power"
	},
	"baia_carico": {
		"name": "Baia di carico",
		"min_size": Vector2(150, 150),
		"default_devices": [],
		"color": Color(0.5, 0.5, 0.5, 0.5),
		"category": "cargo"
	},
	"sala_motori": {
		"name": "Sala motori",
		"min_size": Vector2(100, 100),
		"default_devices": ["reattore_1", "reattore_2"],
		"color": Color(0.7, 0.3, 0.1, 0.5),
		"category": "propulsion"
	},
	"pod_drone": {
		"name": "Pod drone di servizio",
		"min_size": Vector2(60, 60),
		"default_devices": ["baia_ricarica_drone"],
		"color": Color(0.3, 0.3, 0.6, 0.5),
		"category": "utility"
	},
	"matrice_sensori": {
		"name": "Matrice sensori",
		"min_size": Vector2(60, 60),
		"default_devices": ["array_sensori"],
		"color": Color(0.2, 0.5, 0.5, 0.5),
		"category": "utility"
	},
	"armatura_adattiva": {
		"name": "Armatura adattiva",
		"min_size": Vector2(30, 30),
		"default_devices": ["sistema_difesa"],
		"color": Color(0.4, 0.4, 0.4, 0.5),
		"category": "defense"
	},
	"armamenti": {
		"name": "Armamenti",
		"min_size": Vector2(80, 80),
		"default_devices": ["gestore_torrette"],
		"color": Color(0.9, 0.1, 0.1, 0.5),
		"category": "offense"
	}
}

func get_room_ids() -> Array:
	return ROOMS.keys()

func get_room_data(id: String) -> Dictionary:
	return ROOMS.get(id, {})

func get_room_name(id: String) -> String:
	return ROOMS.get(id, {}).get("name", "Stanza Sconosciuta")
