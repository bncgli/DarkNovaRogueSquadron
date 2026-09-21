class_name RechargeDockComponent
extends ShipPhysicalComponent

## Modello del nodo ricarica e connessione Duct Drone interno (recharge_dock).
## Permette la ricarica rapida della batteria del Duct Drone (+8.0% / sec) e il bootstrap di recupero.
## Se disalimentato o offline, il drone non si ricarica e rimangono bloccate le riparazioni interne.

signal duct_drone_connected()
signal duct_drone_recharged(battery_percent: float)

@export var is_docked: bool = true
@export var battery_charge_rate_pct: float = 8.0 # % al secondo
@export var emergency_recovery_available: bool = true

func _init(p_device_id: String = "recharge_dock", p_room_id: String = "cargo", p_category: String = "engineering") -> void:
	super._init(p_device_id, p_room_id, p_category)
	power_draw_nominal = 10.0

func initialize_registers() -> void:
	super.initialize_registers()
	registers["is_docked"] = is_docked
	registers["charging_rate"] = battery_charge_rate_pct
	registers["recovery_available"] = emergency_recovery_available
	
	if not readonly_registers.has("is_docked"):
		readonly_registers.append("is_docked")
	if not readonly_registers.has("charging_rate"):
		readonly_registers.append("charging_rate")
	if not readonly_registers.has("recovery_available"):
		readonly_registers.append("recovery_available")

func read_register(reg_name: String) -> Variant:
	match reg_name:
		"is_docked":
			return is_docked
		"charging_rate":
			return battery_charge_rate_pct
		"recovery_available":
			return emergency_recovery_available and is_online and power_ratio >= 0.3
		_:
			return super.read_register(reg_name)

func charge_duct_drone(current_battery_pct: float, delta: float) -> float:
	if not is_online or power_ratio < 0.3:
		return current_battery_pct
	
	var health_factor := health_percent / 100.0
	var gain := battery_charge_rate_pct * power_ratio * health_factor * delta
	var new_battery := minf(100.0, current_battery_pct + gain)
	duct_drone_recharged.emit(new_battery)
	return new_battery

func step(delta: float) -> void:
	if not is_online:
		power_draw_current = 0.0
		_sync_dock_registers()
		super.step(delta)
		return

	power_draw_current = power_draw_nominal
	if power_draw_current > 0.0:
		power_ratio = clampf(power_supplied / power_draw_current, 0.0, 1.0)
	else:
		power_ratio = 1.0

	_sync_dock_registers()
	super.step(delta)

func _sync_dock_registers() -> void:
	registers["is_docked"] = is_docked
	registers["charging_rate"] = battery_charge_rate_pct
	registers["recovery_available"] = emergency_recovery_available and is_online and power_ratio >= 0.3

func get_telemetry() -> Dictionary:
	var telem := super.get_telemetry()
	telem["is_docked"] = is_docked
	telem["charging_rate"] = battery_charge_rate_pct
	telem["recovery_available"] = emergency_recovery_available and is_online and power_ratio >= 0.3
	return telem
