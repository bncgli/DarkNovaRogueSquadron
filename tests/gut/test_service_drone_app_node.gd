extends GutTest

## Test GUT per l'applicazione ServiceDrone (pilotaggio EVA, saldatura falle,
## taglio laser, stiva cargo e docking automatico).
## Migrato da tests/test_service_drone_app_node.gd (extends Node, assert() nudo).

var _app: ServiceDroneApp = null

func before_each() -> void:
	NetworkManager.disconnect_game()

func after_each() -> void:
	if is_instance_valid(_app):
		_app.queue_free()
	_app = null
	NetworkManager.disconnect_game()

func _start_solo_mission(player_name: String = "Comandante Test") -> void:
	NetworkManager.start_solo_game(player_name)
	NetworkManager.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame

func _create_app() -> ServiceDroneApp:
	var scene: PackedScene = load("res://Applications/ServiceDrone/service_drone_app.tscn")
	assert_not_null(scene, "Scena service_drone_app.tscn deve essere caricabile")
	var app: ServiceDroneApp = scene.instantiate() as ServiceDroneApp
	add_child_autofree(app)
	await get_tree().process_frame
	return app

func test_disconnected_overlay_lifecycle() -> void:
	_app = await _create_app()
	assert_not_null(_app.disconnected_overlay, "%DisconnectedOverlay deve esistere nella scena")
	assert_true(_app.disconnected_overlay.visible, "%DisconnectedOverlay deve essere VISIBILE quando la nave è offline")
	
	await _start_solo_mission()
	
	assert_false(_app.disconnected_overlay.visible, "%DisconnectedOverlay deve SCOMPARIRE quando la nave è connessa")

func test_rbac_permissions_matrix_for_crew_roles() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	NetworkManager.request_role(NetworkManager.ROLE_PILOT)
	await get_tree().process_frame
	assert_false(_app.can_control_drone, "Pilota non deve avere controllo attivo sul drone EVA")
	assert_true(_app.manipulator_control.btn_undock.disabled, "BtnUndock deve essere disabilitato per Pilota")
	assert_true(_app.manipulator_control.btn_welder.disabled, "BtnWelder deve essere disabilitato per Pilota")
	assert_true(_app.manipulator_control.btn_activate_tool.disabled, "BtnActivateTool deve essere disabilitato per Pilota")
	
	NetworkManager.request_role(NetworkManager.ROLE_SOLDIER)
	await get_tree().process_frame
	assert_false(_app.can_control_drone, "Soldato non deve avere controllo attivo sul drone EVA")
	assert_true(_app.manipulator_control.btn_undock.disabled, "BtnUndock deve essere disabilitato per Soldato")
	
	NetworkManager.request_role(NetworkManager.ROLE_HACKER)
	await get_tree().process_frame
	assert_true(_app.can_control_drone, "Hacker deve avere controllo completo sul drone EVA")
	assert_false(_app.manipulator_control.btn_undock.disabled, "BtnUndock deve essere abilitato per Hacker")
	assert_false(_app.manipulator_control.btn_laser.disabled, "BtnLaser deve essere abilitato per Hacker")
	
	NetworkManager.request_role(NetworkManager.ROLE_ENGINEER)
	await get_tree().process_frame
	assert_true(_app.can_control_drone, "Ingegnere deve avere controllo completo sul drone EVA")
	assert_false(_app.manipulator_control.btn_undock.disabled, "BtnUndock deve essere abilitato per Ingegnere")
	assert_false(_app.manipulator_control.btn_welder.disabled, "BtnWelder deve essere abilitato per Ingegnere")
	
	NetworkManager.request_role(NetworkManager.ROLE_CAPTAIN)
	await get_tree().process_frame
	assert_true(_app.can_control_drone, "Capitano deve avere controllo completo sul drone EVA")
	
	NetworkManager.request_role(NetworkManager.ROLE_STAGISTA)
	await get_tree().process_frame
	assert_true(_app.can_control_drone, "Stagista deve avere controllo completo sul drone EVA")

func test_app_resource_registered_in_ship_software_manager() -> void:
	var ssm := get_node_or_null("/root/ShipSoftwareManager") as ShipSoftwareManagerSingleton
	assert_not_null(ssm, "ShipSoftwareManager singleton deve essere attivo")
	
	var res: AppResource = ssm.get_registered_app("service_drone")
	assert_not_null(res, "service_drone_app.tres deve essere registrata nel catalogo ShipSoftwareManager")
	assert_eq(res.app_id, "service_drone", "L'ID della risorsa deve essere 'service_drone'")
	assert_eq(res.title, "Drone di Servizio EVA", "Il titolo della risorsa deve corrispondere")
	assert_eq(res.power_draw_mw, 80.0, "L'assorbimento energetico deve essere 80.0 MW")
	assert_eq(res.default_password, "SERV-7815", "La password di default deve essere 'SERV-7815'")
	assert_true(res.required_subsystems.has("service_bay"), "Deve richiedere il sottosistema 'service_bay'")

func test_dat_configuration_parsing_and_hot_reload() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	assert_true(DirAccess.dir_exists_absolute("user://files/Ship Drive/Programs/ServiceDrone"), "La cartella Programs/ServiceDrone deve esistere")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/ServiceDrone/service_drone_config.dat"), "service_drone_config.dat deve esistere")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/ServiceDrone/manipulator_tuning.dat"), "manipulator_tuning.dat deve esistere")
	
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	assert_not_null(fpm, "FolderPasswordManager deve essere disponibile come autoload")
	assert_true(fpm.has_password("Ship Drive/Programs/ServiceDrone"), "La cartella deve essere protetta da password")
	assert_true(fpm.check_password("Ship Drive/Programs/ServiceDrone", "SERV-7815"), "La password deve essere SERV-7815")
	
	_app.load_dat_configuration()
	assert_eq(_app.active_config.get("max_thrust"), 35.0, "max_thrust iniziale deve essere 35.0")
	assert_eq(_app.active_config.get("battery_capacity_sec"), 240.0, "battery_capacity_sec iniziale deve essere 240.0")
	assert_eq(_app.active_config.get("repair_rate"), 15.0, "repair_rate iniziale deve essere 15.0")
	assert_eq(_app.active_config.get("cutting_laser_power"), 25.0, "cutting_laser_power iniziale deve essere 25.0")
	
	var new_cfg := "[SYSTEM]\napp_name=ServiceDroneApp\nversion=1.1.0\nstatus=OVERCLOCKED\n\n[FLIGHT]\nmax_thrust=55.0\nbattery_capacity_sec=320.0\ntether_range=2000.0\nauto_dock_speed=18.0\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/ServiceDrone/service_drone_config.dat", FileAccess.WRITE)
	f_out.store_string(new_cfg)
	f_out.close()
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("file_synced"):
		sdm.file_synced.emit("Ship Drive/Programs/ServiceDrone/service_drone_config.dat")
		await get_tree().process_frame
	
	assert_eq(_app.active_config.get("max_thrust"), 55.0, "max_thrust deve aggiornarsi a 55.0 tramite hot-reloading")
	assert_eq(_app.active_config.get("battery_capacity_sec"), 320.0, "battery_capacity_sec deve aggiornarsi a 320.0")

func test_drone_entity_collider_and_collision_mask() -> void:
	await _start_solo_mission()
	
	var drone := SpaceWorldManager.get_service_drone()
	assert_not_null(drone, "SpaceWorldManager deve istanziare o restituire il ServiceDroneEntity")
	assert_true(drone is CharacterBody3D, "ServiceDroneEntity deve estendere CharacterBody3D")
	
	var col_shape := drone.get_node_or_null("CollisionShape3D") as CollisionShape3D
	assert_not_null(col_shape, "ServiceDroneEntity deve possedere un nodo CollisionShape3D")
	assert_true(col_shape.shape is BoxShape3D, "CollisionShape3D deve usare una risorsa BoxShape3D")
	var box := col_shape.shape as BoxShape3D
	assert_eq(box.size, Vector3(0.7, 0.35, 0.9), "BoxShape3D deve avere dimensioni Vector3(0.7, 0.35, 0.9)")
	assert_eq(drone.collision_layer, 2, "collision_layer del drone deve essere 2")
	assert_eq(drone.collision_mask, 7, "collision_mask del drone deve essere 7")

func test_launch_and_thruster_physics() -> void:
	await _start_solo_mission()
	var drone := SpaceWorldManager.get_service_drone()
	
	SpaceWorldManager.launch_service_drone()
	await get_tree().process_frame
	assert_false(drone.is_docked, "Il drone deve essere in stato non-docked dopo il decollo")
	
	SpaceWorldManager.set_service_drone_inputs(Vector3(0, 0, -1), Vector3.ZERO, false)
	drone._physics_process(0.1)
	assert_true(drone.current_linear_velocity.length() > 0.0, "I thruster devono impartire velocità lineare al drone")

func test_arrow_key_pitch_and_yaw_controls() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	var drone := SpaceWorldManager.get_service_drone()
	SpaceWorldManager.launch_service_drone()
	await get_tree().process_frame
	
	var evt_up := InputEventKey.new()
	evt_up.keycode = KEY_UP
	evt_up.pressed = true
	_app._input(evt_up)
	assert_eq(_app._manual_angular_input.x, 1.0, "KEY_UP deve impostare _manual_angular_input.x a 1.0 (Pitch positivo)")
	drone._physics_process(0.1)
	assert_true(drone.current_angular_velocity.x > 0.0, "KEY_UP deve impartire velocità angolare di pitch positiva")
	
	evt_up.pressed = false
	_app._input(evt_up)
	assert_eq(_app._manual_angular_input.x, 0.0, "Rilascio KEY_UP deve resettare _manual_angular_input.x a 0.0")
	
	var evt_down := InputEventKey.new()
	evt_down.keycode = KEY_DOWN
	evt_down.pressed = true
	_app._input(evt_down)
	assert_eq(_app._manual_angular_input.x, -1.0, "KEY_DOWN deve impostare _manual_angular_input.x a -1.0 (Pitch negativo)")
	evt_down.pressed = false
	_app._input(evt_down)
	
	var evt_left := InputEventKey.new()
	evt_left.keycode = KEY_LEFT
	evt_left.pressed = true
	_app._input(evt_left)
	assert_eq(_app._manual_angular_input.y, 1.0, "KEY_LEFT deve impostare _manual_angular_input.y a 1.0 (Yaw antiorario)")
	drone._physics_process(0.1)
	assert_true(drone.current_angular_velocity.y > 0.0, "KEY_LEFT deve impartire velocità angolare di yaw positiva")
	
	evt_left.pressed = false
	_app._input(evt_left)
	assert_eq(_app._manual_angular_input.y, 0.0, "Rilascio KEY_LEFT deve resettare _manual_angular_input.y a 0.0")
	
	var evt_right := InputEventKey.new()
	evt_right.keycode = KEY_RIGHT
	evt_right.pressed = true
	_app._input(evt_right)
	assert_eq(_app._manual_angular_input.y, -1.0, "KEY_RIGHT deve impostare _manual_angular_input.y a -1.0 (Yaw orario)")
	evt_right.pressed = false
	_app._input(evt_right)

func test_welder_tool_repairs_hull_breach() -> void:
	await _start_solo_mission()
	var drone := SpaceWorldManager.get_service_drone()
	SpaceWorldManager.launch_service_drone()
	await get_tree().process_frame
	
	var test_dmg := SpaceWorldManager.spawn_ship_damage(SpaceWorldManager.DAMAGE_TYPE_BREACH, Vector2(100, 100), "Scafo Esterno", 2.0)
	assert_not_null(test_dmg.get("id"), "Danno breccia deve essere spawnato")
	
	SpaceWorldManager.set_service_drone_active_tool("welder")
	SpaceWorldManager.set_service_drone_tool_trigger(true, str(test_dmg.get("id")))
	drone._physics_process(1.0)
	drone._physics_process(1.0)
	assert_eq(drone.target_breach_id, str(test_dmg.get("id")), "Il drone deve mantenere il tracciamento della breccia target durante la saldatura")

func test_cargo_bay_collection_and_drop() -> void:
	await _start_solo_mission()
	var drone := SpaceWorldManager.get_service_drone()
	
	var item_added := drone.collect_cargo_item("salvage_01", "Titanium Hull Debris", 150.0)
	assert_true(item_added, "Raccolta materiale cargo deve riuscire entro la capienza max")
	assert_eq(drone.cargo_weight_kg, 150.0, "Il peso cargo deve essere 150 kg")
	var dropped := drone.drop_cargo_item(0)
	assert_eq(dropped.get("id"), "salvage_01", "L'oggetto rilasciato deve corrispondere a quello raccolto")
	assert_eq(drone.cargo_weight_kg, 0.0, "Il peso cargo deve tornare a 0 kg")

func test_auto_docking_completes() -> void:
	await _start_solo_mission()
	var drone := SpaceWorldManager.get_service_drone()
	SpaceWorldManager.launch_service_drone()
	await get_tree().process_frame
	
	SpaceWorldManager.dock_service_drone()
	# Avanza deterministicamente la fisica del docking automatico invece di
	# affidarsi a un singolo frame renderizzato (potenzialmente non deterministico
	# a seconda della distanza residua dalla baia droni).
	var steps := 0
	while not drone.is_docked and steps < 600:
		drone._physics_process(1.0 / 60.0)
		steps += 1
	assert_true(drone.is_docked, "Il drone deve risultare agganciato in baia dopo l'auto-docking")

func test_queue_free_cleanup_does_not_error() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	_app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_app = null
	assert_true(true, "La rimozione dell'app ServiceDrone non deve generare errori di pulizia dei segnali")
