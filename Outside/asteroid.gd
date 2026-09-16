class_name Asteroid
extends StaticBody3D

## Rappresenta un asteroide nello spazio esterno con rotazione, integrità e frantumazione balistica.

signal asteroid_damaged(remaining_integrity: float, damage_taken: float)
signal asteroid_fractured(deposit_nodes: Array)

@export var rotation_speed: Vector3 = Vector3(0.05, 0.08, 0.03)
@export var wobble_speed: float = 0.0

@export var composition: Dictionary = {
	"Ferro (Fe)": 45.0,
	"Nichel (Ni)": 28.0,
	"Silicati": 18.0,
	"Cobalto": 9.0
}
@export var integrity: float = 100.0
@export var max_integrity: float = 100.0
@export var mass_tons: float = 2400.0
@export var radius_m: float = 4.0
@export var iff_tag: String = "NEUTRAL"
@export var signal_signature: float = 0.80
@export var is_fractured: bool = false

@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")

var _time_elapsed: float = 0.0

func _ready() -> void:
	add_to_group("asteroids")
	add_to_group("scannable_entities")
	var max_scale := maxf(scale.x, maxf(scale.y, scale.z))
	radius_m = 4.0 * max_scale
	if max_integrity <= 0.0:
		max_integrity = integrity
	# Randomizza leggermente la fase di rotazione per non avere asteroidi sincronizzati
	rotation_degrees += Vector3(
		randf_range(-180, 180),
		randf_range(-180, 180),
		randf_range(-180, 180)
	)

func _process(delta: float) -> void:
	_time_elapsed += delta
	rotate_x(rotation_speed.x * delta)
	rotate_y(rotation_speed.y * delta)
	rotate_z(rotation_speed.z * delta)

## Riceve danno balistico o minerario
func take_damage(amount: float, hit_position: Vector3 = Vector3.ZERO) -> void:
	if is_fractured or integrity <= 0.0:
		return
	var dmg := maxf(0.0, amount)
	integrity = maxf(0.0, integrity - dmg)
	asteroid_damaged.emit(integrity, dmg)
	
	if integrity <= 0.0:
		fracture(hit_position)

## Alias per danni da trivella o impulsi minerari
func apply_mining_damage(amount: float, hit_position: Vector3 = Vector3.ZERO) -> void:
	take_damage(amount, hit_position)

## Frantuma l'asteroide generando nodi MineralDepositEntity
func fracture(impact_pos: Vector3 = Vector3.ZERO) -> Array:
	if is_fractured:
		return []
	is_fractured = true
	
	var spawned_deposits: Array = []
	var count: int = randi_range(2, 4)
	
	# Determina risorse da generare in base alla composizione
	var resource_types: Array[Dictionary] = _determine_resource_types_from_composition()
	
	var parent_node := get_parent()
	if parent_node == null:
		parent_node = self
		
	for i in range(count):
		var res_info: Dictionary = resource_types[i % resource_types.size()]
		var deposit := MineralDepositEntity.new()
		deposit.deposit_id = res_info.get("deposit_id", "durasteel_ore")
		deposit.mineral_name = res_info.get("name", "Giacimento Minerale")
		deposit.resource_type = res_info.get("resource_type", "heavy_metals")
		deposit.mass_kg = res_info.get("mass_kg", randf_range(20.0, 45.0))
		deposit.volume_m3 = res_info.get("volume_m3", randf_range(0.4, 0.8))
		deposit.purity = clampf(randf_range(0.7, 1.0), 0.1, 1.0)
		deposit.base_value_credits = int(res_info.get("base_value_credits", 200))
		deposit.flux_yield = float(res_info.get("flux_yield", 1.5))
		deposit.life_support_water_units = float(res_info.get("life_support_water_units", 0.0))
		
		# Offset posizionale casuale attorno al centro o all'impatto
		var offset_dir := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		).normalized()
		if offset_dir.length_squared() < 0.01:
			offset_dir = Vector3.UP
			
		var spawn_pos: Vector3 = global_position + offset_dir * (radius_m * 0.5 + randf_range(0.5, 2.0))
		
		# Impulso newtoniano di espulsione
		var eject_speed: float = randf_range(2.0, 8.0)
		deposit.linear_velocity = offset_dir * eject_speed
		deposit.angular_velocity = Vector3(
			randf_range(-2.0, 2.0),
			randf_range(-2.0, 2.0),
			randf_range(-2.0, 2.0)
		)
		
		if parent_node != self and is_instance_valid(parent_node):
			parent_node.add_child(deposit)
		else:
			var tree = get_tree()
			if tree and tree.current_scene:
				tree.current_scene.add_child(deposit)
			else:
				add_child(deposit)
				
		deposit.global_position = spawn_pos
		spawned_deposits.append(deposit)
		
	asteroid_fractured.emit(spawned_deposits)
	
	# Disattiva collisione e nascondi prima di liberare per evitare colpi fantasma
	visible = false
	collision_layer = 0
	collision_mask = 0
	remove_from_group("asteroids")
	remove_from_group("scannable_entities")
	queue_free()
	
	return spawned_deposits

func _determine_resource_types_from_composition() -> Array[Dictionary]:
	var types: Array[Dictionary] = []
	
	for comp_key: String in composition.keys():
		var key_lower := comp_key.to_lower()
		var pct: float = float(composition[comp_key])
		if pct <= 0.0:
			continue
			
		if "ghiaccio" in key_lower or "ice" in key_lower or "water" in key_lower or "h2o" in key_lower:
			types.append({
				"deposit_id": "water_ice_block",
				"name": "Blocco Ghiaccio d'Acqua",
				"resource_type": "water_ice",
				"mass_kg": 30.0,
				"volume_m3": 0.5,
				"base_value_credits": 180,
				"flux_yield": 0.5,
				"life_support_water_units": 35.0
			})
		elif "cristall" in key_lower or "flux" in key_lower or "esotic" in key_lower or "rare" in key_lower:
			types.append({
				"deposit_id": "exocrystal_shard",
				"name": "Frammento Cristallo Esotico",
				"resource_type": "exocrystal",
				"mass_kg": 15.0,
				"volume_m3": 0.3,
				"base_value_credits": 550,
				"flux_yield": 8.0,
				"life_support_water_units": 0.0
			})
		elif "titan" in key_lower:
			types.append({
				"deposit_id": "titanium_raw",
				"name": "Titanio Grezzo",
				"resource_type": "heavy_metals",
				"mass_kg": 45.0,
				"volume_m3": 0.6,
				"base_value_credits": 320,
				"flux_yield": 2.0,
				"life_support_water_units": 0.0
			})
		elif "ferro" in key_lower or "nichel" in key_lower or "silicat" in key_lower or "cobalto" in key_lower or "durasteel" in key_lower:
			types.append({
				"deposit_id": "durasteel_ore",
				"name": "Minerale Grezzo Durasteel",
				"resource_type": "heavy_metals",
				"mass_kg": 40.0,
				"volume_m3": 0.5,
				"base_value_credits": 220,
				"flux_yield": 1.5,
				"life_support_water_units": 0.0
			})
			
	if types.is_empty():
		types.append({
			"deposit_id": "durasteel_ore",
			"name": "Minerale Grezzo Durasteel",
			"resource_type": "heavy_metals",
			"mass_kg": 35.0,
			"volume_m3": 0.5,
			"base_value_credits": 200,
			"flux_yield": 1.5,
			"life_support_water_units": 0.0
		})
		
	return types
