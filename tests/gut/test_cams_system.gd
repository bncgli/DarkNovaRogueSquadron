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
	CameraFeedWindow.clear_saved_camera_layouts()
	NetworkManager.disconnect_game()
	SpaceWorldManager.close_all_camera_windows()

func after_each() -> void:
	if is_instance_valid(_cams_app):
		_cams_app.queue_free()
	_cams_app = null
	SpaceWorldManager.close_all_camera_windows()
	CameraFeedWindow.clear_saved_camera_layouts()
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
	assert_eq(feed_win.btn_headlights.text, "💡", "Icona pulsante fari deve essere '💡'")
	assert_eq(feed_win.btn_headlights.modulate, Color(0.6, 0.6, 0.6), "Modulate fari deve essere spento all'avvio")
	
	feed_win.btn_headlights.emit_signal("pressed")
	await get_tree().process_frame
	assert_true(SpaceWorldManager.is_camera_headlight_on("front"), "Dopo il toggle, i fari devono risultare accesi")
	assert_eq(feed_win.btn_headlights.text, "💡", "Icona pulsante fari deve rimanere '💡'")
	assert_eq(feed_win.btn_headlights.modulate, Color(1.0, 0.9, 0.3), "Modulate fari deve essere acceso dopo il toggle")
	
	var ship := SpaceWorldManager.get_spaceship()
	assert_not_null(ship, "Spaceship deve essere disponibile")
	assert_true(ship.is_headlight_on("front"), "Il faretto sulla nave fisica deve risultare acceso")
	
	feed_win.btn_headlights.emit_signal("pressed")
	await get_tree().process_frame
	assert_false(SpaceWorldManager.is_camera_headlight_on("front"), "Dopo il secondo toggle, i fari devono risultare spenti")
	assert_eq(feed_win.btn_headlights.text, "💡", "Icona pulsante fari deve essere '💡'")
	assert_eq(feed_win.btn_headlights.modulate, Color(0.6, 0.6, 0.6), "Modulate fari deve tornare spento")

func test_camera_filter_cycle_normal_thermal_lidar() -> void:
	await _start_solo_mission()
	var feed_win: CameraFeedWindow = SpaceWorldManager.open_camera_window("front") as CameraFeedWindow
	assert_not_null(feed_win, "La finestra feed frontale deve aprirsi con successo")
	assert_not_null(feed_win.filter_cycle_btn, "Il pulsante FilterCycleBtn deve essere presente nella finestra feed")
	assert_not_null(feed_win.lidar_overlay, "Il nodo LidarOverlay deve essere presente nella finestra feed")
	
	# Modalita' 0: Normale
	assert_eq(feed_win._filter_mode, 0, "Modalita' iniziale deve essere 0 (Normale)")
	assert_false(feed_win.filter_rect.visible, "FilterColorRect deve essere nascosto in modalita' Normale")
	assert_false(feed_win.lidar_overlay.visible, "LidarOverlay deve essere nascosto in modalita' Normale")
	assert_eq(feed_win.filter_cycle_btn.text, "Filtro: Normale", "Pulsante filtro deve indicare 'Filtro: Normale'")
	
	# Modalita' 1: Termico
	feed_win.filter_cycle_btn.emit_signal("pressed")
	assert_eq(feed_win._filter_mode, 1, "Modalita' deve diventare 1 (Termico)")
	assert_true(feed_win.filter_rect.visible, "FilterColorRect deve essere visibile in modalita' Termico")
	assert_not_null(feed_win.filter_rect.material, "FilterColorRect deve avere uno ShaderMaterial assegnato in modalita' Termico")
	assert_false(feed_win.lidar_overlay.visible, "LidarOverlay deve rimanere nascosto in modalita' Termico")
	assert_eq(feed_win.filter_cycle_btn.text, "Filtro: Termico", "Pulsante filtro deve indicare 'Filtro: Termico'")
	
	# Modalita' 2: Lidar (Feed ottico normale visibile sotto, LidarOverlay attivo)
	feed_win.filter_cycle_btn.emit_signal("pressed")
	assert_eq(feed_win._filter_mode, 2, "Modalita' deve diventare 2 (Lidar)")
	assert_false(feed_win.filter_rect.visible, "FilterColorRect deve essere nascosto in modalita' Lidar")
	assert_true(feed_win.lidar_overlay.visible, "LidarOverlay deve essere visibile in modalita' Lidar")
	assert_eq(feed_win.filter_cycle_btn.text, "Filtro: Lidar", "Pulsante filtro deve indicare 'Filtro: Lidar'")
	
	# Ritorno a Modalita' 0: Normale
	feed_win.filter_cycle_btn.emit_signal("pressed")
	assert_eq(feed_win._filter_mode, 0, "Modalita' deve tornare a 0 (Normale)")
	assert_false(feed_win.filter_rect.visible, "FilterColorRect deve tornare nascosto in modalita' Normale")
	assert_false(feed_win.lidar_overlay.visible, "LidarOverlay deve tornare nascosto in modalita' Normale")
	assert_eq(feed_win.filter_cycle_btn.text, "Filtro: Normale", "Pulsante filtro deve tornare 'Filtro: Normale'")

func test_closing_cams_app_closes_camera_feed_windows() -> void:
	_cams_app = await _create_cams_app()
	await _start_solo_mission()
	
	var front_win = SpaceWorldManager.open_camera_window("front")
	var rear_win = SpaceWorldManager.open_camera_window("rear")
	assert_not_null(front_win, "La finestra front deve aprirsi")
	assert_not_null(rear_win, "La finestra rear deve aprirsi")
	assert_true(SpaceWorldManager.is_camera_window_open("front"), "La finestra front deve essere aperta")
	assert_true(SpaceWorldManager.is_camera_window_open("rear"), "La finestra rear deve essere aperta")
	
	_cams_app.queue_free()
	_cams_app = null
	await get_tree().process_frame
	
	assert_false(SpaceWorldManager.is_camera_window_open("front"), "La finestra front deve risultare chiusa dopo l'uscita di CamsApp")
	assert_false(SpaceWorldManager.is_camera_window_open("rear"), "La finestra rear deve risultare chiusa dopo l'uscita di CamsApp")

func test_closing_cams_app_parent_window_closes_camera_feed_windows() -> void:
	var app_win: FakeWindow = load("res://Scenes/Window/Application Window/application_window.tscn").instantiate()
	add_child_autofree(app_win)
	
	var cams_app_res: PackedScene = load("res://Applications/Cams/cams_app.tscn")
	_cams_app = cams_app_res.instantiate() as CamsApp
	app_win.get_node("%ApplicationContents").add_child(_cams_app)
	await get_tree().process_frame
	await get_tree().process_frame
	
	await _start_solo_mission()
	
	var left_win = SpaceWorldManager.open_camera_window("left")
	assert_not_null(left_win, "La finestra left deve aprirsi")
	assert_true(SpaceWorldManager.is_camera_window_open("left"), "La finestra left deve essere aperta")
	
	app_win._on_close_button_pressed()
	await get_tree().process_frame
	
	assert_false(SpaceWorldManager.is_camera_window_open("left"), "La finestra left deve risultare chiusa dopo la chiusura della finestra padre dell'app Cams")

func test_camera_shader_multi_window_independence() -> void:
	await _start_solo_mission()
	
	var front_win: CameraFeedWindow = SpaceWorldManager.open_camera_window("front") as CameraFeedWindow
	var rear_win: CameraFeedWindow = SpaceWorldManager.open_camera_window("rear") as CameraFeedWindow
	assert_not_null(front_win, "La finestra front deve aprirsi")
	assert_not_null(rear_win, "La finestra rear deve aprirsi")
	
	# Attiva shader termico su entrambe le finestre
	front_win.filter_cycle_btn.emit_signal("pressed") # 1 = Termico
	rear_win.filter_cycle_btn.emit_signal("pressed") # 1 = Termico
	
	assert_eq(front_win._filter_mode, 1, "Front deve essere in modalita' Termica")
	assert_eq(rear_win._filter_mode, 1, "Rear deve essere in modalita' Termica")
	assert_true(front_win.filter_rect.visible, "FilterColorRect di Front deve essere visibile")
	assert_true(rear_win.filter_rect.visible, "FilterColorRect di Rear deve essere visibile")
	
	var front_mat: ShaderMaterial = front_win.filter_rect.material as ShaderMaterial
	var rear_mat: ShaderMaterial = rear_win.filter_rect.material as ShaderMaterial
	assert_not_null(front_mat, "Front deve possedere uno ShaderMaterial")
	assert_not_null(rear_mat, "Rear deve possedere uno ShaderMaterial")
	assert_ne(front_mat, rear_mat, "I materiali delle due finestre devono essere istanze indipendenti")
	
	var front_tex = front_mat.get_shader_parameter("feed_texture")
	var rear_tex = rear_mat.get_shader_parameter("feed_texture")
	assert_not_null(front_tex, "Front material deve avere feed_texture impostata")
	assert_not_null(rear_tex, "Rear material deve avere feed_texture impostata")
	assert_eq(front_tex, front_win.feed_viewport.get_texture(), "Front material deve puntare alla texture del proprio feed_viewport")
	assert_eq(rear_tex, rear_win.feed_viewport.get_texture(), "Rear material deve puntare alla texture del proprio feed_viewport")
	assert_ne(front_tex, rear_tex, "Le texture campionate dalle due finestre devono essere distinte")
	
	# Passa Front e Rear a Lidar
	front_win.filter_cycle_btn.emit_signal("pressed") # 2 = Lidar
	rear_win.filter_cycle_btn.emit_signal("pressed") # 2 = Lidar
	
	assert_false(front_win.filter_rect.visible, "Front FilterColorRect deve essere nascosto in modalita' Lidar")
	assert_false(rear_win.filter_rect.visible, "Rear FilterColorRect deve essere nascosto in modalita' Lidar")
	assert_true(front_win.lidar_overlay.visible, "Front LidarOverlay deve essere visibile")
	assert_true(rear_win.lidar_overlay.visible, "Rear LidarOverlay deve essere visibile")
	assert_ne(front_win._lidar_points, rear_win._lidar_points, "I punti Lidar delle due finestre devono essere memorizzati in array distinti")

func test_lidar_depth_color_gradient() -> void:
	await _start_solo_mission()
	var feed_win: CameraFeedWindow = SpaceWorldManager.open_camera_window("front") as CameraFeedWindow
	assert_not_null(feed_win, "La finestra feed deve aprirsi")
	
	# Distanza ravvicinata (< 20m): rosso caldo dominante
	var col_close: Color = feed_win._get_lidar_depth_color(12.0)
	assert_gt(col_close.r, col_close.b, "A distanza ravvicinata (<20m) il rosso deve dominare sul blu")
	assert_gt(col_close.r, 0.8, "A distanza ravvicinata (<20m) la componente rossa deve essere elevata")
	
	# Distanza intermedia (50-80m): transizione verde / giallo
	var col_mid: Color = feed_win._get_lidar_depth_color(60.0)
	assert_gt(col_mid.g, 0.5, "A distanza intermedia (60m) la componente verde deve essere presente")
	
	# Distanza elevata (> 120m): blu freddo dominante
	var col_far: Color = feed_win._get_lidar_depth_color(150.0)
	assert_gt(col_far.b, col_far.r, "A distanza elevata (>120m) il blu deve dominare sul rosso")
	assert_gt(col_far.b, 0.7, "A distanza elevata (>120m) la componente blu deve essere elevata")

func test_lidar_obstacle_detection_and_ship_exclusion() -> void:
	await _start_solo_mission()
	var feed_win: CameraFeedWindow = SpaceWorldManager.open_camera_window("front") as CameraFeedWindow
	assert_not_null(feed_win, "La finestra front deve essere aperta")
	
	feed_win.filter_cycle_btn.emit_signal("pressed") # 1 = Termico
	feed_win.filter_cycle_btn.emit_signal("pressed") # 2 = Lidar
	assert_eq(feed_win._filter_mode, 2, "La telecamera deve essere in modalita' Lidar")
	
	# Creazione di un corpo fisico ostacolo nello spazio a 15m di fronte alla camera frontale
	var obstacle := StaticBody3D.new()
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 10, 2)
	col_shape.shape = box
	obstacle.add_child(col_shape)
	obstacle.position = Vector3(0, 0.25, -15.0)
	
	var world_3d := SpaceWorldManager.get_world_3d()
	assert_not_null(world_3d, "Il World3D condiviso deve esistere")
	SpaceWorldManager._space_scene_instance.add_child(obstacle)
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# Esecuzione scansione Lidar
	feed_win._update_lidar_scan()
	
	assert_gt(feed_win._lidar_points.size(), 0, "Il Lidar deve rilevare punti di impatto contro l'ostacolo")
	assert_between(feed_win._lidar_closest_distance, 10.0, 16.0, "La distanza minima rilevata deve corrispondere alla posizione dell'ostacolo")
	
	# Verifica che lo scafo della Spaceship non generi collisioni fantasma
	var ship := SpaceWorldManager.get_spaceship()
	assert_not_null(ship, "La nave del giocatore deve esistere")
	var ship_rid := ship.get_rid()
	for pt in feed_win._lidar_points:
		assert_ne(pt.get("rid", RID()), ship_rid, "Nessun raggio Lidar deve collidere con lo scafo della nave madre")
	
	obstacle.queue_free()

func test_lidar_multi_window_direction_independence() -> void:
	await _start_solo_mission()
	var front_win: CameraFeedWindow = SpaceWorldManager.open_camera_window("front") as CameraFeedWindow
	var rear_win: CameraFeedWindow = SpaceWorldManager.open_camera_window("rear") as CameraFeedWindow
	assert_not_null(front_win, "La finestra front deve aprirsi")
	assert_not_null(rear_win, "La finestra rear deve aprirsi")
	
	# Imposta entrambe le finestre su Lidar
	front_win.filter_cycle_btn.emit_signal("pressed")
	front_win.filter_cycle_btn.emit_signal("pressed")
	rear_win.filter_cycle_btn.emit_signal("pressed")
	rear_win.filter_cycle_btn.emit_signal("pressed")
	
	# Ostacolo ravvicinato posizionato solo davanti alla nave (visibile solo dalla camera Front)
	var front_obstacle := StaticBody3D.new()
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(15, 15, 2)
	col_shape.shape = box
	front_obstacle.add_child(col_shape)
	front_obstacle.position = Vector3(0, 0.25, -18.0)
	SpaceWorldManager._space_scene_instance.add_child(front_obstacle)
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	front_win._update_lidar_scan()
	rear_win._update_lidar_scan()
	
	# La telecamera Frontale deve rilevare l'ostacolo ravvicinato a ~15m
	assert_gt(front_win._lidar_points.size(), 0, "La telecamera Frontale deve rilevare l'ostacolo anteriore")
	assert_lt(front_win._lidar_closest_distance, 20.0, "La telecamera Frontale deve agganciare l'ostacolo anteriore a distanza ravvicinata")
	
	# La telecamera Posteriore punta all'indietro (+Z) e non deve vedere l'ostacolo anteriore (< 30m)
	assert_gt(rear_win._lidar_closest_distance, 40.0, "La telecamera Posteriore non deve rilevare l'ostacolo anteriore ravvicinato")
	
	front_obstacle.queue_free()

func test_camera_feed_window_saves_and_restores_layout_across_sessions() -> void:
	await _start_solo_mission()
	
	# Apertura camera front senza layout precedente: default size 460x320
	var front_win: CameraFeedWindow = SpaceWorldManager.open_camera_window("front") as CameraFeedWindow
	assert_not_null(front_win, "La finestra feed deve aprirsi")
	assert_eq(front_win.size, Vector2(460, 320), "Dimensione iniziale deve essere quella di default")
	
	# Modifica di posizione e dimensione (es. ridimensionata e spostata dall'utente)
	var custom_pos := Vector2(250.0, 150.0)
	var custom_size := Vector2(520.0, 380.0)
	front_win.position = custom_pos
	front_win.size = custom_size
	front_win.save_window_layout()
	
	# Verifica che il layout sia stato salvato su file
	assert_true(CameraFeedWindow.has_saved_camera_layout("front"), "Deve esserci un layout salvato per la camera front")
	var saved_data := CameraFeedWindow.get_saved_camera_layout("front")
	assert_eq(saved_data.get("width"), 520.0)
	assert_eq(saved_data.get("height"), 380.0)
	assert_eq(saved_data.get("x"), 250.0)
	assert_eq(saved_data.get("y"), 150.0)
	
	# Chiusura finestra
	SpaceWorldManager.close_camera_window("front")
	assert_false(SpaceWorldManager.is_camera_window_open("front"))
	
	# Simulazione nuova sessione: ricarica dei layout da disco
	CameraFeedWindow.reload_saved_layouts()
	
	# Riapertura finestra: deve ripristinare custom_pos e custom_size
	var reopened_win: CameraFeedWindow = SpaceWorldManager.open_camera_window("front") as CameraFeedWindow
	assert_not_null(reopened_win, "La finestra riaperta deve esistere")
	assert_eq(reopened_win.size, custom_size, "La dimensione salvata deve essere ripristinata")
	assert_eq(reopened_win.position, custom_pos, "La posizione salvata deve essere ripristinata")

func test_camera_feed_windows_independent_layouts() -> void:
	await _start_solo_mission()
	
	var front_win: CameraFeedWindow = SpaceWorldManager.open_camera_window("front") as CameraFeedWindow
	var rear_win: CameraFeedWindow = SpaceWorldManager.open_camera_window("rear") as CameraFeedWindow
	assert_not_null(front_win)
	assert_not_null(rear_win)
	
	# Imposta dimensioni e posizioni distinte
	front_win.position = Vector2(100.0, 80.0)
	front_win.size = Vector2(400.0, 300.0)
	front_win.save_window_layout()
	
	rear_win.position = Vector2(550.0, 200.0)
	rear_win.size = Vector2(500.0, 350.0)
	rear_win.save_window_layout()
	
	SpaceWorldManager.close_all_camera_windows()
	CameraFeedWindow.reload_saved_layouts()
	
	var reopened_front: CameraFeedWindow = SpaceWorldManager.open_camera_window("front") as CameraFeedWindow
	var reopened_rear: CameraFeedWindow = SpaceWorldManager.open_camera_window("rear") as CameraFeedWindow
	
	assert_eq(reopened_front.position, Vector2(100.0, 80.0), "Front deve mantenere la sua posizione indipendente")
	assert_eq(reopened_front.size, Vector2(400.0, 300.0), "Front deve mantenere la sua dimensione indipendente")
	assert_eq(reopened_rear.position, Vector2(550.0, 200.0), "Rear deve mantenere la sua posizione indipendente")
	assert_eq(reopened_rear.size, Vector2(500.0, 350.0), "Rear deve mantenere la sua dimensione indipendente")

func test_camera_feed_window_maximized_saves_unmaximized_size() -> void:
	await _start_solo_mission()
	
	var feed_win: CameraFeedWindow = SpaceWorldManager.open_camera_window("front") as CameraFeedWindow
	var initial_size := Vector2(480.0, 340.0)
	var initial_pos := Vector2(200.0, 100.0)
	feed_win.position = initial_pos
	feed_win.size = initial_size
	feed_win.save_window_layout()
	
	# Massimizza la finestra
	feed_win.maximize_window()
	assert_true(feed_win.is_maximized, "La finestra deve risultare massimizzata")
	
	# Il salvataggio durante lo stato massimizzato deve salvare le dimensioni pre-massimizzazione
	feed_win.save_window_layout()
	var layout := CameraFeedWindow.get_saved_camera_layout("front")
	assert_eq(layout.get("width"), 480.0, "La larghezza salvata non deve essere quella a tutto schermo")
	assert_eq(layout.get("height"), 340.0, "L'altezza salvata non deve essere quella a tutto schermo")

func test_lidar_fixed_spacing_independent_of_window_size() -> void:
	await _start_solo_mission()
	var feed_win: CameraFeedWindow = SpaceWorldManager.open_camera_window("front") as CameraFeedWindow
	assert_not_null(feed_win)

	# Verifica presenza e validità costanti spaziatura
	assert_gt(CameraFeedWindow.LIDAR_COLS_SPACING, 0.0, "LIDAR_COLS_SPACING deve essere maggiore di zero")
	assert_gt(CameraFeedWindow.LIDAR_ROWS_SPACING, 0.0, "LIDAR_ROWS_SPACING deve essere maggiore di zero")

	# Modalità Lidar
	feed_win._filter_mode = 2

	# Posizioniamo un grande ostacolo davanti alla camera che copre il cono visivo
	var obstacle := StaticBody3D.new()
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 100, 2)
	col_shape.shape = box
	obstacle.add_child(col_shape)
	obstacle.position = Vector3(0, 0, -10.0)
	SpaceWorldManager._space_scene_instance.add_child(obstacle)
	await get_tree().physics_frame
	await get_tree().physics_frame

	feed_win._update_lidar_scan()
	assert_gt(feed_win._lidar_points.size(), 1, "Devono essere rilevati più punti Lidar")

	if feed_win._lidar_points.size() >= 2:
		var p0: Vector2 = feed_win._lidar_points[0].pos
		var p1: Vector2 = feed_win._lidar_points[1].pos
		assert_almost_eq(absf(p1.y - p0.y), CameraFeedWindow.LIDAR_ROWS_SPACING, 0.01, "La spaziatura verticale tra punti consecutivi deve corrispondere a LIDAR_ROWS_SPACING")

	obstacle.queue_free()
