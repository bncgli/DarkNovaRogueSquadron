class_name TestRBACStartMenuFilter
extends RefCounted

## Test suite per la verifica del filtraggio RBAC delle applicazioni della nave e la gestione dinamica del menu Start.

static func run_all_tests(node_context: Node) -> bool:
	print("--- Esecuzione TestRBACStartMenuFilter ---")
	
	var ssm: ShipSoftwareManagerSingleton = node_context.get_node_or_null("/root/ShipSoftwareManager") as ShipSoftwareManagerSingleton
	var swm: SpaceWorldManagerSingleton = node_context.get_node_or_null("/root/SpaceWorldManager") as SpaceWorldManagerSingleton
	var net: GameNetworkManager = node_context.get_node_or_null("/root/NetworkManager") as GameNetworkManager
	
	if ssm == null or swm == null:
		print("ERRORE: Autoload essenziali non trovati!")
		return false
	
	var taskbar_scene: PackedScene = load("res://Scenes/Taskbar/taskbar.tscn")
	if not taskbar_scene:
		print("ERRORE: Impossibile caricare taskbar.tscn")
		return false
		
	var taskbar = taskbar_scene.instantiate()
	node_context.add_child(taskbar)
	
	var start_btn = taskbar.get_node_or_null("Taskbar/Start Button")
	if not start_btn:
		print("ERRORE: Start Button non trovato nella taskbar!")
		taskbar.queue_free()
		return false
	
	# =========================================================================
	# TEST 1: Stato Offline / Lobby: Nessuna app nave presente nel Menu Start
	# =========================================================================
	print("\n--- Test 1: Stato Offline / Lobby (Menu Start Pulito da App Nave) ---")
	ssm.end_mission()
	swm.end_mission()
	if net:
		net.is_mission_started = false
		net.is_connected_to_network = false
	start_btn._refresh_ship_apps()
	
	var dynamic_apps = taskbar.get_tree().get_nodes_in_group("dynamic_ship_apps")
	assert(dynamic_apps.size() == 0, "Nello stato offline nessuna app della nave deve essere nel menu Start")
	print("✔ Test 1 superato: Menu Start libero da app operative nave prima del decollo.")
	
	# =========================================================================
	# TEST 2: Filtraggio RBAC per Ruolo
	# =========================================================================
	print("\n--- Test 2: Filtraggio Applicazioni per Ruolo (RBAC) ---")
	var def_bp := ShipBlueprint.get_default_blueprint()
	
	# Ruolo: Pilota -> Flight Control, Cams (e System Map se configurata)
	var pilot_apps = ssm.get_apps_for_role("Pilota", false, def_bp)
	var pilot_ids: Array[String] = []
	for a in pilot_apps:
		pilot_ids.append(a.app_id)
	print("App Pilota:", pilot_ids)
	assert(pilot_ids.has("flight_control"), "Pilota deve avere flight_control")
	assert(pilot_ids.has("cams"), "Pilota deve avere cams")
	assert(not pilot_ids.has("weapons"), "Pilota NON deve avere weapons")
	assert(not pilot_ids.has("power_grid"), "Pilota NON deve avere power_grid")
	assert(not pilot_ids.has("duct_drone"), "Pilota NON deve avere duct_drone")
	
	# Ruolo: Ingegnere -> Power Grid, Duct Drone, Life Support, Shield Matrix
	var eng_apps = ssm.get_apps_for_role("Ingegnere", false, def_bp)
	var eng_ids: Array[String] = []
	for a in eng_apps:
		eng_ids.append(a.app_id)
	print("App Ingegnere:", eng_ids)
	assert(eng_ids.has("power_grid"), "Ingegnere deve avere power_grid")
	assert(eng_ids.has("duct_drone"), "Ingegnere deve avere duct_drone")
	assert(eng_ids.has("life_support"), "Ingegnere deve avere life_support")
	assert(eng_ids.has("shield_matrix"), "Ingegnere deve avere shield_matrix")
	assert(not eng_ids.has("flight_control"), "Ingegnere NON deve avere flight_control")
	assert(not eng_ids.has("weapons"), "Ingegnere NON deve avere weapons")
	
	# Ruolo: Soldato -> Cams, Weapons, Sensors
	var soldier_apps = ssm.get_apps_for_role("Soldato", false, def_bp)
	var soldier_ids: Array[String] = []
	for a in soldier_apps:
		soldier_ids.append(a.app_id)
	print("App Soldato:", soldier_ids)
	assert(soldier_ids.has("cams"), "Soldato deve avere cams")
	assert(soldier_ids.has("weapons"), "Soldato deve avere weapons")
	assert(soldier_ids.has("sensors"), "Soldato deve avere sensors")
	assert(not soldier_ids.has("flight_control"), "Soldato NON deve avere flight_control")
	assert(not soldier_ids.has("power_grid"), "Soldato NON deve avere power_grid")
	
	# Ruolo: Hacker -> Duct Drone, Comms, Diagnostics
	var hacker_apps = ssm.get_apps_for_role("Hacker", false, def_bp)
	var hacker_ids: Array[String] = []
	for a in hacker_apps:
		hacker_ids.append(a.app_id)
	print("App Hacker:", hacker_ids)
	assert(hacker_ids.has("duct_drone"), "Hacker deve avere duct_drone")
	assert(hacker_ids.has("comms"), "Hacker deve avere comms")
	assert(hacker_ids.has("diagnostics"), "Hacker deve avere diagnostics")
	assert(not hacker_ids.has("weapons"), "Hacker NON deve avere weapons")
	assert(not hacker_ids.has("flight_control"), "Hacker NON deve avere flight_control")
	
	# Ruolo: Capitano / Solo Mode -> Tutte le app
	var cap_apps = ssm.get_apps_for_role("Capitano", false, def_bp)
	var solo_apps = ssm.get_apps_for_role("Pilota", true, def_bp)
	var all_installed = ssm.get_installed_apps(def_bp)
	print("App Capitano size:", cap_apps.size(), "App Solo size:", solo_apps.size(), "Totale installate:", all_installed.size())
	assert(cap_apps.size() == all_installed.size(), "Il Capitano deve avere accesso a tutte le applicazioni")
	assert(solo_apps.size() == all_installed.size(), "In Solo Mode il giocatore deve avere accesso a tutte le applicazioni")
	print("✔ Test 2 superato: Matrice RBAC validata con successo per tutti i ruoli.")
	
	# =========================================================================
	# TEST 3: Popolamento Dinamico all'avvio missione (start_mission)
	# =========================================================================
	print("\n--- Test 3: Popolamento dinamico Start Menu con start_mission(Ruolo) ---")
	# Simuliamo avvio missione come Ingegnere
	ssm.start_mission("Ingegnere", false, def_bp)
	start_btn._refresh_ship_apps()
	
	var eng_menu_apps = taskbar.get_tree().get_nodes_in_group("dynamic_ship_apps")
	assert(eng_menu_apps.size() >= 4, "Il menu Start deve contenere le app dell'Ingegnere")
	var menu_titles: Array[String] = []
	for opt in eng_menu_apps:
		menu_titles.append(str(opt.get("title_text")))
	print("Titoli menu per Ingegnere:", menu_titles)
	assert(menu_titles.has("Power Grid"), "Menu deve contenere Power Grid")
	assert(menu_titles.has("Duct Drone"), "Menu deve contenere Duct Drone")
	assert(menu_titles.has("Shield Matrix"), "Menu deve contenere Shield Matrix")
	assert(menu_titles.has("Supporto Vitale & Atmosfera"), "Menu deve contenere Supporto Vitale & Atmosfera")
	print("✔ Test 3 superato: Il menu Start popola reattivamente le app per il ruolo all'avvio missione.")
	
	# =========================================================================
	# TEST 4: Cambio Ruolo a Runtime
	# =========================================================================
	print("\n--- Test 4: Cambio Ruolo a Runtime ---")
	ssm.set_current_role("Pilota")
	start_btn._refresh_ship_apps()
	
	var pilot_menu_apps = taskbar.get_tree().get_nodes_in_group("dynamic_ship_apps")
	var pilot_menu_titles: Array[String] = []
	for opt in pilot_menu_apps:
		pilot_menu_titles.append(str(opt.get("title_text")))
	print("Titoli menu per Pilota dopo switch:", pilot_menu_titles)
	assert(pilot_menu_titles.has("Flight Control"), "Dopo switch a Pilota il menu deve contenere Flight Control")
	assert(pilot_menu_titles.has("Cams"), "Dopo switch a Pilota il menu deve contenere Cams")
	assert(not pilot_menu_titles.has("Power Grid"), "Dopo switch a Pilota il menu NON deve contenere Power Grid")
	print("✔ Test 4 superato: Il cambio ruolo aggiorna istantaneamente il menu Start.")
	
	# =========================================================================
	# TEST 5: Gestione Overlay Disconnessione e Chiusura Missione (end_mission)
	# =========================================================================
	print("\n--- Test 5: Overlay Disconnessione e Fine Missione (end_mission) ---")
	# Istanziamo una app nave con DisconnectedOverlay (es. Flight Control)
	var fc_scene = load("res://Applications/FlightControl/flight_control_app.tscn")
	assert(fc_scene != null, "flight_control_app.tscn deve esistere")
	var fc_app = fc_scene.instantiate()
	node_context.add_child(fc_app)
	
	var overlay = fc_app.get_node_or_null("DisconnectedOverlay")
	if not overlay:
		overlay = fc_app.get_node_or_null("%DisconnectedOverlay")
	assert(overlay != null, "FlightControl deve avere il nodo DisconnectedOverlay")
	
	# Poiché la missione è attiva, l'overlay deve essere nascosto
	assert(overlay.visible == false, "All'avvio missione l'overlay di disconnessione deve essere nascosto")
	
	# Ora terminiamo la missione
	ssm.end_mission()
	start_btn._refresh_ship_apps()
	
	# A missione terminata l'overlay deve riattivarsi e il menu Start svuotarsi
	assert(overlay.visible == true, "A fine missione l'overlay di disconnessione deve riattivarsi")
	var end_menu_apps = taskbar.get_tree().get_nodes_in_group("dynamic_ship_apps")
	assert(end_menu_apps.size() == 0, "A fine missione le app nave devono essere rimosse dal menu Start")
	print("✔ Test 5 superato: DisconnectedOverlay e svuotamento menu a end_mission() verificati con successo.")
	
	# Pulizia
	fc_app.queue_free()
	taskbar.queue_free()
	return true