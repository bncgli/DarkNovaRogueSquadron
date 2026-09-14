extends GutTest

## Test GUT per verificare che il salto Hyperdrive carichi correttamente la zona 3D,
## riposizioni l'astronave, aggiorni le entità locali (stazioni, asteroidi, relitti),
## e sincronizzi waypoint e sensori radar.

const START_COORDS := Vector3i(4, 11, 0) # Adiacente a Stazione Valkyrie (4, 10, 0)
const DEEP_SPACE_COORDS := Vector3i(1, 1, 0) # Spazio profondo vuoto

var _flight_app: FlightControlApp = null

func before_each() -> void:
	NetworkManager.disconnect_game()
	if StarSystemGridManager:
		StarSystemGridManager.load_star_system(StarSystemData.get_default_star_system())
		StarSystemGridManager.set_current_sector_coords(START_COORDS)
		StarSystemGridManager.clear_plotted_route()
	if SpaceWorldManager:
		SpaceWorldManager.configure_initial_station_spawn()

func after_each() -> void:
	if is_instance_valid(_flight_app):
		_flight_app.queue_free()
	_flight_app = null
	NetworkManager.disconnect_game()
	if StarSystemGridManager:
		StarSystemGridManager.clear_plotted_route()

func test_initial_state_has_station_in_adjacent_sector() -> void:
	assert_not_null(SpaceWorldManager, "SpaceWorldManager deve essere disponibile")
	assert_true(SpaceWorldManager.is_station_in_sector(), "La stazione deve essere presente nel settore di partenza adiacente")
	
	var station_entity: SpaceStationEntity = SpaceWorldManager.get_primary_station_entity()
	assert_not_null(station_entity, "L'istanza SpaceStationEntity deve esistere")
	assert_true(station_entity.visible, "La stazione deve essere visibile")
	assert_eq(station_entity.station_id, "STATION_VALKYRIE")
	
	var wp: Dictionary = SpaceWorldManager.get_active_waypoint()
	assert_eq(wp.get("id"), "STATION_VALKYRIE", "Il waypoint iniziale deve puntare alla Stazione Valkyrie")
	
	var contacts := SpaceWorldManager.get_sensor_entities()
	var found_station := false
	for c in contacts:
		if c.get("id") == "STATION_VALKYRIE":
			found_station = true
			break
	assert_true(found_station, "I sensori devono rilevare la Stazione Valkyrie nel settore iniziale")

func test_hyperdrive_transit_to_deep_space_unloads_station_and_resets_ship() -> void:
	_flight_app = load("res://Applications/FlightControl/flight_control_app.tscn").instantiate() as FlightControlApp
	add_child_autofree(_flight_app)
	await get_tree().process_frame
	
	# Muovi leggermente la nave per testare il riposizionamento e l'arresto
	var ship := SpaceWorldManager.get_spaceship()
	if ship and is_instance_valid(ship):
		ship.global_position = Vector3(100.0, 50.0, -200.0)
		ship.linear_velocity = Vector3(10.0, 0.0, -25.0)
	
	# Pianifica rotta verso Deep Space
	var course_vec := Vector3(DEEP_SPACE_COORDS - START_COORDS).normalized()
	_flight_app._on_route_plotted(DEEP_SPACE_COORDS, course_vec)
	await _flight_app.align_to_hyperdrive_vector(0.05)
	
	# Esegui il salto Hyperdrive
	var res := _flight_app.engage_hyperdrive()
	assert_true(res.get("success"), "Il salto Hyperdrive verso Deep Space deve riuscire")
	
	# Verifica sincronizzazione coordinate griglia
	assert_eq(StarSystemGridManager.get_current_sector_coords(), DEEP_SPACE_COORDS)
	
	# Verifica stato del mondo 3D
	assert_false(SpaceWorldManager.is_station_in_sector(), "La stazione non deve essere più presente in Deep Space")
	var st_entity := SpaceWorldManager.get_primary_station_entity()
	assert_false(st_entity.visible, "La mesh 3D della stazione deve essere nascosta")
	
	# Verifica riposizionamento e azzeramento cinetica nave
	if ship and is_instance_valid(ship):
		assert_eq(ship.global_position, Vector3.ZERO, "La nave deve essere riposizionata a ZERO nel nuovo settore")
		assert_eq(ship.linear_velocity, Vector3.ZERO, "I motori e la velocità lineare devono essere azzerati")
	
	# Verifica che il waypoint della stazione sia stato rimosso
	var wp: Dictionary = SpaceWorldManager.get_active_waypoint()
	assert_ne(wp.get("id"), "STATION_VALKYRIE", "Il waypoint della stazione non deve rimanere attivo in Deep Space")
	
	# Verifica sensori: nessuna stazione orbitale a 1800m
	var contacts := SpaceWorldManager.get_sensor_entities()
	for c in contacts:
		assert_ne(c.get("id"), "STATION_VALKYRIE", "I sensori non devono più rilevare la Stazione Valkyrie")

func test_hyperdrive_transit_to_derelict_sector_loads_wreck_3d() -> void:
	# Settore con relitto (es. SEC-06-14 o configurato ad hoc)
	var wreck_coords := Vector3i(6, 14, 0)
	var wreck_sec := StarSystemGridManager.get_or_generate_sector_data(wreck_coords)
	wreck_sec.sector_type = "DERELICT_GRAVEYARD"
	
	# Forza il caricamento della zona del relitto
	SpaceWorldManager.load_sector_zone(wreck_sec, true)
	
	assert_not_null(SpaceWorldManager.primary_derelict_instance, "L'istanza 3D del relitto deve essere creata")
	assert_true(SpaceWorldManager.primary_derelict_instance.visible, "Il relitto 3D deve essere visibile")
	
	var wp: Dictionary = SpaceWorldManager.get_active_waypoint()
	assert_eq(wp.get("type"), "WRECK", "Il waypoint deve essere ancorato al relitto spaziale")
	
	var contacts := SpaceWorldManager.get_sensor_entities()
	var found_wreck := false
	for c in contacts:
		if c.get("type") == "WRECK":
			found_wreck = true
			break
	assert_true(found_wreck, "I sensori devono rilevare il contatto del relitto")

func test_hyperdrive_return_to_station_sector_reloads_station_3d() -> void:
	# Prima salta a Deep Space
	var deep_sec := StarSystemGridManager.get_or_generate_sector_data(DEEP_SPACE_COORDS)
	deep_sec.sector_type = "DEEP_SPACE"
	SpaceWorldManager.load_sector_zone(deep_sec, true)
	assert_false(SpaceWorldManager.is_station_in_sector())
	
	# Poi torna al settore iniziale adiacente alla stazione
	var station_sec := StarSystemGridManager.get_or_generate_sector_data(START_COORDS)
	SpaceWorldManager.load_sector_zone(station_sec, true)
	
	assert_true(SpaceWorldManager.is_station_in_sector(), "La stazione deve tornare attiva al ritorno nel settore")
	var st_entity := SpaceWorldManager.get_primary_station_entity()
	assert_true(st_entity.visible, "La stazione 3D deve essere nuovamente visibile")
	
	var wp: Dictionary = SpaceWorldManager.get_active_waypoint()
	assert_eq(wp.get("id"), "STATION_VALKYRIE", "Il waypoint deve ripuntare alla Stazione Valkyrie")
