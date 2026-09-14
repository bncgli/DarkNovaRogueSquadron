extends GutTest

## Test GUT per verificare che durante il salto Hyperdrive venga attivata
## una transizione in @Applications/Cams (disattivazione/perdita di segnale video),
## e che tale transizione permanga attiva finché tutti i giocatori dell'equipaggio
## non abbiano completato il caricamento della nuova zona.

const START_COORDS := Vector3i(4, 11, 0)
const TARGET_COORDS := Vector3i(4, 12, 0)

var _cams_app: CamsApp = null
var _cam_window: CameraFeedWindow = null

func before_each() -> void:
	NetworkManager.disconnect_game()
	if StarSystemGridManager:
		StarSystemGridManager.load_star_system(StarSystemData.get_default_star_system())
		StarSystemGridManager.set_current_sector_coords(START_COORDS)
		StarSystemGridManager.clear_plotted_route()
	if SpaceWorldManager:
		SpaceWorldManager.configure_initial_station_spawn()
		SpaceWorldManager.close_all_camera_windows()
		SpaceWorldManager.set_ship_connected(true)
		if SpaceWorldManager.is_hyperdrive_transit_active():
			SpaceWorldManager.end_hyperdrive_transition()

func after_each() -> void:
	if is_instance_valid(_cams_app):
		_cams_app.queue_free()
	_cams_app = null
	
	if is_instance_valid(_cam_window):
		_cam_window.queue_free()
	_cam_window = null
	
	if SpaceWorldManager:
		SpaceWorldManager.close_all_camera_windows()
		if SpaceWorldManager.is_hyperdrive_transit_active():
			SpaceWorldManager.end_hyperdrive_transition()
	
	NetworkManager.disconnect_game()

func _create_cams_app() -> CamsApp:
	var scene: PackedScene = load("res://Applications/Cams/cams_app.tscn")
	assert_not_null(scene, "Scena cams_app.tscn deve essere caricabile")
	var app: CamsApp = scene.instantiate() as CamsApp
	add_child_autofree(app)
	await get_tree().process_frame
	return app

func test_hyperdrive_transition_activates_cams_signal_loss() -> void:
	assert_not_null(SpaceWorldManager, "SpaceWorldManager deve esistere")
	
	# Apri la telecamera anteriore
	var win: FakeWindow = SpaceWorldManager.open_camera_window("front")
	assert_not_null(win, "La finestra feed telecamera front deve aprirsi")
	_cam_window = win as CameraFeedWindow
	assert_not_null(_cam_window, "La finestra deve essere di tipo CameraFeedWindow")
	await get_tree().process_frame
	
	assert_false(_cam_window.is_in_hyperdrive_transition, "Inizialmente la telecamera non deve essere in transizione")
	assert_false(_cam_window.hyperdrive_loss_overlay.visible, "L'overlay di perdita segnale deve essere nascosto")
	
	# Avvia transizione Hyperdrive
	SpaceWorldManager.start_hyperdrive_transition(TARGET_COORDS)
	await get_tree().process_frame
	
	assert_true(SpaceWorldManager.is_hyperdrive_transit_active(), "SpaceWorldManager deve segnalare transito attivo")
	assert_true(_cam_window.is_in_hyperdrive_transition, "La telecamera deve essere in modalità perdita segnale")
	assert_true(_cam_window.hyperdrive_loss_overlay.visible, "L'overlay di rumore/perdita segnale deve essere visibile")
	assert_eq(_cam_window.live_badge.text, "● NO SIGNAL", "Il badge deve indicare assenza di segnale")
	assert_true(_cam_window.zoom_in_btn.disabled, "I controlli di zoom devono essere disabilitati durante il transito")

func test_camera_window_opened_during_hyperdrive_shows_signal_loss() -> void:
	assert_not_null(SpaceWorldManager, "SpaceWorldManager deve esistere")
	
	# Avvia transizione Hyperdrive prima di aprire la telecamera
	SpaceWorldManager.start_hyperdrive_transition(TARGET_COORDS)
	assert_true(SpaceWorldManager.is_hyperdrive_transit_active(), "Transito deve essere attivo")
	
	var win: FakeWindow = SpaceWorldManager.open_camera_window("rear")
	assert_not_null(win, "La finestra feed telecamera rear deve aprirsi")
	_cam_window = win as CameraFeedWindow
	await get_tree().process_frame
	
	assert_true(_cam_window.is_in_hyperdrive_transition, "La nuova finestra deve entrare subito in stato di perdita segnale")
	assert_true(_cam_window.hyperdrive_loss_overlay.visible, "L'overlay deve risultare visibile all'apertura durante il warp")

func test_cams_app_ui_tracks_multiplayer_crew_zone_loading_progress() -> void:
	_cams_app = await _create_cams_app()
	assert_not_null(_cams_app, "CamsApp deve essere istanziata")
	
	# Simula 3 giocatori connessi in equipaggio
	SpaceWorldManager.start_hyperdrive_transition(TARGET_COORDS)
	SpaceWorldManager.set_pending_hyperdrive_players([1, 2, 3])
	await get_tree().process_frame
	
	assert_true(_cams_app.hyperdrive_transit_banner.visible, "Il banner Hyperdrive deve essere visibile in CamsApp")
	assert_eq(_cams_app.active_count_badge.text, "IPERDRIVE", "Il badge contatore deve indicare IPERDRIVE")
	assert_true("0 / 3" in _cams_app.hyperdrive_crew_sync_label.text or "0" in _cams_app.hyperdrive_crew_sync_label.text)
	
	# Giocatore 1 (Host) completa il caricamento della nuova zona
	SpaceWorldManager.report_player_zone_loaded(1, TARGET_COORDS)
	await get_tree().process_frame
	
	assert_true(SpaceWorldManager.is_hyperdrive_transit_active(), "La transizione deve rimanere attiva perché mancano gli altri membri")
	assert_true("1 / 3" in _cams_app.hyperdrive_crew_sync_label.text, "Il testo deve mostrare 1 / 3 membri pronti")
	assert_true(_cams_app.hyperdrive_transit_banner.visible, "Il banner deve rimanere visibile")
	
	# Giocatore 2 completa il caricamento
	SpaceWorldManager.report_player_zone_loaded(2, TARGET_COORDS)
	await get_tree().process_frame
	
	assert_true(SpaceWorldManager.is_hyperdrive_transit_active(), "La transizione deve rimanere attiva (2/3 pronti)")
	assert_true("2 / 3" in _cams_app.hyperdrive_crew_sync_label.text, "Il testo deve mostrare 2 / 3 membri pronti")
	
	# Giocatore 3 (ultimo) completa il caricamento della nuova zona
	SpaceWorldManager.report_player_zone_loaded(3, TARGET_COORDS)
	await get_tree().process_frame
	
	# Tutti i giocatori hanno caricato: la transizione DEVE terminare!
	assert_false(SpaceWorldManager.is_hyperdrive_transit_active(), "La transizione Hyperdrive deve terminare ora che tutti i giocatori sono pronti")
	assert_false(_cams_app.hyperdrive_transit_banner.visible, "Il banner Hyperdrive deve nascondersi")
	assert_ne(_cams_app.active_count_badge.text, "IPERDRIVE", "Il badge contatore deve tornare allo stato normale")

func test_player_leaving_during_transit_triggers_completion_if_others_ready() -> void:
	# 2 giocatori in equipaggio
	SpaceWorldManager.start_hyperdrive_transition(TARGET_COORDS)
	SpaceWorldManager.set_pending_hyperdrive_players([1, 2])
	await get_tree().process_frame
	
	# Giocatore 1 carica la zona
	SpaceWorldManager.report_player_zone_loaded(1, TARGET_COORDS)
	assert_true(SpaceWorldManager.is_hyperdrive_transit_active(), "Transito ancora attivo (1/2)")
	
	# Giocatore 2 perde la connessione / abbandona
	SpaceWorldManager._on_network_player_left(2)
	await get_tree().process_frame
	
	# Rimane solo il giocatore 1 che è già pronto: la transizione deve concludersi
	assert_false(SpaceWorldManager.is_hyperdrive_transit_active(), "Transito deve concludersi quando l'unico giocatore rimasto ha caricato la zona")
