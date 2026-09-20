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
@export var component_class: String = ""
@export var custom_properties: Dictionary = {}

## Se power_mw è positivo, il dispositivo è un generatore.
var is_generator: bool:
	get:
		return power_mw > 0.0

func _init(p_id: String = "", p_name: String = "", p_pos: Vector2 = Vector2.ZERO) -> void:
	id = p_id
	name = p_name
	pos = p_pos

func get_or_detect_component_class() -> String:
	if not component_class.is_empty():
		return component_class
	var lower_id := id.to_lower()
	var lower_name := name.to_lower()
	var lower_cat := category.to_lower()
	
	if lower_cat == "propulsion" or lower_id.contains("engine") or lower_id.contains("thruster") or lower_name.contains("motore") or lower_name.contains("propuls"):
		return "ThrusterComponent"
	elif (lower_cat == "engineering" or is_generator) and (lower_id.contains("reactor") or lower_id.contains("reattore") or lower_name.contains("reattore")):
		return "ReactorComponent"
	elif lower_id.contains("battery") or lower_id.contains("batteria") or lower_name.contains("batteria"):
		return "BatteryComponent"
	elif lower_cat == "life_support" or lower_id.contains("life_support") or lower_id.contains("o2") or lower_id.contains("co2") or lower_id.contains("purificatore") or lower_name.contains("ossigeno") or lower_name.contains("caldaia"):
		return "LifeSupportComponent"
	elif lower_id.contains("cooling") or lower_id.contains("radiator") or lower_name.contains("raffreddamento"):
		return "CoolingComponent"
	return "ShipPhysicalComponent"

func create_physical_component(room_id: String = "") -> ShipPhysicalComponent:
	var c_class := get_or_detect_component_class()
	var comp: ShipPhysicalComponent = null
	match c_class:
		"ReactorComponent":
			comp = ReactorComponent.new(id, room_id, category)
			if power_mw > 0.0:
				comp.power_output_nominal = power_mw
		"BatteryComponent":
			comp = BatteryComponent.new(id, room_id, category)
		"ThrusterComponent":
			comp = ThrusterComponent.new(id, room_id, category)
			if power_mw < 0.0:
				comp.power_draw_nominal = absf(power_mw)
		"LifeSupportComponent":
			comp = LifeSupportComponent.new(id, room_id, category)
			if power_mw < 0.0:
				comp.power_draw_nominal = absf(power_mw)
		"CoolingComponent":
			comp = CoolingComponent.new(id, room_id, category)
			if power_mw < 0.0:
				comp.power_draw_nominal = absf(power_mw)
		_:
			comp = ShipPhysicalComponent.new(id, room_id, category)
			if power_mw < 0.0:
				comp.power_draw_nominal = absf(power_mw)
	comp.component_name = name
	for prop in custom_properties:
		if prop in comp:
			comp.set(prop, custom_properties[prop])
	comp.initialize_registers()
	return comp

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"pos": [pos.x, pos.y],
		"power_mw": power_mw,
		"category": category,
		"sector": sector,
		"desc": desc,
		"component_class": component_class,
		"custom_properties": custom_properties
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
	component_class = data.get("component_class", "")
	custom_properties = data.get("custom_properties", {})
