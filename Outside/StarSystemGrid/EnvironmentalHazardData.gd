@tool
class_name EnvironmentalHazardData
extends Resource

@export var id: String = ""
@export var type: String = "RAD" # RAD, EMP, HEAT, COLD, DUST
@export var severity: float = 0.5 # 0.0 - 1.0
@export var radius: float = 100.0
@export var description: String = ""

func _init(p_id: String = "", p_type: String = "RAD", p_sev: float = 0.5) -> void:
	id = p_id
	type = p_type
	severity = p_sev

func to_dict() -> Dictionary:
	return {
		"id": id,
		"type": type,
		"severity": severity,
		"radius": radius,
		"description": description
	}

func from_dict(data: Dictionary) -> void:
	id = data.get("id", id)
	type = data.get("type", type)
	severity = float(data.get("severity", severity))
	radius = float(data.get("radius", radius))
	description = data.get("description", description)
