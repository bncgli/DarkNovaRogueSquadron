class_name RoomPowerEntry
extends PanelContainer

signal power_toggled(room_id, is_on)
signal room_selected(room_id)

@onready var room_name_label: Label = %RoomNameLabel
@onready var power_status_label: Label = %PowerStatusLabel
@onready var power_switch: CheckButton = %PowerSwitch
@onready var power_bar: ProgressBar = %PowerBar
@onready var category_label: Label = %CategoryLabel

var room_id: String = ""
var current_power: float = 0.0
var is_selected: bool = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		room_selected.emit(room_id)

func setup(data: Dictionary) -> void:
	room_id = str(data.get("id", ""))
	if room_name_label:
		room_name_label.text = str(data.get("name", "Stanza"))
	if category_label:
		category_label.text = str(data.get("category", "")).to_upper()
	
	var is_on: bool = bool(data.get("is_on", false))
	if power_switch:
		power_switch.button_pressed = is_on
	_update_visuals(is_on)
	
	update_power(float(data.get("power_mw", 0.0)))

func update_power(power_mw: float) -> void:
	current_power = power_mw
	if power_status_label:
		power_status_label.text = "%.1f MW" % power_mw
		if power_mw > 0.0:
			power_status_label.modulate = Color(0.2, 1.0, 0.4, 1.0) # Generator (#33ff66)
		elif power_mw < 0.0:
			power_status_label.modulate = Color(1.0, 0.25, 0.25, 1.0) # Consumer (#ff4040)
		else:
			power_status_label.modulate = Color(0.65, 0.65, 0.65, 1.0) # Neutral / Standby
	
	if power_bar:
		power_bar.value = abs(power_mw)
		if power_mw > 0.0:
			power_bar.modulate = Color(0.2, 1.0, 0.4, 1.0)
		elif power_mw < 0.0:
			power_bar.modulate = Color(1.0, 0.25, 0.25, 1.0)
		else:
			power_bar.modulate = Color(0.65, 0.65, 0.65, 1.0)

func set_selected_visual(selected_flag: bool) -> void:
	is_selected = selected_flag
	var sb := get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		var new_sb := sb.duplicate() as StyleBoxFlat
		new_sb.border_color = Color(0.35, 0.85, 1.0, 0.9) if selected_flag else Color(0.2, 0.5, 0.8, 0.6)
		new_sb.border_width_left = 3 if selected_flag else 2
		new_sb.border_width_top = 1 if selected_flag else 0
		new_sb.border_width_right = 1 if selected_flag else 0
		new_sb.border_width_bottom = 1 if selected_flag else 0
		add_theme_stylebox_override("panel", new_sb)

func _on_power_switch_toggled(toggled_on: bool) -> void:
	_update_visuals(toggled_on)
	power_toggled.emit(room_id, toggled_on)

func _update_visuals(is_on: bool) -> void:
	if is_on:
		modulate = Color(1, 1, 1, 1)
	else:
		modulate = Color(0.5, 0.5, 0.5, 0.8)

func set_enabled(can_control: bool) -> void:
	power_switch.disabled = not can_control
