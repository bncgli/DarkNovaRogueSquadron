class_name MissionManagerSingleton
extends Node

## MissionManager Autonomo per Dark Nova: Rogue Squadron
## Coordina il ciclo vitale di contratti, taglie (Bounty), missioni di trasporto e recupero relitti.
## Disaccoppiato dalla UI per consentire simulazione indipendente e test headless.

enum ContractType {
	BOUNTY,
	TRANSPORT,
	RETRIEVAL,
	PATROL
}

enum ContractStatus {
	AVAILABLE,
	IN_PROGRESS,
	COMPLETED,
	FAILED,
	CLAIMED
}

signal contract_accepted(contract_data: Dictionary)
signal contract_completed(contract_data: Dictionary)
signal contract_claimed(contract_data: Dictionary, credits: int, flux: int)
signal contract_failed(contract_data: Dictionary, reason: String)
signal contracts_updated()

## Contratti disponibili e attivi
var available_contracts: Array[Dictionary] = []
var active_contracts: Array[Dictionary] = []
var completed_contracts: Array[Dictionary] = []

## Singleton statico se instanziato come autoload
static var instance: MissionManagerSingleton = null

func _init() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	if instance == null:
		instance = self

## Genera contratti procedurali per una data stazione orbitale
func generate_station_contracts(station: Node, system_data: Resource = null) -> Array[Dictionary]:
	var contracts: Array[Dictionary] = []
	var station_id: String = "STATION_START"
	var station_name: String = "Stazione Orbitale"
	var station_sector := Vector3i.ZERO
	
	if station:
		if "station_id" in station:
			station_id = str(station.station_id)
		elif "id" in station:
			station_id = str(station.id)
		if "station_name" in station:
			station_name = str(station.station_name)
		elif "name" in station:
			station_name = str(station.name)
		if "current_sector" in station:
			station_sector = station.current_sector
	
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(station_id + "_CONTRACTS_SEED")
	
	# Trova destinazioni alternative nel sistema stellare se disponibili
	var other_stations: Array[Dictionary] = []
	if system_data and "celestial_bodies" in system_data:
		for body in system_data.celestial_bodies:
			if body.type == "STATION" and str(body.id) != station_id:
				other_stations.append({
					"id": str(body.id),
					"name": str(body.name),
					"coords": body.coords
				})
	
	var dest_station_id := "STATION_OUTPOST_B"
	var dest_station_name := "Raffineria Mineraria 'Titan-Alpha'"
	var dest_coords := station_sector + Vector3i(rng.randi_range(-3, 3), rng.randi_range(-3, 3), rng.randi_range(-1, 1))
	if not other_stations.is_empty():
		var dest: Dictionary = other_stations[rng.randi() % other_stations.size()]
		dest_station_id = dest["id"]
		dest_station_name = dest["name"]
		dest_coords = dest["coords"]
	
	# 1. BOUNTY HUNTING CONTRACT
	var bounty_seed := rng.randi_range(100, 999)
	var bounty_coords_3d := Vector3(
		rng.randf_range(800.0, 2200.0) * (1.0 if rng.randf() > 0.5 else -1.0),
		rng.randf_range(250.0, 950.0) * (1.0 if rng.randf() > 0.5 else -1.0),
		rng.randf_range(800.0, 2200.0) * (1.0 if rng.randf() > 0.5 else -1.0)
	)
	var bounty_sector := station_sector + Vector3i(rng.randi_range(-2, 2), rng.randi_range(-2, 2), rng.randi_range(-1, 1))
	var bounty_contract := {
		"id": "CNT_BOUNTY_%d" % bounty_seed,
		"title": "Taglia: Corsaro 'Red Vulture %d'" % bounty_seed,
		"type": "BOUNTY",
		"contract_type": ContractType.BOUNTY,
		"issuer": "Consorzio di Sicurezza Spaziale",
		"target_entity_id": "PIRATE_VULTURE_%d" % bounty_seed,
		"target_faction": "PIRATES",
		"target_sector": "Settore [%d, %d, %d]" % [bounty_sector.x, bounty_sector.y, bounty_sector.z],
		"target_sector_coords": bounty_sector,
		"target_coords_3d": bounty_coords_3d,
		"reward_credits": 2500 + rng.randi_range(500, 1500),
		"reward_flux": 3000 + rng.randi_range(500, 1500),
		"reward_liquid_flux": 3000 + rng.randi_range(500, 1500),
		"reward_debt_relief": 350,
		"creditor_relief_target": "Ship Rent Service",
		"status": "AVAILABLE",
		"contract_status": ContractStatus.AVAILABLE,
		"is_accepted": false,
		"is_completed": false,
		"origin_station_id": station_id,
		"description": "Neutralizzare la corvetta d'assalto pirata avvistata alle coordinate volumetriche indicate a quota Y = %.0f m." % bounty_coords_3d.y
	}
	contracts.append(bounty_contract)
	
	# 2. CARGO TRANSPORT CONTRACT
	var transport_seed := rng.randi_range(100, 999)
	var cargo_materials := [
		{"type": "TITANIUM", "name": "Titanio Grezzo", "amt": 15},
		{"type": "NANITES", "name": "Naniti Medici", "amt": 25},
		{"type": "ALLOY", "name": "Leghe Durasteel", "amt": 10},
		{"type": "ENERGY_CELL", "name": "Celle Energetiche al Plasma", "amt": 20}
	]
	var chosen_cargo: Dictionary = cargo_materials[rng.randi() % cargo_materials.size()]
	var transport_contract := {
		"id": "CNT_TRANS_%d" % transport_seed,
		"title": "Consegna Merci: %dx %s" % [chosen_cargo["amt"], chosen_cargo["name"]],
		"type": "TRANSPORT",
		"contract_type": ContractType.TRANSPORT,
		"issuer": "Ufficio Logistica Portuale",
		"cargo_type": chosen_cargo["type"],
		"cargo_name": chosen_cargo["name"],
		"cargo_amount": chosen_cargo["amt"],
		"origin_station_id": station_id,
		"destination_station_id": dest_station_id,
		"destination_station_name": dest_station_name,
		"target_sector": "Settore [%d, %d, %d]" % [dest_coords.x, dest_coords.y, dest_coords.z],
		"target_sector_coords": dest_coords,
		"target_coords_3d": Vector3(0.0, 0.0, 0.0),
		"reward_credits": 1400 + rng.randi_range(300, 900),
		"reward_flux": 1800 + rng.randi_range(300, 800),
		"reward_liquid_flux": 1800 + rng.randi_range(300, 800),
		"reward_debt_relief": 200,
		"creditor_relief_target": "Aegis Port Authority",
		"status": "AVAILABLE",
		"contract_status": ContractStatus.AVAILABLE,
		"is_accepted": false,
		"is_completed": false,
		"description": "Trasportare e consegnare carichi prioritari di %s presso la stazione '%s'." % [chosen_cargo["name"], dest_station_name]
	}
	contracts.append(transport_contract)
	
	# 3. RETRIEVAL CONTRACT (Recupero Relitto Volumetrico)
	var ret_seed := rng.randi_range(100, 999)
	var ret_coords_3d := Vector3(
		rng.randf_range(1100.0, 1900.0) * (1.0 if rng.randf() > 0.5 else -1.0),
		rng.randf_range(300.0, 850.0) * (1.0 if rng.randf() > 0.5 else -1.0),
		rng.randf_range(1100.0, 1900.0) * (1.0 if rng.randf() > 0.5 else -1.0)
	)
	var ret_sector := station_sector + Vector3i(rng.randi_range(-2, 2), rng.randi_range(-2, 2), rng.randi_range(-1, 1))
	var retrieval_contract := {
		"id": "CNT_RET_%d" % ret_seed,
		"title": "Recupero Scatola Nera: Relitto 'Apex-%d'" % ret_seed,
		"type": "RETRIEVAL",
		"contract_type": ContractType.RETRIEVAL,
		"issuer": "Autorità di Recupero Spaziale",
		"target_sector": "Settore [%d, %d, %d]" % [ret_sector.x, ret_sector.y, ret_sector.z],
		"target_sector_coords": ret_sector,
		"target_coords_3d": ret_coords_3d,
		"reward_credits": 1900 + rng.randi_range(400, 1200),
		"reward_flux": 2400 + rng.randi_range(400, 1200),
		"reward_liquid_flux": 2400 + rng.randi_range(400, 1200),
		"reward_debt_relief": 300,
		"creditor_relief_target": "Ship Rent Service",
		"status": "AVAILABLE",
		"contract_status": ContractStatus.AVAILABLE,
		"is_accepted": false,
		"is_completed": false,
		"origin_station_id": station_id,
		"description": "Individuare il relitto della fregata a quota Y = %.0f m e recuperare la memoria di volo." % ret_coords_3d.y
	}
	contracts.append(retrieval_contract)
	
	# 4. PATROL CONTRACT
	var patrol_seed := rng.randi_range(100, 999)
	var patrol_sector := station_sector + Vector3i(rng.randi_range(-1, 1), rng.randi_range(-1, 1), 0)
	var patrol_contract := {
		"id": "CNT_PATROL_%d" % patrol_seed,
		"title": "Pattugliamento Difensivo: Settore [%d, %d, %d]" % [patrol_sector.x, patrol_sector.y, patrol_sector.z],
		"type": "PATROL",
		"contract_type": ContractType.PATROL,
		"issuer": station_name,
		"target_sector": "Settore [%d, %d, %d]" % [patrol_sector.x, patrol_sector.y, patrol_sector.z],
		"target_sector_coords": patrol_sector,
		"target_coords_3d": Vector3(0.0, 150.0, 0.0),
		"reward_credits": 1100 + rng.randi_range(200, 600),
		"reward_flux": 1500 + rng.randi_range(200, 600),
		"reward_liquid_flux": 1500 + rng.randi_range(200, 600),
		"reward_debt_relief": 150,
		"creditor_relief_target": "ALL",
		"status": "AVAILABLE",
		"contract_status": ContractStatus.AVAILABLE,
		"is_accepted": false,
		"is_completed": false,
		"origin_station_id": station_id,
		"description": "Pattugliare le rotte d'accesso alla stazione ed eseguire scansioni radar approfondite."
	}
	contracts.append(patrol_contract)
	
	# Sincronizza i contratti nella stazione
	if station and "active_contracts" in station:
		station.active_contracts = contracts.duplicate(true)
	
	# Aggiungi a contratti disponibili
	for c in contracts:
		_register_available_contract(c)
		
	contracts_updated.emit()
	return contracts

func _register_available_contract(contract_data: Dictionary) -> void:
	var cid: String = str(contract_data.get("id"))
	for i in range(available_contracts.size()):
		if str(available_contracts[i].get("id")) == cid:
			available_contracts[i] = contract_data
			return
	available_contracts.append(contract_data)

## Recupera tutti i contratti associati a una stazione (disponibili, attivi, completati, riscossi)
func get_contracts_for_station(station_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for c in available_contracts:
		if str(c.get("origin_station_id")) == station_id:
			result.append(c)
			seen[str(c.get("id"))] = true
	for c in active_contracts:
		var cid := str(c.get("id"))
		if not seen.has(cid) and (str(c.get("origin_station_id")) == station_id or str(c.get("destination_station_id")) == station_id):
			result.append(c)
			seen[cid] = true
	for c in completed_contracts:
		var cid := str(c.get("id"))
		if not seen.has(cid) and (str(c.get("origin_station_id")) == station_id or str(c.get("destination_station_id")) == station_id):
			result.append(c)
			seen[cid] = true
	return result

## Recupera tutti i contratti disponibili per una stazione
func get_available_contracts_for_station(station_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for c in available_contracts:
		if str(c.get("origin_station_id")) == station_id and str(c.get("status")) == "AVAILABLE":
			result.append(c)
	return result

## Recupera tutti i contratti correntemente disponibili
func get_available_contracts() -> Array[Dictionary]:
	return available_contracts

## Recupera tutti i contratti correntemente attivi
func get_active_contracts() -> Array[Dictionary]:
	return active_contracts

## Recupera tutti i contratti completati pronti per il claim
func get_completed_contracts() -> Array[Dictionary]:
	return completed_contracts

## Cerca un contratto per ID
func get_contract_by_id(contract_id: String) -> Dictionary:
	for c in active_contracts:
		if str(c.get("id")) == contract_id:
			return c
	for c in completed_contracts:
		if str(c.get("id")) == contract_id:
			return c
	for c in available_contracts:
		if str(c.get("id")) == contract_id:
			return c
	return {}

## Accetta un contratto disponibile
func accept_contract(contract_id: String) -> bool:
	var target_contract: Dictionary = {}
	var source_idx: int = -1
	
	for i in range(available_contracts.size()):
		if str(available_contracts[i].get("id")) == contract_id:
			target_contract = available_contracts[i]
			source_idx = i
			break
			
	if target_contract.is_empty():
		# Cerca se già in active
		for c in active_contracts:
			if str(c.get("id")) == contract_id:
				return false
		return false
		
	if str(target_contract.get("status")) != "AVAILABLE":
		return false
		
	target_contract["status"] = "IN_PROGRESS"
	target_contract["contract_status"] = ContractStatus.IN_PROGRESS
	target_contract["is_accepted"] = true
	target_contract["is_completed"] = false
	
	active_contracts.append(target_contract)
	contract_accepted.emit(target_contract)
	contracts_updated.emit()
	
	sync_with_logbook(target_contract)
	
	# Sincronizza SpaceWorldManager se presente
	var swm = _get_space_world_manager()
	if swm and swm.has_method("add_active_contract"):
		swm.add_active_contract(target_contract)
		
	return true

## Completa un contratto attivo
func complete_contract(contract_id: String) -> bool:
	var target_contract: Dictionary = {}
	var active_idx: int = -1
	
	for i in range(active_contracts.size()):
		if str(active_contracts[i].get("id")) == contract_id:
			target_contract = active_contracts[i]
			active_idx = i
			break
			
	if target_contract.is_empty():
		return false
		
	if str(target_contract.get("status")) != "IN_PROGRESS":
		return false
		
	target_contract["status"] = "COMPLETED"
	target_contract["contract_status"] = ContractStatus.COMPLETED
	target_contract["is_completed"] = true
	
	completed_contracts.append(target_contract)
	contract_completed.emit(target_contract)
	contracts_updated.emit()
	
	sync_with_logbook(target_contract)
	return true

## Riscuote la ricompensa di un contratto completato
func claim_contract_reward(contract_id: String) -> Dictionary:
	var target_contract: Dictionary = {}
	
	for c in completed_contracts:
		if str(c.get("id")) == contract_id:
			target_contract = c
			break
			
	if target_contract.is_empty():
		for c in active_contracts:
			if str(c.get("id")) == contract_id and str(c.get("status")) == "COMPLETED":
				target_contract = c
				break
				
	if target_contract.is_empty() or str(target_contract.get("status")) != "COMPLETED":
		return {}
		
	target_contract["status"] = "CLAIMED"
	target_contract["contract_status"] = ContractStatus.CLAIMED
	
	var r_credits: int = int(target_contract.get("reward_credits", 0))
	var r_flux: int = int(target_contract.get("reward_flux", r_credits))
	var r_liquid: int = int(target_contract.get("reward_liquid_flux", r_flux))
	var r_relief: int = int(target_contract.get("reward_debt_relief", 0))
	var target_creditor: String = str(target_contract.get("creditor_relief_target", "ALL"))
	
	# Accredito su FluxEconomyManager
	var flux_mgr = _get_flux_economy_manager()
	var relief_applied: int = 0
	if flux_mgr:
		if flux_mgr.has_method("receive_contract_reward"):
			var res_fem: Dictionary = flux_mgr.receive_contract_reward(target_contract)
			r_liquid = int(res_fem.get("liquid_reward", r_liquid))
			relief_applied = int(res_fem.get("debt_relief_applied", 0))
		else:
			if flux_mgr.has_method("add_liquid_flux"):
				flux_mgr.add_liquid_flux(r_liquid)
			elif "credits" in flux_mgr:
				flux_mgr.credits += r_liquid
			if flux_mgr.has_method("repay_debt") and r_relief > 0:
				relief_applied = flux_mgr.repay_debt(target_creditor, r_relief)
	else:
		var bp = _get_active_ship_blueprint()
		if bp and "flux" in bp:
			bp.flux += r_liquid
		if bp and bp.has_method("repay_rent_debt") and r_relief > 0:
			relief_applied = bp.repay_rent_debt(r_relief)
			
	# Rimuovi da active_contracts
	for i in range(active_contracts.size() - 1, -1, -1):
		if str(active_contracts[i].get("id")) == contract_id:
			active_contracts.remove_at(i)
			break
			
	contract_claimed.emit(target_contract, r_credits, r_flux)
	contracts_updated.emit()
	
	sync_with_logbook(target_contract)
	
	return {
		"success": true,
		"contract": target_contract,
		"credits": r_credits,
		"flux": r_flux,
		"liquid_flux": r_liquid,
		"debt_relief_applied": relief_applied
	}

## Restituisce tutti i contratti con stato COMPLETED (non ancora riscossi)
func get_unclaimed_completed_contracts() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for c in completed_contracts:
		if str(c.get("status")) == "COMPLETED":
			list.append(c)
	for c in active_contracts:
		if str(c.get("status")) == "COMPLETED" and not list.has(c):
			list.append(c)
	return list

## Riscuote in blocco tutti i contratti completati con accredito unificato
func claim_all_completed_contracts() -> Dictionary:
	var to_claim := get_unclaimed_completed_contracts()
	var total_creds: int = 0
	var total_flx: int = 0
	var total_relief: int = 0
	var claimed_list: Array[Dictionary] = []
	
	for c in to_claim:
		var c_id: String = str(c.get("id"))
		var res := claim_contract_reward(c_id)
		if res.get("success", false):
			total_creds += int(res.get("credits", 0))
			total_flx += int(res.get("flux", 0))
			total_relief += int(res.get("debt_relief_applied", 0))
			claimed_list.append(res.get("contract", c))
			
	return {
		"claimed_count": claimed_list.size(),
		"total_credits": total_creds,
		"total_flux": total_flx,
		"total_liquid_flux": total_flx,
		"total_debt_relief": total_relief,
		"claimed_contracts": claimed_list
	}

## Fallisce un contratto attivo
func fail_contract(contract_id: String, reason: String = "") -> bool:
	for i in range(active_contracts.size()):
		if str(active_contracts[i].get("id")) == contract_id:
			var c: Dictionary = active_contracts[i]
			c["status"] = "FAILED"
			c["contract_status"] = ContractStatus.FAILED
			contract_failed.emit(c, reason)
			contracts_updated.emit()
			sync_with_logbook(c)
			active_contracts.remove_at(i)
			return true
	return false

## Notifica distruzione nemico per contratti Bounty
func on_enemy_destroyed(ship_id: String, faction: String, _coords: Vector3 = Vector3.ZERO) -> void:
	for c in active_contracts.duplicate():
		if str(c.get("status")) != "IN_PROGRESS":
			continue
		var ctype: String = str(c.get("type", ""))
		if ctype == "BOUNTY" or c.get("contract_type") == ContractType.BOUNTY:
			var target_id: String = str(c.get("target_entity_id", ""))
			var target_fac: String = str(c.get("target_faction", ""))
			
			var matches_target: bool = (not target_id.is_empty() and target_id == ship_id)
			var matches_faction: bool = (not target_fac.is_empty() and target_fac == faction)
			var generic_pirate_bounty: bool = (faction == "PIRATES" and (target_id.is_empty() or target_id.begins_with("PIRATE_")))
			
			if matches_target or matches_faction or generic_pirate_bounty:
				complete_contract(str(c.get("id")))

## Notifica attracco a stazione per contratti di trasporto
func on_station_docked(station_id: String) -> void:
	for c in active_contracts.duplicate():
		if str(c.get("status")) != "IN_PROGRESS":
			continue
		var ctype: String = str(c.get("type", ""))
		if ctype == "TRANSPORT" or c.get("contract_type") == ContractType.TRANSPORT:
			var dest_id: String = str(c.get("destination_station_id", ""))
			if dest_id == station_id:
				complete_contract(str(c.get("id")))

## Sincronizzazione diegetica con LogbookApp
func sync_with_logbook(contract_data: Dictionary) -> void:
	if not is_inside_tree():
		return
	var logbook_nodes := get_tree().get_nodes_in_group("logbook_app")
	for lb in logbook_nodes:
		if is_instance_valid(lb) and lb.has_method("add_contract"):
			lb.add_contract(contract_data)
			return
			
	var root := get_tree().root
	var lb_node := root.find_child("LogbookApp", true, false)
	if is_instance_valid(lb_node) and lb_node.has_method("add_contract"):
		lb_node.add_contract(contract_data)

## Reset completo dello stato (per test e cambi sessione)
func reset_state() -> void:
	available_contracts.clear()
	active_contracts.clear()
	completed_contracts.clear()
	contracts_updated.emit()

func _get_flux_economy_manager() -> Node:
	if is_inside_tree() and get_tree().root.has_node("FluxEconomyManager"):
		return get_tree().root.get_node("FluxEconomyManager")
	return null

func _get_space_world_manager() -> Node:
	if is_inside_tree() and get_tree().root.has_node("SpaceWorldManager"):
		return get_tree().root.get_node("SpaceWorldManager")
	return null

func _get_active_ship_blueprint() -> Resource:
	var swm := _get_space_world_manager()
	if swm and swm.has_method("get_active_blueprint"):
		var bp = swm.get_active_blueprint()
		if bp:
			return bp
	if ClassDB.class_exists("ShipBlueprint"):
		return ShipBlueprint.get_default_blueprint()
	return null
