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
	id = data.get("id", id)
	name = data.get("name", name)
	type = data.get("type", type)
	
	if data.has("coords"):
		var c: Variant = data["coords"]
		if c is Array and c.size() >= 3:
			coords = Vector3i(int(c[0]), int(c[1]), int(c[2]))
		elif c is String:
			coords = SectorData.parse_id_to_coords(c)
		elif c is Vector3i:
			coords = c
	
	radius_km = float(data.get("radius_km", radius_km))
	mass_tons = float(data.get("mass_tons", mass_tons))
	luminosity = float(data.get("luminosity", luminosity))
	
	if data.has("color"):
		var col: Variant = data["color"]
		if col is Array and col.size() >= 3:
			var a := float(col[3]) if col.size() > 3 else 1.0
			color = Color(float(col[0]), float(col[1]), float(col[2]), a)
		elif col is Color:
			color = col
		
	occluding = bool(data.get("occluding", occluding))
	description = data.get("description", description)
	temperature = float(data.get("temperature", temperature))
	atmosphere = data.get("atmosphere", atmosphere)
	
	if data.has("resources") and data["resources"] is Array:
		resources.clear()
		for r in data["resources"]:
			resources.append(str(r))
