class_name MineralDepositEntity
extends RigidBody3D

## Rappresenta un frammento o nodo minerario fluttuante nello spazio esterno.
## Può essere attratto da fasci magnetici / arpioni di droni e stivato nella Cargo Bay.

signal deposit_collected(collector: Node)
signal deposit_depleted()

@export var deposit_id: String = "ore_fragment"
@export var mineral_name: String = "Frammento Minerale Grezzo"
@export var resource_type: String = "heavy_metals" # heavy_metals, rare_alloys, crystals, water_ice, durasteel_ore, exocrystal
@export var mass_kg: float = 25.0
@export var volume_m3: float = 0.5
@export var purity: float = 1.0 # Da 0.1 a 1.0 moltiplicatore resa
@export var base_value_credits: int = 150
@export var flux_yield: float = 1.5
@export var life_support_water_units: float = 0.0 # Per estrazione ghiaccio
@export var health: float = 50.0
@export var max_health: float = 50.0

@export var is_collected: bool = false
@export var is_floating: bool = true

var _attractor_target: Node3D = null
var _attraction_speed: float = 15.0

func _ready() -> void:
	add_to_group("mineral_deposits")
	add_to_group("scannable_entities")
	_setup_collision()

func _setup_collision() -> void:
	# Configura parametri fisici di default se non definiti
	mass = mass_kg
	gravity_scale = 0.0
	linear_damp = 0.5
	angular_damp = 0.8

	# Configura CollisionShape3D programmatica se assente
	var col_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape == null:
		col_shape = CollisionShape3D.new()
		col_shape.name = "CollisionShape3D"
		var sphere := SphereShape3D.new()
		sphere.radius = maxf(0.5, pow(volume_m3 * 0.75 / PI, 1.0 / 3.0))
		col_shape.shape = sphere
		add_child(col_shape)

	# Configura MeshInstance3D per resa grafica e sensori/LIDAR
	var mesh_inst := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst == null:
		mesh_inst = MeshInstance3D.new()
		mesh_inst.name = "MeshInstance3D"
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = 0.6
		sphere_mesh.height = 1.2
		mesh_inst.mesh = sphere_mesh
		
		var mat := StandardMaterial3D.new()
		if resource_type in ["water_ice", "ice", "water"]:
			mat.albedo_color = Color(0.3, 0.75, 1.0, 0.85) # Ghiaccio azzurro
			mat.roughness = 0.1
			mat.metallic = 0.1
		elif resource_type in ["crystals", "exocrystal", "rare_alloys"]:
			mat.albedo_color = Color(0.85, 0.2, 0.95) # Cristallo FLUX violaceo
			mat.emission_enabled = true
			mat.emission = Color(0.7, 0.1, 0.8)
			mat.emission_energy_multiplier = 0.8
		else:
			mat.albedo_color = Color(0.65, 0.65, 0.7) # Metallo denso
			mat.metallic = 0.8
			mat.roughness = 0.4
		mesh_inst.material_override = mat
		add_child(mesh_inst)

func _physics_process(delta: float) -> void:
	if is_collected:
		return
	if _attractor_target and is_instance_valid(_attractor_target):
		var target_pos := _attractor_target.global_position
		var dir := (target_pos - global_position).normalized()
		var dist := global_position.distance_to(target_pos)
		if dist > 0.5:
			global_position = global_position.move_toward(target_pos, _attraction_speed * delta)
		else:
			complete_collection(_attractor_target)

## Inizia l'attrazione magnetica verso un drone o harpoon
func start_magnetic_attraction(target_node: Node3D, speed: float = 15.0) -> void:
	_attractor_target = target_node
	_attraction_speed = speed
	freeze = true # Disattiva simulazione fisica libera durante l'attrazione

## Ferma l'attrazione
func stop_magnetic_attraction() -> void:
	_attractor_target = null
	freeze = false

## Riceve danno da laser minerari o cinetici (può frantumarsi ulteriormente o raffinarsi)
func apply_mining_damage(amount: float) -> Dictionary:
	if is_collected:
		return {}
	health -= amount
	if health <= 0.0:
		health = 0.0
		deposit_depleted.emit()
		var yield_data := get_resource_dict()
		queue_free()
		return yield_data
	return get_resource_dict()

## Converte il frammento minerale in formato Dictionary per inventario CargoBay
func get_resource_dict() -> Dictionary:
	return {
		"id": deposit_id,
		"name": mineral_name,
		"category": "MINERAL",
		"type": "MINERAL",
		"resource_sub_type": resource_type,
		"unit_mass_kg": mass_kg,
		"unit_volume_m3": volume_m3,
		"unit_base_value": float(int(base_value_credits * purity)),
		"mass_kg": mass_kg,
		"volume_m3": volume_m3,
		"purity": purity,
		"value_credits": int(base_value_credits * purity),
		"flux_yield": flux_yield * purity,
		"water_units": life_support_water_units * purity
	}

## Raccoglie il frammento direttamente inserendolo nella Cargo Bay o nel Drone
func collect_into_cargo(cargo_manager: Node = null) -> bool:
	if is_collected:
		return false
	var res_dict := get_resource_dict()
	var success := false
	if cargo_manager and cargo_manager.has_method("add_item"):
		success = cargo_manager.add_item(res_dict, 1)
	else:
		# Fallback se non passato o istanza standard
		success = true

	if success:
		is_collected = true
		deposit_collected.emit(cargo_manager)
		queue_free()
	return success

## Raccoglie il frammento dentro un Service Drone
func collect_into_drone(drone: Node) -> bool:
	if is_collected:
		return false
	if drone and drone.has_method("collect_cargo_item"):
		var ok: bool = drone.collect_cargo_item(deposit_id, mineral_name, mass_kg)
		if ok:
			is_collected = true
			deposit_collected.emit(drone)
			queue_free()
			return true
	return false

## Ritorna le info di spettrometria per l'app Sensors
func get_spectrometry_data() -> Dictionary:
	return {
		"deposit_id": deposit_id,
		"name": mineral_name,
		"composition": resource_type,
		"purity_pct": int(purity * 100),
		"mass_kg": mass_kg,
		"volume_m3": volume_m3,
		"estimated_credits": int(base_value_credits * purity),
		"flux_potential": flux_yield * purity,
		"water_units": life_support_water_units * purity
	}

func complete_collection(collector: Node) -> void:
	is_collected = true
	deposit_collected.emit(collector)
	queue_free()
