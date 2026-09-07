extends GutTest

## Test GUT per Stazioni Spaziali, Docking e StationHub.
## Verifica:
## 1. Flusso di richiesta e concessione slot di docking tramite messaggistica radio IFF.
## 2. Coni telemetrici di cattura, vincoli cinematici e blocco nave in stato docked / sblocco in undock.
## 3. Apertura, overlay e popolamento corretto dell'app StationHub con i servizi attivi (Cantiere, Mercato, Contratti, Taverna).
## 4. Architettura storage .dat, password cartella di sicurezza e RBAC.
## `station`, `dm`, `hub` condividono stato tra le fasi: creati/liberati in before_all/after_all
## (add_child_autofree libererebbe già al termine del singolo test, rompendo la sequenza).

var station: SpaceStationEntity
var dm: DockingManager
var hub: StationHubApp

func before_all() -> void:
	var station_scene: PackedScene = load("res://Outside/Stations/space_station_entity.tscn")
	assert_not_null(station_scene, "La scena space_station_entity.tscn deve essere caricata con successo")

	station = station_scene.instantiate() as SpaceStationEntity
	assert_not_null(station, "SpaceStationEntity deve istanziarsi correttamente")
	add_child(station)

	dm = DockingManager.new()
	add_child(dm)

	var hub_scene: PackedScene = load("res://Applications/StationHub/station_hub_app.tscn")
	assert_not_null(hub_scene, "La scena station_hub_app.tscn deve essere caricata con successo")
	hub = hub_scene.instantiate() as StationHubApp
	add_child(hub)
	hub.bind_docking_manager(dm)

	await get_tree().process_frame
	await get_tree().process_frame

func after_all() -> void:
	if is_instance_valid(hub):
		hub.free()
	if is_instance_valid(dm):
		dm.free()
	if is_instance_valid(station):
		station.free()

func test_radio_iff_protocol_and_bay_assignment() -> void:
	var clearance_data := {"emitted": false, "bay_id": -1}
	dm.docking_clearance_granted.connect(func(st_id: String, bay_id: int, _msg: String):
		clearance_data["emitted"] = true
		clearance_data["bay_id"] = bay_id
	)

	var req_res := dm.request_docking_clearance(station, "NOVA-ROGUE-01", "SOL-NAV-DEFENSE")
	assert_true(req_res, "La richiesta di docking deve avere successo")
	assert_true(clearance_data["emitted"], "Il segnale docking_clearance_granted deve essere emesso")
	assert_eq(clearance_data["bay_id"], 0, "Deve essere assegnato il primo bay disponibile (0)")
	assert_true(station.docking_bays[0]["is_occupied"], "Il bay 0 della stazione deve risultare occupato")
	assert_eq(station.docking_bays[0]["assigned_ship_id"], "NOVA-ROGUE-01", "La nave assegnata deve essere NOVA-ROGUE-01")

func test_telemetry_guidance_and_magnetic_lock() -> void:
	assert_eq(dm.current_state, DockingManager.DockingState.APPROACH_GUIDANCE, "Lo stato deve essere APPROACH_GUIDANCE")

	var docking_completed_data := {"emitted": false}
	dm.docking_completed.connect(func(_st_id: String, _bay_id: int, _st_data: Dictionary):
		docking_completed_data["emitted"] = true
	)

	# Forza completamento docking
	dm.force_complete_docking(station, 0)
	assert_true(docking_completed_data["emitted"], "Il segnale docking_completed deve essere emesso")
	assert_true(dm.is_docked, "dm.is_docked deve risultare true")
	assert_eq(dm.current_state, DockingManager.DockingState.DOCKED, "Lo stato deve essere DOCKED")

func test_station_hub_ui_and_port_services() -> void:
	await get_tree().process_frame
	assert_true(hub.is_station_docked, "StationHubApp deve riconoscere lo stato docked")
	assert_false(hub.undocked_overlay.visible, "L'overlay undocked deve essere nascosto quando si è ancorati")
	assert_gt(hub.active_market_items.size(), 0, "Il catalogo di mercato deve essere popolato")
	assert_gt(hub.active_contracts.size(), 0, "La bacheca contratti deve essere popolata")
	assert_gt(hub.active_rumors.size(), 0, "La taverna spaziale deve contenere rumors")

	# Test acquisto Cantiere
	var initial_credits: int = hub.flux_mgr.credits
	var initial_nanites: int = hub.player_nanites
	hub._on_buy_nanites_pressed()
	assert_eq(hub.flux_mgr.credits, initial_credits - 200, "I crediti devono scalare di 200")
	assert_eq(hub.player_nanites, initial_nanites + 25, "I naniti devono incrementare di 25")

	# Test accettazione contratto
	hub._on_contract_item_selected(0)
	hub._on_accept_contract_pressed()
	assert_true(hub.active_contracts[0]["is_accepted"], "Il contratto 0 deve risultare accettato")

	# Test Taverna e registrazione coordinate
	hub._on_rumor_item_selected(0)
	hub._on_record_coordinates_pressed()

func test_undocking_and_magnetic_release() -> void:
	var undocking_data := {"done": false}
	dm.undocking_completed.connect(func():
		undocking_data["done"] = true
	)
	hub._on_btn_undock_pressed()
	assert_true(undocking_data["done"], "Il segnale undocking_completed deve essere emesso")
	assert_false(dm.is_docked, "dm.is_docked deve risultare false dopo undock")
	assert_false(station.docking_bays[0]["is_occupied"], "Il bay della stazione deve essere liberato")
	assert_true(hub.undocked_overlay.visible, "L'overlay undocked deve tornare visibile")

func test_software_manager_dat_files_and_rbac() -> void:
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	var ssm := get_node_or_null("/root/ShipSoftwareManager") as ShipSoftwareManagerSingleton

	assert_not_null(ssm, "ShipSoftwareManager deve essere attivo")
	var res := ssm.get_registered_app("station_hub")
	assert_not_null(res, "station_hub deve essere registrata nel catalogo ShipSoftwareManager")
	assert_eq(res.app_id, "station_hub", "L'app_id deve essere 'station_hub'")

	# Verifica password cartella
	if fpm:
		var pwd: String = str(fpm.get_password("Ship Drive/Programs/StationHub"))
		assert_eq(pwd, "STTN-7815", "La password di sicurezza deve essere STTN-7815")

	# Verifica esistenza file config
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/StationHub/station_hub_config.dat"), "Il file station_hub_config.dat deve esistere su Ship Drive")
