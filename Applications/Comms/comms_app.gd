class_name CommsApp
extends BaseApp

## Applicazione GodotOS per le Comunicazioni Subspaziali, Guerra Elettronica (EW) e Decodifica Cifrari (Hackwarfare).
## Conforme allo standard architetturale di bordo (APP_ARCHITECTURE_STANDARD.md).
## Punto 5.4 del Documento di Feature Design Dark Nova.

const APP_TITLE: String = "Communications, Electronic Warfare & Hackwarfare"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(680, 480)

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

# Guerra Elettronica (EW)
@onready var jammer_switch: CheckButton = get_node_or_null("%JammerSwitch")
@onready var jammer_power_slider: HSlider = get_node_or_null("%JammerPowerSlider")
@onready var jammer_power_label: Label = get_node_or_null("%JammerPowerLabel")
@onready var jammer_mode_option: OptionButton = get_node_or_null("%JammerModeOption")
@onready var spoof_signature_option: OptionButton = get_node_or_null("%SpoofSignatureOption")
@onready var jammer_effect_label: Label = get_node_or_null("%JammerEffectLabel")

# Modulo Hackwarfare & Cifrari
@onready var cipher_package_option: OptionButton = get_node_or_null("%CipherPackageOption")
@onready var decryption_progress_bar: ProgressBar = get_node_or_null("%DecryptionProgressBar")
@onready var decryption_status_label: Label = get_node_or_null("%DecryptionStatusLabel")
@onready var btn_start_decrypt: Button = get_node_or_null("%BtnStartDecrypt")
@onready var extracted_key_edit: LineEdit = get_node_or_null("%ExtractedKeyEdit")
@onready var btn_save_to_ship_drive: Button = get_node_or_null("%BtnSaveToShipDrive")

# Registro Comunicazioni & Log
@onready var comms_log_text: RichTextLabel = get_node_or_null("%CommsLogText")
@onready var btn_clear_log: Button = get_node_or_null("%BtnClearLog")
@onready var action_log_label: Label = get_node_or_null("%ActionLogLabel")

# --- STATO OPERATIVO E PARAMETRI RUNTIME ---
var current_frequency: float = 1420.0
var is_jamming_active: bool = false
var jamming_power_mw: float = 120.0
var jamming_mode: int = 0 # 0: Radar Blind, 1: Full Spectrum
var current_spoof_sig: String = "CORVETTE_CIVILIAN"

var is_decrypting: bool = false
var decryption_progress: float = 0.0
var selected_package_index: int = 0
var last_decrypted_text: String = ""

var can_control_comms: bool = true
var is_comms_powered: bool = true

# Parametri .DAT attivi con fallback ai valori di default
var active_config: Dictionary = {
	"bandwidth_hz": 1420.0,
	"decryption_speed_multiplier": 1.0,
	"subspace_relay_active": true,
	"auto_tune_sos": true,
	"signal_amplification": 1.2,
	"jamming_power_mw": 120.0,
	"signal_noise_ratio": 0.85,
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
		"unlocked": true
	},
	{
		"id": "subspace_corp",
		"freq": 1420.0,
		"strength": 0.9,
		"name": "🌐 [RETE SUBSPAZIALE] Weyland-Yutani Corp Relay",
		"desc": "Bollettino commerciale e direttive corporative di settore. Canale idrogeno attivo.",
		"source": "Mainframe Subspazio",
		"unlocked": true
	},
	{
		"id": "station_trading",
		"freq": 1840.0,
		"strength": 0.8,
		"name": "📻 [CANALE CIVILE] Stazione Spaziale Freccia",
		"desc": "Aggiornamento prezzi combustibile e disponibilità baia d'attracco.",
		"source": "Torre di Controllo Freccia",
		"unlocked": true
	},
	{
		"id": "pirate_encrypted",
		"freq": 2185.2,
		"strength": 0.75,
		"name": "🏴‍☠️ [BURST CRITTOGRAFATO] Canale Pirata Clandestino",
		"desc": "Trasmissione a pacchetti cifrati. Richiede modulo Hackwarfare per estrazione dati.",
		"source": "Predoni della Cintura",
		"unlocked": false
	},
	{
		"id": "deep_space_beacon",
		"freq": 2750.0,
		"strength": 0.6,
		"name": "🛰️ [RADIONAVIGAZIONE] Faro Deep Space Alpha",
		"desc": "Sincronizzazione orologio atomico e dati gravitazionali di settore.",
		"source": "Faro Navigazione Stella 78",
		"unlocked": true
	}
]

# Pacchetti crittografati recuperati da decifrare
var encrypted_packages: Array[Dictionary] = [
	{
		"id": "pkg_drone_firmware",
		"name": "📦 Sonda Spaziale Relitto #41 - Firmware .DAT",
		"difficulty": 1.0,
		"extracted_key": "DRONE-7815",
		"intel_text": "Firmware crittografato recuperato da drone manutenzione derelitto. Password di sblocco: DRONE-7815"
	},
	{
		"id": "pkg_pirate_burst",
		"name": "📦 Burst Crittografato Pirata - Credenziali Stazione",
		"difficulty": 1.4,
		"extracted_key": "PIRATE-BURST-882",
		"intel_text": "Intercettazione comunicazioni pirata. Chiave d'accesso per il mercato nero: PIRATE-BURST-882"
	},
	{
		"id": "pkg_corp_directive",
		"name": "📦 Direttiva Segreta Weyland-Yutani Corp",
		"difficulty": 1.8,
		"extracted_key": "COMM-7815",
		"intel_text": "Direttiva corporativa confidenziale. Password cartella di sicurezza Comms: COMM-7815"
	}
]

func _ready() -> void:
	_configure_window(APP_TITLE, DEFAULT_WINDOW_SIZE)
	_populate_options_ui()
	_connect_system_signals()
	_setup_ui_signals()
	_update_connection_state()
	load_dat_configuration()
	_update_permissions()
	_refresh_ui_display()
	_log_comms_message("[color=#64c8ff][SISTEMA][/color] Suite Comunicazioni Subspaziali & EW inizializzata.")

func _populate_options_ui() -> void:
	# Opzioni Modalità Jammer
	if jammer_mode_option:
		jammer_mode_option.clear()
		jammer_mode_option.add_item("Radar Blind (Acceca Sensori & Missili)", 0)
		jammer_mode_option.add_item("Full Spectrum (Blackout Comms Locali)", 1)
		jammer_mode_option.selected = 0
	
	# Opzioni Firme Spoofing IFF
	if spoof_signature_option:
		spoof_signature_option.clear()
		spoof_signature_option.add_item("CORVETTE_CIVILIAN (Corvetta Civile)", 0)
		spoof_signature_option.add_item("CARGO_HAULER_MINING (Cargo Minerario Pesante)", 1)
		spoof_signature_option.add_item("DERELICT_DEBRIS (Relitto Disattivato)", 2)
		spoof_signature_option.add_item("MILITARY_ESCORT (Scorta Militare Pesante)", 3)
		spoof_signature_option.selected = 0
	
	# Opzioni Pacchetti Cifrati
	if cipher_package_option:
		cipher_package_option.clear()
		for i in range(encrypted_packages.size()):
			var pkg: Dictionary = encrypted_packages[i]
			cipher_package_option.add_item(pkg.get("name"), i)
		cipher_package_option.selected = 0

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
	
	if jammer_switch and not jammer_switch.toggled.is_connected(_on_jammer_toggled):
		jammer_switch.toggled.connect(_on_jammer_toggled)
	
	if jammer_power_slider and not jammer_power_slider.value_changed.is_connected(_on_jammer_power_changed):
		jammer_power_slider.value_changed.connect(_on_jammer_power_changed)
	
	if jammer_mode_option and not jammer_mode_option.item_selected.is_connected(_on_jammer_mode_selected):
		jammer_mode_option.item_selected.connect(_on_jammer_mode_selected)
	
	if spoof_signature_option and not spoof_signature_option.item_selected.is_connected(_on_spoof_signature_selected):
		spoof_signature_option.item_selected.connect(_on_spoof_signature_selected)
	
	if cipher_package_option and not cipher_package_option.item_selected.is_connected(_on_cipher_package_selected):
		cipher_package_option.item_selected.connect(_on_cipher_package_selected)
	
	if btn_start_decrypt and not btn_start_decrypt.pressed.is_connected(_on_btn_start_decrypt_pressed):
		btn_start_decrypt.pressed.connect(_on_btn_start_decrypt_pressed)
	
	if btn_save_to_ship_drive and not btn_save_to_ship_drive.pressed.is_connected(_on_btn_save_to_ship_drive_pressed):
		btn_save_to_ship_drive.pressed.connect(_on_btn_save_to_ship_drive_pressed)
	
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
	
	# Gestione avanzamento decrittazione mini-gioco Hackwarfare
	if is_decrypting:
		var current_pkg: Dictionary = encrypted_packages[selected_package_index]
		var diff: float = current_pkg.get("difficulty")
		var speed_mult: float = float(active_config.get("decryption_speed_multiplier")) * float(active_config.get("crypto_crack_speed"))
		var step := (delta * 30.0 * speed_mult) / maxf(diff, 0.2)
		
		decryption_progress = clampf(decryption_progress + step, 0.0, 100.0)
		if decryption_progress_bar:
			decryption_progress_bar.value = decryption_progress
		if decryption_status_label:
			decryption_status_label.text = "Decrittazione in corso: %.1f%%..." % decryption_progress
		
		if decryption_progress >= 100.0:
			_complete_decryption()

# --- GESTIONE DELLO STATO OPERATIVO / CONNESSIONE ---
func _is_ship_operational() -> bool:
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		return SpaceWorldManager.is_ship_connected()
	if NetworkManager and NetworkManager.has_method("is_ship_connected"):
		return NetworkManager.is_ship_connected()
	return false

func _on_ship_connection_changed(_is_connected: bool) -> void:
	_update_connection_state()

func _on_mission_started() -> void:
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
		if NetworkManager.has_method("has_active_session"):
			is_solo = NetworkManager.is_solo_mode or not NetworkManager.has_active_session()
		else:
			is_solo = NetworkManager.is_solo_mode or my_role.is_empty()
	
	can_control_comms = (my_role.is_empty() or my_role == "Hacker" or my_role == "Capitano" or my_role == "Stagista" or my_role == "Pilota" or my_role == "Ingegnere" or my_role == "Captain" or my_role == "Pilot" or is_solo)
	
	# Disabilita/abilita comandi attivi
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
	
	if jammer_switch:
		jammer_switch.disabled = not can_control_comms
	if jammer_power_slider:
		jammer_power_slider.editable = can_control_comms
	if jammer_mode_option:
		jammer_mode_option.disabled = not can_control_comms
	if spoof_signature_option:
		spoof_signature_option.disabled = not can_control_comms
	
	if cipher_package_option:
		cipher_package_option.disabled = not can_control_comms
	if btn_start_decrypt:
		btn_start_decrypt.disabled = not can_control_comms or is_decrypting
	if btn_save_to_ship_drive:
		btn_save_to_ship_drive.disabled = not can_control_comms or last_decrypted_text.is_empty()

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
	jamming_power_mw = float(active_config.get("jamming_power_mw"))
	current_spoof_sig = str(active_config.get("spoofing_signature"))
	
	if jammer_power_slider:
		jammer_power_slider.value = jamming_power_mw
	
	# Imposta la firma di spoofing corrispondente se presente nella lista
	if spoof_signature_option:
		for i in range(spoof_signature_option.item_count):
			var item_txt := spoof_signature_option.get_item_text(i)
			if current_spoof_sig in item_txt:
				spoof_signature_option.selected = i
				break
	
	_refresh_ui_display()
	_update_action_log("Configurazione .DAT ricaricata con successo.")

func _on_freq_slider_changed(new_val: float) -> void:
	current_frequency = new_val
	_refresh_tuner_state()

func _on_btn_tune_sos_pressed() -> void:
	if not can_control_comms:
		return
	current_frequency = 850.5
	if freq_slider:
		freq_slider.value = current_frequency
	_refresh_tuner_state()
	_update_action_log("Sintonizzato automaticamente su frequenza SOS di emergenza (850.5 MHz).")

func _on_btn_tune_subspace_pressed() -> void:
	if not can_control_comms:
		return
	current_frequency = 1420.0
	if freq_slider:
		freq_slider.value = current_frequency
	_refresh_tuner_state()
	_update_action_log("Sintonizzato su Relay Subspaziale Principale (1420.0 MHz).")

func _on_btn_tune_pirate_pressed() -> void:
	if not can_control_comms:
		return
	current_frequency = 2185.2
	if freq_slider:
		freq_slider.value = current_frequency
	_refresh_tuner_state()
	_update_action_log("Sintonizzato su Burst Cifrato Pirata (2185.2 MHz).")

func _refresh_tuner_state() -> void:
	if freq_value_label:
		freq_value_label.text = "%.1f MHz" % current_frequency
	
	var locked_sig: Variant = _get_locked_signal()
	if locked_sig != null:
		if signal_lock_badge:
			signal_lock_badge.text = "🔒 AGGANCIATO: %s" % locked_sig.get("name")
			signal_lock_badge.modulate = Color(0.2, 1.0, 0.4)
		if signal_info_label:
			signal_info_label.text = "%s\nSorgente: %s" % [locked_sig.get("desc"), locked_sig.get("source")]
		if btn_listen_signal:
			btn_listen_signal.disabled = not can_control_comms
	else:
		if signal_lock_badge:
			signal_lock_badge.text = "⚪ RUMORE BIANCO / NESSUN AGGANCIO"
			signal_lock_badge.modulate = Color(0.6, 0.7, 0.8)
		if signal_info_label:
			signal_info_label.text = "Scorrere il cursore per intercettare portanti RF o trasmissioni subspaziali attive."
		if btn_listen_signal:
			btn_listen_signal.disabled = true
	
	if waterfall_canvas:
		waterfall_canvas.update_state(current_frequency, is_jamming_active, jamming_power_mw, _is_ship_operational(), available_signals)

func _get_locked_signal() -> Variant:
	for sig in available_signals:
		var sig_freq: float = sig.get("freq")
		if absf(current_frequency - sig_freq) <= 15.0:
			return sig
	return null

func _on_btn_listen_signal_pressed() -> void:
	if not can_control_comms:
		return
	var sig: Variant = _get_locked_signal()
	if sig != null:
		_log_comms_message("[color=#ffdd55][RICEZIONE][/color] %s: %s (Fonte: %s)" % [sig.get("name"), sig.get("desc"), sig.get("source")])
		_update_action_log("Messaggio trascritto nel registro di bordo.")

# --- LOGICA APPLICATIVA: GUERRA ELETTRONICA (EW) ---
func _on_jammer_toggled(button_pressed: bool) -> void:
	if not can_control_comms:
		if jammer_switch:
			jammer_switch.set_pressed_no_signal(is_jamming_active)
		return
	
	is_jamming_active = button_pressed
	if is_jamming_active:
		_log_comms_message("[color=#ff5555][GUERRA ELETTRONICA][/color] ⚡ JAMMER ATTIVATO a %.0f MW. Raggio di disturbo: %.0f m." % [jamming_power_mw, float(active_config.get("jamming_radius"))])
		_update_action_log("Jammer attivo: sensori nemici disturbati.")
	else:
		_log_comms_message("[color=#64c8ff][GUERRA ELETTRONICA][/color] Jammer disattivato. Emissione normale.")
		_update_action_log("Jammer disattivato.")
	
	_refresh_ui_display()

func _on_jammer_power_changed(new_val: float) -> void:
	jamming_power_mw = new_val
	if jammer_power_label:
		jammer_power_label.text = "%.0f MW" % jamming_power_mw
	if jammer_effect_label:
		var radius_calc: float = float(active_config.get("jamming_radius")) * (jamming_power_mw / 120.0)
		jammer_effect_label.text = "Efficienza Jammer: %.0f%% | Raggio: %.0f m" % [(jamming_power_mw / 180.0) * 100.0, radius_calc]
	
	if waterfall_canvas:
		waterfall_canvas.update_state(current_frequency, is_jamming_active, jamming_power_mw, _is_ship_operational(), available_signals)
	_refresh_ui_display()

func _on_jammer_mode_selected(index: int) -> void:
	jamming_mode = index
	var mode_name := "Radar Blind" if jamming_mode == 0 else "Full Spectrum"
	_update_action_log("Modalità Jammer impostata su: %s" % mode_name)

func _on_spoof_signature_selected(index: int) -> void:
	if not can_control_comms:
		return
	if spoof_signature_option:
		var raw_txt := spoof_signature_option.get_item_text(index)
		current_spoof_sig = raw_txt.split(" ")[0]
	_log_comms_message("[color=#ff9933][SPOOFING IFF][/color] Transponder nave falsificato con firma: %s" % current_spoof_sig)
	_update_action_log("Transponder IFF impostato su: %s" % current_spoof_sig)

# --- LOGICA APPLICATIVA: HACKWARFARE & DECODIFICA CIFRARI ---
func _on_cipher_package_selected(index: int) -> void:
	selected_package_index = index
	decryption_progress = 0.0
	is_decrypting = false
	last_decrypted_text = ""
	if decryption_progress_bar:
		decryption_progress_bar.value = 0.0
	if decryption_status_label:
		decryption_status_label.text = "Pronto per la decrittazione."
	if extracted_key_edit:
		extracted_key_edit.text = ""
	if btn_save_to_ship_drive:
		btn_save_to_ship_drive.disabled = true
	if btn_start_decrypt:
		btn_start_decrypt.disabled = not can_control_comms

func _on_btn_start_decrypt_pressed() -> void:
	if not can_control_comms or is_decrypting:
		return
	
	is_decrypting = true
	decryption_progress = 0.0
	if btn_start_decrypt:
		btn_start_decrypt.disabled = true
	if decryption_status_label:
		decryption_status_label.text = "Inizializzazione algoritmo di violazione cifrario..."
	_log_comms_message("[color=#ff00ff][HACKWARFARE][/color] Avviata violazione cifrario su: %s" % encrypted_packages[selected_package_index].get("name"))
	_update_action_log("Decrittazione avviata...")

func _complete_decryption() -> void:
	is_decrypting = false
	var current_pkg: Dictionary = encrypted_packages[selected_package_index]
	var extracted_key: String = current_pkg.get("extracted_key")
	var intel_text: String = current_pkg.get("intel_text")
	last_decrypted_text = "[%s]\nCHIAVE / PASSWORD: %s\nINFO: %s" % [current_pkg.get("name"), extracted_key, intel_text]
	
	if extracted_key_edit:
		extracted_key_edit.text = "🔑 CHIAVE ESTRATTA: %s" % extracted_key
	if decryption_status_label:
		decryption_status_label.text = "✔ DECODIFICA COMPLETATA CON SUCCESSO!"
	if btn_start_decrypt:
		btn_start_decrypt.disabled = false
	if btn_save_to_ship_drive:
		btn_save_to_ship_drive.disabled = not can_control_comms
	
	_log_comms_message("[color=#00ff88][DECODIFICA COMPLETATA][/color] %s -> Chiave estratta: [b]%s[/b]" % [current_pkg.get("name"), extracted_key])
	_update_action_log("Violazione riuscita! Password estratta: %s" % extracted_key)
	
	var notif_mgr := get_node_or_null("/root/NotificationManager")
	if notif_mgr and notif_mgr.has_method("send_notification"):
		notif_mgr.send_notification("Comms Hackwarfare", "Chiave crittografica estratta: %s" % extracted_key)

func _on_btn_save_to_ship_drive_pressed() -> void:
	if not can_control_comms or last_decrypted_text.is_empty():
		return
	
	var export_path := "Ship Drive/intercepted_crypto_key.txt"
	var abs_p := "user://files/%s" % export_path
	var base_dir := abs_p.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)
	var f := FileAccess.open(abs_p, FileAccess.WRITE)
	if f:
		f.store_string(last_decrypted_text)
		f.close()
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_method("sync_file"):
		sdm.sync_file(export_path, last_decrypted_text)
	
	_log_comms_message("[color=#64c8ff][SHIP DRIVE][/color] File salvato con successo: %s" % export_path)
	_update_action_log("Salvato su Ship Drive: %s" % export_path)

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
func _refresh_ui_display() -> void:
	# Calcolo Assorbimento Potenza (50 MW base quando online + jamming power se attivo)
	var base_power := 50.0
	var total_power := base_power + (jamming_power_mw if is_jamming_active else 0.0)
	
	if power_badge:
		power_badge.text = "⚡ %d MW" % int(total_power)
	
	if status_badge:
		if not _is_ship_operational():
			status_badge.text = "● OFFLINE"
			status_badge.modulate = Color(0.9, 0.3, 0.3)
		elif is_jamming_active:
			status_badge.text = "⚡ EW JAMMING ATTIVO"
			status_badge.modulate = Color(1.0, 0.6, 0.2)
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
		var st_mgr = get_node_or_null("/root/StationManager")
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
		if SpaceWorldManager and SpaceWorldManager.has_method("get_station_entity"):
			target_station = SpaceWorldManager.get_station_entity()
		elif is_inside_tree():
			var found_st = get_tree().root.find_child("SpaceStationEntity", true, false)
			if found_st is SpaceStationEntity:
				target_station = found_st
	
	if not target_station:
		_log_comms_message("[color=#ff5555][DOCKING][/color] Nessuna stazione rilevata sulla frequenza attuale o nei paraggi.")
		docking_clearance_denied.emit("", "Nessuna stazione rilevata")
		return false
	
	docking_clearance_requested.emit(target_station.station_id)
	_log_comms_message("[color=#64c8ff][DOCKING][/color] Richiesta autorizzazione attracco inviata a %s su %.1f MHz..." % [target_station.station_name, current_frequency])
	return target_dm.request_docking_clearance(target_station, "NOVA-ROGUE-01", current_spoof_sig)

func _on_docking_clearance_granted(station_id: String, bay_id: int, message: String) -> void:
	docking_clearance_granted.emit(station_id, bay_id)
	_log_comms_message("[color=#00ff88][DOCKING AUTORIZZATO][/color] Stazione %s: %s" % [station_id, message])
	_update_action_log("Autorizzazione attracco concessa: Bay 0%d." % (bay_id + 1))
	var nm = get_node_or_null("/root/NotificationManager")
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
	var nm = get_node_or_null("/root/NotificationManager")
	if nm and nm.has_method("send_notification"):
		nm.send_notification("Controllo Portuale", "Attracco completato. Servizi Station Hub operativi.")
	elif nm and nm.has_method("spawn_notification"):
		nm.spawn_notification("Attracco completato. Servizi Station Hub operativi.")

func _on_undocking_completed_event() -> void:
	is_docked = false
	_log_comms_message("[color=#64c8ff][UNDOCKING][/color] Disinnesto magnetico eseguito. Nave in assetto libero di navigazione.")
	_update_action_log("Disinnesto stazione completato.")
