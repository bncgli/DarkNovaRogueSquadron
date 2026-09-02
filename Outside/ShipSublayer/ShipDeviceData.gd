@tool
class_name ShipDeviceData
extends Resource

## Rappresenta un dispositivo all'interno di una stanza della nave (generatore, utility, ecc.)

@export var id: String = ""
@export var name: String = ""
@export var pos: Vector2 = Vector2.ZERO
@export var power_mw: float = 0.0
@export var category: String = "utility"
@export var sector: String = ""
@export var desc: String = ""

## Se power_mw è positivo, il dispositivo è un generatore.
var is_generator: bool:
	get:
		return power_mw > 0.0

func _init(p_id: String = "", p_name: String = "", p_pos: Vector2 = Vector2.ZERO) -> void:
	id = p_id
	name = p_name
	pos = p_pos

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"pos": [pos.x, pos.y],
		"power_mw": power_mw,
		"category": category,
		"sector": sector,
		"desc": desc
	}

func from_dict(data: Dictionary) -> void:
	id = data.get("id", "")
	name = data.get("name", "")
	
	if data.has("pos"):
		if data["pos"] is Array and data["pos"].size() == 2:
			pos = Vector2(float(data["pos"][0]), float(data["pos"][1]))
		elif data["pos"] is Vector2:
			pos = data["pos"]
			
	power_mw = float(data.get("power_mw", 0.0))
	category = data.get("category", "utility")
	sector = data.get("sector", "")
	desc = data.get("desc", "")
