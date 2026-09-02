@tool
class_name CameraMetadata
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var code: String = ""
@export var direction: String = ""
@export var desc: String = ""
@export var icon: String = ""

func _init(p_id: String = "", p_name: String = "", p_code: String = "", p_dir: String = "", p_desc: String = "", p_icon: String = "") -> void:
	id = p_id
	name = p_name
	code = p_code
	direction = p_dir
	desc = p_desc
	icon = p_icon
