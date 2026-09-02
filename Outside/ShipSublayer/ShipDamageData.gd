@tool
class_name ShipDamageData
extends Resource

@export var id: String = ""
@export var type: String = ""
@export var name: String = ""
@export var pos: Vector2 = Vector2.ZERO
@export var sector: String = ""
@export var severity: float = 0.0
@export var repair_cost: float = 0.0
@export var desc: String = ""
@export var system_impact: String = ""

func _init(p_id: String = "", p_name: String = "", p_pos: Vector2 = Vector2.ZERO) -> void:
	id = p_id
	name = p_name
	pos = p_pos

func to_dict() -> Dictionary:
	return {
		"id": id,
		"type": type,
		"name": name,
		"pos": [pos.x, pos.y],
		"sector": sector,
		"severity": severity,
		"repair_cost": repair_cost,
		"desc": desc,
		"system_impact": system_impact
	}

func from_dict(data: Dictionary) -> void:
	id = data.get("id", id)
	type = data.get("type", type)
	name = data.get("name", name)
	if data.has("pos"):
		var p = data["pos"]
		if p is Array and p.size() == 2:
			pos = Vector2(p[0], p[1])
		elif p is Vector2:
			pos = p
	sector = data.get("sector", sector)
	severity = float(data.get("severity", severity))
	repair_cost = float(data.get("repair_cost", repair_cost))
	desc = data.get("desc", desc)
	system_impact = data.get("system_impact", system_impact)
