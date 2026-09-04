@tool
class_name ShipDamageData
extends Resource

const DAMAGE_TYPE_BREACH: String = "breach"
const DAMAGE_TYPE_SHORT_CIRCUIT: String = "short_circuit"
const DAMAGE_TYPE_FIRE: String = "fire"

@export var id: String = ""
@export var type: String = ""
@export var name: String = ""
@export var pos: Vector2 = Vector2.ZERO
@export var sector: String = ""
@export var severity: float = 0.0
@export var repair_cost: float = 0.0
@export var desc: String = ""
@export var system_impact: String = ""
@export var repaired: bool = false
@export var revealed: bool = false
@export var revealed_by: String = ""
@export var repair_progress: float = 0.0
@export var repair_duration: float = 5.0

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
		"system_impact": system_impact,
		"repaired": repaired,
		"revealed": revealed,
		"revealed_by": revealed_by,
		"repair_progress": repair_progress,
		"repair_duration": repair_duration
	}

func from_dict(data: Dictionary) -> void:
	id = str(data.get("id", id))
	type = str(data.get("type", type))
	name = str(data.get("name", name))
	if data.has("pos"):
		var p: Variant = data["pos"]
		if p is Array and p.size() == 2:
			pos = Vector2(float(p[0]), float(p[1]))
		elif p is Vector2:
			pos = p
	sector = str(data.get("sector", sector))
	severity = float(data.get("severity", severity))
	repair_cost = float(data.get("repair_cost", repair_cost))
	desc = str(data.get("desc", desc))
	system_impact = str(data.get("system_impact", system_impact))
	repaired = bool(data.get("repaired", repaired))
	revealed = bool(data.get("revealed", revealed))
	revealed_by = str(data.get("revealed_by", revealed_by))
	repair_progress = float(data.get("repair_progress", repair_progress))
	repair_duration = float(data.get("repair_duration", repair_duration))
