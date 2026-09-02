@tool
class_name ShipDriveFile
extends Resource

@export var path: String = ""
@export var content: String = ""
@export var is_protected: bool = false
@export var desc: String = ""

func _init(p_path: String = "", p_content: String = "", p_protected: bool = false, p_desc: String = "") -> void:
	path = p_path
	content = p_content
	is_protected = p_protected
	desc = p_desc

func to_dict() -> Dictionary:
	return {
		"path": path,
		"content": content,
		"is_protected": is_protected,
		"desc": desc
	}

func from_dict(data: Dictionary) -> void:
	path = data.get("path", path)
	content = data.get("content", content)
	is_protected = data.get("is_protected", is_protected)
	desc = data.get("desc", desc)
