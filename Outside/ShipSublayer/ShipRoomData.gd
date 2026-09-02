@tool
class_name ShipRoomData
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var rect: Rect2 = Rect2()
@export var color: Color = Color(1, 1, 1, 0.5)
@export var border_color: Color = Color(1, 1, 1, 0.8)
@export var category: String = "command"
@export var devices: Array[Dictionary] = []
@export var power_mw: float = 0.0
@export var is_on: bool = true

func _init(p_id: String = "", p_name: String = "", p_rect: Rect2 = Rect2()) -> void:
	id = p_id
	name = p_name
	rect = p_rect

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"color": [color.r, color.g, color.b, color.a],
		"border_color": [border_color.r, border_color.g, border_color.b, border_color.a],
		"category": category,
		"devices": devices.duplicate(true),
		"power_mw": power_mw,
		"is_on": is_on
	}

func from_dict(data: Dictionary) -> void:
	id = data.get("id")
	name = data.get("name")
	
	if data.has("rect"):
		if data["rect"] is Array and data["rect"].size() == 4:
			var r = data["rect"]
			rect = Rect2(r[0], r[1], r[2], r[3])
		elif data["rect"] is Rect2:
			rect = data["rect"]
			
	if data.has("color"):
		if data["color"] is Array and data["color"].size() >= 3:
			var c = data["color"]
			var a = c[3] if c.size() > 3 else 1.0
			color = Color(c[0], c[1], c[2], a)
		elif data["color"] is Color:
			color = data["color"]

	if data.has("border_color"):
		if data["border_color"] is Array and data["border_color"].size() >= 3:
			var c = data["border_color"]
			var a = c[3] if c.size() > 3 else 1.0
			border_color = Color(c[0], c[1], c[2], a)
		elif data["border_color"] is Color:
			border_color = data["border_color"]
			
	category = data.get("category")
			
	if data.has("devices") and data["devices"] is Array:
		devices.clear()
		for d in data["devices"]:
			if d is Dictionary:
				devices.append(d.duplicate(true))
			else:
				devices.append(d)
		
	power_mw = data.get("power_mw")
	is_on = data.get("is_on")
