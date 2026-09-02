class_name MiningManager
extends Node

## Gestore principale del ciclo di gameplay Deep Core Mining & Derelict Scavenging.
## Si occupa di:
## 1. Analisi spettrometrica preliminare su Sensori (vene di metalli pesanti, leghe rare, cristalli, ghiaccio).
## 2. Frantumazione progressiva: danni laser o cinetici rilasciano frammenti fisici (MineralDepositEntity).
## 3. Cattura tramite harpoon/fascio magnetico del Service Drone e stivaggio nella Cargo Bay.
## 4. Scavenging relitti: violazione ICE (Hacker), taglio paratie (Laser Drone), infiltrazione condotti (Duct Drone).

signal asteroid_scanned(asteroid_id: String, spectrometry_info: Dictionary)
signal asteroid_fragmented(asteroid: Node, fragments: Array)
signal resource_harvested(resource_data: Dictionary, destination: String)
signal derelict_scanned(derelict_id: String, scan_info: Dictionary)
signal derelict_breached(derelict_id: String)
signal derelict_hacked(derelict_id: String, success: bool)
signal salvage_collected(derelict_id: String, loot_data: Dictionary)

# Risorse minerarie disponibili
const MINERAL_TYPES: Dictionary = {
	"heavy_metals": {
		"name": "Metalli Pesanti Grezzi",
		"base_val": 120,
		"mass": 30.0,
		"vol": 0.4,
		"flux": 1.2,
		"water": 0.0
	},
	"rare_alloys": {
		"name": "Leghe Rare Complesse",
		"base_val": 350,
		"mass": 25.0,
		"vol": 0.3,
		"flux": 3.5,
		"water": 0.0
	},
	"crystals": {
		"name": "Cristalli di Quarzo Galattico",
		"base_val": 500,
		"mass": 15.0,
		"vol": 0.2,
		"flux": 5.0,
		"water": 0.0
	},
	"water_ice": {
		"name": "Ghiaccio d'Acqua Minerale",
		"base_val": 80,
		"mass": 20.0,
		"vol": 0.5,
		"flux": 0.5,
		"water": 15.0
	},
	"durasteel_ore": {
		"name": "Minerale Grezzo di Durasteel",
		"base_val": 200,
		"mass": 40.0,
		"vol": 0.6,
		"flux": 2.0,
		"water": 0.0
	}
}

var mineral_deposit_scene: PackedScene = preload("res://Outside/Mining/mineral_deposit_entity.tscn")
var derelict_ship_scene: PackedScene = preload("res://Outside/Mining/derelict_ship_entity.tscn")

# Mappa dello stato degli asteroidi conosciuti
# { asteroid_instance_id: { health, max_health, resource_type, purity, fragments_remaining } }
var _asteroid_states: Dictionary = {}

func _ready() -> void:
	add_to_group("mining_manager")

## Inizializza o recupera lo stato minerario di un asteroide
func get_or_register_asteroid_state(asteroid: Node) -> Dictionary:
	var id := str(asteroid.get_instance_id())
	if not _asteroid_states.has(id):
		var types_keys := MINERAL_TYPES.keys()
		var chosen_type: String = types_keys[randi() % types_keys.size()]
		# Se l'asteroide ha un tipo preimpostato
		if asteroid.get("mineral_type"):
			chosen_type = asteroid.get("mineral_type")
		
		var purity_val: float = snappedf(randf_range(0.5, 1.0), 0.01)
		if asteroid.get("mineral_purity"):
			purity_val = float(asteroid.get("mineral_purity"))

		_asteroid_states[id] = {
			"asteroid_node": asteroid,
			"resource_type": chosen_type,
			"purity": purity_val,
			"health": 200.0,
			"max_health": 200.0,
			"total_fragments": randi_range(3, 6),
			"spawned_fragments": 0,
			"scanned": false
		}
	return _asteroid_states[id]

## Analisi spettrometrica preliminare da parte dei Sensori
func perform_spectrometric_scan(asteroid: Node) -> Dictionary:
	var state := get_or_register_asteroid_state(asteroid)
	state["scanned"] = true
	var type_info: Dictionary = MINERAL_TYPES.get(state["resource_type"], MINERAL_TYPES["heavy_metals"])
	var res_info := {
		"asteroid_id": str(asteroid.get_instance_id()),
		"name": asteroid.name if "name" in asteroid else "Asteroide",
		"composition": state["resource_type"],
		"resource_name": type_info["name"],
		"purity_pct": int(state["purity"] * 100),
		"estimated_yield_fragments": state["total_fragments"],
		"health_pct": int((state["health"] / state["max_health"]) * 100),
		"base_value_credits": int(type_info["base_val"] * state["purity"]),
		"flux_potential": snappedf(type_info["flux"] * state["purity"], 0.1),
		"water_units": snappedf(type_info["water"] * state["purity"], 0.1)
	}
	asteroid_scanned.emit(str(asteroid.get_instance_id()), res_info)
	return res_info

## Applica danno minerario (armi della nave, torrette soldato o laser drone) all'asteroide
func apply_mining_damage_to_asteroid(asteroid: Node, damage_amount: float, hit_position: Vector3 = Vector3.ZERO) -> Array:
	var state := get_or_register_asteroid_state(asteroid)
	var prev_health: float = state["health"]
	state["health"] = max(0.0, state["health"] - damage_amount)
	
	var health_step: float = state["max_health"] / float(state["total_fragments"])
	var prev_steps: int = int((state["max_health"] - prev_health) / health_step)
	var curr_steps: int = int((state["max_health"] - state["health"]) / health_step)
	var fragments_to_spawn: int = min(curr_steps - prev_steps, state["total_fragments"] - state["spawned_fragments"])
	
	var spawned_nodes: Array = []
	if fragments_to_spawn > 0:
		for i in range(fragments_to_spawn):
			var frag := _spawn_mineral_fragment(asteroid, state, hit_position)
			if frag:
				spawned_nodes.append(frag)
				state["spawned_fragments"] += 1
		
		asteroid_fragmented.emit(asteroid, spawned_nodes)
	
	return spawned_nodes

## Genera un frammento minerario fisico (MineralDepositEntity)
func _spawn_mineral_fragment(asteroid: Node, state: Dictionary, hit_position: Vector3) -> Node:
	var fragment = mineral_deposit_scene.instantiate()
	var type_key: String = state["resource_type"]
	var type_info: Dictionary = MINERAL_TYPES.get(type_key, MINERAL_TYPES["heavy_metals"])
	
	fragment.deposit_id = "%s_frag_%d" % [type_key, state["spawned_fragments"] + 1]
	fragment.mineral_name = type_info["name"]
	fragment.resource_type = type_key
	fragment.mass_kg = type_info["mass"]
	fragment.volume_m3 = type_info["vol"]
	fragment.purity = state["purity"]
	fragment.base_value_credits = type_info["base_val"]
	fragment.flux_yield = type_info["flux"]
	fragment.life_support_water_units = type_info["water"]
	
	# Posizionamento
	var spawn_pos: Vector3 = hit_position
	if spawn_pos == Vector3.ZERO and asteroid is Node3D:
		spawn_pos = (asteroid as Node3D).global_position + Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
	else:
		spawn_pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))

	var parent_node := asteroid.get_parent()
	if parent_node:
		parent_node.add_child(fragment)
		fragment.global_position = spawn_pos
		# Impulso fisico leggero di dispersione
		var impulse := Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)).normalized() * randf_range(2.0, 5.0)
		fragment.apply_central_impulse(impulse)
	
	return fragment

## Cattura frammento e stivaggio istantaneo nella Cargo Bay o nel Drone
func capture_deposit(fragment: Node, collector: Node, cargo_bay: Node = null) -> bool:
	if not fragment or fragment.is_collected:
		return false
	
	var res_data: Dictionary = fragment.get_resource_dict()
	var success := false
	
	# Se il collector è un drone con stiva limitata
	if collector and collector.has_method("collect_cargo_item"):
		success = collector.collect_cargo_item(res_data["id"], res_data["name"], res_data["mass_kg"])
		if success:
			fragment.complete_collection(collector)
			resource_harvested.emit(res_data, "SERVICE_DRONE")
			return true

	# Se viene fornito direttamente il CargoManager / CargoBay
	if cargo_bay and cargo_bay.has_method("add_item"):
		success = cargo_bay.add_item(res_data, 1)
		if success:
			# Se c'è acqua e abbiamo LifeSupport, possiamo notificarlo
			if res_data.get("water_units") > 0.0:
				_replenish_life_support_water(res_data["water_units"])
			fragment.complete_collection(cargo_bay)
			resource_harvested.emit(res_data, "CARGO_BAY")
			return true

	# Fallback diretto completamento
	fragment.complete_collection(collector if collector else self)
	resource_harvested.emit(res_data, "CARGO_BAY")
	return true

func _replenish_life_support_water(amount: float) -> void:
	var life_support_nodes = get_tree().get_nodes_in_group("life_support")
	for ls in life_support_nodes:
		if ls.has_method("add_water_supply"):
			ls.add_water_supply(amount)
		elif "water_level" in ls:
			ls.water_level = min(100.0, ls.water_level + amount)

# --- SCAVENGING LOGIC ---

## Esegue scansione sensori su un relitto
func scan_derelict(derelict: Node) -> Dictionary:
	if not derelict:
		return {}
	var data: Dictionary = derelict.get_sensor_scan_data()
	derelict_scanned.emit(derelict.derelict_id, data)
	return data

## Esegue il taglio laser delle paratie esterne del relitto
func cut_derelict_bulkhead(derelict: Node, laser_power: float) -> bool:
	if not derelict:
		return false
	var breached: bool = derelict.apply_laser_cutting(laser_power)
	if breached:
		derelict_breached.emit(derelict.derelict_id)
	return breached

## Esegue hacking ICE del relitto (Hacker)
func hack_derelict_ice(derelict: Node, hacker_level: int, bypass_code: String = "") -> bool:
	if not derelict:
		return false
	var ok: bool = derelict.hack_ice_subsystem(hacker_level, bypass_code)
	derelict_hacked.emit(derelict.derelict_id, ok)
	return ok

## Infiltra condotti interni con Duct Drone
func infiltrate_derelict_with_duct_drone(derelict: Node, duct_drone: Node = null) -> Dictionary:
	if not derelict:
		return {"success": false}
	return derelict.infiltrate_ducts(duct_drone)

## Raccoglie moduli o risorse dal relitto e li trasferisce al drone o stiva
func scavenge_derelict_loot(derelict: Node, destination: Node) -> Dictionary:
	if not derelict:
		return {"error": "NO_DERELICT"}
	var result: Dictionary = derelict.scavenge_all_available(destination)
	if result.get("success"):
		salvage_collected.emit(derelict.derelict_id, result)
	return result
