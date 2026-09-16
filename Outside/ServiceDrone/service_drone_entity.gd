class_name ServiceDroneEntity
extends CharacterBody3D

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
@export var max_rot_speed: float = 2.5
@export var angular_accel: float = 8.0
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
var latched_container: CargoContainerEntity = null

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
	if cfg.has("max_rot_speed"): max_rot_speed = float(cfg["max_rot_speed"])
	if cfg.has("angular_accel"): angular_accel = float(cfg["angular_accel"])
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
	velocity = Vector3.ZERO
	is_tool_active = false
	if laser_mesh:
		laser_mesh.visible = false
	_transfer_cargo_to_ship()
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
	if not active and active_tool == "magnet":
		unlatch_cargo()

func _physics_process(delta: float) -> void:
	var ship := _get_spaceship()
	var ship_pos := ship.global_position if ship and is_instance_valid(ship) else Vector3.ZERO
	var ship_trans := ship.global_transform if ship and is_instance_valid(ship) else Transform3D.IDENTITY
	
	if is_docked:
		# Quando agganciato, segue fedelmente la posizione della baia droni della corvetta
		if ship and is_instance_valid(ship):
			global_transform = ship_trans * Transform3D(Basis.IDENTITY, DOCK_OFFSET_LOCAL)
		velocity = Vector3.ZERO
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
	if latched_container != null and is_instance_valid(latched_container):
		active_drain_mult += (latched_container.mass_kg / 100.0) * 0.9
	
	battery = maxf(0.0, battery - drain_per_sec * active_drain_mult * delta)
	if battery <= 0.0:
		# Batteria esaurita: niente spinta attiva, rilascio harpoon ed emergenza
		input_move = Vector3.ZERO
		input_rot = Vector3.ZERO
		is_tool_active = false
		if latched_container != null:
			unlatch_cargo()
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
			velocity = current_linear_velocity
			move_and_slide()
			current_linear_velocity = velocity
	else:
		# Controllo manuale thruster RCS
		var thrust_power: float = max_thrust
		if is_boost_active:
			thrust_power *= 1.8
		
		# Modulazione dell'inerzia e della velocità in base alla massa rimorchiata
		var tow_mass := latched_container.mass_kg if (latched_container and is_instance_valid(latched_container)) else 0.0
		var inertia_mult := 1.0 / (1.0 + (tow_mass / 180.0))
		thrust_power *= inertia_mult
		
		# Movimento in coordinate locali del drone
		var local_move := input_move.normalized() if input_move.length() > 1.0 else input_move
		var target_vel := (global_basis * local_move) * thrust_power
		current_linear_velocity = current_linear_velocity.move_toward(target_vel, 25.0 * inertia_mult * delta)
		
		# Rotazione angolare con smorzamento diegetico
		var target_rot_y := input_rot.y * max_rot_speed
		var target_rot_x := input_rot.x * max_rot_speed
		var target_rot_z := input_rot.z * max_rot_speed
		
		current_angular_velocity.y = lerpf(current_angular_velocity.y, target_rot_y, minf(1.0, angular_accel * delta))
		current_angular_velocity.x = lerpf(current_angular_velocity.x, target_rot_x, minf(1.0, angular_accel * delta))
		current_angular_velocity.z = lerpf(current_angular_velocity.z, target_rot_z, minf(1.0, angular_accel * delta))
		
		rotate_object_local(Vector3.UP, current_angular_velocity.y * delta)
		rotate_object_local(Vector3.RIGHT, current_angular_velocity.x * delta)
		if absf(current_angular_velocity.z) > 0.0001:
			rotate_object_local(Vector3.FORWARD, current_angular_velocity.z * delta)
		
		velocity = current_linear_velocity
		move_and_slide()
		current_linear_velocity = velocity
	
	# Verifica limite Tether Range
	var dist_from_ship := global_position.distance_to(ship_pos)
	if dist_from_ship > tether_range:
		var to_center := (ship_pos - global_position).normalized()
		global_position = ship_pos - to_center * tether_range
		# Smorza la velocità che allontana ulteriormente
		if current_linear_velocity.dot(-to_center) > 0:
			current_linear_velocity = current_linear_velocity.slide(to_center)
			velocity = current_linear_velocity
	
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
	if latched_container != null and is_instance_valid(latched_container):
		return

	var best_target: CargoContainerEntity = null
	var min_dist: float = magnet_range
	
	# Scansione dei container nel gruppo
	var containers := get_tree().get_nodes_in_group("cargo_containers")
	for c in containers:
		if c is CargoContainerEntity and is_instance_valid(c) and not c.is_latched and not c.is_collected:
			var d := global_position.distance_to(c.global_position)
			if d <= min_dist:
				min_dist = d
				best_target = c
				
	# Fallback a SpaceWorldManager active_debris_containers
	if best_target == null and SpaceWorldManager and SpaceWorldManager.has_method("get_active_debris_containers"):
		for c in SpaceWorldManager.get_active_debris_containers():
			if c and is_instance_valid(c) and not c.is_latched and not c.is_collected:
				var d := global_position.distance_to(c.global_position)
				if d <= min_dist:
					min_dist = d
					best_target = c
					
	if best_target != null:
		latch_cargo(best_target)
		return
		
	# Se nessun container è agganciato o nelle vicinanze, ricerca nodi mineral_deposits
	var deposits := get_tree().get_nodes_in_group("mineral_deposits")
	var best_deposit: MineralDepositEntity = null
	var min_dep_dist: float = magnet_range
	for dep in deposits:
		if dep is MineralDepositEntity and is_instance_valid(dep) and not dep.is_collected:
			var d := global_position.distance_to(dep.global_position)
			if d <= min_dep_dist:
				min_dep_dist = d
				best_deposit = dep
				
	if best_deposit != null:
		if min_dep_dist <= 2.5:
			if cargo_weight_kg + best_deposit.mass_kg <= cargo_capacity_kg:
				best_deposit.collect_into_drone(self)
			else:
				best_deposit.start_magnetic_attraction(self, 14.0)
		else:
			best_deposit.start_magnetic_attraction(self, 14.0)

## Scarica il carico stivato nel drone verso la corvetta madre o CargoManager
func _transfer_cargo_to_ship() -> void:
	if cargo_items.is_empty():
		return
	var ship := _get_spaceship()
	var cargo_mgr: Node = null
	if ship and is_instance_valid(ship) and "cargo_manager" in ship and ship.cargo_manager:
		cargo_mgr = ship.cargo_manager
	elif is_inside_tree():
		var nodes := get_tree().get_nodes_in_group("cargo_managers")
		if not nodes.is_empty():
			cargo_mgr = nodes[0]
			
	for item in cargo_items:
		var item_id: String = str(item.get("id", "ore_fragment"))
		var item_name: String = str(item.get("name", "Frammento Minerale"))
		var mass: float = float(item.get("weight_kg", 25.0))
		if cargo_mgr and cargo_mgr.has_method("add_item"):
			cargo_mgr.add_item({
				"id": item_id,
				"name": item_name,
				"category": "MINERAL",
				"unit_mass_kg": mass,
				"unit_volume_m3": 0.5,
				"unit_base_value": 200.0,
				"quantity": 1,
				"is_scavenged": false
			}, 1)
	cargo_items.clear()
	cargo_weight_kg = 0.0

## Aggancia un container cargo tramite harpoon
func latch_cargo(container: CargoContainerEntity) -> bool:
	if container == null or not is_instance_valid(container) or container.is_collected:
		return false
	latched_container = container
	cargo_weight_kg = container.mass_kg
	container.latch(self, Vector3(0.0, -1.2, -2.8))
	return true

## Sgancia il container rimorchiato
func unlatch_cargo() -> void:
	if latched_container != null and is_instance_valid(latched_container):
		latched_container.unlatch()
		cargo_dropped.emit(latched_container.get_cargo_item_dict())
	latched_container = null
	cargo_weight_kg = 0.0

## Verifica se un container è attualmente vincolato all'harpoon
func is_cargo_latched() -> bool:
	return latched_container != null and is_instance_valid(latched_container) and latched_container.is_latched

## Restituisce il container attualmente vincolato all'harpoon
func get_latched_container() -> CargoContainerEntity:
	return latched_container

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
		"is_latched": is_cargo_latched(),
		"latched_container_id": latched_container.container_id if latched_container and is_instance_valid(latched_container) else "",
		"tether_range": tether_range,
		"tether_pct": clampf((cur_dist / maxf(tether_range, 1.0)) * 100.0, 0.0, 100.0)
	}

func _get_spaceship() -> Spaceship:
	if SpaceWorldManager and SpaceWorldManager.has_method("get_spaceship"):
		var s: Spaceship = SpaceWorldManager.get_spaceship()
		if s and is_instance_valid(s):
			return s
	if is_inside_tree():
		var ships := get_tree().get_nodes_in_group("spaceship")
		for s in ships:
			if s is Spaceship and is_instance_valid(s):
				return s
	return null
