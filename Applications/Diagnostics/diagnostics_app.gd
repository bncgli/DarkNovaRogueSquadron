class_name DiagnosticsApp
extends Control

## Applicazione GodotOS per la Diagnostica di Sistema, Sicurezza Cyber, Difesa ICE e Ripristino Firmware .DAT.
## Conforme allo standard architetturale di bordo (APP_ARCHITECTURE_STANDARD.md).
## Punto 5.7 del Documento di Feature Design Dark Nova.

const APP_TITLE: String = "System Diagnostics, Cyber Security & ICE Defense"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(640, 450)

const CONFIG_PATH_PRIMARY: String = "Ship Drive/Programs/Diagnostics/diagnostics_config.dat"
const CONFIG_PATH_FALLBACK: String = "Terminal Drive/Programs/Diagnostics/diagnostics_config.dat"
const TUNING_PATH_PRIMARY: String = "Ship Drive/Programs/Diagnostics/security_tuning.dat"
const TUNING_PATH_FALLBACK: String = "Terminal Drive/Programs/Diagnostics/security_tuning.dat"

# --- RIFERIMENTI NODI UI ---
@onready var disconnected_overlay: Control = get_node_or_null("%DisconnectedOverlay")
@onready var status_badge: Label = get_node_or_null("%StatusBadge")
@onready var role_badge: Label = get_node_or_null("%RoleBadge")
@onready var ice_badge: Label = get_node_or_null("%IceBadge")
@onready var dat_status_badge: Label = get_node_or_null("%DatStatusBadge")
@onready var reload_dat_button: Button = get_node_or_null("%ReloadDatButton")

# Scanner Drive & Minacce
@onready var target_drive_option: OptionButton = get_node_or_null("%TargetDriveOption")
@onready var depth_option: OptionButton = get_node_or_null("%DepthOption")
@onready var btn_start_scan: Button = get_node_or_null("%BtnStartScan")
@onready var btn_purge_threats: Button = get_node_or_null("%BtnPurgeThreats")
@onready var scan_progress_bar: ProgressBar = get_node_or_null("%ScanProgressBar")
@onready var scan_status_label: Label = get_node_or_null("%ScanStatusLabel")
@onready var threats_list: ItemList = get_node_or_null("%ThreatsList")
@onready var integrity_score_label: Label = get_node_or_null("%IntegrityScoreLabel")

# Pannello ICE & Firewall Difensivo
@onready var ice_progress_bar: ProgressBar = get_node_or_null("%IceProgressBar")
@onready var ice_value_label: Label = get_node_or_null("%IceValueLabel")
@onready var btn_reinforce_ice: Button = get_node_or_null("%BtnReinforceIce")
@onready var btn_flush_firewall: Button = get_node_or_null("%BtnFlushFirewall")
@onready var ice_log_text: RichTextLabel = get_node_or_null("%IceLogText")
@onready var node_avionics_status: Label = get_node_or_null("%NodeAvionicsStatus")
@onready var node_reactor_status: Label = get_node_or_null("%NodeReactorStatus")
@onready var node_comms_status: Label = get_node_or_null("%NodeCommsStatus")
@onready var node_weapons_status: Label = get_node_or_null("%NodeWeaponsStatus")
@onready var node_mainframe_status: Label = get_node_or_null("%NodeMainframeStatus")

# Ripristino Firmware & Factory Reset
@onready var subsystem_option: OptionButton = get_node_or_null("%SubsystemOption")
@onready var btn_factory_reset: Button = get_node_or_null("%BtnFactoryReset")
@onready var reset_progress_bar: ProgressBar = get_node_or_null("%ResetProgressBar")
@onready var reset_status_label: Label = get_node_or_null("%ResetStatusLabel")
@onready var firmware_status_text: RichTextLabel = get_node_or_null("%FirmwareStatusText")

# Registro Cyber & Audit Log
@onready var audit_log_text: RichTextLabel = get_node_or_null("%AuditLogText")
@onready var btn_clear_log: Button = get_node_or_null("%BtnClearLog")
@onready var action_log_label: Label = get_node_or_null("%ActionLogLabel")

# --- STATO OPERATIVO E PARAMETRI RUNTIME ---
var can_control_diagnostics: bool = true
var is_scanning: bool = false
var scan_progress: float = 0.0
var scan_target_drive: int = 0 # 0: Ship Drive, 1: Terminal Drive, 2: All
var scan_depth_mode: int = 1 # 0: Quick, 1: Deep
var system_integrity_score: float = 100.0

var current_ice_strength: float = 100.0
var max_ice_strength: float = 100.0
var is_ice_under_attack: bool = false

var is_factory_resetting: bool = false
var reset_progress: float = 0.0
var reset_target_subsystem: String = "ALL"
var reset_timer_target: float = 3.0

var detected_threats: Array[Dictionary] = []
var quarantined_threats: Array[Dictionary] = []

var ice_nodes_status: Dictionary = {
	"avionics": {"name": "Avionica & Navigazione", "integrity": 100.0, "status": "SECURE"},
	"reactor": {"name": "Nucleo Reattore & Griglia", "integrity": 100.0, "status": "SECURE"},
	"comms": {"name": "Relay Comms & Subspazio", "integrity": 100.0, "status": "SECURE"},
	"weapons": {"name": "Matrice Puntamento Armi", "integrity": 100.0, "status": "SECURE"},
	"mainframe": {"name": "Mainframe OS & Firmware", "integrity": 100.0, "status": "SECURE"}
}

# Parametri attivi .DAT con fallback
var active_config: Dictionary = {
	"scan_depth": "DEEP",
	"auto_quarantine_malware": true,
	"alert_sound": true,
	"scan_speed_multiplier": 1.0,
	"tamper_detection_level": "HIGH",
	"log_telemetry_integrity": true,
	"ice_firewall_strength": 100.0,
	"factory_reset_delay_sec": 3.0,
	"ice_recharge_rate": 5.0,
	"malware_purge_efficiency": 1.0,
	"overclock_bypass_security": false,
	"is_dat_loaded": false
}

# Database configurazioni di fabbrica dei firmware
const SUBSYSTEM_FACTORY_DEFAULTS: Dictionary = {
	"FlightControls": {
		"folder": "Ship Drive/Programs/FlightControls",
		"files": {
			"Ship Drive/Programs/FlightControls/flight_config.dat": "# DARK NOVA FLIGHT CONTROLS RUNTIME CONFIGURATION\n# WARNING: SYSTEM CONFIGURATION FILE - ACTIVE FLIGHT TUNING\n[SYSTEM]\napp_name=FlightControls\nversion=1.0.4\nstatus=OPERATIONAL\nrcs_subsystem=ACTIVE\n\n[FLIGHT_DYNAMICS]\nmax_linear_speed=20.0\nlinear_acceleration=35.0\nlinear_deceleration=20.0\nmax_angular_speed=2.5\nangular_acceleration=8.0\nangular_deceleration=6.0\n\n[SPEED_MODES]\nturbo_multiplier=2.0\nprecision_multiplier=0.4\n",
			"Ship Drive/Programs/FlightControls/thrusters_tuning.dat": "# RCS & MAIN THRUSTERS TUNING MATRIX\n[THRUSTERS]\nrcs_power_rate=1.0\npitch_thrust_mult=1.0\nyaw_thrust_mult=1.0\nroll_thrust_mult=1.0\nvertical_thrust_mult=1.0\noverclock_limit=1.5\n"
		}
	},
	"Cams": {
		"folder": "Ship Drive/Programs/Cams",
		"files": {
			"Ship Drive/Programs/Cams/cams_config.dat": "# DARK NOVA CAMS ARRAY RUNTIME CONFIGURATION\n# WARNING: SENSORS & OPTICS CONFIGURATION FILE\n[SYSTEM]\napp_name=Cams\nversion=1.0.4\nstatus=OPERATIONAL\nsensor_array=CCTV_6CH\n\n[OPTICS]\ndefault_fov=75.0\nmin_fov=30.0\nmax_fov=100.0\nzoom_step=10.0\nnight_vision_intensity=0.18\ntactical_hud_contrast=0.18\nthermal_intensity=0.22\n",
			"Ship Drive/Programs/Cams/optics_tuning.dat": "# OPTICS & SENSOR CALIBRATION MATRIX\n[SENSORS]\nsignal_boost=1.0\nnoise_reduction=1.0\nrefresh_rate_hz=60.0\ncrosshair_style=STANDARD\noverclock_gain=1.0\n"
		}
	},
	"DuctDrone": {
		"folder": "Ship Drive/Programs/DuctDrone",
		"files": {
			"Ship Drive/Programs/DuctDrone/duct_drone_config.dat": "# DARK NOVA DUCT DRONE RUNTIME CONFIGURATION\n# WARNING: SYSTEM CONFIGURATION FILE - MAINTENANCE & REPAIR ROBOT\n[SYSTEM]\napp_name=DuctDrone\nversion=1.0.4\nstatus=OPERATIONAL\nmaintenance_subsystem=ACTIVE\n\n[DRONE_DYNAMICS]\nlinear_speed=175.0\nlinear_acceleration=650.0\nlinear_deceleration=750.0\nrotate_speed=3.0\n\n[BATTERY_MANAGEMENT]\nbattery_max=100.0\nbattery_drain_move=0.35\nbattery_drain_lights=0.75\nbattery_drain_radar=3.5\nbattery_drain_repair=6.0\n\n[MAINTENANCE]\nradar_scan_radius_max=160.0\nrepair_range=42.0\nrepair_speed_multiplier=1.0\n",
			"Ship Drive/Programs/DuctDrone/drone_tuning.dat": "# DUCT DRONE CALIBRATION & EFFICIENCY MATRIX\n[TUNING]\nturbo_multiplier=2.0\nprecision_multiplier=0.5\nrepair_efficiency=1.0\nradar_intensity=1.0\noverclock_speed_gain=1.0\n"
		}
	},
	"PowerGrid": {
		"folder": "Ship Drive/Programs/PowerGrid",
		"files": {
			"Ship Drive/Programs/PowerGrid/power_grid_config.dat": "# DARK NOVA POWER GRID RUNTIME CONFIGURATION\n# WARNING: ELECTRICAL GRID AND POWER DISTRIBUTION MATRIX\n[SYSTEM]\napp_name=PowerGrid\nversion=1.0.4\nstatus=OPERATIONAL\nmode=AUTOMATIC_BALANCING\n\n[GRID_SETTINGS]\nreactor_output_mw=1200.0\naux_generator_mw=450.0\njunction_switch_delay=0.25\noverload_threshold_pct=110.0\nreroute_efficiency_loss=0.05\n\n[CIRCUIT_PROTECTION]\nbreaker_trip_threshold=1.4\nshort_circuit_damping=0.85\nauto_reroute_on_short=false\n",
			"Ship Drive/Programs/PowerGrid/grid_tuning.dat": "# POWER GRID CALIBRATION & TUNING MATRIX\n[TUNING]\npower_efficiency_mult=1.0\nbackup_line_conductivity=0.95\nswitch_rate_hz=10.0\nregime_boost=1.0\noverclock_tolerance=1.2\n"
		}
	},
	"Weapons": {
		"folder": "Ship Drive/Programs/Weapons",
		"files": {
			"Ship Drive/Programs/Weapons/weapons_config.dat": "# DARK NOVA TACTICAL WEAPONS RUNTIME CONFIGURATION\n# WARNING: TACTICAL WEAPONS & DEFENSE SYSTEMS FIRMWARE\n[SYSTEM]\napp_name=Weapons\nversion=1.0.4\nstatus=OPERATIONAL\nweapons_subsystem=ACTIVE\n\n[WEAPONS]\nmax_range=4500.0\nfire_rate=1.8\ncooling_rate=0.75\nauto_pdg_enabled=true\nlaser_power_draw=250.0\ntorpedo_max_ammo=12\npdg_ammo_max=500\npdg_fire_rate=8.0\nemergency_vent_cooldown=10.0\n",
			"Ship Drive/Programs/Weapons/ammo_tuning.dat": "# WEAPONS BALLISTICS & TARGETING CALIBRATION MATRIX\n[BALLISTICS]\ntorpedo_velocity=85.0\nauto_lead_tracking=true\noverclock_damage_mult=1.0\nheat_multiplier=1.0\npdg_range=1200.0\nlaser_beam_intensity=1.0\n"
		}
	},
	"ShieldMatrix": {
		"folder": "Ship Drive/Programs/ShieldMatrix",
		"files": {
			"Ship Drive/Programs/ShieldMatrix/shields_config.dat": "# DARK NOVA SHIELD MATRIX RUNTIME CONFIGURATION\n# WARNING: SHIELD DEFLECTOR AND HULL PROTECTION MATRIX\n[SYSTEM]\napp_name=ShieldMatrix\nversion=1.0.4\nstatus=OPERATIONAL\nshield_subsystem=ACTIVE\n\n[SHIELD_SETTINGS]\nmax_capacity_per_quadrant=250.0\nrecharge_rate_per_sec=15.0\noverload_limit=1.3\nbase_power_draw_mw=90.0\nemergency_boost_power_mw=120.0\nemergency_boost_amount=75.0\nemergency_boost_cooldown=8.0\ndecay_rate_unpowered=25.0\n",
			"Ship Drive/Programs/ShieldMatrix/deflector_tuning.dat": "# DEFLECTOR HARMONICS & FIELD TUNING MATRIX\n[HARMONICS]\nharmonic_frequency=440.0\nemergency_boost_multiplier=2.5\noverclock_absorption=1.0\nphase_sync_stability=0.98\ndispersion_damping=0.88\n"
		}
	},
	"Comms": {
		"folder": "Ship Drive/Programs/Comms",
		"files": {
			"Ship Drive/Programs/Comms/comms_config.dat": "# DARK NOVA COMMUNICATIONS & EW RUNTIME CONFIGURATION\n# WARNING: SUBSPACE RELAY AND CRYPTOGRAPHY MATRIX\n[SYSTEM]\napp_name=Comms\nversion=1.0.4\nstatus=OPERATIONAL\ncomms_subsystem=ACTIVE\n\n[COMMS_SETTINGS]\nbandwidth_hz=1420.0\ndecryption_speed_multiplier=1.0\nsubspace_relay_active=true\nauto_tune_sos=true\nsignal_amplification=1.2\n",
			"Ship Drive/Programs/Comms/crypto_tuning.dat": "# EW COUNTERMEASURES & CRYPTO TUNING MATRIX\n[ELECTRONIC_WARFARE]\njamming_power_mw=120.0\nsignal_noise_ratio=0.85\nspoofing_signature=CORVETTE_CIVILIAN\njamming_radius=15000.0\noverclock_ew_boost=1.0\ncrypto_crack_speed=1.0\n"
		}
	},
	"Diagnostics": {
		"folder": "Ship Drive/Programs/Diagnostics",
		"files": {
			"Ship Drive/Programs/Diagnostics/diagnostics_config.dat": "# DARK NOVA SYSTEM DIAGNOSTICS RUNTIME CONFIGURATION\n# WARNING: SYSTEM INTEGRITY & THREAT SCANNER CONFIGURATION\n[SYSTEM]\napp_name=Diagnostics\nversion=1.0.4\nstatus=OPERATIONAL\ndiagnostics_subsystem=ACTIVE\n\n[SCANNER_SETTINGS]\nscan_depth=DEEP\nauto_quarantine_malware=true\nalert_sound=true\nscan_speed_multiplier=1.0\ntamper_detection_level=HIGH\nlog_telemetry_integrity=true\n",
			"Ship Drive/Programs/Diagnostics/security_tuning.dat": "# ICE DEFENSE & CYBER SECURITY TUNING MATRIX\n[ICE_DEFENSE]\nice_firewall_strength=100.0\nfactory_reset_delay_sec=3.0\ntamper_detection_level=HIGH\nice_recharge_rate=5.0\nmalware_purge_efficiency=1.0\noverclock_bypass_security=false\n"
		}
	},
	"Sensors": {
		"folder": "Ship Drive/Programs/Sensors",
		"files": {
			"Ship Drive/Programs/Sensors/sensors_config.dat": "# DARK NOVA SENSORS ARRAY & TACTICAL MAP CONFIGURATION\n# WARNING: SYSTEM CONFIGURATION FILE - RUNTIME RADAR FIRMWARE\n[SYSTEM]\napp_name=SensorsApp\nversion=1.0.0\nstatus=OPERATIONAL\n\n[SWEEP]\nsweep_frequency_hz=12.0\nactive_ping_radius=50000.0\nnoise_filter=0.92\n",
			"Ship Drive/Programs/Sensors/radar_tuning.dat": "# RADAR TUNING & SPECTROMETRY CALIBRATION MATRIX\n[TUNING]\nspectrum_sensitivity=1.0\niff_auto_tag=true\nstealth_detection_threshold=0.35\n"
		}
	},
	"LifeSupport": {
		"folder": "Ship Drive/Programs/LifeSupport",
		"files": {
			"Ship Drive/Programs/LifeSupport/life_support_config.dat": "# DARK NOVA LIFE SUPPORT & ATMOSPHERE CONTROL CONFIGURATION\n# WARNING: SYSTEM CONFIGURATION FILE - RUNTIME ATMOSPHERE FIRMWARE\n[SYSTEM]\napp_name=LifeSupportApp\nversion=1.0.0\nstatus=OPERATIONAL\n\n[OXYGEN]\no2_generation_rate=1.2\nseal_door_speed=0.5\nauto_fire_suppress=false\n",
			"Ship Drive/Programs/LifeSupport/atmo_tuning.dat": "# ATMOSPHERE TUNING & DECOMPRESSION PARAMETERS MATRIX\n[PARAMETERS]\ndecompression_rate=1.8\nfire_suppression_co2_level=0.45\nscrubber_efficiency=0.98\n"
		}
	}
}

func _ready() -> void:
	_configure_window()
	_init_ui_dropdowns()
	_connect_system_signals()
	_connect_ui_signals()
	_update_connection_state()
	_update_permissions()
	load_dat_configuration()
	_refresh_all_ui()
	_log_audit("Inizializzazione modulo System Diagnostics & ICE Defense completata.")

func _configure_window() -> void:
	custom_minimum_size = DEFAULT_WINDOW_SIZE
	var parent_win = get_parent()
	while parent_win:
		if "window_title" in parent_win:
			parent_win.window_title = APP_TITLE
			break
		parent_win = parent_win.get_parent()

func _init_ui_dropdowns() -> void:
	if target_drive_option:
		target_drive_option.clear()
		target_drive_option.add_item("Ship Drive (Condiviso)", 0)
		target_drive_option.add_item("Terminal Drive (Locale)", 1)
		target_drive_option.add_item("Tutti i Drive (Full System)", 2)
		target_drive_option.selected = 0
	
	if depth_option:
		depth_option.clear()
		depth_option.add_item("Scansione Rapida (Quick)", 0)
		depth_option.add_item("Scansione Profonda (Deep)", 1)
		depth_option.selected = 1
	
	if subsystem_option:
		subsystem_option.clear()
		subsystem_option.add_item("Tutti i Sottosistemi (Full Purge)", 0)
		subsystem_option.add_item("Flight Controls (Propulsione & RCS)", 1)
		subsystem_option.add_item("Cams (Array CCTV 6CH)", 2)
		subsystem_option.add_item("Duct Drone (Robot & Radar)", 3)
		subsystem_option.add_item("Power Grid (Reattore & Snodi)", 4)
		subsystem_option.add_item("Tactical Weapons (Armi & PDG)", 5)
		subsystem_option.add_item("Shield Matrix (Deflettori 4Q)", 6)
		subsystem_option.add_item("Comms & EW (Subspazio & Cifrari)", 7)
		subsystem_option.add_item("Diagnostics (Sicurezza & ICE)", 8)
		subsystem_option.add_item("Sensors (Array Radar 50km)", 9)
		subsystem_option.add_item("Life Support (Supporto Vitale & O2)", 10)
		subsystem_option.selected = 0

func _connect_system_signals() -> void:
	if SpaceWorldManager:
		if SpaceWorldManager.has_signal("ship_connection_changed") and not SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
	
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
		if sdm.has_signal("ship_drive_mounted") and not sdm.ship_drive_mounted.is_connected(_on_drive_mounted):
			sdm.ship_drive_mounted.connect(_on_drive_mounted)
		if sdm.has_signal("ship_drive_unmounted") and not sdm.ship_drive_unmounted.is_connected(_on_drive_unmounted):
			sdm.ship_drive_unmounted.connect(_on_drive_unmounted)

func _connect_ui_signals() -> void:
	if btn_start_scan and not btn_start_scan.pressed.is_connected(_on_start_scan_pressed):
		btn_start_scan.pressed.connect(_on_start_scan_pressed)
	if btn_purge_threats and not btn_purge_threats.pressed.is_connected(_on_purge_threats_pressed):
		btn_purge_threats.pressed.connect(_on_purge_threats_pressed)
	if btn_reinforce_ice and not btn_reinforce_ice.pressed.is_connected(_on_reinforce_ice_pressed):
		btn_reinforce_ice.pressed.connect(_on_reinforce_ice_pressed)
	if btn_flush_firewall and not btn_flush_firewall.pressed.is_connected(_on_flush_firewall_pressed):
		btn_flush_firewall.pressed.connect(_on_flush_firewall_pressed)
	if btn_factory_reset and not btn_factory_reset.pressed.is_connected(_on_factory_reset_pressed):
		btn_factory_reset.pressed.connect(_on_factory_reset_pressed)
	if reload_dat_button and not reload_dat_button.pressed.is_connected(_on_reload_dat_pressed):
		reload_dat_button.pressed.connect(_on_reload_dat_pressed)
	if btn_clear_log and not btn_clear_log.pressed.is_connected(_on_clear_log_pressed):
		btn_clear_log.pressed.connect(_on_clear_log_pressed)
	if target_drive_option and not target_drive_option.item_selected.is_connected(_on_target_drive_selected):
		target_drive_option.item_selected.connect(_on_target_drive_selected)
	if depth_option and not depth_option.item_selected.is_connected(_on_depth_selected):
		depth_option.item_selected.connect(_on_depth_selected)

func _exit_tree() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_signal("ship_connection_changed") and SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
		SpaceWorldManager.ship_connection_changed.disconnect(_on_ship_connection_changed)
	
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
		if sdm.has_signal("ship_drive_mounted") and sdm.ship_drive_mounted.is_connected(_on_drive_mounted):
			sdm.ship_drive_mounted.disconnect(_on_drive_mounted)
		if sdm.has_signal("ship_drive_unmounted") and sdm.ship_drive_unmounted.is_connected(_on_drive_unmounted):
			sdm.ship_drive_unmounted.disconnect(_on_drive_unmounted)

func _process(delta: float) -> void:
	# Aggiornamento progress barra scansione
	if is_scanning:
		var speed_mult: float = float(active_config.get("scan_speed_multiplier", 1.0))
		var base_speed: float = 35.0 if scan_depth_mode == 0 else 18.0
		scan_progress += base_speed * speed_mult * delta
		if scan_progress >= 100.0:
			scan_progress = 100.0
			_finish_scan()
		_update_scan_ui()
	
	# Aggiornamento countdown factory reset
	if is_factory_resetting:
		var delay_target: float = maxf(float(active_config.get("factory_reset_delay_sec", 3.0)), 0.1)
		reset_progress += (100.0 / delay_target) * delta
		if reset_progress >= 100.0:
			reset_progress = 100.0
			_finish_factory_reset()
		_update_reset_ui()
	
	# Rigenerazione passiva della barriera ICE
	var recharge_rate: float = float(active_config.get("ice_recharge_rate", 5.0))
	if current_ice_strength < max_ice_strength:
		current_ice_strength = minf(current_ice_strength + recharge_rate * delta * 0.1, max_ice_strength)
		_update_ice_ui()

# --- GESTIONE STATO DI CONNESSIONE & OVERLAY ---

func _is_ship_operational() -> bool:
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		return SpaceWorldManager.is_ship_connected()
	var nm := get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("is_ship_connected"):
		return nm.is_ship_connected()
	return false

func _on_ship_connection_changed(_is_connected: bool) -> void:
	_update_connection_state()

func _on_mission_started() -> void:
	_update_connection_state()
	_update_permissions()
	load_dat_configuration()
	_log_audit("Avvio missione intercettato: Sistemi diagnostici sbloccati.")

func _on_mission_ended() -> void:
	_update_connection_state()
	_log_audit("Missione terminata: Sistemi diagnostici posti in standby.")

func _on_drive_mounted() -> void:
	load_dat_configuration()
	_log_audit("Ship Drive montato: firmware di bordo disponibili.")

func _on_drive_unmounted() -> void:
	_log_audit("Ship Drive smontato: firmware di bordo non accessibili.")

func _update_connection_state() -> void:
	var operational := _is_ship_operational()
	if disconnected_overlay:
		disconnected_overlay.visible = not operational
	
	set_process(operational)
	set_process_input(operational)

# --- GESTIONE PERMESSI RUOLI (RBAC) ---

func _on_player_role_changed(_peer_id: int, _new_role: String) -> void:
	_update_permissions()

func _update_permissions() -> void:
	var nm := get_node_or_null("/root/NetworkManager")
	var my_role := ""
	var is_solo := false
	if nm:
		my_role = nm.get_local_player_role()
		is_solo = nm.is_solo_mode
	
	# Hacker, Ingegnere, Capitano, Factotum e Solo Mode hanno pieno controllo
	can_control_diagnostics = (is_solo or my_role == "Hacker" or my_role == "Ingegnere" or my_role == "Capitano" or my_role == "Factotum" or my_role.is_empty())
	
	if role_badge:
		var display_role := my_role if not my_role.is_empty() else ("SOLO" if is_solo else "SPETTATORE")
		role_badge.text = "👤 RUOLO: %s" % display_role.to_upper()
	
	# Abilita/disabilita i pulsanti di controllo
	if btn_start_scan:
		btn_start_scan.disabled = not can_control_diagnostics
	if btn_purge_threats:
		btn_purge_threats.disabled = not can_control_diagnostics or detected_threats.is_empty()
	if btn_reinforce_ice:
		btn_reinforce_ice.disabled = not can_control_diagnostics
	if btn_flush_firewall:
		btn_flush_firewall.disabled = not can_control_diagnostics
	if btn_factory_reset:
		btn_factory_reset.disabled = not can_control_diagnostics or is_factory_resetting
	if reload_dat_button:
		reload_dat_button.disabled = not can_control_diagnostics

# --- GESTIONE FILE .DAT E HOT-RELOADING ---

func _on_drive_file_modified(rel_path: String) -> void:
	if "Programs/Diagnostics" in rel_path and rel_path.ends_with(".dat"):
		load_dat_configuration()
		_log_audit("Hot-reloading .DAT applicato per percorso: %s" % rel_path)

func load_dat_configuration() -> void:
	var primary_cfg := _parse_dat_file(CONFIG_PATH_PRIMARY)
	if primary_cfg.is_empty():
		primary_cfg = _parse_dat_file(CONFIG_PATH_FALLBACK)
	
	var tuning_cfg := _parse_dat_file(TUNING_PATH_PRIMARY)
	if tuning_cfg.is_empty():
		tuning_cfg = _parse_dat_file(TUNING_PATH_FALLBACK)
	
	var dat_loaded := false
	
	if not primary_cfg.is_empty():
		for k in primary_cfg:
			active_config[k] = primary_cfg[k]
		dat_loaded = true
	
	if not tuning_cfg.is_empty():
		for k in tuning_cfg:
			active_config[k] = tuning_cfg[k]
		dat_loaded = true
	
	active_config["is_dat_loaded"] = dat_loaded
	_apply_configuration()

func _apply_configuration() -> void:
	max_ice_strength = float(active_config.get("ice_firewall_strength", 100.0))
	current_ice_strength = clampf(current_ice_strength, 0.0, max_ice_strength)
	
	var depth_str: String = str(active_config.get("scan_depth", "DEEP")).to_upper()
	if depth_str == "QUICK" or depth_str == "0":
		scan_depth_mode = 0
		if depth_option: depth_option.selected = 0
	else:
		scan_depth_mode = 1
		if depth_option: depth_option.selected = 1
	
	if dat_status_badge:
		if active_config.get("is_dat_loaded", false):
			dat_status_badge.text = "⚙️ .DAT: CARICATO"
			dat_status_badge.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4, 1.0))
		else:
			dat_status_badge.text = "⚙️ .DAT: STANDARD"
			dat_status_badge.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2, 1.0))
	
	_update_ice_ui()
	_update_firmware_ui()

func _parse_dat_file(rel_path: String) -> Dictionary:
	var result: Dictionary = {}
	var abs_path := "user://files/%s" % rel_path
	if not FileAccess.file_exists(abs_path):
		return result
	
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if not file:
		return result
	
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#") or line.begins_with(";"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			continue
		
		var eq_pos := line.find("=")
		if eq_pos != -1:
			var key := line.substr(0, eq_pos).strip_edges()
			var val_str := line.substr(eq_pos + 1).strip_edges()
			if val_str.to_lower() == "true":
				result[key] = true
			elif val_str.to_lower() == "false":
				result[key] = false
			elif val_str.is_valid_float():
				result[key] = val_str.to_float()
			elif val_str.is_valid_int():
				result[key] = val_str.to_int()
			else:
				result[key] = val_str
	
	file.close()
	return result

# --- MODULO 1: SCANNER INTEGRITÀ & MINACCE ---

func _on_target_drive_selected(idx: int) -> void:
	scan_target_drive = idx

func _on_depth_selected(idx: int) -> void:
	scan_depth_mode = idx

func _on_start_scan_pressed() -> void:
	if not can_control_diagnostics or is_scanning:
		return
	start_scan(scan_target_drive, scan_depth_mode)

func start_scan(target_drive: int = 0, depth_mode: int = 1) -> void:
	scan_target_drive = target_drive
	scan_depth_mode = depth_mode
	is_scanning = true
	scan_progress = 0.0
	
	var drive_name := "Ship Drive" if target_drive == 0 else ("Terminal Drive" if target_drive == 1 else "Tutti i Drive")
	var mode_name := "Rapida" if depth_mode == 0 else "Profonda"
	_log_audit("Avviata scansione integrità (%s) su target: %s" % [mode_name, drive_name])
	
	if status_badge:
		status_badge.text = "● SCANSIONE IN CORSO..."
		status_badge.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2, 1.0))
	
	if btn_start_scan:
		btn_start_scan.disabled = true
	
	_update_scan_ui()

func _finish_scan() -> void:
	is_scanning = false
	if btn_start_scan:
		btn_start_scan.disabled = not can_control_diagnostics
	
	_perform_actual_threat_scan()
	
	if status_badge:
		if detected_threats.is_empty():
			status_badge.text = "● INTEGRITÀ 100% (SECURE)"
			status_badge.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4, 1.0))
		else:
			status_badge.text = "⚠️ %d MINACCE RILEVATE" % detected_threats.size()
			status_badge.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25, 1.0))
	
	_update_scan_ui()
	_update_permissions()
	
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		if detected_threats.is_empty():
			notif.spawn_notification("Scansione completata: Nessuna minaccia rilevata.")
		else:
			notif.spawn_notification("Scansione completata: Rilevate %d anomalie/minacce!" % detected_threats.size())
	
	# Auto-quarantena se abilitata nella configurazione
	if bool(active_config.get("auto_quarantine_malware", true)) and not detected_threats.is_empty():
		_log_audit("Auto-quarantine attiva: bonifica automatica minacce avviata.")
		purge_threats()

func _perform_actual_threat_scan() -> void:
	# Analisi reale e diegetica dei drive e dei file di bordo
	detected_threats.clear()
	
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	var dirs_to_check: Array[String] = []
	if scan_target_drive == 0 or scan_target_drive == 2:
		dirs_to_check.append("user://files/Ship Drive")
	if scan_target_drive == 1 or scan_target_drive == 2:
		dirs_to_check.append("user://files/Terminal Drive")
	
	# 1. Ispezione cartelle protette di bordo
	if fpm:
		var expected_passwords: Dictionary = {
			"Ship Drive/Programs/FlightControls": "FLIGHT-7815",
			"Ship Drive/Programs/Cams": "CAMS-7815",
			"Ship Drive/Programs/DuctDrone": "DRONE-7815",
			"Ship Drive/Programs/PowerGrid": "GRID-7815",
			"Ship Drive/Programs/Weapons": "WEAP-7815",
			"Ship Drive/Programs/ShieldMatrix": "SHLD-7815",
			"Ship Drive/Programs/Comms": "COMM-7815",
			"Ship Drive/Programs/Diagnostics": "DIAG-7815",
			"Ship Drive/Programs/Sensors": "SENS-7815",
			"Ship Drive/Programs/LifeSupport": "LIFE-7815",
			"Ship Drive/systems": "ROOT-7815",
			"Terminal Drive/systems": "ROOT-7815"
		}
		
		for folder: String in expected_passwords:
			var rel_norm: String = str(fpm.normalize_path(folder))
			if DirAccess.dir_exists_absolute("user://files/" + folder):
				if not fpm.has_password(rel_norm):
					detected_threats.append({
						"name": "Cartella Firmware Non Protetta",
						"type": "SECURITY_HOLE",
						"path": folder,
						"severity": "HIGH",
						"desc": "La cartella firmware %s non dispone di password di crittografia." % folder
					})
	
	# 2. Scansione file infetti o manomessi
	for base_dir in dirs_to_check:
		_scan_directory_recursive(base_dir)
	
	# Calcolo indice di integrità
	if detected_threats.is_empty():
		system_integrity_score = 100.0
	else:
		system_integrity_score = maxf(100.0 - float(detected_threats.size()) * 20.0, 15.0)

func _scan_directory_recursive(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var item_name := dir.get_next()
	while not item_name.is_empty():
		if item_name != "." and item_name != "..":
			var full_path := "%s/%s" % [dir_path, item_name]
			var rel_path := full_path.replace("user://files/", "").replace("user://files", "")
			if dir.current_is_dir():
				_scan_directory_recursive(full_path)
			else:
				var lower_name := item_name.to_lower()
				if lower_name.ends_with(".miner") or lower_name.ends_with(".trojan") or lower_name.ends_with(".worm") or "malware" in lower_name or "exploit" in lower_name:
					detected_threats.append({
						"name": "Malware Rilevato: %s" % item_name,
						"type": "TROJAN_VIRUS",
						"path": rel_path,
						"severity": "CRITICAL",
						"desc": "Firma malware clandestina identificata nel file system."
					})
				elif lower_name.ends_with(".corrupt") or lower_name.ends_with(".tampered"):
					detected_threats.append({
						"name": "Firmware .DAT Corrotto / Manomesso",
						"type": "FIRMWARE_CORRUPTION",
						"path": rel_path,
						"severity": "HIGH",
						"desc": "Incoerenza di parità logica rilevata nei blocchi del firmware."
					})
		item_name = dir.get_next()
	dir.list_dir_end()

func inject_threat(threat_name: String, threat_type: String, file_path: String, severity: String = "HIGH", description: String = "") -> void:
	var t: Dictionary = {
		"name": threat_name,
		"type": threat_type,
		"path": file_path,
		"severity": severity,
		"desc": description if not description.is_empty() else "Anomalia iniettata per test di diagnostica."
	}
	detected_threats.append(t)
	system_integrity_score = maxf(100.0 - float(detected_threats.size()) * 20.0, 10.0)
	_update_scan_ui()
	_log_audit("⚠️ Minaccia rilevata: %s [%s]" % [threat_name, file_path])

func _on_purge_threats_pressed() -> void:
	if not can_control_diagnostics:
		return
	purge_threats()

func purge_threats() -> void:
	var count := detected_threats.size()
	if count == 0:
		return
	
	for threat in detected_threats:
		var p: String = threat.get("path", "")
		var abs_p := "user://files/%s" % p
		if FileAccess.file_exists(abs_p):
			DirAccess.remove_absolute(abs_p)
		quarantined_threats.append(threat)
	
	detected_threats.clear()
	system_integrity_score = 100.0
	
	_log_audit("Bonifica completata: %d minacce rimosse e messe in quarantena." % count)
	_update_scan_ui()
	_update_permissions()
	
	if status_badge:
		status_badge.text = "● INTEGRITÀ 100% (SECURE)"
		status_badge.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4, 1.0))
	
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("Bonifica completata: %d minacce neutralizzate." % count)

func _update_scan_ui() -> void:
	if scan_progress_bar:
		scan_progress_bar.value = scan_progress
	
	if scan_status_label:
		if is_scanning:
			scan_status_label.text = "Scansione in corso... %.1f%%" % scan_progress
		else:
			scan_status_label.text = "Scansione terminata. Rilevate %d minacce." % detected_threats.size()
	
	if integrity_score_label:
		integrity_score_label.text = "Integrità Sistema: %.0f%%" % system_integrity_score
		if system_integrity_score >= 90.0:
			integrity_score_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4, 1.0))
		elif system_integrity_score >= 60.0:
			integrity_score_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2, 1.0))
		else:
			integrity_score_label.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25, 1.0))
	
	if threats_list:
		threats_list.clear()
		if detected_threats.is_empty():
			threats_list.add_item("✔ Nessuna minaccia rilevata nel file system. Firma logica integra.")
		else:
			for t in detected_threats:
				var prefix := "🔴 [CRITICA]" if t.get("severity") == "CRITICAL" else "🟡 [AVVISO]"
				threats_list.add_item("%s %s (%s) - %s" % [prefix, t.get("name", "Anomalia"), t.get("path", ""), t.get("desc", "")])

# --- MODULO 2: PANNELLO ICE & DIFESA FIREWALL ---

func _on_reinforce_ice_pressed() -> void:
	if not can_control_diagnostics:
		return
	reinforce_ice(25.0)

func reinforce_ice(amount: float = 25.0) -> void:
	current_ice_strength = minf(current_ice_strength + amount, max_ice_strength)
	_log_audit("Barriera ICE rinforzata: +%.1f HP (Stato attuale: %.1f/%.1f)" % [amount, current_ice_strength, max_ice_strength])
	_update_ice_ui()
	
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("ICE Rinforzato: %.0f/%.0f HP" % [current_ice_strength, max_ice_strength])

func _on_flush_firewall_pressed() -> void:
	if not can_control_diagnostics:
		return
	flush_firewall_cache()

func flush_firewall_cache() -> void:
	for k in ice_nodes_status:
		ice_nodes_status[k]["integrity"] = 100.0
		ice_nodes_status[k]["status"] = "SECURE"
	
	_log_audit("Flush cache firewall eseguito: porte chiuse e pacchetti sospetti azzerati.")
	_update_ice_ui()
	
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("Firewall: Cache svuotata e nodi ripristinati.")

func simulate_cyber_attack(intensity: float = 20.0, node_key: String = "comms") -> void:
	current_ice_strength = maxf(current_ice_strength - intensity, 0.0)
	if ice_nodes_status.has(node_key):
		ice_nodes_status[node_key]["integrity"] = maxf(ice_nodes_status[node_key]["integrity"] - intensity * 1.5, 10.0)
		ice_nodes_status[node_key]["status"] = "ATTACKED"
	
	_log_audit("⚠️ ALLARME INTRUSIONE: Attacco informatico rilevato sul nodo %s! Danno ICE: -%.1f" % [node_key, intensity])
	_update_ice_ui()
	
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("⚠️ Allarme Cyber Warfare: Barriera ICE sotto attacco!")

func _update_ice_ui() -> void:
	if ice_progress_bar:
		ice_progress_bar.max_value = max_ice_strength
		ice_progress_bar.value = current_ice_strength
	
	if ice_value_label:
		var pct := (current_ice_strength / max_ice_strength) * 100.0 if max_ice_strength > 0 else 0.0
		ice_value_label.text = "Integrità ICE: %.1f / %.1f HP (%.0f%%)" % [current_ice_strength, max_ice_strength, pct]
	
	if ice_badge:
		ice_badge.text = "🛡️ ICE: %.0f/%.0f" % [current_ice_strength, max_ice_strength]
		if current_ice_strength >= 70.0:
			ice_badge.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4, 1.0))
		elif current_ice_strength >= 35.0:
			ice_badge.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2, 1.0))
		else:
			ice_badge.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25, 1.0))
	
	# Aggiorna label dei singoli nodi
	if node_avionics_status: _format_node_label(node_avionics_status, "avionics")
	if node_reactor_status: _format_node_label(node_reactor_status, "reactor")
	if node_comms_status: _format_node_label(node_comms_status, "comms")
	if node_weapons_status: _format_node_label(node_weapons_status, "weapons")
	if node_mainframe_status: _format_node_label(node_mainframe_status, "mainframe")

func _format_node_label(lbl: Label, key: String) -> void:
	if not ice_nodes_status.has(key): return
	var data: Dictionary = ice_nodes_status[key]
	var integ: float = float(data.get("integrity", 100.0))
	var st: String = str(data.get("status", "SECURE"))
	lbl.text = "%s: %.0f%% [%s]" % [data.get("name", key), integ, st]
	if st == "SECURE":
		lbl.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0, 1.0))
	else:
		lbl.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25, 1.0))

# --- MODULO 3: RIPRISTINO FIRMWARE & FACTORY RESET ---

func _on_factory_reset_pressed() -> void:
	if not can_control_diagnostics or is_factory_resetting:
		return
	
	var selected_idx := subsystem_option.selected if subsystem_option else 0
	var target_sub := "ALL"
	match selected_idx:
		1: target_sub = "FlightControls"
		2: target_sub = "Cams"
		3: target_sub = "DuctDrone"
		4: target_sub = "PowerGrid"
		5: target_sub = "Weapons"
		6: target_sub = "ShieldMatrix"
		7: target_sub = "Comms"
		8: target_sub = "Diagnostics"
		9: target_sub = "Sensors"
		10: target_sub = "LifeSupport"
		_: target_sub = "ALL"
	
	start_factory_reset(target_sub)

func start_factory_reset(subsystem_name: String) -> void:
	reset_target_subsystem = subsystem_name
	is_factory_resetting = true
	reset_progress = 0.0
	reset_timer_target = maxf(float(active_config.get("factory_reset_delay_sec", 3.0)), 0.1)
	
	_log_audit("Avvio procedura Factory Reset per target: %s (Attesa: %.1fs)" % [subsystem_name, reset_timer_target])
	
	if btn_factory_reset:
		btn_factory_reset.disabled = true
	
	_update_reset_ui()

func _finish_factory_reset() -> void:
	is_factory_resetting = false
	if btn_factory_reset:
		btn_factory_reset.disabled = not can_control_diagnostics
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	var restored_files_count := 0
	
	var targets: Array[String] = []
	if reset_target_subsystem == "ALL":
		targets.append_array(SUBSYSTEM_FACTORY_DEFAULTS.keys())
	elif SUBSYSTEM_FACTORY_DEFAULTS.has(reset_target_subsystem):
		targets.append(reset_target_subsystem)
	
	for sub_key in targets:
		var sub_data: Dictionary = SUBSYSTEM_FACTORY_DEFAULTS[sub_key]
		var files_map: Dictionary = sub_data.get("files", {})
		for rel_path in files_map:
			var default_content: String = files_map[rel_path]
			var abs_path := "user://files/%s" % rel_path
			var base_dir := abs_path.get_base_dir()
			if not DirAccess.dir_exists_absolute(base_dir):
				DirAccess.make_dir_recursive_absolute(base_dir)
			
			var f := FileAccess.open(abs_path, FileAccess.WRITE)
			if f:
				f.store_string(default_content)
				f.close()
				restored_files_count += 1
				if sdm and sdm.has_method("sync_file"):
					sdm.sync_file(rel_path, default_content)
				elif sdm and sdm.has_signal("file_synced"):
					sdm.file_synced.emit(rel_path)
	
	# Se è stato resettato Diagnostics, ricarica i valori attivi
	if reset_target_subsystem == "ALL" or reset_target_subsystem == "Diagnostics":
		load_dat_configuration()
	
	_log_audit("✔ Factory Reset completato: %d file di configurazione .DAT ripristinati." % restored_files_count)
	_update_reset_ui()
	_update_firmware_ui()
	
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("Factory Reset completato (%d file ripristinati)." % restored_files_count)

func _update_reset_ui() -> void:
	if reset_progress_bar:
		reset_progress_bar.value = reset_progress
	
	if reset_status_label:
		if is_factory_resetting:
			reset_status_label.text = "Ripristino in corso [%s]... %.0f%%" % [reset_target_subsystem, reset_progress]
		else:
			reset_status_label.text = "Pronto. Ultimo ripristino: %s." % reset_target_subsystem

func _update_firmware_ui() -> void:
	if not firmware_status_text:
		return
	
	var text := "[b]Stato Firmware Mainframe:[/b]\n"
	for sub_name in SUBSYSTEM_FACTORY_DEFAULTS:
		var cfg_p: String = "Ship Drive/Programs/%s/%s_config.dat" % [sub_name, sub_name.to_snake_case()]
		var exists := FileAccess.file_exists("user://files/" + cfg_p)
		var status_col := "green" if exists else "yellow"
		var status_str := "ONLINE (VALIDATO)" if exists else "NON PRESENTE (FALLBACK)"
		text += "- [color=%s]● %s[/color]: %s\n" % [status_col, sub_name, status_str]
	
	firmware_status_text.text = text

# --- LOG AUDIT E AZIONI ---

func _on_reload_dat_pressed() -> void:
	load_dat_configuration()
	_log_audit("Ricarica manuale parametri .DAT forzata dall'operatore.")
	
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("Parametri .DAT ricaricati con successo.")

func _on_clear_log_pressed() -> void:
	if audit_log_text:
		audit_log_text.clear()
	if ice_log_text:
		ice_log_text.clear()
	_log_audit("Registro eventi pulito.")

func _log_audit(msg: String) -> void:
	var time_str := Time.get_time_string_from_system()
	var formatted := "[%s] %s" % [time_str, msg]
	
	if audit_log_text:
		audit_log_text.append_text(formatted + "\n")
	if ice_log_text:
		ice_log_text.append_text(formatted + "\n")
	if action_log_label:
		action_log_label.text = "Stato: %s" % msg

func _refresh_all_ui() -> void:
	_update_scan_ui()
	_update_ice_ui()
	_update_reset_ui()
	_update_firmware_ui()
	_update_permissions()
