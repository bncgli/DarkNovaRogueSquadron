@tool
class_name RadarDisplay
extends Control

## Radar Display 2D/3D polare e cartesiano per l'applicazione Sensors (50 km).
## Supporta sweep passivo continuo, ping attivo impulsivo, tracciamento contatti, IFF e ghosts.

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
var max_range: float = 50000.0 # Metri (default 50 km)
var current_mode: DisplayMode = DisplayMode.POLAR_2D
var filter_category: String = "ALL" # ALL, MINERALS, WRECKS, THREATS, BEACONS

# Parametri Sweep e Ping
var sweep_angle: float = 0.0
var sweep_frequency_hz: float = 12.0
var is_sweep_active: bool = true
var ping_active: bool = false
var ping_radius_progress: float = 0.0
var ping_max_radius: float = 50000.0
var ping_speed: float = 25000.0 # m/s

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
		# sweep_frequency_hz determina la velocità angolare dello sweep
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
	var count := randi_range(2, 5)
	for i in range(count):
		var ang := randf_range(0, TAU)
		var d := randf_range(2000, max_range * 0.9)
		_ghosts.append({
			"id": "GHOST_%d" % i,
			"name": "ECO ANOMALO [Ghost-%d]" % i,
			"distance": d,
			"bearing_deg": rad_to_deg(ang),
			"elevation_deg": randf_range(-15, 15),
			"type": "GHOST",
			"iff_tag": "UNKNOWN",
			"stealth_level": 0.0,
			"pos": Vector3(cos(ang) * d, 0, sin(ang) * d)
		})

func trigger_ping(radius: float = 50000.0) -> void:
	ping_active = true
	ping_radius_progress = 0.0
	ping_max_radius = radius
	queue_redraw()

func set_range(r: float) -> void:
	max_range = maxf(r, 1000.0)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var center := size * 0.5
		var radius := minf(center.x, center.y) - 15.0
		var m_pos: Vector2 = event.position
		var delta_pos: Vector2 = m_pos - center
		var click_dist_ratio: float = delta_pos.length() / radius
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Controlla se è stato cliccato un contatto
			var clicked_target := _find_entity_at_screen_pos(m_pos, 16.0)
			if not clicked_target.is_empty():
				selected_entity_id = clicked_target.get("id")
				entity_selected.emit(clicked_target)
			else:
				selected_entity_id = ""
				entity_selected.emit({})
		
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Crea un waypoint tattico alle coordinate cliccate
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
		var s_pos := _world_to_screen(e, center, r)
		if screen_pos.distance_to(s_pos) <= hit_radius:
			return e
	
	for g in _ghosts:
		var s_pos := _world_to_screen(g, center, r)
		if screen_pos.distance_to(s_pos) <= hit_radius:
			return g
	
	return {}

func _passes_filter(e: Dictionary) -> bool:
	var t: String = e.get("type")
	var iff: String = e.get("iff_tag")
	
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
	var dist: float = float(e.get("distance"))
	var norm_dist := clampf(dist / max_range, 0.0, 1.0)
	var bearing: float = deg_to_rad(float(e.get("bearing_deg")) - 90.0)
	
	if current_mode == DisplayMode.ELEVATION_3D:
		var elev: float = deg_to_rad(float(e.get("elevation_deg")))
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
	
	# 3. Effetto Ping Attivo (Onda a espansione)
	if ping_active and ping_max_radius > 0.0:
		var ping_norm := clampf(ping_radius_progress / max_range, 0.0, 1.0)
		var p_r := ping_norm * radius
		var alpha := 1.0 - (ping_radius_progress / ping_max_radius)
		draw_arc(center, p_r, 0, TAU, 64, Color(0.1, 0.9, 1.0, alpha * 0.75), 2.5, true)
		draw_circle(center, p_r, Color(0.1, 0.9, 1.0, alpha * 0.08))
	
	# 4. Sweep passivo rotante
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
	
	# 5. Marcatori contatti ed entità
	_draw_entities(center, radius)
	
	# 6. Ghost contacts se danneggiato
	if has_radar_ghosts:
		_draw_ghosts(center, radius)
	
	# 7. Nave centrale (Propria posizione)
	var ship_pts := PackedVector2Array([
		center + Vector2(0, -8),
		center + Vector2(6, 7),
		center + Vector2(0, 4),
		center + Vector2(-6, 7)
	])
	draw_colored_polygon(ship_pts, Color(0.2, 0.9, 1.0, 0.95))
	draw_polyline(ship_pts, Color(0.8, 1.0, 1.0, 1.0), 1.0)
	
	# 8. Bordo esterno e scala radar
	draw_arc(center, radius, 0, TAU, 72, Color(0.2, 0.7, 0.8, 0.75), 1.5, true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-radius + 5, -radius + 15), "PORTATA: %.0f KM" % (max_range / 1000.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.85, 1.0, 0.8))

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
		
		# Etichette di portata sui cerchi
		var km_val := (max_range * frac) / 1000.0
		var label_str := "%.0f km" % km_val
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
		# Linea verticale delimitata dal cerchio
		var half_h := sqrt(maxf(0.0, radius * radius - offset * offset))
		draw_line(center + Vector2(offset, -half_h), center + Vector2(offset, half_h), Color(0.12, 0.38, 0.48, 0.25), 1.0)
		# Linea orizzontale
		var half_w := sqrt(maxf(0.0, radius * radius - offset * offset))
		draw_line(center + Vector2(-half_w, offset), center + Vector2(half_w, offset), Color(0.12, 0.38, 0.48, 0.25), 1.0)
	
	# Cerchio guida
	draw_arc(center, radius, 0, TAU, 64, Color(0.2, 0.5, 0.6, 0.4), 1.0, true)

func _draw_elevation_3d_grid(center: Vector2, radius: float) -> void:
	# Disegna piano ellittico inclinato 3D
	for i in range(1, 4):
		var frac := float(i) / 3.0
		var rx := radius * frac
		var ry := radius * frac * 0.5
		draw_arc(center, rx, 0, TAU, 48, Color(0.15, 0.4, 0.5, 0.3), 1.0, true)
	
	# Asse Z / Elevazione verticale
	draw_line(center - Vector2(0, radius * 0.8), center + Vector2(0, radius * 0.8), Color(0.2, 0.7, 0.9, 0.4), 1.0)

func _draw_entities(center: Vector2, radius: float) -> void:
	for e in entities:
		if not _passes_filter(e):
			continue
		
		var dist: float = float(e.get("distance"))
		if dist > max_range * 1.05:
			continue
		
		# Controllo stealth
		var stealth: float = float(e.get("stealth_level"))
		if stealth > stealth_threshold and not ping_active:
			continue # Invisibile durante sweep normale a meno di ping attivo
		
		var s_pos := _world_to_screen(e, center, radius)
		var e_id: String = e.get("id")
		var is_sel: bool = (e_id == selected_entity_id)
		var is_lock: bool = (e_id == locked_entity_id)
		var iff: String = e.get("iff_tag")
		var e_type: String = e.get("type")
		
		# Colore IFF
		var col: Color = Color(0.3, 0.8, 0.4) # Neutro / Verde
		if iff == "HAZARD":
			col = Color(1.0, 0.65, 0.2) # Arancio
		elif iff == "HOSTILE":
			col = Color(1.0, 0.25, 0.25) # Rosso
		elif iff == "FRIENDLY":
			col = Color(0.25, 0.85, 1.0) # Ciano
		elif iff == "WAYPOINT":
			col = Color(0.9, 0.3, 1.0) # Magenta
		elif iff == "UNKNOWN":
			col = Color(0.7, 0.7, 0.7) # Grigio
		
		# Simbolo grafico in base al tipo
		match e_type:
			"MINERAL_ASTEROID", "ASTEROID":
				# Rombo minerale
				var diamond := PackedVector2Array([
					s_pos + Vector2(0, -5),
					s_pos + Vector2(5, 0),
					s_pos + Vector2(0, 5),
					s_pos + Vector2(-5, 0)
				])
				draw_colored_polygon(diamond, col)
			"WRECK", "DERELICT":
				# Quadrato cavo con croce
				draw_rect(Rect2(s_pos - Vector2(4, 4), Vector2(8, 8)), col, false, 1.2)
				draw_line(s_pos - Vector2(3, 0), s_pos + Vector2(3, 0), col, 1.0)
			"STATION", "BEACON":
				# Cerchio e triangolo
				draw_arc(s_pos, 5.0, 0, TAU, 16, col, 1.2, true)
				draw_circle(s_pos, 2.0, col)
			"WAYPOINT":
				# Flag / Diamante Waypoint pulsante
				draw_arc(s_pos, 7.0, 0, TAU, 20, col, 1.5, true)
				draw_line(s_pos, s_pos + Vector2(0, -10), col, 1.5)
				draw_colored_polygon(PackedVector2Array([
					s_pos + Vector2(0, -10),
					s_pos + Vector2(6, -7),
					s_pos + Vector2(0, -4)
				]), col)
			"SHIP_HOSTILE", "HOSTILE":
				# Triangolo invertito
				var tri := PackedVector2Array([
					s_pos + Vector2(0, 5),
					s_pos + Vector2(-5, -4),
					s_pos + Vector2(5, -4)
				])
				draw_colored_polygon(tri, col)
			_:
				# Blip circolare standard
				draw_circle(s_pos, 3.5, col)
		
		# Vettore di velocità se in movimento
		var vel: Vector3 = e.get("velocity")
		if vel.length_squared() > 0.05:
			var vel_2d := Vector2(vel.x, -vel.z) * 3.0
			draw_line(s_pos, s_pos + vel_2d, Color(col.r, col.g, col.b, 0.6), 1.0)
		
		# Proiezione gambo in 3D Elevation
		if current_mode == DisplayMode.ELEVATION_3D:
			var bearing: float = deg_to_rad(float(e.get("bearing_deg")) - 90.0)
			var norm_dist := clampf(dist / max_range, 0.0, 1.0)
			var base_plane_pos := center + Vector2(cos(bearing) * norm_dist * radius, sin(bearing) * norm_dist * radius * 0.5)
			draw_dashed_line(base_plane_pos, s_pos, Color(col.r, col.g, col.b, 0.4), 1.0, 2.0)
			draw_circle(base_plane_pos, 1.5, Color(col.r, col.g, col.b, 0.5))
		
		# Rettangolo di Selezione
		if is_sel:
			var box := 14.0
			var b_rect := Rect2(s_pos - Vector2(box, box) * 0.5, Vector2(box, box))
			draw_rect(b_rect, Color(1.0, 0.9, 0.2, 0.9), false, 1.5)
			
			var name_str: String = str(e.get("name"))
			var d_km: float = dist / 1000.0
			var info_txt := "%s [%.1f km]" % [name_str, d_km]
			draw_string(ThemeDB.fallback_font, s_pos + Vector2(10, 3), info_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.95, 0.5, 0.9))
		
		# Riconoscimento Lock
		if is_lock:
			draw_arc(s_pos, 10.0, 0, TAU, 24, Color(1.0, 0.2, 0.2, 0.9), 1.5, true)
			draw_line(s_pos - Vector2(12, 0), s_pos + Vector2(12, 0), Color(1.0, 0.2, 0.2, 0.7), 1.0)
			draw_line(s_pos - Vector2(0, 12), s_pos + Vector2(0, 12), Color(1.0, 0.2, 0.2, 0.7), 1.0)

func _draw_ghosts(center: Vector2, radius: float) -> void:
	for g in _ghosts:
		var s_pos := _world_to_screen(g, center, radius)
		# Blip fantasma sfarfallante
		var f_alpha := randf_range(0.3, 0.8)
		draw_circle(s_pos, 3.0, Color(0.9, 0.8, 0.3, f_alpha))
		draw_arc(s_pos, 6.0, 0, TAU, 12, Color(0.9, 0.4, 0.2, f_alpha * 0.6), 1.0, true)
