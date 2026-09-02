class_name CelestialBodyData
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var type: String = "planet" # planet, star, moon, station, asteroid_belt
@export var coords: Vector3i = Vector3i.ZERO
@export var radius_km: float = 10.0
@export var mass_tons: float = 0.0
@export var luminosity: float = 0.0
@export var color: Color = Color.WHITE
@export var occluding: bool = true
@export var description: String = ""
@export var temperature: float = 20.0 # Celsius
@export var atmosphere: String = "none"
@export var resources: Array[String] = []

func _init(p_id: String = "", p_name: String = "", p_type: String = "planet", p_coords: Vector3i = Vector3i.ZERO) -> void:
	id = p_id
	name = p_name
	type = p_type
	coords = p_coords

## Serializzazione in dizionario
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"type": type,
		"coords": [coords.x, coords.y, coords.z],
		"radius_km": radius_km,
		"mass_tons": mass_tons,
		"luminosity": luminosity,
		"color": [color.r, color.g, color.b, color.a],
		"occluding": occluding,
		"description": description,
		"temperature": temperature,
		"atmosphere": atmosphere,
		"resources": resources.duplicate()
	}

## Deserializzazione da dizionario
func from_dict(data: Dictionary) -> void:
	id = data.get("id")
	name = data.get("name")
	type = data.get("type", type)
	
	if data.has("coords"):
		if data["coords"] is Array and data["coords"].size() >= 3:
			coords = Vector3i(int(data["coords"][0]), int(data["coords"][1]), int(data["coords"][2]))
		elif data["coords"] is String:
			# Se SectorData è disponibile globalmente, usa il suo parser
			coords = SectorData.parse_id_to_coords(data["coords"])
	
	radius_km = data.get("radius_km", radius_km)
	mass_tons = data.get("mass_tons", mass_tons)
	luminosity = data.get("luminosity", luminosity)
	
	if data.has("color") and data["color"] is Array and data["color"].size() >= 4:
		var c :Color = data["color"]
		color = Color(c[0], c[1], c[2], c[3])
		
	occluding = data.get("occluding", occluding)
	description = data.get("description", description)
	temperature = data.get("temperature", temperature)
	atmosphere = data.get("atmosphere", atmosphere)
	
	if data.has("resources") and data["resources"] is Array:
		resources.clear()
		for r:Resource in data["resources"]:
			resources.append(str(r))
