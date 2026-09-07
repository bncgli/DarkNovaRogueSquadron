extends GutTest

## Test GUT per il Posizionamento Iniziale della Nave Adiacente alla Stazione Spaziale.
## Verifica:
## 1. Posizione iniziale calcolata in un settore adiacente libero rispetto alla stazione orbitale definita nel StarSystemData.
## 2. Rilevamento della stazione spaziale come bersaglio/contatto su sensori e radar con segnale IFF FRIENDLY/STATION.
## 3. Distanza nello spazio 3D appropriata (1000–2500m) che consente sia il docking sia la rotta di fuga verso altri settori.
## 4. Generazione automatica di Waypoint e notifica diegetica di sistema.
## Le funzioni condividono stato (sys_data, grid_mgr, world_mgr, ecc.) creato/liberato
## manualmente in before_all/after_all (add_child_autofree libererebbe già al termine
## del singolo test, rompendo la sequenza).

var sys_data: StarSystemData
var primary_st: CelestialBodyData
var st_coords: Vector3i
var spawn_coords: Vector3i

var grid_mgr: Node
var local_grid_mgr: bool = false
var world_mgr: Node
var local_world_mgr: bool = false
var current_sector: Vector3i
var station_entity: SpaceStationEntity
var dm: Node

func after_all() -> void:
	if is_instance_valid(dm):
		dm.free()
	if is_instance_valid(world_mgr):
		if local_world_mgr:
			world_mgr.free()
		elif world_mgr.has_method("end_mission"):
			# world_mgr e' il singleton reale /root/SpaceWorldManager: non va liberato,
			# ma la missione avviata da questo test deve essere terminata per non
			# inquinare lo stato condiviso (is_ship_connected_state) dei test successivi.
			world_mgr.end_mission()
	if local_grid_mgr and is_instance_valid(grid_mgr):
		grid_mgr.free()

func test_identifies_primary_station_and_adjacent_spawn_sector() -> void:
	sys_data = StarSystemData.new("SYS-TEST-01", "Test Helios System")
	sys_data.create_default_system()

	primary_st = sys_data.find_primary_station()
	assert_not_null(primary_st, "StarSystemData deve identificare la stazione spaziale primaria")
	assert_eq(primary_st.id, "STATION_VALKYRIE", "L'ID della stazione primaria di default deve essere STATION_VALKYRIE")

	st_coords = primary_st.coords
	assert_eq(st_coords, Vector3i(4, 12, 0), "Le coordinate di griglia della stazione devono essere (4, 12, 0)")

	spawn_coords = sys_data.find_adjacent_spawn_sector(st_coords)
	var diff := Vector3(spawn_coords - st_coords)
	assert_true(is_equal_approx(diff.length(), 1.0) or is_equal_approx(diff.length(), sqrt(2.0)), "Lo spawn deve avvenire in una casella adiacente (distanza 1 o diagonale adiacente)")
	assert_ne(spawn_coords, st_coords, "Le coordinate di spawn non devono sovrapporsi al settore della stazione")

func test_star_system_grid_manager_positions_at_adjacent_sector() -> void:
	grid_mgr = get_node_or_null("/root/StarSystemGridManager")
	if grid_mgr == null:
		grid_mgr = StarSystemGridManagerSingleton.new()
		add_child(grid_mgr)
		local_grid_mgr = true

	grid_mgr.load_star_system(sys_data)

	current_sector = grid_mgr.get_current_sector_coords()
	assert_eq(current_sector, spawn_coords, "StarSystemGridManager deve impostare current_sector_coords sul settore adiacente allo spawn")

	var dist_sectors: float = grid_mgr.get_sector_distance(current_sector, st_coords)
	assert_true(dist_sectors >= 1.0 and dist_sectors <= 1.5, "La distanza in settori dalla stazione deve essere di 1 cella di griglia")

	var visible_entities: Array[Dictionary] = grid_mgr.get_visible_system_entities(current_sector)
	var station_visible := false
	for ent in visible_entities:
		if ent.get("id") == primary_st.id:
			station_visible = true
			assert_eq(ent.get("type"), "STATION")
			assert_false(ent.get("is_in_current_sector"), "La stazione non deve essere nello stesso settore di spawn")
			break
	assert_true(station_visible, "La stazione spaziale deve essere visibile nell'elenco delle entità di sistema dal settore di spawn")

func test_space_world_manager_configures_3d_space_ship_and_sensors() -> void:
	world_mgr = get_node_or_null("/root/SpaceWorldManager")
	if world_mgr == null:
		world_mgr = SpaceWorldManagerSingleton.new()
		add_child(world_mgr)
		local_world_mgr = true

	world_mgr.set_star_system_data(sys_data)
	world_mgr.start_mission()

	station_entity = world_mgr.get_primary_station_entity()
	assert_not_null(station_entity, "SpaceWorldManager deve istanziare l'entità 3D della stazione primaria")
	assert_eq(station_entity.station_id, "STATION_VALKYRIE", "L'entità 3D della stazione deve avere l'id corretto")

	var ship: Node3D = world_mgr.get_spaceship()
	assert_not_null(ship, "SpaceWorldManager deve fornire il riferimento alla Spaceship")

	var ship_pos: Vector3 = ship.global_position
	var st_pos: Vector3 = station_entity.global_position
	var dist_3d: float = ship_pos.distance_to(st_pos)

	assert_true(dist_3d >= 1000.0 and dist_3d <= 2500.0, "La distanza 3D iniziale tra nave e stazione deve essere tra 1000 e 2500 metri (area perimetrale)")

	# Verifica orientamento nave verso la stazione (look_at)
	var forward_vec: Vector3 = -ship.global_transform.basis.z.normalized()
	var to_station_vec: Vector3 = (st_pos - ship_pos).normalized()
	var dot_facing: float = forward_vec.dot(to_station_vec)
	assert_gt(dot_facing, 0.9, "La nave deve essere orientata verso il vettore della stazione (dot product > 0.9)")

	# Verifica Waypoint attivo
	var wp: Dictionary = world_mgr.get_active_waypoint()
	assert_false(wp.is_empty(), "SpaceWorldManager deve impostare automaticamente un waypoint verso la stazione")
	assert_eq(wp.get("id"), "STATION_VALKYRIE")
	assert_eq(wp.get("type"), "STATION")
	assert_eq(wp.get("iff_tag"), "FRIENDLY")

	# Verifica contatti sensori
	var sensor_entities: Array[Dictionary] = world_mgr.get_sensor_entities()
	var station_sensor_found := false
	for s_ent in sensor_entities:
		if s_ent.get("id") == "STATION_VALKYRIE":
			station_sensor_found = true
			assert_eq(s_ent.get("type"), "STATION")
			assert_eq(s_ent.get("iff_tag"), "FRIENDLY")
			assert_almost_eq(s_ent.get("distance"), dist_3d, 0.01, "La distanza sui sensori deve coincidere con la distanza 3D")
			break
	assert_true(station_sensor_found, "La stazione spaziale deve essere presente nei contatti del sensore/radar")

func test_docking_clearance_and_alternate_route_planning() -> void:
	# 1. Test opzione A: Manovra di avvicinamento per docking
	var dm_script: GDScript = load("res://Outside/Stations/docking_manager.gd")
	dm = dm_script.new()
	add_child(dm)
	var req_res: bool = dm.request_docking_clearance(station_entity, "DARK-NOVA-TEST", "SOL-NAV-DEFENSE")
	assert_true(req_res, "La richiesta di clearance radio verso la stazione adiacente deve avere successo")
	assert_eq(dm.current_state, 2, "Lo stato di docking deve passare ad APPROACH_GUIDANCE (2)")

	# 2. Test opzione B: Pianificazione rotta verso altro settore del sistema
	var target_sector := Vector3i(8, 20, 0) # Gigante gassoso Kronos
	var route_vec: Vector3 = grid_mgr.get_route_vector(current_sector, target_sector)
	assert_gt(route_vec.length(), 0.9, "Il vettore di rotta verso altro quadrante deve essere calcolato validamente")
	var travel_time: float = grid_mgr.calculate_sublight_travel_time(current_sector, target_sector, 500.0)
	assert_true(travel_time > 0.0 and travel_time < INF, "Il tempo di viaggio sub-luce deve essere un valore finito positivo")
