class_name CargoManagerSingleton
extends Node

## Gestore Stiva Cargo e Logistica Trasferimenti per Dark Nova: Rogue Squadron.
## Gestisce capacità di massa (kg) e volumetrica (m³), categorizzazione merci,
## prevenzione del sovraccarico e trasferimento bidirezionale tra Corvetta,
## Service Drone e Stazioni Spaziali.

signal cargo_updated(items: Array[Dictionary], total_mass: float, total_vol: float)
signal item_added(item: Dictionary, quantity: int)
signal item_removed(item: Dictionary, quantity: int)
signal overload_prevented(attempted_item: Dictionary, attempted_qty: int, reason: String)
signal transfer_completed(from_source: String, to_target: String, item_id: String, quantity: int)
signal transfer_failed(from_source: String, to_target: String, item_id: String, quantity: int, reason: String)

# Limiti fisici di carico della Corvetta
@export var max_mass_kg: float = 2000.0
@export var max_volume_m3: float = 100.0

# Inventario Stiva
var cargo_items: Array[Dictionary] = []

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
		"description": "Carico illegale non registrato nel manifesto di bordo. Alta remunerazione sul mercato nero."
	}
}

func _ready() -> void:
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
	for item in cargo_items:
		var qty := int(item.get("quantity", 0))
		var unit_mass := float(item.get("unit_mass_kg", 0.0))
		total += qty * unit_mass
	return total

## Restituisce il volume totale attualmente occupato
func get_total_volume() -> float:
	var total: float = 0.0
	for item in cargo_items:
		var qty := int(item.get("quantity", 0))
		var unit_vol := float(item.get("unit_volume_m3", 0.0))
		total += qty * unit_vol
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

## Aggiunge un item generico tramite dizionario completo
func add_item(item_data: Dictionary, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	
	var unit_mass := float(item_data.get("unit_mass_kg", 1.0))
	var unit_vol := float(item_data.get("unit_volume_m3", 0.1))
	var item_id := str(item_data.get("id", "unknown_item"))
	
	if not can_fit(unit_mass, unit_vol, quantity):
		var reason := "Capacità massima superata (Richiesti: %.1f kg / %.1f m³ - Disponibili: %.1f kg / %.1f m³)" % [
			unit_mass * quantity, unit_vol * quantity, get_free_mass(), get_free_volume()
		]
		overload_prevented.emit(item_data, quantity, reason)
		return false
	
	# Cerca se l'item esiste già (se non è un disco dati con metadata unici)
	var is_snet := bool(item_data.get("is_snet_disk", false))
	var existing_idx := -1
	if not is_snet:
		for i in range(cargo_items.size()):
			if cargo_items[i].get("id", "") == item_id:
				existing_idx = i
				break
	
	if existing_idx != -1:
		cargo_items[existing_idx]["quantity"] = int(cargo_items[existing_idx].get("quantity", 0)) + quantity
		item_added.emit(cargo_items[existing_idx], quantity)
	else:
		var new_item := item_data.duplicate(true)
		new_item["quantity"] = quantity
		cargo_items.append(new_item)
		item_added.emit(new_item, quantity)
	
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
func remove_item(item_id: String, quantity: int = 1) -> Dictionary:
	if quantity <= 0:
		return {}
	
	for i in range(cargo_items.size()):
		if cargo_items[i].get("id", "") == item_id:
			var current_qty := int(cargo_items[i].get("quantity", 0))
			var removed_qty := mini(current_qty, quantity)
			var removed_item := cargo_items[i].duplicate(true)
			removed_item["quantity"] = removed_qty
			
			if current_qty <= quantity:
				cargo_items.remove_at(i)
			else:
				cargo_items[i]["quantity"] = current_qty - removed_qty
			
			item_removed.emit(removed_item, removed_qty)
			cargo_updated.emit(cargo_items, get_total_mass(), get_total_volume())
			return removed_item
	
	return {}

## Verifica presenza item
func has_item(item_id: String, quantity: int = 1) -> bool:
	for item in cargo_items:
		if item.get("id", "") == item_id:
			return int(item.get("quantity", 0)) >= quantity
	return false

## Recupera item per id
func get_item(item_id: String) -> Dictionary:
	for item in cargo_items:
		if item.get("id", "") == item_id:
			return item
	return {}

## Recupera tutti gli item presenti
func get_cargo_list() -> Array[Dictionary]:
	return cargo_items

## Svuota completamente la stiva
func clear_cargo() -> void:
	cargo_items.clear()
	cargo_updated.emit(cargo_items, 0.0, 0.0)

# ==============================================================================
# TRASFERIMENTO BIDIREZIONALE (NAVE <-> SERVICE DRONE <-> STAZIONE)
# ==============================================================================

## Trasferisce merce dalla stiva nave al Service Drone
func transfer_to_drone(item_id: String, quantity: int = 1, drone = null) -> bool:
	if not has_item(item_id, quantity):
		transfer_failed.emit("ship", "drone", item_id, quantity, "Articolo non presente o quantità insufficiente nella stiva.")
		return false
	
	var item := get_item(item_id)
	var unit_mass := float(item.get("unit_mass_kg", 1.0))
	var item_name := str(item.get("name", item_id))
	var total_transfer_mass := unit_mass * float(quantity)
	
	# Se il drone è fornito o reperibile
	if drone != null and is_instance_valid(drone):
		var cur_weight: float = float(drone.get("cargo_weight_kg") if "cargo_weight_kg" in drone else 0.0)
		var cap_weight: float = float(drone.get("cargo_capacity_kg") if "cargo_capacity_kg" in drone else 500.0)
		if cur_weight + total_transfer_mass > cap_weight:
			transfer_failed.emit("ship", "drone", item_id, quantity, "Capacità di carico del Service Drone esaurita.")
			return false
		
		# Aggiunge al drone
		if drone.has_method("collect_cargo_item"):
			drone.collect_cargo_item(item_id, item_name, total_transfer_mass)
		elif "cargo_items" in drone:
			var d_item = item.duplicate(true)
			d_item["quantity"] = quantity
			drone.cargo_items.append(d_item)
			if "cargo_weight_kg" in drone:
				drone.cargo_weight_kg += total_transfer_mass
	
	remove_item(item_id, quantity)
	transfer_completed.emit("ship", "drone", item_id, quantity)
	return true

## Trasferisce merce dal Service Drone alla stiva nave
func transfer_from_drone(item_id: String, quantity: int = 1, drone = null) -> bool:
	var item_to_add: Dictionary = {}
	var unit_mass: float = 10.0
	var unit_vol: float = 0.2
	
	if drone != null and is_instance_valid(drone):
		var found_idx := -1
		if "cargo_items" in drone:
			for i in range(drone.cargo_items.size()):
				if drone.cargo_items[i].get("id", "") == item_id:
					found_idx = i
					item_to_add = drone.cargo_items[i].duplicate(true)
					break
		
		if found_idx == -1:
			transfer_failed.emit("drone", "ship", item_id, quantity, "Item non trovato nel cargo del drone.")
			return false
		
		unit_mass = float(item_to_add.get("unit_mass_kg", item_to_add.get("weight_kg", 10.0) / float(quantity if quantity > 0 else 1)))
		unit_vol = float(item_to_add.get("unit_volume_m3", 0.2))
		
		if not can_fit(unit_mass, unit_vol, quantity):
			transfer_failed.emit("drone", "ship", item_id, quantity, "Spazio insufficiente nella stiva della corvetta.")
			return false
		
		# Rimuove dal drone
		if drone.has_method("drop_cargo_item"):
			drone.drop_cargo_item(found_idx)
		elif "cargo_items" in drone:
			drone.cargo_items.remove_at(found_idx)
			if "cargo_weight_kg" in drone:
				drone.cargo_weight_kg = maxf(0.0, drone.cargo_weight_kg - (unit_mass * quantity))
	else:
		# Fallback da catalogo
		if item_templates.has(item_id):
			item_to_add = item_templates[item_id].duplicate(true)
			unit_mass = float(item_to_add.get("unit_mass_kg", 10.0))
			unit_vol = float(item_to_add.get("unit_volume_m3", 0.2))
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
func transfer_to_station(item_id: String, quantity: int = 1, station = null) -> bool:
	if not has_item(item_id, quantity):
		transfer_failed.emit("ship", "station", item_id, quantity, "Quantità insufficiente nella stiva per il deposito.")
		return false
	
	var removed := remove_item(item_id, quantity)
	if station != null and is_instance_valid(station):
		if "warehouse_cargo" in station:
			station.warehouse_cargo.append(removed)
	
	transfer_completed.emit("ship", "station", item_id, quantity)
	return true

## Trasferisce merce dal magazzino stazione alla stiva nave
func transfer_from_station(item_id: String, quantity: int = 1, station = null) -> bool:
	var item_to_add: Dictionary = {}
	if item_templates.has(item_id):
		item_to_add = item_templates[item_id].duplicate(true)
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
	
	var unit_mass := float(item_to_add.get("unit_mass_kg", 15.0))
	var unit_vol := float(item_to_add.get("unit_volume_m3", 0.3))
	
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
