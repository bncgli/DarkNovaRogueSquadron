class_name ServiceDroneApp
extends BaseApp

## Controller per l'applicazione "External Service Drone & EVA Operations" (Applications/ServiceDrone).
## Permette il pilotaggio teleguidato del drone EVA per ispezioni e riparazioni scafo,
## saldatura di falle (dmg_breach), recupero cargo/detriti e sabotaggio/taglio laser.
## Conforme allo standard architetturale di bordo (APP_ARCHITECTURE_STANDARD.md).

const APP_TITLE: String = "DRONE DI SERVIZIO EVA"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(720, 520)

const CONFIG_PATH_PRIMARY: String = "Ship Drive/Programs/ServiceDrone/service_drone_config.dat"
const CONFIG_PATH_FALLBACK: String = "Ship Drive/Programs/ServiceDrone/config.dat"
const TUNING_PATH_PRIMARY: String = "Ship Drive/Programs/ServiceDrone/manipulator_tuning.dat"
const TUNING_PATH_FALLBACK: String = "Ship Drive/Programs/ServiceDrone/tuning.dat"

# Riferimenti UI principali (Unique Names)
@onready var disconnected_overlay: Control = get_node_or_null("%DisconnectedOverlay")
@onready var status_label: Label = get_node_or_null("%StatusLabel")
@onready var status_badge: Label = get_node_or_null("%StatusBadge")
@onready var dat_status_badge: Label = get_node_or_null("%DatStatusBadge")
@onready var role_badge: Label = get_node_or_null("%RoleBadge")
@onready var reload_dat_button: Button = get_node_or_null("%ReloadConfigButton")

# Telemetria & Status bar
@onready var dist_label: Label = get_node_or_null("%DistLabel")
@onready var battery_label: Label = get_node_or_null("%BatteryLabel")
@onready var cargo_label: Label = get_node_or_null("%CargoLabel")

# Feed 3D SubViewport
@onready var feed_viewport: SubViewport = get_node_or_null("%FeedViewport")
@onready var feed_camera: Camera3D = get_node_or_null("%FeedCamera")
@onready var hud_crosshair: Control = get_node_or_null("%HUDCrosshair")
@onready var hud_telemetry_label: Label = get_node_or_null("%HUDTelemetryLabel")

# Widget Braccio Manipolatore & Thruster
@onready var manipulator_control: ManipulatorControl = get_node_or_null("%ManipulatorControl")

# Permessi RBAC
var can_control_drone: bool = true

# Parametri runtime caricati dai file .DAT
var active_config: Dictionary = {
	"app_name": "ServiceDroneApp",
	"version": "1.0.0",
	"status": "OPERATIONAL",
	"max_thrust": 35.0,
	"battery_capacity_sec": 240.0,
	"tether_range": 1500.0,
	"auto_dock_speed": 12.0,
	"repair_rate": 15.0,
	"cutting_laser_power": 25.0,
	"cargo_capacity_kg": 500.0,
	"magnet_range": 18.0,
	"is_dat_loaded": false
}

# Input manuali correnti
var _manual_linear_input: Vector3 = Vector3.ZERO
var _manual_angular_input: Vector3 = Vector3.ZERO
var _is_boost: bool = false
var _latest_telemetry: Dictionary = {}

func _ready() -> void:
	_configure_window(APP_TITLE, DEFAULT_WINDOW_SIZE)
	_connect_system_signals()
	_connect_ui_signals()
	_setup_viewport_world()
	load_dat_configuration()
	_update_connection_state()
	_update_permissions()
	_refresh_ui()

func _setup_viewport_world() -> void:
	if not is_inside_tree():
		return
	
	if feed_viewport:
		if SpaceWorldManager and SpaceWorldManager.has_method("get_world_3d"):
			feed_viewport.world_3d = SpaceWorldManager.get_world_3d()
		feed_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		feed_viewport.handle_input_locally = false
		feed_viewport.own_world_3d = false
	
	if feed_camera:
		feed_camera.current = true
		feed_camera.fov = 75.0

func _connect_system_signals() -> void:
	if SpaceWorldManager:
		if SpaceWorldManager.has_signal("ship_connection_changed") and not SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
		if SpaceWorldManager.has_signal("service_drone_state_changed") and not SpaceWorldManager.service_drone_state_changed.is_connected(_on_service_drone_state_changed):
			SpaceWorldManager.service_drone_state_changed.connect(_on_service_drone_state_changed)
		if SpaceWorldManager.has_signal("ship_damages_updated") and not SpaceWorldManager.ship_damages_updated.is_connected(_on_ship_damages_updated):
			SpaceWorldManager.ship_damages_updated.connect(_on_ship_damages_updated)
	
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		if nm.has_signal("player_role_changed") and not nm.player_role_changed.is_connected(_on_player_role_changed):
			nm.player_role_changed.connect(_on_player_role_changed)
		if nm.has_signal("mission_started") and not nm.mission_started.is_connected(_on_mission_started):
			nm.mission_started.connect(_on_mission_started)
		if nm.has_signal("mission_ended") and not nm.mission_ended.is_connected(_on_mission_ended):
			nm.mission_ended.connect(_on_mission_ended)
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm:
		if sdm.has_signal("file_synced") and not sdm.file_synced.is_connected(_on_drive_file_modified):
			sdm.file_synced.connect(_on_drive_file_modified)
		if sdm.has_signal("file_modified") and not sdm.file_modified.is_connected(_on_drive_file_modified):
			sdm.file_modified.connect(_on_drive_file_modified)

func _connect_ui_signals() -> void:
	if reload_dat_button and not reload_dat_button.pressed.is_connected(_on_reload_dat_pressed):
		reload_dat_button.pressed.connect(_on_reload_dat_pressed)
	
	if manipulator_control:
		if not manipulator_control.undock_requested.is_connected(_on_undock_requested):
			manipulator_control.undock_requested.connect(_on_undock_requested)
		if not manipulator_control.auto_dock_requested.is_connected(_on_auto_dock_requested):
			manipulator_control.auto_dock_requested.connect(_on_auto_dock_requested)
		if not manipulator_control.tool_selected.is_connected(_on_tool_selected):
			manipulator_control.tool_selected.connect(_on_tool_selected)
		if not manipulator_control.tool_trigger_toggled.is_connected(_on_tool_trigger_toggled):
			manipulator_control.tool_trigger_toggled.connect(_on_tool_trigger_toggled)
		if not manipulator_control.lights_toggled.is_connected(_on_lights_toggled):
			manipulator_control.lights_toggled.connect(_on_lights_toggled)
		if not manipulator_control.boost_toggled.is_connected(_on_boost_toggled):
			manipulator_control.boost_toggled.connect(_on_boost_toggled)
		if not manipulator_control.thruster_command.is_connected(_on_ui_thruster_command):
			manipulator_control.thruster_command.connect(_on_ui_thruster_command)

func _exit_tree() -> void:
	if SpaceWorldManager:
		if SpaceWorldManager.has_signal("ship_connection_changed") and SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.disconnect(_on_ship_connection_changed)
		if SpaceWorldManager.has_signal("service_drone_state_changed") and SpaceWorldManager.service_drone_state_changed.is_connected(_on_service_drone_state_changed):
			SpaceWorldManager.service_drone_state_changed.disconnect(_on_service_drone_state_changed)
		if SpaceWorldManager.has_signal("ship_damages_updated") and SpaceWorldManager.ship_damages_updated.is_connected(_on_ship_damages_updated):
			SpaceWorldManager.ship_damages_updated.disconnect(_on_ship_damages_updated)
	
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		if nm.has_signal("player_role_changed") and nm.player_role_changed.is_connected(_on_player_role_changed):
			nm.player_role_changed.disconnect(_on_player_role_changed)
		if nm.has_signal("mission_started") and nm.mission_started.is_connected(_on_mission_started):
			nm.mission_started.disconnect(_on_mission_started)
		if nm.has_signal("mission_ended") and nm.mission_ended.is_connected(_on_mission_ended):
			nm.mission_ended.disconnect(_on_mission_ended)
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm:
		if sdm.has_signal("file_synced") and sdm.file_synced.is_connected(_on_drive_file_modified):
			sdm.file_synced.disconnect(_on_drive_file_modified)
		if sdm.has_signal("file_modified") and sdm.file_modified.is_connected(_on_drive_file_modified):
			sdm.file_modified.disconnect(_on_drive_file_modified)

func _process(_delta: float) -> void:
	if not _is_ship_operational():
		return
	
	# Sincronizza la telecamera della viewport con l'entità 3D ServiceDrone
	if SpaceWorldManager and SpaceWorldManager.has_method("get_service_drone") and feed_camera:
		var drone := SpaceWorldManager.get_service_drone()
		if drone and is_instance_valid(drone):
			var drone_cam := drone.get_camera_3d()
			if drone_cam and is_instance_valid(drone_cam):
				feed_camera.global_transform = drone_cam.global_transform
			else:
				feed_camera.global_transform = drone.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0.2, -0.45))
			_latest_telemetry = drone.get_telemetry()
			_update_telemetry_ui(_latest_telemetry)

func _input(event: InputEvent) -> void:
	if not _is_ship_operational() or not can_control_drone:
		return
	
	# Controlli da tastiera per pilotaggio rapido
	if event is InputEventKey and not event.echo:
		var key_event := event as InputEventKey
		var pressed := key_event.pressed
		var handled := false
		
		match key_event.keycode:
			KEY_W:
				_manual_linear_input.z = -1.0 if pressed else 0.0
				handled = true
			KEY_S:
				_manual_linear_input.z = 1.0 if pressed else 0.0
				handled = true
			KEY_A:
				_manual_linear_input.x = -1.0 if pressed else 0.0
				handled = true
			KEY_D:
				_manual_linear_input.x = 1.0 if pressed else 0.0
				handled = true
			KEY_Q:
				_manual_linear_input.y = 1.0 if pressed else 0.0
				handled = true
			KEY_E:
				_manual_linear_input.y = -1.0 if pressed else 0.0
				handled = true
			KEY_SPACE:
				if pressed:
					_manual_linear_input = Vector3.ZERO
					_manual_angular_input = Vector3.ZERO
				handled = true
			KEY_SHIFT:
				_is_boost = pressed
				handled = true
			KEY_F:
				if pressed:
					_on_lights_toggled()
				handled = true
			KEY_T:
				if pressed and manipulator_control:
					manipulator_control._on_activate_tool_pressed()
				handled = true
		
		if handled:
			_send_thruster_inputs()

func _send_thruster_inputs() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_method("set_service_drone_inputs"):
		SpaceWorldManager.set_service_drone_inputs(_manual_linear_input, _manual_angular_input, _is_boost)

func _on_ui_thruster_command(move_vec: Vector3, rot_vec: Vector3) -> void:
	if not can_control_drone: return
	_manual_linear_input = move_vec
	_manual_angular_input = rot_vec
	_send_thruster_inputs()

# --- GESTIONE STATO DI CONNESSIONE & OVERLAY ---

func _is_ship_operational() -> bool:
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		return SpaceWorldManager.is_ship_connected()
	var nm := get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("is_ship_connected"):
		return nm.is_ship_connected()
	return false

func _update_connection_state() -> void:
	var connected := _is_ship_operational()
	if disconnected_overlay:
		disconnected_overlay.visible = not connected
	
	if status_badge:
		if connected:
			status_badge.text = "● BAIA EVA ATTIVA"
			status_badge.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4, 1.0))
		else:
			status_badge.text = "● OFFLINE"
			status_badge.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25, 1.0))

func _on_ship_connection_changed(_connected: bool) -> void:
	_update_connection_state()
	_update_permissions()
	_refresh_ui()

func _on_mission_started(_role: String = "", _is_solo: bool = false) -> void:
	_update_connection_state()
	_update_permissions()
	_refresh_ui()

func _on_mission_ended() -> void:
	_update_connection_state()
	_update_permissions()
	_refresh_ui()

# --- MATRICE RBAC (ROLE-BASED ACCESS CONTROL) ---

func _on_player_role_changed(_peer_id: int, _new_role: String) -> void:
	_update_permissions()

func _update_permissions() -> void:
	var nm := get_node_or_null("/root/NetworkManager")
	var my_role := ""
	var is_solo := true
	
	if nm:
		if nm.has_method("get_local_player_role"):
			my_role = str(nm.get_local_player_role())
		elif "my_role" in nm:
			my_role = str(nm.my_role)
		if "is_solo_mode" in nm:
			is_solo = bool(nm.is_solo_mode)
		elif "is_multiplayer_active" in nm:
			is_solo = not bool(nm.is_multiplayer_active)
	
	# Matrice RBAC:
	# - Ingegnere, Hacker, Capitano, Stagista, Solo Mode: Controllo Completo
	# - Pilota, Soldato: Sola Visualizzazione
	var role_lower := my_role.to_lower().strip_edges()
	if not my_role.is_empty():
		can_control_drone = role_lower in ["engineer", "ingegnere", "hacker", "captain", "capitano", "stagista", "admin", "host"]
	else:
		can_control_drone = is_solo
	
	if role_badge:
		var display_role := my_role if not my_role.is_empty() else ("SOLO MODE" if is_solo else "SPETTATORE")
		role_badge.text = "Ruolo: %s (%s)" % [display_role, "CONTROLLO TOTALE" if can_control_drone else "SOLA LETTURA"]
		role_badge.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5, 1.0) if can_control_drone else Color(0.9, 0.7, 0.2, 1.0))
	
	if manipulator_control:
		manipulator_control.set_controls_enabled(can_control_drone)

# --- GESTIONE FILE .DAT E HOT-RELOADING ---

func _on_drive_file_modified(path: String, _content: String = "") -> void:
	if "Programs/ServiceDrone" in path and path.ends_with(".dat"):
		load_dat_configuration()

func _on_reload_dat_pressed() -> void:
	load_dat_configuration()
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("Parametri Service Drone .DAT ricaricati.")

func load_dat_configuration() -> void:
	var cfg_primary := _parse_dat_file(CONFIG_PATH_PRIMARY)
	var cfg_fallback := _parse_dat_file(CONFIG_PATH_FALLBACK)
	var tuning_primary := _parse_dat_file(TUNING_PATH_PRIMARY)
	var tuning_fallback := _parse_dat_file(TUNING_PATH_FALLBACK)
	
	var loaded_any := false
	if not cfg_primary.is_empty():
		_apply_dict_to_config(cfg_primary)
		loaded_any = true
	elif not cfg_fallback.is_empty():
		_apply_dict_to_config(cfg_fallback)
		loaded_any = true
	
	if not tuning_primary.is_empty():
		_apply_dict_to_config(tuning_primary)
		loaded_any = true
	elif not tuning_fallback.is_empty():
		_apply_dict_to_config(tuning_fallback)
		loaded_any = true
	
	active_config["is_dat_loaded"] = loaded_any
	_apply_configuration()
	
	if dat_status_badge:
		if loaded_any:
			dat_status_badge.text = "DAT: ATTIVO (FIRMWARE V1.0.0)"
			dat_status_badge.modulate = Color(0.3, 1.0, 0.4)
		else:
			dat_status_badge.text = "DAT: STANDARD (FALLBACK)"
			dat_status_badge.modulate = Color(1.0, 0.8, 0.2)

func _apply_dict_to_config(data: Dictionary) -> void:
	for k in data:
		active_config[k] = data[k]

func _apply_configuration() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_method("set_service_drone_config"):
		SpaceWorldManager.set_service_drone_config(active_config)
	
	if manipulator_control:
		manipulator_control.update_tuning(active_config)

func _on_service_drone_state_changed(t: Dictionary) -> void:
	_latest_telemetry = t
	_update_telemetry_ui(t)

func _on_ship_damages_updated(_damages: Array) -> void:
	_refresh_ui()

func _update_telemetry_ui(t: Dictionary) -> void:
	var dist: float = float(t.get("distance_to_ship"))
	var bat: float = float(t.get("battery"))
	var is_docked: bool = bool(t.get("is_docked"))
	var is_auto_dock: bool = bool(t.get("is_auto_docking"))
	var spd: float = float(t.get("speed"))
	var cargo_c: int = int(t.get("cargo_count", 0))
	var cargo_w: float = float(t.get("cargo_weight", 0.0))
	var cargo_max: float = float(t.get("max_cargo_weight", 500.0))
	var is_tool_act: bool = bool(t.get("is_tool_active", false))
	var tool_name: String = str(t.get("active_tool", "welder")).to_upper()
	
	if dist_label:
		dist_label.text = "DIST. NAVE: %.1f m" % dist
		dist_label.modulate = Color(0.3, 0.9, 0.5) if dist < float(active_config.get("tether_range", 1500.0)) * 0.8 else Color(1.0, 0.4, 0.4)
	
	if battery_label:
		battery_label.text = "BATTERIA: %.0f%%" % bat
		battery_label.modulate = Color(0.3, 0.9, 0.5) if bat > 25.0 else Color(1.0, 0.3, 0.3)
	
	if cargo_label:
		cargo_label.text = "CARGO: %d (%0.f/%0.f kg)" % [cargo_c, cargo_w, cargo_max]
	
	if status_label:
		if is_docked:
			status_label.text = "STATO: AGGANCIATO IN BAIA (STANDBY)"
			status_label.modulate = Color(0.3, 0.85, 1.0)
		elif is_auto_dock:
			status_label.text = "STATO: RIENTRO E DOCKING AUTOMATICO..."
			status_label.modulate = Color(1.0, 0.8, 0.2)
		elif is_tool_act:
			status_label.text = "STATO: OPERATIVO [%s ATTIVO]" % tool_name
			status_label.modulate = Color(0.9, 0.5, 0.2)
		else:
			status_label.text = "STATO: VOLO EVA ATTIVO (%.1f m/s)" % spd
			status_label.modulate = Color(0.3, 0.9, 0.5)
	
	if hud_telemetry_label:
		hud_telemetry_label.text = "EVA FEED | V: %.1f m/s | D: %.1fm | BAT: %.0f%%" % [spd, dist, bat]
	
	if manipulator_control:
		manipulator_control.update_telemetry(t)

func _refresh_ui() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_method("get_service_drone_telemetry"):
		var t := SpaceWorldManager.get_service_drone_telemetry()
		if not t.is_empty():
			_update_telemetry_ui(t)

# --- AZIONI MANIPOLATORE & VOLO ---

func _on_undock_requested() -> void:
	if not can_control_drone: return
	if SpaceWorldManager and SpaceWorldManager.has_method("launch_service_drone"):
		SpaceWorldManager.launch_service_drone()

func _on_auto_dock_requested() -> void:
	if not can_control_drone: return
	if SpaceWorldManager and SpaceWorldManager.has_method("start_service_drone_auto_dock"):
		SpaceWorldManager.start_service_drone_auto_dock()

func _on_tool_selected(tool_name: String) -> void:
	if not can_control_drone: return
	if SpaceWorldManager and SpaceWorldManager.has_method("set_service_drone_active_tool"):
		SpaceWorldManager.set_service_drone_active_tool(tool_name)

func _on_tool_trigger_toggled(is_active: bool) -> void:
	if not can_control_drone: return
	if SpaceWorldManager and SpaceWorldManager.has_method("set_service_drone_tool_trigger"):
		SpaceWorldManager.set_service_drone_tool_trigger(is_active)

func _on_lights_toggled() -> void:
	if not can_control_drone: return
	if SpaceWorldManager and SpaceWorldManager.has_method("get_service_drone"):
		var drone := SpaceWorldManager.get_service_drone()
		if drone:
			drone.toggle_lights()

func _on_boost_toggled() -> void:
	_is_boost = not _is_boost
	_send_thruster_inputs()
