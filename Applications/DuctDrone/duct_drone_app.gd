extends BaseApp
class_name DuctDroneApp

## Applicazione GodotOS per l'ispezione e manutenzione 2D nei condotti della nave (Duct Drone).
## Conforme allo standard architetturale di bordo (APP_ARCHITECTURE_STANDARD.md).
##
## Comandi Tank supportati:
## - W / Freccia Su: Spostamento in Avanti (nella direzione della prua del robottino)
## - S / Freccia Giù: Spostamento all'Indietro (retromarcia)
## - A / Freccia Sinistra: Rotazione a Sinistra (antioraria)
## - D / Freccia Destra: Rotazione a Destra (oraria)
## - Spazio / X: Freno / Stop immediato
## - R: Reset robottino alla stazione di ricarica

const APP_TITLE: String = "Duct Drone - Schema Nave & Condotti"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(880, 580)

const CONFIG_PATH_PRIMARY: String = "Ship Drive/Programs/DuctDrone/duct_drone_config.dat"
const CONFIG_PATH_FALLBACK: String = "Ship Drive/Programs/DuctDrone/config.dat"
const TUNING_PATH_PRIMARY: String = "Ship Drive/Programs/DuctDrone/drone_tuning.dat"
const TUNING_PATH_FALLBACK: String = "Ship Drive/Programs/DuctDrone/tuning.dat"

# Riferimenti UI principali
@onready var disconnected_overlay: Control = get_node_or_null("%DisconnectedOverlay")
@onready var status_summary_label: Label = get_node_or_null("%StatusSummaryLabel")
@onready var status_badge: Label = get_node_or_null("%StatusBadge")
@onready var role_badge: Label = get_node_or_null("%RoleBadge")
@onready var map_canvas: Control = get_node_or_null("%MapCanvas")

# Configurazione .DAT e Tuning
@onready var dat_status_badge: Label = get_node_or_null("%DatStatusBadge")
@onready var dat_config_summary_label: Label = get_node_or_null("%DatConfigSummaryLabel")
@onready var reload_config_button: Button = get_node_or_null("%ReloadConfigButton")

# Telemetria UI
@onready var pos_value_label: Label = get_node_or_null("%PosValueLabel")
@onready var heading_value_label: Label = get_node_or_null("%HeadingValueLabel")
@onready var speed_value_label: Label = get_node_or_null("%SpeedValueLabel")
@onready var sector_value_label: Label = get_node_or_null("%SectorValueLabel")
@onready var battery_progress_bar: ProgressBar = get_node_or_null("%BatteryProgressBar")
@onready var battery_label: Label = get_node_or_null("%BatteryLabel")

# Danni e Riparazioni UI
@onready var damage_count_label: Label = get_node_or_null("%DamageCountLabel")
@onready var nearby_damage_label: Label = get_node_or_null("%NearbyDamageLabel")
@onready var btn_repair: Button = get_node_or_null("%BtnRepair")
@onready var repair_progress_bar: ProgressBar = get_node_or_null("%RepairProgressBar")
@onready var repair_status_label: Label = get_node_or_null("%RepairStatusLabel")

# Pulsanti Tank UI
@onready var btn_forward: Button = get_node_or_null("%BtnForward")
@onready var btn_backward: Button = get_node_or_null("%BtnBackward")
@onready var btn_rot_left: Button = get_node_or_null("%BtnRotLeft")
@onready var btn_rot_right: Button = get_node_or_null("%BtnRotRight")
@onready var btn_stop: Button = get_node_or_null("%BtnStop")
@onready var btn_reset: Button = get_node_or_null("%BtnReset")
@onready var btn_speed_mode: Button = get_node_or_null("%BtnSpeedMode")
@onready var btn_lights_toggle: Button = get_node_or_null("%BtnLightsToggle")
@onready var btn_scan_pulse: Button = get_node_or_null("%BtnScanPulse")

var can_control: bool = true

# Parametri runtime configurati dai file .dat protetti
var active_config: Dictionary = {
	"linear_speed": 175.0,
	"linear_acceleration": 650.0,
	"linear_deceleration": 750.0,
	"rotate_speed": 3.0,
	"battery_max": 100.0,
	"battery_drain_move": 0.35,
	"battery_drain_lights": 0.75,
	"battery_drain_radar": 3.5,
	"battery_drain_repair": 6.0,
	"radar_scan_radius_max": 160.0,
	"repair_range": 42.0,
	"repair_speed_multiplier": 1.0,
	"turbo_multiplier": 2.0,
	"precision_multiplier": 0.5,
	"repair_efficiency": 1.0,
	"radar_intensity": 1.0,
	"overclock_speed_gain": 1.0,
	"is_dat_loaded": false
}

# Stato del robottino
var drone_pos: Vector2 = Vector2(300, 80) # Posizione iniziale nel Ponte di Comando
var drone_heading: float = -PI * 0.5 # Angolo di prua in radianti (-PI/2 = orientato in alto/Nord)
var drone_current_speed: float = 0.0
var drone_battery: float = 100.0
var lights_enabled: bool = true
var scan_pulse_radius: float = 0.0
var scan_pulse_active: bool = false

# Gestione danni & riparazioni
var ship_damages: Array = []
var is_repairing: bool = false
var current_repair_target_id: String = ""
var current_repair_progress: float = 0.0
var nearby_damage: Dictionary = {}

# Parametri dinamica movimento Tank
const BASE_LINEAR_SPEED: float = 175.0 # pixel al secondo
const BASE_ROTATE_SPEED: float = 3.0 # radianti al secondo
const ACCELERATION: float = 650.0
const DECELERATION: float = 750.0

var _linear_input: float = 0.0 # +1 avanti, -1 indietro
var _angular_input: float = 0.0 # -1 sinistra, +1 destra
var _ui_linear_input: float = 0.0
var _ui_angular_input: float = 0.0

# Modalità velocità
var _speed_multiplier: float = 1.0
var _speed_mode_index: int = 0
var speed_modes: Array[Dictionary] = [
	{"name": "NORMALE (1x)", "mult": 1.0, "color": Color(0.3, 0.85, 1.0)},
	{"name": "TURBO (2x)", "mult": 2.0, "color": Color(1.0, 0.5, 0.2)},
	{"name": "PRECISIONE (0.5x)", "mult": 0.5, "color": Color(0.4, 1.0, 0.6)}
]

# Definizione Blueprint Nave e Condotti
# Coordinate base di riferimento blueprint: Larghezza 600, Altezza 440
const BLUEPRINT_SIZE := Vector2(600, 440)
var initial_drone_pos := Vector2(300, 80)
var current_sector_name: String = "Ponte di Comando"

# Stanze della nave: { "id": str, "name": str, "rect": Rect2, "color": Color }
var rooms: Array[Dictionary] = [
	{
		"id": "bridge",
		"name": "Ponte di Comando",
		"rect": Rect2(230, 45, 140, 70),
		"color": Color(0.12, 0.28, 0.45, 0.55),
		"border_color": Color(0.35, 0.75, 1.0, 0.8)
	},
	{
		"id": "sensors",
		"name": "Sensori & Avionica",
		"rect": Rect2(110, 115, 100, 65),
		"color": Color(0.12, 0.35, 0.3, 0.5),
		"border_color": Color(0.2, 0.85, 0.65, 0.8)
	},
	{
		"id": "comms",
		"name": "Comunicazioni & EW",
		"rect": Rect2(390, 115, 100, 65),
		"color": Color(0.12, 0.35, 0.3, 0.5),
		"border_color": Color(0.2, 0.85, 0.65, 0.8)
	},
	{
		"id": "armory",
		"name": "Armeria & Sicurezza",
		"rect": Rect2(245, 135, 110, 60),
		"color": Color(0.35, 0.15, 0.2, 0.5),
		"border_color": Color(0.9, 0.35, 0.4, 0.8)
	},
	{
		"id": "quarters",
		"name": "Alloggi Equipaggio",
		"rect": Rect2(100, 200, 120, 75),
		"color": Color(0.22, 0.22, 0.35, 0.5),
		"border_color": Color(0.55, 0.55, 0.85, 0.8)
	},
	{
		"id": "cargo",
		"name": "Baia di Carico Principale",
		"rect": Rect2(380, 200, 120, 75),
		"color": Color(0.35, 0.28, 0.12, 0.5),
		"border_color": Color(0.95, 0.75, 0.25, 0.8)
	},
	{
		"id": "reactor",
		"name": "Nucleo Reattore & Fusione",
		"rect": Rect2(235, 215, 130, 80),
		"color": Color(0.35, 0.12, 0.35, 0.55),
		"border_color": Color(0.95, 0.35, 0.95, 0.9)
	},
	{
		"id": "engine",
		"name": "Sala Motori Principale",
		"rect": Rect2(185, 315, 230, 85),
		"color": Color(0.4, 0.2, 0.1, 0.55),
		"border_color": Color(1.0, 0.5, 0.2, 0.85)
	},
	{
		"id": "rcs_left",
		"name": "Pod RCS Sinistro",
		"rect": Rect2(30, 230, 50, 60),
		"color": Color(0.18, 0.25, 0.32, 0.5),
		"border_color": Color(0.4, 0.65, 0.85, 0.7)
	},
	{
		"id": "rcs_right",
		"name": "Pod RCS Destro",
		"rect": Rect2(520, 230, 50, 60),
		"color": Color(0.18, 0.25, 0.32, 0.5),
		"border_color": Color(0.4, 0.65, 0.85, 0.7)
	}
]

# Segmenti di condotto (Ducts): ogni condotto ha [p1, p2, width, nome]
var ducts: Array[Dictionary] = [
	# Condotto dorsale principale (Spine)
	{"from": Vector2(300, 115), "to": Vector2(300, 135), "width": 16.0, "name": "Condotto Dorsale Alpha"},
	{"from": Vector2(300, 195), "to": Vector2(300, 215), "width": 16.0, "name": "Condotto Reattore-Armeria"},
	{"from": Vector2(300, 295), "to": Vector2(300, 315), "width": 18.0, "name": "Condotto Termico Motori"},
	
	# Condotti orizzontali frontali (Ponte -> Sensori / Comms)
	{"from": Vector2(230, 80), "to": Vector2(160, 80), "width": 14.0, "name": "Condotto Dati Sensori"},
	{"from": Vector2(160, 80), "to": Vector2(160, 115), "width": 14.0, "name": "Condotto Avionica"},
	{"from": Vector2(370, 80), "to": Vector2(440, 80), "width": 14.0, "name": "Condotto Linea Comms"},
	{"from": Vector2(440, 80), "to": Vector2(440, 115), "width": 14.0, "name": "Condotto EW Comms"},
	
	# Condotti laterali (Sensori -> Alloggi, Comms -> Cargo)
	{"from": Vector2(160, 180), "to": Vector2(160, 200), "width": 14.0, "name": "Condotto Filtrazione SX"},
	{"from": Vector2(440, 180), "to": Vector2(440, 200), "width": 14.0, "name": "Condotto Linea Merci DX"},
	
	# Condotti trasversali di sicurezza verso il reattore
	{"from": Vector2(220, 240), "to": Vector2(235, 240), "width": 14.0, "name": "Bypass Refrigerante SX"},
	{"from": Vector2(365, 240), "to": Vector2(380, 240), "width": 14.0, "name": "Bypass Refrigerante DX"},
	
	# Condotti esterni verso i pod RCS
	{"from": Vector2(100, 250), "to": Vector2(80, 250), "width": 14.0, "name": "Condotto RCS Sinistro"},
	{"from": Vector2(500, 250), "to": Vector2(520, 250), "width": 14.0, "name": "Condotto RCS Destro"},
	
	# Condotti ausiliari verso i motori
	{"from": Vector2(160, 275), "to": Vector2(160, 350), "width": 14.0, "name": "Condotto Manutenzione SX"},
	{"from": Vector2(160, 350), "to": Vector2(185, 350), "width": 14.0, "name": "Accesso Motori SX"},
	{"from": Vector2(440, 275), "to": Vector2(440, 350), "width": 14.0, "name": "Condotto Manutenzione DX"},
	{"from": Vector2(440, 350), "to": Vector2(415, 350), "width": 14.0, "name": "Accesso Motori DX"},
	
	# Condotti di sfiato poppa
	{"from": Vector2(250, 400), "to": Vector2(250, 425), "width": 14.0, "name": "Sfiato Plasma 1"},
	{"from": Vector2(350, 400), "to": Vector2(350, 425), "width": 14.0, "name": "Sfiato Plasma 2"}
]

# Traccia / particelle del drone
var drone_trail: Array[Vector2] = []
const MAX_TRAIL_LENGTH: int = 35

func _ready() -> void:
	if SpaceWorldManager:
		var mgr_rooms := SpaceWorldManager.get_duct_rooms()
		if mgr_rooms.size() > 0:
			rooms.clear()
			for r in mgr_rooms:
				rooms.append({
					"id": r.id,
					"name": r.name,
					"rect": r.rect,
					"color": r.color,
					"border_color": r.color.lightened(0.3)
				})
					
		var mgr_ducts := SpaceWorldManager.get_duct_corridors()
		if mgr_ducts.size() > 0:
			ducts.clear()
			for d in mgr_ducts:
				ducts.append({
					"from": d.from,
					"to": d.to,
					"width": d.width,
					"name": d.name
				})
	_configure_window(APP_TITLE, DEFAULT_WINDOW_SIZE)
	_setup_ui_events()
	load_dat_configuration()
	_update_speed_mode_button()
	_connect_system_signals()
	_sync_state_from_manager()
	_update_connection_state()
	_update_permissions()
	_update_lights_button()
	_update_telemetry_ui()

func _setup_parent_window(_title: String, _size: Vector2) -> void:
	parent_window = _find_parent_window()
	if parent_window:
		parent_window.size = DEFAULT_WINDOW_SIZE
		parent_window.custom_minimum_size = Vector2(720, 500)
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

func _setup_ui_events() -> void:
	# Disabilita il focus trapping sui pulsanti per non intercettare le frecce o lo spazio
	var all_buttons: Array[Button] = [
		btn_forward, btn_backward, btn_rot_left, btn_rot_right,
		btn_stop, btn_reset, btn_speed_mode, btn_lights_toggle, btn_scan_pulse,
		btn_repair, reload_config_button
	]
	for b in all_buttons:
		if b:
			b.focus_mode = Control.FOCUS_NONE
	
	# Eventi Tank Controls
	if btn_forward:
		btn_forward.button_down.connect(func(): _ui_linear_input = 1.0)
		btn_forward.button_up.connect(func(): _ui_linear_input = 0.0)
	if btn_backward:
		btn_backward.button_down.connect(func(): _ui_linear_input = -1.0)
		btn_backward.button_up.connect(func(): _ui_linear_input = 0.0)
	if btn_rot_left:
		btn_rot_left.button_down.connect(func(): _ui_angular_input = -1.0)
		btn_rot_left.button_up.connect(func(): _ui_angular_input = 0.0)
	if btn_rot_right:
		btn_rot_right.button_down.connect(func(): _ui_angular_input = 1.0)
		btn_rot_right.button_up.connect(func(): _ui_angular_input = 0.0)
	
	if btn_stop:
		btn_stop.pressed.connect(_on_stop_pressed)
	if btn_reset:
		btn_reset.pressed.connect(_on_reset_pressed)
	if btn_speed_mode:
		btn_speed_mode.pressed.connect(_on_speed_mode_toggle)
	if btn_lights_toggle:
		btn_lights_toggle.pressed.connect(_on_lights_toggle)
	if btn_scan_pulse:
		btn_scan_pulse.pressed.connect(_on_scan_pulse_pressed)
	if btn_repair:
		btn_repair.pressed.connect(_on_repair_button_pressed)
	if reload_config_button:
		reload_config_button.pressed.connect(func() -> void:
			load_dat_configuration()
			var notif := get_node_or_null("/root/NotificationManager")
			if notif and notif.has_method("spawn_notification"):
				notif.spawn_notification("Duct Drone: Configurazione .DAT ricaricata.")
		)

func _connect_system_signals() -> void:
	if SpaceWorldManager:
		if not SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
		if not SpaceWorldManager.duct_drone_state_changed.is_connected(_on_manager_drone_state_changed):
			SpaceWorldManager.duct_drone_state_changed.connect(_on_manager_drone_state_changed)
		if not SpaceWorldManager.duct_drone_reset_performed.is_connected(_on_manager_drone_reset):
			SpaceWorldManager.duct_drone_reset_performed.connect(_on_manager_drone_reset)
		if not SpaceWorldManager.ship_damages_updated.is_connected(_on_ship_damages_updated):
			SpaceWorldManager.ship_damages_updated.connect(_on_ship_damages_updated)
		if not SpaceWorldManager.ship_damage_discovered.is_connected(_on_ship_damage_discovered):
			SpaceWorldManager.ship_damage_discovered.connect(_on_ship_damage_discovered)
		if not SpaceWorldManager.ship_damage_repaired.is_connected(_on_ship_damage_repaired):
			SpaceWorldManager.ship_damage_repaired.connect(_on_ship_damage_repaired)
		if not SpaceWorldManager.duct_drone_repair_state_changed.is_connected(_on_repair_state_changed):
			SpaceWorldManager.duct_drone_repair_state_changed.connect(_on_repair_state_changed)
		
		var mgr_damages := SpaceWorldManager.get_ship_damages()
		ship_damages.clear()
		for sd in mgr_damages:
			if sd is ShipDamageRuntimeState:
				ship_damages.append(sd.to_dict())
			else:
				ship_damages.append(sd)
	else:
		_init_standalone_damages()
	
	if NetworkManager:
		if not NetworkManager.player_role_changed.is_connected(_on_player_role_changed):
			NetworkManager.player_role_changed.connect(_on_player_role_changed)
	
	var sdm := _get_ship_drive_manager()
	if sdm:
		if sdm.has_signal("file_synced") and not sdm.file_synced.is_connected(_on_file_synced):
			sdm.file_synced.connect(_on_file_synced)
		if sdm.has_signal("ship_drive_mounted") and not sdm.ship_drive_mounted.is_connected(_on_ship_drive_mounted):
			sdm.ship_drive_mounted.connect(_on_ship_drive_mounted)

func _exit_tree() -> void:
	if SpaceWorldManager:
		if SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.disconnect(_on_ship_connection_changed)
		if SpaceWorldManager.duct_drone_state_changed.is_connected(_on_manager_drone_state_changed):
			SpaceWorldManager.duct_drone_state_changed.disconnect(_on_manager_drone_state_changed)
		if SpaceWorldManager.duct_drone_reset_performed.is_connected(_on_manager_drone_reset):
			SpaceWorldManager.duct_drone_reset_performed.disconnect(_on_manager_drone_reset)
		if SpaceWorldManager.ship_damages_updated.is_connected(_on_ship_damages_updated):
			SpaceWorldManager.ship_damages_updated.disconnect(_on_ship_damages_updated)
		if SpaceWorldManager.ship_damage_discovered.is_connected(_on_ship_damage_discovered):
			SpaceWorldManager.ship_damage_discovered.disconnect(_on_ship_damage_discovered)
		if SpaceWorldManager.ship_damage_repaired.is_connected(_on_ship_damage_repaired):
			SpaceWorldManager.ship_damage_repaired.disconnect(_on_ship_damage_repaired)
		if SpaceWorldManager.duct_drone_repair_state_changed.is_connected(_on_repair_state_changed):
			SpaceWorldManager.duct_drone_repair_state_changed.disconnect(_on_repair_state_changed)
		SpaceWorldManager.stop_duct_drone()
	if NetworkManager and NetworkManager.player_role_changed.is_connected(_on_player_role_changed):
		NetworkManager.player_role_changed.disconnect(_on_player_role_changed)
	
	var sdm := _get_ship_drive_manager()
	if sdm:
		if sdm.has_signal("file_synced") and sdm.file_synced.is_connected(_on_file_synced):
			sdm.file_synced.disconnect(_on_file_synced)
		if sdm.has_signal("ship_drive_mounted") and sdm.ship_drive_mounted.is_connected(_on_ship_drive_mounted):
			sdm.ship_drive_mounted.disconnect(_on_ship_drive_mounted)

func _get_ship_drive_manager() -> Node:
	return get_node_or_null("/root/ShipDriveManager")

func _on_ship_drive_mounted() -> void:
	load_dat_configuration()

func _on_file_synced(path: String) -> void:
	if "Programs/DuctDrone" in path and path.ends_with(".dat"):
		load_dat_configuration()

## Carica i parametri di funzionamento del drone dai file .dat protetti in Ship Drive
func load_dat_configuration() -> Dictionary:
	var cfg_dict := _parse_dat_file(CONFIG_PATH_PRIMARY)
	if cfg_dict.is_empty():
		cfg_dict = _parse_dat_file(CONFIG_PATH_FALLBACK)
	
	var tuning_dict := _parse_dat_file(TUNING_PATH_PRIMARY)
	if tuning_dict.is_empty():
		tuning_dict = _parse_dat_file(TUNING_PATH_FALLBACK)
	
	var has_dat := not cfg_dict.is_empty() or not tuning_dict.is_empty()
	
	for k in cfg_dict:
		if cfg_dict[k] is String and (cfg_dict[k] as String).is_valid_float():
			active_config[k] = float(cfg_dict[k])
		else:
			active_config[k] = cfg_dict[k]
	
	for k in tuning_dict:
		if tuning_dict[k] is String and (tuning_dict[k] as String).is_valid_float():
			active_config[k] = float(tuning_dict[k])
		else:
			active_config[k] = tuning_dict[k]
			
	active_config["is_dat_loaded"] = has_dat
	
	_apply_configuration()
	return active_config

func _apply_configuration() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_method("set_duct_drone_config"):
		SpaceWorldManager.set_duct_drone_config(active_config)
	
	if speed_modes.size() >= 3:
		speed_modes[1]["mult"] = active_config["turbo_multiplier"]
		speed_modes[2]["mult"] = active_config["precision_multiplier"]
		_speed_multiplier = speed_modes[_speed_mode_index]["mult"]
		_update_speed_mode_button()
	
	if dat_status_badge:
		if active_config["is_dat_loaded"]:
			dat_status_badge.text = "● .DAT ATTIVO"
			dat_status_badge.modulate = Color(0.3, 1.0, 0.6)
		else:
			dat_status_badge.text = "○ DEFAULT"
			dat_status_badge.modulate = Color(0.8, 0.8, 0.4)
	
	if dat_config_summary_label:
		var src := "Ship Drive" if active_config["is_dat_loaded"] else "Default"
		dat_config_summary_label.text = "Fonte: %s | VMax: %.0f px/s | Rot: %.1f rad/s | Drain: %.2f/s | Range: %.0f px" % [
			src,
			float(active_config["linear_speed"]),
			float(active_config["rotate_speed"]),
			float(active_config["battery_drain_move"]),
			float(active_config["repair_range"])
		]

func _sync_state_from_manager() -> void:
	if SpaceWorldManager:
		drone_pos = SpaceWorldManager.get_duct_drone_pos()
		drone_heading = SpaceWorldManager.get_duct_drone_heading()
		drone_current_speed = SpaceWorldManager.get_duct_drone_speed()
		drone_battery = SpaceWorldManager.get_duct_drone_battery()
		lights_enabled = SpaceWorldManager.get_duct_drone_lights()
		scan_pulse_active = SpaceWorldManager.is_duct_drone_scan_active()
		scan_pulse_radius = SpaceWorldManager.get_duct_drone_scan_radius()

func _on_manager_drone_state_changed(pos: Vector2, heading: float, speed: float, battery: float, lights: bool, scan_active: bool, scan_radius: float) -> void:
	drone_pos = pos
	drone_heading = heading
	drone_current_speed = speed
	drone_battery = battery
	lights_enabled = lights
	scan_pulse_active = scan_active
	scan_pulse_radius = scan_radius
	_update_lights_button()
	_update_trail(pos)

func _on_manager_drone_reset() -> void:
	drone_trail.clear()
	_sync_state_from_manager()
	_update_sector_info()
	_update_telemetry_ui()
	_update_lights_button()

func _update_trail(pos: Vector2) -> void:
	if drone_trail.is_empty() or drone_trail.back().distance_to(pos) > 6.0:
		drone_trail.push_back(pos)
		if drone_trail.size() > MAX_TRAIL_LENGTH:
			drone_trail.pop_front()

func is_operational() -> bool:
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		return SpaceWorldManager.is_ship_connected()
	elif NetworkManager and NetworkManager.has_method("is_ship_connected"):
		return NetworkManager.is_ship_connected()
	return false

func is_control_active() -> bool:
	if not is_inside_tree() or not is_visible_in_tree():
		return false
	if parent_window:
		if parent_window.is_minimized or not parent_window.visible:
			return false
	return can_control

func _on_ship_connection_changed(_is_connected: bool) -> void:
	_update_connection_state()

func _update_connection_state() -> void:
	var op := is_operational()
	if disconnected_overlay:
		disconnected_overlay.visible = not op
	
	if status_badge:
		if op:
			status_badge.text = "● ATTIVO"
			status_badge.modulate = Color(0.3, 1.0, 0.5)
		else:
			status_badge.text = "○ OFFLINE"
			status_badge.modulate = Color(1.0, 0.4, 0.3)
	
	if status_summary_label:
		if op:
			status_summary_label.text = "Telemetria Drone Collegata - Canale Manutenzione Nave Attivo"
		else:
			status_summary_label.text = "Telemetria Disconnessa - In attesa di avvio missione o connessione alla nave"
	
	set_process(op)
	set_process_input(op)
	set_physics_process(op)
	
	if op:
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
	else:
		is_solo = true
	
	var role_lower := my_role.to_lower()
	if not my_role.is_empty():
		can_control = role_lower in ["ingegnere", "engineer", "capitano", "captain", "stagista", "hacker", "pilota", "pilot", "admin", "host"]
	else:
		can_control = is_solo
	
	if role_badge:
		if is_solo:
			role_badge.text = "MODO: SOLO (FULL ACCESS)"
			role_badge.modulate = Color(0.4, 1.0, 0.6)
		elif not my_role.is_empty():
			role_badge.text = "RUOLO: %s" % my_role.to_upper()
			role_badge.modulate = Color(0.35, 0.85, 1.0)
		else:
			role_badge.text = "OPERATORE MANUTENZIONE"
			role_badge.modulate = Color(0.8, 0.8, 0.9)
	
	var controls_disabled := not can_control
	if btn_forward: btn_forward.disabled = controls_disabled
	if btn_backward: btn_backward.disabled = controls_disabled
	if btn_rot_left: btn_rot_left.disabled = controls_disabled
	if btn_rot_right: btn_rot_right.disabled = controls_disabled
	if btn_stop: btn_stop.disabled = controls_disabled
	if btn_reset: btn_reset.disabled = controls_disabled
	if btn_repair: btn_repair.disabled = controls_disabled
	if btn_lights_toggle: btn_lights_toggle.disabled = controls_disabled
	if btn_scan_pulse: btn_scan_pulse.disabled = controls_disabled
	if btn_speed_mode: btn_speed_mode.disabled = controls_disabled
	if reload_config_button: reload_config_button.disabled = controls_disabled

func _is_key_down(key: Key) -> bool:
	return Input.is_physical_key_pressed(key) \
		or Input.is_key_pressed(key) \
		or Input.is_key_label_pressed(key)

func _is_space_down() -> bool:
	return Input.is_physical_key_pressed(KEY_SPACE) \
		or Input.is_key_pressed(KEY_SPACE) \
		or Input.is_key_label_pressed(KEY_SPACE)

func _highlight_button(btn: Button, active: bool) -> void:
	if btn == null:
		return
	if active:
		btn.modulate = Color(0.3, 1.0, 0.6)
	else:
		btn.modulate = Color(1.0, 1.0, 1.0)

func _clear_button_highlights() -> void:
	var buttons := [btn_forward, btn_backward, btn_rot_left, btn_rot_right]
	for b in buttons:
		if b:
			b.modulate = Color(1.0, 1.0, 1.0)

func _input(event: InputEvent) -> void:
	if not is_control_active():
		return
	
	if event is InputEventKey and not event.is_echo():
		if event.is_action_pressed("ui_cancel"):
			return
		
		# Tasto rapido Freno (Spazio o X)
		if event.pressed and (event.keycode in [KEY_SPACE, KEY_X] or event.physical_keycode in [KEY_SPACE, KEY_X]):
			_on_stop_pressed()
			get_viewport().set_input_as_handled()
			return
		
		# Tasto rapido Reset (R)
		if event.pressed and (event.keycode == KEY_R or event.physical_keycode == KEY_R):
			_on_reset_pressed()
			get_viewport().set_input_as_handled()
			return
		
		# Tasto rapido Fari (F)
		if event.pressed and (event.keycode == KEY_F or event.physical_keycode == KEY_F):
			_on_lights_toggle()
			get_viewport().set_input_as_handled()
			return
		
		# Tasto rapido Riparazione (E)
		if event.pressed and (event.keycode == KEY_E or event.physical_keycode == KEY_E):
			_on_repair_button_pressed()
			get_viewport().set_input_as_handled()
			return

func _process(delta: float) -> void:
	_handle_movement(delta)
	
	if not SpaceWorldManager:
		_update_scan_pulse(delta)
		_local_simulate_repair_and_discovery(delta)
	
	_update_nearby_damage()
	_update_damage_ui()
	_update_sector_info()
	_update_telemetry_ui()
	
	if map_canvas:
		map_canvas.queue_redraw()

func _parse_pos(val: Variant) -> Vector2:
	if val is Vector2:
		return val
	if val is Array and val.size() >= 2:
		return Vector2(float(val[0]), float(val[1]))
	return Vector2.ZERO

func _update_nearby_damage() -> void:
	nearby_damage = {}
	var min_d := 38.0
	for dmg in ship_damages:
		var is_repaired: bool = bool(dmg.repaired if "repaired" in dmg else dmg.get("repaired", false))
		if is_repaired:
			continue
		var dpos: Vector2 = _parse_pos(dmg.pos if "pos" in dmg else dmg.get("pos"))
		var d := drone_pos.distance_to(dpos)
		if d <= min_d:
			min_d = d
			nearby_damage = dmg if dmg is Dictionary else (dmg.to_dict() if dmg.has_method("to_dict") else {})

func _update_damage_ui() -> void:
	var total_active := 0
	var revealed_count := 0
	for dmg in ship_damages:
		var is_repaired: bool = bool(dmg.repaired if "repaired" in dmg else dmg.get("repaired", false))
		if not is_repaired:
			total_active += 1
			var is_revealed: bool = bool(dmg.revealed if "revealed" in dmg else dmg.get("revealed", false))
			if is_revealed:
				revealed_count += 1
	
	if damage_count_label:
		if total_active == 0:
			damage_count_label.text = "0 / 0 (Scafo Integro)"
			damage_count_label.modulate = Color(0.3, 1.0, 0.5)
		else:
			damage_count_label.text = "%d Rilevati (%d Totali)" % [revealed_count, total_active]
			damage_count_label.modulate = Color(1.0, 0.4, 0.3) if revealed_count > 0 else Color(0.7, 0.7, 0.7)
	
	if nearby_damage_label:
		if not nearby_damage.is_empty():
			var type_str := "Breccia Scafo" if nearby_damage.get("type") == "breach" else "Cortocircuito"
			var is_revealed: bool = nearby_damage.get("revealed")
			var dur: float = float(nearby_damage.get("repair_duration", 5.0))
			if is_revealed:
				nearby_damage_label.text = "⚠️ Adiacente a: %s (Tempo: %.1fs)" % [type_str, dur]
				nearby_damage_label.modulate = Color(1.0, 0.75, 0.2)
			else:
				nearby_damage_label.text = "❓ Anomalia adiacente non rilevata (Usa Fari / Radar)"
				nearby_damage_label.modulate = Color(0.6, 0.6, 0.8)
		else:
			nearby_damage_label.text = "Nessun danno adiacente"
			nearby_damage_label.modulate = Color(0.65, 0.75, 0.85, 0.8)
	
	if btn_repair:
		if is_repairing:
			btn_repair.text = "⏹ STOP RIPARAZIONE (E)"
			btn_repair.modulate = Color(1.0, 0.35, 0.35)
			btn_repair.disabled = false
		elif not nearby_damage.is_empty() and nearby_damage.get("revealed"):
			var type_label := "BRECCIA" if nearby_damage.get("type") == "breach" else "CORTO"
			btn_repair.text = "🔧 RIPARA %s (E)" % type_label
			btn_repair.modulate = Color(0.3, 1.0, 0.6)
			btn_repair.disabled = false
		else:
			btn_repair.text = "🔧 RIPARA (E)"
			btn_repair.modulate = Color(0.6, 0.6, 0.6)
			btn_repair.disabled = nearby_damage.is_empty() or not nearby_damage.get("revealed")
	
	if repair_progress_bar and repair_status_label:
		if is_repairing:
			repair_progress_bar.value = current_repair_progress * 100.0
			repair_status_label.text = "Riparazione in corso: %3.0f%%" % (current_repair_progress * 100.0)
			repair_status_label.modulate = Color(0.2, 1.0, 0.8)
		else:
			var target_dmg := nearby_damage if not nearby_damage.is_empty() else {}
			var p: float = float(target_dmg.get("repair_progress", 0.0))
			repair_progress_bar.value = p * 100.0
			if p > 0.0:
				repair_status_label.text = "Progresso salvato: %3.0f%%" % (p * 100.0)
			else:
				repair_status_label.text = "Pronto ad operare"
			repair_status_label.modulate = Color(0.5, 0.7, 0.9, 0.8)

func _on_repair_button_pressed() -> void:
	if not is_control_active():
		return
	
	if is_repairing:
		if SpaceWorldManager:
			SpaceWorldManager.stop_duct_drone_repair()
		else:
			is_repairing = false
			current_repair_target_id = ""
		return
	
	_update_nearby_damage()
	if not nearby_damage.is_empty():
		var dmg_id: String = str(nearby_damage.get("id", ""))
		if SpaceWorldManager:
			SpaceWorldManager.start_duct_drone_repair(dmg_id)
		else:
			is_repairing = true
			current_repair_target_id = dmg_id

func _init_standalone_damages() -> void:
	ship_damages = [
		{
			"id": "dmg_1",
			"type": "breach",
			"pos": Vector2(160, 310),
			"sector": "Condotto Manutenzione SX",
			"revealed": false,
			"revealed_by": "",
			"repair_progress": 0.0,
			"repair_duration": 4.5,
			"repaired": false
		},
		{
			"id": "dmg_2",
			"type": "short_circuit",
			"pos": Vector2(390, 140),
			"sector": "Comunicazioni & EW",
			"revealed": false,
			"revealed_by": "",
			"repair_progress": 0.0,
			"repair_duration": 5.2,
			"repaired": false
		},
		{
			"id": "dmg_3",
			"type": "breach",
			"pos": Vector2(440, 310),
			"sector": "Condotto Manutenzione DX",
			"revealed": false,
			"revealed_by": "",
			"repair_progress": 0.0,
			"repair_duration": 6.0,
			"repaired": false
		},
		{
			"id": "dmg_4",
			"type": "short_circuit",
			"pos": Vector2(200, 140),
			"sector": "Sensori & Avionica",
			"revealed": false,
			"revealed_by": "",
			"repair_progress": 0.0,
			"repair_duration": 3.8,
			"repaired": false
		}
	]

func _local_simulate_repair_and_discovery(delta: float) -> void:
	for dmg in ship_damages:
		var is_repaired: bool = bool(dmg.repaired if "repaired" in dmg else dmg.get("repaired", false))
		if is_repaired:
			continue
		var is_revealed: bool = bool(dmg.revealed if "revealed" in dmg else dmg.get("revealed", false))
		if not is_revealed:
			var dtype: String = str(dmg.type if "type" in dmg else dmg.get("type", ""))
			var dpos: Vector2 = _parse_pos(dmg.pos if "pos" in dmg else dmg.get("pos"))
			if dtype == "breach" and lights_enabled:
				var dist := drone_pos.distance_to(dpos)
				if dist <= 35.0:
					if dmg is Dictionary:
						dmg["revealed"] = true
						dmg["revealed_by"] = "light"
					else:
						dmg.revealed = true
						dmg.revealed_by = "light"
				elif dist <= 90.0:
					var to_dmg := (dpos - drone_pos).normalized()
					var forward := Vector2.from_angle(drone_heading)
					if absf(forward.angle_to(to_dmg)) <= 0.55:
						if dmg is Dictionary:
							dmg["revealed"] = true
							dmg["revealed_by"] = "light"
						else:
							dmg.revealed = true
							dmg.revealed_by = "light"
			elif dtype == "short_circuit" and scan_pulse_active:
				if drone_pos.distance_to(dpos) <= scan_pulse_radius:
					if dmg is Dictionary:
						dmg["revealed"] = true
						dmg["revealed_by"] = "radar"
					else:
						dmg.revealed = true
						dmg.revealed_by = "radar"
	
	if lights_enabled:
		drone_battery = maxf(0.0, drone_battery - 0.75 * delta)
	if scan_pulse_active:
		drone_battery = maxf(0.0, drone_battery - 3.5 * delta)
	if is_repairing:
		drone_battery = maxf(0.0, drone_battery - 6.0 * delta)
	
	if is_repairing and current_repair_target_id != "":
		var target_dmg: Dictionary = {}
		for dmg in ship_damages:
			var d_id: String = str(dmg.id if "id" in dmg else dmg.get("id", ""))
			if d_id == current_repair_target_id:
				target_dmg = dmg if dmg is Dictionary else (dmg.to_dict() if dmg.has_method("to_dict") else {})
				break
		if target_dmg.is_empty() or target_dmg.get("repaired") or drone_pos.distance_to(_parse_pos(target_dmg.get("pos"))) > 42.0 or drone_battery <= 0.0:
			is_repairing = false
			current_repair_target_id = ""
		else:
			var dur: float = maxf(1.0, float(target_dmg.get("repair_duration", 5.0)))
			var p: float = float(target_dmg.get("repair_progress", 0.0))
			p = clampf(p + (delta / dur), 0.0, 1.0)
			target_dmg["repair_progress"] = p
			current_repair_progress = p
			if p >= 1.0:
				target_dmg["repaired"] = true
				is_repairing = false
				current_repair_target_id = ""

func _on_ship_damages_updated(damages: Array) -> void:
	ship_damages = damages

func _on_ship_damage_discovered(damage: Variant) -> void:
	if status_summary_label:
		var dtype: String = str(damage.type if "type" in damage else damage.get("type", ""))
		var dsec: String = str(damage.sector if "sector" in damage else damage.get("sector", ""))
		var type_str := "BRECCIA nello scafo" if dtype == "breach" else "CORTOCIRCUITO elettrico"
		status_summary_label.text = "⚠️ Rilevato %s nel settore %s!" % [type_str, dsec]

func _on_ship_damage_repaired(damage: Variant) -> void:
	if status_summary_label:
		var dtype: String = str(damage.type if "type" in damage else damage.get("type", ""))
		var dsec: String = str(damage.sector if "sector" in damage else damage.get("sector", ""))
		var type_str := "Breccia" if dtype == "breach" else "Cortocircuito"
		status_summary_label.text = "✔ %s riparato con successo in %s!" % [type_str, dsec]

func _on_repair_state_changed(rep: bool, dmg_id: String, progress: float) -> void:
	is_repairing = rep
	current_repair_target_id = dmg_id
	current_repair_progress = progress

func _handle_movement(delta: float) -> void:
	if not is_control_active():
		_clear_button_highlights()
		if SpaceWorldManager:
			SpaceWorldManager.set_duct_drone_inputs(0.0, 0.0, _speed_multiplier)
		return
	
	# Raccogli input tastiera (WASD + Frecce) + UI
	var key_linear := 0.0
	var key_angular := 0.0
	
	var k_w := _is_key_down(KEY_W) or _is_key_down(KEY_UP)
	var k_s := _is_key_down(KEY_S) or _is_key_down(KEY_DOWN)
	var k_a := _is_key_down(KEY_A) or _is_key_down(KEY_LEFT)
	var k_d := _is_key_down(KEY_D) or _is_key_down(KEY_RIGHT)
	
	if k_w:
		key_linear += 1.0
	if k_s:
		key_linear -= 1.0
	if k_a:
		key_angular -= 1.0
	if k_d:
		key_angular += 1.0
	
	_linear_input = clampf(key_linear + _ui_linear_input, -1.0, 1.0)
	_angular_input = clampf(key_angular + _ui_angular_input, -1.0, 1.0)
	
	# Aggiorna evidenziazione visiva dei pulsanti UI
	_highlight_button(btn_forward, k_w or _ui_linear_input > 0)
	_highlight_button(btn_backward, k_s or _ui_linear_input < 0)
	_highlight_button(btn_rot_left, k_a or _ui_angular_input < 0)
	_highlight_button(btn_rot_right, k_d or _ui_angular_input > 0)
	
	if SpaceWorldManager:
		SpaceWorldManager.set_duct_drone_inputs(_linear_input, _angular_input, _speed_multiplier)
	else:
		_local_simulate_movement(delta)

func _local_simulate_movement(delta: float) -> void:
	# 1. Rotazione Tank (Gira sul posto a sinistra o destra)
	if absf(_angular_input) > 0.01:
		var rot_step := _angular_input * BASE_ROTATE_SPEED * _speed_multiplier * delta
		drone_heading += rot_step
		# Normalizza angolo tra -PI e +PI
		drone_heading = wrapf(drone_heading, -PI, PI)
	
	# 2. Spostamento Lineare (Avanti / Indietro nella direzione della prua)
	var target_speed := _linear_input * BASE_LINEAR_SPEED * _speed_multiplier
	drone_current_speed = target_speed
	if absf(_linear_input) > 0.01:
		# Consumo batteria dinamico
		drone_battery = maxf(5.0, drone_battery - 0.25 * delta * _speed_multiplier)
	
	if absf(drone_current_speed) > 0.1:
		var forward_dir := Vector2.from_angle(drone_heading)
		var movement := forward_dir * drone_current_speed * delta
		var new_pos := drone_pos + movement
		
		# Limita lo spostamento entro i confini navigabili della nave
		new_pos = _constrain_drone_movement(drone_pos, new_pos)
		drone_pos = new_pos
		_update_trail(drone_pos)
	else:
		# Lenta ricarica se vicino al punto iniziale (dock di ricarica)
		if drone_pos.distance_to(initial_drone_pos) < 30.0:
			drone_battery = minf(100.0, drone_battery + 8.0 * delta)

func _constrain_drone_movement(old_pos: Vector2, new_pos: Vector2) -> Vector2:
	# Controlla se la nuova posizione è valida all'interno di una stanza o condotto
	if _is_position_valid(new_pos):
		return new_pos
	
	# Tentativo di scorrimento su asse X
	var test_x := Vector2(new_pos.x, old_pos.y)
	if _is_position_valid(test_x):
		return test_x
	
	# Tentativo di scorrimento su asse Y
	var test_y := Vector2(old_pos.x, new_pos.y)
	if _is_position_valid(test_y):
		return test_y
	
	# Altrimenti blocca la posizione
	return old_pos

func _is_position_valid(pos: Vector2) -> bool:
	# Controlla se il punto è all'interno di una stanza
	for room in rooms:
		var r: Rect2 = room["rect"]
		# Margine di sicurezza interno per le stanze
		if r.grow(-2.0).has_point(pos):
			return true
	
	# Controlla se il punto è all'interno di un condotto
	for duct in ducts:
		var p1: Vector2 = duct["from"]
		var p2: Vector2 = duct["to"]
		var width: float = duct.get("width")
		var seg_dist := _distance_to_segment(pos, p1, p2)
		if seg_dist <= width * 0.8:
			return true
	
	return false

func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ab_len_sq := ab.length_squared()
	if ab_len_sq < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var projection := a + t * ab
	return p.distance_to(projection)

func _update_scan_pulse(delta: float) -> void:
	if scan_pulse_active:
		scan_pulse_radius += 180.0 * delta
		if scan_pulse_radius > 160.0:
			scan_pulse_active = false
			scan_pulse_radius = 0.0

func _update_sector_info() -> void:
	# Determina il settore o condotto attuale
	var found_sector := "Condotti di Servizio"
	
	for room in rooms:
		var r: Rect2 = room["rect"]
		if r.has_point(drone_pos):
			found_sector = room["name"]
			break
	
	if found_sector == "Condotti di Servizio":
		var closest_dist: float = 9999.0
		for duct in ducts:
			var from_pos: Vector2 = duct["from"]
			var to_pos: Vector2 = duct["to"]
			var d := _distance_to_segment(drone_pos, from_pos, to_pos)
			if d < closest_dist and d < 20.0:
				closest_dist = d
				found_sector = str(duct["name"])
	
	current_sector_name = found_sector

func _update_telemetry_ui() -> void:
	if pos_value_label:
		pos_value_label.text = "X: %4.1f | Y: %4.1f" % [drone_pos.x, drone_pos.y]
	
	if heading_value_label:
		var deg := int(rad_to_deg(drone_heading))
		var cardinal := _get_cardinal_direction(deg)
		heading_value_label.text = "%d° (%s)" % [deg, cardinal]
	
	if speed_value_label:
		speed_value_label.text = "%4.1f px/s" % absf(drone_current_speed)
	
	if sector_value_label:
		sector_value_label.text = current_sector_name
	
	if battery_progress_bar:
		battery_progress_bar.value = drone_battery
	
	if battery_label:
		battery_label.text = "%3.0f%%" % drone_battery

func _get_cardinal_direction(deg: int) -> String:
	# Con -90° = N, 0° = E, 90° = S, 180° = O
	var d := wrapf(deg, -180.0, 180.0)
	if d >= -112.5 and d < -67.5:
		return "N (Prua)"
	elif d >= -67.5 and d < -22.5:
		return "NE"
	elif d >= -22.5 and d < 22.5:
		return "E (Tribordo)"
	elif d >= 22.5 and d < 67.5:
		return "SE"
	elif d >= 67.5 and d < 112.5:
		return "S (Poppa)"
	elif d >= 112.5 and d < 157.5:
		return "SO"
	elif d >= -157.5 and d < -112.5:
		return "NO"
	else:
		return "O (Babordo)"

func _on_stop_pressed() -> void:
	_ui_linear_input = 0.0
	_ui_angular_input = 0.0
	_linear_input = 0.0
	_angular_input = 0.0
	drone_current_speed = 0.0
	if SpaceWorldManager:
		SpaceWorldManager.stop_duct_drone()

func _on_reset_pressed() -> void:
	_on_stop_pressed()
	drone_trail.clear()
	if SpaceWorldManager:
		SpaceWorldManager.reset_duct_drone()
	else:
		drone_pos = initial_drone_pos
		drone_heading = -PI * 0.5
		drone_battery = 100.0

func _on_speed_mode_toggle() -> void:
	_speed_mode_index = (_speed_mode_index + 1) % speed_modes.size()
	_speed_multiplier = speed_modes[_speed_mode_index]["mult"]
	_update_speed_mode_button()

func _update_speed_mode_button() -> void:
	if btn_speed_mode:
		var mode: Dictionary = speed_modes[_speed_mode_index]
		btn_speed_mode.text = "⚡ " + mode["name"]
		btn_speed_mode.modulate = mode["color"]

func _on_lights_toggle() -> void:
	if SpaceWorldManager:
		SpaceWorldManager.toggle_duct_drone_lights()
		lights_enabled = SpaceWorldManager.get_duct_drone_lights()
	else:
		lights_enabled = not lights_enabled
	_update_lights_button()

func _update_lights_button() -> void:
	if btn_lights_toggle:
		if lights_enabled:
			btn_lights_toggle.text = "💡 Fari: ON"
			btn_lights_toggle.modulate = Color(1.0, 0.9, 0.3)
		else:
			btn_lights_toggle.text = "💡 Fari: OFF"
			btn_lights_toggle.modulate = Color(0.6, 0.6, 0.6)

func _on_scan_pulse_pressed() -> void:
	if SpaceWorldManager:
		SpaceWorldManager.trigger_duct_drone_scan()
		scan_pulse_active = SpaceWorldManager.is_duct_drone_scan_active()
		scan_pulse_radius = SpaceWorldManager.get_duct_drone_scan_radius()
	else:
		scan_pulse_active = true
		scan_pulse_radius = 5.0

# Disegno personalizzato 2D dello schema nave, condotti e robottino
func draw_blueprint(canvas: Control) -> void:
	if not canvas or not is_instance_valid(canvas):
		return
	
	var canvas_size: Vector2 = canvas.size
	var scale_factor: float = minf(canvas_size.x / BLUEPRINT_SIZE.x, canvas_size.y / BLUEPRINT_SIZE.y)
	if scale_factor <= 0.001:
		scale_factor = 1.0
	var offset: Vector2 = (canvas_size - BLUEPRINT_SIZE * scale_factor) * 0.5
	
	var trans := Transform2D().translated(offset).scaled(Vector2(scale_factor, scale_factor))
	
	# 1. Griglia di sfondo Blueprint
	_draw_blueprint_grid(canvas, trans)
	
	# 2. Sagoma esterna dello Scafo Nave (Hull Silhouette)
	_draw_ship_hull(canvas, trans)
	
	# 3. Disegno Stanze Interne
	_draw_rooms(canvas, trans)
	
	# 4. Rete di Condotti (Ducts Network)
	_draw_ducts(canvas, trans)
	
	# 5. Danni Nave Rivelati (Brecce & Cortocircuiti)
	_draw_damages(canvas, trans)
	
	# 6. Scia di movimento del Robottino
	_draw_drone_trail(canvas, trans)
	
	# 7. Disegno Robottino e Fari
	_draw_robot(canvas, trans)
	
	# 8. Onda impulso sonar/scanner se attiva
	if scan_pulse_active:
		var p := trans * drone_pos
		var alpha := 1.0 - (scan_pulse_radius / 160.0)
		canvas.draw_arc(p, scan_pulse_radius * scale_factor, 0, TAU, 36, Color(0.2, 0.9, 1.0, alpha * 0.8), 2.0 * scale_factor, true)
		canvas.draw_circle(p, scan_pulse_radius * scale_factor * 0.5, Color(0.2, 0.9, 1.0, alpha * 0.12))
	
	# 9. Overlay Riparazione in Corso & Prompt Interazione
	_draw_repair_overlay(canvas, trans)

func _draw_damages(canvas: Control, trans: Transform2D) -> void:
	var s: float = trans.get_scale().x
	var font: Font = ThemeDB.fallback_font
	var time_now := Time.get_ticks_msec() * 0.003
	
	for dmg in ship_damages:
		var is_repaired: bool = bool(dmg.repaired if "repaired" in dmg else dmg.get("repaired", false))
		if is_repaired:
			# Disegna indicatore verde di danno risolto / riparato
			var pos_val: Vector2 = _parse_pos(dmg.pos if "pos" in dmg else dmg.get("pos"))
			var p: Vector2 = trans * pos_val
			canvas.draw_circle(p, 3.5 * s, Color(0.2, 0.8, 0.4, 0.3))
			canvas.draw_arc(p, 5.5 * s, 0, TAU, 16, Color(0.2, 0.9, 0.5, 0.6), 1.0 * s, true)
			continue
		
		var is_revealed: bool = bool(dmg.revealed if "revealed" in dmg else dmg.get("revealed", false))
		if not is_revealed:
			continue # Invisibile finché non scoperto tramite Luce o Radar
		
		var dmg_pos: Vector2 = _parse_pos(dmg.pos if "pos" in dmg else dmg.get("pos"))
		var p := trans * dmg_pos
		var dtype: String = str(dmg.type if "type" in dmg else dmg.get("type", ""))
		
		if dtype == "breach":
			# --- BRECCIA NELLO SCAFO / CONDOTTO (Arancione / Rosso allerta) ---
			var pulse := 0.7 + 0.3 * sin(time_now * 3.0)
			var base_col := Color(1.0, 0.35, 0.1, pulse)
			
			# Alone di allarme
			canvas.draw_circle(p, 9.0 * s, Color(1.0, 0.2, 0.05, 0.18 * pulse))
			canvas.draw_arc(p, 8.5 * s, 0, TAU, 20, base_col, 1.5 * s, true)
			
			# Disegno crepe / fratture scafo
			var crack1_start := p + Vector2(-6, -4) * s
			var crack1_mid := p + Vector2(1, -1) * s
			var crack1_end := p + Vector2(6, 5) * s
			canvas.draw_line(crack1_start, crack1_mid, Color(1.0, 0.8, 0.3, 0.95), 1.8 * s)
			canvas.draw_line(crack1_mid, crack1_end, Color(1.0, 0.3, 0.1, 0.95), 1.8 * s)
			
			var crack2_start := p + Vector2(-4, 4) * s
			var crack2_end := p + Vector2(4, -3) * s
			canvas.draw_line(crack2_start, crack2_end, Color(1.0, 0.6, 0.1, 0.9), 1.2 * s)
			
			# Etichetta identificativa
			canvas.draw_string(font, p + Vector2(-18 * s, -11 * s), "⚠ BRECCIA", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * s), Color(1.0, 0.5, 0.2, 0.95))
			
		elif dtype == "short_circuit":
			# --- CORTOCIRCUITO ELETTRICO (Ciano / Giallo fulmine) ---
			var spark_pulse := 0.6 + 0.4 * sin(time_now * 6.0)
			var cyan_col := Color(0.15, 0.9, 1.0, spark_pulse)
			
			# Alone campo elettromagnetico
			canvas.draw_circle(p, 8.0 * s, Color(0.1, 0.8, 1.0, 0.2 * spark_pulse))
			canvas.draw_arc(p, 7.5 * s, 0, TAU, 18, cyan_col, 1.2 * s, true)
			
			# Fulmine / scintilla elettrica saetta
			var bolt1 := p + Vector2(-2, -6) * s
			var bolt2 := p + Vector2(3, -1) * s
			var bolt3 := p + Vector2(-2, 1) * s
			var bolt4 := p + Vector2(2, 6) * s
			canvas.draw_line(bolt1, bolt2, Color(1.0, 1.0, 0.4, 0.95), 1.8 * s)
			canvas.draw_line(bolt2, bolt3, Color(0.3, 0.95, 1.0, 0.95), 1.8 * s)
			canvas.draw_line(bolt3, bolt4, Color(1.0, 1.0, 0.6, 0.95), 1.8 * s)
			
			canvas.draw_string(font, p + Vector2(-16 * s, -10 * s), "⚡ CORTO", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * s), Color(0.3, 0.95, 1.0, 0.95))

func _draw_repair_overlay(canvas: Control, trans: Transform2D) -> void:
	var s: float = trans.get_scale().x
	var font: Font = ThemeDB.fallback_font
	var drone_scr := trans * drone_pos
	
	if is_repairing and current_repair_target_id != "":
		var target_pos := Vector2.ZERO
		for dmg in ship_damages:
			var d_id: String = str(dmg.id if "id" in dmg else dmg.get("id", ""))
			if d_id == current_repair_target_id:
				target_pos = _parse_pos(dmg.pos if "pos" in dmg else dmg.get("pos"))
				break
		
		if target_pos != Vector2.ZERO:
			var dmg_scr := trans * target_pos
			
			# Raggio laser / arco voltaico di riparazione dal robottino al danno
			var beam_color := Color(0.3, 1.0, 0.7, 0.85)
			canvas.draw_line(drone_scr, dmg_scr, beam_color, 2.5 * s)
			canvas.draw_line(drone_scr, dmg_scr, Color(1.0, 1.0, 1.0, 0.95), 1.0 * s)
			
			# Scintille al punto di contatto
			canvas.draw_circle(dmg_scr, 5.0 * s, Color(0.5, 1.0, 0.8, 0.9))
			
			# Barra di caricamento circolare / ad arco sopra il danno
			var arc_radius := 14.0 * s
			var progress_angle := current_repair_progress * TAU
			canvas.draw_arc(dmg_scr, arc_radius, 0, TAU, 28, Color(0.2, 0.3, 0.4, 0.6), 3.0 * s, true)
			if progress_angle > 0.05:
				canvas.draw_arc(dmg_scr, arc_radius, -PI * 0.5, -PI * 0.5 + progress_angle, 28, Color(0.2, 1.0, 0.6, 0.95), 3.5 * s, true)
			
			var pct_text := "%d%%" % int(current_repair_progress * 100.0)
			canvas.draw_string(font, dmg_scr + Vector2(-10 * s, 22 * s), pct_text, HORIZONTAL_ALIGNMENT_CENTER, -1, int(10 * s), Color(0.3, 1.0, 0.7, 1.0))
			
	elif not nearby_damage.is_empty() and nearby_damage.get("revealed"):
		var near_pos: Vector2 = _parse_pos(nearby_damage.get("pos"))
		var dmg_scr: Vector2 = trans * near_pos
		var ring_radius := 14.0 * s
		canvas.draw_arc(dmg_scr, ring_radius, 0, TAU, 24, Color(0.2, 1.0, 0.6, 0.8), 1.5 * s, true)
		canvas.draw_string(font, dmg_scr + Vector2(-18 * s, 20 * s), "[E] RIPARA", HORIZONTAL_ALIGNMENT_CENTER, -1, int(9 * s), Color(0.4, 1.0, 0.6, 0.95))

func _draw_blueprint_grid(canvas: Control, trans: Transform2D) -> void:
	var grid_color := Color(0.08, 0.16, 0.25, 0.4)
	var step := 30.0
	
	for x in range(0, int(BLUEPRINT_SIZE.x), int(step)):
		var p1 := trans * Vector2(x, 0)
		var p2 := trans * Vector2(x, BLUEPRINT_SIZE.y)
		canvas.draw_line(p1, p2, grid_color, 1.0)
	
	for y in range(0, int(BLUEPRINT_SIZE.y), int(step)):
		var p1 := trans * Vector2(0, y)
		var p2 := trans * Vector2(BLUEPRINT_SIZE.x, y)
		canvas.draw_line(p1, p2, grid_color, 1.0)

func _draw_ship_hull(canvas: Control, trans: Transform2D) -> void:
	# Sagoma poligonale della nave da guerra Dark Nova
	var hull_points: PackedVector2Array = [
		Vector2(300, 20),   # Prua / Muso Cockpit
		Vector2(340, 45),
		Vector2(400, 70),   # Ala Comms
		Vector2(500, 110),
		Vector2(510, 170),
		Vector2(490, 200),
		Vector2(580, 225),  # Ala Esterna RCS DX
		Vector2(580, 300),
		Vector2(510, 305),
		Vector2(430, 310),  # Inizio Motori DX
		Vector2(420, 410),  # Propulsore DX
		Vector2(350, 425),  # Ugello Centrale DX
		Vector2(300, 430),  # Poppa Centro
		Vector2(250, 425),  # Ugello Centrale SX
		Vector2(180, 410),  # Propulsore SX
		Vector2(170, 310),  # Inizio Motori SX
		Vector2(90, 305),
		Vector2(20, 300),   # Ala Esterna RCS SX
		Vector2(20, 225),
		Vector2(110, 200),
		Vector2(90, 170),
		Vector2(100, 110),
		Vector2(200, 70),   # Ala Sensori
		Vector2(260, 45)
	]
	
	var transformed_hull: PackedVector2Array = []
	for pt in hull_points:
		transformed_hull.push_back(trans * pt)
	
	# Riempimento scafo trasparente scuro
	canvas.draw_colored_polygon(transformed_hull, Color(0.04, 0.08, 0.14, 0.85))
	
	# Bordo luminoso dello scafo
	for i in range(transformed_hull.size()):
		var p1: Variant = transformed_hull[i]
		var p2: Variant = transformed_hull[(i + 1) % transformed_hull.size()]
		canvas.draw_line(p1, p2, Color(0.25, 0.55, 0.85, 0.8), 2.0)

func _draw_rooms(canvas: Control, trans: Transform2D) -> void:
	for room in rooms:
		var r: Rect2 = room.get("rect", Rect2())
		var p1 := trans * r.position
		var p2 := trans * (r.position + r.size)
		var transformed_rect := Rect2(p1, p2 - p1)
		
		# Riempimento stanza
		var col: Color = room.get("color", Color(0.2, 0.4, 0.6, 0.5))
		canvas.draw_rect(transformed_rect, col)
		# Bordo stanza
		var bcol: Color = room.get("border_color", col.lightened(0.3))
		canvas.draw_rect(transformed_rect, bcol, false, 1.5)
		
		# Etichetta stanza
		var font: Font = ThemeDB.fallback_font
		var text_pos := p1 + Vector2(6, 14)
		canvas.draw_string(font, text_pos, str(room.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.8, 0.9, 1.0, 0.85))

func _draw_ducts(canvas: Control, trans: Transform2D) -> void:
	for duct in ducts:
		var from_pos: Vector2 = duct["from"]
		var to_pos: Vector2 = duct["to"]
		var p1: Vector2 = trans * from_pos
		var p2: Vector2 = trans * to_pos
		var w: float = float(duct.get("width", 14.0)) * trans.get_scale().x
		
		# Fondo condotto
		canvas.draw_line(p1, p2, Color(0.08, 0.22, 0.28, 0.95), w)
		# Bordo condotto (tubo neon)
		canvas.draw_line(p1, p2, Color(0.2, 0.8, 0.9, 0.75), w, false)
		# Linea centrale di scorrimento
		canvas.draw_line(p1, p2, Color(0.4, 1.0, 0.9, 0.4), 1.5)
		
		# Boccaporti / snodi alle estremità
		canvas.draw_circle(p1, w * 0.45, Color(0.25, 0.85, 1.0, 0.9))
		canvas.draw_circle(p2, w * 0.45, Color(0.25, 0.85, 1.0, 0.9))

func _draw_drone_trail(canvas: Control, trans: Transform2D) -> void:
	if drone_trail.size() < 2:
		return
	
	for i in range(1, drone_trail.size()):
		var p1 := trans * drone_trail[i - 1]
		var p2 := trans * drone_trail[i]
		var alpha := float(i) / float(drone_trail.size()) * 0.6
		canvas.draw_line(p1, p2, Color(0.3, 0.9, 1.0, alpha), 2.0)

func _draw_robot(canvas: Control, trans: Transform2D) -> void:
	var screen_pos := trans * drone_pos
	var s: float = trans.get_scale().x
	var forward := Vector2.from_angle(drone_heading)
	var right := Vector2(-forward.y, forward.x)
	
	# 1. Cono Luce / Fari se attivi
	if lights_enabled:
		var light_len := 75.0 * s
		var light_angle := 0.45 # radianti
		var l1 := screen_pos + Vector2.from_angle(drone_heading - light_angle) * light_len
		var l2 := screen_pos + Vector2.from_angle(drone_heading + light_angle) * light_len
		var light_poly: PackedVector2Array = [screen_pos, l1, l2]
		canvas.draw_colored_polygon(light_poly, Color(1.0, 0.95, 0.6, 0.18))
		canvas.draw_line(screen_pos, l1, Color(1.0, 0.95, 0.6, 0.35), 1.0)
		canvas.draw_line(screen_pos, l2, Color(1.0, 0.95, 0.6, 0.35), 1.0)
	
	# 2. Cingoli laterali del Robottino Tank
	var body_len := 12.0 * s
	var body_width := 8.0 * s
	var track_width := 2.5 * s
	
	# Cingolo Sinistro
	var t_left_center := screen_pos - right * (body_width * 0.8)
	var t_left_p1 := t_left_center - forward * (body_len * 0.9)
	var t_left_p2 := t_left_center + forward * (body_len * 0.9)
	canvas.draw_line(t_left_p1, t_left_p2, Color(0.2, 0.25, 0.3, 0.95), track_width)
	canvas.draw_line(t_left_p1, t_left_p2, Color(0.7, 0.8, 0.9, 0.8), 1.0)
	
	# Cingolo Destro
	var t_right_center := screen_pos + right * (body_width * 0.8)
	var t_right_p1 := t_right_center - forward * (body_len * 0.9)
	var t_right_p2 := t_right_center + forward * (body_len * 0.9)
	canvas.draw_line(t_right_p1, t_right_p2, Color(0.2, 0.25, 0.3, 0.95), track_width)
	canvas.draw_line(t_right_p1, t_right_p2, Color(0.7, 0.8, 0.9, 0.8), 1.0)
	
	# 3. Corpo Centrale Robottino
	var chassis_p1 := screen_pos - forward * (body_len * 0.7) - right * (body_width * 0.6)
	var chassis_p2 := screen_pos + forward * (body_len * 0.7) - right * (body_width * 0.6)
	var chassis_p3 := screen_pos + forward * (body_len * 0.7) + right * (body_width * 0.6)
	var chassis_p4 := screen_pos - forward * (body_len * 0.7) + right * (body_width * 0.6)
	var chassis_poly: PackedVector2Array = [chassis_p1, chassis_p2, chassis_p3, chassis_p4]
	canvas.draw_colored_polygon(chassis_poly, Color(0.9, 0.6, 0.1, 0.95))
	
	for i in range(chassis_poly.size()):
		canvas.draw_line(chassis_poly[i], chassis_poly[(i + 1) % chassis_poly.size()], Color(1.0, 0.85, 0.3, 1.0), 1.2)
	
	# 4. Cupola Sensore / Radar scanner
	canvas.draw_circle(screen_pos, 4.0 * s, Color(0.1, 0.3, 0.5, 1.0))
	canvas.draw_circle(screen_pos, 2.5 * s, Color(0.2, 0.9, 1.0, 1.0))
	
	# 5. Freccia Direzionale Prua (Tank Heading Arrow)
	var arrow_tip := screen_pos + forward * (body_len * 1.3)
	canvas.draw_line(screen_pos, arrow_tip, Color(1.0, 0.3, 0.2, 1.0), 2.0)
	canvas.draw_circle(arrow_tip, 2.0 * s, Color(1.0, 0.3, 0.2, 1.0))
