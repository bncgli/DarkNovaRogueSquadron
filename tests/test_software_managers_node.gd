extends Node

func _ready() -> void:
	print("--- INIZIO TEST SOFTWARE MANAGERS & APP RESOURCES ARCHITECTURE ---")
	await get_tree().process_frame
	
	_test_app_resource_hierarchy()
	_test_ship_software_manager_registry()
	_test_terminal_software_manager_registry()
	_test_ship_software_manager_blueprint_integration()
	_test_ship_software_manager_drive_population()
	_test_terminal_software_manager_drive_population()
	_test_role_filtering_rbac()
	
	print("\n=======================================================")
	print("✔ TUTTI I TEST SOFTWARE MANAGERS COMPLETATI CON SUCCESSO!")
	print("=======================================================\n")
	get_tree().quit(0)

func _test_app_resource_hierarchy() -> void:
	print("\n--- TEST 1: Metodi e Proprietà di AppResource ---")
	var base_res: AppResource = AppResource.new()
	base_res.app_id = "test_base"
	base_res.title = "Test App"
	base_res.drive_folder = "Programs/Test"
	base_res.default_files = [{
		"name": "config.dat",
		"content": "key=val",
		"is_protected": true
	}]
	
	var files: Array[Dictionary] = base_res.get_formatted_drive_files("Ship Drive")
	assert(files.size() == 1, "Deve generare 1 file formattato")
	assert(files[0]["path"] == "Ship Drive/Programs/Test/config.dat", "Il percorso del file formattato non corrisponde: %s" % files[0]["path"])
	
	var ship_res: AppResource = AppResource.new()
	ship_res.app_id = "test_ship"
	ship_res.roles = ["Pilota", "Ingegnere"]
	assert(ship_res.is_role_allowed("Pilota"), "Pilota deve essere autorizzato")
	assert(ship_res.is_role_allowed("Capitano"), "Capitano (super-ruolo) deve essere sempre autorizzato")
	assert(not ship_res.is_role_allowed("Soldato"), "Soldato non deve essere autorizzato")
	
	var term_res: AppResource = AppResource.new()
	term_res.app_id = "test_term"
	term_res.is_system_app = true
	var term_dict: Dictionary = term_res.to_dict()
	assert(term_dict.get("is_system_app", false) == true, "Serializzazione to_dict deve includere is_system_app")
	print("✔ Funzionalità unificate di AppResource verificate")

func _test_ship_software_manager_registry() -> void:
	print("\n--- TEST 2: Catalogo Registrato ShipSoftwareManager ---")
	var ssm: Node = get_node_or_null("/root/ShipSoftwareManager")
	assert(ssm != null, "ShipSoftwareManager autoload deve essere presente")
	
	var registered: Array = ssm.get_all_registered_apps()
	assert(registered.size() >= 8, "Devono essere registrate almeno 8 risorse della nave (trovate: %d)" % registered.size())
	
	var expected_ids: Array[String] = [
		"flight_control", "cams", "duct_drone", "power_grid",
		"weapons", "shield_matrix", "diagnostics", "sensors"
	]
	for id: String in expected_ids:
		var app: AppResource = ssm.get_registered_app(id)
		assert(app != null, "App '%s' deve essere presente nel catalogo registrato" % id)
		assert(not app.title.is_empty(), "App '%s' deve avere un titolo valido" % id)
		assert(not app.scene_path.is_empty(), "App '%s' deve avere un scene_path valido" % id)
	print("✔ Catalogo e risorse predefinite ShipSoftwareManager verificate")

func _test_terminal_software_manager_registry() -> void:
	print("\n--- TEST 3: Catalogo Registrato TerminalSoftwareManager ---")
	var tsm: Node = get_node_or_null("/root/TerminalSoftwareManager")
	assert(tsm != null, "TerminalSoftwareManager autoload deve essere presente")
	
	var term_app: AppResource = tsm.get_registered_app("terminal")
	assert(term_app != null, "App terminale locale 'terminal' deve essere presente")
	assert(term_app.is_system_app == true, "Terminale locale deve avere is_system_app=true")
	assert(term_app.default_files.size() >= 3, "Terminale deve definire almeno 3 file di configurazione predefiniti")
	print("✔ Catalogo e risorse predefinite TerminalSoftwareManager verificate")

func _test_ship_software_manager_blueprint_integration() -> void:
	print("\n--- TEST 4: Integrazione ShipSoftwareManager & ShipBlueprint ---")
	var bp: ShipBlueprint = ShipBlueprint.new()
	var ssm: Node = get_node_or_null("/root/ShipSoftwareManager")
	
	var custom_app: AppResource = AppResource.new()
	custom_app.app_id = "custom_ew_suite"
	custom_app.title = "EW Combat Suite"
	custom_app.description = "Suite avanzata di guerra elettronica"
	custom_app.scene_path = "res://Applications/Diagnostics/diagnostics_app.tscn"
	custom_app.roles = ["Hacker", "Capitano"]
	custom_app.drive_folder = "Programs/CustomEW"
	custom_app.default_password = "EW-9999"
	custom_app.default_files = [{
		"name": "ew_tuning.dat",
		"content": "# CUSTOM EW TUNING\n[EW]\njamming_mult=2.5\n",
		"is_protected": true,
		"desc": "Parametri EW personalizzati"
	}]
	
	ssm.install_app_to_blueprint(custom_app, bp)
	
	var installed: Dictionary = bp.get_installed_app_by_id("custom_ew_suite")
	assert(not installed.is_empty(), "App custom_ew_suite deve essere registrata nella blueprint")
	assert(bp.get_drive_password("Ship Drive/Programs/CustomEW") == "EW-9999", "Password drive deve essere salvata nella blueprint")
	assert(not bp.get_drive_file_by_path("Ship Drive/Programs/CustomEW/ew_tuning.dat").is_empty(), "File drive deve essere registrato nella blueprint")
	
	# Test disinstallazione (verifica rimozione app, file e password dal blueprint)
	var removed: bool = ssm.uninstall_app_from_blueprint("custom_ew_suite", bp)
	assert(removed == true, "Disinstallazione deve avere esito positivo")
	assert(bp.get_installed_app_by_id("custom_ew_suite").is_empty(), "App custom_ew_suite deve essere stata rimossa da installed_apps")
	assert(bp.get_drive_password("Ship Drive/Programs/CustomEW").is_empty(), "Password drive deve essere stata rimossa dalla blueprint")
	assert(bp.get_drive_file_by_path("Ship Drive/Programs/CustomEW/ew_tuning.dat").is_empty(), "File drive deve essere stato rimosso dalla blueprint")
	print("✔ Installazione e disinstallazione app con copia/rimozione file e password su ShipBlueprint verificate")

func _test_ship_software_manager_drive_population() -> void:
	print("\n--- TEST 5: Popolamento File e Password su Ship Drive ---")
	var sdm: Node = get_node_or_null("/root/ShipDriveManager")
	var ssm: Node = get_node_or_null("/root/ShipSoftwareManager")
	var fpm: Node = get_node_or_null("/root/FolderPasswordManager")
	
	sdm.mount_drive()
	ssm.populate_all_installed_ship_drive_apps()
	
	# Verifica file creati per FlightControl, Cams, PowerGrid, ecc.
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/FlightControls/flight_config.dat"), "File flight_config.dat deve esistere su Ship Drive")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/Cams/cams_config.dat"), "File cams_config.dat deve esistere su Ship Drive")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/PowerGrid/power_grid_config.dat"), "File power_grid_config.dat deve esistere su Ship Drive")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/Sensors/sensors_config.dat"), "File sensors_config.dat deve esistere su Ship Drive")
	
	# Verifica password impostate
	assert(fpm.has_password("Ship Drive/Programs/FlightControls"), "Cartella FlightControls deve essere protetta da password")
	assert(fpm.has_password("Ship Drive/Programs/Cams"), "Cartella Cams deve essere protetta da password")
	assert(fpm.has_password("Ship Drive/Programs/Sensors"), "Cartella Sensors deve essere protetta da password")
	print("✔ Popolamento file e registrazione password su Ship Drive verificati")

func _test_terminal_software_manager_drive_population() -> void:
	print("\n--- TEST 6: Popolamento File su Terminal Drive ---")
	var tdm: Node = get_node_or_null("/root/TerminalDriveManager")
	var tsm: Node = get_node_or_null("/root/TerminalSoftwareManager")
	var fpm: Node = get_node_or_null("/root/FolderPasswordManager")
	
	tdm.ensure_drive_exists()
	tsm.populate_all_terminal_drive_apps()
	
	assert(FileAccess.file_exists("user://files/Terminal Drive/systems/terminal_config.dat"), "File terminal_config.dat deve esistere su Terminal Drive")
	assert(FileAccess.file_exists("user://files/Terminal Drive/systems/godotos_core.dat"), "File godotos_core.dat deve esistere su Terminal Drive")
	assert(fpm.has_password("Terminal Drive/systems"), "Cartella Terminal Drive/systems deve essere protetta da password")
	print("✔ Popolamento file e registrazione password su Terminal Drive verificati")

func _test_role_filtering_rbac() -> void:
	print("\n--- TEST 7: Filtro Ruoli RBAC tramite ShipSoftwareManager ---")
	var ssm: Node = get_node_or_null("/root/ShipSoftwareManager")
	
	var pilot_apps: Array = ssm.get_apps_for_role("Pilota")
	var pilot_ids: Array[String] = []
	for a in pilot_apps:
		if a is AppResource:
			pilot_ids.append(a.app_id)
		elif a is Dictionary:
			pilot_ids.append(str(a.get("id", "")))
	assert(pilot_ids.has("flight_control"), "Pilota deve accedere a flight_control")
	assert(pilot_ids.has("cams"), "Pilota deve accedere a cams")
	assert(not pilot_ids.has("power_grid"), "Pilota non deve accedere a power_grid")
	
	var eng_apps: Array = ssm.get_apps_for_role("Ingegnere")
	var eng_ids: Array[String] = []
	for a in eng_apps:
		if a is AppResource:
			eng_ids.append(a.app_id)
		elif a is Dictionary:
			eng_ids.append(str(a.get("id", "")))
	assert(eng_ids.has("power_grid"), "Ingegnere deve accedere a power_grid")
	assert(eng_ids.has("duct_drone"), "Ingegnere deve accedere a duct_drone")
	assert(eng_ids.has("shield_matrix"), "Ingegnere deve accedere a shield_matrix")
	assert(not eng_ids.has("weapons"), "Ingegnere non deve accedere a weapons")
	
	var cap_apps: Array = ssm.get_apps_for_role("Capitano")
	assert(cap_apps.size() >= 8, "Capitano deve avere accesso a tutte le applicazioni")
	print("✔ Controllo accessi RBAC basato su risorse convalidato")
