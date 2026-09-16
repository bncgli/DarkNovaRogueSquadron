extends GutTest

## Test suite GUT per la Fase D: Esplorazione Spaziale, Relitti, Scavenging con Service Drone e Caricamento Dinamico dei Quadranti.
## Valida il Debris Field volumetrico 3D, l'harpoon magnetico del drone, il portello cargo della corvetta, l'allerta sciacalli e lo streaming seamless.

var space_world: SpaceWorldManager = null
var grid_mgr: StarSystemGridManagerSingleton = null
var combat_dir: CombatDirector = null
var ship: Spaceship = null
var drone: ServiceDroneEntity = null
var cargo_mgr: CargoManagerSingleton = null

func before_each() -> void:
	# Inizializza GridManager
	grid_mgr = StarSystemGridManagerSingleton.new()
	add_child(grid_mgr)
	grid_mgr.load_star_system(StarSystemData.get_default_star_system())

	# Inizializza SpaceWorldManager
	space_world = SpaceWorldManager
	
	# Inizializza CombatDirector
	combat_dir = CombatDirector.new()
	add_child(combat_dir)
	combat_dir.auto_manage_encounters = false

	# Inizializza CargoManager
	cargo_mgr = CargoManagerSingleton.new()
	add_child(cargo_mgr)
	cargo_mgr.clear_cargo()

	# Inizializza Spaceship
	ship = Spaceship.new()
	add_child(ship)
	ship.cargo_manager = cargo_mgr
	combat_dir.setup(ship)

	# Inizializza ServiceDroneEntity
	drone = ServiceDroneEntity.new()
	add_child(drone)
	drone.undock()

	await get_tree().process_frame

func after_each() -> void:
	for n in [drone, ship, combat_dir, cargo_mgr, grid_mgr]:
		if is_instance_valid(n):
			n.free()
	if space_world:
		space_world.clear_debris_field()

# =============================================================================
# TEST 1: CAMPO DETRITI VOLUMETRICO 3D E CONTAINER SPAWN
# =============================================================================
func test_volumetric_debris_field_and_containers_spawn() -> void:
	var sec_data := SectorData.new()
	sec_data.sector_id = "SEC-04-12"
	sec_data.coordinates = Vector3i(4, 12, 0)
	sec_data.sector_type = "DERELICT_GRAVEYARD"
	sec_data.sector_name = "Cimitero Relitti Spaziali"

	space_world.load_sector_zone(sec_data)

	var derelict := space_world.get_primary_derelict_entity()
	assert_not_null(derelict, "Deve esistere l'istanza del relitto primario")
	assert_true(derelict.visible, "Il relitto primario deve essere visibile")
	assert_ne(derelict.global_position.y, 0.0, "La quota Y del relitto deve essere non-zero (volumetrica 3D)")

	var containers := space_world.get_active_debris_containers()
	assert_gte(containers.size(), 3, "Il campo detriti deve contenere almeno 3 container galleggianti")

	# Verifica quote tridimensionali variabili Y per ciascun container
	var has_diff_y := false
	var first_y: float = containers[0].global_position.y
	for c in containers:
		assert_true(c.is_inside_tree(), "Il container deve essere presente nell'albero della scena")
		assert_gt(c.mass_kg, 0.0, "La massa del container deve essere positiva")
		var item_dict := c.get_cargo_item_dict()
		assert_false(item_dict.is_empty(), "I dati cargo del container devono essere validi")
		assert_gt(item_dict.get("unit_base_value", 0.0), 0.0, "Il valore base del carico deve essere positivo")
		if not is_equal_approx(c.global_position.y, first_y):
			has_diff_y = true
	assert_true(has_diff_y, "I container devono avere quote altimetriche Y tridimensionali differenziate")

	# Verifica inclusione nei sensori
	var all_entities: Array = space_world.get_all_spatial_entities()
	var found_containers_in_sensors := 0
	for ent in all_entities:
		if str(ent.get("type")) == "CARGO_CONTAINER":
			found_containers_in_sensors += 1
	assert_gte(found_containers_in_sensors, containers.size(), "Tutti i container devono essere rilevabili dai sensori/LIDAR")

# =============================================================================
# TEST 2: HARPOON MAGNETICO DEL SERVICE DRONE E RIMORCHIO
# =============================================================================
func test_service_drone_magnet_harpoon_latch_and_tow() -> void:
	# Posiziona il drone nello spazio
	drone.global_position = Vector3(0.0, 0.0, 0.0)
	drone.battery = 100.0

	# Crea un container a 8m di distanza (entro magnet_range = 18m)
	var container := CargoContainerEntity.new()
	container.container_id = "CONTAINER_TEST_01"
	container.mass_kg = 50.0
	add_child(container)
	container.global_position = Vector3(0.0, 0.0, -8.0)

	# Seleziona strumento magnete e attiva
	drone.set_active_tool("magnet")
	drone.set_tool_trigger(true)

	# Processa scansione magnete
	drone._process_magnet(0.1)

	assert_true(drone.is_cargo_latched(), "Il drone deve risultare con carico agganciato all'harpoon")
	assert_true(container.is_latched, "Il container deve passare allo stato is_latched = true")
	assert_eq(container.latched_to, drone, "Il container deve essere vincolato al drone")
	assert_eq(drone.get_latched_container(), container, "Il container associato al drone deve corrispondere")

	# Simula spostamento del drone per rimorchio
	drone.global_position = Vector3(15.0, 5.0, -20.0)
	container._physics_process(0.5)

	# Il container deve aver seguito la posizione del drone
	var dist_drone_container := container.global_position.distance_to(drone.global_position)
	assert_lt(dist_drone_container, 8.0, "La posizione del container deve seguire il moto di traino del drone")

	# Verifica consumo batteria maggiorato per traino carico
	var pre_batt := drone.battery
	drone._physics_process(1.0)
	var drain_with_cargo := pre_batt - drone.battery
	assert_gt(drain_with_cargo, 0.5, "Il traino di massa deve consumare batteria in misura maggiore")

	# Esaurimento batteria forzato -> rilascio automatico
	drone.battery = 0.0
	drone._physics_process(0.1)
	assert_false(drone.is_cargo_latched(), "A batteria esaurita l'harpoon deve rilasciare il carico")
	assert_false(container.is_latched, "Il container deve risultare sganciato")

	if is_instance_valid(container):
		container.free()

# =============================================================================
# TEST 3: PORTELLO CARGO E DEPOSITO AUTOMATICO IN CARGOMANAGER
# =============================================================================
func test_cargo_hatch_intake_and_cargomanager_storage() -> void:
	var initial_mass := cargo_mgr.get_total_mass()
	var initial_count := cargo_mgr.cargo_items.size()

	# Crea container cargo
	var container := CargoContainerEntity.new()
	container.container_id = "CONTAINER_ALLOY_VEND"
	container.item_data = {
		"id": "alloys_durasteel",
		"name": "Leghe Raffinate Durasteel",
		"category": "ALLOY",
		"unit_mass_kg": 40.0,
		"unit_volume_m3": 0.5,
		"unit_base_value": 350.0,
		"quantity": 2
	}
	container.mass_kg = 80.0
	add_child(container)

	# Vincola al drone
	drone.latch_cargo(container)
	assert_true(drone.is_cargo_latched(), "Il drone ha agganciato il container")

	# Il drone porta il container all'interno del portello cargo della corvetta
	var intake_ok := ship.intake_cargo_container(container)
	assert_true(intake_ok, "intake_cargo_container deve completarsi con successo")

	# Verifica stivaggio in CargoManager
	assert_gt(cargo_mgr.get_total_mass(), initial_mass, "La massa della stiva deve essere aumentata")
	assert_gt(cargo_mgr.get_item_quantity("alloys_durasteel"), 0, "Le leghe durasteel devono essere presenti in stiva")

	# Verifica che il drone sia stato liberato dall'harpoon
	assert_false(drone.is_cargo_latched(), "L'harpoon del drone deve essere liberato al termine dello stivaggio")

	# Test caso limite: stiva piena (overload)
	cargo_mgr.max_mass_kg = cargo_mgr.get_total_mass() # Stiva satura
	var overflow_container := CargoContainerEntity.new()
	overflow_container.mass_kg = 50.0
	overflow_container.item_data = {
		"id": "minerals_titanium",
		"name": "Titanio Grezzo",
		"category": "MINERAL",
		"unit_mass_kg": 50.0,
		"unit_volume_m3": 1.0,
		"unit_base_value": 120.0,
		"quantity": 1
	}
	add_child(overflow_container)
	drone.latch_cargo(overflow_container)

	var overflow_result := ship.intake_cargo_container(overflow_container)
	assert_false(overflow_result, "Il portello deve respingere il carico se la stiva è satura")
	assert_true(drone.is_cargo_latched(), "Il container deve rimanere agganciato all'harpoon del drone")

	if is_instance_valid(overflow_container):
		overflow_container.free()

# =============================================================================
# TEST 4: ALLERTA E IMBOSCATA SCIACALLI PIRATA IN COMBATDIRECTOR
# =============================================================================
func test_scavenger_pirate_ambush_alert_trigger() -> void:
	combat_dir.scavenger_ambush_interval = 2.0
	combat_dir.scavenger_ambush_chance = 1.0 # 100% per test deterministico
	combat_dir.is_in_combat = false

	var alert_tracker := {"emitted": false}
	combat_dir.scavenger_threat_alert.connect(func(_lvl): alert_tracker["emitted"] = true)

	var ambush_tracker := {"triggered": false, "scavengers": []}
	combat_dir.scavenger_ambush_triggered.connect(func(scavs):
		ambush_tracker["triggered"] = true
		ambush_tracker["scavengers"] = scavs
	)

	# Avanza il timer di pattuglia sciacalli durante operazioni nel campo detriti
	var triggered := combat_dir.process_scavenger_threat(1.0, true, true)
	assert_false(triggered, "Non deve scattare prima dell'intervallo")
	assert_true(alert_tracker["emitted"], "Il segnale scavenger_threat_alert deve essere emesso")

	# Raggiunge la soglia limite
	triggered = combat_dir.process_scavenger_threat(1.5, true, true)
	assert_true(triggered, "L'imboscata deve scattare al superamento dell'intervallo")
	assert_true(ambush_tracker["triggered"], "Il segnale scavenger_ambush_triggered deve essere stato emesso")
	assert_gt(ambush_tracker["scavengers"].size(), 0, "Devono essere stati generati caccia sciacalli")
	assert_true(combat_dir.is_in_combat, "CombatDirector deve essere entrato nello stato di combattimento")

# =============================================================================
# TEST 5: PROXIMITY TRIGGER E ASYNC PRELOAD A VELOCITÀ DI CROCIERA
# =============================================================================
func test_cruise_sector_boundary_proximity_and_async_preload() -> void:
	grid_mgr.set_current_sector_coords(Vector3i(4, 11, 0))

	var proximity_tracker := {"emitted": false}
	var preload_tracker := {"completed": false}
	grid_mgr.sector_boundary_proximity.connect(func(_curr, _adj, _dist): proximity_tracker["emitted"] = true)
	grid_mgr.sector_preload_completed.connect(func(_coords, _sec): preload_tracker["completed"] = true)

	# Nave all'interno della zona di allerta pre-confine (a 40.000 km, bordo a 50.000 km -> dist = 10.000 km <= 15.000 km)
	var ship_pos_km := Vector3(40000.0, 0.0, 0.0)
	var res := grid_mgr.check_sector_boundary_proximity(ship_pos_km)

	assert_true(res.get("is_near_boundary"), "La nave deve trovarsi entro la soglia di prossimità al bordo")
	assert_false(res.get("crossed"), "La nave non ha ancora oltrepassato il confine")
	assert_eq(res.get("adjacent_coords"), Vector3i(5, 11, 0), "Il settore adiacente lungo l'asse X deve essere (5, 11, 0)")
	assert_true(proximity_tracker["emitted"], "Il segnale sector_boundary_proximity deve essere stato emesso")
	assert_true(preload_tracker["completed"], "Il pre-caricamento asincrono del settore adiacente deve essere completato")
	assert_not_null(grid_mgr.preloaded_sector_data, "I dati del settore adiacente devono essere pre-caricati in memoria")

# =============================================================================
# TEST 6: VALICO CONTINUO (SEAMLESS CROSSING) E FLOATING ORIGIN SHIFT
# =============================================================================
func test_seamless_sector_crossing_and_origin_shift() -> void:
	grid_mgr.set_current_sector_coords(Vector3i(4, 11, 0))

	var crossing_tracker := {
		"emitted": false,
		"coords": Vector3i.ZERO,
		"offset": Vector3.ZERO
	}
	grid_mgr.sector_boundary_crossed.connect(func(coords, offset):
		crossing_tracker["emitted"] = true
		crossing_tracker["coords"] = coords
		crossing_tracker["offset"] = offset
	)

	# La nave supera il bordo del settore (+50.000 km su X)
	var ship_crossing_pos_km := Vector3(50050.0, 100.0, -200.0)
	var res := grid_mgr.check_sector_boundary_proximity(ship_crossing_pos_km)

	assert_true(res.get("crossed"), "Il crossing deve essere rilevato come avvenuto")
	assert_true(crossing_tracker["emitted"], "Il segnale sector_boundary_crossed deve essere stato emesso")
	assert_eq(crossing_tracker["coords"], Vector3i(5, 11, 0), "Il nuovo settore attivo deve essere promosso a (5, 11, 0)")
	assert_eq(grid_mgr.get_current_sector_coords(), Vector3i(5, 11, 0))

	# Verifica coordinate floating origin shift sul margine opposto (-50.000 km)
	assert_almost_eq(crossing_tracker["offset"].x, -49950.0, 1.0, "La coordinata X deve essere traslata al margine opposto (-49.950 km)")
	assert_eq(crossing_tracker["offset"].y, 100.0, "Le coordinate trasversali Y e Z devono essere conservate")
	assert_eq(crossing_tracker["offset"].z, -200.0)
