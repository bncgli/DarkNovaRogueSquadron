extends Node

func _ready() -> void:
	print("--- INIZIO TEST COMPLETO CAMS & ARCHITECTURE STANDARD ---")
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
	
	var cams_app_scene: PackedScene = load("res://Applications/Cams/cams_app.tscn")
	assert(cams_app_scene != null, "Scena cams_app.tscn valida")
	var cams_app: CamsApp = cams_app_scene.instantiate() as CamsApp
	add_child(cams_app)
	await get_tree().process_frame
	
	assert(not cams_app.is_operational(), "L'app Cams non deve essere operativa quando la nave è disconnessa")
	assert(cams_app.disconnected_overlay != null and cams_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve essere visibile da disconnesso")
	assert(not SpaceWorldManager.open_camera_window("front"), "Non deve essere possibile aprire feed telecamera da disconnesso")
	print("✔ Overlay di blocco visibile e operativo da disconnesso")
	
	# =========================================================================
	# FASE 2: AVVIO MISSIONE & STATO OPERATIVO
	# =========================================================================
	print("\n--- TEST 2: Avvio Missione & Connessione Nave ---")
	if NetworkManager:
		NetworkManager.start_solo_game("Ufficiale Tattico")
		NetworkManager.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame
	
	assert(cams_app.is_operational(), "L'app Cams deve essere operativa dopo l'avvio della missione")
	assert(cams_app.disconnected_overlay != null and not cams_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve scomparire dopo l'avvio della missione")
	print("✔ Overlay rimosso istantaneamente all'avvio della missione")
	
	# =========================================================================
	# FASE 3: VERIFICA CARTELLA DRIVE PROTETTA & FILE .DAT DI DEFAULT
	# =========================================================================
	print("\n--- TEST 3: Cartella Protetta Ship Drive/Programs/Cams e file .dat ---")
	assert(DirAccess.dir_exists_absolute("user://files/Ship Drive/Programs/Cams"), "Cartella Programs/Cams deve esistere in Ship Drive")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/Cams/cams_config.dat"), "cams_config.dat deve esistere in Ship Drive/Programs/Cams/")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/Cams/optics_tuning.dat"), "optics_tuning.dat deve esistere in Ship Drive/Programs/Cams/")
	
	if fpm:
		assert(fpm.has_password("Ship Drive/Programs/Cams"), "La cartella Ship Drive/Programs/Cams deve essere protetta da password")
		assert(fpm.check_password("Ship Drive/Programs/Cams", "CAMS-7815"), "La password predefinita della cartella deve essere CAMS-7815")
	print("✔ Cartella e file .dat protetti creati con successo in Ship Drive")
	
	# =========================================================================
	# FASE 4: CARICAMENTO DINAMICO DEI PARAMETRI .DAT E APPLICAZIONE A RUNTIME
	# =========================================================================
	print("\n--- TEST 4: Caricamento dinamico ed effetto a runtime dei parametri .dat ---")
	var initial_cfg := cams_app.load_dat_configuration()
	assert(initial_cfg.get("is_dat_loaded") == true, "Configurazione .dat deve risultare caricata")
	assert(initial_cfg.get("default_fov") == 75.0, "FOV di fabbrica deve essere 75.0")
	assert(initial_cfg.get("zoom_step") == 10.0, "Zoom step di fabbrica deve essere 10.0")
	print("✔ Valori iniziali .dat caricati con successo")
	
	# Apri finestra feed frontale per verificare sincronizzazione con le finestre
	var feed_win := SpaceWorldManager.open_camera_window("front")
	assert(feed_win != null, "Finestra feed deve aprirsi correttamente")
	assert(feed_win.default_fov == 75.0, "Finestra feed riceve default_fov da active_config")
	assert(feed_win.zoom_step == 10.0, "Finestra feed riceve zoom_step da active_config")
	
	# Modifica dinamica del file cams_config.dat (Tuning / Overclocking sensori)
	var new_dat_content := "[SYSTEM]\napp_name=Cams\nversion=1.0.4\nstatus=OVERCLOCKED\nsensor_array=CCTV_6CH\n\n[OPTICS]\ndefault_fov=60.0\nmin_fov=20.0\nmax_fov=120.0\nzoom_step=15.0\nnight_vision_intensity=0.35\ntactical_hud_contrast=0.30\nthermal_intensity=0.40\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/Cams/cams_config.dat", FileAccess.WRITE)
	f_out.store_string(new_dat_content)
	f_out.close()
	
	var new_tuning_content := "[SENSORS]\nsignal_boost=1.5\nnoise_reduction=2.0\nrefresh_rate_hz=90.0\ncrosshair_style=ADVANCED\noverclock_gain=1.5\n"
	var f_tune := FileAccess.open("user://files/Ship Drive/Programs/Cams/optics_tuning.dat", FileAccess.WRITE)
	f_tune.store_string(new_tuning_content)
	f_tune.close()
	
	# Notifica sincronizzazione/modifica
	if sdm:
		sdm.file_synced.emit("Ship Drive/Programs/Cams/cams_config.dat")
	else:
		cams_app.load_dat_configuration()
	await get_tree().process_frame
	
	assert(cams_app.active_config["default_fov"] == 60.0, "default_fov aggiornato a runtime a 60.0")
	assert(cams_app.active_config["zoom_step"] == 15.0, "zoom_step aggiornato a runtime a 15.0")
	assert(cams_app.active_config["signal_boost"] == 1.5, "signal_boost aggiornato a runtime a 1.5")
	assert(feed_win.zoom_step == 15.0, "Finestra feed aggiornata in tempo reale con zoom_step=15.0")
	assert(feed_win.signal_boost == 1.5, "Finestra feed aggiornata in tempo reale con signal_boost=1.5")
	print("✔ Modifica del file .dat recepita in tempo reale e applicata ai feed telecamera")
	
	# Test zoom in con nuovo step
	var prev_fov: float = feed_win.current_fov
	feed_win._on_zoom_in_pressed()
	assert(feed_win.current_fov == prev_fov - 15.0, "Zoom in riduce FOV del nuovo step di 15.0")
	
	# =========================================================================
	# FASE 5: RBAC - CONTROLLO RUOLI
	# =========================================================================
	print("\n--- TEST 5: Controllo Ruoli RBAC ---")
	NetworkManager.request_role("Tattico")
	await get_tree().process_frame
	assert(cams_app.can_control_cams == true, "Ufficiale Tattico ha accesso ai controlli telecamere")
	assert(cams_app.open_all_button.disabled == false, "Pulsanti abilitati per il Tattico")
	print("✔ Ruolo Tattico verificato con successo")
	
	# =========================================================================
	# FASE 6: 6 TELECAMERE, TOGGLE E AZIONI GLOBALI
	# =========================================================================
	print("\n--- TEST 6: Verifica 6 Telecamere, Toggle, Open All e Close All ---")
	var cam_ids := ["front", "rear", "left", "right", "top", "bottom"]
	for cid in cam_ids:
		var btn: Button = cams_app.cam_buttons.get(cid)
		assert(btn != null, "Pulsante per '%s' deve esistere nel pannello" % cid)
		
		# Toggle ON
		btn.button_pressed = true
		assert(SpaceWorldManager.is_camera_window_open(cid), "Finestra '%s' deve risultare aperta" % cid)
		
		# Toggle OFF
		btn.button_pressed = false
		assert(not SpaceWorldManager.is_camera_window_open(cid), "Finestra '%s' deve risultare chiusa" % cid)
	
	# Test Open All (6 feed aperti simultaneamente)
	cams_app._on_open_all_pressed()
	for cid in cam_ids:
		assert(SpaceWorldManager.is_camera_window_open(cid), "Tutte le 6 finestre devono essere aperte")
	assert(cams_app.active_count_badge.text.contains("6 / 6 ATTIVI"), "Badge indica 6 / 6 attivi")
	print("✔ Open All apre con successo tutti i 6 feed simultaneamente")
	
	# Test Reset Ottiche
	cams_app._on_reset_optics_pressed()
	for cid in cam_ids:
		var w := SpaceWorldManager.get_camera_window(cid)
		assert(w != null and w.current_fov == 60.0, "Reset ottiche reimposta FOV al valore configurato in .dat")
	print("✔ Reset ottiche applicato su tutte le finestre aperte")
	
	# Test Close All
	cams_app._on_close_all_pressed()
	for cid in cam_ids:
		assert(not SpaceWorldManager.is_camera_window_open(cid), "Tutte le 6 finestre devono essere chiuse")
	assert(cams_app.active_count_badge.text.contains("0 / 6 ATTIVI"), "Badge indica 0 / 6 attivi")
	print("✔ Close All chiude con successo tutti i feed")
	
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
		term.virtual_path_manager.set_path("Ship Drive/Programs/Cams")
		var args: Array[String] = ["cams_config.dat"]
		cat_cmd.execute(term, args)
		
		var found_msg := false
		for c in term.command_output_container.get_children():
			if "text" in c and (c.text.contains("non sono leggibili") or c.text.contains(".dat")):
				found_msg = true
				break
		assert(found_msg, "Il comando cat deve rifiutare la lettura diretta del file .dat di Cams")
		print("✔ File .dat protetto dalla visualizzazione di testo standard")
		term.queue_free()
	
	cams_app.queue_free()
	print("\n=== TUTTI I TEST DELLO STANDARD ARCHITETTURALE E CAMS COMPLETATI CON SUCCESSO! ===")
	get_tree().quit(0)
