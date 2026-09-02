@tool
class_name ShipDamageRuntimeState
extends Resource

@export var id: String = ""
@export var type: String = ""
@export var pos: Vector2 = Vector2.ZERO
@export var sector: String = ""
@export var revealed: bool = false
@export var revealed_by: String = ""
@export var repair_progress: float = 0.0
@export var repair_duration: float = 5.0
@export var repaired: bool = false

func _init(p_id: String = "", p_type: String = "", p_pos: Vector2 = Vector2.ZERO) -> void:
	id = p_id
	type = p_type
	pos = p_pos

func to_dict() -> Dictionary:
	return {
		"id": id,
		"type": type,
		"pos": [pos.x, pos.y],
		"sector": sector,
		"revealed": revealed,
		"revealed_by": revealed_by,
		"repair_progress": repair_progress,
		"repair_duration": repair_duration,
		"repaired": repaired
	}

func from_dict(data: Dictionary) -> void:
	id = data.get("id", id)
	type = data.get("type", type)
	if data.has("pos"):
		var p = data["pos"]
		if p is Array and p.size() == 2:
			pos = Vector2(p[0], p[1])
		elif p is Vector2:
			pos = p
	sector = data.get("sector", sector)
	revealed = bool(data.get("revealed", revealed))
	revealed_by = data.get("revealed_by", revealed_by)
	repair_progress = float(data.get("repair_progress", repair_progress))
	repair_duration = float(data.get("repair_duration", repair_duration))
	repaired = bool(data.get("repaired", repaired))
