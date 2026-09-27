class_name AntennaArrayComponent
extends ShipPhysicalComponent

## Modello dell'antenna transceiver e array comunicazioni sub-spazio (antenna_array).
## Gestisce rotazione azimutale, tuning e ascolto frequenze radio, e stabilizzazione link EW per HackExploits.
## Le frequenze visibili (visible_frequencies) sono calcolate dinamicamente in base all'azimut dell'antenna
## e alle trasmissioni emesse da navi, stazioni, beacon, relé nello spazio 3D corrente o nella mappa di sistema.
## Quando disalimentato o offline, waterfall muta, richieste docking bloccate e link EW disconnesso.

signal azimuth_changed(deg: float)
signal frequency_locked(frequency: float)
signal ew_link_established(target_id: String)
signal ew_link_lost()
signal message_received(frequency: float, message: String)

@export var azimuth_deg: float = 0.0 # 0..360 gradi
@export var reception_cone_deg: float = 45.0 # Raggio di azione angolare antenna (45-60° di raggio)
@export var max_range_quadrants: float = 5.0 # Distanza massima raggiungibile in quadranti a piena potenza erogata (100% / power_ratio = 1.0)
@export var is_scanning: bool = false
@export var locked_frequency: float = 0.0
@export var ew_target_id: String = ""
@export var ew_link_active: bool = false

var visible_frequencies: Array[float] = []
var custom_emitters: Array[Dictionary] = []

func _init(p_device_id: String = "antenna_array", p_room_id: String = "comunicazioni", p_category: String = "comms") -> void:
	super._init(p_device_id, p_room_id, p_category)
	power_draw_nominal = 15.0
	update_visible_frequencies()

func initialize_registers() -> void:
	super.initialize_registers()
	update_visible_frequencies()
	registers["azimuth"] = azimuth_deg
	registers["reception_cone"] = reception_cone_deg
	registers["max_range_quadrants"] = max_range_quadrants
	registers["range_quadrants"] = get_effective_range_quadrants()
	registers["is_scanning"] = is_scanning
	registers["locked_freq"] = locked_frequency
	registers["ew_connected"] = ew_link_active
	registers["ew_target"] = ew_target_id
	registers["visible_freq_count"] = visible_frequencies.size()
	registers["visible_frequencies"] = visible_frequencies.duplicate()
	
	if not readonly_registers.has("ew_connected"):
		readonly_registers.append("ew_connected")
	if not readonly_registers.has("ew_target"):
		readonly_registers.append("ew_target")
	if not readonly_registers.has("range_quadrants"):
		readonly_registers.append("range_quadrants")
	if not readonly_registers.has("visible_freq_count"):
		readonly_registers.append("visible_freq_count")
	if not readonly_registers.has("visible_frequencies"):
		readonly_registers.append("visible_frequencies")

func read_register(reg_name: String) -> Variant:
	match reg_name:
		"azimuth":
			return azimuth_deg
		"reception_cone", "beam_radius":
			return reception_cone_deg
		"max_range_quadrants":
			return max_range_quadrants
		"range_quadrants", "effective_range_quadrants":
			return get_effective_range_quadrants()
		"is_scanning":
			return is_scanning
		"locked_freq":
			return locked_frequency
		"ew_connected":
			return ew_link_active and is_online and power_ratio >= 0.3
		"ew_target":
			return ew_target_id
		"visible_freq_count":
			return visible_frequencies.size() if (is_online and power_ratio >= 0.2) else 0
		"visible_frequencies":
			return get_frequencies()
		_:
			return super.read_register(reg_name)

func _on_register_written(reg_name: String, value: Variant) -> void:
	super._on_register_written(reg_name, value)
	match reg_name:
		"azimuth":
			rotate_antenna(float(value))
		"reception_cone", "beam_radius":
			set_reception_cone(float(value))
		"max_range_quadrants":
			set_max_range_quadrants(float(value))
		"is_scanning":
			toggle_scan(bool(value))
		"locked_freq":
			lock_frequency(float(value))

func rotate_antenna(degrees: float) -> void:
	azimuth_deg = fposmod(degrees, 360.0)
	registers["azimuth"] = azimuth_deg
	update_visible_frequencies()
	_sync_comms_registers()
	azimuth_changed.emit(azimuth_deg)

func set_reception_cone(cone_deg: float) -> void:
	reception_cone_deg = clampf(cone_deg, 45.0, 60.0)
	registers["reception_cone"] = reception_cone_deg
	update_visible_frequencies()
	_sync_comms_registers()

func get_effective_range_quadrants() -> float:
	if not is_online or power_ratio < 0.2:
		return 0.0
	return max_range_quadrants * power_ratio

func set_max_range_quadrants(quadrants: float) -> void:
	max_range_quadrants = maxf(0.5, quadrants)
	registers["max_range_quadrants"] = max_range_quadrants
	update_visible_frequencies()
	_sync_comms_registers()

func toggle_scan(enabled: bool) -> void:
	is_scanning = enabled
	registers["is_scanning"] = is_scanning

func lock_frequency(freq: float) -> bool:
	if not is_online or power_ratio < 0.2:
		return false
	locked_frequency = freq
	registers["locked_freq"] = locked_frequency
	frequency_locked.emit(locked_frequency)
	return true

func establish_ew_link(target_id: String) -> bool:
	if not is_online or power_ratio < 0.4:
		return false
	ew_target_id = target_id
	ew_link_active = true
	registers["ew_connected"] = true
	registers["ew_target"] = ew_target_id
	ew_link_established.emit(target_id)
	return true

func disconnect_ew_link() -> void:
	if ew_link_active:
		ew_link_active = false
		ew_target_id = ""
		registers["ew_connected"] = false
		registers["ew_target"] = ""
		ew_link_lost.emit()

func get_frequencies() -> Array[float]:
	if not is_online or power_ratio < 0.2:
		visible_frequencies.clear()
		return []
	update_visible_frequencies()
	return visible_frequencies

func get_visible_frequencies() -> Array[float]:
	return get_frequencies()

## Aggiunge un emettitore personalizzato (per simulazioni, test o eventi missione)
func add_emitter(freq: float, bearing_deg: float, emitter_type: String = "BEACON", emitter_name: String = "", distance_quadrants: float = 1.0) -> void:
	custom_emitters.append({
		"freq": freq,
		"bearing_deg": fposmod(bearing_deg, 360.0),
		"distance_quadrants": maxf(0.0, distance_quadrants),
		"type": emitter_type,
		"name": emitter_name,
		"source": "custom"
	})
	update_visible_frequencies()
	_sync_comms_registers()

## Rimuove un emettitore personalizzato in base alla frequenza
func remove_emitter(freq: float) -> void:
	var filtered: Array[Dictionary] = []
	for em in custom_emitters:
		if absf(float(em.get("freq", 0.0)) - freq) > 0.05:
			filtered.append(em)
	custom_emitters = filtered
	update_visible_frequencies()
	_sync_comms_registers()

## Svuota la lista degli emettitori personalizzati
func clear_custom_emitters() -> void:
	custom_emitters.clear()
	update_visible_frequencies()
	_sync_comms_registers()

## Ricalcola la lista visible_frequencies in base all'azimut corrente dell'antenna, al raggio di azione (45-60°)
## e alla distanza massima (X quadranti in base alla potenza erogata)
func update_visible_frequencies() -> Array[float]:
	if not is_online or power_ratio < 0.2:
		visible_frequencies.clear()
		return visible_frequencies

	var effective_max_range := get_effective_range_quadrants()
	var detected_emitters := get_all_detected_emitters()
	var result: Array[float] = []

	for emitter in detected_emitters:
		var dist_q: float = float(emitter.get("distance_quadrants", 0.0))
		# 1. Filtro Portata: X quadranti in base alla potenza erogata
		if dist_q > effective_max_range:
			continue

		# 2. Filtro Angolare: raggio di azione 45-60° di raggio
		var bearing: float = float(emitter.get("bearing_deg", 0.0))
		var diff_deg := absf(fposmod(bearing - azimuth_deg + 180.0, 360.0) - 180.0)
		if diff_deg <= reception_cone_deg:
			var freq: float = snappedf(float(emitter.get("freq", 0.0)), 0.1)
			if freq > 0.0 and not _has_frequency_approx(result, freq):
				result.append(freq)

	result.sort()
	visible_frequencies = result
	return visible_frequencies

func _has_frequency_approx(arr: Array[float], freq: float, tolerance: float = 0.05) -> bool:
	for f in arr:
		if absf(f - freq) <= tolerance:
			return true
	return false

## Raccoglie tutti gli emettitori attivi nello spazio 3D corrente, nella mappa stellare a settori e sorgenti custom
func get_all_detected_emitters() -> Array[Dictionary]:
	var emitters: Array[Dictionary] = []
	var has_live_sources := false

	# 1. Emettitori Custom registrati via script
	for c_em in custom_emitters:
		if c_em.has("freq") and c_em.has("bearing_deg"):
			var em_entry: Dictionary = c_em.duplicate()
			if not em_entry.has("distance_quadrants"):
				em_entry["distance_quadrants"] = 1.0
			emitters.append(em_entry)
			has_live_sources = true

	# 2. Spazio Corrente (SpaceWorldManager e Scene 3D)
	var swm := _get_space_world_manager()
	if swm != null and swm.has_method("get_comms_transmissions"):
		var transmissions: Array = swm.get_comms_transmissions()
		for t in transmissions:
			if t is Dictionary and t.has("freq") and t.has("bearing_deg"):
				var f := float(t["freq"])
				var b := float(t["bearing_deg"])
				var dist_q := 0.0
				if t.has("distance_quadrants"):
					dist_q = float(t["distance_quadrants"])
				elif t.has("distance"):
					var d_val := float(t["distance"])
					dist_q = d_val / 100000.0 if d_val > 5000.0 else 0.0
				emitters.append({
					"freq": f,
					"bearing_deg": fposmod(b, 360.0),
					"distance_quadrants": dist_q,
					"type": str(t.get("type", "UNKNOWN")),
					"name": str(t.get("name", "")),
					"source": "current_space"
				})
				has_live_sources = true

	# Controllo nodi 3D fisici presenti nell'albero per gruppi radio se non già catturati
	var tree := _get_scene_tree()
	if tree != null:
		var ship := _get_spaceship()
		var ship_pos: Vector3 = ship.global_position if (ship and is_instance_valid(ship)) else Vector3.ZERO
		var ship_basis: Basis = ship.global_transform.basis if (ship and is_instance_valid(ship)) else Basis.IDENTITY

		for group_name in ["stations", "derelicts", "enemy_ships", "beacons", "relays", "ships"]:
			for node in tree.get_nodes_in_group(group_name):
				if node is Node3D and is_instance_valid(node) and node != ship:
					var freq := _extract_node_frequency(node, group_name)
					if freq > 0.0:
						var diff: Vector3 = node.global_position - ship_pos
						var local_diff: Vector3 = ship_basis.inverse() * diff
						var bearing := fposmod(rad_to_deg(atan2(local_diff.x, -local_diff.z)), 360.0)
						var dist_q := float(node.get("distance_quadrants")) if "distance_quadrants" in node else 0.0
						emitters.append({
							"freq": freq,
							"bearing_deg": bearing,
							"distance_quadrants": dist_q,
							"type": group_name.to_upper(),
							"name": node.name,
							"source": "space_node"
						})
						has_live_sources = true

	# 3. Mappa di Sistema (StarSystemGridManager / StarSystemData / Settori)
	var gm := _get_star_system_grid_manager()
	if gm != null:
		var cur_coords: Vector3i = gm.get_current_sector_coords()
		var bodies: Array = gm.system_celestial_bodies
		if bodies.is_empty() and gm.current_system_data != null:
			bodies = gm.current_system_data.celestial_bodies

		var ship_heading_deg := _get_ship_heading_deg()

		for b in bodies:
			if b == null:
				continue
			var b_type := ""
			var b_id := ""
			var b_name := ""
			var b_coords := Vector3i.ZERO
			var b_freq := 0.0

			if b is CelestialBodyData:
				b_type = b.type.to_upper()
				b_id = b.id
				b_name = b.name
				b_coords = b.coords
				if "comms_frequency" in b:
					b_freq = float(b.get("comms_frequency"))
				elif b.has_meta("comms_frequency"):
					b_freq = float(b.get_meta("comms_frequency"))
			elif b is Dictionary:
				b_type = str(b.get("type", "")).to_upper()
				b_id = str(b.get("id", ""))
				b_name = str(b.get("name", ""))
				var c_val: Variant = b.get("coords")
				if c_val is Array and c_val.size() >= 3:
					b_coords = Vector3i(int(c_val[0]), int(c_val[1]), int(c_val[2]))
				elif c_val is Vector3i:
					b_coords = c_val
				b_freq = float(b.get("comms_frequency", 0.0))

			if b_freq <= 0.0:
				b_freq = _get_default_frequency_for_system_body(b_type, b_id, b_name)

			if b_freq > 0.0:
				var dx := float(b_coords.x - cur_coords.x)
				var dy := float(b_coords.y - cur_coords.y)
				var dist_quadrants := sqrt(dx * dx + dy * dy)

				var bearing_deg := 0.0
				if dist_quadrants < 0.001:
					# Stesso settore della nave: segnale a prua o locale
					bearing_deg = 0.0
				else:
					var world_bearing := fposmod(rad_to_deg(atan2(dx, -dy)), 360.0)
					bearing_deg = fposmod(world_bearing - ship_heading_deg, 360.0)

				emitters.append({
					"freq": b_freq,
					"bearing_deg": bearing_deg,
					"distance_quadrants": dist_quadrants,
					"type": b_type,
					"name": b_name,
					"source": "system_map"
				})
				has_live_sources = true

	# 4. Sorgenti Fallback (quando nessun manager di mondo/griglia è attivo, es. unit test isolati)
	if not has_live_sources:
		emitters.append_array(_get_fallback_emitters())

	return emitters

func _extract_node_frequency(node: Node3D, group: String) -> float:
	if not node or not is_instance_valid(node):
		return 0.0
	if "comms_frequency" in node and float(node.get("comms_frequency")) > 0.0:
		return float(node.get("comms_frequency"))
	if "radio_frequency" in node and float(node.get("radio_frequency")) > 0.0:
		return float(node.get("radio_frequency"))
	if node.has_method("get_radio_frequency"):
		return float(node.get_radio_frequency())

	match group:
		"stations":
			return 1840.0
		"derelicts":
			var beacon_active: bool = node.get("distress_beacon_active") if "distress_beacon_active" in node else true
			return 850.5 if beacon_active else 0.0
		"enemy_ships", "ships":
			return 2185.2 if group == "enemy_ships" else 1920.0
		"beacons":
			return 2750.0
		"relays":
			return 1420.0
	return 0.0

func _get_default_frequency_for_system_body(b_type: String, b_id: String, b_name: String) -> float:
	var type_upper := b_type.to_upper()
	var id_upper := b_id.to_upper()
	var name_lower := b_name.to_lower()

	# Stazioni Spaziali
	if type_upper in ["STATION", "OUTPOST", "PORT", "HUB", "MILITARY_SHIPYARD", "MINING_DEPOT", "COMMERCIAL_HUB", "CIVILIAN_OUTPOST"] \
		or id_upper.begins_with("STATION") or name_lower.contains("stazione"):
		return 1840.0

	# Navi / Pattuglie / Convogli
	if type_upper in ["PATROL", "SHIP", "VESSEL", "COURIER"] \
		or id_upper.begins_with("PATROL") or id_upper.begins_with("SHIP") or name_lower.contains("pattuglia"):
		return 1920.0

	# Zone Taglie Corsare / Pirati
	if type_upper in ["BOUNTY_ZONE", "PIRATE", "CORVETTE"] \
		or id_upper.begins_with("BOUNTY") or name_lower.contains("corsaro"):
		return 2185.2

	# Relitti con Mayday Beacon
	if type_upper in ["WRECK", "DERELICT"] \
		or id_upper.begins_with("WRECK") or name_lower.contains("relitto"):
		return 850.5

	# Fari di Radionavigazione / Beacon
	if type_upper in ["BEACON", "FARO", "BUOY"] \
		or id_upper.begins_with("BEACON") or name_lower.contains("beacon") or name_lower.contains("faro"):
		return 2750.0

	# Relé di Comunicazione / Subspazio
	if type_upper in ["RELAY", "RELE", "COMM_ARRAY", "COMM_BUOY", "SUB_SPACE_RELAY"] \
		or id_upper.begins_with("RELAY") or name_lower.contains("relé") or name_lower.contains("relay"):
		return 1420.0

	return 0.0

func _get_fallback_emitters() -> Array[Dictionary]:
	return [
		{"freq": 1920.0, "bearing_deg": 0.0, "distance_quadrants": 1.0, "type": "PATROL", "name": "Pattuglia Vanguard"},
		{"freq": 433.0, "bearing_deg": 0.0, "distance_quadrants": 0.5, "type": "SHIP", "name": "Telemetry Sonda"},
		{"freq": 850.5, "bearing_deg": 40.0, "distance_quadrants": 2.0, "type": "DERELICT", "name": "SOS Distress Beacon"},
		{"freq": 1920.0, "bearing_deg": 0.0, "distance_quadrants": 3.0, "type": "COURIER", "name": "S-Net Courier"},
		{"freq": 2185.2, "bearing_deg": 225.0, "distance_quadrants": 4.0, "type": "CORVETTE", "name": "Pirate Corvette"},
		{"freq": 1420.0, "bearing_deg": 180.0, "distance_quadrants": 2.5, "type": "RELAY", "name": "Subspace Relay"},
		{"freq": 1840.0, "bearing_deg": 270.0, "distance_quadrants": 3.5, "type": "STATION", "name": "Stazione Valkyrie"},
		{"freq": 2400.0, "bearing_deg": 270.0, "distance_quadrants": 4.5, "type": "STATION", "name": "Civilian Link"},
		{"freq": 2750.0, "bearing_deg": 315.0, "distance_quadrants": 5.0, "type": "BEACON", "name": "Deep Space Beacon"}
	]

func _get_space_world_manager() -> Node:
	if Engine.has_singleton("SpaceWorldManager"):
		return Engine.get_singleton("SpaceWorldManager")
	var tree := _get_scene_tree()
	if tree != null and tree.root != null:
		if tree.root.has_node("SpaceWorldManager"):
			return tree.root.get_node("SpaceWorldManager")
	if is_inside_tree():
		return get_node_or_null("/root/SpaceWorldManager")
	return null

func _get_star_system_grid_manager() -> Node:
	if Engine.has_singleton("StarSystemGridManager"):
		return Engine.get_singleton("StarSystemGridManager")
	var tree := _get_scene_tree()
	if tree != null and tree.root != null:
		if tree.root.has_node("StarSystemGridManager"):
			return tree.root.get_node("StarSystemGridManager")
	if is_inside_tree():
		return get_node_or_null("/root/StarSystemGridManager")
	return null

func _get_scene_tree() -> SceneTree:
	if is_inside_tree():
		return get_tree()
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return main_loop as SceneTree
	return null

func _get_spaceship() -> Node3D:
	var swm := _get_space_world_manager()
	if swm != null and swm.has_method("get_spaceship"):
		var s = swm.get_spaceship()
		if s is Node3D and is_instance_valid(s):
			return s
	var tree := _get_scene_tree()
	if tree != null:
		for s in tree.get_nodes_in_group("player_ship"):
			if s is Node3D and is_instance_valid(s):
				return s
	return null

func _get_ship_heading_deg() -> float:
	var ship := _get_spaceship()
	if ship != null and is_instance_valid(ship):
		var ship_fwd: Vector3 = -ship.global_transform.basis.z.normalized()
		return fposmod(rad_to_deg(atan2(ship_fwd.x, -ship_fwd.z)), 360.0)
	return 0.0

func step(delta: float) -> void:
	if not is_online:
		power_draw_current = 0.0
		is_scanning = false
		if ew_link_active:
			disconnect_ew_link()
		visible_frequencies.clear()
		_sync_comms_registers()
		super.step(delta)
		return

	# Calcolo consumo: base 15 MW + 15 MW se scanning + 35 MW se link EW
	var draw := power_draw_nominal
	if is_scanning:
		draw += 15.0
	if ew_link_active:
		draw += 35.0

	power_draw_current = draw
	if power_draw_current > 0.0:
		power_ratio = clampf(power_supplied / power_draw_current, 0.0, 1.0)
	else:
		power_ratio = 1.0

	var health_factor := health_percent / 100.0
	var is_operational := (power_ratio >= 0.3) and (health_factor > 0.1)

	if not is_operational and ew_link_active:
		disconnect_ew_link()

	if is_operational and is_scanning:
		rotate_antenna(azimuth_deg + 45.0 * power_ratio * delta)
	else:
		update_visible_frequencies()

	_sync_comms_registers()
	super.step(delta)

func _sync_comms_registers() -> void:
	registers["azimuth"] = azimuth_deg
	registers["reception_cone"] = reception_cone_deg
	registers["max_range_quadrants"] = max_range_quadrants
	registers["range_quadrants"] = get_effective_range_quadrants()
	registers["is_scanning"] = is_scanning
	registers["locked_freq"] = locked_frequency
	registers["ew_connected"] = ew_link_active
	registers["ew_target"] = ew_target_id
	var count: int = visible_frequencies.size() if (is_online and power_ratio >= 0.2) else 0
	registers["visible_freq_count"] = count
	registers["visible_frequencies"] = visible_frequencies.duplicate() if (is_online and power_ratio >= 0.2) else []

func get_telemetry() -> Dictionary:
	var telem := super.get_telemetry()
	telem["azimuth"] = azimuth_deg
	telem["reception_cone"] = reception_cone_deg
	telem["max_range_quadrants"] = max_range_quadrants
	telem["range_quadrants"] = get_effective_range_quadrants()
	telem["is_scanning"] = is_scanning
	telem["locked_freq"] = locked_frequency
	telem["ew_connected"] = ew_link_active
	telem["ew_target"] = ew_target_id
	telem["visible_frequencies"] = get_frequencies()
	return telem
