class_name Spaceship
extends RigidBody3D

## Gestione dell'astronave, mount telecamere esterne e controlli di movimento e rotazione.

signal flight_telemetry_updated(speed: float, position: Vector3, velocity: Vector3, orientation: Vector3)

@export var max_linear_speed: float = 20.0
@export var linear_acceleration: float = 35.0
@export var linear_deceleration: float = 20.0

@export var max_angular_speed: float = 2.5
@export var angular_acceleration: float = 8.0
@export var angular_deceleration: float = 6.0

@onready var cam_front: Marker3D = get_node_or_null("CameraMounts/CamFront")
@onready var cam_rear: Marker3D = get_node_or_null("CameraMounts/CamRear")
@onready var cam_left: Marker3D = get_node_or_null("CameraMounts/CamLeft")
@onready var cam_right: Marker3D = get_node_or_null("CameraMounts/CamRight")
@onready var cam_top: Marker3D = get_node_or_null("CameraMounts/CamTop")
@onready var cam_bottom: Marker3D = get_node_or_null("CameraMounts/CamBottom")

@onready var engine_light: OmniLight3D = get_node_or_null("Model/EngineLight")

var _time_elapsed: float = 0.0
var _camera_mounts: Dictionary = {}

# Input attuali (in coordinate locali nave)
# linear_input: Vector3(X: strife sx/dx [-1..1], Y: strife giu/su [-1..1], Z: avanti/indietro [-1..1, -1 = avanti / +1 = indietro])
var linear_input: Vector3 = Vector3.ZERO
# angular_input: Vector3(X: beccheggio su/giu [+1..-1], Y: imbardata sx/dx [+1..-1], Z: rollio sx/dx [+1..-1])
var angular_input: Vector3 = Vector3.ZERO

var initial_transform: Transform3D = Transform3D.IDENTITY

# Sistema di Propulsione a Velocità di Crociera (Cruise Mode)
var cruise_controller: Node = null

# Proprietà per la sincronizzazione di rete e stato di connessione
var is_ship_connected: bool = false
var is_network_client: bool = false
var target_synced_transform: Transform3D = Transform3D.IDENTITY
var target_synced_linear_velocity: Vector3 = Vector3.ZERO
var target_synced_angular_velocity: Vector3 = Vector3.ZERO

signal ship_connection_changed(is_connected: bool)

func _ready() -> void:
	initial_transform = transform
	_init_camera_mounts()

func _init_camera_mounts() -> void:
	var mounts_parent := get_node_or_null("CameraMounts")
	if mounts_parent == null:
		mounts_parent = Node3D.new()
		mounts_parent.name = "CameraMounts"
		add_child(mounts_parent)
	
	_camera_mounts = {
		"front": _ensure_mount(mounts_parent, "CamFront", Vector3(0.0, 0.25, -2.1), Vector3(0.0, 0.0, 0.0)),
		"rear": _ensure_mount(mounts_parent, "CamRear", Vector3(0.0, 0.6, 2.2), Vector3(0.0, 180.0, 0.0)),
		"left": _ensure_mount(mounts_parent, "CamLeft", Vector3(-2.0, 0.1, 0.0), Vector3(0.0, 90.0, 0.0)),
		"right": _ensure_mount(mounts_parent, "CamRight", Vector3(2.0, 0.1, 0.0), Vector3(0.0, -90.0, 0.0)),
		"top": _ensure_mount(mounts_parent, "CamTop", Vector3(0.0, 1.2, -0.2), Vector3(90.0, 0.0, 0.0)),
		"bottom": _ensure_mount(mounts_parent, "CamBottom", Vector3(0.0, -0.8, -0.2), Vector3(-90.0, 0.0, 0.0))
	}

func _ensure_mount(parent: Node, node_name: String, local_pos: Vector3, local_rot_deg: Vector3) -> Marker3D:
	var marker: Marker3D = parent.get_node_or_null(node_name)
	if marker == null:
		marker = Marker3D.new()
		marker.name = node_name
		marker.position = local_pos
		marker.rotation_degrees = local_rot_deg
		parent.add_child(marker)
	else:
		marker.position = local_pos
		marker.rotation_degrees = local_rot_deg
	return marker

func get_camera_mount(cam_id: String) -> Marker3D:
	if _camera_mounts.is_empty():
		_init_camera_mounts()
	return _camera_mounts.get(cam_id, null)

func get_cruise_controller() -> Node:
	if cruise_controller and is_instance_valid(cruise_controller):
		return cruise_controller
	var found := get_node_or_null("CruiseDriveController")
	if found:
		cruise_controller = found
		return cruise_controller
	return null

func set_cruise_controller(controller: Node) -> void:
	cruise_controller = controller

func get_camera_global_transform(cam_id: String) -> Transform3D:
	var mount: Marker3D = get_camera_mount(cam_id)
	if mount and is_instance_valid(mount) and mount.is_inside_tree():
		return mount.global_transform
	
	# Fallback calcolato al volo su base locale
	var local_trans := Transform3D.IDENTITY
	match cam_id:
		"front":
			local_trans = Transform3D(Basis.from_euler(Vector3(0, 0, 0)), Vector3(0.0, 0.25, -2.1))
		"rear":
			local_trans = Transform3D(Basis.from_euler(Vector3(0, PI, 0)), Vector3(0.0, 0.6, 2.2))
		"left":
			local_trans = Transform3D(Basis.from_euler(Vector3(0, PI * 0.5, 0)), Vector3(-2.0, 0.1, 0.0))
		"right":
			local_trans = Transform3D(Basis.from_euler(Vector3(0, -PI * 0.5, 0)), Vector3(2.0, 0.1, 0.0))
		"top":
			local_trans = Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(0.0, 1.2, -0.2))
		"bottom":
			local_trans = Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0, 0)), Vector3(0.0, -0.8, -0.2))
	
	if is_inside_tree():
		return global_transform * local_trans
	return transform * local_trans

func _physics_process(delta: float) -> void:
	if is_network_client:
		_apply_client_interpolation(delta)
	else:
		_apply_flight_physics(delta)
	
	var cur_pos := global_position if is_inside_tree() else position
	flight_telemetry_updated.emit(linear_velocity.length(), cur_pos, linear_velocity, rotation_degrees)

func _apply_client_interpolation(delta: float) -> void:
	var cur_trans := global_transform if is_inside_tree() else transform
	var t_weight: float = clampf(25.0 * delta, 0.0, 1.0)
	var next_trans := cur_trans.interpolate_with(target_synced_transform, t_weight)
	if is_inside_tree():
		global_transform = next_trans
	else:
		transform = next_trans
	
	linear_velocity = target_synced_linear_velocity
	angular_velocity = target_synced_angular_velocity

func set_ship_connected(connected: bool) -> void:
	if is_ship_connected != connected:
		is_ship_connected = connected
		ship_connection_changed.emit(connected)

func get_is_ship_connected() -> bool:
	return is_ship_connected

func set_network_client_mode(is_client: bool) -> void:
	is_network_client = is_client
	freeze = is_client
	if is_client:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		target_synced_transform = global_transform if is_inside_tree() else transform
		target_synced_linear_velocity = linear_velocity
		target_synced_angular_velocity = angular_velocity
	else:
		pass

func apply_synced_state(pos: Vector3, quat: Quaternion, lin_vel: Vector3, ang_vel: Vector3, lin_in: Vector3, ang_in: Vector3) -> void:
	if not is_network_client:
		set_network_client_mode(true)
	
	target_synced_transform = Transform3D(Basis(quat), pos)
	target_synced_linear_velocity = lin_vel
	target_synced_angular_velocity = ang_vel
	linear_input = lin_in
	angular_input = ang_in
	linear_velocity = lin_vel
	angular_velocity = ang_vel
	
	# Se la distanza è notevole (es. join iniziale o reset), salta l'interpolazione per allineamento immediato
	var cur_origin := global_position if is_inside_tree() else position
	if cur_origin.distance_squared_to(pos) > 100.0:
		if is_inside_tree():
			global_transform = target_synced_transform
		else:
			transform = target_synced_transform

func get_network_state() -> Dictionary:
	var cur_trans := global_transform if is_inside_tree() else transform
	var quat := cur_trans.basis.get_rotation_quaternion()
	return {
		"pos": cur_trans.origin,
		"quat": [quat.x, quat.y, quat.z, quat.w],
		"lin_vel": linear_velocity,
		"ang_vel": angular_velocity,
		"lin_in": linear_input,
		"ang_in": angular_input
	}

func _apply_flight_physics(delta: float) -> void:
	# Se Cruise Mode è attiva o RCS è bloccato da cruise controller, non applicare i controlli RCS ordinari
	if cruise_controller and is_instance_valid(cruise_controller):
		var ctrl_state: int = int(cruise_controller.get("current_state"))
		var rcs_locked: bool = bool(cruise_controller.get("is_rcs_locked"))
		if ctrl_state == 2 or rcs_locked: # 2 = State.ENGAGED
			return
	
	var cur_basis := global_transform.basis if is_inside_tree() else transform.basis
	
	# Calcola velocità target locale
	var target_local_vel := Vector3.ZERO
	target_local_vel.x = linear_input.x * max_linear_speed
	target_local_vel.y = linear_input.y * max_linear_speed
	target_local_vel.z = linear_input.z * max_linear_speed
	
	# Converti nel frame di riferimento globale usando la basis della nave
	var target_global_vel := cur_basis * target_local_vel
	
	if linear_input.length_squared() > 0.001:
		linear_velocity = linear_velocity.move_toward(target_global_vel, linear_acceleration * delta)
	else:
		linear_velocity = linear_velocity.move_toward(Vector3.ZERO, linear_deceleration * delta)
	
	# Rotazioni angolari
	var target_local_ang := Vector3.ZERO
	# Pitch (Up/Down) attorno all'asse X locale
	target_local_ang.x = angular_input.x * max_angular_speed
	# Yaw (Left/Right) attorno all'asse Y locale
	target_local_ang.y = angular_input.y * max_angular_speed
	# Roll attorno all'asse Z locale
	target_local_ang.z = angular_input.z * max_angular_speed
	
	var target_global_ang := cur_basis * target_local_ang
	
	if angular_input.length_squared() > 0.001:
		angular_velocity = angular_velocity.move_toward(target_global_ang, angular_acceleration * delta)
	else:
		angular_velocity = angular_velocity.move_toward(Vector3.ZERO, angular_deceleration * delta)

func set_linear_input(input_vec: Vector3) -> void:
	linear_input = input_vec.clamp(Vector3(-2, -2, -2), Vector3(2, 2, 2))

func set_angular_input(rot_vec: Vector3) -> void:
	angular_input = rot_vec.clamp(Vector3(-2, -2, -2), Vector3(2, 2, 2))

func set_flight_inputs(move_vec: Vector3, rot_vec: Vector3) -> void:
	set_linear_input(move_vec)
	set_angular_input(rot_vec)

func stop_engines() -> void:
	linear_input = Vector3.ZERO
	angular_input = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func reset_to_origin() -> void:
	stop_engines()
	transform = initial_transform

func _process(delta: float) -> void:
	_time_elapsed += delta
	# Effetto pulsazione reattore con incremento durante la spinta in avanti
	if engine_light:
		var thrust_boost: float = clampf(-linear_input.z, 0.0, 1.0) * 2.5
		engine_light.light_energy = 2.2 + sin(_time_elapsed * 8.0) * 0.4 + thrust_boost
