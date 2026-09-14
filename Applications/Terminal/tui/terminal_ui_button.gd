extends TerminalUIWidget
class_name TerminalUIButton
## Interactive diegetic terminal button with mouse hover and click dispatch.

signal clicked(button: TerminalUIButton)

@export var label_text: String = "Action":
	set(val):
		label_text = val
		_update_label()

@export var command_to_execute: String = ""
var custom_data: Variant = null

var _label: Label = null


func _setup_widget() -> void:
	custom_minimum_size = Vector2(0, 24)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	
	_label = Label.new()
	_label.add_theme_font_override("font", FONT_INCONSOLATA)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", COLOR_MATRIX_GREEN)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_update_label()


func _update_label() -> void:
	if _label == null:
		return
	if is_hovered:
		_label.add_theme_color_override("font_color", COLOR_CYAN)
		_label.text = ">[ %s ]<" % label_text
	else:
		_label.add_theme_color_override("font_color", COLOR_MATRIX_GREEN)
		_label.text = "[ %s ]" % label_text


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		_trigger_click()
		accept_event()


func _trigger_click() -> void:
	clicked.emit(self)
	if not command_to_execute.is_empty():
		var term: Node = get_terminal()
		if term != null and term.has_method("execute_command"):
			term.execute_command(command_to_execute)


func _on_hover_changed(_hovered: bool) -> void:
	_update_label()
