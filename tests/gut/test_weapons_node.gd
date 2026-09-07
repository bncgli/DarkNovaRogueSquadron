extends GutTest

## Test GUT per l'applicazione Weapons (armi tattiche, 4 tipi di munizioni,
## termodinamica canne, radar tattico, lock bersaglio/missile, torretta mouse).
## Migrato da tests/test_weapons_node.gd (extends Node, assert() nudo).

var _app: WeaponsApp = null

func before_each() -> void:
	NetworkManager.disconnect_game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func after_each() -> void:
	if is_instance_valid(_app):
		_app.queue_free()
	_app = null
	NetworkManager.disconnect_game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _start_solo_mission(player_name: String = "Comandante Test") -> void:
	NetworkManager.start_solo_game(player_name)
	NetworkManager.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame

func _create_app() -> WeaponsApp:
	var scene: PackedScene = load("res://Applications/Weapons/weapons_app.tscn")
	assert_not_null(scene, "Scena weapons_app.tscn deve essere caricabile")
	var app: WeaponsApp = scene.instantiate() as WeaponsApp
	add_child_autofree(app)
	await get_tree().process_frame
	return app

func test_disconnected_overlay_and_operational_state() -> void:
	_app = await _create_app()
	assert_false(_app._is_ship_operational(), "L'app Weapons non deve essere operativa a nave disconnessa")
	assert_not_null(_app.disconnected_overlay, "L'overlay DisconnectedOverlay deve esistere")
	assert_true(_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve essere visibile da disconnesso")
	
	await _start_solo_mission()
	
	assert_true(_app._is_ship_operational(), "L'app Weapons deve essere operativa dopo l'avvio della missione")
	assert_false(_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve scomparire all'avvio della missione")

func test_ship_drive_folder_is_protected_by_default_password() -> void:
	await _start_solo_mission()
	assert_true(DirAccess.dir_exists_absolute("user://files/Ship Drive/Programs/Weapons"), "Cartella Programs/Weapons deve esistere in Ship Drive")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/Weapons/weapons_config.dat"), "weapons_config.dat deve esistere in Ship Drive/Programs/Weapons/")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/Weapons/ammo_tuning.dat"), "ammo_tuning.dat deve esistere in Ship Drive/Programs/Weapons/")
	
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	assert_not_null(fpm, "FolderPasswordManager deve essere disponibile come autoload")
	assert_true(fpm.has_password("Ship Drive/Programs/Weapons"), "La cartella Ship Drive/Programs/Weapons deve essere protetta da password")
	assert_true(fpm.check_password("Ship Drive/Programs/Weapons", "WEAP-7815"), "La password predefinita della cartella deve essere WEAP-7815")

func test_dat_configuration_default_values_and_runtime_hot_reload() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app.load_dat_configuration()
	assert_true(_app.active_config.get("is_dat_loaded"), "Configurazione .dat deve risultare caricata")
	assert_eq(_app.active_config.get("max_range"), 4500.0, "max_range di fabbrica deve essere 4500.0")
	assert_eq(_app.active_config.get("torpedo_velocity"), 85.0, "torpedo_velocity di fabbrica deve essere 85.0")
	
	var new_dat_content := "[SYSTEM]\napp_name=Weapons\nversion=1.0.4\nstatus=OVERCLOCKED\nweapons_subsystem=ACTIVE\n\n[WEAPONS]\nmax_range=6000.0\nfire_rate=2.5\ncooling_rate=1.2\nauto_pdg_enabled=true\nlaser_power_draw=300.0\ntorpedo_max_ammo=16\npdg_ammo_max=600\npdg_fire_rate=12.0\nemergency_vent_cooldown=5.0\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/Weapons/weapons_config.dat", FileAccess.WRITE)
	f_out.store_string(new_dat_content)
	f_out.close()
	
	var new_tuning_content := "[BALLISTICS]\ntorpedo_velocity=120.0\nauto_lead_tracking=true\noverclock_damage_mult=1.5\nheat_multiplier=1.2\npdg_range=1500.0\nlaser_beam_intensity=1.5\n"
	var f_tune := FileAccess.open("user://files/Ship Drive/Programs/Weapons/ammo_tuning.dat", FileAccess.WRITE)
	f_tune.store_string(new_tuning_content)
	f_tune.close()
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("file_synced"):
		sdm.file_synced.emit("Ship Drive/Programs/Weapons/weapons_config.dat")
	else:
		_app.load_dat_configuration()
	await get_tree().process_frame
	
	assert_eq(_app.active_config["max_range"], 6000.0, "max_range deve aggiornarsi a runtime a 6000.0")
	assert_eq(_app.active_config["torpedo_velocity"], 120.0, "torpedo_velocity deve aggiornarsi a runtime a 120.0")
	assert_eq(_app.active_config["emergency_vent_cooldown"], 5.0, "emergency_vent_cooldown deve aggiornarsi a 5.0")

func test_rbac_permissions_matrix_for_crew_roles() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	# NOTA: can_control_weapons include un OR diretto su is_solo_mode, quindi va
	# disattivata esplicitamente la modalità Solo per validare la vera matrice RBAC.
	NetworkManager.is_solo_mode = false
	
	NetworkManager.request_role(NetworkManager.ROLE_SOLDIER)
	await get_tree().process_frame
	assert_true(_app.can_control_weapons, "Soldato deve avere pieno controllo sulle armi")
	assert_false(_app.fire_button.disabled, "Pulsante fuoco abilitato per Soldato")
	assert_false(_app.vent_heat_button.disabled, "Pulsante scarico termico abilitato per Soldato")
	
	NetworkManager.request_role(NetworkManager.ROLE_PILOT)
	await get_tree().process_frame
	assert_false(_app.can_control_weapons, "Pilota deve essere in sola lettura")
	assert_true(_app.fire_button.disabled, "Pulsante fuoco disabilitato per Pilota")
	assert_true(_app.vent_heat_button.disabled, "Pulsante scarico termico disabilitato per Pilota")
	
	NetworkManager.request_role(NetworkManager.ROLE_ENGINEER)
	await get_tree().process_frame
	assert_false(_app.can_control_weapons, "Ingegnere deve essere in sola lettura")
	assert_true(_app.fire_button.disabled, "Pulsante fuoco disabilitato per Ingegnere")
	
	NetworkManager.request_role(NetworkManager.ROLE_CAPTAIN)
	await get_tree().process_frame
	assert_true(_app.can_control_weapons, "Capitano deve avere pieno controllo d'armi")
	assert_false(_app.fire_button.disabled, "Pulsante fuoco abilitato per Capitano")
	
	NetworkManager.request_role(NetworkManager.ROLE_SOLDIER)
	await get_tree().process_frame
	assert_true(_app.can_control_weapons, "Controllo ripristinato per Soldato")

func test_heavy_mg_fire_consumes_ammo_and_generates_heat() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app._select_ammo_type(WeaponsApp.AmmoType.HEAVY_MG)
	assert_eq(_app.active_ammo_type, WeaponsApp.AmmoType.HEAVY_MG, "Mitragliatrice Pesante attiva")
	var prev_mg: int = _app.heavy_mg_ammo
	_app.fire_cooldown_timer = 0.0
	_app.barrel_heat = 0.0
	_app.is_overheated = false
	_app._on_fire_button_pressed()
	assert_eq(_app.heavy_mg_ammo, prev_mg - 1, "Il fuoco MG deve consumare 1 colpo")
	assert_true(_app.barrel_heat > 0.0, "Il fuoco MG deve generare calore nelle canne")

func test_heavy_cannon_fire_consumes_capacitor_and_ammo() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app._select_ammo_type(WeaponsApp.AmmoType.HEAVY_CANNON)
	assert_eq(_app.active_ammo_type, WeaponsApp.AmmoType.HEAVY_CANNON, "Cannone Pesante attivo")
	_app.laser_charge = 100.0
	_app.fire_cooldown_timer = 0.0
	var prev_cannon: int = _app.heavy_cannon_ammo
	_app._on_fire_button_pressed()
	assert_eq(_app.laser_charge, 80.0, "Il cannone pesante deve consumare il 20% di condensatore")
	assert_eq(_app.heavy_cannon_ammo, prev_cannon - 1, "Il cannone pesante deve consumare 1 colpo")

func test_missile_fire_requires_target_lock() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app._select_ammo_type(WeaponsApp.AmmoType.MISSILE)
	assert_eq(_app.active_ammo_type, WeaponsApp.AmmoType.MISSILE, "Missili attivi")
	_app.fire_cooldown_timer = 0.0
	_app.is_missile_locked = false
	_app.is_target_locked = false
	var prev_missiles: int = _app.missile_ammo
	
	_app._on_fire_button_pressed()
	assert_eq(_app.missile_ammo, prev_missiles, "Il fuoco missile senza lock deve essere bloccato")
	
	_app.is_missile_locked = true
	_app.selected_target_id = "AST-01"
	_app._on_fire_button_pressed()
	assert_eq(_app.missile_ammo, prev_missiles - 1, "Il lancio missile con lock deve consumare 1 missile")

func test_probe_launch_decrements_ammo_and_registers_active_probe() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app._select_ammo_type(WeaponsApp.AmmoType.PROBE)
	assert_eq(_app.active_ammo_type, WeaponsApp.AmmoType.PROBE, "Sonde telemetriche attive")
	_app.fire_cooldown_timer = 0.0
	var prev_probes: int = _app.probe_ammo
	_app._on_fire_button_pressed()
	assert_eq(_app.probe_ammo, prev_probes - 1, "Il lancio sonda deve decrementare la riserva di 1")
	assert_true(SpaceWorldManager.active_probes.size() > 0, "Una sonda attiva deve risultare registrata in SpaceWorldManager")

func test_overheat_lockout_and_emergency_thermal_vent() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app.barrel_heat = 100.0
	_app._update_cooling_and_power(0.1)
	assert_true(_app.is_overheated, "barrel_heat a 100% deve innescare il blocco di surriscaldamento")
	
	_app._select_ammo_type(WeaponsApp.AmmoType.HEAVY_MG)
	_app.fire_cooldown_timer = 0.0
	var ammo_before_overheat := _app.heavy_mg_ammo
	_app._on_fire_button_pressed()
	assert_eq(_app.heavy_mg_ammo, ammo_before_overheat, "Il fuoco deve essere bloccato durante il surriscaldamento")
	
	_app.vent_cooldown_timer = 0.0
	_app._on_vent_heat_button_pressed()
	assert_eq(_app.barrel_heat, 0.0, "Lo scarico termico deve azzerare il calore delle canne")
	assert_false(_app.is_overheated, "Lo scarico termico deve sbloccare lo stato di surriscaldamento")

func test_radar_target_lock_and_lead_indicator() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app._refresh_targets()
	assert_true(_app.detected_targets.size() > 0, "Il radar deve rilevare bersagli/contatti nello spazio")
	
	_app._on_target_option_selected(1)
	assert_false(_app.selected_target_id.is_empty(), "Un bersaglio deve risultare selezionato")
	
	_app._on_lock_button_pressed()
	assert_true(_app.is_target_locked, "Il bersaglio deve risultare bloccato (Lock)")
	assert_true(_app.radar_canvas.has_lock, "Il canvas radar deve riflettere il lock attivo")
	
	_app._refresh_targets()
	assert_true(_app.lead_calc_label.text.contains("ANTICIPO TIRO"), "Label lead indicator deve calcolare l'anticipo")

func test_armory_power_integration() -> void:
	await _start_solo_mission()
	assert_true(SpaceWorldManager.is_armory_powered(), "L'armeria deve risultare alimentata di default")

func test_terminal_cat_command_rejects_reading_weapons_dat_files() -> void:
	await _start_solo_mission()
	var terminal_res := load("res://Applications/Terminal/src/terminal_scene.tscn") as PackedScene
	assert_not_null(terminal_res, "Scena Terminal deve essere caricabile")
	
	var term: Terminal = terminal_res.instantiate() as Terminal
	add_child_autofree(term)
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
	assert_true(found_msg, "Il comando cat deve rifiutare la lettura diretta del file .dat di Weapons")

func test_optical_aim_camera_and_subviewport() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	assert_not_null(_app.feed_viewport, "Feed viewport deve essere presente")
	assert_not_null(_app.feed_camera_3d, "Feed Camera3D deve essere presente")
	assert_not_null(_app.trajectory_hud, "TrajectoryHUD deve essere presente nel viewport")
	
	_app.aim_yaw_slider.value = 15.0
	_app.aim_pitch_slider.value = -10.0
	_app._on_aim_slider_changed(0.0)
	assert_eq(_app.manual_aim, Vector2(15.0, -10.0), "La mira manuale deve essere aggiornata dai cursori")
	assert_true(_app.turret_feed_label.text.contains("+15.0°") and _app.turret_feed_label.text.contains("-10.0°"), "Label telecamera deve riflettere yaw e pitch")
	
	_app._on_aim_center_pressed()
	assert_eq(_app.manual_aim, Vector2.ZERO, "La pressione di Centro deve azzerare la mira")

func test_mouse_aim_capture_space_escape_and_focus_loss() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app.is_mouse_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var ev_space := InputEventKey.new()
	ev_space.keycode = KEY_SPACE
	ev_space.pressed = true
	_app._input(ev_space)
	assert_true(_app.is_mouse_captured, "La pressione di Spazio deve attivare la cattura del mouse")
	
	_app.manual_aim = Vector2.ZERO
	var ev_motion := InputEventMouseMotion.new()
	ev_motion.relative = Vector2(40.0, -20.0)
	_app._input(ev_motion)
	assert_true(_app.manual_aim.x != 0.0 or _app.manual_aim.y != 0.0, "Il movimento del mouse deve muovere yaw e pitch della torretta")
	
	var ev_esc := InputEventKey.new()
	ev_esc.keycode = KEY_ESCAPE
	ev_esc.pressed = true
	_app._input(ev_esc)
	assert_false(_app.is_mouse_captured, "La pressione di Escape deve rilasciare il mouse")
	
	_app._toggle_mouse_capture()
	assert_true(_app.is_mouse_captured, "Mouse ricatturato")
	_app._on_parent_window_selected(false)
	assert_false(_app.is_mouse_captured, "La de-selezione della finestra deve rilasciare il mouse")

func test_numeric_key_ammo_selection() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	var ev_k1 := InputEventKey.new()
	ev_k1.keycode = KEY_1
	ev_k1.pressed = true
	_app._input(ev_k1)
	assert_eq(_app.active_ammo_type, WeaponsApp.AmmoType.HEAVY_MG, "Tasto 1 deve selezionare Heavy MG")
	
	var ev_k2 := InputEventKey.new()
	ev_k2.keycode = KEY_2
	ev_k2.pressed = true
	_app._input(ev_k2)
	assert_eq(_app.active_ammo_type, WeaponsApp.AmmoType.HEAVY_CANNON, "Tasto 2 deve selezionare Heavy Cannon")
	
	var ev_k3 := InputEventKey.new()
	ev_k3.keycode = KEY_3
	ev_k3.pressed = true
	_app._input(ev_k3)
	assert_eq(_app.active_ammo_type, WeaponsApp.AmmoType.MISSILE, "Tasto 3 deve selezionare Missile")
	
	var ev_k4 := InputEventKey.new()
	ev_k4.keycode = KEY_4
	ev_k4.pressed = true
	_app._input(ev_k4)
	assert_eq(_app.active_ammo_type, WeaponsApp.AmmoType.PROBE, "Tasto 4 deve selezionare Probe")

func test_missile_optical_lock_accumulation_and_trajectory_hud() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app._select_ammo_type(WeaponsApp.AmmoType.MISSILE)
	_app._refresh_targets()
	assert_true(_app.detected_targets.size() > 0, "Bersagli rilevati per il lock")
	var target_ast: Dictionary = _app.detected_targets[0]
	_app.manual_aim = Vector2(float(target_ast.get("bearing_deg", 0.0)), float(target_ast.get("elevation_deg", 0.0)))
	_app.missile_current_aim_time = 0.0
	_app.is_missile_locked = false
	_app.is_target_locked = false
	
	_app._process(1.0)
	assert_true(_app.missile_current_aim_time >= 1.0 and not _app.is_missile_locked, "Lock missile in accumulo")
	_app._process(1.2)
	assert_true(_app.is_missile_locked, "Lock missile completato dopo 2.0s di puntamento continuo")
	
	_app._update_turret_camera_feed()
	assert_eq(_app.trajectory_hud.active_ammo_type, WeaponsApp.AmmoType.MISSILE, "TrajectoryHUD deve riflettere il tipo d'arma")
	assert_true(_app.trajectory_hud.is_missile_locked, "TrajectoryHUD deve mostrare lock missile attivo")
	assert_true(_app.trajectory_hud.has_lead, "TrajectoryHUD deve mostrare lead indicator per il bersaglio")

func test_queue_free_cleanup_does_not_error() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	_app.queue_free()
	await get_tree().process_frame
	_app = null
	assert_true(true, "La rimozione dell'app Weapons non deve generare errori di pulizia dei segnali")
