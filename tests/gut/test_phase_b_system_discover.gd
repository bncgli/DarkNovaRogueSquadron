extends GutTest

## Test GUT per la Fase B: Generazione Procedurale Sistemi & Applicazione "System Discover"
## Valida:
## 1. Determinismo della generazione da seed (a parità di seed e archetipo il sistema è identico).
## 2. Bilanciamento e composizione degli archetipi galattici (Frontiera, Hub Industriale, Anarchia, Deep Space).
## 3. Distribuzione volumetrica 3D reale con quote z non vincolate a zero ed elevazioni verticali relative.
## 4. Ciclo di vita ed esportazione diegetica dell'applicazione SystemDiscoverApp.
## 5. Rilevamento automatico e indicizzazione dinamica dei sistemi custom salvati all'interno di LobbyApp.
## 6. Spawn 3D volumetrico in SpaceWorldManager con quote Y variabili applicate a stazioni, relitti e sensori.

var world_mgr: Node = null
var local_world_mgr: bool = false

func after_each() -> void:
	if is_instance_valid(world_mgr):
		if local_world_mgr:
			world_mgr.free()
			world_mgr = null
			local_world_mgr = false
		elif world_mgr.has_method("end_mission"):
			world_mgr.end_mission()

func test_deterministic_seed_generation() -> void:
	var seed_test := "ALPHA-77-TEST"
	var sys1 := StarSystemGenerator.generate_system(seed_test, StarSystemGenerator.Archetype.FRONTIER_EXPANSE)
	var sys2 := StarSystemGenerator.generate_system(seed_test, StarSystemGenerator.Archetype.FRONTIER_EXPANSE)
	
	assert_not_null(sys1, "sys1 non deve essere null")
	assert_not_null(sys2, "sys2 non deve essere null")
	assert_eq(sys1.system_id, sys2.system_id, "I system_id generati con lo stesso seed devono essere identici")
	assert_eq(sys1.primary_star_name, sys2.primary_star_name, "I nomi della stella primaria devono coincidere")
	assert_eq(sys1.celestial_bodies.size(), sys2.celestial_bodies.size(), "Il numero di corpi celesti deve essere identico")
	
	for i in range(sys1.celestial_bodies.size()):
		var b1: CelestialBodyData = sys1.celestial_bodies[i]
		var b2: CelestialBodyData = sys2.celestial_bodies[i]
		assert_eq(b1.id, b2.id, "ID corpo %d deve coincidere" % i)
		assert_eq(b1.name, b2.name, "Nome corpo %d deve coincidere" % i)
		assert_eq(b1.type, b2.type, "Tipo corpo %d deve coincidere" % i)
		assert_eq(b1.coords, b2.coords, "Coordinate Vector3i corpo %d devono essere identiche" % i)
		assert_almost_eq(b1.radius_km, b2.radius_km, 0.001, "Raggio corpo %d deve coincidere" % i)
		assert_almost_eq(b1.mass_tons, b2.mass_tons, 0.001, "Massa corpo %d deve coincidere" % i)

func test_system_archetypes_and_composition() -> void:
	# 1. CORE_INDUSTRIAL
	var ind_sys := StarSystemGenerator.generate_system("IND-01", StarSystemGenerator.Archetype.CORE_INDUSTRIAL)
	var ind_stations: int = 0
	var ind_planets: int = 0
	for b in ind_sys.celestial_bodies:
		if b.type == "STATION":
			ind_stations += 1
		elif b.type in ["PLANET", "GAS_GIANT"]:
			ind_planets += 1
	assert_true(ind_stations >= 2, "L'hub industriale deve contenere almeno 2 stazioni orbitali")
	assert_true(ind_planets >= 5, "L'hub industriale deve contenere almeno 5 pianeti")
	assert_not_null(ind_sys.find_primary_station(), "L'hub industriale deve sempre avere una stazione primaria")

	# 2. ANARCHY_PIRATE_SECTOR
	var pirate_sys := StarSystemGenerator.generate_system("PIR-01", StarSystemGenerator.Archetype.ANARCHY_PIRATE_SECTOR)
	var has_bounty_zone := false
	var has_wreck := false
	for b in pirate_sys.celestial_bodies:
		if b.type == "BOUNTY_ZONE":
			has_bounty_zone = true
		elif b.type == "WRECK":
			has_wreck = true
	assert_true(has_bounty_zone, "Il settore fuorilegge deve generare zone di taglie BOUNTY_ZONE")
	assert_true(has_wreck, "Il settore fuorilegge deve contenere relitti bellici WRECK")
	assert_not_null(pirate_sys.find_primary_station(), "Anche il settore anarchico deve garantire una stazione di partenza")

	# 3. FRONTIER_EXPANSE
	var front_sys := StarSystemGenerator.generate_system("FRONTIER-01", StarSystemGenerator.Archetype.FRONTIER_EXPANSE)
	assert_not_null(front_sys.find_primary_station(), "La frontiera periferica deve avere una stazione")

	# 4. DEEP_EXPLORATION
	var deep_sys := StarSystemGenerator.generate_system("DEEP-01", StarSystemGenerator.Archetype.DEEP_EXPLORATION)
	assert_not_null(deep_sys.find_primary_station(), "Lo spazio profondo deve garantire una stazione")

func test_volumetric_3d_coordinates_distribution() -> void:
	var sys := StarSystemGenerator.generate_system("VOLUMETRIC-SEED", StarSystemGenerator.Archetype.FRONTIER_EXPANSE, {"vertical_spread": 4})
	var non_zero_z_count: int = 0
	var non_zero_elevation_count: int = 0
	
	for b in sys.celestial_bodies:
		if b.coords.z != 0:
			non_zero_z_count += 1
		if b.local_elevation != 0.0 or b.has_meta("local_elevation"):
			non_zero_elevation_count += 1
			
	assert_gt(non_zero_z_count, 0, "Almeno uno o più corpi celesti devono avere quota griglia Z != 0 (spazio volumetrico reale)")
	assert_gt(non_zero_elevation_count, 0, "Almeno uno o più corpi devono possedere un'elevazione altimetrica locale != 0m")
	
	# Verifica helper get_effective_elevation()
	var test_body := CelestialBodyData.new("TEST_ELEV", "Test Entity", "STATION", Vector3i(2, 4, 2), 650.0)
	assert_eq(test_body.get_effective_elevation(), 650.0, "get_effective_elevation() deve dare precedenza a local_elevation")
	test_body.local_elevation = 0.0
	assert_eq(test_body.get_effective_elevation(), 700.0, "A local_elevation 0, deve derivare quota da coords.z * 350.0")

func test_system_discover_app_lifecycle_and_export() -> void:
	var app_scene: PackedScene = load("res://Applications/SystemDiscover/system_discover_app.tscn")
	assert_not_null(app_scene, "La scena di SystemDiscoverApp deve essere caricabile")
	
	var app: SystemDiscoverApp = app_scene.instantiate() as SystemDiscoverApp
	assert_not_null(app, "SystemDiscoverApp deve istanziarsi correttamente")
	add_child(app)
	
	# Configura controlli
	app.seed_input.text = "DISCOVER-GUT-01"
	app.archetype_option.selected = int(StarSystemGenerator.Archetype.CORE_INDUSTRIAL)
	app.current_archetype = StarSystemGenerator.Archetype.CORE_INDUSTRIAL
	app.spin_spread_z.value = 3
	
	app.generate_system_from_ui()
	assert_not_null(app.current_system, "current_system deve essere popolato")
	assert_true(app.system_title_label.text.contains("DISCOVER-GUT-01".replace("-", "").substr(0, 6)), "Il titolo deve riflettere il seed")
	
	# Test salvataggio su disco
	var safe_id := app.current_system.system_id.to_lower().replace(" ", "_").replace("-", "_")
	var file_name := "%s.tres" % safe_id
	var diegetic_path := SystemDiscoverApp.EXPORT_DIR_DIEGETIC + file_name
	var systems_path := SystemDiscoverApp.EXPORT_DIR_SYSTEMS + file_name
	
	app._on_save_pressed()
	assert_true(FileAccess.file_exists(diegetic_path), "Il file .tres deve essere salvato in Terminal Drive")
	assert_true(FileAccess.file_exists(systems_path), "Il file .tres deve essere salvato in star_systems")
	
	# Test invio alla Lobby / NetworkManager
	app.send_to_lobby()
	var nm := get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("get_session_star_system_info"):
		var info: Dictionary = nm.get_session_star_system_info()
		assert_eq(info.get("name"), app.current_system.system_name, "NetworkManager deve ricevere il sistema generato")
		
	# Pulizia
	if FileAccess.file_exists(diegetic_path):
		DirAccess.remove_absolute(diegetic_path)
	if FileAccess.file_exists(systems_path):
		DirAccess.remove_absolute(systems_path)
	var json_path := SystemDiscoverApp.EXPORT_DIR_DIEGETIC + "%s.json" % safe_id
	if FileAccess.file_exists(json_path):
		DirAccess.remove_absolute(json_path)
		
	app.queue_free()

func test_lobby_app_dynamic_system_discovery() -> void:
	# 1. Crea un sistema fittizio salvato nella cartella di esportazione di SystemDiscover
	var dummy_sys := StarSystemGenerator.generate_system("TEST-LOBBY-DISCOVERY", StarSystemGenerator.Archetype.ANARCHY_PIRATE_SECTOR)
	DirAccess.make_dir_recursive_absolute("user://star_systems/")
	var test_path := "user://star_systems/test_lobby_discovery_sys.tres"
	var err := ResourceSaver.save(dummy_sys, test_path)
	assert_eq(err, OK, "Il salvataggio del sistema di test deve restituire OK")
	
	# 2. Istanzia LobbyApp
	var lobby_scene: PackedScene = load("res://Applications/Lobby/lobby_app.tscn")
	assert_not_null(lobby_scene, "La scena di LobbyApp deve essere caricabile")
	var lobby: Control = lobby_scene.instantiate()
	add_child(lobby)
	
	var opt_button: OptionButton = lobby.get_node_or_null("%StarSystemOption")
	assert_not_null(opt_button, "L'OptionButton star_system_option deve essere presente")
	
	var found_in_options := false
	for i in range(opt_button.item_count):
		var meta_path = opt_button.get_item_metadata(i)
		if meta_path == test_path:
			found_in_options = true
			break
			
	assert_true(found_in_options, "LobbyApp deve scansionare e includere automaticamente il sistema da star_systems")
	
	# Pulizia
	lobby.queue_free()
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(test_path)

func test_space_world_volumetric_poi_elevation_spawn() -> void:
	var custom_sys := StarSystemData.new("SYS-VOL-POI", "Volumetric Sector System")
	
	# Stazione primaria a quota elevata (+550m)
	var station_body := CelestialBodyData.new(
		"STATION_HIGH_Y",
		"Stazione High Peak",
		"STATION",
		Vector3i(2, 4, 1),
		550.0
	)
	custom_sys.add_or_update_body(station_body)
	
	# Relitto spaziale a quota ribassata (-820m)
	var wreck_body := CelestialBodyData.new(
		"WRECK_LOW_Y",
		"Relitto Incrociatore Deep",
		"WRECK",
		Vector3i(5, 8, -2),
		-820.0
	)
	custom_sys.add_or_update_body(wreck_body)
	
	var wreck_sec := SectorData.new(Vector3i(5, 8, -2), "SEC-05-08--02", "Settore Relitto Profondo")
	wreck_sec.sector_type = "DERELICT_GRAVEYARD"
	wreck_sec.add_entity(wreck_body)
	custom_sys.add_or_update_custom_sector(wreck_sec)
	
	world_mgr = get_node_or_null("/root/SpaceWorldManager")
	if world_mgr == null:
		var wm_script: GDScript = load("res://Outside/space_world_manager.gd")
		world_mgr = wm_script.new()
		add_child(world_mgr)
		local_world_mgr = true
		
	world_mgr.set_star_system_data(custom_sys)
	world_mgr.set_initial_spawn_docked(false)
	world_mgr.configure_initial_station_spawn(false)
	
	# 1. Verifica quota Y della stazione primaria nello spazio 3D
	var st_entity = world_mgr.get_primary_station_entity()
	assert_not_null(st_entity, "La stazione spaziale 3D deve essere istanziata")
	assert_almost_eq(st_entity.global_position.y, 550.0, 0.5, "La stazione spaziale deve essere posizionata alla quota Y di +550m")
	
	var wp = world_mgr.active_waypoint
	assert_not_null(wp, "Il waypoint attivo deve essere configurato")
	assert_almost_eq(wp.get("pos", Vector3.ZERO).y, 550.0, 0.5, "Il waypoint della stazione deve riportare la quota Y di +550m")
	
	# 2. Caricamento zona relitto con quota negativa
	world_mgr.load_sector_zone(wreck_sec, true)
	var wreck_entity = world_mgr.get_primary_derelict_entity()
	assert_not_null(wreck_entity, "L'entità del relitto spaziale deve essere istanziata")
	assert_almost_eq(wreck_entity.global_position.y, -820.0, 0.5, "Il relitto deve essere posizionato alla quota Y di -820m")
	
	var wreck_wp = world_mgr.active_waypoint
	assert_not_null(wreck_wp, "Il waypoint del relitto deve essere configurato")
	assert_almost_eq(wreck_wp.get("pos", Vector3.ZERO).y, -820.0, 0.5, "Il waypoint del relitto deve riportare la quota Y di -820m")
