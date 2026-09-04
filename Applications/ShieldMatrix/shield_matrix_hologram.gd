class_name ShieldMatrixHologram
extends Control

## Visualizzatore Olografico Diegetico della Corvetta, Matrice Scudi a 4 Quadranti
## e Dispositivi di Difesa Attiva (Gatling di Prossimità e Lanciatori Flack Angel-Hair).

signal sector_clicked(sector: int)

enum DefenseSector {
	FORE = 0,
	PORT = 1,
	STARBOARD = 2,
	AFT = 3
}

var fore_ratio: float = 0.25
var aft_ratio: float = 0.25
var port_ratio: float = 0.25
var starboard_ratio: float = 0.25

var fore_health_pct: float = 1.0
var aft_health_pct: float = 1.0
var port_health_pct: float = 1.0
var starboard_health_pct: float = 1.0

var is_phase_synced: bool = true
var is_operational: bool = false
var pulse_time: float = 0.0

var defense_devices: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS

func _gui_input(event: InputEvent) -> void:
	if not is_operational:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var center := size * 0.5
			var rel := mb.position - center
			var dist := rel.length()
			var min_dim := minf(size.x, size.y)
			if dist >= min_dim * 0.15 and dist <= min_dim * 0.55:
				var deg := rad_to_deg(atan2(rel.y, rel.x))
				var s := _get_sector_from_screen_angle(deg)
				sector_clicked.emit(s)
				accept_event()

func _get_sector_from_screen_angle(deg: float) -> int:
	if deg >= -135.0 and deg < -45.0:
		return DefenseSector.FORE
	elif deg >= 45.0 and deg < 135.0:
		return DefenseSector.AFT
	elif deg >= 135.0 or deg < -135.0:
		return DefenseSector.PORT
	else:
		return DefenseSector.STARBOARD

func _process(delta: float) -> void:
	if is_operational:
		pulse_time += delta
		queue_redraw()

func update_matrix_state(
	f_ratio: float, a_ratio: float, p_ratio: float, s_ratio: float,
	f_hp: float, a_hp: float, p_hp: float, s_hp: float,
	synced: bool, operational: bool
) -> void:
	fore_ratio = f_ratio
	aft_ratio = a_ratio
	port_ratio = p_ratio
	starboard_ratio = s_ratio
	fore_health_pct = clampf(f_hp, 0.0, 1.0)
	aft_health_pct = clampf(a_hp, 0.0, 1.0)
	port_health_pct = clampf(p_hp, 0.0, 1.0)
	starboard_health_pct = clampf(s_hp, 0.0, 1.0)
	is_phase_synced = synced
	is_operational = operational
	queue_redraw()

func set_defense_devices(devices: Array[Dictionary]) -> void:
	defense_devices = devices
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var min_dim := minf(size.x, size.y)
	var base_radius := min_dim * 0.38
	
	# Sfondo circolare radar olografico
	draw_circle(center, base_radius * 1.15, Color(0.02, 0.06, 0.1, 0.6))
	draw_arc(center, base_radius * 1.15, 0, TAU, 48, Color(0.15, 0.35, 0.5, 0.3), 1.0)
	draw_arc(center, base_radius * 0.85, 0, TAU, 36, Color(0.15, 0.35, 0.5, 0.2), 1.0)
	draw_arc(center, base_radius * 0.5, 0, TAU, 24, Color(0.15, 0.35, 0.5, 0.15), 1.0)
	
	# Assi ortogonali a croce
	draw_line(Vector2(center.x, center.y - base_radius * 1.1), Vector2(center.x, center.y + base_radius * 1.1), Color(0.2, 0.4, 0.6, 0.25), 1.0)
	draw_line(Vector2(center.x - base_radius * 1.1, center.y), Vector2(center.x + base_radius * 1.1, center.y), Color(0.2, 0.4, 0.6, 0.25), 1.0)

	# Sagoma Olografica Astronavetta centrale
	_draw_ship_wireframe(center, min_dim * 0.26)

	if not is_operational:
		return

	# Pulse per armoniche di fase
	var pulse_glow := sin(pulse_time * 4.0) * 0.15 + 0.85 if is_phase_synced else 0.7
	
	# 4 Archi Scudo: Fore (Prua - top), Aft (Poppa - bottom), Port (Babordo - left), Starboard (Tribordo - right)
	var arc_radius := base_radius * 0.95
	
	# FORE ARC (-3*PI/4 .. -PI/4)
	_draw_shield_quadrant_arc(center, arc_radius, -3.0 * PI / 4.0 + 0.1, -PI / 4.0 - 0.1, fore_ratio, fore_health_pct, pulse_glow, "PRUA")
	
	# AFT ARC (PI/4 .. 3*PI/4)
	_draw_shield_quadrant_arc(center, arc_radius, PI / 4.0 + 0.1, 3.0 * PI / 4.0 - 0.1, aft_ratio, aft_health_pct, pulse_glow, "POPPA")
	
	# PORT ARC (3*PI/4 .. 5*PI/4)
	_draw_shield_quadrant_arc(center, arc_radius, 3.0 * PI / 4.0 + 0.1, 5.0 * PI / 4.0 - 0.1, port_ratio, port_health_pct, pulse_glow, "BABORDO")
	
	# STARBOARD ARC (-PI/4 .. PI/4)
	_draw_shield_quadrant_arc(center, arc_radius, -PI / 4.0 + 0.1, PI / 4.0 - 0.1, starboard_ratio, starboard_health_pct, pulse_glow, "TRIBORDO")

	# Rendering marcatori / simboli dispositivi di difesa assegnati ai settori
	_draw_sector_defense_devices(center, arc_radius)

func _draw_ship_wireframe(center: Vector2, scale_len: float) -> void:
	var nose := center + Vector2(0, -scale_len * 0.9)
	var wing_left := center + Vector2(-scale_len * 0.55, scale_len * 0.4)
	var wing_right := center + Vector2(scale_len * 0.55, scale_len * 0.4)
	var aft_left := center + Vector2(-scale_len * 0.25, scale_len * 0.75)
	var aft_right := center + Vector2(scale_len * 0.25, scale_len * 0.75)
	var cockpit := center + Vector2(0, -scale_len * 0.3)
	
	var ship_color := Color(0.3, 0.75, 1.0, 0.85) if is_operational else Color(0.5, 0.5, 0.5, 0.4)
	var fill_color := Color(0.1, 0.3, 0.5, 0.15) if is_operational else Color(0.2, 0.2, 0.2, 0.1)
	
	var hull_pts := PackedVector2Array([nose, wing_right, aft_right, aft_left, wing_left])
	draw_colored_polygon(hull_pts, fill_color)
	
	# Linee di contorno
	draw_line(nose, wing_right, ship_color, 2.0)
	draw_line(wing_right, aft_right, ship_color, 2.0)
	draw_line(aft_right, aft_left, ship_color, 2.0)
	draw_line(aft_left, wing_left, ship_color, 2.0)
	draw_line(wing_left, nose, ship_color, 2.0)
	
	# Dettaglio abitacolo / spina
	draw_line(nose, cockpit, ship_color * 0.8, 1.5)
	draw_line(cockpit, center + Vector2(0, scale_len * 0.2), ship_color * 0.6, 1.0)

func _draw_shield_quadrant_arc(
	center: Vector2, radius: float, start_angle: float, end_angle: float,
	ratio: float, health_pct: float, pulse_glow: float, _label: String
) -> void:
	# Spessore arc proporzionale al bilanciamento energetico (ratio 0.1 .. 0.8 -> 2px .. 10px)
	var line_width := clampf(ratio * 20.0, 2.0, 12.0)
	
	# Colore in base alla salute del quadrante
	var base_col: Color
	if health_pct > 0.65:
		base_col = Color(0.2, 0.8, 1.0) # Ciano ottimale
	elif health_pct > 0.3:
		base_col = Color(1.0, 0.75, 0.2) # Giallo-arancio degradato
	elif health_pct > 0.05:
		base_col = Color(1.0, 0.25, 0.25) # Rosso critico
	else:
		base_col = Color(0.4, 0.1, 0.1, 0.3) # Collassato
	
	var arc_color := base_col
	arc_color.a = clampf((health_pct * 0.75 + 0.25) * pulse_glow, 0.15, 1.0)
	
	# Disegna arco esterno
	draw_arc(center, radius, start_angle, end_angle, 24, arc_color, line_width)
	
	# Secondo arco interno di rifrazione se c'è energia sufficiente
	if health_pct > 0.2:
		var inner_color := arc_color
		inner_color.a *= 0.4
		draw_arc(center, radius - 6.0, start_angle + 0.05, end_angle - 0.05, 18, inner_color, line_width * 0.5)

func _draw_sector_defense_devices(center: Vector2, arc_radius: float) -> void:
	if defense_devices.is_empty():
		return
	
	var sector_angles := {
		DefenseSector.FORE: -PI * 0.5,
		DefenseSector.PORT: PI,
		DefenseSector.STARBOARD: 0.0,
		DefenseSector.AFT: PI * 0.5
	}
	
	# Raggruppa i dispositivi per settore
	var sector_groups := {
		DefenseSector.FORE: [],
		DefenseSector.PORT: [],
		DefenseSector.STARBOARD: [],
		DefenseSector.AFT: []
	}
	
	for dev in defense_devices:
		var sec: int = int(dev.get("sector", 0))
		if sector_groups.has(sec):
			sector_groups[sec].append(dev)
	
	var marker_radius := arc_radius + 18.0
	
	for sec in sector_groups.keys():
		var devs: Array = sector_groups[sec]
		var count: int = devs.size()
		if count == 0:
			continue
		
		var base_ang: float = sector_angles[sec]
		var ang_spread: float = 0.24 # Spread angolare tra dispositivi multipli
		var start_offset: float = -((count - 1) * ang_spread) * 0.5
		
		for i in range(count):
			var dev: Dictionary = devs[i]
			var dev_ang: float = base_ang + start_offset + i * ang_spread
			var dev_pos := center + Vector2(cos(dev_ang), sin(dev_ang)) * marker_radius
			_draw_device_marker(dev_pos, dev_ang, dev)

func _draw_device_marker(pos: Vector2, angle: float, dev: Dictionary) -> void:
	var dev_type: String = str(dev.get("type", "GATLING")).to_upper()
	var ammo: int = int(dev.get("ammo", 0))
	var cooldown: float = float(dev.get("cooldown", 0.0))
	
	var dev_color: Color
	if ammo <= 0:
		dev_color = Color(0.8, 0.2, 0.2, 0.6) # Esaurito (rosso)
	elif cooldown > 0.0:
		dev_color = Color(1.0, 0.7, 0.2, 0.85) # In cooldown (giallo/arancio)
	else:
		dev_color = Color(0.25, 0.95, 0.55, 0.95) if dev_type == "GATLING" else Color(0.4, 0.85, 1.0, 0.95)
	
	var dir_vec := Vector2(cos(angle), sin(angle))
	var normal_vec := Vector2(-dir_vec.y, dir_vec.x)
	
	if dev_type == "GATLING":
		# Torretta Gatling: cerchietto base + doppia canna verso l'esterno
		draw_circle(pos, 4.0, dev_color * Color(1, 1, 1, 0.35))
		draw_arc(pos, 4.5, 0, TAU, 12, dev_color, 1.2)
		var barrel1_start := pos + normal_vec * 2.0
		var barrel1_end := barrel1_start + dir_vec * 7.0
		var barrel2_start := pos - normal_vec * 2.0
		var barrel2_end := barrel2_start + dir_vec * 7.0
		draw_line(barrel1_start, barrel1_end, dev_color, 1.5)
		draw_line(barrel2_start, barrel2_end, dev_color, 1.5)
	elif dev_type == "FLACK":
		# Lanciatore Flack: rombo/diamante centrale con particelle radiali ("Angel Hair")
		var p_top := pos + dir_vec * 5.5
		var p_right := pos + normal_vec * 4.5
		var p_bottom := pos - dir_vec * 3.5
		var p_left := pos - normal_vec * 4.5
		var diamond_pts := PackedVector2Array([p_top, p_right, p_bottom, p_left])
		draw_colored_polygon(diamond_pts, dev_color * Color(1, 1, 1, 0.4))
		draw_line(p_top, p_right, dev_color, 1.2)
		draw_line(p_right, p_bottom, dev_color, 1.2)
		draw_line(p_bottom, p_left, dev_color, 1.2)
		draw_line(p_left, p_top, dev_color, 1.2)
		# Raggi dispersione
		draw_line(pos + normal_vec * 6.0, pos + normal_vec * 8.0 + dir_vec * 2.0, dev_color * 0.7, 1.0)
		draw_line(pos - normal_vec * 6.0, pos - normal_vec * 8.0 + dir_vec * 2.0, dev_color * 0.7, 1.0)
	else:
		# Generico
		draw_circle(pos, 4.0, dev_color)
