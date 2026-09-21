class_name CamArrayComponent
extends ShipPhysicalComponent

## Modello dell'array telecamere esterne e fari scafo (cam_array).
## Gestisce i 6 canali ottici (Prua, Poppa, Babordo, Tribordo, Dorsale, Ventrale)
## e i proiettori luminosi esterni per illuminare relitti e asteroidi.
## Se disalimentato o offline, canali su 'NO SIGNAL' e fari spenti.

signal active_camera_changed(channel: int)
signal floodlights_toggled(channel: int, enabled: bool)

@export var active_camera_channel: int = 1 # 1..6
@export var floodlights_mask: int = 0 # bitmask o bool per canale

var camera_names: Array[String] = [
	"CAM 01 [PRUA]", "CAM 02 [POPPA]", "CAM 03 [BABORDO]", 
	"CAM 04 [TRIBORDO]", "CAM 05 [DORSALE]", "CAM 06 [VENTRALE]"
]

func _init(p_device_id: String = "cam_array", p_room_id: String = "esterno", p_category: String = "sensors") -> void:
	super._init(p_device_id, p_room_id, p_category)
	power_draw_nominal = 5.0

func initialize_registers() -> void:
	super.initialize_registers()
	registers["active_channel"] = active_camera_channel
	registers["floodlights_mask"] = floodlights_mask
	registers["feed_status"] = get_feed_status()
	registers["floodlights_active"] = (floodlights_mask > 0)
	
	if not readonly_registers.has("feed_status"):
		readonly_registers.append("feed_status")

func read_register(reg_name: String) -> Variant:
	match reg_name:
		"active_channel":
			return active_camera_channel
		"floodlights_mask":
			return floodlights_mask
		"feed_status":
			return get_feed_status()
		"floodlights_active":
			return floodlights_mask > 0 and is_online and power_ratio >= 0.3
		_:
			return super.read_register(reg_name)

func _on_register_written(reg_name: String, value: Variant) -> void:
	super._on_register_written(reg_name, value)
	match reg_name:
		"active_channel":
			set_active_camera(int(value))
		"floodlights_mask":
			floodlights_mask = int(value)
			registers["floodlights_mask"] = floodlights_mask
			registers["floodlights_active"] = (floodlights_mask > 0)
		"floodlights_active":
			toggle_all_floodlights(bool(value))

func set_active_camera(channel: int) -> void:
	active_camera_channel = clampi(channel, 1, 6)
	registers["active_channel"] = active_camera_channel
	active_camera_changed.emit(active_camera_channel)

func toggle_all_floodlights(enabled: bool) -> void:
	floodlights_mask = 0b111111 if enabled else 0
	registers["floodlights_mask"] = floodlights_mask
	registers["floodlights_active"] = enabled
	floodlights_toggled.emit(0, enabled)

func toggle_floodlight(channel: int, on: bool) -> void:
	var bit := 1 << (channel - 1)
	if on:
		floodlights_mask |= bit
	else:
		floodlights_mask &= ~bit
	registers["floodlights_mask"] = floodlights_mask
	registers["floodlights_active"] = (floodlights_mask > 0)
	floodlights_toggled.emit(channel, on)

func get_feed_status() -> String:
	if not is_online or power_ratio < 0.2:
		return "NO SIGNAL"
	if health_percent < 25.0:
		return "STATIC / GLITCH"
	return "ONLINE"

func step(delta: float) -> void:
	if not is_online:
		power_draw_current = 0.0
		_sync_cam_registers()
		super.step(delta)
		return

	# Calcolo consumo: base 5 MW + fino a 10 MW con fari
	var light_count := 0
	for i in range(6):
		if (floodlights_mask & (1 << i)) != 0:
			light_count += 1
	var draw := power_draw_nominal + (float(light_count) * 1.6)
	power_draw_current = draw

	if power_draw_current > 0.0:
		power_ratio = clampf(power_supplied / power_draw_current, 0.0, 1.0)
	else:
		power_ratio = 1.0

	_sync_cam_registers()
	super.step(delta)

func _sync_cam_registers() -> void:
	registers["active_channel"] = active_camera_channel
	registers["floodlights_mask"] = floodlights_mask
	registers["feed_status"] = get_feed_status()
	registers["floodlights_active"] = floodlights_mask > 0 and is_online and power_ratio >= 0.3

func get_telemetry() -> Dictionary:
	var telem := super.get_telemetry()
	telem["active_channel"] = active_camera_channel
	telem["camera_name"] = camera_names[active_camera_channel - 1] if active_camera_channel >= 1 and active_camera_channel <= 6 else "UNKNOWN"
	telem["floodlights_mask"] = floodlights_mask
	telem["feed_status"] = get_feed_status()
	telem["floodlights_active"] = floodlights_mask > 0 and is_online and power_ratio >= 0.3
	return telem
