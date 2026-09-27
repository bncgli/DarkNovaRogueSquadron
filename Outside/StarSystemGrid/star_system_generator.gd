class_name StarSystemGenerator
extends RefCounted

## Generatore astronomico procedurale modulare deterministico per Dark Nova Rogue Squadron.
## Disaccoppiato dall'interfaccia utente, genera istanze coerenti di StarSystemData
## in base a seed alfanumerico, archetipo galattico e parametri volumetrici 3D.

enum Archetype {
	FRONTIER_EXPANSE,     ## Frontiera Periferica: 1 stella, 3-5 pianeti, campi asteroidi, 1 avamposto, relitti
	CORE_INDUSTRIAL,       ## Hub Industriale: 1 stella brillante, 5-8 pianeti, 2-3 stazioni commerciali, alto traffico
	ANARCHY_PIRATE_SECTOR, ## Settore Fuorilegge: stella debole, basi clandestine, taglie Fixer, relitti bellici
	DEEP_EXPLORATION       ## Spazio Profondo: giganti gassosi con anelli, lune multiple, anomalie, nubi
}

const ARCHETYPE_NAMES := {
	Archetype.FRONTIER_EXPANSE: "Frontiera Periferica",
	Archetype.CORE_INDUSTRIAL: "Hub Industriale & Commerciale",
	Archetype.ANARCHY_PIRATE_SECTOR: "Settore Fuorilegge / Anarchia",
	Archetype.DEEP_EXPLORATION: "Spazio Profondo & Esplorazione"
}

const ARCHETYPE_DESCRIPTIONS := {
	Archetype.FRONTIER_EXPANSE: "Settore remoto ai margini dello spazio civilizzato. Risorse grezze, avamposti solitari e relitti dimenticati.",
	Archetype.CORE_INDUSTRIAL: "Cuore economico ad alta densità. Più stazioni orbitali, cantieri navali, pattuglie di sicurezza e vivace commercio.",
	Archetype.ANARCHY_PIRATE_SECTOR: "Zona contesa priva di giurisdizione. Covi pirata, abbondanti taglie del Fixer e cimiteri di navi da guerra.",
	Archetype.DEEP_EXPLORATION: "Regione inesplorata ricca di giganti gassosi, sistemi di lune complesse e anomalie spettrometriche."
}

# Tabelle astronomiche per nomi e attributi
const STAR_NAME_PREFIXES := [
	"Helios", "Astraea", "Prometheus", "Vanguard", "Kronos", "Aegis", "Hyperion", 
	"Cerberus", "Elysium", "Nemesis", "Orion", "Taurus", "Solaria", "Cygnus", "Vega"
]

const STAR_NAME_SUFFIXES := [
	"Prime", "Nova", "Major", "Secundus", "Australis", "Borealis", "Terminus", "Zenith"
]

const PLANET_NAME_BASES := [
	"Ares", "Hermes", "Vulcan", "Demeter", "Thalassa", "Tartarus", "Aether", 
	"Nyx", "Erebos", "Proteus", "Tethys", "Atlas", "Gorgon", "Janus", "Pandora"
]

const ROMAN_NUMERALS := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

## Ritorna il nome leggibile dell'archetipo
static func get_archetype_name(arch: Archetype) -> String:
	return ARCHETYPE_NAMES.get(arch, "Archetipo Sconosciuto")

## Ritorna la descrizione estesa dell'archetipo
static func get_archetype_description(arch: Archetype) -> String:
	return ARCHETYPE_DESCRIPTIONS.get(arch, "")

## Converte un seed in valore intero deterministico a 64-bit
static func hash_seed_to_int(seed_str: String) -> int:
	if seed_str.is_empty():
		return 1337
	# Combina hash standard con moltiplicatore polinomiale per eccellente entropia
	var h: int = 5381
	for b in seed_str.to_utf8_buffer():
		h = ((h << 5) + h) + int(b)
		h = h & 0x7FFFFFFFFFFFFFFF
	return h

## Genera un seed casuale alfanumerico diegetico
static func generate_random_seed() -> String:
	var chars := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var out := ""
	for i in range(4):
		out += chars[randi() % chars.length()]
	out += "-"
	for i in range(4):
		out += chars[randi() % chars.length()]
	return out

## Metodo principale di generazione procedurale
static func generate_system(seed_str: String = "", archetype: Archetype = Archetype.FRONTIER_EXPANSE, custom_params: Dictionary = {}) -> StarSystemData:
	var final_seed: String = seed_str.strip_edges()
	if final_seed.is_empty():
		final_seed = generate_random_seed()

	var rng := RandomNumberGenerator.new()
	var seed_val := hash_seed_to_int(final_seed)
	rng.seed = seed_val

	var system := StarSystemData.new()
	var sys_tag := final_seed.replace("-", "").to_upper().substr(0, 6)
	system.system_id = "SYS-%s-%02d" % [sys_tag, int(archetype) + 1]

	# Configurazione Stella Primaria in base all'archetipo
	var star_prefix: String = STAR_NAME_PREFIXES[rng.randi_range(0, STAR_NAME_PREFIXES.size() - 1)]
	var star_suffix: String = STAR_NAME_SUFFIXES[rng.randi_range(0, STAR_NAME_SUFFIXES.size() - 1)]
	system.primary_star_name = "%s %s" % [star_prefix, star_suffix]
	system.system_name = "%s System" % system.primary_star_name
	system.description = "%s. Generato deterministicamente con seed [%s]." % [
		get_archetype_description(archetype), final_seed
	]
	system.primary_star_coords = Vector3i.ZERO

	# Calcolo tipo spettrale, colore ed energia
	match archetype:
		Archetype.CORE_INDUSTRIAL:
			system.primary_star_color = Color(1.0, 0.98, 0.88, 1.0) # G-type solare caldo
			system.primary_star_energy = rng.randf_range(1.2, 1.5)
			system.primary_star_radius_km = rng.randf_range(650000.0, 950000.0)
			system.primary_star_mass_tons = rng.randf_range(1.8e27, 2.4e27)
		Archetype.ANARCHY_PIRATE_SECTOR:
			system.primary_star_color = Color(1.0, 0.55, 0.35, 1.0) # M-dwarf / K-dwarf rossa/arancio
			system.primary_star_energy = rng.randf_range(0.7, 1.0)
			system.primary_star_radius_km = rng.randf_range(380000.0, 520000.0)
			system.primary_star_mass_tons = rng.randf_range(0.8e27, 1.3e27)
		Archetype.DEEP_EXPLORATION:
			system.primary_star_color = Color(0.85, 0.92, 1.0, 1.0) # A/B blue giant o bianca
			system.primary_star_energy = rng.randf_range(1.4, 1.8)
			system.primary_star_radius_km = rng.randf_range(900000.0, 1400000.0)
			system.primary_star_mass_tons = rng.randf_range(2.5e27, 3.8e27)
		_: # FRONTIER_EXPANSE
			system.primary_star_color = Color(1.0, 0.92, 0.75, 1.0) # K-type arancio dorato
			system.primary_star_energy = rng.randf_range(1.0, 1.3)
			system.primary_star_radius_km = rng.randf_range(580000.0, 780000.0)
			system.primary_star_mass_tons = rng.randf_range(1.4e27, 2.0e27)

	# Aggiunge la stella primaria come CelestialBodyData
	var star_body := CelestialBodyData.new(
		"STAR_%s" % sys_tag,
		"%s (Stella Primaria)" % system.primary_star_name,
		"STAR",
		Vector3i.ZERO
	)
	star_body.radius_km = system.primary_star_radius_km
	star_body.mass_tons = system.primary_star_mass_tons
	star_body.luminosity = system.primary_star_energy
	star_body.color = system.primary_star_color
	star_body.occluding = false
	star_body.description = "Stella di sequenza principale al baricentro del sistema."
	star_body.temperature = rng.randf_range(4800.0, 6800.0)
	system.add_or_update_body(star_body)

	# Mappa di coordinate occupate per prevenire sovrapposizioni
	var occupied_coords: Dictionary = {Vector3i.ZERO: true}

	# Parametri di bilanciamento
	var vertical_spread: int = int(custom_params.get("vertical_spread", 3))
	var min_planets: int = 3
	var max_planets: int = 5
	var station_count: int = 1
	var has_wrecks: bool = true
	var bounty_zones_count: int = 0

	match archetype:
		Archetype.CORE_INDUSTRIAL:
			min_planets = 5
			max_planets = 8
			station_count = rng.randi_range(2, 3)
			has_wrecks = false
			bounty_zones_count = 0
		Archetype.ANARCHY_PIRATE_SECTOR:
			min_planets = 3
			max_planets = 6
			station_count = rng.randi_range(1, 2)
			has_wrecks = true
			bounty_zones_count = rng.randi_range(2, 4)
		Archetype.DEEP_EXPLORATION:
			min_planets = 4
			max_planets = 7
			station_count = 1
			has_wrecks = true
			bounty_zones_count = 1
		_: # FRONTIER_EXPANSE
			min_planets = 3
			max_planets = 5
			station_count = 1
			has_wrecks = true
			bounty_zones_count = 1

	if custom_params.has("num_planets"):
		min_planets = int(custom_params["num_planets"])
		max_planets = min_planets

	var total_planets: int = rng.randi_range(min_planets, max_planets)
	var base_orbit_dist: float = 3.0
	var planet_names_pool := PLANET_NAME_BASES.duplicate()
	# Mescola deterministico con Fisher-Yates tramite rng del seed
	for p_idx in range(planet_names_pool.size() - 1, 0, -1):
		var swap_j := rng.randi_range(0, p_idx)
		var tmp = planet_names_pool[p_idx]
		planet_names_pool[p_idx] = planet_names_pool[swap_j]
		planet_names_pool[swap_j] = tmp

	# Generazione Pianeti, Fasce e Lune
	for i in range(total_planets):
		var p_name_base: String = planet_names_pool[i % planet_names_pool.size()]
		var p_numeral: String = ROMAN_NUMERALS[i % ROMAN_NUMERALS.size()]
		var p_name: String = "%s %s" % [p_name_base, p_numeral]
		
		# Legge logaritmica orbitale con passo proporzionale
		base_orbit_dist += rng.randf_range(2.2, 4.0)
		var angle := rng.randf_range(0.0, TAU)
		var orbit_x := int(round(base_orbit_dist * cos(angle)))
		var orbit_y := int(round(base_orbit_dist * sin(angle)))
		var orbit_z := rng.randi_range(-vertical_spread, vertical_spread)
		
		var planet_coords := _find_free_coord(Vector3i(orbit_x, orbit_y, orbit_z), occupied_coords, rng)
		occupied_coords[planet_coords] = true

		var is_gas_giant: bool = (i >= 3 and rng.randf() < 0.45) or (archetype == Archetype.DEEP_EXPLORATION and i >= 2 and rng.randf() < 0.6)
		var p_body := CelestialBodyData.new(
			"PLANET_%s_%d" % [sys_tag, i + 1],
			p_name,
			"GAS_GIANT" if is_gas_giant else "PLANET",
			planet_coords
		)

		if is_gas_giant:
			p_body.radius_km = rng.randf_range(40000.0, 75000.0)
			p_body.mass_tons = rng.randf_range(8.0e23, 2.5e24)
			p_body.color = Color(rng.randf_range(0.6, 0.9), rng.randf_range(0.5, 0.8), rng.randf_range(0.4, 0.7), 1.0)
			p_body.description = "Gigante gassoso con spesse fasce atmosferiche e tempeste gioviane."
			p_body.atmosphere = "hydrogen_helium"
			p_body.temperature = rng.randf_range(-160.0, -90.0)
			p_body.resources = ["HYDROGEN", "HELIUM_3", "DEUTERIUM"]
		else:
			p_body.radius_km = rng.randf_range(3500.0, 9500.0)
			p_body.mass_tons = rng.randf_range(1.5e21, 9.0e21)
			p_body.color = Color(rng.randf_range(0.4, 0.85), rng.randf_range(0.4, 0.85), rng.randf_range(0.4, 0.95), 1.0)
			var dist_norm: float = float(i) / float(maxi(total_planets, 1))
			if dist_norm < 0.25:
				p_body.description = "Pianeta roccioso interno ad alta radiazione e vulcani attivi."
				p_body.atmosphere = "carbon_dioxide"
				p_body.temperature = rng.randf_range(180.0, 420.0)
				p_body.resources = ["HEAVY_METALS", "SULFUR", "TITANIUM"]
			elif dist_norm < 0.65:
				p_body.description = "Mondo della fascia temperata con potenziale idrosferico."
				p_body.atmosphere = "nitrogen_oxygen"
				p_body.temperature = rng.randf_range(-15.0, 32.0)
				p_body.resources = ["WATER_ICE", "SILICATES", "ORGANICS"]
			else:
				p_body.description = "Pianeta ghiacciato esterno coperto da permafrost di azoto."
				p_body.atmosphere = "methane"
				p_body.temperature = rng.randf_range(-180.0, -80.0)
				p_body.resources = ["ICE", "HYDROCARBONS", "RARE_MINERALS"]

		# Assegna elevazione altimetrica locale diegetica Y
		var p_elevation: float = rng.randf_range(-600.0, 600.0)
		if p_body.get("local_elevation") != null:
			p_body.set("local_elevation", p_elevation)
		p_body.set_meta("local_elevation", p_elevation)

		system.add_or_update_body(p_body)

		# Possibile Luna orbitale attorno al pianeta
		if (is_gas_giant or rng.randf() < 0.4) and system.celestial_bodies.size() < 18:
			var moon_coords := _find_free_coord(planet_coords + Vector3i(1, 0, 0), occupied_coords, rng)
			occupied_coords[moon_coords] = true
			var moon_body := CelestialBodyData.new(
				"MOON_%s_%d_A" % [sys_tag, i + 1],
				"%s-A (Luna)" % p_name,
				"MOON",
				moon_coords
			)
			moon_body.radius_km = rng.randf_range(800.0, 2400.0)
			moon_body.mass_tons = rng.randf_range(3.0e19, 9.0e19)
			moon_body.color = Color(0.7, 0.72, 0.75, 1.0)
			moon_body.description = "Satellite naturale con regolite superficiale e crateri d'impatto."
			moon_body.atmosphere = "none"
			moon_body.temperature = p_body.temperature - 20.0
			moon_body.resources = ["REGOLITH", "TITANIUM", "RARE_EARTHS"]
			var moon_elevation: float = p_elevation + rng.randf_range(-400.0, 400.0)
			if moon_body.get("local_elevation") != null:
				moon_body.set("local_elevation", moon_elevation)
			moon_body.set_meta("local_elevation", moon_elevation)
			system.add_or_update_body(moon_body)

	# Fascia Principale d'Asteroidi
	var belt_radius := base_orbit_dist * 0.55
	var belt_angle := rng.randf_range(0.0, TAU)
	var belt_coords := _find_free_coord(
		Vector3i(int(round(belt_radius * cos(belt_angle))), int(round(belt_radius * sin(belt_angle))), rng.randi_range(-2, 2)),
		occupied_coords, rng
	)
	occupied_coords[belt_coords] = true
	var belt_body := CelestialBodyData.new(
		"BELT_%s_MAIN" % sys_tag,
		"Fascia d'Asteroidi %s" % star_prefix,
		"ASTEROID_FIELD",
		belt_coords
	)
	belt_body.radius_km = rng.randf_range(18000.0, 35000.0)
	belt_body.mass_tons = rng.randf_range(1.0e18, 4.0e18)
	belt_body.occluding = false
	belt_body.description = "Vasto anello di frammenti rocciosi e metalliferi."
	belt_body.resources = ["ORE", "SILICATES", "PLATINUM", "ICE"]
	var belt_elev: float = rng.randf_range(-300.0, 300.0)
	if belt_body.get("local_elevation") != null:
		belt_body.set("local_elevation", belt_elev)
	belt_body.set_meta("local_elevation", belt_elev)
	system.add_or_update_body(belt_body)

	# Stazioni Spaziali (GARANTITA sempre almeno 1 per lo spawn iniziale della corvetta)
	var station_types := ["CIVILIAN_OUTPOST", "COMMERCIAL_HUB", "MINING_DEPOT", "MILITARY_SHIPYARD"]
	var station_names_core := ["Valkyrie", "Aegis Port", "Centurion Yard", "Olympus Station", "Nautilus Gate"]

	for s_idx in range(station_count):
		var s_name_raw: String = station_names_core[(rng.randi() + s_idx) % station_names_core.size()]
		var s_name := "Stazione %s %s" % [s_name_raw, ROMAN_NUMERALS[s_idx % ROMAN_NUMERALS.size()]]
		var s_dist := rng.randf_range(4.0, 9.0) + (float(s_idx) * 3.5)
		var s_angle := rng.randf_range(0.0, TAU)
		var s_z := rng.randi_range(-vertical_spread, vertical_spread)
		# Assicuriamo quota z non nulla se abbiamo più stazioni o per diversificazione volumetrica
		if s_idx > 0 and s_z == 0:
			s_z = 1 if rng.randf() > 0.5 else -1

		var s_coords := _find_free_coord(
			Vector3i(int(round(s_dist * cos(s_angle))), int(round(s_dist * sin(s_angle))), s_z),
			occupied_coords, rng
		)
		occupied_coords[s_coords] = true

		var station_body := CelestialBodyData.new(
			"STATION_%s_%d" % [sys_tag, s_idx + 1],
			s_name,
			"STATION",
			s_coords
		)
		station_body.radius_km = rng.randf_range(8.0, 22.0)
		station_body.mass_tons = rng.randf_range(4.0e10, 1.2e11)
		station_body.occluding = false
		station_body.description = "Hub orbitale con scali commerciali, baia d'attracco e riparazioni navali."
		station_body.resources = ["FUEL", "SUPPLIES", "NANITES"]
		station_body.comms_frequency = 1840.0
		
		# Dislivello altimetrico 3D locale Y (es. +/- 200..1200m)
		var s_elevation: float = rng.randf_range(200.0, 850.0) * (1.0 if rng.randf() > 0.5 else -1.0)
		if station_body.get("local_elevation") != null:
			station_body.set("local_elevation", s_elevation)
		station_body.set_meta("local_elevation", s_elevation)
		system.add_or_update_body(station_body)

		# Crea un settore dedicato in custom_sectors
		var sec := SectorData.new(s_coords, SectorData.format_coords_to_id(s_coords), "Settore %s" % s_name)
		sec.sector_type = "STATION"
		sec.security_level = "HIGH" if archetype == Archetype.CORE_INDUSTRIAL else ("LOW" if archetype == Archetype.ANARCHY_PIRATE_SECTOR else "MEDIUM")
		sec.traffic_density = 0.8 if archetype == Archetype.CORE_INDUSTRIAL else 0.3
		sec.add_entity(station_body)
		system.add_or_update_custom_sector(sec)

	# Relitti Spaziali (WRECK)
	if has_wrecks:
		var wreck_count := rng.randi_range(1, 3 if archetype == Archetype.ANARCHY_PIRATE_SECTOR else 2)
		for w_idx in range(wreck_count):
			var w_dist := rng.randf_range(7.0, 14.0)
			var w_angle := rng.randf_range(0.0, TAU)
			var w_z := rng.randi_range(-vertical_spread, vertical_spread)
			if w_z == 0:
				w_z = 2 if rng.randf() > 0.5 else -2
			var w_coords := _find_free_coord(
				Vector3i(int(round(w_dist * cos(w_angle))), int(round(w_dist * sin(w_angle))), w_z),
				occupied_coords, rng
			)
			occupied_coords[w_coords] = true

			var wreck_body := CelestialBodyData.new(
				"WRECK_%s_%d" % [sys_tag, w_idx + 1],
				"Relitto Incrociatore Derelict-%02d" % (w_idx + 1),
				"WRECK",
				w_coords
			)
			wreck_body.radius_km = rng.randf_range(1.5, 4.0)
			wreck_body.mass_tons = rng.randf_range(8.0e7, 3.5e8)
			wreck_body.occluding = false
			wreck_body.description = "Relitto bellico abbandonato con scafo squarciato e moduli di recupero."
			wreck_body.resources = ["ALLOYS", "SCRAP_ELECTRONICS", "COMPONENTS"]
			wreck_body.comms_frequency = 850.5
			
			var w_elevation: float = rng.randf_range(300.0, 1100.0) * (1.0 if rng.randf() > 0.5 else -1.0)
			if wreck_body.get("local_elevation") != null:
				wreck_body.set("local_elevation", w_elevation)
			wreck_body.set_meta("local_elevation", w_elevation)
			system.add_or_update_body(wreck_body)

			var w_sec := SectorData.new(w_coords, SectorData.format_coords_to_id(w_coords), "Quadrante Relitto %d" % (w_idx + 1))
			w_sec.sector_type = "WRECK_SITE"
			w_sec.security_level = "ANARCHY" if archetype == Archetype.ANARCHY_PIRATE_SECTOR else "LOW"
			w_sec.add_entity(wreck_body)
			system.add_or_update_custom_sector(w_sec)

	# Zone Calde di Taglie (BOUNTY_ZONE)
	for b_idx in range(bounty_zones_count):
		var b_dist := rng.randf_range(9.0, 16.0)
		var b_angle := rng.randf_range(0.0, TAU)
		var b_z := rng.randi_range(-vertical_spread, vertical_spread)
		var b_coords := _find_free_coord(
			Vector3i(int(round(b_dist * cos(b_angle))), int(round(b_dist * sin(b_angle))), b_z),
			occupied_coords, rng
		)
		occupied_coords[b_coords] = true

		var b_body := CelestialBodyData.new(
			"BOUNTY_%s_%d" % [sys_tag, b_idx + 1],
			"Avamposto Corsaro %d" % (b_idx + 1),
			"BOUNTY_ZONE",
			b_coords
		)
		b_body.radius_km = 1.0
		b_body.occluding = false
		b_body.description = "Settore ad alto rischio presidiato da sciacalli e navi ricercate."
		b_body.comms_frequency = 2185.2
		var b_elev: float = rng.randf_range(-800.0, 800.0)
		if b_body.get("local_elevation") != null:
			b_body.set("local_elevation", b_elev)
		b_body.set_meta("local_elevation", b_elev)
		system.add_or_update_body(b_body)

		var b_sec := SectorData.new(b_coords, SectorData.format_coords_to_id(b_coords), "Settore Taglia Corsara %d" % (b_idx + 1))
		b_sec.sector_type = "BOUNTY_ZONE"
		b_sec.security_level = "ANARCHY"
		b_sec.traffic_density = 0.5
		b_sec.add_entity(b_body)
		system.add_or_update_custom_sector(b_sec)

	return system

## Cerca una coordinata 3D libera vicina se la destinazione candidata è già occupata
static func _find_free_coord(cand: Vector3i, occupied: Dictionary, rng: RandomNumberGenerator) -> Vector3i:
	if not occupied.has(cand):
		return cand
	
	# Prova offset adiacenti a spirale
	var offsets: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(1, 1, 0), Vector3i(-1, -1, 0),
		Vector3i(1, 0, 1), Vector3i(-1, 0, -1), Vector3i(0, 1, 1), Vector3i(0, -1, -1)
	]
	for o_idx in range(offsets.size() - 1, 0, -1):
		var swap_o := rng.randi_range(0, o_idx)
		var tmp_o = offsets[o_idx]
		offsets[o_idx] = offsets[swap_o]
		offsets[swap_o] = tmp_o
	
	for off in offsets:
		var c := cand + off
		if not occupied.has(c):
			return c
			
	# Fallback aggiungendo offset casuale più ampio
	for attempt in range(20):
		var c := cand + Vector3i(rng.randi_range(-3, 3), rng.randi_range(-3, 3), rng.randi_range(-2, 2))
		if not occupied.has(c) and c != Vector3i.ZERO:
			return c
			
	return cand + Vector3i(rng.randi_range(2, 5), rng.randi_range(2, 5), 1)
