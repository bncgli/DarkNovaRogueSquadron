@tool
class_name RoomDatabaseSingleton
extends Node

## Database delle stanze standard per l'editor delle navi.
## Contiene definizioni di dimensioni minime e dispositivi predefiniti.

const ROOMS = {
	"ponte_comando": {
		"name": "Ponte di comando",
		"min_size": Vector2(30, 30),
		"default_devices": ["pod_piloti"],
		"color": Color(0.2, 0.4, 0.6, 0.5)
	},
	"supporto_vitale_min": {
		"name": "Supporto vitale minimale",
		"min_size": Vector2(60, 60),
		"default_devices": ["purificatore", "caldaia"],
		"color": Color(0.2, 0.6, 0.2, 0.5)
	},
	"supporto_vitale_adv": {
		"name": "Supporto vitale avanzato",
		"min_size": Vector2(100, 100),
		"default_devices": ["purificatore", "caldaia", "serra_idroponica"],
		"color": Color(0.1, 0.7, 0.1, 0.5)
	},
	"mainframe": {
		"name": "Mainframe",
		"min_size": Vector2(30, 30),
		"default_devices": ["mainframe"],
		"color": Color(0.4, 0.2, 0.6, 0.5)
	},
	"comunicazioni": {
		"name": "Sistemi di comunicazione",
		"min_size": Vector2(60, 60),
		"default_devices": ["matrice_comunicazione"],
		"color": Color(0.6, 0.4, 0.2, 0.5)
	},
	"reattore_fusione": {
		"name": "Reattore a fusione",
		"min_size": Vector2(200, 200),
		"default_devices": ["reattore"],
		"color": Color(0.8, 0.2, 0.2, 0.5)
	},
	"baia_carico": {
		"name": "Baia di carico",
		"min_size": Vector2(150, 150),
		"default_devices": [],
		"color": Color(0.5, 0.5, 0.5, 0.5)
	},
	"sala_motori": {
		"name": "Sala motori",
		"min_size": Vector2(100, 100),
		"default_devices": ["reattore_1", "reattore_2"],
		"color": Color(0.7, 0.3, 0.1, 0.5)
	},
	"pod_drone": {
		"name": "Pod drone di servizio",
		"min_size": Vector2(60, 60),
		"default_devices": ["baia_ricarica_drone"],
		"color": Color(0.3, 0.3, 0.6, 0.5)
	},
	"matrice_sensori": {
		"name": "Matrice sensori",
		"min_size": Vector2(60, 60),
		"default_devices": ["array_sensori"],
		"color": Color(0.2, 0.5, 0.5, 0.5)
	},
	"armatura_adattiva": {
		"name": "Armatura adattiva",
		"min_size": Vector2(30, 30),
		"default_devices": ["sistema_difesa"],
		"color": Color(0.4, 0.4, 0.4, 0.5)
	},
	"armamenti": {
		"name": "Armamenti",
		"min_size": Vector2(80, 80),
		"default_devices": ["gestore_torrette"],
		"color": Color(0.9, 0.1, 0.1, 0.5)
	}
}


const CAMERAS_METADATA: Array[Dictionary] = [
	{
		"id": "front",
		"name": "Frontale",
		"code": "CAM 01 [PRUA]",
		"direction": "Prua (-Z)",
		"desc": "Visuale di navigazione anteriore",
		"icon": "▲"
	},
	{
		"id": "rear",
		"name": "Posteriore",
		"code": "CAM 02 [POPPA]",
		"direction": "Poppa (+Z)",
		"desc": "Visuale posteriore propulsori",
		"icon": "▼"
	},
	{
		"id": "left",
		"name": "Laterale Sinistra",
		"code": "CAM 03 [BABORDO]",
		"direction": "Babordo (-X)",
		"desc": "Visuale ala sinistra",
		"icon": "◀"
	},
	{
		"id": "right",
		"name": "Laterale Destra",
		"code": "CAM 04 [TRIBORDO]",
		"direction": "Tribordo (+X)",
		"desc": "Visuale ala destra",
		"icon": "▶"
	},
	{
		"id": "top",
		"name": "Superiore",
		"code": "CAM 05 [DORSALE]",
		"direction": "Dorsale (+Y)",
		"desc": "Visuale superiore / Zenit",
		"icon": "▲"
	},
	{
		"id": "bottom",
		"name": "Inferiore",
		"code": "CAM 06 [VENTRALE]",
		"direction": "Ventrale (-Y)",
		"desc": "Visuale inferiore / Nadir",
		"icon": "▼"
	}
]

const DUCT_ROOMS: Array[Dictionary] = [
	{
		"id": "bridge",
		"name": "Ponte di Comando",
		"rect": Rect2(230, 45, 140, 70),
		"color": Color(0.12, 0.28, 0.45, 0.55),
		"border_color": Color(0.35, 0.75, 1.0, 0.8)
	},
	{
		"id": "sensors",
		"name": "Sensori & Avionica",
		"rect": Rect2(110, 115, 100, 65),
		"color": Color(0.12, 0.35, 0.3, 0.5),
		"border_color": Color(0.2, 0.85, 0.65, 0.8)
	},
	{
		"id": "comms",
		"name": "Comunicazioni & EW",
		"rect": Rect2(390, 115, 100, 65),
		"color": Color(0.12, 0.35, 0.3, 0.5),
		"border_color": Color(0.2, 0.85, 0.65, 0.8)
	},
	{
		"id": "armory",
		"name": "Armeria & Sicurezza",
		"rect": Rect2(245, 135, 110, 60),
		"color": Color(0.35, 0.15, 0.2, 0.5),
		"border_color": Color(0.9, 0.35, 0.4, 0.8)
	},
	{
		"id": "quarters",
		"name": "Alloggi Equipaggio",
		"rect": Rect2(100, 200, 120, 75),
		"color": Color(0.22, 0.22, 0.35, 0.5),
		"border_color": Color(0.55, 0.55, 0.85, 0.8)
	},
	{
		"id": "cargo",
		"name": "Baia di Carico Principale",
		"rect": Rect2(380, 200, 120, 75),
		"color": Color(0.35, 0.28, 0.12, 0.5),
		"border_color": Color(0.95, 0.75, 0.25, 0.8)
	},
	{
		"id": "reactor",
		"name": "Nucleo Reattore & Fusione",
		"rect": Rect2(235, 215, 130, 80),
		"color": Color(0.35, 0.12, 0.35, 0.55),
		"border_color": Color(0.95, 0.35, 0.95, 0.9)
	},
	{
		"id": "engine",
		"name": "Sala Motori Principale",
		"rect": Rect2(185, 315, 230, 85),
		"color": Color(0.4, 0.2, 0.1, 0.55),
		"border_color": Color(1.0, 0.5, 0.2, 0.85)
	},
	{
		"id": "rcs_left",
		"name": "Pod RCS Sinistro",
		"rect": Rect2(30, 230, 50, 60),
		"color": Color(0.18, 0.25, 0.32, 0.5),
		"border_color": Color(0.4, 0.65, 0.85, 0.7)
	},
	{
		"id": "rcs_right",
		"name": "Pod RCS Destro",
		"rect": Rect2(520, 230, 50, 60),
		"color": Color(0.18, 0.25, 0.32, 0.5),
		"border_color": Color(0.4, 0.65, 0.85, 0.7)
	}
]

static func get_room_ids() -> Array:
	return ROOMS.keys()

static func get_room_data(id: String) -> Dictionary:
	return ROOMS.get(id, {})

static func get_room_name(id: String) -> String:
	return ROOMS.get(id, {}).get("name")
