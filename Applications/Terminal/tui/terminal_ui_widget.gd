extends Control
class_name TerminalUIWidget
## Base class for Terminal UI (TUI) widgets in GodotOS.
## Provides retro sci-fi styling, matrix green & cyan palettes, and hover/focus tracking.

const FONT_INCONSOLATA: Font = preload("res://Applications/Terminal/Inconsolata-Regular.ttf")

const COLOR_MATRIX_GREEN: Color = Color("39ff14")
const COLOR_CYAN: Color = Color("00e5ff")
const COLOR_TEXT_DIM: Color = Color(0.75, 0.9, 0.75, 1.0)
const COLOR_BG_DARK: Color = Color(0.02, 0.05, 0.02, 0.95)
const COLOR_BORDER: Color = Color(0.22, 0.6, 0.22, 0.8)
const COLOR_HOVER_BG: Color = Color(0.08, 0.18, 0.08, 0.95)

var terminal_ref: Node = null
var is_hovered: bool = false
var is_focused: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_widget()


func _setup_widget() -> void:
	pass


## Resolves and returns the parent Terminal instance.
func get_terminal() -> Node:
	if terminal_ref != null:
		return terminal_ref
	var curr: Node = get_parent()
	while curr != null:
		if curr is Terminal:
			terminal_ref = curr
			return terminal_ref
		curr = curr.get_parent()
	return null


func set_hovered(hovered: bool) -> void:
	is_hovered = hovered
	_on_hover_changed(hovered)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		set_hovered(true)
	elif what == NOTIFICATION_MOUSE_EXIT:
		set_hovered(false)


func _on_hover_changed(_hovered: bool) -> void:
	queue_redraw()
