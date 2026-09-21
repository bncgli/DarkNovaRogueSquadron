class_name ShipPhysicalComponent
extends Node

## Componente fisico autonomo simulato all'interno delle stanze dell'astronave.
## Costituisce l'entità base su cui si basano monitoraggio, telemetria, registri I/O
## e bilanciamento carichi della nave.

signal telemetry_updated(device_id: String, data: Dictionary)
signal state_changed(device_id: String, new_state: String)
signal register_changed(device_id: String, reg_name: String, new_val: Variant)
signal alert_triggered(device_id: String, alert_type: String, message: String)

@export var device_id: String = ""
@export var component_name: String = ""
@export var room_id: String = ""
@export var category: String = "utility"

@export var power_draw_nominal: float = 10.0
@export var heat_max: float = 120.0
@export var ambient_temp: float = 20.0
@export var passive_cooling_rate: float = 0.5

var power_draw_current: float = 0.0
var power_supplied: float = 0.0
var power_ratio: float = 1.0
var heat_current: float = 20.0
var health_percent: float = 100.0
var is_online: bool = true
var status_string: String = "ONLINE"
var wear_rate: float = 0.0001

var registers: Dictionary = {}
var readonly_registers: Array[String] = [
	"status", "power_nominal", "power_draw", 
	"power_supplied", "power_ratio", "efficiency"
]

func _init(p_device_id: String = "", p_room_id: String = "", p_category: String = "utility") -> void:
	device_id = p_device_id
	room_id = p_room_id
	category = p_category
	heat_current = ambient_temp
	initialize_registers()

func _ready() -> void:
	if registers.is_empty():
		initialize_registers()

func initialize_registers() -> void:
	registers["status"] = status_string
	registers["health"] = health_percent
	registers["temp"] = heat_current
	registers["power_nominal"] = power_draw_nominal
	registers["power_draw"] = power_draw_current
	registers["power_supplied"] = power_supplied
	registers["power_ratio"] = power_ratio
	registers["power_target"] = 1.0
	registers["is_online"] = is_online
	registers["efficiency"] = 1.0

func read_register(reg_name: String) -> Variant:
	match reg_name:
		"power_nominal":
			return power_draw_nominal
		"power_draw":
			return power_draw_current
		"power_supplied":
			return power_supplied
		"power_ratio":
			return power_ratio
		"temp":
			return heat_current
		"health":
			return health_percent
		"status":
			return status_string
		"is_online":
			return is_online
		_:
			return registers.get(reg_name, null)

func write_register(reg_name: String, value: Variant) -> bool:
	if readonly_registers.has(reg_name):
		return false
	if not registers.has(reg_name):
		return false
	
	var current_val: Variant = registers[reg_name]
	var parsed_val: Variant = _parse_value_to_match(current_val, value)
	if parsed_val == null and value != null and typeof(current_val) != TYPE_STRING:
		return false
	
	registers[reg_name] = parsed_val
	_on_register_written(reg_name, parsed_val)
	register_changed.emit(device_id, reg_name, parsed_val)
	telemetry_updated.emit(device_id, get_telemetry())
	return true

func _parse_value_to_match(target_val: Variant, raw_val: Variant) -> Variant:
	if typeof(target_val) == typeof(raw_val):
		return raw_val
	if raw_val is String:
		var s := (raw_val as String).strip_edges()
		match typeof(target_val):
			TYPE_BOOL:
				if s.to_lower() in ["true", "1", "on", "yes"]:
					return true
				elif s.to_lower() in ["false", "0", "off", "no"]:
					return false
				return null
			TYPE_INT:
				if s.is_valid_int():
					return s.to_int()
				return null
			TYPE_FLOAT:
				if s.is_valid_float():
					return s.to_float()
				return null
			TYPE_STRING:
				return s
	return raw_val

func _on_register_written(reg_name: String, value: Variant) -> void:
	if reg_name == "is_online":
		set_online(bool(value))
	elif reg_name == "power_target":
		var target := clampf(float(value), 0.0, 2.0)
		registers["power_target"] = target
	elif reg_name == "health":
		var h := clampf(float(value), 0.0, 100.0)
		health_percent = h
		registers["health"] = h
		if h <= 0.0:
			status_string = "FAULT"
			is_online = false
			registers["is_online"] = false
			state_changed.emit(device_id, "FAULT")
		elif h < 25.0:
			status_string = "FAULT"
			state_changed.emit(device_id, "FAULT")
		elif is_online:
			status_string = "ONLINE"
			state_changed.emit(device_id, "ONLINE")
		registers["status"] = status_string
	elif reg_name == "temp":
		var t := clampf(float(value), -50.0, 1000.0)
		heat_current = t
		registers["temp"] = t
		if heat_current > heat_max:
			alert_triggered.emit(device_id, "OVERHEAT", "Surriscaldamento critico: %.1f C / %.1f C" % [heat_current, heat_max])

func step(delta: float) -> void:
	if not is_online:
		power_draw_current = 0.0
		heat_current = move_toward(heat_current, ambient_temp, passive_cooling_rate * delta * 2.0)
		if status_string != "SCRAM" and status_string != "DEPLETED" and status_string != "FAULT":
			status_string = "OFFLINE"
		_sync_base_registers()
		telemetry_updated.emit(device_id, get_telemetry())
		return

	if power_draw_current > 0.0:
		power_ratio = clampf(power_supplied / power_draw_current, 0.0, 1.0)
	else:
		power_ratio = 1.0

	var efficiency: float = (health_percent / 100.0) * power_ratio
	registers["efficiency"] = efficiency

	# Rilascia calore passivo proporzionale alla temperatura attuale
	heat_current = move_toward(heat_current, ambient_temp, passive_cooling_rate * delta)

	# Se surriscaldato, applica danno
	if heat_current > heat_max:
		var overheat_diff := heat_current - heat_max
		apply_damage(overheat_diff * 0.1 * delta)
		alert_triggered.emit(device_id, "OVERHEAT", "Surriscaldamento critico: %.1f C / %.1f C" % [heat_current, heat_max])
	
	if health_percent <= 0.0:
		health_percent = 0.0
		status_string = "FAULT"
		is_online = false
		state_changed.emit(device_id, "FAULT")
	elif health_percent < 25.0:
		status_string = "FAULT"
	elif status_string != "DEPLETED":
		status_string = "ONLINE"

	_sync_base_registers()
	telemetry_updated.emit(device_id, get_telemetry())

func _sync_base_registers() -> void:
	registers["status"] = status_string
	registers["health"] = health_percent
	registers["temp"] = heat_current
	registers["power_nominal"] = power_draw_nominal
	registers["power_draw"] = power_draw_current
	registers["power_supplied"] = power_supplied
	registers["power_ratio"] = power_ratio
	registers["is_online"] = is_online

func set_online(online: bool) -> void:
	if is_online == online:
		return
	is_online = online
	if is_online:
		status_string = "ONLINE"
	elif status_string != "SCRAM" and status_string != "DEPLETED" and status_string != "FAULT":
		status_string = "OFFLINE"
	registers["is_online"] = is_online
	registers["status"] = status_string
	if not is_online:
		power_draw_current = 0.0
		power_supplied = 0.0
		power_ratio = 0.0
		registers["power_draw"] = 0.0
		registers["power_supplied"] = 0.0
		registers["power_ratio"] = 0.0
	state_changed.emit(device_id, status_string)
	telemetry_updated.emit(device_id, get_telemetry())

func reboot() -> void:
	set_online(false)
	if is_inside_tree():
		get_tree().create_timer(0.2).timeout.connect(func(): set_online(true))
	else:
		set_online(true)

func apply_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	health_percent = maxf(0.0, health_percent - amount)
	registers["health"] = health_percent
	if health_percent <= 0.0:
		status_string = "FAULT"
		is_online = false
		registers["is_online"] = false
		registers["status"] = status_string
		state_changed.emit(device_id, "FAULT")

func repair(amount: float) -> void:
	if amount <= 0.0:
		return
	health_percent = minf(100.0, health_percent + amount)
	registers["health"] = health_percent
	if health_percent > 0.0 and status_string == "FAULT":
		status_string = "ONLINE"
		registers["status"] = status_string

func get_telemetry() -> Dictionary:
	return {
		"device_id": device_id,
		"component_name": component_name,
		"room_id": room_id,
		"category": category,
		"is_online": is_online,
		"status": status_string,
		"health": health_percent,
		"temp": heat_current,
		"heat_max": heat_max,
		"power_nominal": power_draw_nominal,
		"power_draw": power_draw_current,
		"power_supplied": power_supplied,
		"power_ratio": power_ratio,
		"registers": registers.duplicate(true)
	}
