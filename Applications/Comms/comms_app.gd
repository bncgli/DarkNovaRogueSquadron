class_name CommsApp
extends BaseApp

## Applicazione GodotOS per le Comunicazioni Subspaziali, Antenna Direzionale e Intrusione EW.
## Conforme allo standard architetturale di bordo (APP_ARCHITECTURE_STANDARD.md).
## Task TASK-036.

const APP_TITLE: String = "Communications & Directional Antenna Array"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(680, 510)
const MIN_WINDOW_SIZE: Vector2 = Vector2(680, 510)

signal docking_clearance_requested(station_id: String)
signal docking_clearance_granted(station_id: String, bay_id: int)
signal docking_clearance_denied(station_id: String, reason: String)
signal docking_completed(station_id: String, bay_id: int)

const CONFIG_PATH_PRIMARY: String = "Ship Drive/Programs/Comms/comms_config.dat"
const CONFIG_PATH_FALLBACK: String = "Terminal Drive/Programs/Comms/comms_config.dat"
const TUNING_PATH_PRIMARY: String = "Ship Drive/Programs/Comms/crypto_tuning.dat"
const TUNING_PATH_FALLBACK: String = "Terminal Drive/Programs/Comms/crypto_tuning.dat"

# --- RIFERIMENTI NODI UI ---
@onready var disconnected_overlay: Control = get_node_or_null("%DisconnectedOverlay")
@onready var status_badge: Label = get_node_or_null("%StatusBadge")
@onready var role_badge: Label = get_node_or_null("%RoleBadge")
@onready var power_badge: Label = get_node_or_null("%PowerBadge")
@onready var dat_status_badge: Label = get_node_or_null("%DatStatusBadge")
@onready var reload_dat_button: Button = get_node_or_null("%ReloadDatButton")

# Waterfall & Sintonizzatore
@onready var waterfall_canvas: CommsWaterfallCanvas = get_node_or_null("%WaterfallCanvas")
@onready var freq_slider: HSlider = get_node_or_null("%FreqSlider")
@onready var freq_value_label: Label = get_node_or_null("%FreqValueLabel")
@onready var signal_lock_badge: Label = get_node_or_null("%SignalLockBadge")
@onready var signal_info_label: Label = get_node_or_null("%SignalInfoLabel")
@onready var btn_tune_sos: Button = get_node_or_null("%BtnTuneSos")
@onready var btn_tune_subspace: Button = get_node_or_null("%BtnTuneSubspace")
@onready var btn_tune_pirate: Button = get_node_or_null("%BtnTunePirate")
@onready var btn_listen_signal: Button = get_node_or_null("%BtnListenSignal")

# Settore Sinistro: Controlli Antenna Direzionale
@onready var antenna_sector: PanelContainer = get_node_or_null("%AntennaSector")
@onready var antenna_heading_slider: HSlider = get_node_or_null("%AntennaHeadingSlider")
@onready var antenna_heading_value: Label = get_node_or_null("%AntennaHeadingValue")
@onready var btn_auto_rotate: Button = get_node_or_null("%BtnAutoRotate")
@onready var btn_freq_lock: Button = get_node_or_null("%BtnFreqLock")
@onready var antenna_status_label: Label = get_node_or_null("%AntennaStatusLabel")
@onready var antenna_gain_label: Label = get_node_or_null("%AntennaGainLabel")

# Settore Destro: Ricezione & Interazione Frequenza
@onready var signal_interaction_sector: PanelContainer = get_node_or_null("%SignalInteractionSector")
@onready var signal_detail_label: RichTextLabel = get_node_or_null("%SignalDetailLabel")
@onready var station_actions_box: Container = get_node_or_null("%StationActionsBox")
@onready var btn_request_docking: Button = get_node_or_null("%BtnRequestDocking")
@onready var btn_station_emergency: Button = get_node_or_null("%BtnStationEmergency")
@onready var btn_station_trade: Button = get_node_or_null("%BtnStationTrade")
@onready var btn_connect_drive: Button = get_node_or_null("%BtnConnectDrive")

# Registro Comunicazioni & Log
@onready var comms_log_text: RichTextLabel = get_node_or_null("%CommsLogText")
@onready var btn_clear_log: Button = get_node_or_null("%BtnClearLog")
@onready var action_log_label: Label = get_node_or_null("%ActionLogLabel")

# --- STATO OPERATIVO E PARAMETRI RUNTIME ---
var current_frequency: float = 1420.0
var antenna_azimuth_deg: float = 0.0 # 0..360 gradi
var is_auto_rotating: bool = false
var auto_rotate_speed: float = 45.0 # gradi/sec
var is_frequency_locked: bool = false
var locked_signal_id: String = ""

var can_control_comms: bool = true
var is_comms_powered: bool = true

# Parametri .DAT attivi con fallback ai valori di default
var active_config: Dictionary = {
	"bandwidth_hz": 1420.0,
	"antenna_gain": 1.0,
	"auto_rotate_speed": 45.0,
	"reception_cone_deg": 25.0,
	"subspace_relay_active": true,
	"auto_tune_sos": true,
	"signal_amplification": 1.2,
	"signal_noise_ratio": 0.85,
	"decryption_speed_multiplier": 1.0,
	"jamming_power_mw": 120.0,
	"spoofing_signature": "CORVETTE_CIVILIAN",
	"jamming_radius": 15000.0,
	"overclock_ew_boost": 1.0,
	"crypto_crack_speed": 1.0,
	"is_dat_loaded": false
}

# Database trasmissioni subspaziali intercettabili
var available_signals: Array[Dictionary] = [
	{
		"id": "sos_scout",
		"freq": 850.5,
		"strength": 0.95,
		"name": "📡 [SOS EMERGENZA] Relitto Vascello Scout",
		"desc": "Richiesta soccorso da corvetta derelitta in avaria. Coordinate settore 4.",
		"source": "Beacon Automatico Mayday",
		"bearing_deg": 45.0,
		"distance": 650.0,
		"type": "DERELICT",
		"target_ship_id": "SCOUT-DERELICT-04",
		"unlocked": true
	},
	{
		"id": "subspace_corp",
		"freq": 1420.0,
		"strength": 0.9,
		"name": "🌐 [RETE SUBSPAZIALE] Weyland-Yutani Corp Relay",
		"desc": "Bollettino commerciale e direttive corporative di settore. Canale idrogeno attivo.",
		"source": "Mainframe Subspazio",
		"bearing_deg": 180.0,
		"distance": 3200.0,
		"type": "RELAY",
		"unlocked": true
	},
	{
		"id": "station_trading",
		"freq": 1840.0,
		"strength": 0.85,
		"name": "📻 [CANALE CIVILE] Stazione Spaziale Freccia",
		"desc": "Aggiornamento prezzi combustibile e disponibilità baia d'attracco.",
		"source": "Torre di Controllo Freccia",
		"bearing_deg": 270.0,
		"distance": 1100.0,
		"type": "STATION",
		"station_id": "STATION-FRECCIA",
		"unlocked": true
	},
	{
		"id": "pirate_encrypted",
		"freq": 2185.2,
		"strength": 0.80,
		"name": "🏴‍☠️ [BURST CRITTOGRAFATO] Canale Pirata Clandestino",
		"desc": "Trasmissione da corvetta da guerra corsara. Intercettazione telemetria e drive bersaglio.",
		"source": "Predoni della Cintura",
		"bearing_deg": 120.0,
		"distance": 950.0,
		"type": "CORVETTE",
		"target_ship_id": "PIRATE-CORVETTE-01",
		"unlocked": true
	},
	{
		"id": "deep_space_beacon",
		"freq": 2750.0,
		"strength": 0.6,
		"name": "🛰️ [RADIONAVIGAZIONE] Faro Deep Space Alpha",
		"desc": "Sincronizzazione orologio atomico e dati gravitazionali di settore.",
		"source": "Faro Navigazione Stella 78",
		"bearing_deg": 315.0,
		"distance": 4500.0,
		"type": "BEACON",
		"unlocked": true
	}
]

func _ready() -> void:
	_configure_window(APP_TITLE, DEFAULT_WINDOW_SIZE, MIN_WINDOW_SIZE)
	_connect_system_signals()
	_setup_ui_signals()
	_update_connection_state()
	load_dat_configuration()
	_update_permissions()
	_refresh_signals()
	_refresh_ui_display()
	_log_comms_message("[color=#64c8ff][SISTEMA][/color] Suite Ricezione Comms & Antenna Direzionale inizializzata.")

func _connect_system_signals() -> void:
	if SpaceWorldManager:
		if SpaceWorldManager.has_signal("ship_connection_changed") and not SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
	
	if NetworkManager:
		if NetworkManager.has_signal("player_role_changed") and not NetworkManager.player_role_changed.is_connected(_on_player_role_changed):
			NetworkManager.player_role_changed.connect(_on_player_role_changed)
		if NetworkManager.has_signal("mission_started") and not NetworkManager.mission_started.is_connected(_on_mission_started):
			NetworkManager.mission_started.connect(_on_mission_started)
		if NetworkManager.has_signal("mission_ended") and not NetworkManager.mission_ended.is_connected(_on_mission_ended):
			NetworkManager.mission_ended.connect(_on_mission_ended)
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm:
		if sdm.has_signal("file_synced") and not sdm.file_synced.is_connected(_on_drive_file_modified):
			sdm.file_synced.connect(_on_drive_file_modified)
		if sdm.has_signal("file_modified") and not sdm.file_modified.is_connected(_on_drive_file_modified):
			sdm.file_modified.connect(_on_drive_file_modified)
		if sdm.has_signal("file_written") and not sdm.file_written.is_connected(_on_drive_file_written):
			sdm.file_written.connect(_on_drive_file_written)

func _setup_ui_signals() -> void:
	if reload_dat_button and not reload_dat_button.pressed.is_connected(load_dat_configuration):
		reload_dat_button.pressed.connect(load_dat_configuration)
	
	if freq_slider and not freq_slider.value_changed.is_connected(_on_freq_slider_changed):
		freq_slider.value_changed.connect(_on_freq_slider_changed)
	
	if btn_tune_sos and not btn_tune_sos.pressed.is_connected(_on_btn_tune_sos_pressed):
		btn_tune_sos.pressed.connect(_on_btn_tune_sos_pressed)
	
	if btn_tune_subspace and not btn_tune_subspace.pressed.is_connected(_on_btn_tune_subspace_pressed):
		btn_tune_subspace.pressed.connect(_on_btn_tune_subspace_pressed)
	
	if btn_tune_pirate and not btn_tune_pirate.pressed.is_connected(_on_btn_tune_pirate_pressed):
		btn_tune_pirate.pressed.connect(_on_btn_tune_pirate_pressed)
	
	if btn_listen_signal and not btn_listen_signal.pressed.is_connected(_on_btn_listen_signal_pressed):
		btn_listen_signal.pressed.connect(_on_btn_listen_signal_pressed)
	
	if antenna_heading_slider and not antenna_heading_slider.value_changed.is_connected(_on_antenna_heading_changed):
		antenna_heading_slider.value_changed.connect(_on_antenna_heading_changed)
	
	if btn_auto_rotate and not btn_auto_rotate.toggled.is_connected(_on_btn_auto_rotate_toggled):
		btn_auto_rotate.toggled.connect(_on_btn_auto_rotate_toggled)
	
	if btn_freq_lock and not btn_freq_lock.toggled.is_connected(_on_btn_freq_lock_toggled):
		btn_freq_lock.toggled.connect(_on_btn_freq_lock_toggled)
	
	if btn_request_docking and not btn_request_docking.pressed.is_connected(_on_btn_request_docking_pressed):
		btn_request_docking.pressed.connect(_on_btn_request_docking_pressed)
	
	if btn_station_emergency and not btn_station_emergency.pressed.is_connected(_on_btn_station_emergency_pressed):
		btn_station_emergency.pressed.connect(_on_btn_station_emergency_pressed)
	
	if btn_station_trade and not btn_station_trade.pressed.is_connected(_on_btn_station_trade_pressed):
		btn_station_trade.pressed.connect(_on_btn_station_trade_pressed)
	
	if btn_connect_drive and not btn_connect_drive.pressed.is_connected(_on_connect_drive_pressed):
		btn_connect_drive.pressed.connect(_on_connect_drive_pressed)
	
	if btn_clear_log and not btn_clear_log.pressed.is_connected(_on_btn_clear_log_pressed):
		btn_clear_log.pressed.connect(_on_btn_clear_log_pressed)

func _exit_tree() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_signal("ship_connection_changed") and SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
		SpaceWorldManager.ship_connection_changed.disconnect(_on_ship_connection_changed)
	
	if NetworkManager:
		if NetworkManager.has_signal("player_role_changed") and NetworkManager.player_role_changed.is_connected(_on_player_role_changed):
			NetworkManager.player_role_changed.disconnect(_on_player_role_changed)
		if NetworkManager.has_signal("mission_started") and NetworkManager.mission_started.is_connected(_on_mission_started):
			NetworkManager.mission_started.disconnect(_on_mission_started)
		if NetworkManager.has_signal("mission_ended") and NetworkManager.mission_ended.is_connected(_on_mission_ended):
			NetworkManager.mission_ended.disconnect(_on_mission_ended)
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm:
		if sdm.has_signal("file_synced") and sdm.file_synced.is_connected(_on_drive_file_modified):
			sdm.file_synced.disconnect(_on_drive_file_modified)
		if sdm.has_signal("file_modified") and sdm.file_modified.is_connected(_on_drive_file_modified):
			sdm.file_modified.disconnect(_on_drive_file_modified)
		if sdm.has_signal("file_written") and sdm.file_written.is_connected(_on_drive_file_written):
			sdm.file_written.disconnect(_on_drive_file_written)

func _process(delta: float) -> void:
	if not _is_ship_operational():
		return
	
	_refresh_signals()
	
	# 1. Auto-rotazione continua antenna a 360°
	if is_auto_rotating and not is_frequency_locked:
		antenna_azimuth_deg = fmod(antenna_azimuth_deg + auto_rotate_speed * delta, 360.0)
		if antenna_azimuth_deg < 0.0:
			antenna_azimuth_deg += 360.0
		if antenna_heading_slider:
			antenna_heading_slider.set_value_no_signal(antenna_azimuth_deg)
		if antenna_heading_value:
			antenna_heading_value.text = "%03d°" % int(antenna_azimuth_deg)
		_refresh_antenna_ui()
		_refresh_tuner_state()
	
	# 2. Tracking bersaglio attivo con Frequency Lock
	elif is_frequency_locked and not locked_signal_id.is_empty():
		var target_bearing := _get_signal_bearing_by_id(locked_signal_id)
		if target_bearing >= 0.0:
			var diff := fposmod(target_bearing - antenna_azimuth_deg + 180.0, 360.0) - 180.0
			var step := signf(diff) * minf(absf(diff), auto_rotate_speed * 2.0 * delta)
			antenna_azimuth_deg = fposmod(antenna_azimuth_deg + step, 360.0)
			if antenna_heading_slider:
				antenna_heading_slider.set_value_no_signal(antenna_azimuth_deg)
			if antenna_heading_value:
				antenna_heading_value.text = "%03d°" % int(antenna_azimuth_deg)
			_refresh_antenna_ui()
			_refresh_tuner_state()

# --- GESTIONE DELLO STATO OPERATIVO / CONNESSIONE ---
func _is_ship_operational() -> bool:
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		return SpaceWorldManager.is_ship_connected()
	if NetworkManager and NetworkManager.has_method("is_ship_connected"):
		return NetworkManager.is_ship_connected()
	return false

func _on_ship_connection_changed(_is_connected: bool) -> void:
	_update_connection_state()

func _on_mission_started(_role: String = "", _is_solo: bool = false) -> void:
	_update_connection_state()
	_update_permissions()
	_refresh_ui_display()

func _on_mission_ended() -> void:
	_update_connection_state()

func _update_connection_state() -> void:
	var operational := _is_ship_operational()
	
	if disconnected_overlay:
		disconnected_overlay.visible = not operational
	
	set_process(operational)
	set_process_input(operational)
	
	if waterfall_canvas:
		waterfall_canvas.set_operational(operational)
	
	_refresh_ui_display()

# --- GESTIONE AUTORIZZAZIONI RBAC ---
func _on_player_role_changed(_peer_id: int, _new_role: String) -> void:
	_update_permissions()
	_refresh_ui_display()

func _update_permissions() -> void:
	var my_role := ""
	var is_solo := true
	if NetworkManager:
		my_role = NetworkManager.get_local_player_role()
		is_solo = NetworkManager.is_solo_mode
	
	var role_lower := my_role.to_lower()
	if not my_role.is_empty():
		can_control_comms = role_lower in ["hacker", "capitano", "captain", "stagista", "admin", "host"]
	else:
		can_control_comms = is_solo
	
	# Sintonizzatore
	if freq_slider:
		freq_slider.editable = can_control_comms
	if btn_tune_sos:
		btn_tune_sos.disabled = not can_control_comms
	if btn_tune_subspace:
		btn_tune_subspace.disabled = not can_control_comms
	if btn_tune_pirate:
		btn_tune_pirate.disabled = not can_control_comms
	if btn_listen_signal:
		btn_listen_signal.disabled = not can_control_comms
	
	# Antenna Direzionale
	if antenna_heading_slider:
		antenna_heading_slider.editable = can_control_comms
	if btn_auto_rotate:
		btn_auto_rotate.disabled = not can_control_comms
	if btn_freq_lock:
		btn_freq_lock.disabled = not can_control_comms
	
	# Azioni e Connessione
	if btn_request_docking:
		btn_request_docking.disabled = not can_control_comms
	if btn_station_emergency:
		btn_station_emergency.disabled = not can_control_comms
	if btn_station_trade:
		btn_station_trade.disabled = not can_control_comms

# --- GESTIONE FILE .DAT & HOT-RELOADING ---
func _on_drive_file_modified(rel_path: String) -> void:
	if "Programs/Comms" in rel_path and rel_path.ends_with(".dat"):
		load_dat_configuration()

func _on_drive_file_written(rel_path: String, _content: String) -> void:
	if "Programs/Comms" in rel_path and rel_path.ends_with(".dat"):
		load_dat_configuration()

func load_dat_configuration() -> void:
	var cfg_dict := _parse_dat_file(CONFIG_PATH_PRIMARY)
	if cfg_dict.is_empty():
		cfg_dict = _parse_dat_file(CONFIG_PATH_FALLBACK)
	
	var tuning_dict := _parse_dat_file(TUNING_PATH_PRIMARY)
	if tuning_dict.is_empty():
		tuning_dict = _parse_dat_file(TUNING_PATH_FALLBACK)
	
	var loaded_any := false
	for k in cfg_dict.keys():
		active_config[k] = cfg_dict[k]
		loaded_any = true
	
	for k in tuning_dict.keys():
		active_config[k] = tuning_dict[k]
		loaded_any = true
	
	active_config["is_dat_loaded"] = loaded_any
	_apply_configuration()

func _apply_configuration() -> void:
	auto_rotate_speed = float(active_config.get("auto_rotate_speed", 45.0))
	_refresh_ui_display()
	_update_action_log("Configurazione .DAT ricaricata con successo.")

# --- SINTONIZZATORE FREQUENZE & CONTROLLI TUNER ---
func _on_freq_slider_changed(new_val: float) -> void:
	current_frequency = new_val
	if is_frequency_locked:
		var sig: Variant = _get_locked_signal()
		if sig != null:
			locked_signal_id = str(sig.get("id", ""))
		else:
			locked_signal_id = ""
	_refresh_tuner_state()

func _on_btn_tune_sos_pressed() -> void:
	if not can_control_comms:
		return
	current_frequency = 850.5
	if freq_slider:
		freq_slider.value = current_frequency
	if is_frequency_locked:
		locked_signal_id = "sos_scout"
	_refresh_tuner_state()
	_update_action_log("Sintonizzato automaticamente su frequenza SOS di emergenza (850.5 MHz).")

func _on_btn_tune_subspace_pressed() -> void:
	if not can_control_comms:
		return
	current_frequency = 1420.0
	if freq_slider:
		freq_slider.value = current_frequency
	if is_frequency_locked:
		locked_signal_id = "subspace_corp"
	_refresh_tuner_state()
	_update_action_log("Sintonizzato su Relay Subspaziale Principale (1420.0 MHz).")

func _on_btn_tune_pirate_pressed() -> void:
	if not can_control_comms:
		return
	current_frequency = 2185.2
	if freq_slider:
		freq_slider.value = current_frequency
	if is_frequency_locked:
		locked_signal_id = "pirate_encrypted"
	_refresh_tuner_state()
	_update_action_log("Sintonizzato su Canale Pirata Clandestino (2185.2 MHz).")

func _on_btn_listen_signal_pressed() -> void:
	if not can_control_comms:
		return
	var sig: Variant = _get_locked_signal()
	if sig != null:
		var eff_strength := get_effective_signal_strength(sig)
		if eff_strength < 0.2:
			_log_comms_message("[color=#ff5555][RICEZIONE][/color] Segnale troppo degradato o fuori puntamento antenna per la trascrizione.")
			_update_action_log("Trascrizione fallita: allineare l'antenna.")
			return
		_log_comms_message("[color=#ffdd55][RICEZIONE][/color] %s: %s (Fonte: %s, SNR: %.0f%%)" % [str(sig.get("name", "Segnale")), str(sig.get("desc", "")), str(sig.get("source", "Ignota")), eff_strength * 100.0])
		_update_action_log("Messaggio trascritto nel registro di bordo.")

func _get_locked_signal() -> Variant:
	for sig in available_signals:
		var sig_freq: float = float(sig.get("freq", 0.0))
		if absf(current_frequency - sig_freq) <= 15.0:
			return sig
	return null

func _refresh_signals() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_method("get_comms_transmissions"):
		var live_transmissions: Array[Dictionary] = SpaceWorldManager.get_comms_transmissions()
		if not live_transmissions.is_empty():
			available_signals = live_transmissions

# --- CALCOLI ANTENNA DIREZIONALE & MATEMATICA SEGNALE ---
func get_angular_difference(a_deg: float, b_deg: float) -> float:
	var diff := fposmod(a_deg - b_deg + 180.0, 360.0) - 180.0
	return absf(diff)

func _get_signal_bearing(sig: Dictionary) -> float:
	if sig.has("bearing_deg"):
		return float(sig.get("bearing_deg", 0.0))
	
	var sig_id: String = str(sig.get("id", ""))
	var target_id: String = str(sig.get("target_ship_id", sig.get("station_id", sig_id)))
	
	if SpaceWorldManager and SpaceWorldManager.has_method("get_sensor_entities"):
		var entities: Array[Dictionary] = SpaceWorldManager.get_sensor_entities()
		for e in entities:
			var e_id: String = str(e.get("id", ""))
			if e_id == target_id or e_id == sig_id:
				var raw_bearing: float = float(e.get("bearing_deg", 0.0))
				return fposmod(raw_bearing, 360.0)
	
	return 0.0

func _get_signal_distance(sig: Dictionary) -> float:
	if sig.has("distance"):
		return float(sig.get("distance", 1000.0))
	
	var sig_id: String = str(sig.get("id", ""))
	var target_id: String = str(sig.get("target_ship_id", sig.get("station_id", sig_id)))
	
	if SpaceWorldManager and SpaceWorldManager.has_method("get_sensor_entities"):
		var entities: Array[Dictionary] = SpaceWorldManager.get_sensor_entities()
		for e in entities:
			var e_id: String = str(e.get("id", ""))
			if e_id == target_id or e_id == sig_id:
				return float(e.get("distance", 1000.0))
	
	return 1000.0

func _get_signal_bearing_by_id(sig_id: String) -> float:
	for sig in available_signals:
		if str(sig.get("id", "")) == sig_id:
			return _get_signal_bearing(sig)
	return -1.0

func get_effective_signal_strength(sig: Dictionary) -> float:
	var base_strength: float = float(sig.get("strength", 1.0))
	var dist: float = _get_signal_distance(sig)
	var target_bearing: float = _get_signal_bearing(sig)
	var delta_theta: float = get_angular_difference(antenna_azimuth_deg, target_bearing)
	var cone_deg: float = float(active_config.get("reception_cone_deg", 25.0))
	
	if is_auto_rotating and not is_frequency_locked:
		# In auto-rotazione: raggio ridotto del 70% (max 800m) e rapporto SNR degradato con rumore
		if dist > 800.0:
			return 0.0
		var dist_factor: float = clampf(1.0 - (dist / 800.0) * 0.5, 0.3, 0.8)
		return clampf(base_strength * 0.35 * dist_factor, 0.0, 1.0)
	
	# Modalità manuale o frequency locked (focalizzata)
	if delta_theta <= cone_deg:
		var angle_factor: float = cos(deg_to_rad(delta_theta))
		var dist_factor: float = clampf(1800.0 / maxf(dist, 400.0), 0.5, 1.2)
		return clampf(base_strength * angle_factor * (dist_factor * 0.5 + 0.5), 0.0, 1.0)
	else:
		# Fuori dal cono di ±25° il segnale cala drasticamente fino a zero/rumore
		var falloff: float = maxf(0.0, cos(deg_to_rad(delta_theta))) * 0.05
		return clampf(base_strength * falloff, 0.0, 1.0)

# --- CONTROLLI SETTORE SINISTRO: ANTENNA DIREZIONALE ---
func _on_antenna_heading_changed(new_val: float) -> void:
	if not can_control_comms:
		if antenna_heading_slider:
			antenna_heading_slider.set_value_no_signal(antenna_azimuth_deg)
		return
	antenna_azimuth_deg = fposmod(new_val, 360.0)
	_refresh_antenna_ui()
	_refresh_tuner_state()

func _on_btn_auto_rotate_toggled(toggled_on: bool) -> void:
	if not can_control_comms:
		if btn_auto_rotate:
			btn_auto_rotate.set_pressed_no_signal(is_auto_rotating)
		return
	is_auto_rotating = toggled_on
	if is_auto_rotating:
		is_frequency_locked = false
		if btn_freq_lock:
			btn_freq_lock.set_pressed_no_signal(false)
		_log_comms_message("[color=#ffdd55][ANTENNA DIREZIONALE][/color] Avviata rotazione automatica continua a 360° (%.0f°/s)." % auto_rotate_speed)
		_update_action_log("Antenna in auto-rotazione.")
	else:
		_log_comms_message("[color=#64c8ff][ANTENNA DIREZIONALE][/color] Rotazione automatica arrestata. Puntamento manuale a %03d°." % int(antenna_azimuth_deg))
		_update_action_log("Puntamento manuale ripristinato.")
	_refresh_ui_display()

func _on_btn_freq_lock_toggled(toggled_on: bool) -> void:
	if not can_control_comms:
		if btn_freq_lock:
			btn_freq_lock.set_pressed_no_signal(is_frequency_locked)
		return
	is_frequency_locked = toggled_on
	if is_frequency_locked:
		is_auto_rotating = false
		if btn_auto_rotate:
			btn_auto_rotate.set_pressed_no_signal(false)
		var tuned_sig: Variant = _get_locked_signal()
		if tuned_sig != null:
			locked_signal_id = str(tuned_sig.get("id", ""))
			var s_name: String = str(tuned_sig.get("name", "Segnale"))
			_log_comms_message("[color=#00ff88][FREQUENCY LOCK][/color] Aggancio frequenza attivo su %s. Tracking angolare bersaglio avviato." % s_name)
			_update_action_log("Frequency Lock attivo: tracking %s." % s_name)
		else:
			locked_signal_id = ""
			_log_comms_message("[color=#ff9933][FREQUENCY LOCK][/color] Nessun segnale sintonizzato per il tracking.")
			_update_action_log("Frequency Lock attivo (in attesa di segnale).")
	else:
		locked_signal_id = ""
		_log_comms_message("[color=#64c8ff][FREQUENCY LOCK][/color] Disattivato tracking frequenza. Antenna in posizione %03d°." % int(antenna_azimuth_deg))
		_update_action_log("Frequency Lock disattivato.")
	_refresh_ui_display()

# --- CONTROLLI SETTORE DESTRO: INTERAZIONI, STAZIONE & EW CONNECT ---
func _on_btn_request_docking_pressed() -> void:
	if not can_control_comms:
		return
	var cur_sig: Variant = _get_locked_signal()
	var station_id := ""
	var target_st: SpaceStationEntity = null
	if cur_sig != null and cur_sig.get("type", "").to_upper() == "STATION":
		station_id = str(cur_sig.get("station_id", "STATION-FRECCIA"))
		if cur_sig.get("node_ref") is SpaceStationEntity:
			target_st = cur_sig.get("node_ref") as SpaceStationEntity
	docking_clearance_requested.emit(station_id)
	request_station_docking(target_st)

func _on_btn_station_emergency_pressed() -> void:
	if not can_control_comms:
		return
	var cur_sig: Variant = _get_locked_signal()
	var s_name := str(cur_sig.get("name", "Stazione")) if cur_sig != null else "Stazione"
	_log_comms_message("[color=#ff5555][CANALE EMERGENZA][/color] Contatto prioritario con %s stabilito. Canale di soccorso riservato." % s_name)
	_update_action_log("Canale emergenza stazione aperto.")

func _on_btn_station_trade_pressed() -> void:
	if not can_control_comms:
		return
	var cur_sig: Variant = _get_locked_signal()
	var s_name := str(cur_sig.get("name", "Stazione")) if cur_sig != null else "Stazione"
	_log_comms_message("[color=#ffdd55][CANALE MERCANTILE][/color] Ricevuto bollettino prezzi e manifesti cargo da %s. Consultare StationHub all'attracco." % s_name)
	_update_action_log("Dati commerciali stazione ricevuti.")

func _on_connect_drive_pressed() -> void:
	if not can_control_comms:
		return
	
	var cur_sig: Variant = _get_locked_signal()
	if cur_sig == null:
		return
	
	var eff_strength: float = get_effective_signal_strength(cur_sig)
	var sig_dist: float = float(cur_sig.get("distance", 9999.0))
	if eff_strength < 0.75 or sig_dist >= 1200.0:
		_log_comms_message("[color=#ff5555][CONNESSIONE NEGATA][/color] Potenza segnale radio insufficiente o distanza eccessiva (Richiesto SNR >= 75%%, Dist < 1200m).")
		_update_action_log("Connessione EW fallita: segnale instabile.")
		return
	
	var target_ship_id: String = str(cur_sig.get("target_ship_id", cur_sig.get("id", "TARGET-SHIP")))
	var target_name: String = str(cur_sig.get("name", "Nave Bersaglio"))
	
	_log_comms_message("[color=#ff00ff][EW DRIVE INTRUSION][/color] ⚡ Link dati radio stabilito con [b]%s[/b] (ID: %s, SNR: %.0f%%, Dist: %.0fm)!" % [target_name, target_ship_id, eff_strength * 100.0, sig_dist])
	_update_action_log("Intrusione completata: Drive bersaglio %s agganciato." % target_ship_id)
	
	# Monta il Drive remoto bersaglio su GodotOS filesystem
	var rdm := get_node_or_null("/root/RemoteDriveManager")
	if rdm and rdm.has_method("mount_target_drive"):
		rdm.mount_target_drive(target_ship_id)
	else:
		var target_drive_path := "user://files/Target Drive"
		if not DirAccess.dir_exists_absolute(target_drive_path):
			DirAccess.make_dir_recursive_absolute(target_drive_path)
			DirAccess.make_dir_recursive_absolute(target_drive_path + "/FlightControl")
			DirAccess.make_dir_recursive_absolute(target_drive_path + "/Cams")
			DirAccess.make_dir_recursive_absolute(target_drive_path + "/System")
			DirAccess.make_dir_recursive_absolute(target_drive_path + "/LifeSupport")
			DirAccess.make_dir_recursive_absolute(target_drive_path + "/Weapons")
	
	var sw_mgr := get_node_or_null("/root/ShipSoftwareManager")
	if sw_mgr and sw_mgr.has_method("launch_app"):
		sw_mgr.launch_app("hack_exploits")
	
	var nm := get_node_or_null("/root/NotificationManager")
	if nm and nm.has_method("send_notification"):
		nm.send_notification("Electronic Warfare", "Target Drive montato per %s. Suite Hack Exploits pronta." % target_name)
	elif nm and nm.has_method("spawn_notification"):
		nm.spawn_notification("Target Drive montato per %s." % target_name)

func _on_btn_clear_log_pressed() -> void:
	if comms_log_text:
		comms_log_text.clear()
	_update_action_log("Registro comunicazioni ripulito.")

func _log_comms_message(msg: String) -> void:
	var time_str := Time.get_time_string_from_system().substr(0, 5)
	var formatted := "[color=#888888][%s][/color] %s" % [time_str, msg]
	if comms_log_text:
		comms_log_text.append_text(formatted + "\n")

func _update_action_log(msg: String) -> void:
	if action_log_label:
		action_log_label.text = "▶ %s" % msg

# --- AGGIORNAMENTO COMPLETO DELL'INTERFACCIA ---
func _refresh_antenna_ui() -> void:
	if antenna_heading_value:
		antenna_heading_value.text = "%03d°" % int(antenna_azimuth_deg)
	
	if antenna_status_label:
		if is_frequency_locked:
			var target_name := locked_signal_id
			for s in available_signals:
				if s.get("id") == locked_signal_id:
					target_name = s.get("name")
					break
			antenna_status_label.text = "🔒 FREQUENCY LOCK: %s (%03d°)" % [target_name, int(antenna_azimuth_deg)]
			antenna_status_label.modulate = Color(0.2, 1.0, 0.4)
		elif is_auto_rotating:
			antenna_status_label.text = "🔄 AUTO-ROTAZIONE 360° (%.0f°/s | Raggio ridotto)" % auto_rotate_speed
			antenna_status_label.modulate = Color(1.0, 0.8, 0.2)
		else:
			antenna_status_label.text = "🧭 PUNTAMENTO MANUALE: %03d° (Cono ±%.0f°)" % [int(antenna_azimuth_deg), float(active_config.get("reception_cone_deg", 25.0))]
			antenna_status_label.modulate = Color(0.4, 0.85, 1.0)
	
	if antenna_gain_label:
		if is_auto_rotating and not is_frequency_locked:
			antenna_gain_label.text = "Guadagno ridotto 35% | Raggio max 800m | Rumore SNR"
			antenna_gain_label.modulate = Color(1.0, 0.7, 0.3)
		elif is_frequency_locked:
			antenna_gain_label.text = "Tracking continuo attivo | Guadagno 100% | SNR Ottimale"
			antenna_gain_label.modulate = Color(0.3, 1.0, 0.5)
		else:
			antenna_gain_label.text = "Guadagno antenna: 100% | Cono di focalizzazione attivo"
			antenna_gain_label.modulate = Color(0.7, 0.8, 0.9)
	
	if btn_auto_rotate:
		btn_auto_rotate.set_pressed_no_signal(is_auto_rotating)
	if btn_freq_lock:
		btn_freq_lock.set_pressed_no_signal(is_frequency_locked)

func _refresh_tuner_state() -> void:
	if freq_value_label:
		freq_value_label.text = "%.1f MHz" % current_frequency
	
	var tuned_sig: Variant = _get_locked_signal()
	if tuned_sig != null:
		var sig_id: String = str(tuned_sig.get("id", ""))
		var sig_name: String = str(tuned_sig.get("name", "Segnale"))
		var sig_type: String = str(tuned_sig.get("type", "UNKNOWN"))
		var sig_desc: String = str(tuned_sig.get("desc", ""))
		var sig_source: String = str(tuned_sig.get("source", "Ignota"))
		var sig_bearing: float = _get_signal_bearing(tuned_sig)
		var sig_dist: float = float(tuned_sig.get("distance", 1000.0))
		var eff_strength: float = get_effective_signal_strength(tuned_sig)
		var delta_theta: float = get_angular_difference(antenna_azimuth_deg, sig_bearing)
		
		if is_frequency_locked and locked_signal_id.is_empty():
			locked_signal_id = sig_id
		
		# Badge Sintonizzatore
		if signal_lock_badge:
			if eff_strength >= 0.70:
				signal_lock_badge.text = "🔒 AGGANCIATO (OTTIMO): %s [%d%%]" % [sig_name, int(eff_strength * 100)]
				signal_lock_badge.modulate = Color(0.2, 1.0, 0.4)
			elif eff_strength >= 0.25:
				signal_lock_badge.text = "🟡 SEGNALE PARZIALE: %s [%d%%]" % [sig_name, int(eff_strength * 100)]
				signal_lock_badge.modulate = Color(1.0, 0.85, 0.3)
			else:
				signal_lock_badge.text = "⚠️ SEGNALE DEBOLE (FUORI CONO: Δθ=%d°)" % int(delta_theta)
				signal_lock_badge.modulate = Color(1.0, 0.4, 0.3)
		
		if signal_info_label:
			signal_info_label.text = "%s | Azimut: %03d° | Dist: %.0fm" % [sig_name, int(sig_bearing), sig_dist]
		
		if signal_detail_label:
			var lock_txt := "OTTIMO" if eff_strength >= 0.75 else ("DEBOLE / RUMORE" if eff_strength < 0.25 else "PARZIALE")
			var bb := "[b]%s[/b]\n" % sig_name
			bb += "[color=#88ccff]Info:[/color] %s\n" % sig_desc
			bb += "[color=#88ccff]Sorgente:[/color] %s | [color=#88ccff]Tipo:[/color] %s\n" % [sig_source, sig_type]
			bb += "[color=#88ccff]Azimut Bersaglio:[/color] %03d° (Δθ: %03d°) | [color=#88ccff]Distanza:[/color] %.0f m\n" % [int(sig_bearing), int(delta_theta), sig_dist]
			bb += "[color=#88ccff]Qualità Segnale SNR:[/color] [color=%s]%.0f%% (%s)[/color]" % [("lime" if eff_strength >= 0.75 else ("yellow" if eff_strength >= 0.25 else "red")), eff_strength * 100.0, lock_txt]
			signal_detail_label.text = bb
		
		if btn_listen_signal:
			btn_listen_signal.disabled = not can_control_comms or eff_strength < 0.2
		
		# Menu Stazione Spaziale
		var is_station := (sig_type.to_upper() == "STATION")
		if station_actions_box:
			station_actions_box.visible = is_station
		if btn_request_docking:
			btn_request_docking.disabled = not (can_control_comms and is_station and eff_strength >= 0.25)
		if btn_station_emergency:
			btn_station_emergency.disabled = not (can_control_comms and is_station)
		if btn_station_trade:
			btn_station_trade.disabled = not (can_control_comms and is_station)
		
		# Pulsante Connect Drive EW
		var is_ship_target := sig_type.to_upper() in ["SHIP", "CORVETTE", "DERELICT", "SHIP_HOSTILE", "ENEMY", "VESSEL"]
		var is_connectable := is_ship_target and eff_strength >= 0.75 and sig_dist < 1200.0
		if btn_connect_drive:
			btn_connect_drive.visible = not is_station
			btn_connect_drive.disabled = not (can_control_comms and is_connectable)
			if is_connectable:
				btn_connect_drive.text = "🔗 CONNETTI A DRIVE BERSAGLIO (%s)" % str(tuned_sig.get("target_ship_id", sig_name))
			elif not is_ship_target:
				btn_connect_drive.text = "🔗 NESSUN DRIVE BERSAGLIO SINTONIZZATO"
			else:
				btn_connect_drive.text = "⚠️ SEGNALE INSUFFICIENTE PER INTRUSIONE EW (SNR >= 75%%, Dist < 1200m)"
	else:
		if signal_lock_badge:
			signal_lock_badge.text = "⚪ RUMORE BIANCO / NESSUN AGGANCIO"
			signal_lock_badge.modulate = Color(0.6, 0.7, 0.8)
		if signal_info_label:
			signal_info_label.text = "Scorrere il cursore per intercettare portanti RF o trasmissioni subspaziali attive."
		if signal_detail_label:
			signal_detail_label.text = "[color=#7799aa]Nessuna trasmissione agganciata sulla frequenza attuale.[/color]\n[color=#557788]Sintonizzare la frequenza e orientare l'antenna verso la sorgente per stabilire il collegamento radio.[/color]"
		if btn_listen_signal:
			btn_listen_signal.disabled = true
		if station_actions_box:
			station_actions_box.visible = false
		if btn_connect_drive:
			btn_connect_drive.visible = true
			btn_connect_drive.disabled = true
			btn_connect_drive.text = "🔗 NESSUN SEGNALE BERSAGLIO AGGANCIATO"
	
	if waterfall_canvas:
		waterfall_canvas.update_state(current_frequency, is_auto_rotating, antenna_azimuth_deg, _is_ship_operational(), available_signals)

func _refresh_ui_display() -> void:
	var total_power := 50.0 + (15.0 if is_auto_rotating else 0.0)
	if power_badge:
		power_badge.text = "⚡ %d MW" % int(total_power)
	
	if status_badge:
		if not _is_ship_operational():
			status_badge.text = "● OFFLINE"
			status_badge.modulate = Color(0.9, 0.3, 0.3)
		elif is_frequency_locked:
			status_badge.text = "🔒 FREQ LOCK"
			status_badge.modulate = Color(0.2, 0.9, 0.4)
		elif is_auto_rotating:
			status_badge.text = "🔄 AUTO-ROTAZIONE"
			status_badge.modulate = Color(1.0, 0.7, 0.2)
		else:
			status_badge.text = "● STANDBY / IN ASCOLTO"
			status_badge.modulate = Color(0.2, 0.9, 0.4)
	
	if role_badge:
		var current_role := "Solo / Capitano"
		if NetworkManager:
			current_role = NetworkManager.get_local_player_role()
			if current_role.is_empty():
				current_role = "Solo / Ospite"
		role_badge.text = "👤 RUOLO: %s" % current_role.to_upper()
		role_badge.modulate = Color(0.3, 0.8, 1.0) if can_control_comms else Color(0.8, 0.5, 0.2)
	
	if dat_status_badge:
		if active_config.get("is_dat_loaded"):
			dat_status_badge.text = "✔ .DAT ATTIVO"
			dat_status_badge.modulate = Color(0.2, 0.9, 0.4)
		else:
			dat_status_badge.text = "⚠️ DEFAULT"
			dat_status_badge.modulate = Color(0.9, 0.7, 0.2)
	
	_refresh_antenna_ui()
	_refresh_tuner_state()

# --- INTEGRAZIONE DOCKING E CONTROLLO PORTUALE STAZIONE ---
var docking_manager: DockingManager = null
var is_docked: bool = false

func bind_docking_manager(dm: DockingManager) -> void:
	docking_manager = dm
	if not dm:
		return
	if not dm.docking_clearance_granted.is_connected(_on_docking_clearance_granted):
		dm.docking_clearance_granted.connect(_on_docking_clearance_granted)
	if not dm.docking_clearance_denied.is_connected(_on_docking_clearance_denied):
		dm.docking_clearance_denied.connect(_on_docking_clearance_denied)
	if not dm.docking_completed.is_connected(_on_docking_completed_event):
		dm.docking_completed.connect(_on_docking_completed_event)
	if not dm.undocking_completed.is_connected(_on_undocking_completed_event):
		dm.undocking_completed.connect(_on_undocking_completed_event)

func request_station_docking(station: SpaceStationEntity = null, dm: DockingManager = null) -> bool:
	if not can_control_comms:
		return false
	var target_dm := dm if dm != null else docking_manager
	if not target_dm:
		var st_mgr := get_node_or_null("/root/StationManager")
		if st_mgr is DockingManager:
			target_dm = st_mgr
		elif SpaceWorldManager and SpaceWorldManager.has_method("get_docking_manager"):
			target_dm = SpaceWorldManager.get_docking_manager()
	
	if not target_dm:
		target_dm = DockingManager.new()
		add_child(target_dm)
		bind_docking_manager(target_dm)
	
	var target_station := station
	if not target_station and target_dm.target_station:
		target_station = target_dm.target_station
	if not target_station:
		if SpaceWorldManager and SpaceWorldManager.has_method("get_primary_station_entity"):
			target_station = SpaceWorldManager.get_primary_station_entity()
		elif SpaceWorldManager and SpaceWorldManager.has_method("get_station_entity"):
			target_station = SpaceWorldManager.get_station_entity()
		elif is_inside_tree():
			var found_st := get_tree().root.find_child("SpaceStationEntity", true, false)
			if found_st is SpaceStationEntity:
				target_station = found_st
	
	var st_id := target_station.station_id if target_station else "STATION-01"
	docking_clearance_requested.emit(st_id)
	
	if not target_station:
		_log_comms_message("[color=#ff5555][DOCKING][/color] Nessuna stazione rilevata sulla frequenza attuale o nei paraggi.")
		docking_clearance_denied.emit("", "Nessuna stazione rilevata")
		return false
	
	_log_comms_message("[color=#64c8ff][DOCKING][/color] Richiesta autorizzazione attracco inviata a %s su %.1f MHz..." % [target_station.station_name, current_frequency])
	return target_dm.request_docking_clearance(target_station, "NOVA-ROGUE-01", "SOL-NAV-DEFENSE")

func _on_docking_clearance_granted(station_id: String, bay_id: int, message: String) -> void:
	docking_clearance_granted.emit(station_id, bay_id)
	_log_comms_message("[color=#00ff88][DOCKING AUTORIZZATO][/color] Stazione %s: %s" % [station_id, message])
	_update_action_log("Autorizzazione attracco concessa: Bay 0%d." % (bay_id + 1))
	var nm := get_node_or_null("/root/NotificationManager")
	if nm and nm.has_method("send_notification"):
		nm.send_notification("Controllo Portuale", "Autorizzazione attracco concessa (Bay 0%d)." % (bay_id + 1))
	elif nm and nm.has_method("spawn_notification"):
		nm.spawn_notification("Autorizzazione attracco concessa (Bay 0%d)." % (bay_id + 1))

func _on_docking_clearance_denied(station_id: String, reason: String) -> void:
	docking_clearance_denied.emit(station_id, reason)
	_log_comms_message("[color=#ff5555][DOCKING NEGATO][/color] %s: %s" % [station_id, reason])
	_update_action_log("Richiesta attracco respinta: %s" % reason)

func _on_docking_completed_event(station_id: String, bay_id: int, _st_data: Dictionary) -> void:
	is_docked = true
	docking_completed.emit(station_id, bay_id)
	_log_comms_message("[color=#00ff88][AGGANCIO COMPLETATO][/color] Nave ancorata con successo a Stazione %s (Bay 0%d). Servizi Station Hub sbloccati su GodotOS." % [station_id, bay_id + 1])
	_update_action_log("Aggancio stazione completato.")
	var nm := get_node_or_null("/root/NotificationManager")
	if nm and nm.has_method("send_notification"):
		nm.send_notification("Controllo Portuale", "Attracco completato. Servizi Station Hub operativi.")
	elif nm and nm.has_method("spawn_notification"):
		nm.spawn_notification("Attracco completato. Servizi Station Hub operativi.")

func _on_undocking_completed_event() -> void:
	is_docked = false
	_log_comms_message("[color=#64c8ff][UNDOCKING][/color] Disinnesto magnetico eseguito. Nave in assetto libero di navigazione.")
	_update_action_log("Disinnesto stazione completato.")
