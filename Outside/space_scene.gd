class_name SpaceScene
extends Node3D

## Gestione della scena spaziale e fornitura dei riferimenti all'astronave.

@onready var spaceship: Spaceship = $Spaceship
@onready var sun_light: DirectionalLight3D = $SunLight

func _ready() -> void:
	pass

func get_spaceship() -> Spaceship:
	if spaceship == null:
		spaceship = get_node_or_null("Spaceship")
	return spaceship

func get_camera_global_transform(cam_id: String) -> Transform3D:
	if spaceship and is_instance_valid(spaceship):
		return spaceship.get_camera_global_transform(cam_id)
	return Transform3D.IDENTITY

func get_asteroids() -> Node3D:
	return get_node_or_null("Asteroids")

## Ritorna tutti i nodi asteroide presenti nella scena
func get_all_asteroids() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var ast_node := get_asteroids()
	if ast_node and is_instance_valid(ast_node):
		for child in ast_node.get_children():
			if child is Node3D and child.visible:
				result.append(child)
	var tree := get_tree()
	if tree:
		for node in tree.get_nodes_in_group("asteroids"):
			if node is Node3D and not result.has(node) and is_ancestor_of(node) and node.visible:
				result.append(node)
	return result

## Ritorna tutte le stazioni spaziali presenti nella scena
func get_stations() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in get_children():
		if child is SpaceStationEntity and child.visible:
			result.append(child)
	var tree := get_tree()
	if tree:
		for node in tree.get_nodes_in_group("stations"):
			if node is Node3D and not result.has(node) and is_ancestor_of(node) and node.visible:
				result.append(node)
	return result

## Ritorna tutti i relitti spaziali presenti nella scena
func get_derelicts() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in get_children():
		if child is DerelictShipEntity and child.visible:
			result.append(child)
	var tree := get_tree()
	if tree:
		for node in tree.get_nodes_in_group("derelicts"):
			if node is Node3D and not result.has(node) and is_ancestor_of(node) and node.visible:
				result.append(node)
	return result

## Ritorna tutte le navi ostili presenti nella scena (da CombatDirector o gerarchia)
func get_hostile_ships() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var tree := get_tree()
	if tree:
		for node in tree.get_nodes_in_group("enemy_ships"):
			if node is Node3D and is_instance_valid(node) and node.visible:
				result.append(node)
	var combat_dir := get_node_or_null("CombatDirector") as CombatDirector
	if combat_dir:
		for enemy in combat_dir.active_enemies:
			if enemy and is_instance_valid(enemy) and enemy.visible and not result.has(enemy):
				result.append(enemy)
	for child in get_children():
		if child is EnemyShipAI and child.visible and not result.has(child):
			result.append(child)
	return result

## Ritorna tutte le entità 3D attive nello spazio circostante
func get_active_space_entities() -> Array[Node3D]:
	return get_all_space_entities()

## Alias per get_active_space_entities()
func get_all_space_entities() -> Array[Node3D]:
	var entities: Array[Node3D] = []
	for a in get_all_asteroids():
		if not entities.has(a):
			entities.append(a)
	for s in get_stations():
		if not entities.has(s):
			entities.append(s)
	for d in get_derelicts():
		if not entities.has(d):
			entities.append(d)
	for h in get_hostile_ships():
		if not entities.has(h):
			entities.append(h)
	var drone := get_node_or_null("ServiceDrone") as Node3D
	if drone and is_instance_valid(drone) and drone.visible and not entities.has(drone):
		entities.append(drone)
	return entities

## Verifica se un'entità emette segnali radio o trasmissioni intercettabili
func has_radio_transmission(entity: Node3D) -> bool:
	if not entity or not is_instance_valid(entity):
		return false
	if "comms_frequency" in entity and float(entity.get("comms_frequency")) > 0.0:
		return true
	if "radio_frequency" in entity and float(entity.get("radio_frequency")) > 0.0:
		return true
	if entity is SpaceStationEntity:
		return true
	if entity is DerelictShipEntity:
		return entity.get("distress_beacon_active") if "distress_beacon_active" in entity else true
	if entity is EnemyShipAI:
		return true
	return false

## Ritorna la frequenza radio MHz emessa dall'entità
func get_radio_frequency(entity: Node3D) -> float:
	if not entity or not is_instance_valid(entity):
		return 0.0
	if "comms_frequency" in entity and float(entity.get("comms_frequency")) > 0.0:
		return float(entity.get("comms_frequency"))
	if "radio_frequency" in entity and float(entity.get("radio_frequency")) > 0.0:
		return float(entity.get("radio_frequency"))
	if entity is SpaceStationEntity:
		return 1840.0
	if entity is DerelictShipEntity:
		return 850.5
	if entity is EnemyShipAI:
		return 2185.2
	return 0.0

## Ritorna la firma radar / elettromagnetica dell'entità
func get_entity_signature(entity: Node3D) -> float:
	if not entity or not is_instance_valid(entity):
		return 0.0
	if "signal_signature" in entity:
		return float(entity.get("signal_signature"))
	if "signature" in entity:
		return float(entity.get("signature"))
	if entity is SpaceStationEntity:
		return 1.0
	if entity is DerelictShipEntity:
		return 0.70
	if entity is EnemyShipAI:
		return 0.85
	if entity is Asteroid or entity.name.begins_with("Asteroid"):
		return 0.80
	return 0.5

## Ritorna il tag IFF diegetico dell'entità
func get_entity_iff(entity: Node3D) -> String:
	if not entity or not is_instance_valid(entity):
		return "UNKNOWN"
	if "iff_tag" in entity:
		return str(entity.get("iff_tag"))
	if "threat_level" in entity:
		return str(entity.get("threat_level"))
	if entity is SpaceStationEntity:
		return "FRIENDLY"
	if entity is DerelictShipEntity:
		return "NEUTRAL"
	if entity is EnemyShipAI:
		return "HOSTILE"
	if entity is Asteroid or entity.name.begins_with("Asteroid"):
		return "HAZARD"
	return "NEUTRAL"
