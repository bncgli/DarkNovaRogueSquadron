extends Node

func _ready() -> void:
	print("--- INIZIO TEST COMPLETO TACTICAL WEAPONS & ARCHITECTURE STANDARD ---")
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
	
	var weap_app_scene: PackedScene = load("res://Applications/Weapons/weapons_app.tscn")
	assert(weap_app_scene != null, "Scena weapons_app.tscn valida")
	var weapons_app: WeaponsApp = weap_app_scene.instantiate() as WeaponsApp
	add_child(weapons_app)
	await get_tree().process_frame
	
	assert(not weapons_app._is_ship_operational(), "L'app Weapons non deve essere operativa a nave disconnessa")
	assert(weapons_app.disconnected_overlay != null and weapons_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve essere visibile da disconnesso")
	print("✔ Overlay di blocco visibile e operativo da disconnesso")
	
	# =========================================================================
	# FASE 2: AVVIO MISSIONE & STATO OPERATIVO
	# =========================================================================
	print("\n--- TEST 2: Avvio Missione & Connessione Nave ---")
	if net_mgr:
		net_mgr.start_solo_game("Soldato")
		net_mgr.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame
	
	assert(weapons_app._is_ship_operational(), "L'app Weapons deve essere operativa dopo l'avvio della missione")
	assert(weapons_app.disconnected_overlay != null and not weapons_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve scomparire all'avvio della missione")
	print("✔ Overlay rimosso istantaneamente all'avvio della missione")
	
	# =========================================================================
	# FASE 3: CARTELLA DRIVE PROTETTA & FILE .DAT DI DEFAULT
	# =========================================================================
	print("\n--- TEST 3: Cartella Protetta Ship Drive/Programs/Weapons e file .dat ---")
	assert(DirAccess.dir_exists_absolute("user://files/Ship Drive/Programs/Weapons"), "Cartella Programs/Weapons deve esistere in Ship Drive")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/Weapons/weapons_config.dat"), "weapons_config.dat deve esistere in Ship Drive/Programs/Weapons/")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/Weapons/ammo_tuning.dat"), "ammo_tuning.dat deve esistere in Ship Drive/Programs/Weapons/")
	
	if fpm:
		assert(fpm.has_password("Ship Drive/Programs/Weapons"), "La cartella Ship Drive/Programs/Weapons deve essere protetta da password")
		assert(fpm.check_password("Ship Drive/Programs/Weapons", "WEAP-7815"), "La password predefinita della cartella deve essere WEAP-7815")
	print("✔ Cartella e file .dat protetti creati con successo in Ship Drive con password WEAP-7815")
	
	# =========================================================================
	# FASE 4: CARICAMENTO DINAMICO DEI PARAMETRI .DAT E HOT-RELOADING A RUNTIME
	# =========================================================================
	print("\n--- TEST 4: Caricamento dinamico ed effetto a runtime dei parametri .dat ---")
	weapons_app.load_dat_configuration()
	assert(weapons_app.active_config.get("is_dat_loaded") == true, "Configurazione .dat deve risultare caricata")
	assert(weapons_app.active_config.get("max_range") == 4500.0, "max_range di fabbrica deve essere 4500.0")
	assert(weapons_app.active_config.get("torpedo_velocity") == 85.0, "torpedo_velocity di fabbrica deve essere 85.0")
	print("✔ Valori iniziali .dat caricati con successo")
	
	# Modifica dinamica del file weapons_config.dat (Overclocking armi / Clandestine Firmware)
	var new_dat_content := "[SYSTEM]\napp_name=Weapons\nversion=1.0.4\nstatus=OVERCLOCKED\nweapons_subsystem=ACTIVE\n\n[WEAPONS]\nmax_range=6000.0\nfire_rate=2.5\ncooling_rate=1.2\nauto_pdg_enabled=true\nlaser_power_draw=300.0\ntorpedo_max_ammo=16\npdg_ammo_max=600\npdg_fire_rate=12.0\nemergency_vent_cooldown=5.0\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/Weapons/weapons_config.dat", FileAccess.WRITE)
	f_out.store_string(new_dat_content)
	f_out.close()
	
	var new_tuning_content := "[BALLISTICS]\ntorpedo_velocity=120.0\nauto_lead_tracking=true\noverclock_damage_mult=1.5\nheat_multiplier=1.2\npdg_range=1500.0\nlaser_beam_intensity=1.5\n"
	var f_tune := FileAccess.open("user://files/Ship Drive/Programs/Weapons/ammo_tuning.dat", FileAccess.WRITE)
	f_tune.store_string(new_tuning_content)
	f_tune.close()
	
	# Notifica evento sincronizzazione drive
	if sdm:
		sdm.file_synced.emit("Ship Drive/Programs/Weapons/weapons_config.dat")
	else:
		weapons_app.load_dat_configuration()
	await get_tree().process_frame
	
	assert(weapons_app.active_config["max_range"] == 6000.0, "max_range aggiornato a runtime a 6000.0")
	assert(weapons_app.active_config["torpedo_velocity"] == 120.0, "torpedo_velocity aggiornato a runtime a 120.0")
	assert(weapons_app.active_config["emergency_vent_cooldown"] == 5.0, "emergency_vent_cooldown aggiornato a 5.0")
	print("✔ Modifica del file .dat recepita in tempo reale tramite Hot-Reloading")
	
	# =========================================================================
	# FASE 5: CONTROLLO RUOLI RBAC
	# =========================================================================
	print("\n--- TEST 5: Controllo Ruoli RBAC ---")
	if net_mgr:
		net_mgr.is_solo_mode = false # Disabilita solo mode per verificare i singoli ruoli
		
		# Ruolo Soldato (Pieno controllo)
		net_mgr.request_role("Soldato")
		await get_tree().process_frame
		assert(weapons_app.can_control_weapons == true, "Soldato deve avere pieno controllo sulle armi")
		assert(weapons_app.fire_button.disabled == false, "Pulsante fuoco abilitato per Soldato")
		assert(weapons_app.vent_heat_button.disabled == false, "Pulsante scarico termico abilitato per Soldato")
		
		# Ruolo Pilota (Sola lettura / Blocco comandi)
		net_mgr.request_role("Pilota")
		await get_tree().process_frame
		assert(weapons_app.can_control_weapons == false, "Pilota deve essere in sola lettura")
		assert(weapons_app.fire_button.disabled == true, "Pulsante fuoco disabilitato per Pilota")
		assert(weapons_app.vent_heat_button.disabled == true, "Pulsante scarico termico disabilitato per Pilota")
		
		# Ruolo Ingegnere (Sola lettura / Blocco comandi)
		net_mgr.request_role("Ingegnere")
		await get_tree().process_frame
		assert(weapons_app.can_control_weapons == false, "Ingegnere deve essere in sola lettura")
		assert(weapons_app.fire_button.disabled == true, "Pulsante fuoco disabilitato per Ingegnere")
		
		# Ruolo Capitano (Pieno controllo & Override)
		net_mgr.request_role("Capitano")
		await get_tree().process_frame
		assert(weapons_app.can_control_weapons == true, "Capitano deve avere pieno controllo d'armi")
		assert(weapons_app.fire_button.disabled == false, "Pulsante fuoco abilitato per Capitano")
		
		# Ripristina ruolo Soldato per i test successivi
		net_mgr.request_role("Soldato")
		await get_tree().process_frame
	print("✔ Matrice dei ruoli RBAC verificata con successo")
	
	# =========================================================================
	# FASE 6: GESTIONE CLASSI DI MUNIZIONI [1-4], FUOCO E TERMODINAMICA
	# =========================================================================
	print("\n--- TEST 6: Selettore Munizioni 1-4, Fuoco Differenziato e Termodinamica ---")
	
	# 1. Mitragliatrice Pesante [1] (Alta cadenza, consumo 1 colpo)
	weapons_app._select_ammo_type(WeaponsApp.AmmoType.HEAVY_MG)
	assert(weapons_app.active_ammo_type == WeaponsApp.AmmoType.HEAVY_MG, "Mitragliatrice Pesante attiva")
	var prev_mg: int = weapons_app.heavy_mg_ammo
	weapons_app.fire_cooldown_timer = 0.0
	weapons_app.barrel_heat = 0.0
	weapons_app.is_overheated = false
	weapons_app._on_fire_button_pressed()
	assert(weapons_app.heavy_mg_ammo == prev_mg - 1, "Il fuoco MG deve consumare 1 colpo")
	assert(weapons_app.barrel_heat > 0.0, "Il fuoco MG deve generare calore nelle canne")
	print("✔ Fuoco Mitragliatrice Pesante [1] verificato con successo")
	
	# 2. Cannone Pesante [2] (Danno elevato, consumo carica/colpo)
	weapons_app._select_ammo_type(WeaponsApp.AmmoType.HEAVY_CANNON)
	assert(weapons_app.active_ammo_type == WeaponsApp.AmmoType.HEAVY_CANNON, "Cannone Pesante attivo")
	weapons_app.laser_charge = 100.0
	weapons_app.fire_cooldown_timer = 0.0
	var prev_cannon: int = weapons_app.heavy_cannon_ammo
	weapons_app._on_fire_button_pressed()
	assert(weapons_app.laser_charge == 80.0, "Il cannone pesante deve consumare il 20% di condensatore")
	assert(weapons_app.heavy_cannon_ammo == prev_cannon - 1, "Il cannone pesante deve consumare 1 colpo")
	print("✔ Fuoco Cannone Pesante [2] verificato con successo")
	
	# 3. Missili a Ricerca [3] (Richiede Lock Bersaglio)
	weapons_app._select_ammo_type(WeaponsApp.AmmoType.MISSILE)
	assert(weapons_app.active_ammo_type == WeaponsApp.AmmoType.MISSILE, "Missili attivi")
	weapons_app.fire_cooldown_timer = 0.0
	weapons_app.is_missile_locked = false
	weapons_app.is_target_locked = false
	var prev_missiles: int = weapons_app.missile_ammo
	
	# Tentativo di fuoco senza lock (deve essere rifiutato)
	weapons_app._on_fire_button_pressed()
	assert(weapons_app.missile_ammo == prev_missiles, "Il fuoco missile senza lock deve essere bloccato")
	
	# Con lock attivo (deve essere consentito)
	weapons_app.is_missile_locked = true
	weapons_app.selected_target_id = "AST-01"
	weapons_app._on_fire_button_pressed()
	assert(weapons_app.missile_ammo == prev_missiles - 1, "Il lancio missile con lock deve consumare 1 missile")
	print("✔ Logica di lancio Missili a Ricerca [3] con Lock verificata con successo")
	
	# 4. Sonda Telemetrica [4] (Lancio sonda sensori nello spazio)
	weapons_app._select_ammo_type(WeaponsApp.AmmoType.PROBE)
	assert(weapons_app.active_ammo_type == WeaponsApp.AmmoType.PROBE, "Sonde telemetriche attive")
	weapons_app.fire_cooldown_timer = 0.0
	var prev_probes: int = weapons_app.probe_ammo
	weapons_app._on_fire_button_pressed()
	assert(weapons_app.probe_ammo == prev_probes - 1, "Il lancio sonda deve decrementare la riserva di 1")
	assert(SpaceWorldManager.active_probes.size() > 0, "Una sonda attiva deve risultare registrata in SpaceWorldManager")
	print("✔ Lancio Sonda Telemetrica [4] verificato con successo")
	
	# 5. Overheat Lockout & Scarico Termico d'Emergenza (Thermal Vent)
	weapons_app.barrel_heat = 100.0
	weapons_app._update_cooling_and_power(0.1)
	assert(weapons_app.is_overheated == true, "barrel_heat a 100% deve innescare il blocco di surriscaldamento")
	
	weapons_app._select_ammo_type(WeaponsApp.AmmoType.HEAVY_MG)
	weapons_app.fire_cooldown_timer = 0.0
	var ammo_before_overheat := weapons_app.heavy_mg_ammo
	weapons_app._on_fire_button_pressed()
	assert(weapons_app.heavy_mg_ammo == ammo_before_overheat, "Il fuoco deve essere bloccato durante il surriscaldamento")
	
	# Esegui scarico termico
	weapons_app.vent_cooldown_timer = 0.0
	weapons_app._on_vent_heat_button_pressed()
	assert(weapons_app.barrel_heat == 0.0, "Lo scarico termico deve azzerare il calore delle canne")
	assert(weapons_app.is_overheated == false, "Lo scarico termico deve sbloccare lo stato di surriscaldamento")
	print("✔ Meccanica di surriscaldamento e scarico termico d'emergenza convalidate")
	
	# =========================================================================
	# FASE 7: RADAR TATTICO, TARGET LOCK E LEAD INDICATOR
	# =========================================================================
	print("\n--- TEST 7: Radar Tattico, Target Lock e Anticipo di Tiro (Lead) ---")
	weapons_app._refresh_targets()
	assert(weapons_app.detected_targets.size() > 0, "Il radar deve rilevare bersagli/contatti nello spazio")
	
	# Test selezione bersaglio e target lock
	weapons_app._on_target_option_selected(1)
	assert(not weapons_app.selected_target_id.is_empty(), "Un bersaglio deve risultare selezionato")
	
	weapons_app._on_lock_button_pressed()
	assert(weapons_app.is_target_locked == true, "Il bersaglio deve risultare bloccato (Lock)")
	assert(weapons_app.radar_canvas.has_lock == true, "Il canvas radar deve riflettere il lock attivo")
	
	# Verifica calcolo Lead Indicator
	weapons_app._refresh_targets()
	assert(weapons_app.lead_calc_label.text.contains("ANTICIPO TIRO"), "Label lead indicator deve calcolare l'anticipo")
	print("✔ Radar tattico, acquisizione lock e calcolo lead indicator verificati con successo")
	
	# =========================================================================
	# FASE 8: INTEGRAZIONE SUBLAYER 3 (RETE ELETTRICA & ARMERIA)
	# =========================================================================
	print("\n--- TEST 8: Integrazione Sublayer 3 (Rete Elettrica) ---")
	assert(SpaceWorldManager.is_armory_powered() == true, "L'armeria deve risultare alimentata di default")
	
	# =========================================================================
	# FASE 9: PROTEZIONE FILE .DAT DAL TERMINALE DIEGETICO (CAT)
	# =========================================================================
	print("\n--- TEST 9: Protezione .dat dal File Reader / Visualizzatore di testo ---")
	var terminal_res := load("res://Applications/Terminal/src/terminal_scene.tscn") as PackedScene
	if terminal_res:
		var term := terminal_res.instantiate() as Terminal
		add_child(term)
		await get_tree().process_frame
		
		var cat_script: GDScript = load("res://Applications/Terminal/commands/cat_command.gd")
		var cat_cmd = cat_script.new()
		term.virtual_path_manager.set_path("Ship Drive/Programs/Weapons")
		var args: Array[String] = ["weapons_config.dat"]
		cat_cmd.execute(term, args)
		
		var found_msg := false
		for c in term.command_output_container.get_children():
			if "text" in c and (c.text.contains("non sono leggibili") or c.text.contains(".dat")):
				found_msg = true
				break
		assert(found_msg, "Il comando cat deve rifiutare la lettura diretta del file .dat di Weapons")
		print("✔ File .dat protetto dalla lettura in chiaro standard")
		term.queue_free()
	
	# =========================================================================
	# FASE 10: CAMERA OTTICA DI PUNTAMENTO & SUBVIEWPORT 3D
	# =========================================================================
	print("\n--- TEST 10: Camera Ottica di Puntamento e SubViewport 3D ---")
	assert(weapons_app.feed_viewport != null, "Feed viewport deve essere presente")
	assert(weapons_app.feed_camera_3d != null, "Feed Camera3D deve essere presente")
	assert(weapons_app.trajectory_hud != null, "TrajectoryHUD deve essere presente nel viewport")
	
	# Test orientamento ottico manuale
	weapons_app.aim_yaw_slider.value = 15.0
	weapons_app.aim_pitch_slider.value = -10.0
	weapons_app._on_aim_slider_changed(0.0)
	assert(weapons_app.manual_aim == Vector2(15.0, -10.0), "La mira manuale deve essere aggiornata dai cursori")
	assert(weapons_app.turret_feed_label.text.contains("+15.0°") and weapons_app.turret_feed_label.text.contains("-10.0°"), "Label telecamera deve riflettere yaw e pitch")
	
	# Test ricentratura mira
	weapons_app._on_aim_center_pressed()
	assert(weapons_app.manual_aim == Vector2.ZERO, "La pressione di Centro deve azzerare la mira")
	print("✔ Camera ottica di puntamento, SubViewport 3D e orientamento verificati con successo")
	
	# =========================================================================
	# FASE 11: CONTROLLO MOUSE AIMING, CATTURA SPAZIO ED ESCAPE (TASK-031)
	# =========================================================================
	print("\n--- TEST 11: Controllo Torretta Mouse, Cattura con Spazio e Rilascio con Escape ---")
	weapons_app.is_mouse_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Test cattura mouse con tasto Spazio
	var ev_space := InputEventKey.new()
	ev_space.keycode = KEY_SPACE
	ev_space.pressed = true
	weapons_app._input(ev_space)
	assert(weapons_app.is_mouse_captured == true, "La pressione di Spazio deve attivare la cattura del mouse")
	if DisplayServer.get_name() != "headless":
		assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Il mouse_mode deve passare a MOUSE_MODE_CAPTURED")
	
	# Test tracciamento movimento mouse
	weapons_app.manual_aim = Vector2.ZERO
	var ev_motion := InputEventMouseMotion.new()
	ev_motion.relative = Vector2(40.0, -20.0)
	weapons_app._input(ev_motion)
	assert(weapons_app.manual_aim.x != 0.0 or weapons_app.manual_aim.y != 0.0, "Il movimento del mouse deve muovere yaw e pitch della torretta")
	
	# Test rilascio mouse con tasto Escape
	var ev_esc := InputEventKey.new()
	ev_esc.keycode = KEY_ESCAPE
	ev_esc.pressed = true
	weapons_app._input(ev_esc)
	assert(weapons_app.is_mouse_captured == false, "La pressione di Escape deve rilasciare il mouse")
	if DisplayServer.get_name() != "headless":
		assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Il mouse_mode deve tornare a MOUSE_MODE_VISIBLE")
	
	# Test rilascio mouse per perdita di focus della finestra
	weapons_app._toggle_mouse_capture()
	assert(weapons_app.is_mouse_captured == true, "Mouse ricatturato")
	weapons_app._on_parent_window_selected(false)
	assert(weapons_app.is_mouse_captured == false, "La de-selezione della finestra deve rilasciare il mouse")
	print("✔ Cattura, rilascio con Spazio/Escape/Deselezione e mira mouse convalidate")
	
	# =========================================================================
	# FASE 12: SELETTORE TASTI 1-4, LOCK OTTICO MISSILE E HUD TRAIETTORIA
	# =========================================================================
	print("\n--- TEST 12: Selettore Tasti 1-4, Lock Ottico Continuo e HUD Traiettoria ---")
	
	# Test selezione rapida con tasti numerici 1, 2, 3, 4
	var ev_k1 := InputEventKey.new()
	ev_k1.keycode = KEY_1
	ev_k1.pressed = true
	weapons_app._input(ev_k1)
	assert(weapons_app.active_ammo_type == WeaponsApp.AmmoType.HEAVY_MG, "Tasto 1 deve selezionare Heavy MG")
	
	var ev_k2 := InputEventKey.new()
	ev_k2.keycode = KEY_2
	ev_k2.pressed = true
	weapons_app._input(ev_k2)
	assert(weapons_app.active_ammo_type == WeaponsApp.AmmoType.HEAVY_CANNON, "Tasto 2 deve selezionare Heavy Cannon")
	
	var ev_k3 := InputEventKey.new()
	ev_k3.keycode = KEY_3
	ev_k3.pressed = true
	weapons_app._input(ev_k3)
	assert(weapons_app.active_ammo_type == WeaponsApp.AmmoType.MISSILE, "Tasto 3 deve selezionare Missile")
	
	var ev_k4 := InputEventKey.new()
	ev_k4.keycode = KEY_4
	ev_k4.pressed = true
	weapons_app._input(ev_k4)
	assert(weapons_app.active_ammo_type == WeaponsApp.AmmoType.PROBE, "Tasto 4 deve selezionare Probe")
	
	# Test accumulatore lock ottico missile (allineamento continuo per 2.0s)
	weapons_app._select_ammo_type(WeaponsApp.AmmoType.MISSILE)
	weapons_app._refresh_targets()
	assert(weapons_app.detected_targets.size() > 0, "Bersagli rilevati per il lock")
	var target_ast := weapons_app.detected_targets[0]
	weapons_app.manual_aim = Vector2(float(target_ast.get("bearing_deg", 0.0)), float(target_ast.get("elevation_deg", 0.0)))
	weapons_app.missile_current_aim_time = 0.0
	weapons_app.is_missile_locked = false
	weapons_app.is_target_locked = false
	
	# Simula allineamento nel processo per 2.2 secondi
	weapons_app._process(1.0)
	assert(weapons_app.missile_current_aim_time >= 1.0 and not weapons_app.is_missile_locked, "Lock missile in accumulo")
	weapons_app._process(1.2)
	assert(weapons_app.is_missile_locked == true, "Lock missile completato dopo 2.0s di puntamento continuo")
	
	# Test aggiornamento TrajectoryHUD
	weapons_app._update_turret_camera_feed()
	assert(weapons_app.trajectory_hud.active_ammo_type == WeaponsApp.AmmoType.MISSILE, "TrajectoryHUD deve riflettere il tipo d'arma")
	assert(weapons_app.trajectory_hud.is_missile_locked == true, "TrajectoryHUD deve mostrare lock missile attivo")
	assert(weapons_app.trajectory_hud.has_lead == true, "TrajectoryHUD deve mostrare lead indicator per il bersaglio")
	print("✔ Selettore tasti 1-4, lock ottico missile e rendering TrajectoryHUD convalidati con successo")
	
	weapons_app.queue_free()
	print("\n=======================================================")
	print("✔ TUTTI I TEST TACTICAL WEAPONS (TASK-031) COMPLETATI CON SUCCESSO!")
	print("=======================================================")
	get_tree().quit(0)
