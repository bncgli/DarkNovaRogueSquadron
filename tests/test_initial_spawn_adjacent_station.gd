extends Node

## Suite di Test Headless per il Posizionamento Iniziale della Nave Adiacente alla Stazione Spaziale
## Verifica:
## 1. Posizione iniziale calcolata in un settore adiacente libero rispetto alla stazione orbitale definita nel StarSystemData.
## 2. Rilevamento della stazione spaziale come bersaglio/contatto su sensori e radar con segnale IFF FRIENDLY/STATION.
## 3. Distanza nello spazio 3D appropriata (1000–2500m) che consente sia il docking sia la rotta di fuga verso altri settori.
## 4. Generazione automatica di Waypoint e notifica diegetica di sistema.

func _ready() -> void:
	print("\n=======================================================")
	print(">>> AVVIO SUITE DI TEST HEADLESS: INITIAL SPAWN ADJACENT TO STATION")
	print("=======================================================\n")
	_run_tests()

func _run_tests() -> void:
	await get_tree().process_frame
	var success_count := 0
	
	print("--- TEST 1: Identificazione Stazione Primaria e Calcolo Settore Adiacente di Spawning ---")
	var sys_data := StarSystemData.new("SYS-TEST-01", "Test Helios System")
	sys_data.create_default_system()
	
	var primary_st: Dictionary = sys_data.find_primary_station()
	assert(not primary_st.is_empty(), "StarSystemData deve identificare la stazione spaziale primaria")
	assert(primary_st.get("id", "") == "STATION_VALKYRIE", "L'ID della stazione primaria di default deve essere STATION_VALKYRIE")
	
	var st_coords: Vector3i = primary_st.get("coords", Vector3i.ZERO)
	assert(st_coords == Vector3i(4, 12, 0), "Le coordinate di griglia della stazione devono essere (4, 12, 0)")
	
	var spawn_coords := sys_data.find_adjacent_spawn_sector(st_coords)
	var diff := Vector3(spawn_coords - st_coords)
	assert(diff.length() == 1.0 or diff.length() == sqrt(2.0), "Lo spawn deve avvenire in una casella adiacente (distanza 1 o diagonale adiacente)")
	assert(spawn_coords != st_coords, "Le coordinate di spawn non devono sovrapporsi al settore della stazione")
	
	print("   [OK] Stazione primaria '%s' a %s -> Settore spawn adiacente calcolato: %s" % [primary_st.get("name"), str(st_coords), str(spawn_coords)])
	success_count += 1
	
	print("\n--- TEST 2: Inizializzazione e Posizionamento in StarSystemGridManager ---")
	var grid_mgr = get_node_or_null("/root/StarSystemGridManager")
	var local_grid_mgr := false
	if grid_mgr == null:
		grid_mgr = StarSystemGridManagerSingleton.new()
		add_child(grid_mgr)
		local_grid_mgr = true
		
	grid_mgr.load_star_system(sys_data)
	
	var current_sector: Vector3i = grid_mgr.get_current_sector_coords()
	assert(current_sector == spawn_coords, "StarSystemGridManager deve impostare current_sector_coords sul settore adiacente allo spawn")
	
	var dist_sectors: float = grid_mgr.get_sector_distance(current_sector, st_coords)
	assert(dist_sectors >= 1.0 and dist_sectors <= 1.5, "La distanza in settori dalla stazione deve essere di 1 cella di griglia")
	
	var visible_entities: Array[Dictionary] = grid_mgr.get_visible_system_entities(current_sector)
	var station_visible := false
	for ent in visible_entities:
		if ent.get("id") == primary_st.get("id"):
			station_visible = true
			assert(ent.get("type") == "STATION", "Il tipo di entità visibile deve essere STATION")
			assert(ent.get("is_in_current_sector") == false, "La stazione non deve essere nello stesso settore di spawn")
			break
	assert(station_visible, "La stazione spaziale deve essere visibile nell'elenco delle entità di sistema dal settore di spawn")
	print("   [OK] StarSystemGridManager posizionato correttamente a %s con stazione rilevabile a distanza %.1f settori" % [str(current_sector), dist_sectors])
	success_count += 1
	
	print("\n--- TEST 3: Configurazione Spazio 3D, Orientamento Nave, Waypoint e Sensori in SpaceWorldManager ---")
	var world_mgr = get_node_or_null("/root/SpaceWorldManager")
	var local_world_mgr := false
	if world_mgr == null:
		world_mgr = SpaceWorldManagerSingleton.new()
		add_child(world_mgr)
		local_world_mgr = true
		
	world_mgr.set_star_system_data(sys_data)
	world_mgr.start_mission()
	
	var station_entity: SpaceStationEntity = world_mgr.get_primary_station_entity()
	assert(station_entity != null, "SpaceWorldManager deve istanziare l'entità 3D della stazione primaria")
	assert(station_entity.station_id == "STATION_VALKYRIE", "L'entità 3D della stazione deve avere l'id corretto")
	
	var ship: Node3D = world_mgr.get_spaceship()
	assert(ship != null, "SpaceWorldManager deve fornire il riferimento alla Spaceship")
	
	var ship_pos: Vector3 = ship.global_position
	var st_pos: Vector3 = station_entity.global_position
	var dist_3d: float = ship_pos.distance_to(st_pos)
	
	assert(dist_3d >= 1000.0 and dist_3d <= 2500.0, "La distanza 3D iniziale tra nave e stazione deve essere tra 1000 e 2500 metri (area perimetrale)")
	
	# Verifica orientamento nave verso la stazione (look_at)
	var forward_vec: Vector3 = -ship.global_transform.basis.z.normalized()
	var to_station_vec: Vector3 = (st_pos - ship_pos).normalized()
	var dot_facing: float = forward_vec.dot(to_station_vec)
	assert(dot_facing > 0.9, "La nave deve essere orientata verso il vettore della stazione (dot product > 0.9)")
	
	# Verifica Waypoint attivo
	var wp: Dictionary = world_mgr.get_active_waypoint()
	assert(not wp.is_empty(), "SpaceWorldManager deve impostare automaticamente un waypoint verso la stazione")
	assert(wp.get("id") == "STATION_VALKYRIE", "Il waypoint attivo deve corrispondere alla stazione")
	assert(wp.get("type") == "STATION", "Il tipo di waypoint deve essere STATION")
	assert(wp.get("iff_tag") == "FRIENDLY", "L'IFF tag del waypoint deve essere FRIENDLY")
	
	# Verifica contatti sensori
	var sensor_entities: Array[Dictionary] = world_mgr.get_sensor_entities()
	var station_sensor_found := false
	for s_ent in sensor_entities:
		if s_ent.get("id") == "STATION_VALKYRIE":
			station_sensor_found = true
			assert(s_ent.get("type") == "STATION", "Il tipo sensore deve essere STATION")
			assert(s_ent.get("iff_tag") == "FRIENDLY", "L'IFF sui sensori deve essere FRIENDLY")
			assert(is_equal_approx(s_ent.get("distance"), dist_3d), "La distanza sui sensori deve coincidere con la distanza 3D")
			break
	assert(station_sensor_found, "La stazione spaziale deve essere presente nei contatti del sensore/radar")
	
	print("   [OK] Spazio 3D configurato: Distanza = %.1f m, Allineamento vettore = %.2f, Waypoint e IFF verificati." % [dist_3d, dot_facing])
	success_count += 1
	
	print("\n--- TEST 4: Bivio Operativo (Avvicinamento per Docking vs Allontanamento/Rotta Fuga) ---")
	# 1. Test opzione A: Manovra di avvicinamento per docking
	var dm_script = load("res://Outside/Stations/docking_manager.gd")
	var dm = dm_script.new()
	add_child(dm)
	var req_res: bool = dm.request_docking_clearance(station_entity, "DARK-NOVA-TEST", "SOL-NAV-DEFENSE")
	assert(req_res == true, "La richiesta di clearance radio verso la stazione adiacente deve avere successo")
	assert(dm.current_state == 2, "Lo stato di docking deve passare ad APPROACH_GUIDANCE (2)")
	
	# 2. Test opzione B: Pianificazione rotta verso altro settore del sistema
	var target_sector := Vector3i(8, 20, 0) # Gigante gassoso Kronos
	var route_vec: Vector3 = grid_mgr.get_route_vector(current_sector, target_sector)
	assert(route_vec.length() > 0.9, "Il vettore di rotta verso altro quadrante deve essere calcolato validamente")
	var travel_time: float = grid_mgr.calculate_sublight_travel_time(current_sector, target_sector, 500.0)
	assert(travel_time > 0.0 and travel_time < INF, "Il tempo di viaggio sub-luce deve essere un valore finito positivo")
	
	print("   [OK] Bivio Operativo verificato: Docking clearance richiesta con successo e rotta alternativa verso %s calcolabile (tempo: %.1f s)." % [str(target_sector), travel_time])
	success_count += 1
	
	# Cleanup
	dm.queue_free()
	if local_world_mgr:
		world_mgr.queue_free()
	if local_grid_mgr:
		grid_mgr.queue_free()
	
	print("\n=======================================================")
	print(">>> TUTTI I %d TEST DI INITIAL SPAWN ADJACENT STATION SONO STATI SUPERATI CON SUCCESSO!" % success_count)
	print("=======================================================\n")
	
	get_tree().quit(0)
