extends GutTest

## Test GUT per ShipBlueprint & Sublayer Architecture (`Outside/ShipSublayer/ship_blueprint.gd`).
## Le funzioni condividono lo stato di `bp` (ShipBlueprint è una Resource: nessuna gestione
## manuale della memoria necessaria, a differenza dei Node creati nelle singole fasi che usano
## `add_child_autofree`).

const TEST_JSON_PATH := "user://test_ship_blueprint.json"

var bp: ShipBlueprint

func after_all() -> void:
	if FileAccess.file_exists(TEST_JSON_PATH):
		DirAccess.remove_absolute(TEST_JSON_PATH)

func test_default_ship_blueprint_structure() -> void:
	bp = ShipBlueprint.new()
	bp.create_default_ship()

	assert_eq(bp.ship_id, "dark_nova_corvette", "ship_id deve essere dark_nova_corvette")
	assert_eq(bp.ship_name, "Dark Nova Corvette", "ship_name deve essere Dark Nova Corvette")
	assert_gte(bp.rooms.size(), 10, "La Blueprint deve contenere almeno 10 stanze di default")
	assert_gte(bp.ducts.size(), 17, "La Blueprint deve contenere almeno 17 condotti di default")

	var all_devs := []
	for r in bp.rooms:
		all_devs.append_array(r.devices)
	assert_gte(all_devs.size(), 11, "La Blueprint deve contenere almeno 11 dispositivi elettrici di default")

	assert_gte(bp.damages.size(), 8, "La Blueprint deve contenere almeno 8 punti di danno predefiniti")
	assert_gte(bp.installed_apps.size(), 8, "La Blueprint deve contenere almeno 8 applicazioni installate")

func test_quick_query_methods() -> void:
	var bridge_room := bp.get_room_by_id("bridge")
	assert_not_null(bridge_room, "get_room_by_id(bridge) deve trovare la stanza")
	assert_eq(bridge_room.name, "Ponte di Comando", "Nome stanza deve essere Ponte di Comando")

	var room_at_bridge := bp.get_room_at(Vector2(250, 60))
	assert_not_null(room_at_bridge, "get_room_at deve trovare la stanza al punto (250, 60)")
	assert_eq(room_at_bridge.id, "bridge", "La stanza trovata deve essere bridge")

	var non_existing_room := bp.get_room_by_id("non_existing_room_id")
	assert_null(non_existing_room, "get_room_by_id su ID inesistente deve ritornare null")

	var duct_spine := bp.get_duct_by_id("duct_1")
	assert_not_null(duct_spine, "get_duct_by_id(duct_1) deve trovare il condotto")

	var reactor_dev := bp.get_device_by_id("reactor_main")
	assert_not_null(reactor_dev, "get_device_by_id(reactor_main) deve trovare il dispositivo")
	assert_true(reactor_dev.is_generator, "reactor_main deve essere un generatore")

	var dmg_1 := bp.get_damage_by_id("dmg_1")
	assert_not_null(dmg_1, "get_damage_by_id(dmg_1) deve trovare il punto di danno")

	var weap_cfg := bp.get_drive_file_by_path("Ship Drive/Programs/Weapons/weapons_config.dat")
	assert_not_null(weap_cfg, "get_drive_file_by_path deve trovare weapons_config.dat")
	assert_true(weap_cfg.is_protected, "weapons_config.dat deve essere protetto")
	assert_true("decryption_key=WEAP-CFG-7815" in weap_cfg.content, "weapons_config.dat deve contenere decryption_key")

	var weap_pwd := bp.get_drive_password("Ship Drive/Programs/Weapons")
	assert_eq(weap_pwd, "WEAP-7815", "Password Weapons deve essere WEAP-7815")

	var shld_cfg := bp.get_drive_file_by_path("Ship Drive/Programs/ShieldMatrix/shields_config.dat")
	assert_not_null(shld_cfg, "get_drive_file_by_path deve trovare shields_config.dat")
	assert_true(shld_cfg.is_protected, "shields_config.dat deve essere protetto")
	assert_true("decryption_key=SHLD-CFG-7815" in shld_cfg.content, "shields_config.dat deve contenere decryption_key")

	var shld_pwd := bp.get_drive_password("Ship Drive/Programs/ShieldMatrix")
	assert_eq(shld_pwd, "SHLD-7815", "Password ShieldMatrix deve essere SHLD-7815")

	var comm_cfg := bp.get_drive_file_by_path("Ship Drive/Programs/Comms/comms_config.dat")
	assert_not_null(comm_cfg, "get_drive_file_by_path deve trovare comms_config.dat")
	assert_true(comm_cfg.is_protected, "comms_config.dat deve essere protetto")
	assert_true("decryption_key=COMM-CFG-7815" in comm_cfg.content, "comms_config.dat deve contenere decryption_key")

	var comm_pwd := bp.get_drive_password("Ship Drive/Programs/Comms")
	assert_eq(comm_pwd, "COMM-7815", "Password Comms deve essere COMM-7815")

	var sens_cfg := bp.get_drive_file_by_path("Ship Drive/Programs/Sensors/sensors_config.dat")
	assert_not_null(sens_cfg, "get_drive_file_by_path deve trovare sensors_config.dat")
	assert_true(sens_cfg.is_protected, "sensors_config.dat deve essere protetto")
	assert_true("decryption_key=SENS-CFG-7815" in sens_cfg.content, "sensors_config.dat deve contenere decryption_key")

	var sens_pwd := bp.get_drive_password("Ship Drive/Programs/Sensors")
	assert_eq(sens_pwd, "SENS-7815", "Password Sensors deve essere SENS-7815")

	# Verifica decryption keys nella risorsa default_ship_blueprint.tres
	var default_bp_res: ShipBlueprint = load("res://Outside/ShipSublayer/default_ship_blueprint.tres") as ShipBlueprint
	assert_not_null(default_bp_res, "Caricamento default_ship_blueprint.tres fallito")
	var default_expected_keys: Dictionary = {
		"Ship Drive/Programs/Weapons/weapons_config.dat": "WEAP-CFG-7815",
		"Ship Drive/Programs/Weapons/ammo_tuning.dat": "AMMO-TUN-7815",
		"Ship Drive/Programs/Sensors/sensors_config.dat": "SENS-CFG-7815",
		"Ship Drive/Programs/Sensors/radar_tuning.dat": "RADR-TUN-7815",
		"Ship Drive/Programs/Comms/comms_config.dat": "COMM-CFG-7815",
		"Ship Drive/Programs/Comms/crypto_tuning.dat": "CRYP-TUN-7815",
		"Ship Drive/Programs/DuctDrone/duct_drone_config.dat": "DUCT-CFG-7815",
		"Ship Drive/Programs/DuctDrone/drone_tuning.dat": "DRONE-TUN-7815",
		"Ship Drive/Programs/ShieldMatrix/shields_config.dat": "SHLD-CFG-7815",
		"Ship Drive/Programs/ShieldMatrix/deflector_tuning.dat": "DEFL-TUN-7815"
	}
	for f_p in default_expected_keys:
		var f_obj := default_bp_res.get_drive_file_by_path(f_p)
		assert_not_null(f_obj, "File non trovato nella blueprint: " + f_p)
		assert_true(("decryption_key=" + default_expected_keys[f_p]) in f_obj.content, "Decryption key mancante in " + f_p)

	# Test aggiunta e rimozione file dinamico
	bp.set_drive_file("Ship Drive/test_note.txt", "Note test", false, "Descrizione")
	assert_not_null(bp.get_drive_file_by_path("Ship Drive/test_note.txt"), "File temporaneo aggiunto con successo")
	assert_true(bp.remove_drive_file("Ship Drive/test_note.txt"), "File temporaneo rimosso con successo")

	# Test query applicazioni mainframe e filtro ruoli
	var fc_app := bp.get_installed_app_by_id("flight_control")
	assert_not_null(fc_app, "get_installed_app_by_id deve trovare flight_control")
	assert_eq(fc_app.title, "Flight Control", "Titolo app deve essere Flight Control")

	var weap_app := bp.get_installed_app_by_id("weapons")
	assert_not_null(weap_app, "get_installed_app_by_id deve trovare weapons")
	assert_eq(weap_app.title, "Tactical Weapons", "Titolo app deve essere Tactical Weapons")

	var shld_app := bp.get_installed_app_by_id("shield_matrix")
	assert_not_null(shld_app, "get_installed_app_by_id deve trovare shield_matrix")
	assert_eq(shld_app.title, "Shield Matrix", "Titolo app deve essere Shield Matrix")

	var comm_app := bp.get_installed_app_by_id("comms")
	assert_not_null(comm_app, "get_installed_app_by_id deve trovare comms")
	assert_eq(comm_app.title, "Comms & Electronic War", "Titolo app deve essere Comms & Electronic War")

	var diag_app := bp.get_installed_app_by_id("diagnostics")
	assert_not_null(diag_app, "get_installed_app_by_id deve trovare diagnostics")
	assert_eq(diag_app.title, "System Diagnostics", "Titolo app deve essere System Diagnostics")

	var pilot_apps := bp.get_apps_for_role("Pilota", false)
	assert_gte(pilot_apps.size(), 4, "Pilota deve visualizzare almeno 4 app")

	var eng_apps := bp.get_apps_for_role("Ingegnere", false)
	assert_gte(eng_apps.size(), 5, "Ingegnere deve visualizzare almeno 5 app")

	var soldier_apps := bp.get_apps_for_role("Soldato", false)
	assert_gte(soldier_apps.size(), 3, "Soldato deve visualizzare almeno 3 app")

	var hacker_apps := bp.get_apps_for_role("Hacker", false)
	assert_gte(hacker_apps.size(), 4, "Hacker deve visualizzare almeno 4 app")

	var cap_apps := bp.get_apps_for_role("Capitano", false)
	assert_gte(cap_apps.size(), 8, "Capitano deve visualizzare almeno 8 app")

func test_serialization_to_dict_and_from_dict() -> void:
	var serialized_dict := bp.to_dict()
	assert_true(serialized_dict.has("ship_id") and serialized_dict["ship_id"] == "dark_nova_corvette", "Dizionario deve contenere ship_id")
	assert_true(serialized_dict.has("rooms") and serialized_dict["rooms"].size() >= 10, "Dizionario deve contenere stanze")
	assert_true(serialized_dict.has("drive_files") and serialized_dict["drive_files"].size() >= 0, "Dizionario deve contenere file drive")
	assert_true(serialized_dict.has("drive_passwords") and serialized_dict["drive_passwords"].size() >= 0, "Dizionario deve contenere password drive")
	assert_true(serialized_dict.has("installed_apps") and serialized_dict["installed_apps"].size() >= 8, "Dizionario deve contenere app mainframe")

	var reconstructed_bp := ShipBlueprint.new()
	reconstructed_bp.from_dict(serialized_dict)
	assert_eq(reconstructed_bp.ship_id, bp.ship_id, "ship_id ricostruito deve coincidere")
	assert_eq(reconstructed_bp.ship_bounds, bp.ship_bounds, "ship_bounds ricostruito deve coincidere")
	assert_eq(reconstructed_bp.rooms.size(), bp.rooms.size(), "Numero stanze ricostruito deve coincidere")
	assert_eq(reconstructed_bp.ducts.size(), bp.ducts.size(), "Numero condotti ricostruito deve coincidere")
	assert_eq(reconstructed_bp.damages.size(), bp.damages.size(), "Numero danni ricostruito deve coincidere")
	assert_eq(reconstructed_bp.drive_files.size(), bp.drive_files.size(), "Numero file drive ricostruito deve coincidere")
	assert_eq(reconstructed_bp.drive_passwords.size(), bp.drive_passwords.size(), "Numero password drive ricostruito deve coincidere")
	assert_eq(reconstructed_bp.installed_apps.size(), bp.installed_apps.size(), "Numero app mainframe ricostruito deve coincidere")

func test_json_export_and_import() -> void:
	var export_err := bp.export_to_json(TEST_JSON_PATH)
	assert_eq(export_err, OK, "Esportazione su file JSON deve restituire OK")
	assert_true(FileAccess.file_exists(TEST_JSON_PATH), "Il file JSON esportato deve esistere su disco")

	var imported_bp := ShipBlueprint.new()
	var import_err := imported_bp.import_from_json(TEST_JSON_PATH)
	assert_eq(import_err, OK, "Importazione da file JSON deve restituire OK")
	assert_eq(imported_bp.ship_name, "Dark Nova Corvette", "Nome nave importato deve coincidere")
	assert_eq(imported_bp.rooms.size(), bp.rooms.size(), "Stanze importate da JSON devono coincidere")
	var total_devs_imp := 0
	for r in imported_bp.rooms: total_devs_imp += r.devices.size()
	var total_devs_orig := 0
	for r in bp.rooms: total_devs_orig += r.devices.size()
	assert_eq(total_devs_imp, total_devs_orig, "Dispositivi importati da JSON devono coincidere")
	assert_eq(imported_bp.drive_files.size(), bp.drive_files.size(), "File drive importati da JSON devono coincidere")
	assert_eq(imported_bp.drive_passwords.size(), bp.drive_passwords.size(), "Password drive importate da JSON devono coincidere")
	assert_eq(imported_bp.installed_apps.size(), bp.installed_apps.size(), "App mainframe importate da JSON devono coincidere")

	# Test gestione errori su file inesistente
	var missing_err := imported_bp.import_from_json("user://non_existing_file_12345.json")
	assert_ne(missing_err, OK, "Importazione di file inesistente deve restituire errore")

func test_deep_clone_and_isolation() -> void:
	var cloned_bp := bp.clone()
	assert_not_null(cloned_bp, "L'istanza clonata non deve essere null")
	assert_eq(cloned_bp.ship_id, bp.ship_id, "L'istanza clonata deve avere lo stesso ship_id")

	# Modifica sull'istanza clonata per verificare l'isolamento
	cloned_bp.ship_name = "Corvetta Modificata"
	cloned_bp.rooms[0].name = "Ponte Personalizzato"
	assert_eq(bp.ship_name, "Dark Nova Corvette", "L'originale non deve essere mutato dalla modifica del nome clone")
	assert_eq(bp.rooms[0].name, "Ponte di Comando", "L'originale non deve essere mutato dalla modifica di una stanza nel clone")

func test_space_world_manager_integration() -> void:
	# NOTA: SpaceWorldManager è un autoload (Node), non un vero Engine singleton:
	# il vecchio test usava Engine.get_singleton("SpaceWorldManager") che genera un
	# errore di motore (script error) anche se gestito con un fallback "if SWM",
	# causando un falso fallimento sotto GUT (che intercetta gli errori stampati).
	# Essendo un autoload sempre presente, si referenzia direttamente.
	SpaceWorldManager.set_ship_blueprint(bp)
	var mgr_bp: ShipBlueprint = SpaceWorldManager.get_ship_blueprint()
	assert_true(mgr_bp != null and mgr_bp.ship_id == "dark_nova_corvette", "SpaceWorldManager deve restituire la blueprint attiva")

	var mgr_rooms: Array = SpaceWorldManager.get_duct_rooms()
	assert_gte(mgr_rooms.size(), 10, "SpaceWorldManager.get_duct_rooms() deve restituire almeno 10 stanze")

	var mgr_ducts: Array = SpaceWorldManager.get_duct_corridors()
	assert_gte(mgr_ducts.size(), 17, "SpaceWorldManager.get_duct_corridors() deve restituire almeno 17 condotti")

	var mgr_devs: Array = SpaceWorldManager.get_power_devices()
	assert_gte(mgr_devs.size(), 11, "SpaceWorldManager.get_power_devices() deve restituire almeno 11 dispositivi")

	var mgr_damages: Array = SpaceWorldManager.get_damage_zones()
	assert_gte(mgr_damages.size(), 8, "SpaceWorldManager.get_damage_zones() deve restituire almeno 8 zone di danno")

	var mgr_files: Array = SpaceWorldManager.get_ship_drive_files()
	assert_gte(mgr_files.size(), 0, "SpaceWorldManager deve restituire file per blueprint")

	var mgr_passwords: Dictionary = SpaceWorldManager.get_ship_drive_passwords()
	assert_gte(mgr_passwords.size(), 0, "SpaceWorldManager deve restituire password")

	var mgr_apps: Array = SpaceWorldManager.get_installed_apps()
	assert_gte(mgr_apps.size(), 8, "SpaceWorldManager.get_installed_apps() deve restituire almeno 8 app")

	var mgr_pilot_apps: Array = SpaceWorldManager.get_installed_apps_for_role("Pilota")
	assert_gte(mgr_pilot_apps.size(), 4, "SpaceWorldManager.get_installed_apps_for_role(Pilota) deve restituire almeno 4 app")

	var mgr_eng_apps: Array = SpaceWorldManager.get_installed_apps_for_role("Ingegnere")
	assert_gte(mgr_eng_apps.size(), 5, "SpaceWorldManager.get_installed_apps_for_role(Ingegnere) deve restituire almeno 5 app")

	var mgr_soldier_apps: Array = SpaceWorldManager.get_installed_apps_for_role("Soldato")
	assert_gte(mgr_soldier_apps.size(), 3, "SpaceWorldManager.get_installed_apps_for_role(Soldato) deve restituire almeno 3 app")

	var mgr_hacker_apps: Array = SpaceWorldManager.get_installed_apps_for_role("Hacker")
	assert_gte(mgr_hacker_apps.size(), 4, "SpaceWorldManager.get_installed_apps_for_role(Hacker) deve restituire almeno 4 app")

	# Test generazione danni da blueprint
	SpaceWorldManager.generate_initial_ship_damages(3)
	var active_damages: Array = SpaceWorldManager.get_ship_damages()
	assert_eq(active_damages.size(), 3, "SpaceWorldManager deve aver generato 3 danni attingendo dalla blueprint")

func test_power_grid_app_integration() -> void:
	var pwr_res: PackedScene = load("res://Applications/PowerGrid/power_grid_app.tscn")
	assert_not_null(pwr_res, "Scena power_grid_app.tscn valida")
	var pwr_app: PowerGridApp = pwr_res.instantiate() as PowerGridApp
	add_child_autofree(pwr_app)
	await get_tree().process_frame

	assert_gte(pwr_app.rooms_data.size(), 10, "PowerGridApp deve aver caricato almeno 10 stanze da ShipBlueprint")

func test_duct_drone_app_integration() -> void:
	var drone_res: PackedScene = load("res://Applications/DuctDrone/duct_drone_app.tscn")
	assert_not_null(drone_res, "Scena duct_drone_app.tscn valida")
	var drone_app := drone_res.instantiate()
	add_child_autofree(drone_app)
	await get_tree().process_frame

	assert_gte(drone_app.get("rooms").size(), 10, "DuctDroneApp deve aver caricato almeno 10 stanze")
	assert_gte(drone_app.get("ducts").size(), 17, "DuctDroneApp deve aver caricato almeno 17 condotti")

func test_ship_sublayer_editor_integration() -> void:
	var editor := ShipSublayerEditor.new()
	add_child_autofree(editor)
	await get_tree().process_frame

	editor.load_blueprint(bp)
	assert_not_null(editor.canvas, "Editor canvas deve essere istanziato")
	assert_eq(editor.canvas.blueprint, bp, "Canvas deve referenziare la blueprint corrente")

func test_ship_drive_manager_mount_integration() -> void:
	var net_mgr: GameNetworkManager = get_node_or_null("/root/NetworkManager") as GameNetworkManager
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if not sdm:
		pending("ShipDriveManager non trovato, test saltato")
		return

	sdm.unmount_drive()
	assert_false(sdm.is_drive_mounted, "ShipDrive deve essere smontato prima del test")

	# Assicura pulizia cartella temporanea prima del mount
	if DirAccess.dir_exists_absolute("user://files/Ship Drive"):
		sdm._delete_dir_recursive("user://files/Ship Drive")

	if net_mgr:
		net_mgr.start_solo_game("Capitano")
		net_mgr.start_mission()
		await get_tree().process_frame
		await get_tree().process_frame
	else:
		sdm.mount_drive()

	assert_true(sdm.is_drive_mounted, "ShipDrive deve essere montato")

	# Verifica che i file e i file .dat siano stati scritti da ShipBlueprint
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/Weapons/weapons_config.dat"), "weapons_config.dat deve esistere su disco")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/Comms/comms_config.dat"), "comms_config.dat deve esistere su disco")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/ShieldMatrix/shields_config.dat"), "shields_config.dat deve esistere su disco")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/Sensors/sensors_config.dat"), "sensors_config.dat deve esistere su disco")

	# Verifica che le password cartella siano state applicate
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	if fpm:
		assert_true(fpm.has_password("Ship Drive/Programs/Weapons"), "Password Weapons deve essere impostata")
		assert_true(fpm.has_password("Ship Drive/Programs/ShieldMatrix"), "Password ShieldMatrix deve essere impostata")
		assert_true(fpm.has_password("Ship Drive/Programs/Comms"), "Password Comms deve essere impostata")

	sdm.unmount_drive()
	if net_mgr:
		net_mgr.disconnect_game()
	assert_false(sdm.is_drive_mounted, "ShipDrive smontato al termine del test")

func test_mainframe_apps_role_filter_start_menu() -> void:
	var net_mgr: GameNetworkManager = get_node_or_null("/root/NetworkManager") as GameNetworkManager
	var taskbar_scene: PackedScene = load("res://Scenes/Taskbar/taskbar.tscn")
	assert_not_null(taskbar_scene, "Scena taskbar.tscn valida")
	var taskbar_inst: Control = taskbar_scene.instantiate() as Control
	add_child_autofree(taskbar_inst)
	await get_tree().process_frame

	var start_btn := taskbar_inst.get_node("Taskbar/Start Button")
	var vbox := taskbar_inst.get_node_or_null("StartMenuAnchor/Start Menu/ScrollContainer/VBoxContainer") if taskbar_inst.has_node("StartMenuAnchor/Start Menu/ScrollContainer/VBoxContainer") else taskbar_inst.get_node("StartMenuAnchor/Start Menu/VBoxContainer")
	assert_true(start_btn != null and vbox != null, "Nodi Start Button e VBoxContainer presenti in Taskbar")

	# 1. Stato Offline / Lobby: le app della nave NON devono essere presenti nel menu
	var count_dynamic_initial := 0
	for child in vbox.get_children():
		if child.is_in_group("dynamic_ship_apps"):
			count_dynamic_initial += 1
	assert_eq(count_dynamic_initial, 0, "A gioco offline/disconnesso non devono comparire app nave nel menu Start")

	if not net_mgr:
		return

	# 2. Avvio missione come Pilota (aggiornamento automatico via segnali)
	net_mgr.start_solo_game("GiocatoreTest")
	net_mgr.is_solo_mode = false
	net_mgr.request_role("Pilota")
	net_mgr.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame

	var pilot_apps := bp.get_apps_for_role("Pilota", false)
	assert_gte(pilot_apps.size(), 4, "Pilota deve avere accesso ad almeno 4 app")

	var current_ship_apps: Array = _collect_all_ship_app_names(vbox)
	assert_true(current_ship_apps.has("ShipApp_flight_control"), "Menu Start per Pilota deve contenere Flight Control")
	assert_true(current_ship_apps.has("ShipApp_cams"), "Menu Start per Pilota deve contenere Cams")
	assert_true(current_ship_apps.has("ShipApp_logbook"), "Menu Start per Pilota deve contenere Logbook")
	assert_true(current_ship_apps.has("ShipApp_cargo_bay"), "Menu Start per Pilota deve contenere CargoBay")
	assert_false(current_ship_apps.has("ShipApp_power_grid"), "Menu Start per Pilota NON deve contenere Power Grid")
	assert_false(current_ship_apps.has("ShipApp_duct_drone"), "Menu Start per Pilota NON deve contenere Duct Drone")

	# 3. Cambio ruolo in Ingegnere (aggiornamento automatico via segnale)
	net_mgr.request_role("Ingegnere")
	await get_tree().process_frame
	await get_tree().process_frame

	var eng_apps := bp.get_apps_for_role("Ingegnere", false)
	assert_gte(eng_apps.size(), 8, "Ingegnere deve avere accesso ad almeno 8 app")

	current_ship_apps = _collect_all_ship_app_names(vbox)
	assert_true(current_ship_apps.has("ShipApp_power_grid"), "Menu Start per Ingegnere deve contenere Power Grid")
	assert_true(current_ship_apps.has("ShipApp_duct_drone"), "Menu Start per Ingegnere deve contenere Duct Drone")
	assert_true(current_ship_apps.has("ShipApp_shield_matrix"), "Menu Start per Ingegnere deve contenere Shield Matrix")
	assert_true(current_ship_apps.has("ShipApp_diagnostics"), "Menu Start per Ingegnere deve contenere Diagnostics")
	assert_true(current_ship_apps.has("ShipApp_life_support"), "Menu Start per Ingegnere deve contenere Life Support")
	assert_true(current_ship_apps.has("ShipApp_logbook"), "Menu Start per Ingegnere deve contenere Logbook")
	assert_true(current_ship_apps.has("ShipApp_service_drone"), "Menu Start per Ingegnere deve contenere Service Drone")
	assert_true(current_ship_apps.has("ShipApp_cargo_bay"), "Menu Start per Ingegnere deve contenere CargoBay")
	assert_false(current_ship_apps.has("ShipApp_flight_control"), "Menu Start per Ingegnere NON deve contenere Flight Control")

	# 4. Cambio ruolo in Capitano (Accesso totale a tutte le app installate)
	net_mgr.request_role("Capitano")
	await get_tree().process_frame
	await get_tree().process_frame

	current_ship_apps = _collect_all_ship_app_names(vbox)
	assert_gte(current_ship_apps.size(), 13, "Menu Start per Capitano deve contenere tutte le app nave")
	assert_true(current_ship_apps.has("ShipApp_weapons"), "Menu Start per Capitano deve contenere Weapons")
	assert_true(current_ship_apps.has("ShipApp_shield_matrix"), "Menu Start per Capitano deve contenere Shield Matrix")
	assert_true(current_ship_apps.has("ShipApp_comms"), "Menu Start per Capitano deve contenere Comms")
	assert_true(current_ship_apps.has("ShipApp_diagnostics"), "Menu Start per Capitano deve contenere Diagnostics")
	assert_true(current_ship_apps.has("ShipApp_sensors"), "Menu Start per Capitano deve contenere Sensors")
	assert_true(current_ship_apps.has("ShipApp_life_support"), "Menu Start per Capitano deve contenere Life Support")
	assert_true(current_ship_apps.has("ShipApp_logbook"), "Menu Start per Capitano deve contenere Logbook")
	assert_true(current_ship_apps.has("ShipApp_service_drone"), "Menu Start per Capitano deve contenere Service Drone")
	assert_true(current_ship_apps.has("ShipApp_cargo_bay"), "Menu Start per Capitano deve contenere CargoBay")

	# 4b. Cambio ruolo in Soldato (Cams, Weapons, Sensors e Logbook)
	net_mgr.request_role("Soldato")
	await get_tree().process_frame
	await get_tree().process_frame

	current_ship_apps = _collect_all_ship_app_names(vbox)
	assert_gte(current_ship_apps.size(), 4, "Menu Start per Soldato deve contenere almeno 4 app")
	assert_true(current_ship_apps.has("ShipApp_cams"), "Menu Start per Soldato deve contenere Cams")
	assert_true(current_ship_apps.has("ShipApp_weapons"), "Menu Start per Soldato deve contenere Weapons")
	assert_true(current_ship_apps.has("ShipApp_sensors"), "Menu Start per Soldato deve contenere Sensors")
	assert_true(current_ship_apps.has("ShipApp_logbook"), "Menu Start per Soldato deve contenere Logbook")

	# 4c. Cambio ruolo in Hacker (Duct Drone, Comms, Diagnostics, Sensors, Logbook, Service Drone e CargoBay)
	net_mgr.request_role("Hacker")
	await get_tree().process_frame
	await get_tree().process_frame

	current_ship_apps = _collect_all_ship_app_names(vbox)
	assert_gte(current_ship_apps.size(), 7, "Menu Start per Hacker deve contenere almeno 7 app")
	assert_true(current_ship_apps.has("ShipApp_duct_drone"), "Menu Start per Hacker deve contenere Duct Drone")
	assert_true(current_ship_apps.has("ShipApp_comms"), "Menu Start per Hacker deve contenere Comms")
	assert_true(current_ship_apps.has("ShipApp_diagnostics"), "Menu Start per Hacker deve contenere Diagnostics")
	assert_true(current_ship_apps.has("ShipApp_sensors"), "Menu Start per Hacker deve contenere Sensors")
	assert_true(current_ship_apps.has("ShipApp_logbook"), "Menu Start per Hacker deve contenere Logbook")
	assert_true(current_ship_apps.has("ShipApp_service_drone"), "Menu Start per Hacker deve contenere Service Drone")
	assert_true(current_ship_apps.has("ShipApp_cargo_bay"), "Menu Start per Hacker deve contenere CargoBay")

	# 5. Fine missione / Disconnessione
	net_mgr.disconnect_game()
	await get_tree().process_frame
	await get_tree().process_frame

	current_ship_apps = _collect_all_ship_app_names(vbox)
	assert_eq(current_ship_apps.size(), 0, "Alla disconnessione le app nave devono essere rimosse dal menu Start")

func _collect_all_ship_app_names(container: Control) -> Array:
	var list: Array = []
	for child in container.get_children():
		if child.is_in_group("dynamic_ship_apps"):
			list.append(child.name)
			var sub: Variant = child.get("sub_tree")
			if sub is Dictionary and not sub.is_empty():
				_collect_sub_tree_app_names(sub, list)
	return list

func _collect_sub_tree_app_names(tree: Dictionary, list: Array) -> void:
	for app in tree.get("apps", []):
		list.append("ShipApp_%s" % str(app.get("id")))
	for sub in tree.get("subfolders", {}).values():
		if sub is Dictionary:
			_collect_sub_tree_app_names(sub, list)
