class_name ShipHAL
extends Node

## Hardware Abstraction Layer & Ship Operating System (ShipHAL) per Dark Nova: Rogue Squadron.
## Funziona come vero e proprio OS Kernel di bordo tra l'hardware fisico simulato (ShipHardwareBus)
## e il software applicativo (GodotOS apps e comandi shell CLI).
## Espone sottosistemi tipizzati di dominio:
##   - power: bilanciamento energetico, policy reattore/batterie, monitoraggio blackout.
##   - propulsion: spinta vettoriale, Cruise Drive, stabilizzazione inerziale, timone.
##   - navigation: calcolo rotte orbitali, vettori salto Hyperdrive e waypoint.
##   - sensors: feed radar phased array 3D, scansione passiva e ping attivo.
##   - comms: transceiver subspaziale, sintonia canali radio e link EW cyberwarfare.
##   - defense: scudi deflettori 4 quadranti, condensatori laser e torrette.
##   - life_support: atmosfera cabina (O2, CO2, temperatura, filtri).
##   - logistics / cargo: movimentazione stiva, ricarica droni EVA e condotti.
##   - cyber: mainframe, firewall difensivo, esecuzione exploit e coprocessore crypto.
##   - optics: telecamere esterne perimetrali 6CH e proiettori scafo.

# --- SEGNALI DEL KERNEL OS ---
signal propulsion_profile_changed(efficiency: float, max_thrust: float, available_thrust: float)
signal flight_controls_state_changed(can_control: bool)
signal power_telemetry_updated(generated_mw: float, demanded_mw: float, ratio: float, is_blackout: bool)
signal thermal_telemetry_updated(total_heat: float, avg_temp: float)
signal hardware_integrity_changed(device_id: String, health: float, status: String)
signal system_alert_emitted(alert_type: String, message: String)
signal life_support_updated(o2: float, co2: float, cabin_temp: float)
signal navigation_route_updated(destination: Vector2, distance: float, eta: float)
signal sensor_sweep_updated(targets: Array)
signal comms_state_updated(frequency: float, ew_connected: bool)
signal defense_shields_updated(front: float, rear: float, left: float, right: float)
signal cyber_firewall_updated(integrity: float, active: bool)
signal optics_feed_updated(channel: int, status: String)
signal device_lifecycle_changed(device_id: String, action: String)

var _hardware_bus: ShipHardwareBus = null

# Sottosistemi tipizzati esposti
var power: PowerSubsystem = null
var propulsion: PropulsionSubsystem = null
var navigation: NavigationSubsystem = null
var sensors: SensorsSubsystem = null
var comms: CommsSubsystem = null
var defense: DefenseSubsystem = null
var life_support: LifeSupportSubsystem = null
var logistics: LogisticsSubsystem = null
var cargo: LogisticsSubsystem = null # Alias per logistics
var cyber: CyberSubsystem = null
var optics: OpticsSubsystem = null

# --- MAPPATURE CANONICHE E ALIASING RETROCOMPATIBILE ---
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
	"supporto_vitale_adv": ["supporto_vitale_adv", "room_11", "supporto_vitale_min"],
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
	"cargo_handling": ["cargo_handling", "cargo", "baia_carico"],
	"dronestation": ["dronestation", "baia_ricarica_drone", "room_13", "pod_drone"],
	"recharge_dock": ["recharge_dock", "drone_dock", "cargo"],
	"server_rack": ["server_rack", "mainserver", "mainframe"],
	"cooling_01": ["cooling_01", "engine_room", "sala_motori", "engine"],
	"battery_01": ["battery_01", "engine_room", "sala_motori", "engine", "reactor"],
	"core_reactor": ["core_reactor", "reactor_01", "reactor_main", "reattore", "reactor", "reattore_fusione", "engine_room"],
	"cam_array": ["cam_array", "lights_main", "cams"]
}

const DEVICE_DEFAULT_ROOMS: Dictionary = {
	"engine_main": "engine_room",
	"rcs_pitch_l": "rcs_left",
	"rcs_pitch_r": "rcs_right",
	"helm_control": "bridge",
	"nav_computer": "bridge",
	"sensors_matrix": "sensors",
	"antenna_array": "comms",
	"armory_defense": "armory",
	"arm_sx_balancer": "room_14",
	"arm_dx_balancer": "room_15",
	"scrubber": "room_11",
	"heater": "room_11",
	"serra_idroponica": "room_11",
	"cargo_handling": "cargo",
	"dronestation": "room_13",
	"recharge_dock": "cargo",
	"server_rack": "mainframe",
	"cooling_01": "engine_room",
	"battery_01": "reactor",
	"core_reactor": "reactor",
	"cam_array": "bridge"
}

func _init(p_bus: ShipHardwareBus = null) -> void:
	_init_subsystems()
	if p_bus:
		set_hardware_bus(p_bus)

func _ready() -> void:
	if _hardware_bus == null:
		_auto_connect_bus()

func _init_subsystems() -> void:
	power = PowerSubsystem.new(self)
	propulsion = PropulsionSubsystem.new(self)
	navigation = NavigationSubsystem.new(self)
	sensors = SensorsSubsystem.new(self)
	comms = CommsSubsystem.new(self)
	defense = DefenseSubsystem.new(self)
	life_support = LifeSupportSubsystem.new(self)
	logistics = LogisticsSubsystem.new(self)
	cargo = logistics
	cyber = CyberSubsystem.new(self)
	optics = OpticsSubsystem.new(self)

func _auto_connect_bus() -> void:
	var swm = null
	if is_inside_tree():
		swm = get_node_or_null("/root/SpaceWorldManager")
	elif Engine.get_main_loop() is SceneTree:
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			swm = tree.root.get_node_or_null("SpaceWorldManager")
	
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
	if not _hardware_bus.device_registered.is_connected(_on_bus_device_registered):
		_hardware_bus.device_registered.connect(_on_bus_device_registered)
	if not _hardware_bus.device_unregistered.is_connected(_on_bus_device_unregistered):
		_hardware_bus.device_unregistered.connect(_on_bus_device_unregistered)

func _disconnect_bus_signals() -> void:
	if _hardware_bus.telemetry_received.is_connected(_on_bus_telemetry_received):
		_hardware_bus.telemetry_received.disconnect(_on_bus_telemetry_received)
	if _hardware_bus.power_grid_balanced.is_connected(_on_bus_power_balanced):
		_hardware_bus.power_grid_balanced.disconnect(_on_bus_power_balanced)
	if _hardware_bus.thermal_grid_updated.is_connected(_on_bus_thermal_updated):
		_hardware_bus.thermal_grid_updated.disconnect(_on_bus_thermal_updated)
	if _hardware_bus.blackout_state_changed.is_connected(_on_bus_blackout_changed):
		_hardware_bus.blackout_state_changed.disconnect(_on_bus_blackout_changed)
	if _hardware_bus.device_registered.is_connected(_on_bus_device_registered):
		_hardware_bus.device_registered.disconnect(_on_bus_device_registered)
	if _hardware_bus.device_unregistered.is_connected(_on_bus_device_unregistered):
		_hardware_bus.device_unregistered.disconnect(_on_bus_device_unregistered)

func _on_bus_device_registered(dev_id: String, comp: ShipPhysicalComponent) -> void:
	device_lifecycle_changed.emit(dev_id, "REGISTERED")
	_refresh_all_domains()

func _on_bus_device_unregistered(dev_id: String) -> void:
	device_lifecycle_changed.emit(dev_id, "UNREGISTERED")
	_refresh_all_domains()

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
	
	var helm := find_component_for_device("helm_control") as HelmControlComponent
	if helm:
		flight_controls_state_changed.emit(helm.can_control_flight)

func _on_bus_telemetry_received(device_id: String, telem: Dictionary) -> void:
	var cat: String = telem.get("category", "")
	var health: float = float(telem.get("health", 100.0))
	var status: String = str(telem.get("status", "UNKNOWN"))
	
	hardware_integrity_changed.emit(device_id, health, status)
	
	match cat:
		"propulsion", "command":
			refresh_propulsion_profile()
			if device_id == "helm_control" and telem.has("can_control"):
				flight_controls_state_changed.emit(bool(telem["can_control"]))
		"life_support":
			var ls := get_life_support_metrics()
			life_support_updated.emit(ls.get("o2", 100.0), ls.get("co2", 0.0), ls.get("temp", 21.0))
		"defense":
			var shld: Dictionary = defense.get_status().get("shields", {})
			defense_shields_updated.emit(
				shld.get("front", 100.0), shld.get("rear", 100.0),
				shld.get("left", 100.0), shld.get("right", 100.0)
			)
		"cyber":
			cyber_firewall_updated.emit(float(telem.get("firewall_integrity", 100.0)), bool(telem.get("firewall_active", true)))
		"sensors":
			if telem.has("contacts"):
				sensor_sweep_updated.emit(telem["contacts"])
		"comms":
			comms_state_updated.emit(float(telem.get("locked_freq", 0.0)), bool(telem.get("ew_connected", false)))

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
# SYSCALLS ATOMICHE & CONTROLLO SISTEMI
# ==============================================================================

## Richiesta allocazione transitoria di potenza elettrica da un dispositivo
func request_power_allocation(device_id: String, amount_mw: float) -> bool:
	if _hardware_bus == null:
		return true
	if _hardware_bus.is_blackout:
		return false
	if not is_device_powered(device_id):
		return false
	return (_hardware_bus.net_balance_mw >= amount_mw) or (_hardware_bus.power_ratio >= 0.8)

## Esegue un'azione hardware atomica mediata dal kernel OS
func execute_hardware_action(subsystem_name: String, action: String, params: Dictionary = {}) -> Dictionary:
	match subsystem_name.to_lower():
		"propulsion":
			match action:
				"throttle":
					propulsion.apply_thrust(float(params.get("value", 0.0)))
					return {"success": true}
				"speed_limit":
					var ok := propulsion.set_speed_limiter(float(params.get("value", 1.0)))
					return {"success": ok}
				"toggle_inertia":
					var ok := propulsion.toggle_inertia(bool(params.get("value", true)))
					return {"success": ok}
				"cruise":
					var ok := propulsion.toggle_cruise(bool(params.get("value", true)))
					return {"success": ok}
		"navigation":
			match action:
				"calculate":
					var dest: Vector2 = params.get("destination", Vector2.ZERO)
					return navigation.calculate_route(dest)
		"sensors":
			match action:
				"ping":
					var t: Array = sensors.trigger_active_ping()
					return {"success": true, "targets": t}
				"sweep":
					var ok := sensors.toggle_sweep(bool(params.get("enabled", true)))
					return {"success": ok}
		"comms":
			match action:
				"rotate":
					var ok := comms.rotate_antenna(float(params.get("degrees", 0.0)))
					return {"success": ok}
				"lock":
					var ok := comms.lock_frequency(float(params.get("frequency", 0.0)))
					return {"success": ok}
				"ew_link":
					var ok := comms.establish_ew_link(str(params.get("target_id", "")))
					return {"success": ok}
		"defense":
			match action:
				"fire":
					var ok := defense.request_weapon_discharge(str(params.get("weapon", "laser")))
					return {"success": ok}
				"boost":
					var ok := defense.activate_shield_boost(str(params.get("quadrant", "front")))
					return {"success": ok}
				"vent":
					var ok := defense.trigger_emergency_venting()
					return {"success": ok}
		"life_support":
			match action:
				"temperature":
					var ok := life_support.set_target_temp(float(params.get("value", 21.0)))
					return {"success": ok}
		"cargo", "logistics":
			match action:
				"doors":
					var ok := logistics.toggle_cargo_doors(bool(params.get("open", false)))
					return {"success": ok}
		"cyber":
			match action:
				"exploit":
					var ok := cyber.start_exploit(str(params.get("name", "")))
					return {"success": ok}
		"optics":
			match action:
				"channel":
					var ok := optics.set_active_channel(int(params.get("channel", 1)))
					return {"success": ok}
				"floodlights":
					var ok := optics.toggle_all_floodlights(bool(params.get("enabled", false)))
					return {"success": ok}
	return {"success": false, "error": "UNKNOWN_ACTION"}

## Ritorna lo stato di salute aggregato di un sottosistema
func query_subsystem_health(subsystem_name: String) -> Dictionary:
	var sub_cat := subsystem_name.to_lower()
	var comps: Array = []
	if _hardware_bus:
		comps = _hardware_bus.get_components_by_category(sub_cat)
		if comps.is_empty():
			for id_k in _hardware_bus._components:
				var c: ShipPhysicalComponent = _hardware_bus._components[id_k]
				if c.category == sub_cat or c.device_id.contains(sub_cat):
					comps.append(c)
	
	if comps.is_empty():
		return {"status": "OFFLINE", "health": 0.0, "power_ratio": 0.0, "devices_count": 0}
	
	var total_h := 0.0
	var total_ratio := 0.0
	var any_online := false
	for c in comps:
		total_h += c.health_percent
		total_ratio += c.power_ratio
		if c.is_online:
			any_online = true
			
	var avg_h: float = total_h / float(comps.size())
	var avg_ratio: float = total_ratio / float(comps.size())
	var status_str := "ONLINE" if any_online and avg_ratio >= 0.5 else ("DEGRADED" if any_online else "OFFLINE")
	return {
		"status": status_str,
		"health": avg_h,
		"power_ratio": avg_ratio,
		"devices_count": comps.size()
	}

# ==============================================================================
# RICERCA DISPOSITIVI E REGISTRI
# ==============================================================================

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

func is_device_online(device_id: String) -> bool:
	var comp := find_component_for_device(device_id)
	if comp:
		return comp.is_online
		
	var aliases: Array = DEVICE_ALIASES.get(device_id, [device_id])
	if _hardware_bus:
		for a in aliases:
			var comps := _hardware_bus.get_components_in_room(str(a))
			if not comps.is_empty():
				for c in comps:
					if c.is_online:
						return true
				return false
	return _check_fallback_device_online(device_id)

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

func is_device_operational(device_id: String) -> bool:
	var comp := find_component_for_device(device_id)
	if comp:
		return comp.is_online and is_device_powered(device_id) and comp.health_percent > 10.0 and comp.status_string != "FAULT" and comp.status_string != "SCRAM"
	return is_device_online(device_id) and is_device_powered(device_id)

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
		_hardware_bus.step(0.0)
				
	# Sincronizza stanza nel blueprint
	var swm = null
	if is_inside_tree():
		swm = get_node_or_null("/root/SpaceWorldManager")
	elif Engine.get_main_loop() is SceneTree:
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			swm = tree.root.get_node_or_null("SpaceWorldManager")
			
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

func toggle_device_power(device_id: String, online: bool) -> bool:
	var comp := find_component_for_device(device_id)
	if comp:
		comp.set_online(online)
		return true
	return false

func get_device_status(device_id: String) -> Dictionary:
	var comp := find_component_for_device(device_id)
	var room: String = DEVICE_DEFAULT_ROOMS.get(device_id, "unknown")
	var dev_name: String = device_id
	var online: bool = false
	var powered: bool = false
	var health: float = 100.0
	var status_str: String = "OFFLINE"
	var p_draw: float = 0.0
	var p_sup: float = 0.0
	var cat: String = "utility"
	
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

func _check_fallback_device_online(device_id: String) -> bool:
	var room: String = DEVICE_DEFAULT_ROOMS.get(device_id, "")
	var swm = null
	if is_inside_tree():
		swm = get_node_or_null("/root/SpaceWorldManager")
	elif Engine.get_main_loop() is SceneTree:
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			swm = tree.root.get_node_or_null("SpaceWorldManager")
			
	if swm and swm.has_method("get_ship_blueprint"):
		var bp = swm.get_ship_blueprint()
		if bp:
			var target_rooms: Array = [room]
			if ROOM_ALIASES.has(room):
				target_rooms = ROOM_ALIASES[room]
			for r in bp.rooms:
				var rid: String = str(r.get("id") if r is Dictionary else (r.id if "id" in r else ""))
				if rid in target_rooms or rid == room:
					return bool(r.get("is_on", true) if r is Dictionary else (r.is_on if "is_on" in r else true))
	return true

# ==============================================================================
# CONTRATTI FORWARDED COMPATIBILITA'
# ==============================================================================

func get_propulsion_efficiency() -> float:
	return propulsion.get_status().get("efficiency", 1.0)

func get_total_available_thrust() -> float:
	return propulsion.get_status().get("available_thrust", 35.0)

func refresh_propulsion_profile() -> void:
	var eff: float = get_propulsion_efficiency()
	var avail: float = get_total_available_thrust()
	var max_th := 0.0
	if _hardware_bus:
		for t in _hardware_bus.get_components_by_category("propulsion"):
			if t is ThrusterComponent:
				max_th += t.max_thrust
	if max_th <= 0.0:
		max_th = 35.0
	propulsion_profile_changed.emit(eff, max_th, avail)

func apply_thrust_input(throttle: float) -> void:
	propulsion.apply_thrust(throttle)

func get_power_telemetry() -> Dictionary:
	return power.get_balance()

func get_thermal_telemetry() -> Dictionary:
	if _hardware_bus == null:
		return {"total_heat": 20.0, "avg_temp": 20.0}
	return {
		"total_heat": _hardware_bus.total_heat,
		"avg_temp": _hardware_bus.avg_temperature
	}

func set_reactor_power_target(target: float) -> bool:
	return power.set_reactor_target(target)

func autobalance_grid() -> void:
	power.autobalance()

func get_life_support_metrics() -> Dictionary:
	return life_support.get_status()

func set_target_temperature(target_celsius: float) -> void:
	life_support.set_target_temp(target_celsius)

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
# SOTTOSISTEMI DI DOMINIO SHIP OS
# ==============================================================================

class PowerSubsystem extends RefCounted:
	var _hal: ShipHAL
	
	func _init(hal: ShipHAL) -> void:
		_hal = hal
		
	func get_balance() -> Dictionary:
		if _hal._hardware_bus == null:
			return {
				"generated_mw": 1000.0,
				"demanded_mw": 200.0,
				"net_balance_mw": 800.0,
				"power_ratio": 1.0,
				"is_blackout": false,
				"battery_charge_mj": 500.0,
				"battery_capacity_mj": 500.0
			}
		return _hal._hardware_bus.get_grid_telemetry()
		
	func set_reactor_target(target: float) -> bool:
		if _hal._hardware_bus == null:
			return false
		var reactors := _hal._hardware_bus.get_components_by_category("engineering")
		reactors.append_array(_hal._hardware_bus.get_components_by_category("reactor"))
		var modified := false
		for r in reactors:
			if r is ReactorComponent:
				if r.write_register("power_target", target):
					modified = true
		return modified
		
	func autobalance() -> void:
		if _hal._hardware_bus == null:
			return
		var reactors := _hal._hardware_bus.get_components_by_category("engineering")
		reactors.append_array(_hal._hardware_bus.get_components_by_category("reactor"))
		var demand := _hal._hardware_bus.total_demanded_mw
		for r in reactors:
			if r is ReactorComponent and r.power_output_nominal > 0.0:
				var optimal_target := clampf((demand * 1.15) / r.power_output_nominal, 0.2, 1.5)
				r.write_register("power_target", optimal_target)

	func is_blackout() -> bool:
		return _hal._hardware_bus.is_blackout if _hal._hardware_bus else false

	func toggle_room(room_id: String, online: bool) -> void:
		_hal.toggle_room_power(room_id, online)

	func is_operational() -> bool:
		return not is_blackout()


class PropulsionSubsystem extends RefCounted:
	var _hal: ShipHAL
	
	func _init(hal: ShipHAL) -> void:
		_hal = hal
		
	func get_status() -> Dictionary:
		var helm := _hal.find_component_for_device("helm_control") as HelmControlComponent
		var can_ctrl := true
		var inertia := true
		var speed_lim := 1.0
		var cruise := false
		
		if helm:
			can_ctrl = helm.can_control_flight and _hal.is_device_powered("helm_control")
			inertia = helm.inertia_damping_enabled
			speed_lim = helm.speed_limiter
			cruise = helm.cruise_drive_enabled
		else:
			can_ctrl = _hal.is_device_powered("helm_control") and _hal.is_device_online("helm_control")
			
		var eff: float = _hal._hardware_bus.get_propulsion_efficiency() if _hal._hardware_bus else 1.0
		var avail: float = _hal._hardware_bus.get_total_available_thrust() if _hal._hardware_bus else 35.0
		var max_th := 0.0
		if _hal._hardware_bus:
			for t in _hal._hardware_bus.get_components_by_category("propulsion"):
				if t is ThrusterComponent:
					max_th += t.max_thrust
		if max_th <= 0.0:
			max_th = 35.0
			
		var eng_powered := _hal.is_device_powered("engine_main")
		return {
			"can_control": can_ctrl and eng_powered,
			"available_thrust": avail if eng_powered else 0.0,
			"max_thrust": max_th,
			"efficiency": eff if eng_powered else 0.0,
			"inertia_damping": inertia,
			"speed_limiter": speed_lim,
			"cruise_drive_enabled": cruise and eng_powered,
			"engine_online": eng_powered
		}

	func can_control_flight() -> bool:
		return bool(get_status().get("can_control", false))

	func apply_thrust(throttle: float) -> void:
		if not can_control_flight():
			return
		if _hal._hardware_bus:
			for t in _hal._hardware_bus.get_components_by_category("propulsion"):
				if t is ThrusterComponent and t.thruster_type == "main":
					t.set_throttle(throttle)

	func set_speed_limiter(val: float) -> bool:
		if not can_control_flight():
			return false
		var helm := _hal.find_component_for_device("helm_control") as HelmControlComponent
		if helm:
			helm.set_speed_limiter(val)
			return true
		return true

	func toggle_inertia(enabled: bool) -> bool:
		if not can_control_flight():
			return false
		var helm := _hal.find_component_for_device("helm_control") as HelmControlComponent
		if helm:
			helm.toggle_inertia(enabled)
			return true
		return true

	func toggle_cruise(start: bool) -> bool:
		if not can_control_flight():
			return false
		var helm := _hal.find_component_for_device("helm_control") as HelmControlComponent
		if helm:
			helm.toggle_cruise(start)
			return true
		return true


class NavigationSubsystem extends RefCounted:
	var _hal: ShipHAL
	
	func _init(hal: ShipHAL) -> void:
		_hal = hal
		
	func get_status() -> Dictionary:
		var nav := _hal.find_component_for_device("nav_computer") as NavComputerComponent
		if nav:
			var telem := nav.get_telemetry()
			telem["is_operational"] = nav.is_online and _hal.is_device_powered("nav_computer")
			return telem
		var op := _hal.is_device_operational("nav_computer")
		return {
			"is_operational": op,
			"route_calculating": false,
			"dest_x": 0.0,
			"dest_y": 0.0,
			"est_distance": 0.0,
			"est_eta": 0.0,
			"hyperdrive_ready": false,
			"shadow_cones": op,
			"waypoints_active": op
		}

	func calculate_route(dest: Vector2) -> Dictionary:
		var nav := _hal.find_component_for_device("nav_computer") as NavComputerComponent
		if nav:
			return nav.calculate_route(dest)
		if not _hal.is_device_operational("nav_computer"):
			return {"success": false, "error": "NAV_COMPUTER_OFFLINE"}
		var dist := dest.length() * 100.0
		var eta := maxf(5.0, dist / 160.0)
		return {"success": true, "destination": dest, "distance": dist, "eta": eta}

	func get_hyperdrive_solution() -> Dictionary:
		var nav := _hal.find_component_for_device("nav_computer") as NavComputerComponent
		if nav:
			return nav.get_hyperdrive_solution()
		return {"ready": _hal.is_device_operational("nav_computer"), "vector": Vector3(0, 0, -1)}

	func is_operational() -> bool:
		var nav := _hal.find_component_for_device("nav_computer") as NavComputerComponent
		if nav:
			return nav.is_online and _hal.is_device_powered("nav_computer")
		return _hal.is_device_operational("nav_computer")


class SensorsSubsystem extends RefCounted:
	var _hal: ShipHAL
	
	func _init(hal: ShipHAL) -> void:
		_hal = hal
		
	func get_status() -> Dictionary:
		var s := _hal.find_component_for_device("sensors_matrix") as SensorsMatrixComponent
		if s:
			var telem := s.get_telemetry()
			telem["is_operational"] = s.is_online and _hal.is_device_powered("sensors_matrix")
			return telem
		var op := _hal.is_device_operational("sensors_matrix")
		return {
			"is_operational": op,
			"is_sweeping": op,
			"radar_range": 1000.0 if op else 0.0,
			"active_ping_range": 2000.0 if op else 0.0,
			"target_count": 0,
			"active_ping_ready": op
		}

	func get_contacts() -> Array[Dictionary]:
		var s := _hal.find_component_for_device("sensors_matrix") as SensorsMatrixComponent
		if s:
			return s.get_targets()
		return []

	func trigger_active_ping() -> Array:
		var s := _hal.find_component_for_device("sensors_matrix") as SensorsMatrixComponent
		if s:
			return s.trigger_active_ping()
		return []

	func toggle_sweep(enabled: bool) -> bool:
		var s := _hal.find_component_for_device("sensors_matrix") as SensorsMatrixComponent
		if s:
			s.toggle_sweep(enabled)
			return true
		return false

	func is_operational() -> bool:
		return bool(get_status().get("is_operational", false))


class CommsSubsystem extends RefCounted:
	var _hal: ShipHAL
	
	func _init(hal: ShipHAL) -> void:
		_hal = hal
		
	func get_status() -> Dictionary:
		var ant := _hal.find_component_for_device("antenna_array") as AntennaArrayComponent
		if ant:
			var telem := ant.get_telemetry()
			telem["is_operational"] = ant.is_online and _hal.is_device_powered("antenna_array")
			return telem
		var op := _hal.is_device_operational("antenna_array")
		return {
			"is_operational": op,
			"azimuth": 0.0,
			"is_scanning": false,
			"locked_freq": 0.0,
			"ew_connected": false,
			"visible_frequencies": [1420.0, 1920.0, 433.0] if op else []
		}

	func rotate_antenna(degrees: float) -> bool:
		var ant := _hal.find_component_for_device("antenna_array") as AntennaArrayComponent
		if ant:
			ant.rotate_antenna(degrees)
			return true
		return false

	func toggle_scan(enabled: bool) -> bool:
		var ant := _hal.find_component_for_device("antenna_array") as AntennaArrayComponent
		if ant:
			ant.toggle_scan(enabled)
			return true
		return false

	func lock_frequency(freq: float) -> bool:
		var ant := _hal.find_component_for_device("antenna_array") as AntennaArrayComponent
		if ant:
			return ant.lock_frequency(freq)
		return _hal.is_device_operational("antenna_array")

	func establish_ew_link(target_id: String) -> bool:
		var ant := _hal.find_component_for_device("antenna_array") as AntennaArrayComponent
		if ant:
			return ant.establish_ew_link(target_id)
		return false

	func disconnect_ew_link() -> void:
		var ant := _hal.find_component_for_device("antenna_array") as AntennaArrayComponent
		if ant:
			ant.disconnect_ew_link()

	func get_visible_frequencies() -> Array[float]:
		var ant := _hal.find_component_for_device("antenna_array") as AntennaArrayComponent
		if ant:
			return ant.get_frequencies()
		return [1420.0, 1920.0, 433.0] if _hal.is_device_operational("antenna_array") else []

	func is_operational() -> bool:
		return bool(get_status().get("is_operational", false))


class DefenseSubsystem extends RefCounted:
	var _hal: ShipHAL
	
	func _init(hal: ShipHAL) -> void:
		_hal = hal
		
	func get_status() -> Dictionary:
		var shld_sx := _hal.find_component_for_device("arm_sx_balancer") as ShieldBalancerComponent
		var arm := _hal.find_component_for_device("armory_defense") as ArmoryDefenseComponent
		
		var shld_dict := {"front": 100.0, "rear": 100.0, "left": 100.0, "right": 100.0}
		var dist := Vector2.ZERO
		var boost_ready := false
		
		if shld_sx:
			shld_dict = {
				"front": shld_sx.front_hp,
				"rear": shld_sx.rear_hp,
				"left": shld_sx.left_hp,
				"right": shld_sx.right_hp
			}
			dist = shld_sx.distribution
			boost_ready = (shld_sx.boost_cooldown <= 0.0)
			
		var laser_ch := 250.0
		var laser_mx := 250.0
		var can_f := false
		if arm:
			laser_ch = arm.laser_capacitor_current
			laser_mx = arm.laser_capacitor_max
			can_f = arm.can_fire_weapons()
			
		return {
			"shields": shld_dict,
			"distribution": dist,
			"boost_ready": boost_ready,
			"laser_charge": laser_ch,
			"laser_max": laser_mx,
			"can_fire": can_f,
			"is_operational": _hal.is_device_operational("armory_defense") or _hal.is_device_operational("arm_sx_balancer")
		}

	func set_shield_distribution(dist: Vector2) -> bool:
		var sx := _hal.find_component_for_device("arm_sx_balancer") as ShieldBalancerComponent
		var dx := _hal.find_component_for_device("arm_dx_balancer") as ShieldBalancerComponent
		if sx: sx.set_distribution(dist)
		if dx: dx.set_distribution(dist)
		return (sx != null or dx != null)

	func activate_shield_boost(quadrant: String) -> bool:
		var sx := _hal.find_component_for_device("arm_sx_balancer") as ShieldBalancerComponent
		var dx := _hal.find_component_for_device("arm_dx_balancer") as ShieldBalancerComponent
		var ok := false
		if sx and sx.activate_emergency_boost(quadrant): ok = true
		if dx and dx.activate_emergency_boost(quadrant): ok = true
		return ok

	func request_weapon_discharge(weapon_type: String) -> bool:
		var arm := _hal.find_component_for_device("armory_defense") as ArmoryDefenseComponent
		if arm:
			return arm.fire_weapon(weapon_type)
		return false

	func trigger_emergency_venting() -> bool:
		var arm := _hal.find_component_for_device("armory_defense") as ArmoryDefenseComponent
		if arm:
			return arm.trigger_emergency_venting()
		return false

	func is_operational() -> bool:
		return bool(get_status().get("is_operational", false))


class LifeSupportSubsystem extends RefCounted:
	var _hal: ShipHAL
	
	func _init(hal: ShipHAL) -> void:
		_hal = hal
		
	func get_status() -> Dictionary:
		if _hal._hardware_bus:
			return _hal._hardware_bus.get_life_support_status()
		return {"o2": 100.0, "co2": 0.0, "temp": 21.0, "status": "NOMINAL", "is_operational": true}

	func set_target_temp(target: float) -> bool:
		var heater := _hal.find_component_for_device("heater") as LifeSupportComponent
		if heater:
			heater.write_register("target_temp", target)
			return true
		if _hal._hardware_bus:
			for ls in _hal._hardware_bus.get_components_by_category("life_support"):
				if ls is LifeSupportComponent:
					ls.write_register("target_temp", target)
					return true
		return false

	func replace_filters() -> bool:
		var sc := _hal.find_component_for_device("scrubber") as LifeSupportComponent
		if sc:
			sc.replace_filters()
			return true
		return false

	func is_operational() -> bool:
		return bool(get_status().get("is_operational", false))


class LogisticsSubsystem extends RefCounted:
	var _hal: ShipHAL
	
	func _init(hal: ShipHAL) -> void:
		_hal = hal
		
	func get_status() -> Dictionary:
		var cargo_comp := _hal.find_component_for_device("cargo_handling") as CargoHandlingComponent
		var drone_st := _hal.find_component_for_device("dronestation") as DroneStationComponent
		
		var doors := false
		var clamps := true
		var refining := false
		var ref_prog := 0.0
		
		if cargo_comp:
			doors = cargo_comp.doors_open
			clamps = cargo_comp.magnetic_clamps_active
			refining = cargo_comp.is_refining
			ref_prog = cargo_comp.refine_progress
			
		var d_docked := true
		var d_bat := 240.0
		if drone_st:
			d_docked = drone_st.is_drone_docked
			d_bat = drone_st.drone_battery
			
		return {
			"doors_open": doors,
			"magnetic_clamps": clamps,
			"is_refining": refining,
			"refine_progress": ref_prog,
			"drone_docked": d_docked,
			"drone_battery": d_bat,
			"is_operational": _hal.is_device_operational("cargo_handling")
		}

	func toggle_cargo_doors(open: bool) -> bool:
		var c := _hal.find_component_for_device("cargo_handling") as CargoHandlingComponent
		if c:
			return c.set_doors(open)
		return false

	func toggle_magnetic_clamps(clamped: bool) -> bool:
		var c := _hal.find_component_for_device("cargo_handling") as CargoHandlingComponent
		if c:
			return c.set_magnetic_clamps(clamped)
		return false

	func charge_duct_drone(current_battery: float, delta: float) -> float:
		var dock := _hal.find_component_for_device("recharge_dock") as RechargeDockComponent
		if dock:
			return dock.charge_duct_drone(current_battery, delta)
		return current_battery

	func dock_eva_drone() -> bool:
		var st := _hal.find_component_for_device("dronestation") as DroneStationComponent
		if st:
			return st.dock_drone()
		return false

	func launch_eva_drone() -> bool:
		var st := _hal.find_component_for_device("dronestation") as DroneStationComponent
		if st:
			return st.launch_drone()
		return false

	func is_operational() -> bool:
		return bool(get_status().get("is_operational", false))


class CyberSubsystem extends RefCounted:
	var _hal: ShipHAL
	
	func _init(hal: ShipHAL) -> void:
		_hal = hal
		
	func get_status() -> Dictionary:
		var s := _hal.find_component_for_device("server_rack") as ServerRackComponent
		if s:
			var telem := s.get_telemetry()
			telem["is_operational"] = s.is_online and _hal.is_device_powered("server_rack")
			return telem
		var op := _hal.is_device_operational("server_rack")
		return {
			"is_operational": op,
			"firewall_integrity": 100.0 if op else 0.0,
			"firewall_active": op,
			"cpu_load": 10.0 if op else 0.0,
			"active_exploit": "",
			"crypto_ready": op
		}

	func start_exploit(name: String) -> bool:
		var s := _hal.find_component_for_device("server_rack") as ServerRackComponent
		if s:
			return s.start_exploit(name)
		return false

	func cancel_exploit() -> void:
		var s := _hal.find_component_for_device("server_rack") as ServerRackComponent
		if s:
			s.cancel_exploit()

	func execute_crypto_op(op: String) -> bool:
		var s := _hal.find_component_for_device("server_rack") as ServerRackComponent
		if s:
			return s.execute_crypt_operation(op)
		return _hal.is_device_operational("server_rack")

	func is_operational() -> bool:
		return bool(get_status().get("is_operational", false))


class OpticsSubsystem extends RefCounted:
	var _hal: ShipHAL
	
	func _init(hal: ShipHAL) -> void:
		_hal = hal
		
	func get_status() -> Dictionary:
		var cam := _hal.find_component_for_device("cam_array") as CamArrayComponent
		if cam:
			var telem := cam.get_telemetry()
			telem["is_operational"] = cam.is_online and _hal.is_device_powered("cam_array")
			return telem
		var op := _hal.is_device_operational("cam_array")
		return {
			"is_operational": op,
			"active_channel": 1,
			"camera_name": "CAM 01 [PRUA]",
			"feed_status": "ONLINE" if op else "NO SIGNAL",
			"floodlights_mask": 0,
			"floodlights_active": false
		}

	func set_active_channel(ch: int) -> bool:
		var cam := _hal.find_component_for_device("cam_array") as CamArrayComponent
		if cam:
			cam.set_active_camera(ch)
			return true
		return false

	func toggle_floodlight(ch: int, on: bool) -> bool:
		var cam := _hal.find_component_for_device("cam_array") as CamArrayComponent
		if cam:
			cam.toggle_floodlight(ch, on)
			return true
		return false

	func toggle_all_floodlights(on: bool) -> bool:
		var cam := _hal.find_component_for_device("cam_array") as CamArrayComponent
		if cam:
			cam.toggle_all_floodlights(on)
			return true
		return false

	func is_operational() -> bool:
		return bool(get_status().get("is_operational", false))
