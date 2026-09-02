class_name StarSystemData
extends Resource

## Rappresenta i dati completi di un Sistema Stellare (macro-corpi, settori predefiniti, parametri di illuminazione).

@export var system_id: String = "SYS-HELIOS-01"
@export var system_name: String = "Helios Nova System"
@export var description: String = "Sistema stellare principale."
@export var primary_star_name: String = "Helios Nova"
@export var primary_star_coords := Vector3i.ZERO
@export var primary_star_color := Color(1.0, 0.96, 0.9, 1.0)
@export var primary_star_energy: float = 1.3
@export var primary_star_radius_km: float = 696340.0
@export var primary_star_mass_tons: float = 1.989e27

# Catalogo macro-corpi del sistema (Array di CelestialBodyData o Dictionary)
@export var celestial_bodies: Array = []

# Mappa/Lista di settori custom predefiniti o speciali
@export var custom_sectors: Array[Dictionary] = []

func _init(p_id: String = "", p_name: String = "") -> void:
	if not p_id.is_empty():
		system_id = p_id
	if not p_name.is_empty():
		system_name = p_name

## Aggiunge o aggiorna un corpo celeste nel catalogo
func add_or_update_body(p_body: Variant) -> void:
	var body: CelestialBodyData = _ensure_body_is_object(p_body)
	if not body:
		return
		
	if body.id.is_empty():
		body.id = "BODY_%d" % celestial_bodies.size()
	
	for i in range(celestial_bodies.size()):
		var b = celestial_bodies[i]
		var bid = b.get("id") if b is Dictionary else b.id
		if bid == body.id:
			celestial_bodies[i] = body
			return
			
	celestial_bodies.append(body)

## Rimuove un corpo celeste per ID
func remove_body(body_id: String) -> bool:
	for i in range(celestial_bodies.size()):
		var b = celestial_bodies[i]
		var bid = b.get("id") if b is Dictionary else b.id
		if bid == body_id:
			celestial_bodies.remove_at(i)
			return true
	return false

## Ritorna un corpo celeste per ID
func get_body(body_id: String) -> CelestialBodyData:
	for b in celestial_bodies:
		var bid = b.get("id", "") if b is Dictionary else b.id
		if bid == body_id:
			return _ensure_body_is_object(b)
	return null

## Trova e ritorna la stazione spaziale primaria/di partenza del sistema stellare
func find_primary_station() -> CelestialBodyData:
	for b in celestial_bodies:
		var b_type = b.get("type", "") if b is Dictionary else b.type
		if b_type.to_upper() == "STATION":
			return _ensure_body_is_object(b)
	return null

func _ensure_body_is_object(b) -> CelestialBodyData:
	if b is CelestialBodyData:
		return b
	if b is Dictionary:
		var body := CelestialBodyData.new()
		body.from_dict(b)
		# Aggiorniamo l'array per il futuro
		for i in range(celestial_bodies.size()):
			if celestial_bodies[i] == b:
				celestial_bodies[i] = body
				break
		return body
	return null

## Calcola le coordinate di un settore adiacente libero (a distanza 1 casella di griglia) rispetto alla stazione
func find_adjacent_spawn_sector(station_coords: Vector3i) -> Vector3i:
	# Settori adiacenti candidati su assi X e Y (+X, -X, +Y, -Y)
	var candidate_offsets: Array[Vector3i] = [
		Vector3i(0, -1, 0),
		Vector3i(1, 0, 0),
		Vector3i(0, 1, 0),
		Vector3i(-1, 0, 0),
		Vector3i(1, 1, 0),
		Vector3i(-1, -1, 0)
	]
	
	# Mappa coordinate già occupate da macro-corpi celesti
	var occupied_coords: Dictionary = {}
	for b in celestial_bodies:
		var b_coords = b.get("coords", Vector3i.ZERO) if b is Dictionary else b.coords
		if b_coords is Array:
			b_coords = Vector3i(b_coords[0], b_coords[1], b_coords[2])
		occupied_coords[b_coords] = true
	
	for offset in candidate_offsets:
		var cand := station_coords + offset
		if not occupied_coords.has(cand):
			return cand
	
	# Se tutti i candidati sono occupati, ritorna il primo offset standard
	return station_coords + Vector3i(0, -1, 0)

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

func get_primary_star_coords() -> Vector3i:
	if primary_star_coords is Vector3i:
		return primary_star_coords
	return Vector3i.ZERO

func get_primary_star_color() -> Color:
	if primary_star_color is Color:
		return primary_star_color
	return Color(1.0, 0.96, 0.9, 1.0)

## Serializzazione in dizionario
func to_dict() -> Dictionary:
	var bodies_serialized: Array[Dictionary] = []
	for b in celestial_bodies:
		bodies_serialized.append(b.to_dict() if b is CelestialBodyData else b)

	var p_coords = get_primary_star_coords()
	var p_color = get_primary_star_color()

	return {
		"system_id": system_id,
		"system_name": system_name,
		"description": description,
		"primary_star_name": primary_star_name,
		"primary_star_coords": [p_coords.x, p_coords.y, p_coords.z],
		"primary_star_color": [p_color.r, p_color.g, p_color.b, p_color.a],
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
				var body := CelestialBodyData.new()
				body.from_dict(b)
				celestial_bodies.append(body)
			elif b is CelestialBodyData:
				celestial_bodies.append(b)
				
	if data.has("custom_sectors") and data["custom_sectors"] is Array:
		custom_sectors.clear()
		for s in data["custom_sectors"]:
			if s is Dictionary:
				custom_sectors.append(s.duplicate(true))

## Clona l'istanza corrente
func clone() -> StarSystemData:
	var copy := StarSystemData.new()
	copy.from_dict(to_dict())
	return copy

## Crea e popola il sistema solare standard di default (Helios Nova System)
func create_default_system() -> void:
	system_id = "SYS-HELIOS-01"
	system_name = "Helios Nova System"
	description = "Sistema stellare principale Dark Nova Helios."
	primary_star_name = "Helios Nova"
	primary_star_coords = Vector3i.ZERO
	primary_star_color = Color(1.0, 0.96, 0.9, 1.0)
	primary_star_energy = 1.3
	primary_star_radius_km = 696340.0
	primary_star_mass_tons = 1.989e27
	
	var bodies_data: Array[Dictionary] = [
		{
			"id": "STAR_SOL_PRIME",
			"name": "Helios Nova (Stella Primaria)",
			"type": "STAR",
			"coords": [0, 0, 0],
			"radius_km": 696340.0,
			"mass_tons": 1.989e27,
			"luminosity": 1.0,
			"color": [1.0, 0.96, 0.9, 1.0],
			"occluding": false,
			"description": "Stella di sequenza principale al centro del sistema."
		},
		{
			"id": "PLANET_VULCAN",
			"name": "Vulcanus (Pianeta Roccioso)",
			"type": "PLANET",
			"coords": [1, 3, 0],
			"radius_km": 4800.0,
			"mass_tons": 3.3e20,
			"occluding": true,
			"description": "Mondo lavico interno ad alta densità metallica."
		},
		{
			"id": "PLANET_TERRA_NOVA",
			"name": "Terra Nova Prime",
			"type": "PLANET",
			"coords": [4, 8, 0],
			"radius_km": 6371.0,
			"mass_tons": 5.97e21,
			"occluding": true,
			"description": "Pianeta abitabile dell'orbita mediana con ecosfera stabilizzata."
		},
		{
			"id": "MOON_LUNA_SEC",
			"name": "Selene Secundus",
			"type": "MOON",
			"coords": [4, 8, 0],
			"radius_km": 1737.0,
			"mass_tons": 7.35e19,
			"occluding": true,
			"description": "Luna mineraria di Terra Nova."
		},
		{
			"id": "BELT_CERES_EX",
			"name": "Fascia d'Asteroidi Interna",
			"type": "ASTEROID_FIELD",
			"coords": [3, 10, 0],
			"radius_km": 25000.0,
			"mass_tons": 1.5e18,
			"occluding": false,
			"description": "Denso campo di detriti e minerali preziosi."
		},
		{
			"id": "STATION_VALKYRIE",
			"name": "Stazione Spaziale Valkyrie",
			"type": "STATION",
			"coords": [4, 12, 0],
			"radius_km": 15.0,
			"mass_tons": 8.5e10,
			"occluding": false,
			"description": "Hub orbitale militare e commerciale dell'avamposto."
		},
		{
			"id": "PATROL_VANGUARD",
			"name": "Pattuglia Vanguard-7",
			"type": "PATROL",
			"coords": [4, 11, 0],
			"radius_km": 0.5,
			"mass_tons": 45000.0,
			"occluding": false,
			"description": "Squadriglia di caccia di sicurezza perimetrale."
		},
		{
			"id": "WRECK_TITAN_GRAVE",
			"name": "Relitto Incrociatore Titan-04",
			"type": "WRECK",
			"coords": [5, 14, 0],
			"radius_km": 2.5,
			"mass_tons": 1.2e8,
			"occluding": false,
			"description": "Relitto bellico abbandonato ricco di materiali rari."
		},
		{
			"id": "GAS_GIANT_KRONOS",
			"name": "Kronos Titan (Gigante Gassoso)",
			"type": "GAS_GIANT",
			"coords": [8, 20, 0],
			"radius_km": 69911.0,
			"mass_tons": 1.89e24,
			"occluding": true,
			"description": "Imponente gigante gassoso con complessi anelli d'idrogeno."
		},
		{
			"id": "GAS_GIANT_AETHER",
			"name": "Aetheris (Gigante di Ghiaccio)",
			"type": "GAS_GIANT",
			"coords": [-12, 16, 0],
			"radius_km": 25362.0,
			"mass_tons": 8.68e22,
			"occluding": true,
			"description": "Gigante ghiacciato all'estrema periferia del sistema."
		}
	]
	
	celestial_bodies.clear()
	for b_dict in bodies_data:
		var body := CelestialBodyData.new()
		body.from_dict(b_dict)
		celestial_bodies.append(body)
	
	custom_sectors = []

static func get_default_star_system() -> StarSystemData:
	const PATH := "res://Outside/StarSystemGrid/default_star_system.tres"
	if ResourceLoader.exists(PATH):
		var res = ResourceLoader.load(PATH)
		if res is StarSystemData:
			return res as StarSystemData
	var sys := StarSystemData.new()
	sys.create_default_system()
	return sys
