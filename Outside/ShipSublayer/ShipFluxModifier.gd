@tool
class_name ShipFluxModifier
extends Resource

@export var value: int = 0
@export var owner: String = ""
@export var reason: String = ""

func _init(p_val: int = 0, p_owner: String = "", p_reason: String = "") -> void:
	value = p_val
	owner = p_owner
	reason = p_reason

func to_dict() -> Dictionary:
	return {
		"value": value,
		"owner": owner,
		"reason": reason
	}

func from_dict(data: Dictionary) -> void:
	value = int(data.get("value", value))
	owner = data.get("owner", owner)
	reason = data.get("reason", reason)
