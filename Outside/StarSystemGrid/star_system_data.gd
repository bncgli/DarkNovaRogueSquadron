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

# Catalogo macro-corpi del sistema
@export var celestial_bodies: Array = []:
	set(val):
		celestial_bodies = _ensure_objects(val, CelestialBodyData)

# Mappa/Lista di settori custom predefiniti o speciali
@export var custom_sectors: Array = []:
	set(val):
		custom_sectors = _ensure_objects(val, SectorData)

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

func _init(p_id: String = "", p_name: String = "") -> void:
	if not p_id.is_empty():
		system_id = p_id
	if not p_name.is_empty():
		system_name = p_name

## Aggiunge o aggiorna un corpo celeste nel catalogo
func add_or_update_body(p_body: Variant) -> void:
	var body: CelestialBodyData = null
	if p_body is CelestialBodyData:
		body = p_body
	elif p_body is Dictionary:
		body = CelestialBodyData.new()
		body.from_dict(p_body)
	
	if not body:
		return
		
	if body.id.is_empty():
		body.id = "BODY_%d" % celestial_bodies.size()
	
	for i in range(celestial_bodies.size()):
		if celestial_bodies[i].id == body.id:
			celestial_bodies[i] = body
			return
			
	celestial_bodies.append(body)

## Rimuove un corpo celeste per ID
func remove_body(body_id: String) -> bool:
	for i in range(celestial_bodies.size()):
		if celestial_bodies[i].id == body_id:
			celestial_bodies.remove_at(i)
			return true
	return false

## Ritorna un corpo celeste per ID
func get_body(body_id: String) -> CelestialBodyData:
	for b in celestial_bodies:
		if b.id == body_id:
			return b
	return null

## Trova e ritorna la stazione spaziale primaria/di partenza del sistema stellare
func find_primary_station() -> CelestialBodyData:
	for b in celestial_bodies:
		if b.type.to_upper() == "STATION":
			return b
	return null

func _ensure_body_is_object(b) -> CelestialBodyData:
	if b is CelestialBodyData:
		return b
	if b is Dictionary:
		var body := CelestialBodyData.new()
		body.from_dict(b)
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
		occupied_coords[b.coords] = true
	
	for offset in candidate_offsets:
		var cand := station_coords + offset
		if not occupied_coords.has(cand):
			return cand
	
	# Se tutti i candidati sono occupati, ritorna il primo offset standard
	return station_coords + Vector3i(0, -1, 0)

## Aggiunge o aggiorna un settore custom
func add_or_update_custom_sector(p_sector: Variant) -> void:
	var sector: SectorData = null
	if p_sector is SectorData:
		sector = p_sector
	elif p_sector is Dictionary:
		sector = SectorData.new()
		sector.from_dict(p_sector)
	
	if not sector or sector.sector_id.is_empty():
		return

	for i in range(custom_sectors.size()):
		if custom_sectors[i].sector_id == sector.sector_id:
			custom_sectors[i] = sector
			return
	custom_sectors.append(sector)

## Rimuove un settore custom
func remove_custom_sector(sec_id: String) -> bool:
	for i in range(custom_sectors.size()):
		if custom_sectors[i].sector_id == sec_id:
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
		bodies_serialized.append(b.to_dict())

	var sectors_serialized: Array[Dictionary] = []
	for s in custom_sectors:
		sectors_serialized.append(s.to_dict())

	var p_coords := get_primary_star_coords()
	var p_color := get_primary_star_color()

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
		"custom_sectors": sectors_serialized
	}

## Deserializzazione da dizionario
func from_dict(data: Dictionary) -> void:
	system_id = str(data.get("system_id", system_id))
	system_name = str(data.get("system_name", system_name))
	description = str(data.get("description", description))
	primary_star_name = str(data.get("primary_star_name", primary_star_name))
	
	if data.has("primary_star_coords"):
		var psc: Variant = data["primary_star_coords"]
		if psc is Array and psc.size() >= 3:
			primary_star_coords = Vector3i(int(psc[0]), int(psc[1]), int(psc[2]))
		elif psc is Vector3i:
			primary_star_coords = psc
		
	if data.has("primary_star_color"):
		var col: Variant = data["primary_star_color"]
		if col is Array and col.size() >= 3:
			var a := float(col[3]) if col.size() > 3 else 1.0
			primary_star_color = Color(float(col[0]), float(col[1]), float(col[2]), a)
		elif col is Color:
			primary_star_color = col
		
	primary_star_energy = float(data.get("primary_star_energy", primary_star_energy))
	primary_star_radius_km = float(data.get("primary_star_radius_km", primary_star_radius_km))
	primary_star_mass_tons = float(data.get("primary_star_mass_tons", primary_star_mass_tons))
	
	if data.has("celestial_bodies") and data["celestial_bodies"] is Array:
		celestial_bodies = data["celestial_bodies"]
				
	if data.has("custom_sectors") and data["custom_sectors"] is Array:
		custom_sectors = data["custom_sectors"]

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

## Verifica se il sistema è privo di corpi celesti
func is_empty() -> bool:
	return celestial_bodies.is_empty()

## Genera un sistema stellare casuale procedurale
func generate_random_system(seed_str: String = "") -> void:
	var rng := RandomNumberGenerator.new()
	if seed_str.is_empty():
		rng.randomize()
	else:
		rng.seed = hash(seed_str)
	
	system_id = "SYS-RAND-%d" % rng.randi_range(1000, 9999)
	system_name = "Settore Inesplorato %s" % system_id
	description = "Sistema stellare generato proceduralmente in uno spazio profondo."
	
	primary_star_name = "Stella %X" % rng.randi()
	primary_star_coords = Vector3i.ZERO
	primary_star_color = Color(rng.randf_range(0.7, 1.0), rng.randf_range(0.7, 1.0), rng.randf_range(0.7, 1.0), 1.0)
	primary_star_energy = rng.randf_range(0.8, 1.8)
	primary_star_radius_km = rng.randf_range(400000.0, 900000.0)
	primary_star_mass_tons = rng.randf_range(1.0e27, 3.0e27)
	
	celestial_bodies.clear()
	
	# Stella Primaria
	var star := CelestialBodyData.new()
	star.id = "STAR_PRIME"
	star.name = primary_star_name
	star.type = "STAR"
	star.coords = primary_star_coords
	star.radius_km = primary_star_radius_km
	star.mass_tons = primary_star_mass_tons
	star.color = primary_star_color
	celestial_bodies.append(star)
	
	# Aggiungi alcuni pianeti (3-6)
	var planet_count := rng.randi_range(3, 6)
	for i in range(planet_count):
		var planet := CelestialBodyData.new()
		planet.id = "PLANET_%d" % i
		planet.name = "Pianeta %d" % (i + 1)
		planet.type = "PLANET"
		var dist := rng.randi_range(2, 20)
		var angle := rng.randf() * TAU
		planet.coords = Vector3i(int(cos(angle) * dist), int(sin(angle) * dist), 0)
		planet.radius_km = rng.randf_range(2000.0, 8000.0)
		planet.mass_tons = rng.randf_range(1.0e20, 1.0e22)
		planet.occluding = true
		celestial_bodies.append(planet)
		
		# Aggiungi una luna ogni tanto
		if rng.randf() < 0.4:
			var moon := CelestialBodyData.new()
			moon.id = "MOON_%d" % i
			moon.name = "Luna %d" % (i + 1)
			moon.type = "MOON"
			moon.coords = planet.coords
			moon.radius_km = rng.randf_range(500.0, 1800.0)
			moon.mass_tons = rng.randf_range(1.0e18, 1.0e20)
			moon.occluding = true
			celestial_bodies.append(moon)
	
	# Aggiungi una stazione di partenza obbligatoria
	var station := CelestialBodyData.new()
	station.id = "STATION_START"
	station.name = "Avamposto di Frontiera"
	station.type = "STATION"
	var s_dist := rng.randi_range(5, 15)
	var s_angle := rng.randf() * TAU
	station.coords = Vector3i(int(cos(s_angle) * s_dist), int(sin(s_angle) * s_dist), 0)
	station.radius_km = 10.0
	station.mass_tons = 5.0e10
	celestial_bodies.append(station)
	
	custom_sectors = []
	emit_changed()

static func get_default_star_system() -> StarSystemData:
	const PATH := "res://Outside/StarSystemGrid/default_star_system.tres"
	var sys: StarSystemData = null
	if ResourceLoader.exists(PATH):
		var res: Resource = ResourceLoader.load(PATH)
		if res is StarSystemData:
			sys = res
	
	if sys == null or sys.is_empty():
		if sys == null:
			sys = StarSystemData.new()
		sys.create_default_system()
		
		# Se dopo create_default_system è ancora vuoto (strano ma possibile se create_default fallisce)
		if sys.is_empty():
			sys.generate_random_system()
			
	return sys
