class_name ShipHardwareBus
extends Node

## Bus hardware centralizzato per Dark Nova: Rogue Squadron.
## Disaccoppia la comunicazione tra i componenti fisici delle stanze, gestisce la telemetria,
## instrada pacchetti di controllo ed esegue il bilanciamento dinamico di Power Grid e Thermal Grid.

signal device_registered(device_id: String, component: ShipPhysicalComponent)
signal device_unregistered(device_id: String)
signal telemetry_received(device_id: String, telemetry: Dictionary)
signal power_grid_balanced(total_generated: float, total_demanded: float, net_balance: float)
signal thermal_grid_updated(total_heat: float, avg_temp: float)
signal blackout_state_changed(is_blackout: bool, power_ratio: float)
signal command_dispatched(device_id: String, command: String, result: Dictionary)

var _components: Dictionary = {} # device_id -> ShipPhysicalComponent
var _rooms_index: Dictionary = {} # room_id -> Array[ShipPhysicalComponent]
var _categories_index: Dictionary = {} # category -> Array[ShipPhysicalComponent]
var _telemetry_cache: Dictionary = {} # device_id -> Dictionary

var total_generated_mw: float = 0.0
var total_demanded_mw: float = 0.0
var net_balance_mw: float = 0.0
var power_ratio: float = 1.0
var is_blackout: bool = false

var total_heat: float = 0.0
var avg_temperature: float = 20.0

@export var active_simulation: bool = false

func _physics_process(delta: float) -> void:
	if active_simulation:
		step(delta)

## Registra un componente fisico sul bus hardware
func register_component(component: ShipPhysicalComponent) -> void:
	if component == null or component.device_id.is_empty():
		return
	
	var dev_id := component.device_id
	if _components.has(dev_id):
		unregister_component(dev_id)
		
	_components[dev_id] = component
	
	# Indicizzazione per stanza
	var room := component.room_id
	if not _rooms_index.has(room):
		_rooms_index[room] = []
	_rooms_index[room].append(component)
	
	# Indicizzazione per categoria
	var cat := component.category
	if not _categories_index.has(cat):
		_categories_index[cat] = []
	_categories_index[cat].append(component)
	
	# Connessione segnali
	if not component.telemetry_updated.is_connected(_on_component_telemetry):
		component.telemetry_updated.connect(_on_component_telemetry)
	
	_telemetry_cache[dev_id] = component.get_telemetry()
	device_registered.emit(dev_id, component)

## Disconnette e rimuove un componente dal bus
func unregister_component(device_id: String) -> bool:
	if not _components.has(device_id):
		return false
	
	var comp: ShipPhysicalComponent = _components[device_id]
	if comp.telemetry_updated.is_connected(_on_component_telemetry):
		comp.telemetry_updated.disconnect(_on_component_telemetry)
		
	if _rooms_index.has(comp.room_id):
		_rooms_index[comp.room_id].erase(comp)
		if _rooms_index[comp.room_id].is_empty():
			_rooms_index.erase(comp.room_id)
			
	if _categories_index.has(comp.category):
		_categories_index[comp.category].erase(comp)
		if _categories_index[comp.category].is_empty():
			_categories_index.erase(comp.category)
			
	_components.erase(device_id)
	_telemetry_cache.erase(device_id)
	device_unregistered.emit(device_id)
	return true

## Svuota tutti i componenti registrati
func clear_all_components(free_components: bool = true) -> void:
	var comps: Array = _components.values().duplicate()
	for comp: ShipPhysicalComponent in comps:
		if is_instance_valid(comp):
			unregister_component(comp.device_id)
			if free_components:
				comp.free()
	_components.clear()
	_rooms_index.clear()
	_categories_index.clear()
	_telemetry_cache.clear()

## Carica e istanzia tutti i componenti da uno ShipBlueprint
func load_from_blueprint(blueprint: ShipBlueprint) -> void:
	clear_all_components()
	if blueprint == null:
		return
	
	var comps := blueprint.instantiate_physical_components()
	for comp in comps:
		add_child(comp)
		register_component(comp)

func get_component(device_id: String) -> ShipPhysicalComponent:
	return _components.get(device_id, null)

func has_component(device_id: String) -> bool:
	return _components.has(device_id)

func get_all_components() -> Array[ShipPhysicalComponent]:
	var res: Array[ShipPhysicalComponent] = []
	for c in _components.values():
		if c is ShipPhysicalComponent:
			res.append(c)
	return res

func get_components_in_room(room_id: String) -> Array[ShipPhysicalComponent]:
	var res: Array[ShipPhysicalComponent] = []
	var list: Array = _rooms_index.get(room_id, [])
	for c in list:
		if c is ShipPhysicalComponent:
			res.append(c)
	return res

func get_components_by_category(category: String) -> Array[ShipPhysicalComponent]:
	var res: Array[ShipPhysicalComponent] = []
	var list: Array = _categories_index.get(category, [])
	for c in list:
		if c is ShipPhysicalComponent:
			res.append(c)
	return res

func get_all_device_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in _components.keys():
		ids.append(str(k))
	return ids

func get_all_room_ids() -> Array[String]:
	var rooms: Array[String] = []
	for k in _rooms_index.keys():
		rooms.append(str(k))
	return rooms

## Instradamento pacchetto di controllo o comando a basso livello verso un componente
func dispatch_command(device_id: String, command: String, args: Array = []) -> Dictionary:
	if not _components.has(device_id):
		var err_res := {"success": false, "error": "Device not found: %s" % device_id}
		command_dispatched.emit(device_id, command, err_res)
		return err_res
		
	var comp: ShipPhysicalComponent = _components[device_id]
	var res_dict: Dictionary = {"success": false}
	
	match command:
		"read", "read_register", "get":
			if args.is_empty():
				res_dict = {"success": false, "error": "Missing register name"}
			else:
				var reg_name := str(args[0])
				var val = comp.read_register(reg_name)
				res_dict = {"success": true, "result": val, "register": reg_name}
		"write", "write_register", "set":
			if args.size() < 2:
				res_dict = {"success": false, "error": "Missing register name or value"}
			else:
				var reg_name := str(args[0])
				var ok := comp.write_register(reg_name, args[1])
				res_dict = {"success": ok, "result": ok, "register": reg_name}
		"reboot":
			comp.reboot()
			res_dict = {"success": true, "result": "rebooting"}
		"set_online":
			var online_target := bool(args[0]) if not args.is_empty() else true
			comp.set_online(online_target)
			res_dict = {"success": true, "result": comp.is_online}
		_:
			if comp.has_method(command):
				var call_res = comp.callv(command, args)
				res_dict = {"success": true, "result": call_res}
			else:
				res_dict = {"success": false, "error": "Unknown command '%s' on %s" % [command, device_id]}
				
	command_dispatched.emit(device_id, command, res_dict)
	return res_dict

## Ciclo di simulazione e bilanciamento carichi su Power Grid e Thermal Grid
func step(delta: float) -> void:
	# 1. Bilanciamento Power Grid (calcola generazione e distribuisce potenza)
	_balance_power_grid(delta)
	
	# 2. Esecuzione tick autonomo per ogni componente con la potenza fornita
	for comp: ShipPhysicalComponent in _components.values():
		if is_instance_valid(comp):
			comp.step(delta)
			
	# 3. Bilanciamento Thermal Grid
	_balance_thermal_grid(delta)

func _balance_power_grid(delta: float) -> void:
	var total_generated: float = 0.0
	var total_demanded: float = 0.0
	var batteries: Array[BatteryComponent] = []
	var consumers: Array[ShipPhysicalComponent] = []
	
	for comp: ShipPhysicalComponent in _components.values():
		if not is_instance_valid(comp):
			continue
			
		if comp is ReactorComponent:
			if comp.is_online and comp.status_string != "SCRAM" and comp.status_string != "DEPLETED":
				total_generated += comp.power_output_current
		elif comp is BatteryComponent:
			batteries.append(comp)
		else:
			var demand: float = comp.power_draw_current if comp.power_draw_current > 0.0 else comp.power_draw_nominal
			if comp.is_online and demand > 0.0:
				total_demanded += demand
				consumers.append(comp)
			else:
				comp.power_supplied = 0.0
				
	total_generated_mw = total_generated
	total_demanded_mw = total_demanded
	net_balance_mw = total_generated - total_demanded
	
	if net_balance_mw >= 0.0:
		# Sovrappiù o pareggio: tutti i consumatori ricevono 100%
		for c in consumers:
			var dem: float = c.power_draw_current if c.power_draw_current > 0.0 else c.power_draw_nominal
			c.power_supplied = dem
			c.power_ratio = 1.0
			
		# Carica batterie con l'eccesso
		var surplus := net_balance_mw
		for b in batteries:
			if surplus <= 0.0:
				break
			var absorbed := b.charge(surplus, delta)
			surplus = maxf(0.0, surplus - absorbed)
			
		power_ratio = 1.0
		if is_blackout:
			is_blackout = false
			blackout_state_changed.emit(false, power_ratio)
	else:
		# Deficit: tenta scarica batterie
		var deficit := absf(net_balance_mw)
		var battery_support := 0.0
		for b in batteries:
			if deficit <= 0.0:
				break
			var discharged := b.discharge(deficit, delta)
			battery_support += discharged
			deficit = maxf(0.0, deficit - discharged)
			
		var effective_available := total_generated + battery_support
		power_ratio = clampf(effective_available / maxf(total_demanded, 0.001), 0.0, 1.0)
		
		# Distribuzione proporzionale o razionata
		for c in consumers:
			c.power_supplied = c.power_draw_current * power_ratio
			
		var blackout_now := power_ratio < 0.5
		if blackout_now != is_blackout:
			is_blackout = blackout_now
			blackout_state_changed.emit(is_blackout, power_ratio)
			
	power_grid_balanced.emit(total_generated_mw, total_demanded_mw, net_balance_mw)

func _balance_thermal_grid(delta: float) -> void:
	var total_h: float = 0.0
	var coolers: Array[CoolingComponent] = []
	var count: int = 0
	
	for comp: ShipPhysicalComponent in _components.values():
		if not is_instance_valid(comp):
			continue
		total_h += comp.heat_current
		count += 1
		if comp is CoolingComponent and comp.is_online:
			coolers.append(comp)
			
	total_heat = total_h
	avg_temperature = total_h / maxf(count, 1.0)
	
	# Raffreddamento attivo dai cooler sui componenti surriscaldati
	if not coolers.is_empty():
		for comp: ShipPhysicalComponent in _components.values():
			if not is_instance_valid(comp) or comp is CoolingComponent:
				continue
			if comp.heat_current > comp.ambient_temp + 10.0:
				var excess := comp.heat_current - comp.ambient_temp
				for cooler in coolers:
					if excess <= 0.0:
						break
					var cooled := cooler.dissipate_heat(excess, delta)
					comp.heat_current = maxf(comp.ambient_temp, comp.heat_current - cooled)
					excess = maxf(0.0, excess - cooled)
					
	thermal_grid_updated.emit(total_heat, avg_temperature)

func _on_component_telemetry(device_id: String, telem: Dictionary) -> void:
	_telemetry_cache[device_id] = telem
	telemetry_received.emit(device_id, telem)

## Ritorna l'efficienza propulsiva complessiva della nave calcolata dai thruster pesata per la spinta massima
func get_propulsion_efficiency() -> float:
	var thrusters := get_components_by_category("propulsion")
	if thrusters.is_empty():
		return 1.0 # fallback di sicurezza
		
	var total_nominal_thrust: float = 0.0
	var total_avail_thrust: float = 0.0
	var online_count: int = 0
	for t in thrusters:
		if t is ThrusterComponent:
			total_nominal_thrust += t.max_thrust
			if t.is_online:
				total_avail_thrust += t.max_thrust * (t.health_percent / 100.0) * t.power_ratio
				online_count += 1
			
	if total_nominal_thrust <= 0.0:
		return 1.0
	if online_count == 0:
		return 0.0
	return clampf(total_avail_thrust / total_nominal_thrust, 0.0, 1.0)

## Ritorna la spinta totale teorica disponibile
func get_total_available_thrust() -> float:
	var thrusters := get_components_by_category("propulsion")
	var total: float = 0.0
	for t in thrusters:
		if t is ThrusterComponent and t.is_online:
			total += t.max_thrust * (t.health_percent / 100.0) * t.power_ratio
	return total

## Ritorna lo stato aggregato del supporto vitale
func get_life_support_status() -> Dictionary:
	var ls_list := get_components_by_category("life_support")
	if ls_list.is_empty():
		return {"o2": 100.0, "co2": 0.0, "temp": 21.0, "target_temp": 21.0, "status": "NOMINAL"}
		
	var o2_sum := 0.0
	var co2_sum := 0.0
	var temp_sum := 0.0
	var target_temp_sum := 0.0
	var online_count := 0
	
	for ls in ls_list:
		if ls is LifeSupportComponent:
			o2_sum += ls.oxygen_level
			co2_sum += ls.co2_level
			temp_sum += ls.cabin_temp
			target_temp_sum += ls.target_temp
			if ls.is_online:
				online_count += 1
				
	var n := float(ls_list.size())
	return {
		"o2": o2_sum / n,
		"co2": co2_sum / n,
		"temp": temp_sum / n,
		"target_temp": target_temp_sum / n,
		"online_count": online_count,
		"total_count": ls_list.size(),
		"status": "NOMINAL" if online_count > 0 else "OFFLINE"
	}

## Ritorna lo stato aggregato della griglia energetica
func get_grid_telemetry() -> Dictionary:
	var battery_charge := 0.0
	var battery_max := 0.0
	for comp in _components.values():
		if comp is BatteryComponent:
			battery_charge += comp.charge_current
			battery_max += comp.capacity_max
			
	return {
		"generated_mw": total_generated_mw,
		"demanded_mw": total_demanded_mw,
		"net_balance_mw": net_balance_mw,
		"power_ratio": power_ratio,
		"is_blackout": is_blackout,
		"battery_charge_mj": battery_charge,
		"battery_capacity_mj": battery_max,
		"total_heat": total_heat,
		"avg_temp": avg_temperature,
		"devices_count": _components.size()
	}
