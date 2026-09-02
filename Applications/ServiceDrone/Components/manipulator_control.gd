class_name ManipulatorControl
extends VBoxContainer

## Widget di controllo per il braccio manipolatore multi-funzione e thruster del Service Drone.

signal tool_selected(tool_name: String)
signal tool_trigger_toggled(is_active: bool)
signal undock_requested()
signal auto_dock_requested()
signal lights_toggled()
signal boost_toggled()
signal thruster_command(move_vec: Vector3, rot_vec: Vector3)

@onready var btn_undock: Button = get_node_or_null("%BtnUndock")
@onready var btn_auto_dock: Button = get_node_or_null("%BtnAutoDock")
@onready var btn_welder: Button = get_node_or_null("%BtnWelder")
@onready var btn_laser: Button = get_node_or_null("%BtnLaser")
@onready var btn_magnet: Button = get_node_or_null("%BtnMagnet")
@onready var btn_activate_tool: Button = get_node_or_null("%BtnActivateTool")
@onready var btn_toggle_lights: Button = get_node_or_null("%BtnToggleLights")
@onready var btn_toggle_boost: Button = get_node_or_null("%BtnToggleBoost")

# Movimento manuale UI
@onready var btn_fwd: Button = get_node_or_null("%BtnFwd")
@onready var btn_back: Button = get_node_or_null("%BtnBack")
@onready var btn_left: Button = get_node_or_null("%BtnLeft")
@onready var btn_right: Button = get_node_or_null("%BtnRight")
@onready var btn_up: Button = get_node_or_null("%BtnUp")
@onready var btn_down: Button = get_node_or_null("%BtnDown")
@onready var btn_rot_left: Button = get_node_or_null("%BtnRotLeft")
@onready var btn_rot_right: Button = get_node_or_null("%BtnRotRight")
@onready var btn_stop_thrusters: Button = get_node_or_null("%BtnStopThrusters")

# Etichette di stato strumento e tuning
@onready var tool_info_label: Label = get_node_or_null("%ToolInfoLabel")
@onready var tool_progress_bar: ProgressBar = get_node_or_null("%ToolProgressBar")
@onready var cargo_info_label: Label = get_node_or_null("%CargoInfoLabel")

var current_tool: String = "welder"
var is_tool_active: bool = false
var is_boost_active: bool = false
var controls_enabled: bool = true

var active_tuning: Dictionary = {
	"repair_rate": 15.0,
	"cutting_laser_power": 25.0,
	"cargo_capacity_kg": 500.0,
	"magnet_range": 18.0
}

func _ready() -> void:
	_connect_buttons()
	_update_tool_selection_ui()
	_update_tuning_labels()

func _connect_buttons() -> void:
	if btn_undock and not btn_undock.pressed.is_connected(_on_undock_pressed):
		btn_undock.pressed.connect(_on_undock_pressed)
	if btn_auto_dock and not btn_auto_dock.pressed.is_connected(_on_auto_dock_pressed):
		btn_auto_dock.pressed.connect(_on_auto_dock_pressed)
	if btn_welder and not btn_welder.pressed.is_connected(_on_welder_pressed):
		btn_welder.pressed.connect(_on_welder_pressed)
	if btn_laser and not btn_laser.pressed.is_connected(_on_laser_pressed):
		btn_laser.pressed.connect(_on_laser_pressed)
	if btn_magnet and not btn_magnet.pressed.is_connected(_on_magnet_pressed):
		btn_magnet.pressed.connect(_on_magnet_pressed)
	if btn_activate_tool and not btn_activate_tool.pressed.is_connected(_on_activate_tool_pressed):
		btn_activate_tool.pressed.connect(_on_activate_tool_pressed)
	if btn_toggle_lights and not btn_toggle_lights.pressed.is_connected(_on_toggle_lights_pressed):
		btn_toggle_lights.pressed.connect(_on_toggle_lights_pressed)
	if btn_toggle_boost and not btn_toggle_boost.pressed.is_connected(_on_toggle_boost_pressed):
		btn_toggle_boost.pressed.connect(_on_toggle_boost_pressed)
		
	# Controlli direzionali
	if btn_fwd: btn_fwd.pressed.connect(func(): thruster_command.emit(Vector3(0, 0, -1), Vector3.ZERO))
	if btn_back: btn_back.pressed.connect(func(): thruster_command.emit(Vector3(0, 0, 1), Vector3.ZERO))
	if btn_left: btn_left.pressed.connect(func(): thruster_command.emit(Vector3(-1, 0, 0), Vector3.ZERO))
	if btn_right: btn_right.pressed.connect(func(): thruster_command.emit(Vector3(1, 0, 0), Vector3.ZERO))
	if btn_up: btn_up.pressed.connect(func(): thruster_command.emit(Vector3(0, 1, 0), Vector3.ZERO))
	if btn_down: btn_down.pressed.connect(func(): thruster_command.emit(Vector3(0, -1, 0), Vector3.ZERO))
	if btn_rot_left: btn_rot_left.pressed.connect(func(): thruster_command.emit(Vector3.ZERO, Vector3(0, 1, 0)))
	if btn_rot_right: btn_rot_right.pressed.connect(func(): thruster_command.emit(Vector3.ZERO, Vector3(0, -1, 0)))
	if btn_stop_thrusters: btn_stop_thrusters.pressed.connect(func(): thruster_command.emit(Vector3.ZERO, Vector3.ZERO))

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	var btns := [
		btn_undock, btn_auto_dock, btn_welder, btn_laser, btn_magnet,
		btn_activate_tool, btn_toggle_lights, btn_toggle_boost,
		btn_fwd, btn_back, btn_left, btn_right, btn_up, btn_down,
		btn_rot_left, btn_rot_right, btn_stop_thrusters
	]
	for b in btns:
		if b and is_instance_valid(b):
			b.disabled = not enabled

func update_tuning(tuning: Dictionary) -> void:
	for k in tuning:
		active_tuning[k] = tuning[k]
	_update_tuning_labels()

func _update_tuning_labels() -> void:
	if not tool_info_label:
		return
	
	match current_tool:
		"welder":
			var rate := float(active_tuning.get("repair_rate"))
			tool_info_label.text = "SALDATRICE: Tasso %.1f%%/s | Target: Falle Scafo (dmg_breach)" % rate
		"laser":
			var pwr := float(active_tuning.get("cutting_laser_power"))
			tool_info_label.text = "LASER TAGLIO: Potenza %.1f MW | Target: Relitti & Sabotaggio" % pwr
		"magnet":
			var rng := float(active_tuning.get("magnet_range"))
			var cap := float(active_tuning.get("cargo_capacity_kg"))
			tool_info_label.text = "HARPOON: Raggio %.1fm | Capacità Max: %.0f kg" % [rng, cap]

func update_telemetry(t: Dictionary) -> void:
	var is_docked: bool = t.get("is_docked")
	var is_auto_dock: bool = t.get("is_auto_docking")
	
	if btn_undock:
		btn_undock.text = "🚀 DECOLLO" if is_docked else "IN VOLO"
		btn_undock.disabled = not controls_enabled or not is_docked
	
	if btn_auto_dock:
		btn_auto_dock.text = "⚓ IN RIENTRO..." if is_auto_dock else "⚓ AUTO-DOCK"
		btn_auto_dock.disabled = not controls_enabled or is_docked
	
	is_tool_active = bool(t.get("is_tool_active"))
	if btn_activate_tool:
		if is_tool_active:
			btn_activate_tool.text = "⏹ DISATTIVA STRUMENTO"
			btn_activate_tool.modulate = Color(1.0, 0.4, 0.4)
		else:
			btn_activate_tool.text = "▶ ATTIVA STRUMENTO"
			btn_activate_tool.modulate = Color(0.3, 0.9, 0.5)
	
	if tool_progress_bar:
		var p := float(t.get("repair_progress")) * 100.0
		tool_progress_bar.value = p
		tool_progress_bar.visible = is_tool_active or p > 0.0
	
	if cargo_info_label:
		var count: int = int(t.get("cargo_count"))
		var w: float = float(t.get("cargo_weight"))
		var max_w: float = float(t.get("max_cargo_weight"))
		cargo_info_label.text = "STIVA CARGO: %d slot | %.1f / %.0f kg (%.0f%%)" % [count, w, max_w, (w / maxf(max_w, 1.0)) * 100.0]

func _on_undock_pressed() -> void:
	if not controls_enabled: return
	undock_requested.emit()

func _on_auto_dock_pressed() -> void:
	if not controls_enabled: return
	auto_dock_requested.emit()

func _on_welder_pressed() -> void:
	if not controls_enabled: return
	current_tool = "welder"
	_update_tool_selection_ui()
	tool_selected.emit("welder")

func _on_laser_pressed() -> void:
	if not controls_enabled: return
	current_tool = "laser"
	_update_tool_selection_ui()
	tool_selected.emit("laser")

func _on_magnet_pressed() -> void:
	if not controls_enabled: return
	current_tool = "magnet"
	_update_tool_selection_ui()
	tool_selected.emit("magnet")

func _on_activate_tool_pressed() -> void:
	if not controls_enabled: return
	is_tool_active = not is_tool_active
	tool_trigger_toggled.emit(is_tool_active)

func _on_toggle_lights_pressed() -> void:
	if not controls_enabled: return
	lights_toggled.emit()

func _on_toggle_boost_pressed() -> void:
	if not controls_enabled: return
	is_boost_active = not is_boost_active
	if btn_toggle_boost:
		btn_toggle_boost.text = "BOOST: ON" if is_boost_active else "BOOST: OFF"
	boost_toggled.emit()

func _update_tool_selection_ui() -> void:
	if btn_welder: btn_welder.button_pressed = (current_tool == "welder")
	if btn_laser: btn_laser.button_pressed = (current_tool == "laser")
	if btn_magnet: btn_magnet.button_pressed = (current_tool == "magnet")
	_update_tuning_labels()
