extends Node

func _ready() -> void:
	print("--- INIZIO TEST COMPLETO SHIELD MATRIX & ARCHITECTURE STANDARD ---")
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
	
	var shld_app_scene: PackedScene = load("res://Applications/ShieldMatrix/shield_matrix_app.tscn")
	assert(shld_app_scene != null, "Scena shield_matrix_app.tscn valida")
	var shield_app: ShieldMatrixApp = shld_app_scene.instantiate() as ShieldMatrixApp
	add_child(shield_app)
	await get_tree().process_frame
	
	assert(not shield_app._is_ship_operational(), "L'app ShieldMatrix non deve essere operativa a nave disconnessa")
	assert(shield_app.disconnected_overlay != null and shield_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve essere visibile da disconnesso")
	print("✔ Overlay di blocco visibile e operativo da disconnesso")
	
	# =========================================================================
	# FASE 2: AVVIO MISSIONE & STATO OPERATIVO
	# =========================================================================
	print("\n--- TEST 2: Avvio Missione & Connessione Nave ---")
	if net_mgr:
		net_mgr.start_solo_game("Ingegnere")
		net_mgr.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame
	
	assert(shield_app._is_ship_operational(), "L'app ShieldMatrix deve essere operativa dopo l'avvio della missione")
	assert(shield_app.disconnected_overlay != null and not shield_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve scomparire all'avvio della missione")
	print("✔ Overlay rimosso istantaneamente all'avvio della missione")
	
	# =========================================================================
	# FASE 3: CARTELLA DRIVE PROTETTA & FILE .DAT DI DEFAULT
	# =========================================================================
	print("\n--- TEST 3: Cartella Protetta Ship Drive/Programs/ShieldMatrix e file .dat ---")
	assert(DirAccess.dir_exists_absolute("user://files/Ship Drive/Programs/ShieldMatrix"), "Cartella Programs/ShieldMatrix deve esistere in Ship Drive")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/ShieldMatrix/shields_config.dat"), "shields_config.dat deve esistere in Ship Drive/Programs/ShieldMatrix/")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/ShieldMatrix/deflector_tuning.dat"), "deflector_tuning.dat deve esistere in Ship Drive/Programs/ShieldMatrix/")
	
	if fpm:
		assert(fpm.has_password("Ship Drive/Programs/ShieldMatrix"), "La cartella Ship Drive/Programs/ShieldMatrix deve essere protetta da password")
		assert(fpm.check_password("Ship Drive/Programs/ShieldMatrix", "SHLD-7815"), "La password predefinita della cartella deve essere SHLD-7815")
	print("✔ Cartella e file .dat protetti creati con successo in Ship Drive con password SHLD-7815")
	
	# =========================================================================
	# FASE 4: CARICAMENTO DINAMICO DEI PARAMETRI .DAT E HOT-RELOADING A RUNTIME
	# =========================================================================
	print("\n--- TEST 4: Caricamento dinamico ed effetto a runtime dei parametri .dat ---")
	shield_app.load_dat_configuration()
	assert(shield_app.active_config.get("is_dat_loaded") == true, "Configurazione .dat deve risultare caricata")
	assert(shield_app.active_config.get("max_capacity_per_quadrant") == 250.0, "max_capacity_per_quadrant di fabbrica deve essere 250.0")
	assert(shield_app.active_config.get("harmonic_frequency") == 440.0, "harmonic_frequency di fabbrica deve essere 440.0")
	print("✔ Valori iniziali .dat caricati con successo")
	
	# Modifica dinamica del file shields_config.dat e deflector_tuning.dat
	var new_dat_content := "[SYSTEM]\napp_name=ShieldMatrix\nversion=1.0.4\nstatus=OVERCLOCKED\nshield_subsystem=ACTIVE\n\n[SHIELD_SETTINGS]\nmax_capacity_per_quadrant=350.0\nrecharge_rate_per_sec=25.0\noverload_limit=1.5\nbase_power_draw_mw=110.0\nemergency_boost_power_mw=150.0\nemergency_boost_amount=100.0\nemergency_boost_cooldown=5.0\ndecay_rate_unpowered=20.0\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/ShieldMatrix/shields_config.dat", FileAccess.WRITE)
	f_out.store_string(new_dat_content)
	f_out.close()
	
	var new_tuning_content := "[HARMONICS]\nharmonic_frequency=528.0\nemergency_boost_multiplier=3.0\noverclock_absorption=1.5\nphase_sync_stability=0.99\ndispersion_damping=0.92\n"
	var f_tune := FileAccess.open("user://files/Ship Drive/Programs/ShieldMatrix/deflector_tuning.dat", FileAccess.WRITE)
	f_tune.store_string(new_tuning_content)
	f_tune.close()
	
	# Notifica evento sincronizzazione drive
	if sdm:
		sdm.file_synced.emit("Ship Drive/Programs/ShieldMatrix/shields_config.dat")
	else:
		shield_app.load_dat_configuration()
	await get_tree().process_frame
	
	assert(shield_app.active_config["max_capacity_per_quadrant"] == 350.0, "max_capacity_per_quadrant aggiornato a runtime a 350.0")
	assert(shield_app.active_config["harmonic_frequency"] == 528.0, "harmonic_frequency aggiornato a runtime a 528.0")
	assert(shield_app.active_config["emergency_boost_cooldown"] == 5.0, "emergency_boost_cooldown aggiornato a 5.0")
	print("✔ Modifica del file .dat recepita in tempo reale tramite Hot-Reloading")
	
	# =========================================================================
	# FASE 5: CONTROLLO RUOLI RBAC
	# =========================================================================
	print("\n--- TEST 5: Controllo Ruoli RBAC ---")
	if net_mgr:
		net_mgr.is_solo_mode = false # Disabilita solo mode per verificare i singoli ruoli
		
		# Ruolo Ingegnere (Pieno controllo)
		net_mgr.request_role("Ingegnere")
		await get_tree().process_frame
		assert(shield_app.can_control_shields == true, "Ingegnere deve avere pieno controllo sugli scudi")
		assert(shield_app.emergency_boost_button.disabled == false, "Pulsante ricarica rapida abilitato per Ingegnere")
		assert(shield_app.reset_balance_button.disabled == false, "Pulsante reset bilanciamento abilitato per Ingegnere")
		assert(shield_app.phase_sync_switch.disabled == false, "Interruttore armoniche abilitato per Ingegnere")
		
		# Ruolo Capitano (Pieno controllo & Override)
		net_mgr.request_role("Capitano")
		await get_tree().process_frame
		assert(shield_app.can_control_shields == true, "Capitano deve avere pieno controllo sugli scudi")
		assert(shield_app.emergency_boost_button.disabled == false, "Pulsante ricarica rapida abilitato per Capitano")
		
		# Ruolo Pilota (Sola lettura / Blocco comandi)
		net_mgr.request_role("Pilota")
		await get_tree().process_frame
		assert(shield_app.can_control_shields == false, "Pilota deve essere in sola lettura")
		assert(shield_app.emergency_boost_button.disabled == true, "Pulsante ricarica rapida disabilitato per Pilota")
		assert(shield_app.reset_balance_button.disabled == true, "Pulsante reset bilanciamento disabilitato per Pilota")
		assert(shield_app.phase_sync_switch.disabled == true, "Interruttore armoniche disabilitato per Pilota")
		
		# Ruolo Soldato (Sola lettura / Blocco comandi)
		net_mgr.request_role("Soldato")
		await get_tree().process_frame
		assert(shield_app.can_control_shields == false, "Soldato deve essere in sola lettura")
		assert(shield_app.emergency_boost_button.disabled == true, "Pulsante ricarica rapida disabilitato per Soldato")
		
		# Ruolo Hacker (Sola lettura / Blocco comandi)
		net_mgr.request_role("Hacker")
		await get_tree().process_frame
		assert(shield_app.can_control_shields == false, "Hacker deve essere in sola lettura")
		assert(shield_app.emergency_boost_button.disabled == true, "Pulsante ricarica rapida disabilitato per Hacker")
		
		# Ripristina ruolo Ingegnere per i test successivi
		net_mgr.request_role("Ingegnere")
		await get_tree().process_frame
	print("✔ Matrice dei ruoli RBAC verificata con successo")
	
	# =========================================================================
	# FASE 6: BILANCIAMENTO 4 QUADRANTI & VECTOR PAD
	# =========================================================================
	print("\n--- TEST 6: Bilanciamento 4 Quadranti & Vector Pad ---")
	
	# 1. Bilanciamento iniziale simmetrico (25% per quadrante)
	shield_app._on_reset_balance_pressed()
	assert(is_equal_approx(shield_app.ratio_fore, 0.25), "Ratio Prua iniziale deve essere 0.25")
	assert(is_equal_approx(shield_app.ratio_aft, 0.25), "Ratio Poppa iniziale deve essere 0.25")
	assert(is_equal_approx(shield_app.ratio_port, 0.25), "Ratio Babordo iniziale deve essere 0.25")
	assert(is_equal_approx(shield_app.ratio_starboard, 0.25), "Ratio Tribordo iniziale deve essere 0.25")
	
	# 2. Modifica ratio slider Prua a 50%
	shield_app._on_slider_ratio_changed(ShieldMatrixApp.Quadrant.FORE, 50.0)
	assert(is_equal_approx(shield_app.ratio_fore, 0.50), "Ratio Prua deve essere 0.50")
	var sum_ratios := shield_app.ratio_fore + shield_app.ratio_aft + shield_app.ratio_port + shield_app.ratio_starboard
	assert(is_equal_approx(sum_ratios, 1.0), "La somma dei ratio deve rimanere 1.0 (100%)")
	
	# 3. Orientamento tramite Vector Pad (Spinta in avanti/Prua)
	shield_app._apply_vector_bias(Vector2(0, -1.0))
	assert(shield_app.ratio_fore > shield_app.ratio_aft, "Ratio Prua deve prevalere su Poppa quando il vector pad punta in avanti")
	
	# 4. Reset bilanciamento
	shield_app._on_reset_balance_pressed()
	assert(is_equal_approx(shield_app.ratio_fore, 0.25), "Reset bilanciamento ripristina Prua a 0.25")
	print("✔ Bilanciamento dinamico quadranti e vector pad validati con successo")
	
	# =========================================================================
	# FASE 7: RICARICA RAPIDA D'EMERGENZA & COOLDOWN
	# =========================================================================
	print("\n--- TEST 7: Ricarica Rapida d'Emergenza & Cooldown ---")
	shield_app.shield_fore = 50.0
	shield_app.shield_aft = 50.0
	shield_app.shield_port = 50.0
	shield_app.shield_starboard = 50.0
	shield_app.boost_cooldown_timer = 0.0
	
	shield_app._on_emergency_boost_pressed()
	assert(shield_app.shield_fore > 50.0, "Ricarica rapida deve incrementare il livello scudi di Prua")
	assert(shield_app.boost_cooldown_timer > 0.0, "Ricarica rapida deve attivare il timer di cooldown")
	assert(shield_app.emergency_boost_button.disabled == true, "Pulsante ricarica rapida deve essere disabilitato durante il cooldown")
	print("✔ Meccanica di boost d'emergenza e cooldown convalidata")
	
	# =========================================================================
	# FASE 8: ARMONICHE DI DEFLESSIONE (PHASE SYNC)
	# =========================================================================
	print("\n--- TEST 8: Armoniche di Deflessione (Phase Sync) ---")
	shield_app._on_phase_sync_toggled(false)
	assert(shield_app.is_phase_synced == false, "Armoniche devono risultare disattivate")
	assert(shield_app.phase_status_label.text.contains("DISATTIVE"), "Label di stato deve riflettere la disattivazione")
	
	shield_app._on_phase_sync_toggled(true)
	assert(shield_app.is_phase_synced == true, "Armoniche devono risultare sincronizzate")
	assert(shield_app.phase_status_label.text.contains("SINCRONIZZATE"), "Label di stato deve riflettere la sincronizzazione")
	print("✔ Sincronizzazione armoniche di deflessione verificata con successo")
	
	# =========================================================================
	# FASE 9: PROTEZIONE FILE .DAT DAL TERMINALE DIEGETICO (CAT)
	# =========================================================================
	print("\n--- TEST 9: Protezione .dat dal File Reader / Visualizzatore di testo ---")
	var terminal_res := load("res://Applications/Terminal/src/terminal_scene.tscn") as PackedScene
	if terminal_res:
		var term := terminal_res.instantiate() as Terminal
		add_child(term)
		await get_tree().process_frame
		
		var cat_cmd = load("res://Applications/Terminal/commands/cat_command.gd").new()
		term.virtual_path_manager.set_path("Ship Drive/Programs/ShieldMatrix")
		var args: Array[String] = ["shields_config.dat"]
		cat_cmd.execute(term, args)
		
		var found_msg := false
		for c in term.command_output_container.get_children():
			if "text" in c and (c.text.contains("non sono leggibili") or c.text.contains(".dat")):
				found_msg = true
				break
		assert(found_msg == true, "Il comando cat deve rifiutare la lettura diretta del file shields_config.dat")
		term.queue_free()
	print("✔ File .dat protetto dalla lettura in chiaro standard")
	
	# Pulizia
	shield_app.queue_free()
	await get_tree().process_frame
	
	print("\n=======================================================")
	print("✔ TUTTI I TEST SHIELD MATRIX COMPLETATI CON SUCCESSO!")
	print("=======================================================")
	get_tree().quit(0)
