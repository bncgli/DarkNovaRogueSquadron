class_name DynamicSpaceSkybox
extends Node3D

## Gestore della proiezione scalare dello skybox diegetico e dell'illuminazione stellare dinamica.

@export var target_environment: Environment = null
@export var sun_light: DirectionalLight3D = null
var grid_manager: Node = null

# Nodo contenitore per gli impostori 3D / proiezioni dei corpi celesti sullo skybox
@onready var celestial_container: Node3D = Node3D.new()

# Raggio della sfera di proiezione dello skybox attorno alla nave/camera
const SKY_SPHERE_RADIUS: float = 400.0

var _rendered_entities: Array[Dictionary] = []

func _ready() -> void:
	name = "DynamicSpaceSkybox"
	if not celestial_container.is_inside_tree():
		add_child(celestial_container)
		celestial_container.name = "CelestialContainer"
	
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

## Rileva automaticamente WorldEnvironment e DirectionalLight3D se presenti nella scena genitore
func _auto_detect_scene_elements() -> void:
	if target_environment == null:
		var world_env: WorldEnvironment = get_node_or_null("../WorldEnvironment") as WorldEnvironment
		if world_env:
			target_environment = world_env.environment
	
	if sun_light == null:
		sun_light = get_node_or_null("../SunLight") as DirectionalLight3D

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
		var is_local: bool = ent.get("is_in_current_sector", false)
		var dir: Vector3 = ent.get("direction", Vector3.ZERO)
		var scale_factor: float = ent.get("apparent_angular_size", 1.0)
		var brightness: float = ent.get("apparent_brightness", 1.0)
		var ent_type: String = ent.get("type", "")
		
		# Proietta sulla sfera dello skybox
		var sphere_pos := dir * SKY_SPHERE_RADIUS if dir.length_squared() > 0.001 else Vector3.FORWARD * SKY_SPHERE_RADIUS
		
		var render_info := {
			"id": ent.get("id", ""),
			"name": ent.get("name", ""),
			"type": ent_type,
			"projected_pos": sphere_pos,
			"apparent_scale": scale_factor,
			"brightness": brightness,
			"distance_sectors": ent.get("distance_sectors", 0.0),
			"is_local": is_local
		}
		
		_rendered_entities.append(render_info)
		
		if celestial_container and is_instance_valid(celestial_container):
			_create_celestial_impostor_node(render_info)

func _create_celestial_impostor_node(info: Dictionary) -> void:
	var marker := Marker3D.new()
	marker.name = "Impostor_%s" % info.get("id", "Unknown")
	marker.position = info.get("projected_pos", Vector3.ZERO)
	marker.scale = Vector3.ONE * info.get("apparent_scale", 1.0)
	marker.set_meta("entity_data", info)
	celestial_container.add_child(marker)

func _on_sector_changed(_old_coords: Vector3i, _new_coords: Vector3i, _sec_data: SectorData) -> void:
	update_skybox()
