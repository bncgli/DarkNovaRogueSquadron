@tool
class_name ShipDuctData
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var from: Vector2 = Vector2()
@export var to: Vector2 = Vector2()
@export var width: float = 10.0
@export var is_blocked: bool = false

func _init(p_id: String = "", p_name: String = "", p_from: Vector2 = Vector2(), p_to: Vector2 = Vector2()) -> void:
	id = p_id
	name = p_name
	from = p_from
	to = p_to

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"from": [from.x, from.y],
		"to": [to.x, to.y],
		"width": width,
		"is_blocked": is_blocked
	}

func from_dict(data: Dictionary) -> void:
	id = data.get("id")
	name = data.get("name")
	
	if data.has("from"):
		if data["from"] is Array and data["from"].size() == 2:
			from = Vector2(data["from"][0], data["from"][1])
		elif data["from"] is Vector2:
			from = data["from"]
			
	if data.has("to"):
		if data["to"] is Array and data["to"].size() == 2:
			to = Vector2(data["to"][0], data["to"][1])
		elif data["to"] is Vector2:
			to = data["to"]
			
	width = data.get("width")
	is_blocked = data.get("is_blocked")
