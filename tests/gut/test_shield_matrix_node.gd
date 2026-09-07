extends GutTest

## Test GUT per l'applicazione ShieldMatrix (bilanciamento scudi a 4 quadranti,
## ricarica rapida d'emergenza, armoniche di deflessione e dispositivi
## point-defense Gatling/Flack con vincolo direzionale monosettore).
## Migrato da tests/test_shield_matrix_node.gd (extends Node, assert() nudo).

var _app: ShieldMatrixApp = null

func before_each() -> void:
	NetworkManager.disconnect_game()
	if SpaceWorldManager:
		SpaceWorldManager.clear_incoming_projectiles()

func after_each() -> void:
	if is_instance_valid(_app):
		_app.queue_free()
	_app = null
	NetworkManager.disconnect_game()
	if SpaceWorldManager:
		SpaceWorldManager.clear_incoming_projectiles()

func _start_solo_mission(player_name: String = "Comandante Test") -> void:
	NetworkManager.start_solo_game(player_name)
	NetworkManager.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame

func _create_app() -> ShieldMatrixApp:
	var scene: PackedScene = load("res://Applications/ShieldMatrix/shield_matrix_app.tscn")
	assert_not_null(scene, "Scena shield_matrix_app.tscn deve essere caricabile")
	var app: ShieldMatrixApp = scene.instantiate() as ShieldMatrixApp
	add_child_autofree(app)
	await get_tree().process_frame
	return app

func test_disconnected_overlay_and_operational_state() -> void:
	_app = await _create_app()
	assert_false(_app._is_ship_operational(), "L'app ShieldMatrix non deve essere operativa a nave disconnessa")
	assert_not_null(_app.disconnected_overlay, "L'overlay DisconnectedOverlay deve esistere")
	assert_true(_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve essere visibile da disconnesso")
	
	await _start_solo_mission()
	
	assert_true(_app._is_ship_operational(), "L'app ShieldMatrix deve essere operativa dopo l'avvio della missione")
	assert_false(_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve scomparire all'avvio della missione")

func test_ship_drive_folder_is_protected_by_default_password() -> void:
	await _start_solo_mission()
	assert_true(DirAccess.dir_exists_absolute("user://files/Ship Drive/Programs/ShieldMatrix"), "Cartella Programs/ShieldMatrix deve esistere in Ship Drive")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/ShieldMatrix/shields_config.dat"), "shields_config.dat deve esistere in Ship Drive/Programs/ShieldMatrix/")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/ShieldMatrix/deflector_tuning.dat"), "deflector_tuning.dat deve esistere in Ship Drive/Programs/ShieldMatrix/")
	
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	assert_not_null(fpm, "FolderPasswordManager deve essere disponibile come autoload")
	assert_true(fpm.has_password("Ship Drive/Programs/ShieldMatrix"), "La cartella Ship Drive/Programs/ShieldMatrix deve essere protetta da password")
	assert_true(fpm.check_password("Ship Drive/Programs/ShieldMatrix", "SHLD-7815"), "La password predefinita della cartella deve essere SHLD-7815")

func test_dat_configuration_default_values_and_runtime_hot_reload() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app.load_dat_configuration()
	assert_true(_app.active_config.get("is_dat_loaded"), "Configurazione .dat deve risultare caricata")
	assert_eq(_app.active_config.get("max_capacity_per_quadrant"), 250.0, "max_capacity_per_quadrant di fabbrica deve essere 250.0")
	assert_eq(_app.active_config.get("harmonic_frequency"), 440.0, "harmonic_frequency di fabbrica deve essere 440.0")
	
	var new_dat_content := "[SYSTEM]\napp_name=ShieldMatrix\nversion=1.0.4\nstatus=OVERCLOCKED\nshield_subsystem=ACTIVE\n\n[SHIELD_SETTINGS]\nmax_capacity_per_quadrant=350.0\nrecharge_rate_per_sec=25.0\noverload_limit=1.5\nbase_power_draw_mw=110.0\nemergency_boost_power_mw=150.0\nemergency_boost_amount=100.0\nemergency_boost_cooldown=5.0\ndecay_rate_unpowered=20.0\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/ShieldMatrix/shields_config.dat", FileAccess.WRITE)
	f_out.store_string(new_dat_content)
	f_out.close()
	
	var new_tuning_content := "[HARMONICS]\nharmonic_frequency=528.0\nemergency_boost_multiplier=3.0\noverclock_absorption=1.5\nphase_sync_stability=0.99\ndispersion_damping=0.92\n"
	var f_tune := FileAccess.open("user://files/Ship Drive/Programs/ShieldMatrix/deflector_tuning.dat", FileAccess.WRITE)
	f_tune.store_string(new_tuning_content)
	f_tune.close()
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("file_synced"):
		sdm.file_synced.emit("Ship Drive/Programs/ShieldMatrix/shields_config.dat")
	else:
		_app.load_dat_configuration()
	await get_tree().process_frame
	
	assert_eq(_app.active_config["max_capacity_per_quadrant"], 350.0, "max_capacity_per_quadrant deve aggiornarsi a runtime a 350.0")
	assert_eq(_app.active_config["harmonic_frequency"], 528.0, "harmonic_frequency deve aggiornarsi a runtime a 528.0")
	assert_eq(_app.active_config["emergency_boost_cooldown"], 5.0, "emergency_boost_cooldown deve aggiornarsi a 5.0")

func test_rbac_permissions_matrix_for_crew_roles() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	# NOTA: can_control_shields include un OR diretto su is_solo_mode, quindi va
	# disattivata esplicitamente la modalità Solo per validare la vera matrice RBAC.
	NetworkManager.is_solo_mode = false
	
	NetworkManager.request_role(NetworkManager.ROLE_ENGINEER)
	await get_tree().process_frame
	assert_true(_app.can_control_shields, "Ingegnere deve avere pieno controllo sugli scudi")
	assert_false(_app.emergency_boost_button.disabled, "Pulsante ricarica rapida abilitato per Ingegnere")
	assert_false(_app.reset_balance_button.disabled, "Pulsante reset bilanciamento abilitato per Ingegnere")
	assert_false(_app.phase_sync_switch.disabled, "Interruttore armoniche abilitato per Ingegnere")
	
	NetworkManager.request_role(NetworkManager.ROLE_CAPTAIN)
	await get_tree().process_frame
	assert_true(_app.can_control_shields, "Capitano deve avere pieno controllo sugli scudi")
	assert_false(_app.emergency_boost_button.disabled, "Pulsante ricarica rapida abilitato per Capitano")
	
	NetworkManager.request_role(NetworkManager.ROLE_PILOT)
	await get_tree().process_frame
	assert_false(_app.can_control_shields, "Pilota deve essere in sola lettura")
	assert_true(_app.emergency_boost_button.disabled, "Pulsante ricarica rapida disabilitato per Pilota")
	assert_true(_app.reset_balance_button.disabled, "Pulsante reset bilanciamento disabilitato per Pilota")
	assert_true(_app.phase_sync_switch.disabled, "Interruttore armoniche disabilitato per Pilota")
	
	NetworkManager.request_role(NetworkManager.ROLE_SOLDIER)
	await get_tree().process_frame
	assert_false(_app.can_control_shields, "Soldato deve essere in sola lettura")
	assert_true(_app.emergency_boost_button.disabled, "Pulsante ricarica rapida disabilitato per Soldato")
	
	NetworkManager.request_role(NetworkManager.ROLE_HACKER)
	await get_tree().process_frame
	assert_false(_app.can_control_shields, "Hacker deve essere in sola lettura")
	assert_true(_app.emergency_boost_button.disabled, "Pulsante ricarica rapida disabilitato per Hacker")
	
	NetworkManager.request_role(NetworkManager.ROLE_ENGINEER)
	await get_tree().process_frame
	assert_true(_app.can_control_shields, "Controllo ripristinato per Ingegnere")

func test_quadrant_balance_reset_slider_and_vector_pad() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app._on_reset_balance_pressed()
	assert_true(is_equal_approx(_app.ratio_fore, 0.25), "Ratio Prua iniziale deve essere 0.25")
	assert_true(is_equal_approx(_app.ratio_aft, 0.25), "Ratio Poppa iniziale deve essere 0.25")
	assert_true(is_equal_approx(_app.ratio_port, 0.25), "Ratio Babordo iniziale deve essere 0.25")
	assert_true(is_equal_approx(_app.ratio_starboard, 0.25), "Ratio Tribordo iniziale deve essere 0.25")
	
	_app._on_slider_ratio_changed(GlobalValues.Quadrant.FORE, 50.0)
	assert_true(is_equal_approx(_app.ratio_fore, 0.50), "Ratio Prua deve essere 0.50")
	var sum_ratios := _app.ratio_fore + _app.ratio_aft + _app.ratio_port + _app.ratio_starboard
	assert_true(is_equal_approx(sum_ratios, 1.0), "La somma dei ratio deve rimanere 1.0 (100%)")
	
	_app._apply_vector_bias(Vector2(0, -1.0))
	assert_true(_app.ratio_fore > _app.ratio_aft, "Ratio Prua deve prevalere su Poppa quando il vector pad punta in avanti")
	
	_app._on_reset_balance_pressed()
	assert_true(is_equal_approx(_app.ratio_fore, 0.25), "Reset bilanciamento ripristina Prua a 0.25")

func test_emergency_boost_and_cooldown() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app.shield_fore = 50.0
	_app.shield_aft = 50.0
	_app.shield_port = 50.0
	_app.shield_starboard = 50.0
	_app.boost_cooldown_timer = 0.0
	
	_app._on_emergency_boost_pressed()
	assert_true(_app.shield_fore > 50.0, "Ricarica rapida deve incrementare il livello scudi di Prua")
	assert_true(_app.boost_cooldown_timer > 0.0, "Ricarica rapida deve attivare il timer di cooldown")
	assert_true(_app.emergency_boost_button.disabled, "Pulsante ricarica rapida deve essere disabilitato durante il cooldown")

func test_phase_sync_harmonics_toggle() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app._on_phase_sync_toggled(false)
	assert_false(_app.is_phase_synced, "Armoniche devono risultare disattivate")
	assert_true(_app.phase_status_label.text.contains("DISATTIVE"), "Label di stato deve riflettere la disattivazione")
	
	_app._on_phase_sync_toggled(true)
	assert_true(_app.is_phase_synced, "Armoniche devono risultare sincronizzate")
	assert_true(_app.phase_status_label.text.contains("SINCRONIZZATE"), "Label di stato deve riflettere la sincronizzazione")

func test_terminal_cat_command_rejects_reading_shield_dat_files() -> void:
	await _start_solo_mission()
	var terminal_res := load("res://Applications/Terminal/src/terminal_scene.tscn") as PackedScene
	assert_not_null(terminal_res, "Scena Terminal deve essere caricabile")
	
	var term: Terminal = terminal_res.instantiate() as Terminal
	add_child_autofree(term)
	await get_tree().process_frame
	
	var cat_script: GDScript = load("res://Applications/Terminal/commands/cat_command.gd")
	var cat_cmd = cat_script.new()
	term.virtual_path_manager.set_path("Ship Drive/Programs/ShieldMatrix")
	var args: Array[String] = ["shields_config.dat"]
	cat_cmd.execute(term, args)
	
	var found_msg := false
	for c in term.command_output_container.get_children():
		if "text" in c and (c.text.contains("non sono leggibili") or c.text.contains(".dat")):
			found_msg = true
			break
	assert_true(found_msg, "Il comando cat deve rifiutare la lettura diretta del file shields_config.dat")

func test_split_view_default_defense_devices() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	assert_not_null(_app.defense_devices_panel, "Pannello destro %DefenseDevicesPanel deve essere presente")
	assert_not_null(_app.devices_scroll_container, "ScrollContainer %DevicesScrollContainer deve essere presente")
	assert_not_null(_app.devices_list_container, "VBoxContainer %DevicesListContainer deve essere presente")
	assert_true(_app.devices_list_container.get_child_count() >= 3, "Devono essere istanziate le schede dei dispositivi iniziali")
	
	var default_devices := _app.get_defense_devices()
	assert_true(default_devices.size() >= 3, "Devono essere registrati almeno 3 dispositivi predefiniti")
	assert_eq(default_devices[0]["id"], "gatling_1", "Primo dispositivo predefinito deve essere gatling_1")
	assert_eq(default_devices[1]["id"], "gatling_2", "Secondo dispositivo predefinito deve essere gatling_2")
	assert_eq(default_devices[2]["id"], "flack_1", "Terzo dispositivo predefinito deve essere flack_1")

func test_dynamic_device_registration_and_sector_reassignment() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	var new_pd_device := {
		"id": "emp_defense_1",
		"name": "Generatore EMP Settore",
		"type": "EMP",
		"sector": ShieldMatrixApp.DefenseSector.STARBOARD,
		"ammo": 5,
		"status": "READY",
		"cooldown": 0.0
	}
	_app.register_defense_device(new_pd_device)
	assert_eq(_app.get_defense_devices().size(), 4, "La lista deve contenere 4 dispositivi dopo registrazione dinamica")
	assert_eq(_app.devices_list_container.get_child_count(), 4, "La UI deve contenere 4 schede DefenseDeviceCard")
	
	_app.assign_device_sector("gatling_1", ShieldMatrixApp.DefenseSector.AFT)
	var devs_aft := _app.get_devices_in_sector(ShieldMatrixApp.DefenseSector.AFT)
	var found_g1 := false
	for d in devs_aft:
		if d.get("id") == "gatling_1":
			found_g1 = true
			break
	assert_true(found_g1, "gatling_1 deve essere assegnata al settore Poppa (AFT)")
	
	_app.assign_device_sector("gatling_1", ShieldMatrixApp.DefenseSector.FORE)
	assert_true(_app.get_devices_in_sector(ShieldMatrixApp.DefenseSector.FORE).size() > 0, "gatling_1 riassegnata a FORE")

func test_gatling_interception_and_directional_sector_constraint() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	SpaceWorldManager.clear_incoming_projectiles()
	_app.reload_all_defense_devices()
	_app.assign_device_sector("gatling_1", ShieldMatrixApp.DefenseSector.FORE)
	var g1_initial_ammo: int = _app.get_devices_in_sector(ShieldMatrixApp.DefenseSector.FORE)[0]["ammo"]
	
	SpaceWorldManager.spawn_incoming_projectile("KINETIC", Vector3(0, 0, -50), Vector3(0, 0, 20), 30.0, Vector3.ZERO)
	assert_eq(SpaceWorldManager.get_incoming_projectiles().size(), 1, "Proiettile registrato in SpaceWorldManager")
	
	_app._process_active_defenses(0.1)
	
	assert_true(SpaceWorldManager.get_incoming_projectiles().is_empty(), "Proiettile da Prua deve essere stato intercettato e distrutto")
	var g1_current_ammo: int = _app.get_devices_in_sector(ShieldMatrixApp.DefenseSector.FORE)[0]["ammo"]
	assert_eq(g1_current_ammo, g1_initial_ammo - 1, "Munizioni Gatling 1 decrementate di 1")
	
	# Minaccia in arrivo da un settore non presidiato (Poppa/AFT): nessun'arma assegnata
	_app.assign_device_sector("flack_1", ShieldMatrixApp.DefenseSector.PORT)
	_app.assign_device_sector("gatling_2", ShieldMatrixApp.DefenseSector.STARBOARD)
	
	SpaceWorldManager.spawn_incoming_projectile("KINETIC", Vector3(0, 0, 50), Vector3(0, 0, -20), 30.0, Vector3.ZERO)
	_app._process_active_defenses(0.1)
	
	assert_eq(SpaceWorldManager.get_incoming_projectiles().size(), 1, "Proiettile in settore non difeso NON deve essere intercettato")

func test_flack_countermeasures_deflect_homing_missile() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	SpaceWorldManager.clear_incoming_projectiles()
	_app.reload_all_defense_devices()
	_app.assign_device_sector("flack_1", ShieldMatrixApp.DefenseSector.STARBOARD)
	
	var homing_missile := SpaceWorldManager.spawn_incoming_projectile("HOMING_MISSILE", Vector3(60, 0, 0), Vector3(-25, 0, 0), 45.0, Vector3.ZERO)
	assert_true(homing_missile["is_homing"], "Il missile deve essere inizialmente agganciato (is_homing = true)")
	
	_app._process_active_defenses(0.1)
	
	var projs := SpaceWorldManager.get_incoming_projectiles()
	assert_eq(projs.size(), 1, "Il missile rimane nello spazio ma con traiettoria deviata")
	assert_true(projs[0]["is_deflected"], "Il missile deve risultare deviato dalla cortina Angel Hair")
	assert_false(projs[0]["is_homing"], "L'aggancio a guida autonoma del missile deve essere azzerato")

func test_combat_director_defense_evaluation_integration() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	_app.assign_device_sector("gatling_1", ShieldMatrixApp.DefenseSector.FORE)
	
	var combat_dir := CombatDirector.new()
	add_child_autofree(combat_dir)
	
	var devices := _app.get_defense_devices()
	var eval_fore: Dictionary = combat_dir.evaluate_defensive_interception(Vector3(0, 0, -10), "kinetic", devices)
	assert_true(eval_fore.intercepted, "Hit da prua deve essere intercettato da Gatling 1")
	assert_eq(eval_fore.action, "DESTROYED", "Azione Gatling deve essere DESTROYED")

func test_queue_free_cleanup_does_not_error() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	_app.queue_free()
	await get_tree().process_frame
	_app = null
	assert_true(true, "La rimozione dell'app ShieldMatrix non deve generare errori di pulizia dei segnali")
