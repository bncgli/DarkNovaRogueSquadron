@tool
class_name WeaponsTrajectoryHUD
extends Control

## HUD Diegetico per la visualizzazione di mira ottica, traiettoria balistica,
## lead indicator di puntamento predittivo, stato lock missili e cattura mouse.

var crosshair_pos: Vector2 = Vector2.ZERO
var lead_pos: Vector2 = Vector2.ZERO
var target_screen_pos: Vector2 = Vector2.ZERO
var has_lead: bool = false
var has_target_screen: bool = false
var is_mouse_captured: bool = false
var is_missile_locked: bool = false
var missile_lock_progress: float = 0.0 # 0.0..1.0
var active_ammo_type: int = 1
var active_ammo_name: String = "MITRAGLIATRICE PESANTE"
var target_name: String = ""
var target_dist: float = 0.0
var aim_yaw: float = 0.0
var aim_pitch: float = 0.0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var viewport_size := size
	if viewport_size.x <= 10.0 or viewport_size.y <= 10.0:
		return
	
	var center := viewport_size * 0.5
	var reticle_center := crosshair_pos if crosshair_pos.length_squared() > 1.0 else center
	
	# 1. Griglia / Frame tattico ai bordi del viewport
	_draw_tactical_frame(viewport_size)
	
	# 2. Indicatore Stato Mouse Capture & Modalità Torretta
	_draw_mouse_capture_status(viewport_size)
	
	# 3. Reticolo di Mira Centrale Diegetico
	_draw_optical_reticle(reticle_center)
	
	# 4. Target Box sul Bersaglio se presente a schermo
	if has_target_screen and target_screen_pos != Vector2.ZERO:
		_draw_target_box(target_screen_pos, target_name, target_dist)
	
	# 5. Lead Indicator (Marker di Anticipo Balistico)
	if has_lead and lead_pos != Vector2.ZERO:
		_draw_lead_indicator(reticle_center, lead_pos)
	
	# 6. Lock Missilistico (Anello di acquisizione o Lock Box)
	if active_ammo_type == 3: # MISSILE
		_draw_missile_lock_hud(reticle_center, lead_pos if has_lead else (target_screen_pos if has_target_screen else reticle_center))
	
	# 7. Barra Munizioni / Selettore 1-4 in basso
	_draw_ammo_bar(viewport_size)

func _draw_tactical_frame(v_size: Vector2) -> void:
	var border_col := Color(0.15, 0.45, 0.65, 0.3)
	var corner_len := 16.0
	# Angoli HUD
	draw_line(Vector2(6, 6), Vector2(6 + corner_len, 6), border_col, 1.5)
	draw_line(Vector2(6, 6), Vector2(6, 6 + corner_len), border_col, 1.5)
	
	draw_line(Vector2(v_size.x - 6, 6), Vector2(v_size.x - 6 - corner_len, 6), border_col, 1.5)
	draw_line(Vector2(v_size.x - 6, 6), Vector2(v_size.x - 6, 6 + corner_len), border_col, 1.5)
	
	draw_line(Vector2(6, v_size.y - 6), Vector2(6 + corner_len, v_size.y - 6), border_col, 1.5)
	draw_line(Vector2(6, v_size.y - 6), Vector2(6, v_size.y - 6 - corner_len), border_col, 1.5)
	
	draw_line(Vector2(v_size.x - 6, v_size.y - 6), Vector2(v_size.x - 6 - corner_len, v_size.y - 6), border_col, 1.5)
	draw_line(Vector2(v_size.x - 6, v_size.y - 6), Vector2(v_size.x - 6, v_size.y - 6 - corner_len), border_col, 1.5)

func _draw_mouse_capture_status(v_size: Vector2) -> void:
	var cap_text: String
	var cap_color: Color
	if is_mouse_captured:
		cap_text = "[MOUSE LOCK ATTIVO] (SPAZIO: Sblocca | ESC: Rilascia)"
		cap_color = Color(0.3, 1.0, 0.5, 0.85)
	else:
		cap_text = "[PUNTAMENTO LIBERO] Premere SPAZIO per cattura mouse torretta"
		cap_color = Color(0.8, 0.8, 0.8, 0.65)
	
	draw_string(ThemeDB.fallback_font, Vector2(10, 16), cap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, cap_color)
	
	var ang_text := "YAW: %+.1f°  PITCH: %+.1f°" % [aim_yaw, aim_pitch]
	draw_string(ThemeDB.fallback_font, Vector2(v_size.x - 140, 16), ang_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, Color(0.4, 0.85, 1.0, 0.85))

func _draw_optical_reticle(c: Vector2) -> void:
	var cross_col := Color(0.2, 0.95, 1.0, 0.8)
	var cross_len := 12.0
	var gap := 4.0
	
	# Crocicchio centrale aperti al centro
	draw_line(c - Vector2(gap + cross_len, 0), c - Vector2(gap, 0), cross_col, 1.2)
	draw_line(c + Vector2(gap, 0), c + Vector2(gap + cross_len, 0), cross_col, 1.2)
	draw_line(c - Vector2(0, gap + cross_len), c - Vector2(0, gap), cross_col, 1.2)
	draw_line(c + Vector2(0, gap), c + Vector2(0, gap + cross_len), cross_col, 1.2)
	
	# Punto centrale
	draw_circle(c, 1.5, Color(0.2, 0.95, 1.0, 0.9))
	
	# Cerchio di collimazione
	draw_arc(c, 18.0, 0, TAU, 32, Color(0.2, 0.95, 1.0, 0.35), 1.0, true)

func _draw_target_box(t_pos: Vector2, t_name: String, t_dist: float) -> void:
	var box_sz := 24.0
	var col := Color(1.0, 0.8, 0.2, 0.9)
	var rect := Rect2(t_pos - Vector2(box_sz, box_sz) * 0.5, Vector2(box_sz, box_sz))
	
	# Disegna parentesi target quadrate agli angoli
	var c_len := 6.0
	# Top-Left
	draw_line(rect.position, rect.position + Vector2(c_len, 0), col, 1.5)
	draw_line(rect.position, rect.position + Vector2(0, c_len), col, 1.5)
	# Top-Right
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - c_len, rect.position.y), col, 1.5)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + c_len), col, 1.5)
	# Bottom-Left
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + c_len, rect.end.y), col, 1.5)
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.end.y - c_len), col, 1.5)
	# Bottom-Right
	draw_line(rect.end, rect.end - Vector2(c_len, 0), col, 1.5)
	draw_line(rect.end, rect.end - Vector2(0, c_len), col, 1.5)
	
	# Didascalia bersaglio
	var label := "%s (%.0fm)" % [t_name, t_dist]
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, -4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col)

func _draw_lead_indicator(reticle: Vector2, l_pos: Vector2) -> void:
	var lead_col := Color(1.0, 0.3, 0.3, 0.95)
	
	# Linea tratteggiata di mira verso il lead point
	draw_dashed_line(reticle, l_pos, Color(1.0, 0.5, 0.3, 0.6), 1.0, 4.0)
	
	# Cerchio predittivo diegetico
	draw_circle(l_pos, 3.0, Color(1.0, 0.2, 0.2, 1.0))
	draw_arc(l_pos, 8.0, 0, TAU, 24, lead_col, 1.5, true)
	draw_arc(l_pos, 12.0, 0, TAU, 24, Color(1.0, 0.4, 0.4, 0.4), 1.0, true)
	
	# Tacche direzionali croce sul lead marker
	draw_line(l_pos - Vector2(5, 0), l_pos + Vector2(5, 0), lead_col, 1.0)
	draw_line(l_pos - Vector2(0, 5), l_pos + Vector2(0, 5), lead_col, 1.0)
	
	# Etichetta "LEAD"
	draw_string(ThemeDB.fallback_font, l_pos + Vector2(10, 4), "LEAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, lead_col)

func _draw_missile_lock_hud(reticle: Vector2, lock_pos: Vector2) -> void:
	if is_missile_locked:
		var locked_col := Color(1.0, 0.2, 0.2, 0.95)
		# Box di Lock confermato
		var l_sz := 32.0
		var rect := Rect2(lock_pos - Vector2(l_sz, l_sz) * 0.5, Vector2(l_sz, l_sz))
		draw_rect(rect, locked_col, false, 1.8)
		draw_arc(lock_pos, 18.0, 0, TAU, 32, locked_col, 1.5, true)
		draw_string(ThemeDB.fallback_font, lock_pos + Vector2(-42, 26), "🔒 LOCK CONFERMATO", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, locked_col)
	elif missile_lock_progress > 0.0:
		var prog_col := Color(1.0, 0.8, 0.2, 0.9)
		var angle_sweep := missile_lock_progress * TAU
		draw_arc(lock_pos, 22.0, -PI * 0.5, -PI * 0.5 + angle_sweep, 32, prog_col, 2.0, true)
		var pct_str := "LOCKING %.0f%%" % (missile_lock_progress * 100.0)
		draw_string(ThemeDB.fallback_font, lock_pos + Vector2(-35, 24), pct_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, prog_col)

func _draw_ammo_bar(v_size: Vector2) -> void:
	var bar_y := v_size.y - 8.0
	var ammo_slots: Array[Dictionary] = [
		{"key": "1", "name": "MITR. PESANTE", "type": 1},
		{"key": "2", "name": "CANNONE", "type": 2},
		{"key": "3", "name": "MISSILE", "type": 3},
		{"key": "4", "name": "SONDA", "type": 4}
	]
	
	var start_x := 10.0
	var slot_w := (v_size.x - 20.0) / 4.0
	
	for i in range(ammo_slots.size()):
		var slot: Dictionary = ammo_slots[i]
		var is_active: bool = (int(slot.get("type", 0)) == active_ammo_type)
		var col: Color = Color(0.3, 1.0, 0.5, 0.95) if is_active else Color(0.5, 0.6, 0.7, 0.6)
		var text: String = "[%s] %s" % [str(slot.get("key", "")), str(slot.get("name", ""))]
		if is_active:
			text = "► " + text
		draw_string(ThemeDB.fallback_font, Vector2(start_x + i * slot_w, bar_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col)
