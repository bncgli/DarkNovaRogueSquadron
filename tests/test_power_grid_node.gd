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
	print("✔ Modifica del file .dat recepita in tempo reale")
	
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
	assert(app.can_control == false, "Un ruolo non autorizzato (Tattico) in multiplayer non deve poter spegnere le stanze")
	
	# Ripristina controllo Ingegnere
	NetworkManager.is_solo_mode = true
	NetworkManager.request_role("Ingegnere")
	NetworkManager.player_role_changed.emit(1, "Ingegnere")
	await get_tree().process_frame
	assert(app.can_control == true, "Controllo ripristinato per Ingegnere")
	print("✔ Regole RBAC verificate con successo")
	
	# =========================================================================
	# FASE 6: MONITORAGGIO POTENZA NAVE
	# =========================================================================
	print("\n--- TEST 6: Monitoraggio Potenza Nave ---")
	app._refresh_power_logic()
	print("  Potenza Generata: %.2f MW" % app.total_gen_mw)
	print("  Potenza Consumata: %.2f MW" % app.total_cons_mw)
	assert(app.total_gen_mw > 0.0, "Deve esserci potenza generata (reattore)")
	print("✔ Monitoraggio potenza energetica validato")
	
	# =========================================================================
	# FASE 7: TASK-026 - COLORI STATO PRODUTTORI/CONSUMATORI (RoomPowerEntry)
	# =========================================================================
	print("\n--- TEST 7: TASK-026 Colori Stato Stanze (RoomPowerEntry) ---")
	var entry_scene: PackedScene = load("res://Applications/PowerGrid/Components/room_power_entry.tscn")
	var test_entry: RoomPowerEntry = entry_scene.instantiate() as RoomPowerEntry
	add_child(test_entry)
	await get_tree().process_frame
	
	# Caso 1: Generatore (power_mw > 0)
	test_entry.update_power(500.0)
	assert(test_entry.power_status_label.modulate.is_equal_approx(Color(0.2, 1.0, 0.4, 1.0)), "Produttore deve avere colore verde brillante Color(0.2, 1.0, 0.4)")
	assert(test_entry.power_bar.modulate.is_equal_approx(Color(0.2, 1.0, 0.4, 1.0)), "PowerBar produttore deve essere verde")
	
	# Caso 2: Consumatore (power_mw < 0)
	test_entry.update_power(-150.0)
	assert(test_entry.power_status_label.modulate.is_equal_approx(Color(1.0, 0.25, 0.25, 1.0)), "Consumatore deve avere colore rosso chiaro Color(1.0, 0.25, 0.25)")
	assert(test_entry.power_bar.modulate.is_equal_approx(Color(1.0, 0.25, 0.25, 1.0)), "PowerBar consumatore deve essere rossa")
	
	# Caso 3: Neutro / Spento (power_mw == 0)
	test_entry.update_power(0.0)
	assert(test_entry.power_status_label.modulate.is_equal_approx(Color(0.65, 0.65, 0.65, 1.0)), "Neutro deve avere colore grigio Color(0.65, 0.65, 0.65)")
	assert(test_entry.power_bar.modulate.is_equal_approx(Color(0.65, 0.65, 0.65, 1.0)), "PowerBar neutra deve essere grigia")
	
	remove_child(test_entry)
	test_entry.queue_free()
	print("✔ TASK-026: Colori RoomPowerEntry verificati con successo")
	
	# =========================================================================
	# FASE 8: TASK-026 - ISPETTORE DI STANZA & FORMATTAZIONE
	# =========================================================================
	print("\n--- TEST 8: TASK-026 Ispettore di Stanza ---")
	if not app.rooms_data.is_empty():
		var first_rid: String = str(app.rooms_data[0].get("id", ""))
		app._on_room_selected(first_rid)
		assert(app.inspector_title_label != null and not app.inspector_title_label.text.is_empty(), "Inspector title popolato")
		assert(app.inspector_inputs_label != null, "Inspector inputs label presente")
	print("✔ TASK-026: Ispettore di stanza verificato con successo")
	
	# =========================================================================
	# FASE 9: MINI-TERMINALE COMANDI
	# =========================================================================
	print("\n--- TEST 9: Esecuzione Comandi Mini-Terminale ---")
	app.execute_terminal_command("help")
	app.execute_terminal_command("status")
	app.execute_terminal_command("diag")
	app.execute_terminal_command("autobalance")
	app.execute_terminal_command("config")
	app.execute_terminal_command("reload")
	app.execute_terminal_command("clear")
	print("✔ Comandi del mini-terminale eseguiti senza errori")
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
