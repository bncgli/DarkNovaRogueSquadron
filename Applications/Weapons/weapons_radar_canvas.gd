@tool
class_name WeaponsRadarCanvas
extends Control

## Canvas 2D per la visualizzazione del Radar Tattico, Target Lock e Lead Indicator

var targets: Array[Dictionary] = []
var locked_target_id: String = ""
var lead_offset: Vector2 = Vector2.ZERO
var aim_angles: Vector2 = Vector2.ZERO # Vector2(yaw_deg, pitch_deg)
var max_radar_dist: float = 120.0
var has_lock: bool = false
var sweep_angle: float = 0.0

func _process(delta: float) -> void:
	sweep_angle = fmod(sweep_angle + delta * 2.0, TAU)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(center.x, center.y) - 10.0
	if radius <= 10.0:
		return
	
	# Sfondo Radar circolare
	draw_circle(center, radius, Color(0.03, 0.06, 0.1, 0.75))
	
	# Anelli di distanza concentrici (Portata)
	var rings := 3
	for i in range(1, rings + 1):
		var r := radius * (float(i) / float(rings))
		draw_arc(center, r, 0, TAU, 48, Color(0.15, 0.35, 0.45, 0.4), 1.0, true)
	
	# Assi ortogonali e diagonali
	draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(0.15, 0.4, 0.5, 0.35), 1.0)
	draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color(0.15, 0.4, 0.5, 0.35), 1.0)
	
	# Linea di sweep radar rotante
	var sweep_end := center + Vector2(cos(sweep_angle), sin(sweep_angle)) * radius
	draw_line(center, sweep_end, Color(0.2, 0.8, 1.0, 0.25), 1.5)
	
	# Nave al centro (Triangolino cyan)
	var ship_pts := PackedVector2Array([
		center + Vector2(0, -7),
		center + Vector2(5, 6),
		center + Vector2(-5, 6)
	])
	draw_colored_polygon(ship_pts, Color(0.3, 0.9, 1.0, 0.9))
	
	# Disegna i contatti bersaglio
	for t in targets:
		var dist: float = float(t.get("distance", 50.0))
		var bearing: float = deg_to_rad(float(t.get("bearing_deg", 0.0)) - 90.0)
		var norm_dist := clampf(dist / max_radar_dist, 0.1, 1.0)
		var t_pos := center + Vector2(cos(bearing), sin(bearing)) * (norm_dist * radius)
		
		var t_id: String = t.get("id", "")
		var is_locked: bool = (t_id == locked_target_id and has_lock)
		var threat: String = t.get("threat_level", "NEUTRAL")
		
		var col: Color = Color(0.3, 0.8, 0.4) # Verde default
		if threat == "HAZARD":
			col = Color(1.0, 0.6, 0.2) # Arancio
		elif threat == "HOSTILE":
			col = Color(1.0, 0.2, 0.2) # Rosso
		
		if is_locked:
			# Box di Lock (Quadrato giallo/rosso attorno al bersaglio)
			var box_size := 12.0
			var rect := Rect2(t_pos - Vector2(box_size, box_size) * 0.5, Vector2(box_size, box_size))
			draw_rect(rect, Color(1.0, 0.85, 0.1, 0.9), false, 1.5)
			draw_circle(t_pos, 3.0, Color(1.0, 0.85, 0.1, 1.0))
			
			# Disegna Lead Indicator (Calcolo anticipo di tiro)
			var lead_screen_pos := t_pos + lead_offset
			draw_circle(lead_screen_pos, 4.0, Color(1.0, 0.2, 0.2, 0.9))
			draw_arc(lead_screen_pos, 7.0, 0, TAU, 24, Color(1.0, 0.3, 0.3, 0.8), 1.2, true)
			draw_dashed_line(t_pos, lead_screen_pos, Color(1.0, 0.5, 0.2, 0.7), 1.0, 3.0)
		else:
			# Blip standard
			draw_circle(t_pos, 3.5, col)
	
	# Reticolo di Puntamento Manuale / Torretta (Croce ciano)
	var aim_norm := Vector2(aim_angles.x / 45.0, aim_angles.y / 30.0)
	var aim_pos := center + aim_norm * (radius * 0.6)
	draw_line(aim_pos - Vector2(8, 0), aim_pos + Vector2(8, 0), Color(0.2, 0.95, 1.0, 0.85), 1.2)
	draw_line(aim_pos - Vector2(0, 8), aim_pos + Vector2(0, 8), Color(0.2, 0.95, 1.0, 0.85), 1.2)
	draw_arc(aim_pos, 10.0, 0, TAU, 24, Color(0.2, 0.95, 1.0, 0.65), 1.0, true)
	
	# Bordo esterno
	draw_arc(center, radius, 0, TAU, 64, Color(0.25, 0.55, 0.8, 0.8), 1.5, true)
