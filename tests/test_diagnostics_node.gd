extends Node

func _ready() -> void:
	print("--- INIZIO TEST COMPLETO SYSTEM DIAGNOSTICS, CYBER SECURITY & ICE DEFENSE ---")
	_run_suite.call_deferred()

func _run_suite() -> void:
	await get_tree().process_frame
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	var net_mgr := get_node_or_null("/root/NetworkManager")
	
	# =========================================================================
	# FASE 1: TEST STATO OFFLINE / LOBBY (DISCONNECTED OVERLAY & LIFE CYCLE)
	# =========================================================================
	print("\n--- TEST 1: Stato Offline / Overlay Disconnesso ---")
	if net_mgr:
		net_mgr.disconnect_game()
	await get_tree().process_frame
	
	var diag_app_scene: PackedScene = load("res://Applications/Diagnostics/diagnostics_app.tscn")
	assert(diag_app_scene != null, "Scena diagnostics_app.tscn valida")
	var diag_app: DiagnosticsApp = diag_app_scene.instantiate() as DiagnosticsApp
	add_child(diag_app)
	await get_tree().process_frame
	
	assert(not diag_app._is_ship_operational(), "L'app Diagnostics non deve essere operativa a nave disconnessa")
	assert(diag_app.disconnected_overlay != null and diag_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve essere visibile da disconnesso")
	print("✔ Overlay di blocco visibile e operativo da disconnesso")
	
	# =========================================================================
	# FASE 2: AVVIO MISSIONE & STATO OPERATIVO
	# =========================================================================
	print("\n--- TEST 2: Avvio Missione & Connessione Nave ---")
	if net_mgr:
		net_mgr.start_solo_game("Hacker")
		net_mgr.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame
	
	assert(diag_app._is_ship_operational(), "L'app Diagnostics deve essere operativa dopo l'avvio della missione")
	assert(diag_app.disconnected_overlay != null and not diag_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve scomparire all'avvio della missione")
	print("✔ Overlay rimosso istantaneamente all'avvio della missione")
	
	# =========================================================================
	# FASE 3: CARTELLA DRIVE PROTETTA & FILE .DAT DI DEFAULT
	# =========================================================================
	print("\n--- TEST 3: Cartella Protetta Ship Drive/Programs/Diagnostics e file .dat ---")
	assert(DirAccess.dir_exists_absolute("user://files/Ship Drive/Programs/Diagnostics"), "Cartella Programs/Diagnostics deve esistere in Ship Drive")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/Diagnostics/diagnostics_config.dat"), "diagnostics_config.dat deve esistere in Ship Drive/Programs/Diagnostics/")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/Diagnostics/security_tuning.dat"), "security_tuning.dat deve esistere in Ship Drive/Programs/Diagnostics/")
	
	if fpm:
		assert(fpm.has_password("Ship Drive/Programs/Diagnostics"), "La cartella Ship Drive/Programs/Diagnostics deve essere protetta da password")
		assert(fpm.check_password("Ship Drive/Programs/Diagnostics", "DIAG-7815"), "La password predefinita della cartella deve essere DIAG-7815")
	print("✔ Cartella e file .dat protetti creati con successo in Ship Drive con password DIAG-7815")
	
	# =========================================================================
	# FASE 4: CARICAMENTO DINAMICO DEI PARAMETRI .DAT E HOT-RELOADING A RUNTIME
	# =========================================================================
	print("\n--- TEST 4: Caricamento dinamico ed effetto a runtime dei parametri .dat ---")
	diag_app.load_dat_configuration()
	assert(diag_app.active_config.get("is_dat_loaded") == true, "Configurazione .dat deve risultare caricata")
	assert(diag_app.active_config.get("scan_depth") == "DEEP", "scan_depth di fabbrica deve essere DEEP")
	assert(diag_app.active_config.get("ice_firewall_strength") == 100.0, "ice_firewall_strength di fabbrica deve essere 100.0")
	assert(diag_app.active_config.get("factory_reset_delay_sec") == 3.0, "factory_reset_delay_sec di fabbrica deve essere 3.0")
	print("✔ Valori iniziali .dat caricati con successo")
	
	# Modifica dinamica di diagnostics_config.dat e security_tuning.dat
	var new_dat_content := "[SYSTEM]\napp_name=Diagnostics\nversion=1.0.4\nstatus=OVERCLOCKED\ndiagnostics_subsystem=ACTIVE\n\n[SCANNER_SETTINGS]\nscan_depth=QUICK\nauto_quarantine_malware=false\nalert_sound=true\nscan_speed_multiplier=2.5\ntamper_detection_level=MAXIMUM\nlog_telemetry_integrity=true\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/Diagnostics/diagnostics_config.dat", FileAccess.WRITE)
	f_out.store_string(new_dat_content)
	f_out.close()
	
	var new_tuning_content := "[ICE_DEFENSE]\nice_firewall_strength=150.0\nfactory_reset_delay_sec=1.5\ntamper_detection_level=MAXIMUM\nice_recharge_rate=12.0\nmalware_purge_efficiency=1.8\noverclock_bypass_security=true\n"
	var f_tune := FileAccess.open("user://files/Ship Drive/Programs/Diagnostics/security_tuning.dat", FileAccess.WRITE)
	f_tune.store_string(new_tuning_content)
	f_tune.close()
	
	# Notifica evento sincronizzazione drive
	if sdm:
		sdm.file_synced.emit("Ship Drive/Programs/Diagnostics/diagnostics_config.dat")
	else:
		diag_app.load_dat_configuration()
	await get_tree().process_frame
	
	assert(diag_app.active_config["scan_depth"] == "QUICK", "scan_depth aggiornato a runtime a QUICK")
	assert(diag_app.active_config["auto_quarantine_malware"] == false, "auto_quarantine_malware aggiornato a false")
	assert(diag_app.active_config["scan_speed_multiplier"] == 2.5, "scan_speed_multiplier aggiornato a 2.5")
	assert(diag_app.active_config["ice_firewall_strength"] == 150.0, "ice_firewall_strength aggiornato a 150.0")
	assert(diag_app.active_config["factory_reset_delay_sec"] == 1.5, "factory_reset_delay_sec aggiornato a 1.5")
	assert(diag_app.active_config["ice_recharge_rate"] == 12.0, "ice_recharge_rate aggiornato a 12.0")
	print("✔ Modifica del file .dat recepita in tempo reale tramite Hot-Reloading")
	
	# =========================================================================
	# FASE 5: CONTROLLO RUOLI RBAC
	# =========================================================================
	print("\n--- TEST 5: Controllo Ruoli RBAC ---")
	if net_mgr:
		net_mgr.is_solo_mode = false # Disabilita solo mode per verificare i singoli ruoli
		
		# Ruolo Hacker (Pieno controllo)
		net_mgr.request_role("Hacker")
		await get_tree().process_frame
		assert(diag_app.can_control_diagnostics == true, "Hacker deve avere pieno controllo su Diagnostics ed ICE")
		assert(diag_app.btn_start_scan.disabled == false, "Pulsante scansione abilitato per Hacker")
		assert(diag_app.btn_reinforce_ice.disabled == false, "Pulsante rinforzo ICE abilitato per Hacker")
		assert(diag_app.btn_factory_reset.disabled == false, "Pulsante factory reset abilitato per Hacker")
		
		# Ruolo Ingegnere (Pieno controllo)
		net_mgr.request_role("Ingegnere")
		await get_tree().process_frame
		assert(diag_app.can_control_diagnostics == true, "Ingegnere deve avere pieno controllo su Diagnostics ed ICE")
		assert(diag_app.btn_start_scan.disabled == false, "Pulsante scansione abilitato per Ingegnere")
		assert(diag_app.btn_factory_reset.disabled == false, "Pulsante factory reset abilitato per Ingegnere")
		
		# Ruolo Capitano (Pieno controllo & Override)
		net_mgr.request_role("Capitano")
		await get_tree().process_frame
		assert(diag_app.can_control_diagnostics == true, "Capitano deve avere pieno controllo con override")
		assert(diag_app.btn_start_scan.disabled == false, "Pulsante scansione abilitato per Capitano")
		
		# Ruolo Factotum (Pieno controllo & Override)
		net_mgr.request_role("Factotum")
		await get_tree().process_frame
		assert(diag_app.can_control_diagnostics == true, "Factotum deve avere pieno controllo")
		
		# Ruolo Pilota (Sola visualizzazione / Telemetria)
		net_mgr.request_role("Pilota")
		await get_tree().process_frame
		assert(diag_app.can_control_diagnostics == false, "Pilota deve essere in sola lettura")
		assert(diag_app.btn_start_scan.disabled == true, "Pulsante scansione disabilitato per Pilota")
		assert(diag_app.btn_reinforce_ice.disabled == true, "Pulsante rinforzo ICE disabilitato per Pilota")
		assert(diag_app.btn_factory_reset.disabled == true, "Pulsante factory reset disabilitato per Pilota")
		
		# Ruolo Soldato (Sola visualizzazione)
		net_mgr.request_role("Soldato")
		await get_tree().process_frame
		assert(diag_app.can_control_diagnostics == false, "Soldato deve essere in sola lettura")
		assert(diag_app.btn_start_scan.disabled == true, "Pulsante scansione disabilitato per Soldato")
		
		# Ripristino ruolo Hacker per proseguire i test
		net_mgr.request_role("Hacker")
		await get_tree().process_frame
		assert(diag_app.can_control_diagnostics == true, "Ripristinato controllo per Hacker")
	print("✔ Matrice dei ruoli RBAC verificata con successo")
	
	# =========================================================================
	# FASE 6: SCANNER INTEGRITÀ, RILEVAMENTO MINACCE & QUARANTENA
	# =========================================================================
	print("\n--- TEST 6: Scanner Integrità & Rilevamento Minacce ---")
	
	# Iniezione di un file malware di test in Ship Drive
	var fake_malware_path := "user://files/Ship Drive/test_crypto_miner.miner"
	var f_mal := FileAccess.open(fake_malware_path, FileAccess.WRITE)
	if f_mal:
		f_mal.store_string("CLANDESTINE_MINER_PAYLOAD")
		f_mal.close()
	
	# Iniezione manuale e avvio scansione
	diag_app.start_scan(0, 1) # Ship Drive, Deep
	assert(diag_app.is_scanning == true, "Scansione deve risultare attiva")
	
	# Simulazione completamento scansione
	diag_app.scan_progress = 100.0
	diag_app._finish_scan()
	
	assert(diag_app.is_scanning == false, "Scansione completata")
	assert(diag_app.detected_threats.size() > 0 or diag_app.quarantined_threats.size() > 0, "Deve aver identificato minacce sul drive")
	
	# Test purga e bonifica manuale
	diag_app.inject_threat("Corporate Worm X9", "TROJAN_VIRUS", "Ship Drive/worm.trojan", "CRITICAL", "Test Worm")
	assert(diag_app.detected_threats.size() > 0, "Minaccia iniettata presente")
	assert(diag_app.system_integrity_score < 100.0, "Punteggio integrità deve scendere sotto 100%")
	
	diag_app.purge_threats()
	assert(diag_app.detected_threats.is_empty(), "Minacce devono essere azzerate dopo la bonifica")
	assert(diag_app.system_integrity_score == 100.0, "Integrità deve tornare a 100%")
	assert(not FileAccess.file_exists(fake_malware_path), "File malware eliminato dal disco")
	print("✔ Scanner di integrità, rilevamento minacce e bonifica quarantena validati con successo")
	
	# =========================================================================
	# FASE 7: PANNELLO ICE & DIFESA FIREWALL
	# =========================================================================
	print("\n--- TEST 7: Pannello ICE & Difesa Firewall ---")
	var initial_ice: float = diag_app.current_ice_strength
	
	# Simulazione attacco cyber warfare
	diag_app.simulate_cyber_attack(35.0, "comms")
	assert(diag_app.current_ice_strength < initial_ice, "Integrità ICE deve diminuire a seguito dell'attacco")
	assert(diag_app.ice_nodes_status["comms"]["status"] == "ATTACKED", "Nodo comms deve risultare sotto attacco")
	
	# Rinforzo barriera ICE
	var post_attack_ice: float = diag_app.current_ice_strength
	diag_app.reinforce_ice(25.0)
	assert(diag_app.current_ice_strength > post_attack_ice, "Rinforzo ICE deve incrementare la barriera")
	
	# Flush cache firewall
	diag_app.flush_firewall_cache()
	assert(diag_app.ice_nodes_status["comms"]["status"] == "SECURE", "Nodo comms deve tornare SECURE dopo flush")
	assert(diag_app.ice_nodes_status["comms"]["integrity"] == 100.0, "Integrità nodo comms ripristinata al 100%")
	print("✔ Difesa ICE, gestione nodi e contromisure firewall verificate con successo")
	
	# =========================================================================
	# FASE 8: FACTORY RESET FIRMWARE .DAT
	# =========================================================================
	print("\n--- TEST 8: Factory Reset Firmware .DAT ---")
	
	# Manomettiamo un file di configurazione (es. flight_config.dat)
	var flight_cfg_path := "user://files/Ship Drive/Programs/FlightControls/flight_config.dat"
	var f_corrupt := FileAccess.open(flight_cfg_path, FileAccess.WRITE)
	if f_corrupt:
		f_corrupt.store_string("[SYSTEM]\ncorrupted=true\noverclock_danger=9999\n")
		f_corrupt.close()
	
	var corrupted_content := FileAccess.get_file_as_string(flight_cfg_path)
	assert("corrupted=true" in corrupted_content, "File flight_config.dat manomesso per test")
	
	# Esecuzione Factory Reset su FlightControls
	diag_app.start_factory_reset("FlightControls")
	assert(diag_app.is_factory_resetting == true, "Factory reset deve risultare in corso")
	
	# Completamento istantaneo del reset
	diag_app.reset_progress = 100.0
	diag_app._finish_factory_reset()
	assert(diag_app.is_factory_resetting == false, "Factory reset terminato")
	
	var restored_content := FileAccess.get_file_as_string(flight_cfg_path)
	assert("max_linear_speed=20.0" in restored_content, "flight_config.dat deve essere ripristinato ai valori di fabbrica standard")
	assert(not "corrupted=true" in restored_content, "Dati corrotti rimossi con successo")
	print("✔ Procedura di Factory Reset per i firmware .DAT convalidata con successo")
	
	# =========================================================================
	# FASE 9: INTEGRAZIONE SHIPBLUEPRINT & SUBLAYER 6
	# =========================================================================
	print("\n--- TEST 9: Integrazione ShipBlueprint & Catalogo Mainframe ---")
	var bp = SpaceWorldManager.get_ship_blueprint() if SpaceWorldManager else null
	assert(bp != null, "ShipBlueprint attiva trovata")
	
	var diag_installed_app := bp.get_installed_app_by_id("diagnostics")
	assert(not diag_installed_app.is_empty(), "App Diagnostics deve essere presente nel catalogo installed_apps")
	assert(diag_installed_app.get("title") == "System Diagnostics", "Titolo app Diagnostics in blueprint corretto")
	assert(diag_installed_app.get("roles").has("Hacker"), "Hacker deve essere tra i ruoli autorizzati in blueprint")
	assert(diag_installed_app.get("roles").has("Ingegnere"), "Ingegnere deve essere tra i ruoli autorizzati in blueprint")
	
	var passwords := SpaceWorldManager.get_ship_drive_passwords()
	assert(passwords.has("Ship Drive/Programs/Diagnostics"), "Password Diagnostics presente nel gestore password")
	assert(passwords["Ship Drive/Programs/Diagnostics"] == "DIAG-7815", "Password Diagnostics deve essere DIAG-7815")
	print("✔ Integrazione completa con ShipBlueprint e Sublayer 5 & 6 verificata")
	
	# =========================================================================
	# FASE 10: PULIZIA RISORSE _exit_tree()
	# =========================================================================
	print("\n--- TEST 10: Pulizia Risorse _exit_tree() ---")
	diag_app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("✔ Pulizia nodi e segnali completata senza errori")
	
	print("\n=======================================================")
	print("✔ TUTTI I TEST SYSTEM DIAGNOSTICS & ICE DEFENSE COMPLETATI CON SUCCESSO!")
	print("=======================================================")
	get_tree().quit(0)
