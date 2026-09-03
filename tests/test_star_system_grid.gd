extends Node

## Test Runner Headless per il Modulo "Architettura del Sistema Stellare e Griglia Spaziale"
## Verifica: Coordinate e Transizioni, Occlusione e Coni d'Ombra Planetari, Visibilità Scalare Skybox e Vincoli No-FTL.

func _ready() -> void:
	print("\n=======================================================")
	print(">>> AVVIO SUITE DI TEST HEADLESS: STAR SYSTEM GRID")
	print("=======================================================\n")
	_run_all_tests()

func _run_all_tests() -> void:
	await get_tree().process_frame
	
	# =========================================================================
	# TEST 1: FORMATTAZIONE COORDINATE E PARSING SETTORI
	# =========================================================================
	print("--- TEST 1: Coordinate di Settore & Parsing ---")
	var grid_mgr_script: Script = load("res://Outside/StarSystemGrid/star_system_grid_manager.gd")
	var grid_mgr: Node = get_node_or_null("/root/StarSystemGridManager")
	if grid_mgr == null:
		grid_mgr = grid_mgr_script.new()
		add_child(grid_mgr)
		await get_tree().process_frame
	
	# Test formattazione ID
	var id_00: String = grid_mgr.format_sector_id(Vector3i(0, 0, 0))
	assert(id_00 == "SEC-00-00", "Formato coordinate (0,0,0) deve essere SEC-00-00, ottenuto: %s" % id_00)
	
	var id_04_12: String = grid_mgr.format_sector_id(Vector3i(4, 12, 0))
	assert(id_04_12 == "SEC-04-12", "Formato coordinate (4,12,0) deve essere SEC-04-12, ottenuto: %s" % id_04_12)
	
	var id_neg: String = grid_mgr.format_sector_id(Vector3i(-3, 7, 0))
	assert(id_neg == "SEC--03-07", "Formato coordinate (-3,7,0) deve essere SEC--03-07, ottenuto: %s" % id_neg)
	
	var id_3d: String = grid_mgr.format_sector_id(Vector3i(2, 5, 8))
	assert(id_3d == "SEC-02-05-08", "Formato coordinate 3D deve essere SEC-02-05-08, ottenuto: %s" % id_3d)
	
	# Test parsing ID
	var p1: Vector3i = grid_mgr.parse_sector_id("SEC-04-12")
	assert(p1 == Vector3i(4, 12, 0), "Parsing SEC-04-12 deve restituire Vector3i(4, 12, 0), ottenuto: %s" % str(p1))
	
	var p2: Vector3i = grid_mgr.parse_sector_id("SEC-00-00")
	assert(p2 == Vector3i(0, 0, 0), "Parsing SEC-00-00 deve restituire Vector3i(0, 0, 0)")
	
	var p3: Vector3i = grid_mgr.parse_sector_id("SEC-01-03-05")
	assert(p3 == Vector3i(1, 3, 5), "Parsing SEC-01-03-05 deve restituire Vector3i(1, 3, 5)")
	print("✔ Formattazione e parsing bidirezionale delle coordinate validati")
	
	# =========================================================================
	# TEST 2: TRANSIZIONI TRA CASELLE ADIACENTI E CARICAMENTO SETTORI
	# =========================================================================
	print("\n--- TEST 2: Transizioni tra Caselle Adiacenti & Generazione Dati ---")
	grid_mgr.set_current_sector_coords(Vector3i(4, 12, 0))
	assert(grid_mgr.get_current_sector_id() == "SEC-04-12", "Settore corrente iniziale deve essere SEC-04-12")
	
	var current_data: SectorData = grid_mgr.get_current_sector_data()
	assert(current_data != null, "SectorData non deve essere nullo")
	assert(current_data.sector_id == "SEC-04-12", "SectorData.sector_id non valido")
	assert(current_data.has_entity_of_type("STATION"), "SEC-04-12 deve ospitare la Stazione Spaziale Valkyrie")
	
	# Transizione adiacente verso Destra (+X)
	var moved: bool = grid_mgr.transition_to_adjacent_sector(Vector3i(1, 0, 0))
	assert(moved == true, "Transizione adiacente deve avere successo")
	assert(grid_mgr.get_current_sector_coords() == Vector3i(5, 12, 0), "Coordinate dopo passo +X devono essere (5,12,0)")
	assert(grid_mgr.get_current_sector_id() == "SEC-05-12", "ID dopo passo deve essere SEC-05-12")
	
	# Transizione adiacente verso Alto (+Y)
	grid_mgr.transition_to_adjacent_sector(Vector3i(0, 1, 0))
	assert(grid_mgr.get_current_sector_coords() == Vector3i(5, 13, 0), "Coordinate dopo passo +Y devono essere (5,13,0)")
	
	# Transizione adiacente verso Relitto (5, 14, 0)
	grid_mgr.transition_to_adjacent_sector(Vector3i(0, 1, 0))
	var wreck_sec: SectorData = grid_mgr.get_current_sector_data()
	assert(wreck_sec.has_entity_of_type("WRECK"), "SEC-05-14 deve contenere il Relitto Titan-04")
	assert(wreck_sec.sector_type == "DERELICT_GRAVEYARD", "Tipo settore per relitto deve essere DERELICT_GRAVEYARD")
	print("✔ Transizioni cinematiche discrete e caricamento deterministico dei dati confermati")
	
	# =========================================================================
	# TEST 3: CALCOLO DISTANZE, ROTTE E VINCOLO NO-FTL
	# =========================================================================
	print("\n--- TEST 3: Distanze Cinematiche, Vettori di Rotta & Vincolo No-FTL ---")
	var from_c: Vector3i = Vector3i(0, 0, 0)
	var to_c: Vector3i = Vector3i(3, 4, 0)
	var dist_sectors: float = grid_mgr.get_sector_distance(from_c, to_c)
	assert(is_equal_approx(dist_sectors, 5.0), "Distanza euclidea tra (0,0,0) e (3,4,0) deve essere 5.0 caselle")
	
	var dist_km: float = grid_mgr.calculate_kinematic_distance_km(from_c, to_c)
	assert(is_equal_approx(dist_km, 500000.0), "Distanza in km deve corrispondere a 5 * 100000 = 500.000 km")
	
	var travel_time_s: float = grid_mgr.calculate_sublight_travel_time(from_c, to_c, 500.0)
	assert(is_equal_approx(travel_time_s, 1000.0), "Tempo di crociera sub-luce (500 km/s) deve essere 1000.0 s")
	
	var route_vec: Vector3 = grid_mgr.get_route_vector(from_c, to_c)
	assert(is_equal_approx(route_vec.length(), 1.0), "Il vettore di rotta deve essere normalizzato")
	assert(is_equal_approx(route_vec.x, 0.6) and is_equal_approx(route_vec.y, 0.8), "Direzione rotta normalizzata valida (0.6, 0.8, 0.0)")
	print("✔ Calcoli rotte sub-luce e distanze cinematiche senza FTL validati")
	
	# =========================================================================
	# TEST 4: ILLUMINAZIONE DINAMICA E CONI D'OMBRA PLANETARI (ECLISSI)
	# =========================================================================
	print("\n--- TEST 4: Calcolo Occlusione, Coni d'Ombra & Blackout Solare ---")
	# Posizione stella primaria al centro (0,0,0)
	# Pianeta Terra Nova a (4, 8, 0)
	# Settore direttamente allineato dietro Terra Nova: es. (8, 16, 0) o (5, 10, 0)
	var unoccluded_sec: Dictionary = grid_mgr.calculate_planetary_occlusion(Vector3i(1, 0, 0))
	assert(unoccluded_sec["is_occluded"] == false, "Un settore con linea di vista libera verso la stella non deve essere occluso")
	assert(unoccluded_sec["solar_blackout"] == false, "Nessun blackout solare in linea di vista aperta")
	assert(unoccluded_sec["light_energy_factor"] == 1.0, "Fattore di luce solare deve essere 1.0")
	
	# Verifica settore dietro Terra Nova lungo l'asse (0,0,0) -> (4,8,0) -> (8,16,0)
	var shadow_sec: Dictionary = grid_mgr.calculate_planetary_occlusion(Vector3i(8, 16, 0))
	assert(shadow_sec["is_occluded"] == true, "Settore allineato dietro Terra Nova (8,16,0) deve risultare in cono d'ombra")
	var occ_body: Dictionary = shadow_sec["occluding_body"]
	assert(occ_body["id"] == "PLANET_TERRA_NOVA", "Il corpo occludente identificato deve essere PLANET_TERRA_NOVA")
	assert(shadow_sec["solar_blackout"] == true, "Deve scattare lo stato di blackout dei pannelli solari")
	assert(float(shadow_sec["light_energy_factor"]) < 0.2, "L'energia luminosa deve essere drasticamente ridotta nel cono d'ombra")
	
	# Test direzione luce dal centro stella
	var light_dir: Vector3 = grid_mgr.get_light_direction_from_star(Vector3i(4, 0, 0))
	assert(light_dir.x < 0.0, "Il vettore di luce solare per un settore a +X deve puntare verso -X (verso la sorgente)")
	print("✔ Geometria del cono d'ombra planetario, occlusione ed effetto blackout solare verificati")
	
	# =========================================================================
	# TEST 5: VISIBILITÀ SCALARE DELLE ENTITÀ SULLO SKYBOX DIEGETICO
	# =========================================================================
	print("\n--- TEST 5: Visibilità Scalare Entità sullo Skybox Diegetico ---")
	# Osservatore in SEC-04-12
	grid_mgr.set_current_sector_coords(Vector3i(4, 12, 0))
	var visible_ents: Array = grid_mgr.get_visible_system_entities(Vector3i(4, 12, 0))
	assert(visible_ents.size() > 0, "La lista entità visibili deve essere popolata")
	
	# Verifica Stella Primaria (a ~12.6 caselle, max range 40 caselle): DEVE ESSERE VISIBILE
	var star_found: bool = false
	for e in visible_ents:
		if e["type"] == "STAR":
			star_found = true
			assert(float(e["distance_sectors"]) > 10.0 and float(e["distance_sectors"]) < 15.0, "Distanza stella corretta")
			assert(float(e["apparent_brightness"]) > 0.0, "La stella deve avere luminosità apparente positiva")
			break
	assert(star_found, "La Stella Primaria deve essere visibile a oltre 12 caselle")
	
	# Verifica Gigante Gassoso Kronos a (8, 20, 0) da (4, 12, 0) -> diff (4, 8, 0) -> dist ~8.94 caselle (max range 15): VISIBILE
	var kronos_found: bool = false
	for e in visible_ents:
		if e["id"] == "GAS_GIANT_KRONOS":
			kronos_found = true
			assert(float(e["apparent_angular_size"]) > 0.0, "Il gigante gassoso deve avere una scala angolare proiettata valida")
			break
	assert(kronos_found, "Gigante Gassoso Kronos deve essere visibile entro 10-15 caselle")
	
	# Verifica Gigante Gassoso Aetheris a (-12, 16, 0) da (4, 12, 0) -> diff (-16, 4, 0) -> dist ~16.49 caselle (range 15): NON VISIBILE
	var aetheris_found: bool = false
	for e in visible_ents:
		if e["id"] == "GAS_GIANT_AETHER":
			aetheris_found = true
			break
	assert(not aetheris_found, "Aetheris a 16.5 caselle (> 15) NON deve essere visibile sullo skybox")
	
	# Verifica Stazione Locale Valkyrie a (4, 12, 0): dist = 0 -> locale
	var valkyrie_found: bool = false
	for e in visible_ents:
		if e["id"] == "STATION_VALKYRIE":
			valkyrie_found = true
			assert(e["is_in_current_sector"] == true, "La stazione Valkyrie deve risultare nel settore corrente")
			break
	assert(valkyrie_found, "Stazione Valkyrie presente nei dati del settore")
	print("✔ Raggi scalari di proiezione diegetica per Stelle, Giganti Gassosi, Pianeti e Stazioni convalidati")
	
	# =========================================================================
	# TEST 6: COMPONENTE DYNAMIC SPACE SKYBOX
	# =========================================================================
	print("\n--- TEST 6: Integrazione DynamicSpaceSkybox ---")
	var skybox: DynamicSpaceSkybox = DynamicSpaceSkybox.new()
	skybox.set_grid_manager(grid_mgr)
	add_child(skybox)
	await get_tree().process_frame
	
	skybox.update_skybox()
	var rendered: Array = skybox.get_rendered_entities()
	assert(rendered.size() > 0, "DynamicSpaceSkybox deve istanziare entità proiettate sullo skybox")
	assert(skybox.celestial_container.get_child_count() > 0, "Il contenitore celestiale deve avere nodi impostori istanziati")
	
	# Verifica proiezione sul raggio SKY_SPHERE_RADIUS (400 m)
	var first_impostor: Node3D = skybox.celestial_container.get_child(0) as Node3D
	assert(first_impostor != null, "L'impostore deve essere un Node3D / MeshInstance3D")
	assert(first_impostor is MeshInstance3D, "L'impostore deve essere una MeshInstance3D visibile")
	assert(is_equal_approx(first_impostor.position.length(), DynamicSpaceSkybox.SKY_SPHERE_RADIUS), "L'impostore deve essere posizionato sulla sfera celeste dello skybox (400m)")
	
	skybox.queue_free()
	print("✔ Componente DynamicSpaceSkybox ed elaborazione rendering confermati")
	
	print("\n=======================================================")
	print("✔ TUTTI I TEST STAR SYSTEM GRID COMPLETATI CON SUCCESSO!")
	print("=======================================================\n")
	get_tree().quit(0)
