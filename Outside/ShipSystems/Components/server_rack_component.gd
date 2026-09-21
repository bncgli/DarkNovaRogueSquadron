class_name ServerRackComponent
extends ShipPhysicalComponent

## Modello del server centrale cyber-guerra e mainframe (server_rack).
## Esegue exploit offensivi contro navi nemiche in HackExploitsApp, protegge i firewall
## e gestisce l'elaborazione crittografica per comandi terminale (worm, decript).
## Se disalimentato o offline, exploit bloccati, caduta firewall e coprocessore crypto offline.

signal firewall_status_changed(integrity: float, active: bool)
signal exploit_completed(exploit_name: String, success: bool)
signal crypto_operation_finished(op_type: String, result: Dictionary)

@export var firewall_integrity: float = 100.0
@export var firewall_active: bool = true
@export var cpu_load: float = 10.0 # percentuale 0..100%
@export var crypto_coprocessor_online: bool = true

var active_exploit: String = ""
var exploit_progress: float = 0.0

func _init(p_device_id: String = "server_rack", p_room_id: String = "mainframe", p_category: String = "cyber") -> void:
	super._init(p_device_id, p_room_id, p_category)
	power_draw_nominal = 10.0

func initialize_registers() -> void:
	super.initialize_registers()
	registers["firewall_integrity"] = firewall_integrity
	registers["firewall_active"] = firewall_active
	registers["cpu_load"] = cpu_load
	registers["active_exploit"] = active_exploit
	registers["exploit_progress"] = exploit_progress
	registers["crypto_ready"] = (crypto_coprocessor_online and is_online and power_ratio >= 0.3)
	
	if not readonly_registers.has("firewall_integrity"):
		readonly_registers.append("firewall_integrity")
	if not readonly_registers.has("cpu_load"):
		readonly_registers.append("cpu_load")
	if not readonly_registers.has("active_exploit"):
		readonly_registers.append("active_exploit")
	if not readonly_registers.has("exploit_progress"):
		readonly_registers.append("exploit_progress")
	if not readonly_registers.has("crypto_ready"):
		readonly_registers.append("crypto_ready")

func read_register(reg_name: String) -> Variant:
	match reg_name:
		"firewall_integrity":
			return firewall_integrity
		"firewall_active":
			return firewall_active and is_online and power_ratio >= 0.3
		"cpu_load":
			return cpu_load
		"active_exploit":
			return active_exploit
		"exploit_progress":
			return exploit_progress
		"crypto_ready":
			return crypto_coprocessor_online and is_online and power_ratio >= 0.3
		_:
			return super.read_register(reg_name)

func _on_register_written(reg_name: String, value: Variant) -> void:
	super._on_register_written(reg_name, value)
	if reg_name == "firewall_active":
		set_firewall_active(bool(value))

func set_firewall_active(active: bool) -> void:
	firewall_active = active
	registers["firewall_active"] = firewall_active
	firewall_status_changed.emit(firewall_integrity, firewall_active)

func start_exploit(exploit_name: String) -> bool:
	if not is_online or power_ratio < 0.4 or not crypto_coprocessor_online:
		return false
	active_exploit = exploit_name
	exploit_progress = 0.0
	registers["active_exploit"] = active_exploit
	registers["exploit_progress"] = exploit_progress
	return true

func cancel_exploit() -> void:
	if not active_exploit.is_empty():
		active_exploit = ""
		exploit_progress = 0.0
		registers["active_exploit"] = ""
		registers["exploit_progress"] = 0.0

func execute_crypt_operation(op_type: String) -> bool:
	return is_online and power_ratio >= 0.3 and crypto_coprocessor_online

func step(delta: float) -> void:
	if not is_online:
		power_draw_current = 0.0
		active_exploit = ""
		exploit_progress = 0.0
		cpu_load = 0.0
		crypto_coprocessor_online = false
		_sync_server_registers()
		super.step(delta)
		return

	var is_busy := not active_exploit.is_empty()
	var draw := power_draw_nominal + (20.0 if is_busy else 0.0)
	power_draw_current = draw

	if power_draw_current > 0.0:
		power_ratio = clampf(power_supplied / power_draw_current, 0.0, 1.0)
	else:
		power_ratio = 1.0

	var health_factor := health_percent / 100.0
	crypto_coprocessor_online = (power_ratio >= 0.3) and (health_factor > 0.1)

	if not crypto_coprocessor_online and is_busy:
		active_exploit = ""
		exploit_progress = 0.0

	if is_busy and crypto_coprocessor_online:
		cpu_load = 75.0 + 20.0 * (1.0 - power_ratio)
		exploit_progress += 0.2 * power_ratio * health_factor * delta
		if exploit_progress >= 1.0:
			var finished_exploit := active_exploit
			active_exploit = ""
			exploit_progress = 0.0
			exploit_completed.emit(finished_exploit, true)
	else:
		cpu_load = 10.0

	_sync_server_registers()
	super.step(delta)

func _sync_server_registers() -> void:
	registers["firewall_integrity"] = firewall_integrity
	registers["firewall_active"] = firewall_active and is_online and power_ratio >= 0.3
	registers["cpu_load"] = cpu_load
	registers["active_exploit"] = active_exploit
	registers["exploit_progress"] = exploit_progress
	registers["crypto_ready"] = crypto_coprocessor_online and is_online and power_ratio >= 0.3

func get_telemetry() -> Dictionary:
	var telem := super.get_telemetry()
	telem["firewall_integrity"] = firewall_integrity
	telem["firewall_active"] = firewall_active and is_online and power_ratio >= 0.3
	telem["cpu_load"] = cpu_load
	telem["active_exploit"] = active_exploit
	telem["exploit_progress"] = exploit_progress
	telem["crypto_ready"] = crypto_coprocessor_online and is_online and power_ratio >= 0.3
	return telem
