extends GutTest

## Migrato e CONSOLIDATO dai due vecchi test duplicati:
## - tests/test_rbac_start_menu_filter.gd (static class RefCounted)
## - tests/test_rbac_start_menu_filter_node.gd (Node wrapper)
## Entrambi testavano lo stesso sistema (filtraggio RBAC delle app nave nel
## menu Start). Questo file unico ne copre l'intera funzionalità:
## stato offline, matrice RBAC per ruolo, popolamento dinamico all'avvio
## missione, cambio ruolo a runtime, e gestione dell'overlay di
## disconnessione / svuotamento del menu a fine missione.

var ssm: ShipSoftwareManagerSingleton
var swm: SpaceWorldManagerSingleton
var net: GameNetworkManager
var taskbar: Node
var start_btn: Node

func before_each() -> void:
	ssm = get_node_or_null("/root/ShipSoftwareManager") as ShipSoftwareManagerSingleton
	swm = get_node_or_null("/root/SpaceWorldManager") as SpaceWorldManagerSingleton
	net = get_node_or_null("/root/NetworkManager") as GameNetworkManager
	assert_not_null(ssm, "ShipSoftwareManager deve essere registrato come Autoload")
	assert_not_null(swm, "SpaceWorldManager deve essere registrato come Autoload")

	var taskbar_scene: PackedScene = load("res://Scenes/Taskbar/taskbar.tscn")
	assert_not_null(taskbar_scene, "taskbar.tscn deve caricarsi")
	taskbar = taskbar_scene.instantiate()
	add_child_autofree(taskbar)

	start_btn = taskbar.get_node_or_null("Taskbar/Start Button")
	assert_not_null(start_btn, "Start Button deve esistere nella taskbar")

func after_each() -> void:
	ssm.end_mission()
	swm.end_mission()
	if net:
		net.is_mission_started = false
		net.is_connected_to_network = false

static func _collect_all_titles(options: Array, titles: Array[String]) -> void:
	for opt in options:
		titles.append(str(opt.get("title_text")))
		var sub: Variant = opt.get("sub_tree")
		if sub is Dictionary and not sub.is_empty():
			_collect_sub_tree_titles(sub, titles)

static func _collect_sub_tree_titles(tree: Dictionary, titles: Array[String]) -> void:
	for app in tree.get("apps", []):
		titles.append(str(app.get("title")))
	for sub_folder in tree.get("subfolders", {}).values():
		if sub_folder is Dictionary:
			_collect_sub_tree_titles(sub_folder, titles)

func test_offline_state_has_no_ship_apps_in_start_menu() -> void:
	ssm.end_mission()
	swm.end_mission()
	if net:
		net.is_mission_started = false
		net.is_connected_to_network = false
	start_btn._refresh_ship_apps()

	var dynamic_apps := taskbar.get_tree().get_nodes_in_group("dynamic_ship_apps")
	assert_eq(dynamic_apps.size(), 0, "Nello stato offline nessuna app della nave deve essere nel menu Start")

func test_rbac_filtering_by_role() -> void:
	var def_bp := ShipBlueprint.get_default_blueprint()

	# Ruolo: Pilota -> Flight Control, Cams (e System Map se configurata)
	var pilot_apps := ssm.get_apps_for_role(net.ROLE_PILOT, false, def_bp)
	var pilot_ids: Array[String] = []
	for a in pilot_apps:
		pilot_ids.append(a.app_id)
	assert_true(pilot_ids.has("flight_control"), "Pilota deve avere flight_control")
	assert_true(pilot_ids.has("cams"), "Pilota deve avere cams")
	assert_false(pilot_ids.has("weapons"), "Pilota NON deve avere weapons")
	assert_false(pilot_ids.has("power_grid"), "Pilota NON deve avere power_grid")
	assert_false(pilot_ids.has("duct_drone"), "Pilota NON deve avere duct_drone")

	# Ruolo: Ingegnere -> Power Grid, Duct Drone, Life Support, Shield Matrix
	var eng_apps := ssm.get_apps_for_role(net.ROLE_ENGINEER, false, def_bp)
	var eng_ids: Array[String] = []
	for a in eng_apps:
		eng_ids.append(a.app_id)
	assert_true(eng_ids.has("power_grid"), "Ingegnere deve avere power_grid")
	assert_true(eng_ids.has("duct_drone"), "Ingegnere deve avere duct_drone")
	assert_true(eng_ids.has("life_support"), "Ingegnere deve avere life_support")
	assert_true(eng_ids.has("shield_matrix"), "Ingegnere deve avere shield_matrix")
	assert_false(eng_ids.has("flight_control"), "Ingegnere NON deve avere flight_control")
	assert_false(eng_ids.has("weapons"), "Ingegnere NON deve avere weapons")

	# Ruolo: Soldato -> Cams, Weapons, Sensors
	var soldier_apps := ssm.get_apps_for_role(net.ROLE_SOLDIER, false, def_bp)
	var soldier_ids: Array[String] = []
	for a in soldier_apps:
		soldier_ids.append(a.app_id)
	assert_true(soldier_ids.has("cams"), "Soldato deve avere cams")
	assert_true(soldier_ids.has("weapons"), "Soldato deve avere weapons")
	assert_true(soldier_ids.has("sensors"), "Soldato deve avere sensors")
	assert_false(soldier_ids.has("flight_control"), "Soldato NON deve avere flight_control")
	assert_false(soldier_ids.has("power_grid"), "Soldato NON deve avere power_grid")

	# Ruolo: Hacker -> Duct Drone, Comms, Diagnostics
	var hacker_apps := ssm.get_apps_for_role(net.ROLE_HACKER, false, def_bp)
	var hacker_ids: Array[String] = []
	for a in hacker_apps:
		hacker_ids.append(a.app_id)
	assert_true(hacker_ids.has("duct_drone"), "Hacker deve avere duct_drone")
	assert_true(hacker_ids.has("comms"), "Hacker deve avere comms")
	assert_true(hacker_ids.has("diagnostics"), "Hacker deve avere diagnostics")
	assert_false(hacker_ids.has("weapons"), "Hacker NON deve avere weapons")
	assert_false(hacker_ids.has("flight_control"), "Hacker NON deve avere flight_control")

	# Ruolo: Stagista -> Tutte le app
	var stagista_apps := ssm.get_apps_for_role(net.ROLE_STAGISTA, false, def_bp)
	assert_eq(stagista_apps.size(), ssm.get_installed_apps(def_bp).size(), "Lo Stagista deve avere accesso a tutte le applicazioni")

	# Ruolo: Capitano / Solo Mode -> Tutte le app
	var cap_apps := ssm.get_apps_for_role(net.ROLE_CAPTAIN, false, def_bp)
	var solo_apps := ssm.get_apps_for_role("Pilota", true, def_bp)
	var all_installed := ssm.get_installed_apps(def_bp)
	assert_eq(cap_apps.size(), all_installed.size(), "Il Capitano deve avere accesso a tutte le applicazioni")
	assert_eq(solo_apps.size(), all_installed.size(), "In Solo Mode il giocatore deve avere accesso a tutte le applicazioni")

func test_dynamic_population_on_mission_start() -> void:
	var def_bp := ShipBlueprint.get_default_blueprint()
	# Simuliamo avvio missione come Ingegnere
	ssm.start_mission(net.ROLE_ENGINEER, false, def_bp)
	start_btn._refresh_ship_apps()
	await get_tree().process_frame

	var eng_menu_apps := taskbar.get_tree().get_nodes_in_group("dynamic_ship_apps")
	assert_gt(eng_menu_apps.size(), 0, "Il menu Start deve contenere le voci dell'Ingegnere (cartelle o app)")
	var menu_titles: Array[String] = []
	_collect_all_titles(eng_menu_apps, menu_titles)
	assert_true(menu_titles.has("Power Grid"), "Menu deve contenere Power Grid")
	assert_true(menu_titles.has("Duct Drone"), "Menu deve contenere Duct Drone")
	assert_true(menu_titles.has("Shield Matrix"), "Menu deve contenere Shield Matrix")
	assert_true(menu_titles.has("Supporto Vitale & Atmosfera"), "Menu deve contenere Supporto Vitale & Atmosfera")

func test_runtime_role_switch_updates_menu() -> void:
	var def_bp := ShipBlueprint.get_default_blueprint()
	# Iniziamo missione come Ingegnere, poi passiamo a Pilota a runtime
	ssm.start_mission(net.ROLE_ENGINEER, false, def_bp)
	start_btn._refresh_ship_apps()
	await get_tree().process_frame

	ssm.set_current_role(net.ROLE_PILOT)
	start_btn._refresh_ship_apps()
	await get_tree().process_frame

	var pilot_menu_apps := taskbar.get_tree().get_nodes_in_group("dynamic_ship_apps")
	var pilot_menu_titles: Array[String] = []
	_collect_all_titles(pilot_menu_apps, pilot_menu_titles)
	assert_true(pilot_menu_titles.has("Flight Control"), "Dopo switch a Pilota il menu deve contenere Flight Control")
	assert_true(pilot_menu_titles.has("Cams"), "Dopo switch a Pilota il menu deve contenere Cams")
	assert_false(pilot_menu_titles.has("Power Grid"), "Dopo switch a Pilota il menu NON deve contenere Power Grid")

func test_disconnected_overlay_and_menu_clear_on_end_mission() -> void:
	var def_bp := ShipBlueprint.get_default_blueprint()
	ssm.start_mission(net.ROLE_PILOT, false, def_bp)
	start_btn._refresh_ship_apps()
	await get_tree().process_frame

	# Istanziamo una app nave con DisconnectedOverlay (es. Flight Control)
	var fc_scene: PackedScene = load("res://Applications/FlightControl/flight_control_app.tscn")
	assert_not_null(fc_scene, "flight_control_app.tscn deve esistere")
	var fc_app: Node = fc_scene.instantiate()
	add_child_autofree(fc_app)

	var overlay: Control = fc_app.get_node_or_null("DisconnectedOverlay") as Control
	if not overlay:
		overlay = fc_app.get_node_or_null("%DisconnectedOverlay") as Control
	assert_not_null(overlay, "FlightControl deve avere il nodo DisconnectedOverlay")

	# Poiché la missione è attiva, l'overlay deve essere nascosto
	assert_false(overlay.visible, "All'avvio missione l'overlay di disconnessione deve essere nascosto")

	# Ora terminiamo la missione
	ssm.end_mission()
	start_btn._refresh_ship_apps()
	await get_tree().process_frame

	# A missione terminata l'overlay deve riattivarsi e il menu Start svuotarsi
	assert_true(overlay.visible, "A fine missione l'overlay di disconnessione deve riattivarsi")
	var end_menu_apps := taskbar.get_tree().get_nodes_in_group("dynamic_ship_apps")
	assert_eq(end_menu_apps.size(), 0, "A fine missione le app nave devono essere rimosse dal menu Start")
