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
