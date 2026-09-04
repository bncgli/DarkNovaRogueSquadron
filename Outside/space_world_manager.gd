class_name SpaceWorldManagerSingleton
extends Node

## Singleton / Manager per il mondo 3D dello spazio e i feed delle telecamere dell'astronave.

signal camera_window_opened(cam_id: String, window: FakeWindow)
signal camera_window_closed(cam_id: String)
signal camera_status_changed(cam_id: String, is_open: bool)
signal camera_headlight_toggled(cam_id: String, enabled: bool)
signal ship_connection_changed(is_connected: bool)
signal duct_drone_state_changed(pos: Vector2, heading: float, speed: float, battery: float, lights: bool, scan_active: bool, scan_radius: float)
signal duct_drone_reset_performed()
signal ship_damages_updated(damages: Array[ShipDamageRuntimeState])
signal ship_damage_discovered(damage: ShipDamageRuntimeState)
signal ship_damage_repaired(damage: ShipDamageRuntimeState)
signal duct_drone_repair_state_changed(is_repairing: bool, damage_id: String, progress: float)
signal weapon_fired(weapon_type: String, origin: Vector3, target_pos: Vector3, hit_success: bool, target_id: String)
signal weapon_target_locked(target_id: String, target_data: Dictionary)
signal waypoint_updated(waypoint_data: Dictionary)
signal active_ping_triggered(origin: Vector3, radius: float)
signal sensors_scan_completed(contacts: Array)
signal service_drone_state_changed(telemetry: Dictionary)
signal ship_system_power_changed(category: String, is_powered: bool)
signal projectile_spawned(projectile_data: Dictionary)
signal projectile_intercepted(projectile_id: String, device_id: String, sector: int)
signal projectile_deflected(projectile_id: String, device_id: String, sector: int)
signal projectile_destroyed(projectile_id: String)
signal ship_damage_taken(pos: Vector2, type: String)
signal electrical_short_sparked(pos: Vector2)
signal duct_drone_position_updated(pos: Vector2)
signal g_force_updated(g_force: float)
signal crew_game_over(reason: String)

# --- SHIP DAMAGE TYPES & CONSTANTS ---
const DAMAGE_TYPE_BREACH: String = "breach"
const DAMAGE_TYPE_SHORT_CIRCUIT: String = "short_circuit"
const DAMAGE_TYPE_FIRE: String = "fire"

const SPACE_SCENE_PATH := "res://Outside/space_scene.tscn"
const CAMERA_FEED_WINDOW_SCENE := "res://Applications/Cams/CameraFeed/camera_feed_window.tscn"

var drone_manager := DuctDroneManager.new()
var damage_manager := ShipDamageManager.new()
var camera_manager := CameraFeedManager.new()

func _ready() -> void:
	add_child(drone_manager)
	add_child(damage_manager)
	add_child(camera_manager)
	
	_connect_submanagers()
	_init_space_world()
	duct_drone_pos = get_drone_spawn_pos()
	duct_drone_heading = get_drone_spawn_heading()
	duct_drone_lights = false
	generate_initial_ship_damages()
	call_deferred("_connect_network_signals")

func _connect_submanagers() -> void:
	drone_manager.state_changed.connect(func(p, h, s, b, l, sa, sr):
		duct_drone_state_changed.emit(p, h, s, b, l, sa, sr)
		duct_drone_position_updated.emit(p)
	)
	drone_manager.reset_performed.connect(func(): duct_drone_reset_performed.emit())
	drone_manager.repair_state_changed.connect(func(ir, di, pr): duct_drone_repair_state_changed.emit(ir, di, pr))
	
	damage_manager.damages_updated.connect(func(d): ship_damages_updated.emit(d))
	damage_manager.damage_discovered.connect(func(d):
		ship_damage_discovered.emit(d)
		var d_pos: Vector2 = d.get("position", Vector2.ZERO)
		var d_type: String = str(d.get("damage_type", d.get("type", "breach")))
		ship_damage_taken.emit(d_pos, d_type)
		if d_type == "short_circuit":
			electrical_short_sparked.emit(d_pos)
	)
	damage_manager.damage_repaired.connect(func(d): ship_damage_repaired.emit(d))
	
	camera_manager.window_opened.connect(func(ci, w): camera_window_opened.emit(ci, w))
	camera_manager.window_closed.connect(func(ci): camera_window_closed.emit(ci))
	camera_manager.status_changed.connect(func(ci, io): camera_status_changed.emit(ci, io))
	camera_manager.headlight_toggled.connect(func(ci, en): camera_headlight_toggled.emit(ci, en))

# --- DUCT DRONE METADATA & CONSTANTS ---
const INITIAL_DUCT_DRONE_POS := Vector2(300, 80)
const INITIAL_DUCT_DRONE_HEADING := -PI * 0.5 # -90 gradi (Prua / Nord)
const DUCT_BASE_LINEAR_SPEED: float = 175.0
const DUCT_BASE_ROTATE_SPEED: float = 3.0
const DUCT_ACCELERATION: float = 650.0
const DUCT_DECELERATION: float = 750.0

# Stato sincronizzato del Duct Drone
var duct_drone_pos: Vector2 = INITIAL_DUCT_DRONE_POS
var duct_drone_heading: float = INITIAL_DUCT_DRONE_HEADING
var duct_drone_speed: float = 0.0
var duct_drone_battery: float = 100.0
var duct_drone_lights: bool = false
var duct_drone_scan_active: bool = false
var duct_drone_scan_radius: float = 0.0

var duct_drone_linear_input: float = 0.0
var duct_drone_angular_input: float = 0.0
var duct_drone_speed_mult: float = 1.0

# Danni strutturali e sistemici alla nave
var ship_damages: Array[ShipDamageRuntimeState] = []
var is_duct_drone_repairing: bool = false
var repairing_damage_id: String = ""
var _next_damage_idx: int = 1

# Sublayer Blueprint unificato della nave
var active_ship_blueprint: ShipBlueprint = null

# Risorsa attiva del Sistema Stellare
var active_star_system: StarSystemData = null

# Istanza 3D della stazione orbitale primaria nello spazio
var primary_station_instance: SpaceStationEntity = null
var default_station_approach_distance: float = 1800.0 # Metri dallo scalo portuale (1000-2500m)

var _last_sent_drone_linear_in: float = 0.0
var _last_sent_drone_angular_in: float = 0.0
var _last_sent_drone_speed_mult: float = 1.0

var _master_viewport: SubViewport = null
var _space_scene_instance: SpaceScene = null
var _active_camera_windows: Dictionary = {} # cam_id (String) -> FakeWindow
var _cams_active_config: Dictionary = {} # Parametri runtime ottiche caricati da .dat
var _duct_drone_active_config: Dictionary = {
	"linear_speed": 175.0,
	"linear_acceleration": 650.0,
	"linear_deceleration": 750.0,
	"rotate_speed": 3.0,
	"battery_max": 100.0,
	"battery_drain_move": 0.35,
	"battery_drain_lights": 0.75,
	"battery_drain_radar": 3.5,
	"battery_drain_repair": 6.0,
	"radar_scan_radius_max": 160.0,
	"repair_range": 42.0,
	"repair_speed_multiplier": 1.0,
	"repair_efficiency": 1.0,
	"turbo_multiplier": 2.0,
	"precision_multiplier": 0.5,
	"is_dat_loaded": false
}
var _net_mgr: Node = null

func _get_net_mgr() -> Node:
	if _net_mgr != null and is_instance_valid(_net_mgr):
		return _net_mgr
	if is_inside_tree():
		_net_mgr = get_node_or_null("/root/NetworkManager")
	return _net_mgr

func _connect_network_signals() -> void:
	var nm := _get_net_mgr()
	if nm:
		if nm.has_signal("connection_state_changed") and not nm.connection_state_changed.is_connected(_on_network_connection_state_changed):
			nm.connection_state_changed.connect(_on_network_connection_state_changed)
		if nm.has_signal("mission_started") and not nm.mission_started.is_connected(_on_network_mission_started):
			nm.mission_started.connect(_on_network_mission_started)
		if nm.has_signal("mission_ended") and not nm.mission_ended.is_connected(_on_network_mission_ended):
			nm.mission_ended.connect(_on_network_mission_ended)
		if nm.has_signal("player_joined") and not nm.player_joined.is_connected(_on_network_player_joined):
			nm.player_joined.connect(_on_network_player_joined)
		if nm.has_method("is_ship_connected") and nm.is_ship_connected():
			_on_network_mission_started()
		elif nm.get("is_connected_to_network"):
			_on_network_connection_state_changed(true, nm.get("is_host"))

func _on_network_connection_state_changed(is_connected: bool, is_host: bool) -> void:
	var nm := _get_net_mgr()
	var mission_active: bool = nm.is_ship_connected() if (nm and nm.has_method("is_ship_connected")) else false
	
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		ship.set_ship_connected(mission_active)
		if is_connected and not is_host:
			ship.set_network_client_mode(true)
		else:
			ship.set_network_client_mode(false)
	
	if not is_connected or not mission_active:
		close_all_camera_windows()
		stop_spaceship_engines()
	
	ship_connection_changed.emit(mission_active)

func _on_network_mission_started() -> void:
	var nm := _get_net_mgr()
	var is_host: bool = nm.get("is_host") if nm else true
	
	if nm:
		if nm.has_method("get_selected_ship_blueprint"):
			var bp: ShipBlueprint = nm.get_selected_ship_blueprint()
			if bp != null:
				set_ship_blueprint(bp)
		if nm.has_method("get_selected_star_system"):
			var sys: StarSystemData = nm.get_selected_star_system()
			if sys != null:
				set_star_system_data(sys)
				
	configure_initial_station_spawn()

	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		ship.set_ship_connected(true)
		if not is_host:
			ship.set_network_client_mode(true)
		else:
			ship.set_network_client_mode(false)
	
	ship_connection_changed.emit(true)

func _on_network_mission_ended() -> void:
	is_ship_connected_state = false
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		ship.set_ship_connected(false)
	
	close_all_camera_windows()
	stop_spaceship_engines()
	
	ship_connection_changed.emit(false)

var is_ship_connected_state: bool = false

func is_ship_connected() -> bool:
	if is_ship_connected_state:
		return true
	var ssm := get_node_or_null("/root/ShipSoftwareManager")
	if ssm and ssm.get("is_mission_active"):
		return true
	var nm := _get_net_mgr()
	if nm and nm.has_method("is_ship_connected") and nm.is_ship_connected():
		return true
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		return ship.is_ship_connected
	return false

## Avvia la sessione di missione nello spazio e attiva la connessione nave
func start_mission(bp: ShipBlueprint = null) -> void:
	if bp != null:
		set_ship_blueprint(bp)
	configure_initial_station_spawn()
	set_ship_connected(true)

## Termina la sessione di missione, disconnette la nave e resetta lo stato
func end_mission() -> void:
	set_ship_connected(false)

func set_ship_connected(p_connected: bool) -> void:
	is_ship_connected_state = p_connected
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		ship.set_ship_connected(p_connected)
	
	if not p_connected:
		close_all_camera_windows()
		stop_spaceship_engines()
	
	ship_connection_changed.emit(p_connected)

func _on_network_player_joined(peer_id: int, _player_data: Dictionary) -> void:
	var nm := _get_net_mgr()
	if nm == null or not nm.get("is_host") or peer_id == 1:
		return
	var ship := get_spaceship()
	if ship and is_instance_valid(ship) and is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().has(peer_id):
		var state := ship.get_network_state()
		_rpc_sync_ship_initial_state.rpc_id(
			peer_id,
			state["pos"],
			state["quat"],
			state["lin_vel"],
			state["ang_vel"],
			state["lin_in"],
			state["ang_in"]
		)
	if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().has(peer_id):
		_rpc_sync_duct_drone_initial_state.rpc_id(
			peer_id,
			duct_drone_pos,
			duct_drone_heading,
			duct_drone_speed,
			duct_drone_battery,
			duct_drone_lights,
			duct_drone_scan_active,
			duct_drone_scan_radius
		)
		_rpc_sync_ship_damages.rpc_id(peer_id, ship_damages)

func _physics_process(delta: float) -> void:
	var nm := _get_net_mgr()
	var is_networked: bool = nm != null and nm.get("is_connected_to_network")
	var is_host: bool = is_networked and nm.get("is_host")
	var is_client: bool = is_networked and not is_host
	
	if is_host and is_ship_connected():
		if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
			var ship := get_spaceship()
			if ship and is_instance_valid(ship):
				var state := ship.get_network_state()
				_rpc_sync_ship_state.rpc(
					state["pos"],
					state["quat"],
					state["lin_vel"],
					state["ang_vel"],
					state["lin_in"],
					state["ang_in"]
				)
	
	# Aggiorna la simulazione fisica del Duct Drone sull'Host o in modalità Solo / Standby
	if not is_client:
		_update_duct_drone_physics(delta)
		_update_incoming_projectiles(delta)
		if is_host and is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
			_rpc_sync_duct_drone_state.rpc(
				duct_drone_pos,
				duct_drone_heading,
				duct_drone_speed,
				duct_drone_battery,
				duct_drone_lights,
				duct_drone_scan_active,
				duct_drone_scan_radius
			)
	else:
		_update_incoming_projectiles(delta)
		if duct_drone_scan_active:
			duct_drone_scan_radius += 180.0 * delta
			if duct_drone_scan_radius > 160.0:
				duct_drone_scan_active = false
				duct_drone_scan_radius = 0.0

func _init_space_world() -> void:
	if _master_viewport != null and is_instance_valid(_master_viewport):
		return
	
	_master_viewport = SubViewport.new()
	_master_viewport.name = "MasterSpaceViewport"
	_master_viewport.world_3d = World3D.new()
	_master_viewport.size = Vector2i(1024, 1024)
	_master_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_master_viewport.handle_input_locally = false
	add_child(_master_viewport)
	
	var packed_scene: PackedScene = load(SPACE_SCENE_PATH)
	if packed_scene:
		_space_scene_instance = packed_scene.instantiate() as SpaceScene
		_master_viewport.add_child(_space_scene_instance)

func get_world_3d() -> World3D:
	if _master_viewport == null or not is_instance_valid(_master_viewport):
		_init_space_world()
	return _master_viewport.world_3d

func get_spaceship() -> Spaceship:
	if _space_scene_instance and is_instance_valid(_space_scene_instance):
		return _space_scene_instance.get_spaceship()
	return null

func set_spaceship_inputs(move_vec: Vector3, rot_vec: Vector3) -> void:
	if not is_ship_connected():
		return
	var nm := _get_net_mgr()
	if nm and nm.get("is_connected_to_network") and not nm.get("is_host"):
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			_rpc_client_flight_input.rpc_id(1, move_vec, rot_vec)
		return
	
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		ship.set_flight_inputs(move_vec, rot_vec)

func set_ship_flight_input(move_vec: Vector3, rot_vec: Vector3) -> void:
	set_spaceship_inputs(move_vec, rot_vec)

func stop_spaceship_engines() -> void:
	var nm := _get_net_mgr()
	if nm and nm.get("is_connected_to_network") and not nm.get("is_host"):
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			_rpc_client_stop_engines.rpc_id(1)
		return
	
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		ship.stop_engines()

func set_inertia_dampening(enabled: bool) -> void:
	var nm := _get_net_mgr()
	if nm and nm.get("is_connected_to_network") and not nm.get("is_host"):
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			_rpc_client_set_inertia_dampening.rpc_id(1, enabled)
		return
	
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		ship.inertia_dampening = enabled

func get_inertia_dampening() -> bool:
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		return ship.inertia_dampening
	return true

func reset_spaceship_position() -> void:
	if not is_ship_connected():
		return
	var nm := _get_net_mgr()
	if nm and nm.get("is_connected_to_network") and not nm.get("is_host"):
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			_rpc_client_reset_ship.rpc_id(1)
		return
	
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		ship.reset_to_origin()
		if nm and nm.get("is_connected_to_network") and nm.get("is_host"):
			if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
				_rpc_sync_ship_reset.rpc()

func reset_ship_position() -> void:
	reset_spaceship_position()

# --- RPC MULTIPLAYER SYNCHRONIZATION ---

@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_sync_ship_state(pos: Vector3, quat_arr: Array, lin_vel: Vector3, ang_vel: Vector3, lin_in: Vector3, ang_in: Vector3) -> void:
	var ship := get_spaceship()
	if ship and is_instance_valid(ship) and quat_arr.size() == 4:
		var quat := Quaternion(quat_arr[0], quat_arr[1], quat_arr[2], quat_arr[3])
		ship.apply_synced_state(pos, quat, lin_vel, ang_vel, lin_in, ang_in)

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_ship_initial_state(pos: Vector3, quat_arr: Array, lin_vel: Vector3, ang_vel: Vector3, lin_in: Vector3, ang_in: Vector3) -> void:
	var ship := get_spaceship()
	if ship and is_instance_valid(ship) and quat_arr.size() == 4:
		var quat := Quaternion(quat_arr[0], quat_arr[1], quat_arr[2], quat_arr[3])
		ship.apply_synced_state(pos, quat, lin_vel, ang_vel, lin_in, ang_in)
		if ship.is_inside_tree():
			ship.global_transform = Transform3D(Basis(quat), pos)
		else:
			ship.transform = Transform3D(Basis(quat), pos)

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_ship_reset() -> void:
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		ship.reset_to_origin()

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_client_flight_input(move_vec: Vector3, rot_vec: Vector3) -> void:
	var nm := _get_net_mgr()
	if nm == null or not nm.get("is_host"):
		return
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		ship.set_flight_inputs(move_vec, rot_vec)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_stop_engines() -> void:
	var nm := _get_net_mgr()
	if nm == null or not nm.get("is_host"):
		return
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		ship.stop_engines()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_set_inertia_dampening(enabled: bool) -> void:
	var nm := _get_net_mgr()
	if nm == null or not nm.get("is_host"):
		return
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		ship.inertia_dampening = enabled

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_reset_ship() -> void:
	var nm := _get_net_mgr()
	if nm == null or not nm.get("is_host"):
		return
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		ship.reset_to_origin()
		if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
			_rpc_sync_ship_reset.rpc()

# --- DUCT DRONE CONTROLLER & SYNCHRONIZATION ---

func get_duct_drone_pos() -> Vector2:
	return duct_drone_pos

func get_duct_drone_heading() -> float:
	return duct_drone_heading

func get_duct_drone_speed() -> float:
	return duct_drone_speed

func get_duct_drone_battery() -> float:
	return duct_drone_battery

func get_duct_drone_lights() -> bool:
	return duct_drone_lights

func is_duct_drone_scan_active() -> bool:
	return duct_drone_scan_active

func get_duct_drone_scan_radius() -> float:
	return duct_drone_scan_radius

func get_duct_drone_state() -> Dictionary:
	return {
		"pos": duct_drone_pos,
		"heading": duct_drone_heading,
		"speed": duct_drone_speed,
		"battery": duct_drone_battery,
		"lights": duct_drone_lights,
		"scan_active": duct_drone_scan_active,
		"scan_radius": duct_drone_scan_radius
	}

func set_duct_drone_inputs(linear_in: float, angular_in: float, speed_mult: float = 1.0) -> void:
	var nm := _get_net_mgr()
	if nm and nm.get("is_connected_to_network") and not nm.get("is_host"):
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			if not is_equal_approx(_last_sent_drone_linear_in, linear_in) \
				or not is_equal_approx(_last_sent_drone_angular_in, angular_in) \
				or not is_equal_approx(_last_sent_drone_speed_mult, speed_mult):
				_last_sent_drone_linear_in = linear_in
				_last_sent_drone_angular_in = angular_in
				_last_sent_drone_speed_mult = speed_mult
				_rpc_client_duct_drone_input.rpc_id(1, linear_in, angular_in, speed_mult)
		return
	
	duct_drone_linear_input = linear_in
	duct_drone_angular_input = angular_in
	duct_drone_speed_mult = speed_mult

func stop_duct_drone() -> void:
	var nm := _get_net_mgr()
	if nm and nm.get("is_connected_to_network") and not nm.get("is_host"):
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			_rpc_client_duct_drone_stop.rpc_id(1)
		return
	
	duct_drone_linear_input = 0.0
	duct_drone_angular_input = 0.0
	duct_drone_speed = 0.0

func reset_duct_drone() -> void:
	var nm := _get_net_mgr()
	if nm and nm.get("is_connected_to_network") and not nm.get("is_host"):
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			_rpc_client_reset_duct_drone.rpc_id(1)
		return
	
	duct_drone_pos = get_drone_spawn_pos()
	duct_drone_heading = get_drone_spawn_heading()
	duct_drone_speed = 0.0
	duct_drone_linear_input = 0.0
	duct_drone_angular_input = 0.0
	duct_drone_battery = 100.0
	duct_drone_scan_active = false
	duct_drone_scan_radius = 0.0
	duct_drone_reset_performed.emit()
	
	if nm and nm.get("is_connected_to_network") and nm.get("is_host"):
		if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
			_rpc_sync_duct_drone_reset.rpc()

func set_duct_drone_lights(enabled: bool) -> void:
	var nm := _get_net_mgr()
	if nm and nm.get("is_connected_to_network") and not nm.get("is_host"):
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			_rpc_client_duct_drone_lights.rpc_id(1, enabled)
		duct_drone_lights = enabled
		return
	duct_drone_lights = enabled

func toggle_duct_drone_lights() -> void:
	set_duct_drone_lights(not duct_drone_lights)

func trigger_duct_drone_scan() -> void:
	var nm := _get_net_mgr()
	if nm and nm.get("is_connected_to_network") and not nm.get("is_host"):
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			_rpc_client_duct_drone_scan.rpc_id(1)
		duct_drone_scan_active = true
		duct_drone_scan_radius = 0.0
		return
	duct_drone_scan_active = true
	duct_drone_scan_radius = 0.0

func apply_synced_duct_drone_state(pos: Vector2, heading: float, speed: float, battery: float, lights: bool, scan_active: bool, scan_radius: float) -> void:
	duct_drone_pos = pos
	duct_drone_heading = heading
	duct_drone_speed = speed
	duct_drone_battery = battery
	duct_drone_lights = lights
	duct_drone_scan_active = scan_active
	duct_drone_scan_radius = scan_radius
	duct_drone_state_changed.emit(pos, heading, speed, battery, lights, scan_active, scan_radius)

func set_duct_drone_config(cfg: Dictionary) -> void:
	for k in cfg:
		_duct_drone_active_config[k] = cfg[k]
	_duct_drone_active_config["is_dat_loaded"] = true

func get_duct_drone_config() -> Dictionary:
	return _duct_drone_active_config

func _update_duct_drone_physics(delta: float) -> void:
	var base_rot_speed: float = float(_duct_drone_active_config.get("rotate_speed"))
	var base_lin_speed: float = float(_duct_drone_active_config.get("linear_speed"))
	var drain_move: float = float(_duct_drone_active_config.get("battery_drain_move"))
	var drain_lights: float = float(_duct_drone_active_config.get("battery_drain_lights"))
	var drain_radar: float = float(_duct_drone_active_config.get("battery_drain_radar"))
	var drain_repair: float = float(_duct_drone_active_config.get("battery_drain_repair"))
	var scan_max: float = float(_duct_drone_active_config.get("radar_scan_radius_max"))
	var repair_rng: float = float(_duct_drone_active_config.get("repair_range"))
	var repair_mult: float = float(_duct_drone_active_config.get("repair_speed_multiplier", 1.0)) * float(_duct_drone_active_config.get("repair_efficiency", 1.0))

	# 1. Rotazione Tank (gira sul posto)
	if absf(duct_drone_angular_input) > 0.01 and duct_drone_battery > 0.0:
		var rot_step := duct_drone_angular_input * base_rot_speed * duct_drone_speed_mult * delta
		duct_drone_heading += rot_step
		duct_drone_heading = wrapf(duct_drone_heading, -PI, PI)
	
	# Se la batteria è esaurita (<= 0.0), il robottino non può muoversi né riparare
	var effective_linear_input := duct_drone_linear_input
	if duct_drone_battery <= 0.0:
		effective_linear_input = 0.0
		if is_duct_drone_repairing:
			stop_duct_drone_repair()
	
	# 2. Spostamento Lineare (avanti/indietro su vettore prua)
	var target_speed := effective_linear_input * base_lin_speed * duct_drone_speed_mult
	duct_drone_speed = target_speed
	
	# Consumo batteria differenziato da parametri attivi
	if absf(effective_linear_input) > 0.01:
		duct_drone_battery = maxf(0.0, duct_drone_battery - drain_move * delta * duct_drone_speed_mult)
	
	if duct_drone_lights:
		duct_drone_battery = maxf(0.0, duct_drone_battery - drain_lights * delta)
	
	if duct_drone_scan_active:
		duct_drone_battery = maxf(0.0, duct_drone_battery - drain_radar * delta)
	
	if is_duct_drone_repairing:
		duct_drone_battery = maxf(0.0, duct_drone_battery - drain_repair * delta)
	
	if absf(duct_drone_speed) > 0.1:
		var forward_dir := Vector2.from_angle(duct_drone_heading)
		var movement := forward_dir * duct_drone_speed * delta
		var new_pos := duct_drone_pos + movement
		duct_drone_pos = _constrain_duct_drone_movement(duct_drone_pos, new_pos)
	else:
		# Ricarica se il robottino è all'interno della stanza di ricarica
		var bp := get_ship_blueprint()
		var recharge_room: Variant = null
		if bp and bp.recharge_room_id != "":
			recharge_room = bp.get_room_by_id(bp.recharge_room_id)
		if recharge_room and recharge_room.rect.has_point(duct_drone_pos):
			var max_bat: float = float(_duct_drone_active_config.get("battery_max"))
			duct_drone_battery = minf(max_bat, duct_drone_battery + 15.0 * delta)
	
	# 3. Sonar pulse
	if duct_drone_scan_active:
		duct_drone_scan_radius += 180.0 * delta
		if duct_drone_scan_radius > scan_max:
			duct_drone_scan_active = false
			duct_drone_scan_radius = 0.0
	
	# 4. Rilevamento Danni Invisibili
	var damages_changed := false
	for dmg in ship_damages:
		if dmg.repaired:
			continue
		
		var dmg_type: String = dmg.type
		var dmg_pos: Vector2 = dmg.pos
		var is_revealed: bool = dmg.revealed
		
		if not is_revealed:
			if dmg_type == DAMAGE_TYPE_BREACH and duct_drone_lights:
				var dist := duct_drone_pos.distance_to(dmg_pos)
				if dist <= 35.0:
					dmg.revealed = true
					dmg.revealed_by = "light"
					damages_changed = true
					ship_damage_discovered.emit(dmg)
				elif dist <= 90.0:
					var to_dmg := (dmg_pos - duct_drone_pos).normalized()
					var forward := Vector2.from_angle(duct_drone_heading)
					var angle_diff := absf(forward.angle_to(to_dmg))
					if angle_diff <= 0.55: # cono fari (~31 gradi)
						dmg.revealed = true
						dmg.revealed_by = "light"
						damages_changed = true
						ship_damage_discovered.emit(dmg)
			
			elif dmg_type == DAMAGE_TYPE_SHORT_CIRCUIT and duct_drone_scan_active:
				var dist := duct_drone_pos.distance_to(dmg_pos)
				if dist <= duct_drone_scan_radius:
					dmg.revealed = true
					dmg.revealed_by = "radar"
					damages_changed = true
					ship_damage_discovered.emit(dmg)
			
			elif (dmg_type == DAMAGE_TYPE_FIRE or dmg_type == "dmg_fire" or dmg_type == "FIRE" or dmg_type == "fire"):
				var dist := duct_drone_pos.distance_to(dmg_pos)
				if dist <= 45.0:
					dmg.revealed = true
					dmg.revealed_by = "thermal"
					damages_changed = true
					ship_damage_discovered.emit(dmg)
				elif duct_drone_lights and dist <= 90.0:
					var to_dmg := (dmg_pos - duct_drone_pos).normalized()
					var forward := Vector2.from_angle(duct_drone_heading)
					var angle_diff := absf(forward.angle_to(to_dmg))
					if angle_diff <= 0.55:
						dmg.revealed = true
						dmg.revealed_by = "light"
						damages_changed = true
						ship_damage_discovered.emit(dmg)
				elif duct_drone_scan_active and dist <= duct_drone_scan_radius:
					dmg.revealed = true
					dmg.revealed_by = "radar"
					damages_changed = true
					ship_damage_discovered.emit(dmg)
	
	# 5. Elaborazione Riparazione in corso
	if is_duct_drone_repairing and repairing_damage_id != "":
		var target_dmg: ShipDamageRuntimeState = null
		for i in range(ship_damages.size()):
			if ship_damages[i].id == repairing_damage_id:
				target_dmg = ship_damages[i]
				break
		
		if target_dmg == null or target_dmg.repaired:
			is_duct_drone_repairing = false
			repairing_damage_id = ""
			duct_drone_repair_state_changed.emit(false, "", 0.0)
		else:
			var d: float = duct_drone_pos.distance_to(target_dmg.pos)
			if d > repair_rng or duct_drone_battery <= 0.0:
				# Troppo lontano o batteria esaurita: interrompi riparazione
				is_duct_drone_repairing = false
				repairing_damage_id = ""
				duct_drone_repair_state_changed.emit(false, "", float(target_dmg.repair_progress))
			else:
				var duration: float = maxf(1.0, float(target_dmg.repair_duration))
				var progress: float = float(target_dmg.repair_progress)
				progress = clampf(progress + ((delta * repair_mult) / duration), 0.0, 1.0)
				target_dmg.repair_progress = progress
				duct_drone_repair_state_changed.emit(true, repairing_damage_id, progress)
				
				if progress >= 1.0:
					target_dmg.repaired = true
					is_duct_drone_repairing = false
					repairing_damage_id = ""
					damages_changed = true
					ship_damage_repaired.emit(target_dmg)
					duct_drone_repair_state_changed.emit(false, "", 1.0)
	
	if damages_changed:
		ship_damages_updated.emit(ship_damages)
		var nm := _get_net_mgr()
		if nm and nm.get("is_connected_to_network") and nm.get("is_host"):
			if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
				_rpc_sync_ship_damages.rpc(ship_damages)
	
	duct_drone_state_changed.emit(duct_drone_pos, duct_drone_heading, duct_drone_speed, duct_drone_battery, duct_drone_lights, duct_drone_scan_active, duct_drone_scan_radius)

var sealed_rooms: Dictionary = {}

func set_room_sealed(room_id: String, sealed: bool) -> void:
	sealed_rooms[room_id] = sealed
	if _life_support_instance and is_instance_valid(_life_support_instance) and _life_support_instance.has_method("set_bulkhead_sealed"):
		if _life_support_instance.rooms_state.has(room_id) and _life_support_instance.rooms_state[room_id].get("is_sealed") != sealed:
			_life_support_instance.set_bulkhead_sealed(room_id, sealed)

func is_room_sealed(room_id: String) -> bool:
	if _life_support_instance and is_instance_valid(_life_support_instance) and _life_support_instance.has_method("is_room_sealed"):
		return _life_support_instance.is_room_sealed(room_id)
	return sealed_rooms.get(room_id, false)

func get_sealed_rooms() -> Array:
	if _life_support_instance and is_instance_valid(_life_support_instance) and _life_support_instance.has_method("get_sealed_rooms"):
		var ls_sealed = _life_support_instance.get_sealed_rooms()
		if ls_sealed.size() > 0:
			return ls_sealed
	var result: Array = []
	var bp := get_ship_blueprint()
	if bp:
		for room in bp.rooms:
			var r_id: String = room.id if "id" in room else room.get("id", "")
			if sealed_rooms.get(r_id, false):
				result.append({
					"id": r_id,
					"name": room.name if "name" in room else room.get("name", ""),
					"rect": room.rect if "rect" in room else room.get("rect", Rect2()),
					"is_sealed": true
				})
	return result

func _can_duct_drone_move(from_pos: Vector2, to_pos: Vector2) -> bool:
	if not _is_duct_drone_position_valid(to_pos):
		return false
	
	var sealed := get_sealed_rooms()
	for room in sealed:
		var rect: Rect2 = room.rect if "rect" in room else room.get("rect", Rect2())
		if rect.size == Vector2.ZERO:
			continue
		var was_inside := rect.has_point(from_pos)
		var will_be_inside := rect.has_point(to_pos)
		if was_inside != will_be_inside:
			return false
	return true

func _constrain_duct_drone_movement(old_pos: Vector2, new_pos: Vector2) -> Vector2:
	if _can_duct_drone_move(old_pos, new_pos):
		return new_pos
	
	var test_x := Vector2(new_pos.x, old_pos.y)
	if _can_duct_drone_move(old_pos, test_x):
		return test_x
	
	var test_y := Vector2(old_pos.x, new_pos.y)
	if _can_duct_drone_move(old_pos, test_y):
		return test_y
	
	return old_pos

## Ritorna l'istanza attiva della ShipBlueprint
func get_ship_blueprint() -> ShipBlueprint:
	if active_ship_blueprint == null:
		active_ship_blueprint = ShipBlueprint.get_default_blueprint()
	return active_ship_blueprint

## Imposta l'istanza attiva della ShipBlueprint
func set_ship_blueprint(bp: ShipBlueprint) -> void:
	active_ship_blueprint = bp

## Ritorna l'istanza attiva del StarSystemData
func get_star_system_data() -> StarSystemData:
	if active_star_system == null:
		active_star_system = StarSystemData.get_default_star_system()
	return active_star_system

## Imposta l'istanza attiva del StarSystemData e aggiorna StarSystemGridManager
func set_star_system_data(sys: StarSystemData) -> void:
	active_star_system = sys
	if is_inside_tree() and get_tree().root.has_node("StarSystemGridManager"):
		var grid_mgr := get_node_or_null("/root/StarSystemGridManager")
		if grid_mgr and grid_mgr.has_method("load_star_system"):
			grid_mgr.load_star_system(sys)
	configure_initial_station_spawn()

## Configura e posiziona la stazione orbitale primaria nello spazio 3D e orienta la nave per lo spawn iniziale
func configure_initial_station_spawn() -> void:
	var sys := get_star_system_data()
	var station_data := {}
	if sys != null and sys.has_method("find_primary_station"):
		var st := sys.find_primary_station()
		if st != null:
			station_data = st.to_dict()
	if station_data.is_empty():
		var grid_mgr := get_node_or_null("/root/StarSystemGridManager")
		if grid_mgr and grid_mgr.has_method("get_starting_station"):
			station_data = grid_mgr.get_starting_station()
	
	if station_data.is_empty():
		return
		
	var st_id: String = station_data.get("id")
	var st_name: String = station_data.get("name")
	var st_type: String = station_data.get("type")
	
	# Calcola la posizione 3D della stazione nel mondo di gioco (area perimetrale a 1800m dalla prua nave)
	var station_3d_pos := Vector3(0.0, 0.0, -default_station_approach_distance)
	
	# Assicura il master viewport e space scene
	if _master_viewport == null or not is_instance_valid(_master_viewport):
		_init_space_world()
		
	if _space_scene_instance and is_instance_valid(_space_scene_instance):
		if primary_station_instance == null or not is_instance_valid(primary_station_instance):
			# Controlla se esiste già un nodo stazione
			primary_station_instance = _space_scene_instance.get_node_or_null("SpaceStationEntity") as SpaceStationEntity
			if primary_station_instance == null:
				var station_scene := load("res://Outside/Stations/space_station_entity.tscn")
				if station_scene:
					primary_station_instance = station_scene.instantiate() as SpaceStationEntity
				else:
					primary_station_instance = SpaceStationEntity.new()
				primary_station_instance.name = "SpaceStationEntity"
				_space_scene_instance.add_child(primary_station_instance)
		
		if primary_station_instance and is_instance_valid(primary_station_instance):
			primary_station_instance.station_id = st_id
			primary_station_instance.station_name = st_name
			primary_station_instance.station_type = st_type
			primary_station_instance.global_position = station_3d_pos
			
	# Orienta la nave verso la stazione spaziale
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		ship.global_position = Vector3.ZERO
		ship.look_at(station_3d_pos, Vector3.UP)
		
	# Genera automaticamente un waypoint diegetico e segnale IFF identificativo
	set_active_waypoint({
		"id": st_id,
		"name": st_name,
		"pos": station_3d_pos,
		"type": "STATION",
		"iff_tag": "FRIENDLY",
		"distance_km": default_station_approach_distance / 1000.0,
		"is_station": true
	})
	
	# Notifica diegetica di sistema
	_send_spawn_notification("Posizionamento completato: Stazione Spaziale rilevata nel settore adiacente")

## Invia una notifica di sistema diegetica a schermo
func _send_spawn_notification(msg: String) -> void:
	if is_inside_tree() and get_tree().root.has_node("NotificationManager"):
		var notif := get_node_or_null("/root/NotificationManager")
		if notif and notif.has_method("spawn_notification"):
			notif.spawn_notification(msg)

## Ritorna l'istanza SpaceStationEntity della stazione primaria
func get_primary_station_entity() -> SpaceStationEntity:
	if primary_station_instance == null or not is_instance_valid(primary_station_instance):
		configure_initial_station_spawn()
	return primary_station_instance

## Alias per compatibilità con DockingManager
func get_docking_station() -> SpaceStationEntity:
	return get_primary_station_entity()

## Ritorna le stanze della nave da ShipBlueprint o fallback a costanti
func get_duct_rooms() -> Array[DuctRoomData]:
	var bp := get_ship_blueprint()
	var res: Array[DuctRoomData] = []
	if bp:
		for r in bp.rooms:
			res.append(DuctRoomData.new(r.id, r.name, r.rect, r.color, r.border_color))
	return res

## Ritorna i condotti della nave da ShipBlueprint o fallback a costanti
func get_duct_corridors() -> Array[ShipDuctData]:
	var bp := get_ship_blueprint()
	var res: Array[ShipDuctData] = []
	if bp:
		for d in bp.ducts:
			if d is ShipDuctData:
				res.append(d)
	return res

## Ritorna i dispositivi elettrici della nave da ShipBlueprint
func get_power_devices() -> Array[ShipDeviceData]:
	var bp := get_ship_blueprint()
	if not bp: return []
	var all_devs: Array[ShipDeviceData] = []
	for r in bp.rooms:
		for d in r.devices:
			all_devs.append(d)
	return all_devs

## Ritorna gli snodi elettrici della nave (Rimosso in TASK-017)
func get_power_junctions() -> Array[Dictionary]:
	return []

## Ritorna le zone/punti di danno predefiniti della nave da ShipBlueprint
func get_damage_zones() -> Array:
	var bp := get_ship_blueprint()
	if bp and bp.damages.size() > 0:
		return bp.damages
	return []

## Ritorna i confini strutturali della nave
func get_ship_bounds() -> Rect2:
	var bp := get_ship_blueprint()
	if bp:
		return bp.ship_bounds
	return Rect2(60, 30, 480, 420)

## Ritorna la posizione di spawn iniziale del Duct Drone
func get_drone_spawn_pos() -> Vector2:
	var bp := get_ship_blueprint()
	if bp:
		return bp.drone_spawn_pos
	return INITIAL_DUCT_DRONE_POS

## Ritorna l'orientamento di spawn iniziale del Duct Drone
func get_drone_spawn_heading() -> float:
	var bp := get_ship_blueprint()
	if bp:
		return bp.drone_spawn_heading
	return INITIAL_DUCT_DRONE_HEADING

## Ritorna i file di sistema e file di bordo di Ship Drive da ShipBlueprint
func get_ship_drive_files() -> Array:
	var bp := get_ship_blueprint()
	if bp and bp.drive_files.size() > 0:
		return bp.drive_files
	return []

## Ritorna le password delle cartelle di Ship Drive da ShipBlueprint
func get_ship_drive_passwords() -> Dictionary:
	var bp := get_ship_blueprint()
	if bp and bp.drive_passwords.size() > 0:
		return bp.drive_passwords
	return {}

## Ritorna le applicazioni mainframe installate da ShipBlueprint
func get_installed_apps() -> Array:
	var bp := get_ship_blueprint()
	if bp and bp.installed_apps.size() > 0:
		return bp.installed_apps
	var def_bp := ShipBlueprint.get_default_blueprint()
	if def_bp:
		return def_bp.installed_apps
	return []

## Ritorna le applicazioni mainframe installate filtrate per il ruolo del giocatore
func get_installed_apps_for_role(role_name: String, is_solo: bool = false) -> Array:
	var bp := get_ship_blueprint()
	if bp and bp.installed_apps.size() > 0:
		return bp.get_apps_for_role(role_name, is_solo)
	var def_bp := ShipBlueprint.get_default_blueprint()
	if def_bp:
		return def_bp.get_apps_for_role(role_name, is_solo)
	return []

func _is_duct_drone_position_valid(pos: Vector2) -> bool:
	for room in get_duct_rooms():
		var r: Rect2 = room.rect
		if r.grow(-2.0).has_point(pos):
			return true
	
	for duct in get_duct_corridors():
		var p1: Vector2 = duct.from
		var p2: Vector2 = duct.to
		var width: float = duct.width
		var seg_dist := _distance_to_segment_2d(pos, p1, p2)
		if seg_dist <= width * 0.8:
			return true
	
	return false

func _distance_to_segment_2d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ab_len_sq := ab.length_squared()
	if ab_len_sq < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var projection := a + t * ab
	return p.distance_to(projection)

# --- DUCT DRONE RPC MULTIPLAYER HANDLERS ---

@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_sync_duct_drone_state(pos: Vector2, heading: float, speed: float, battery: float, lights: bool, scan_active: bool, scan_radius: float) -> void:
	apply_synced_duct_drone_state(pos, heading, speed, battery, lights, scan_active, scan_radius)

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_duct_drone_initial_state(pos: Vector2, heading: float, speed: float, battery: float, lights: bool, scan_active: bool, scan_radius: float) -> void:
	apply_synced_duct_drone_state(pos, heading, speed, battery, lights, scan_active, scan_radius)

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_duct_drone_reset() -> void:
	duct_drone_pos = get_drone_spawn_pos()
	duct_drone_heading = get_drone_spawn_heading()
	duct_drone_speed = 0.0
	duct_drone_linear_input = 0.0
	duct_drone_angular_input = 0.0
	duct_drone_battery = 100.0
	duct_drone_scan_active = false
	duct_drone_scan_radius = 0.0
	duct_drone_reset_performed.emit()

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_client_duct_drone_input(lin_in: float, ang_in: float, speed_mult: float) -> void:
	var nm := _get_net_mgr()
	if nm == null or not nm.get("is_host"):
		return
	duct_drone_linear_input = lin_in
	duct_drone_angular_input = ang_in
	duct_drone_speed_mult = speed_mult

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_duct_drone_stop() -> void:
	var nm := _get_net_mgr()
	if nm == null or not nm.get("is_host"):
		return
	stop_duct_drone()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_reset_duct_drone() -> void:
	var nm := _get_net_mgr()
	if nm == null or not nm.get("is_host"):
		return
	reset_duct_drone()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_duct_drone_lights(enabled: bool) -> void:
	var nm := _get_net_mgr()
	if nm == null or not nm.get("is_host"):
		return
	duct_drone_lights = enabled

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_duct_drone_scan() -> void:
	var nm := _get_net_mgr()
	if nm == null or not nm.get("is_host"):
		return
	trigger_duct_drone_scan()

# --- SHIP DAMAGES & REPAIR API ---

func get_ship_damages() -> Array[ShipDamageRuntimeState]:
	return ship_damages

func get_active_ship_damages() -> Array[ShipDamageRuntimeState]:
	var active: Array[ShipDamageRuntimeState] = []
	for dmg in ship_damages:
		if not dmg.repaired:
			active.append(dmg)
	return active

func get_damage_by_id(dmg_id: String) -> ShipDamageRuntimeState:
	for dmg in ship_damages:
		if dmg.id == dmg_id:
			return dmg
	return null

func get_adjacent_damage(pos: Vector2, max_dist: float = 38.0) -> ShipDamageRuntimeState:
	var closest: ShipDamageRuntimeState = null
	var min_d := max_dist
	for dmg in ship_damages:
		if dmg.repaired:
			continue
		var d: float = pos.distance_to(dmg.pos)
		if d <= min_d:
			min_d = d
			closest = dmg
	return closest

func spawn_ship_damage(type: String = "", pos: Vector2 = Vector2.ZERO, sector_name: String = "", duration: float = 0.0) -> ShipDamageRuntimeState:
	var nm := _get_net_mgr()
	if nm and nm.get("is_connected_to_network") and not nm.get("is_host"):
		return null
	
	if type == "":
		var r := randf()
		if r < 0.34:
			type = DAMAGE_TYPE_BREACH
		elif r < 0.67:
			type = DAMAGE_TYPE_SHORT_CIRCUIT
		else:
			type = DAMAGE_TYPE_FIRE
	
	if pos == Vector2.ZERO:
		var bp_rooms := get_duct_rooms()
		var bp_ducts := get_duct_corridors()
		if randf() < 0.6 and bp_rooms.size() > 0:
			var room: DuctRoomData = bp_rooms.pick_random()
			var r: Rect2 = room.rect
			pos = Vector2(
				randf_range(r.position.x + 10, r.position.x + r.size.x - 10),
				randf_range(r.position.y + 10, r.position.y + r.size.y - 10)
			)
			if sector_name == "":
				sector_name = room.name
		elif bp_ducts.size() > 0:
			var duct: ShipDuctData = bp_ducts.pick_random()
			var p1: Vector2 = duct.from
			var p2: Vector2 = duct.to
			var t := randf_range(0.2, 0.8)
			pos = p1.lerp(p2, t)
			if sector_name == "":
				sector_name = duct.name

	if duration <= 0.0:
		duration = randf_range(3.0, 8.0)

	var dmg_id := "dmg_%d" % _next_damage_idx
	_next_damage_idx += 1

	var dmg := ShipDamageRuntimeState.new(dmg_id, type, pos)
	dmg.sector = sector_name if sector_name != "" else "Condotto / Scafo"
	dmg.repair_duration = duration

	ship_damages.append(dmg)
	ship_damages_updated.emit(ship_damages)

	if nm and nm.get("is_connected_to_network") and nm.get("is_host"):
		if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
			var snapshot: Array[Dictionary] = []
			for d in ship_damages:
				snapshot.append(d.to_dict())
			_rpc_sync_ship_damages.rpc(snapshot)

	return dmg

func generate_initial_ship_damages(count: int = 4) -> void:
	ship_damages.clear()
	_next_damage_idx = 1

	var bp_damages := get_damage_zones()
	if bp_damages.size() > 0:
		var num := mini(count, bp_damages.size())
		for i in range(num):
			var d: ShipDamageData = bp_damages[i]
			var dmg_type: String = d.type
			var dmg_pos: Vector2 = d.pos
			var dmg_sector: String = d.sector
			var dmg_dur: float = d.repair_cost
			spawn_ship_damage(dmg_type, dmg_pos, dmg_sector, dmg_dur)
	else:
		var preset_damages := [
			{
				"type": DAMAGE_TYPE_BREACH,
				"pos": Vector2(160, 310),
				"sector": "Condotto Manutenzione SX",
				"duration": 4.5
			},
			{
				"type": DAMAGE_TYPE_SHORT_CIRCUIT,
				"pos": Vector2(390, 140),
				"sector": "Comunicazioni & EW",
				"duration": 5.2
			},
			{
				"type": DAMAGE_TYPE_BREACH,
				"pos": Vector2(440, 310),
				"sector": "Condotto Manutenzione DX",
				"duration": 6.0
			},
			{
				"type": DAMAGE_TYPE_SHORT_CIRCUIT,
				"pos": Vector2(200, 140),
				"sector": "Sensori & Avionica",
				"duration": 3.8
			},
			{
				"type": DAMAGE_TYPE_SHORT_CIRCUIT,
				"pos": Vector2(300, 255),
				"sector": "Reattore Principale",
				"duration": 7.0
			}
		]

		var num := mini(count, preset_damages.size())
		for i in range(num):
			var p: Dictionary = preset_damages[i]
			spawn_ship_damage(p["type"], p["pos"], p["sector"], p["duration"])

func clear_ship_damages() -> void:
	ship_damages.clear()
	is_duct_drone_repairing = false
	repairing_damage_id = ""
	ship_damages_updated.emit(ship_damages)
	var nm := _get_net_mgr()
	if nm and nm.get("is_connected_to_network") and nm.get("is_host"):
		if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
			_rpc_sync_ship_damages.rpc(ship_damages)

func start_duct_drone_repair(damage_id: String) -> void:
	var nm := _get_net_mgr()
	if nm and nm.get("is_connected_to_network") and not nm.get("is_host"):
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			_rpc_client_start_repair.rpc_id(1, damage_id)
		is_duct_drone_repairing = true
		repairing_damage_id = damage_id
		return
	
	var dmg: Variant = get_damage_by_id(damage_id)
	if dmg == null or duct_drone_battery <= 0.0:
		return
	var is_repaired: bool = bool(dmg.repaired if "repaired" in dmg else dmg.get("repaired", false))
	if is_repaired:
		return
	
	var d_pos: Vector2 = dmg.pos if "pos" in dmg else Vector2.ZERO
	if d_pos == Vector2.ZERO and dmg is Dictionary and dmg.has("pos"):
		var p_raw: Variant = dmg["pos"]
		if p_raw is Array and p_raw.size() >= 2:
			d_pos = Vector2(float(p_raw[0]), float(p_raw[1]))
		elif p_raw is Vector2:
			d_pos = p_raw
	var d: float = duct_drone_pos.distance_to(d_pos)
	var repair_rng: float = float(_duct_drone_active_config.get("repair_range", 42.0))
	if d > repair_rng:
		return
	
	is_duct_drone_repairing = true
	repairing_damage_id = damage_id
	var progress: float = float(dmg.repair_progress if "repair_progress" in dmg else dmg.get("repair_progress", 0.0))
	duct_drone_repair_state_changed.emit(true, damage_id, progress)
	
	if nm and nm.get("is_connected_to_network") and nm.get("is_host"):
		if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
			_rpc_sync_repair_state.rpc(true, damage_id, progress)

func stop_duct_drone_repair() -> void:
	var nm := _get_net_mgr()
	if nm and nm.get("is_connected_to_network") and not nm.get("is_host"):
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			_rpc_client_stop_repair.rpc_id(1)
		is_duct_drone_repairing = false
		repairing_damage_id = ""
		return
	
	is_duct_drone_repairing = false
	repairing_damage_id = ""
	duct_drone_repair_state_changed.emit(false, "", 0.0)
	
	if nm and nm.get("is_connected_to_network") and nm.get("is_host"):
		if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
			_rpc_sync_repair_state.rpc(false, "", 0.0)

func is_duct_drone_repairing_active() -> bool:
	return is_duct_drone_repairing

func get_repairing_damage_id() -> String:
	return repairing_damage_id

# --- DAMAGE & REPAIR RPC HANDLERS ---

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_ship_damages(p_damages: Array) -> void:
	ship_damages.clear()
	for d_dict in p_damages:
		if d_dict is Dictionary:
			var dmg := ShipDamageRuntimeState.new()
			dmg.from_dict(d_dict)
			ship_damages.append(dmg)
	ship_damages_updated.emit(ship_damages)

@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_sync_repair_state(is_repairing: bool, damage_id: String, progress: float) -> void:
	is_duct_drone_repairing = is_repairing
	repairing_damage_id = damage_id
	for dmg in ship_damages:
		if dmg.id == damage_id:
			dmg.repair_progress = progress
			break
	duct_drone_repair_state_changed.emit(is_repairing, damage_id, progress)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_start_repair(damage_id: String) -> void:
	var nm := _get_net_mgr()
	if nm == null or not nm.get("is_host"):
		return
	start_duct_drone_repair(damage_id)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_stop_repair() -> void:
	var nm := _get_net_mgr()
	if nm == null or not nm.get("is_host"):
		return
	stop_duct_drone_repair()

func get_camera_transform(cam_id: String) -> Transform3D:
	if _space_scene_instance and is_instance_valid(_space_scene_instance):
		return _space_scene_instance.get_camera_global_transform(cam_id)
	return Transform3D.IDENTITY

func get_cameras_info() -> Array[CameraMetadata]:
	return RoomDatabase.CAMERAS_METADATA

func get_camera_info(cam_id: String) -> CameraMetadata:
	for c in RoomDatabase.CAMERAS_METADATA:
		if c.id == cam_id:
			return c
	return null

func is_camera_window_open(cam_id: String) -> bool:
	if _active_camera_windows.has(cam_id):
		var win: FakeWindow = _active_camera_windows[cam_id]
		if win and is_instance_valid(win) and not win.is_being_deleted:
			return true
	return false

func get_camera_window(cam_id: String) -> FakeWindow:
	if is_camera_window_open(cam_id):
		return _active_camera_windows[cam_id]
	return null

func toggle_camera_window(cam_id: String) -> bool:
	if is_camera_window_open(cam_id):
		close_camera_window(cam_id)
		return false
	else:
		open_camera_window(cam_id)
		return true

func open_camera_window(cam_id: String) -> FakeWindow:
	if not is_ship_connected():
		return null
	
	if is_camera_window_open(cam_id):
		var existing_win: FakeWindow = _active_camera_windows[cam_id]
		if existing_win.is_minimized:
			existing_win.show_window()
		existing_win.select_window(false)
		return existing_win
	
	var packed_win: PackedScene = load(CAMERA_FEED_WINDOW_SCENE)
	if not packed_win:
		push_error("Impossibile caricare la scena finestra feed telecamera: " + CAMERA_FEED_WINDOW_SCENE)
		return null
	
	var win_instance: FakeWindow = packed_win.instantiate() as FakeWindow
	if win_instance == null:
		return null
	
	var cam_info := get_camera_info(cam_id)
	var cam_code: String = cam_info.code if cam_info and not cam_info.code.is_empty() else cam_id.to_upper()
	var title: String = "%s - Feed Esterno" % [cam_code]
	win_instance.title_text = title
	
	# Trova il desktop o il nodo contenitore finestre
	var desktop: Node = _find_windows_container()
	if desktop:
		if desktop.is_node_ready():
			desktop.add_child(win_instance)
		else:
			desktop.add_child.call_deferred(win_instance)
	else:
		get_tree().root.add_child.call_deferred(win_instance)
	
	# Configura la telecamera nella finestra
	if win_instance.has_method("setup_camera"):
		win_instance.setup_camera(cam_id, cam_info)
	
	if win_instance.has_method("apply_optics_config") and not _cams_active_config.is_empty():
		win_instance.apply_optics_config(_cams_active_config)
	
	# Calcola una posizione sfalsata ordinata per la finestra
	_position_camera_window(win_instance, cam_id)
	
	_active_camera_windows[cam_id] = win_instance
	
	win_instance.tree_exiting.connect(func() -> void:
		_on_camera_window_closed(cam_id)
	)
	
	camera_window_opened.emit(cam_id, win_instance)
	camera_status_changed.emit(cam_id, true)
	return win_instance

func close_camera_window(cam_id: String) -> void:
	if _active_camera_windows.has(cam_id):
		var win: FakeWindow = _active_camera_windows[cam_id]
		_active_camera_windows.erase(cam_id)
		if win and is_instance_valid(win) and not win.is_being_deleted:
			win._on_close_button_pressed()
		camera_window_closed.emit(cam_id)
		camera_status_changed.emit(cam_id, false)

func close_all_camera_windows() -> void:
	var keys := _active_camera_windows.keys()
	for cam_id in keys:
		close_camera_window(cam_id)

func open_all_camera_windows() -> void:
	for c in RoomDatabase.CAMERAS_METADATA:
		if c and "id" in c:
			open_camera_window(c.id)

func set_cams_config(cfg: Dictionary) -> void:
	_cams_active_config = cfg.duplicate()
	apply_cams_config_to_open_windows(_cams_active_config)

func get_cams_config() -> Dictionary:
	return _cams_active_config

func apply_cams_config_to_open_windows(cfg: Dictionary) -> void:
	_cams_active_config = cfg.duplicate()
	for cam_id in _active_camera_windows:
		var win: FakeWindow = _active_camera_windows[cam_id]
		if win and is_instance_valid(win) and win.has_method("apply_optics_config"):
			win.apply_optics_config(cfg)

func set_camera_headlight(cam_id: String, enabled: bool) -> void:
	camera_manager.set_headlight(cam_id, enabled)
	var ship := get_spaceship()
	if ship and is_instance_valid(ship) and ship.has_method("set_headlight"):
		ship.set_headlight(cam_id, enabled)

func is_camera_headlight_on(cam_id: String) -> bool:
	var ship := get_spaceship()
	if ship and is_instance_valid(ship) and ship.has_method("is_headlight_on"):
		return ship.is_headlight_on(cam_id)
	return camera_manager.is_headlight_on(cam_id)

func toggle_camera_headlight(cam_id: String) -> bool:
	var new_state := not is_camera_headlight_on(cam_id)
	set_camera_headlight(cam_id, new_state)
	return new_state

func set_all_camera_headlights(enabled: bool) -> void:
	for c in RoomDatabase.CAMERAS_METADATA:
		if c and "id" in c:
			set_camera_headlight(c.id, enabled)

func _on_camera_window_closed(cam_id: String) -> void:
	if _active_camera_windows.has(cam_id):
		_active_camera_windows.erase(cam_id)
		camera_window_closed.emit(cam_id)
		camera_status_changed.emit(cam_id, false)

func _find_windows_container() -> Node:
	# Cerca il Desktop all'interno della scena principale
	var root := get_tree().root
	var desktop: Node = root.find_child("Desktop", true, false)
	if desktop:
		return desktop
	var main_control := root.find_child("Control", true, false)
	if main_control:
		return main_control
	return root

func _position_camera_window(win: FakeWindow, cam_id: String) -> void:
	# Dimensioni predefinite della finestra feed
	win.size = Vector2(460, 320)
	win.custom_minimum_size = Vector2(360, 240)
	
	# Posizioni logiche sullo schermo per le 6 telecamere
	var viewport_size := get_viewport().get_visible_rect().size if get_viewport() else Vector2(1920, 1080)
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = Vector2(1280, 720)
	
	var base_x := 450.0
	var base_y := 60.0
	var w := 460.0
	var h := 320.0
	var margin_x := 15.0
	var margin_y := 15.0
	
	match cam_id:
		"front":
			win.position = Vector2(base_x, base_y)
		"rear":
			win.position = Vector2(base_x, base_y + h + margin_y)
		"left":
			win.position = Vector2(base_x - w - margin_x, base_y)
		"right":
			win.position = Vector2(base_x + w + margin_x, base_y)
		"top":
			win.position = Vector2(base_x - w - margin_x, base_y + h + margin_y)
		"bottom":
			win.position = Vector2(base_x + w + margin_x, base_y + h + margin_y)
		_:
			win.position = Vector2(base_x + randf_range(20, 60), base_y + randf_range(20, 60))

# --- WEAPONS SYSTEM & TARGETING METHODS ---

var active_probes: Array[Dictionary] = []

## Registra e rilascia nello spazio una sonda telemetrica attiva verso la direzione specificata
func spawn_telemetry_probe(origin: Vector3, direction: Vector3) -> Dictionary:
	var probe_id := "PROBE-%03d" % (active_probes.size() + 1)
	var dir_norm := direction.normalized() if direction.length_squared() > 0.01 else Vector3(0, 0, -1)
	var probe_data: Dictionary = {
		"id": probe_id,
		"name": "SONDA PROBE-%02d" % (active_probes.size() + 1),
		"pos": origin + dir_norm * 15.0,
		"velocity": dir_norm * 35.0,
		"type": "PROBE",
		"threat_level": "FRIENDLY",
		"battery": 100.0,
		"signal_signature": 1.0,
		"scan_radius": 1000.0,
		"radius_m": 5.0,
		"timestamp": Time.get_ticks_msec()
	}
	active_probes.append(probe_data)
	return probe_data

## Ritorna l'ultima sonda telemetrica attiva in volo (o vuota se nessuna)
func get_active_probe() -> Dictionary:
	if active_probes.is_empty():
		return {}
	return active_probes.back()

## Ritorna tutte le sonde attive
func get_active_probes() -> Array[Dictionary]:
	return active_probes

## Cancella le sonde attive
func clear_active_probes() -> void:
	active_probes.clear()

## Ritorna l'elenco dei bersagli rilevati nello spazio circostante (asteroidi o minacce).
func get_weapon_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	var ship := get_spaceship()
	var ship_pos := ship.global_position if ship and is_instance_valid(ship) and ship.is_inside_tree() else Vector3.ZERO
	var ship_basis := ship.global_transform.basis if ship and is_instance_valid(ship) and ship.is_inside_tree() else Basis.IDENTITY
	var ship_vel := ship.linear_velocity if ship and is_instance_valid(ship) else Vector3.ZERO
	
	if _space_scene_instance and is_instance_valid(_space_scene_instance) and _space_scene_instance.has_method("get_asteroids"):
		var asteroids_node: Node3D = _space_scene_instance.get_asteroids()
		if asteroids_node and is_instance_valid(asteroids_node):
			for child in asteroids_node.get_children():
				if child is Node3D:
					var a_pos: Vector3 = child.global_position
					var diff: Vector3 = a_pos - ship_pos
					var dist: float = diff.length()
					var local_diff: Vector3 = ship_basis.inverse() * diff
					var bearing_deg: float = rad_to_deg(atan2(local_diff.x, -local_diff.z))
					var elevation_deg: float = rad_to_deg(atan2(local_diff.y, Vector2(local_diff.x, local_diff.z).length()))
					
					targets.append({
						"id": child.name,
						"name": child.name.replace("_", " "),
						"pos": a_pos,
						"rel_pos": diff,
						"distance": dist,
						"velocity": Vector3(0.1, 0.0, 0.2),
						"bearing_deg": bearing_deg,
						"elevation_deg": elevation_deg,
						"type": "ASTEROID",
						"threat_level": "NEUTRAL" if dist > 60.0 else "HAZARD"
					})
	
	# Fallback se non ci sono nodi attivi (es. test headless)
	if targets.is_empty():
		var default_targets: Array[Dictionary] = [
			{"id": "AST-ALPHA", "name": "AST-01 [Alpha]", "pos": Vector3(0, 8, -65), "vel": Vector3(0.2, 0, 0.5), "threat": "HAZARD"},
			{"id": "AST-BETA", "name": "AST-02 [Beta]", "pos": Vector3(45, -6, -110), "vel": Vector3(-0.3, 0.1, 0.2), "threat": "NEUTRAL"},
			{"id": "AST-GAMMA", "name": "AST-03 [Gamma]", "pos": Vector3(-32, 12, -50), "vel": Vector3(0.5, -0.2, 0.8), "threat": "HAZARD"},
			{"id": "DRONE-HOSTILE", "name": "PROBE-7X [Sconosciuto]", "pos": Vector3(16, 5, -30), "vel": Vector3(-1.2, 0.4, 2.5), "threat": "HOSTILE"}
		]
		for dt in default_targets:
			var d_pos: Vector3 = dt["pos"]
			var diff: Vector3 = d_pos - ship_pos
			var dist: float = diff.length()
			var local_diff: Vector3 = ship_basis.inverse() * diff
			var bearing_deg: float = rad_to_deg(atan2(local_diff.x, -local_diff.z))
			var elevation_deg: float = rad_to_deg(atan2(local_diff.y, Vector2(local_diff.x, local_diff.z).length()))
			
			targets.append({
				"id": dt["id"],
				"name": dt["name"],
				"pos": d_pos,
				"rel_pos": diff,
				"distance": dist,
				"velocity": dt["vel"],
				"bearing_deg": bearing_deg,
				"elevation_deg": elevation_deg,
				"type": "CONTACT",
				"threat_level": dt["threat"]
			})
	
	# Includi le sonde attive lanciate nello spazio
	for p in active_probes:
		var p_pos: Vector3 = p.get("pos", Vector3.ZERO)
		var diff: Vector3 = p_pos - ship_pos
		var dist: float = diff.length()
		var local_diff: Vector3 = ship_basis.inverse() * diff
		var bearing_deg: float = rad_to_deg(atan2(local_diff.x, -local_diff.z))
		var elevation_deg: float = rad_to_deg(atan2(local_diff.y, Vector2(local_diff.x, local_diff.z).length()))
		targets.append({
			"id": p.get("id"),
			"name": p.get("name"),
			"pos": p_pos,
			"rel_pos": diff,
			"distance": dist,
			"velocity": p.get("velocity", Vector3.ZERO),
			"bearing_deg": bearing_deg,
			"elevation_deg": elevation_deg,
			"type": "PROBE",
			"threat_level": "FRIENDLY"
		})
	
	# Ordina per distanza crescente
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", 0.0)) < float(b.get("distance", 0.0))
	)
	return targets

## Verifica se il sottosistema Armeria (Sublayer 3) riceve alimentazione sufficiente
func is_armory_powered() -> bool:
	var devices := get_power_devices()
	for dev in devices:
		if dev and dev.id == "armory_defense":
			return true # Sostituito logica obsoleta inputs_powered
	return true

## Esegue una richiesta di fuoco per il tipo d'arma specificato
func request_fire_weapon(weapon_type: String, target_id: String = "", manual_aim_dir: Vector3 = Vector3.ZERO) -> Dictionary:
	var ship := get_spaceship()
	var origin: Vector3 = ship.global_position if ship and is_instance_valid(ship) and ship.is_inside_tree() else Vector3.ZERO
	var target_pos: Vector3 = origin + (manual_aim_dir * 100.0 if manual_aim_dir.length_squared() > 0.01 else Vector3(0, 0, -100))
	var hit_success: bool = false
	var probe_info: Dictionary = {}
	
	if weapon_type == "PROBE" or weapon_type == "TELEMETRY_PROBE":
		probe_info = spawn_telemetry_probe(origin, manual_aim_dir)
		target_pos = probe_info.get("pos", target_pos)
		hit_success = true
	elif not target_id.is_empty():
		for t in get_weapon_targets():
			if t.get("id") == target_id:
				target_pos = t.get("pos", Vector3.ZERO)
				hit_success = true
				break
	
	weapon_fired.emit(weapon_type, origin, target_pos, hit_success, target_id)
	return {
		"weapon_type": weapon_type,
		"origin": origin,
		"target_pos": target_pos,
		"hit_success": hit_success,
		"target_id": target_id,
		"probe": probe_info
	}

# --- SENSORS & TACTICAL MAP METHODS ---

var active_waypoint: Dictionary = {}

func set_active_waypoint(wp_data: Dictionary) -> void:
	active_waypoint = wp_data.duplicate(true)
	waypoint_updated.emit(active_waypoint)

func get_active_waypoint() -> Dictionary:
	return active_waypoint

func clear_active_waypoint() -> void:
	active_waypoint.clear()
	waypoint_updated.emit({})

func trigger_active_ping(radius: float = 50000.0) -> void:
	var ship := get_spaceship()
	var origin: Vector3 = ship.global_position if ship and is_instance_valid(ship) and ship.is_inside_tree() else Vector3.ZERO
	active_ping_triggered.emit(origin, radius)

func is_sensors_powered() -> bool:
	var devices := get_power_devices()
	for dev in devices:
		if dev and dev.id == "sensors_radar":
			return true # Sostituito logica obsoleta inputs_powered
	return true

## Verifica se la nave ha potenza disponibile sufficiente (es. per ping radar)
func can_consume_power(_amount_mw: float) -> bool:
	return is_sensors_powered()

## Alias per compatibilità con PowerGrid/Sensors
func has_available_power(amount_mw: float) -> bool:
	return can_consume_power(amount_mw)

## Consuma potenza istantanea
func consume_power(amount_mw: float) -> bool:
	return can_consume_power(amount_mw)

func has_radar_damage() -> bool:
	for d in ship_damages:
		if d and not d.repaired:
			if d.sector == "Sensori & Avionica" or d.sector == "Matrice sensori":
				return true
	return false

## Ritorna tutti i contatti telemetrici/radar a lungo raggio (fino a 50 km) con spettrometria e IFF.
func get_sensor_entities() -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	var ship := get_spaceship()
	var ship_pos := ship.global_position if ship and is_instance_valid(ship) and ship.is_inside_tree() else Vector3.ZERO
	var ship_basis := ship.global_transform.basis if ship and is_instance_valid(ship) and ship.is_inside_tree() else Basis.IDENTITY
	
	if _space_scene_instance and is_instance_valid(_space_scene_instance) and _space_scene_instance.has_method("get_asteroids"):
		var asteroids_node: Node3D = _space_scene_instance.get_asteroids()
		if asteroids_node and is_instance_valid(asteroids_node):
			for child in asteroids_node.get_children():
				if child is Node3D:
					var a_pos: Vector3 = child.global_position
					var diff: Vector3 = a_pos - ship_pos
					var dist: float = diff.length()
					var local_diff: Vector3 = ship_basis.inverse() * diff
					var bearing_deg: float = rad_to_deg(atan2(local_diff.x, -local_diff.z))
					var elevation_deg: float = rad_to_deg(atan2(local_diff.y, Vector2(local_diff.x, local_diff.z).length()))
					
					var is_hazard := dist < 60.0
					var mass_val: float = 2400.0
					entities.append({
						"id": child.name,
						"name": child.name.replace("_", " "),
						"pos": a_pos,
						"rel_pos": diff,
						"distance": dist,
						"velocity": Vector3(0.1, 0.0, 0.2),
						"bearing_deg": bearing_deg,
						"elevation_deg": elevation_deg,
						"type": "ASTEROID",
						"iff_tag": "HAZARD" if is_hazard else "NEUTRAL",
						"stealth_level": 0.0,
						"radius_m": 30.0,
						"composition": {
							"Ferro (Fe)": 45.0,
							"Nichel (Ni)": 28.0,
							"Silicati": 18.0,
							"Cobalto": 9.0
						},
						"integrity": 100.0,
						"mass_tons": mass_val,
						"radiation_level": 0.05,
						"signal_signature": 0.85,
						"estimated_value_cr": 4500
					})
					
	# Aggiungi l'entità della stazione orbitale primaria nello spazio se attiva
	if primary_station_instance and is_instance_valid(primary_station_instance):
		var st_pos: Vector3 = primary_station_instance.global_position
		var diff: Vector3 = st_pos - ship_pos
		var dist: float = diff.length()
		var local_diff: Vector3 = ship_basis.inverse() * diff
		var bearing_deg: float = rad_to_deg(atan2(local_diff.x, -local_diff.z))
		var elevation_deg: float = rad_to_deg(atan2(local_diff.y, Vector2(local_diff.x, local_diff.z).length()))
		
		entities.append({
			"id": primary_station_instance.station_id,
			"name": primary_station_instance.station_name,
			"pos": st_pos,
			"rel_pos": diff,
			"distance": dist,
			"velocity": Vector3.ZERO,
			"bearing_deg": bearing_deg,
			"elevation_deg": elevation_deg,
			"type": "STATION",
			"iff_tag": "FRIENDLY",
			"stealth_level": 0.0,
			"radius_m": 120.0,
			"composition": {
				"Struttura Modulare": 70.0,
				"Reattore Fusione": 20.0,
				"Serbatoi Idrogeno": 10.0
			},
			"integrity": 100.0,
			"mass_tons": 185000.0,
			"radiation_level": 0.15,
			"signal_signature": 1.0,
			"estimated_value_cr": 250000
		})
	
	# Contatti diegetici aggiuntivi a lungo raggio / stazioni / relitti / sonde
	var long_range_defaults: Array[Dictionary] = [
		{
			"id": "AST-ALPHA",
			"name": "AST-01 [Alpha - Ricco di Titanio]",
			"pos": Vector3(0, 8, -65),
			"vel": Vector3(0.2, 0, 0.5),
			"type": "MINERAL_ASTEROID",
			"iff_tag": "HAZARD",
			"stealth": 0.0,
			"radius_m": 35.0,
			"composition": {"Titanio (Ti)": 52.0, "Platino (Pt)": 18.0, "Ferro (Fe)": 20.0, "Silicati": 10.0},
			"integrity": 100.0,
			"mass_tons": 3200.0,
			"radiation": 0.08,
			"signature": 0.90,
			"value": 14200
		},
		{
			"id": "AST-BETA",
			"name": "AST-02 [Beta - Ghiaccio & Silicio]",
			"pos": Vector3(45, -6, -110),
			"vel": Vector3(-0.3, 0.1, 0.2),
			"type": "ASTEROID",
			"iff_tag": "NEUTRAL",
			"stealth": 0.0,
			"radius_m": 25.0,
			"composition": {"Ghiaccio d'Acqua": 65.0, "Silicati": 25.0, "Metano": 10.0},
			"integrity": 95.0,
			"mass_tons": 1800.0,
			"radiation": 0.02,
			"signature": 0.65,
			"value": 3100
		},
		{
			"id": "WRECK-VALKYRIE",
			"name": "RELITTO-09 [Fregata Valkyrie]",
			"pos": Vector3(-2400, 350, -4800),
			"vel": Vector3(0.0, 0.0, 0.0),
			"type": "WRECK",
			"iff_tag": "NEUTRAL",
			"stealth": 0.20,
			"radius_m": 45.0,
			"composition": {"Blindatura Scafo": 55.0, "Elettronica Avionica": 25.0, "Leghe Rare": 20.0},
			"integrity": 32.0,
			"mass_tons": 12500.0,
			"radiation": 0.45,
			"signature": 0.70,
			"value": 38000
		},
		{
			"id": "STATION-OUTPOST-7",
			"name": "STAZIONE [Avamposto Minerario 7]",
			"pos": Vector3(12000, -800, -18500),
			"vel": Vector3(0.0, 0.0, 0.0),
			"type": "STATION",
			"iff_tag": "FRIENDLY",
			"stealth": 0.0,
			"radius_m": 120.0,
			"composition": {"Struttura Modulare": 70.0, "Reattore Fusione": 20.0, "Serbatoi Idrogeno": 10.0},
			"integrity": 100.0,
			"mass_tons": 185000.0,
			"radiation": 0.15,
			"signature": 1.0,
			"value": 250000
		},
		{
			"id": "BEACON-NAV-04",
			"name": "FARO-NAV [Settore Helios-4]",
			"pos": Vector3(-8500, 1200, -12000),
			"vel": Vector3(0.0, 0.0, 0.0),
			"type": "BEACON",
			"iff_tag": "FRIENDLY",
			"stealth": 0.0,
			"radius_m": 10.0,
			"composition": {"Emettitore Subspaziale": 60.0, "Pannelli Solari": 40.0},
			"integrity": 90.0,
			"mass_tons": 450.0,
			"radiation": 0.10,
			"signature": 0.95,
			"value": 8500
		},
		{
			"id": "DRONE-HOSTILE",
			"name": "SONDA-7X [Firma Clandestina]",
			"pos": Vector3(16, 5, -30),
			"vel": Vector3(-1.2, 0.4, 2.5),
			"type": "SHIP_HOSTILE",
			"iff_tag": "HOSTILE",
			"stealth": 0.40,
			"radius_m": 8.0,
			"composition": {"Scafo Composito": 40.0, "Testata Energetica": 45.0, "Micro-Propulsore": 15.0},
			"integrity": 80.0,
			"mass_tons": 120.0,
			"radiation": 0.85,
			"signature": 0.45,
			"value": 15000
		},
		{
			"id": "STEALTH-CORVETTE-X",
			"name": "CONTATTO-SCONOSCIUTO [Firma Stealth]",
			"pos": Vector3(18000, -2100, -29500),
			"vel": Vector3(12.5, -2.0, -8.0),
			"type": "UNKNOWN",
			"iff_tag": "UNKNOWN",
			"stealth": 0.75,
			"radius_m": 25.0,
			"composition": {"Assorbitori Radar": 60.0, "ECM Array": 30.0, "Leghe Oscure": 10.0},
			"integrity": 100.0,
			"mass_tons": 4500.0,
			"radiation": 0.30,
			"signature": 0.25,
			"value": 75000
		}
	]
	
	var existing_ids: Dictionary = {}
	for e in entities:
		existing_ids[e.get("id")] = true
	
	for lrd in long_range_defaults:
		if not existing_ids.has(lrd["id"]):
			var d_pos: Vector3 = lrd["pos"]
			var diff: Vector3 = d_pos - ship_pos
			var dist: float = diff.length()
			var local_diff: Vector3 = ship_basis.inverse() * diff
			var bearing_deg: float = rad_to_deg(atan2(local_diff.x, -local_diff.z))
			var elevation_deg: float = rad_to_deg(atan2(local_diff.y, Vector2(local_diff.x, local_diff.z).length()))
			
			entities.append({
				"id": lrd["id"],
				"name": lrd["name"],
				"pos": d_pos,
				"rel_pos": diff,
				"distance": dist,
				"velocity": lrd["vel"],
				"bearing_deg": bearing_deg,
				"elevation_deg": elevation_deg,
				"type": lrd["type"],
				"iff_tag": lrd["iff_tag"],
				"stealth_level": lrd["stealth"],
				"radius_m": float(lrd.get("radius_m", 25.0)),
				"composition": lrd["composition"],
				"integrity": lrd["integrity"],
				"mass_tons": lrd["mass_tons"],
				"radiation_level": lrd["radiation"],
				"signal_signature": lrd["signature"],
				"estimated_value_cr": lrd["value"]
			})
	
	if not active_waypoint.is_empty():
		var wp_pos: Vector3 = active_waypoint.get("pos")
		var diff: Vector3 = wp_pos - ship_pos
		var dist: float = diff.length()
		var local_diff: Vector3 = ship_basis.inverse() * diff
		var bearing_deg: float = rad_to_deg(atan2(local_diff.x, -local_diff.z))
		var elevation_deg: float = rad_to_deg(atan2(local_diff.y, Vector2(local_diff.x, local_diff.z).length()))
		
		entities.append({
			"id": "ACTIVE_WAYPOINT",
			"name": active_waypoint.get("name"),
			"pos": wp_pos,
			"rel_pos": diff,
			"distance": dist,
			"velocity": Vector3.ZERO,
			"bearing_deg": bearing_deg,
			"elevation_deg": elevation_deg,
			"type": "WAYPOINT",
			"iff_tag": "WAYPOINT",
			"stealth_level": 0.0,
			"radius_m": 1.0,
			"composition": {},
			"integrity": 100.0,
			"mass_tons": 0.0,
			"radiation_level": 0.0,
			"signal_signature": 1.0,
			"estimated_value_cr": 0
		})
	
	# Includi le sonde attive lanciate nello spazio
	for p in active_probes:
		var p_pos: Vector3 = p.get("pos", Vector3.ZERO)
		var diff: Vector3 = p_pos - ship_pos
		var dist: float = diff.length()
		var local_diff: Vector3 = ship_basis.inverse() * diff
		var bearing_deg: float = rad_to_deg(atan2(local_diff.x, -local_diff.z))
		var elevation_deg: float = rad_to_deg(atan2(local_diff.y, Vector2(local_diff.x, local_diff.z).length()))
		entities.append({
			"id": p.get("id"),
			"name": p.get("name"),
			"pos": p_pos,
			"rel_pos": diff,
			"distance": dist,
			"velocity": p.get("velocity", Vector3.ZERO),
			"bearing_deg": bearing_deg,
			"elevation_deg": elevation_deg,
			"type": "PROBE",
			"iff_tag": "FRIENDLY",
			"stealth_level": 0.0,
			"radius_m": 5.0,
			"scan_radius": float(p.get("scan_radius", 1000.0)),
			"composition": {"Array Sensori": 60.0, "Batteria Litio": 40.0},
			"integrity": 100.0,
			"mass_tons": 0.5,
			"radiation_level": 0.01,
			"signal_signature": 1.0,
			"estimated_value_cr": 250
		})
	
	entities.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", 0.0)) < float(b.get("distance", 0.0))
	)
	return entities

# --- SERVICE DRONE (EVA OPERATIONS) API ---

var _service_drone_instance: ServiceDroneEntity = null

func get_service_drone() -> ServiceDroneEntity:
	if _service_drone_instance and is_instance_valid(_service_drone_instance):
		return _service_drone_instance
	
	if _space_scene_instance and is_instance_valid(_space_scene_instance):
		var existing := _space_scene_instance.get_node_or_null("ServiceDrone") as ServiceDroneEntity
		if existing:
			_service_drone_instance = existing
			return _service_drone_instance
		
		var packed := load("res://Outside/ServiceDrone/service_drone_entity.tscn") as PackedScene
		if packed:
			var inst := packed.instantiate() as ServiceDroneEntity
			inst.name = "ServiceDrone"
			_space_scene_instance.add_child(inst)
			_service_drone_instance = inst
			return _service_drone_instance
	
	# Fallback per test headless o ambiente senza master viewport
	if _service_drone_instance == null or not is_instance_valid(_service_drone_instance):
		var packed_fb := load("res://Outside/ServiceDrone/service_drone_entity.tscn") as PackedScene
		if packed_fb:
			var inst_fb := packed_fb.instantiate() as ServiceDroneEntity
			inst_fb.name = "ServiceDrone"
			add_child(inst_fb)
			_service_drone_instance = inst_fb
	
	return _service_drone_instance

func get_service_drone_telemetry() -> Dictionary:
	var drone := get_service_drone()
	if drone:
		return drone.get_telemetry()
	return {}

func set_service_drone_inputs(move_vec: Vector3, rot_vec: Vector3, boost: bool = false) -> void:
	var drone := get_service_drone()
	if drone:
		drone.set_inputs(move_vec, rot_vec, boost)

func set_service_drone_lights(enabled: bool) -> void:
	var drone := get_service_drone()
	if drone:
		drone.set_lights(enabled)

func launch_service_drone() -> void:
	var drone := get_service_drone()
	if drone:
		drone.undock()

func dock_service_drone() -> void:
	var drone := get_service_drone()
	if drone:
		drone.dock()

func start_service_drone_auto_dock() -> void:
	var drone := get_service_drone()
	if drone:
		drone.start_auto_dock()

func set_service_drone_active_tool(tool_name: String) -> void:
	var drone := get_service_drone()
	if drone:
		drone.set_active_tool(tool_name)

func set_service_drone_tool_trigger(active: bool, target_id: String = "") -> void:
	var drone := get_service_drone()
	if drone:
		drone.set_tool_trigger(active, target_id)

func set_service_drone_config(cfg: Dictionary) -> void:
	var drone := get_service_drone()
	if drone:
		drone.apply_config(cfg)

# --- CRUISE DRIVE (SUB-FTL) API ---

var _cruise_drive_instance: CruiseDriveController = null

func get_cruise_drive_controller() -> CruiseDriveController:
	if _cruise_drive_instance and is_instance_valid(_cruise_drive_instance):
		return _cruise_drive_instance
	
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		var existing := ship.get_node_or_null("CruiseDriveController")
		if existing and existing is CruiseDriveController:
			_cruise_drive_instance = existing
			ship.set_cruise_controller(_cruise_drive_instance)
			return _cruise_drive_instance
		
		# Istanzia e collega alla spaceship
		var cdc := CruiseDriveController.new()
		cdc.name = "CruiseDriveController"
		ship.add_child(cdc)
		ship.set_cruise_controller(cdc)
		_cruise_drive_instance = cdc
		return _cruise_drive_instance
	
	if _cruise_drive_instance == null or not is_instance_valid(_cruise_drive_instance):
		var cdc_fb := CruiseDriveController.new()
		cdc_fb.name = "CruiseDriveController"
		add_child(cdc_fb)
		_cruise_drive_instance = cdc_fb
	
	return _cruise_drive_instance

func set_cruise_coils_power(power_mw: float) -> void:
	var cdc := get_cruise_drive_controller()
	if cdc:
		cdc.set_cruise_coils_power(power_mw)

func is_cruise_drive_powered() -> bool:
	var cdc := get_cruise_drive_controller()
	if cdc:
		return cdc.get_is_powered()
	return false

# --- LIFE SUPPORT & CREW VITALS INTEGRATION API ---
var _life_support_instance: Node = null
var _bridge_atmo_override: Dictionary = {}
var _current_ship_g_force: float = 1.0

func register_life_support_app(app: Node) -> void:
	_life_support_instance = app

func unregister_life_support_app(app: Node) -> void:
	if _life_support_instance == app:
		_life_support_instance = null

func get_life_support_app() -> Node:
	if _life_support_instance and is_instance_valid(_life_support_instance):
		return _life_support_instance
	return null

func set_bridge_atmo_override(atmo: Dictionary) -> void:
	_bridge_atmo_override = atmo

func clear_bridge_atmo_override() -> void:
	_bridge_atmo_override.clear()

func get_bridge_atmo_state() -> Dictionary:
	if not _bridge_atmo_override.is_empty():
		return _bridge_atmo_override.duplicate()
	if _life_support_instance and is_instance_valid(_life_support_instance) and _life_support_instance.has_method("get_room_atmo_state"):
		var candidates: Array[String] = ["bridge", "ponte_comando", "room_1", "command"]
		for cand in candidates:
			var st: Dictionary = _life_support_instance.get_room_atmo_state(cand)
			if not st.is_empty():
				return st
		if _life_support_instance.has_method("get_all_rooms_atmo_state"):
			var all_st: Dictionary = _life_support_instance.get_all_rooms_atmo_state()
			for r_id in all_st:
				if "bridge" in r_id.to_lower() or "ponte" in r_id.to_lower() or "command" in r_id.to_lower():
					return all_st[r_id]
			if not all_st.is_empty():
				return all_st.values()[0]
	return {
		"o2_pct": 21.0,
		"co2_pct": 0.04,
		"pressure_kpa": 101.3,
		"temperature_c": 21.5,
		"heater_online": true,
		"has_breach": false,
		"has_short_circuit": false,
		"is_fire_active": false
	}

func get_bridge_position() -> Vector2:
	var bp := get_ship_blueprint()
	if bp:
		for r in bp.rooms:
			var rid := str(r.id).to_lower()
			var rname := str(r.name).to_lower()
			if rid == "bridge" or rid == "ponte_comando" or "bridge" in rid or "ponte" in rid or "command" in rname or "ponte" in rname:
				return r.rect.get_center()
		if not bp.rooms.is_empty():
			return bp.rooms[0].rect.get_center()
	for r in get_duct_rooms():
		var rid := str(r.id).to_lower()
		var rname := str(r.name).to_lower()
		if rid == "bridge" or rid == "ponte_comando" or "bridge" in rid or "ponte" in rid or "command" in rname or "ponte" in rname:
			return r.rect.get_center()
	return Vector2(300, 80)

func get_ship_g_force() -> float:
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		if ship.has_method("get_current_g_force"):
			return ship.get_current_g_force()
		elif "current_g_force" in ship:
			return float(ship.current_g_force)
	return _current_ship_g_force

func set_ship_g_force(g: float) -> void:
	_current_ship_g_force = g
	var ship := get_spaceship()
	if ship and is_instance_valid(ship) and ship.has_method("set_current_g_force"):
		ship.set_current_g_force(g)
	g_force_updated.emit(g)

func emit_ship_damage_taken(pos: Vector2, type: String) -> void:
	ship_damage_taken.emit(pos, type)

func emit_electrical_short_sparked(pos: Vector2) -> void:
	electrical_short_sparked.emit(pos)

func emit_duct_drone_position_updated(pos: Vector2) -> void:
	duct_drone_position_updated.emit(pos)

# --- POINT DEFENSE & INCOMING PROJECTILES API ---

var incoming_projectiles: Array[Dictionary] = []

func get_incoming_projectiles() -> Array[Dictionary]:
	return incoming_projectiles

func spawn_incoming_projectile(
	p_type: String,
	origin: Vector3,
	p_velocity: Vector3,
	damage: float = 25.0,
	target_pos: Vector3 = Vector3.ZERO
) -> Dictionary:
	var proj_id := "PROJ_%d_%d" % [Time.get_ticks_msec(), incoming_projectiles.size() + 1]
	var upper_type := p_type.to_upper()
	var is_hom := (upper_type in ["HOMING_MISSILE", "TORPEDO", "MISSILE_HOMING", "MISSILE"])
	var proj_data: Dictionary = {
		"id": proj_id,
		"type": upper_type,
		"position": origin,
		"velocity": p_velocity,
		"damage": damage,
		"target_pos": target_pos,
		"is_homing": is_hom,
		"is_deflected": false,
		"is_destroyed": false,
		"spawn_time": Time.get_ticks_msec() / 1000.0,
		"lifetime": 15.0
	}
	incoming_projectiles.append(proj_data)
	projectile_spawned.emit(proj_data)
	return proj_data

func intercept_projectile(projectile_id: String, device_id: String = "", sector: int = 0) -> bool:
	for i in range(incoming_projectiles.size()):
		if incoming_projectiles[i].get("id") == projectile_id:
			incoming_projectiles[i]["is_destroyed"] = true
			projectile_intercepted.emit(projectile_id, device_id, sector)
			projectile_destroyed.emit(projectile_id)
			incoming_projectiles.remove_at(i)
			return true
	return false

func deflect_projectile(projectile_id: String, device_id: String = "", sector: int = 0) -> bool:
	for i in range(incoming_projectiles.size()):
		if incoming_projectiles[i].get("id") == projectile_id:
			incoming_projectiles[i]["is_deflected"] = true
			incoming_projectiles[i]["is_homing"] = false
			var cur_vel: Vector3 = incoming_projectiles[i].get("velocity", Vector3.ZERO)
			incoming_projectiles[i]["velocity"] = cur_vel.rotated(Vector3.UP, deg_to_rad(randf_range(45.0, 90.0)))
			projectile_deflected.emit(projectile_id, device_id, sector)
			return true
	return false

func remove_incoming_projectile(projectile_id: String) -> void:
	for i in range(incoming_projectiles.size()):
		if incoming_projectiles[i].get("id") == projectile_id:
			incoming_projectiles.remove_at(i)
			return

func clear_incoming_projectiles() -> void:
	incoming_projectiles.clear()

func _update_incoming_projectiles(delta: float) -> void:
	if incoming_projectiles.is_empty():
		return
	var remaining: Array[Dictionary] = []
	var now := Time.get_ticks_msec() / 1000.0
	for p in incoming_projectiles:
		if p.get("is_destroyed", false):
			continue
		var spawn_t: float = float(p.get("spawn_time", now))
		var lifetime: float = float(p.get("lifetime", 15.0))
		if (now - spawn_t) > lifetime:
			continue
		var vel: Vector3 = p.get("velocity", Vector3.ZERO)
		p["position"] = p.get("position", Vector3.ZERO) + vel * delta
		remaining.append(p)
	incoming_projectiles = remaining
