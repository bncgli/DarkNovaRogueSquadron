class_name ThrusterComponent
extends ShipPhysicalComponent

## Modello di propulsore fisico (principale di navigazione o manovra RCS).
## Converte energia elettrica e comandi di throttle in spinta newtoniana effettiva.

@export var thruster_type: String = "main" # "main", "rcs_pitch", "rcs_yaw", "rcs_roll", "maneuver"
@export var max_thrust: float = 35.0 # kN o unita' di accelerazione lineare
@export var thrust_axis: Vector3 = Vector3(0, 0, -1)

var current_thrust: float = 0.0
var throttle_target: float = 0.0
var heat_generation_mult: float = 1.8

func _init(p_device_id: String = "", p_room_id: String = "", p_category: String = "propulsion") -> void:
	super._init(p_device_id, p_room_id, p_category)
	power_draw_nominal = 30.0

func initialize_registers() -> void:
	super.initialize_registers()
	registers["thruster_type"] = thruster_type
	registers["max_thrust"] = max_thrust
	registers["throttle_target"] = throttle_target
	registers["throttle"] = throttle_target
	registers["thrust_output"] = current_thrust
	if not readonly_registers.has("throttle"):
		readonly_registers.append("throttle")
	if not readonly_registers.has("thrust_output"):
		readonly_registers.append("thrust_output")
	if not readonly_registers.has("max_thrust"):
		readonly_registers.append("max_thrust")

func read_register(reg_name: String) -> Variant:
	match reg_name:
		"throttle":
			return throttle_target
		"thrust_output":
			return current_thrust
		_:
			return super.read_register(reg_name)

func _on_register_written(reg_name: String, value: Variant) -> void:
	super._on_register_written(reg_name, value)
	if reg_name == "throttle_target" or reg_name == "throttle":
		set_throttle(float(value))

func set_throttle(target: float) -> void:
	throttle_target = clampf(target, -1.0, 1.0)
	registers["throttle_target"] = throttle_target
	registers["throttle"] = throttle_target

func step(delta: float) -> void:
	if not is_online:
		current_thrust = 0.0
		power_draw_current = 0.0
		registers["thrust_output"] = 0.0
		registers["throttle"] = 0.0
		super.step(delta)
		return

	# La potenza richiesta scala con il valore assoluto del throttle
	power_draw_current = power_draw_nominal * absf(throttle_target)
	
	# Calcola power ratio tramite la classe base
	if power_draw_current > 0.0:
		power_ratio = clampf(power_supplied / power_draw_current, 0.0, 1.0)
	else:
		power_ratio = 1.0

	# Penalità termica se temperatura vicina al limite
	var thermal_efficiency: float = 1.0
	if heat_current > (heat_max * 0.75):
		thermal_efficiency = maxf(0.2, 1.0 - ((heat_current - heat_max * 0.75) / (heat_max * 0.25)))

	var health_factor: float = health_percent / 100.0
	current_thrust = max_thrust * throttle_target * health_factor * power_ratio * thermal_efficiency
	registers["thrust_output"] = current_thrust
	registers["throttle"] = throttle_target

	# Generazione calore dal lavoro del propulsore
	heat_current += absf(throttle_target) * heat_generation_mult * delta

	super.step(delta)

func get_telemetry() -> Dictionary:
	var telem := super.get_telemetry()
	telem["thruster_type"] = thruster_type
	telem["max_thrust"] = max_thrust
	telem["throttle_target"] = throttle_target
	telem["throttle"] = throttle_target
	telem["thrust_output"] = current_thrust
	return telem
