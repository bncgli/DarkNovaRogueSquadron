class_name HelmControlComponent
extends ShipPhysicalComponent

## Componente della consolle di pilotaggio e plancia comando (helm_control).
## Funziona come interfaccia diegetica tra i comandi dell'equipaggio/pilota e l'HAL.
## Quando disalimentato o offline, disabilita il controllo manuale WASD/QE.

signal flight_controls_toggled(enabled: bool)

@export var can_control_flight: bool = true
@export var input_responsiveness: float = 1.0
@export var inertia_damping_enabled: bool = true
@export var cruise_drive_enabled: bool = false
@export var speed_limiter: float = 1.0 # 0.1 .. 2.0

func _init(p_device_id: String = "helm_control", p_room_id: String = "ponte_comando", p_category: String = "command") -> void:
	super._init(p_device_id, p_room_id, p_category)
	power_draw_nominal = 15.0

func initialize_registers() -> void:
	super.initialize_registers()
	registers["can_control"] = can_control_flight
	registers["input_responsiveness"] = input_responsiveness
	registers["inertia_damping"] = inertia_damping_enabled
	registers["cruise_drive"] = cruise_drive_enabled
	registers["speed_limiter"] = speed_limiter
	
	if not readonly_registers.has("can_control"):
		readonly_registers.append("can_control")
	if not readonly_registers.has("input_responsiveness"):
		readonly_registers.append("input_responsiveness")

func read_register(reg_name: String) -> Variant:
	match reg_name:
		"can_control":
			return can_control_flight
		"input_responsiveness":
			return input_responsiveness
		"inertia_damping":
			return inertia_damping_enabled
		"cruise_drive":
			return cruise_drive_enabled
		"speed_limiter":
			return speed_limiter
		_:
			return super.read_register(reg_name)

func _on_register_written(reg_name: String, value: Variant) -> void:
	super._on_register_written(reg_name, value)
	match reg_name:
		"inertia_damping":
			inertia_damping_enabled = bool(value)
			registers["inertia_damping"] = inertia_damping_enabled
		"cruise_drive":
			cruise_drive_enabled = bool(value)
			registers["cruise_drive"] = cruise_drive_enabled
		"speed_limiter":
			speed_limiter = clampf(float(value), 0.1, 2.0)
			registers["speed_limiter"] = speed_limiter

func set_speed_limiter(val: float) -> void:
	speed_limiter = clampf(val, 0.1, 2.0)
	registers["speed_limiter"] = speed_limiter

func toggle_inertia(enabled: bool) -> void:
	inertia_damping_enabled = enabled
	registers["inertia_damping"] = inertia_damping_enabled

func toggle_cruise(enabled: bool) -> void:
	cruise_drive_enabled = enabled
	registers["cruise_drive"] = cruise_drive_enabled

func set_online(online: bool) -> void:
	super.set_online(online)
	if not is_online:
		can_control_flight = false
		input_responsiveness = 0.0
		cruise_drive_enabled = false
	else:
		can_control_flight = (health_percent > 10.0)
		input_responsiveness = clampf(health_percent / 100.0, 0.0, 1.0)
	_sync_helm_registers()
	flight_controls_toggled.emit(can_control_flight)

func step(delta: float) -> void:
	var prev_can_control := can_control_flight
	
	if not is_online:
		power_draw_current = 0.0
		can_control_flight = false
		input_responsiveness = 0.0
		cruise_drive_enabled = false
		_sync_helm_registers()
		if prev_can_control != can_control_flight:
			flight_controls_toggled.emit(false)
		super.step(delta)
		return

	power_draw_current = power_draw_nominal
	if power_draw_current > 0.0:
		power_ratio = clampf(power_supplied / power_draw_current, 0.0, 1.0)
	else:
		power_ratio = 1.0

	var health_factor := health_percent / 100.0
	can_control_flight = (power_ratio >= 0.4) and (health_percent > 10.0)
	input_responsiveness = clampf(power_ratio * health_factor, 0.0, 1.0)
	
	if not can_control_flight and cruise_drive_enabled:
		cruise_drive_enabled = false

	if prev_can_control != can_control_flight:
		flight_controls_toggled.emit(can_control_flight)

	_sync_helm_registers()
	super.step(delta)

func _sync_helm_registers() -> void:
	registers["can_control"] = can_control_flight
	registers["input_responsiveness"] = input_responsiveness
	registers["inertia_damping"] = inertia_damping_enabled
	registers["cruise_drive"] = cruise_drive_enabled
	registers["speed_limiter"] = speed_limiter

func get_telemetry() -> Dictionary:
	var telem := super.get_telemetry()
	telem["can_control"] = can_control_flight
	telem["input_responsiveness"] = input_responsiveness
	telem["inertia_damping"] = inertia_damping_enabled
	telem["cruise_drive"] = cruise_drive_enabled
	telem["speed_limiter"] = speed_limiter
	return telem
