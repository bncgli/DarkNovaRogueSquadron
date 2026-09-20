class_name ReactorComponent
extends ShipPhysicalComponent

## Modello di reattore nucleare/generatore primario.
## Produce energia per la nave consumando carburante ed emettendo calore termico.

@export var power_output_nominal: float = 1000.0
@export var fuel_consumption_rate: float = 0.05 # unita' di carburante per secondo al 100%
@export var heat_production_rate: float = 2.5 # gradi C al secondo al 100%

var power_output_current: float = 0.0
var fuel_level: float = 100.0
var power_target: float = 1.0

func _init(p_device_id: String = "", p_room_id: String = "", p_category: String = "engineering") -> void:
	super._init(p_device_id, p_room_id, p_category)
	power_draw_nominal = 0.0 # Il reattore è un generatore, non assorbe passivamente
	heat_max = 250.0 # Il reattore tollera temperature più elevate

func initialize_registers() -> void:
	super.initialize_registers()
	registers["power_target"] = power_target
	registers["fuel"] = fuel_level
	registers["power_output"] = power_output_current
	if not readonly_registers.has("power_output"):
		readonly_registers.append("power_output")

func _on_register_written(reg_name: String, value: Variant) -> void:
	super._on_register_written(reg_name, value)
	if reg_name == "power_target":
		power_target = clampf(float(value), 0.0, 2.0)
		registers["power_target"] = power_target
		if power_target > 1.0:
			var msg := "ATTENZIONE: Sovraccarico reattore impostato (>100%): " + str(roundi(power_target * 100.0)) + "%"
			alert_triggered.emit(device_id, "OVERDRIVE", msg)
			if Engine.get_main_loop() is SceneTree:
				var tree := Engine.get_main_loop() as SceneTree
				if tree and tree.root:
					var notif := tree.root.get_node_or_null("NotificationManager")
					if notif and notif.has_method("spawn_notification"):
						notif.spawn_notification("ATTENZIONE: Sovraccarico reattore impostato (>100%)")
	elif reg_name == "fuel":
		fuel_level = clampf(float(value), 0.0, 100.0)
		registers["fuel"] = fuel_level

func step(delta: float) -> void:
	if not is_online:
		power_output_current = 0.0
		registers["power_output"] = 0.0
		super.step(delta)
		return

	# Scram termico di sicurezza se temperatura raggiunge o supera la soglia critica
	if heat_current >= heat_max:
		set_online(false)
		status_string = "SCRAM"
		registers["status"] = "SCRAM"
		power_output_current = 0.0
		registers["power_output"] = 0.0
		alert_triggered.emit(device_id, "SCRAM", "SCRAM TERMICO ATTIVATO: Temperatura nocciolo >= %.1f C! Reattore disconnesso per prevenire meltdown." % heat_max)
		super.step(delta)
		return

	if fuel_level <= 0.0:
		fuel_level = 0.0
		power_output_current = 0.0
		status_string = "DEPLETED"
		registers["status"] = status_string
		registers["power_output"] = 0.0
		super.step(delta)
		status_string = "DEPLETED"
		registers["status"] = status_string
		return

	# Consumo carburante
	var fuel_spent := fuel_consumption_rate * power_target * delta
	fuel_level = maxf(0.0, fuel_level - fuel_spent)
	registers["fuel"] = fuel_level

	if fuel_level <= 0.0:
		fuel_level = 0.0
		power_output_current = 0.0
		status_string = "DEPLETED"
		registers["status"] = status_string
		registers["power_output"] = 0.0
		super.step(delta)
		status_string = "DEPLETED"
		registers["status"] = status_string
		return

	# Produzione di potenza effettiva
	var health_factor: float = health_percent / 100.0
	power_output_current = power_output_nominal * power_target * health_factor
	registers["power_output"] = power_output_current

	# Generazione termica proporzionale al target di erogazione
	heat_current += heat_production_rate * power_target * delta

	super.step(delta)

func get_telemetry() -> Dictionary:
	var telem := super.get_telemetry()
	telem["power_output"] = power_output_current
	telem["fuel"] = fuel_level
	telem["power_target"] = power_target
	return telem
