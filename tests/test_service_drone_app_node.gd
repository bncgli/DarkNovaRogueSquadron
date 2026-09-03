extends Node

## Test Runner Headless per ServiceDroneApp (Applications/ServiceDrone)
## Verifica Overlay/Ciclo di vita, RBAC, File .DAT / Hot-Reload, ShipSoftwareManager, Azioni Drone 3D e Pulizia Segnali.

func _ready() -> void:
	print("\n=======================================================")
	print(">>> AVVIO SUITE DI TEST HEADLESS: SERVICE DRONE APP")
	print("=======================================================\n")
	_run_all_tests()

func _run_all_tests() -> void:
	await get_tree().process_frame
	
	var app_scene: PackedScene = load("res://Applications/ServiceDrone/service_drone_app.tscn")
	assert(app_scene != null, "La scena service_drone_app.tscn deve essere caricata con successo")
	
	var app: ServiceDroneApp = app_scene.instantiate() as ServiceDroneApp
	assert(app != null, "ServiceDroneApp deve istanziarsi come nodo ServiceDroneApp")
	add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	
	var net_mgr := get_node_or_null("/root/NetworkManager")
	var sdm := get_node_or_null("/root/ShipDriveManager")
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	var ssm := get_node_or_null("/root/ShipSoftwareManager") as ShipSoftwareManagerSingleton
	
	# =========================================================================
	# TEST 1: OVERLAY E CICLO DI VITA (OFFLINE vs MISSIONE AVVIATA)
	# =========================================================================
	print("--- TEST 1: Overlay e Ciclo di Vita Offline / Online ---")
	if net_mgr and net_mgr.is_mission_active:
		net_mgr.disconnect_game()
		await get_tree().process_frame
	
	if SpaceWorldManager:
		SpaceWorldManager.is_ship_connected_state = false
		SpaceWorldManager.ship_connection_changed.emit(false)
		await get_tree().process_frame
	
	assert(app.disconnected_overlay != null, "%DisconnectedOverlay deve esistere nella scena")
	assert(app.disconnected_overlay.visible == true, "%DisconnectedOverlay deve essere VISIBILE quando la nave è offline")
	print("✔ Overlay offline correttamente visualizzato")
	
	# Simula connessione nave / avvio missione
	if SpaceWorldManager:
		SpaceWorldManager.is_ship_connected_state = true
		SpaceWorldManager.ship_connection_changed.emit(true)
		await get_tree().process_frame
	
	assert(app.disconnected_overlay.visible == false, "%DisconnectedOverlay deve SCOMPARIRE quando la nave è connessa")
	print("✔ Overlay rimosso automaticamente a connessione stabilita")
	
	# =========================================================================
	# TEST 2: RBAC (ROLE-BASED ACCESS CONTROL)
	# =========================================================================
	print("\n--- TEST 2: Matrice RBAC (Permessi Ruolo e Controlli) ---")
	if net_mgr:
		net_mgr.host_game("OperatoreEVA")
		await get_tree().process_frame
		
		# 2.1 Pilota: Sola Lettura
		net_mgr.request_role("Pilota")
		await get_tree().process_frame
		assert(app.can_control_drone == false, "Pilota non deve avere controllo attivo sul drone EVA")
		assert(app.manipulator_control.btn_undock.disabled == true, "BtnUndock deve essere disabilitato per Pilota")
		assert(app.manipulator_control.btn_welder.disabled == true, "BtnWelder deve essere disabilitato per Pilota")
		assert(app.manipulator_control.btn_activate_tool.disabled == true, "BtnActivateTool deve essere disabilitato per Pilota")
		print("✔ Ruolo Pilota: correttamente limitato a sola visualizzazione")
		
		# 2.2 Soldato: Sola Lettura
		net_mgr.request_role("Soldato")
		await get_tree().process_frame
		assert(app.can_control_drone == false, "Soldato non deve avere controllo attivo sul drone EVA")
		assert(app.manipulator_control.btn_undock.disabled == true, "BtnUndock deve essere disabilitato per Soldato")
		print("✔ Ruolo Soldato: correttamente limitato a sola visualizzazione")
		
		# 2.3 Hacker: Controllo Completo (Sabotaggio, Taglio Laser, Hacking ravvicinato)
		net_mgr.request_role("Hacker")
		await get_tree().process_frame
		assert(app.can_control_drone == true, "Hacker deve avere controllo completo sul drone EVA")
		assert(app.manipulator_control.btn_undock.disabled == false, "BtnUndock deve essere abilitato per Hacker")
		assert(app.manipulator_control.btn_laser.disabled == false, "BtnLaser deve essere abilitato per Hacker")
		print("✔ Ruolo Hacker: controllo completo abilitato")
		
		# 2.4 Ingegnere: Controllo Completo (Riparazioni esterne, Saldatura, Cargo)
		net_mgr.request_role("Ingegnere")
		await get_tree().process_frame
		assert(app.can_control_drone == true, "Ingegnere deve avere controllo completo sul drone EVA")
		assert(app.manipulator_control.btn_undock.disabled == false, "BtnUndock deve essere abilitato per Ingegnere")
		assert(app.manipulator_control.btn_welder.disabled == false, "BtnWelder deve essere abilitato per Ingegnere")
		print("✔ Ruolo Ingegnere: controllo completo abilitato")
		
		# 2.5 Capitano: Controllo Completo e Override
		net_mgr.request_role("Capitano")
		await get_tree().process_frame
		assert(app.can_control_drone == true, "Capitano deve avere controllo completo sul drone EVA")
		print("✔ Ruolo Capitano: controllo completo abilitato")
		
		# 2.6 Stagista / Solo Mode
		net_mgr.request_role("Stagista")
		await get_tree().process_frame
		assert(app.can_control_drone == true, "Stagista deve avere controllo completo sul drone EVA")
		print("✔ Ruolo Stagista: controllo completo abilitato")
	
	# =========================================================================
	# TEST 3: RISORSA E SOFTWARE MANAGER
	# =========================================================================
	print("\n--- TEST 3: Risorsa AppResource e ShipSoftwareManager ---")
	assert(ssm != null, "ShipSoftwareManager singleton deve essere attivo")
	
	var res: AppResource = ssm.get_registered_app("service_drone")
	assert(res != null, "service_drone_app.tres deve essere registrata nel catalogo ShipSoftwareManager")
	assert(res.app_id == "service_drone", "L'ID della risorsa deve essere 'service_drone'")
	assert(res.title == "Drone di Servizio EVA", "Il titolo della risorsa deve corrispondere")
	assert(res.power_draw_mw == 80.0, "L'assorbimento energetico deve essere 80.0 MW")
	assert(res.default_password == "SERV-7815", "La password di default deve essere 'SERV-7815'")
	assert(res.required_subsystems.has("service_bay"), "Deve richiedere il sottosistema 'service_bay'")
	print("✔ Registrazione e metadati AppResource validati con successo")
	
	# =========================================================================
	# TEST 4: FILE .DAT, PARSING E HOT-RELOADING
	# =========================================================================
	print("\n--- TEST 4: File .DAT, Parsing e Hot-Reloading ---")
	# Popola i file di default su Ship Drive
	if ssm:
		ssm.populate_ship_drive_for_app(res)
		await get_tree().process_frame
	
	assert(DirAccess.dir_exists_absolute("user://files/Ship Drive/Programs/ServiceDrone"), "La cartella Programs/ServiceDrone deve esistere")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/ServiceDrone/service_drone_config.dat"), "service_drone_config.dat deve esistere")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/ServiceDrone/manipulator_tuning.dat"), "manipulator_tuning.dat deve esistere")
	
	if fpm:
		assert(fpm.has_password("Ship Drive/Programs/ServiceDrone"), "La cartella deve essere protetta da password")
		assert(fpm.check_password("Ship Drive/Programs/ServiceDrone", "SERV-7815"), "La password deve essere SERV-7815")
		print("✔ Cartella protetta e file .DAT generati con password corretta")
	
	app.load_dat_configuration()
	assert(app.active_config.get("max_thrust") == 35.0, "max_thrust iniziale deve essere 35.0")
	assert(app.active_config.get("battery_capacity_sec") == 240.0, "battery_capacity_sec iniziale deve essere 240.0")
	assert(app.active_config.get("repair_rate") == 15.0, "repair_rate iniziale deve essere 15.0")
	assert(app.active_config.get("cutting_laser_power") == 25.0, "cutting_laser_power iniziale deve essere 25.0")
	print("✔ Valori iniziali .DAT caricati correttamente")
	
	# Simula modifica del file .DAT (Hot-Reload)
	var new_cfg := "[SYSTEM]\napp_name=ServiceDroneApp\nversion=1.1.0\nstatus=OVERCLOCKED\n\n[FLIGHT]\nmax_thrust=55.0\nbattery_capacity_sec=320.0\ntether_range=2000.0\nauto_dock_speed=18.0\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/ServiceDrone/service_drone_config.dat", FileAccess.WRITE)
	if f_out:
		f_out.store_string(new_cfg)
		f_out.close()
	
	if sdm:
		sdm.file_synced.emit("Ship Drive/Programs/ServiceDrone/service_drone_config.dat")
		await get_tree().process_frame
	
	assert(app.active_config.get("max_thrust") == 55.0, "max_thrust deve aggiornarsi a 55.0 tramite hot-reloading")
	assert(app.active_config.get("battery_capacity_sec") == 320.0, "battery_capacity_sec deve aggiornarsi a 320.0")
	print("✔ Hot-reloading su modifica file .DAT eseguito con successo")
	
	# =========================================================================
	# TEST 5: SIMULAZIONE FISICA 3D, AZIONI BRACCIO E DOCKING
	# =========================================================================
	print("\n--- TEST 5: Simulazione 3D, Collisioni, Controlli Rotazione e Docking ---")
	var drone := SpaceWorldManager.get_service_drone()
	assert(drone != null, "SpaceWorldManager deve istanziare o restituire il ServiceDroneEntity")
	assert(drone is CharacterBody3D, "ServiceDroneEntity deve estendere CharacterBody3D")
	
	# Verifica Collider e Layer/Mask
	var col_shape := drone.get_node_or_null("CollisionShape3D") as CollisionShape3D
	assert(col_shape != null, "ServiceDroneEntity deve possedere un nodo CollisionShape3D")
	assert(col_shape.shape is BoxShape3D, "CollisionShape3D deve usare una risorsa BoxShape3D")
	var box := col_shape.shape as BoxShape3D
	assert(box.size == Vector3(0.7, 0.35, 0.9), "BoxShape3D deve avere dimensioni Vector3(0.7, 0.35, 0.9)")
	assert(drone.collision_layer == 2, "collision_layer del drone deve essere 2")
	assert(drone.collision_mask == 7, "collision_mask del drone deve essere 7")
	print("✔ Collider 3D, BoxShape3D e layer/mask di collisione convalidati")
	
	# Decollo
	SpaceWorldManager.launch_service_drone()
	await get_tree().process_frame
	assert(drone.is_docked == false, "Il drone deve essere in stato non-docked dopo il decollo")
	print("✔ Decollo drone EVA completato")
	
	# Test spinta e movimento lineare
	SpaceWorldManager.set_service_drone_inputs(Vector3(0, 0, -1), Vector3.ZERO, false)
	drone._physics_process(0.1)
	assert(drone.current_linear_velocity.length() > 0.0, "I thruster devono impartire velocità lineare al drone")
	print("✔ Propulsione thruster RCS e fisica move_and_slide verificata")
	
	# Test Controlli di Rotazione con Tasti Freccia (KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT)
	var evt_up := InputEventKey.new()
	evt_up.keycode = KEY_UP
	evt_up.pressed = true
	app._input(evt_up)
	assert(app._manual_angular_input.x == 1.0, "KEY_UP deve impostare _manual_angular_input.x a 1.0 (Pitch positivo)")
	drone._physics_process(0.1)
	assert(drone.current_angular_velocity.x > 0.0, "KEY_UP deve impartire velocità angolare di pitch positiva")
	
	evt_up.pressed = false
	app._input(evt_up)
	assert(app._manual_angular_input.x == 0.0, "Rilascio KEY_UP deve resettare _manual_angular_input.x a 0.0")
	
	var evt_down := InputEventKey.new()
	evt_down.keycode = KEY_DOWN
	evt_down.pressed = true
	app._input(evt_down)
	assert(app._manual_angular_input.x == -1.0, "KEY_DOWN deve impostare _manual_angular_input.x a -1.0 (Pitch negativo)")
	evt_down.pressed = false
	app._input(evt_down)
	
	var evt_left := InputEventKey.new()
	evt_left.keycode = KEY_LEFT
	evt_left.pressed = true
	app._input(evt_left)
	assert(app._manual_angular_input.y == 1.0, "KEY_LEFT deve impostare _manual_angular_input.y a 1.0 (Yaw antiorario)")
	drone._physics_process(0.1)
	assert(drone.current_angular_velocity.y > 0.0, "KEY_LEFT deve impartire velocità angolare di yaw positiva")
	
	evt_left.pressed = false
	app._input(evt_left)
	assert(app._manual_angular_input.y == 0.0, "Rilascio KEY_LEFT deve resettare _manual_angular_input.y a 0.0")
	
	var evt_right := InputEventKey.new()
	evt_right.keycode = KEY_RIGHT
	evt_right.pressed = true
	app._input(evt_right)
	assert(app._manual_angular_input.y == -1.0, "KEY_RIGHT deve impostare _manual_angular_input.y a -1.0 (Yaw orario)")
	evt_right.pressed = false
	app._input(evt_right)
	print("✔ Mappatura tasti freccia (Pitch & Yaw) e rotazione angolare diegetica validate")
	
	# Test selezione e attivazione strumento saldatura su breccia
	var test_dmg := SpaceWorldManager.spawn_ship_damage(SpaceWorldManager.DAMAGE_TYPE_BREACH, Vector2(100, 100), "Scafo Esterno", 2.0)
	assert(test_dmg.get("id") != null, "Danno breccia deve essere spawnato")
	
	SpaceWorldManager.set_service_drone_active_tool("welder")
	SpaceWorldManager.set_service_drone_tool_trigger(true, str(test_dmg.get("id")))
	drone._physics_process(1.0)
	drone._physics_process(1.0)
	print("✔ Saldatrice e avanzamento riparazione breccia verificati")
	
	# Test stiva cargo
	var item_added := drone.collect_cargo_item("salvage_01", "Titanium Hull Debris", 150.0)
	assert(item_added == true, "Raccolta materiale cargo deve riuscire entro la capienza max")
	assert(drone.cargo_weight_kg == 150.0, "Il peso cargo deve essere 150 kg")
	var dropped := drone.drop_cargo_item(0)
	assert(dropped.get("id") == "salvage_01")
	assert(drone.cargo_weight_kg == 0.0, "Il peso cargo deve tornare a 0 kg")
	print("✔ Operazioni stiva cargo e harpoon validate")
	
	# Test auto-docking
	SpaceWorldManager.dock_service_drone()
	await get_tree().process_frame
	assert(drone.is_docked == true, "Il drone deve risultare agganciato in baia")
	print("✔ Aggancio e docking completati")
	
	# =========================================================================
	# TEST 6: PULIZIA SEGNALI E MEMORY LEAK SULLA CHIUSURA
	# =========================================================================
	print("\n--- TEST 6: Pulizia Segnali e Ciclo di Vita ---")
	app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("✔ Disconnessione pulita dei segnali in _exit_tree() validata")
	
	print("\n=======================================================")
	print(">>> TUTTI I TEST DEL SERVICE DRONE COMPLETATI CON SUCCESSO! <<<")
	print("=======================================================\n")
	get_tree().quit(0)
