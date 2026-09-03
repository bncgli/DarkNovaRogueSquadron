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
@export var macro_entities: Array = []:
	set(val):
		macro_entities = _ensure_objects(val, CelestialBodyData)

@export var environmental_hazards: Array = []:
	set(val):
		environmental_hazards = _ensure_objects(val, EnvironmentalHazardData)

func _ensure_objects(list: Array, type: GDScript) -> Array:
	var new_list := []
	for item in list:
		if item is Dictionary:
			var obj = type.new()
			if obj.has_method("from_dict"):
				obj.from_dict(item)
			new_list.append(obj)
		else:
			new_list.append(item)
	return new_list

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
func add_entity(p_entity: Variant) -> void:
	var entity: CelestialBodyData = null
	if p_entity is CelestialBodyData:
		entity = p_entity
	elif p_entity is Dictionary:
		entity = CelestialBodyData.new()
		entity.from_dict(p_entity)
	
	if not entity:
		return

	if entity.id.is_empty():
		entity.id = "ENT_%d" % macro_entities.size()
	macro_entities.append(entity)

## Rimuove un'entità in base all'ID
func remove_entity(entity_id: String) -> bool:
	for i in range(macro_entities.size()):
		if macro_entities[i].id == entity_id:
			macro_entities.remove_at(i)
			return true
	return false

## Ritorna tutte le entità di un determinato tipo (es. STAR, PLANET, GAS_GIANT, STATION, ASTEROID_FIELD, WRECK, PATROL)
func get_entities_by_type(type_name: String) -> Array[CelestialBodyData]:
	var result: Array[CelestialBodyData] = []
	for ent in macro_entities:
		if ent.type.to_upper() == type_name.to_upper():
			result.append(ent)
	return result

## Verifica se il settore contiene un tipo di entità
func has_entity_of_type(type_name: String) -> bool:
	for ent in macro_entities:
		if ent.type.to_upper() == type_name.to_upper():
			return true
	return false

## Ritorna corpi celesti massicci capaci di proiettare coni d'ombra
func get_occluding_bodies() -> Array[CelestialBodyData]:
	var occluders: Array[CelestialBodyData] = []
	for ent in macro_entities:
		var t: String = ent.type.to_upper()
		if t in ["PLANET", "GAS_GIANT", "MOON", "SUPER_MASSIVE_STATION"]:
			occluders.append(ent)
	return occluders

## Serializzazione in dizionario
func to_dict() -> Dictionary:
	var entities_serialized: Array[Dictionary] = []
	for ent in macro_entities:
		entities_serialized.append(ent.to_dict())
	
	var hazards_serialized: Array[Dictionary] = []
	for haz in environmental_hazards:
		hazards_serialized.append(haz.to_dict())

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
		"macro_entities": entities_serialized,
		"environmental_hazards": hazards_serialized
	}

## Deserializzazione da dizionario
func from_dict(data: Dictionary) -> void:
	sector_id = str(data.get("sector_id", sector_id))
	if data.has("coordinates"):
		var coords_data: Variant = data["coordinates"]
		if coords_data is Array and coords_data.size() >= 3:
			coordinates = Vector3i(int(coords_data[0]), int(coords_data[1]), int(coords_data[2]))
		elif coords_data is Vector3i:
			coordinates = coords_data
			
	sector_name = str(data.get("sector_name", sector_name))
	sector_type = str(data.get("sector_type", sector_type))
	description = str(data.get("description", description))
	security_level = str(data.get("security_level", security_level))
	traffic_density = float(data.get("traffic_density", traffic_density))
	
	if data.has("ambient_light_color"):
		var c: Variant = data["ambient_light_color"]
		if c is Array and c.size() >= 3:
			var a := float(c[3]) if c.size() > 3 else 1.0
			ambient_light_color = Color(float(c[0]), float(c[1]), float(c[2]), a)
		elif c is Color:
			ambient_light_color = c
	ambient_light_energy = float(data.get("ambient_light_energy", ambient_light_energy))
	
	if data.has("sun_light_color"):
		var sc: Variant = data["sun_light_color"]
		if sc is Array and sc.size() >= 3:
			var a := float(sc[3]) if sc.size() > 3 else 1.0
			sun_light_color = Color(float(sc[0]), float(sc[1]), float(sc[2]), a)
		elif sc is Color:
			sun_light_color = sc
	sun_light_energy = float(data.get("sun_light_energy", sun_light_energy))
	
	is_in_planetary_shadow = bool(data.get("is_in_planetary_shadow", is_in_planetary_shadow))
	shadow_occlusion_factor = float(data.get("shadow_occlusion_factor", shadow_occlusion_factor))
	solar_panels_blackout = bool(data.get("solar_panels_blackout", solar_panels_blackout))
	
	if data.has("macro_entities") and data["macro_entities"] is Array:
		macro_entities = data["macro_entities"]
				
	if data.has("environmental_hazards") and data["environmental_hazards"] is Array:
		environmental_hazards = data["environmental_hazards"]
