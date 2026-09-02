class_name SectorData
extends Resource

## Rappresenta i dati e lo stato di una singola cella/settore della griglia del sistema stellare.

@export var sector_id: String = "SEC-00-00"
@export var coordinates: Vector3i = Vector3i.ZERO
@export var sector_name: String = "Settore Inesplorato"
@export var sector_type: String = "DEEP_SPACE"
@export var description: String = "Spazio profondo standard privo di formazioni rilevanti."
@export var security_level: String = "MEDIUM" # HIGH, MEDIUM, LOW, ANARCHY, MILITARY
@export var traffic_density: float = 0.1 # 0.0 - 1.0

# Dati Ambientali & Illuminazione
@export var ambient_light_color: Color = Color(0.2, 0.22, 0.3, 1.0)
@export var ambient_light_energy: float = 0.5
@export var sun_light_energy: float = 1.3
@export var sun_light_color: Color = Color(1.0, 0.96, 0.9, 1.0)
@export var is_in_planetary_shadow: bool = false
@export var shadow_occlusion_factor: float = 0.0 # 0.0 = luce diretta piena, 1.0 = oscuramento totale
@export var solar_panels_blackout: bool = false

# Liste entità e pericoli
@export var macro_entities: Array[Dictionary] = []
@export var environmental_hazards: Array[Dictionary] = []

func _init(p_coords: Vector3i = Vector3i.ZERO, p_id: String = "", p_name: String = "") -> void:
	coordinates = p_coords
	if not p_id.is_empty():
		sector_id = p_id
	else:
		sector_id = format_coords_to_id(coordinates)
	
	if not p_name.is_empty():
		sector_name = p_name
	else:
		sector_name = "Settore %s" % sector_id

## Converte coordinate Vector3i nel formato standard SEC-XX-YY (o SEC-XX-YY-ZZ se Z != 0)
static func format_coords_to_id(coords: Vector3i) -> String:
	var x_str := "%02d" % coords.x if coords.x >= 0 else "-%02d" % abs(coords.x)
	var y_str := "%02d" % coords.y if coords.y >= 0 else "-%02d" % abs(coords.y)
	if coords.z == 0:
		return "SEC-%s-%s" % [x_str, y_str]
	var z_str := "%02d" % coords.z if coords.z >= 0 else "-%02d" % abs(coords.z)
	return "SEC-%s-%s-%s" % [x_str, y_str, z_str]

## Estrae coordinate Vector3i da una stringa formato SEC-XX-YY o SEC-XX-YY-ZZ
static func parse_id_to_coords(id_str: String) -> Vector3i:
	var clean := id_str.strip_edges().to_upper()
	if not clean.begins_with("SEC-"):
		return Vector3i.ZERO
	
	var parts := clean.substr(4).split("-")
	var x: int = 0
	var y: int = 0
	var z: int = 0
	
	if parts.size() >= 2:
		x = int(parts[0])
		y = int(parts[1])
	if parts.size() >= 3:
		z = int(parts[2])
		
	return Vector3i(x, y, z)

## Aggiunge una macro-entità al settore
func add_entity(entity: Dictionary) -> void:
	if not entity.has("id"):
		entity["id"] = "ENT_%d" % macro_entities.size()
	macro_entities.append(entity)

## Rimuove un'entità in base all'ID
func remove_entity(entity_id: String) -> bool:
	for i in range(macro_entities.size()):
		if macro_entities[i].get("id") == entity_id:
			macro_entities.remove_at(i)
			return true
	return false

## Ritorna tutte le entità di un determinato tipo (es. STAR, PLANET, GAS_GIANT, STATION, ASTEROID_FIELD, WRECK, PATROL)
func get_entities_by_type(type_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ent in macro_entities:
		if ent.get("type", "").to_upper() == type_name.to_upper():
			result.append(ent)
	return result

## Verifica se il settore contiene un tipo di entità
func has_entity_of_type(type_name: String) -> bool:
	for ent in macro_entities:
		if ent.get("type", "").to_upper() == type_name.to_upper():
			return true
	return false

## Ritorna corpi celesti massicci capaci di proiettare coni d'ombra
func get_occluding_bodies() -> Array[Dictionary]:
	var occluders: Array[Dictionary] = []
	for ent in macro_entities:
		var t: String = ent.get("type", "").to_upper()
		if t in ["PLANET", "GAS_GIANT", "MOON", "SUPER_MASSIVE_STATION"]:
			occluders.append(ent)
	return occluders

## Serializzazione in dizionario
func to_dict() -> Dictionary:
	return {
		"sector_id": sector_id,
		"coordinates": [coordinates.x, coordinates.y, coordinates.z],
		"sector_name": sector_name,
		"sector_type": sector_type,
		"description": description,
		"security_level": security_level,
		"traffic_density": traffic_density,
		"ambient_light_color": [ambient_light_color.r, ambient_light_color.g, ambient_light_color.b, ambient_light_color.a],
		"ambient_light_energy": ambient_light_energy,
		"sun_light_energy": sun_light_energy,
		"sun_light_color": [sun_light_color.r, sun_light_color.g, sun_light_color.b, sun_light_color.a],
		"is_in_planetary_shadow": is_in_planetary_shadow,
		"shadow_occlusion_factor": shadow_occlusion_factor,
		"solar_panels_blackout": solar_panels_blackout,
		"macro_entities": macro_entities.duplicate(true),
		"environmental_hazards": environmental_hazards.duplicate(true)
	}

## Deserializzazione da dizionario
func from_dict(data: Dictionary) -> void:
	sector_id = data.get("sector_id", sector_id)
	if data.has("coordinates") and data["coordinates"] is Array and data["coordinates"].size() >= 3:
		coordinates = Vector3i(data["coordinates"][0], data["coordinates"][1], data["coordinates"][2])
	sector_name = data.get("sector_name", sector_name)
	sector_type = data.get("sector_type", sector_type)
	description = data.get("description", description)
	security_level = data.get("security_level", security_level)
	traffic_density = data.get("traffic_density", traffic_density)
	
	if data.has("ambient_light_color") and data["ambient_light_color"] is Array and data["ambient_light_color"].size() >= 4:
		var c = data["ambient_light_color"]
		ambient_light_color = Color(c[0], c[1], c[2], c[3])
	ambient_light_energy = data.get("ambient_light_energy", ambient_light_energy)
	
	if data.has("sun_light_color") and data["sun_light_color"] is Array and data["sun_light_color"].size() >= 4:
		var sc = data["sun_light_color"]
		sun_light_color = Color(sc[0], sc[1], sc[2], sc[3])
	sun_light_energy = data.get("sun_light_energy", sun_light_energy)
	
	is_in_planetary_shadow = data.get("is_in_planetary_shadow", is_in_planetary_shadow)
	shadow_occlusion_factor = data.get("shadow_occlusion_factor", shadow_occlusion_factor)
	solar_panels_blackout = data.get("solar_panels_blackout", solar_panels_blackout)
	
	if data.has("macro_entities") and data["macro_entities"] is Array:
		macro_entities.clear()
		for item in data["macro_entities"]:
			if item is Dictionary:
				macro_entities.append(item.duplicate(true))
				
	if data.has("environmental_hazards") and data["environmental_hazards"] is Array:
		environmental_hazards.clear()
		for item in data["environmental_hazards"]:
			if item is Dictionary:
				environmental_hazards.append(item.duplicate(true))
