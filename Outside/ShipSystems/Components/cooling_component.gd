class_name CoolingComponent
extends ShipPhysicalComponent

## Modello del sistema di raffreddamento, pompe refrigeranti e radiatori termici.
## Dissipa l'energia termica prodotta dai reattori, propulsori e computer di bordo.

@export var cooling_capacity: float = 50.0 # quantita' max di calore dissipata per secondo
@export var coolant_level: float = 100.0
@export var pump_speed: float = 1.0

func _init(p_device_id: String = "", p_room_id: String = "", p_category: String = "engineering") -> void:
	super._init(p_device_id, p_room_id, p_category)
	power_draw_nominal = 12.0
	heat_max = 150.0

func initialize_registers() -> void:
	super.initialize_registers()
	registers["cooling_capacity"] = cooling_capacity
	registers["coolant_level"] = coolant_level
	registers["pump_speed"] = pump_speed
	if not readonly_registers.has("cooling_capacity"):
		readonly_registers.append("cooling_capacity")
	if not readonly_registers.has("coolant_level"):
		readonly_registers.append("coolant_level")

func _on_register_written(reg_name: String, value: Variant) -> void:
	super._on_register_written(reg_name, value)
	if reg_name == "pump_speed":
		pump_speed = clampf(float(value), 0.0, 2.0)
		registers["pump_speed"] = pump_speed
	elif reg_name == "coolant_level":
		coolant_level = clampf(float(value), 0.0, 100.0)
		registers["coolant_level"] = coolant_level

## Rimuove calore dal bus o da un componente esterno. Ritorna il calore effettivamente dissipato.
func dissipate_heat(heat_amount: float, delta: float) -> float:
	if not is_online or heat_amount <= 0.0 or delta <= 0.0 or coolant_level <= 0.0:
		return 0.0
	
	var health_factor := health_percent / 100.0
	var coolant_factor := coolant_level / 100.0
	var max_dissipation := cooling_capacity * pump_speed * health_factor * coolant_factor * power_ratio * delta
	
	var dissipated := minf(heat_amount, max_dissipation)
	
	# La dissipazione incrementa lievemente la temperatura temporanea del circuito radiatore prima del rilascio
	heat_current += (dissipated * 0.1)
	return dissipated

func step(delta: float) -> void:
	if not is_online:
		power_draw_current = 0.0
		super.step(delta)
		return

	power_draw_current = power_draw_nominal * pump_speed
	if power_draw_current > 0.0:
		power_ratio = clampf(power_supplied / power_draw_current, 0.0, 1.0)
	else:
		power_ratio = 1.0

	# Il circuito di raffreddamento si dissipa molto velocemente verso ambient_temp
	var active_cooling_mult := 3.0 * pump_speed * (health_percent / 100.0) * power_ratio
	heat_current = move_toward(heat_current, ambient_temp, passive_cooling_rate * active_cooling_mult * delta)

	# Se surriscaldato, il refrigerante può degradarsi lentamente
	if heat_current > 110.0:
		var loss := (heat_current - 110.0) * 0.02 * delta
		coolant_level = maxf(0.0, coolant_level - loss)
		registers["coolant_level"] = coolant_level

	registers["cooling_capacity"] = cooling_capacity
	registers["pump_speed"] = pump_speed
	super.step(delta)

func refill_coolant() -> void:
	coolant_level = 100.0
	registers["coolant_level"] = coolant_level

func get_telemetry() -> Dictionary:
	var telem := super.get_telemetry()
	telem["cooling_capacity"] = cooling_capacity
	telem["coolant_level"] = coolant_level
	telem["pump_speed"] = pump_speed
	return telem
