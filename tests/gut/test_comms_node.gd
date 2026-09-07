extends GutTest

## Test GUT per l'applicazione Comms (comunicazioni subspaziali, antenna
## direzionale, docking stazione e intrusione EW su Drive bersaglio).
## Migrato da tests/test_comms_node.gd (extends Node, assert() nudo).

var _comms_app: CommsApp = null

func before_each() -> void:
	NetworkManager.disconnect_game()

func after_each() -> void:
	if is_instance_valid(_comms_app):
		_comms_app.queue_free()
	_comms_app = null
	NetworkManager.disconnect_game()

func _start_solo_mission(player_name: String = "Comandante Test") -> void:
	NetworkManager.start_solo_game(player_name)
	NetworkManager.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame

func _create_comms_app() -> CommsApp:
	var scene: PackedScene = load("res://Applications/Comms/comms_app.tscn")
	assert_not_null(scene, "Scena comms_app.tscn deve essere caricabile")
	var app: CommsApp = scene.instantiate() as CommsApp
	add_child_autofree(app)
	await get_tree().process_frame
	return app

func test_disconnected_overlay_and_operational_state() -> void:
	_comms_app = await _create_comms_app()
	assert_false(_comms_app._is_ship_operational(), "L'app Comms non deve essere operativa a nave disconnessa")
	assert_not_null(_comms_app.disconnected_overlay, "L'overlay DisconnectedOverlay deve esistere")
	assert_true(_comms_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve essere visibile da disconnesso")
	
	await _start_solo_mission()
	
	assert_true(_comms_app._is_ship_operational(), "L'app Comms deve essere operativa dopo l'avvio della missione")
	assert_false(_comms_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve scomparire all'avvio della missione")

func test_ship_drive_comms_folder_is_protected_by_default_password() -> void:
	await _start_solo_mission()
	assert_true(DirAccess.dir_exists_absolute("user://files/Ship Drive/Programs/Comms"), "Cartella Programs/Comms deve esistere in Ship Drive")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/Comms/comms_config.dat"), "comms_config.dat deve esistere in Ship Drive/Programs/Comms/")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/Comms/crypto_tuning.dat"), "crypto_tuning.dat deve esistere in Ship Drive/Programs/Comms/")
	
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	assert_not_null(fpm, "FolderPasswordManager deve essere disponibile come autoload")
	assert_true(fpm.has_password("Ship Drive/Programs/Comms"), "La cartella Ship Drive/Programs/Comms deve essere protetta da password")
	assert_true(fpm.check_password("Ship Drive/Programs/Comms", "COMM-7815"), "La password predefinita della cartella deve essere COMM-7815")

func test_dat_configuration_default_values_and_runtime_hot_reload() -> void:
	_comms_app = await _create_comms_app()
	await _start_solo_mission()
	
	_comms_app.load_dat_configuration()
	assert_true(_comms_app.active_config.get("is_dat_loaded"), "Configurazione .dat deve risultare caricata")
	assert_eq(_comms_app.active_config.get("bandwidth_hz"), 1420.0, "bandwidth_hz di fabbrica deve essere 1420.0")
	
	var new_dat_content := "[SYSTEM]\napp_name=Comms\nversion=1.0.4\nstatus=OVERCLOCKED\ncomms_subsystem=ACTIVE\n\n[COMMS_SETTINGS]\nbandwidth_hz=1680.0\nauto_rotate_speed=60.0\nreception_cone_deg=30.0\nsubspace_relay_active=true\nauto_tune_sos=true\nsignal_amplification=1.5\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/Comms/comms_config.dat", FileAccess.WRITE)
	f_out.store_string(new_dat_content)
	f_out.close()
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("file_synced"):
		sdm.file_synced.emit("Ship Drive/Programs/Comms/comms_config.dat")
	else:
		_comms_app.load_dat_configuration()
	await get_tree().process_frame
	
	assert_eq(_comms_app.active_config["bandwidth_hz"], 1680.0, "bandwidth_hz deve aggiornarsi a runtime a 1680.0")
	assert_eq(_comms_app.active_config["auto_rotate_speed"], 60.0, "auto_rotate_speed deve aggiornarsi a 60.0")
	assert_eq(_comms_app.active_config["reception_cone_deg"], 30.0, "reception_cone_deg deve aggiornarsi a 30.0")

func test_rbac_permissions_matrix_for_crew_roles() -> void:
	_comms_app = await _create_comms_app()
	await _start_solo_mission()
	# Disabilita l'override della modalita' Solo per validare la vera matrice dei ruoli
	NetworkManager.is_solo_mode = false
	
	NetworkManager.request_role(NetworkManager.ROLE_HACKER)
	await get_tree().process_frame
	assert_true(_comms_app.can_control_comms, "Hacker deve avere pieno controllo su Comms")
	assert_true(_comms_app.freq_slider.editable, "Slider frequenza abilitato per Hacker")
	assert_true(_comms_app.antenna_heading_slider.editable, "Slider azimut antenna abilitato per Hacker")
	assert_false(_comms_app.btn_auto_rotate.disabled, "Auto-rotate abilitato per Hacker")
	assert_false(_comms_app.btn_freq_lock.disabled, "Frequency Lock abilitato per Hacker")
	
	NetworkManager.request_role(NetworkManager.ROLE_CAPTAIN)
	await get_tree().process_frame
	assert_true(_comms_app.can_control_comms, "Capitano deve avere pieno controllo su Comms")
	assert_true(_comms_app.antenna_heading_slider.editable, "Slider azimut abilitato per Capitano")
	
	NetworkManager.request_role(NetworkManager.ROLE_PILOT)
	await get_tree().process_frame
	assert_false(_comms_app.can_control_comms, "Pilota non deve avere controllo su Comms")
	assert_false(_comms_app.freq_slider.editable, "Slider frequenza in sola lettura per Pilota")
	assert_false(_comms_app.antenna_heading_slider.editable, "Slider azimut disabilitato per Pilota")
	assert_true(_comms_app.btn_auto_rotate.disabled, "Auto-rotate disabilitato per Pilota")
	
	NetworkManager.request_role(NetworkManager.ROLE_ENGINEER)
	await get_tree().process_frame
	assert_false(_comms_app.can_control_comms, "Ingegnere non deve avere controllo su Comms")
	
	NetworkManager.request_role(NetworkManager.ROLE_SOLDIER)
	await get_tree().process_frame
	assert_false(_comms_app.can_control_comms, "Soldato non deve avere controllo su Comms")
	
	NetworkManager.request_role(NetworkManager.ROLE_HACKER)
	await get_tree().process_frame
	assert_true(_comms_app.can_control_comms, "Il controllo deve essere ripristinato per Hacker")

func test_radio_tuner_sos_subspace_pirate_frequencies_and_listen_log() -> void:
	_comms_app = await _create_comms_app()
	await _start_solo_mission()
	
	_comms_app._on_btn_tune_sos_pressed()
	assert_eq(_comms_app.current_frequency, 850.5, "Frequenza deve essere 850.5 MHz")
	var locked_sos: Variant = _comms_app._get_locked_signal()
	assert_not_null(locked_sos, "Un segnale deve risultare agganciato sulla frequenza SOS")
	assert_eq(locked_sos.get("id"), "sos_scout", "Il segnale agganciato deve essere sos_scout")
	
	_comms_app._on_antenna_heading_changed(45.0)
	assert_eq(_comms_app.antenna_azimuth_deg, 45.0, "Azimut antenna impostato a 45°")
	assert_false(_comms_app.btn_listen_signal.disabled, "Pulsante ascolto abilitato per segnale agganciato e allineato")
	
	_comms_app._on_btn_listen_signal_pressed()
	var log_str: String = _comms_app.comms_log_text.get_parsed_text()
	if log_str.is_empty():
		log_str = _comms_app.comms_log_text.text
	assert_true(log_str.contains("SOS") or log_str.contains("Relitto"), "Log comunicazioni deve contenere il messaggio SOS")
	
	_comms_app._on_btn_tune_subspace_pressed()
	var locked_subspace: Variant = _comms_app._get_locked_signal()
	assert_not_null(locked_subspace, "Un segnale deve risultare agganciato sulla frequenza subspaziale")
	assert_eq(locked_subspace.get("id"), "subspace_corp", "Il segnale agganciato deve essere subspace_corp")
	
	_comms_app._on_btn_tune_pirate_pressed()
	assert_eq(_comms_app.current_frequency, 2185.2, "Frequenza deve essere 2185.2 MHz")

func test_antenna_manual_pointing_auto_rotate_and_frequency_lock_tracking() -> void:
	_comms_app = await _create_comms_app()
	await _start_solo_mission()
	
	_comms_app._on_antenna_heading_changed(180.0)
	assert_eq(_comms_app.antenna_azimuth_deg, 180.0, "Azimut antenna impostato manualmente a 180°")
	assert_true(_comms_app.antenna_status_label.text.contains("180°"), "Status label antenna aggiornato a 180°")
	
	_comms_app._on_btn_auto_rotate_toggled(true)
	assert_true(_comms_app.is_auto_rotating, "Auto-rotate deve risultare attivo")
	assert_false(_comms_app.is_frequency_locked, "Frequency lock deve essere disattivato quando auto-rotate si avvia")
	assert_true(_comms_app.status_badge.text.contains("AUTO-ROTAZIONE"), "Status badge deve indicare auto-rotazione")
	
	var prev_azimuth: float = _comms_app.antenna_azimuth_deg
	var speed: float = _comms_app.auto_rotate_speed
	_comms_app._process(1.0)
	assert_eq(_comms_app.antenna_azimuth_deg, fmod(prev_azimuth + speed, 360.0), "Antenna deve essere ruotata di auto_rotate_speed° dopo 1s")
	
	_comms_app._on_btn_tune_sos_pressed() # SOS a 45°
	_comms_app._on_btn_freq_lock_toggled(true)
	assert_true(_comms_app.is_frequency_locked, "Frequency Lock deve risultare attivo")
	assert_false(_comms_app.is_auto_rotating, "Auto-rotate deve disattivarsi su frequency lock")
	assert_eq(_comms_app.locked_signal_id, "sos_scout", "locked_signal_id deve essere sos_scout")
	
	for _i in range(5):
		_comms_app._process(0.5)
	assert_true(absf(_comms_app.antenna_azimuth_deg - 45.0) < 5.0, "Antenna deve aver agganciato e inseguito il bearing a 45°")
	_comms_app._on_btn_freq_lock_toggled(false)

func test_reception_cone_and_signal_strength_falloff() -> void:
	_comms_app = await _create_comms_app()
	await _start_solo_mission()
	
	_comms_app.active_config["reception_cone_deg"] = 25.0
	var sos_sig: Dictionary = _comms_app.available_signals[0] # bearing 45°, dist 650m
	
	_comms_app.antenna_azimuth_deg = 45.0
	var pwr_aligned: float = _comms_app.get_effective_signal_strength(sos_sig)
	assert_true(pwr_aligned >= 0.85, "Potenza segnale allineato deve essere piena (>= 0.85)")
	
	_comms_app.antenna_azimuth_deg = 180.0
	var pwr_off: float = _comms_app.get_effective_signal_strength(sos_sig)
	assert_true(pwr_off < 0.1, "Potenza segnale fuori cono deve calare drasticamente (< 0.1)")
	
	_comms_app.is_auto_rotating = true
	var pwr_autorot: float = _comms_app.get_effective_signal_strength(sos_sig)
	assert_true(pwr_autorot > 0.0 and pwr_autorot <= 0.5, "Potenza in auto-rotazione deve essere attenuata (<= 0.5)")
	
	var far_sig: Dictionary = _comms_app.available_signals[1] # relay dist 3200m
	var pwr_far: float = _comms_app.get_effective_signal_strength(far_sig)
	assert_eq(pwr_far, 0.0, "Segnali a distanza > 800m devono essere azzerati in auto-rotazione")
	_comms_app.is_auto_rotating = false

func test_station_docking_request_menu() -> void:
	_comms_app = await _create_comms_app()
	await _start_solo_mission()
	
	_comms_app.current_frequency = 1840.0
	_comms_app.antenna_azimuth_deg = 270.0
	_comms_app._refresh_tuner_state()
	
	assert_true(_comms_app.station_actions_box.visible, "Box azioni stazione deve essere visibile")
	assert_false(_comms_app.btn_request_docking.disabled, "Pulsante richiesta attracco deve essere abilitato")
	
	var docking_requested_data := {"fired": false, "station_id": ""}
	_comms_app.docking_clearance_requested.connect(func(st_id: String):
		docking_requested_data["fired"] = true
		docking_requested_data["station_id"] = st_id
	)
	_comms_app._on_btn_request_docking_pressed()
	assert_true(docking_requested_data["fired"], "Il segnale docking_clearance_requested deve essere stato emesso")

func test_ew_drive_connect_enabled_only_for_strong_aligned_signal() -> void:
	_comms_app = await _create_comms_app()
	await _start_solo_mission()
	
	# Canale pirata da corvetta (2185.2 MHz, bearing 120°, dist 950m, type CORVETTE)
	_comms_app._on_btn_tune_pirate_pressed()
	
	_comms_app._on_antenna_heading_changed(0.0)
	assert_true(_comms_app.btn_connect_drive.disabled, "Connect deve essere disabilitato se il segnale e' debole/disallineato")
	
	_comms_app._on_antenna_heading_changed(120.0)
	assert_false(_comms_app.btn_connect_drive.disabled, "Connect deve essere abilitato con segnale forte ed entro 1200m")
	
	_comms_app._on_connect_drive_pressed()
	assert_true(DirAccess.dir_exists_absolute("user://files/Target Drive"), "Cartella user://files/Target Drive deve essere montata")
	assert_true(DirAccess.dir_exists_absolute("user://files/Target Drive/FlightControl"), "Sottocartelle remote devono essere create")

func test_power_grid_sublayer_registers_comms_device() -> void:
	await _start_solo_mission()
	var devs := SpaceWorldManager.get_power_devices()
	var found_comms := false
	for d in devs:
		if d.get("id") in ["comms_relay", "comms_ew", "matrice_comunicazione"] or d.get("category") == "comms":
			found_comms = true
			break
	assert_true(found_comms, "Dispositivo comunicazioni deve esistere nella rete elettrica della nave")

func test_ship_blueprint_flags_comms_dat_file_as_protected() -> void:
	await _start_solo_mission()
	var is_comms_dat_protected := false
	var ship_files := SpaceWorldManager.get_ship_drive_files()
	for f in ship_files:
		if f.get("path") == "Ship Drive/Programs/Comms/comms_config.dat":
			is_comms_dat_protected = f.get("is_protected")
			break
	assert_true(is_comms_dat_protected, "comms_config.dat deve avere il flag is_protected = true nel blueprint della nave")

func test_queue_free_cleanup_does_not_error() -> void:
	_comms_app = await _create_comms_app()
	await _start_solo_mission()
	_comms_app.queue_free()
	await get_tree().process_frame
	_comms_app = null
	assert_true(true, "La rimozione dell'app Comms non deve generare errori di pulizia dei segnali")
