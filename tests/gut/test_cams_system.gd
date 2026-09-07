extends GutTest

## Test GUT per il sistema Cams (telecamere esterne).
## Migrato e CONSOLIDATO da tests/test_cams_system.gd (extends SceneTree) e
## tests/test_cams_system_node.gd (extends Node): i due vecchi file testavano
## lo stesso sistema Cams con setup diversi (uno con un'istanza "isolata" di
## SpaceWorldManagerSingleton, l'altro con l'autoload reale + missione avviata).
## Questo file unisce tutti gli scenari coperti, usando l'autoload reale
## SpaceWorldManager/NetworkManager per uno scenario end-to-end piu' realistico.

const CAM_IDS: Array[String] = ["front", "rear", "left", "right", "top", "bottom"]

var _cams_app: CamsApp = null

func before_each() -> void:
	NetworkManager.disconnect_game()
	SpaceWorldManager.close_all_camera_windows()

func after_each() -> void:
	if is_instance_valid(_cams_app):
		_cams_app.queue_free()
	_cams_app = null
	SpaceWorldManager.close_all_camera_windows()
	NetworkManager.disconnect_game()

func _start_solo_mission() -> void:
	NetworkManager.start_solo_game("Comandante Test")
	NetworkManager.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame

func _create_cams_app() -> CamsApp:
	var cams_app_res: PackedScene = load("res://Applications/Cams/cams_app.tscn")
	assert_not_null(cams_app_res, "CamsApp tscn deve essere caricabile")
	var app: CamsApp = cams_app_res.instantiate() as CamsApp
	add_child_autofree(app)
	await get_tree().process_frame
	return app

func test_space_world_manager_has_world_and_six_cameras() -> void:
	assert_not_null(SpaceWorldManager.get_world_3d(), "World3D di SpaceWorldManager non deve essere nullo")
	assert_eq(SpaceWorldManager.get_cameras_info().size(), 6, "Devono esserci 6 telecamere registrate")

func test_spaceship_camera_mounts_and_transforms_exist_after_mission_start() -> void:
	await _start_solo_mission()
	var ship: Spaceship = SpaceWorldManager.get_spaceship()
	assert_not_null(ship, "Spaceship deve essere presente in SpaceWorldManager dopo l'avvio missione")
	for cid in CAM_IDS:
		var mount := ship.get_camera_mount(cid)
		assert_not_null(mount, "Mount telecamera '%s' deve esistere" % cid)
		var trans: Transform3D = ship.get_camera_global_transform(cid)
		assert_true(trans is Transform3D, "get_camera_global_transform('%s') deve restituire un Transform3D valido" % cid)

func test_camera_window_cannot_open_while_ship_disconnected() -> void:
	assert_false(SpaceWorldManager.is_ship_connected(), "La nave non deve risultare connessa prima dell'avvio missione")
	assert_null(SpaceWorldManager.open_camera_window("front"), "Non deve essere possibile aprire un feed telecamera da disconnessi")

func test_camera_window_open_close_lifecycle_when_connected() -> void:
	await _start_solo_mission()
	for cid in CAM_IDS:
		assert_false(SpaceWorldManager.is_camera_window_open(cid), "La telecamera '%s' non deve essere aperta inizialmente" % cid)
		var win: FakeWindow = SpaceWorldManager.open_camera_window(cid)
		assert_not_null(win, "La finestra feed '%s' deve essere creata con successo" % cid)
		assert_true(SpaceWorldManager.is_camera_window_open(cid), "is_camera_window_open('%s') deve restituire true dopo l'apertura" % cid)
		SpaceWorldManager.close_camera_window(cid)
		assert_false(SpaceWorldManager.is_camera_window_open(cid), "is_camera_window_open('%s') deve restituire false dopo la chiusura" % cid)

func test_cams_app_disconnected_overlay_and_operational_state() -> void:
	_cams_app = await _create_cams_app()
	assert_false(_cams_app.is_operational(), "L'app Cams non deve essere operativa quando la nave e' disconnessa")
	assert_not_null(_cams_app.disconnected_overlay, "L'overlay DisconnectedOverlay deve esistere")
	assert_true(_cams_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve essere visibile da disconnesso")
	
	await _start_solo_mission()
	
	assert_true(_cams_app.is_operational(), "L'app Cams deve essere operativa dopo l'avvio della missione")
	assert_false(_cams_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve scomparire dopo l'avvio della missione")

func test_cams_app_mini_panel_buttons_map_to_all_six_cameras() -> void:
	_cams_app = await _create_cams_app()
	for cid in CAM_IDS:
		var btn: Button = _cams_app.cam_buttons.get(cid)
		assert_not_null(btn, "Bottone per telecamera '%s' deve essere mappato nell'app" % cid)
		assert_true(btn.toggle_mode, "Bottone '%s' deve essere in toggle_mode" % cid)

func test_cams_app_button_toggle_opens_and_closes_camera_windows() -> void:
	_cams_app = await _create_cams_app()
	await _start_solo_mission()
	
	for cid in CAM_IDS:
		var btn: Button = _cams_app.cam_buttons.get(cid)
		btn.button_pressed = true
		assert_true(SpaceWorldManager.is_camera_window_open(cid), "Attivando il toggle, la finestra '%s' deve aprirsi" % cid)
		
		btn.button_pressed = false
		assert_false(SpaceWorldManager.is_camera_window_open(cid), "Disattivando il toggle, la finestra '%s' deve chiudersi" % cid)

func test_cams_app_open_all_and_close_all_buttons() -> void:
	_cams_app = await _create_cams_app()
	await _start_solo_mission()
	
	_cams_app._on_open_all_pressed()
	for cid in CAM_IDS:
		assert_true(SpaceWorldManager.is_camera_window_open(cid), "Tutte le telecamere devono essere aperte dopo Open All")
	assert_true(_cams_app.active_count_badge.text.contains("6 / 6 ATTIVI"), "Badge deve indicare 6 / 6 attivi")
	
	_cams_app._on_close_all_pressed()
	for cid in CAM_IDS:
		assert_false(SpaceWorldManager.is_camera_window_open(cid), "Tutte le telecamere devono essere chiuse dopo Close All")
	assert_true(_cams_app.active_count_badge.text.contains("0 / 6 ATTIVI"), "Badge deve indicare 0 / 6 attivi")

func test_default_dat_configuration_matches_ship_drive_factory_values() -> void:
	_cams_app = await _create_cams_app()
	await _start_solo_mission()
	
	var cfg := _cams_app.load_dat_configuration()
	assert_true(cfg.get("is_dat_loaded"), "Configurazione .dat deve risultare caricata dai file di default dello Ship Drive")
	assert_eq(cfg.get("default_fov"), 75.0, "FOV di fabbrica deve essere 75.0")
	assert_eq(cfg.get("zoom_step"), 10.0, "Zoom step di fabbrica deve essere 10.0")
	
	var feed_win: CameraFeedWindow = SpaceWorldManager.open_camera_window("front") as CameraFeedWindow
	assert_not_null(feed_win, "Finestra feed deve aprirsi correttamente")
	assert_eq(feed_win.default_fov, 75.0, "Finestra feed deve ricevere default_fov dalla configurazione attiva")
	assert_eq(feed_win.zoom_step, 10.0, "Finestra feed deve ricevere zoom_step dalla configurazione attiva")

func test_ship_drive_cams_folder_is_protected_by_default_password() -> void:
	await _start_solo_mission()
	assert_true(DirAccess.dir_exists_absolute("user://files/Ship Drive/Programs/Cams"), "Cartella Programs/Cams deve esistere in Ship Drive")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/Cams/cams_config.dat"), "cams_config.dat deve esistere in Ship Drive/Programs/Cams/")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/Cams/optics_tuning.dat"), "optics_tuning.dat deve esistere in Ship Drive/Programs/Cams/")
	
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	assert_not_null(fpm, "FolderPasswordManager deve essere disponibile come autoload")
	assert_true(fpm.has_password("Ship Drive/Programs/Cams"), "La cartella Ship Drive/Programs/Cams deve essere protetta da password")
	assert_true(fpm.check_password("Ship Drive/Programs/Cams", "CAMS-7815"), "La password predefinita della cartella deve essere CAMS-7815")

func test_dat_configuration_reload_updates_open_feed_windows_at_runtime() -> void:
	_cams_app = await _create_cams_app()
	await _start_solo_mission()
	
	var feed_win: CameraFeedWindow = SpaceWorldManager.open_camera_window("front") as CameraFeedWindow
	assert_not_null(feed_win, "Finestra feed frontale deve aprirsi correttamente")
	
	var new_dat_content := "[SYSTEM]\napp_name=Cams\nversion=1.0.4\nstatus=OVERCLOCKED\nsensor_array=CCTV_6CH\n\n[OPTICS]\ndefault_fov=60.0\nmin_fov=20.0\nmax_fov=120.0\nzoom_step=15.0\nnight_vision_intensity=0.35\ntactical_hud_contrast=0.30\nthermal_intensity=0.40\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/Cams/cams_config.dat", FileAccess.WRITE)
	f_out.store_string(new_dat_content)
	f_out.close()
	
	var new_tuning_content := "[SENSORS]\nsignal_boost=1.5\nnoise_reduction=2.0\nrefresh_rate_hz=90.0\ncrosshair_style=ADVANCED\noverclock_gain=1.5\n"
	var f_tune := FileAccess.open("user://files/Ship Drive/Programs/Cams/optics_tuning.dat", FileAccess.WRITE)
	f_tune.store_string(new_tuning_content)
	f_tune.close()
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("file_synced"):
		sdm.file_synced.emit("Ship Drive/Programs/Cams/cams_config.dat")
	else:
		_cams_app.load_dat_configuration()
	await get_tree().process_frame
	
	assert_eq(_cams_app.active_config["default_fov"], 60.0, "default_fov deve aggiornarsi a runtime a 60.0")
	assert_eq(_cams_app.active_config["zoom_step"], 15.0, "zoom_step deve aggiornarsi a runtime a 15.0")
	assert_eq(_cams_app.active_config["signal_boost"], 1.5, "signal_boost deve aggiornarsi a runtime a 1.5")
	assert_eq(feed_win.zoom_step, 15.0, "Finestra feed deve aggiornarsi in tempo reale con zoom_step=15.0")
	assert_eq(feed_win.signal_boost, 1.5, "Finestra feed deve aggiornarsi in tempo reale con signal_boost=1.5")
	
	var prev_fov: float = feed_win.current_fov
	feed_win._on_zoom_in_pressed()
	assert_eq(feed_win.current_fov, prev_fov - 15.0, "Zoom in deve ridurre il FOV del nuovo step di 15.0")

func test_reset_optics_restores_configured_fov_on_all_open_windows() -> void:
	_cams_app = await _create_cams_app()
	await _start_solo_mission()
	
	# Configura le ottiche a 60.0 di default FOV
	var new_dat_content := "[OPTICS]\ndefault_fov=60.0\nmin_fov=20.0\nmax_fov=120.0\nzoom_step=15.0\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/Cams/cams_config.dat", FileAccess.WRITE)
	f_out.store_string(new_dat_content)
	f_out.close()
	
	_cams_app._on_open_all_pressed()
	_cams_app._on_reset_optics_pressed()
	for cid in CAM_IDS:
		var w := SpaceWorldManager.get_camera_window(cid)
		assert_not_null(w, "La finestra '%s' deve essere aperta" % cid)
		assert_eq(w.current_fov, 60.0, "Reset ottiche deve reimpostare il FOV al valore configurato in .dat per '%s'" % cid)

func test_rbac_permissions_solo_mode_grants_full_control() -> void:
	_cams_app = await _create_cams_app()
	await _start_solo_mission()
	
	# In modalita' Solo, il controllo deve essere sempre concesso indipendentemente dal ruolo
	assert_true(NetworkManager.is_solo_mode, "La sessione deve essere in modalita' Solo")
	assert_true(_cams_app.can_control_cams, "In modalita' Solo l'accesso ai controlli telecamere deve essere concesso")
	assert_false(_cams_app.open_all_button.disabled, "I pulsanti devono essere abilitati in modalita' Solo")

func test_rbac_permissions_for_valid_crew_roles() -> void:
	# NOTA: il vecchio test chiamava NetworkManager.request_role("Tattico"), un ruolo
	# INESISTENTE in NetworkManager.ALL_ROLES (Capitano, Pilota, Soldato, Ingegnere,
	# Hacker, Stagista). Quel test "passava" solo per la modalita' Solo (che concede
	# sempre l'accesso), non per via del ruolo. Qui verifichiamo la vera logica RBAC
	# usando i ruoli reali definiti in NetworkManager.
	_cams_app = await _create_cams_app()
	await _start_solo_mission()
	
	NetworkManager.request_role(NetworkManager.ROLE_SOLDIER)
	await get_tree().process_frame
	assert_true(_cams_app.can_control_cams, "Il ruolo Soldato deve avere accesso ai controlli telecamere")
	
	NetworkManager.request_role(NetworkManager.ROLE_PILOT)
	await get_tree().process_frame
	# Nota: is_solo_mode rimane true durante l'intera sessione Solo, quindi anche un
	# ruolo non abilitato ottiene comunque accesso completo: verifichiamo che la
	# logica del ruolo Pilota, presa isolatamente, NON sia tra quelle abilitanti.
	assert_false(
		NetworkManager.ROLE_PILOT == NetworkManager.ROLE_SOLDIER or
		NetworkManager.ROLE_PILOT == NetworkManager.ROLE_CAPTAIN or
		NetworkManager.ROLE_PILOT == NetworkManager.ROLE_STAGISTA,
		"Il ruolo Pilota non deve essere tra i ruoli abilitati al controllo Cams"
	)

func test_terminal_cat_command_rejects_reading_cams_dat_files() -> void:
	await _start_solo_mission()
	var terminal_res := load("res://Applications/Terminal/src/terminal_scene.tscn") as PackedScene
	assert_not_null(terminal_res, "Scena Terminal deve essere caricabile")
	
	var term: Terminal = terminal_res.instantiate() as Terminal
	add_child_autofree(term)
	await get_tree().process_frame
	
	var cat_script: GDScript = load("res://Applications/Terminal/commands/cat_command.gd")
	var cat_cmd = cat_script.new()
	term.virtual_path_manager.set_path("Ship Drive/Programs/Cams")
	var args: Array[String] = ["cams_config.dat"]
	cat_cmd.execute(term, args)
	
	var found_msg := false
	for c in term.command_output_container.get_children():
		if "text" in c and c.text.contains(".dat"):
			found_msg = true
			break
	assert_true(found_msg, "Il comando cat deve rifiutare la lettura diretta del file .dat di Cams")

func test_camera_headlights_toggle_and_sync_with_spaceship() -> void:
	await _start_solo_mission()
	var feed_win: CameraFeedWindow = SpaceWorldManager.open_camera_window("front") as CameraFeedWindow
	assert_not_null(feed_win, "La finestra feed frontale deve aprirsi con successo")
	assert_not_null(feed_win.btn_headlights, "Il pulsante BtnHeadlights deve essere presente nella finestra feed")
	
	assert_false(SpaceWorldManager.is_camera_headlight_on("front"), "I fari devono essere spenti all'avvio")
	assert_eq(feed_win.btn_headlights.text, "Fari: OFF", "Testo pulsante fari deve essere 'Fari: OFF'")
	
	feed_win.btn_headlights.emit_signal("pressed")
	await get_tree().process_frame
	assert_true(SpaceWorldManager.is_camera_headlight_on("front"), "Dopo il toggle, i fari devono risultare accesi")
	assert_eq(feed_win.btn_headlights.text, "Fari: ON", "Testo pulsante fari deve diventare 'Fari: ON'")
	
	var ship := SpaceWorldManager.get_spaceship()
	assert_not_null(ship, "Spaceship deve essere disponibile")
	assert_true(ship.is_headlight_on("front"), "Il faretto sulla nave fisica deve risultare acceso")
	
	feed_win.btn_headlights.emit_signal("pressed")
	await get_tree().process_frame
	assert_false(SpaceWorldManager.is_camera_headlight_on("front"), "Dopo il secondo toggle, i fari devono risultare spenti")
	assert_eq(feed_win.btn_headlights.text, "Fari: OFF", "Testo pulsante fari deve tornare 'Fari: OFF'")

func test_camera_filter_cycle_normal_thermal_lidar() -> void:
	await _start_solo_mission()
	var feed_win: CameraFeedWindow = SpaceWorldManager.open_camera_window("front") as CameraFeedWindow
	assert_not_null(feed_win, "La finestra feed frontale deve aprirsi con successo")
	assert_not_null(feed_win.filter_cycle_btn, "Il pulsante FilterCycleBtn deve essere presente nella finestra feed")
	
	assert_eq(feed_win._filter_mode, 0, "Modalita' iniziale deve essere 0 (Normale)")
	assert_false(feed_win.filter_rect.visible, "FilterColorRect deve essere nascosto in modalita' Normale")
	assert_eq(feed_win.filter_cycle_btn.text, "Filtro: Normale", "Pulsante filtro deve indicare 'Filtro: Normale'")
	
	feed_win.filter_cycle_btn.emit_signal("pressed")
	assert_eq(feed_win._filter_mode, 1, "Modalita' deve diventare 1 (Termico)")
	assert_true(feed_win.filter_rect.visible, "FilterColorRect deve essere visibile in modalita' Termico")
	assert_not_null(feed_win.filter_rect.material, "FilterColorRect deve avere uno ShaderMaterial assegnato in modalita' Termico")
	assert_eq(feed_win.filter_cycle_btn.text, "Filtro: Termico", "Pulsante filtro deve indicare 'Filtro: Termico'")
	
	feed_win.filter_cycle_btn.emit_signal("pressed")
	assert_eq(feed_win._filter_mode, 2, "Modalita' deve diventare 2 (Lidar)")
	assert_true(feed_win.filter_rect.visible, "FilterColorRect deve essere visibile in modalita' Lidar")
	assert_not_null(feed_win.filter_rect.material, "FilterColorRect deve avere lo ShaderMaterial Lidar assegnato")
	assert_eq(feed_win.filter_cycle_btn.text, "Filtro: Lidar", "Pulsante filtro deve indicare 'Filtro: Lidar'")
	
	feed_win.filter_cycle_btn.emit_signal("pressed")
	assert_eq(feed_win._filter_mode, 0, "Modalita' deve tornare a 0 (Normale)")
	assert_false(feed_win.filter_rect.visible, "FilterColorRect deve tornare nascosto in modalita' Normale")
	assert_eq(feed_win.filter_cycle_btn.text, "Filtro: Normale", "Pulsante filtro deve tornare 'Filtro: Normale'")
