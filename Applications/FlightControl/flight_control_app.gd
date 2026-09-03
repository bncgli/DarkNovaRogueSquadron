extends BaseApp
class_name FlightControlApp

## Applicazione GodotOS per il controllo dei movimenti e rotazioni dell'astronave (Flight Control).
## Conforme allo standard architetturale di bordo (APP_ARCHITECTURE_STANDARD.md).
## Supporta caricamento runtime e sincronizzazione attiva dei parametri di volo da file .dat protetti:
## - Ship Drive/Programs/FlightControls/flight_config.dat
## - Ship Drive/Programs/FlightControls/thrusters_tuning.dat

## Configurazione standard della finestra GodotOS
const APP_TITLE: String = "Flight Control - Guida Astronave"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(560, 530)

const CONFIG_PATH_PRIMARY: String = "Ship Drive/Programs/FlightControls/flight_config.dat"
const CONFIG_PATH_FALLBACK: String = "Ship Drive/Programs/FlightControl/flight_config.dat"
const TUNING_PATH_PRIMARY: String = "Ship Drive/Programs/FlightControls/thrusters_tuning.dat"
const TUNING_PATH_FALLBACK: String = "Ship Drive/Programs/FlightControl/thrusters_tuning.dat"

# Indicatori e Pulsanti di movimento
@onready var btn_q: Button = %BtnQ
@onready var btn_w: Button = %BtnW
@onready var btn_e: Button = %BtnE
@onready var btn_s: Button = %BtnS
@onready var btn_a: Button = %BtnA
@onready var btn_d: Button = %BtnD
@onready var btn_space: Button = %BtnSpace
@onready var btn_ctrl: Button = %BtnCtrl

# Indicatori e Pulsanti di rotazione
@onready var btn_pitch_up: Button = %BtnPitchUp
@onready var btn_pitch_down: Button = %BtnPitchDown
@onready var btn_yaw_left: Button = %BtnYawLeft
@onready var btn_yaw_right: Button = %BtnYawRight

# Badge e Telemetria
@onready var thrusters_badge: Label = %ThrustersBadge
@onready var status_summary_label: Label = %StatusSummaryLabel
@onready var speed_value_label: Label = %SpeedValueLabel
@onready var pos_value_label: Label = %PosValueLabel
@onready var rot_value_label: Label = %RotValueLabel
@onready var speed_progress_bar: ProgressBar = %SpeedProgressBar

# Configurazione .DAT e Tuning
@onready var dat_status_badge: Label = %DatStatusBadge
@onready var dat_config_summary_label: Label = %DatConfigSummaryLabel
@onready var reload_config_button: Button = %ReloadConfigButton

# Azioni
@onready var stop_button: Button = %StopButton
@onready var reset_button: Button = %ResetButton
@onready var speed_mode_button: Button = %SpeedModeButton
@onready var disconnected_overlay: Control = get_node_or_null("%DisconnectedOverlay")
@onready var cruise_control_panel: CruiseControlPanel = get_node_or_null("%CruiseControlPanel")

# Elementi UI Rotta Hyperdrive (da System Map)
@onready var hyperdrive_card: PanelContainer = get_node_or_null("%HyperdriveCard")
@onready var hyperdrive_target_label: Label = get_node_or_null("%HyperdriveTargetLabel")
@onready var hyperdrive_align_label: Label = get_node_or_null("%HyperdriveAlignLabel")
@onready var btn_align_hyperdrive: Button = get_node_or_null("%BtnAlignHyperdrive")
@onready var btn_engage_hyperdrive: Button = get_node_or_null("%BtnEngageHyperdrive")

var can_control_flight: bool = true
var active_hyperdrive_route: Dictionary = {}

# Input da click su UI (permettono di controllare anche con il mouse/touch)
var _ui_linear_input := Vector3.ZERO
var _ui_angular_input := Vector3.ZERO

# Modalità velocità (1.0 = Normale, 2.0 = Turbo, 0.4 = Precisione)
var _speed_multiplier: float = 1.0
var _speed_mode_index: int = 0
var speed_modes: Array[Dictionary] = [
	{"name": "NORMALE (1x)", "mult": 1.0, "color": Color(0.3, 0.85, 1.0)},
	{"name": "TURBO (2x)", "mult": 2.0, "color": Color(1.0, 0.5, 0.2)},
	{"name": "PRECISIONE (0.4x)", "mult": 0.4, "color": Color(0.4, 1.0, 0.6)}
]

# Configurazione attiva di volo estratta dai file .dat o da valori di calibrazione di fabbrica
var active_config: Dictionary = {
	"max_linear_speed": 20.0,
	"linear_acceleration": 35.0,
	"linear_deceleration": 20.0,
	"max_angular_speed": 2.5,
	"angular_acceleration": 8.0,
	"angular_deceleration": 6.0,
	"turbo_multiplier": 2.0,
	"precision_multiplier": 0.4,
	"rcs_power_rate": 1.0,
	"pitch_thrust_mult": 1.0,
	"yaw_thrust_mult": 1.0,
	"roll_thrust_mult": 1.0,
	"vertical_thrust_mult": 1.0,
	"is_dat_loaded": false
}

func _ready() -> void:
	_configure_window(APP_TITLE, DEFAULT_WINDOW_SIZE)
	_setup_ui_events()
	load_dat_configuration()
	_update_speed_mode_button()
	_connect_system_signals()
	_update_connection_state()
	_update_permissions()

func _setup_parent_window(_title: String, _size: Vector2) -> void:
	parent_window = _find_parent_window()
	if parent_window:
		parent_window.size = DEFAULT_WINDOW_SIZE
		parent_window.custom_minimum_size = Vector2(500, 440)
		parent_window.title_text = APP_TITLE
		var title_label := parent_window.get_node_or_null("Top Bar/Title Text")
		if title_label:
			title_label.text = "[center]" + APP_TITLE

func _find_parent_window() -> FakeWindow:
	var node: Node = get_parent()
	while node != null:
		if node is FakeWindow:
			return node
		node = node.get_parent()
	return null

func _connect_system_signals() -> void:
	if SpaceWorldManager:
		SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
		if SpaceWorldManager.has_signal("ship_system_power_changed"):
			SpaceWorldManager.ship_system_power_changed.connect(_on_system_power_changed)
	if NetworkManager:
		NetworkManager.player_role_changed.connect(_on_player_role_changed)
	if StarSystemGridManager:
		if not StarSystemGridManager.route_plotted.is_connected(_on_route_plotted):
			StarSystemGridManager.route_plotted.connect(_on_route_plotted)
	
	var sdm := _get_ship_drive_manager()
	if sdm:
		if sdm.has_signal("file_synced"):
			sdm.file_synced.connect(_on_file_synced)
		if sdm.has_signal("ship_drive_mounted"):
			sdm.ship_drive_mounted.connect(_on_ship_drive_mounted)

func _exit_tree() -> void:
	# Disconnessione segnali e pulizia risorse
	if SpaceWorldManager:
		if SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.disconnect(_on_ship_connection_changed)
		if SpaceWorldManager.has_signal("ship_system_power_changed") and SpaceWorldManager.ship_system_power_changed.is_connected(_on_system_power_changed):
			SpaceWorldManager.ship_system_power_changed.disconnect(_on_system_power_changed)
		SpaceWorldManager.stop_spaceship_engines()
	if NetworkManager:
		if NetworkManager.player_role_changed.is_connected(_on_player_role_changed):
			NetworkManager.player_role_changed.disconnect(_on_player_role_changed)
	if StarSystemGridManager:
		if StarSystemGridManager.route_plotted.is_connected(_on_route_plotted):
			StarSystemGridManager.route_plotted.disconnect(_on_route_plotted)
	
	var sdm := _get_ship_drive_manager()
	if sdm:
		if sdm.has_signal("file_synced") and sdm.file_synced.is_connected(_on_file_synced):
			sdm.file_synced.disconnect(_on_file_synced)
		if sdm.has_signal("ship_drive_mounted") and sdm.ship_drive_mounted.is_connected(_on_ship_drive_mounted):
			sdm.ship_drive_mounted.disconnect(_on_ship_drive_mounted)

func _get_ship_drive_manager() -> Node:
	return get_node_or_null("/root/ShipDriveManager")

func is_operational() -> bool:
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		return SpaceWorldManager.is_ship_connected()
	elif NetworkManager and NetworkManager.has_method("is_ship_connected"):
		return NetworkManager.is_ship_connected()
	return false

func _on_system_power_changed(category: String, is_powered: bool) -> void:
	if category == "propulsion" or category == "command":
		if not is_powered:
			# Disabilita controlli di volo
			can_control_flight = false
			_update_permissions()
			if thrusters_badge:
				thrusters_badge.text = "OFFLINE - NO POWER"
				thrusters_badge.modulate = Color(1.0, 0.3, 0.2)
		else:
			_update_permissions()

func _on_ship_connection_changed(_connected: bool) -> void:
	_update_connection_state()

func _on_ship_drive_mounted() -> void:
	load_dat_configuration()

func _on_file_synced(path: String) -> void:
	if path.begins_with("Ship Drive/Programs/FlightControls") or path.begins_with("Ship Drive/Programs/FlightControl"):
		load_dat_configuration()

func _update_connection_state() -> void:
	var op := is_operational()
	if disconnected_overlay:
		disconnected_overlay.visible = not op
	
	set_process(op)
	set_process_input(op)
	set_physics_process(op)
	
	if not op:
		_clear_all_highlights()
		_ui_linear_input = Vector3.ZERO
		_ui_angular_input = Vector3.ZERO
		if SpaceWorldManager:
			SpaceWorldManager.stop_spaceship_engines()
	else:
		_update_permissions()
		load_dat_configuration()

func _on_player_role_changed(_peer_id: int, _new_role: String) -> void:
	_update_permissions()

func _update_permissions() -> void:
	var my_role := ""
	var is_solo := false
	if NetworkManager:
		my_role = NetworkManager.get_local_player_role()
		is_solo = NetworkManager.is_solo_mode
	
	# Controllo abilitato per Pilota, Capitano, Solo Mode o se nessun ruolo bloccante
	can_control_flight = (my_role == NetworkManager.ROLE_PILOT or my_role == NetworkManager.ROLE_CAPTAIN or my_role == "" or my_role == NetworkManager.ROLE_UNASSIGNED or is_solo)
	
	# Aggiorna stato pulsanti di manovra
	var btns := [
		btn_q, btn_w, btn_e, btn_s, btn_a, btn_d, btn_space, btn_ctrl,
		btn_pitch_up, btn_pitch_down, btn_yaw_left, btn_yaw_right,
		stop_button, reset_button, speed_mode_button, reload_config_button
	]
	for b in btns:
		if b:
			b.disabled = not can_control_flight
	
	# Aggiorna badge/indicatori visivi
	if cruise_control_panel and is_instance_valid(cruise_control_panel):
		cruise_control_panel.set_permission_control(can_control_flight)
	
	if not can_control_flight and is_operational():
		if thrusters_badge:
			thrusters_badge.text = "SOLO TELEMETRIA"
			thrusters_badge.modulate = Color(0.7, 0.7, 1.0)
		if status_summary_label:
			status_summary_label.text = "Postazione in modalità osservatore (Ruolo: %s). Comandi di volo riservati al Pilota." % my_role
	elif is_operational():
		if thrusters_badge:
			thrusters_badge.text = "PROPULSORI PRONTI"
			thrusters_badge.modulate = Color(0.4, 1.0, 0.6)
		if status_summary_label:
			status_summary_label.text = "Tutti i sistemi RCS e propulsione operativi. Controllo attivo."

func _setup_ui_events() -> void:
	# Pulsanti ausiliari
	if stop_button:
		stop_button.pressed.connect(_on_stop_button_pressed)
	if reset_button:
		reset_button.pressed.connect(_on_reset_button_pressed)
	if speed_mode_button:
		speed_mode_button.pressed.connect(_on_speed_mode_toggle)
	if reload_config_button:
		reload_config_button.pressed.connect(func() -> void:
			load_dat_configuration()
			var notif := get_node_or_null("/root/NotificationManager")
			if notif and notif.has_method("spawn_notification"):
				notif.spawn_notification("Configurazione .DAT ricaricata.")
		)
	if btn_align_hyperdrive:
		btn_align_hyperdrive.pressed.connect(align_to_hyperdrive_vector)
	if btn_engage_hyperdrive:
		btn_engage_hyperdrive.pressed.connect(engage_hyperdrive)
	
	# Mapping pulsanti UI con pressione mouse (button_down / button_up)
	_bind_hold_button(btn_w, Vector3(0, 0, -1), Vector3.ZERO)
	_bind_hold_button(btn_s, Vector3(0, 0, 1), Vector3.ZERO)
	_bind_hold_button(btn_a, Vector3(-1, 0, 0), Vector3.ZERO)
	_bind_hold_button(btn_d, Vector3(1, 0, 0), Vector3.ZERO)
	_bind_hold_button(btn_q, Vector3.ZERO, Vector3(0, 0, 1))
	_bind_hold_button(btn_e, Vector3.ZERO, Vector3(0, 0, -1))
	_bind_hold_button(btn_space, Vector3(0, 1, 0), Vector3.ZERO)
	_bind_hold_button(btn_ctrl, Vector3(0, -1, 0), Vector3.ZERO)
	
	_bind_hold_button(btn_pitch_up, Vector3.ZERO, Vector3(1, 0, 0))
	_bind_hold_button(btn_pitch_down, Vector3.ZERO, Vector3(-1, 0, 0))
	_bind_hold_button(btn_yaw_left, Vector3.ZERO, Vector3(0, 1, 0))
	_bind_hold_button(btn_yaw_right, Vector3.ZERO, Vector3(0, -1, 0))

func _bind_hold_button(btn: Button, linear_dir: Vector3, angular_dir: Vector3) -> void:
	if btn == null:
		return
	btn.button_down.connect(func() -> void:
		_ui_linear_input += linear_dir
		_ui_angular_input += angular_dir
	)
	btn.button_up.connect(func() -> void:
		_ui_linear_input -= linear_dir
		_ui_angular_input -= angular_dir
	)

# ==============================================================================
# GESTIONE FILE .DAT DI CONFIGURAZIONE RUNTIME (APP_ARCHITECTURE_STANDARD.md)
# ==============================================================================

## Carica i parametri attivi di volo dai file .dat protetti in Ship Drive
func load_dat_configuration() -> Dictionary:
	var cfg_dict := _parse_dat_file(CONFIG_PATH_PRIMARY)
	if cfg_dict.is_empty():
		cfg_dict = _parse_dat_file(CONFIG_PATH_FALLBACK)
	
	var tuning_dict := _parse_dat_file(TUNING_PATH_PRIMARY)
	if tuning_dict.is_empty():
		tuning_dict = _parse_dat_file(TUNING_PATH_FALLBACK)
	
	var dat_found: bool = not cfg_dict.is_empty() or not tuning_dict.is_empty()
	
	if dat_found:
		if cfg_dict.has("max_linear_speed"):
			active_config["max_linear_speed"] = float(cfg_dict["max_linear_speed"])
		if cfg_dict.has("linear_acceleration"):
			active_config["linear_acceleration"] = float(cfg_dict["linear_acceleration"])
		if cfg_dict.has("linear_deceleration"):
			active_config["linear_deceleration"] = float(cfg_dict["linear_deceleration"])
		if cfg_dict.has("max_angular_speed"):
			active_config["max_angular_speed"] = float(cfg_dict["max_angular_speed"])
		if cfg_dict.has("angular_acceleration"):
			active_config["angular_acceleration"] = float(cfg_dict["angular_acceleration"])
		if cfg_dict.has("angular_deceleration"):
			active_config["angular_deceleration"] = float(cfg_dict["angular_deceleration"])
		if cfg_dict.has("turbo_multiplier"):
			active_config["turbo_multiplier"] = float(cfg_dict["turbo_multiplier"])
		if cfg_dict.has("precision_multiplier"):
			active_config["precision_multiplier"] = float(cfg_dict["precision_multiplier"])
		
		if tuning_dict.has("rcs_power_rate"):
			active_config["rcs_power_rate"] = float(tuning_dict["rcs_power_rate"])
		if tuning_dict.has("pitch_thrust_mult"):
			active_config["pitch_thrust_mult"] = float(tuning_dict["pitch_thrust_mult"])
		if tuning_dict.has("yaw_thrust_mult"):
			active_config["yaw_thrust_mult"] = float(tuning_dict["yaw_thrust_mult"])
		if tuning_dict.has("roll_thrust_mult"):
			active_config["roll_thrust_mult"] = float(tuning_dict["roll_thrust_mult"])
		if tuning_dict.has("vertical_thrust_mult"):
			active_config["vertical_thrust_mult"] = float(tuning_dict["vertical_thrust_mult"])
		
		active_config["is_dat_loaded"] = true
	else:
		active_config["is_dat_loaded"] = false
	
	# Aggiorna moltiplicatori delle modalità di velocità
	speed_modes[1]["mult"] = active_config["turbo_multiplier"]
	speed_modes[2]["mult"] = active_config["precision_multiplier"]
	_speed_multiplier = speed_modes[_speed_mode_index]["mult"]
	
	_apply_configuration_to_ship()
	_update_config_ui()
	_update_speed_mode_button()
	
	return active_config

## Applica attivamente i parametri di configurazione all'istanza Spaceship
func _apply_configuration_to_ship() -> void:
	if not SpaceWorldManager:
		return
	
	var ship: Spaceship = null
	if SpaceWorldManager.has_method("get_spaceship"):
		ship = SpaceWorldManager.get_spaceship()
	
	if ship and is_instance_valid(ship):
		var rcs: float = active_config.get("rcs_power_rate")
		ship.max_linear_speed = active_config.get("max_linear_speed") * rcs
		ship.linear_acceleration = active_config.get("linear_acceleration") * rcs
		ship.linear_deceleration = active_config.get("linear_deceleration")
		ship.max_angular_speed = active_config.get("max_angular_speed") * rcs
		ship.angular_acceleration = active_config.get("angular_acceleration") * rcs
		ship.angular_deceleration = active_config.get("angular_deceleration")

## Parsifica un file .dat formato INI/Key-Value
func _update_config_ui() -> void:
	if dat_status_badge:
		if active_config.get("is_dat_loaded"):
			dat_status_badge.text = "● .DAT ATTIVO"
			dat_status_badge.modulate = Color(0.3, 1.0, 0.6)
		else:
			dat_status_badge.text = "○ CALIBRAZIONE BASE"
			dat_status_badge.modulate = Color(0.9, 0.7, 0.3)
	
	if dat_config_summary_label:
		var spd: float = active_config.get("max_linear_speed") * active_config.get("rcs_power_rate")
		var acc: float = active_config.get("linear_acceleration") * active_config.get("rcs_power_rate")
		var ang: float = active_config.get("max_angular_speed") * active_config.get("rcs_power_rate")
		var rcs: float = active_config.get("rcs_power_rate")
		dat_config_summary_label.text = "VMax: %.1f m/s | Accel: %.1f m/s² | Ang: %.1f rad/s | RCS Mult: %.2fx" % [spd, acc, ang, rcs]

func get_active_config() -> Dictionary:
	return active_config

# ==============================================================================
# INPUT & CONTROLLO DINAMICA DI VOLO
# ==============================================================================

func is_control_active() -> bool:
	if not is_inside_tree() or not is_visible_in_tree():
		return false
	if not is_operational():
		return false
	if not can_control_flight:
		return false
	if parent_window:
		if parent_window.is_minimized or not parent_window.visible:
			return false
	return true

func _process(_delta: float) -> void:
	var move_vec := Vector3.ZERO
	var rot_vec := Vector3.ZERO
	
	if is_control_active():
		# Input Traslazione Orizzontale & Longitudinale
		if Input.is_key_pressed(KEY_W):
			move_vec.z -= 1.0
		if Input.is_key_pressed(KEY_S):
			move_vec.z += 1.0
		if Input.is_key_pressed(KEY_A):
			move_vec.x -= 1.0
		if Input.is_key_pressed(KEY_D):
			move_vec.x += 1.0
		
		# Quota Verticale
		if Input.is_key_pressed(KEY_SPACE):
			move_vec.y += active_config.get("vertical_thrust_mult")
		if Input.is_key_pressed(KEY_CTRL):
			move_vec.y -= active_config.get("vertical_thrust_mult")
		
		# Rollio (Q / E)
		if Input.is_key_pressed(KEY_Q):
			rot_vec.z += active_config.get("roll_thrust_mult")
		if Input.is_key_pressed(KEY_E):
			rot_vec.z -= active_config.get("roll_thrust_mult")
		
		# Beccheggio (Frecce Su/Giu) & Imbardata (Frecce Sinistra/Destra)
		if Input.is_key_pressed(KEY_UP):
			rot_vec.x += active_config.get("pitch_thrust_mult")
		if Input.is_key_pressed(KEY_DOWN):
			rot_vec.x -= active_config.get("pitch_thrust_mult")
		if Input.is_key_pressed(KEY_LEFT):
			rot_vec.y += active_config.get("yaw_thrust_mult")
		if Input.is_key_pressed(KEY_RIGHT):
			rot_vec.y -= active_config.get("yaw_thrust_mult")
		
		# Somma input da click UI
		move_vec += _ui_linear_input
		rot_vec += _ui_angular_input
	
	# Normalizzazione e applicazione moltiplicatore velocità
	if move_vec.length_squared() > 1.0:
		move_vec = move_vec.normalized()
	move_vec *= _speed_multiplier
	
	if rot_vec.length_squared() > 1.0:
		rot_vec = rot_vec.normalized()
	
	# Invia input al gestore spaziale
	if SpaceWorldManager:
		SpaceWorldManager.set_ship_flight_input(move_vec, rot_vec)
	
	# Aggiorna evidenziazione pulsanti UI
	_update_buttons_highlight(move_vec, rot_vec)
	_update_hyperdrive_ui()

func _physics_process(_delta: float) -> void:
	if not is_operational():
		return
	
	# Aggiorna telemetria
	if SpaceWorldManager and SpaceWorldManager.has_method("get_spaceship"):
		var ship := SpaceWorldManager.get_spaceship()
		if ship and is_instance_valid(ship):
			var cur_speed: float = ship.linear_velocity.length()
			var cur_pos: Vector3 = ship.global_position if ship.is_inside_tree() else ship.position
			var cur_rot: Vector3 = ship.rotation_degrees
			_update_telemetry_display(cur_speed, cur_pos, cur_rot)

func _update_telemetry_display(speed: float, pos: Vector3, rot: Vector3) -> void:
	if speed_value_label:
		speed_value_label.text = "%.1f m/s" % speed
	if speed_progress_bar:
		var max_s: float = active_config.get("max_linear_speed") * active_config.get("rcs_power_rate") * _speed_multiplier
		speed_progress_bar.max_value = max_s
		speed_progress_bar.value = speed
	if pos_value_label:
		pos_value_label.text = "X: %+.1f  Y: %+.1f  Z: %+.1f" % [pos.x, pos.y, pos.z]
	if rot_value_label:
		rot_value_label.text = "P: %+.1f°  Y: %+.1f°  R: %+.1f°" % [rot.x, rot.y, rot.z]

func _update_buttons_highlight(move: Vector3, rot: Vector3) -> void:
	_set_btn_active(btn_w, move.z < -0.05)
	_set_btn_active(btn_s, move.z > 0.05)
	_set_btn_active(btn_a, move.x < -0.05)
	_set_btn_active(btn_d, move.x > 0.05)
	_set_btn_active(btn_space, move.y > 0.05)
	_set_btn_active(btn_ctrl, move.y < -0.05)
	
	_set_btn_active(btn_q, rot.z > 0.05)
	_set_btn_active(btn_e, rot.z < -0.05)
	_set_btn_active(btn_pitch_up, rot.x > 0.05)
	_set_btn_active(btn_pitch_down, rot.x < -0.05)
	_set_btn_active(btn_yaw_left, rot.y > 0.05)
	_set_btn_active(btn_yaw_right, rot.y < -0.05)
	
	if thrusters_badge and can_control_flight:
		if move.length_squared() > 0.01 or rot.length_squared() > 0.01:
			thrusters_badge.text = "● PROPULSORI ATTIVI"
			thrusters_badge.modulate = Color(0.2, 1.0, 0.4)
		else:
			thrusters_badge.text = "○ IN VOLO D'INERZIA"
			thrusters_badge.modulate = Color(0.4, 0.8, 1.0)

func _set_btn_active(btn: Button, active: bool) -> void:
	if btn == null:
		return
	if active:
		btn.modulate = Color(1.2, 1.5, 2.0)
	else:
		btn.modulate = Color(1.0, 1.0, 1.0)

func _clear_all_highlights() -> void:
	var btns := [btn_q, btn_w, btn_e, btn_s, btn_a, btn_d, btn_space, btn_ctrl, btn_pitch_up, btn_pitch_down, btn_yaw_left, btn_yaw_right]
	for b in btns:
		if b:
			b.modulate = Color(1.0, 1.0, 1.0)

func _on_stop_button_pressed() -> void:
	if not can_control_flight:
		return
	_ui_linear_input = Vector3.ZERO
	_ui_angular_input = Vector3.ZERO
	if SpaceWorldManager:
		SpaceWorldManager.stop_spaceship_engines()

func _on_reset_button_pressed() -> void:
	if not can_control_flight:
		return
	_ui_linear_input = Vector3.ZERO
	_ui_angular_input = Vector3.ZERO
	if SpaceWorldManager:
		SpaceWorldManager.reset_ship_position()

func _on_speed_mode_toggle() -> void:
	if not can_control_flight:
		return
	_speed_mode_index = (_speed_mode_index + 1) % speed_modes.size()
	_speed_multiplier = speed_modes[_speed_mode_index]["mult"]
	_update_speed_mode_button()

func _update_speed_mode_button() -> void:
	if speed_mode_button:
		var mode: Dictionary = speed_modes[_speed_mode_index]
		speed_mode_button.text = "⚡ VELOCITÀ: %s" % mode["name"]
		speed_mode_button.modulate = mode["color"]

# ==============================================================================
# INTEGRAZIONE ROTTA SYSTEM MAP & INGAGGI HYPERDRIVE
# ==============================================================================

func _on_route_plotted(target_coords: Vector3i, course_vec: Vector3) -> void:
	active_hyperdrive_route = {
		"target_coords": target_coords,
		"target_sector_id": SectorData.format_coords_to_id(target_coords),
		"course_vector": course_vec
	}
	_update_hyperdrive_ui()

func _update_hyperdrive_ui() -> void:
	if StarSystemGridManager and active_hyperdrive_route.is_empty():
		var sys_route := StarSystemGridManager.get_active_route()
		if not sys_route.is_empty():
			active_hyperdrive_route = sys_route

	if active_hyperdrive_route.is_empty():
		if hyperdrive_card:
			hyperdrive_card.visible = false
		if btn_align_hyperdrive:
			btn_align_hyperdrive.disabled = true
		if btn_engage_hyperdrive:
			btn_engage_hyperdrive.disabled = true
		return

	if hyperdrive_card:
		hyperdrive_card.visible = true

	var target_id: String = active_hyperdrive_route.get("target_sector_id", "")
	var cur_coords := StarSystemGridManager.get_current_sector_coords() if StarSystemGridManager else Vector3i.ZERO
	var target_coords: Vector3i = active_hyperdrive_route.get("target_coords", Vector3i.ZERO)
	var dist_sectors := (Vector3(target_coords) - Vector3(cur_coords)).length()

	if hyperdrive_target_label:
		hyperdrive_target_label.text = "DESTINAZIONE: %s (Dist: %.1f sec)" % [target_id, dist_sectors]

	var aligned := is_hyperdrive_aligned()
	var angle_diff := get_hyperdrive_alignment_angle_deg()

	if hyperdrive_align_label:
		if aligned:
			hyperdrive_align_label.text = "ALLINEAMENTO: 🟢 AGGANCIATO (Dev: %.1f°)" % angle_diff
			hyperdrive_align_label.modulate = Color(0.2, 1.0, 0.5)
		else:
			hyperdrive_align_label.text = "ALLINEAMENTO: 🟡 DEVIAZIONE %.1f°" % angle_diff
			hyperdrive_align_label.modulate = Color(1.0, 0.8, 0.3)

	if btn_align_hyperdrive:
		btn_align_hyperdrive.disabled = not can_control_flight or aligned
	if btn_engage_hyperdrive:
		# Abilitato se can_control_flight, aligned, e distanza > 0
		btn_engage_hyperdrive.disabled = not can_control_flight or not aligned or dist_sectors < 0.01

## Calcola l'angolo in gradi tra la prua attuale della nave e il vettore rotta Hyperdrive
func get_hyperdrive_alignment_angle_deg() -> float:
	if active_hyperdrive_route.is_empty():
		return 0.0
	
	var course_vec: Vector3 = active_hyperdrive_route.get("course_vector", Vector3.ZERO)
	if course_vec.length_squared() < 0.0001:
		return 0.0

	var ship_forward := Vector3.FORWARD
	if SpaceWorldManager and SpaceWorldManager.has_method("get_spaceship"):
		var ship := SpaceWorldManager.get_spaceship()
		if ship and is_instance_valid(ship):
			# Direzione di prua (-Z nello spazio locale della nave trasformato in globale)
			ship_forward = -ship.global_transform.basis.z.normalized()

	# Proiezione sul piano XZ (griglia settori X-Y)
	var route_dir_2d := Vector2(course_vec.x, course_vec.y).normalized()
	var ship_dir_2d := Vector2(ship_forward.x, -ship_forward.z).normalized()
	
	if route_dir_2d.length_squared() < 0.001 or ship_dir_2d.length_squared() < 0.001:
		return 0.0

	var dot_val := clampf(ship_dir_2d.dot(route_dir_2d), -1.0, 1.0)
	return rad_to_deg(acos(dot_val))

## Verifica se la nave è allineata al vettore Hyperdrive entro una tolleranza diegetica (es. 5 gradi)
func is_hyperdrive_aligned(tolerance_deg: float = 5.0) -> bool:
	if active_hyperdrive_route.is_empty():
		return false
	return get_hyperdrive_alignment_angle_deg() <= tolerance_deg

## Allinea automaticamente la prua dell'astronave verso il vettore rotta Hyperdrive
func align_to_hyperdrive_vector() -> void:
	if not can_control_flight or active_hyperdrive_route.is_empty():
		return
	
	var course_vec: Vector3 = active_hyperdrive_route.get("course_vector", Vector3.ZERO)
	var route_dir_2d := Vector2(course_vec.x, course_vec.y).normalized()
	
	# Calcola angolo yaw desiderato
	# (0, 1) = sud (+90 deg), (0, -1) = nord (-90 deg), (1, 0) = est (0 deg)
	var target_angle_rad := atan2(route_dir_2d.y, route_dir_2d.x)
	var target_yaw_deg := -rad_to_deg(target_angle_rad) + 90.0

	if SpaceWorldManager and SpaceWorldManager.has_method("get_spaceship"):
		var ship := SpaceWorldManager.get_spaceship()
		if ship and is_instance_valid(ship):
			ship.rotation_degrees.y = fposmod(target_yaw_deg, 360.0)
			ship.rotation_degrees.x = 0.0
			ship.rotation_degrees.z = 0.0
			if "angular_velocity" in ship:
				ship.angular_velocity = Vector3.ZERO
	
	_update_hyperdrive_ui()

## Attiva l'Hyperdrive transit verso il settore target della rotta
func engage_hyperdrive() -> Dictionary:
	if not can_control_flight:
		return {"success": false, "reason": "Permesso di volo negato"}
	
	if active_hyperdrive_route.is_empty():
		if StarSystemGridManager:
			active_hyperdrive_route = StarSystemGridManager.get_active_route()
	
	if active_hyperdrive_route.is_empty():
		return {"success": false, "reason": "Nessuna rotta pianificata"}

	var target_coords: Vector3i = active_hyperdrive_route.get("target_coords", Vector3i.ZERO)
	
	if StarSystemGridManager:
		var res := StarSystemGridManager.engage_hyperdrive_transit(target_coords)
		if res.get("success"):
			active_hyperdrive_route.clear()
			_update_hyperdrive_ui()
		return res

	return {"success": false, "reason": "StarSystemGridManager non disponibile"}
