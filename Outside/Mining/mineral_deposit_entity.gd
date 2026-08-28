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
