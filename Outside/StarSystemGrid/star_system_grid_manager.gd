class_name StarSystemGridManagerSingleton
extends Node

## Manager Singleton per la Griglia Spaziale a Settori, illuminazione stellare e occlusione planetaria.

signal sector_changed(old_coords: Vector3i, new_coords: Vector3i, sector_data: SectorData)
signal sector_loaded(sector_data: SectorData)
signal celestial_occlusion_changed(is_occluded: bool, occlusion_factor: float)
signal solar_blackout_changed(in_blackout: bool)
signal lighting_updated(sun_direction: Vector3, light_energy: float, ambient_energy: float)
signal system_entities_updated(visible_entities: Array[Dictionary])
signal route_plotted(target_sector_coords: Vector3i, course_vector: Vector3)
signal hyperdrive_transit_started(target_sector_coords: Vector3i)
signal hyperdrive_transit_completed(target_sector_coords: Vector3i)

# Costanti di scala e visibilità della griglia
const SECTOR_SIZE_KM: float = 100000.0 # 100.000 km per lato settore
const DEFAULT_CRUISE_SPEED_KM_S: float = 500.0 # 500 km/s velocità sub-luce standard

# Soglie di visibilità diegetica sullo skybox (in caselle/settori)
const VISIBILITY_RANGE_STAR: float = 40.0 # 30+ caselle
const VISIBILITY_RANGE_GAS_GIANT: float = 15.0 # 10-15 caselle
const VISIBILITY_RANGE_PLANET: float = 12.0 # 10-12 caselle
const VISIBILITY_RANGE_MOON: float = 8.0
const VISIBILITY_RANGE_STATION: float = 4.0 # 2-4 caselle
const VISIBILITY_RANGE_ASTEROID_BELT: float = 4.0 # 2-4 caselle
const VISIBILITY_RANGE_WRECK: float = 2.0
const VISIBILITY_RANGE_PATROL: float = 2.0

# Posizione Stella Primaria nel sistema
const PRIMARY_STAR_COORDS: Vector3i = Vector3i(0, 0, 0)
const PRIMARY_STAR_RADIUS_KM: float = 696340.0
const PRIMARY_STAR_BASE_ENERGY: float = 1.3

# Stato del Manager
var current_sector_coords: Vector3i = Vector3i(4, 11, 0) # Spawning iniziale adiacente alla stazione orbitale (4, 12, 0)
var current_sector_data: SectorData = null

# Database settori generati/memorizzati
var _sector_cache: Dictionary = {}

# Rotta di navigazione pianificata attiva
var active_plotted_route: Dictionary = {}

# Catalogo macro-corpi del sistema stellare ("Dark Nova Helios System")
var current_system_data: StarSystemData = null
var system_celestial_bodies: Array[Dictionary] = [
	{
		"id": "STAR_SOL_PRIME",
		"name": "Helios Nova (Stella Primaria)",
		"type": "STAR",
		"coords": Vector3i(0, 0, 0),
		"radius_km": 696340.0,
		"mass_tons": 1.989e27,
		"luminosity": 1.0,
		"color": Color(1.0, 0.96, 0.9, 1.0),
		"occluding": false,
		"description": "Stella di sequenza principale al centro del sistema."
	},
	{
		"id": "PLANET_VULCAN",
		"name": "Vulcanus (Pianeta Roccioso)",
		"type": "PLANET",
		"coords": Vector3i(1, 3, 0),
		"radius_km": 4800.0,
		"mass_tons": 3.3e20,
		"occluding": true,
		"description": "Mondo lavico interno ad alta densità metallica."
	},
	{
		"id": "PLANET_TERRA_NOVA",
		"name": "Terra Nova Prime",
		"type": "PLANET",
		"coords": Vector3i(4, 8, 0),
		"radius_km": 6371.0,
		"mass_tons": 5.97e21,
		"occluding": true,
		"description": "Pianeta abitabile dell'orbita mediana con ecosfera stabilizzata."
	},
	{
		"id": "MOON_LUNA_SEC",
		"name": "Selene Secundus",
		"type": "MOON",
		"coords": Vector3i(4, 8, 0), # orbita nello stesso settore
		"radius_km": 1737.0,
		"mass_tons": 7.35e19,
		"occluding": true,
		"description": "Luna mineraria di Terra Nova."
	},
	{
		"id": "BELT_CERES_EX",
		"name": "Fascia d'Asteroidi Interna",
		"type": "ASTEROID_FIELD",
		"coords": Vector3i(3, 10, 0),
		"radius_km": 25000.0,
		"mass_tons": 1.5e18,
		"occluding": false,
		"description": "Denso campo di detriti e minerali preziosi."
	},
	{
		"id": "STATION_VALKYRIE",
		"name": "Stazione Spaziale Valkyrie",
		"type": "STATION",
		"coords": Vector3i(4, 12, 0),
		"radius_km": 15.0,
		"mass_tons": 8.5e10,
		"occluding": false,
		"description": "Hub orbitale militare e commerciale dell'avamposto."
	},
	{
		"id": "PATROL_VANGUARD",
		"name": "Pattuglia Vanguard-7",
		"type": "PATROL",
		"coords": Vector3i(4, 11, 0),
		"radius_km": 0.5,
		"mass_tons": 45000.0,
		"occluding": false,
		"description": "Squadriglia di caccia di sicurezza perimetrale."
	},
	{
		"id": "WRECK_TITAN_GRAVE",
		"name": "Relitto Incrociatore Titan-04",
		"type": "WRECK",
		"coords": Vector3i(5, 14, 0),
		"radius_km": 2.5,
		"mass_tons": 1.2e8,
		"occluding": false,
		"description": "Relitto bellico abbandonato ricco di materiali rari."
	},
	{
		"id": "GAS_GIANT_KRONOS",
		"name": "Kronos Titan (Gigante Gassoso)",
		"type": "GAS_GIANT",
		"coords": Vector3i(8, 20, 0),
		"radius_km": 69911.0,
		"mass_tons": 1.89e24,
		"occluding": true,
		"description": "Imponente gigante gassoso con complessi anelli d'idrogeno."
	},
	{
		"id": "GAS_GIANT_AETHER",
		"name": "Aetheris (Gigante di Ghiaccio)",
		"type": "GAS_GIANT",
		"coords": Vector3i(-12, 16, 0),
		"radius_km": 25362.0,
		"mass_tons": 8.68e22,
		"occluding": true,
		"description": "Gigante ghiacciato all'estrema periferia del sistema."
	}
]

func _ready() -> void:
	if current_system_data == null:
		load_star_system(StarSystemData.get_default_star_system())
	else:
		current_sector_coords = calculate_initial_spawn_coords()
		load_sector(current_sector_coords)

## Ritorna la stazione di partenza primaria/principale presente nel sistema stellare attivo
func get_starting_station() -> Dictionary:
	if current_system_data != null and current_system_data.has_method("find_primary_station"):
		var st := current_system_data.find_primary_station()
		if not st.is_empty():
			return st
	for b in system_celestial_bodies:
		if b.get("type", "").to_upper() == "STATION":
			return b
	return {}

## Calcola le coordinate del settore iniziale di spawn adiacente alla stazione di partenza
func calculate_initial_spawn_coords() -> Vector3i:
	var station := get_starting_station()
	if not station.is_empty():
		var st_coords: Vector3i = station.get("coords", Vector3i(4, 12, 0))
		if current_system_data != null and current_system_data.has_method("find_adjacent_spawn_sector"):
			return current_system_data.find_adjacent_spawn_sector(st_coords)
		return st_coords + Vector3i(0, -1, 0)
	return Vector3i(4, 11, 0)

## Posiziona la nave nel settore adiacente alla stazione primaria
func spawn_adjacent_to_station() -> Vector3i:
	var spawn_coords := calculate_initial_spawn_coords()
	set_current_sector_coords(spawn_coords)
	return spawn_coords

# =============================================================================
# GESTIONE COORDINATE E TRANSIZIONI SETTORE
# =============================================================================

## Formatta un Vector3i nel formato standard SEC-XX-YY
func format_sector_id(coords: Vector3i) -> String:
	return SectorData.format_coords_to_id(coords)

## Converte una stringa di settore in Vector3i
func parse_sector_id(id_str: String) -> Vector3i:
	return SectorData.parse_id_to_coords(id_str)

## Ritorna le coordinate del settore attuale
func get_current_sector_coords() -> Vector3i:
	return current_sector_coords

## Ritorna la stringa identificativa del settore corrente
func get_current_sector_id() -> String:
	return format_sector_id(current_sector_coords)

## Ritorna la risorsa SectorData del settore corrente
func get_current_sector_data() -> SectorData:
	if current_sector_data == null:
		current_sector_data = get_or_generate_sector_data(current_sector_coords)
	return current_sector_data

## Imposta e carica un nuovo settore
func set_current_sector_coords(new_coords: Vector3i) -> void:
	if current_sector_coords == new_coords and current_sector_data != null:
		return
	var old_coords := current_sector_coords
	current_sector_coords = new_coords
	var sec_data := get_or_generate_sector_data(new_coords)
	current_sector_data = sec_data
	
	_update_sector_environmental_state(sec_data)
	
	sector_changed.emit(old_coords, new_coords, sec_data)
	sector_loaded.emit(sec_data)
	
	var visible_ents := get_visible_system_entities(new_coords)
	system_entities_updated.emit(visible_ents)

## Carica esplicitamente un settore
func load_sector(coords: Vector3i) -> SectorData:
	set_current_sector_coords(coords)
	return current_sector_data

## Esegue una transizione di navigazione verso una cella adiacente (es. Vector3i(1,0,0))
func transition_to_adjacent_sector(direction: Vector3i) -> bool:
	if direction == Vector3i.ZERO:
		return false
	# Normalizza il passo a celle unitarie
	var step := Vector3i(
		clampi(direction.x, -1, 1),
		clampi(direction.y, -1, 1),
		clampi(direction.z, -1, 1)
	)
	var target_coords := current_sector_coords + step
	set_current_sector_coords(target_coords)
	return true

# =============================================================================
# CINEMATICA, ROTTE E DISTANZE (HYPERDRIVE & CRUISE)
# =============================================================================

## Calcola la distanza euclidea tra due settori (in numero di celle)
func get_sector_distance(from_coords: Vector3i, to_coords: Vector3i) -> float:
	var diff := Vector3(to_coords - from_coords)
	return diff.length()

## Calcola il vettore di rotta direzionale tra due settori
func get_route_vector(from_coords: Vector3i, to_coords: Vector3i) -> Vector3:
	var diff := Vector3(to_coords - from_coords)
	if diff.length_squared() < 0.0001:
		return Vector3.ZERO
	return diff.normalized()

## Calcola la distanza fisica reale in chilometri (km) tra settori
func calculate_kinematic_distance_km(from_coords: Vector3i, to_coords: Vector3i) -> float:
	var dist_sectors := get_sector_distance(from_coords, to_coords)
	return dist_sectors * SECTOR_SIZE_KM

## Calcola il tempo di viaggio sub-luce in secondi data una velocità di crociera in km/s
func calculate_sublight_travel_time(from_coords: Vector3i, to_coords: Vector3i, cruise_speed_km_s: float = DEFAULT_CRUISE_SPEED_KM_S) -> float:
	if cruise_speed_km_s <= 0.0:
		return INF
	var distance_km := calculate_kinematic_distance_km(from_coords, to_coords)
	return distance_km / cruise_speed_km_s

## Pianifica e calcola una rotta di navigazione Hyperdrive verso il settore specificato
func plot_route(target_coords: Vector3i, from_coords: Vector3i = current_sector_coords) -> Dictionary:
	var dist_sectors := get_sector_distance(from_coords, target_coords)
	var dist_km := calculate_kinematic_distance_km(from_coords, target_coords)
	var course_vec := get_route_vector(from_coords, target_coords)
	
	# Calcolo stime di transito Hyperdrive
	# Hyperdrive velocità equivalente ~ 25000 km/s per calcolo ETA rapido
	var eta_seconds := 0.0
	if dist_sectors > 0.0:
		eta_seconds = maxf(3.0, dist_sectors * 4.5) # ~4.5 secondi per settore di transito
	
	var energy_cost_mw := dist_sectors * 15.0 # 15 MW per settore
	var fuel_cost := dist_sectors * 2.5       # 2.5 unità per settore
	
	var route_info := {
		"from_coords": from_coords,
		"from_sector_id": format_sector_id(from_coords),
		"target_coords": target_coords,
		"target_sector_id": format_sector_id(target_coords),
		"distance_sectors": dist_sectors,
		"distance_km": dist_km,
		"course_vector": course_vec,
		"eta_seconds": eta_seconds,
		"energy_cost_mw": energy_cost_mw,
		"fuel_cost": fuel_cost,
		"timestamp": Time.get_ticks_msec()
	}
	
	active_plotted_route = route_info
	route_plotted.emit(target_coords, course_vec)
	return route_info

## Ritorna la rotta pianificata attiva (o vuota se non presente)
func get_active_route() -> Dictionary:
	return active_plotted_route

## Annulla/cancella la rotta pianificata
func clear_plotted_route() -> void:
	active_plotted_route.clear()

## Esegue l'attivazione Hyperdrive verso il settore pianificato o quello passato come argomento
func engage_hyperdrive_transit(target_coords: Vector3i = Vector3i.ZERO) -> Dictionary:
	var dest := target_coords
	if dest == Vector3i.ZERO:
		if active_plotted_route.has("target_coords"):
			dest = active_plotted_route["target_coords"]
		else:
			return {"success": false, "reason": "Nessuna rotta pianificata attiva."}
	
	if dest == current_sector_coords:
		return {"success": false, "reason": "La nave si trova già nel settore target."}
	
	hyperdrive_transit_started.emit(dest)
	set_current_sector_coords(dest)
	hyperdrive_transit_completed.emit(dest)
	
	# Pulisce la rotta una volta completato il transito
	if active_plotted_route.get("target_coords", Vector3i.ZERO) == dest:
		active_plotted_route.clear()
		
	return {
		"success": true,
		"new_sector_coords": dest,
		"new_sector_id": format_sector_id(dest)
	}

# =============================================================================
# ILLUMINAZIONE DINAMICA E CONI D'OMBRA PLANETARI (OCCLUSIONE & ECLISSI)
# =============================================================================

## Ritorna le coordinate della stella primaria
func get_primary_star_coords() -> Vector3i:
	return PRIMARY_STAR_COORDS

## Calcola la direzione normalizzata della luce solare che colpisce il settore target
func get_light_direction_from_star(target_coords: Vector3i = current_sector_coords) -> Vector3:
	var star_pos := Vector3(PRIMARY_STAR_COORDS)
	var target_pos := Vector3(target_coords)
	var diff := target_pos - star_pos
	if diff.length_squared() < 0.0001:
		return Vector3(0, -1, 0) # Stella al centro
	return -diff.normalized() # Direzione luce verso la stella

## Calcola se il settore specificato si trova in una zona d'ombra/eclissi generata da pianeti o giganti gassosi
func calculate_planetary_occlusion(target_coords: Vector3i = current_sector_coords) -> Dictionary:
	var star_pos := Vector3(PRIMARY_STAR_COORDS)
	var target_pos := Vector3(target_coords)
	var dist_target_from_star := (target_pos - star_pos).length()
	
	if dist_target_from_star < 0.001:
		# Siamo dentro la stella
		return {
			"is_occluded": false,
			"occlusion_factor": 0.0,
			"occluding_body": {},
			"solar_blackout": false,
			"light_energy_factor": 1.0
		}
	
	var ray_dir := (target_pos - star_pos).normalized()
	var max_occlusion: float = 0.0
	var occluding_body_found: Dictionary = {}
	
	for body in system_celestial_bodies:
		if not body.get("occluding", false):
			continue
		
		var b_coords: Vector3i = body.get("coords", Vector3i.ZERO)
		var b_pos := Vector3(b_coords)
		var body_from_star := b_pos - star_pos
		
		# Proietta la posizione del corpo sul raggio stella -> target
		var proj_dist := body_from_star.dot(ray_dir)
		
		# Il corpo deve trovarsi tra la stella e il settore target
		if proj_dist > 0.05 and proj_dist < dist_target_from_star:
			var closest_point_on_ray := star_pos + ray_dir * proj_dist
			var perp_distance := (b_pos - closest_point_on_ray).length()
			
			# Raggio d'ombra in unità di settore (approssimazione con raggio fisico del corpo)
			var body_radius_km: float = body.get("radius_km", 6000.0)
			var shadow_radius_sectors: float = maxf(0.65, (body_radius_km / SECTOR_SIZE_KM) * 8.0)
			
			if perp_distance < shadow_radius_sectors:
				var factor := 1.0 - (perp_distance / shadow_radius_sectors)
				if factor > max_occlusion:
					max_occlusion = factor
					occluding_body_found = body
	
	var is_occluded := max_occlusion > 0.1
	var is_blackout := max_occlusion >= 0.75
	var light_factor := clampf(1.0 - max_occlusion, 0.05, 1.0)
	
	return {
		"is_occluded": is_occluded,
		"occlusion_factor": max_occlusion,
		"occluding_body": occluding_body_found,
		"solar_blackout": is_blackout,
		"light_energy_factor": light_factor
	}

## Verifica rapida se il settore si trova in cono d'ombra
func is_in_planetary_shadow(coords: Vector3i = current_sector_coords) -> bool:
	var occ := calculate_planetary_occlusion(coords)
	return occ.get("is_occluded", false)

## Verifica se c'è un blackout completo dei pannelli solari
func is_solar_blackout(coords: Vector3i = current_sector_coords) -> bool:
	var occ := calculate_planetary_occlusion(coords)
	return occ.get("solar_blackout", false)

## Calcola l'energia solare effettiva al settore (0.0 - 1.3)
func get_effective_solar_energy(coords: Vector3i = current_sector_coords) -> float:
	var occ := calculate_planetary_occlusion(coords)
	var factor: float = occ.get("light_energy_factor", 1.0)
	return PRIMARY_STAR_BASE_ENERGY * factor

# =============================================================================
# DISTANZE DI RENDER E SKYBOX DIEGETICO
# =============================================================================

## Carica una configurazione completa di sistema stellare da risorsa StarSystemData
func load_star_system(sys_data: StarSystemData) -> void:
	if sys_data == null:
		return
	current_system_data = sys_data
	system_celestial_bodies = sys_data.celestial_bodies.duplicate(true)
	_sector_cache.clear()
	for sec_dict in sys_data.custom_sectors:
		var sec := SectorData.new()
		sec.from_dict(sec_dict)
		_sector_cache[sec.sector_id] = sec
	current_sector_coords = calculate_initial_spawn_coords()
	load_sector(current_sector_coords)

## Esporta lo stato corrente in un oggetto StarSystemData
func export_to_star_system_data() -> StarSystemData:
	var sys := StarSystemData.new("SYS-CURRENT", "Current Star System")
	sys.primary_star_coords = PRIMARY_STAR_COORDS
	sys.primary_star_energy = PRIMARY_STAR_BASE_ENERGY
	sys.primary_star_radius_km = PRIMARY_STAR_RADIUS_KM
	sys.celestial_bodies = system_celestial_bodies.duplicate(true)
	var customs: Array[Dictionary] = []
	for sec_id in _sector_cache:
		var sec_res = _sector_cache[sec_id]
		if sec_res is SectorData:
			customs.append(sec_res.to_dict())
	sys.custom_sectors = customs
	return sys

## Ritorna la lista di tutte le macro-entità del sistema visibili dal punto di vista dell'osservatore
func get_visible_system_entities(observer_coords: Vector3i = current_sector_coords) -> Array[Dictionary]:
	var visible_list: Array[Dictionary] = []
	var obs_pos := Vector3(observer_coords)
	
	for body in system_celestial_bodies:
		var b_coords: Vector3i = body.get("coords", Vector3i.ZERO)
		var b_pos := Vector3(b_coords)
		var diff := b_pos - obs_pos
		var dist_sectors := diff.length()
		var b_type: String = body.get("type", "").to_upper()
		
		var max_range: float = 0.0
		match b_type:
			"STAR":
				max_range = VISIBILITY_RANGE_STAR
			"GAS_GIANT":
				max_range = VISIBILITY_RANGE_GAS_GIANT
			"PLANET":
				max_range = VISIBILITY_RANGE_PLANET
			"MOON":
				max_range = VISIBILITY_RANGE_MOON
			"STATION":
				max_range = VISIBILITY_RANGE_STATION
			"ASTEROID_FIELD", "ASTEROID_BELT":
				max_range = VISIBILITY_RANGE_ASTEROID_BELT
			"WRECK":
				max_range = VISIBILITY_RANGE_WRECK
			"PATROL":
				max_range = VISIBILITY_RANGE_PATROL
			_:
				max_range = 2.0
		
		# Verifica se è entro la distanza massima diegetica
		if dist_sectors <= max_range:
			var dir := diff.normalized() if dist_sectors > 0.0001 else Vector3.ZERO
			var dist_km := dist_sectors * SECTOR_SIZE_KM
			
			# Calcolo scala angolare apparente (dimensione diegetica sullo skybox)
			var radius_km: float = body.get("radius_km", 1000.0)
			var apparent_angular_size := 1.0
			if dist_sectors > 0.1:
				apparent_angular_size = clampf((radius_km / (dist_km + 1000.0)) * 50.0, 0.05, 10.0)
			
			# Calcolo luminosità apparente
			var apparent_brightness := clampf(1.0 - (dist_sectors / max_range), 0.1, 1.0)
			
			visible_list.append({
				"id": body.get("id", ""),
				"name": body.get("name", ""),
				"type": b_type,
				"coords": b_coords,
				"distance_sectors": dist_sectors,
				"distance_km": dist_km,
				"direction": dir,
				"apparent_angular_size": apparent_angular_size,
				"apparent_brightness": apparent_brightness,
				"is_in_current_sector": dist_sectors < 0.1,
				"occluding": body.get("occluding", false),
				"raw_data": body
			})
	
	visible_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("distance_sectors", 0.0) < b.get("distance_sectors", 0.0)
	)
	
	return visible_list

# =============================================================================
# GENERAZIONE & CACHE CONTENUTI SETTORE
# =============================================================================

## Ritorna i dati di un settore (da cache o generati deterministicamente)
func get_or_generate_sector_data(coords: Vector3i) -> SectorData:
	var sec_id := format_sector_id(coords)
	if _sector_cache.has(sec_id):
		return _sector_cache[sec_id]
	
	var data := SectorData.new(coords, sec_id)
	
	# Associa entità note a queste coordinate
	for body in system_celestial_bodies:
		if body.get("coords", Vector3i.MIN) == coords:
			data.add_entity(body)
	
	# Determina tipo e descrizione in base alle entità presenti
	if coords == PRIMARY_STAR_COORDS:
		data.sector_type = "STAR_CORONA"
		data.sector_name = "Corona di Helios Nova"
		data.description = "Zona ad altissima radiazione e calore critico in prossimità della stella primaria."
		data.sun_light_energy = 3.5
	elif data.has_entity_of_type("PLANET"):
		data.sector_type = "PLANETARY_ORBIT"
		data.sector_name = "Orbita di %s" % data.macro_entities[0].get("name", "Pianeta")
		data.description = "Spazio orbitale stabile in prossimità del pianeta."
	elif data.has_entity_of_type("GAS_GIANT"):
		data.sector_type = "GAS_GIANT_WELL"
		data.sector_name = "Pozzo Gravitazionale %s" % data.macro_entities[0].get("name", "Gigante")
		data.description = "Zona densa di radiazioni e tempeste atmosferiche del gigante gassoso."
	elif data.has_entity_of_type("STATION"):
		data.sector_type = "STATION_ORBIT"
		data.sector_name = "Spazio Portuale %s" % data.macro_entities[0].get("name", "Stazione")
		data.description = "Area di traffico commerciale e pattugliamento regolamentato."
		data.security_level = "HIGH"
		data.traffic_density = 0.8
	elif data.has_entity_of_type("ASTEROID_FIELD"):
		data.sector_type = "ASTEROID_BELT"
		data.sector_name = "Cintura d'Asteroidi"
		data.description = "Campo denso di frammenti rocciosi e metallici."
	elif data.has_entity_of_type("WRECK"):
		data.sector_type = "DERELICT_GRAVEYARD"
		data.sector_name = "Cimitero di Relitti"
		data.description = "Resti di battaglie spaziali passate, relitti e rottami."
	else:
		# Settore di spazio profondo
		data.sector_type = "DEEP_SPACE"
		data.sector_name = "Spazio Profondo %s" % sec_id
		data.description = "Vuoto cosmico aperto del sistema stellare."
	
	_sector_cache[sec_id] = data
	return data

## Aggiorna lo stato ambientale (illuminazione, ombre, blackout) sul SectorData
func _update_sector_environmental_state(sec_data: SectorData) -> void:
	var occ := calculate_planetary_occlusion(sec_data.coordinates)
	sec_data.is_in_planetary_shadow = occ.get("is_occluded", false)
	sec_data.shadow_occlusion_factor = occ.get("occlusion_factor", 0.0)
	sec_data.solar_panels_blackout = occ.get("solar_blackout", false)
	
	var base_sun_energy := PRIMARY_STAR_BASE_ENERGY
	if sec_data.sector_type == "STAR_CORONA":
		base_sun_energy = 3.5
	
	sec_data.sun_light_energy = base_sun_energy * occ.get("light_energy_factor", 1.0)
	
	if sec_data.is_in_planetary_shadow:
		sec_data.ambient_light_energy = clampf(0.5 * (1.0 - sec_data.shadow_occlusion_factor * 0.6), 0.15, 0.5)
	else:
		sec_data.ambient_light_energy = 0.5
	
	var sun_dir := get_light_direction_from_star(sec_data.coordinates)
	
	celestial_occlusion_changed.emit(sec_data.is_in_planetary_shadow, sec_data.shadow_occlusion_factor)
	solar_blackout_changed.emit(sec_data.solar_panels_blackout)
	lighting_updated.emit(sun_dir, sec_data.sun_light_energy, sec_data.ambient_light_energy)
	
	# Se SpaceWorldManager è attivo, sincronizza le entità e l'ambiente
	_sync_with_space_world_manager(sec_data)

## Sincronizzazione con SpaceWorldManager se presente nell'albero di gioco
func _sync_with_space_world_manager(sec_data: SectorData) -> void:
	var swm = get_node_or_null("/root/SpaceWorldManager")
	if swm and is_instance_valid(swm):
		# Se SpaceWorldManager ha metodi o segnali dedicati, li notifica
		if swm.has_signal("sensors_scan_completed"):
			var visible_contacts := get_visible_system_entities(sec_data.coordinates)
			swm.sensors_scan_completed.emit(visible_contacts)
