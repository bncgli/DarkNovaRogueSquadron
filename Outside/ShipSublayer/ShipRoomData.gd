@tool
class_name ShipRoomData
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var rect: Rect2 = Rect2()
@export var color: Color = Color(1, 1, 1, 0.5)
@export var border_color: Color = Color(1, 1, 1, 0.8)
@export var category: String = "command"
@export var devices: Array = []:
	set(val):
		devices = _ensure_objects(val, ShipDeviceData)

func _ensure_objects(list: Array, type: GDScript) -> Array:
	var new_list := []
	for item in list:
		if item is Dictionary:
			var obj = type.new()
			if obj.has_method("from_dict"):
				obj.from_dict(item)
			new_list.append(obj)
		else:
			new_list.append(item)
	return new_list
@export var default_devices: Array[String] = []
@export var min_size: Vector2 = Vector2.ZERO
@export var power_mw: float = 0.0
@export var is_on: bool = true

func _init(p_id: String = "", p_name: String = "", p_rect: Rect2 = Rect2()) -> void:
	id = p_id
	name = p_name
	rect = p_rect

func to_dict() -> Dictionary:
	var devs_copy: Array = []
	for d in devices:
		devs_copy.append(d.to_dict())
		
	return {
		"id": id,
		"name": name,
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"color": [color.r, color.g, color.b, color.a],
		"border_color": [border_color.r, border_color.g, border_color.b, border_color.a],
		"category": category,
		"devices": devs_copy,
		"default_devices": default_devices.duplicate(),
		"min_size": [min_size.x, min_size.y],
		"power_mw": power_mw,
		"is_on": is_on
	}

func from_dict(data: Dictionary) -> void:
	id = str(data.get("id", id))
	name = str(data.get("name", name))
	
	if data.has("rect"):
		var r_data: Variant = data["rect"]
		if r_data is Array and r_data.size() == 4:
			rect = Rect2(float(r_data[0]), float(r_data[1]), float(r_data[2]), float(r_data[3]))
		elif r_data is Rect2:
			rect = r_data
			
	if data.has("color"):
		var c: Variant = data["color"]
		if c is Array and c.size() >= 3:
			var a := float(c[3]) if c.size() > 3 else 1.0
			color = Color(float(c[0]), float(c[1]), float(c[2]), a)
		elif c is Color:
			color = c

	if data.has("border_color"):
		var bc: Variant = data["border_color"]
		if bc is Array and bc.size() >= 3:
			var a := float(bc[3]) if bc.size() > 3 else 1.0
			border_color = Color(float(bc[0]), float(bc[1]), float(bc[2]), a)
		elif bc is Color:
			border_color = bc
			
	category = data.get("category", category)
			
	if data.has("devices") and data["devices"] is Array:
		devices = data["devices"]
				
	if data.has("default_devices") and data["default_devices"] is Array:
		default_devices.clear()
		for d in data["default_devices"]:
			default_devices.append(str(d))
			
	if data.has("min_size"):
		var ms: Variant = data["min_size"]
		if ms is Array and ms.size() == 2:
			min_size = Vector2(float(ms[0]), float(ms[1]))
		elif ms is Vector2:
			min_size = ms
		
	power_mw = float(data.get("power_mw", power_mw))
	is_on = bool(data.get("is_on", is_on))
