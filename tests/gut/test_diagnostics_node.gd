extends GutTest

## Test GUT per l'applicazione Diagnostics (scanner integrità di sistema,
## sicurezza cyber, difesa ICE e ripristino firmware .DAT di fabbrica).
## Migrato da tests/test_diagnostics_node.gd (extends Node, assert() nudo).

var _diag_app: DiagnosticsApp = null

func before_each() -> void:
	NetworkManager.disconnect_game()

func after_each() -> void:
	if is_instance_valid(_diag_app):
		_diag_app.queue_free()
	_diag_app = null
	NetworkManager.disconnect_game()

func _start_solo_mission(player_name: String = "Comandante Test") -> void:
	NetworkManager.start_solo_game(player_name)
	NetworkManager.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame

func _create_diag_app() -> DiagnosticsApp:
	var scene: PackedScene = load("res://Applications/Diagnostics/diagnostics_app.tscn")
	assert_not_null(scene, "Scena diagnostics_app.tscn deve essere caricabile")
	var app: DiagnosticsApp = scene.instantiate() as DiagnosticsApp
	add_child_autofree(app)
	await get_tree().process_frame
	return app

func test_disconnected_overlay_and_operational_state() -> void:
	_diag_app = await _create_diag_app()
	assert_false(_diag_app._is_ship_operational(), "L'app Diagnostics non deve essere operativa a nave disconnessa")
	assert_not_null(_diag_app.disconnected_overlay, "L'overlay DisconnectedOverlay deve esistere")
	assert_true(_diag_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve essere visibile da disconnesso")
	
	await _start_solo_mission()
	
	assert_true(_diag_app._is_ship_operational(), "L'app Diagnostics deve essere operativa dopo l'avvio della missione")
	assert_false(_diag_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve scomparire all'avvio della missione")

func test_ship_drive_diagnostics_folder_is_protected_by_default_password() -> void:
	await _start_solo_mission()
	assert_true(DirAccess.dir_exists_absolute("user://files/Ship Drive/Programs/Diagnostics"), "Cartella Programs/Diagnostics deve esistere in Ship Drive")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/Diagnostics/diagnostics_config.dat"), "diagnostics_config.dat deve esistere in Ship Drive/Programs/Diagnostics/")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/Diagnostics/security_tuning.dat"), "security_tuning.dat deve esistere in Ship Drive/Programs/Diagnostics/")
	
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	assert_not_null(fpm, "FolderPasswordManager deve essere disponibile come autoload")
	assert_true(fpm.has_password("Ship Drive/Programs/Diagnostics"), "La cartella Ship Drive/Programs/Diagnostics deve essere protetta da password")
	assert_true(fpm.check_password("Ship Drive/Programs/Diagnostics", "DIAG-7815"), "La password predefinita della cartella deve essere DIAG-7815")

func test_dat_configuration_default_values_and_runtime_hot_reload() -> void:
	_diag_app = await _create_diag_app()
	await _start_solo_mission()
	
	_diag_app.load_dat_configuration()
	assert_true(_diag_app.active_config.get("is_dat_loaded"), "Configurazione .dat deve risultare caricata")
	assert_eq(_diag_app.active_config.get("scan_depth"), "DEEP", "scan_depth di fabbrica deve essere DEEP")
	assert_eq(_diag_app.active_config.get("ice_firewall_strength"), 100.0, "ice_firewall_strength di fabbrica deve essere 100.0")
	assert_eq(_diag_app.active_config.get("factory_reset_delay_sec"), 3.0, "factory_reset_delay_sec di fabbrica deve essere 3.0")
	
	var new_dat_content := "[SYSTEM]\napp_name=Diagnostics\nversion=1.0.4\nstatus=OVERCLOCKED\ndiagnostics_subsystem=ACTIVE\n\n[SCANNER_SETTINGS]\nscan_depth=QUICK\nauto_quarantine_malware=false\nalert_sound=true\nscan_speed_multiplier=2.5\ntamper_detection_level=MAXIMUM\nlog_telemetry_integrity=true\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/Diagnostics/diagnostics_config.dat", FileAccess.WRITE)
	f_out.store_string(new_dat_content)
	f_out.close()
	
	var new_tuning_content := "[ICE_DEFENSE]\nice_firewall_strength=150.0\nfactory_reset_delay_sec=1.5\ntamper_detection_level=MAXIMUM\nice_recharge_rate=12.0\nmalware_purge_efficiency=1.8\noverclock_bypass_security=true\n"
	var f_tune := FileAccess.open("user://files/Ship Drive/Programs/Diagnostics/security_tuning.dat", FileAccess.WRITE)
	f_tune.store_string(new_tuning_content)
	f_tune.close()
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("file_synced"):
		sdm.file_synced.emit("Ship Drive/Programs/Diagnostics/diagnostics_config.dat")
	else:
		_diag_app.load_dat_configuration()
	await get_tree().process_frame
	
	assert_eq(_diag_app.active_config["scan_depth"], "QUICK", "scan_depth deve aggiornarsi a runtime a QUICK")
	assert_eq(_diag_app.active_config["auto_quarantine_malware"], false, "auto_quarantine_malware deve aggiornarsi a false")
	assert_eq(_diag_app.active_config["scan_speed_multiplier"], 2.5, "scan_speed_multiplier deve aggiornarsi a 2.5")
	assert_eq(_diag_app.active_config["ice_firewall_strength"], 150.0, "ice_firewall_strength deve aggiornarsi a 150.0")
	assert_eq(_diag_app.active_config["factory_reset_delay_sec"], 1.5, "factory_reset_delay_sec deve aggiornarsi a 1.5")
	assert_eq(_diag_app.active_config["ice_recharge_rate"], 12.0, "ice_recharge_rate deve aggiornarsi a 12.0")

func test_rbac_permissions_matrix_for_crew_roles() -> void:
	_diag_app = await _create_diag_app()
	await _start_solo_mission()
	# Disabilita l'override della modalita' Solo per validare la vera matrice dei ruoli
	NetworkManager.is_solo_mode = false
	
	NetworkManager.request_role(NetworkManager.ROLE_HACKER)
	await get_tree().process_frame
	assert_true(_diag_app.can_control_diagnostics, "Hacker deve avere pieno controllo su Diagnostics ed ICE")
	assert_false(_diag_app.btn_start_scan.disabled, "Pulsante scansione abilitato per Hacker")
	assert_false(_diag_app.btn_reinforce_ice.disabled, "Pulsante rinforzo ICE abilitato per Hacker")
	assert_false(_diag_app.btn_factory_reset.disabled, "Pulsante factory reset abilitato per Hacker")
	
	NetworkManager.request_role(NetworkManager.ROLE_ENGINEER)
	await get_tree().process_frame
	assert_true(_diag_app.can_control_diagnostics, "Ingegnere deve avere pieno controllo su Diagnostics ed ICE")
	assert_false(_diag_app.btn_start_scan.disabled, "Pulsante scansione abilitato per Ingegnere")
	assert_false(_diag_app.btn_factory_reset.disabled, "Pulsante factory reset abilitato per Ingegnere")
	
	NetworkManager.request_role(NetworkManager.ROLE_CAPTAIN)
	await get_tree().process_frame
	assert_true(_diag_app.can_control_diagnostics, "Capitano deve avere pieno controllo con override")
	assert_false(_diag_app.btn_start_scan.disabled, "Pulsante scansione abilitato per Capitano")
	
	NetworkManager.request_role(NetworkManager.ROLE_STAGISTA)
	await get_tree().process_frame
	assert_true(_diag_app.can_control_diagnostics, "Stagista deve avere pieno controllo")
	
	NetworkManager.request_role(NetworkManager.ROLE_PILOT)
	await get_tree().process_frame
	assert_false(_diag_app.can_control_diagnostics, "Pilota deve essere in sola lettura")
	assert_true(_diag_app.btn_start_scan.disabled, "Pulsante scansione disabilitato per Pilota")
	assert_true(_diag_app.btn_reinforce_ice.disabled, "Pulsante rinforzo ICE disabilitato per Pilota")
	assert_true(_diag_app.btn_factory_reset.disabled, "Pulsante factory reset disabilitato per Pilota")
	
	NetworkManager.request_role(NetworkManager.ROLE_SOLDIER)
	await get_tree().process_frame
	assert_false(_diag_app.can_control_diagnostics, "Soldato deve essere in sola lettura")
	assert_true(_diag_app.btn_start_scan.disabled, "Pulsante scansione disabilitato per Soldato")
	
	NetworkManager.request_role(NetworkManager.ROLE_HACKER)
	await get_tree().process_frame
	assert_true(_diag_app.can_control_diagnostics, "Il controllo deve essere ripristinato per Hacker")

func test_threat_scanner_detection_and_quarantine_purge() -> void:
	_diag_app = await _create_diag_app()
	await _start_solo_mission()
	
	# Iniezione di un file malware di test in Ship Drive
	var fake_malware_path := "user://files/Ship Drive/test_crypto_miner.miner"
	var f_mal := FileAccess.open(fake_malware_path, FileAccess.WRITE)
	f_mal.store_string("CLANDESTINE_MINER_PAYLOAD")
	f_mal.close()
	
	_diag_app.start_scan(0, 1) # Ship Drive, Deep
	assert_true(_diag_app.is_scanning, "Scansione deve risultare attiva")
	
	_diag_app.scan_progress = 100.0
	_diag_app._finish_scan()
	
	assert_false(_diag_app.is_scanning, "Scansione completata")
	assert_true(_diag_app.detected_threats.size() > 0 or _diag_app.quarantined_threats.size() > 0, "Deve aver identificato minacce sul drive")
	
	_diag_app.inject_threat("Corporate Worm X9", "TROJAN_VIRUS", "Ship Drive/worm.trojan", "CRITICAL", "Test Worm")
	assert_true(_diag_app.detected_threats.size() > 0, "Minaccia iniettata presente")
	assert_true(_diag_app.system_integrity_score < 100.0, "Punteggio integrità deve scendere sotto 100%")
	
	_diag_app.purge_threats()
	assert_true(_diag_app.detected_threats.is_empty(), "Minacce devono essere azzerate dopo la bonifica")
	assert_eq(_diag_app.system_integrity_score, 100.0, "Integrità deve tornare a 100%")
	assert_false(FileAccess.file_exists(fake_malware_path), "File malware eliminato dal disco")

func test_ice_firewall_defense_panel_attack_reinforce_and_flush() -> void:
	_diag_app = await _create_diag_app()
	await _start_solo_mission()
	
	var initial_ice: float = _diag_app.current_ice_strength
	
	_diag_app.simulate_cyber_attack(35.0, "comms")
	assert_true(_diag_app.current_ice_strength < initial_ice, "Integrità ICE deve diminuire a seguito dell'attacco")
	assert_eq(_diag_app.ice_nodes_status["comms"]["status"], "ATTACKED", "Nodo comms deve risultare sotto attacco")
	
	var post_attack_ice: float = _diag_app.current_ice_strength
	_diag_app.reinforce_ice(25.0)
	assert_true(_diag_app.current_ice_strength > post_attack_ice, "Rinforzo ICE deve incrementare la barriera")
	
	_diag_app.flush_firewall_cache()
	assert_eq(_diag_app.ice_nodes_status["comms"]["status"], "SECURE", "Nodo comms deve tornare SECURE dopo flush")
	assert_eq(_diag_app.ice_nodes_status["comms"]["integrity"], 100.0, "Integrità nodo comms ripristinata al 100%")

func test_factory_reset_restores_dat_firmware_to_defaults() -> void:
	_diag_app = await _create_diag_app()
	await _start_solo_mission()
	
	var flight_cfg_path := "user://files/Ship Drive/Programs/FlightControls/flight_config.dat"
	var f_corrupt := FileAccess.open(flight_cfg_path, FileAccess.WRITE)
	f_corrupt.store_string("[SYSTEM]\ncorrupted=true\noverclock_danger=9999\n")
	f_corrupt.close()
	
	var corrupted_content := FileAccess.get_file_as_string(flight_cfg_path)
	assert_true("corrupted=true" in corrupted_content, "File flight_config.dat manomesso per test")
	
	_diag_app.start_factory_reset("FlightControls")
	assert_true(_diag_app.is_factory_resetting, "Factory reset deve risultare in corso")
	
	_diag_app.reset_progress = 100.0
	_diag_app._finish_factory_reset()
	assert_false(_diag_app.is_factory_resetting, "Factory reset terminato")
	
	var restored_content := FileAccess.get_file_as_string(flight_cfg_path)
	assert_true("max_linear_speed=20.0" in restored_content, "flight_config.dat deve essere ripristinato ai valori di fabbrica standard")
	assert_false("corrupted=true" in restored_content, "Dati corrotti rimossi con successo")

func test_ship_blueprint_and_sublayer_integration() -> void:
	await _start_solo_mission()
	var bp := SpaceWorldManager.get_ship_blueprint()
	assert_not_null(bp, "ShipBlueprint attiva deve essere trovata")
	
	var diag_installed_app := bp.get_installed_app_by_id("diagnostics")
	assert_not_null(diag_installed_app, "App Diagnostics deve essere presente nel catalogo installed_apps")
	assert_eq(diag_installed_app.title, "System Diagnostics", "Titolo app deve essere 'System Diagnostics'")
	assert_true(diag_installed_app.roles.has("Hacker"), "Hacker deve essere tra i ruoli autorizzati in blueprint")
	assert_true(diag_installed_app.roles.has("Ingegnere"), "Ingegnere deve essere tra i ruoli autorizzati in blueprint")
	
	var passwords := SpaceWorldManager.get_ship_drive_passwords()
	assert_true(passwords.has("Ship Drive/Programs/Diagnostics"), "Password Diagnostics presente nel gestore password")
	assert_eq(passwords["Ship Drive/Programs/Diagnostics"], "DIAG-7815", "Password Diagnostics deve essere DIAG-7815")

func test_queue_free_cleanup_does_not_error() -> void:
	_diag_app = await _create_diag_app()
	await _start_solo_mission()
	_diag_app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_diag_app = null
	assert_true(true, "La rimozione dell'app Diagnostics non deve generare errori di pulizia dei segnali")
