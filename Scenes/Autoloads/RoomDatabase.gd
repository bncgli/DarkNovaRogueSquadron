@tool
class_name RoomDatabaseSingleton
extends Node

## Database delle stanze standard per l'editor delle navi.
## Contiene definizioni di dimensioni minime e dispositivi predefiniti.

static var ROOMS: Dictionary[String, ShipRoomData] = {
	"ponte_comando": _create_room("ponte_comando", "Ponte di comando", Vector2(30, 30), ["helm_control", "nav_computer"], Color(0.2, 0.4, 0.6, 0.5)),
	"supporto_vitale_min": _create_room("supporto_vitale_min", "Supporto vitale minimale", Vector2(60, 60), ["scrubber", "heater"], Color(0.2, 0.6, 0.2, 0.5)),
	"supporto_vitale_adv": _create_room("supporto_vitale_adv", "Supporto vitale avanzato", Vector2(100, 100), ["scrubber", "heater", "serra_idroponica"], Color(0.1, 0.7, 0.1, 0.5)),
	"mainframe": _create_room("mainframe", "Mainframe", Vector2(30, 30), ["server_rack"], Color(0.4, 0.2, 0.6, 0.5)),
	"comunicazioni": _create_room("comunicazioni", "Sistemi di comunicazione", Vector2(60, 60), ["antenna_array"], Color(0.6, 0.4, 0.2, 0.5)),
	"reattore_fusione": _create_room("reattore_fusione", "Reattore a fusione", Vector2(200, 200), ["core_reactor", "battery_01"], Color(0.8, 0.2, 0.2, 0.5)),
	"baia_carico": _create_room("baia_carico", "Baia di carico", Vector2(150, 150), ["cargo_handling", "recharge_dock"], Color(0.5, 0.5, 0.5, 0.5)),
	"sala_motori": _create_room("sala_motori", "Sala motori", Vector2(100, 100), ["engine_main", "cooling_01"], Color(0.7, 0.3, 0.1, 0.5)),
	"pod_drone": _create_room("pod_drone", "Pod drone di servizio", Vector2(60, 60), ["dronestation"], Color(0.3, 0.3, 0.6, 0.5)),
	"matrice_sensori": _create_room("matrice_sensori", "Matrice sensori", Vector2(60, 60), ["sensors_matrix"], Color(0.2, 0.5, 0.5, 0.5)),
	"armatura_adattiva": _create_room("armatura_adattiva", "Armatura adattiva", Vector2(30, 30), ["arm_sx_balancer", "arm_dx_balancer"], Color(0.4, 0.4, 0.4, 0.5)),
	"armamenti": _create_room("armamenti", "Armamenti", Vector2(80, 80), ["armory_defense"], Color(0.9, 0.1, 0.1, 0.5))
}

## Definizione dei 21 dispositivi canonici (sincronizzata con ShipDeviceData)
static var CANONICAL_DEVICES: Dictionary = ShipDeviceData.CANONICAL_DEVICES

static func _create_room(p_id: String, p_name: String, p_min_size: Vector2, p_default_devices: Array[String], p_color: Color) -> ShipRoomData:
	var r := ShipRoomData.new(p_id, p_name)
	r.min_size = p_min_size
	r.default_devices = p_default_devices
	r.color = p_color
	return r


static var CAMERAS_METADATA: Array[CameraMetadata] = [
	CameraMetadata.new("front", "Frontale", "CAM 01 [PRUA]", "Prua (-Z)", "Visuale di navigazione anteriore", "▲"),
	CameraMetadata.new("rear", "Posteriore", "CAM 02 [POPPA]", "Poppa (+Z)", "Visuale posteriore propulsori", "▼"),
	CameraMetadata.new("left", "Laterale Sinistra", "CAM 03 [BABORDO]", "Babordo (-X)", "Visuale ala sinistra", "◀"),
	CameraMetadata.new("right", "Laterale Destra", "CAM 04 [TRIBORDO]", "Tribordo (+X)", "Visuale ala destra", "▶"),
	CameraMetadata.new("top", "Superiore", "CAM 05 [DORSALE]", "Dorsale (+Y)", "Visuale superiore / Zenit", "▲"),
	CameraMetadata.new("bottom", "Inferiore", "CAM 06 [VENTRALE]", "Ventrale (-Y)", "Visuale inferiore / Nadir", "▼")
]

static func get_room_ids() -> Array:
	return ROOMS.keys()

static func get_room_data(id: String) -> ShipRoomData:
	return ROOMS.get(id)

static func get_room_name(id: String) -> String:
	var room: Variant = ROOMS.get(id)
	return room.name if room else ""
