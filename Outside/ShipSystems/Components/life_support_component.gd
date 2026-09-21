class_name LifeSupportComponent
extends ShipPhysicalComponent

## Modello del sistema di supporto vitale di bordo.
## Gestisce generazione ossigeno (O2), depurazione anidride carbonica (CO2),
## filtrazione atmosferica e regolazione termica della cabina.

@export var subsystem_type: String = "general" # "general", "scrubber", "heater", "serra"
@export var oxygen_level: float = 100.0 # percentuale 0..100%
@export var co2_level: float = 0.0 # percentuale 0..100%
@export var target_temp: float = 21.0 # gradi Celsius
@export var cabin_temp: float = 21.0
@export var filter_integrity: float = 100.0

func _init(p_device_id: String = "", p_room_id: String = "", p_category: String = "life_support") -> void:
	super._init(p_device_id, p_room_id, p_category)
	power_draw_nominal = 15.0
	var lower_id := p_device_id.to_lower()
	if lower_id.contains("scrubber") or lower_id.contains("co2") or lower_id.contains("purificatore"):
		subsystem_type = "scrubber"
		power_draw_nominal = 10.0
	elif lower_id.contains("heater") or lower_id.contains("caldaia"):
		subsystem_type = "heater"
		power_draw_nominal = 10.0
	elif lower_id.contains("serra") or lower_id.contains("idroponica"):
		subsystem_type = "serra"
		power_draw_nominal = 15.0

func initialize_registers() -> void:
	super.initialize_registers()
	registers["subsystem_type"] = subsystem_type
	registers["o2_level"] = oxygen_level
	registers["co2_level"] = co2_level
	registers["cabin_temp"] = cabin_temp
	registers["target_temp"] = target_temp
	registers["filter_integrity"] = filter_integrity
	if not readonly_registers.has("subsystem_type"):
		readonly_registers.append("subsystem_type")
	if not readonly_registers.has("o2_level"):
		readonly_registers.append("o2_level")
	if not readonly_registers.has("co2_level"):
		readonly_registers.append("co2_level")
	if not readonly_registers.has("cabin_temp"):
		readonly_registers.append("cabin_temp")
	if not readonly_registers.has("filter_integrity"):
		readonly_registers.append("filter_integrity")

func _on_register_written(reg_name: String, value: Variant) -> void:
	super._on_register_written(reg_name, value)
	if reg_name == "target_temp":
		target_temp = clampf(float(value), 10.0, 35.0)
		registers["target_temp"] = target_temp
		_sync_atmosphere_registers()
		telemetry_updated.emit(device_id, get_telemetry())

func step(delta: float) -> void:
	if not is_online:
		power_draw_current = 0.0
		# Degradazione passiva atmosfera quando spento
		oxygen_level = maxf(0.0, oxygen_level - 0.5 * delta)
		co2_level = minf(100.0, co2_level + 0.4 * delta)
		cabin_temp = move_toward(cabin_temp, ambient_temp, 0.1 * delta)
		_sync_atmosphere_registers()
		super.step(delta)
		return

	power_draw_current = power_draw_nominal
	if power_draw_current > 0.0:
		power_ratio = clampf(power_supplied / power_draw_current, 0.0, 1.0)
	else:
		power_ratio = 1.0

	var health_factor := health_percent / 100.0
	var filter_factor := filter_integrity / 100.0
	var scrub_efficiency := power_ratio * health_factor * filter_factor

	if scrub_efficiency > 0.2:
		oxygen_level = minf(100.0, oxygen_level + 1.5 * scrub_efficiency * delta)
		co2_level = maxf(0.0, co2_level - 1.2 * scrub_efficiency * delta)
		cabin_temp = move_toward(cabin_temp, target_temp, 0.4 * scrub_efficiency * delta)
		# Usura lenta dei filtri
		filter_integrity = maxf(0.0, filter_integrity - 0.002 * delta)
	else:
		# Potenza o filtri insufficienti
		oxygen_level = maxf(0.0, oxygen_level - 0.3 * delta)
		co2_level = minf(100.0, co2_level + 0.3 * delta)
		cabin_temp = move_toward(cabin_temp, ambient_temp, 0.05 * delta)

	_sync_atmosphere_registers()
	super.step(delta)

func _sync_atmosphere_registers() -> void:
	registers["o2_level"] = oxygen_level
	registers["co2_level"] = co2_level
	registers["cabin_temp"] = cabin_temp
	registers["target_temp"] = target_temp
	registers["filter_integrity"] = filter_integrity

func replace_filters() -> void:
	filter_integrity = 100.0
	registers["filter_integrity"] = filter_integrity

func get_telemetry() -> Dictionary:
	var telem := super.get_telemetry()
	telem["o2_level"] = oxygen_level
	telem["co2_level"] = co2_level
	telem["cabin_temp"] = cabin_temp
	telem["target_temp"] = target_temp
	telem["filter_integrity"] = filter_integrity
	return telem
