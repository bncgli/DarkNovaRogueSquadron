@tool
class_name StarSystemCanvas
extends Control

## Canvas 2D interattivo per la visualizzazione e l'editing della griglia del sistema stellare e dei corpi celesti.

signal entity_selected(body: CelestialBodyData)
signal sector_clicked(coords: Vector3i)
signal entity_moved(body_id: String, old_coords: Vector3i, new_coords: Vector3i)
signal cursor_coords_changed(coords: Vector3i)

var system_data: StarSystemData = null

# Visualizzazione e Camera
var zoom_level: float = 1.0 # 0.2 a 4.0
var pan_offset: Vector2 = Vector2.ZERO
var is_panning: bool = false
var pan_start_pos: Vector2 = Vector2.ZERO
var pan_start_offset: Vector2 = Vector2.ZERO

# Dimensione cella di griglia a schermo (in pixel con zoom 1.0)
const CELL_SIZE: float = 40.0

# Layer visibilità
var show_grid: bool = true
var show_orbits: bool = true
var show_shadow_cones: bool = true
var show_labels: bool = true
var show_sectors_id: bool = true

# Selezione e Dragging
var selected_body_id: String = ""
var is_dragging: bool = false
var drag_body_id: String = ""
var drag_start_coords: Vector3i = Vector3i.ZERO
var _has_user_panned: bool = false

# Colori entità per tipo
const TYPE_COLORS := {
	"STAR": Color(1.0, 0.85, 0.2, 1.0),
	"PLANET": Color(0.3, 0.7, 1.0, 1.0),
	"GAS_GIANT": Color(0.9, 0.5, 0.2, 1.0),
	"MOON": Color(0.7, 0.75, 0.8, 1.0),
	"STATION": Color(0.2, 1.0, 0.4, 1.0),
	"ASTEROID_FIELD": Color(0.7, 0.55, 0.35, 1.0),
	"WRECK": Color(0.8, 0.2, 0.2, 1.0),
	"PATROL": Color(0.9, 0.3, 0.9, 1.0)
}

func reset_view() -> void:
	zoom_level = 1.0
	_has_user_panned = false
	pan_offset = size * 0.5
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if not _has_user_panned:
			pan_offset = size * 0.5
		queue_redraw()

func world_to_screen(grid_coords: Vector2) -> Vector2:
	return pan_offset + (grid_coords * CELL_SIZE * zoom_level)

func screen_to_world(screen_pos: Vector2) -> Vector2:
	return (screen_pos - pan_offset) / (CELL_SIZE * zoom_level)

func screen_to_grid_coords(screen_pos: Vector2) -> Vector3i:
	var w := screen_to_world(screen_pos)
	return Vector3i(int(round(w.x)), int(round(w.y)), 0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE or (mb.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SPACE)):
			if mb.pressed:
				is_panning = true
				pan_start_pos = mb.position
				pan_start_offset = pan_offset
			else:
				is_panning = false
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			var mouse_world_before := screen_to_world(mb.position)
			zoom_level = clampf(zoom_level * 1.15, 0.15, 5.0)
			pan_offset = mb.position - (mouse_world_before * CELL_SIZE * zoom_level)
			_has_user_panned = true
			queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var mouse_world_before := screen_to_world(mb.position)
			zoom_level = clampf(zoom_level / 1.15, 0.15, 5.0)
			pan_offset = mb.position - (mouse_world_before * CELL_SIZE * zoom_level)
			_has_user_panned = true
			queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var hit_body := _find_body_at_pos(mb.position)
				if hit_body:
					selected_body_id = hit_body.id
					drag_body_id = selected_body_id
					drag_start_coords = hit_body.coords
					is_dragging = true
					entity_selected.emit(hit_body)
				else:
					selected_body_id = ""
					var g_coords := screen_to_grid_coords(mb.position)
					sector_clicked.emit(g_coords)
				queue_redraw()
			else:
				if is_dragging:
					is_dragging = false
					var new_g_coords := screen_to_grid_coords(mb.position)
					entity_moved.emit(drag_body_id, drag_start_coords, new_g_coords)
					drag_body_id = ""
					queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				var g_coords := screen_to_grid_coords(mb.position)
				sector_clicked.emit(g_coords)

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if is_panning:
			pan_offset = pan_start_offset + (mm.position - pan_start_pos)
			_has_user_panned = true
			queue_redraw()
		elif is_dragging and not drag_body_id.is_empty() and system_data != null:
			var new_coords := screen_to_grid_coords(mm.position)
			var b := system_data.get_body(drag_body_id)
			if b:
				b.coords = new_coords
				queue_redraw()
		
		var cur_coords := screen_to_grid_coords(mm.position)
		cursor_coords_changed.emit(cur_coords)

func _find_body_at_pos(screen_pos: Vector2) -> CelestialBodyData:
	if system_data == null:
		return null
	
	for i in range(system_data.celestial_bodies.size() - 1, -1, -1):
		var body = system_data.celestial_bodies[i]
		if not (body is CelestialBodyData):
			continue
		var c: Vector3i = body.coords
		var center := world_to_screen(Vector2(c.x, c.y))
		var r := _get_body_render_radius(body)
		if screen_pos.distance_to(center) <= maxf(r + 4.0, 10.0):
			return body
	return null

func _get_body_render_radius(body: CelestialBodyData) -> float:
	if body == null:
		return 6.0 * clampf(zoom_level, 0.6, 2.5)
	var t: String = body.type.to_upper()
	var base_r: float = 6.0
	match t:
		"STAR":
			base_r = 16.0
		"GAS_GIANT":
			base_r = 12.0
		"PLANET":
			base_r = 8.0
		"MOON":
			base_r = 5.0
		"STATION":
			base_r = 6.0
		"ASTEROID_FIELD":
			base_r = 10.0
		"WRECK":
			base_r = 5.0
		"PATROL":
			base_r = 4.0
	return base_r * clampf(zoom_level, 0.6, 2.5)

func _draw() -> void:
	# Sfondo spazio profondo
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.08, 1.0), true)
	
	if show_grid:
		_draw_grid()
		
	if system_data == null:
		return
		
	if show_orbits:
		_draw_orbits()
		
	if show_shadow_cones:
		_draw_shadow_cones()
		
	_draw_celestial_bodies()

func _draw_grid() -> void:
	var top_left_world := screen_to_world(Vector2.ZERO)
	var bottom_right_world := screen_to_world(size)
	
	var min_x := int(floor(top_left_world.x)) - 1
	var max_x := int(ceil(bottom_right_world.x)) + 1
	var min_y := int(floor(top_left_world.y)) - 1
	var max_y := int(ceil(bottom_right_world.y)) + 1
	
	var grid_color := Color(0.15, 0.2, 0.28, 0.4)
	var axis_color := Color(0.3, 0.45, 0.65, 0.8)
	
	# Linee verticali
	for gx in range(min_x, max_x + 1):
		var p1 := world_to_screen(Vector2(gx, min_y))
		var p2 := world_to_screen(Vector2(gx, max_y))
		var col := axis_color if gx == 0 else grid_color
		var width := 1.5 if gx == 0 else 1.0
		draw_line(p1, p2, col, width)
		
	# Linee orizzontali
	for gy in range(min_y, max_y + 1):
		var p1 := world_to_screen(Vector2(min_x, gy))
		var p2 := world_to_screen(Vector2(max_x, gy))
		var col := axis_color if gy == 0 else grid_color
		var width := 1.5 if gy == 0 else 1.0
		draw_line(p1, p2, col, width)
		
	# Coordinate sui settori se zoom adeguato
	if show_sectors_id and zoom_level >= 0.7:
		var font: Font = get_theme_default_font()
		if font == null:
			font = ThemeDB.fallback_font
		if font != null:
			var font_size := int(clampi(int(9 * zoom_level), 8, 12))
			for gx in range(min_x, max_x):
				for gy in range(min_y, max_y):
					var cell_center := world_to_screen(Vector2(gx, gy))
					var sec_id := SectorData.format_coords_to_id(Vector3i(gx, gy, 0))
					draw_string(font, cell_center + Vector2(-18 * zoom_level, 16 * zoom_level), sec_id, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.3, 0.4, 0.5, 0.5))

func _draw_orbits() -> void:
	var star_coords :Vector3i = system_data.primary_star_coords
	var star_center := world_to_screen(Vector2(star_coords.x, star_coords.y))
	var orbit_color := Color(0.25, 0.35, 0.5, 0.3)
	
	for body in system_data.celestial_bodies:
		if not (body is CelestialBodyData):
			continue
		var t: String = body.type.to_upper()
		if t in ["PLANET", "GAS_GIANT", "ASTEROID_FIELD"]:
			var c: Vector3i = body.coords
			var dist := (Vector2(c.x, c.y) - Vector2(star_coords.x, star_coords.y)).length()
			var r_screen := dist * CELL_SIZE * zoom_level
			if r_screen > 2.0:
				draw_arc(star_center, r_screen, 0.0, TAU, 64, orbit_color, 1.0)

func _draw_shadow_cones() -> void:
	var star_coords :Vector3i = system_data.primary_star_coords
	var star_pos := Vector2(star_coords.x, star_coords.y)
	var cone_color := Color(0.0, 0.0, 0.0, 0.45)
	
	for body in system_data.celestial_bodies:
		if not (body is CelestialBodyData) or not body.occluding:
			continue
		var c: Vector3i = body.coords
		var b_pos := Vector2(c.x, c.y)
		var dir := (b_pos - star_pos)
		if dir.length_squared() < 0.001:
			continue
		var dir_norm := dir.normalized()
		var perp := Vector2(-dir_norm.y, dir_norm.x)
		
		var body_screen := world_to_screen(b_pos)
		var r_body := _get_body_render_radius(body)
		
		var p_left := body_screen + perp * r_body
		var p_right := body_screen - perp * r_body
		var cone_len := 300.0 * zoom_level
		var p_far_left := p_left + dir_norm * cone_len + perp * (r_body * 2.0)
		var p_far_right := p_right + dir_norm * cone_len - perp * (r_body * 2.0)
		
		var poly := PackedVector2Array([p_left, p_far_left, p_far_right, p_right])
		draw_colored_polygon(poly, cone_color)

func _draw_celestial_bodies() -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	
	for body in system_data.celestial_bodies:
		if not (body is CelestialBodyData):
			continue
		var b_id: String = body.id
		var b_name: String = body.name
		var b_type: String = body.type.to_upper()
		var c: Vector3i = body.coords
		var center := world_to_screen(Vector2(c.x, c.y))
		var radius := _get_body_render_radius(body)
		var col: Color = TYPE_COLORS.get(b_type, Color.WHITE)
		if body.color != Color.WHITE and body.color != Color(0, 0, 0, 0):
			col = body.color
			
		var is_selected := (b_id == selected_body_id)
		
		# Glow per la stella
		if b_type == "STAR":
			draw_circle(center, radius * 1.8, Color(col.r, col.g, col.b, 0.25))
			draw_circle(center, radius * 1.3, Color(col.r, col.g, col.b, 0.45))
			
		# Corpo principale
		draw_circle(center, radius, col)
		
		# Anelli per giganti gassosi o campi asteroidi
		if b_type == "GAS_GIANT":
			draw_arc(center, radius * 1.6, -0.8, 2.3, 32, Color(col.r, col.g, col.b, 0.5), 2.0)
		elif b_type == "ASTEROID_FIELD":
			draw_arc(center, radius * 1.3, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.6), 1.5)
			
		# Selezione evidenziata
		if is_selected:
			draw_arc(center, radius + 5.0, 0.0, TAU, 32, Color(1.0, 1.0, 0.0, 0.9), 2.0)
			
		# Label diegetica nome corpo
		if show_labels and font != null:
			var label_text := "%s" % b_name
			var f_size := int(clampi(int(11 * clampf(zoom_level, 0.7, 1.4)), 9, 14))
			var text_pos := center + Vector2(radius + 6.0, 4.0)
			draw_string(font, text_pos + Vector2(1, 1), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size, Color(0, 0, 0, 0.8))
			draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size, Color(0.9, 0.95, 1.0, 0.9))
