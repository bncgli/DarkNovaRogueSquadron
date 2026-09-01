extends PanelContainer

signal power_toggled(room_id, is_on)

@onready var room_name_label: Label = %RoomNameLabel
@onready var power_status_label: Label = %PowerStatusLabel
@onready var power_switch: CheckButton = %PowerSwitch
@onready var power_bar: ProgressBar = %PowerBar
@onready var category_label: Label = %CategoryLabel

var room_id: String = ""
var current_power: float = 0.0

func setup(data: Dictionary) -> void:
	room_id = data.get("id", "")
	room_name_label.text = data.get("name", room_id)
	category_label.text = data.get("category", "General").to_upper()
	
	var is_on = data.get("is_on", true)
	power_switch.button_pressed = is_on
	_update_visuals(is_on)
	
	update_power(data.get("power_mw", 0.0))

func update_power(power_mw: float) -> void:
	current_power = power_mw
	power_status_label.text = "%.1f MW" % power_mw
	
	if power_mw > 0:
		power_status_label.modulate = Color(0.4, 1.0, 0.6) # Generator
	elif power_mw < 0:
		power_status_label.modulate = Color(1.0, 0.6, 0.4) # Consumer
	else:
		power_status_label.modulate = Color(0.7, 0.7, 0.7)
	
	# Visual representation of load if needed
	power_bar.value = abs(power_mw)

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
