class_name CargoHandlingComponent
extends ShipPhysicalComponent

## Modello del manipolatore e sistemi stiva merci (cargo_handling).
## Controlla serrande portelloni di carico, agganci magnetici container e raffinatore ghiaccio/minerali.
## Se disalimentato o offline, portelloni bloccati, disattivazione clamp magnetiche e stop raffinazione.

signal cargo_doors_toggled(opened: bool)
signal magnetic_clamps_toggled(clamped: bool)
signal refining_progress_updated(progress: float)

@export var doors_open: bool = false
@export var magnetic_clamps_active: bool = true
@export var is_refining: bool = false
@export var refine_progress: float = 0.0
@export var cargo_bay_temp: float = 5.0

func _init(p_device_id: String = "cargo_handling", p_room_id: String = "baia_carico", p_category: String = "cargo") -> void:
	super._init(p_device_id, p_room_id, p_category)
	power_draw_nominal = 10.0

func initialize_registers() -> void:
	super.initialize_registers()
	registers["doors_open"] = doors_open
	registers["magnetic_clamps"] = magnetic_clamps_active
	registers["is_refining"] = is_refining
	registers["refine_progress"] = refine_progress
	registers["cargo_bay_temp"] = cargo_bay_temp
	
	if not readonly_registers.has("refine_progress"):
		readonly_registers.append("refine_progress")
	if not readonly_registers.has("cargo_bay_temp"):
		readonly_registers.append("cargo_bay_temp")

func read_register(reg_name: String) -> Variant:
	match reg_name:
		"doors_open":
			return doors_open
		"magnetic_clamps":
			return magnetic_clamps_active
		"is_refining":
			return is_refining
		"refine_progress":
			return refine_progress
		"cargo_bay_temp":
			return cargo_bay_temp
		_:
			return super.read_register(reg_name)

func _on_register_written(reg_name: String, value: Variant) -> void:
	super._on_register_written(reg_name, value)
	match reg_name:
		"doors_open":
			set_doors(bool(value))
		"magnetic_clamps":
			set_magnetic_clamps(bool(value))
		"is_refining":
			set_refining(bool(value))

func set_doors(open: bool) -> bool:
	if not is_online or power_ratio < 0.4:
		return false
	doors_open = open
	registers["doors_open"] = doors_open
	cargo_doors_toggled.emit(doors_open)
	return true

func set_magnetic_clamps(clamped: bool) -> bool:
	if not is_online or power_ratio < 0.2:
		return false
	magnetic_clamps_active = clamped
	registers["magnetic_clamps"] = magnetic_clamps_active
	magnetic_clamps_toggled.emit(magnetic_clamps_active)
	return true

func set_refining(refining: bool) -> bool:
	if not is_online or power_ratio < 0.5:
		return false
	is_refining = refining
	registers["is_refining"] = is_refining
	return true

func step(delta: float) -> void:
	if not is_online:
		power_draw_current = 0.0
		is_refining = false
		magnetic_clamps_active = false
		_sync_cargo_registers()
		super.step(delta)
		return

	var draw := power_draw_nominal + (15.0 if is_refining else 0.0)
	power_draw_current = draw
	
	if power_draw_current > 0.0:
		power_ratio = clampf(power_supplied / power_draw_current, 0.0, 1.0)
	else:
		power_ratio = 1.0

	var health_factor := health_percent / 100.0
	
	if is_refining:
		if power_ratio >= 0.4 and health_factor > 0.1:
			refine_progress += 0.1 * power_ratio * health_factor * delta
			if refine_progress >= 1.0:
				refine_progress = 0.0
				is_refining = false
			refining_progress_updated.emit(refine_progress)
		else:
			is_refining = false

	_sync_cargo_registers()
	super.step(delta)

func _sync_cargo_registers() -> void:
	registers["doors_open"] = doors_open
	registers["magnetic_clamps"] = magnetic_clamps_active
	registers["is_refining"] = is_refining
	registers["refine_progress"] = refine_progress
	registers["cargo_bay_temp"] = cargo_bay_temp

func get_telemetry() -> Dictionary:
	var telem := super.get_telemetry()
	telem["doors_open"] = doors_open
	telem["magnetic_clamps"] = magnetic_clamps_active
	telem["is_refining"] = is_refining
	telem["refine_progress"] = refine_progress
	telem["cargo_bay_temp"] = cargo_bay_temp
	return telem
