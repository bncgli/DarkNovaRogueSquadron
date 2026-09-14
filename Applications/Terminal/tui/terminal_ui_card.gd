extends TerminalUIWidget
class_name TerminalUICard
## Boxed card with diegetic frame, title bar, and flexible content body.

@export var card_title: String = "":
	set(val):
		card_title = val
		_update_card()

@export_multiline var body_text: String = "":
	set(val):
		body_text = val
		_update_card()

var _panel: PanelContainer = null
var _title_label: Label = null
var _body_label: Label = null
var _content_box: VBoxContainer = null


func _setup_widget() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_panel = PanelContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG_DARK
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	
	_content_box = VBoxContainer.new()
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_box.add_theme_constant_override("separation", 6)
	_panel.add_child(_content_box)
	
	_title_label = Label.new()
	_title_label.add_theme_font_override("font", FONT_INCONSOLATA)
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", COLOR_CYAN)
	_content_box.add_child(_title_label)
	
	_body_label = Label.new()
	_body_label.add_theme_font_override("font", FONT_INCONSOLATA)
	_body_label.add_theme_font_size_override("font_size", 16)
	_body_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_box.add_child(_body_label)
	
	_update_card()


func _update_card() -> void:
	if _title_label == null:
		return
	if card_title.is_empty():
		_title_label.visible = false
	else:
		_title_label.visible = true
		_title_label.text = "[ %s ]" % card_title
	
	if body_text.is_empty():
		_body_label.visible = false
	else:
		_body_label.visible = true
		_body_label.text = body_text


## Adds a custom interactive widget into the card body.
func add_body_widget(widget: Control) -> void:
	if _content_box != null:
		_content_box.add_child(widget)
