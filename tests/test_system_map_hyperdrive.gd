extends Node

## Test Runner Headless per l'Applicazione "System Map" e l'Integrazione Rotte Hyperdrive con Flight Control.
## Verifica:
## 1. Caricamento griglia e macro-corpi celesti da StarSystemData su System Map.
## 2. Calcolo rotta (distanza, ETA, costi energetici) e trasmissione segnale `route_plotted`.
## 3. Ricezione rotta in Flight Control, visualizzazione e allineamento vettore Hyperdrive.
## 4. Ingaggio Hyperdrive e transizione corretta di settore su StarSystemGridManager.

func _ready() -> void:
	print("\n=======================================================")
	print(">>> AVVIO SUITE DI TEST HEADLESS: SYSTEM MAP & HYPERDRIVE")
	print("=======================================================\n")
	_run_all_tests()

func _run_all_tests() -> void:
	await get_tree().process_frame
	
	# =========================================================================
	# TEST 1: CARICAMENTO DATI SISTEMA E SETTORI SU STARSYSTEMGRIDMANAGER
	# =========================================================================
	print("--- TEST 1: Inizializzazione Dati StarSystem & Posizione Iniziale ---")
	var grid_mgr: Node = get_node_or_null("/root/StarSystemGridManager")
	if grid_mgr == null:
		var grid_mgr_script: Script = load("res://Outside/StarSystemGrid/star_system_grid_manager.gd")
		grid_mgr = grid_mgr_script.new()
		grid_mgr.name = "StarSystemGridManager"
		get_tree().root.add_child(grid_mgr)
		await get_tree().process_frame

	grid_mgr.load_star_system(StarSystemData.get_default_star_system())
	var cur_coords: Vector3i = grid_mgr.get_current_sector_coords()
	assert(cur_coords != Vector3i.ZERO, "Coordinate iniziali devono essere valide, ottenuto: %s" % str(cur_coords))
	assert(grid_mgr.system_celestial_bodies.size() > 0, "I corpi celesti devono essere caricati nel sistema")
	print("✔ Inizializzazione e catalogo astronomico confermati (settore attuale: %s)" % str(cur_coords))

	# =========================================================================
	# TEST 2: ISTANZIAZIONE SYSTEM MAP APP E SELEZIONE SETTORE
	# =========================================================================
	print("\n--- TEST 2: Istanziazione SystemMapApp & Selezione Settore ---")
	# Imposta esplicitamente la nave in (4, 11, 0) per i test di rotta verso Valkyrie (4, 12, 0)
	grid_mgr.set_current_sector_coords(Vector3i(4, 11, 0))

	var sys_map_scene: PackedScene = load("res://Applications/SystemMap/system_map_app.tscn")
	assert(sys_map_scene != null, "Scena system_map_app.tscn non trovata")
	
	var sys_map_app: SystemMapApp = sys_map_scene.instantiate() as SystemMapApp
	assert(sys_map_app != null, "Istanziazione di SystemMapApp fallita")
	add_child(sys_map_app)
	await get_tree().process_frame

	# Selezione del settore target (es. Stazione Valkyrie a SEC-04-12)
	var target_sector := Vector3i(4, 12, 0)
	sys_map_app.select_sector(target_sector)
	assert(sys_map_app.selected_sector_coords == target_sector, "Settore selezionato deve corrispondere a (4,12,0)")
	assert(not sys_map_app.calculated_route.is_empty(), "La rotta deve essere calcolata automaticamente alla selezione")
	assert(is_equal_approx(sys_map_app.calculated_route["distance_sectors"], 1.0), "Distanza deve essere pari a 1.0 settore, ottenuto: %f" % sys_map_app.calculated_route["distance_sectors"])
	assert(sys_map_app.calculated_route["course_vector"] == Vector3(0, 1, 0), "Vettore di rotta verso (4,12,0) deve essere (0,1,0)")
	print("✔ Selezione e calcolo rotta preliminare su System Map validati")

	# =========================================================================
	# TEST 3: TRASMISSIONE ROTTA VERSO FLIGHT CONTROL TRAMITE SEGNALE
	# =========================================================================
	print("\n--- TEST 3: Trasmissione Segnale route_plotted & Ricezione ---")
	var signal_data := {
		"emitted": false,
		"target": Vector3i.ZERO,
		"vector": Vector3.ZERO
	}

	sys_map_app.route_plotted.connect(func(t_coords: Vector3i, c_vec: Vector3) -> void:
		signal_data["emitted"] = true
		signal_data["target"] = t_coords
		signal_data["vector"] = c_vec
	)

	# Invio rotta da System Map
	var res_route: Dictionary = sys_map_app.send_route_to_flight_control()
	await get_tree().process_frame

	assert(signal_data["emitted"] == true, "Il segnale route_plotted deve essere emesso")
	assert(signal_data["target"] == target_sector, "Target trasmesso errato: %s" % str(signal_data["target"]))
	assert(signal_data["vector"] == Vector3(0, 1, 0), "Vettore trasmesso errato: %s" % str(signal_data["vector"]))
	
	var active_route: Dictionary = grid_mgr.get_active_route()
	assert(not active_route.is_empty(), "StarSystemGridManager deve memorizzare la rotta attiva")
	assert(active_route["target_coords"] == target_sector, "Rotta attiva target errato")
	print("✔ Trasmissione della rotta di navigazione completata con successo")

	# =========================================================================
	# TEST 4: INTEGRAZIONE FLIGHT CONTROL, AGGANCIO E ALLINEAMENTO VETTORE
	# =========================================================================
	print("\n--- TEST 4: Aggancio Vettore & Allineamento in Flight Control ---")
	var flight_app_scene: PackedScene = load("res://Applications/FlightControl/flight_control_app.tscn")
	assert(flight_app_scene != null, "Scena flight_control_app.tscn non trovata")

	var flight_app: FlightControlApp = flight_app_scene.instantiate() as FlightControlApp
	add_child(flight_app)
	await get_tree().process_frame

	flight_app._on_route_plotted(target_sector, Vector3(0, 1, 0))
	assert(not flight_app.active_hyperdrive_route.is_empty(), "Flight Control deve memorizzare la rotta Hyperdrive")
	
	# Allineamento automatico della nave
	flight_app.align_to_hyperdrive_vector()
	assert(flight_app.is_hyperdrive_aligned(), "La nave deve risultare allineata al vettore di navigazione")
	print("✔ Aggancio vettore e allineamento prua in Flight Control verificati")

	# =========================================================================
	# TEST 5: ATTIVAZIONE HYPERDRIVE E TRANSIZIONE SETTORE
	# =========================================================================
	print("\n--- TEST 5: Attivazione Hyperdrive & Salto di Settore ---")
	var transit_status := {
		"started": false,
		"completed": false,
		"destination": Vector3i.ZERO
	}

	grid_mgr.hyperdrive_transit_started.connect(func(dest: Vector3i) -> void:
		transit_status["started"] = true
	)
	grid_mgr.hyperdrive_transit_completed.connect(func(dest: Vector3i) -> void:
		transit_status["completed"] = true
		transit_status["destination"] = dest
	)

	var engage_res: Dictionary = flight_app.engage_hyperdrive()
	assert(engage_res.get("success", false) == true, "L'attivazione Hyperdrive deve avere successo: %s" % str(engage_res))
	assert(transit_status["started"] == true, "Segnale hyperdrive_transit_started non emesso")
	assert(transit_status["completed"] == true, "Segnale hyperdrive_transit_completed non emesso")
	assert(transit_status["destination"] == target_sector, "Destinazione raggiunta diversa dal settore target")
	assert(grid_mgr.get_current_sector_coords() == target_sector, "Il settore corrente deve essere aggiornato a SEC-04-12")
	assert(grid_mgr.get_current_sector_id() == "SEC-04-12", "ID settore corrente non aggiornato")
	print("✔ Transizione di settore con Hyperdrive eseguita con successo")

	# Pulizia nodi di test
	sys_map_app.queue_free()
	flight_app.queue_free()

	print("\n=======================================================")
	print("✔ TUTTI I TEST SYSTEM MAP & HYPERDRIVE COMPLETATI CON SUCCESSO!")
	print("=======================================================\n")
	get_tree().quit(0)
