class_name SpaceWorldManagerSingleton
extends Node

## Singleton / Manager per il mondo 3D dello spazio e i feed delle telecamere dell'astronave.

signal camera_window_opened(cam_id: String, window: FakeWindow)
signal camera_window_closed(cam_id: String)
signal camera_status_changed(cam_id: String, is_open: bool)
signal ship_connection_changed(is_connected: bool)
signal duct_drone_state_changed(pos: Vector2, heading: float, speed: float, battery: float, lights: bool, scan_active: bool, scan_radius: float)
signal duct_drone_reset_performed()
signal ship_damages_updated(damages: Array)
signal ship_damage_discovered(damage: Dictionary)
signal ship_damage_repaired(damage: Dictionary)
signal duct_drone_repair_state_changed(is_repairing: bool, damage_id: String, progress: float)
signal weapon_fired(weapon_type: String, origin: Vector3, target_pos: Vector3, hit_success: bool, target_id: String)
signal weapon_target_locked(target_id: String, target_data: Dictionary)

# --- SHIP DAMAGE TYPES & CONSTANTS ---
const DAMAGE_TYPE_BREACH: String = "breach"
const DAMAGE_TYPE_SHORT_CIRCUIT: String = "short_circuit"

const SPACE_SCENE_PATH := "res://Outside/space_scene.tscn"
const CAMERA_FEED_WINDOW_SCENE := "res://Applications/Cams/CameraFeed/camera_feed_window.tscn"

const CAMERAS_METADATA: Array[Dictionary] = [
	{
		"id": "front",
		"name": "Frontale",
		"code": "CAM 01 [PRUA]",
		"direction": "Prua (-Z)",
		"desc": "Visuale di navigazione anteriore",
		"icon": "▲"
	},
	{
		"id": "rear",
		"name": "Posteriore",
		"code": "CAM 02 [POPPA]",
		"direction": "Poppa (+Z)",
		"desc": "Visuale posteriore propulsori",
		"icon": "▼"
	},
	{
		"id": "left",
		"name": "Laterale Sinistra",
		"code": "CAM 03 [BABORDO]",
		"direction": "Babordo (-X)",
		"desc": "Visuale ala sinistra",
		"icon": "◀"
	},
	{
		"id": "right",
		"name": "Laterale Destra",
		"code": "CAM 04 [TRIBORDO]",
		"direction": "Tribordo (+X)",
		"desc": "Visuale ala destra",
		"icon": "▶"
	},
	{
		"id": "top",
		"name": "Superiore",
		"code": "CAM 05 [DORSALE]",
		"direction": "Dorsale (+Y)",
		"desc": "Visuale superiore / Zenit",
		"icon": "▲"
	},
	{
		"id": "bottom",
		"name": "Inferiore",
		"code": "CAM 06 [VENTRALE]",
		"direction": "Ventrale (-Y)",
		"desc": "Visuale inferiore / Nadir",
		"icon": "▼"
	}
]

# --- DUCT DRONE METADATA & CONSTANTS ---
const INITIAL_DUCT_DRONE_POS := Vector2(300, 80)
const INITIAL_DUCT_DRONE_HEADING := -PI * 0.5 # -90 gradi (Prua / Nord)
const DUCT_BASE_LINEAR_SPEED: float = 175.0
const DUCT_BASE_ROTATE_SPEED: float = 3.0
const DUCT_ACCELERATION: float = 650.0
const DUCT_DECELERATION: float = 750.0

const DUCT_ROOMS: Array[Dictionary] = [
	{
		"id": "bridge",
		"name": "Ponte di Comando",
		"rect": Rect2(230, 45, 140, 70),
		"color": Color(0.12, 0.28, 0.45, 0.55),
		"border_color": Color(0.35, 0.75, 1.0, 0.8)
	},
	{
		"id": "sensors",
		"name": "Sensori & Avionica",
		"rect": Rect2(110, 115, 100, 65),
		"color": Color(0.12, 0.35, 0.3, 0.5),
		"border_color": Color(0.2, 0.85, 0.65, 0.8)
	},
	{
		"id": "comms",
		"name": "Comunicazioni & EW",
		"rect": Rect2(390, 115, 100, 65),
		"color": Color(0.12, 0.35, 0.3, 0.5),
		"border_color": Color(0.2, 0.85, 0.65, 0.8)
	},
	{
		"id": "armory",
		"name": "Armeria & Sicurezza",
		"rect": Rect2(245, 135, 110, 60),
		"color": Color(0.35, 0.15, 0.2, 0.5),
		"border_color": Color(0.9, 0.35, 0.4, 0.8)
	},
	{
		"id": "quarters",
		"name": "Alloggi Equipaggio",
		"rect": Rect2(100, 200, 120, 75),
		"color": Color(0.22, 0.22, 0.35, 0.5),
		"border_color": Color(0.55, 0.55, 0.85, 0.8)
	},
	{
		"id": "cargo",
		"name": "Baia di Carico Principale",
		"rect": Rect2(380, 200, 120, 75),
		"color": Color(0.35, 0.28, 0.12, 0.5),
		"border_color": Color(0.95, 0.75, 0.25, 0.8)
	},
	{
		"id": "reactor",
		"name": "Nucleo Reattore & Fusione",
		"rect": Rect2(235, 215, 130, 80),
		"color": Color(0.35, 0.12, 0.35, 0.55),
		"border_color": Color(0.95, 0.35, 0.95, 0.9)
	},
	{
		"id": "engine",
		"name": "Sala Motori Principale",
		"rect": Rect2(185, 315, 230, 85),
		"color": Color(0.4, 0.2, 0.1, 0.55),
		"border_color": Color(1.0, 0.5, 0.2, 0.85)
	},
	{
		"id": "rcs_left",
		"name": "Pod RCS Sinistro",
		"rect": Rect2(30, 230, 50, 60),
		"color": Color(0.18, 0.25, 0.32, 0.5),
		"border_color": Color(0.4, 0.65, 0.85, 0.7)
	},
	{
		"id": "rcs_right",
		"name": "Pod RCS Destro",
		"rect": Rect2(520, 230, 50, 60),
		"color": Color(0.18, 0.25, 0.32, 0.5),
		"border_color": Color(0.4, 0.65, 0.85, 0.7)
	}
]

const DUCT_CORRIDORS: Array[Dictionary] = [
	{"from": Vector2(300, 115), "to": Vector2(300, 135), "width": 16.0, "name": "Condotto Dorsale Alpha"},
	{"from": Vector2(300, 195), "to": Vector2(300, 215), "width": 16.0, "name": "Condotto Reattore-Armeria"},
	{"from": Vector2(300, 295), "to": Vector2(300, 315), "width": 18.0, "name": "Condotto Termico Motori"},
	{"from": Vector2(230, 80), "to": Vector2(160, 80), "width": 14.0, "name": "Condotto Dati Sensori"},
	{"from": Vector2(160, 80), "to": Vector2(160, 115), "width": 14.0, "name": "Condotto Avionica"},
	{"from": Vector2(370, 80), "to": Vector2(440, 80), "width": 14.0, "name": "Condotto Linea Comms"},
	{"from": Vector2(440, 80), "to": Vector2(440, 115), "width": 14.0, "name": "Condotto EW Comms"},
	{"from": Vector2(160, 180), "to": Vector2(160, 200), "width": 14.0, "name": "Condotto Filtrazione SX"},
	{"from": Vector2(440, 180), "to": Vector2(440, 200), "width": 14.0, "name": "Condotto Linea Merci DX"},
	{"from": Vector2(220, 240), "to": Vector2(235, 240), "width": 14.0, "name": "Bypass Refrigerante SX"},
	{"from": Vector2(365, 240), "to": Vector2(380, 240), "width": 14.0, "name": "Bypass Refrigerante DX"},
	{"from": Vector2(100, 250), "to": Vector2(80, 250), "width": 14.0, "name": "Condotto RCS Sinistro"},
	{"from": Vector2(500, 250), "to": Vector2(520, 250), "width": 14.0, "name": "Condotto RCS Destro"},
	{"from": Vector2(160, 275), "to": Vector2(160, 350), "width": 14.0, "name": "Condotto Manutenzione SX"},
	{"from": Vector2(160, 350), "to": Vector2(185, 350), "width": 14.0, "name": "Accesso Motori SX"},
	{"from": Vector2(440, 275), "to": Vector2(440, 350), "width": 14.0, "name": "Condotto Manutenzione DX"},
	{"from": Vector2(440, 350), "to": Vector2(415, 350), "width": 14.0, "name": "Accesso Motori DX"}
]

# Stato sincronizzato del Duct Drone
var duct_drone_pos: Vector2 = INITIAL_DUCT_DRONE_POS
var duct_drone_heading: float = INITIAL_DUCT_DRONE_HEADING
var duct_drone_speed: float = 0.0
var duct_drone_battery: float = 100.0
var duct_drone_lights: bool = true
var duct_drone_scan_active: bool = false
var duct_drone_scan_radius: float = 0.0

var duct_drone_linear_input: float = 0.0
var duct_drone_angular_input: float = 0.0
var duct_drone_speed_mult: float = 1.0

# Danni strutturali e sistemici alla nave
var ship_damages: Array[Dictionary] = []
var is_duct_drone_repairing: bool = false
var repairing_damage_id: String = ""
var _next_damage_idx: int = 1

# Sublayer Blueprint unificato della nave
var active_ship_blueprint: ShipBlueprint = null

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
	"turbo_multiplier": 2.0,
	"precision_multiplier": 0.5,
	"is_dat_loaded": false
}
var _net_mgr: Node = null

func _ready() -> void:
	_init_space_world()
	generate_initial_ship_damages()
	call_deferred("_connect_network_signals")

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
	
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		ship.set_ship_connected(true)
		if not is_host:
			ship.set_network_client_mode(true)
		else:
			ship.set_network_client_mode(false)
	
	ship_connection_changed.emit(true)

func _on_network_mission_ended() -> void:
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		ship.set_ship_connected(false)
	
	close_all_camera_windows()
	stop_spaceship_engines()
	
	ship_connection_changed.emit(false)

func is_ship_connected() -> bool:
	var nm := _get_net_mgr()
	if nm and nm.has_method("is_ship_connected"):
		return nm.is_ship_connected()
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		return ship.is_ship_connected
	return false

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
	
	duct_drone_pos = INITIAL_DUCT_DRONE_POS
	duct_drone_heading = INITIAL_DUCT_DRONE_HEADING
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
	var base_rot_speed: float = float(_duct_drone_active_config.get("rotate_speed", DUCT_BASE_ROTATE_SPEED))
	var base_lin_speed: float = float(_duct_drone_active_config.get("linear_speed", DUCT_BASE_LINEAR_SPEED))
	var drain_move: float = float(_duct_drone_active_config.get("battery_drain_move", 0.35))
	var drain_lights: float = float(_duct_drone_active_config.get("battery_drain_lights", 0.75))
	var drain_radar: float = float(_duct_drone_active_config.get("battery_drain_radar", 3.5))
	var drain_repair: float = float(_duct_drone_active_config.get("battery_drain_repair", 6.0))
	var scan_max: float = float(_duct_drone_active_config.get("radar_scan_radius_max", 160.0))
	var repair_rng: float = float(_duct_drone_active_config.get("repair_range", 42.0))
	var repair_mult: float = float(_duct_drone_active_config.get("repair_speed_multiplier", 1.0)) * float(_duct_drone_active_config.get("repair_efficiency", 1.0))

	# 1. Rotazione Tank (gira sul posto)
	if absf(duct_drone_angular_input) > 0.01:
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
		# Ricarica al dock station se il robottino è fermo alla base
		if duct_drone_pos.distance_to(INITIAL_DUCT_DRONE_POS) < 30.0:
			var max_bat: float = float(_duct_drone_active_config.get("battery_max", 100.0))
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
		if dmg.get("repaired", false):
			continue
		
		var dmg_type: String = dmg.get("type", "")
		var dmg_pos: Vector2 = dmg.get("pos", Vector2.ZERO)
		var is_revealed: bool = dmg.get("revealed", false)
		
		if not is_revealed:
			if dmg_type == DAMAGE_TYPE_BREACH and duct_drone_lights:
				var dist := duct_drone_pos.distance_to(dmg_pos)
				if dist <= 35.0:
					dmg["revealed"] = true
					dmg["revealed_by"] = "light"
					damages_changed = true
					ship_damage_discovered.emit(dmg)
				elif dist <= 90.0:
					var to_dmg := (dmg_pos - duct_drone_pos).normalized()
					var forward := Vector2.from_angle(duct_drone_heading)
					var angle_diff := absf(forward.angle_to(to_dmg))
					if angle_diff <= 0.55: # cono fari (~31 gradi)
						dmg["revealed"] = true
						dmg["revealed_by"] = "light"
						damages_changed = true
						ship_damage_discovered.emit(dmg)
			
			elif dmg_type == DAMAGE_TYPE_SHORT_CIRCUIT and duct_drone_scan_active:
				var dist := duct_drone_pos.distance_to(dmg_pos)
				if dist <= duct_drone_scan_radius:
					dmg["revealed"] = true
					dmg["revealed_by"] = "radar"
					damages_changed = true
					ship_damage_discovered.emit(dmg)
	
	# 5. Elaborazione Riparazione in corso
	if is_duct_drone_repairing and repairing_damage_id != "":
		var target_dmg: Dictionary = {}
		for i in range(ship_damages.size()):
			if ship_damages[i].get("id") == repairing_damage_id:
				target_dmg = ship_damages[i]
				break
		
		if target_dmg.is_empty() or target_dmg.get("repaired", false):
			is_duct_drone_repairing = false
			repairing_damage_id = ""
			duct_drone_repair_state_changed.emit(false, "", 0.0)
		else:
			var d: float = duct_drone_pos.distance_to(target_dmg.get("pos", Vector2.ZERO))
			if d > repair_rng or duct_drone_battery <= 0.0:
				# Troppo lontano o batteria esaurita: interrompi riparazione
				is_duct_drone_repairing = false
				repairing_damage_id = ""
				duct_drone_repair_state_changed.emit(false, "", float(target_dmg.get("repair_progress", 0.0)))
			else:
				var duration: float = maxf(1.0, float(target_dmg.get("repair_duration", 5.0)))
				var progress: float = float(target_dmg.get("repair_progress", 0.0))
				progress = clampf(progress + ((delta * repair_mult) / duration), 0.0, 1.0)
				target_dmg["repair_progress"] = progress
				duct_drone_repair_state_changed.emit(true, repairing_damage_id, progress)
				
				if progress >= 1.0:
					target_dmg["repaired"] = true
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

func _constrain_duct_drone_movement(old_pos: Vector2, new_pos: Vector2) -> Vector2:
	if _is_duct_drone_position_valid(new_pos):
		return new_pos
	
	var test_x := Vector2(new_pos.x, old_pos.y)
	if _is_duct_drone_position_valid(test_x):
		return test_x
	
	var test_y := Vector2(old_pos.x, new_pos.y)
	if _is_duct_drone_position_valid(test_y):
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

## Ritorna le stanze della nave da ShipBlueprint o fallback a costanti
func get_duct_rooms() -> Array[Dictionary]:
	var bp := get_ship_blueprint()
	if bp and bp.rooms.size() > 0:
		return bp.rooms
	return DUCT_ROOMS

## Ritorna i condotti della nave da ShipBlueprint o fallback a costanti
func get_duct_corridors() -> Array[Dictionary]:
	var bp := get_ship_blueprint()
	if bp and bp.ducts.size() > 0:
		return bp.ducts
	return DUCT_CORRIDORS

## Ritorna i dispositivi elettrici della nave da ShipBlueprint
func get_power_devices() -> Array[Dictionary]:
	var bp := get_ship_blueprint()
	if bp and bp.devices.size() > 0:
		return bp.devices
	return []

## Ritorna gli snodi elettrici della nave da ShipBlueprint
func get_power_junctions() -> Array[Dictionary]:
	var bp := get_ship_blueprint()
	if bp and bp.junctions.size() > 0:
		return bp.junctions
	return []

## Ritorna le zone/punti di danno predefiniti della nave da ShipBlueprint
func get_damage_zones() -> Array[Dictionary]:
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
func get_ship_drive_files() -> Array[Dictionary]:
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
func get_installed_apps() -> Array[Dictionary]:
	var bp := get_ship_blueprint()
	if bp and bp.installed_apps.size() > 0:
		return bp.installed_apps
	var def_bp := ShipBlueprint.get_default_blueprint()
	if def_bp:
		return def_bp.installed_apps
	return []

## Ritorna le applicazioni mainframe installate filtrate per il ruolo del giocatore
func get_installed_apps_for_role(role_name: String, is_solo: bool = false) -> Array[Dictionary]:
	var bp := get_ship_blueprint()
	if bp and bp.installed_apps.size() > 0:
		return bp.get_apps_for_role(role_name, is_solo)
	var def_bp := ShipBlueprint.get_default_blueprint()
	if def_bp:
		return def_bp.get_apps_for_role(role_name, is_solo)
	return []

func _is_duct_drone_position_valid(pos: Vector2) -> bool:
	for room in get_duct_rooms():
		var r: Rect2 = room["rect"]
		if r.grow(-2.0).has_point(pos):
			return true
	
	for duct in get_duct_corridors():
		var p1: Vector2 = duct["from"]
		var p2: Vector2 = duct["to"]
		var width: float = float(duct.get("width", 14.0))
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
	duct_drone_pos = INITIAL_DUCT_DRONE_POS
	duct_drone_heading = INITIAL_DUCT_DRONE_HEADING
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

func get_ship_damages() -> Array[Dictionary]:
	return ship_damages

func get_active_ship_damages() -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	for dmg in ship_damages:
		if not dmg.get("repaired", false):
			active.append(dmg)
	return active

func get_damage_by_id(dmg_id: String) -> Dictionary:
	for dmg in ship_damages:
		if dmg.get("id") == dmg_id:
			return dmg
	return {}

func get_adjacent_damage(pos: Vector2, max_dist: float = 38.0) -> Dictionary:
	var closest: Dictionary = {}
	var min_d := max_dist
	for dmg in ship_damages:
		if dmg.get("repaired", false):
			continue
		var d: float = pos.distance_to(dmg.get("pos", Vector2.ZERO))
		if d <= min_d:
			min_d = d
			closest = dmg
	return closest

func spawn_ship_damage(type: String = "", pos: Vector2 = Vector2.ZERO, sector_name: String = "", duration: float = 0.0) -> Dictionary:
	var nm := _get_net_mgr()
	if nm and nm.get("is_connected_to_network") and not nm.get("is_host"):
		return {}
	
	if type == "":
		type = DAMAGE_TYPE_BREACH if randf() < 0.5 else DAMAGE_TYPE_SHORT_CIRCUIT
	
	if pos == Vector2.ZERO:
		var bp_rooms := get_duct_rooms()
		var bp_ducts := get_duct_corridors()
		if randf() < 0.6 and bp_rooms.size() > 0:
			var room: Dictionary = bp_rooms.pick_random()
			var r: Rect2 = room["rect"]
			pos = Vector2(
				randf_range(r.position.x + 10, r.position.x + r.size.x - 10),
				randf_range(r.position.y + 10, r.position.y + r.size.y - 10)
			)
			if sector_name == "":
				sector_name = room.get("name", "Settore Nave")
		elif bp_ducts.size() > 0:
			var duct: Dictionary = bp_ducts.pick_random()
			var p1: Vector2 = duct["from"]
			var p2: Vector2 = duct["to"]
			var t := randf_range(0.2, 0.8)
			pos = p1.lerp(p2, t)
			if sector_name == "":
				sector_name = duct.get("name", "Condotto")

	if duration <= 0.0:
		duration = randf_range(3.0, 8.0)

	var dmg_id := "dmg_%d" % _next_damage_idx
	_next_damage_idx += 1

	var dmg_dict: Dictionary = {
		"id": dmg_id,
		"type": type,
		"pos": pos,
		"sector": sector_name if sector_name != "" else "Condotto / Scafo",
		"revealed": false,
		"revealed_by": "",
		"repair_progress": 0.0,
		"repair_duration": duration,
		"repaired": false
	}

	ship_damages.append(dmg_dict)
	ship_damages_updated.emit(ship_damages)

	if nm and nm.get("is_connected_to_network") and nm.get("is_host"):
		if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
			_rpc_sync_ship_damages.rpc(ship_damages)

	return dmg_dict

func generate_initial_ship_damages(count: int = 4) -> void:
	ship_damages.clear()
	_next_damage_idx = 1

	var bp_damages := get_damage_zones()
	if bp_damages.size() > 0:
		var num := mini(count, bp_damages.size())
		for i in range(num):
			var d: Dictionary = bp_damages[i]
			var dmg_type: String = str(d.get("type", DAMAGE_TYPE_SHORT_CIRCUIT))
			var dmg_pos: Vector2 = d.get("pos", Vector2.ZERO)
			var dmg_sector: String = str(d.get("sector", d.get("name", "Settore Nave")))
			var dmg_dur: float = float(d.get("repair_cost", d.get("duration", 5.0)))
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
	
	var dmg := get_damage_by_id(damage_id)
	if dmg.is_empty() or dmg.get("repaired", false) or duct_drone_battery <= 0.0:
		return
	
	var d: float = duct_drone_pos.distance_to(dmg.get("pos", Vector2.ZERO))
	var repair_rng: float = float(_duct_drone_active_config.get("repair_range", 42.0))
	if d > repair_rng:
		return
	
	is_duct_drone_repairing = true
	repairing_damage_id = damage_id
	var progress: float = float(dmg.get("repair_progress", 0.0))
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
func _rpc_sync_ship_damages(damages: Array) -> void:
	ship_damages = damages
	ship_damages_updated.emit(ship_damages)

@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_sync_repair_state(is_repairing: bool, damage_id: String, progress: float) -> void:
	is_duct_drone_repairing = is_repairing
	repairing_damage_id = damage_id
	for dmg in ship_damages:
		if dmg.get("id") == damage_id:
			dmg["repair_progress"] = progress
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

func get_cameras_info() -> Array[Dictionary]:
	return CAMERAS_METADATA

func get_camera_info(cam_id: String) -> Dictionary:
	for c in CAMERAS_METADATA:
		if c["id"] == cam_id:
			return c
	return {}

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
	var title: String = "%s - Feed Esterno" % [cam_info.get("code", "CAM FEED")]
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
	for c in CAMERAS_METADATA:
		open_camera_window(c["id"])

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
	
	# Ordina per distanza crescente
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("distance", 0.0) < b.get("distance", 0.0)
	)
	return targets

## Verifica se il sottosistema Armeria (Sublayer 3) riceve alimentazione sufficiente
func is_armory_powered() -> bool:
	var devices := get_power_devices()
	for dev in devices:
		if dev.get("id", "") == "armory_defense":
			return dev.get("inputs_powered", 1) > 0
	return true

## Esegue una richiesta di fuoco per il tipo d'arma specificato
func request_fire_weapon(weapon_type: String, target_id: String = "", manual_aim_dir: Vector3 = Vector3.ZERO) -> Dictionary:
	var ship := get_spaceship()
	var origin: Vector3 = ship.global_position if ship and is_instance_valid(ship) and ship.is_inside_tree() else Vector3.ZERO
	var target_pos: Vector3 = origin + (manual_aim_dir * 100.0 if manual_aim_dir.length_squared() > 0.01 else Vector3(0, 0, -100))
	var hit_success: bool = false
	
	if not target_id.is_empty():
		for t in get_weapon_targets():
			if t.get("id", "") == target_id:
				target_pos = t.get("pos", target_pos)
				hit_success = true
				break
	
	weapon_fired.emit(weapon_type, origin, target_pos, hit_success, target_id)
	return {
		"weapon_type": weapon_type,
		"origin": origin,
		"target_pos": target_pos,
		"hit_success": hit_success,
		"target_id": target_id
	}
