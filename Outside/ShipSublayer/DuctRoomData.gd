@tool
class_name DuctRoomData
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var rect: Rect2 = Rect2()
@export var color: Color = Color.WHITE
@export var border_color: Color = Color.WHITE

func _init(p_id: String = "", p_name: String = "", p_rect: Rect2 = Rect2(), p_color: Color = Color.WHITE, p_border: Color = Color.WHITE) -> void:
	id = p_id
	name = p_name
	rect = p_rect
	color = p_color
	border_color = p_border
