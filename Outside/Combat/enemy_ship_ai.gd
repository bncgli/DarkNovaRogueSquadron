class_name EnemyShipAI
extends Node3D

## Modulo IA per Caccia Pirata, Droni Ostili e Corvette di Pattuglia.
## Gestisce comportamenti tattici a FSM / Decision Tree:
## PATROL, SWARM_CHASE, TORPEDO_BOMBING, EVASIVE_STRAFE, TACTICAL_RETREAT, DISABLED.
## Supporta guerra elettronica (EW / Jamming / Firmware Exploits).

signal state_changed(old_state: AIState, new_state: AIState)
signal weapon_fired(weapon_type: String, origin: Vector3, target_pos: Vector3, damage: float)
signal health_changed(current_health: float, max_health: float, current_shield: float)
signal ship_destroyed(ship_id: String, ship_type: String, position: Vector3)
signal ew_effect_applied(effect_type: String, duration: float)

enum AIState {
	PATROL,
	SWARM_CHASE,
	TORPEDO_BOMBING,
	EVASIVE_STRAFE,
	TACTICAL_RETREAT,
	DISABLED
}

enum ShipType {
	PIRATE_FIGHTER,
	HOSTILE_DRONE,
	PATROL_CORVETTE
}

# --- CONFIGURAZIONE NAVE ---
@export var ship_id: String = ""
@export var ship_name: String = "Pirate Raider"
@export var ship_type: ShipType = ShipType.PIRATE_FIGHTER
@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var max_shield: float = 50.0
@export var current_shield: float = 50.0
@export var shield_regen_rate: float = 4.0

# --- PARAMETRI DI MOVIMENTO & MANOVRA ---
@export var max_speed: float = 35.0
@export var acceleration: float = 20.0
@export var turn_speed: float = 2.5
@export var attack_range: float = 120.0
@export var optimal_range: float = 45.0
@export var retreat_health_threshold: float = 25.0 # % di vita per iniziare la ritirata

# --- ARMI & CADENZA ---
@export var primary_cooldown: float = 1.2
@export var torpedo_cooldown: float = 6.0
@export var primary_damage: float = 12.0
@export var torpedo_damage: float = 45.0

# --- STATO RUNTIME ---
var current_state: AIState = AIState.PATROL
var target_node: Node3D = null
var target_position: Vector3 = Vector3(INF, INF, INF)
var velocity: Vector3 = Vector3.ZERO
var patrol_waypoints: Array[Vector3] = []
var current_waypoint_index: int = 0

var primary_timer: float = 0.0
var torpedo_timer: float = 0.0
var state_timer: float = 0.0
var strafe_direction: Vector3 = Vector3.RIGHT

# --- GUERRA ELETTRONICA & EXPLOIT ---
var is_jammed: bool = false
var jam_duration: float = 0.0
var is_firmware_hacked: bool = false # Motori disabilitati
var hack_duration: float = 0.0
var accuracy_penalty: float = 0.0 # 0.0 a 1.0 (imprecisione da EW)

func _ready() -> void:
	if ship_id.is_empty():
		ship_id = "ENEMY_" + str(get_instance_id())
	_setup_ship_parameters()

func setup(p_id: String, p_type: ShipType, p_pos: Vector3 = Vector3.ZERO) -> void:
	ship_id = p_id
	ship_type = p_type
	global_position = p_pos
	_setup_ship_parameters()

func _setup_ship_parameters() -> void:
	match ship_type:
		ShipType.HOSTILE_DRONE:
			ship_name = "Hostile Drone " + ship_id
			max_health = 45.0
			max_shield = 20.0
			max_speed = 45.0
			acceleration = 30.0
			turn_speed = 3.5
			primary_damage = 8.0
			primary_cooldown = 0.8
			torpedo_cooldown = 0.0 # I droni non hanno siluri di default
			retreat_health_threshold = 0.0 # Droni non fuggono (kamikaze/swarm)
		ShipType.PATROL_CORVETTE:
			ship_name = "Patrol Corvette " + ship_id
			max_health = 350.0
			max_shield = 180.0
			max_speed = 22.0
			acceleration = 12.0
			turn_speed = 1.2
			primary_damage = 25.0
			primary_cooldown = 1.8
			torpedo_damage = 60.0
			torpedo_cooldown = 4.5
			retreat_health_threshold = 15.0
		ShipType.PIRATE_FIGHTER, _:
			ship_name = "Pirate Fighter " + ship_id
			max_health = 90.0
			max_shield = 50.0
			max_speed = 38.0
			acceleration = 24.0
			turn_speed = 2.8
			primary_damage = 14.0
			primary_cooldown = 1.1
			torpedo_damage = 40.0
			torpedo_cooldown = 7.0
			retreat_health_threshold = 25.0

	current_health = max_health
	current_shield = max_shield

func _process(delta: float) -> void:
	_update_ew_effects(delta)
	_update_cooldowns(delta)
	_regenerate_shields(delta)
	_evaluate_decision_tree(delta)
	_execute_state_behavior(delta)

func _update_ew_effects(delta: float) -> void:
	if is_jammed:
		jam_duration -= delta
		if jam_duration <= 0.0:
			is_jammed = false
			accuracy_penalty = 0.0
	
	if is_firmware_hacked:
		hack_duration -= delta
		if hack_duration <= 0.0:
			is_firmware_hacked = false
			if current_state == AIState.DISABLED:
				set_state(AIState.PATROL)

func _update_cooldowns(delta: float) -> void:
	if primary_timer > 0.0:
		primary_timer -= delta
	if torpedo_timer > 0.0:
		torpedo_timer -= delta
	state_timer += delta

func _regenerate_shields(delta: float) -> void:
	if current_health > 0.0 and current_shield < max_shield and not is_firmware_hacked:
		current_shield = min(max_shield, current_shield + shield_regen_rate * delta)

## Decision Tree / State Machine Evaluation
func _evaluate_decision_tree(delta: float) -> void:
	if current_health <= 0.0:
		return

	if is_firmware_hacked:
		if current_state != AIState.DISABLED:
			set_state(AIState.DISABLED)
		return

	# Calcola percentuale vita rimasta
	var health_percent := (current_health / max_health) * 100.0
	if health_percent <= retreat_health_threshold and retreat_health_threshold > 0.0:
		if current_state != AIState.TACTICAL_RETREAT:
			set_state(AIState.TACTICAL_RETREAT)
		return

	# Verifica se il bersaglio esiste ed è valido
	var has_target := false
	var dist_to_target := 99999.0
	if target_node and is_instance_valid(target_node):
		target_position = target_node.global_position
		dist_to_target = global_position.distance_to(target_position)
		has_target = true
	elif not is_inf(target_position.x):
		dist_to_target = global_position.distance_to(target_position)
		has_target = true

	if not has_target or dist_to_target > attack_range * 1.5:
		if current_state != AIState.PATROL:
			set_state(AIState.PATROL)
		return

	# Se siamo a portata di ingaggio
	match current_state:
		AIState.PATROL:
			if has_target and dist_to_target <= attack_range:
				if ship_type == ShipType.PATROL_CORVETTE:
					set_state(AIState.TORPEDO_BOMBING)
				else:
					set_state(AIState.SWARM_CHASE)
		
		AIState.SWARM_CHASE:
			if dist_to_target < optimal_range * 0.5:
				set_state(AIState.EVASIVE_STRAFE)
			elif ship_type == ShipType.PATROL_CORVETTE and torpedo_timer <= 0.0:
				set_state(AIState.TORPEDO_BOMBING)

		AIState.EVASIVE_STRAFE:
			if state_timer >= 3.5: # Termina manovra evasiva
				if has_target and dist_to_target <= attack_range:
					set_state(AIState.SWARM_CHASE)
				else:
					set_state(AIState.PATROL)

		AIState.TORPEDO_BOMBING:
			if torpedo_timer > 0.0 and state_timer >= 2.0:
				set_state(AIState.SWARM_CHASE if ship_type != ShipType.PATROL_CORVETTE else AIState.EVASIVE_STRAFE)

		AIState.TACTICAL_RETREAT:
			# Rimane in ritirata finché non è abbastanza lontano o ripara scudi
			if dist_to_target > attack_range * 2.0:
				set_state(AIState.PATROL)

func set_state(new_state: AIState) -> void:
	if current_state == new_state:
		return
	var old_state := current_state
	current_state = new_state
	state_timer = 0.0
	
	if new_state == AIState.EVASIVE_STRAFE:
		# Scegli direzione laterale casuale
		strafe_direction = Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5), randf_range(-1.0, 1.0)).normalized()

	state_changed.emit(old_state, new_state)

func _execute_state_behavior(delta: float) -> void:
	if is_firmware_hacked or current_state == AIState.DISABLED:
		# Motori disabilitati: decelera per inerzia
		velocity = velocity.move_toward(Vector3.ZERO, acceleration * 0.5 * delta)
		global_position += velocity * delta
		return

	match current_state:
		AIState.PATROL:
			_behavior_patrol(delta)
		AIState.SWARM_CHASE:
			_behavior_swarm_chase(delta)
		AIState.TORPEDO_BOMBING:
			_behavior_torpedo_bombing(delta)
		AIState.EVASIVE_STRAFE:
			_behavior_evasive_strafe(delta)
		AIState.TACTICAL_RETREAT:
			_behavior_tactical_retreat(delta)

## Comportamento: Pattugliamento tra waypoint o stazionamento lento
func _behavior_patrol(delta: float) -> void:
	var target_wp := Vector3.ZERO
	if not patrol_waypoints.is_empty():
		target_wp = patrol_waypoints[current_waypoint_index]
		if global_position.distance_to(target_wp) < 15.0:
			current_waypoint_index = (current_waypoint_index + 1) % patrol_waypoints.size()
			target_wp = patrol_waypoints[current_waypoint_index]
	
	var desired_vel := Vector3.ZERO
	if target_wp != Vector3.ZERO:
		var dir := (target_wp - global_position).normalized()
		_rotate_towards(dir, delta)
		desired_vel = dir * (max_speed * 0.4)
	
	velocity = velocity.move_toward(desired_vel, acceleration * delta)
	global_position += velocity * delta

## Comportamento: Inseguimento a sciame con raffiche primarie
func _behavior_swarm_chase(delta: float) -> void:
	var target_pt := target_position
	var to_target := target_pt - global_position
	var dist := to_target.length()
	var dir := to_target.normalized() if dist > 0.001 else -global_transform.basis.z

	_rotate_towards(dir, delta)

	# Se a distanza ottimale, mantieni velocità, altrimenti accelera
	var desired_speed := max_speed
	if dist < optimal_range:
		desired_speed = max_speed * 0.5
	velocity = velocity.move_toward(dir * desired_speed, acceleration * delta)
	global_position += velocity * delta

	# Apri il fuoco primario se allineato al bersaglio
	var fwd := -global_transform.basis.z
	var angle := fwd.angle_to(dir)
	if dist <= attack_range and angle < deg_to_rad(30.0):
		_fire_primary_weapon()

## Comportamento: Bombardamento pesante con siluri (Corvette o caccia pesanti)
func _behavior_torpedo_bombing(delta: float) -> void:
	var target_pt := target_position
	var to_target := target_pt - global_position
	var dist := to_target.length()
	var dir := to_target.normalized() if dist > 0.001 else -global_transform.basis.z

	_rotate_towards(dir, delta)

	# Frena per stabilizzare il puntamento dei siluri
	velocity = velocity.move_toward(dir * (max_speed * 0.3), acceleration * delta)
	global_position += velocity * delta

	var fwd := -global_transform.basis.z
	var angle := fwd.angle_to(dir)
	if dist <= attack_range and angle < deg_to_rad(20.0):
		_fire_torpedo()
		_fire_primary_weapon()

## Comportamento: Manovra evasiva e strafe laterale per schivare torrette/PD
func _behavior_evasive_strafe(delta: float) -> void:
	var target_pt := target_position
	var to_target := target_pt - global_position
	var dir := to_target.normalized() if to_target.length_squared() > 0.001 else Vector3.FORWARD
	
	# Manovra a spirale/zig-zag combinando direzione bersaglio e strafe laterale
	var evasive_dir := (strafe_direction + dir * 0.3).normalized()
	_rotate_towards(dir, delta * 1.5)

	velocity = velocity.move_toward(evasive_dir * max_speed, acceleration * 1.5 * delta)
	global_position += velocity * delta

	# Fuoco di disturbo se possibile
	if primary_timer <= 0.0:
		_fire_primary_weapon()

## Comportamento: Fuga tattica lontano dal bersaglio
func _behavior_tactical_retreat(delta: float) -> void:
	var target_pt := target_position
	var away_dir := (global_position - target_pt).normalized()
	if away_dir.length_squared() < 0.001:
		away_dir = Vector3.UP

	_rotate_towards(away_dir, delta * 1.2)
	velocity = velocity.move_toward(away_dir * (max_speed * 1.2), acceleration * delta)
	global_position += velocity * delta

func _rotate_towards(target_dir: Vector3, delta: float) -> void:
	if target_dir.length_squared() < 0.001:
		return
	var current_fwd := -global_transform.basis.z
	var angle := current_fwd.angle_to(target_dir)
	if angle > 0.001:
		var axis := current_fwd.cross(target_dir).normalized()
		if axis.length_squared() > 0.001:
			var step: float = min(turn_speed * delta, angle)
			global_rotate(axis, step)

func _fire_primary_weapon() -> void:
	if primary_timer > 0.0:
		return
	primary_timer = primary_cooldown

	var aim_target := target_position
	if is_jammed or accuracy_penalty > 0.0:
		# Deviazione colpo a causa del jamming da EW
		var spread := 25.0 * (1.0 + accuracy_penalty)
		aim_target += Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))

	weapon_fired.emit("laser_burst", global_position, aim_target, primary_damage)

func _fire_torpedo() -> void:
	if torpedo_cooldown <= 0.0 or torpedo_timer > 0.0:
		return
	torpedo_timer = torpedo_cooldown

	var aim_target := target_position
	if is_jammed:
		var spread := 40.0
		aim_target += Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))

	weapon_fired.emit("torpedo", global_position, aim_target, torpedo_damage)

# --- APPLICAZIONE DANNI & INTERAZIONI EW ---

## Applica danno proveniente da armi della nave giocatrice (laser, plasma, railgun, torpedini)
func take_damage(amount: float, is_emp: bool = false) -> Dictionary:
	var shield_damage := 0.0
	var hull_damage := 0.0

	if current_shield > 0.0:
		var effective_dmg := amount * (1.5 if is_emp else 1.0)
		if current_shield >= effective_dmg:
			current_shield -= effective_dmg
			shield_damage = effective_dmg
		else:
			shield_damage = current_shield
			var remaining := (effective_dmg - current_shield) / (1.5 if is_emp else 1.0)
			current_shield = 0.0
			hull_damage = remaining
			current_health = max(0.0, current_health - hull_damage)
	else:
		hull_damage = amount
		current_health = max(0.0, current_health - hull_damage)

	health_changed.emit(current_health, max_health, current_shield)

	if current_health <= 0.0:
		ship_destroyed.emit(ship_id, ShipType.keys()[ship_type], global_position)
		if get_parent():
			queue_free()

	return {
		"ship_id": ship_id,
		"shield_damage": shield_damage,
		"hull_damage": hull_damage,
		"current_health": current_health,
		"current_shield": current_shield,
		"is_destroyed": current_health <= 0.0
	}

## Guerra Elettronica: Jamming del puntamento da parte dell'Hacker (Comms / EW)
func apply_comms_jamming(duration: float, penalty: float = 0.6) -> void:
	is_jammed = true
	jam_duration = max(jam_duration, duration)
	accuracy_penalty = penalty
	ew_effect_applied.emit("JAMMING", duration)

## Guerra Elettronica: Iniezione Firmware Exploit per disabilitare i motori
func inject_firmware_exploit(duration: float) -> void:
	is_firmware_hacked = true
	hack_duration = max(hack_duration, duration)
	set_state(AIState.DISABLED)
	ew_effect_applied.emit("FIRMWARE_EXPLOIT", duration)

func get_tactical_status() -> Dictionary:
	return {
		"id": ship_id,
		"name": ship_name,
		"type": ShipType.keys()[ship_type],
		"state": AIState.keys()[current_state],
		"health": current_health,
		"max_health": max_health,
		"shield": current_shield,
		"max_shield": max_shield,
		"position": global_position,
		"is_jammed": is_jammed,
		"is_hacked": is_firmware_hacked
	}
