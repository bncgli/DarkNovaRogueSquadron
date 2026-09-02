class_name ServiceDroneEntity
extends Node3D

## Entità 3D simulata nello spazio per il Drone di Servizio EVA (Extra-Vehicular Activity).
## Gestisce spinta RCS, batteria, raggio tether dalla nave, fari, e braccio manipolatore multi-funzione
## (saldatore riparazione falle, laser da taglio/sabotaggio e magnete/harpoon recupero cargo).

signal telemetry_updated(telemetry: Dictionary)
signal docking_completed()
signal breach_welded(breach_id: String)
signal cargo_collected(item: Dictionary)
signal cargo_dropped(item: Dictionary)

# Parametri operativi configurabili via .DAT
@export var max_thrust: float = 35.0
@export var battery_capacity_sec: float = 240.0
@export var tether_range: float = 1500.0
@export var auto_dock_speed: float = 12.0

@export var repair_rate: float = 15.0
@export var cutting_laser_power: float = 25.0
@export var cargo_capacity_kg: float = 500.0
@export var magnet_range: float = 18.0

# Nodi visivi e telecamera
@onready var camera_3d: Camera3D = get_node_or_null("Camera3D")
@onready var headlight: Light3D = get_node_or_null("Headlight")
@onready var laser_ray: RayCast3D = get_node_or_null("LaserRay")
@onready var laser_mesh: MeshInstance3D = get_node_or_null("LaserVisual")

# Stato operativo
var is_docked: bool = true
var is_auto_docking: bool = false
var battery: float = 100.0 # Percentuale 0..100
var lights_enabled: bool = true
var current_linear_velocity: Vector3 = Vector3.ZERO
var current_angular_velocity: Vector3 = Vector3.ZERO

# Input pilota
var input_move: Vector3 = Vector3.ZERO
var input_rot: Vector3 = Vector3.ZERO
var is_boost_active: bool = false

# Strumenti e manipolatore
var active_tool: String = "welder" # "welder", "laser", "magnet"
var is_tool_active: bool = false
var target_breach_id: String = ""
var target_object_id: String = ""
var repair_progress: float = 0.0

# Stiva Cargo
var cargo_items: Array[Dictionary] = []
var cargo_weight_kg: float = 0.0

# Posizione di aggancio relativa all'astronave
const DOCK_OFFSET_LOCAL: Vector3 = Vector3(0.0, -1.8, 2.5)

func _ready() -> void:
	if not camera_3d:
		camera_3d = get_node_or_null("Camera3D")
	if not headlight:
		headlight = get_node_or_null("Headlight")
	if not laser_mesh:
		laser_mesh = get_node_or_null("LaserVisual")
	if laser_mesh:
		laser_mesh.visible = false
	
	battery = 100.0
	_update_lights_state()

func apply_config(cfg: Dictionary) -> void:
	if cfg.has("max_thrust"): max_thrust = float(cfg["max_thrust"])
	if cfg.has("battery_capacity_sec"): battery_capacity_sec = float(cfg["battery_capacity_sec"])
	if cfg.has("tether_range"): tether_range = float(cfg["tether_range"])
	if cfg.has("auto_dock_speed"): auto_dock_speed = float(cfg["auto_dock_speed"])
	if cfg.has("repair_rate"): repair_rate = float(cfg["repair_rate"])
	if cfg.has("cutting_laser_power"): cutting_laser_power = float(cfg["cutting_laser_power"])
	if cfg.has("cargo_capacity_kg"): cargo_capacity_kg = float(cfg["cargo_capacity_kg"])
	if cfg.has("magnet_range"): magnet_range = float(cfg["magnet_range"])

func get_camera_3d() -> Camera3D:
	if camera_3d == null:
		camera_3d = get_node_or_null("Camera3D")
	return camera_3d

func set_inputs(move_vec: Vector3, rot_vec: Vector3, boost: bool = false) -> void:
	input_move = move_vec
	input_rot = rot_vec
	is_boost_active = boost
	if (move_vec != Vector3.ZERO or rot_vec != Vector3.ZERO) and is_docked:
		# L'azione manuale sveglia il drone se era docked
		undock()

func set_lights(enabled: bool) -> void:
	lights_enabled = enabled
	_update_lights_state()

func toggle_lights() -> bool:
	lights_enabled = not lights_enabled
	_update_lights_state()
	return lights_enabled

func _update_lights_state() -> void:
	if headlight:
		headlight.visible = lights_enabled

func undock() -> void:
	is_docked = false
	is_auto_docking = false

func dock() -> void:
	is_docked = true
	is_auto_docking = false
	current_linear_velocity = Vector3.ZERO
	current_angular_velocity = Vector3.ZERO
	is_tool_active = false
	if laser_mesh:
		laser_mesh.visible = false
	docking_completed.emit()

func start_auto_dock() -> void:
	if is_docked:
		return
	is_auto_docking = true
	is_tool_active = false
	if laser_mesh:
		laser_mesh.visible = false

func set_active_tool(tool_name: String) -> void:
	active_tool = tool_name
	if not is_tool_active and laser_mesh:
		laser_mesh.visible = false

func set_tool_trigger(active: bool, target_id: String = "") -> void:
	is_tool_active = active
	if target_id != "":
		target_breach_id = target_id
		target_object_id = target_id
	if laser_mesh:
		laser_mesh.visible = is_tool_active and (active_tool == "laser" or active_tool == "welder")

func _physics_process(delta: float) -> void:
	var ship := _get_spaceship()
	var ship_pos := ship.global_position if ship and is_instance_valid(ship) else Vector3.ZERO
	var ship_trans := ship.global_transform if ship and is_instance_valid(ship) else Transform3D.IDENTITY
	
	if is_docked:
		# Quando agganciato, segue fedelmente la posizione della baia droni della corvetta
		if ship and is_instance_valid(ship):
			global_transform = ship_trans * Transform3D(Basis.IDENTITY, DOCK_OFFSET_LOCAL)
		# Ricarica rapida della batteria in baia
		if battery < 100.0:
			var charge_rate: float = (100.0 / 30.0) # ricarica completa in 30 secondi
			battery = minf(100.0, battery + charge_rate * delta)
		_emit_telemetry(0.0)
		return
	
	# Consumo batteria in volo
	var drain_per_sec: float = 100.0 / maxf(battery_capacity_sec, 10.0)
	var active_drain_mult: float = 1.0
	if is_boost_active:
		active_drain_mult += 0.8
	if lights_enabled:
		active_drain_mult += 0.15
	if is_tool_active:
		active_drain_mult += 0.6
	
	battery = maxf(0.0, battery - drain_per_sec * active_drain_mult * delta)
	if battery <= 0.0:
		# Batteria esaurita: niente spinta attiva, deriva inerziale o rientro di emergenza
		input_move = Vector3.ZERO
		input_rot = Vector3.ZERO
		is_tool_active = false
		if laser_mesh:
			laser_mesh.visible = false
	
	if is_auto_docking:
		var dock_target_pos := ship_trans * DOCK_OFFSET_LOCAL
		var to_dock := dock_target_pos - global_position
		var dist_to_dock := to_dock.length()
		
		if dist_to_dock < 1.5:
			dock()
			return
		else:
			var dock_dir := to_dock.normalized()
			current_linear_velocity = dock_dir * auto_dock_speed
			# Allinea gradualmente la rotazione a quella della nave
			global_basis = global_basis.slerp(ship_trans.basis, minf(1.0, 4.0 * delta))
			global_position += current_linear_velocity * delta
	else:
		# Controllo manuale thruster RCS
		var thrust_power: float = max_thrust
		if is_boost_active:
			thrust_power *= 1.8
		
		# Movimento in coordinate locali del drone
		var local_move := input_move.normalized() if input_move.length() > 1.0 else input_move
		var target_vel := (global_basis * local_move) * thrust_power
		current_linear_velocity = current_linear_velocity.move_toward(target_vel, 25.0 * delta)
		
		# Rotazione
		var rot_target := input_rot * 2.5
		current_angular_velocity = current_angular_velocity.move_toward(rot_target, 8.0 * delta)
		
		rotate_object_local(Vector3.UP, current_angular_velocity.y * delta)
		rotate_object_local(Vector3.RIGHT, current_angular_velocity.x * delta)
		rotate_object_local(Vector3.FORWARD, current_angular_velocity.z * delta)
		
		global_position += current_linear_velocity * delta
	
	# Verifica limite Tether Range
	var dist_from_ship := global_position.distance_to(ship_pos)
	if dist_from_ship > tether_range:
		var to_center := (ship_pos - global_position).normalized()
		global_position = ship_pos - to_center * tether_range
		# Smorza la velocità che allontana ulteriormente
		if current_linear_velocity.dot(-to_center) > 0:
			current_linear_velocity = current_linear_velocity.slide(to_center)
	
	# Esecuzione strumenti attivi
	if is_tool_active and battery > 0.0:
		_process_active_tool(delta)
	
	_emit_telemetry(dist_from_ship)

func _process_active_tool(delta: float) -> void:
	match active_tool:
		"welder":
			_process_welder(delta)
		"laser":
			_process_laser(delta)
		"magnet":
			_process_magnet(delta)

func _process_welder(delta: float) -> void:
	if not SpaceWorldManager:
		return
	
	# Se c'è una breccia vicina (o target specificato), salda la falla
	var target_dmg: ShipDamageRuntimeState = null
	if target_breach_id != "":
		target_dmg = SpaceWorldManager.get_damage_by_id(target_breach_id)
	
	if target_dmg == null:
		# Cerca la prima breccia scafo attiva
		var active_dmgs := SpaceWorldManager.get_active_ship_damages()
		for d in active_dmgs:
			if d.type == SpaceWorldManager.DAMAGE_TYPE_BREACH:
				target_dmg = d
				target_breach_id = d.id
				break
	
	if target_dmg != null and not target_dmg.repaired:
		var repair_delta: float = (repair_rate / 100.0) * delta
		var cur_p: float = target_dmg.repair_progress + repair_delta
		target_dmg.repair_progress = minf(1.0, cur_p)
		repair_progress = target_dmg.repair_progress
		
		if cur_p >= 1.0:
			target_dmg.repaired = true
			target_dmg.repair_progress = 1.0
			SpaceWorldManager.ship_damage_repaired.emit(target_dmg)
			SpaceWorldManager.ship_damages_updated.emit(SpaceWorldManager.get_ship_damages())
			breach_welded.emit(target_dmg.id)
			target_breach_id = ""
			is_tool_active = false
			if laser_mesh:
				laser_mesh.visible = false

func _process_laser(delta: float) -> void:
	# Taglio laser ad alta potenza
	repair_progress = minf(1.0, repair_progress + (cutting_laser_power / 100.0) * delta)

func _process_magnet(_delta: float) -> void:
	# Harpoon magnetico per la raccolta di rottami o capsule cargo nello spazio
	if cargo_weight_kg < cargo_capacity_kg:
		# Trova o raccoglie materiale
		pass

func collect_cargo_item(item_id: String, item_name: String, weight_kg: float) -> bool:
	if cargo_weight_kg + weight_kg > cargo_capacity_kg:
		return false
	
	var item: Dictionary = {
		"id": item_id,
		"name": item_name,
		"weight_kg": weight_kg
	}
	cargo_items.append(item)
	cargo_weight_kg += weight_kg
	cargo_collected.emit(item)
	return true

func drop_cargo_item(index: int = 0) -> Dictionary:
	if index >= 0 and index < cargo_items.size():
		var item: Dictionary = cargo_items[index]
		cargo_items.remove_at(index)
		cargo_weight_kg = maxf(0.0, cargo_weight_kg - float(item.get("weight_kg")))
		cargo_dropped.emit(item)
		return item
	return {}

func clear_cargo() -> void:
	cargo_items.clear()
	cargo_weight_kg = 0.0

func _emit_telemetry(dist_from_ship: float) -> void:
	var t: Dictionary = get_telemetry(dist_from_ship)
	telemetry_updated.emit(t)
	if SpaceWorldManager and SpaceWorldManager.has_signal("service_drone_state_changed"):
		SpaceWorldManager.service_drone_state_changed.emit(t)

func get_telemetry(dist: float = -1.0) -> Dictionary:
	var ship := _get_spaceship()
	var ship_pos := ship.global_position if ship and is_instance_valid(ship) else Vector3.ZERO
	var cur_dist := dist if dist >= 0.0 else global_position.distance_to(ship_pos)
	
	return {
		"position": global_position,
		"velocity": current_linear_velocity,
		"speed": current_linear_velocity.length(),
		"distance_to_ship": cur_dist,
		"battery": battery,
		"is_docked": is_docked,
		"is_auto_docking": is_auto_docking,
		"lights": lights_enabled,
		"active_tool": active_tool,
		"is_tool_active": is_tool_active,
		"target_breach_id": target_breach_id,
		"repair_progress": repair_progress,
		"cargo_count": cargo_items.size(),
		"cargo_weight": cargo_weight_kg,
		"max_cargo_weight": cargo_capacity_kg,
		"tether_range": tether_range,
		"tether_pct": clampf((cur_dist / maxf(tether_range, 1.0)) * 100.0, 0.0, 100.0)
	}

func _get_spaceship() -> Spaceship:
	if SpaceWorldManager and SpaceWorldManager.has_method("get_spaceship"):
		return SpaceWorldManager.get_spaceship()
	return null
