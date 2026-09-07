class_name DynamicSpaceSkybox
extends Node3D

## Gestore della proiezione scalare dello skybox diegetico e dell'illuminazione stellare dinamica.

@export var target_environment: Environment = null
@export var sun_light: DirectionalLight3D = null
@export var ship_node: Node3D = null
var grid_manager: Node = null

# Nodo contenitore per gli impostori 3D / proiezioni dei corpi celesti sullo skybox
@onready var celestial_container: Node3D = Node3D.new()

# Nodo contenitore del campo stellare procedurale (sempre centrato sulla nave)
@onready var starfield: CPUParticles3D = CPUParticles3D.new()

# Raggio della sfera di proiezione dello skybox attorno alla nave/camera
const SKY_SPHERE_RADIUS: float = 400.0

# Raggio della sfera del campo stellare (leggermente entro SKY_SPHERE_RADIUS)
const STARFIELD_RADIUS: float = 380.0
const STARFIELD_COUNT: int = 600

var _rendered_entities: Array[Dictionary] = []

func _ready() -> void:
	name = "DynamicSpaceSkybox"
	if not celestial_container.is_inside_tree():
		add_child(celestial_container)
		celestial_container.name = "CelestialContainer"
	
	if not starfield.is_inside_tree():
		add_child(starfield)
		starfield.name = "Starfield"
		_setup_starfield()
	
	if grid_manager == null:
		grid_manager = get_node_or_null("/root/StarSystemGridManager")
	
	if grid_manager:
		if not grid_manager.lighting_updated.is_connected(_on_lighting_updated):
			grid_manager.lighting_updated.connect(_on_lighting_updated)
		if not grid_manager.system_entities_updated.is_connected(_on_system_entities_updated):
			grid_manager.system_entities_updated.connect(_on_system_entities_updated)
		if not grid_manager.sector_changed.is_connected(_on_sector_changed):
			grid_manager.sector_changed.connect(_on_sector_changed)
	
	_auto_detect_scene_elements()
	update_skybox()

## Rileva automaticamente WorldEnvironment, DirectionalLight3D e la nave se presenti nella scena genitore
func _auto_detect_scene_elements() -> void:
	if target_environment == null:
		var world_env: WorldEnvironment = get_node_or_null("../WorldEnvironment") as WorldEnvironment
		if world_env:
			target_environment = world_env.environment
	
	if sun_light == null:
		sun_light = get_node_or_null("../SunLight") as DirectionalLight3D
	
	if ship_node == null:
		ship_node = get_node_or_null("../Spaceship") as Node3D

func set_target_environment(env: Environment) -> void:
	target_environment = env
	update_skybox()

func set_sun_light(light: DirectionalLight3D) -> void:
	sun_light = light
	update_skybox()

func set_grid_manager(mgr: Node) -> void:
	if grid_manager and is_instance_valid(grid_manager):
		if grid_manager.lighting_updated.is_connected(_on_lighting_updated):
			grid_manager.lighting_updated.disconnect(_on_lighting_updated)
		if grid_manager.system_entities_updated.is_connected(_on_system_entities_updated):
			grid_manager.system_entities_updated.disconnect(_on_system_entities_updated)
		if grid_manager.sector_changed.is_connected(_on_sector_changed):
			grid_manager.sector_changed.disconnect(_on_sector_changed)
	
	grid_manager = mgr
	if grid_manager:
		grid_manager.lighting_updated.connect(_on_lighting_updated)
		grid_manager.system_entities_updated.connect(_on_system_entities_updated)
		grid_manager.sector_changed.connect(_on_sector_changed)
	
	update_skybox()

## Ritorna le entità attualmente proiettate sullo skybox
func get_rendered_entities() -> Array[Dictionary]:
	return _rendered_entities

## Aggiorna completamente la proiezione diegetica dello skybox e l'illuminazione
func update_skybox() -> void:
	if grid_manager == null:
		grid_manager = get_node_or_null("/root/StarSystemGridManager")
	
	if grid_manager == null:
		return
	
	var sec_coords: Vector3i = grid_mgr_get_coords()
	var visible_ents: Array = grid_manager.get_visible_system_entities(sec_coords)
	_on_system_entities_updated(visible_ents)
	
	var sun_dir: Vector3 = grid_manager.get_light_direction_from_star(sec_coords)
	var sun_energy: float = grid_manager.get_effective_solar_energy(sec_coords)
	var sec_data: SectorData = grid_manager.get_current_sector_data() as SectorData
	var amb_energy: float = sec_data.ambient_light_energy if sec_data else 0.5
	
	_on_lighting_updated(sun_dir, sun_energy, amb_energy)

func grid_mgr_get_coords() -> Vector3i:
	if grid_manager and grid_manager.has_method("get_current_sector_coords"):
		return grid_manager.get_current_sector_coords()
	return Vector3i.ZERO

func _on_lighting_updated(sun_direction: Vector3, light_energy: float, ambient_energy: float) -> void:
	if sun_light and is_instance_valid(sun_light):
		sun_light.light_energy = light_energy
		if sun_direction.length_squared() > 0.001:
			var target_basis := Basis.looking_at(sun_direction, Vector3.UP)
			sun_light.transform.basis = target_basis
	
	if target_environment and is_instance_valid(target_environment):
		target_environment.ambient_light_energy = ambient_energy

func _on_system_entities_updated(entities: Array[Dictionary]) -> void:
	_rendered_entities.clear()
	
	# Pulisce i nodi impostori esistenti
	if celestial_container and is_instance_valid(celestial_container):
		for child in celestial_container.get_children():
			child.queue_free()
	
	for ent in entities:
		# Non proiettare come elemento skybox lontano se siamo già all'interno dello stesso settore
		# (le entità locali del settore sono caricate fisicamente da SpaceWorldManager)
		var is_local: bool = ent.get("is_in_current_sector")
		var dir: Vector3 = ent.get("direction")
		var scale_factor: float = ent.get("apparent_angular_size")
		var brightness: float = ent.get("apparent_brightness")
		var ent_type: String = ent.get("type")
		
		# Proietta sulla sfera dello skybox
		var sphere_pos := dir * SKY_SPHERE_RADIUS if dir.length_squared() > 0.001 else Vector3.FORWARD * SKY_SPHERE_RADIUS
		
		var render_info := {
			"id": ent.get("id"),
			"name": ent.get("name"),
			"type": ent_type,
			"projected_pos": sphere_pos,
			"apparent_scale": scale_factor,
			"brightness": brightness,
			"distance_sectors": ent.get("distance_sectors"),
			"is_local": is_local
		}
		
		_rendered_entities.append(render_info)
		
		if celestial_container and is_instance_valid(celestial_container):
			_create_celestial_impostor_node(render_info)

func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	
	# Centra lo skybox sulla nave (non sulla camera attiva del viewport), cosi' la
	# proiezione dei corpi celesti e il campo stellare seguono l'astronave anche
	# quando viene osservata da una camera esterna (es. Cams) diversa da quella
	# statica di default della scena.
	if ship_node == null or not is_instance_valid(ship_node):
		_auto_detect_scene_elements()
	
	if ship_node and is_instance_valid(ship_node):
		global_position = ship_node.global_position
		return
	
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam and is_instance_valid(cam):
		global_position = cam.global_position

func _create_celestial_impostor_node(info: Dictionary) -> void:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Impostor_%s" % str(info.get("id"))
	mesh_inst.position = info.get("projected_pos", Vector3.ZERO)
	
	var apparent_scale: float = float(info.get("apparent_scale", 1.0))
	var sphere := SphereMesh.new()
	sphere.radius = 2.0
	sphere.height = 4.0
	mesh_inst.mesh = sphere
	mesh_inst.scale = Vector3.ONE * maxf(apparent_scale, 0.05)
	
	var ent_type: String = str(info.get("type", "")).to_upper()
	var brightness: float = float(info.get("brightness", 1.0))
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	var base_col := Color.WHITE
	match ent_type:
		"STAR":
			base_col = Color(1.0, 0.9, 0.4)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.95, 0.6)
			mat.emission_energy_multiplier = 2.5 * brightness
		"GAS_GIANT":
			base_col = Color(0.85, 0.55, 0.3)
			mat.emission_enabled = true
			mat.emission = Color(0.85, 0.55, 0.3)
			mat.emission_energy_multiplier = 0.6 * brightness
		"PLANET":
			base_col = Color(0.25, 0.55, 0.85)
			mat.emission_enabled = true
			mat.emission = Color(0.25, 0.55, 0.85)
			mat.emission_energy_multiplier = 0.4 * brightness
		"MOON":
			base_col = Color(0.75, 0.75, 0.8)
			mat.emission_enabled = true
			mat.emission = Color(0.75, 0.75, 0.8)
			mat.emission_energy_multiplier = 0.25 * brightness
		"STATION":
			base_col = Color(0.4, 0.9, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.4, 0.9, 1.0)
			mat.emission_energy_multiplier = 1.0 * brightness
		_:
			base_col = Color(0.8, 0.8, 0.8)
			mat.emission_enabled = true
			mat.emission = Color(0.8, 0.8, 0.8)
			mat.emission_energy_multiplier = 0.3 * brightness
	
	mat.albedo_color = base_col
	mesh_inst.material_override = mat
	mesh_inst.set_meta("entity_data", info)
	celestial_container.add_child(mesh_inst)

func _on_sector_changed(_old_coords: Vector3i, _new_coords: Vector3i, _sec_data: SectorData) -> void:
	update_skybox()

## Configura il campo stellare procedurale: piccoli punti luminosi non ombreggiati
## distribuiti sulla superficie di una sfera centrata sulla nave, per simulare
## un cielo stellato a distanza infinita (nessuna parallasse) attorno all'astronave.
func _setup_starfield() -> void:
	starfield.amount = STARFIELD_COUNT
	starfield.lifetime = 1000.0
	starfield.preprocess = 1000.0
	starfield.one_shot = false
	starfield.speed_scale = 0.0
	starfield.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	starfield.emission_sphere_radius = STARFIELD_RADIUS
	starfield.direction = Vector3.ZERO
	starfield.spread = 0.0
	starfield.gravity = Vector3.ZERO
	starfield.initial_velocity_min = 0.0
	starfield.initial_velocity_max = 0.0
	starfield.scale_amount_min = 0.4
	starfield.scale_amount_max = 1.8
	
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.05
	star_mesh.height = 0.1
	star_mesh.radial_segments = 4
	star_mesh.rings = 2
	
	var star_mat := StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.albedo_color = Color(0.9, 0.95, 1.0, 1.0)
	star_mat.emission_enabled = true
	star_mat.emission = Color(0.85, 0.9, 1.0)
	star_mat.emission_energy_multiplier = 1.5
	star_mesh.material = star_mat
	
	starfield.mesh = star_mesh
