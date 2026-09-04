@tool
class_name RadarDisplay
extends Control

## Radar Display 2D/3D polare e cartesiano per l'applicazione Sensors (1 km standard, 2 km ping).
## Supporta sweep passivo, ombreggiamento Line of Sight da ostacoli, feed radar Probe e ping energetico.

signal entity_selected(entity_data: Dictionary)
signal entity_locked(entity_data: Dictionary)
signal waypoint_placed(world_pos: Vector3)

enum DisplayMode {
	POLAR_2D,
	CARTESIAN_GRID,
	ELEVATION_3D
}

# --- STATO E PARAMETRI RUNTIME ---
var entities: Array[Dictionary] = []
var selected_entity_id: String = ""
var locked_entity_id: String = ""
var max_range: float = 1000.0 # Metri (default 1 km standard)
var current_mode: DisplayMode = DisplayMode.POLAR_2D
var filter_category: String = "ALL"

# Feed sonda telemetrica (Probe)
var probe_data: Dictionary = {}

# Parametri Sweep e Ping
var sweep_angle: float = 0.0
var sweep_frequency_hz: float = 12.0
var is_sweep_active: bool = true
var ping_active: bool = false
var ping_radius_progress: float = 0.0
var ping_max_radius: float = 2000.0 # 2 km
var ping_speed: float = 1000.0 # m/s

# Parametri Tuning e Danni
var noise_filter: float = 0.92
var spectrum_sensitivity: float = 1.0
var iff_auto_tag: bool = true
var stealth_threshold: float = 0.35
var has_radar_ghosts: bool = false
var is_powered: bool = true

# Ghost Contacts generati se danneggiato
var _ghost_timer: float = 0.0
var _ghosts: Array[Dictionary] = []

func _ready() -> void:
	custom_minimum_size = Vector2(380, 380)

func _process(delta: float) -> void:
	if is_sweep_active and is_powered:
		sweep_angle = fmod(sweep_angle + delta * (sweep_frequency_hz * 0.15), TAU)
	
	if ping_active:
		ping_radius_progress += ping_speed * delta
		if ping_radius_progress >= ping_max_radius:
			ping_active = false
			ping_radius_progress = 0.0
	
	if has_radar_ghosts:
		_ghost_timer += delta
		if _ghost_timer >= 2.0:
			_ghost_timer = 0.0
			_generate_ghosts()
	else:
		_ghosts.clear()
	
	queue_redraw()

func _generate_ghosts() -> void:
	_ghosts.clear()
	var count := randi_range(2, 4)
	for i in range(count):
		var ang := randf_range(0, TAU)
		var d := randf_range(150.0, max_range * 0.95)
		_ghosts.append({
			"id": "GHOST_%d" % i,
			"name": "ECO ANOMALO [Ghost-%d]" % i,
			"distance": d,
			"bearing_deg": rad_to_deg(ang),
			"elevation_deg": randf_range(-15, 15),
			"type": "GHOST",
			"iff_tag": "UNKNOWN",
			"stealth_level": 0.0,
			"signal_signature": 0.5,
			"pos": Vector3(cos(ang) * d, 0, sin(ang) * d)
		})

func trigger_ping(radius: float = 2000.0) -> void:
	ping_active = true
	ping_radius_progress = 0.0
	ping_max_radius = radius
	queue_redraw()

func set_range(r: float) -> void:
	max_range = maxf(r, 200.0)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var center := size * 0.5
		var radius := minf(center.x, center.y) - 15.0
		var m_pos: Vector2 = event.position
		var delta_pos: Vector2 = m_pos - center
		var click_dist_ratio: float = delta_pos.length() / radius
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			var clicked_target := _find_entity_at_screen_pos(m_pos, 16.0)
			if not clicked_target.is_empty():
				selected_entity_id = str(clicked_target.get("id"))
				entity_selected.emit(clicked_target)
			else:
				selected_entity_id = ""
				entity_selected.emit({})
		
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if click_dist_ratio <= 1.05:
				var world_dist: float = click_dist_ratio * max_range
				var angle := atan2(delta_pos.y, delta_pos.x) + PI * 0.5
				var wx: float = sin(angle) * world_dist
				var wz: float = -cos(angle) * world_dist
				var wp_pos := Vector3(wx, 0.0, wz)
				waypoint_placed.emit(wp_pos)

func _find_entity_at_screen_pos(screen_pos: Vector2, hit_radius: float) -> Dictionary:
	var center := size * 0.5
	var r := minf(center.x, center.y) - 15.0
	
	for e in entities:
		if not _passes_filter(e):
			continue
		if bool(e.get("is_occluded", false)) and not ping_active and not bool(e.get("is_revealed_by_probe", false)):
			continue
		var s_pos := _world_to_screen(e, center, r)
		if screen_pos.distance_to(s_pos) <= hit_radius:
			return e
	
	for g in _ghosts:
		var s_pos := _world_to_screen(g, center, r)
		if screen_pos.distance_to(s_pos) <= hit_radius:
			return g
	
	return {}

func _passes_filter(e: Dictionary) -> bool:
	var t: String = str(e.get("type", ""))
	var iff: String = str(e.get("iff_tag", ""))
	
	match filter_category:
		"MINERALS":
			return t in ["ASTEROID", "MINERAL_ASTEROID"]
		"WRECKS":
			return t in ["WRECK", "DERELICT"]
		"THREATS":
			return iff in ["HOSTILE", "HAZARD"] or t in ["SHIP_HOSTILE"]
		"BEACONS":
			return t in ["BEACON", "STATION", "WAYPOINT"]
		_:
			return true

func _world_to_screen(e: Dictionary, center: Vector2, radius: float) -> Vector2:
	var dist: float = float(e.get("distance", 0.0))
	var norm_dist := clampf(dist / max_range, 0.0, 1.1)
	var bearing: float = deg_to_rad(float(e.get("bearing_deg", 0.0)) - 90.0)
	
	if current_mode == DisplayMode.ELEVATION_3D:
		var elev: float = deg_to_rad(float(e.get("elevation_deg", 0.0)))
		var x := cos(bearing) * norm_dist * radius
		var y := sin(bearing) * norm_dist * radius * 0.5 - sin(elev) * (radius * 0.35)
		return center + Vector2(x, y)
	
	return center + Vector2(cos(bearing), sin(bearing)) * (norm_dist * radius)

func _world_pos_to_screen(world_pos: Vector3, center: Vector2, radius: float) -> Vector2:
	var dist := Vector2(world_pos.x, world_pos.z).length()
	var norm_dist := clampf(dist / max_range, 0.0, 1.2)
	var bearing_deg := rad_to_deg(atan2(world_pos.x, -world_pos.z))
	var bearing := deg_to_rad(bearing_deg - 90.0)
	
	if current_mode == DisplayMode.ELEVATION_3D:
		var elev_deg := rad_to_deg(atan2(world_pos.y, maxf(0.001, dist)))
		var elev := deg_to_rad(elev_deg)
		var x := cos(bearing) * norm_dist * radius
		var y := sin(bearing) * norm_dist * radius * 0.5 - sin(elev) * (radius * 0.35)
		return center + Vector2(x, y)
	
	return center + Vector2(cos(bearing), sin(bearing)) * (norm_dist * radius)

# --- DRAW ROUTINE ---

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(center.x, center.y) - 15.0
	if radius <= 20.0:
		return
	
	if not is_powered:
		_draw_unpowered_screen(center, radius)
		return
	
	# 1. Sfondo base radar
	draw_circle(center, radius, Color(0.02, 0.05, 0.08, 0.88))
	
	# 2. Griglia di fondo in base alla modalità
	if current_mode == DisplayMode.POLAR_2D:
		_draw_polar_grid(center, radius)
	elif current_mode == DisplayMode.CARTESIAN_GRID:
		_draw_cartesian_grid(center, radius)
	elif current_mode == DisplayMode.ELEVATION_3D:
		_draw_elevation_3d_grid(center, radius)
	
	# 3. Disegno Coni d'Ombra Ostacoli (Line of Sight Shadows)
	_draw_obstacle_shadows(center, radius)
	
	# 4. Disegno Feed Radar Sonda Telemetrica (Probe Feed)
	_draw_probe_feed(center, radius)
	
	# 5. Effetto Ping Attivo (Onda a espansione)
	if ping_active and ping_max_radius > 0.0:
		var ping_norm := clampf(ping_radius_progress / max_range, 0.0, 1.0)
		var p_r := ping_norm * radius
		var alpha := 1.0 - (ping_radius_progress / ping_max_radius)
		draw_arc(center, p_r, 0, TAU, 64, Color(0.1, 0.9, 1.0, alpha * 0.75), 2.5, true)
		draw_circle(center, p_r, Color(0.1, 0.9, 1.0, alpha * 0.08))
	
	# 6. Sweep passivo rotante
	if is_sweep_active:
		var sweep_len := radius
		var sweep_dir := Vector2(cos(sweep_angle), sin(sweep_angle))
		var sweep_end := center + sweep_dir * sweep_len
		draw_line(center, sweep_end, Color(0.2, 0.9, 0.5, 0.6), 1.5)
		
		# Settore di decadimento luminosità
		var trail_segments := 8
		for i in range(1, trail_segments + 1):
			var trail_ang := sweep_angle - float(i) * 0.04
			var trail_end := center + Vector2(cos(trail_ang), sin(trail_ang)) * sweep_len
			var t_alpha := (1.0 - float(i) / float(trail_segments)) * 0.25
			draw_line(center, trail_end, Color(0.2, 0.9, 0.5, t_alpha), 1.2)
	
	# 7. Marcatori contatti ed entità (Radar Puro Diegetico)
	_draw_entities(center, radius)
	
	# 8. Ghost contacts se danneggiato
	if has_radar_ghosts:
		_draw_ghosts(center, radius)
	
	# 9. Nave centrale (Propria posizione)
	var ship_pts := PackedVector2Array([
		center + Vector2(0, -8),
		center + Vector2(6, 7),
		center + Vector2(0, 4),
		center + Vector2(-6, 7)
	])
	draw_colored_polygon(ship_pts, Color(0.2, 0.9, 1.0, 0.95))
	draw_polyline(ship_pts, Color(0.8, 1.0, 1.0, 1.0), 1.0)
	
	# 10. Bordo esterno e scala radar
	draw_arc(center, radius, 0, TAU, 72, Color(0.2, 0.7, 0.8, 0.75), 1.5, true)
	var scale_str := "PORTATA: %.1f KM" % (max_range / 1000.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-radius + 5, -radius + 15), scale_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.85, 1.0, 0.8))

func _draw_unpowered_screen(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, Color(0.04, 0.04, 0.04, 0.9))
	draw_arc(center, radius, 0, TAU, 64, Color(0.5, 0.2, 0.2, 0.6), 1.5, true)
	draw_line(center - Vector2(radius * 0.5, 0), center + Vector2(radius * 0.5, 0), Color(0.8, 0.2, 0.2, 0.5), 1.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-90, 4), "⚠️ ALIMENTAZIONE INSUFFICIENTE", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1.0, 0.3, 0.3, 0.9))

func _draw_polar_grid(center: Vector2, radius: float) -> void:
	var rings := 4
	for i in range(1, rings + 1):
		var frac := float(i) / float(rings)
		var r := radius * frac
		var ring_col := Color(0.12, 0.35, 0.45, 0.35)
		draw_arc(center, r, 0, TAU, 48, ring_col, 1.0, true)
		
		var m_val := max_range * frac
		var label_str := "%.0f m" % m_val if max_range <= 1500.0 else "%.1f km" % (m_val / 1000.0)
		draw_string(ThemeDB.fallback_font, center + Vector2(4, -r + 11), label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.3, 0.7, 0.8, 0.5))
	
	# Assi primari ortogonali (N, S, E, O)
	draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(0.15, 0.45, 0.55, 0.3), 1.0)
	draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color(0.15, 0.45, 0.55, 0.3), 1.0)
	
	# Assi diagonali (45°, 135°, 225°, 315°)
	var diag := radius * 0.7071
	draw_line(center - Vector2(diag, diag), center + Vector2(diag, diag), Color(0.12, 0.35, 0.45, 0.2), 1.0)
	draw_line(center - Vector2(diag, -diag), center + Vector2(diag, -diag), Color(0.12, 0.35, 0.45, 0.2), 1.0)

func _draw_cartesian_grid(center: Vector2, radius: float) -> void:
	var grid_steps := 6
	var step_size := (radius * 2.0) / float(grid_steps)
	
	for i in range(grid_steps + 1):
		var offset := -radius + float(i) * step_size
		var half_h := sqrt(maxf(0.0, radius * radius - offset * offset))
		draw_line(center + Vector2(offset, -half_h), center + Vector2(offset, half_h), Color(0.12, 0.38, 0.48, 0.25), 1.0)
		var half_w := sqrt(maxf(0.0, radius * radius - offset * offset))
		draw_line(center + Vector2(-half_w, offset), center + Vector2(half_w, offset), Color(0.12, 0.38, 0.48, 0.25), 1.0)
	
	draw_arc(center, radius, 0, TAU, 64, Color(0.2, 0.5, 0.6, 0.4), 1.0, true)

func _draw_elevation_3d_grid(center: Vector2, radius: float) -> void:
	for i in range(1, 4):
		var frac := float(i) / 3.0
		var rx := radius * frac
		var ry := radius * frac * 0.5
		draw_arc(center, rx, 0, TAU, 48, Color(0.15, 0.4, 0.5, 0.3), 1.0, true)
	
	draw_line(center - Vector2(0, radius * 0.8), center + Vector2(0, radius * 0.8), Color(0.2, 0.7, 0.9, 0.4), 1.0)

## Disegna le proiezioni dei coni d'ombra proiettati dai corpi massivi / asteroidi
func _draw_obstacle_shadows(center: Vector2, radius: float) -> void:
	for e in entities:
		var t: String = str(e.get("type", ""))
		var r_m: float = float(e.get("radius_m", 0.0))
		if r_m <= 0.0 and t not in ["ASTEROID", "MINERAL_ASTEROID", "STATION", "WRECK"]:
			continue
		
		if r_m <= 0.0:
			r_m = 25.0
		
		var dist: float = float(e.get("distance", 0.0))
		if dist <= 5.0 or dist > max_range * 1.5:
			continue
		
		var obs_screen := _world_to_screen(e, center, radius)
		var d_vec := obs_screen - center
		var d_len := d_vec.length()
		if d_len <= 2.0:
			continue
		
		var obs_rad := clampf((r_m / max_range) * radius, 4.0, 28.0)
		var ang := atan2(d_vec.y, d_vec.x)
		var ratio := clampf(obs_rad / maxf(d_len, obs_rad + 0.1), 0.0, 0.99)
		var delta_ang := asin(ratio)
		
		var t1 := obs_screen + Vector2(cos(ang - PI * 0.5 + delta_ang), sin(ang - PI * 0.5 + delta_ang)) * obs_rad
		var t2 := obs_screen + Vector2(cos(ang + PI * 0.5 - delta_ang), sin(ang + PI * 0.5 - delta_ang)) * obs_rad
		var f_len := radius * 1.3
		var t3 := center + Vector2(cos(ang + delta_ang), sin(ang + delta_ang)) * f_len
		var t4 := center + Vector2(cos(ang - delta_ang), sin(ang - delta_ang)) * f_len
		
		# Disegna il poligono d'ombra radar
		var shadow_poly := PackedVector2Array([t1, t2, t3, t4])
		draw_colored_polygon(shadow_poly, Color(0.01, 0.02, 0.04, 0.55))
		draw_line(t1, t4, Color(0.12, 0.22, 0.32, 0.25), 1.0)
		draw_line(t2, t3, Color(0.12, 0.22, 0.32, 0.25), 1.0)

## Disegna l'area di copertura e il feed radar della sonda telemetrica secondaria
func _draw_probe_feed(center: Vector2, radius: float) -> void:
	if probe_data.is_empty():
		return
	
	var probe_pos: Vector3 = probe_data.get("pos", Vector3.ZERO)
	var probe_scan_r: float = float(probe_data.get("scan_radius", 1000.0))
	var p_screen := _world_pos_to_screen(probe_pos, center, radius)
	var p_screen_r := (probe_scan_r / max_range) * radius
	
	# Cerchio di copertura radar della sonda
	draw_circle(p_screen, p_screen_r, Color(0.08, 0.55, 0.85, 0.07))
	draw_arc(p_screen, p_screen_r, 0, TAU, 48, Color(0.2, 0.85, 1.0, 0.4), 1.2, true)
	
	# Indicatore icona sonda
	var probe_diamond := PackedVector2Array([
		p_screen + Vector2(0, -4),
		p_screen + Vector2(4, 0),
		p_screen + Vector2(0, 4),
		p_screen + Vector2(-4, 0)
	])
	draw_colored_polygon(probe_diamond, Color(0.3, 0.95, 1.0, 0.9))
	draw_polyline(probe_diamond, Color(0.8, 1.0, 1.0, 1.0), 1.0)
	draw_string(ThemeDB.fallback_font, p_screen + Vector2(7, 3), "PROBE FEED", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.35, 0.9, 1.0, 0.85))

func _draw_entities(center: Vector2, radius: float) -> void:
	for e in entities:
		if not _passes_filter(e):
			continue
		
		var dist: float = float(e.get("distance", 0.0))
		var is_occluded: bool = bool(e.get("is_occluded", false))
		var is_revealed_by_probe: bool = bool(e.get("is_revealed_by_probe", false))
		var e_type: String = str(e.get("type", ""))
		
		# Se il contatto è in ombra rispetto alla nave e non è rivelato da una sonda (e non c'è ping attivo)
		if is_occluded and not ping_active and not is_revealed_by_probe and e_type != "WAYPOINT":
			continue
		
		if dist > max_range * 1.05 and not ping_active and not is_revealed_by_probe:
			continue
		
		# Controllo stealth
		var stealth: float = float(e.get("stealth_level", 0.0))
		if stealth > stealth_threshold and not ping_active:
			continue
		
		var s_pos := _world_to_screen(e, center, radius)
		var e_id: String = str(e.get("id", ""))
		var is_sel: bool = (e_id == selected_entity_id)
		var is_lock: bool = (e_id == locked_entity_id)
		
		# --- RENDERING RADAR DIEGETICO PURO ---
		# Nessuna classificazione magica o colore fazioni IFF automatico cheat!
		if e_type == "WAYPOINT":
			var wp_col := Color(0.9, 0.3, 1.0)
			draw_arc(s_pos, 7.0, 0, TAU, 20, wp_col, 1.5, true)
			draw_line(s_pos, s_pos + Vector2(0, -10), wp_col, 1.5)
			draw_colored_polygon(PackedVector2Array([
				s_pos + Vector2(0, -10),
				s_pos + Vector2(6, -7),
				s_pos + Vector2(0, -4)
			]), wp_col)
		elif e_type == "PROBE":
			var prb_col := Color(0.2, 0.85, 1.0)
			draw_circle(s_pos, 3.5, prb_col)
			draw_arc(s_pos, 6.0, 0, TAU, 16, prb_col, 1.0, true)
		else:
			# Blip / Eco diegetico
			var blip_col: Color = Color(0.3, 0.95, 0.45, 0.9)
			if is_revealed_by_probe:
				blip_col = Color(0.2, 0.88, 1.0, 0.95) # Feed sonda (ciano)
			
			var sig: float = float(e.get("signal_signature", 0.5))
			var blip_size: float = clampf(3.0 + sig * 2.5, 3.0, 6.0)
			
			draw_circle(s_pos, blip_size, blip_col)
			draw_arc(s_pos, blip_size + 2.0, 0, TAU, 16, Color(blip_col.r, blip_col.g, blip_col.b, 0.35), 1.0, true)
			
			# Vettore di velocità relativa
			var vel: Vector3 = e.get("velocity", Vector3.ZERO)
			if vel.length_squared() > 0.05:
				var vel_2d := Vector2(vel.x, -vel.z) * 3.0
				draw_line(s_pos, s_pos + vel_2d, Color(blip_col.r, blip_col.g, blip_col.b, 0.5), 1.0)
		
		# Proiezione gambo in 3D Elevation
		if current_mode == DisplayMode.ELEVATION_3D:
			var bearing: float = deg_to_rad(float(e.get("bearing_deg", 0.0)) - 90.0)
			var norm_dist := clampf(dist / max_range, 0.0, 1.0)
			var base_plane_pos := center + Vector2(cos(bearing) * norm_dist * radius, sin(bearing) * norm_dist * radius * 0.5)
			draw_dashed_line(base_plane_pos, s_pos, Color(0.3, 0.8, 0.9, 0.4), 1.0, 2.0)
			draw_circle(base_plane_pos, 1.5, Color(0.3, 0.8, 0.9, 0.5))
		
		# Rettangolo di Selezione
		if is_sel:
			var box := 14.0
			var b_rect := Rect2(s_pos - Vector2(box, box) * 0.5, Vector2(box, box))
			draw_rect(b_rect, Color(1.0, 0.9, 0.2, 0.9), false, 1.5)
			
			var d_km: float = dist / 1000.0
			var info_txt := "ECO #%s [%.2f km]" % [e_id, d_km]
			if e_type == "WAYPOINT":
				info_txt = "WAYPOINT [%.2f km]" % d_km
			elif e_type == "PROBE":
				info_txt = "PROBE [%.2f km]" % d_km
			elif is_revealed_by_probe:
				info_txt = "ECO (PROBE) #%s [%.2f km]" % [e_id, d_km]
			
			draw_string(ThemeDB.fallback_font, s_pos + Vector2(10, 3), info_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.95, 0.5, 0.9))
		
		# Riconoscimento Lock
		if is_lock:
			draw_arc(s_pos, 10.0, 0, TAU, 24, Color(1.0, 0.2, 0.2, 0.9), 1.5, true)
			draw_line(s_pos - Vector2(12, 0), s_pos + Vector2(12, 0), Color(1.0, 0.2, 0.2, 0.7), 1.0)
			draw_line(s_pos - Vector2(0, 12), s_pos + Vector2(0, 12), Color(1.0, 0.2, 0.2, 0.7), 1.0)

func _draw_ghosts(center: Vector2, radius: float) -> void:
	for g in _ghosts:
		var s_pos := _world_to_screen(g, center, radius)
		var f_alpha := randf_range(0.3, 0.8)
		draw_circle(s_pos, 3.0, Color(0.9, 0.8, 0.3, f_alpha))
		draw_arc(s_pos, 6.0, 0, TAU, 12, Color(0.9, 0.4, 0.2, f_alpha * 0.6), 1.0, true)
