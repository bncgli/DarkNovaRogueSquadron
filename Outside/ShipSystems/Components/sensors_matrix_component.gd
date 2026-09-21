class_name SensorsMatrixComponent
extends ShipPhysicalComponent

## Modello della matrice sensori Phased Array (sensors_matrix).
## Gestisce lo sweep radar passivo 360°, il tracciamento dei bersagli (asteroidi, navi, stazioni),
## e l'impulso ad alta potenza Ping Attivo (+120 MW).
## Se disalimentato o offline, il radar diventa cieco e il tracking si azzera.

signal sweep_completed(targets: Array)
signal active_ping_triggered(targets: Array)
signal storm_alert_detected(storm_data: Dictionary)

@export var is_sweeping: bool = true
@export var radar_range_nominal: float = 1000.0
@export var active_ping_range: float = 2000.0
@export var sweep_angle: float = 0.0 # 0..360 gradi
@export var sweep_frequency_hz: float = 12.0
@export var active_ping_cooldown: float = 0.0

var detected_targets: Array[Dictionary] = []
var _ping_power_timer: float = 0.0

func _init(p_device_id: String = "sensors_matrix", p_room_id: String = "matrice_sensori", p_category: String = "sensors") -> void:
	super._init(p_device_id, p_room_id, p_category)
	power_draw_nominal = 25.0

func initialize_registers() -> void:
	super.initialize_registers()
	registers["is_sweeping"] = is_sweeping
	registers["radar_range"] = radar_range_nominal
	registers["active_ping_range"] = active_ping_range
	registers["sweep_angle"] = sweep_angle
	registers["target_count"] = detected_targets.size()
	registers["active_ping_ready"] = (active_ping_cooldown <= 0.0)
	
	if not readonly_registers.has("radar_range"):
		readonly_registers.append("radar_range")
	if not readonly_registers.has("active_ping_range"):
		readonly_registers.append("active_ping_range")
	if not readonly_registers.has("sweep_angle"):
		readonly_registers.append("sweep_angle")
	if not readonly_registers.has("target_count"):
		readonly_registers.append("target_count")
	if not readonly_registers.has("active_ping_ready"):
		readonly_registers.append("active_ping_ready")

func read_register(reg_name: String) -> Variant:
	match reg_name:
		"is_sweeping":
			return is_sweeping
		"radar_range":
			return radar_range_nominal
		"active_ping_range":
			return active_ping_range
		"sweep_angle":
			return sweep_angle
		"target_count":
			return detected_targets.size()
		"active_ping_ready":
			return active_ping_cooldown <= 0.0 and is_online and power_ratio >= 0.5
		_:
			return super.read_register(reg_name)

func _on_register_written(reg_name: String, value: Variant) -> void:
	super._on_register_written(reg_name, value)
	if reg_name == "is_sweeping":
		is_sweeping = bool(value)
		registers["is_sweeping"] = is_sweeping

func toggle_sweep(enabled: bool) -> void:
	is_sweeping = enabled
	registers["is_sweeping"] = is_sweeping

func trigger_active_ping() -> Array:
	if not is_online or power_ratio < 0.5 or active_ping_cooldown > 0.0:
		return []
	
	# Richiede picco di potenza transitorio (120 MW per 1s)
	_ping_power_timer = 1.0
	active_ping_cooldown = 10.0
	
	# Emette evento ping
	active_ping_triggered.emit(detected_targets)
	return detected_targets

func set_contacts(contacts: Array) -> void:
	detected_targets.clear()
	for c in contacts:
		if c is Dictionary:
			detected_targets.append(c)
	registers["target_count"] = detected_targets.size()

func get_targets() -> Array[Dictionary]:
	if not is_online or power_ratio < 0.2:
		return []
	return detected_targets

func step(delta: float) -> void:
	if not is_online:
		power_draw_current = 0.0
		detected_targets.clear()
		_ping_power_timer = 0.0
		_sync_sensors_registers()
		super.step(delta)
		return

	# Potenza assorbita: base 25 MW + 15 MW se in sweep + 120 MW se ping attivo
	var target_draw := power_draw_nominal
	if is_sweeping:
		target_draw += 15.0
	if _ping_power_timer > 0.0:
		target_draw += 120.0
		_ping_power_timer = maxf(0.0, _ping_power_timer - delta)
		
	power_draw_current = target_draw
	if power_draw_current > 0.0:
		power_ratio = clampf(power_supplied / power_draw_current, 0.0, 1.0)
	else:
		power_ratio = 1.0

	var health_factor := health_percent / 100.0
	var is_operational := (power_ratio >= 0.3) and (health_factor > 0.1)

	if is_operational:
		if is_sweeping:
			sweep_angle = fmod(sweep_angle + 60.0 * power_ratio * delta, 360.0)
	else:
		detected_targets.clear()

	if active_ping_cooldown > 0.0:
		active_ping_cooldown = maxf(0.0, active_ping_cooldown - delta)

	_sync_sensors_registers()
	super.step(delta)

func _sync_sensors_registers() -> void:
	registers["is_sweeping"] = is_sweeping
	registers["radar_range"] = radar_range_nominal
	registers["active_ping_range"] = active_ping_range
	registers["sweep_angle"] = sweep_angle
	registers["target_count"] = detected_targets.size()
	registers["active_ping_ready"] = (active_ping_cooldown <= 0.0)

func get_telemetry() -> Dictionary:
	var telem := super.get_telemetry()
	telem["is_sweeping"] = is_sweeping
	telem["radar_range"] = radar_range_nominal
	telem["active_ping_range"] = active_ping_range
	telem["sweep_angle"] = sweep_angle
	telem["target_count"] = detected_targets.size()
	telem["active_ping_ready"] = (active_ping_cooldown <= 0.0)
	telem["contacts"] = get_targets()
	return telem
