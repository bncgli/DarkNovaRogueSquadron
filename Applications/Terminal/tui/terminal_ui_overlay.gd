extends TerminalUIWidget
class_name TerminalUIOverlay
## Full-screen modal TUI view container inside the terminal.

signal closed()

var overlay_title: String = "TUI Overlay":
	set(val):
		overlay_title = val
		if _title_label != null:
			_title_label.text = "=== [ %s ] ===" % overlay_title

var _panel: PanelContainer = null
var _title_label: Label = null
var _close_btn: TerminalUIButton = null
var _body_container: VBoxContainer = null


func _setup_widget() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	_panel = PanelContainer.new()
	_panel.anchors_preset = Control.PRESET_FULL_RECT
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.03, 0.01, 0.96)
	style.border_color = COLOR_CYAN
	style.set_border_width_all(2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(main_vbox)
	
	# Header
	var header_hbox := HBoxContainer.new()
	header_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(header_hbox)
	
	_title_label = Label.new()
	_title_label.add_theme_font_override("font", FONT_INCONSOLATA)
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", COLOR_CYAN)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.text = "=== [ %s ] ===" % overlay_title
	header_hbox.add_child(_title_label)
	
	_close_btn = TerminalUIButton.new()
	_close_btn.label_text = "X"
	_close_btn.clicked.connect(func(_b: TerminalUIButton) -> void:
		close()
	)
	header_hbox.add_child(_close_btn)
	
	# Scrollable body
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)
	
	_body_container = VBoxContainer.new()
	_body_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_body_container)


func add_content(widget: Control) -> void:
	if _body_container != null:
		_body_container.add_child(widget)


func get_body_container() -> VBoxContainer:
	return _body_container


func close() -> void:
	closed.emit()
	var term: Node = get_terminal()
	if term != null and term.has_method("close_tui_overlay"):
		term.close_tui_overlay()
	else:
		queue_free()
