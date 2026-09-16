class_name CargoManagerSingleton
extends Node

## Gestore Stiva Cargo e Logistica Trasferimenti per Dark Nova: Rogue Squadron.
## Gestisce capacità di massa (kg) e volumetrica (m³), categorizzazione merci,
## prevenzione del sovraccarico e trasferimento bidirezionale tra Corvetta,
## Service Drone e Stazioni Spaziali.

signal cargo_updated(items: Array[CargoItemData], total_mass: float, total_vol: float)
signal item_added(item: CargoItemData, quantity: int)
signal item_removed(item: CargoItemData, quantity: int)
signal overload_prevented(attempted_item: Variant, attempted_qty: int, reason: String)
signal transfer_completed(from_source: String, to_target: String, item_id: String, quantity: int)
signal transfer_failed(from_source: String, to_target: String, item_id: String, quantity: int, reason: String)

# Limiti fisici di carico della Corvetta
@export var max_mass_kg: float = 2000.0
@export var max_volume_m3: float = 100.0

# Inventario Stiva
var cargo_items: Array[CargoItemData] = []

# Catalogo standard di merci spaziali
var item_templates: Dictionary = {
	"minerals_titanium": {
		"id": "minerals_titanium",
		"name": "Titanio Grezzo",
		"category": "MINERAL",
		"unit_mass_kg": 25.0,
		"unit_volume_m3": 0.8,
		"unit_base_value": 120.0,
		"is_contraband": false,
		"is_snet_disk": false,
		"description": "Minerali di titanio grezzo estratti da asteroidi di classe C."
	},
	"alloys_durasteel": {
		"id": "alloys_durasteel",
		"name": "Leghe Raffinate Durasteel",
		"category": "ALLOY",
		"unit_mass_kg": 40.0,
		"unit_volume_m3": 0.5,
		"unit_base_value": 350.0,
		"is_contraband": false,
		"is_snet_disk": false,
		"description": "Lingotti compositi ad altissima densità per corazzature e cantieri navali."
	},
	"ammo_railgun": {
		"id": "ammo_railgun",
		"name": "Munizioni Sabot Railgun",
		"category": "AMMO",
		"unit_mass_kg": 15.0,
		"unit_volume_m3": 0.2,
		"unit_base_value": 220.0,
		"is_contraband": false,
		"is_snet_disk": false,
		"description": "Proiettili cinetici al tungsteno-uranio per torrette pesanti."
	},
	"energy_cell": {
		"id": "energy_cell",
		"name": "Celle Energetiche al Plasma",
		"category": "ENERGY_CELL",
		"unit_mass_kg": 10.0,
		"unit_volume_m3": 0.3,
		"unit_base_value": 180.0,
		"is_contraband": false,
		"is_snet_disk": false,
		"description": "Condensatori al plasma ad alta densità per ricarica sublayer e scudi."
	},
	"snet_snapshot_alpha": {
		"id": "snet_snapshot_alpha",
		"name": "Array Snapshot Rete S-Net",
		"category": "SNET_DISK",
		"unit_mass_kg": 5.0,
		"unit_volume_m3": 0.1,
		"unit_base_value": 1800.0,
		"is_contraband": false,
		"is_snet_disk": true,
		"description": "Storage diegetico fisico contenente snapshot finanziari e listini di settore.",
		"metadata": {
			"ice_strength": 3,
			"ice_broken": false,
			"sector": "Theta-9",
			"financial_snapshot": 2500,
			"market_intel": "Domanda record per leghe durasteel nel settore Aegis."
		}
	},
	"contraband_synth_narcotics": {
		"id": "contraband_synth_narcotics",
		"name": "Narcotici Sintetici Sigillati",
		"category": "CONTRABAND",
		"unit_mass_kg": 8.0,
		"unit_volume_m3": 0.2,
		"unit_base_value": 1100.0,
		"is_contraband": true,
		"is_snet_disk": false,
		"is_scavenged": false,
		"description": "Carico illegale non registrato nel manifesto di bordo. Alta remunerazione sul mercato nero."
	},
	"salvaged_hull_plating": {
		"id": "salvaged_hull_plating",
		"name": "Pannelli di Corazza Recuperati",
		"category": "WRECK_COMPONENT",
		"unit_mass_kg": 35.0,
		"unit_volume_m3": 0.6,
		"unit_base_value": 280.0,
		"is_contraband": false,
		"is_snet_disk": false,
		"is_scavenged": true,
		"description": "Frammenti di scafo corazzato recuperati da un relitto orbitale."
	},
	"alien_relic_fragment": {
		"id": "alien_relic_fragment",
		"name": "Frammento Reliquia Precursore",
		"category": "SCAVENGED",
		"unit_mass_kg": 12.0,
		"unit_volume_m3": 0.3,
		"unit_base_value": 950.0,
		"is_contraband": false,
		"is_snet_disk": false,
		"is_scavenged": true,
		"description": "Manufatto alieno ad alta energia rinvenuto tra i detriti spaziali."
	},
	"derelict_avionics_core": {
		"id": "derelict_avionics_core",
		"name": "Nucleo Avionica di Relitto",
		"category": "WRECK_COMPONENT",
		"unit_mass_kg": 18.0,
		"unit_volume_m3": 0.4,
		"unit_base_value": 520.0,
		"is_contraband": false,
		"is_snet_disk": false,
		"is_scavenged": true,
		"description": "Unità computazionale intatta estratta da una nave alla deriva."
	},
	"durasteel_ore": {
		"id": "durasteel_ore",
		"name": "Minerale Grezzo Durasteel",
		"category": "MINERAL",
		"unit_mass_kg": 40.0,
		"unit_volume_m3": 0.5,
		"unit_base_value": 220.0,
		"is_contraband": false,
		"is_snet_disk": false,
		"is_scavenged": false,
		"description": "Minerale metallico denso estratto da asteroidi profondi, base per leghe corazzate."
	},
	"titanium_raw": {
		"id": "titanium_raw",
		"name": "Titanio Grezzo Purificato",
		"category": "MINERAL",
		"unit_mass_kg": 45.0,
		"unit_volume_m3": 0.6,
		"unit_base_value": 320.0,
		"is_contraband": false,
		"is_snet_disk": false,
		"is_scavenged": false,
		"description": "Titanio spaziale ad alta resistenza strutturale, molto richiesto dai cantieri navali."
	},
	"exocrystal_shard": {
		"id": "exocrystal_shard",
		"name": "Frammento Cristallo Esotico",
		"category": "MINERAL",
		"unit_mass_kg": 15.0,
		"unit_volume_m3": 0.3,
		"unit_base_value": 550.0,
		"is_contraband": false,
		"is_snet_disk": false,
		"is_scavenged": false,
		"description": "Cristallo con risonanza FLUX estratto dal nucleo di asteroidi rari. Alto valore energetico.",
		"metadata": {
			"flux_potential": 8.0
		}
	},
	"water_ice_block": {
		"id": "water_ice_block",
		"name": "Blocco Ghiaccio d'Acqua",
		"category": "MINERAL",
		"unit_mass_kg": 30.0,
		"unit_volume_m3": 0.5,
		"unit_base_value": 180.0,
		"is_contraband": false,
		"is_snet_disk": false,
		"is_scavenged": false,
		"description": "Ghiaccio d'acqua purificabile per rifornire le riserve vitali di Life Support.",
		"metadata": {
			"water_yield_units": 35.0
		}
	}
}

func _ready() -> void:
	add_to_group("cargo_managers")
	if cargo_items.is_empty():
		_init_default_manifest()

## Inizializza carico predefinito di test / inizio partita
func _init_default_manifest() -> void:
	add_item_by_id("energy_cell", 4)
	add_item_by_id("ammo_railgun", 6)
	add_item_by_id("alloys_durasteel", 2)
	add_item_by_id("snet_snapshot_alpha", 1)

## Restituisce la massa totale attualmente occupata
func get_total_mass() -> float:
	var total: float = 0.0
	for item: CargoItemData in cargo_items:
		total += item.get_total_mass()
	return total

## Restituisce il volume totale attualmente occupato
func get_total_volume() -> float:
	var total: float = 0.0
	for item: CargoItemData in cargo_items:
		total += item.get_total_volume()
	return total

## Spazio residuo in kg
func get_free_mass() -> float:
	return maxf(0.0, max_mass_kg - get_total_mass())

## Spazio residuo in m³
func get_free_volume() -> float:
	return maxf(0.0, max_volume_m3 - get_total_volume())

## Verifica se una data quantità di merce può entrare nella stiva senza sovraccarico
func can_fit(unit_mass: float, unit_volume: float, quantity: int) -> bool:
	if quantity <= 0:
		return true
	var req_mass := unit_mass * float(quantity)
	var req_vol := unit_volume * float(quantity)
	return (get_total_mass() + req_mass <= max_mass_kg) and (get_total_volume() + req_vol <= max_volume_m3)

## Aggiunge un item generico tramite oggetto o dizionario completo
func add_item(p_item: Variant, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	
	var item: CargoItemData = null
	if p_item is CargoItemData:
		item = p_item
	elif p_item is Dictionary:
		item = CargoItemData.new()
		item.from_dict(p_item)
	
	if not item: return false
	
	var unit_mass := float(item.unit_mass_kg)
	var unit_vol := float(item.unit_volume_m3)
	var item_id := str(item.id)
	
	if not can_fit(unit_mass, unit_vol, quantity):
		var reason := "Capacità massima superata (Richiesti: %.1f kg / %.1f m³ - Disponibili: %.1f kg / %.1f m³)" % [
			unit_mass * quantity, unit_vol * quantity, get_free_mass(), get_free_volume()
		]
		overload_prevented.emit(item, quantity, reason)
		return false
	
	# Cerca se l'item esiste già (se non è un disco dati con metadata unici)
	var is_snet := bool(item.is_snet_disk)
	var is_scav := bool(item.is_scavenged)
	var existing_item: CargoItemData = null
	if not is_snet:
		for i: CargoItemData in cargo_items:
			if i.id == item_id and bool(i.is_scavenged) == is_scav:
				existing_item = i
				break
	
	if existing_item:
		existing_item.quantity += quantity
		item_added.emit(existing_item, quantity)
	else:
		item.quantity = quantity
		cargo_items.append(item)
		item_added.emit(item, quantity)
	
	cargo_updated.emit(cargo_items, get_total_mass(), get_total_volume())
	return true

## Aggiunge un item dal catalogo templates
func add_item_by_id(item_id: String, quantity: int = 1, metadata_override: Dictionary = {}) -> bool:
	if not item_templates.has(item_id):
		# Fallback se non censito
		var generic := {
			"id": item_id,
			"name": item_id.capitalize(),
			"category": "GENERAL",
			"unit_mass_kg": 10.0,
			"unit_volume_m3": 0.2,
			"unit_base_value": 100.0,
			"is_contraband": false,
			"is_snet_disk": false
		}
		if not metadata_override.is_empty():
			generic["metadata"] = metadata_override
		return add_item(generic, quantity)
	
	var item_dict: Dictionary = item_templates[item_id].duplicate(true)
	if not metadata_override.is_empty():
		if not item_dict.has("metadata"):
			item_dict["metadata"] = {}
		for k in metadata_override:
			item_dict["metadata"][k] = metadata_override[k]
	
	return add_item(item_dict, quantity)

## Rimuove una determinata quantità di un item dalla stiva
func remove_item(item_id: String, quantity: int = 1) -> CargoItemData:
	if quantity <= 0:
		return null
	
	for i: int in range(cargo_items.size()):
		if cargo_items[i].id == item_id:
			var current_qty := int(cargo_items[i].quantity)
			var removed_qty := mini(current_qty, quantity)
			
			var removed_item := CargoItemData.new()
			removed_item.from_dict(cargo_items[i].to_dict())
			removed_item.quantity = removed_qty
			
			if current_qty <= quantity:
				cargo_items.remove_at(i)
			else:
				cargo_items[i].quantity = current_qty - removed_qty
			
			item_removed.emit(removed_item, removed_qty)
			cargo_updated.emit(cargo_items, get_total_mass(), get_total_volume())
			return removed_item
	
	return null

## Verifica presenza item
func has_item(item_id: String, quantity: int = 1) -> bool:
	for item: CargoItemData in cargo_items:
		if item.id == item_id:
			return item.quantity >= quantity
	return false

## Restituisce la quantità presente di un dato item
func get_item_quantity(item_id: String) -> int:
	for item: CargoItemData in cargo_items:
		if item.id == item_id:
			return item.quantity
	return 0

## Recupera item per id
func get_item(item_id: String) -> CargoItemData:
	for item: CargoItemData in cargo_items:
		if item.id == item_id:
			return item
	return null

## Recupera tutti gli item presenti
func get_cargo_list() -> Array[CargoItemData]:
	return cargo_items

## Svuota completamente la stiva
func clear_cargo() -> void:
	cargo_items.clear()
	cargo_updated.emit(cargo_items, 0.0, 0.0)

## Restituisce tutti gli item contrassegnati come bottino recuperato/scavenged
func get_scavenged_items() -> Array[CargoItemData]:
	var scavenged: Array[CargoItemData] = []
	for item in cargo_items:
		if bool(item.is_scavenged) or item.category in ["SCAVENGED", "WRECK_COMPONENT", "SALVAGE"]:
			scavenged.append(item)
	return scavenged

## Calcola il valore totale stimato del bottino di scavenging
func calculate_scavenged_value(multiplier: float = 1.0) -> Dictionary:
	var total_credits: float = 0.0
	var total_flux: float = 0.0
	var total_count: int = 0
	var total_mass: float = 0.0
	var total_vol: float = 0.0
	
	for item in get_scavenged_items():
		var item_credits: float = item.unit_base_value * float(item.quantity) * multiplier
		total_credits += item_credits
		total_count += item.quantity
		total_mass += item.get_total_mass()
		total_vol += item.get_total_volume()
		if item.metadata.has("flux_potential"):
			total_flux += float(item.metadata["flux_potential"]) * float(item.quantity)
		elif item.category in ["WRECK_COMPONENT", "SALVAGE"]:
			total_flux += float(item.quantity) * 5.0
			
	return {
		"credits": total_credits,
		"flux": total_flux,
		"item_count": total_count,
		"mass_kg": total_mass,
		"volume_m3": total_vol
	}

var flux_mgr_ref: Node = null

func bind_flux_manager(fm: Node) -> void:
	flux_mgr_ref = fm

func _get_flux_manager() -> Node:
	if flux_mgr_ref and is_instance_valid(flux_mgr_ref):
		return flux_mgr_ref
	if is_inside_tree():
		var nodes = get_tree().get_nodes_in_group("flux_managers")
		if not nodes.is_empty():
			return nodes[0]
		if get_tree().root.has_node("FluxEconomyManager"):
			return get_tree().root.get_node("FluxEconomyManager")
	return null

## Liquida istantaneamente tutto il bottino di scavenging, rimuovendolo dalla stiva
func liquidate_scavenged_items(multiplier: float = 1.0, destination: String = "LIQUID", target_debt_owner: String = "Ship Rent Service") -> Dictionary:
	var scav_items := get_scavenged_items()
	if scav_items.is_empty():
		return {
			"liquidated_count": 0,
			"credits_earned": 0.0,
			"flux_earned": 0.0,
			"debt_relief_applied": 0,
			"mass_freed": 0.0,
			"volume_freed": 0.0,
			"removed_items": []
		}
		
	var summary := calculate_scavenged_value(multiplier)
	var removed_items: Array[Dictionary] = []
	
	for item in scav_items:
		var removed := remove_item(item.id, item.quantity)
		if removed:
			removed_items.append(removed.to_dict())
			
	# Accredito all'economia di bordo se presenti i singleton
	var total_creds := int(round(summary.get("credits", 0.0)))
	var total_flux := int(round(summary.get("flux", 0.0)))
	var total_value: int = maxi(total_creds, total_flux)
	var relief_applied: int = 0
	
	var flux_mgr := _get_flux_manager()
	if destination == "DEBT_RELIEF" or destination == "RENT":
		if flux_mgr and flux_mgr.has_method("apply_debt_relief"):
			relief_applied = flux_mgr.apply_debt_relief(target_debt_owner, total_value)
		elif flux_mgr and flux_mgr.has_method("repay_debt"):
			relief_applied = flux_mgr.repay_debt(target_debt_owner, total_value)
		else:
			var bp = get_node_or_null("/root/ShipBlueprint")
			if not bp and is_inside_tree():
				var bps = get_tree().get_nodes_in_group("ship_blueprints")
				if not bps.is_empty():
					bp = bps[0]
			if bp and bp.has_method("repay_rent_debt"):
				relief_applied = bp.repay_rent_debt(total_value)
	else:
		if flux_mgr:
			if flux_mgr.has_method("add_liquid_flux"):
				flux_mgr.add_liquid_flux(total_value)
			elif "credits" in flux_mgr:
				flux_mgr.credits += total_value
			if flux_mgr.has_method("add_transaction"):
				flux_mgr.add_transaction(float(total_value), true, true, "Vendita in blocco bottino scavenging")
		else:
			var bp = get_node_or_null("/root/ShipBlueprint")
			if not bp and is_inside_tree():
				var bps = get_tree().get_nodes_in_group("ship_blueprints")
				if not bps.is_empty():
					bp = bps[0]
			if bp and "flux" in bp:
				bp.flux += total_value
				
	cargo_updated.emit(cargo_items, get_total_mass(), get_total_volume())
	
	return {
		"liquidated_count": summary.get("item_count", 0),
		"credits_earned": float(total_value),
		"flux_earned": float(total_value),
		"debt_relief_applied": relief_applied,
		"mass_freed": summary.get("mass_kg", 0.0),
		"volume_freed": summary.get("volume_m3", 0.0),
		"removed_items": removed_items
	}

## Converte uno o più blocchi di ghiaccio in riserva idrica vitale per il sistema di supporto vitale
func convert_ice_to_life_support(quantity: int = 1) -> Dictionary:
	if quantity <= 0:
		return {"success": false, "water_units_produced": 0.0, "converted_count": 0}
		
	var ice_item := get_item("water_ice_block")
	if ice_item == null or ice_item.quantity <= 0:
		return {"success": false, "water_units_produced": 0.0, "converted_count": 0, "reason": "Nessun blocco di ghiaccio in stiva"}
		
	var to_convert: int = mini(quantity, ice_item.quantity)
	var removed := remove_item("water_ice_block", to_convert)
	if removed == null:
		return {"success": false, "water_units_produced": 0.0, "converted_count": 0}
		
	var yield_per_block: float = 35.0
	if removed.metadata.has("water_yield_units"):
		yield_per_block = float(removed.metadata["water_yield_units"])
	var total_water := yield_per_block * float(to_convert)
	
	if is_inside_tree():
		if SpaceWorldManager and SpaceWorldManager.has_signal("life_support_resource_replenished"):
			SpaceWorldManager.life_support_resource_replenished.emit("water", total_water)
		var life_support_nodes := get_tree().get_nodes_in_group("life_support_systems")
		for ls in life_support_nodes:
			if ls.has_method("add_water_reserve"):
				ls.add_water_reserve(total_water)
				
	return {
		"success": true,
		"converted_count": to_convert,
		"water_units_produced": total_water,
		"mass_freed": removed.unit_mass_kg * float(to_convert)
	}

# ==============================================================================
# TRASFERIMENTO BIDIREZIONALE (NAVE <-> SERVICE DRONE <-> STAZIONE)
# ==============================================================================

## Trasferisce merce dalla stiva nave al Service Drone
func transfer_to_drone(item_id: String, quantity: int = 1, drone: Node = null) -> bool:
	if not has_item(item_id, quantity):
		transfer_failed.emit("ship", "drone", item_id, quantity, "Articolo non presente o quantità insufficiente nella stiva.")
		return false
	
	var item := get_item(item_id)
	if not item: return false
	var unit_mass := float(item.unit_mass_kg)
	var item_name := str(item.name)
	var total_transfer_mass := unit_mass * float(quantity)
	
	# Se il drone è fornito o reperibile
	if drone != null and is_instance_valid(drone):
		var cur_weight := float(drone.get("cargo_weight_kg") if "cargo_weight_kg" in drone else 0.0)
		var cap_weight := float(drone.get("cargo_capacity_kg") if "cargo_capacity_kg" in drone else 500.0)
		if cur_weight + total_transfer_mass > cap_weight:
			transfer_failed.emit("ship", "drone", item_id, quantity, "Capacità di carico del Service Drone esaurita.")
			return false
		
		# Aggiunge al drone
		if drone.has_method("collect_cargo_item"):
			drone.call("collect_cargo_item", item_id, item_name, total_transfer_mass)
		elif "cargo_items" in drone:
			var d_item := item.to_dict()
			d_item["quantity"] = quantity
			(drone.get("cargo_items") as Array).append(d_item)
			if "cargo_weight_kg" in drone:
				drone.set("cargo_weight_kg", cur_weight + total_transfer_mass)
	
	remove_item(item_id, quantity)
	transfer_completed.emit("ship", "drone", item_id, quantity)
	return true

## Trasferisce merce dal Service Drone alla stiva nave
func transfer_from_drone(item_id: String, quantity: int = 1, drone: Node = null) -> bool:
	var item_to_add: Variant = null
	var unit_mass: float = 10.0
	var unit_vol: float = 0.2
	
	if drone != null and is_instance_valid(drone):
		var found_idx := -1
		if "cargo_items" in drone:
			var d_cargo: Variant = drone.get("cargo_items") as Array
			for i: int in range(d_cargo.size()):
				if d_cargo[i].get("id") == item_id:
					found_idx = i
					item_to_add = d_cargo[i].duplicate(true)
					break
		
		if found_idx == -1:
			transfer_failed.emit("drone", "ship", item_id, quantity, "Item non trovato nel cargo del drone.")
			return false
		
		var tpl: Dictionary = item_templates[item_id] if item_templates.has(item_id) else {}
		var raw_mass = item_to_add.get("unit_mass_kg") if item_to_add is Dictionary else (item_to_add.unit_mass_kg if item_to_add != null else null)
		var raw_vol = item_to_add.get("unit_volume_m3") if item_to_add is Dictionary else (item_to_add.unit_volume_m3 if item_to_add != null else null)
		
		if raw_mass != null:
			unit_mass = float(raw_mass)
		elif tpl.has("unit_mass_kg"):
			unit_mass = float(tpl["unit_mass_kg"])
		elif item_to_add is Dictionary and item_to_add.has("weight_kg"):
			unit_mass = float(item_to_add["weight_kg"]) / maxf(1.0, float(quantity))
		else:
			unit_mass = 10.0
		
		if raw_vol != null:
			unit_vol = float(raw_vol)
		elif tpl.has("unit_volume_m3"):
			unit_vol = float(tpl["unit_volume_m3"])
		else:
			unit_vol = 0.2
		
		if item_templates.has(item_id):
			item_to_add = item_templates[item_id].duplicate(true)
		
		if not can_fit(unit_mass, unit_vol, quantity):
			transfer_failed.emit("drone", "ship", item_id, quantity, "Spazio insufficiente nella stiva della corvetta.")
			return false
		
		# Rimuove dal drone
		if drone.has_method("drop_cargo_item"):
			drone.call("drop_cargo_item", found_idx)
		elif "cargo_items" in drone:
			(drone.get("cargo_items") as Array).remove_at(found_idx)
			if "cargo_weight_kg" in drone:
				drone.set("cargo_weight_kg", maxf(0.0, float(drone.get("cargo_weight_kg")) - (unit_mass * float(quantity))))
	else:
		# Fallback da catalogo
		if item_templates.has(item_id):
			item_to_add = item_templates[item_id].duplicate(true)
			unit_mass = float(item_to_add.get("unit_mass_kg"))
			unit_vol = float(item_to_add.get("unit_volume_m3"))
		else:
			item_to_add = {
				"id": item_id,
				"name": item_id.capitalize(),
				"unit_mass_kg": 10.0,
				"unit_volume_m3": 0.2
			}
		
		if not can_fit(unit_mass, unit_vol, quantity):
			transfer_failed.emit("drone", "ship", item_id, quantity, "Spazio insufficiente nella stiva della corvetta.")
			return false

	add_item(item_to_add, quantity)
	transfer_completed.emit("drone", "ship", item_id, quantity)
	return true

## Trasferisce merce dalla stiva nave al magazzino stazione
func transfer_to_station(item_id: String, quantity: int = 1, station: Node = null) -> bool:
	if not has_item(item_id, quantity):
		transfer_failed.emit("ship", "station", item_id, quantity, "Quantità insufficiente nella stiva per il deposito.")
		return false
	
	var removed := remove_item(item_id, quantity)
	if station != null and is_instance_valid(station):
		if "warehouse_cargo" in station and station.warehouse_cargo is Array:
			var w_item: Dictionary = removed.to_dict() if removed != null else {}
			station.warehouse_cargo.append(w_item)
	
	transfer_completed.emit("ship", "station", item_id, quantity)
	return true

## Trasferisce merce dal magazzino stazione alla stiva nave
func transfer_from_station(item_id: String, quantity: int = 1, station: Node = null) -> bool:
	var item_to_add: Variant = null
	if item_templates.has(item_id):
		item_to_add = item_templates[item_id]
	else:
		item_to_add = {
			"id": item_id,
			"name": item_id.capitalize(),
			"unit_mass_kg": 15.0,
			"unit_volume_m3": 0.3,
			"unit_base_value": 200.0,
			"is_contraband": false,
			"is_snet_disk": false
		}
	
	var unit_mass := float(item_to_add.get("unit_mass_kg") if item_to_add is Dictionary else item_to_add.unit_mass_kg)
	var unit_vol := float(item_to_add.get("unit_volume_m3", 0.3) if item_to_add is Dictionary else item_to_add.unit_volume_m3)
	
	if not can_fit(unit_mass, unit_vol, quantity):
		transfer_failed.emit("station", "ship", item_id, quantity, "Capacità massima della stiva superata.")
		return false
	
	if station != null and is_instance_valid(station):
		if "warehouse_cargo" in station and station.warehouse_cargo is Array:
			for i in range(station.warehouse_cargo.size()):
				if station.warehouse_cargo[i].get("id", "") == item_id:
					station.warehouse_cargo.remove_at(i)
					break
	
	add_item(item_to_add, quantity)
	transfer_completed.emit("station", "ship", item_id, quantity)
	return true
