class_name DerelictShipEntity
extends StaticBody3D

## Rappresenta un relitto spaziale abbandonato esplorabile e scassinabile.
## Include serrature con residui ICE (Hacker), paratie tagliabili da laser (Drone),
## condotti interni accessibili (Duct Drone) e loot riscattabile (Moduli, Black Box, FLUX, Crediti).

signal bulkhead_breached(bulkhead_id: String)
signal ice_hacked(success: bool)
signal loot_scavenged(item_data: Dictionary)
signal derelict_fully_salvaged()

@export var derelict_id: String = "derelict_alpha"
@export var ship_name: String = "Relitto Cargo 'Nostromo-IV'"
@export var ship_class: String = "Freighter" # Freighter, Corvette, Gunship, ScienceVessel

# Sicurezza & ICE
@export var ice_locked: bool = true
@export var ice_security_level: int = 2 # 1=Easy, 2=Medium, 3=Hard, 4=Military
@export var ice_health: float = 100.0
@export var ice_type: String = "STANDARD_MILITARY" # BLIZZARD, TARPIT, SENTRY, STANDARD_MILITARY

# Paratie e Struttura
@export var bulkhead_intact: bool = true
@export var bulkhead_hp: float = 150.0
@export var bulkhead_max_hp: float = 150.0
@export var requires_laser_cutting: bool = true

# Accessibilità condotti interni (Duct Drone)
@export var duct_accessible: bool = true
@export var duct_hazards_cleared: bool = false

# Contenuto Scavenging (Moduli, Scatola Nera, Valuta)
@export var credits_contained: int = 1200
@export var flux_contained: float = 25.0
@export var black_box_recovered: bool = false
@export var black_box_data: Dictionary = {
	"flight_log": "Registrazione volo: Sovraccarico del reattore in settore Deep Void.",
	"encryption": "AES-256",
	"value_credits": 800
}

@export var salvageable_modules: Array[Dictionary] = [
	{
		"id": "avionics_core_mk2",
		"name": "Nucleo Avionico Danneggiato Mk II",
		"type": "MODULE",
		"mass_kg": 45.0,
		"volume_m3": 1.2,
		"condition": 0.65,
		"value_credits": 950,
		"flux_yield": 4.0
	},
	{
		"id": "nav_computer_subsystem",
		"name": "Sottosistema Computer di Navigazione",
		"type": "COMPONENT",
		"mass_kg": 20.0,
		"volume_m3": 0.8,
		"condition": 0.80,
		"value_credits": 600,
		"flux_yield": 2.5
	}
]

var _is_fully_scavenged: bool = false

func _ready() -> void:
	add_to_group("derelicts")
	add_to_group("scannable_entities")

## Ritorna dati diagnostici/spettrometrici per Sensori
func get_sensor_scan_data() -> Dictionary:
	return {
		"id": derelict_id,
		"name": ship_name,
		"class": ship_class,
		"ice_locked": ice_locked,
		"ice_security_level": ice_security_level,
		"ice_health": ice_health,
		"bulkhead_intact": bulkhead_intact,
		"bulkhead_hp": bulkhead_hp,
		"duct_accessible": duct_accessible,
		"estimated_salvage_value": _calculate_estimated_value(),
		"is_fully_scavenged": _is_fully_scavenged
	}

func _calculate_estimated_value() -> int:
	var total: int = credits_contained
	if not black_box_recovered:
		total += black_box_data.get("value_credits", 0)
	for mod in salvageable_modules:
		total += int(mod.get("value_credits", 0))
	return total

## Taglio laser applicato alle paratie esterne da parte del Service Drone
func apply_laser_cutting(damage: float) -> bool:
	if not bulkhead_intact:
		return true # Già aperta
	bulkhead_hp -= damage
	if bulkhead_hp <= 0.0:
		bulkhead_hp = 0.0
		bulkhead_intact = false
		bulkhead_breached.emit(derelict_id)
		return true
	return false

## Tentativo di violazione ICE da parte dell'Hacker
func hack_ice_subsystem(hacker_skill_or_tool_level: int = 2, bypass_code: String = "") -> bool:
	if not ice_locked:
		return true # Già sbloccato

	# Se viene fornito bypass code corretto o se il livello hacker è >= ice_security_level
	if bypass_code == "ICE_OVERRIDE_ROOT" or hacker_skill_or_tool_level >= ice_security_level:
		ice_locked = false
		ice_health = 0.0
		ice_hacked.emit(true)
		return true
	
	# Fallimento hacking o violazione parziale
	ice_health = max(0.0, ice_health - (hacker_skill_or_tool_level * 30.0))
	if ice_health <= 0.0:
		ice_locked = false
		ice_hacked.emit(true)
		return true

	ice_hacked.emit(false)
	return false

## Infiltrazione condotti tramite Duct Drone
func infiltrate_ducts(duct_drone: Node = null) -> Dictionary:
	if not duct_accessible:
		return {"success": false, "reason": "Condotti inaccessibili o bloccati"}
	
	duct_hazards_cleared = true
	var found_items := []
	
	# Il duct drone può recuperare scatola nera e crediti direttamente
	if not black_box_recovered:
		black_box_recovered = true
		found_items.append({
			"id": "black_box_" + derelict_id,
			"name": "Scatola Nera " + ship_name,
			"type": "DATA_CORE",
			"mass_kg": 5.0,
			"volume_m3": 0.1,
			"log_data": black_box_data,
			"value_credits": black_box_data.get("value_credits", 500)
		})
	
	_check_fully_scavenged()
	return {
		"success": true,
		"found_items": found_items,
		"credits": credits_contained,
		"hazards_cleared": true
	}

## Recupero modulo / pezzo di scavenging specifico
func scavenge_module_by_index(index: int, destination_cargo_or_drone: Node = null) -> Dictionary:
	if ice_locked:
		return {"error": "ICE_LOCKED", "message": "Accesso negato: Sistema di sicurezza ICE attivo"}
	if bulkhead_intact and requires_laser_cutting:
		return {"error": "BULKHEAD_INTACT", "message": "Paratia esterna sigillata: Richiesto taglio laser"}

	if index < 0 or index >= salvageable_modules.size():
		return {"error": "INVALID_INDEX", "message": "Modulo non trovato"}

	var item: Dictionary = salvageable_modules.pop_at(index)
	var stored := false
	if destination_cargo_or_drone:
		if destination_cargo_or_drone.has_method("add_item"):
			stored = destination_cargo_or_drone.add_item(item, 1)
		elif destination_cargo_or_drone.has_method("collect_cargo_item"):
			stored = destination_cargo_or_drone.collect_cargo_item(item.id, item.name, item.mass_kg)
	
	loot_scavenged.emit(item)
	_check_fully_scavenged()
	return {"success": true, "item": item, "stored": stored}

## Recupero dell'intero bottino (Crediti, FLUX, Moduli rimasti, Scatola nera)
func scavenge_all_available(destination_cargo_or_drone: Node = null) -> Dictionary:
	if ice_locked:
		return {"error": "ICE_LOCKED", "message": "Accesso negato: violare ICE prima dell'estrazione totale"}
	if bulkhead_intact and requires_laser_cutting:
		return {"error": "BULKHEAD_INTACT", "message": "Paratia sigillata: tagliare con laser"}

	var collected_modules: Array = []
	while salvageable_modules.size() > 0:
		var mod_data: Dictionary = salvageable_modules.pop_back()
		if destination_cargo_or_drone:
			if destination_cargo_or_drone.has_method("add_item"):
				destination_cargo_or_drone.add_item(mod_data, 1)
			elif destination_cargo_or_drone.has_method("collect_cargo_item"):
				destination_cargo_or_drone.collect_cargo_item(mod_data.id, mod_data.name, mod_data.mass_kg)
		collected_modules.append(mod_data)

	var cr := credits_contained
	var fl := flux_contained
	credits_contained = 0
	flux_contained = 0.0

	var bb_data: Dictionary = {}
	if not black_box_recovered:
		black_box_recovered = true
		bb_data = black_box_data

	_check_fully_scavenged()
	return {
		"success": true,
		"credits_recovered": cr,
		"flux_recovered": fl,
		"modules_recovered": collected_modules,
		"black_box": bb_data
	}

func _check_fully_scavenged() -> void:
	if salvageable_modules.is_empty() and credits_contained == 0 and flux_contained <= 0.0 and black_box_recovered:
		_is_fully_scavenged = true
		derelict_fully_salvaged.emit()

func is_salvaged() -> bool:
	return _is_fully_scavenged
