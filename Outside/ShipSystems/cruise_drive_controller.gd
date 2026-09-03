class_name CruiseDriveController
extends Node

## Controller per il sistema di propulsione sub-FTL / Velocità di Crociera (Cruise Mode).
## Gestisce la sequenza di warmup tra Pilota e Ingegnere, l'amplificazione esponenziale
## della spinta lineare con rotta vincolata, il blocco RCS e il disingaggio d'emergenza (Proximity Drop).

enum State {
	IDLE,           # Sistema pronto / a riposo
	WARMUP,         # Sequenza di carica bobine e allineamento (4.0s)
	ENGAGED,        # Modalità Crociera attiva (spinta moltiplicata x8.0, RCS bloccato)
	COOLDOWN,       # Cooldown post-disingaggio ordinario
	EMERGENCY_DROP  # Disingaggio d'emergenza per ostacolo ravvicinato (Proximity Drop)
}

# Segnali del sistema di crociera
signal state_changed(new_state: State, old_state: State)
signal warmup_progress_updated(current_time: float, total_time: float, ratio: float)
signal cruise_engaged()
signal cruise_disengaged(reason: String)
signal proximity_drop_triggered(obstacle_name: String, distance: float)
signal power_state_changed(is_powered: bool, current_power: float, required_power: float)
signal alignment_updated(angle_deg: float, is_aligned: bool)
signal rest_state_updated(current_speed: float, is_at_rest: bool)
signal heat_penalty_applied(heat_amount: float, total_heat: float)
signal destination_target_updated(target_pos: Vector3, has_target: bool)
signal cruise_thrust_applied(forward_velocity: Vector3)

# Parametri operativi configurabili via thrusters_tuning.dat
@export var cruise_multiplier: float = 8.0
@export var warmup_time_sec: float = 4.0
@export var proximity_drop_distance: float = 250.0
@export var heat_penalty: float = 45.0
@export var required_power_mw: float = 160.0
@export var max_rest_speed: float = 5.0
@export var max_alignment_deg: float = 3.0

# Stato interno
var current_state: State = State.IDLE
var warmup_timer: float = 0.0
var cooldown_timer: float = 0.0
var cooldown_duration: float = 3.0
var emergency_cooldown_duration: float = 6.0

# Stato energetico (PowerGrid)
var cruise_coils_power_mw: float = 0.0
var is_reactor_peak_active: bool = false

# Dati di navigazione e rotta
var target_destination: Vector3 = Vector3.ZERO
var has_target_destination: bool = false
var cruise_forward_direction: Vector3 = Vector3.FORWARD
var target_cruise_speed: float = 160.0 # 20 m/s * 8.0
var current_heat: float = 0.0
var is_rcs_locked: bool = false

# Riferimenti
var spaceship_ref: Spaceship = null
const TUNING_PATH_PRIMARY: String = "Ship Drive/Programs/FlightControls/thrusters_tuning.dat"
const TUNING_PATH_FALLBACK: String = "Ship Drive/Programs/FlightControl/thrusters_tuning.dat"

func _ready() -> void:
	load_tuning_configuration()
	_connect_system_signals()
	_find_or_attach_spaceship()

func _connect_system_signals() -> void:
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("file_synced"):
		if not sdm.file_synced.is_connected(_on_file_synced):
			sdm.file_synced.connect(_on_file_synced)
	
	if SpaceWorldManager:
		if SpaceWorldManager.has_signal("waypoint_updated"):
			if not SpaceWorldManager.waypoint_updated.is_connected(_on_waypoint_updated):
				SpaceWorldManager.waypoint_updated.connect(_on_waypoint_updated)

func _on_waypoint_updated(wp_data: Dictionary) -> void:
	if not wp_data.is_empty() and wp_data.has("pos"):
		set_destination_target(wp_data["pos"])
	else:
		clear_destination_target()

func _on_file_synced(path: String) -> void:
	if "thrusters_tuning.dat" in path:
		load_tuning_configuration()

func load_tuning_configuration() -> void:
	var path_to_load := ""
	if FileAccess.file_exists("user://files/" + TUNING_PATH_PRIMARY):
		path_to_load = "user://files/" + TUNING_PATH_PRIMARY
	elif FileAccess.file_exists("user://files/" + TUNING_PATH_FALLBACK):
		path_to_load = "user://files/" + TUNING_PATH_FALLBACK
	
	if path_to_load.is_empty():
		return
	
	var file := FileAccess.open(path_to_load, FileAccess.READ)
	if not file:
		return
	
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("#") or line.begins_with(";") or line.begins_with("[") or line.is_empty():
			continue
		var parts := line.split("=", false, 1)
		if parts.size() == 2:
			var key: String = parts[0].strip_edges().to_lower()
			var val_str: Variant = parts[1].strip_edges()
			match key:
				"cruise_multiplier":
					cruise_multiplier = val_str.to_float()
				"warmup_time_sec":
					warmup_time_sec = val_str.to_float()
				"proximity_drop_distance":
					proximity_drop_distance = val_str.to_float()
				"heat_penalty":
					heat_penalty = val_str.to_float()
				"required_power_mw":
					required_power_mw = val_str.to_float()
	file.close()

func set_spaceship(ship: Spaceship) -> void:
	spaceship_ref = ship
	if ship and is_instance_valid(ship) and ship.has_method("set_cruise_controller"):
		ship.set_cruise_controller(self)

func get_spaceship() -> Spaceship:
	if spaceship_ref and is_instance_valid(spaceship_ref):
		return spaceship_ref
	_find_or_attach_spaceship()
	return spaceship_ref

func _find_or_attach_spaceship() -> void:
	if SpaceWorldManager:
		var ship := SpaceWorldManager.get_spaceship()
		if ship and is_instance_valid(ship):
			spaceship_ref = ship
			return
	
	# Cerca nel tree o nei parent
	var p := get_parent()
	while p != null:
		if p is Spaceship:
			spaceship_ref = p
			return
		p = p.get_parent()

func set_destination_target(target_pos: Vector3) -> void:
	target_destination = target_pos
	has_target_destination = true
	destination_target_updated.emit(target_destination, true)

func clear_destination_target() -> void:
	target_destination = Vector3.ZERO
	has_target_destination = false
	destination_target_updated.emit(Vector3.ZERO, false)

func set_cruise_coils_power(power_mw: float) -> void:
	cruise_coils_power_mw = maxf(0.0, power_mw)
	is_reactor_peak_active = cruise_coils_power_mw >= required_power_mw
	power_state_changed.emit(is_reactor_peak_active, cruise_coils_power_mw, required_power_mw)
	
	if current_state == State.WARMUP and not is_reactor_peak_active:
		abort_warmup("Picco energetico reattore interrotto (< %.1f MW)" % required_power_mw)
	elif current_state == State.ENGAGED and not is_reactor_peak_active:
		disengage("Alimentazione bobine di crociera insufficiente")

func get_is_powered() -> bool:
	return cruise_coils_power_mw >= required_power_mw

func get_current_speed() -> float:
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		return ship.linear_velocity.length()
	return 0.0

func check_rest_state() -> Dictionary:
	var spd := get_current_speed()
	var is_rest := spd < max_rest_speed
	rest_state_updated.emit(spd, is_rest)
	return {
		"is_valid": is_rest,
		"speed": spd,
		"max_allowed": max_rest_speed
	}

func get_ship_forward_vector() -> Vector3:
	var ship := get_spaceship()
	if ship and is_instance_valid(ship):
		var trans := ship.global_transform if ship.is_inside_tree() else ship.transform
		return -trans.basis.z.normalized()
	return Vector3.FORWARD

func check_vector_alignment() -> Dictionary:
	var ship := get_spaceship()
	var forward_vec := get_ship_forward_vector()
	
	var target_dir := Vector3.ZERO
	if has_target_destination:
		var ship_pos := ship.global_position if (ship and ship.is_inside_tree()) else (ship.position if ship else Vector3.ZERO)
		var diff := target_destination - ship_pos
		if diff.length_squared() > 0.001:
			target_dir = diff.normalized()
		else:
			target_dir = forward_vec
	else:
		# Se non c'è waypoint esplicito, la direzione è allineata sulla prua attuale
		target_dir = forward_vec
	
	var dot_prod := clampf(forward_vec.dot(target_dir), -1.0, 1.0)
	var angle_rad := acos(dot_prod)
	var angle_deg := rad_to_deg(angle_rad)
	var is_aligned := angle_deg <= max_alignment_deg
	
	alignment_updated.emit(angle_deg, is_aligned)
	return {
		"is_valid": is_aligned,
		"angle_deg": angle_deg,
		"max_allowed_deg": max_alignment_deg,
		"target_direction": target_dir
	}

func check_power_state() -> Dictionary:
	var is_powered := cruise_coils_power_mw >= required_power_mw
	power_state_changed.emit(is_powered, cruise_coils_power_mw, required_power_mw)
	return {
		"is_valid": is_powered,
		"current_power_mw": cruise_coils_power_mw,
		"required_power_mw": required_power_mw
	}

## Avvia la sequenza di warmup sequenziale del Cruise Drive
func request_engage() -> Dictionary:
	if current_state == State.ENGAGED:
		return {"success": true, "message": "Cruise Mode già ingaggiata"}
	if current_state == State.WARMUP:
		return {"success": true, "message": "Warmup già in corso"}
	if current_state == State.COOLDOWN or current_state == State.EMERGENCY_DROP:
		return {"success": false, "reason": "Sottosistemi in cooldown termico (%.1fs rimanenti)" % cooldown_timer}
	
	# Verifica Fase 1: Stato di Quiete
	var rest_check := check_rest_state()
	if not rest_check["is_valid"]:
		return {"success": false, "reason": "Velocità nave eccessiva (%.1f m/s > %.1f m/s)" % [rest_check["speed"], max_rest_speed]}
	
	# Verifica Fase 2: Allineamento Vettoriale
	var align_check := check_vector_alignment()
	if not align_check["is_valid"]:
		return {"success": false, "reason": "Disallineamento prua rotta (%.2f° > %.1f°)" % [align_check["angle_deg"], max_alignment_deg]}
	
	# Verifica Fase 3: Picco Energetico Reattore
	var pwr_check := check_power_state()
	if not pwr_check["is_valid"]:
		return {"success": false, "reason": "Potenza bobine insufficiente (%.1f MW / %.1f MW)" % [cruise_coils_power_mw, required_power_mw]}
	
	# Avvio Fase 4: Warmup
	_change_state(State.WARMUP)
	warmup_timer = 0.0
	cruise_forward_direction = align_check["target_direction"]
	warmup_progress_updated.emit(0.0, warmup_time_sec, 0.0)
	
	return {"success": true, "message": "Sequenza di Warmup avviata con successo"}

func abort_warmup(reason: String = "Warmup interrotto") -> void:
	if current_state == State.WARMUP:
		warmup_timer = 0.0
		_change_state(State.IDLE)
		cruise_disengaged.emit(reason)

func engage_cruise() -> void:
	var ship := get_spaceship()
	var align_check := check_vector_alignment()
	cruise_forward_direction = align_check["target_direction"] if has_target_destination else get_ship_forward_vector()
	
	_change_state(State.ENGAGED)
	is_rcs_locked = true
	
	if ship and is_instance_valid(ship):
		var base_speed: float = ship.max_linear_speed
		target_cruise_speed = base_speed * cruise_multiplier
		# Applica spinta iniziale di crociera sub-FTL
		var fwd_dir := cruise_forward_direction.normalized()
		ship.linear_velocity = fwd_dir * target_cruise_speed
		ship.set_flight_inputs(Vector3(0, 0, -1.0), Vector3.ZERO)
	
	cruise_engaged.emit()

func disengage(reason: String = "Disattivazione manuale", is_emergency: bool = false) -> void:
	if current_state != State.ENGAGED and current_state != State.WARMUP:
		return
	
	is_rcs_locked = false
	var ship := get_spaceship()
	
	if is_emergency:
		_change_state(State.EMERGENCY_DROP)
		cooldown_timer = emergency_cooldown_duration
		_apply_heat_penalty(heat_penalty)
		if ship and is_instance_valid(ship):
			# Drop immediato a velocità ordinaria
			ship.linear_velocity = ship.linear_velocity.limit_length(ship.max_linear_speed)
			ship.set_flight_inputs(Vector3.ZERO, Vector3.ZERO)
	else:
		_change_state(State.COOLDOWN)
		cooldown_timer = cooldown_duration
		if ship and is_instance_valid(ship):
			ship.linear_velocity = ship.linear_velocity.limit_length(ship.max_linear_speed)
			ship.set_flight_inputs(Vector3.ZERO, Vector3.ZERO)
	
	cruise_disengaged.emit(reason)

func _apply_heat_penalty(amount: float) -> void:
	current_heat += amount
	heat_penalty_applied.emit(amount, current_heat)
	
	# Notifica danno / calore nel sistema se possibile
	if SpaceWorldManager and SpaceWorldManager.has_method("report_system_alert"):
		SpaceWorldManager.report_system_alert("SURRISCALDAMENTO PROPULSORI (+%.0f°C) PER PROXIMITY DROP!" % amount)

func _change_state(new_state: State) -> void:
	if current_state != new_state:
		var old := current_state
		current_state = new_state
		state_changed.emit(new_state, old)

func _physics_process(delta: float) -> void:
	# Raffreddamento termico graduale
	if current_heat > 0.0:
		current_heat = maxf(0.0, current_heat - delta * 5.0)
	
	match current_state:
		State.IDLE:
			pass
			
		State.WARMUP:
			_process_warmup(delta)
			
		State.ENGAGED:
			_process_engaged_cruise(delta)
			
		State.COOLDOWN, State.EMERGENCY_DROP:
			_process_cooldown(delta)

func _process_warmup(delta: float) -> void:
	# Verifica continua dei 3 vincoli durante il warmup
	var rest_check := check_rest_state()
	if not rest_check["is_valid"]:
		abort_warmup("Movimento rilevato durante warmup (%.1f m/s)" % rest_check["speed"])
		return
	
	var align_check := check_vector_alignment()
	if not align_check["is_valid"]:
		abort_warmup("Disallineamento durante warmup (%.1f°)" % align_check["angle_deg"])
		return
	
	if not get_is_powered():
		abort_warmup("Perdita picco energetico reattore")
		return
	
	warmup_timer += delta
	var ratio := clampf(warmup_timer / maxf(0.01, warmup_time_sec), 0.0, 1.0)
	warmup_progress_updated.emit(warmup_timer, warmup_time_sec, ratio)
	
	if warmup_timer >= warmup_time_sec:
		engage_cruise()

func _process_engaged_cruise(delta: float) -> void:
	var ship := get_spaceship()
	if not ship or not is_instance_valid(ship):
		return
	
	# Blocco RCS manuale durante la crociera
	ship.angular_input = Vector3.ZERO
	ship.angular_velocity = Vector3.ZERO
	
	# Applicazione spinta di crociera esponenziale lineare
	var cur_trans := ship.global_transform if ship.is_inside_tree() else ship.transform
	var cruise_vel_target: Vector3 = -cur_trans.basis.z.normalized() * (ship.max_linear_speed * cruise_multiplier)
	
	# Accelerazione progressiva verso la velocità di crociera
	var cruise_accel: float = ship.linear_acceleration * cruise_multiplier * 1.5
	ship.linear_velocity = ship.linear_velocity.move_toward(cruise_vel_target, cruise_accel * delta)
	cruise_thrust_applied.emit(ship.linear_velocity)
	
	# Monitoraggio Proximity Drop
	_check_proximity_hazards()

func _check_proximity_hazards() -> void:
	var ship := get_spaceship()
	if not ship or not is_instance_valid(ship):
		return
	
	var ship_pos: Vector3 = ship.global_position if ship.is_inside_tree() else ship.position
	var forward_vec := get_ship_forward_vector()
	
	# Controllo entità da SpaceWorldManager
	if SpaceWorldManager and SpaceWorldManager.has_method("get_sensor_entities"):
		var entities: Array[Dictionary] = SpaceWorldManager.get_sensor_entities()
		for ent in entities:
			var ent_pos: Vector3 = ent.get("pos")
			var dist: float = ship_pos.distance_to(ent_pos)
			
			if dist <= proximity_drop_distance:
				# Verifica se l'ostacolo è di fronte / lungo la traiettoria o molto vicino
				var dir_to_ent := (ent_pos - ship_pos).normalized() if dist > 0.001 else forward_vec
				var dot_val := forward_vec.dot(dir_to_ent)
				if dot_val > 0.2 or dist < (proximity_drop_distance * 0.5):
					var obs_name: String = ent.get("name")
					trigger_proximity_drop(obs_name, dist)
					return
	
	# Controllo asteroidi diretti nella space_scene se presente
	if ship.is_inside_tree():
		var asteroids_group := get_tree().get_nodes_in_group("asteroids")
		for ast in asteroids_group:
			if ast is Node3D and is_instance_valid(ast) and ast != ship:
				var dist: float = ship_pos.distance_to(ast.global_position)
				if dist <= proximity_drop_distance:
					trigger_proximity_drop(ast.name, dist)
					return

func trigger_proximity_drop(obstacle_name: String, distance: float) -> void:
	proximity_drop_triggered.emit(obstacle_name, distance)
	disengage("PROXIMITY DROP: Rilevato %s a %.1fm" % [obstacle_name, distance], true)

func _process_cooldown(delta: float) -> void:
	cooldown_timer -= delta
	if cooldown_timer <= 0.0:
		cooldown_timer = 0.0
		_change_state(State.IDLE)
