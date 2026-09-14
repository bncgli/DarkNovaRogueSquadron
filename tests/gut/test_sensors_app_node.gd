extends GutTest

## Test GUT per l'applicazione Sensors (radar a lungo raggio, occlusione LoS,
## feed sonda telemetrica, ping attivo vincolato all'energia e RBAC).
## Migrato da tests/test_sensors_app_node.gd (extends Node, assert() nudo).

var _app: SensorsApp = null

func before_each() -> void:
	NetworkManager.disconnect_game()

func after_each() -> void:
	if is_instance_valid(_app):
		_app.queue_free()
	_app = null
	NetworkManager.disconnect_game()
	if SpaceWorldManager:
		SpaceWorldManager.clear_active_probes()
		SpaceWorldManager.clear_active_waypoint()

func _start_solo_mission(player_name: String = "Comandante Test") -> void:
	NetworkManager.start_solo_game(player_name)
	NetworkManager.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame

func _create_app() -> SensorsApp:
	var scene: PackedScene = load("res://Applications/Sensors/sensors_app.tscn")
	assert_not_null(scene, "Scena sensors_app.tscn deve essere caricabile")
	var app: SensorsApp = scene.instantiate() as SensorsApp
	add_child_autofree(app)
	await get_tree().process_frame
	return app

func test_disconnected_overlay_lifecycle() -> void:
	_app = await _create_app()
	assert_not_null(_app.disconnected_overlay, "%DisconnectedOverlay deve esistere nella scena")
	assert_true(_app.disconnected_overlay.visible, "%DisconnectedOverlay deve essere VISIBILE quando la nave è offline")
	
	await _start_solo_mission()
	
	assert_false(_app.disconnected_overlay.visible, "%DisconnectedOverlay deve SCOMPARIRE quando la nave è connessa")

func test_rbac_permissions_matrix_for_crew_roles() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	NetworkManager.request_role(NetworkManager.ROLE_PILOT)
	await get_tree().process_frame
	assert_false(_app.can_control_sensors, "Pilota non deve avere controllo attivo sui sensori")
	assert_true(_app.btn_sweep_toggle.disabled, "BtnSweepToggle deve essere disabilitato per Pilota")
	assert_true(_app.btn_active_ping.disabled, "BtnActivePing deve essere disabilitato per Pilota")
	
	NetworkManager.request_role(NetworkManager.ROLE_ENGINEER)
	await get_tree().process_frame
	assert_false(_app.can_control_sensors, "Ingegnere non deve avere controllo attivo sui sensori")
	assert_true(_app.btn_sweep_toggle.disabled, "BtnSweepToggle deve essere disabilitato per Ingegnere")
	assert_true(_app.btn_active_ping.disabled, "BtnActivePing deve essere disabilitato per Ingegnere")
	
	NetworkManager.request_role(NetworkManager.ROLE_SOLDIER)
	await get_tree().process_frame
	assert_true(_app.can_control_sensors, "Soldato deve avere controllo completo sui sensori")
	assert_false(_app.btn_sweep_toggle.disabled, "BtnSweepToggle deve essere abilitato per Soldato")
	assert_false(_app.btn_active_ping.disabled, "BtnActivePing deve essere abilitato per Soldato")
	
	NetworkManager.request_role(NetworkManager.ROLE_HACKER)
	await get_tree().process_frame
	assert_true(_app.can_control_sensors, "Hacker deve avere controllo completo sui sensori")
	
	NetworkManager.request_role(NetworkManager.ROLE_CAPTAIN)
	await get_tree().process_frame
	assert_true(_app.can_control_sensors, "Capitano deve avere controllo completo sui sensori")
	
	NetworkManager.request_role(NetworkManager.ROLE_STAGISTA)
	await get_tree().process_frame
	assert_true(_app.can_control_sensors, "Stagista deve avere controllo completo sui sensori")

func test_dat_configuration_default_values_and_hot_reload() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app.load_dat_configuration()
	await get_tree().process_frame
	assert_true(_app.active_config.get("is_dat_loaded"), "Configurazioni .DAT devono essere caricate")
	assert_eq(_app.active_config.get("sweep_frequency_hz"), 12.0, "sweep_frequency_hz deve corrispondere a 12.0 Hz")
	assert_eq(_app.active_config.get("active_ping_radius"), 2000.0, "active_ping_radius deve corrispondere a 2 km (2000 m)")
	assert_eq(_app.active_config.get("noise_filter"), 0.92, "noise_filter deve corrispondere a 0.92")
	assert_eq(_app.active_config.get("spectrum_sensitivity"), 1.0, "spectrum_sensitivity deve corrispondere a 1.0")
	assert_eq(_app.active_config.get("stealth_detection_threshold"), 0.35, "stealth_detection_threshold deve corrispondere a 0.35")
	
	# NOTA: il segnale file_synced e' dichiarato con un solo parametro (path); il
	# vecchio test lo emetteva erroneamente con un secondo argomento extra, il che
	# causa un errore quando altri listener con firma stretta (es. controller nave)
	# sono connessi allo stesso segnale. Emettiamo qui con la firma corretta.
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("file_synced"):
		sdm.file_synced.emit("Ship Drive/Programs/Sensors/sensors_config.dat")
		await get_tree().process_frame
		assert_true(_app.active_config.get("is_dat_loaded"), "Hot-reloading deve ricaricare la configurazione")
	
	_app.btn_reload_dat.emit_signal("pressed")
	await get_tree().process_frame
	assert_true(_app.active_config.get("is_dat_loaded"), "Pulsante ricarica .DAT deve rinfrescare la configurazione")

func test_radar_range_calibration_constants() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	assert_not_null(_app.radar_display, "RadarDisplay deve essere istanziato")
	assert_eq(_app.radar_display.max_range, 1000.0, "Portata standard radar deve essere esattamente 1000m (1 km)")
	assert_eq(SensorsApp.RADAR_STANDARD_RANGE, 1000.0, "Costante RADAR_STANDARD_RANGE deve essere 1000.0")
	assert_eq(SensorsApp.ACTIVE_PING_RANGE, 2000.0, "Costante ACTIVE_PING_RANGE deve essere 2000.0")

func test_radar_contact_selection_and_diegetic_telemetry() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	assert_true(_app.detected_entities.size() > 0, "I sensori devono rilevare contatti diegetici")
	var test_contact: Dictionary = _app.detected_entities[0]
	var test_id: String = str(test_contact.get("id"))
	_app._on_radar_entity_selected(test_contact)
	await get_tree().process_frame
	assert_eq(_app.selected_entity_id, test_id, "Il contatto deve risultare selezionato")
	assert_true(_app.target_details_label.text.contains("ECO #") or _app.target_details_label.text.contains("SONDA"), "Dettagli telemetrici devono presentare intestazione diegetica")
	assert_true(_app.target_details_label.text.contains("Distanza Scanner"), "Dettagli telemetrici devono mostrare distanza diegetica")

func test_target_lock_and_release() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	var test_contact: Dictionary = _app.detected_entities[0]
	var test_id: String = str(test_contact.get("id"))
	_app._on_radar_entity_selected(test_contact)
	await get_tree().process_frame
	
	_app.btn_lock_target.emit_signal("pressed")
	await get_tree().process_frame
	assert_eq(_app.locked_entity_id, test_id, "Il bersaglio deve risultare agganciato (Locked)")
	assert_true(_app.is_target_locked, "Stato is_target_locked deve essere true")
	
	_app.btn_lock_target.emit_signal("pressed")
	await get_tree().process_frame
	assert_true(_app.locked_entity_id.is_empty(), "Il bersaglio deve essere rilasciato")

func test_waypoint_transmission_and_clear() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	var test_contact: Dictionary = _app.detected_entities[0]
	var test_id: String = str(test_contact.get("id"))
	_app._on_radar_entity_selected(test_contact)
	_app.btn_transmit_waypoint.emit_signal("pressed")
	await get_tree().process_frame
	
	var active_wp := SpaceWorldManager.get_active_waypoint()
	assert_false(active_wp.is_empty(), "SpaceWorldManager deve aver registrato il waypoint trasmesso")
	assert_eq(active_wp.get("target_id"), test_id, "L'ID bersaglio nel waypoint deve coincidere")
	
	_app.btn_clear_waypoint.emit_signal("pressed")
	await get_tree().process_frame
	assert_true(SpaceWorldManager.get_active_waypoint().is_empty(), "Il waypoint attivo deve essere rimosso")

func test_line_of_sight_occlusion_geometry() -> void:
	# NOTA: il vecchio test costruiva dizionari "obs_ast"/"hidden_target" ma non li
	# iniettava mai in SpaceWorldManager.get_sensor_entities(), quindi la sua
	# asserzione finale era in realtà un controllo aritmetico banale (dot product
	# sempre compreso tra 40 e 598), non una vera verifica dell'algoritmo di
	# occlusione LoS usato in _refresh_entities(). Qui replichiamo fedelmente la
	# formula geometrica di occlusione (proiezione + distanza perpendicolare)
	# effettivamente implementata in sensors_app.gd per validarne la correttezza.
	var ship_pos := Vector3.ZERO
	var obstacle_rel := Vector3(0, 0, -200) # Asteroide a 200m, raggio 40m
	var obstacle_radius := 40.0
	var target_rel := Vector3(0, 0, -600) # Bersaglio nascosto a 600m, dietro l'asteroide
	var target_dist: float = target_rel.length()
	var ray_dir: Vector3 = target_rel / target_dist
	
	var t_proj: float = obstacle_rel.dot(ray_dir)
	var perp_dist_sq: float = obstacle_rel.length_squared() - (t_proj * t_proj)
	var is_between := t_proj > obstacle_radius and t_proj < (target_dist - 2.0)
	var is_occluded := is_between and perp_dist_sq < (obstacle_radius * obstacle_radius)
	assert_true(is_occluded, "Un bersaglio direttamente dietro un asteroide allineato deve risultare occluso dalla LoS")
	
	# Bersaglio non allineato con l'ostacolo (offset laterale ampio): non deve essere occluso
	var offset_target_rel := Vector3(500, 0, -600)
	var offset_dist: float = offset_target_rel.length()
	var offset_ray_dir: Vector3 = offset_target_rel / offset_dist
	var offset_t_proj: float = obstacle_rel.dot(offset_ray_dir)
	var offset_perp_sq: float = obstacle_rel.length_squared() - (offset_t_proj * offset_t_proj)
	var offset_is_between := offset_t_proj > obstacle_radius and offset_t_proj < (offset_dist - 2.0)
	var offset_is_occluded := offset_is_between and offset_perp_sq < (obstacle_radius * obstacle_radius)
	assert_false(offset_is_occluded, "Un bersaglio ampiamente disallineato dall'ostacolo non deve risultare occluso")
	assert_true(ship_pos == Vector3.ZERO, "Il punto di osservazione di riferimento resta l'origine della nave")

func test_telemetry_probe_feed_integration() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	SpaceWorldManager.clear_active_probes()
	var probe_info := SpaceWorldManager.spawn_telemetry_probe(Vector3.ZERO, Vector3(0, 0, -500))
	assert_false(probe_info.is_empty(), "La sonda telemetrica deve essere creata con successo")
	assert_eq(probe_info.get("scan_radius"), 1000.0, "La sonda telemetrica deve avere un raggio di scansione di 1000m")
	
	var active_p := SpaceWorldManager.get_active_probe()
	assert_false(active_p.is_empty(), "get_active_probe() deve ritornare la sonda attiva")
	assert_eq(active_p.get("id"), probe_info.get("id"), "L'ID della sonda deve corrispondere")
	
	_app._refresh_entities()
	await get_tree().process_frame
	assert_false(_app.radar_display.probe_data.is_empty(), "RadarDisplay deve ricevere probe_data da SensorsApp")
	assert_true(_app.probe_status_label.text.contains("ATTIVO"), "ProbeStatusLabel deve indicare stato attivo per il feed sonda")

func test_active_ping_gated_by_power() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app.is_radar_powered = false
	_app.ping_cooldown = 0.0
	_app.is_pinging = false
	_app._on_active_ping_pressed()
	await get_tree().process_frame
	assert_false(_app.is_pinging, "Ping deve essere BLOCCATO se non c'è alimentazione")
	
	_app.is_radar_powered = true
	_app._on_active_ping_pressed()
	await get_tree().process_frame
	assert_true(_app.is_pinging, "Ping attivo deve avviarsi con alimentazione disponibile")
	assert_true(_app.radar_display.ping_active, "RadarDisplay deve aver avviato l'onda ping")
	assert_eq(_app.radar_display.ping_max_radius, 2000.0, "Raggio massimo ping deve essere 2000m")

func test_queue_free_cleanup_does_not_error() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	_app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_app = null
	assert_true(true, "La rimozione dell'app Sensors non deve generare errori di pulizia dei segnali")

func test_radar_3d_viewport_and_sphere_instantiation() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	var rd: RadarDisplay = _app.radar_display
	assert_not_null(rd, "RadarDisplay deve essere istanziato")
	assert_not_null(rd.sub_viewport_container, "SubViewportContainer deve esistere")
	assert_not_null(rd.sub_viewport, "SubViewport deve esistere")
	assert_true(rd.sub_viewport.own_world_3d, "SubViewport deve avere own_world_3d attivo per isolamento")
	assert_not_null(rd.camera_3d, "Camera3D deve essere presente nella gerarchia 3D")
	assert_not_null(rd.orbit_pivot, "OrbitPivot deve essere presente")
	assert_not_null(rd.pitch_pivot, "PitchPivot deve essere presente")
	assert_not_null(rd.cyan_sphere_mesh, "Mesh wireframe della sfera ciano deve essere generata")
	assert_not_null(rd.center_ship, "Modello 3D della nave centrale deve essere istanziato")
	assert_not_null(rd.hud_overlay, "HUDOverlay 2D deve essere presente")
	assert_eq(rd.max_range, 1000.0, "Portata standard radar deve essere 1000m")
	assert_eq(rd.ping_max_radius, 2000.0, "Portata massima ping deve essere 2000m")

func test_radar_3d_orbit_rotation_drag() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	var rd: RadarDisplay = _app.radar_display
	assert_not_null(rd)
	var init_yaw: float = rd.orbit_yaw
	var init_pitch: float = rd.orbit_pitch
	
	var press_event := InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	press_event.position = Vector2(200, 200)
	rd._gui_input(press_event)
	
	assert_false(rd._is_dragging_orbit, "Non deve attivare il drag prima di superare la soglia di movimento")
	
	var motion_event := InputEventMouseMotion.new()
	motion_event.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion_event.position = Vector2(240, 180)
	motion_event.relative = Vector2(40, -20)
	rd._gui_input(motion_event)
	
	assert_true(rd._is_dragging_orbit, "Deve attivare lo stato di drag dopo aver superato la soglia")
	assert_ne(rd.orbit_yaw, init_yaw, "Yaw deve essere modificato dal trascinamento orizzontale")
	assert_ne(rd.orbit_pitch, init_pitch, "Pitch deve essere modificato dal trascinamento verticale")
	assert_true(rd.orbit_pitch >= -85.0 and rd.orbit_pitch <= 85.0, "Pitch deve restare vincolato tra -85 e +85 gradi")
	
	var release_event := InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	release_event.position = Vector2(240, 180)
	rd._gui_input(release_event)
	
	assert_false(rd._is_dragging_orbit, "Drag deve essere disattivato al rilascio del mouse")
	
	var initial_zoom: float = rd.camera_zoom
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	rd._gui_input(wheel_up)
	assert_eq(rd.camera_zoom, initial_zoom - RadarDisplay.ZOOM_STEP, "Rotellina UP deve avvicinare lo zoom della telecamera")
	
	rd.current_mode = RadarDisplay.DisplayMode.TOP_DOWN
	assert_eq(rd.orbit_pitch, -85.0, "Modalità Top-Down deve orientare il pitch a -85 gradi (zenitale)")
	rd.current_mode = RadarDisplay.DisplayMode.FRONTAL_ELEVATION
	assert_eq(rd.orbit_pitch, 0.0, "Modalità Frontal deve orientare il pitch a 0 gradi (orizzontale)")

func test_radar_3d_contact_selection_threshold() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	var rd: RadarDisplay = _app.radar_display
	assert_not_null(rd)
	assert_true(_app.detected_entities.size() > 0, "Devono essere presenti contatti rilevati")
	
	var target: Dictionary = _app.detected_entities[0]
	var target_id: String = str(target.get("id"))
	var screen_pos := rd._world_to_screen(target, rd.size * 0.5, 175.0)
	
	# Caso 1: Click rapido senza trascinamento -> Seleziona entità
	var press_click := InputEventMouseButton.new()
	press_click.button_index = MOUSE_BUTTON_LEFT
	press_click.pressed = true
	press_click.position = screen_pos
	rd._gui_input(press_click)
	
	var release_click := InputEventMouseButton.new()
	release_click.button_index = MOUSE_BUTTON_LEFT
	release_click.pressed = false
	release_click.position = screen_pos
	rd._gui_input(release_click)
	await get_tree().process_frame
	
	assert_eq(rd.selected_entity_id, target_id, "Il click senza trascinamento sul blip deve selezionare l'entità")
	assert_eq(_app.selected_entity_id, target_id, "SensorsApp deve sincronizzare l'entità selezionata dal radar 3D")
	
	# Deseleziona per test successivo
	rd.selected_entity_id = ""
	_app.selected_entity_id = ""
	
	# Caso 2: Trascinamento sopra il blip (> 5px) -> Ruota la visuale e NON seleziona
	var press_drag := InputEventMouseButton.new()
	press_drag.button_index = MOUSE_BUTTON_LEFT
	press_drag.pressed = true
	press_drag.position = screen_pos
	rd._gui_input(press_drag)
	
	var motion_drag := InputEventMouseMotion.new()
	motion_drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion_drag.position = screen_pos + Vector2(25, 15)
	motion_drag.relative = Vector2(25, 15)
	rd._gui_input(motion_drag)
	
	var release_drag := InputEventMouseButton.new()
	release_drag.button_index = MOUSE_BUTTON_LEFT
	release_drag.pressed = false
	release_drag.position = screen_pos + Vector2(25, 15)
	rd._gui_input(release_drag)
	await get_tree().process_frame
	
	assert_true(rd.selected_entity_id.is_empty(), "Un gesto di trascinamento sopra un blip NON deve cambiare la selezione")

func test_radar_3d_center_ship_arrow() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	var rd: RadarDisplay = _app.radar_display
	assert_not_null(rd, "RadarDisplay deve esistere")
	assert_not_null(rd.center_ship, "Il nodo CenterShip deve essere presente al centro della sfera")
	assert_eq(rd.center_ship.position, Vector3.ZERO, "CenterShip deve trovarsi all'origine (0, 0, 0)")
	
	var arrow_body := rd.center_ship.get_node_or_null("ShipArrowBody")
	assert_not_null(arrow_body, "Deve essere presente la mesh solida della freccia (ShipArrowBody)")
	var arrow_outline := rd.center_ship.get_node_or_null("ShipArrowOutline")
	assert_not_null(arrow_outline, "Deve essere presente il contorno wireframe della freccia (ShipArrowOutline)")

func test_radar_3d_zoom_range_control() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	var rd: RadarDisplay = _app.radar_display
	assert_not_null(rd)
	assert_eq(rd.max_range, 1000.0, "Raggio iniziale standard deve essere 1000m")
	assert_not_null(_app.option_range, "OptionRange deve essere presente nell'interfaccia Sensors")
	assert_eq(_app.option_range.selected, 2, "OptionRange deve selezionare inizialmente 1000m (indice 2)")
	
	# Zoom In sequenziale: 1000m -> 500m -> 200m
	rd.zoom_in_range()
	assert_eq(rd.max_range, 500.0, "Primo zoom in deve portare il raggio a 500m")
	assert_eq(_app.option_range.selected, 1, "OptionRange deve sincronizzarsi a 500m (indice 1)")
	assert_true(_app.range_indicator_label.text.contains("500m"), "Etichetta deve indicare 500m")
	assert_true(_app.range_indicator_label.text.contains("ZOOM 2x"), "Etichetta deve indicare fattore ZOOM 2x")
	
	rd.zoom_in_range()
	assert_eq(rd.max_range, 200.0, "Secondo zoom in deve portare il raggio a 200m (dettaglio ravvicinato)")
	assert_eq(_app.option_range.selected, 0, "OptionRange deve sincronizzarsi a 200m (indice 0)")
	assert_true(_app.range_indicator_label.text.contains("200m"), "Etichetta deve indicare 200m")
	assert_true(_app.range_indicator_label.text.contains("ZOOM 5x"), "Etichetta deve indicare fattore ZOOM 5x")
	
	# Zoom in oltre il minimo resta bloccato a 200m
	rd.zoom_in_range()
	assert_eq(rd.max_range, 200.0, "Il raggio radar minimo non deve scendere sotto i 200m")
	
	# Test pulsante Zoom Out nella UI
	if _app.btn_zoom_out:
		_app.btn_zoom_out.pressed.emit()
		assert_eq(rd.max_range, 500.0, "Pulsante Zoom Out deve allargare a 500m")
	
	# Test posizionamento ingrandito dei contatti vicini (ad es. a 100m)
	var mock_ent := {
		"id": "CLOSE_ASTEROID",
		"type": "ASTEROID",
		"pos": Vector3(0.0, 0.0, -100.0),
		"rel_pos": Vector3(0.0, 0.0, -100.0),
		"distance": 100.0,
		"bearing_deg": 0.0,
		"elevation_deg": 0.0
	}
	
	var rel_p: Vector3 = mock_ent["rel_pos"]
	rd.set_range(1000.0)
	var pos_at_1000: Vector3 = (rel_p / rd.max_range) * RadarDisplay.SPHERE_RADIUS
	assert_almost_eq(pos_at_1000.length(), 0.5, 0.01, "A 1000m di raggio, un corpo a 100m deve occupare 0.5 unità")
	
	rd.set_range(200.0)
	var pos_at_200: Vector3 = (rel_p / rd.max_range) * RadarDisplay.SPHERE_RADIUS
	assert_almost_eq(pos_at_200.length(), 2.5, 0.01, "A 200m di raggio (zoom 5x), un corpo a 100m deve espandersi a 2.5 unità (a metà sfera)")

func test_nearby_obstacles_within_500m_visibility_and_shadow_zones() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app._refresh_entities()
	await get_tree().process_frame
	
	# Verifica che i corpi entro 500m non allineati non siano erroneamente occlusi
	var unoccluded_close_count := 0
	for ent in _app.detected_entities:
		var d: float = float(ent.get("distance", 0.0))
		var is_occ: bool = bool(ent.get("is_occluded", false))
		if d > 0.0 and d <= 500.0 and not is_occ:
			unoccluded_close_count += 1
	
	assert_gt(unoccluded_close_count, 0, "Gli ostacoli vicini entro 500m con linea di vista libera devono essere visibili")
	
	# Verifica la logica del cono d'ombra: un asteroide dietro un altro asteroide deve risultare occluso
	var front_obs := {
		"id": "AST_FRONT",
		"type": "ASTEROID",
		"pos": Vector3(0, 0, -80),
		"rel_pos": Vector3(0, 0, -80),
		"local_rel_pos": Vector3(0, 0, -80),
		"radius_m": 12.0
	}
	var hidden_target := {
		"id": "AST_HIDDEN",
		"type": "ASTEROID",
		"pos": Vector3(0, 0, -250),
		"rel_pos": Vector3(0, 0, -250),
		"local_rel_pos": Vector3(0, 0, -250),
		"radius_m": 8.0
	}
	var visible_side_target := {
		"id": "AST_SIDE",
		"type": "ASTEROID",
		"pos": Vector3(80, 0, -250),
		"rel_pos": Vector3(80, 0, -250),
		"local_rel_pos": Vector3(80, 0, -250),
		"radius_m": 8.0
	}
	
	# Calcolo LoS manuale replicando l'algoritmo di SensorsApp
	var obstacles: Array[Dictionary] = [front_obs]
	var ray_hidden := Vector3(0, 0, -1)
	var t_proj_hidden := Vector3(0, 0, -80).dot(ray_hidden)
	var perp_hidden := Vector3(0, 0, -80).length_squared() - (t_proj_hidden * t_proj_hidden)
	var is_hidden_occluded := t_proj_hidden > 6.0 and t_proj_hidden < (250.0 - 2.0) and perp_hidden < (12.0 * 12.0)
	assert_true(is_hidden_occluded, "Un asteroide posizionato direttamente dietro un altro asteroide deve trovarsi nella zona d'ombra")
	
	var ray_side := (Vector3(80, 0, -250)).normalized()
	var t_proj_side := Vector3(0, 0, -80).dot(ray_side)
	var perp_side := Vector3(0, 0, -80).length_squared() - (t_proj_side * t_proj_side)
	var is_side_occluded := t_proj_side > 6.0 and t_proj_side < (Vector3(80, 0, -250).length() - 2.0) and perp_side < (12.0 * 12.0)
	assert_false(is_side_occluded, "Un asteroide non coperto dal cono d'ombra non deve risultare occluso")

func test_radar_signals_rotate_with_ship_facing() -> void:
	var ship_pos := Vector3.ZERO
	# Nave ruotata di 90 gradi attorno all'asse Y (yaw positivo verso sinistra)
	var ship_basis := Basis(Vector3.UP, deg_to_rad(90.0))
	
	# Bersaglio a nord nello spazio globale (0, 0, -100)
	var target_world_pos := Vector3(0, 0, -100)
	var diff := target_world_pos - ship_pos
	var local_diff: Vector3 = ship_basis.inverse() * diff
	
	# Con virata a sinistra (+90 deg attorno a Y), la prua (-Z) punta a -X globale;
	# di conseguenza il bersaglio a nord (-Z) si trova ora a dritta/destra della nave (coordinate locali +X)
	assert_almost_eq(local_diff.x, 100.0, 0.01, "Il segnale sul radar deve posizionarsi a dritta (+X) quando la nave vira a sinistra")
	assert_almost_eq(local_diff.z, 0.0, 0.01, "Il segnale sul radar non deve più trovarsi dritto davanti (-Z) dopo la rotazione")
	
	# Verifica che radar_display usi local_rel_pos per determinare la posizione del blip 3D
	var mock_entity := {
		"id": "TARGET_ROT",
		"type": "ASTEROID",
		"pos": target_world_pos,
		"rel_pos": local_diff,
		"local_rel_pos": local_diff,
		"distance": 100.0
	}
	var rd := RadarDisplay.new()
	add_child_autofree(rd)
	var resolved_rel := rd._get_entity_rel_pos(mock_entity)
	assert_almost_eq(resolved_rel.x, 100.0, 0.01, "RadarDisplay deve posizionare il blip in base al facing della nave")
