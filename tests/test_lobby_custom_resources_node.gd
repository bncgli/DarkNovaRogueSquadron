extends Node

func _ready() -> void:
	print("--- TEST LOBBY CUSTOM RESOURCES SELECTION & SYNC ---")
	_run_tests.call_deferred()

func _run_tests() -> void:
	await get_tree().process_frame
	
	var net: GameNetworkManager = get_node_or_null("/root/NetworkManager") as GameNetworkManager
	var swm: SpaceWorldManagerSingleton = get_node_or_null("/root/SpaceWorldManager") as SpaceWorldManagerSingleton
	var grid_mgr: StarSystemGridManagerSingleton = get_node_or_null("/root/StarSystemGridManager") as StarSystemGridManagerSingleton
	
	if net == null or swm == null or grid_mgr == null:
		print("FAIL: Autoloads non trovati!")
		get_tree().quit(1)
		return
	
	var lobby_scene: PackedScene = load("res://Applications/Lobby/lobby_app.tscn")
	if lobby_scene == null:
		print("FAIL: Impossibile caricare lobby_app.tscn!")
		get_tree().quit(1)
		return
	
	var lobby_app = lobby_scene.instantiate()
	add_child(lobby_app)
	await get_tree().process_frame
	
	# =========================================================================
	# TEST 1: Default Session Resources & UI Elements
	# =========================================================================
	print("\n--- Test 1: Risorse Default e Presenza Controlli UI ---")
	var ship_opt: OptionButton = lobby_app.get_node_or_null("%ShipBlueprintOption")
	var sys_opt: OptionButton = lobby_app.get_node_or_null("%StarSystemOption")
	var ship_btn: Button = lobby_app.get_node_or_null("%SelectShipFileButton")
	var sys_btn: Button = lobby_app.get_node_or_null("%SelectSystemFileButton")
	var ship_preview: Label = lobby_app.get_node_or_null("%ShipPreviewLabel")
	var sys_preview: Label = lobby_app.get_node_or_null("%SystemPreviewLabel")
	var badge: Label = lobby_app.get_node_or_null("%ResPermissionBadge")
	
	assert(ship_opt != null, "ShipBlueprintOption deve esistere")
	assert(sys_opt != null, "StarSystemOption deve esistere")
	assert(ship_btn != null, "SelectShipFileButton deve esistere")
	assert(sys_btn != null, "SelectSystemFileButton deve esistere")
	assert(ship_preview != null, "ShipPreviewLabel deve esistere")
	assert(sys_preview != null, "SystemPreviewLabel deve esistere")
	assert(badge != null, "ResPermissionBadge deve esistere")
	
	var def_bp := net.get_selected_ship_blueprint()
	var def_sys := net.get_selected_star_system()
	assert(def_bp != null and def_bp.ship_id == "dark_nova_corvette", "Blueprint predefinita deve essere Dark Nova Corvette")
	assert(def_sys != null and def_sys.system_id == "SYS-HELIOS-01", "Sistema predefinito deve essere Helios Nova System")
	print("✔ Test 1 superato: Risorse di default e controlli UI inizializzati.")
	
	# =========================================================================
	# TEST 2: Host / Solo Mode - Modifica Risorse Nave e Sistema Stellare
	# =========================================================================
	print("\n--- Test 2: Solo Mode / Host - Modifica e Anteprima Risorse ---")
	net.start_solo_game("Comandante Test")
	await get_tree().process_frame
	
	assert(net.is_solo_mode and net.is_host, "La modalità Solo deve essere attiva come Host")
	assert(ship_opt.disabled == false, "In Solo Mode il selettore nave deve essere abilitato")
	assert(sys_opt.disabled == false, "In Solo Mode il selettore sistema deve essere abilitato")
	assert(badge.text.contains("SOLO") or badge.text.contains("Modificabile"), "Il badge permessi deve indicare che le risorse sono modificabili")
	
	# Crea blueprint custom
	var custom_bp := ShipBlueprint.new()
	custom_bp.ship_id = "custom_frigate_01"
	custom_bp.ship_name = "Frigata Stella Nera"
	custom_bp.ship_class = "Fregata di Scorta Pesante"
	custom_bp.rooms = [
		{"id": "bridge", "name": "Ponte Comando Avanzato", "rect": Rect2(0, 0, 100, 100), "category": "command"}
	]
	
	# Crea star system custom
	var custom_sys := StarSystemData.new("SYS-VEGA-99", "Vega Prime Outpost")
	custom_sys.primary_star_name = "Vega Alpha"
	custom_sys.primary_star_coords = Vector3i(10, -5, 2)
	custom_sys.add_or_update_body({
		"id": "STATION_VEGA_OUTPOST",
		"name": "Avamposto Vega Orbital",
		"type": "STATION",
		"coords": Vector3i(10, -5, 2),
		"radius_km": 12.0
	})
	
	net.set_session_ship_blueprint(custom_bp)
	net.set_session_star_system(custom_sys)
	await get_tree().process_frame
	
	var active_bp := net.get_selected_ship_blueprint()
	var active_sys := net.get_selected_star_system()
	assert(active_bp.ship_id == "custom_frigate_01", "La blueprint attiva deve corrispondere a custom_bp")
	assert(active_sys.system_id == "SYS-VEGA-99", "Il sistema attivo deve corrispondere a custom_sys")
	assert(ship_preview.text.contains("Frigata Stella Nera"), "L'anteprima nave deve mostrare il nome custom")
	assert(sys_preview.text.contains("Vega Prime Outpost"), "L'anteprima sistema deve mostrare il nome custom")
	print("✔ Test 2 superato: Host/Solo può modificare liberamente ShipBlueprint e StarSystemData con anteprima aggiornata.")
	
	# =========================================================================
	# TEST 3: Permessi Client e Sincronizzazione in Sola Lettura
	# =========================================================================
	print("\n--- Test 3: Permessi Client (Sola Lettura e Ricezione Sincronizzazione) ---")
	# Simuliamo stato client (connesso ma non host)
	net.is_host = false
	net.is_solo_mode = false
	net.is_connected_to_network = true
	lobby_app._refresh_lobby_ui()
	await get_tree().process_frame
	
	assert(ship_opt.disabled == true, "I client non devono poter modificare il selettore blueprint nave")
	assert(sys_opt.disabled == true, "I client non devono poter modificare il selettore sistema stellare")
	assert(ship_btn.visible == false or ship_btn.disabled == true, "Il pulsante Sfoglia nave non deve essere accessibile ai client")
	assert(badge.text.contains("CLIENT") or badge.text.contains("Sola Lettura"), "Il badge deve indicare Sola Lettura per il client")
	
	# Simuliamo ricezione pacchetto RPC di sincronizzazione dall'Host
	var host_bp_dict := {
		"ship_id": "host_dreadnought",
		"ship_name": "Incrociatore Titanico",
		"ship_class": "Incrociatore Pesante",
		"rooms": [{"id": "r1", "name": "Sala Comando", "rect": [0,0,50,50]}],
		"ducts": [],
		"devices": [],
		"junctions": [],
		"damages": [],
		"installed_apps": [{"id": "flight_control", "title": "Flight", "scene_path": "", "roles": []}]
	}
	var host_sys_dict := {
		"system_id": "SYS-SIRIUS-07",
		"system_name": "Sirius Binary System",
		"primary_star_name": "Sirius A",
		"primary_star_coords": [100, 200, 0],
		"celestial_bodies": [
			{"id": "STATION_SIRIUS", "name": "Sirius Dock", "type": "STATION", "coords": [100, 200, 0]}
		],
		"custom_sectors": []
	}
	
	net._rpc_sync_session_resources(host_bp_dict, host_sys_dict, "", "")
	await get_tree().process_frame
	
	var client_bp := net.get_selected_ship_blueprint()
	var client_sys := net.get_selected_star_system()
	assert(client_bp.ship_id == "host_dreadnought", "Il client deve aver sincronizzato la blueprint dell'Host")
	assert(client_sys.system_id == "SYS-SIRIUS-07", "Il client deve aver sincronizzato il sistema stellare dell'Host")
	assert(ship_preview.text.contains("Incrociatore Titanico"), "L'anteprima del client deve riflettere la nave dell'Host")
	assert(sys_preview.text.contains("Sirius Binary System"), "L'anteprima del client deve riflettere il sistema dell'Host")
	print("✔ Test 3 superato: Client riceve sincronizzazione RPC in sola lettura.")
	
	# =========================================================================
	# TEST 4: Avvio Missione e Applicazione Risorse a SpaceWorldManager
	# =========================================================================
	print("\n--- Test 4: Avvio Missione (start_mission) e Caricamento su SpaceWorldManager ---")
	net.is_host = true
	net.is_connected_to_network = true
	net.is_solo_mode = true
	net.is_mission_started = false
	
	var mission_bp := ShipBlueprint.new()
	mission_bp.ship_id = "mission_flagship"
	mission_bp.ship_name = "Ammiraglia di Missione"
	mission_bp.rooms = [{"id": "bridge", "name": "Ponte Ammiraglio", "rect": Rect2(10, 10, 80, 80)}]
	
	var mission_sys := StarSystemData.new("SYS-MISSION-FINAL", "Frontiera Finale")
	mission_sys.primary_star_name = "Frontier Star"
	mission_sys.primary_star_coords = Vector3i(50, 50, 0)
	
	net.set_session_ship_blueprint(mission_bp)
	net.set_session_star_system(mission_sys)
	
	# Avvia la missione
	net.start_mission()
	await get_tree().process_frame
	
	assert(swm.is_ship_connected(), "SpaceWorldManager deve risultare connesso dopo l'avvio della missione")
	var swm_bp := swm.get_ship_blueprint()
	var swm_sys := swm.get_star_system_data()
	
	assert(swm_bp != null and swm_bp.ship_id == "mission_flagship", "SpaceWorldManager deve aver caricato la ShipBlueprint della sessione")
	assert(swm_sys != null and swm_sys.system_id == "SYS-MISSION-FINAL", "SpaceWorldManager deve aver caricato il StarSystemData della sessione")
	assert(grid_mgr.current_system_data != null and grid_mgr.current_system_data.system_id == "SYS-MISSION-FINAL", "StarSystemGridManager deve aver caricato il StarSystemData sincronizzato")
	
	print("✔ Test 4 superato: SpaceWorldManager e StarSystemGridManager caricano correttamente le risorse all'avvio della missione.")
	
	lobby_app.queue_free()
	net.disconnect_game()
	print("\n=======================================================")
	print(" TUTTI I TEST PER LOBBY CUSTOM RESOURCES SUPERATI! [OK]")
	print("=======================================================")
	get_tree().quit(0)
