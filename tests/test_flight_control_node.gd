extends Node

func _ready() -> void:
	print("--- INIZIO TEST FLIGHT CONTROL & ARCHITECTURE STANDARD ---")
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
	
	var app_res: PackedScene = load("res://Applications/FlightControl/flight_control_app.tscn")
	assert(app_res != null, "Scena flight_control_app.tscn valida")
	var app: FlightControlApp = app_res.instantiate() as FlightControlApp
	add_child(app)
	await get_tree().process_frame
	
	assert(not app.is_operational(), "L'app non deve essere operativa quando la nave è disconnessa")
	assert(app.disconnected_overlay != null and app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve essere visibile da disconnesso")
	print("✔ Overlay di blocco visibile e operativo da disconnesso")
	
	# =========================================================================
	# FASE 2: AVVIO MISSIONE & STATO OPERATIVO
	# =========================================================================
	print("\n--- TEST 2: Avvio Missione & Connessione Nave ---")
	if NetworkManager:
		NetworkManager.start_solo_game("Pilota")
		NetworkManager.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame
	
	assert(app.is_operational(), "L'app deve essere operativa dopo l'avvio della missione")
	assert(app.disconnected_overlay != null and not app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve scomparire dopo l'avvio della missione")
	print("✔ Overlay rimosso istantaneamente all'avvio della missione")
	
	var ship: Spaceship = SpaceWorldManager.get_spaceship()
	assert(ship != null, "SpaceWorldManager deve restituire l'istanza Spaceship")
	print("✔ Spaceship presente e collegata")
	
	# =========================================================================
	# FASE 3: VERIFICA CARTELLA DRIVE PROTETTA & FILE .DAT DI DEFAULT
	# =========================================================================
	print("\n--- TEST 3: Cartella Protetta Ship Drive/Programs/FlightControls e file .dat ---")
	assert(DirAccess.dir_exists_absolute("user://files/Ship Drive/Programs/FlightControls"), "Cartella Programs/FlightControls deve esistere in Ship Drive")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/FlightControls/flight_config.dat"), "flight_config.dat deve esistere in Ship Drive/Programs/FlightControls/")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/FlightControls/thrusters_tuning.dat"), "thrusters_tuning.dat deve esistere in Ship Drive/Programs/FlightControls/")
	
	if fpm:
		assert(fpm.has_password("Ship Drive/Programs/FlightControls"), "La cartella Ship Drive/Programs/FlightControls deve essere protetta da password")
		assert(fpm.check_password("Ship Drive/Programs/FlightControls", "FLIGHT-7815"), "La password predefinita della cartella deve essere FLIGHT-7815")
	print("✔ Cartella e file .dat protetti creati con successo in Ship Drive")
	
	# =========================================================================
	# FASE 4: CARICAMENTO DINAMICO DEI PARAMETRI .DAT E APPLICAZIONE A RUNTIME
	# =========================================================================
	print("\n--- TEST 4: Caricamento dinamico ed effetto a runtime dei parametri .dat ---")
	var initial_cfg := app.load_dat_configuration()
	assert(initial_cfg.get("is_dat_loaded") == true, "Configurazione .dat deve risultare caricata")
	assert(ship.max_linear_speed == 20.0, "Velocità lineare iniziale nave deve essere 20.0")
	assert(ship.linear_acceleration == 35.0, "Accelerazione lineare iniziale nave deve essere 35.0")
	print("✔ Valori iniziali .dat applicati correttamente all'istanza Spaceship")
	
	# Modifica dinamica del file flight_config.dat (Tuning / Overclocking)
	var new_dat_content := "[SYSTEM]\napp_name=FlightControls\nversion=1.0.4\nstatus=OVERCLOCKED\n\n[FLIGHT_DYNAMICS]\nmax_linear_speed=50.0\nlinear_acceleration=90.0\nlinear_deceleration=40.0\nmax_angular_speed=5.0\nangular_acceleration=18.0\nangular_deceleration=12.0\n\n[SPEED_MODES]\nturbo_multiplier=3.0\nprecision_multiplier=0.2\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/FlightControls/flight_config.dat", FileAccess.WRITE)
	f_out.store_string(new_dat_content)
	f_out.close()
	
	# Notifica sincronizzazione/modifica
	if sdm:
		sdm.file_synced.emit("Ship Drive/Programs/FlightControls/flight_config.dat")
	else:
		app.load_dat_configuration()
	await get_tree().process_frame
	
	assert(ship.max_linear_speed == 50.0, "max_linear_speed aggiornato in tempo reale a 50.0")
	assert(ship.linear_acceleration == 90.0, "linear_acceleration aggiornato in tempo reale a 90.0")
	assert(ship.max_angular_speed == 5.0, "max_angular_speed aggiornato in tempo reale a 5.0")
	print("✔ Modifica del file .dat recepita in tempo reale e applicata alle prestazioni della nave")
	
	# =========================================================================
	# FASE 5: RBAC - CONTROLLO RUOLI (PILOTA VS INGEGNERE / OSSERVATORE)
	# =========================================================================
	print("\n--- TEST 5: Controllo Ruoli RBAC ---")
	# Ruolo Pilota
	NetworkManager.request_role("Pilota")
	await get_tree().process_frame
	assert(app.can_control_flight == true, "Il Pilota deve poter controllare il volo")
	assert(app.btn_w.disabled == false, "I pulsanti devono essere attivi per il Pilota")
	assert(app.thrusters_badge.text.contains("PROPULSORI PRONTI") or app.thrusters_badge.text.contains("PROPULSORI ATTIVI") or app.thrusters_badge.text.contains("IN VOLO"), "Badge per Pilota")
	
	# Ruolo Ingegnere (Solo telemetria)
	NetworkManager.request_role("Ingegnere")
	NetworkManager.is_solo_mode = false # Simula multiplayer con ruolo assegnato
	NetworkManager.player_role_changed.emit(1, "Ingegnere")
	await get_tree().process_frame
	assert(app.can_control_flight == false, "L'Ingegnere non deve poter manovrare l'astronave")
	assert(app.btn_w.disabled == true, "I pulsanti devono essere disabilitati per l'Ingegnere")
	assert(app.thrusters_badge.text == "SOLO TELEMETRIA", "Badge deve indicare SOLO TELEMETRIA")
	print("✔ Restrizioni RBAC sui ruoli verificate con successo")
	
	# Ripristina ruolo pilota per test fisici
	NetworkManager.is_solo_mode = true
	NetworkManager.request_role("Pilota")
	NetworkManager.player_role_changed.emit(1, "Pilota")
	await get_tree().process_frame
	
	# =========================================================================
	# FASE 6: COMANDI FISICI DI VOLO 6-DOF, INERZIA E REGOLAZIONE VELOCITÀ
	# =========================================================================
	print("\n--- TEST 6: Test Fisici 6-DOF, Inerzia e Regolazione Velocità (R/F) ---")
	# Avanti (W)
	SpaceWorldManager.set_spaceship_inputs(Vector3(0, 0, -1), Vector3.ZERO)
	ship._physics_process(0.1)
	assert(ship.linear_velocity.z < 0.0, "Spostamento in avanti")
	
	# Rollio (Q ed E)
	app.btn_q.button_down.emit()
	assert(app._ui_angular_input.z > 0.0, "UI angular input Z con tasto Q")
	app.btn_q.button_up.emit()
	assert(app._ui_angular_input.z == 0.0, "UI angular input Z ripristinato")
	
	# Smorzamento Inerziale (Inertia Dampening ON di default)
	assert(app.is_inertia_enabled == true, "Inerzia attiva di default")
	assert(ship.inertia_dampening == true, "Smorzamento nave attivo di default")
	assert(app.inertia_toggle_button != null, "Pulsante InertiaToggleButton presente")
	assert(app.inertia_toggle_button.text == "INERZIA: ON", "Testo pulsante iniziale INERZIA: ON")
	
	# Test decelerazione con Inerzia ON
	ship.linear_velocity = Vector3(0, 0, -20.0)
	SpaceWorldManager.set_spaceship_inputs(Vector3.ZERO, Vector3.ZERO)
	ship._physics_process(0.2)
	assert(ship.linear_velocity.length() < 20.0, "Con Inerzia ON la nave deve decelerare quando non ci sono input")
	
	# Toggle Inerzia OFF (Deriva Newtoniana)
	app._on_inertia_toggle_pressed()
	assert(app.is_inertia_enabled == false, "Inerzia disabilitata dopo toggle")
	assert(ship.inertia_dampening == false, "Smorzamento nave disabilitato")
	assert(app.inertia_toggle_button.text == "INERZIA: OFF", "Testo pulsante aggiornato a INERZIA: OFF")
	
	# Con Inerzia OFF, linear_velocity non deve decelerare
	ship.linear_velocity = Vector3(0, 0, -15.0)
	ship._physics_process(0.2)
	assert(is_equal_approx(ship.linear_velocity.length(), 15.0), "Con Inerzia OFF la nave conserva la velocità (deriva newtoniana)")
	
	# Ripristina Inerzia ON
	app._on_inertia_toggle_pressed()
	assert(app.is_inertia_enabled == true, "Inerzia ripristinata a ON")
	assert(ship.inertia_dampening == true, "Smorzamento nave ripristinato")
	
	# Regolazione Dinamica Velocità con Tasti R / F
	app._speed_multiplier = 1.0
	
	# Tasto R: incremento moltiplicatore (+0.1 fino a max 2.0x)
	var ev_r := InputEventKey.new()
	ev_r.keycode = KEY_R
	ev_r.pressed = true
	app._input(ev_r)
	assert(is_equal_approx(app._speed_multiplier, 1.1), "Tasto R incrementa moltiplicatore a 1.1x")
	
	# Incremento fino a clamp 2.0x
	for i in range(15):
		app._input(ev_r)
	assert(is_equal_approx(app._speed_multiplier, 2.0), "Moltiplicatore limitato a massimo 2.0x")
	
	# Tasto F: decremento moltiplicatore (-0.1 fino a min 0.5x)
	var ev_f := InputEventKey.new()
	ev_f.keycode = KEY_F
	ev_f.pressed = true
	app._input(ev_f)
	assert(is_equal_approx(app._speed_multiplier, 1.9), "Tasto F decrementa moltiplicatore a 1.9x")
	
	for i in range(20):
		app._input(ev_f)
	assert(is_equal_approx(app._speed_multiplier, 0.5), "Moltiplicatore limitato a minimo 0.5x")
	
	# Ripristina a 1.0x
	for i in range(5):
		app._input(ev_r)
	assert(is_equal_approx(app._speed_multiplier, 1.0), "Moltiplicatore riportato a 1.0x")
	
	# Verifica display telemetria
	app._update_telemetry_display(12.5, Vector3(10, 20, 30), Vector3(0, 45, 0))
	assert(app.speed_value_label.text.contains("12.5 m/s"), "Display telemetria mostra velocità")
	assert(app.speed_value_label.text.contains("1.0x"), "Display telemetria mostra moltiplicatore velocità")
	print("✔ Test fisici 6-DOF, Deriva Newtoniana e Regolazione Tasti R/F superati")
	
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
		term.virtual_path_manager.set_path("Ship Drive/Programs/FlightControls")
		var args: Array[String] = ["flight_config.dat"]
		cat_cmd.execute(term, args)
		
		# Controlla che nei messaggi di output sia presente l'errore di file non leggibile
		var found_msg := false
		for c in term.command_output_container.get_children():
			if "text" in c and (c.text.contains("non sono leggibili") or c.text.contains(".dat")):
				found_msg = true
				break
		assert(found_msg, "Il comando cat deve rifiutare la lettura diretta del file .dat")
		print("✔ File .dat protetto dalla visualizzazione di testo standard")
		term.queue_free()
	
	# =========================================================================
	# FASE 8: ALLINEAMENTO VETTORE ED ESECUZIONE TRANSITO HYPERDRIVE
	# =========================================================================
	print("\n--- TEST 8: Allineamento ed Esecuzione Hyperdrive ---")
	if StarSystemGridManager:
		var target_sec := Vector3i(4, 15, 0)
		var plotted := StarSystemGridManager.plot_route(target_sec)
		assert(not plotted.is_empty(), "Rotta verso (4,15,0) pianificata con successo")
		app._update_hyperdrive_ui()
		assert(app.hyperdrive_card != null and app.hyperdrive_card.visible, "Card Hyperdrive visibile con rotta attiva")
		
		# Allinea prua nave verso il vettore rotta
		app.align_to_hyperdrive_vector()
		assert(app.is_hyperdrive_aligned() == true, "L'astronave deve risultare allineata al vettore Hyperdrive")
		assert(app.btn_engage_hyperdrive != null and not app.btn_engage_hyperdrive.disabled, "Pulsante Engage abilitato ad allineamento avvenuto")
		
		# Esegui transito Hyperdrive
		var res := app.engage_hyperdrive()
		assert(res.get("success") == true, "Transito Hyperdrive completato con successo")
		assert(StarSystemGridManager.get_current_sector_coords() == target_sec, "Coordinate settore aggiornate al target")
		assert(app.active_hyperdrive_route.is_empty(), "Rotta ripulita dopo il transito")
		print("✔ Allineamento rotte ed esecuzione transito Hyperdrive completati con successo")
	
	app.queue_free()
	print("\n=== TUTTI I TEST DELLO STANDARD ARCHITETTURALE E FLIGHT CONTROLS COMPLETATI CON SUCCESSO! ===")
	get_tree().quit(0)
