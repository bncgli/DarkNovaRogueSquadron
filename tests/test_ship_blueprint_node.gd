extends Node

func _ready() -> void:
	print("--- INIZIO TEST SHIP BLUEPRINT & SUBLAYER ARCHITECTURE ---")
	_run_suite.call_deferred()

func _run_suite() -> void:
	await get_tree().process_frame

	# =========================================================================
	# FASE 1: TEST CREAZIONE E INIZIALIZZAZIONE BLUEPRINT DI DEFAULT
	# =========================================================================
	print("\n--- TEST 1: Inizializzazione e Struttura ShipBlueprint di Default ---")
	var bp := ShipBlueprint.new()
	bp.create_default_ship()
	
	assert(bp.ship_id == "dark_nova_corvette", "ship_id deve essere dark_nova_corvette")
	assert(bp.ship_name == "Dark Nova Corvette", "ship_name deve essere Dark Nova Corvette")
	assert(bp.ship_bounds == Rect2(60, 30, 480, 420), "ship_bounds deve corrispondere alle dimensioni previste")
	assert(bp.rooms.size() == 10, "La Blueprint deve contenere 10 stanze di default")
	assert(bp.ducts.size() == 14, "La Blueprint deve contenere 14 condotti di default")
	assert(bp.devices.size() == 11, "La Blueprint deve contenere 11 dispositivi elettrici di default")
	assert(bp.junctions.size() == 8, "La Blueprint deve contenere 8 snodi elettrici di default")
	assert(bp.damages.size() == 8, "La Blueprint deve contenere 8 punti di danno predefiniti")
	assert(bp.drive_files.size() == 19, "La Blueprint deve contenere 19 file di default per Ship Drive (inclusi Weapons, ShieldMatrix, Comms e Diagnostics)")
	assert(bp.drive_passwords.size() == 8, "La Blueprint deve contenere 8 password cartelle per Ship Drive (inclusi Weapons, ShieldMatrix, Comms e Diagnostics)")
	assert(bp.installed_apps.size() == 8, "La Blueprint deve contenere 8 applicazioni mainframe installate di default (inclusi Weapons, ShieldMatrix, Comms e Diagnostics)")
	print("✔ Struttura dati e 6 sublayer (incluso Mainframe Apps & Ship Drive) inizializzati con successo")

	# =========================================================================
	# FASE 2: METODI DI QUERY RAPIDA (Stanze, Condotti, Dispositivi, Snodi, Danni)
	# =========================================================================
	print("\n--- TEST 2: Metodi di Query Rapida ---")
	var bridge_room := bp.get_room_by_id("bridge")
	assert(not bridge_room.is_empty(), "get_room_by_id(bridge) deve trovare la stanza")
	assert(bridge_room.get("name") == "Ponte di Comando", "Nome stanza deve essere Ponte di Comando")

	var room_at_bridge := bp.get_room_at(Vector2(250, 60))
	assert(not room_at_bridge.is_empty(), "get_room_at deve trovare la stanza al punto (250, 60)")
	assert(room_at_bridge.get("id") == "bridge", "La stanza trovata deve essere bridge")

	var non_existing_room := bp.get_room_by_id("non_existing_room_id")
	assert(non_existing_room.is_empty(), "get_room_by_id su ID inesistente deve ritornare dizionario vuoto")

	var duct_spine := bp.get_duct_by_id("duct_spine_1")
	assert(not duct_spine.is_empty(), "get_duct_by_id(duct_spine_1) deve trovare il condotto")

	var reactor_dev := bp.get_device_by_id("reactor_main")
	assert(not reactor_dev.is_empty(), "get_device_by_id(reactor_main) deve trovare il dispositivo")
	assert(reactor_dev.get("is_generator") == true, "reactor_main deve essere un generatore")

	var junction_j1 := bp.get_junction_by_id("J1")
	assert(not junction_j1.is_empty(), "get_junction_by_id(J1) deve trovare lo snodo J1")

	var dmg_1 := bp.get_damage_by_id("dmg_1")
	assert(not dmg_1.is_empty(), "get_damage_by_id(dmg_1) deve trovare il punto di danno")

	var sys_file := bp.get_drive_file_by_path("Ship Drive/Ship Systems.txt")
	assert(not sys_file.is_empty(), "get_drive_file_by_path deve trovare Ship Systems.txt")
	assert(sys_file.get("is_protected") == false, "Ship Systems.txt non deve essere protetto")

	var flight_cfg := bp.get_drive_file_by_path("Ship Drive/Programs/FlightControls/flight_config.dat")
	assert(not flight_cfg.is_empty(), "get_drive_file_by_path deve trovare flight_config.dat")
	assert(flight_cfg.get("is_protected") == true, "flight_config.dat deve essere protetto")

	var flight_pwd := bp.get_drive_password("Ship Drive/Programs/FlightControls")
	assert(flight_pwd == "FLIGHT-7815", "Password FlightControls deve essere FLIGHT-7815")

	var weap_cfg := bp.get_drive_file_by_path("Ship Drive/Programs/Weapons/weapons_config.dat")
	assert(not weap_cfg.is_empty(), "get_drive_file_by_path deve trovare weapons_config.dat")
	assert(weap_cfg.get("is_protected") == true, "weapons_config.dat deve essere protetto")

	var weap_pwd := bp.get_drive_password("Ship Drive/Programs/Weapons")
	assert(weap_pwd == "WEAP-7815", "Password Weapons deve essere WEAP-7815")

	var shld_cfg := bp.get_drive_file_by_path("Ship Drive/Programs/ShieldMatrix/shields_config.dat")
	assert(not shld_cfg.is_empty(), "get_drive_file_by_path deve trovare shields_config.dat")
	assert(shld_cfg.get("is_protected") == true, "shields_config.dat deve essere protetto")

	var shld_pwd := bp.get_drive_password("Ship Drive/Programs/ShieldMatrix")
	assert(shld_pwd == "SHLD-7815", "Password ShieldMatrix deve essere SHLD-7815")

	var comm_cfg := bp.get_drive_file_by_path("Ship Drive/Programs/Comms/comms_config.dat")
	assert(not comm_cfg.is_empty(), "get_drive_file_by_path deve trovare comms_config.dat")
	assert(comm_cfg.get("is_protected") == true, "comms_config.dat deve essere protetto")

	var comm_pwd := bp.get_drive_password("Ship Drive/Programs/Comms")
	assert(comm_pwd == "COMM-7815", "Password Comms deve essere COMM-7815")

	var diag_cfg := bp.get_drive_file_by_path("Ship Drive/Programs/Diagnostics/diagnostics_config.dat")
	assert(not diag_cfg.is_empty(), "get_drive_file_by_path deve trovare diagnostics_config.dat")
	assert(diag_cfg.get("is_protected") == true, "diagnostics_config.dat deve essere protetto")

	var diag_pwd := bp.get_drive_password("Ship Drive/Programs/Diagnostics")
	assert(diag_pwd == "DIAG-7815", "Password Diagnostics deve essere DIAG-7815")

	# Test aggiunta e rimozione file dinamico
	bp.set_drive_file("Ship Drive/test_note.txt", "Note test", false, "Descrizione")
	assert(not bp.get_drive_file_by_path("Ship Drive/test_note.txt").is_empty(), "File temporaneo aggiunto con successo")
	assert(bp.remove_drive_file("Ship Drive/test_note.txt") == true, "File temporaneo rimosso con successo")

	# Test query applicazioni mainframe e filtro ruoli
	var fc_app := bp.get_installed_app_by_id("flight_control")
	assert(not fc_app.is_empty(), "get_installed_app_by_id deve trovare flight_control")
	assert(fc_app.get("title") == "Flight Control", "Titolo app deve essere Flight Control")
	
	var weap_app := bp.get_installed_app_by_id("weapons")
	assert(not weap_app.is_empty(), "get_installed_app_by_id deve trovare weapons")
	assert(weap_app.get("title") == "Tactical Weapons", "Titolo app deve essere Tactical Weapons")
	
	var shld_app := bp.get_installed_app_by_id("shield_matrix")
	assert(not shld_app.is_empty(), "get_installed_app_by_id deve trovare shield_matrix")
	assert(shld_app.get("title") == "Shield Matrix", "Titolo app deve essere Shield Matrix")
	
	var comm_app := bp.get_installed_app_by_id("comms")
	assert(not comm_app.is_empty(), "get_installed_app_by_id deve trovare comms")
	assert(comm_app.get("title") == "Comms & Electronic War", "Titolo app deve essere Comms & Electronic War")

	var diag_app := bp.get_installed_app_by_id("diagnostics")
	assert(not diag_app.is_empty(), "get_installed_app_by_id deve trovare diagnostics")
	assert(diag_app.get("title") == "System Diagnostics", "Titolo app deve essere System Diagnostics")
	
	var pilot_apps := bp.get_apps_for_role("Pilota", false)
	assert(pilot_apps.size() == 2, "Pilota deve visualizzare 2 app (Flight Control e Cams)")
	
	var eng_apps := bp.get_apps_for_role("Ingegnere", false)
	assert(eng_apps.size() == 4, "Ingegnere deve visualizzare 4 app (Duct Drone, Power Grid, Shield Matrix e System Diagnostics)")
	
	var soldier_apps := bp.get_apps_for_role("Soldato", false)
	assert(soldier_apps.size() == 2, "Soldato deve visualizzare 2 app (Cams e Weapons)")
	
	var hacker_apps := bp.get_apps_for_role("Hacker", false)
	assert(hacker_apps.size() == 3, "Hacker deve visualizzare 3 app (Duct Drone, Comms & Electronic War e System Diagnostics)")
	
	var cap_apps := bp.get_apps_for_role("Capitano", false)
	assert(cap_apps.size() == 8, "Capitano deve visualizzare tutte e 8 le app")

	print("✔ Tutte le query e ricerche per ID/coordinate/drive/app hanno avuto successo")

	# =========================================================================
	# FASE 3: SERIALIZZAZIONE TO_DICT E FROM_DICT
	# =========================================================================
	print("\n--- TEST 3: Serializzazione to_dict() e from_dict() ---")
	var serialized_dict := bp.to_dict()
	assert(serialized_dict.has("ship_id") and serialized_dict["ship_id"] == "dark_nova_corvette", "Dizionario deve contenere ship_id")
	assert(serialized_dict.has("rooms") and serialized_dict["rooms"].size() == 10, "Dizionario deve contenere 10 stanze")
	assert(serialized_dict.has("devices") and serialized_dict["devices"].size() == 11, "Dizionario deve contenere 11 dispositivi")
	assert(serialized_dict.has("junctions") and serialized_dict["junctions"].size() == 8, "Dizionario deve contenere 8 snodi")
	assert(serialized_dict.has("drive_files") and serialized_dict["drive_files"].size() == 19, "Dizionario deve contenere 19 file drive")
	assert(serialized_dict.has("drive_passwords") and serialized_dict["drive_passwords"].size() == 8, "Dizionario deve contenere 8 password drive")
	assert(serialized_dict.has("installed_apps") and serialized_dict["installed_apps"].size() == 8, "Dizionario deve contenere 8 app mainframe")

	var reconstructed_bp := ShipBlueprint.new()
	reconstructed_bp.from_dict(serialized_dict)
	assert(reconstructed_bp.ship_id == bp.ship_id, "ship_id ricostruito deve coincidere")
	assert(reconstructed_bp.ship_bounds == bp.ship_bounds, "ship_bounds ricostruito deve coincidere")
	assert(reconstructed_bp.rooms.size() == bp.rooms.size(), "Numero stanze ricostruito deve coincidere")
	assert(reconstructed_bp.ducts.size() == bp.ducts.size(), "Numero condotti ricostruito deve coincidere")
	assert(reconstructed_bp.devices.size() == bp.devices.size(), "Numero dispositivi ricostruito deve coincidere")
	assert(reconstructed_bp.junctions.size() == bp.junctions.size(), "Numero snodi ricostruito deve coincidere")
	assert(reconstructed_bp.damages.size() == bp.damages.size(), "Numero danni ricostruito deve coincidere")
	assert(reconstructed_bp.drive_files.size() == bp.drive_files.size(), "Numero file drive ricostruito deve coincidere")
	assert(reconstructed_bp.drive_passwords.size() == bp.drive_passwords.size(), "Numero password drive ricostruito deve coincidere")
	assert(reconstructed_bp.installed_apps.size() == bp.installed_apps.size(), "Numero app mainframe ricostruito deve coincidere")
	print("✔ Serializzazione e deserializzazione validate con successo")

	# =========================================================================
	# FASE 4: ESPORTAZIONE E IMPORTAZIONE JSON
	# =========================================================================
	print("\n--- TEST 4: Export e Import JSON ---")
	const TEST_JSON_PATH := "user://test_ship_blueprint.json"
	var export_err := bp.export_to_json(TEST_JSON_PATH)
	assert(export_err == OK, "Esportazione su file JSON deve restituire OK")
	assert(FileAccess.file_exists(TEST_JSON_PATH), "Il file JSON esportato deve esistere su disco")

	var imported_bp := ShipBlueprint.new()
	var import_err := imported_bp.import_from_json(TEST_JSON_PATH)
	assert(import_err == OK, "Importazione da file JSON deve restituire OK")
	assert(imported_bp.ship_name == "Dark Nova Corvette", "Nome nave importato deve coincidere")
	assert(imported_bp.rooms.size() == 10, "Stanze importate da JSON devono essere 10")
	assert(imported_bp.devices.size() == 11, "Dispositivi importati da JSON devono essere 11")
	assert(imported_bp.drive_files.size() == 19, "File drive importati da JSON devono essere 19")
	assert(imported_bp.drive_passwords.size() == 8, "Password drive importate da JSON devono essere 8")
	assert(imported_bp.installed_apps.size() == 8, "App mainframe importate da JSON devono essere 8")

	# Test gestione errori su file inesistente
	var missing_err := imported_bp.import_from_json("user://non_existing_file_12345.json")
	assert(missing_err != OK, "Importazione di file inesistente deve restituire errore")
	print("✔ Esportazione e importazione JSON eseguite correttamente")

	# =========================================================================
	# FASE 5: CLONAZIONE PROFONDA E ISOLAMENTO
	# =========================================================================
	print("\n--- TEST 5: Clonazione Profonda (clone()) ---")
	var cloned_bp := bp.clone()
	assert(cloned_bp != null, "L'istanza clonata non deve essere null")
	assert(cloned_bp.ship_id == bp.ship_id, "L'istanza clonata deve avere lo stesso ship_id")

	# Modifica sull'istanza clonata per verificare l'isolamento
	cloned_bp.ship_name = "Corvetta Modificata"
	cloned_bp.rooms[0]["name"] = "Ponte Personalizzato"
	assert(bp.ship_name == "Dark Nova Corvette", "L'originale non deve essere mutato dalla modifica del nome clone")
	assert(bp.rooms[0]["name"] == "Ponte di Comando", "L'originale non deve essere mutato dalla modifica di una stanza nel clone")
	print("✔ Clonazione profonda e isolamento delle istanze validati")

	# =========================================================================
	# FASE 6: INTEGRAZIONE CON SPACE WORLD MANAGER
	# =========================================================================
	print("\n--- TEST 6: Integrazione con SpaceWorldManager ---")
	if SpaceWorldManager:
		SpaceWorldManager.set_ship_blueprint(bp)
		var mgr_bp := SpaceWorldManager.get_ship_blueprint()
		assert(mgr_bp != null and mgr_bp.ship_id == "dark_nova_corvette", "SpaceWorldManager deve restituire la blueprint attiva")

		var mgr_rooms := SpaceWorldManager.get_duct_rooms()
		assert(mgr_rooms.size() == 10, "SpaceWorldManager.get_duct_rooms() deve restituire 10 stanze")

		var mgr_ducts := SpaceWorldManager.get_duct_corridors()
		assert(mgr_ducts.size() == 14, "SpaceWorldManager.get_duct_corridors() deve restituire 14 condotti")

		var mgr_devs := SpaceWorldManager.get_power_devices()
		assert(mgr_devs.size() == 11, "SpaceWorldManager.get_power_devices() deve restituire 11 dispositivi")

		var mgr_juncs := SpaceWorldManager.get_power_junctions()
		assert(mgr_juncs.size() == 8, "SpaceWorldManager.get_power_junctions() deve restituire 8 snodi")

		var mgr_damages := SpaceWorldManager.get_damage_zones()
		assert(mgr_damages.size() == 8, "SpaceWorldManager.get_damage_zones() deve restituire 8 zone di danno")

		var mgr_files := SpaceWorldManager.get_ship_drive_files()
		assert(mgr_files.size() == 19, "SpaceWorldManager.get_ship_drive_files() deve restituire 19 file")

		var mgr_passwords := SpaceWorldManager.get_ship_drive_passwords()
		assert(mgr_passwords.size() == 8, "SpaceWorldManager.get_ship_drive_passwords() deve restituire 8 password")

		var mgr_apps := SpaceWorldManager.get_installed_apps()
		assert(mgr_apps.size() == 8, "SpaceWorldManager.get_installed_apps() deve restituire 8 app")

		var mgr_pilot_apps := SpaceWorldManager.get_installed_apps_for_role("Pilota")
		assert(mgr_pilot_apps.size() == 2, "SpaceWorldManager.get_installed_apps_for_role(Pilota) deve restituire 2 app")

		var mgr_eng_apps := SpaceWorldManager.get_installed_apps_for_role("Ingegnere")
		assert(mgr_eng_apps.size() == 4, "SpaceWorldManager.get_installed_apps_for_role(Ingegnere) deve restituire 4 app (Duct Drone, Power Grid, Shield Matrix e System Diagnostics)")

		var mgr_soldier_apps := SpaceWorldManager.get_installed_apps_for_role("Soldato")
		assert(mgr_soldier_apps.size() == 2, "SpaceWorldManager.get_installed_apps_for_role(Soldato) deve restituire 2 app (Cams e Weapons)")

		var mgr_hacker_apps := SpaceWorldManager.get_installed_apps_for_role("Hacker")
		assert(mgr_hacker_apps.size() == 3, "SpaceWorldManager.get_installed_apps_for_role(Hacker) deve restituire 3 app (Duct Drone, Comms & Electronic War e System Diagnostics)")

		# Test generazione danni da blueprint
		SpaceWorldManager.generate_initial_ship_damages(3)
		var active_damages := SpaceWorldManager.get_ship_damages()
		assert(active_damages.size() == 3, "SpaceWorldManager deve aver generato 3 danni attingendo dalla blueprint")
		print("✔ Integrazione completa tra SpaceWorldManager e ShipBlueprint verificata")

	# =========================================================================
	# FASE 7: INTEGRAZIONE CON POWER GRID APP
	# =========================================================================
	print("\n--- TEST 7: Integrazione PowerGridApp con ShipBlueprint ---")
	var pwr_res: PackedScene = load("res://Applications/PowerGrid/power_grid_app.tscn")
	assert(pwr_res != null, "Scena power_grid_app.tscn valida")
	var pwr_app: PowerGridApp = pwr_res.instantiate() as PowerGridApp
	add_child(pwr_app)
	await get_tree().process_frame

	assert(pwr_app.devices.size() == 11, "PowerGridApp deve aver caricato 11 dispositivi da ShipBlueprint")
	assert(pwr_app.junctions.size() == 8, "PowerGridApp deve aver caricato 8 snodi da ShipBlueprint")
	assert(pwr_app.devices.has("reactor_main"), "PowerGridApp deve contenere reactor_main")
	assert(pwr_app.junctions.has("J1"), "PowerGridApp deve contenere snodo J1")

	pwr_app.queue_free()
	await get_tree().process_frame
	print("✔ PowerGridApp inizializzata con successo dai dati della Blueprint")

	# =========================================================================
	# FASE 8: INTEGRAZIONE CON DUCT DRONE APP
	# =========================================================================
	print("\n--- TEST 8: Integrazione DuctDroneApp con ShipBlueprint ---")
	var drone_res: PackedScene = load("res://Applications/DuctDrone/duct_drone_app.tscn")
	assert(drone_res != null, "Scena duct_drone_app.tscn valida")
	var drone_app = drone_res.instantiate()
	add_child(drone_app)
	await get_tree().process_frame

	assert(drone_app.get("rooms").size() == 10, "DuctDroneApp deve aver caricato 10 stanze")
	assert(drone_app.get("ducts").size() == 14, "DuctDroneApp deve aver caricato 14 condotti")

	drone_app.queue_free()
	await get_tree().process_frame
	print("✔ DuctDroneApp inizializzata con successo dai dati della Blueprint")

	# =========================================================================
	# FASE 9: ISTANZIAZIONE VISUAL EDITOR & CANVAS
	# =========================================================================
	print("\n--- TEST 9: Istanziazione Editor e Canvas UI ---")
	var editor := ShipSublayerEditor.new()
	add_child(editor)
	await get_tree().process_frame

	editor.load_blueprint(bp)
	assert(editor.canvas != null, "Editor canvas deve essere istanziato")
	assert(editor.canvas.blueprint == bp, "Canvas deve referenziare la blueprint corrente")

	editor.queue_free()
	await get_tree().process_frame
	print("✔ Editor visivo e Canvas istanziati e collegati alla Blueprint con successo")

	# =========================================================================
	# FASE 10: INTEGRAZIONE SHIP DRIVE MANAGER & MOUNT DA BLUEPRINT
	# =========================================================================
	print("\n--- TEST 10: Integrazione ShipDriveManager con ShipBlueprint ---")
	var net_mgr: GameNetworkManager = get_node_or_null("/root/NetworkManager") as GameNetworkManager
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm:
		sdm.unmount_drive()
		assert(not sdm.is_drive_mounted, "ShipDrive deve essere smontato prima del test")
		
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
		
		assert(sdm.is_drive_mounted, "ShipDrive deve essere montato")
		
		# Verifica che i file e i file .dat siano stati scritti da ShipBlueprint
		assert(FileAccess.file_exists("user://files/Ship Drive/Ship Systems.txt"), "Ship Systems.txt deve esistere su disco")
		assert(FileAccess.file_exists("user://files/Ship Drive/Programs/FlightControls/flight_config.dat"), "flight_config.dat deve esistere su disco")
		assert(FileAccess.file_exists("user://files/Ship Drive/Programs/PowerGrid/power_grid_config.dat"), "power_grid_config.dat deve esistere su disco")
		assert(FileAccess.file_exists("user://files/Ship Drive/Programs/Comms/comms_config.dat"), "comms_config.dat deve esistere su disco")
		
		# Verifica che le password cartella siano state applicate
		var fpm := get_node_or_null("/root/FolderPasswordManager")
		if fpm:
			assert(fpm.has_password("Ship Drive/Programs/FlightControls"), "Password FlightControls deve essere impostata")
			assert(fpm.has_password("Ship Drive/Programs/PowerGrid"), "Password PowerGrid deve essere impostata")
			assert(fpm.has_password("Ship Drive/Programs/Comms"), "Password Comms deve essere impostata")
			
		sdm.unmount_drive()
		if net_mgr:
			net_mgr.disconnect_game()
		assert(not sdm.is_drive_mounted, "ShipDrive smontato al termine del test")
		print("✔ ShipDriveManager ha montato e popolato i file da ShipBlueprint con successo")

	# =========================================================================
	# FASE 11: APPLICAZIONI MAINFRAME, FILTRO RUOLI E MENU START TASKBAR
	# =========================================================================
	print("\n--- TEST 11: Applicazioni Mainframe e Filtro Ruoli Menu Start ---")
	var taskbar_scene: PackedScene = load("res://Scenes/Taskbar/taskbar.tscn")
	assert(taskbar_scene != null, "Scena taskbar.tscn valida")
	var taskbar_inst: Control = taskbar_scene.instantiate() as Control
	add_child(taskbar_inst)
	await get_tree().process_frame
	
	var start_btn = taskbar_inst.get_node("Taskbar/Start Button")
	var vbox = taskbar_inst.get_node("StartMenuAnchor/Start Menu/VBoxContainer")
	assert(start_btn != null and vbox != null, "Nodi Start Button e VBoxContainer presenti in Taskbar")
	
	# 1. Stato Offline / Lobby: le app della nave NON devono essere presenti nel menu
	var count_dynamic_initial := 0
	for child in vbox.get_children():
		if child.is_in_group("dynamic_ship_apps"):
			count_dynamic_initial += 1
	assert(count_dynamic_initial == 0, "A gioco offline/disconnesso non devono comparire app nave nel menu Start")
	
	# 2. Avvio missione come Pilota (aggiornamento automatico via segnali)
	if net_mgr:
		net_mgr.start_solo_game("GiocatoreTest")
		net_mgr.request_role("Pilota")
		net_mgr.start_mission()
		await get_tree().process_frame
		await get_tree().process_frame
		
		pilot_apps = bp.get_apps_for_role("Pilota", false)
		assert(pilot_apps.size() == 2, "Pilota deve avere accesso a 2 app (Flight Control e Cams)")
		
		var current_ship_apps: Array = []
		for child in vbox.get_children():
			if child.is_in_group("dynamic_ship_apps"):
				current_ship_apps.append(child.name)
		assert(current_ship_apps.has("ShipApp_flight_control"), "Menu Start per Pilota deve contenere Flight Control")
		assert(current_ship_apps.has("ShipApp_cams"), "Menu Start per Pilota deve contenere Cams")
		assert(not current_ship_apps.has("ShipApp_power_grid"), "Menu Start per Pilota NON deve contenere Power Grid")
		assert(not current_ship_apps.has("ShipApp_duct_drone"), "Menu Start per Pilota NON deve contenere Duct Drone")
		
		# 3. Cambio ruolo in Ingegnere (aggiornamento automatico via segnale)
		net_mgr.request_role("Ingegnere")
		await get_tree().process_frame
		await get_tree().process_frame
		
		eng_apps = bp.get_apps_for_role("Ingegnere", false)
		assert(eng_apps.size() == 4, "Ingegnere deve avere accesso a 4 app (Power Grid, Duct Drone, Shield Matrix e System Diagnostics)")
		
		current_ship_apps.clear()
		for child in vbox.get_children():
			if child.is_in_group("dynamic_ship_apps"):
				current_ship_apps.append(child.name)
		assert(current_ship_apps.has("ShipApp_power_grid"), "Menu Start per Ingegnere deve contenere Power Grid")
		assert(current_ship_apps.has("ShipApp_duct_drone"), "Menu Start per Ingegnere deve contenere Duct Drone")
		assert(current_ship_apps.has("ShipApp_shield_matrix"), "Menu Start per Ingegnere deve contenere Shield Matrix")
		assert(current_ship_apps.has("ShipApp_diagnostics"), "Menu Start per Ingegnere deve contenere Diagnostics")
		assert(not current_ship_apps.has("ShipApp_flight_control"), "Menu Start per Ingegnere NON deve contenere Flight Control")
		
		# 4. Cambio ruolo in Capitano (Accesso totale a tutte le app installate)
		net_mgr.request_role("Capitano")
		await get_tree().process_frame
		await get_tree().process_frame
		
		current_ship_apps.clear()
		for child in vbox.get_children():
			if child.is_in_group("dynamic_ship_apps"):
				current_ship_apps.append(child.name)
		assert(current_ship_apps.size() == 8, "Menu Start per Capitano deve contenere tutte e 8 le app nave (inclusa Diagnostics)")
		assert(current_ship_apps.has("ShipApp_weapons"), "Menu Start per Capitano deve contenere Weapons")
		assert(current_ship_apps.has("ShipApp_shield_matrix"), "Menu Start per Capitano deve contenere Shield Matrix")
		assert(current_ship_apps.has("ShipApp_comms"), "Menu Start per Capitano deve contenere Comms")
		assert(current_ship_apps.has("ShipApp_diagnostics"), "Menu Start per Capitano deve contenere Diagnostics")
		
		# 4b. Cambio ruolo in Soldato (Cams e Weapons)
		net_mgr.request_role("Soldato")
		await get_tree().process_frame
		await get_tree().process_frame
		
		current_ship_apps.clear()
		for child in vbox.get_children():
			if child.is_in_group("dynamic_ship_apps"):
				current_ship_apps.append(child.name)
		assert(current_ship_apps.size() == 2, "Menu Start per Soldato deve contenere 2 app")
		assert(current_ship_apps.has("ShipApp_cams"), "Menu Start per Soldato deve contenere Cams")
		assert(current_ship_apps.has("ShipApp_weapons"), "Menu Start per Soldato deve contenere Weapons")

		# 4c. Cambio ruolo in Hacker (Duct Drone, Comms e Diagnostics)
		net_mgr.request_role("Hacker")
		await get_tree().process_frame
		await get_tree().process_frame
		
		current_ship_apps.clear()
		for child in vbox.get_children():
			if child.is_in_group("dynamic_ship_apps"):
				current_ship_apps.append(child.name)
		assert(current_ship_apps.size() == 3, "Menu Start per Hacker deve contenere 3 app")
		assert(current_ship_apps.has("ShipApp_duct_drone"), "Menu Start per Hacker deve contenere Duct Drone")
		assert(current_ship_apps.has("ShipApp_comms"), "Menu Start per Hacker deve contenere Comms")
		assert(current_ship_apps.has("ShipApp_diagnostics"), "Menu Start per Hacker deve contenere Diagnostics")
		
		# 5. Fine missione / Disconnessione
		net_mgr.disconnect_game()
		await get_tree().process_frame
		await get_tree().process_frame
		
		current_ship_apps.clear()
		for child in vbox.get_children():
			if child.is_in_group("dynamic_ship_apps"):
				current_ship_apps.append(child.name)
		assert(current_ship_apps.size() == 0, "Alla disconnessione le app nave devono essere rimosse dal menu Start")
	
	taskbar_inst.queue_free()
	await get_tree().process_frame
	print("✔ Filtro ruoli e popolamento dinamico delle app nel menu Start verificati con successo")

	# Pulizia file di test
	if FileAccess.file_exists(TEST_JSON_PATH):
		DirAccess.remove_absolute(TEST_JSON_PATH)

	print("\n=======================================================")
	print("✔ TUTTI I TEST SHIP BLUEPRINT COMPLETATI CON SUCCESSO! (11/11)")
	print("=======================================================")
	get_tree().quit(0)
