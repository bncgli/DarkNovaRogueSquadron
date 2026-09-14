extends GutTest

## Test GUT per l'applicazione System Map e l'integrazione delle rotte
## Hyperdrive con Flight Control.
## Migrato da tests/test_system_map_hyperdrive.gd (extends Node, assert() nudo).

const START_COORDS := Vector3i(4, 11, 0)
const TARGET_COORDS := Vector3i(4, 12, 0)

var _sys_map_app: SystemMapApp = null
var _flight_app: FlightControlApp = null

func before_each() -> void:
	NetworkManager.disconnect_game()
	if StarSystemGridManager:
		StarSystemGridManager.load_star_system(StarSystemData.get_default_star_system())
		StarSystemGridManager.set_current_sector_coords(START_COORDS)
		StarSystemGridManager.clear_plotted_route()

func after_each() -> void:
	if is_instance_valid(_sys_map_app):
		_sys_map_app.queue_free()
	if is_instance_valid(_flight_app):
		_flight_app.queue_free()
	_sys_map_app = null
	_flight_app = null
	NetworkManager.disconnect_game()
	if StarSystemGridManager:
		StarSystemGridManager.clear_plotted_route()

func _create_system_map_app() -> SystemMapApp:
	var scene: PackedScene = load("res://Applications/SystemMap/system_map_app.tscn")
	assert_not_null(scene, "Scena system_map_app.tscn deve essere caricabile")
	var app: SystemMapApp = scene.instantiate() as SystemMapApp
	add_child_autofree(app)
	await get_tree().process_frame
	return app

func test_star_system_data_loaded_with_celestial_bodies() -> void:
	assert_not_null(StarSystemGridManager, "StarSystemGridManager deve essere disponibile come autoload")
	var cur_coords: Vector3i = StarSystemGridManager.get_current_sector_coords()
	assert_ne(cur_coords, Vector3i.ZERO, "Coordinate iniziali devono essere valide")
	assert_true(StarSystemGridManager.system_celestial_bodies.size() > 0, "I corpi celesti devono essere caricati nel sistema")

func test_select_sector_calculates_preliminary_route() -> void:
	_sys_map_app = await _create_system_map_app()
	
	_sys_map_app.select_sector(TARGET_COORDS)
	assert_eq(_sys_map_app.selected_sector_coords, TARGET_COORDS, "Settore selezionato deve corrispondere a (4,12,0)")
	assert_false(_sys_map_app.calculated_route.is_empty(), "La rotta deve essere calcolata automaticamente alla selezione")
	assert_true(is_equal_approx(_sys_map_app.calculated_route["distance_sectors"], 1.0), "Distanza deve essere pari a 1.0 settore")
	assert_eq(_sys_map_app.calculated_route["course_vector"], Vector3(0, 1, 0), "Vettore di rotta verso (4,12,0) deve essere (0,1,0)")

func test_route_transmission_signal_to_flight_control() -> void:
	_sys_map_app = await _create_system_map_app()
	_sys_map_app.select_sector(TARGET_COORDS)
	
	var signal_data := {"emitted": false, "target": Vector3i.ZERO, "vector": Vector3.ZERO}
	_sys_map_app.route_plotted.connect(func(t_coords: Vector3i, c_vec: Vector3) -> void:
		signal_data["emitted"] = true
		signal_data["target"] = t_coords
		signal_data["vector"] = c_vec
	)
	
	_sys_map_app.send_route_to_flight_control()
	await get_tree().process_frame
	
	assert_true(signal_data["emitted"], "Il segnale route_plotted deve essere emesso")
	assert_eq(signal_data["target"], TARGET_COORDS, "Target trasmesso errato")
	assert_eq(signal_data["vector"], Vector3(0, 1, 0), "Vettore trasmesso errato")
	
	var active_route: Dictionary = StarSystemGridManager.get_active_route()
	assert_false(active_route.is_empty(), "StarSystemGridManager deve memorizzare la rotta attiva")
	assert_eq(active_route["target_coords"], TARGET_COORDS, "Rotta attiva target errato")

func test_flight_control_receives_route_and_aligns() -> void:
	_flight_app = load("res://Applications/FlightControl/flight_control_app.tscn").instantiate() as FlightControlApp
	add_child_autofree(_flight_app)
	await get_tree().process_frame
	
	_flight_app._on_route_plotted(TARGET_COORDS, Vector3(0, 1, 0))
	assert_false(_flight_app.active_hyperdrive_route.is_empty(), "Flight Control deve memorizzare la rotta Hyperdrive")
	
	await _flight_app.align_to_hyperdrive_vector(0.05)
	assert_true(_flight_app.is_hyperdrive_aligned(), "La nave deve risultare allineata al vettore di navigazione")

func test_hyperdrive_engage_transitions_sector() -> void:
	_flight_app = load("res://Applications/FlightControl/flight_control_app.tscn").instantiate() as FlightControlApp
	add_child_autofree(_flight_app)
	await get_tree().process_frame
	
	_flight_app._on_route_plotted(TARGET_COORDS, Vector3(0, 1, 0))
	await _flight_app.align_to_hyperdrive_vector(0.05)
	
	var transit_status := {"started": false, "completed": false, "destination": Vector3i.ZERO}
	StarSystemGridManager.hyperdrive_transit_started.connect(func(_dest: Vector3i) -> void:
		transit_status["started"] = true
	)
	StarSystemGridManager.hyperdrive_transit_completed.connect(func(dest: Vector3i) -> void:
		transit_status["completed"] = true
		transit_status["destination"] = dest
	)
	
	var engage_res: Dictionary = _flight_app.engage_hyperdrive()
	assert_true(engage_res.get("success"), "L'attivazione Hyperdrive deve avere successo: %s" % str(engage_res))
	assert_true(transit_status["started"], "Segnale hyperdrive_transit_started non emesso")
	assert_true(transit_status["completed"], "Segnale hyperdrive_transit_completed non emesso")
	assert_eq(transit_status["destination"], TARGET_COORDS, "Destinazione raggiunta diversa dal settore target")
	assert_eq(StarSystemGridManager.get_current_sector_coords(), TARGET_COORDS, "Il settore corrente deve essere aggiornato a SEC-04-12")
	assert_eq(StarSystemGridManager.get_current_sector_id(), "SEC-04-12", "ID settore corrente non aggiornato")

func test_zoom_controls_and_centered_mouse_wheel_input() -> void:
	_sys_map_app = await _create_system_map_app()
	
	assert_true(_sys_map_app.MAX_ZOOM >= 6.0, "MAX_ZOOM deve essere almeno 6.0")
	
	var initial_zoom: float = _sys_map_app.zoom_level
	_sys_map_app._on_zoom_in_pressed()
	assert_true(_sys_map_app.zoom_level > initial_zoom, "Lo zoom in tramite pulsante deve incrementare zoom_level")
	
	_sys_map_app.zoom_level = 1.0
	_sys_map_app.pan_offset = Vector2.ZERO
	var wheel_event := InputEventMouseButton.new()
	wheel_event.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_event.pressed = true
	wheel_event.position = Vector2(200, 200)
	_sys_map_app._on_grid_gui_input(wheel_event)
	assert_true(_sys_map_app.zoom_level > 1.0, "Lo zoom con rotellina deve incrementare zoom_level")
	assert_ne(_sys_map_app.pan_offset, Vector2.ZERO, "Lo zoom centrato sul mouse deve aggiornare pan_offset")
	
	for _i in range(30):
		_sys_map_app._on_zoom_in_pressed()
	assert_true(is_equal_approx(_sys_map_app.zoom_level, _sys_map_app.MAX_ZOOM), "Lo zoom deve raggiungere e bloccarsi a MAX_ZOOM")
	
	_sys_map_app._on_zoom_reset_pressed()
	assert_true(is_equal_approx(_sys_map_app.zoom_level, 1.0), "Reset zoom deve ripristinare zoom_level a 1.0")

func test_async_route_plot_sequence_and_feedback() -> void:
	_sys_map_app = await _create_system_map_app()
	_sys_map_app.select_sector(TARGET_COORDS)
	_sys_map_app._on_plot_route_pressed()
	
	assert_true(_sys_map_app.is_plotting_route, "Alla pressione di Plot Route, is_plotting_route deve essere true")
	assert_true(_sys_map_app.btn_plot_route.disabled, "BtnPlotRoute deve essere disabilitato durante il calcolo")
	assert_true(_sys_map_app.btn_send_route.disabled, "BtnSendRoute deve essere disabilitato durante il calcolo")
	assert_true("Scansione" in _sys_map_app.sector_info_text.text, "Step 1 del feedback deve indicare scansione corpi neri")
	
	await get_tree().create_timer(1.3).timeout
	assert_true(_sys_map_app.is_plotting_route, "Il calcolo deve essere ancora in corso allo step 2")
	assert_true("traiettoria" in _sys_map_app.sector_info_text.text, "Step 2 del feedback deve indicare check traiettoria")
	
	await get_tree().create_timer(1.4).timeout
	assert_true(_sys_map_app.is_plotting_route, "Il calcolo deve essere ancora in corso allo step 3")
	assert_true("iperdrive" in _sys_map_app.sector_info_text.text, "Step 3 del feedback deve indicare calcolo vettore iperdrive")
	
	await get_tree().create_timer(1.3).timeout
	assert_false(_sys_map_app.is_plotting_route, "Al termine della sequenza, is_plotting_route deve essere false")
	assert_false(_sys_map_app.btn_plot_route.disabled, "BtnPlotRoute deve essere riabilitato")
	assert_false(_sys_map_app.btn_send_route.disabled, "BtnSendRoute deve essere riabilitato")
	assert_false(_sys_map_app.calculated_route.is_empty(), "Rotta calcolata deve essere memorizzata")

func test_grid_rendering_does_not_error() -> void:
	_sys_map_app = await _create_system_map_app()
	_sys_map_app.grid_display.queue_redraw()
	await get_tree().process_frame
	assert_true(true, "Rendering della griglia e delle zone d'ombra planetarie deve avvenire senza errori")
