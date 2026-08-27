class_name CommsWaterfallCanvas
extends Control

## Visualizzatore a Cascata di Spettro (Waterfall Display) e Sintonizzatore Frequenze Radio RF / Subspazio.
## Disegna in tempo reale lo spettro elettromagnetico procedurale, le portanti radio e le interferenze EW.

var current_frequency: float = 1420.0
var min_freq: float = 100.0
var max_freq: float = 3000.0

var is_jamming_active: bool = false
var jamming_power: float = 120.0
var is_operational: bool = false
var anim_time: float = 0.0

# Storico righe waterfall per effetto a cascata
var waterfall_history: Array[PackedFloat32Array] = []
const MAX_WATERFALL_ROWS: int = 40
const SPECTRUM_BINS: int = 64

# Segnali attivi con frequenza centrale (MHz) e ampiezza
var active_signals: Array[Dictionary] = []

func _ready() -> void:
	_init_waterfall_buffer()

func _init_waterfall_buffer() -> void:
	waterfall_history.clear()
	for i in range(MAX_WATERFALL_ROWS):
		var row := PackedFloat32Array()
		row.resize(SPECTRUM_BINS)
		for j in range(SPECTRUM_BINS):
			row[j] = randf_range(0.02, 0.12)
		waterfall_history.append(row)

func _process(delta: float) -> void:
	if is_operational:
		anim_time += delta
		_update_waterfall_row(delta)
		queue_redraw()

func _update_waterfall_row(_delta: float) -> void:
	if waterfall_history.is_empty():
		return
	
	var new_row := PackedFloat32Array()
	new_row.resize(SPECTRUM_BINS)
	
	# Rumore di fondo
	for j in range(SPECTRUM_BINS):
		var bin_freq := min_freq + (float(j) / float(SPECTRUM_BINS - 1)) * (max_freq - min_freq)
		var noise := randf_range(0.04, 0.15)
		
		# Aggiungi segnali attivi se vicini al bin
		for sig in active_signals:
			var sig_freq: float = sig.get("freq", 1420.0)
			var sig_strength: float = sig.get("strength", 0.8)
			var dist := absf(bin_freq - sig_freq)
			if dist < 80.0:
				var factor := 1.0 - (dist / 80.0)
				noise += factor * sig_strength * (0.7 + 0.3 * sin(anim_time * 8.0 + j))
		
		# Effetto disturbo Jammer su tutto lo spettro o bande vicine
		if is_jamming_active:
			var jam_factor := clampf(jamming_power / 180.0, 0.3, 1.0)
			noise += randf_range(0.2, 0.6) * jam_factor
		
		new_row[j] = clampf(noise, 0.0, 1.0)
	
	waterfall_history.pop_back()
	waterfall_history.push_front(new_row)

func update_state(freq: float, jamming: bool, jam_pwr: float, operational: bool, signals: Array[Dictionary]) -> void:
	current_frequency = freq
	is_jamming_active = jamming
	jamming_power = jam_pwr
	is_operational = operational
	active_signals = signals
	queue_redraw()

func set_operational(op: bool) -> void:
	is_operational = op
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 10.0 or h <= 10.0:
		return
	
	# Sfondo scuro visualizzatore
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.08, 0.95))
	
	# Se offline, mostra griglia vuota spenta
	if not is_operational:
		_draw_offline_grid()
		return
	
	# 1. Disegna Waterfall History (Cascata dall'alto verso il basso)
	var row_height := (h - 24.0) / float(MAX_WATERFALL_ROWS)
	var bin_width := w / float(SPECTRUM_BINS)
	
	for r in range(waterfall_history.size()):
		var row: PackedFloat32Array = waterfall_history[r]
		var y_pos := 20.0 + float(r) * row_height
		var fade_factor := 1.0 - (float(r) / float(MAX_WATERFALL_ROWS)) * 0.75
		
		for b in range(row.size()):
			var val: float = row[b]
			var x_pos := float(b) * bin_width
			var color := _get_waterfall_color(val, fade_factor)
			draw_rect(Rect2(Vector2(x_pos, y_pos), Vector2(bin_width + 0.5, row_height + 0.5)), color)
	
	# 2. Scala di frequenza superiore
	_draw_frequency_scale()
	
	# 3. Linea e cursore della frequenza attualmente sintonizzata
	_draw_tuner_cursor()
	
	# 4. Bordi e cornice high-tech
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.15, 0.45, 0.7, 0.6), false, 1.0)

func _draw_offline_grid() -> void:
	var w := size.x
	var h := size.y
	var grid_col := Color(0.1, 0.15, 0.22, 0.4)
	
	# Linee orizzontali
	for y_step in range(4):
		var y := 20.0 + (float(y_step) / 4.0) * (h - 20.0)
		draw_line(Vector2(0, y), Vector2(w, y), grid_col, 1.0)
	
	# Linee verticali
	for x_step in range(8):
		var x := (float(x_step) / 8.0) * w
		draw_line(Vector2(x, 0), Vector2(x, h), grid_col, 1.0)
	
	_draw_frequency_scale()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.25, 0.3, 0.4), false, 1.0)

func _draw_frequency_scale() -> void:
	var w := size.x
	# Barra superiore per la scala in MHz
	draw_rect(Rect2(0, 0, w, 20), Color(0.04, 0.08, 0.15, 0.9))
	draw_line(Vector2(0, 20), Vector2(w, 20), Color(0.2, 0.5, 0.8, 0.5), 1.0)
	
	var default_font := ThemeDB.fallback_font
	var font_sz := 9
	var steps := 6
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var freq_val := min_freq + t * (max_freq - min_freq)
		var x := t * (w - 2.0)
		draw_line(Vector2(x, 14), Vector2(x, 20), Color(0.4, 0.8, 1.0, 0.7), 1.0)
		var txt := "%dM" % int(freq_val)
		var text_x := clampf(x - 12.0, 2.0, w - 30.0)
		if default_font:
			draw_string(default_font, Vector2(text_x, 12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, Color(0.4, 0.75, 0.95, 0.7))

func _draw_tuner_cursor() -> void:
	var w := size.x
	var h := size.y
	var norm_freq := clampf((current_frequency - min_freq) / (max_freq - min_freq), 0.0, 1.0)
	var tuner_x := norm_freq * w
	
	# Verifica se il cursore è agganciato a un segnale
	var is_locked := false
	for sig in active_signals:
		var sig_freq: float = sig.get("freq", 1420.0)
		if absf(current_frequency - sig_freq) <= 15.0:
			is_locked = true
			break
	
	var cursor_color := Color(0.2, 1.0, 0.4, 0.85) if is_locked else Color(0.3, 0.8, 1.0, 0.75)
	
	# Linea verticale del tuner
	draw_line(Vector2(tuner_x, 0), Vector2(tuner_x, h), cursor_color, 1.5)
	
	# Triangolino indicatore in cima
	var tri := PackedVector2Array([
		Vector2(tuner_x - 5, 0),
		Vector2(tuner_x + 5, 0),
		Vector2(tuner_x, 8)
	])
	draw_colored_polygon(tri, cursor_color)
	
	# Testo frequenza attiva sul cursore
	var default_font := ThemeDB.fallback_font
	if default_font:
		var freq_str := "%.1f MHz" % current_frequency
		var tx := clampf(tuner_x - 25.0, 4.0, w - 60.0)
		draw_string(default_font, Vector2(tx, h - 6), freq_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, cursor_color)

func _get_waterfall_color(value: float, fade: float) -> Color:
	# Mappa di colore termica radio: Blu scuro -> Ciano -> Verde -> Giallo -> Rosso
	var c: Color
	if value < 0.2:
		c = Color(0.02, 0.05, 0.2 + value * 1.5)
	elif value < 0.45:
		var t := (value - 0.2) / 0.25
		c = Color(0.05, 0.2 + t * 0.6, 0.6 + t * 0.4)
	elif value < 0.75:
		var t := (value - 0.45) / 0.3
		c = Color(0.1 + t * 0.8, 0.8 + t * 0.2, 0.2 - t * 0.1)
	else:
		var t := (value - 0.75) / 0.25
		c = Color(0.9 + t * 0.1, 0.9 - t * 0.5, 0.1 - t * 0.1)
	
	c.a = clampf(fade * (0.4 + value * 0.6), 0.1, 1.0)
	return c
