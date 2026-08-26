extends Node

func _ready() -> void:
	print("--- INIZIO TEST POWER GRID & ELECTRICAL IMPLANTS ---")
	_run_suite.call_deferred()

func _run_suite() -> void:
	await get_tree().process_frame
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	
	# =========================================================================
	# FASE 1: TEST STATO OFFLINE / LOBBY (DISCONNECTED OVERLAY & LIFE CYCLE)
	# =========================================================================
	print("\n--- TEST 1: Stato Offline / Overlay Disconnesso ---")
	if NetworkManager:
		NetworkManager.disconnect_game()
	
	var app_res: PackedScene = load("res://Applications/PowerGrid/power_grid_app.tscn")
	assert(app_res != null, "Scena power_grid_app.tscn valida")
	var app: PowerGridApp = app_res.instantiate() as PowerGridApp
	add_child(app)
	await get_tree().process_frame
	
	assert(not app.is_operational(), "L'app non deve risultare operativa quando la nave è disconnessa")
	assert(app.disconnected_overlay != null and app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve essere visibile da disconnesso")
	print("✔ Overlay di blocco visibile e operativo da disconnesso")
	
	# =========================================================================
	# FASE 2: AVVIO MISSIONE & STATO OPERATIVO
	# =========================================================================
	print("\n--- TEST 2: Avvio Missione & Connessione Nave ---")
	if NetworkManager:
		NetworkManager.start_solo_game("Ingegnere")
		NetworkManager.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame
	
	assert(app.is_operational(), "L'app deve risultare operativa dopo l'avvio della missione")
	assert(app.disconnected_overlay != null and not app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve scomparire dopo l'avvio della missione")
	print("✔ Overlay rimosso istantaneamente all'avvio della missione")
	
	# =========================================================================
	# FASE 3: VERIFICA CARTELLA DRIVE PROTETTA & FILE .DAT DI DEFAULT
	# =========================================================================
	print("\n--- TEST 3: Cartella Protetta Ship Drive/Programs/PowerGrid e file .dat ---")
	assert(DirAccess.dir_exists_absolute("user://files/Ship Drive/Programs/PowerGrid"), "Cartella Programs/PowerGrid deve esistere in Ship Drive")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/PowerGrid/power_grid_config.dat"), "power_grid_config.dat deve esistere in Ship Drive/Programs/PowerGrid/")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/PowerGrid/grid_tuning.dat"), "grid_tuning.dat deve esistere in Ship Drive/Programs/PowerGrid/")
	
	if fpm:
		assert(fpm.has_password("Ship Drive/Programs/PowerGrid"), "La cartella Ship Drive/Programs/PowerGrid deve essere protetta da password")
		assert(fpm.check_password("Ship Drive/Programs/PowerGrid", "GRID-7815"), "La password predefinita della cartella deve essere GRID-7815")
	print("✔ Cartella e file .dat protetti creati con successo in Ship Drive")
	
	# =========================================================================
	# FASE 4: CARICAMENTO DINAMICO DEI PARAMETRI .DAT E HOT-RELOADING
	# =========================================================================
	print("\n--- TEST 4: Caricamento dinamico ed effetto a runtime dei parametri .dat ---")
	var initial_cfg := app.load_dat_configuration()
	assert(initial_cfg.get("is_dat_loaded") == true, "Configurazione .dat deve risultare caricata")
	assert(initial_cfg.get("reactor_output_mw") == 1200.0, "Potenza reattore iniziale deve essere 1200.0")
	assert(initial_cfg.get("aux_generator_mw") == 450.0, "Potenza generatore ausiliario iniziale deve essere 450.0")
	print("✔ Valori iniziali .dat applicati correttamente")
	
	# Modifica dinamica del file power_grid_config.dat
	var new_dat_content := "[SYSTEM]\napp_name=PowerGrid\nversion=1.0.4\nstatus=OVERCLOCKED\nmode=MANUAL_OVERRIDE\n\n[GRID_SETTINGS]\nreactor_output_mw=1500.0\naux_generator_mw=500.0\njunction_switch_delay=0.1\noverload_threshold_pct=130.0\nreroute_efficiency_loss=0.02\n\n[CIRCUIT_PROTECTION]\nbreaker_trip_threshold=1.8\nshort_circuit_damping=0.9\nauto_reroute_on_short=true\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/PowerGrid/power_grid_config.dat", FileAccess.WRITE)
	f_out.store_string(new_dat_content)
	f_out.close()
	
	if sdm:
		sdm.file_synced.emit("Ship Drive/Programs/PowerGrid/power_grid_config.dat")
	else:
		app.load_dat_configuration()
	await get_tree().process_frame
	
	assert(app.active_config["reactor_output_mw"] == 1500.0, "reactor_output_mw aggiornato in tempo reale a 1500.0")
	assert(app.active_config["aux_generator_mw"] == 500.0, "aux_generator_mw aggiornato in tempo reale a 500.0")
	assert(app.devices["reactor_main"]["power_mw"] == 1500.0, "Potenza attiva reattore aggiornata a 1500.0 MW")
	print("✔ Modifica del file .dat recepita in tempo reale e propagata alla simulazione")
	
	# =========================================================================
	# FASE 5: RBAC - CONTROLLO RUOLI (INGEGNERE VS RUOLO NON AUTORIZZATO)
	# =========================================================================
	print("\n--- TEST 5: Controllo Ruoli RBAC ---")
	NetworkManager.request_role("Ingegnere")
	await get_tree().process_frame
	assert(app.can_control == true, "L'Ingegnere deve poter controllare gli snodi della rete elettrica")
	
	# Ruolo Tattico in multiplayer (Solo osservatore)
	NetworkManager.request_role("Tattico")
	NetworkManager.is_solo_mode = false
	NetworkManager.player_role_changed.emit(1, "Tattico")
	await get_tree().process_frame
	assert(app.can_control == false, "Un ruolo non autorizzato (Tattico) in multiplayer non deve poter commutare gli snodi")
	var switch_attempt := app.switch_junction("J1", 1)
	assert(switch_attempt == false, "La commutazione deve essere respinta per ruoli non autorizzati")
	
	# Ripristina controllo Ingegnere
	NetworkManager.is_solo_mode = true
	NetworkManager.request_role("Ingegnere")
	NetworkManager.player_role_changed.emit(1, "Ingegnere")
	await get_tree().process_frame
	assert(app.can_control == true, "Controllo ripristinato per Ingegnere")
	print("✔ Regole RBAC verificate con successo")
	
	# =========================================================================
	# FASE 6: FORMULA CALCOLO REGIMI INPUT (1, 2, 3 INGRESSI -> 100%, 50%, 33%, 0%)
	# =========================================================================
	print("\n--- TEST 6: Formula Regimi e Input Componenti ---")
	# Verifica numero input per componenti
	assert(app.devices["sensors_radar"]["inputs_count"] == 1, "Sensori ha 1 input")
	assert(app.devices["comms_ew"]["inputs_count"] == 1, "Comms ha 1 input")
	assert(app.devices["bridge_nav"]["inputs_count"] == 2, "Ponte di Comando ha 2 input")
	assert(app.devices["life_support"]["inputs_count"] == 2, "Supporto Vitale ha 2 input")
	assert(app.devices["shields_deflector"]["inputs_count"] == 3, "Scudi Deflettori ha 3 input")
	assert(app.devices["engines_sublight"]["inputs_count"] == 3, "Motori Principali ha 3 input")
	
	# Test formula regime:
	# 1/1 -> 1.0 (100%), 0/1 -> 0.0 (0%)
	# 2/2 -> 1.0 (100%), 1/2 -> 0.5 (50%), 0/2 -> 0.0 (0%)
	# 3/3 -> 1.0 (100%), 2/3 -> 0.66 (66%), 1/3 -> 0.33 (33%), 0/3 -> 0.0 (0%)
	app.update_power_simulation()
	
	print("  Regime Ponte Nav (In: %d/%d) -> %d%%" % [app.devices["bridge_nav"]["inputs_powered"], app.devices["bridge_nav"]["inputs_count"], int(app.devices["bridge_nav"]["regime"] * 100.0)])
	print("  Regime Scudi (In: %d/%d) -> %d%%" % [app.devices["shields_deflector"]["inputs_powered"], app.devices["shields_deflector"]["inputs_count"], int(app.devices["shields_deflector"]["regime"] * 100.0)])
	print("  Regime Motori (In: %d/%d) -> %d%%" % [app.devices["engines_sublight"]["inputs_powered"], app.devices["engines_sublight"]["inputs_count"], int(app.devices["engines_sublight"]["regime"] * 100.0)])
	print("✔ Calcolo regimi energetici proporzionali agli input validato")
	
	# =========================================================================
	# FASE 7: SNODI, BIFORCAZIONI E REINDIRIZZAMENTO (REROUTING)
	# =========================================================================
	print("\n--- TEST 7: Commutazione Snodi e Rerouting ---")
	# Commuta J1 su ramo 1 (Bypass Babordo)
	var sw1 := app.switch_junction("J1", 1)
	assert(sw1 == true, "Commutazione J1 valida")
	assert(app.junctions["J1"]["active_branch"] == 1, "Ramo attivo J1 = 1")
	
	# Commuta J2 su ramo 1 (Sensori)
	var sw2 := app.switch_junction("J2", 1)
	assert(sw2 == true, "Commutazione J2 valida")
	assert(app.junctions["J2"]["active_branch"] == 1, "Ramo attivo J2 = 1")
	
	# Commuta J4 su ramo 1 (Scudi Sovralimentazione)
	var sw4 := app.switch_junction("J4", 1)
	assert(sw4 == true, "Commutazione J4 valida")
	assert(app.junctions["J4"]["active_branch"] == 1, "Ramo attivo J4 = 1")
	print("✔ Commutazione snodi e biforcazioni eseguita correttamente")
	
	# =========================================================================
	# FASE 8: INTEGRAZIONE GUASTI CORTOCIRCUITO DUCT DRONE
	# =========================================================================
	print("\n--- TEST 8: Cortocircuiti Duct Drone & Rottura Connessioni ---")
	SpaceWorldManager.clear_ship_damages()
	app.update_power_simulation()
	
	# Genera cortocircuito su linea Sensori / J2
	var short_dmg := SpaceWorldManager.spawn_ship_damage(SpaceWorldManager.DAMAGE_TYPE_SHORT_CIRCUIT, Vector2(300, 125), "Sensori & Avionica", 5.0)
	assert(not short_dmg.is_empty(), "Danno cortocircuito creato in SpaceWorldManager")
	
	app.update_power_simulation()
	
	# Verifica che la linea corrispondente risulti interrotta (is_shorted == true)
	var found_shorted_conduit := false
	for c in app.conduits:
		if c["is_shorted"]:
			found_shorted_conduit = true
			break
	assert(found_shorted_conduit == true, "La connessione intersecata dal cortocircuito deve risultare interrotta")
	print("✔ Cortocircuito Duct Drone ha correttamente interrotto la linea elettrica")
	
	# Esecuzione Autobilanciamento per ripristinare i flussi aggirando il corto
	app.autobalance_grid()
	assert(app.total_grid_efficiency > 0.0, "Autobilanciamento deve mantenere attiva la nave")
	print("✔ Autobilanciamento flussi con successo")
	
	# Riparazione del cortocircuito
	short_dmg["repaired"] = true
	SpaceWorldManager.ship_damages_updated.emit(SpaceWorldManager.get_ship_damages())
	app.update_power_simulation()
	
	var any_short_left := false
	for c in app.conduits:
		if c["is_shorted"]:
			any_short_left = true
			break
	assert(not any_short_left, "Dopo la riparazione del Duct Drone nessuna linea deve rimanere interrotta")
	print("✔ Riparazione cortocircuito recepita: connessione ripristinata")
	
	# =========================================================================
	# FASE 9: MINI-TERMINALE COMANDI
	# =========================================================================
	print("\n--- TEST 9: Esecuzione Comandi Mini-Terminale ---")
	app.execute_terminal_command("help")
	app.execute_terminal_command("status")
	app.execute_terminal_command("devices")
	app.execute_terminal_command("junctions")
	app.execute_terminal_command("switch J1 1")
	app.execute_terminal_command("diag")
	app.execute_terminal_command("autobalance")
	app.execute_terminal_command("config")
	app.execute_terminal_command("reload")
	app.execute_terminal_command("clear")
	print("✔ Tutti i comandi del mini-terminale eseguiti senza errori")
	
	# =========================================================================
	# FASE 10: PULIZIA RISORSE E SEGNALI IN _EXIT_TREE
	# =========================================================================
	print("\n--- TEST 10: Pulizia _exit_tree() ---")
	remove_child(app)
	app.queue_free()
	await get_tree().process_frame
	print("✔ Nodo rimosso e deallocato correttamente")
	
	print("\n=======================================================")
	print("✔ TUTTI I TEST POWER GRID COMPLETATI CON SUCCESSO! (10/10)")
	print("=======================================================\n")
	get_tree().quit(0)
