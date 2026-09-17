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

@export var inertia_dampening: bool = true

@onready var cam_front: Marker3D = get_node_or_null("CameraMounts/CamFront")
@onready var cam_rear: Marker3D = get_node_or_null("CameraMounts/CamRear")
@onready var cam_left: Marker3D = get_node_or_null("CameraMounts/CamLeft")
@onready var cam_right: Marker3D = get_node_or_null("CameraMounts/CamRight")
@onready var cam_top: Marker3D = get_node_or_null("CameraMounts/CamTop")
@onready var cam_bottom: Marker3D = get_node_or_null("CameraMounts/CamBottom")

@onready var engine_light: OmniLight3D = get_node_or_null("Model/EngineLight")

var _time_elapsed: float = 0.0
var _camera_mounts: Dictionary = {}
var _headlights: Dictionary = {}

# Input attuali (in coordinate locali nave)
# linear_input: Vector3(X: strife sx/dx [-1..1], Y: strife giu/su [-1..1], Z: avanti/indietro [-1..1, -1 = avanti / +1 = indietro])
var linear_input: Vector3 = Vector3.ZERO
# angular_input: Vector3(X: beccheggio su/giu [+1..-1], Y: imbardata sx/dx [+1..-1], Z: rollio sx/dx [+1..-1])
var angular_input: Vector3 = Vector3.ZERO

var initial_transform: Transform3D = Transform3D.IDENTITY

# Sistema di Propulsione a Velocità di Crociera (Cruise Mode)
var cruise_controller: Node = null
var current_g_force: float = 1.0
var cyber_drift_intensity: float = 0.0
var _cyber_drift_noise_timer: float = 0.0

func get_current_g_force() -> float:
	return current_g_force

func set_current_g_force(g: float) -> void:
	current_g_force = g

# Proprietà per la sincronizzazione di rete e stato di connessione
var is_ship_connected: bool = false
var is_network_client: bool = false
var target_synced_transform: Transform3D = Transform3D.IDENTITY
var target_synced_linear_velocity: Vector3 = Vector3.ZERO
var target_synced_angular_velocity: Vector3 = Vector3.ZERO

# Blocco cinematico del movimento (es. durante l'attracco a una stazione)
var movement_locked: bool = false

signal ship_connection_changed(is_connected: bool)
signal cargo_stowed_in_ship(item_data: Dictionary)

var cargo_hatch_area: Area3D = null
var cargo_manager: Node = null
const CARGO_HATCH_OFFSET_LOCAL: Vector3 = Vector3(0.0, -1.8, 3.2)
const CARGO_HATCH_RADIUS: float = 8.0

func _ready() -> void:
	add_to_group("spaceship")
	initial_transform = transform
	_init_camera_mounts()
	_init_cargo_hatch()

func _init_camera_mounts() -> void:
	var mounts_parent := get_node_or_null("CameraMounts")
	if mounts_parent == null:
		mounts_parent = Node3D.new()
		mounts_parent.name = "CameraMounts"
		add_child(mounts_parent)
	
	_camera_mounts = {
		"front": _ensure_mount(mounts_parent, "CamFront", Vector3(0.0, 0.25, -2.1), Vector3(0.0, 0.0, 0.0), "front"),
		"rear": _ensure_mount(mounts_parent, "CamRear", Vector3(0.0, 0.6, 2.2), Vector3(0.0, 180.0, 0.0), "rear"),
		"left": _ensure_mount(mounts_parent, "CamLeft", Vector3(-2.0, 0.1, 0.0), Vector3(0.0, 90.0, 0.0), "left"),
		"right": _ensure_mount(mounts_parent, "CamRight", Vector3(2.0, 0.1, 0.0), Vector3(0.0, -90.0, 0.0), "right"),
		"top": _ensure_mount(mounts_parent, "CamTop", Vector3(0.0, 1.2, -0.2), Vector3(90.0, 0.0, 0.0), "top"),
		"bottom": _ensure_mount(mounts_parent, "CamBottom", Vector3(0.0, -0.8, -0.2), Vector3(-90.0, 0.0, 0.0), "bottom")
	}

func _ensure_mount(parent: Node, node_name: String, local_pos: Vector3, local_rot_deg: Vector3, cam_id: String = "") -> Marker3D:
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
	
	# Assicura il faretto (SpotLight3D) associato alla telecamera
	var headlight: SpotLight3D = marker.get_node_or_null("Headlight")
	if headlight == null:
		headlight = SpotLight3D.new()
		headlight.name = "Headlight"
		headlight.visible = false
		headlight.light_energy = 3.5
		headlight.spot_range = 80.0
		headlight.spot_angle = 45.0
		headlight.light_color = Color(0.9, 0.95, 1.0)
		marker.add_child(headlight)
	
	if not cam_id.is_empty():
		_headlights[cam_id] = headlight
	
	return marker

func set_headlight(cam_id: String, enabled: bool) -> void:
	if _headlights.is_empty():
		_init_camera_mounts()
	var light: SpotLight3D = _headlights.get(cam_id, null)
	if light and is_instance_valid(light):
		light.visible = enabled

func is_headlight_on(cam_id: String) -> bool:
	if _headlights.is_empty():
		_init_camera_mounts()
	var light: SpotLight3D = _headlights.get(cam_id, null)
	if light and is_instance_valid(light):
		return light.visible
	return false

func toggle_headlight(cam_id: String) -> bool:
	var new_state := not is_headlight_on(cam_id)
	set_headlight(cam_id, new_state)
	return new_state

func get_headlight(cam_id: String) -> SpotLight3D:
	if _headlights.is_empty():
		_init_camera_mounts()
	return _headlights.get(cam_id, null)

func set_all_headlights(enabled: bool) -> void:
	if _headlights.is_empty():
		_init_camera_mounts()
	for cid in _headlights:
		var light: SpotLight3D = _headlights[cid]
		if light and is_instance_valid(light):
			light.visible = enabled

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

func _init_cargo_hatch() -> void:
	if cargo_hatch_area != null and is_instance_valid(cargo_hatch_area):
		return
	cargo_hatch_area = get_node_or_null("CargoHatchArea3D") as Area3D
	if cargo_hatch_area == null:
		cargo_hatch_area = Area3D.new()
		cargo_hatch_area.name = "CargoHatchArea3D"
		cargo_hatch_area.position = CARGO_HATCH_OFFSET_LOCAL
		
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var sphere := SphereShape3D.new()
		sphere.radius = CARGO_HATCH_RADIUS
		col.shape = sphere
		cargo_hatch_area.add_child(col)
		add_child(cargo_hatch_area)
		
	if not cargo_hatch_area.body_entered.is_connected(_on_cargo_hatch_body_entered):
		cargo_hatch_area.body_entered.connect(_on_cargo_hatch_body_entered)

func get_cargo_hatch() -> Area3D:
	if cargo_hatch_area == null:
		_init_cargo_hatch()
	return cargo_hatch_area

func _on_cargo_hatch_body_entered(body: Node3D) -> void:
	if body is CargoContainerEntity and is_instance_valid(body) and not body.is_collected:
		intake_cargo_container(body)
	elif body is MineralDepositEntity and is_instance_valid(body) and not body.is_collected:
		intake_mineral_deposit(body)

func get_cargo_manager() -> Node:
	if cargo_manager and is_instance_valid(cargo_manager):
		return cargo_manager
	if is_inside_tree():
		var cm = get_node_or_null("/root/CargoManager")
		if cm:
			return cm
		var cms := get_tree().get_nodes_in_group("cargo_managers")
		if not cms.is_empty():
			return cms[0]
	return null

## Prende in carico un deposito minerario, verificando la capienza in CargoManager
func intake_mineral_deposit(deposit: MineralDepositEntity) -> bool:
	if deposit == null or not is_instance_valid(deposit) or deposit.is_collected:
		return false
		
	var res_dict: Dictionary = deposit.get_resource_dict()
	var cm = get_cargo_manager()
	
	var success := false
	if cm and cm.has_method("add_item"):
		success = cm.add_item(res_dict, 1)
	else:
		success = true # Fallback se CargoManager non presente nell'albero
		
	if success:
		deposit.stop_magnetic_attraction()
		deposit.complete_collection(self)
		cargo_stowed_in_ship.emit(res_dict)
		if SpaceWorldManager and SpaceWorldManager.has_signal("cargo_stowed_in_ship"):
			SpaceWorldManager.cargo_stowed_in_ship.emit(res_dict)
		if SpaceWorldManager and SpaceWorldManager.has_method("_send_spawn_notification"):
			SpaceWorldManager._send_spawn_notification("Minerale stivato: %s (%.1f kg)" % [res_dict.get("name", "Minerale"), float(res_dict.get("mass_kg", 25.0))])
		return true
	else:
		if SpaceWorldManager and SpaceWorldManager.has_method("report_system_alert"):
			SpaceWorldManager.report_system_alert("ALLARME: Stiva satura, impossibile imbarcare minerale %s" % res_dict.get("name", "Minerale"))
		return false

## Prende in carico un container cargo, verificando la capienza in CargoManager
func intake_cargo_container(container: CargoContainerEntity) -> bool:
	if container == null or not is_instance_valid(container) or container.is_collected:
		return false
		
	var item_dict: Dictionary = container.get_cargo_item_dict()
	var qty: int = int(item_dict.get("quantity", 1))
	
	# Verifica e inserimento in CargoManager
	var cm = get_cargo_manager()
		
	var success := false
	if cm and cm.has_method("add_item"):
		success = cm.add_item(item_dict, qty)
	else:
		success = true # Fallback se CargoManager non presente nell'albero
		
	if success:
		# Sgancio del drone se rimorchiato
		if container.latched_to != null and is_instance_valid(container.latched_to):
			if container.latched_to.has_method("unlatch_cargo"):
				container.latched_to.unlatch_cargo()
			else:
				container.unlatch()
		else:
			container.unlatch()
			
		container.mark_collected(self)
		cargo_stowed_in_ship.emit(item_dict)
		if SpaceWorldManager and SpaceWorldManager.has_signal("cargo_stowed_in_ship"):
			SpaceWorldManager.cargo_stowed_in_ship.emit(item_dict)
		if SpaceWorldManager and SpaceWorldManager.has_method("_send_spawn_notification"):
			SpaceWorldManager._send_spawn_notification("Carico stivato: %s (%d u.)" % [item_dict.get("name", "Container"), qty])
		return true
	else:
		# Stiva satura: allarme diegetico e carico mantenuto
		if SpaceWorldManager and SpaceWorldManager.has_method("report_system_alert"):
			SpaceWorldManager.report_system_alert("ALLARME: Stiva satura, impossibile imbarcare %s" % item_dict.get("name", "Carico"))
		return false

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
	
	_update_g_force(delta)
	
	var cur_pos := global_position if is_inside_tree() else position
	flight_telemetry_updated.emit(linear_velocity.length(), cur_pos, linear_velocity, rotation_degrees)

func _update_g_force(delta: float) -> void:
	if cruise_controller and is_instance_valid(cruise_controller):
		var ctrl_state: int = int(cruise_controller.get("current_state"))
		if ctrl_state == 1: # WARMUP
			current_g_force = 3.5
			return
		elif ctrl_state == 2: # ENGAGED
			current_g_force = 6.2
			return
		elif ctrl_state == 4: # EMERGENCY_DROP
			if current_g_force < 1.0:
				current_g_force = move_toward(current_g_force, 1.0, delta * 4.8)
				return

	var target_g := 1.0
	if linear_input.length_squared() > 0.001:
		var vert_accel := linear_input.y * (linear_acceleration / 9.8)
		var ang_accel := pow(angular_input.x, 2) * (angular_acceleration / 9.8)
		target_g = 1.0 + ang_accel * 2 + vert_accel * 0.5
	current_g_force = move_toward(current_g_force, target_g, delta * 4.0)

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

func set_movement_locked(locked: bool) -> void:
	movement_locked = locked
	if locked:
		stop_engines()

func get_movement_locked() -> bool:
	return movement_locked

func is_movement_locked() -> bool:
	return movement_locked

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
	# Blocco cinematico esterno (es. attracco a stazione): annulla ogni movimento residuo
	if movement_locked:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		return
	
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
	elif inertia_dampening:
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

	# Se PROPULSION_WORM o drift cyber è attivo, applica la perturbazione
	if cyber_drift_intensity > 0.0:
		apply_cyber_drift(delta, cyber_drift_intensity)
	elif is_inside_tree():
		var cd = get_tree().get_first_node_in_group("combat_directors")
		if cd and cd.has_method("is_exploit_active") and cd.is_exploit_active("PROPULSION_WORM"):
			apply_cyber_drift(delta, 1.0)

## Applica una perturbazione/deriva cyber incontrollata ai controlli di volo (PROPULSION_WORM)
func apply_cyber_drift(delta: float, intensity: float = 1.0) -> void:
	cyber_drift_intensity = intensity
	_cyber_drift_noise_timer += delta
	var cur_basis := global_transform.basis if is_inside_tree() else transform.basis
	# Coppia di deriva angolare erratica
	var drift_torque := Vector3(
		sin(_cyber_drift_noise_timer * 2.3) * 0.8,
		cos(_cyber_drift_noise_timer * 1.7) * 0.9,
		sin(_cyber_drift_noise_timer * 3.1) * 0.4
	) * intensity * max_angular_speed * 0.6
	
	# Forza lineare di deriva erratica
	var drift_force := Vector3(
		cos(_cyber_drift_noise_timer * 1.5) * 0.5,
		sin(_cyber_drift_noise_timer * 2.0) * 0.3,
		sin(_cyber_drift_noise_timer * 1.1) * 0.7
	) * intensity * max_linear_speed * 0.4
	
	angular_velocity += (cur_basis * drift_torque) * delta
	linear_velocity += (cur_basis * drift_force) * delta

func set_cyber_drift_active(active: bool, intensity: float = 1.0) -> void:
	cyber_drift_intensity = intensity if active else 0.0

func set_inertia_dampening(enabled: bool) -> void:
	inertia_dampening = enabled

func get_inertia_dampening() -> bool:
	return inertia_dampening

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
