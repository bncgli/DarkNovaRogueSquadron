class_name SpaceWeatherManager
extends Node

## Sottosistema per la meteorologia spaziale dinamica e i pericoli ambientali estremi.
## Gestisce il ciclo vitale degli eventi (DORMANT, WARNING, ACTIVE, DISSIPATING)
## e coordina il calcolo dell'esposizione (cono d'ombra planetario macro + riparo micro 3D).

enum WeatherState {
	DORMANT = 0,
	WARNING = 1,
	ACTIVE = 2,
	DISSIPATING = 3
}

enum WeatherHazardType {
	SOLAR_CME = 0,
	ION_EMP_STORM = 1,
	COSMIC_RAD_BURST = 2
}

signal weather_state_changed(state: int, hazard_type: int, time_remaining: float)
signal weather_warning_issued(hazard_type: int, countdown: float, sun_vector: Vector3)
signal weather_wave_impacted(hazard_type: int, effective_exposure: float)
signal weather_cleared()
signal ship_shelter_state_changed(is_sheltered: bool, exposure_factor: float, shelter_source: String)

# --- STATO ATTIVO ---
var current_state: int = WeatherState.DORMANT
var current_hazard_type: int = WeatherHazardType.SOLAR_CME
var state_timer: float = 0.0

var warning_duration: float = 20.0
var active_duration: float = 15.0
var dissipating_duration: float = 5.0

# Vettore normalizzato orientato verso la stella primaria (origine del flusso energetico)
var sun_vector: Vector3 = Vector3(0, 0, -1)

# Esposizione: 0.0 = totalmente protetto, 1.0 = completamente esposto
var current_exposure_factor: float = 1.0
var is_sheltered: bool = false
var shelter_source: String = "NONE"

# Limitazione del calcolo di occlusione locale (frequenza 4 Hz)
var occlusion_check_interval: float = 0.25
var _occlusion_timer: float = 0.0

# Riferimenti opzionali di scena
var spaceship_node: Node3D = null
var grid_manager_ref: Node = null

# Override per test o coordinate simulate
var custom_ship_position: Vector3 = Vector3.ZERO
var has_custom_ship_position: bool = false
var custom_obstacles: Array[Dictionary] = []
var custom_macro_shelter: Dictionary = {}
var has_custom_macro_shelter: bool = false

func set_custom_ship_position(pos: Vector3) -> void:
	custom_ship_position = pos
	has_custom_ship_position = true

func clear_custom_ship_position() -> void:
	has_custom_ship_position = false

func set_custom_obstacles(obstacles: Array[Dictionary]) -> void:
	custom_obstacles = obstacles

func clear_custom_obstacles() -> void:
	custom_obstacles.clear()

func set_custom_macro_shelter(is_sheltered: bool, exposure: float = 0.05, source: String = "PLANETARY_SHADOW") -> void:
	custom_macro_shelter = {
		"is_sheltered": is_sheltered,
		"exposure_factor": exposure,
		"shelter_source": source
	}
	has_custom_macro_shelter = true

func clear_custom_macro_shelter() -> void:
	has_custom_macro_shelter = false
	custom_macro_shelter.clear()

func set_grid_manager(mgr: Node) -> void:
	grid_manager_ref = mgr

func set_sun_vector(vec: Vector3) -> void:
	if vec.length_squared() > 0.0001:
		sun_vector = vec.normalized()
	else:
		sun_vector = Vector3(0, 0, -1)

func _ready() -> void:
	_resolve_dependencies()

func _process(delta: float) -> void:
	_update_weather_lifecycle(delta)
	_update_shelter_evaluation(delta)

func _resolve_dependencies() -> void:
	if grid_manager_ref == null:
		grid_manager_ref = get_node_or_null("/root/StarSystemGridManager")
	
	if spaceship_node == null:
		var swm := get_parent()
		if swm and swm.has_method("get_spaceship"):
			spaceship_node = swm.get_spaceship()

func trigger_weather_event(hazard_type: int, warning_time: float = 20.0, active_time: float = 15.0) -> void:
	current_hazard_type = hazard_type
	warning_duration = maxf(1.0, warning_time)
	active_duration = maxf(1.0, active_time)
	dissipating_duration = 5.0
	
	current_state = WeatherState.WARNING
	state_timer = warning_duration
	
	_update_sun_vector()
	evaluate_ship_shelter()
	
	weather_state_changed.emit(current_state, current_hazard_type, state_timer)
	weather_warning_issued.emit(current_hazard_type, state_timer, sun_vector)

func abort_weather_event() -> void:
	if current_state == WeatherState.DORMANT:
		return
	
	current_state = WeatherState.DORMANT
	state_timer = 0.0
	weather_state_changed.emit(current_state, current_hazard_type, 0.0)
	weather_cleared.emit()

func clear_weather() -> void:
	abort_weather_event()

func _update_sun_vector() -> void:
	if grid_manager_ref and grid_manager_ref.has_method("get_light_direction_from_star"):
		var dir: Vector3 = grid_manager_ref.get_light_direction_from_star()
		if dir.length_squared() > 0.001:
			sun_vector = dir.normalized()
			return
	
	sun_vector = Vector3(0, 0, -1)

func _update_weather_lifecycle(delta: float) -> void:
	if current_state == WeatherState.DORMANT:
		return
	
	state_timer -= delta
	
	match current_state:
		WeatherState.WARNING:
			if state_timer <= 0.0:
				current_state = WeatherState.ACTIVE
				state_timer = active_duration
				weather_state_changed.emit(current_state, current_hazard_type, state_timer)
				
				# Impatto dell'onda energetica/solare
				evaluate_ship_shelter()
				weather_wave_impacted.emit(current_hazard_type, current_exposure_factor)
		
		WeatherState.ACTIVE:
			_apply_active_weather_effects(delta)
			if state_timer <= 0.0:
				current_state = WeatherState.DISSIPATING
				state_timer = dissipating_duration
				weather_state_changed.emit(current_state, current_hazard_type, state_timer)
		
		WeatherState.DISSIPATING:
			if state_timer <= 0.0:
				current_state = WeatherState.DORMANT
				state_timer = 0.0
				weather_state_changed.emit(current_state, current_hazard_type, 0.0)
				weather_cleared.emit()

func _update_shelter_evaluation(delta: float) -> void:
	_occlusion_timer += delta
	if _occlusion_timer >= occlusion_check_interval:
		_occlusion_timer = 0.0
		evaluate_ship_shelter()

func evaluate_ship_shelter() -> Dictionary:
	_update_sun_vector()
	
	# 1. Macro-riparo: occlusione planetaria da StarSystemGridManager
	var macro_shelter := _evaluate_macro_planetary_shelter()
	if bool(macro_shelter.get("is_sheltered", false)):
		_set_shelter_state(true, float(macro_shelter.get("exposure_factor", 0.05)), str(macro_shelter.get("shelter_source", "PLANETARY_SHADOW")))
		return get_ship_shelter_status()
	
	# 2. Micro-riparo: cono d'ombra 3D locale dietro asteroidi massicci o relitti
	var micro_shelter := _calculate_micro_occlusion()
	if bool(micro_shelter.get("is_sheltered", false)):
		_set_shelter_state(true, float(micro_shelter.get("exposure_factor", 0.15)), str(micro_shelter.get("shelter_source", "ASTEROID")))
		return get_ship_shelter_status()
	
	# 3. Nessun riparo (100% esposto)
	_set_shelter_state(false, 1.0, "NONE")
	return get_ship_shelter_status()

func _evaluate_macro_planetary_shelter() -> Dictionary:
	if has_custom_macro_shelter:
		return custom_macro_shelter
	
	if grid_manager_ref:
		if grid_manager_ref.has_method("calculate_planetary_occlusion"):
			var occ: Dictionary = grid_manager_ref.calculate_planetary_occlusion()
			var is_occ: bool = bool(occ.get("is_occluded", false))
			var factor: float = float(occ.get("occlusion_factor", 0.0))
			if is_occ and factor >= 0.75:
				var eff_exposure := clampf(1.0 - factor, 0.05, 0.25)
				return {
					"is_sheltered": true,
					"exposure_factor": eff_exposure,
					"shelter_source": "PLANETARY_SHADOW"
				}
		elif grid_manager_ref.has_method("is_in_planetary_shadow"):
			if grid_manager_ref.is_in_planetary_shadow():
				return {
					"is_sheltered": true,
					"exposure_factor": 0.05,
					"shelter_source": "PLANETARY_SHADOW"
				}
	return {"is_sheltered": false, "exposure_factor": 1.0, "shelter_source": "NONE"}

func _calculate_micro_occlusion() -> Dictionary:
	var ship_pos := Vector3.ZERO
	if has_custom_ship_position:
		ship_pos = custom_ship_position
	else:
		if spaceship_node == null:
			var swm := get_parent()
			if swm and swm.has_method("get_spaceship"):
				spaceship_node = swm.get_spaceship()
		
		if spaceship_node and is_instance_valid(spaceship_node):
			ship_pos = spaceship_node.global_position
	
	var obstacles: Array[Dictionary] = []
	for c_obs in custom_obstacles:
		obstacles.append(c_obs)
	
	var swm := get_parent()
	if swm and swm.has_method("get_sensor_entities"):
		var raw_ents: Array = swm.get_sensor_entities()
		for ent in raw_ents:
			if ent is Dictionary:
				var t: String = str(ent.get("type", ""))
				var r: float = float(ent.get("radius_m", 0.0))
				if r >= 20.0 or t in ["ASTEROID", "MINERAL_ASTEROID", "STATION", "WRECK"]:
					obstacles.append(ent)
	
	if obstacles.is_empty() and is_inside_tree():
		var ast_nodes := get_tree().get_nodes_in_group("asteroids")
		for ast in ast_nodes:
			if ast and is_instance_valid(ast) and ast is Node3D:
				var r: float = float(ast.radius_m) if "radius_m" in ast else 25.0
				obstacles.append({
					"pos": ast.global_position,
					"radius_m": r,
					"type": "ASTEROID"
				})
	
	var best_shelter_factor: float = 0.0
	var best_source: String = "NONE"
	
	# sun_vector punta verso la stella.
	# L'ombra dell'ostacolo viene proiettata lungo -sun_vector.
	# Quindi la nave è al riparo se si trova "dietro" l'ostacolo rispetto alla stella:
	# ship_pos = obs_pos + (-sun_vector * distance)  =>  (ship_pos - obs_pos) è concorde con -sun_vector
	for obs in obstacles:
		var obs_pos: Vector3 = obs.get("pos", obs.get("local_rel_pos", Vector3.ZERO))
		var obs_radius: float = float(obs.get("radius_m", 30.0))
		if obs_radius < 15.0:
			obs_radius = 25.0
		
		var to_ship := ship_pos - obs_pos
		var dist_along_shadow := to_ship.dot(-sun_vector)
		
		# La nave deve essere situata dietro l'ostacolo (fino a 250m)
		if dist_along_shadow > (obs_radius * 0.4) and dist_along_shadow < (obs_radius * 10.0 + 150.0):
			# Distanza perpendicolare dall'asse del cilindro d'ombra
			var perp_vec := to_ship - (-sun_vector * dist_along_shadow)
			var perp_dist := perp_vec.length()
			
			# Espansione minima del cono d'ombra
			var shadow_radius := obs_radius * 1.1
			if perp_dist < shadow_radius:
				var coverage := 1.0 - (perp_dist / shadow_radius)
				var factor := clampf(coverage * 0.85, 0.0, 0.85)
				if factor > best_shelter_factor:
					best_shelter_factor = factor
					best_source = str(obs.get("type", "ASTEROID"))
	
	if best_shelter_factor > 0.3:
		var eff_exposure := clampf(1.0 - best_shelter_factor, 0.1, 0.7)
		return {
			"is_sheltered": true,
			"exposure_factor": eff_exposure,
			"shelter_source": best_source
		}
	
	return {"is_sheltered": false, "exposure_factor": 1.0, "shelter_source": "NONE"}

func _set_shelter_state(new_sheltered: bool, new_exposure: float, new_source: String) -> void:
	var changed := (is_sheltered != new_sheltered) or (absf(current_exposure_factor - new_exposure) > 0.05) or (shelter_source != new_source)
	is_sheltered = new_sheltered
	current_exposure_factor = clampf(new_exposure, 0.0, 1.0)
	shelter_source = new_source
	
	if changed:
		ship_shelter_state_changed.emit(is_sheltered, current_exposure_factor, shelter_source)

func _apply_active_weather_effects(delta: float) -> void:
	if current_exposure_factor <= 0.05:
		return
	
	var swm := get_parent()
	if swm == null:
		return
	
	match current_hazard_type:
		WeatherHazardType.SOLAR_CME:
			# Impulso termico progressivo e sovraccarico
			if swm.has_method("apply_solar_heat_surge"):
				swm.apply_solar_heat_surge(35.0 * current_exposure_factor * delta)
		
		WeatherHazardType.ION_EMP_STORM:
			# Drenaggio e interferenza magnetica
			if swm.has_method("apply_ion_emp_interference"):
				swm.apply_ion_emp_interference(current_exposure_factor * delta)
		
		WeatherHazardType.COSMIC_RAD_BURST:
			# Incremento radiazioni nei sistemi di bordo
			if swm.has_method("apply_cosmic_radiation"):
				swm.apply_cosmic_radiation(current_exposure_factor * delta)

func get_active_weather_info() -> Dictionary:
	return {
		"state": current_state,
		"hazard_type": current_hazard_type,
		"time_remaining": state_timer,
		"is_sheltered": is_sheltered,
		"exposure_factor": current_exposure_factor,
		"shelter_source": shelter_source,
		"sun_vector": sun_vector
	}

func get_ship_shelter_status() -> Dictionary:
	return {
		"is_sheltered": is_sheltered,
		"exposure_factor": current_exposure_factor,
		"shelter_source": shelter_source,
		"occlusion_factor": clampf(1.0 - current_exposure_factor, 0.0, 1.0)
	}

func get_hazard_name(hazard_type: int = current_hazard_type) -> String:
	match hazard_type:
		WeatherHazardType.SOLAR_CME:
			return "SOLAR CME"
		WeatherHazardType.ION_EMP_STORM:
			return "ION/EMP STORM"
		WeatherHazardType.COSMIC_RAD_BURST:
			return "COSMIC RADIATION BURST"
		_:
			return "UNKNOWN HAZARD"
