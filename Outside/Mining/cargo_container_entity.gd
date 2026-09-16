class_name CargoContainerEntity
extends RigidBody3D

## Rappresenta un container cargo sigillato fluttuante nello spazio esterno.
## Può essere agganciato e rimorchiato tramite l'harpoon magnetico del Service Drone
## e consegnato al portello cargo della corvetta per essere stivato in CargoManager.

signal latched_changed(is_latched: bool, latched_to: Node3D)
signal container_collected(target: Node)

@export var container_id: String = "cargo_container_01"
@export var container_name: String = "Container Cargo Sigillato"
@export var mass_kg: float = 40.0
@export var volume_m3: float = 1.0
@export var health: float = 100.0
@export var max_health: float = 100.0

@export var is_latched: bool = false
@export var is_collected: bool = false

## Dati del carico compatibili con CargoManager / CargoItemData
@export var item_data: Dictionary = {}

var latched_to: Node3D = null
var latch_offset: Vector3 = Vector3(0.0, -1.0, -2.5)
var _tow_smooth_speed: float = 16.0

func _ready() -> void:
	add_to_group("cargo_containers")
	add_to_group("scannable_entities")
	add_to_group("salvageable_objects")
	_setup_physics_and_visuals()

func _setup_physics_and_visuals() -> void:
	mass = mass_kg
	gravity_scale = 0.0
	linear_damp = 0.4
	angular_damp = 0.6
	
	if item_data.is_empty():
		item_data = {
			"id": "alloys_durasteel",
			"name": "Leghe Raffinate Durasteel",
			"category": "ALLOY",
			"unit_mass_kg": mass_kg,
			"unit_volume_m3": volume_m3,
			"unit_base_value": 350.0,
			"quantity": 1,
			"is_contraband": false,
			"is_scavenged": true
		}
	else:
		if not item_data.has("unit_mass_kg"):
			item_data["unit_mass_kg"] = mass_kg
		if not item_data.has("unit_volume_m3"):
			item_data["unit_volume_m3"] = volume_m3
		if not item_data.has("quantity"):
			item_data["quantity"] = 1
		if not item_data.has("is_scavenged"):
			item_data["is_scavenged"] = true

	# Configura CollisionShape3D programmatica se assente
	var col_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape == null:
		col_shape = CollisionShape3D.new()
		col_shape.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = Vector3(1.8, 1.2, 2.4)
		col_shape.shape = box
		add_child(col_shape)

	# Configura MeshInstance3D programmatica se assente per rendering visivo e LIDAR
	var mesh_inst := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst == null:
		mesh_inst = MeshInstance3D.new()
		mesh_inst.name = "MeshInstance3D"
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(1.8, 1.2, 2.4)
		mesh_inst.mesh = box_mesh
		
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.55, 0.15) # Arancione industriale
		mat.metallic = 0.75
		mat.roughness = 0.35
		mesh_inst.material_override = mat
		add_child(mesh_inst)

func _physics_process(delta: float) -> void:
	if is_collected:
		return

	if is_latched and latched_to != null and is_instance_valid(latched_to):
		var target_pos: Vector3 = latched_to.global_position + (latched_to.global_transform.basis * latch_offset)
		var target_basis: Basis = latched_to.global_transform.basis
		
		# Movimento smorzato (tow) per prevenire glitch fisici e jitter
		global_position = global_position.lerp(target_pos, clampf(delta * _tow_smooth_speed, 0.0, 1.0))
		global_transform.basis = global_transform.basis.slerp(target_basis, clampf(delta * 12.0, 0.0, 1.0)).orthonormalized()

## Aggancia il container tramite harpoon del drone
func latch(source: Node3D, offset: Vector3 = Vector3(0.0, -1.0, -2.5)) -> bool:
	if is_collected:
		return false
	is_latched = true
	latched_to = source
	latch_offset = offset
	freeze = true
	latched_changed.emit(true, source)
	return true

## Sgancia l'harpoon rilasciando il container nello spazio libero
func unlatch() -> void:
	if not is_latched:
		return
	is_latched = false
	if latched_to != null and is_instance_valid(latched_to) and "linear_velocity" in latched_to:
		linear_velocity = latched_to.linear_velocity
	latched_to = null
	freeze = false
	latched_changed.emit(false, null)

## Restituisce i dati per stivaggio in CargoManager
func get_cargo_item_dict() -> Dictionary:
	var out := item_data.duplicate(true)
	if not out.has("id"):
		out["id"] = container_id
	if not out.has("name"):
		out["name"] = container_name
	if not out.has("unit_mass_kg"):
		out["unit_mass_kg"] = mass_kg
	if not out.has("unit_volume_m3"):
		out["unit_volume_m3"] = volume_m3
	if not out.has("unit_base_value"):
		out["unit_base_value"] = 300.0
	if not out.has("quantity"):
		out["quantity"] = 1
	out["is_scavenged"] = true
	return out

## Ritorna dati diagnostici per sensori
func get_sensor_scan_data() -> Dictionary:
	return {
		"id": container_id,
		"name": container_name,
		"mass_kg": mass_kg,
		"volume_m3": volume_m3,
		"is_latched": is_latched,
		"item_id": item_data.get("id", "unknown"),
		"item_name": item_data.get("name", "Container Ignoto"),
		"estimated_value": int(item_data.get("unit_base_value", 300.0) * item_data.get("quantity", 1))
	}

## Ritorna dati di spettrometria per l'app Sensors
func get_spectrometry_data() -> Dictionary:
	return {
		"deposit_id": container_id,
		"name": container_name,
		"composition": str(item_data.get("category", "ALLOY")),
		"purity_pct": 100,
		"mass_kg": mass_kg,
		"volume_m3": volume_m3,
		"estimated_credits": int(item_data.get("unit_base_value", 300.0) * item_data.get("quantity", 1)),
		"flux_potential": 2.0
	}

## Segna il container come raccolto e ne avvia la rimozione
func mark_collected(collector: Node) -> void:
	if is_collected:
		return
	is_collected = true
	unlatch()
	container_collected.emit(collector)
	queue_free()
