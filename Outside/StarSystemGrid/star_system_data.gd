class_name StarSystemData
extends Resource

## Rappresenta i dati completi di un Sistema Stellare (macro-corpi, settori predefiniti, parametri di illuminazione).

@export var system_id: String = "SYS-HELIOS-01"
@export var system_name: String = "Helios Nova System"
@export var description: String = "Sistema stellare principale."
@export var primary_star_name: String = "Helios Nova"
@export var primary_star_coords: Vector3i = Vector3i.ZERO
@export var primary_star_color: Color = Color(1.0, 0.96, 0.9, 1.0)
@export var primary_star_energy: float = 1.3
@export var primary_star_radius_km: float = 696340.0
@export var primary_star_mass_tons: float = 1.989e27

# Catalogo macro-corpi del sistema
@export var celestial_bodies: Array[Dictionary] = []

# Mappa/Lista di settori custom predefiniti o speciali
@export var custom_sectors: Array[Dictionary] = []

func _init(p_id: String = "", p_name: String = "") -> void:
	if not p_id.is_empty():
		system_id = p_id
	if not p_name.is_empty():
		system_name = p_name

## Aggiunge o aggiorna un corpo celeste nel catalogo
func add_or_update_body(body_data: Dictionary) -> void:
	var body_id: String = body_data.get("id", "")
	if body_id.is_empty():
		body_id = "BODY_%d" % celestial_bodies.size()
		body_data["id"] = body_id
	
	for i in range(celestial_bodies.size()):
		if celestial_bodies[i].get("id", "") == body_id:
			celestial_bodies[i] = body_data.duplicate(true)
			return
			
	celestial_bodies.append(body_data.duplicate(true))

## Rimuove un corpo celeste per ID
func remove_body(body_id: String) -> bool:
	for i in range(celestial_bodies.size()):
		if celestial_bodies[i].get("id", "") == body_id:
			celestial_bodies.remove_at(i)
			return true
	return false

## Ritorna un corpo celeste per ID
func get_body(body_id: String) -> Dictionary:
	for b in celestial_bodies:
		if b.get("id", "") == body_id:
			return b
	return {}

## Aggiunge o aggiorna un settore custom
func add_or_update_custom_sector(sector_dict: Dictionary) -> void:
	var sec_id: String = sector_dict.get("sector_id", "")
	if sec_id.is_empty():
		return
	for i in range(custom_sectors.size()):
		if custom_sectors[i].get("sector_id", "") == sec_id:
			custom_sectors[i] = sector_dict.duplicate(true)
			return
	custom_sectors.append(sector_dict.duplicate(true))

## Rimuove un settore custom
func remove_custom_sector(sec_id: String) -> bool:
	for i in range(custom_sectors.size()):
		if custom_sectors[i].get("sector_id", "") == sec_id:
			custom_sectors.remove_at(i)
			return true
	return false

## Serializzazione in dizionario
func to_dict() -> Dictionary:
	var bodies_serialized: Array[Dictionary] = []
	for b in celestial_bodies:
		var copy := b.duplicate(true)
		if copy.has("coords") and copy["coords"] is Vector3i:
			var c: Vector3i = copy["coords"]
			copy["coords"] = [c.x, c.y, c.z]
		if copy.has("color") and copy["color"] is Color:
			var col: Color = copy["color"]
			copy["color"] = [col.r, col.g, col.b, col.a]
		bodies_serialized.append(copy)

	return {
		"system_id": system_id,
		"system_name": system_name,
		"description": description,
		"primary_star_name": primary_star_name,
		"primary_star_coords": [primary_star_coords.x, primary_star_coords.y, primary_star_coords.z],
		"primary_star_color": [primary_star_color.r, primary_star_color.g, primary_star_color.b, primary_star_color.a],
		"primary_star_energy": primary_star_energy,
		"primary_star_radius_km": primary_star_radius_km,
		"primary_star_mass_tons": primary_star_mass_tons,
		"celestial_bodies": bodies_serialized,
		"custom_sectors": custom_sectors.duplicate(true)
	}

## Deserializzazione da dizionario
func from_dict(data: Dictionary) -> void:
	system_id = data.get("system_id", system_id)
	system_name = data.get("system_name", system_name)
	description = data.get("description", description)
	primary_star_name = data.get("primary_star_name", primary_star_name)
	
	if data.has("primary_star_coords") and data["primary_star_coords"] is Array and data["primary_star_coords"].size() >= 3:
		primary_star_coords = Vector3i(int(data["primary_star_coords"][0]), int(data["primary_star_coords"][1]), int(data["primary_star_coords"][2]))
		
	if data.has("primary_star_color") and data["primary_star_color"] is Array and data["primary_star_color"].size() >= 4:
		var col = data["primary_star_color"]
		primary_star_color = Color(col[0], col[1], col[2], col[3])
		
	primary_star_energy = data.get("primary_star_energy", primary_star_energy)
	primary_star_radius_km = data.get("primary_star_radius_km", primary_star_radius_km)
	primary_star_mass_tons = data.get("primary_star_mass_tons", primary_star_mass_tons)
	
	if data.has("celestial_bodies") and data["celestial_bodies"] is Array:
		celestial_bodies.clear()
		for b in data["celestial_bodies"]:
			if b is Dictionary:
				var body_dict := (b as Dictionary).duplicate(true)
				if body_dict.has("coords"):
					if body_dict["coords"] is Array and body_dict["coords"].size() >= 3:
						body_dict["coords"] = Vector3i(int(body_dict["coords"][0]), int(body_dict["coords"][1]), int(body_dict["coords"][2]))
					elif body_dict["coords"] is String:
						body_dict["coords"] = SectorData.parse_id_to_coords(body_dict["coords"])
				if body_dict.has("color") and body_dict["color"] is Array and body_dict["color"].size() >= 4:
					var c = body_dict["color"]
					body_dict["color"] = Color(c[0], c[1], c[2], c[3])
				celestial_bodies.append(body_dict)
				
	if data.has("custom_sectors") and data["custom_sectors"] is Array:
		custom_sectors.clear()
		for s in data["custom_sectors"]:
			if s is Dictionary:
				custom_sectors.append(s.duplicate(true))
