class_name CamsApp
extends BaseApp

## Applicazione GodotOS per il controllo e visualizzazione delle telecamere esterne (Cams).
## Conforme allo standard architetturale di bordo (APP_ARCHITECTURE_STANDARD.md).
## Supporta caricamento runtime e sincronizzazione attiva dei parametri ottici/sensori da file .dat protetti:
## - Ship Drive/Programs/Cams/cams_config.dat
## - Ship Drive/Programs/Cams/optics_tuning.dat

## Configurazione standard della finestra GodotOS
const APP_TITLE: String = "Cams - Controllo Telecamere Esterne"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(520, 500)

const CONFIG_PATH_PRIMARY: String = "Ship Drive/Programs/Cams/cams_config.dat"
const CONFIG_PATH_FALLBACK: String = "Ship Drive/Programs/Cam/cams_config.dat"
const TUNING_PATH_PRIMARY: String = "Ship Drive/Programs/Cams/optics_tuning.dat"
const TUNING_PATH_FALLBACK: String = "Ship Drive/Programs/Cam/optics_tuning.dat"

# Header e Indicatori di stato
@onready var status_summary_label: Label = get_node_or_null("%StatusSummaryLabel")
@onready var active_count_badge: Label = get_node_or_null("%ActiveCountBadge")
@onready var role_badge: Label = get_node_or_null("%RoleBadge")

# Configurazione .DAT e Ottiche
@onready var dat_status_badge: Label = get_node_or_null("%DatStatusBadge")
@onready var dat_config_summary_label: Label = get_node_or_null("%DatConfigSummaryLabel")
@onready var reload_config_button: Button = get_node_or_null("%ReloadConfigButton")

# Griglia pulsanti telecamere
@onready var buttons_grid: GridContainer = get_node_or_null("%ButtonsGrid")
@onready var btn_front: Button = get_node_or_null("%BtnFront")
@onready var btn_rear: Button = get_node_or_null("%BtnRear")
@onready var btn_left: Button = get_node_or_null("%BtnLeft")
@onready var btn_right: Button = get_node_or_null("%BtnRight")
@onready var btn_top: Button = get_node_or_null("%BtnTop")
@onready var btn_bottom: Button = get_node_or_null("%BtnBottom")

# Azioni globali
@onready var open_all_button: Button = get_node_or_null("%OpenAllButton")
@onready var close_all_button: Button = get_node_or_null("%CloseAllButton")
@onready var reset_optics_button: Button = get_node_or_null("%ResetOpticsButton")
@onready var disconnected_overlay: Control = get_node_or_null("%DisconnectedOverlay")

var cam_buttons: Dictionary = {} # cam_id (String) -> Button
var can_control_cams: bool = true

# Parametri runtime ottiche ed elaborate dai file .dat protetti
var active_config: Dictionary = {
	"default_fov": 75.0,
	"min_fov": 30.0,
	"max_fov": 100.0,
	"zoom_step": 10.0,
	"night_vision_intensity": 0.18,
	"tactical_hud_contrast": 0.18,
	"thermal_intensity": 0.22,
	"signal_boost": 1.0,
	"noise_reduction": 1.0,
	"refresh_rate_hz": 60.0,
	"crosshair_style": "STANDARD",
	"overclock_gain": 1.0,
	"is_dat_loaded": false
}

func _ready() -> void:
	_configure_window(APP_TITLE, DEFAULT_WINDOW_SIZE)
	_map_camera_buttons()
	_setup_ui_events()
	load_dat_configuration()
	_connect_system_signals()
	_update_connection_state()
	_update_permissions()
	_refresh_all_buttons_state()

func _setup_parent_window(_title: String, _size: Vector2) -> void:
	parent_window = _find_parent_window()
	if parent_window:
		parent_window.size = DEFAULT_WINDOW_SIZE
		parent_window.custom_minimum_size = Vector2(460, 420)
		parent_window.title_text = APP_TITLE
		var title_label = parent_window.get_node_or_null("Top Bar/Title Text")
		if title_label:
			title_label.text = "[center]" + APP_TITLE

func _find_parent_window() -> FakeWindow:
	var node: Node = get_parent()
	while node != null:
		if node is FakeWindow:
			return node
		node = node.get_parent()
	return null

func _map_camera_buttons() -> void:
	cam_buttons = {
		"front": btn_front,
		"rear": btn_rear,
		"left": btn_left,
		"right": btn_right,
		"top": btn_top,
		"bottom": btn_bottom
	}

func _setup_ui_events() -> void:
	for cam_id in cam_buttons:
		var btn: Button = cam_buttons[cam_id]
		if btn:
			btn.toggle_mode = true
			btn.toggled.connect(_on_button_toggled.bind(cam_id))
	
	if open_all_button:
		open_all_button.pressed.connect(_on_open_all_pressed)
	if close_all_button:
		close_all_button.pressed.connect(_on_close_all_pressed)
	if reset_optics_button:
		reset_optics_button.pressed.connect(_on_reset_optics_pressed)
	if reload_config_button:
		reload_config_button.pressed.connect(func() -> void:
			load_dat_configuration()
			var notif := get_node_or_null("/root/NotificationManager")
			if notif and notif.has_method("spawn_notification"):
				notif.spawn_notification("Configurazione Cams .DAT ricaricata.")
		)

func _connect_system_signals() -> void:
	if SpaceWorldManager:
		if not SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
		if not SpaceWorldManager.camera_status_changed.is_connected(_on_camera_status_changed):
			SpaceWorldManager.camera_status_changed.connect(_on_camera_status_changed)
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
	# Disconnessione pulita di tutti i segnali
	if SpaceWorldManager:
		if SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.disconnect(_on_ship_connection_changed)
		if SpaceWorldManager.camera_status_changed.is_connected(_on_camera_status_changed):
			SpaceWorldManager.camera_status_changed.disconnect(_on_camera_status_changed)
	if NetworkManager:
		if NetworkManager.player_role_changed.is_connected(_on_player_role_changed):
			NetworkManager.player_role_changed.disconnect(_on_player_role_changed)
	
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

func _on_ship_connection_changed(_is_connected: bool) -> void:
	_update_connection_state()
	_refresh_all_buttons_state()

func _on_ship_drive_mounted() -> void:
	load_dat_configuration()

func _on_file_synced(path: String) -> void:
	if path.begins_with("Ship Drive/Programs/Cams") or path.begins_with("Ship Drive/Programs/Cam"):
		load_dat_configuration()

func _update_connection_state() -> void:
	var op := is_operational()
	if disconnected_overlay:
		disconnected_overlay.visible = not op
	
	set_process(op)
	set_process_input(op)
	set_physics_process(op)
	
	if op:
		_update_permissions()
		load_dat_configuration()
	
	_update_status_summary()

func _on_player_role_changed(_peer_id: int, _new_role: String) -> void:
	_update_permissions()

## Gestione autorizzazioni basate sul Ruolo (RBAC)
func _update_permissions() -> void:
	var my_role := ""
	var is_solo := false
	if NetworkManager:
		my_role = NetworkManager.get_local_player_role()
		is_solo = NetworkManager.is_solo_mode
	
	# Controllo abilitato per Soldato, Capitano, Mozzo, Solo Mode o Ruolo non assegnato
	can_control_cams = (
		my_role == NetworkManager.ROLE_SOLDIER or
		my_role == NetworkManager.ROLE_CAPTAIN or
		my_role == NetworkManager.ROLE_MOZZO or
		my_role == "" or
		my_role == NetworkManager.ROLE_UNASSIGNED or
		is_solo
	)
	
	if role_badge:
		if is_solo:
			role_badge.text = "MODO: SOLO (FULL ACCESS)"
			role_badge.modulate = Color(0.4, 1.0, 0.6)
		elif not my_role.is_empty():
			role_badge.text = "RUOLO: %s" % my_role.to_upper()
			role_badge.modulate = Color(0.35, 0.85, 1.0)
		else:
			role_badge.text = "OPERATORE STANDARD"
			role_badge.modulate = Color(0.8, 0.8, 0.9)
	
	# Aggiorna abilitazione pulsanti
	var btns := [open_all_button, close_all_button, reset_optics_button, reload_config_button]
	for b in btns:
		if b:
			b.disabled = not can_control_cams
	
	for cid in cam_buttons:
		var btn: Button = cam_buttons[cid]
		if btn:
			btn.disabled = not can_control_cams

# ==============================================================================
# GESTIONE FILE .DAT DI CONFIGURAZIONE RUNTIME (APP_ARCHITECTURE_STANDARD.md)
# ==============================================================================

## Carica i parametri ottici attivi dai file .dat protetti in Ship Drive
func load_dat_configuration() -> Dictionary:
	var cfg_dict := _parse_dat_file(CONFIG_PATH_PRIMARY)
	if cfg_dict.is_empty():
		cfg_dict = _parse_dat_file(CONFIG_PATH_FALLBACK)
	
	var tuning_dict := _parse_dat_file(TUNING_PATH_PRIMARY)
	if tuning_dict.is_empty():
		tuning_dict = _parse_dat_file(TUNING_PATH_FALLBACK)
	
	var dat_found: bool = not cfg_dict.is_empty() or not tuning_dict.is_empty()
	
	if dat_found:
		if cfg_dict.has("default_fov"):
			active_config["default_fov"] = float(cfg_dict["default_fov"])
		if cfg_dict.has("min_fov"):
			active_config["min_fov"] = float(cfg_dict["min_fov"])
		if cfg_dict.has("max_fov"):
			active_config["max_fov"] = float(cfg_dict["max_fov"])
		if cfg_dict.has("zoom_step"):
			active_config["zoom_step"] = float(cfg_dict["zoom_step"])
		if cfg_dict.has("night_vision_intensity"):
			active_config["night_vision_intensity"] = float(cfg_dict["night_vision_intensity"])
		if cfg_dict.has("tactical_hud_contrast"):
			active_config["tactical_hud_contrast"] = float(cfg_dict["tactical_hud_contrast"])
		if cfg_dict.has("thermal_intensity"):
			active_config["thermal_intensity"] = float(cfg_dict["thermal_intensity"])
		
		if tuning_dict.has("signal_boost"):
			active_config["signal_boost"] = float(tuning_dict["signal_boost"])
		if tuning_dict.has("noise_reduction"):
			active_config["noise_reduction"] = float(tuning_dict["noise_reduction"])
		if tuning_dict.has("refresh_rate_hz"):
			active_config["refresh_rate_hz"] = float(tuning_dict["refresh_rate_hz"])
		if tuning_dict.has("overclock_gain"):
			active_config["overclock_gain"] = float(tuning_dict["overclock_gain"])
		if tuning_dict.has("crosshair_style"):
			active_config["crosshair_style"] = str(tuning_dict["crosshair_style"])
		
		active_config["is_dat_loaded"] = true
	else:
		active_config["is_dat_loaded"] = false
	
	_apply_configuration_to_cams()
	_update_config_ui()
	
	return active_config

## Applica attivamente i parametri di configurazione ai feed telecamera
func _apply_configuration_to_cams() -> void:
	if SpaceWorldManager:
		SpaceWorldManager.set_cams_config(active_config)

## Aggiorna la sezione informativa della configurazione .DAT nella UI
func _update_config_ui() -> void:
	if dat_status_badge:
		if active_config.get("is_dat_loaded"):
			dat_status_badge.text = "● .DAT ATTIVO"
			dat_status_badge.modulate = Color(0.3, 1.0, 0.5)
		else:
			dat_status_badge.text = "○ CALIBRAZIONE STD"
			dat_status_badge.modulate = Color(0.7, 0.8, 1.0, 0.8)
	
	if dat_config_summary_label:
		var fov_d: float = active_config.get("default_fov")
		var fov_min: float = active_config.get("min_fov")
		var fov_max: float = active_config.get("max_fov")
		var z_step: float = active_config.get("zoom_step")
		var sig_b: float = active_config.get("signal_boost")
		var oc: float = active_config.get("overclock_gain")
		
		var oc_str := " | OC: %.1fx" % oc if oc != 1.0 else ""
		dat_config_summary_label.text = "FOV: %.0f° (Range: %.0f°-%.0f°, Step: %.0f°) | Boost: %.1fx%s" % [
			fov_d, fov_min, fov_max, z_step, sig_b, oc_str
		]

## Parsifica un file .dat formato INI/Key-Value
func _on_button_toggled(toggled_on: bool, cam_id: String) -> void:
	if not SpaceWorldManager or not SpaceWorldManager.is_ship_connected():
		if cam_buttons.has(cam_id) and cam_buttons[cam_id]:
			cam_buttons[cam_id].set_pressed_no_signal(false)
		return
	
	var is_open: bool = SpaceWorldManager.is_camera_window_open(cam_id)
	
	if toggled_on and not is_open:
		SpaceWorldManager.open_camera_window(cam_id)
	elif not toggled_on and is_open:
		SpaceWorldManager.close_camera_window(cam_id)
	
	_update_button_visual(cam_id, toggled_on)
	_update_status_summary()

func _on_camera_status_changed(cam_id: String, is_open: bool) -> void:
	if cam_buttons.has(cam_id):
		var btn: Button = cam_buttons[cam_id]
		if btn and btn.button_pressed != is_open:
			btn.set_pressed_no_signal(is_open)
			_update_button_visual(cam_id, is_open)
	
	_update_status_summary()

func _refresh_all_buttons_state() -> void:
	if not SpaceWorldManager:
		return
	
	var connected: bool = SpaceWorldManager.is_ship_connected()
	
	for cam_id in cam_buttons:
		var btn: Button = cam_buttons[cam_id]
		var is_open: bool = SpaceWorldManager.is_camera_window_open(cam_id) if connected else false
		if btn:
			btn.set_pressed_no_signal(is_open)
			_update_button_visual(cam_id, is_open)
	
	_update_status_summary()

func _update_button_visual(cam_id: String, is_active: bool) -> void:
	if not cam_buttons.has(cam_id):
		return
	
	var btn: Button = cam_buttons[cam_id]
	if btn == null:
		return
	
	var info: Dictionary = SpaceWorldManager.get_camera_info(cam_id) if SpaceWorldManager else {}
	var name_str: String = info.get("name")
	var dir_str: String = info.get("direction")
	var icon_str: String = info.get("icon")
	
	if is_active:
		btn.text = "%s %s\n[%s]  ● ATTIVA" % [icon_str, name_str.to_upper(), dir_str]
		btn.modulate = Color(0.4, 1.0, 0.6)
	else:
		btn.text = "%s %s\n[%s]  ○ SPENTA" % [icon_str, name_str.to_upper(), dir_str]
		btn.modulate = Color(1.0, 1.0, 1.0)

func _update_status_summary() -> void:
	var connected := SpaceWorldManager.is_ship_connected() if SpaceWorldManager else false
	var active_count: int = 0
	if SpaceWorldManager and connected:
		for cam_id in cam_buttons:
			if SpaceWorldManager.is_camera_window_open(cam_id):
				active_count += 1
	
	if active_count_badge:
		if not connected:
			active_count_badge.text = "OFFLINE"
			active_count_badge.modulate = Color(1.0, 0.4, 0.4)
		else:
			active_count_badge.text = "%d / 6 ATTIVI" % active_count
			if active_count > 0:
				active_count_badge.modulate = Color(0.3, 1.0, 0.5)
			else:
				active_count_badge.modulate = Color(0.7, 0.7, 0.7)
	
	if status_summary_label:
		if not connected:
			status_summary_label.text = "Connettersi alla nave tramite l'applicazione Lobby per attivare le telecamere."
			status_summary_label.modulate = Color(1.0, 0.75, 0.3)
		elif active_count == 6:
			status_summary_label.text = "Copertura visiva 360° completa (Tutti i 6 feed attivi)."
			status_summary_label.modulate = Color(0.65, 0.75, 0.85, 0.8)
		elif active_count > 0:
			status_summary_label.text = "Visualizzazione feed telecamere in finestre separate."
			status_summary_label.modulate = Color(0.65, 0.75, 0.85, 0.8)
		else:
			status_summary_label.text = "Nessuna telecamera attiva. Premi un pulsante per aprire il feed."
			status_summary_label.modulate = Color(0.65, 0.75, 0.85, 0.8)

func _on_open_all_pressed() -> void:
	if not SpaceWorldManager or not SpaceWorldManager.is_ship_connected():
		return
	SpaceWorldManager.open_all_camera_windows()
	_refresh_all_buttons_state()

func _on_close_all_pressed() -> void:
	if not SpaceWorldManager:
		return
	SpaceWorldManager.close_all_camera_windows()
	_refresh_all_buttons_state()

func _on_reset_optics_pressed() -> void:
	if not SpaceWorldManager or not SpaceWorldManager.is_ship_connected():
		return
	load_dat_configuration()
	for cam_id in cam_buttons:
		var win = SpaceWorldManager.get_camera_window(cam_id)
		if win and is_instance_valid(win) and win.has_method("_on_zoom_reset_pressed"):
			win._on_zoom_reset_pressed()
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("Ottiche telecamere reimpostate ai valori predefiniti.")
