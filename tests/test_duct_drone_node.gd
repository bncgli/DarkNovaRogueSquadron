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
	SpaceWorldManager.duct_drone_heading = -PI * 0.5
	app.drone_heading = -PI * 0.5
	app._ui_linear_input = 1.0
	for i in range(10):
		app._process(0.05)
		SpaceWorldManager._physics_process(0.05)
	app._process(0.01)
	assert(app.drone_pos.y < initial_pos.y, "Avanzamento tank avvenuto con successo")
	app._ui_linear_input = 0.0
	
	# Stop rapido
	app._on_stop_pressed()
	SpaceWorldManager._physics_process(0.05)
	app._process(0.01)
	assert(app.drone_current_speed == 0.0, "Pulsante Stop arresta immediatamente il robottino")
	
	# Fari e Sonar
	assert(app.lights_enabled == false, "Fari inizialmente OFF di default")
	assert(app.btn_lights_toggle.text.contains("OFF"), "Pulsante fari mostra OFF all'avvio")
	app._on_lights_toggle()
	assert(app.lights_enabled == true, "Fari impostati su ON")
	app._on_lights_toggle()
	assert(app.lights_enabled == false, "Fari ripristinati su OFF")
	
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
	SpaceWorldManager.duct_drone_lights = false
	app.lights_enabled = false
	
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
	
	# =========================================================================
	# FASE 8: TASK-028 - BLUEPRINT ALIGNMENT, RADAR KEY 'R' & EMERGENCY RECOVERY
	# =========================================================================
	print("\n--- TEST 8: TASK-028 - Blueprint Alignment, Radar Key 'R', Recharge Room & Emergency Recovery ---")
	
	# 1. Verifica rimozione pulsante %BtnReset
	assert(app.get_node_or_null("%BtnReset") == null, "Il pulsante %BtnReset deve essere rimosso dal layout visivo")
	print("✔ %BtnReset rimosso correttamente dal layout")
	
	# 2. Verifica inizializzazione posizione e heading da ShipBlueprint
	var bp := SpaceWorldManager.get_ship_blueprint()
	assert(bp != null, "ShipBlueprint attiva disponibile")
	assert(app.initial_drone_pos == bp.get_drone_spawn_pos(), "initial_drone_pos allineata a bp.drone_spawn_pos")
	assert(app.drone_heading == bp.drone_spawn_heading, "drone_heading allineato a bp.drone_spawn_heading")
	print("✔ Spawn position e heading allineati alla ShipBlueprint (%v, %.2f rad)" % [app.drone_pos, app.drone_heading])
	
	# 3. Verifica rimappatura tasto 'R' a scan sonar/radar
	app.scan_pulse_active = false
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_R
	key_event.physical_keycode = KEY_R
	app._input(key_event)
	assert(app.scan_pulse_active == true, "La pressione del tasto 'R' deve attivare l'impulso radar/sonar")
	print("✔ Tasto 'R' rimappato con successo all'impulso radar")
	
	# 4. Verifica vincolo di ricarica stanza (recharge_room_id)
	var recharge_room = bp.get_room_by_id(bp.recharge_room_id)
	assert(recharge_room != null, "Stanza di ricarica definita nella blueprint")
	
	# Fuori dalla stanza di ricarica -> NESSUNA ricarica
	app.drone_pos = Vector2(160, 80) # Nel condotto sensori (fuori dalla stanza di ricarica)
	app.drone_battery = 50.0
	app._process(1.0)
	assert(app.drone_battery <= 50.0, "Fuori dalla stanza di ricarica non deve esserci ricarica passiva")
	
	# Dentro la stanza di ricarica -> Ricarica attiva
	app.drone_pos = recharge_room.rect.position + Vector2(10, 10) # Dentro la stanza di ricarica
	var bat_before := app.drone_battery
	app._process(1.0)
	assert(app.drone_battery > bat_before, "All'interno della stanza di ricarica la batteria deve ricaricarsi")
	print("✔ Ricarica batteria vincolata correttamente alla stanza designata (%s)" % bp.recharge_room_id)
	
	# 5. Verifica Timer Recupero Emergenza (60s) a batteria 0% fuori dalla stanza
	app.drone_pos = Vector2(160, 80) # Fuori dalla stanza di ricarica
	app.drone_battery = 0.0
	app.is_in_emergency_recovery = false
	app.emergency_recovery_time_left = 0.0
	
	# Frame 1: Attivazione emergenza
	app._process(0.1)
	assert(app.is_in_emergency_recovery == true, "Stato di recupero di emergenza attivato a batteria 0%")
	assert(app.emergency_recovery_time_left <= 60.0 and app.emergency_recovery_time_left >= 59.0, "Timer emergenza avviato a 60s")
	assert(app.status_summary_label.text.contains("RECUPERO EMERGENZA IN:"), "Countdown visibile nell'HUD")
	
	# Blocco controlli di movimento
	app._ui_linear_input = 1.0
	app._ui_angular_input = 1.0
	var pos_frozen := app.drone_pos
	var heading_frozen := app.drone_heading
	app._process(0.5)
	assert(app.drone_pos == pos_frozen, "Movimento lineare bloccato durante il recupero")
	assert(app.drone_heading == heading_frozen, "Rotazione angolare bloccata durante il recupero")
	
	# Avanzamento timer fino a scadenza (60 secondi)
	app._process(60.0)
	assert(app.is_in_emergency_recovery == false, "Stato di recupero di emergenza terminato allo scadere dei 60s")
	assert(app.drone_pos == bp.get_drone_spawn_pos(), "Drone riposizionato alla posizione di spawn")
	assert(app.drone_battery == 25.0, "Batteria ripristinata al 25% dopo il recupero di emergenza")
	app._ui_linear_input = 0.0
	app._ui_angular_input = 0.0
	SpaceWorldManager.stop_duct_drone()
	app._on_stop_pressed()
	print("✔ Timer di emergenza (60s), blocco comandi e riposizionamento al 25% verificati con successo")
	
	# =========================================================================
	# FASE 9: TASK-034 - TIPO DANNO INCENDIO (FIRE / dmg_fire)
	# =========================================================================
	print("\n--- TEST 9: TASK-034 - Tipo Danno Incendio (FIRE / dmg_fire) ---")
	
	# 1. Verifica costanti danno FIRE
	assert(ShipBlueprint.DAMAGE_TYPE_FIRE == "fire", "ShipBlueprint.DAMAGE_TYPE_FIRE definita")
	assert(ShipDamageData.DAMAGE_TYPE_FIRE == "fire", "ShipDamageData.DAMAGE_TYPE_FIRE definita")
	assert(SpaceWorldManager.DAMAGE_TYPE_FIRE == "fire", "SpaceWorldManager.DAMAGE_TYPE_FIRE definita")
	
	# 2. Spawn danno da incendio
	SpaceWorldManager.clear_ship_damages()
	var fire_dmg := SpaceWorldManager.spawn_ship_damage(SpaceWorldManager.DAMAGE_TYPE_FIRE, Vector2(300, 240), "Nucleo Reattore", 4.0)
	assert(fire_dmg != null, "Danno incendio spawnato con successo")
	assert(fire_dmg.type == "fire", "Tipo danno corrisponde a 'fire'")
	assert(fire_dmg.revealed == false, "Incendio inizialmente non rivelato")
	
	# 3. Rivelazione per vicinanza termica (<= 45px)
	SpaceWorldManager.duct_drone_pos = Vector2(300, 230)
	SpaceWorldManager._physics_process(0.1)
	assert(fire_dmg.revealed == true, "Incendio rivelato dai sensori termici di prossimità")
	assert(fire_dmg.revealed_by == "thermal", "Rivelato via thermal")
	
	# 4. Verifica UI danno incendio
	app.drone_pos = Vector2(300, 230)
	app._process(0.01)
	assert(not app.nearby_damage.is_empty(), "Danno incendio adiacente rilevato dall'app")
	assert(app.nearby_damage_label.text.contains("Incendio"), "Label telemetria indica Incendio Attivo")
	assert(app.btn_repair.text.contains("ESTINGUI") or app.btn_repair.text.contains("FUOCO"), "Pulsante riparazione mostra opzione estinzione fuoco")
	
	# 5. Estinzione e completamento riparazione
	app._on_repair_button_pressed()
	assert(app.is_repairing == true or SpaceWorldManager.is_duct_drone_repairing == true, "Estinzione incendio avviata")
	
	for step in range(35):
		SpaceWorldManager._physics_process(0.1)
		app._process(0.01)
	
	assert(fire_dmg.repaired == true, "Incendio estinto e riparato con successo")
	assert(app.nearby_damage.is_empty(), "Nessun danno adiacente attivo dopo estinzione")
	print("✔ Riconoscimento, rivelazione termica, UI ed estinzione del tipo di danno Incendio (FIRE) verificati con successo")
	
	# =========================================================================
	# FASE 10: TASK-034 - BARRIERE STANZE SIGILLATE (ROOM SEALING COLLISION BARRIERS)
	# =========================================================================
	print("\n--- TEST 10: TASK-034 - Barriere Stanze Sigillate ---")
	
	# Sigilla la stanza del Ponte di Comando ('bridge')
	SpaceWorldManager.set_room_sealed("bridge", true)
	assert(SpaceWorldManager.is_room_sealed("bridge") == true, "Stanza bridge risulta sigillata in SpaceWorldManager")
	assert(app.is_room_sealed("bridge") == true, "Stanza bridge risulta sigillata in DuctDroneApp")
	
	# Caso 1: Drone ESTERNO tenta di entrare nella stanza sigillata -> BLOCCATO
	# Posiziona il drone nel condotto esterno verso il bridge a Vector2(300, 125) (Bridge rect: 230, 45, 140, 70 -> Y da 45 a 115)
	SpaceWorldManager.duct_drone_pos = Vector2(300, 125)
	app.drone_pos = Vector2(300, 125)
	var target_inside_bridge := Vector2(300, 90)
	assert(app._can_move_to(target_inside_bridge) == false, "Il drone all'esterno non può entrare nella stanza sigillata")
	
	# Test fisico con input verso Nord (verso il bridge)
	SpaceWorldManager.duct_drone_heading = -PI * 0.5
	app.drone_heading = -PI * 0.5
	app._ui_linear_input = 1.0
	for step in range(10):
		app._process(0.05)
		SpaceWorldManager._physics_process(0.05)
	app._process(0.01)
	assert(app.drone_pos.y >= 115.0, "Il drone rimane all'esterno del perimetro sigillato (pos: %v)" % app.drone_pos)
	app._ui_linear_input = 0.0
	
	# Caso 2: Drone INTERNO tenta di uscire dalla stanza sigillata -> CONFINATO ALL'INTERNO
	# Posiziona il drone all'interno del bridge a Vector2(300, 60)
	SpaceWorldManager.duct_drone_pos = Vector2(300, 60)
	app.drone_pos = Vector2(300, 60)
	var target_outside_bridge := Vector2(300, 125)
	assert(app._can_move_to(target_outside_bridge) == false, "Il drone all'interno non può uscire dalla stanza sigillata")
	
	# Test fisico con input verso Sud (verso l'uscita condotto)
	SpaceWorldManager.duct_drone_heading = PI * 0.5
	app.drone_heading = PI * 0.5
	app._ui_linear_input = 1.0
	for step in range(10):
		app._process(0.05)
		SpaceWorldManager._physics_process(0.05)
	app._process(0.01)
	assert(app.drone_pos.y <= 115.0 and app.drone_pos.y >= 45.0, "Il drone rimane confinato all'interno del ponte sigillato (pos: %v)" % app.drone_pos)
	app._ui_linear_input = 0.0
	
	# Caso 3: Movimento consentito all'interno della stanza sigillata
	var pos_before_move := app.drone_pos
	SpaceWorldManager.duct_drone_heading = 0.0 # Est (verso destra dentro il ponte)
	app.drone_heading = 0.0
	app._ui_linear_input = 1.0
	for step in range(5):
		app._process(0.05)
		SpaceWorldManager._physics_process(0.05)
	app._process(0.01)
	assert(app.drone_pos.x > pos_before_move.x, "Movimento libero all'interno della stanza sigillata")
	app._ui_linear_input = 0.0
	
	# Caso 4: Dissigillatura stanza -> passaggio riaperto
	SpaceWorldManager.set_room_sealed("bridge", false)
	assert(app.is_room_sealed("bridge") == false, "Stanza ponte dissigillata con successo")
	assert(app._can_move_to(Vector2(300, 125)) == true, "Transito verso l'esterno consentito dopo dissigillatura")
	print("✔ Barriere fisiche paratie stagne perimetrali (blocco ingresso/uscita, confinamento interno) verificate con successo")
	
	# =========================================================================
	# FASE 11: TASK-034 - LUCE SPENTA DI DEFAULT E SPAWN RIGOROSO DA BLUEPRINT
	# =========================================================================
	print("\n--- TEST 11: TASK-034 - Default Luce Spenta e Spawn Rigoroso ---")
	SpaceWorldManager.reset_duct_drone()
	var fresh_app: DuctDroneApp = app_res.instantiate() as DuctDroneApp
	add_child(fresh_app)
	await get_tree().process_frame
	
	# Verifica luce spenta di default all'avvio
	assert(fresh_app.lights_enabled == false, "lights_enabled è false di default all'avvio")
	assert(fresh_app.btn_lights_toggle.text.contains("OFF"), "Pulsante fari indica 'LUCI: OFF' all'avvio")
	
	# Verifica coordinate spawn e heading lette da ShipBlueprint
	assert(fresh_app.initial_drone_pos == bp.get_drone_spawn_pos(), "initial_drone_pos corrisponde esattamente a bp.get_drone_spawn_pos() (%v)" % bp.get_drone_spawn_pos())
	assert(fresh_app.drone_pos == bp.get_drone_spawn_pos(), "drone_pos corrisponde esattamente a bp.get_drone_spawn_pos() (%v)" % bp.get_drone_spawn_pos())
	assert(fresh_app.drone_heading == bp.drone_spawn_heading, "drone_heading corrisponde esattamente a bp.drone_spawn_heading (%f)" % bp.drone_spawn_heading)
	assert(fresh_app.drone_pos != Vector2(300, 80) or bp.get_drone_spawn_pos() == Vector2(300, 80), "Nessun fallback hardcoded spurio a Vector2(300, 80)")
	
	fresh_app.queue_free()
	print("✔ Default luce OFF e inizializzazione coordinate spawn da Blueprint verificati con successo")
	
	app.queue_free()
	print("\n=== TUTTI I TEST DELLO STANDARD ARCHITETTURALE E DUCT DRONE COMPLETATI CON SUCCESSO! ===")
	get_tree().quit(0)
