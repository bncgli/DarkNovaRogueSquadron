class_name ShipHAL
extends Node

## Hardware Abstraction Layer (HAL) per Dark Nova: Rogue Squadron.
## Media tra il bus hardware a basso livello (ShipHardwareBus) e le applicazioni GUI
## ad alto livello (FlightControl, PowerGrid, Diagnostics, LifeSupport).
## Fornisce contratti reattivi, aggregati e disaccoppiati per la UI.

# --- SEGNALI DI DOMINIO AD ALTO LIVELLO ---
signal propulsion_profile_changed(efficiency: float, max_thrust: float, available_thrust: float)
signal power_telemetry_updated(generated_mw: float, demanded_mw: float, ratio: float, is_blackout: bool)
signal thermal_telemetry_updated(total_heat: float, avg_temp: float)
signal hardware_integrity_changed(device_id: String, health: float, status: String)
signal system_alert_emitted(alert_type: String, message: String)
signal life_support_updated(o2: float, co2: float, cabin_temp: float)

var _hardware_bus: ShipHardwareBus = null

func _init(p_bus: ShipHardwareBus = null) -> void:
	if p_bus:
		set_hardware_bus(p_bus)

func _ready() -> void:
	if _hardware_bus == null:
		_auto_connect_bus()

func _auto_connect_bus() -> void:
	if is_inside_tree():
		var swm := get_node_or_null("/root/SpaceWorldManager")
		if swm and swm.has_method("get_hardware_bus"):
			var bus = swm.get_hardware_bus()
			if bus is ShipHardwareBus:
				set_hardware_bus(bus)

func set_hardware_bus(bus: ShipHardwareBus) -> void:
	if _hardware_bus == bus:
		return
		
	if _hardware_bus and is_instance_valid(_hardware_bus):
		_disconnect_bus_signals()
		
	_hardware_bus = bus
	if _hardware_bus and is_instance_valid(_hardware_bus):
		_connect_bus_signals()
		_refresh_all_domains()

func get_hardware_bus() -> ShipHardwareBus:
	if _hardware_bus == null:
		_auto_connect_bus()
	return _hardware_bus

func _connect_bus_signals() -> void:
	if not _hardware_bus.telemetry_received.is_connected(_on_bus_telemetry_received):
		_hardware_bus.telemetry_received.connect(_on_bus_telemetry_received)
	if not _hardware_bus.power_grid_balanced.is_connected(_on_bus_power_balanced):
		_hardware_bus.power_grid_balanced.connect(_on_bus_power_balanced)
	if not _hardware_bus.thermal_grid_updated.is_connected(_on_bus_thermal_updated):
		_hardware_bus.thermal_grid_updated.connect(_on_bus_thermal_updated)
	if not _hardware_bus.blackout_state_changed.is_connected(_on_bus_blackout_changed):
		_hardware_bus.blackout_state_changed.connect(_on_bus_blackout_changed)

func _disconnect_bus_signals() -> void:
	if _hardware_bus.telemetry_received.is_connected(_on_bus_telemetry_received):
		_hardware_bus.telemetry_received.disconnect(_on_bus_telemetry_received)
	if _hardware_bus.power_grid_balanced.is_connected(_on_bus_power_balanced):
		_hardware_bus.power_grid_balanced.disconnect(_on_bus_power_balanced)
	if _hardware_bus.thermal_grid_updated.is_connected(_on_bus_thermal_updated):
		_hardware_bus.thermal_grid_updated.disconnect(_on_bus_thermal_updated)
	if _hardware_bus.blackout_state_changed.is_connected(_on_bus_blackout_changed):
		_hardware_bus.blackout_state_changed.disconnect(_on_bus_blackout_changed)

func _refresh_all_domains() -> void:
	refresh_propulsion_profile()
	var grid := get_power_telemetry()
	power_telemetry_updated.emit(
		grid.get("generated_mw", 0.0),
		grid.get("demanded_mw", 0.0),
		grid.get("power_ratio", 1.0),
		grid.get("is_blackout", false)
	)
	var therm := get_thermal_telemetry()
	thermal_telemetry_updated.emit(therm.get("total_heat", 0.0), therm.get("avg_temp", 20.0))
	var ls := get_life_support_metrics()
	life_support_updated.emit(ls.get("o2", 100.0), ls.get("co2", 0.0), ls.get("temp", 21.0))

# --- GESTIONE EVENTI BUS ---
func _on_bus_telemetry_received(device_id: String, telem: Dictionary) -> void:
	var cat: String = telem.get("category", "")
	var health: float = float(telem.get("health", 100.0))
	var status: String = str(telem.get("status", "UNKNOWN"))
	
	hardware_integrity_changed.emit(device_id, health, status)
	
	if cat == "propulsion":
		refresh_propulsion_profile()
	elif cat == "life_support":
		var ls := get_life_support_metrics()
		life_support_updated.emit(ls.get("o2", 100.0), ls.get("co2", 0.0), ls.get("temp", 21.0))

func _on_bus_power_balanced(generated: float, demanded: float, _net: float) -> void:
	var ratio := 1.0
	var blackout := false
	if _hardware_bus:
		ratio = _hardware_bus.power_ratio
		blackout = _hardware_bus.is_blackout
	power_telemetry_updated.emit(generated, demanded, ratio, blackout)

func _on_bus_thermal_updated(total_h: float, avg_t: float) -> void:
	thermal_telemetry_updated.emit(total_h, avg_t)

func _on_bus_blackout_changed(blackout: bool, ratio: float) -> void:
	if _hardware_bus:
		power_telemetry_updated.emit(
			_hardware_bus.total_generated_mw,
			_hardware_bus.total_demanded_mw,
			ratio,
			blackout
		)

# ==============================================================================
# 1. CONTRATTI PROPULSIONE (per FlightControlApp & Spaceship)
# ==============================================================================

## Ritorna l'efficienza complessiva dei propulsori (0.0..1.0)
func get_propulsion_efficiency() -> float:
	if _hardware_bus == null:
		return 1.0
	return _hardware_bus.get_propulsion_efficiency()

## Ritorna la spinta massima teorica totale
func get_total_available_thrust() -> float:
	if _hardware_bus == null:
		return 35.0
	return _hardware_bus.get_total_available_thrust()

## Notifica e riallinea il profilo propulsivo
func refresh_propulsion_profile() -> void:
	var eff := get_propulsion_efficiency()
	var avail := get_total_available_thrust()
	var max_th := 0.0
	if _hardware_bus:
		for t in _hardware_bus.get_components_by_category("propulsion"):
			if t is ThrusterComponent:
				max_th += t.max_thrust
	if max_th <= 0.0:
		max_th = 35.0
	propulsion_profile_changed.emit(eff, max_th, avail)

## Applica un input di throttle a tutti i propulsori attivi
func apply_thrust_input(throttle: float) -> void:
	if _hardware_bus == null:
		return
	var thrusters := _hardware_bus.get_components_by_category("propulsion")
	for t in thrusters:
		if t is ThrusterComponent:
			t.set_throttle(throttle)

# ==============================================================================
# 2. CONTRATTI ENERGIA & RETE (per PowerGridApp)
# ==============================================================================

func get_power_telemetry() -> Dictionary:
	if _hardware_bus == null:
		return {
			"generated_mw": 1000.0,
			"demanded_mw": 200.0,
			"net_balance_mw": 800.0,
			"power_ratio": 1.0,
			"is_blackout": false,
			"battery_charge_mj": 500.0,
			"battery_capacity_mj": 500.0
		}
	return _hardware_bus.get_grid_telemetry()

func get_thermal_telemetry() -> Dictionary:
	if _hardware_bus == null:
		return {"total_heat": 20.0, "avg_temp": 20.0}
	return {
		"total_heat": _hardware_bus.total_heat,
		"avg_temp": _hardware_bus.avg_temperature
	}

func set_reactor_power_target(target: float) -> bool:
	if _hardware_bus == null:
		return false
	var reactors := _hardware_bus.get_components_by_category("engineering")
	var modified := false
	for r in reactors:
		if r is ReactorComponent:
			var ok := r.write_register("power_target", target)
			if ok:
				modified = true
	return modified

# --- MAPPATURE DISPOSITIVI E STANZE (Specifica docs/POWER_GRID_DEVICES.md) ---
const ROOM_ALIASES: Dictionary = {
	"engine_room": ["engine_room", "sala_motori", "engine"],
	"sala_motori": ["sala_motori", "engine_room", "engine"],
	"engine": ["engine", "sala_motori", "engine_room"],
	"bridge": ["bridge", "ponte_comando"],
	"ponte_comando": ["ponte_comando", "bridge"],
	"sensors": ["sensors", "matrice_sensori"],
	"matrice_sensori": ["matrice_sensori", "sensors"],
	"comms": ["comms", "comunicazioni"],
	"comunicazioni": ["comunicazioni", "comms"],
	"armory": ["armory", "armamenti"],
	"armamenti": ["armamenti", "armory"],
	"reactor": ["reactor", "reattore_fusione", "reattore"],
	"reattore_fusione": ["reattore_fusione", "reactor", "reattore"],
	"cargo": ["cargo", "baia_carico"],
	"baia_carico": ["baia_carico", "cargo"],
	"rcs_left": ["rcs_left", "rcs_pitch_l"],
	"rcs_right": ["rcs_right", "rcs_pitch_r"],
	"room_11": ["room_11", "supporto_vitale_min", "supporto_vitale_adv"],
	"supporto_vitale_min": ["supporto_vitale_min", "room_11", "supporto_vitale_adv"],
	"room_13": ["room_13", "pod_drone"],
	"pod_drone": ["pod_drone", "room_13"],
	"room_14": ["room_14", "armatura_adattiva_sx", "armatura_adattiva"],
	"room_15": ["room_15", "armatura_adattiva_dx", "armatura_adattiva"],
	"mainframe": ["mainframe", "server_rack"]
}

const DEVICE_ALIASES: Dictionary = {
	"engine_main": ["engine_main", "thruster_01", "thruster_02", "engine_left", "engine_right", "engine", "sala_motori"],
	"rcs_pitch_l": ["rcs_pitch_l", "rcs_left", "rcs_pitch_left"],
	"rcs_pitch_r": ["rcs_pitch_r", "rcs_right", "rcs_pitch_right"],
	"helm_control": ["helm_control", "pod_piloti", "bridge", "ponte_comando"],
	"nav_computer": ["nav_computer", "bridge", "ponte_comando"],
	"sensors_matrix": ["sensors_matrix", "sensor_array", "array_sensori", "sensors", "matrice_sensori"],
	"antenna_array": ["antenna_array", "comms_relay", "matrice_comunicazione", "comms", "comunicazioni"],
	"armory_defense": ["armory_defense", "weapon_array", "gestore_torrette", "armory", "armamenti"],
	"arm_sx_balancer": ["arm_sx_balancer", "room_14", "sistema_difesa", "armatura_adattiva"],
	"arm_dx_balancer": ["arm_dx_balancer", "room_15", "sistema_difesa", "armatura_adattiva"],
	"scrubber": ["scrubber", "co2_extr", "purificatore", "room_11", "supporto_vitale_min", "supporto_vitale_adv"],
	"heater": ["heater", "caldaia", "room_11", "supporto_vitale_min", "supporto_vitale_adv"],
	"serra_idroponica": ["serra_idroponica", "supporto_vitale_adv"],
	"quarters_life": ["quarters_life", "quarters"],
	"cargo_handling": ["cargo_handling", "cargo", "baia_carico"],
	"dronestation": ["dronestation", "baia_ricarica_drone", "room_13", "pod_drone"],
	"recharge_dock": ["recharge_dock", "drone_dock", "cargo"],
	"server_rack": ["server_rack", "mainserver", "mainframe"],
	"cooling_01": ["cooling_01", "engine_room", "sala_motori", "engine"],
	"battery_01": ["battery_01", "engine_room", "sala_motori", "engine"],
	"core_reactor": ["core_reactor", "reactor_01", "reactor_main", "reattore", "reactor", "reattore_fusione", "engine_room"],
	"cam_array": ["cam_array", "cams"]
}

const DEVICE_DEFAULT_ROOMS: Dictionary = {
	"engine_main": "sala_motori",
	"rcs_pitch_l": "rcs_left",
	"rcs_pitch_r": "rcs_right",
	"helm_control": "ponte_comando",
	"nav_computer": "ponte_comando",
	"sensors_matrix": "matrice_sensori",
	"antenna_array": "comunicazioni",
	"armory_defense": "armamenti",
	"arm_sx_balancer": "armatura_adattiva",
	"arm_dx_balancer": "armatura_adattiva",
	"scrubber": "supporto_vitale_min",
	"heater": "supporto_vitale_min",
	"serra_idroponica": "supporto_vitale_adv",
	"quarters_life": "quarters",
	"cargo_handling": "baia_carico",
	"dronestation": "pod_drone",
	"recharge_dock": "baia_carico",
	"server_rack": "mainframe",
	"cooling_01": "sala_motori",
	"battery_01": "sala_motori",
	"core_reactor": "reattore_fusione",
	"cam_array": "esterno"
}

const DEVICE_NAMES: Dictionary = {
	"engine_main": "Propulsore Principale a Scarica Ionica",
	"rcs_pitch_l": "Attuatore RCS Babordo",
	"rcs_pitch_r": "Attuatore RCS Tribordo",
	"helm_control": "Consolle di Pilotaggio e Plancia",
	"nav_computer": "Elaboratore Rotte e Calcolo Salto",
	"sensors_matrix": "Matrice Sensori Phased Array",
	"antenna_array": "Antenna Tranceiver Sub-Spazio",
	"armory_defense": "Alimentazione Armeria e Torrette",
	"arm_sx_balancer": "Bilanciatore Servo Motori Scudi SX",
	"arm_dx_balancer": "Bilanciatore Servo Motori Scudi DX",
	"scrubber": "Filtro CO2 Primario / Purificatore",
	"heater": "Caldaia e Termoregolatore Nave",
	"serra_idroponica": "Serra Idroponica di Bordo",
	"quarters_life": "Supporto Vitale Alloggi",
	"cargo_handling": "Manipolatore Stiva e Portelloni",
	"dronestation": "Baia Ricarica Drone EVA",
	"recharge_dock": "Nodo Ricarica Duct Drone",
	"server_rack": "Mainframe Cyber-Guerra",
	"cooling_01": "Radiatore Criogenico",
	"battery_01": "Banco Batterie Emergenza",
	"core_reactor": "Reattore Tokamak Primario",
	"cam_array": "Array Telecamere Esterne"
}

const DEVICE_TO_CATEGORY: Dictionary = {
	"engine_main": "propulsion",
	"rcs_pitch_l": "propulsion",
	"rcs_pitch_r": "propulsion",
	"helm_control": "command",
	"nav_computer": "command",
	"sensors_matrix": "sensors",
	"antenna_array": "comms",
	"armory_defense": "tactical",
	"arm_sx_balancer": "defense",
	"arm_dx_balancer": "defense",
	"scrubber": "life_support",
	"heater": "life_support",
	"serra_idroponica": "life_support",
	"quarters_life": "life_support",
	"cargo_handling": "cargo",
	"dronestation": "service",
	"recharge_dock": "service",
	"server_rack": "mainframe",
	"cooling_01": "engineering",
	"battery_01": "engineering",
	"core_reactor": "engineering",
	"cam_array": "service"
}

func toggle_room_power(room_id: String, online: bool) -> void:
	if _hardware_bus == null:
		_auto_connect_bus()
	
	var target_rooms: Array = [room_id]
	if ROOM_ALIASES.has(room_id):
		target_rooms = ROOM_ALIASES[room_id]
	
	if _hardware_bus:
		for r_id in target_rooms:
			var devs := _hardware_bus.get_components_in_room(str(r_id))
			for d in devs:
				d.set_online(online)
				
	# Aggiorna anche lo stato della stanza nel Blueprint se registrato in SpaceWorldManager
	var swm := get_node_or_null("/root/SpaceWorldManager")
	if swm and swm.has_method("get_ship_blueprint"):
		var bp = swm.get_ship_blueprint()
		if bp:
			for r in bp.rooms:
				var rid: String = str(r.get("id") if r is Dictionary else (r.id if "id" in r else ""))
				if rid in target_rooms or rid == room_id:
					if r is Dictionary:
						r["is_on"] = online
					elif "is_on" in r:
						r.is_on = online
			if bp.has_signal("changed"):
				bp.emit_changed()

## Ricerca il componente fisico corrispondente a un ID dispositivo (supporta alias)
func find_component_for_device(device_id: String) -> ShipPhysicalComponent:
	if _hardware_bus == null:
		_auto_connect_bus()
	if _hardware_bus == null:
		return null
	if _hardware_bus.has_component(device_id):
		return _hardware_bus.get_component(device_id)
		
	var aliases: Array = DEVICE_ALIASES.get(device_id, [])
	for alias in aliases:
		var a_str := str(alias)
		if _hardware_bus.has_component(a_str):
			return _hardware_bus.get_component(a_str)
			
	for alias in aliases:
		var a_str := str(alias)
		var comps := _hardware_bus.get_components_in_room(a_str)
		if not comps.is_empty():
			return comps[0]
	return null

## Verifica se il dispositivo è marcato online nel bus o nel blueprint
func is_device_online(device_id: String) -> bool:
	var comp := find_component_for_device(device_id)
	if comp:
		return comp.is_online
		
	var aliases: Array = DEVICE_ALIASES.get(device_id, [device_id])
	if _hardware_bus:
		for a in aliases:
			var comps := _hardware_bus.get_components_in_room(str(a))
			if not comps.is_empty():
				var any_online := false
				for c in comps:
					if c.is_online:
						any_online = true
						break
				return any_online
				
	return _check_fallback_device_online(device_id)

## Verifica se il dispositivo riceve sufficiente energia elettrica per operare
func is_device_powered(device_id: String) -> bool:
	var comp := find_component_for_device(device_id)
	if comp:
		if not comp.is_online:
			return false
		if comp is ReactorComponent:
			return comp.is_online and comp.health_percent > 0.0 and comp.fuel_level > 0.0
		if comp is BatteryComponent:
			return comp.is_online and comp.charge_current > 0.0
		if _hardware_bus and _hardware_bus.is_blackout:
			return false
		return comp.power_supplied > 0.0 or comp.power_draw_nominal <= 0.0 or comp.power_ratio > 0.1
		
	if not is_device_online(device_id):
		return false
	var grid := get_power_telemetry()
	if bool(grid.get("is_blackout", false)):
		return false
	return true

## Ritorna un dizionario descrittivo con stato, stanza e telemetria del dispositivo
func get_device_status(device_id: String) -> Dictionary:
	var comp := find_component_for_device(device_id)
	var room: String = DEVICE_DEFAULT_ROOMS.get(device_id, "unknown")
	var dev_name: String = DEVICE_NAMES.get(device_id, device_id)
	var online: bool = false
	var powered: bool = false
	var health: float = 100.0
	var status_str: String = "OFFLINE"
	var p_draw: float = 0.0
	var p_sup: float = 0.0
	var cat: String = DEVICE_TO_CATEGORY.get(device_id, "utility")
	
	if comp:
		room = comp.room_id if not comp.room_id.is_empty() else room
		dev_name = comp.component_name if not comp.component_name.is_empty() else dev_name
		online = comp.is_online
		powered = is_device_powered(device_id)
		health = comp.health_percent
		status_str = comp.status_string
		p_draw = comp.power_draw_current
		p_sup = comp.power_supplied
		cat = comp.category
	else:
		online = is_device_online(device_id)
		powered = is_device_powered(device_id)
		status_str = "ONLINE" if online else "OFFLINE"
	
	return {
		"device_id": device_id,
		"device_name": dev_name,
		"room_id": room,
		"is_online": online,
		"is_powered": powered,
		"status": status_str,
		"health": health,
		"power_draw": p_draw,
		"power_supplied": p_sup,
		"category": cat
	}

## Accende o spegne un singolo componente fisico
func toggle_device_power(device_id: String, online: bool) -> bool:
	var comp := find_component_for_device(device_id)
	if comp:
		comp.set_online(online)
		return true
	return false

func _check_fallback_device_online(device_id: String) -> bool:
	var cat: String = DEVICE_TO_CATEGORY.get(device_id, "")
	var room: String = DEVICE_DEFAULT_ROOMS.get(device_id, "")
	var swm := get_node_or_null("/root/SpaceWorldManager")
	if swm:
		if swm.has_method("get_ship_blueprint"):
			var bp = swm.get_ship_blueprint()
			if bp:
				var target_rooms: Array = [room]
				if ROOM_ALIASES.has(room):
					target_rooms = ROOM_ALIASES[room]
				for r in bp.rooms:
					var rid: String = str(r.get("id") if r is Dictionary else (r.id if "id" in r else ""))
					if rid in target_rooms or rid == room:
						return bool(r.get("is_on", true) if r is Dictionary else (r.is_on if "is_on" in r else true))
		if not cat.is_empty() and swm.has_method("is_ship_system_powered"):
			return swm.is_ship_system_powered(cat)
	return true

func autobalance_grid() -> void:
	if _hardware_bus == null:
		return
	var reactors := _hardware_bus.get_components_by_category("engineering")
	var demand := _hardware_bus.total_demanded_mw
	for r in reactors:
		if r is ReactorComponent:
			if r.power_output_nominal > 0.0:
				var optimal_target := clampf((demand * 1.15) / r.power_output_nominal, 0.2, 1.5)
				r.write_register("power_target", optimal_target)

# ==============================================================================
# 3. CONTRATTI DIAGNOSTICA & INTEGRITÀ (per DiagnosticsApp)
# ==============================================================================

## Calcola l'integrità media percentuale dello scafo/hardware
func get_overall_system_integrity() -> float:
	if _hardware_bus == null:
		return 100.0
	var comps := _hardware_bus.get_all_components()
	if comps.is_empty():
		return 100.0
	var total_h := 0.0
	for c in comps:
		total_h += c.health_percent
	return total_h / float(comps.size())

## Ritorna l'elenco dei componenti guasti o con integrità sotto la soglia specificata
func get_damaged_components(threshold: float = 90.0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _hardware_bus == null:
		return result
	for c in _hardware_bus.get_all_components():
		if c.health_percent < threshold or c.status_string == "FAULT":
			result.append(c.get_telemetry())
	return result

func reboot_device(device_id: String) -> bool:
	if _hardware_bus == null:
		return false
	var res := _hardware_bus.dispatch_command(device_id, "reboot")
	return res.get("success", false)

func repair_device(device_id: String, amount: float = 100.0) -> bool:
	if _hardware_bus == null:
		return false
	var comp := _hardware_bus.get_component(device_id)
	if comp:
		comp.repair(amount)
		return true
	return false

# ==============================================================================
# 4. CONTRATTI SUPPORTO VITALE (per LifeSupportApp)
# ==============================================================================

func get_life_support_metrics() -> Dictionary:
	if _hardware_bus == null:
		return {"o2": 100.0, "co2": 0.0, "temp": 21.0, "status": "NOMINAL"}
	return _hardware_bus.get_life_support_status()

func set_target_temperature(target_celsius: float) -> void:
	if _hardware_bus == null:
		return
	var ls_list := _hardware_bus.get_components_by_category("life_support")
	for ls in ls_list:
		if ls is LifeSupportComponent:
			ls.write_register("target_temp", target_celsius)
