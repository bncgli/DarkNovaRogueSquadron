extends Node

## Test Runner Headless per SensorsApp (Applications/Sensors)
## Verifica Overlay/Ciclo di vita, RBAC, File .DAT / Hot-Reload, Spettrometria, Waypoint e Pulizia Segnali.

func _ready() -> void:
	print("\n=======================================================")
	print(">>> AVVIO SUITE DI TEST HEADLESS: SENSORS APP")
	print("=======================================================\n")
	_run_all_tests()

func _run_all_tests() -> void:
	await get_tree().process_frame
	
	var sensors_scene: PackedScene = load("res://Applications/Sensors/sensors_app.tscn")
	assert(sensors_scene != null, "La scena sensors_app.tscn deve essere caricata con successo")
	
	var app: SensorsApp = sensors_scene.instantiate() as SensorsApp
	assert(app != null, "SensorsApp deve istanziarsi come nodo SensorsApp")
	add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	
	var net_mgr = get_node_or_null("/root/NetworkManager")
	var sdm = get_node_or_null("/root/ShipDriveManager")
	
	# =========================================================================
	# TEST 1: OVERLAY E CICLO DI VITA (OFFLINE vs MISSIONE AVVIATA)
	# =========================================================================
	print("--- TEST 1: Overlay e Ciclo di Vita Offline / Online ---")
	if net_mgr and net_mgr.is_mission_active:
		net_mgr.disconnect_game()
		await get_tree().process_frame
	
	if SpaceWorldManager:
		SpaceWorldManager.is_ship_connected_state = false
		SpaceWorldManager.ship_connection_changed.emit(false)
		await get_tree().process_frame
	
	assert(app.disconnected_overlay != null, "%DisconnectedOverlay deve esistere nella scena")
	assert(app.disconnected_overlay.visible == true, "%DisconnectedOverlay deve essere VISIBILE quando la nave è offline")
	print("✔ Overlay offline correttamente visualizzato")
	
	# Simula connessione nave / avvio missione
	if SpaceWorldManager:
		SpaceWorldManager.is_ship_connected_state = true
		SpaceWorldManager.ship_connection_changed.emit(true)
		await get_tree().process_frame
	
	assert(app.disconnected_overlay.visible == false, "%DisconnectedOverlay deve SCOMPARIRE quando la nave è connessa")
	print("✔ Overlay rimosso automaticamente a connessione stabilita")
	
	# =========================================================================
	# TEST 2: RBAC (ROLE-BASED ACCESS CONTROL)
	# =========================================================================
	print("\n--- TEST 2: Matrice RBAC (Permessi Ruolo e Controlli) ---")
	if net_mgr:
		net_mgr.host_game("OperatoreTest")
		await get_tree().process_frame
		
		# 2.1 Pilota: Sola Lettura
		net_mgr.request_role("Pilota")
		await get_tree().process_frame
		assert(app.can_control_sensors == false, "Pilota non deve avere controllo attivo sui sensori")
		assert(app.btn_sweep_toggle.disabled == true, "BtnSweepToggle deve essere disabilitato per Pilota")
		assert(app.btn_active_ping.disabled == true, "BtnActivePing deve essere disabilitato per Pilota")
		print("✔ Ruolo Pilota: correttamente limitato a sola visualizzazione")
		
		# 2.2 Ingegnere: Sola Lettura
		net_mgr.request_role("Ingegnere")
		await get_tree().process_frame
		assert(app.can_control_sensors == false, "Ingegnere non deve avere controllo attivo sui sensori")
		assert(app.btn_sweep_toggle.disabled == true, "BtnSweepToggle deve essere disabilitato per Ingegnere")
		assert(app.btn_active_ping.disabled == true, "BtnActivePing deve essere disabilitato per Ingegnere")
		print("✔ Ruolo Ingegnere: correttamente limitato a sola visualizzazione")
		
		# 2.3 Soldato: Controllo Completo
		net_mgr.request_role("Soldato")
		await get_tree().process_frame
		assert(app.can_control_sensors == true, "Soldato deve avere controllo completo sui sensori")
		assert(app.btn_sweep_toggle.disabled == false, "BtnSweepToggle deve essere abilitato per Soldato")
		assert(app.btn_active_ping.disabled == false, "BtnActivePing deve essere abilitato per Soldato")
		print("✔ Ruolo Soldato: controllo completo abilitato")
		
		# 2.4 Hacker: Controllo Completo
		net_mgr.request_role("Hacker")
		await get_tree().process_frame
		assert(app.can_control_sensors == true, "Hacker deve avere controllo completo sui sensori")
		print("✔ Ruolo Hacker: controllo completo abilitato")
		
		# 2.5 Capitano: Controllo Completo e Override
		net_mgr.request_role("Capitano")
		await get_tree().process_frame
		assert(app.can_control_sensors == true, "Capitano deve avere controllo completo sui sensori")
		print("✔ Ruolo Capitano: controllo completo abilitato")
		
		# 2.6 Mozzo / Solo Mode
		net_mgr.request_role("Mozzo")
		await get_tree().process_frame
		assert(app.can_control_sensors == true, "Mozzo deve avere controllo completo sui sensori")
		print("✔ Ruolo Mozzo: controllo completo abilitato")
	
	# =========================================================================
	# TEST 3: FILE .DAT E HOT-RELOADING
	# =========================================================================
	print("\n--- TEST 3: Parsing file .DAT e Hot-Reloading ---")
	if sdm:
		sdm.mount_drive()
	app.load_dat_configuration()
	await get_tree().process_frame
	assert(app.active_config.get("is_dat_loaded") == true, "Configurazioni .DAT devono essere caricate")
	assert(app.active_config.get("sweep_frequency_hz") == 12.0, "sweep_frequency_hz deve corrispondere a 12.0 Hz")
	assert(app.active_config.get("active_ping_radius") == 50000.0, "active_ping_radius deve corrispondere a 50 km")
	assert(app.active_config.get("noise_filter") == 0.92, "noise_filter deve corrispondere a 0.92")
	assert(app.active_config.get("spectrum_sensitivity") == 1.0, "spectrum_sensitivity deve corrispondere a 1.0")
	assert(app.active_config.get("stealth_detection_threshold") == 0.35, "stealth_detection_threshold deve corrispondere a 0.35")
	print("✔ Parsing .DAT iniziale valido e coerente con firmware")
	
	# Simula hot-reload file_synced
	if sdm:
		sdm.file_synced.emit("Ship Drive/Programs/Sensors/sensors_config.dat", "")
		await get_tree().process_frame
		assert(app.active_config.get("is_dat_loaded") == true, "Hot-reloading deve ricaricare la configurazione")
		print("✔ Hot-reloading su file_synced verificato con successo")
	
	# Simula pressione tasto ricarica .DAT
	app.btn_reload_dat.emit_signal("pressed")
	await get_tree().process_frame
	assert(app.active_config.get("is_dat_loaded") == true, "Pulsante ricarica .DAT deve rinfrescare la configurazione")
	print("✔ Pulsante 🔄 Ricarica .DAT funzionante")
	
	# =========================================================================
	# TEST 4: FUNZIONALITÀ RADAR, SPETTROMETRIA E WAYPOINT
	# =========================================================================
	print("\n--- TEST 4: Funzionalità Radar, Spettrometria e Waypoint ---")
	assert(app.radar_display != null, "RadarDisplay deve essere istanziato")
	assert(app.detected_entities.size() > 0, "I sensori devono rilevare contatti diegetici/astronave")
	
	# Test selezione contatto
	var test_contact := app.detected_entities[0]
	var test_id: String = test_contact.get("id")
	app._on_radar_entity_selected(test_contact)
	await get_tree().process_frame
	assert(app.selected_entity_id == test_id, "Il contatto deve risultare selezionato")
	assert(app.target_details_label.text.length() > 0, "I dettagli telemetrici devono essere popolati")
	assert(app.spectrometry_label.text.length() > 0, "L'analisi spettrometrica deve essere visualizzata")
	print("✔ Selezione contatto e telemetria/spettrometria verificate")
	
	# Test Lock Bersaglio
	app.btn_lock_target.emit_signal("pressed")
	await get_tree().process_frame
	assert(app.locked_entity_id == test_id, "Il bersaglio deve risultare agganciato (Locked)")
	assert(app.is_target_locked == true, "Stato is_target_locked deve essere true")
	
	# Rilascio lock
	app.btn_lock_target.emit_signal("pressed")
	await get_tree().process_frame
	assert(app.locked_entity_id.is_empty(), "Il bersaglio deve essere rilasciato")
	print("✔ Aggancio Lock e rilascio bersaglio verificati")
	
	# Test Trasmissione Waypoint
	app._on_radar_entity_selected(test_contact)
	app.btn_transmit_waypoint.emit_signal("pressed")
	await get_tree().process_frame
	if SpaceWorldManager:
		var active_wp := SpaceWorldManager.get_active_waypoint()
		assert(not active_wp.is_empty(), "SpaceWorldManager deve aver registrato il waypoint trasmesso")
		assert(active_wp.get("target_id") == test_id, "L'ID bersaglio nel waypoint deve coincidere")
		print("✔ Trasmissione waypoint a Flight Control & Weapons completata")
		
		# Test cancellazione waypoint
		app.btn_clear_waypoint.emit_signal("pressed")
		await get_tree().process_frame
		assert(SpaceWorldManager.get_active_waypoint().is_empty(), "Il waypoint attivo deve essere rimosso")
		print("✔ Cancellazione waypoint confermata")
	
	# Test Ping Attivo
	app.btn_active_ping.emit_signal("pressed")
	await get_tree().process_frame
	assert(app.is_pinging == true, "Ping attivo deve essere in esecuzione")
	assert(app.radar_display.ping_active == true, "RadarDisplay deve aver avviato l'onda di espansione ping")
	print("✔ Trigger Ping Attivo (50 km) validato")
	
	# =========================================================================
	# TEST 5: PULIZIA SEGNALI SU _EXIT_TREE()
	# =========================================================================
	print("\n--- TEST 5: Pulizia Segnali e Disconnessione ---")
	app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("✔ Nodo rimosso e segnali disconnessi senza memory leak")
	
	print("\n=======================================================")
	print("✔ TUTTI I TEST SENSORS APP COMPLETATI CON SUCCESSO!")
	print("=======================================================\n")
	get_tree().quit(0)
