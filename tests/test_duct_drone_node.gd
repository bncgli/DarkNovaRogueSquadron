extends Node

func _ready() -> void:
	print("--- INIZIO TEST DUCT DRONE & ARCHITECTURE STANDARD ---")
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
	
	var app_res: PackedScene = load("res://Applications/DuctDrone/duct_drone_app.tscn")
	assert(app_res != null, "Scena duct_drone_app.tscn valida")
	var app: DuctDroneApp = app_res.instantiate() as DuctDroneApp
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
	
	# Verifica che tutti i pulsanti abbiano focus_mode disabilitato per evitare focus trapping
	var buttons: Array[Button] = [
		app.btn_forward, app.btn_backward, app.btn_rot_left, app.btn_rot_right,
		app.btn_stop, app.btn_reset, app.btn_speed_mode, app.btn_lights_toggle,
		app.btn_scan_pulse, app.btn_repair, app.reload_config_button
	]
	for b in buttons:
		if b:
			assert(b.focus_mode == Control.FOCUS_NONE, "Il focus_mode del pulsante %s deve essere FOCUS_NONE" % b.name)
	print("✔ Focus mode di tutti i pulsanti impostato correttamente su FOCUS_NONE")
	
	# =========================================================================
	# FASE 3: VERIFICA CARTELLA DRIVE PROTETTA & FILE .DAT DI DEFAULT
	# =========================================================================
	print("\n--- TEST 3: Cartella Protetta Ship Drive/Programs/DuctDrone e file .dat ---")
	assert(DirAccess.dir_exists_absolute("user://files/Ship Drive/Programs/DuctDrone"), "Cartella Programs/DuctDrone deve esistere in Ship Drive")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/DuctDrone/duct_drone_config.dat"), "duct_drone_config.dat deve esistere in Ship Drive/Programs/DuctDrone/")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/DuctDrone/drone_tuning.dat"), "drone_tuning.dat deve esistere in Ship Drive/Programs/DuctDrone/")
	
	if fpm:
		assert(fpm.has_password("Ship Drive/Programs/DuctDrone"), "La cartella Ship Drive/Programs/DuctDrone deve essere protetta da password")
		assert(fpm.check_password("Ship Drive/Programs/DuctDrone", "DRONE-7815"), "La password predefinita della cartella deve essere DRONE-7815")
	print("✔ Cartella e file .dat protetti creati con successo in Ship Drive")
	
	# =========================================================================
	# FASE 4: CARICAMENTO DINAMICO DEI PARAMETRI .DAT E APPLICAZIONE A RUNTIME
	# =========================================================================
	print("\n--- TEST 4: Caricamento dinamico ed effetto a runtime dei parametri .dat ---")
	var initial_cfg := app.load_dat_configuration()
	assert(initial_cfg.get("is_dat_loaded") == true, "Configurazione .dat deve risultare caricata")
	assert(initial_cfg.get("linear_speed") == 175.0, "Velocità lineare iniziale deve essere 175.0")
	assert(initial_cfg.get("rotate_speed") == 3.0, "Velocità rotazione iniziale deve essere 3.0")
	print("✔ Valori iniziali .dat applicati correttamente")
	
	# Modifica dinamica del file duct_drone_config.dat (Tuning / Overclocking robottino)
	var new_dat_content := "[SYSTEM]\napp_name=DuctDrone\nversion=1.0.4\nstatus=OVERCLOCKED\n\n[DRONE_DYNAMICS]\nlinear_speed=260.0\nlinear_acceleration=900.0\nlinear_deceleration=950.0\nrotate_speed=4.5\n\n[BATTERY_MANAGEMENT]\nbattery_max=120.0\nbattery_drain_move=0.2\nbattery_drain_lights=0.4\nbattery_drain_radar=2.0\nbattery_drain_repair=3.0\n\n[MAINTENANCE]\nradar_scan_radius_max=220.0\nrepair_range=60.0\nrepair_speed_multiplier=2.0\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/DuctDrone/duct_drone_config.dat", FileAccess.WRITE)
	f_out.store_string(new_dat_content)
	f_out.close()
	
	# Notifica sincronizzazione/modifica
	if sdm:
		sdm.file_synced.emit("Ship Drive/Programs/DuctDrone/duct_drone_config.dat")
	else:
		app.load_dat_configuration()
	await get_tree().process_frame
	
	assert(app.active_config["linear_speed"] == 260.0, "linear_speed aggiornato in tempo reale a 260.0")
	assert(app.active_config["rotate_speed"] == 4.5, "rotate_speed aggiornato in tempo reale a 4.5")
	assert(app.active_config["repair_range"] == 60.0, "repair_range aggiornato in tempo reale a 60.0")
	assert(app.active_config["repair_speed_multiplier"] == 2.0, "repair_speed_multiplier aggiornato in tempo reale a 2.0")
	print("✔ Modifica del file .dat recepita in tempo reale e applicata alle prestazioni del robottino")
	
	# =========================================================================
	# FASE 5: RBAC - CONTROLLO RUOLI (INGEGNERE VS RUOLO NON AUTORIZZATO)
	# =========================================================================
	print("\n--- TEST 5: Controllo Ruoli RBAC ---")
	# Ruolo Ingegnere
	NetworkManager.request_role("Ingegnere")
	await get_tree().process_frame
	assert(app.can_control == true, "L'Ingegnere deve poter controllare il Duct Drone")
	assert(app.btn_forward.disabled == false, "I pulsanti devono essere attivi per l'Ingegnere")
	assert(app.btn_lights_toggle.disabled == false, "Pulsante fari attivo per l'Ingegnere")
	
	# Ruolo Tattico in multiplayer (Solo telemetria/osservazione)
	NetworkManager.request_role("Tattico")
	NetworkManager.is_solo_mode = false # Simula multiplayer
	NetworkManager.player_role_changed.emit(1, "Tattico")
	await get_tree().process_frame
	assert(app.can_control == false, "Il Tattico in multiplayer non deve poter manovrare il Duct Drone")
	assert(app.btn_forward.disabled == true, "I pulsanti devono essere disabilitati per il Tattico")
	assert(app.btn_lights_toggle.disabled == true, "Pulsante fari disabilitato per il Tattico")
	print("✔ Restrizioni RBAC sui ruoli verificate con successo")
	
	# Ripristina ruolo Ingegnere per test fisici
	NetworkManager.is_solo_mode = true
	NetworkManager.request_role("Ingegnere")
	NetworkManager.player_role_changed.emit(1, "Ingegnere")
	await get_tree().process_frame
	
	# =========================================================================
	# FASE 6: COMANDI TANK 2D, FARI, SONAR E RIPARAZIONI
	# =========================================================================
	print("\n--- TEST 6: Test Fisici Comandi Tank, Fari, Sonar e Riparazioni ---")
	var initial_pos := app.drone_pos
	var initial_heading := app.drone_heading
	
	# 1. Rotazione Tank
	app._ui_angular_input = 1.0
	app._process(0.1)
	SpaceWorldManager._physics_process(0.1)
	app._process(0.01)
	assert(app.drone_heading > initial_heading, "Rotazione oraria avvenuta con successo")
	app._ui_angular_input = 0.0
	
	# 2. Movimento Lineare
	SpaceWorldManager.duct_drone_heading = PI * 0.5
	app.drone_heading = PI * 0.5
	app._ui_linear_input = 1.0
	for i in range(10):
		app._process(0.05)
		SpaceWorldManager._physics_process(0.05)
	app._process(0.01)
	assert(app.drone_pos.y > initial_pos.y, "Avanzamento tank avvenuto con successo")
	app._ui_linear_input = 0.0
	
	# Stop rapido
	app._on_stop_pressed()
	SpaceWorldManager._physics_process(0.05)
	app._process(0.01)
	assert(app.drone_current_speed == 0.0, "Pulsante Stop arresta immediatamente il robottino")
	
	# Fari e Sonar
	assert(app.lights_enabled == true, "Fari inizialmente ON")
	app._on_lights_toggle()
	assert(app.lights_enabled == false, "Fari impostati su OFF")
	app._on_lights_toggle()
	assert(app.lights_enabled == true, "Fari riaccesi su ON")
	
	app._on_scan_pulse_pressed()
	assert(app.scan_pulse_active == true, "Impulso Sonar attivato")
	SpaceWorldManager._physics_process(0.1)
	app._process(0.01)
	assert(app.scan_pulse_radius > 5.0, "Raggio impulso Sonar in espansione")
	
	# Reset Base Dock
	app._on_reset_pressed()
	SpaceWorldManager._physics_process(0.01)
	app._process(0.01)
	assert(app.drone_pos == app.initial_drone_pos, "Robottino riposizionato alla base dock")
	
	# Danni & Riparazioni
	SpaceWorldManager.clear_ship_damages()
	var breach_dmg := SpaceWorldManager.spawn_ship_damage(SpaceWorldManager.DAMAGE_TYPE_BREACH, Vector2(300, 160), "Condotto Dorsale", 4.0)
	var short_dmg := SpaceWorldManager.spawn_ship_damage(SpaceWorldManager.DAMAGE_TYPE_SHORT_CIRCUIT, Vector2(300, 240), "Condotto Reattore", 5.0)
	
	assert(breach_dmg.get("revealed") == false, "Breccia inizialmente invisibile")
	assert(short_dmg.get("revealed") == false, "Cortocircuito inizialmente invisibile")
	
	# Rivelazione Breccia con luce
	SpaceWorldManager.duct_drone_pos = Vector2(300, 155)
	SpaceWorldManager.duct_drone_lights = true
	SpaceWorldManager._physics_process(0.1)
	assert(breach_dmg.get("revealed") == true, "Breccia rivelata dai fari/luce")
	
	# Rivelazione Cortocircuito con radar
	SpaceWorldManager.duct_drone_pos = Vector2(300, 235)
	SpaceWorldManager.trigger_duct_drone_scan()
	SpaceWorldManager._physics_process(0.3)
	assert(short_dmg.get("revealed") == true, "Cortocircuito rilevato dal radar")
	
	# Riparazione della breccia
	SpaceWorldManager.duct_drone_pos = Vector2(300, 160)
	SpaceWorldManager._physics_process(0.01)
	app._process(0.01)
	assert(not app.nearby_damage.is_empty(), "Danno adiacente rilevato")
	
	app._on_repair_button_pressed()
	assert(app.is_repairing == true or SpaceWorldManager.is_duct_drone_repairing == true, "Riparazione avviata")
	
	for step in range(30):
		SpaceWorldManager._physics_process(0.1)
		app._process(0.01)
	
	assert(breach_dmg.get("repaired") == true, "Breccia riparata con successo")
	
	# =========================================================================
	# FASE 7: VERIFICA TERMINALE / CAT SUI FILE .DAT
	# =========================================================================
	print("\n--- TEST 7: Protezione .dat dal File Reader / Visualizzatore di testo ---")
	var terminal_res := load("res://Applications/Terminal/src/terminal_scene.tscn") as PackedScene
	if terminal_res:
		var term := terminal_res.instantiate() as Terminal
		add_child(term)
		await get_tree().process_frame
		
		var cat_script: GDScript = load("res://Applications/Terminal/commands/cat_command.gd")
		var cat_cmd = cat_script.new()
		term.virtual_path_manager.set_path("Ship Drive/Programs/DuctDrone")
		var args: Array[String] = ["duct_drone_config.dat"]
		cat_cmd.execute(term, args)
		
		var found_msg := false
		for c in term.command_output_container.get_children():
			if "text" in c and (c.text.contains("non sono leggibili") or c.text.contains(".dat")):
				found_msg = true
				break
		assert(found_msg, "Il comando cat deve rifiutare la lettura diretta del file .dat")
		print("✔ File .dat protetto dalla visualizzazione di testo standard")
		term.queue_free()
	
	app.queue_free()
	print("\n=== TUTTI I TEST DELLO STANDARD ARCHITETTURALE E DUCT DRONE COMPLETATI CON SUCCESSO! ===")
	get_tree().quit(0)
