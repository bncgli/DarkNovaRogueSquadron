class_name NavComputerComponent
extends ShipPhysicalComponent

## Modello dell'elaboratore di rotte e calcolo salto (nav_computer).
## Calcola traiettorie interplanetarie, vettori Hyperdrive e waypoint HUD.
## Quando disalimentato o offline, disabilita il calcolo rotte e spegne waypoint e coni d'ombra.

signal route_calculated(destination: Vector2, distance: float, eta_seconds: float)
signal hyperdrive_vector_calculated(vector: Vector3, ready: bool)

@export var is_route_calculating: bool = false
@export var route_calculation_progress: float = 0.0
@export var current_destination: Vector2 = Vector2.ZERO
@export var estimated_distance: float = 0.0
@export var estimated_eta: float = 0.0
@export var hyperdrive_vector: Vector3 = Vector3(0, 0, -1)
@export var hyperdrive_ready: bool = false
@export var shadow_cones_visible: bool = true
@export var waypoints_active: bool = true

func _init(p_device_id: String = "nav_computer", p_room_id: String = "ponte_comando", p_category: String = "command") -> void:
	super._init(p_device_id, p_room_id, p_category)
	power_draw_nominal = 10.0

func initialize_registers() -> void:
	super.initialize_registers()
	registers["route_calculating"] = is_route_calculating
	registers["dest_x"] = current_destination.x
	registers["dest_y"] = current_destination.y
	registers["est_distance"] = estimated_distance
	registers["est_eta"] = estimated_eta
	registers["hyperdrive_ready"] = hyperdrive_ready
	registers["shadow_cones"] = shadow_cones_visible
	registers["waypoints_active"] = waypoints_active
	
	if not readonly_registers.has("route_calculating"):
		readonly_registers.append("route_calculating")
	if not readonly_registers.has("est_distance"):
		readonly_registers.append("est_distance")
	if not readonly_registers.has("est_eta"):
		readonly_registers.append("est_eta")
	if not readonly_registers.has("hyperdrive_ready"):
		readonly_registers.append("hyperdrive_ready")
	if not readonly_registers.has("shadow_cones"):
		readonly_registers.append("shadow_cones")
	if not readonly_registers.has("waypoints_active"):
		readonly_registers.append("waypoints_active")

func read_register(reg_name: String) -> Variant:
	match reg_name:
		"route_calculating":
			return is_route_calculating
		"dest_x":
			return current_destination.x
		"dest_y":
			return current_destination.y
		"est_distance":
			return estimated_distance
		"est_eta":
			return estimated_eta
		"hyperdrive_ready":
			return hyperdrive_ready
		"shadow_cones":
			return shadow_cones_visible
		"waypoints_active":
			return waypoints_active
		_:
			return super.read_register(reg_name)

func _on_register_written(reg_name: String, value: Variant) -> void:
	super._on_register_written(reg_name, value)
	match reg_name:
		"dest_x":
			current_destination.x = float(value)
			registers["dest_x"] = current_destination.x
		"dest_y":
			current_destination.y = float(value)
			registers["dest_y"] = current_destination.y

func calculate_route(dest: Vector2) -> Dictionary:
	if not is_online or power_ratio < 0.4:
		return {"success": false, "error": "NAV_COMPUTER_OFFLINE"}
	
	current_destination = dest
	registers["dest_x"] = dest.x
	registers["dest_y"] = dest.y
	
	is_route_calculating = true
	route_calculation_progress = 0.0
	
	# Calcolo geometrico stimato
	estimated_distance = dest.length() * 100.0
	estimated_eta = maxf(5.0, estimated_distance / 160.0)
	registers["est_distance"] = estimated_distance
	registers["est_eta"] = estimated_eta
	
	route_calculated.emit(current_destination, estimated_distance, estimated_eta)
	return {
		"success": true,
		"destination": current_destination,
		"distance": estimated_distance,
		"eta": estimated_eta
	}

func get_hyperdrive_solution() -> Dictionary:
	return {
		"ready": hyperdrive_ready and is_online and power_ratio >= 0.5,
		"vector": hyperdrive_vector,
		"target": current_destination
	}

func step(delta: float) -> void:
	if not is_online:
		power_draw_current = 0.0
		is_route_calculating = false
		hyperdrive_ready = false
		shadow_cones_visible = false
		waypoints_active = false
		_sync_nav_registers()
		super.step(delta)
		return

	power_draw_current = power_draw_nominal
	if power_draw_current > 0.0:
		power_ratio = clampf(power_supplied / power_draw_current, 0.0, 1.0)
	else:
		power_ratio = 1.0

	var health_factor := health_percent / 100.0
	var is_operational := (power_ratio >= 0.4) and (health_factor > 0.1)

	shadow_cones_visible = is_operational
	waypoints_active = is_operational
	hyperdrive_ready = is_operational and (current_destination != Vector2.ZERO)

	if is_route_calculating:
		var speed := (power_ratio * health_factor) * delta * 0.5
		route_calculation_progress += speed
		if route_calculation_progress >= 1.0:
			route_calculation_progress = 1.0
			is_route_calculating = false

	_sync_nav_registers()
	super.step(delta)

func _sync_nav_registers() -> void:
	registers["route_calculating"] = is_route_calculating
	registers["dest_x"] = current_destination.x
	registers["dest_y"] = current_destination.y
	registers["est_distance"] = estimated_distance
	registers["est_eta"] = estimated_eta
	registers["hyperdrive_ready"] = hyperdrive_ready
	registers["shadow_cones"] = shadow_cones_visible
	registers["waypoints_active"] = waypoints_active

func get_telemetry() -> Dictionary:
	var telem := super.get_telemetry()
	telem["route_calculating"] = is_route_calculating
	telem["dest_x"] = current_destination.x
	telem["dest_y"] = current_destination.y
	telem["est_distance"] = estimated_distance
	telem["est_eta"] = estimated_eta
	telem["hyperdrive_ready"] = hyperdrive_ready
	telem["shadow_cones"] = shadow_cones_visible
	telem["waypoints_active"] = waypoints_active
	return telem
