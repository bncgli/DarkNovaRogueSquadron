class_name AntennaArrayComponent
extends ShipPhysicalComponent

## Modello dell'antenna transceiver e array comunicazioni sub-spazio (antenna_array).
## Gestisce rotazione azimutale, tuning e ascolto frequenze radio, e stabilizzazione link EW per HackExploits.
## Quando disalimentato o offline, waterfall muta, richieste docking bloccate e link EW disconnesso.

signal azimuth_changed(deg: float)
signal frequency_locked(frequency: float)
signal ew_link_established(target_id: String)
signal ew_link_lost()
signal message_received(frequency: float, message: String)

@export var azimuth_deg: float = 0.0 # 0..360
@export var is_scanning: bool = false
@export var locked_frequency: float = 0.0
@export var ew_target_id: String = ""
@export var ew_link_active: bool = false

var visible_frequencies: Array[float] = [1420.0, 1920.0, 433.0, 2400.0]

func _init(p_device_id: String = "antenna_array", p_room_id: String = "comunicazioni", p_category: String = "comms") -> void:
	super._init(p_device_id, p_room_id, p_category)
	power_draw_nominal = 15.0

func initialize_registers() -> void:
	super.initialize_registers()
	registers["azimuth"] = azimuth_deg
	registers["is_scanning"] = is_scanning
	registers["locked_freq"] = locked_frequency
	registers["ew_connected"] = ew_link_active
	registers["ew_target"] = ew_target_id
	registers["visible_freq_count"] = visible_frequencies.size()
	
	if not readonly_registers.has("ew_connected"):
		readonly_registers.append("ew_connected")
	if not readonly_registers.has("ew_target"):
		readonly_registers.append("ew_target")
	if not readonly_registers.has("visible_freq_count"):
		readonly_registers.append("visible_freq_count")

func read_register(reg_name: String) -> Variant:
	match reg_name:
		"azimuth":
			return azimuth_deg
		"is_scanning":
			return is_scanning
		"locked_freq":
			return locked_frequency
		"ew_connected":
			return ew_link_active and is_online and power_ratio >= 0.3
		"ew_target":
			return ew_target_id
		"visible_freq_count":
			return visible_frequencies.size() if (is_online and power_ratio >= 0.2) else 0
		_:
			return super.read_register(reg_name)

func _on_register_written(reg_name: String, value: Variant) -> void:
	super._on_register_written(reg_name, value)
	match reg_name:
		"azimuth":
			rotate_antenna(float(value))
		"is_scanning":
			toggle_scan(bool(value))
		"locked_freq":
			lock_frequency(float(value))

func rotate_antenna(degrees: float) -> void:
	azimuth_deg = fposmod(degrees, 360.0)
	registers["azimuth"] = azimuth_deg
	azimuth_changed.emit(azimuth_deg)

func toggle_scan(enabled: bool) -> void:
	is_scanning = enabled
	registers["is_scanning"] = is_scanning

func lock_frequency(freq: float) -> bool:
	if not is_online or power_ratio < 0.2:
		return false
	locked_frequency = freq
	registers["locked_freq"] = locked_frequency
	frequency_locked.emit(locked_frequency)
	return true

func establish_ew_link(target_id: String) -> bool:
	if not is_online or power_ratio < 0.4:
		return false
	ew_target_id = target_id
	ew_link_active = true
	registers["ew_connected"] = true
	registers["ew_target"] = ew_target_id
	ew_link_established.emit(target_id)
	return true

func disconnect_ew_link() -> void:
	if ew_link_active:
		ew_link_active = false
		ew_target_id = ""
		registers["ew_connected"] = false
		registers["ew_target"] = ""
		ew_link_lost.emit()

func get_frequencies() -> Array[float]:
	if not is_online or power_ratio < 0.2:
		return []
	return visible_frequencies

func step(delta: float) -> void:
	if not is_online:
		power_draw_current = 0.0
		is_scanning = false
		if ew_link_active:
			disconnect_ew_link()
		_sync_comms_registers()
		super.step(delta)
		return

	# Calcolo consumo: base 15 MW + 15 MW se scanning + 35 MW se link EW
	var draw := power_draw_nominal
	if is_scanning:
		draw += 15.0
	if ew_link_active:
		draw += 35.0
		
	power_draw_current = draw
	if power_draw_current > 0.0:
		power_ratio = clampf(power_supplied / power_draw_current, 0.0, 1.0)
	else:
		power_ratio = 1.0

	var health_factor := health_percent / 100.0
	var is_operational := (power_ratio >= 0.3) and (health_factor > 0.1)

	if not is_operational and ew_link_active:
		disconnect_ew_link()

	if is_operational and is_scanning:
		rotate_antenna(azimuth_deg + 45.0 * power_ratio * delta)

	_sync_comms_registers()
	super.step(delta)

func _sync_comms_registers() -> void:
	registers["azimuth"] = azimuth_deg
	registers["is_scanning"] = is_scanning
	registers["locked_freq"] = locked_frequency
	registers["ew_connected"] = ew_link_active
	registers["ew_target"] = ew_target_id
	registers["visible_freq_count"] = visible_frequencies.size() if (is_online and power_ratio >= 0.2) else 0

func get_telemetry() -> Dictionary:
	var telem := super.get_telemetry()
	telem["azimuth"] = azimuth_deg
	telem["is_scanning"] = is_scanning
	telem["locked_freq"] = locked_frequency
	telem["ew_connected"] = ew_link_active
	telem["ew_target"] = ew_target_id
	telem["visible_frequencies"] = get_frequencies()
	return telem
