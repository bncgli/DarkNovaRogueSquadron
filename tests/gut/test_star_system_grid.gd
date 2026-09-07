extends GutTest

## Test GUT per il Modulo "Architettura del Sistema Stellare e Griglia Spaziale".
## Verifica: Coordinate e Transizioni, Occlusione e Coni d'Ombra Planetari, Visibilità Scalare
## Skybox e Vincolo No-FTL. Le funzioni condividono lo stato reale dell'autoload
## StarSystemGridManager e sono eseguite in ordine di dichiarazione (comportamento di GUT).

var grid_mgr: Node
var local_grid_mgr: bool = false

func before_all() -> void:
	grid_mgr = get_node_or_null("/root/StarSystemGridManager")
	if grid_mgr == null:
		var grid_mgr_script: Script = load("res://Outside/StarSystemGrid/star_system_grid_manager.gd")
		grid_mgr = grid_mgr_script.new()
		add_child(grid_mgr)
		local_grid_mgr = true
		await get_tree().process_frame

func after_all() -> void:
	if local_grid_mgr and is_instance_valid(grid_mgr):
		grid_mgr.free()

func test_sector_coordinate_formatting_and_parsing() -> void:
	# Test formattazione ID
	var id_00: String = grid_mgr.format_sector_id(Vector3i(0, 0, 0))
	assert_eq(id_00, "SEC-00-00", "Formato coordinate (0,0,0) deve essere SEC-00-00")

	var id_04_12: String = grid_mgr.format_sector_id(Vector3i(4, 12, 0))
	assert_eq(id_04_12, "SEC-04-12", "Formato coordinate (4,12,0) deve essere SEC-04-12")

	var id_neg: String = grid_mgr.format_sector_id(Vector3i(-3, 7, 0))
	assert_eq(id_neg, "SEC--03-07", "Formato coordinate (-3,7,0) deve essere SEC--03-07")

	var id_3d: String = grid_mgr.format_sector_id(Vector3i(2, 5, 8))
	assert_eq(id_3d, "SEC-02-05-08", "Formato coordinate 3D deve essere SEC-02-05-08")

	# Test parsing ID
	var p1: Vector3i = grid_mgr.parse_sector_id("SEC-04-12")
	assert_eq(p1, Vector3i(4, 12, 0), "Parsing SEC-04-12 deve restituire Vector3i(4, 12, 0)")

	var p2: Vector3i = grid_mgr.parse_sector_id("SEC-00-00")
	assert_eq(p2, Vector3i(0, 0, 0), "Parsing SEC-00-00 deve restituire Vector3i(0, 0, 0)")

	var p3: Vector3i = grid_mgr.parse_sector_id("SEC-01-03-05")
	assert_eq(p3, Vector3i(1, 3, 5), "Parsing SEC-01-03-05 deve restituire Vector3i(1, 3, 5)")

func test_adjacent_sector_transitions_and_deterministic_data() -> void:
	grid_mgr.set_current_sector_coords(Vector3i(4, 12, 0))
	assert_eq(grid_mgr.get_current_sector_id(), "SEC-04-12", "Settore corrente iniziale deve essere SEC-04-12")

	var current_data: SectorData = grid_mgr.get_current_sector_data()
	assert_not_null(current_data, "SectorData non deve essere nullo")
	assert_eq(current_data.sector_id, "SEC-04-12", "SectorData.sector_id non valido")
	assert_true(current_data.has_entity_of_type("STATION"), "SEC-04-12 deve ospitare la Stazione Spaziale Valkyrie")

	# Transizione adiacente verso Destra (+X)
	var moved: bool = grid_mgr.transition_to_adjacent_sector(Vector3i(1, 0, 0))
	assert_true(moved, "Transizione adiacente deve avere successo")
	assert_eq(grid_mgr.get_current_sector_coords(), Vector3i(5, 12, 0), "Coordinate dopo passo +X devono essere (5,12,0)")
	assert_eq(grid_mgr.get_current_sector_id(), "SEC-05-12", "ID dopo passo deve essere SEC-05-12")

	# Transizione adiacente verso Alto (+Y)
	grid_mgr.transition_to_adjacent_sector(Vector3i(0, 1, 0))
	assert_eq(grid_mgr.get_current_sector_coords(), Vector3i(5, 13, 0), "Coordinate dopo passo +Y devono essere (5,13,0)")

	# Transizione adiacente verso Relitto (5, 14, 0)
	grid_mgr.transition_to_adjacent_sector(Vector3i(0, 1, 0))
	var wreck_sec: SectorData = grid_mgr.get_current_sector_data()
	assert_true(wreck_sec.has_entity_of_type("WRECK"), "SEC-05-14 deve contenere il Relitto Titan-04")
	assert_eq(wreck_sec.sector_type, "DERELICT_GRAVEYARD", "Tipo settore per relitto deve essere DERELICT_GRAVEYARD")

func test_kinematic_distances_routes_and_no_ftl_constraint() -> void:
	var from_c: Vector3i = Vector3i(0, 0, 0)
	var to_c: Vector3i = Vector3i(3, 4, 0)
	var dist_sectors: float = grid_mgr.get_sector_distance(from_c, to_c)
	assert_true(is_equal_approx(dist_sectors, 5.0), "Distanza euclidea tra (0,0,0) e (3,4,0) deve essere 5.0 caselle")

	var dist_km: float = grid_mgr.calculate_kinematic_distance_km(from_c, to_c)
	assert_true(is_equal_approx(dist_km, 500000.0), "Distanza in km deve corrispondere a 5 * 100000 = 500.000 km")

	var travel_time_s: float = grid_mgr.calculate_sublight_travel_time(from_c, to_c, 500.0)
	assert_true(is_equal_approx(travel_time_s, 1000.0), "Tempo di crociera sub-luce (500 km/s) deve essere 1000.0 s")

	var route_vec: Vector3 = grid_mgr.get_route_vector(from_c, to_c)
	assert_true(is_equal_approx(route_vec.length(), 1.0), "Il vettore di rotta deve essere normalizzato")
	assert_true(is_equal_approx(route_vec.x, 0.6) and is_equal_approx(route_vec.y, 0.8), "Direzione rotta normalizzata valida (0.6, 0.8, 0.0)")

func test_planetary_occlusion_shadow_cones_and_solar_blackout() -> void:
	# Posizione stella primaria al centro (0,0,0)
	# Pianeta Terra Nova a (4, 8, 0)
	# Settore direttamente allineato dietro Terra Nova: es. (8, 16, 0) o (5, 10, 0)
	var unoccluded_sec: Dictionary = grid_mgr.calculate_planetary_occlusion(Vector3i(1, 0, 0))
	assert_false(unoccluded_sec["is_occluded"], "Un settore con linea di vista libera verso la stella non deve essere occluso")
	assert_false(unoccluded_sec["solar_blackout"], "Nessun blackout solare in linea di vista aperta")
	assert_eq(unoccluded_sec["light_energy_factor"], 1.0, "Fattore di luce solare deve essere 1.0")

	# Verifica settore dietro Terra Nova lungo l'asse (0,0,0) -> (4,8,0) -> (8,16,0)
	var shadow_sec: Dictionary = grid_mgr.calculate_planetary_occlusion(Vector3i(8, 16, 0))
	assert_true(shadow_sec["is_occluded"], "Settore allineato dietro Terra Nova (8,16,0) deve risultare in cono d'ombra")
	var occ_body: Dictionary = shadow_sec["occluding_body"]
	assert_eq(occ_body["id"], "PLANET_TERRA_NOVA", "Il corpo occludente identificato deve essere PLANET_TERRA_NOVA")
	assert_true(shadow_sec["solar_blackout"], "Deve scattare lo stato di blackout dei pannelli solari")
	assert_lt(float(shadow_sec["light_energy_factor"]), 0.2, "L'energia luminosa deve essere drasticamente ridotta nel cono d'ombra")

	# Test direzione luce dal centro stella
	var light_dir: Vector3 = grid_mgr.get_light_direction_from_star(Vector3i(4, 0, 0))
	assert_lt(light_dir.x, 0.0, "Il vettore di luce solare per un settore a +X deve puntare verso -X (verso la sorgente)")

func test_scalar_entity_visibility_on_diegetic_skybox() -> void:
	# Osservatore in SEC-04-12
	grid_mgr.set_current_sector_coords(Vector3i(4, 12, 0))
	var visible_ents: Array = grid_mgr.get_visible_system_entities(Vector3i(4, 12, 0))
	assert_gt(visible_ents.size(), 0, "La lista entità visibili deve essere popolata")

	# Verifica Stella Primaria (a ~12.6 caselle, max range 40 caselle): DEVE ESSERE VISIBILE
	var star_found: bool = false
	for e in visible_ents:
		if e["type"] == "STAR":
			star_found = true
			assert_true(float(e["distance_sectors"]) > 10.0 and float(e["distance_sectors"]) < 15.0, "Distanza stella corretta")
			assert_gt(float(e["apparent_brightness"]), 0.0, "La stella deve avere luminosità apparente positiva")
			break
	assert_true(star_found, "La Stella Primaria deve essere visibile a oltre 12 caselle")

	# Verifica Gigante Gassoso Kronos a (8, 20, 0) da (4, 12, 0) -> diff (4, 8, 0) -> dist ~8.94 caselle (max range 15): VISIBILE
	var kronos_found: bool = false
	for e in visible_ents:
		if e["id"] == "GAS_GIANT_KRONOS":
			kronos_found = true
			assert_gt(float(e["apparent_angular_size"]), 0.0, "Il gigante gassoso deve avere una scala angolare proiettata valida")
			break
	assert_true(kronos_found, "Gigante Gassoso Kronos deve essere visibile entro 10-15 caselle")

	# Verifica Gigante Gassoso Aetheris a (-12, 16, 0) da (4, 12, 0) -> diff (-16, 4, 0) -> dist ~16.49 caselle (range 15): NON VISIBILE
	var aetheris_found: bool = false
	for e in visible_ents:
		if e["id"] == "GAS_GIANT_AETHER":
			aetheris_found = true
			break
	assert_false(aetheris_found, "Aetheris a 16.5 caselle (> 15) NON deve essere visibile sullo skybox")

	# Verifica Stazione Locale Valkyrie a (4, 12, 0): dist = 0 -> locale
	var valkyrie_found: bool = false
	for e in visible_ents:
		if e["id"] == "STATION_VALKYRIE":
			valkyrie_found = true
			assert_true(e["is_in_current_sector"], "La stazione Valkyrie deve risultare nel settore corrente")
			break
	assert_true(valkyrie_found, "Stazione Valkyrie presente nei dati del settore")

func test_dynamic_space_skybox_integration() -> void:
	var skybox: DynamicSpaceSkybox = DynamicSpaceSkybox.new()
	skybox.set_grid_manager(grid_mgr)
	add_child_autofree(skybox)
	await get_tree().process_frame

	skybox.update_skybox()
	var rendered: Array = skybox.get_rendered_entities()
	assert_gt(rendered.size(), 0, "DynamicSpaceSkybox deve istanziare entità proiettate sullo skybox")
	assert_gt(skybox.celestial_container.get_child_count(), 0, "Il contenitore celestiale deve avere nodi impostori istanziati")

	# Verifica proiezione sul raggio SKY_SPHERE_RADIUS (400 m)
	var first_impostor: Node3D = skybox.celestial_container.get_child(0) as Node3D
	assert_not_null(first_impostor, "L'impostore deve essere un Node3D / MeshInstance3D")
	assert_true(first_impostor is MeshInstance3D, "L'impostore deve essere una MeshInstance3D visibile")
	assert_true(is_equal_approx(first_impostor.position.length(), DynamicSpaceSkybox.SKY_SPHERE_RADIUS), "L'impostore deve essere posizionato sulla sfera celeste dello skybox (400m)")
