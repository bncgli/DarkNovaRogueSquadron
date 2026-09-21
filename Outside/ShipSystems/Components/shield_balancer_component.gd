class_name ShieldBalancerComponent
extends ShipPhysicalComponent

## Modello del bilanciatore scudi deflettori e servomotori (arm_sx_balancer, arm_dx_balancer).
## Gestisce la bolla deflettrice a 4 quadranti (Prua, Poppa, Babordo, Tribordo).
## Se disalimentato o offline, rigenerazione collassata e decadimento a 0 HP (-25 HP/s).

signal quadrant_shields_updated(front: float, rear: float, left: float, right: float)
signal emergency_boost_activated(quadrant: String)

@export var front_hp: float = 100.0
@export var rear_hp: float = 100.0
@export var left_hp: float = 100.0
@export var right_hp: float = 100.0
@export var max_quadrant_hp: float = 100.0
@export var regen_rate: float = 15.0 # HP/s
@export var decay_rate_unpowered: float = 25.0 # HP/s
@export var boost_cooldown: float = 0.0
@export var is_harmonized: bool = true
@export var distribution: Vector2 = Vector2.ZERO # X (-1..1 sx/dx), Y (-1..1 poppa/prua)

func _init(p_device_id: String = "arm_sx_balancer", p_room_id: String = "armatura_adattiva", p_category: String = "defense") -> void:
	super._init(p_device_id, p_room_id, p_category)
	power_draw_nominal = 45.0 # Due bilanciatori coprono i ~90 MW nominali

func initialize_registers() -> void:
	super.initialize_registers()
	registers["shield_front"] = front_hp
	registers["shield_rear"] = rear_hp
	registers["shield_left"] = left_hp
	registers["shield_right"] = right_hp
	registers["dist_x"] = distribution.x
	registers["dist_y"] = distribution.y
	registers["is_harmonized"] = is_harmonized
	registers["boost_ready"] = (boost_cooldown <= 0.0)
	
	if not readonly_registers.has("shield_front"):
		readonly_registers.append("shield_front")
	if not readonly_registers.has("shield_rear"):
		readonly_registers.append("shield_rear")
	if not readonly_registers.has("shield_left"):
		readonly_registers.append("shield_left")
	if not readonly_registers.has("shield_right"):
		readonly_registers.append("shield_right")
	if not readonly_registers.has("boost_ready"):
		readonly_registers.append("boost_ready")

func read_register(reg_name: String) -> Variant:
	match reg_name:
		"shield_front":
			return front_hp
		"shield_rear":
			return rear_hp
		"shield_left":
			return left_hp
		"shield_right":
			return right_hp
		"dist_x":
			return distribution.x
		"dist_y":
			return distribution.y
		"is_harmonized":
			return is_harmonized
		"boost_ready":
			return boost_cooldown <= 0.0 and is_online and power_ratio >= 0.5
		_:
			return super.read_register(reg_name)

func _on_register_written(reg_name: String, value: Variant) -> void:
	super._on_register_written(reg_name, value)
	match reg_name:
		"dist_x":
			distribution.x = clampf(float(value), -1.0, 1.0)
			registers["dist_x"] = distribution.x
		"dist_y":
			distribution.y = clampf(float(value), -1.0, 1.0)
			registers["dist_y"] = distribution.y
		"is_harmonized":
			is_harmonized = bool(value)
			registers["is_harmonized"] = is_harmonized

func set_distribution(dist: Vector2) -> void:
	distribution.x = clampf(dist.x, -1.0, 1.0)
	distribution.y = clampf(dist.y, -1.0, 1.0)
	registers["dist_x"] = distribution.x
	registers["dist_y"] = distribution.y

func activate_emergency_boost(quadrant: String) -> bool:
	if not is_online or power_ratio < 0.5 or boost_cooldown > 0.0:
		return false
	
	var overcharge_max := max_quadrant_hp * 1.5
	match quadrant.to_lower():
		"front", "prua":
			front_hp = minf(overcharge_max, front_hp + 75.0)
		"rear", "poppa":
			rear_hp = minf(overcharge_max, rear_hp + 75.0)
		"left", "sx", "babordo":
			left_hp = minf(overcharge_max, left_hp + 75.0)
		"right", "dx", "tribordo":
			right_hp = minf(overcharge_max, right_hp + 75.0)
		_:
			return false
			
	boost_cooldown = 20.0
	emergency_boost_activated.emit(quadrant)
	quadrant_shields_updated.emit(front_hp, rear_hp, left_hp, right_hp)
	return true

func absorb_damage(amount: float, quadrant: String) -> float:
	var damage_remaining := amount
	match quadrant.to_lower():
		"front", "prua":
			var absorbed := minf(front_hp, damage_remaining)
			front_hp -= absorbed
			damage_remaining -= absorbed
		"rear", "poppa":
			var absorbed := minf(rear_hp, damage_remaining)
			rear_hp -= absorbed
			damage_remaining -= absorbed
		"left", "sx", "babordo":
			var absorbed := minf(left_hp, damage_remaining)
			left_hp -= absorbed
			damage_remaining -= absorbed
		"right", "dx", "tribordo":
			var absorbed := minf(right_hp, damage_remaining)
			right_hp -= absorbed
			damage_remaining -= absorbed
	
	quadrant_shields_updated.emit(front_hp, rear_hp, left_hp, right_hp)
	return damage_remaining

func step(delta: float) -> void:
	if not is_online or power_ratio <= 0.0:
		power_draw_current = 0.0
		# Decadimento rapido passivo a 0 HP quando unpowered
		front_hp = maxf(0.0, front_hp - decay_rate_unpowered * delta)
		rear_hp = maxf(0.0, rear_hp - decay_rate_unpowered * delta)
		left_hp = maxf(0.0, left_hp - decay_rate_unpowered * delta)
		right_hp = maxf(0.0, right_hp - decay_rate_unpowered * delta)
		_sync_shield_registers()
		quadrant_shields_updated.emit(front_hp, rear_hp, left_hp, right_hp)
		super.step(delta)
		return

	power_draw_current = power_draw_nominal
	if power_draw_current > 0.0:
		power_ratio = clampf(power_supplied / power_draw_current, 0.0, 1.0)
	else:
		power_ratio = 1.0

	var health_factor := health_percent / 100.0
	var effective_regen := regen_rate * power_ratio * health_factor * (1.2 if is_harmonized else 0.8)

	# Calcolo pesi di distribuzione
	var w_front := clampf(1.0 + distribution.y, 0.2, 2.0)
	var w_rear := clampf(1.0 - distribution.y, 0.2, 2.0)
	var w_left := clampf(1.0 - distribution.x, 0.2, 2.0)
	var w_right := clampf(1.0 + distribution.x, 0.2, 2.0)

	front_hp = minf(max_quadrant_hp, front_hp + effective_regen * w_front * delta)
	rear_hp = minf(max_quadrant_hp, rear_hp + effective_regen * w_rear * delta)
	left_hp = minf(max_quadrant_hp, left_hp + effective_regen * w_left * delta)
	right_hp = minf(max_quadrant_hp, right_hp + effective_regen * w_right * delta)

	if boost_cooldown > 0.0:
		boost_cooldown = maxf(0.0, boost_cooldown - delta)

	_sync_shield_registers()
	quadrant_shields_updated.emit(front_hp, rear_hp, left_hp, right_hp)
	super.step(delta)

func _sync_shield_registers() -> void:
	registers["shield_front"] = front_hp
	registers["shield_rear"] = rear_hp
	registers["shield_left"] = left_hp
	registers["shield_right"] = right_hp
	registers["dist_x"] = distribution.x
	registers["dist_y"] = distribution.y
	registers["is_harmonized"] = is_harmonized
	registers["boost_ready"] = (boost_cooldown <= 0.0)

func get_telemetry() -> Dictionary:
	var telem := super.get_telemetry()
	telem["shield_front"] = front_hp
	telem["shield_rear"] = rear_hp
	telem["shield_left"] = left_hp
	telem["shield_right"] = right_hp
	telem["dist_x"] = distribution.x
	telem["dist_y"] = distribution.y
	telem["is_harmonized"] = is_harmonized
	telem["boost_ready"] = (boost_cooldown <= 0.0)
	return telem
