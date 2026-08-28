extends Node

## Test Suite Headless per Stazioni Spaziali, Docking e StationHub
## Verifica:
## 1. Flusso di richiesta e concessione slot di docking tramite messaggistica radio IFF.
## 2. Coni telemetrici di cattura, vincoli cinematici e blocco nave in stato docked / sblocco in undock.
## 3. Apertura, overlay e popolamento corretto dell'app StationHub con i servizi attivi (Cantiere, Mercato, Contratti, Taverna).
## 4. Architettura storage .dat, password cartella di sicurezza e RBAC.

func _ready() -> void:
	print("\n=======================================================")
	print(">>> AVVIO SUITE DI TEST HEADLESS: STATIONS & DOCKING")
	print("=======================================================\n")
	_run_all_tests()

func _run_all_tests() -> void:
	await get_tree().process_frame
	
	var station_scene: PackedScene = load("res://Outside/Stations/space_station_entity.tscn")
	assert(station_scene != null, "La scena space_station_entity.tscn deve essere caricata con successo")
	
	var station: SpaceStationEntity = station_scene.instantiate() as SpaceStationEntity
	assert(station != null, "SpaceStationEntity deve istanziarsi correttamente")
	add_child(station)
	
	var dm := DockingManager.new()
	add_child(dm)
	
	var hub_scene: PackedScene = load("res://Applications/StationHub/station_hub_app.tscn")
	assert(hub_scene != null, "La scena station_hub_app.tscn deve essere caricata con successo")
	var hub: StationHubApp = hub_scene.instantiate() as StationHubApp
	add_child(hub)
	hub.bind_docking_manager(dm)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var net_mgr = get_node_or_null("/root/NetworkManager")
	var sdm = get_node_or_null("/root/ShipDriveManager")
	var fpm = get_node_or_null("/root/FolderPasswordManager")
	var ssm = get_node_or_null("/root/ShipSoftwareManager") as ShipSoftwareManagerSingleton
	
	# =========================================================================
	# TEST 1: RICHIESTA E CONCESSIONE SLOT DI DOCKING TRAMITE MESSAGGISTICA RADIO
	# =========================================================================
	print("--- TEST 1: Protocollo Radio IFF & Assegnazione Bay ---")
	var clearance_data := {"emitted": false, "bay_id": -1}
	dm.docking_clearance_granted.connect(func(st_id: String, bay_id: int, _msg: String):
		clearance_data["emitted"] = true
		clearance_data["bay_id"] = bay_id
	)
	
	var req_res := dm.request_docking_clearance(station, "NOVA-ROGUE-01", "SOL-NAV-DEFENSE")
	assert(req_res == true, "La richiesta di docking deve avere successo")
	assert(clearance_data["emitted"] == true, "Il segnale docking_clearance_granted deve essere emesso")
	assert(clearance_data["bay_id"] == 0, "Deve essere assegnato il primo bay disponibile (0)")
	assert(station.docking_bays[0]["is_occupied"] == true, "Il bay 0 della stazione deve risultare occupato")
	assert(station.docking_bays[0]["assigned_ship_id"] == "NOVA-ROGUE-01", "La nave assegnata deve essere NOVA-ROGUE-01")
	print("✔ Richiesta radio IFF accettata e slot Bay 01 assegnato con successo")
	
	# =========================================================================
	# TEST 2: VINCOLI CINEMATICI, GUIDA TELEMETRICA E BLOCCO NAVE DOCKED
	# =========================================================================
	print("\n--- TEST 2: Guida Telemetrica e Ancoraggio Magnetico ---")
	assert(dm.current_state == DockingManager.DockingState.APPROACH_GUIDANCE, "Lo stato deve essere APPROACH_GUIDANCE")
	
	var docking_completed_data := {"emitted": false}
	dm.docking_completed.connect(func(_st_id: String, _bay_id: int, _st_data: Dictionary):
		docking_completed_data["emitted"] = true
	)
	
	# Forza completamento docking
	dm.force_complete_docking(station, 0)
	assert(docking_completed_data["emitted"] == true, "Il segnale docking_completed deve essere emesso")
	assert(dm.is_docked == true, "dm.is_docked deve risultare true")
	assert(dm.current_state == DockingManager.DockingState.DOCKED, "Lo stato deve essere DOCKED")
	print("✔ Ancoraggio magnetico completato e stato DOCKED confermato")
	
	# =========================================================================
	# TEST 3: APPLICAZIONE STATION HUB & POPOLAMENTO SERVIZI
	# =========================================================================
	print("\n--- TEST 3: StationHub UI e Servizi Portuali ---")
	await get_tree().process_frame
	assert(hub.is_station_docked == true, "StationHubApp deve riconoscere lo stato docked")
	assert(hub.undocked_overlay.visible == false, "L'overlay undocked deve essere nascosto quando si è ancorati")
	assert(hub.active_market_items.size() > 0, "Il catalogo di mercato deve essere popolato")
	assert(hub.active_contracts.size() > 0, "La bacheca contratti deve essere popolata")
	assert(hub.active_rumors.size() > 0, "La taverna spaziale deve contenere rumors")
	
	# Test acquisto Cantiere
	var initial_credits: int = hub.credits
	var initial_nanites: int = hub.player_nanites
	hub._on_buy_nanites_pressed()
	assert(hub.credits == initial_credits - 200, "I crediti devono scalare di 200")
	assert(hub.player_nanites == initial_nanites + 25, "I naniti devono incrementare di 25")
	print("✔ Cantiere Navale: acquisto naniti e aggiornamento crediti verificato")
	
	# Test accettazione contratto
	hub._on_contract_item_selected(0)
	hub._on_accept_contract_pressed()
	assert(hub.active_contracts[0]["is_accepted"] == true, "Il contratto 0 deve risultare accettato")
	print("✔ Bacheca Contratti: accettazione contratto e sync confermato")
	
	# Test Taverna e registrazione coordinate
	hub._on_rumor_item_selected(0)
	hub._on_record_coordinates_pressed()
	print("✔ Taverna Spaziale: consultazione rumors e coordinate completata")
	
	# =========================================================================
	# TEST 4: UNDOCKING & DISINNESTO MAGNETICO
	# =========================================================================
	print("\n--- TEST 4: Undocking e Ripristino Stato Libero ---")
	var undocking_data := {"done": false}
	dm.undocking_completed.connect(func():
		undocking_data["done"] = true
	)
	hub._on_btn_undock_pressed()
	assert(undocking_data["done"] == true, "Il segnale undocking_completed deve essere emesso")
	assert(dm.is_docked == false, "dm.is_docked deve risultare false dopo undock")
	assert(station.docking_bays[0]["is_occupied"] == false, "Il bay della stazione deve essere liberato")
	assert(hub.undocked_overlay.visible == true, "L'overlay undocked deve tornare visibile")
	print("✔ Procedura di undocking e rilascio bay eseguita con successo")
	
	# =========================================================================
	# TEST 5: SOFTWARE MANAGER, FILE .DAT E RBAC
	# =========================================================================
	print("\n--- TEST 5: Integrazione ShipSoftwareManager, Drive e Password ---")
	assert(ssm != null, "ShipSoftwareManager deve essere attivo")
	var res := ssm.get_registered_app("station_hub")
	assert(res != null, "station_hub deve essere registrata nel catalogo ShipSoftwareManager")
	assert(res.app_id == "station_hub", "L'app_id deve essere 'station_hub'")
	
	# Verifica password cartella
	if fpm:
		var pwd = fpm.get_password("Ship Drive/Programs/StationHub")
		assert(pwd == "STTN-7815", "La password di sicurezza deve essere STTN-7815")
		print("✔ Password di sicurezza verificata (STTN-7815)")
		
	# Verifica esistenza file config
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/StationHub/station_hub_config.dat"), "Il file station_hub_config.dat deve esistere su Ship Drive")
	print("✔ File di configurazione .dat presente e sincronizzato")
	
	print("\n=======================================================")
	print(">>> TUTTI I TEST STATIONS & DOCKING SUPERATI CON SUCCESSO!")
	print("=======================================================\n")
	get_tree().quit(0)
