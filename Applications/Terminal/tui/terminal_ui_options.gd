extends TerminalUIWidget
class_name TerminalUIOptions
## Interactive options selector (Junie-style prompt options with mouse and keyboard support).

signal option_selected(index: int, option_data: Dictionary)
signal selection_confirmed(selected_indices: Array[int])

var title_text: String = ""
var allow_multiple: bool = false
var options: Array[Dictionary] = [] # {"title": String, "description": String, "command": String}
var selected_indices: Array[int] = []

var _container: VBoxContainer = null
var _row_controls: Array[Control] = []


func _setup_widget() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_container = VBoxContainer.new()
	_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_container.add_theme_constant_override("separation", 6)
	add_child(_container)
	_rebuild_ui()


## Sets the options list and rebuilds the interactive elements.
func set_options(in_options: Array[Dictionary], in_title: String = "", multi: bool = false) -> void:
	options = in_options
	title_text = in_title
	allow_multiple = multi
	selected_indices.clear()
	if _container != null:
		_rebuild_ui()


func _rebuild_ui() -> void:
	if _container == null:
		return
	for c in _container.get_children():
		c.queue_free()
	_row_controls.clear()
	
	if not title_text.is_empty():
		var title_label := Label.new()
		title_label.add_theme_font_override("font", FONT_INCONSOLATA)
		title_label.add_theme_font_size_override("font_size", 18)
		title_label.add_theme_color_override("font_color", COLOR_CYAN)
		title_label.text = "=== %s ===" % title_text
		_container.add_child(title_label)
	
	for idx in range(options.size()):
		var opt_data: Dictionary = options[idx]
		var opt_title: String = opt_data.get("title", "Option %d" % [idx + 1])
		var opt_desc: String = opt_data.get("description", "")
		
		var row := VBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		
		var title_lbl := Label.new()
		title_lbl.name = "TitleLabel"
		title_lbl.add_theme_font_override("font", FONT_INCONSOLATA)
		title_lbl.add_theme_font_size_override("font_size", 18)
		title_lbl.add_theme_color_override("font_color", COLOR_MATRIX_GREEN)
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var prefix: String = "[ %d ] " % [idx + 1]
		if allow_multiple:
			prefix = "[x] " if selected_indices.has(idx) else "[ ] "
		title_lbl.text = prefix + opt_title
		row.add_child(title_lbl)
		
		if not opt_desc.is_empty():
			var desc_lbl := Label.new()
			desc_lbl.name = "DescLabel"
			desc_lbl.add_theme_font_override("font", FONT_INCONSOLATA)
			desc_lbl.add_theme_font_size_override("font_size", 14)
			desc_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
			desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			desc_lbl.text = "      " + opt_desc
			row.add_child(desc_lbl)
		
		var captured_idx: int = idx
		row.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
				_on_option_clicked(captured_idx)
				row.accept_event()
		)
		
		row.mouse_entered.connect(func() -> void:
			title_lbl.add_theme_color_override("font_color", COLOR_CYAN)
		)
		row.mouse_exited.connect(func() -> void:
			if not selected_indices.has(captured_idx):
				title_lbl.add_theme_color_override("font_color", COLOR_MATRIX_GREEN)
		)
		
		_container.add_child(row)
		_row_controls.append(row)
	
	if allow_multiple:
		var confirm_btn := TerminalUIButton.new()
		confirm_btn.label_text = "Confirm Selection"
		confirm_btn.clicked.connect(func(_b: TerminalUIButton) -> void:
			selection_confirmed.emit(selected_indices)
		)
		_container.add_child(confirm_btn)


func _on_option_clicked(idx: int) -> void:
	if idx < 0 or idx >= options.size():
		return
	
	if allow_multiple:
		if selected_indices.has(idx):
			selected_indices.erase(idx)
		else:
			selected_indices.append(idx)
		_rebuild_ui()
	else:
		selected_indices = [idx]
		var opt_data: Dictionary = options[idx]
		option_selected.emit(idx, opt_data)
		var cmd: String = opt_data.get("command", "")
		if not cmd.is_empty():
			var term: Node = get_terminal()
			if term != null and term.has_method("execute_command"):
				term.execute_command(cmd)
