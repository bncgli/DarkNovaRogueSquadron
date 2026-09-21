class_name DroneStationComponent
extends ShipPhysicalComponent

## Modello della baia ricarica e manutenzione drone di servizio EVA (dronestation).
## Gestisce docking, ricarica a induzione della batteria del drone EVA e rifornimento propellente.
## Se disalimentato o offline, il drone non si ricarica ad attracco e rischia la deriva nello spazio.

signal drone_docked(drone_id: String)
signal drone_launched(drone_id: String)
signal drone_battery_charged(current_charge: float, max_charge: float)

@export var is_drone_docked: bool = true
@export var drone_battery: float = 240.0 # secondi di autonomia
@export var drone_battery_max: float = 240.0
@export var charge_rate_per_sec: float = 12.0
@export var fuel_level: float = 100.0
@export var clamp_locked: bool = true

func _init(p_device_id: String = "dronestation", p_room_id: String = "pod_drone", p_category: String = "service") -> void:
	super._init(p_device_id, p_room_id, p_category)
	power_draw_nominal = 10.0

func initialize_registers() -> void:
	super.initialize_registers()
	registers["drone_docked"] = is_drone_docked
	registers["drone_battery"] = drone_battery
	registers["drone_battery_max"] = drone_battery_max
	registers["clamp_locked"] = clamp_locked
	registers["charging_active"] = (is_drone_docked and drone_battery < drone_battery_max)
	
	if not readonly_registers.has("drone_battery"):
		readonly_registers.append("drone_battery")
	if not readonly_registers.has("drone_battery_max"):
		readonly_registers.append("drone_battery_max")
	if not readonly_registers.has("charging_active"):
		readonly_registers.append("charging_active")

func read_register(reg_name: String) -> Variant:
	match reg_name:
		"drone_docked":
			return is_drone_docked
		"drone_battery":
			return drone_battery
		"drone_battery_max":
			return drone_battery_max
		"clamp_locked":
			return clamp_locked
		"charging_active":
			return is_drone_docked and (drone_battery < drone_battery_max) and is_online and power_ratio >= 0.3
		_:
			return super.read_register(reg_name)

func _on_register_written(reg_name: String, value: Variant) -> void:
	super._on_register_written(reg_name, value)
	match reg_name:
		"clamp_locked":
			clamp_locked = bool(value)
			registers["clamp_locked"] = clamp_locked

func dock_drone() -> bool:
	if not clamp_locked:
		clamp_locked = true
	is_drone_docked = true
	registers["drone_docked"] = true
	drone_docked.emit("ServiceDrone")
	return true

func launch_drone() -> bool:
	if not is_online or power_ratio < 0.3:
		return false
	is_drone_docked = false
	clamp_locked = false
	registers["drone_docked"] = false
	registers["clamp_locked"] = false
	drone_launched.emit("ServiceDrone")
	return true

func step(delta: float) -> void:
	if not is_online:
		power_draw_current = 0.0
		_sync_drone_station_registers()
		super.step(delta)
		return

	var needs_charge := is_drone_docked and (drone_battery < drone_battery_max)
	var draw := power_draw_nominal + (20.0 if needs_charge else 0.0)
	power_draw_current = draw

	if power_draw_current > 0.0:
		power_ratio = clampf(power_supplied / power_draw_current, 0.0, 1.0)
	else:
		power_ratio = 1.0

	var health_factor := health_percent / 100.0
	
	if needs_charge and power_ratio >= 0.3:
		var charge_amount := charge_rate_per_sec * power_ratio * health_factor * delta
		drone_battery = minf(drone_battery_max, drone_battery + charge_amount)
		drone_battery_charged.emit(drone_battery, drone_battery_max)

	_sync_drone_station_registers()
	super.step(delta)

func _sync_drone_station_registers() -> void:
	registers["drone_docked"] = is_drone_docked
	registers["drone_battery"] = drone_battery
	registers["drone_battery_max"] = drone_battery_max
	registers["clamp_locked"] = clamp_locked
	registers["charging_active"] = is_drone_docked and (drone_battery < drone_battery_max)

func get_telemetry() -> Dictionary:
	var telem := super.get_telemetry()
	telem["drone_docked"] = is_drone_docked
	telem["drone_battery"] = drone_battery
	telem["drone_battery_max"] = drone_battery_max
	telem["clamp_locked"] = clamp_locked
	telem["charging_active"] = is_drone_docked and (drone_battery < drone_battery_max)
	return telem
