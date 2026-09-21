@tool
class_name ShipDeviceData
extends Resource

## Rappresenta un dispositivo all'interno di una stanza della nave (generatore, utility, ecc.)

@export var id: String = ""
@export var name: String = ""
@export var pos: Vector2 = Vector2.ZERO
@export var power_mw: float = 0.0
@export var category: String = "utility"
@export var sector: String = ""
@export var desc: String = ""
@export var component_class: String = ""
@export var custom_properties: Dictionary = {}

const COMPONENT_CLASSES: Array[String] = [
	"ReactorComponent",
	"BatteryComponent",
	"CoolingComponent",
	"ThrusterComponent",
	"HelmControlComponent",
	"NavComputerComponent",
	"SensorsMatrixComponent",
	"AntennaArrayComponent",
	"ArmoryDefenseComponent",
	"ShieldBalancerComponent",
	"LifeSupportComponent",
	"CargoHandlingComponent",
	"DroneStationComponent",
	"RechargeDockComponent",
	"ServerRackComponent",
	"CamArrayComponent",
	"ShipPhysicalComponent"
]

## Definizione dei 21 dispositivi canonici della nave (da docs/POWER_GRID_DEVICES.md)
const CANONICAL_DEVICES: Dictionary = {
	"core_reactor": {"name": "Reattore Tokamak Primario", "category": "reactor", "power_mw": 500.0, "component_class": "ReactorComponent", "desc": "Generatore primario a fusione magnetica."},
	"battery_01": {"name": "Banco Batterie Emergenza", "category": "engineering", "power_mw": 0.0, "component_class": "BatteryComponent", "desc": "Accumulatore tampone per transitori e blackout."},
	"cooling_01": {"name": "Radiatore Criogenico", "category": "engineering", "power_mw": -20.0, "component_class": "CoolingComponent", "desc": "Scambiatore criogenico dissipatore di calore."},
	"engine_main": {"name": "Propulsore a Scarica Ionica", "category": "propulsion", "power_mw": -50.0, "component_class": "ThrusterComponent", "desc": "Spinta longitudinale primaria e Cruise Drive."},
	"rcs_pitch_l": {"name": "Attuatore RCS Babordo", "category": "propulsion", "power_mw": -15.0, "component_class": "ThrusterComponent", "desc": "Attuatore di manovra e stabilizzazione inerziale SX."},
	"rcs_pitch_r": {"name": "Attuatore RCS Tribordo", "category": "propulsion", "power_mw": -15.0, "component_class": "ThrusterComponent", "desc": "Attuatore di manovra e stabilizzazione inerziale DX."},
	"helm_control": {"name": "Consolle Pilotaggio e Plancia", "category": "command", "power_mw": -15.0, "component_class": "HelmControlComponent", "desc": "Interfaccia comandi di manovra pilota."},
	"nav_computer": {"name": "Elaboratore Rotte & Salto", "category": "command", "power_mw": -10.0, "component_class": "NavComputerComponent", "desc": "Calcolo traiettorie orbitali, coordinate salto e waypoint."},
	"sensors_matrix": {"name": "Matrice Sensori Phased Array", "category": "sensors", "power_mw": -25.0, "component_class": "SensorsMatrixComponent", "desc": "Radar volumetrico 3D, tracciamento contatti e ping attivo."},
	"antenna_array": {"name": "Transceiver Sub-Spazio", "category": "comms", "power_mw": -15.0, "component_class": "AntennaArrayComponent", "desc": "Array comunicazioni radio a lungo raggio e link EW."},
	"armory_defense": {"name": "Alimentazione Armeria & Torrette", "category": "tactical", "power_mw": -30.0, "component_class": "ArmoryDefenseComponent", "desc": "Banco di potenza torrette, laser e tubi missilistici."},
	"arm_sx_balancer": {"name": "Bilanciatore Scudi Babordo", "category": "defense", "power_mw": -45.0, "component_class": "ShieldBalancerComponent", "desc": "Rigenerazione e distribuzione scudi deflettori SX."},
	"arm_dx_balancer": {"name": "Bilanciatore Scudi Tribordo", "category": "defense", "power_mw": -45.0, "component_class": "ShieldBalancerComponent", "desc": "Rigenerazione e distribuzione scudi deflettori DX."},
	"scrubber": {"name": "Filtro CO2 Primario", "category": "life_support", "power_mw": -10.0, "component_class": "LifeSupportComponent", "desc": "Purificazione anidride carbonica e ricircolo O2."},
	"heater": {"name": "Caldaia Termoregolatrice", "category": "life_support", "power_mw": -10.0, "component_class": "LifeSupportComponent", "desc": "Mantenimento temperatura abitacolo (21°C)."},
	"serra_idroponica": {"name": "Serra Idroponica O2", "category": "life_support", "power_mw": -15.0, "component_class": "LifeSupportComponent", "desc": "Generazione biologica rinnovabile di ossigeno e razioni."},
	"cargo_handling": {"name": "Manipolatore Stiva", "category": "cargo", "power_mw": -10.0, "component_class": "CargoHandlingComponent", "desc": "Controllo portelloni stiva e bloccaggio container."},
	"dronestation": {"name": "Baia Ricarica Drone EVA", "category": "service", "power_mw": -10.0, "component_class": "DroneStationComponent", "desc": "Culla di attracco e ricarica rapida drone esterno."},
	"recharge_dock": {"name": "Dock Ricarica Duct Drone", "category": "engineering", "power_mw": -10.0, "component_class": "RechargeDockComponent", "desc": "Nodo ricarica e manutenzione per il drone condotti."},
	"server_rack": {"name": "Mainframe Cyber-Guerra", "category": "cyber", "power_mw": -10.0, "component_class": "ServerRackComponent", "desc": "Server centrale per exploit, firewall e crittografia."},
	"cam_array": {"name": "Array Telecamere Esterne", "category": "sensors", "power_mw": -5.0, "component_class": "CamArrayComponent", "desc": "Telecamere perimetrali 6CH e fari ad alta intensità."}
}

static func get_canonical_def(key: String) -> Dictionary:
	if CANONICAL_DEVICES.has(key):
		return CANONICAL_DEVICES[key]
	return {}

static func create_canonical_device(canonical_key: String, new_id: String, room_name: String, center_pos: Vector2) -> ShipDeviceData:
	var def := get_canonical_def(canonical_key)
	var dev_name: String = def.get("name", "Dispositivo")
	var dev := ShipDeviceData.new(new_id, dev_name, center_pos)
	dev.category = def.get("category", "utility")
	dev.power_mw = float(def.get("power_mw", 0.0))
	dev.component_class = def.get("component_class", "")
	dev.desc = def.get("desc", "")
	dev.sector = room_name
	return dev

## Se power_mw è positivo, il dispositivo è un generatore.
var is_generator: bool:
	get:
		return power_mw > 0.0

func _init(p_id: String = "", p_name: String = "", p_pos: Vector2 = Vector2.ZERO) -> void:
	id = p_id
	name = p_name
	pos = p_pos

func get_or_detect_component_class() -> String:
	if not component_class.is_empty() and COMPONENT_CLASSES.has(component_class):
		return component_class
	var lower_id := id.to_lower()
	var lower_name := name.to_lower()
	var lower_cat := category.to_lower()
	
	if lower_id.contains("helm") or lower_id.contains("pod_piloti") or lower_name.contains("pilota") or lower_name.contains("plancia"):
		return "HelmControlComponent"
	elif lower_id.contains("nav_computer") or lower_id.contains("rotte") or lower_name.contains("rotte"):
		return "NavComputerComponent"
	elif lower_id.contains("sensor") or lower_name.contains("sensori") or lower_name.contains("radar"):
		return "SensorsMatrixComponent"
	elif lower_id.contains("antenna") or lower_id.contains("comms") or lower_name.contains("comunicaz") or lower_name.contains("transceiver"):
		return "AntennaArrayComponent"
	elif lower_id.contains("armory") or lower_id.contains("torrett") or lower_id.contains("weapon") or lower_name.contains("arm") or lower_name.contains("armeria"):
		if lower_id.contains("balancer"):
			return "ShieldBalancerComponent"
		return "ArmoryDefenseComponent"
	elif lower_id.contains("balancer") or lower_id.contains("shield") or lower_id.contains("sistema_difesa") or lower_name.contains("scud"):
		return "ShieldBalancerComponent"
	elif lower_id.contains("cargo") or lower_id.contains("stiva") or lower_name.contains("manipolatore") or lower_name.contains("carico"):
		return "CargoHandlingComponent"
	elif lower_id.contains("dronestation") or lower_id.contains("baia_ricarica_drone"):
		return "DroneStationComponent"
	elif lower_id.contains("recharge_dock") or lower_id.contains("drone_dock"):
		return "RechargeDockComponent"
	elif lower_id.contains("server") or lower_id.contains("mainframe") or lower_name.contains("server"):
		return "ServerRackComponent"
	elif lower_id.contains("cam") or lower_id.contains("light") or lower_name.contains("telecamer") or lower_name.contains("fari"):
		return "CamArrayComponent"
	elif lower_cat == "propulsion" or lower_id.contains("engine") or lower_id.contains("thruster") or lower_id.contains("rcs") or lower_name.contains("motore") or lower_name.contains("propuls") or lower_name.contains("rcs"):
		return "ThrusterComponent"
	elif (lower_cat == "engineering" or is_generator) and (lower_id.contains("reactor") or lower_id.contains("reattore") or lower_name.contains("reattore")):
		return "ReactorComponent"
	elif lower_id.contains("battery") or lower_id.contains("batteria") or lower_name.contains("batteria"):
		return "BatteryComponent"
	elif lower_cat == "life_support" or lower_id.contains("life_support") or lower_id.contains("scrubber") or lower_id.contains("heater") or lower_id.contains("serra") or lower_id.contains("o2") or lower_id.contains("co2") or lower_id.contains("purificatore") or lower_name.contains("ossigeno") or lower_name.contains("caldaia"):
		return "LifeSupportComponent"
	elif lower_id.contains("cooling") or lower_id.contains("radiator") or lower_name.contains("raffreddamento"):
		return "CoolingComponent"
	return "ShipPhysicalComponent"

func create_physical_component(room_id: String = "") -> ShipPhysicalComponent:
	var c_class := get_or_detect_component_class()
	var comp: ShipPhysicalComponent = null
	match c_class:
		"HelmControlComponent":
			comp = HelmControlComponent.new(id, room_id, category)
			if power_mw < 0.0:
				comp.power_draw_nominal = absf(power_mw)
		"NavComputerComponent":
			comp = NavComputerComponent.new(id, room_id, category)
			if power_mw < 0.0:
				comp.power_draw_nominal = absf(power_mw)
		"SensorsMatrixComponent":
			comp = SensorsMatrixComponent.new(id, room_id, category)
			if power_mw < 0.0:
				comp.power_draw_nominal = absf(power_mw)
		"AntennaArrayComponent":
			comp = AntennaArrayComponent.new(id, room_id, category)
			if power_mw < 0.0:
				comp.power_draw_nominal = absf(power_mw)
		"ArmoryDefenseComponent":
			comp = ArmoryDefenseComponent.new(id, room_id, category)
			if power_mw < 0.0:
				comp.power_draw_nominal = absf(power_mw)
		"ShieldBalancerComponent":
			comp = ShieldBalancerComponent.new(id, room_id, category)
			if power_mw < 0.0:
				comp.power_draw_nominal = absf(power_mw)
		"CargoHandlingComponent":
			comp = CargoHandlingComponent.new(id, room_id, category)
			if power_mw < 0.0:
				comp.power_draw_nominal = absf(power_mw)
		"DroneStationComponent":
			comp = DroneStationComponent.new(id, room_id, category)
			if power_mw < 0.0:
				comp.power_draw_nominal = absf(power_mw)
		"RechargeDockComponent":
			comp = RechargeDockComponent.new(id, room_id, category)
			if power_mw < 0.0:
				comp.power_draw_nominal = absf(power_mw)
		"ServerRackComponent":
			comp = ServerRackComponent.new(id, room_id, category)
			if power_mw < 0.0:
				comp.power_draw_nominal = absf(power_mw)
		"CamArrayComponent":
			comp = CamArrayComponent.new(id, room_id, category)
			if power_mw < 0.0:
				comp.power_draw_nominal = absf(power_mw)
		"ReactorComponent":
			comp = ReactorComponent.new(id, room_id, category)
			if power_mw > 0.0:
				comp.power_output_nominal = power_mw
		"BatteryComponent":
			comp = BatteryComponent.new(id, room_id, category)
		"ThrusterComponent":
			comp = ThrusterComponent.new(id, room_id, category)
			if power_mw < 0.0:
				comp.power_draw_nominal = absf(power_mw)
		"LifeSupportComponent":
			comp = LifeSupportComponent.new(id, room_id, category)
			if power_mw < 0.0:
				comp.power_draw_nominal = absf(power_mw)
		"CoolingComponent":
			comp = CoolingComponent.new(id, room_id, category)
			if power_mw < 0.0:
				comp.power_draw_nominal = absf(power_mw)
		_:
			comp = ShipPhysicalComponent.new(id, room_id, category)
			if power_mw < 0.0:
				comp.power_draw_nominal = absf(power_mw)
	comp.component_name = name
	for prop in custom_properties:
		if prop in comp:
			comp.set(prop, custom_properties[prop])
	comp.initialize_registers()
	return comp

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"pos": [pos.x, pos.y],
		"power_mw": power_mw,
		"category": category,
		"sector": sector,
		"desc": desc,
		"component_class": component_class,
		"custom_properties": custom_properties
	}

func from_dict(data: Dictionary) -> void:
	id = data.get("id", "")
	name = data.get("name", "")
	
	if data.has("pos"):
		if data["pos"] is Array and data["pos"].size() == 2:
			pos = Vector2(float(data["pos"][0]), float(data["pos"][1]))
		elif data["pos"] is Vector2:
			pos = data["pos"]
			
	power_mw = float(data.get("power_mw", 0.0))
	category = data.get("category", "utility")
	sector = data.get("sector", "")
	desc = data.get("desc", "")
	component_class = data.get("component_class", "")
	custom_properties = data.get("custom_properties", {})
