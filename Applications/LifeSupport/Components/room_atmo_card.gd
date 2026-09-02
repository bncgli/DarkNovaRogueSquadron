class_name RoomAtmoCard
extends PanelContainer

## Widget per il monitoraggio e controllo dell'atmosfera di un singolo compartimento nave.

signal selected(room_id: String)
signal seal_toggled(room_id: String, is_sealed: bool)
signal fire_suppressed(room_id: String)

@onready var btn_select: Button = get_node_or_null("%BtnSelect")
@onready var room_name_label: Label = get_node_or_null("%RoomNameLabel")
@onready var status_badge: Label = get_node_or_null("%StatusBadge")
@onready var o2_label: Label = get_node_or_null("%O2Label")
@onready var o2_progress: ProgressBar = get_node_or_null("%O2Progress")
@onready var pressure_label: Label = get_node_or_null("%PressureLabel")
@onready var temp_label: Label = get_node_or_null("%TempLabel")
@onready var co2_label: Label = get_node_or_null("%CO2Label")
@onready var btn_quick_seal: Button = get_node_or_null("%BtnQuickSeal")
@onready var btn_quick_suppress: Button = get_node_or_null("%BtnQuickSuppress")

var room_id: String = ""
var room_name: String = ""
var is_sealed: bool = false
var is_selected: bool = false
var can_control: bool = false

func _ready() -> void:
	if btn_select:
		btn_select.pressed.connect(_on_select_pressed)
	if btn_quick_seal:
		btn_quick_seal.pressed.connect(_on_quick_seal_pressed)
	if btn_quick_suppress:
		btn_quick_suppress.pressed.connect(_on_quick_suppress_pressed)

func setup(data: Dictionary) -> void:
	room_id = str(data.get("id"))
	room_name = str(data.get("name"))
	if room_name_label:
		room_name_label.text = room_name

func update_telemetry(state: Dictionary) -> void:
	if state.is_empty():
		return
	
	room_id = str(state.get("id"))
	room_name = str(state.get("name"))
	if room_name_label:
		room_name_label.text = room_name
	
	var o2: float = float(state.get("o2_pct"))
	var co2: float = float(state.get("co2_pct"))
	var pressure: float = float(state.get("pressure_kpa"))
	var temp: float = float(state.get("temperature_c"))
	is_sealed = bool(state.get("is_sealed"))
	var is_fire: bool = bool(state.get("is_fire_active"))
	var is_smoke: bool = bool(state.get("is_smoke_active"))
	var is_suppressing: bool = bool(state.get("is_suppression_active"))
	var has_breach: bool = bool(state.get("has_breach"))
	
	if o2_label:
		o2_label.text = "O2: %.1f%%" % o2
	if o2_progress:
		o2_progress.value = o2
		if o2 < 16.0 or o2 > 26.0:
			o2_progress.modulate = Color(0.95, 0.25, 0.25, 1.0)
		elif o2 < 19.0:
			o2_progress.modulate = Color(0.95, 0.75, 0.2, 1.0)
		else:
			o2_progress.modulate = Color(0.2, 0.85, 0.95, 1.0)
	
	if pressure_label:
		pressure_label.text = "P: %.1f kPa" % pressure
		if pressure < 60.0:
			pressure_label.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2, 1.0))
		elif pressure < 90.0:
			pressure_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2, 1.0))
		else:
			pressure_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.9, 1.0))
	
	if temp_label:
		temp_label.text = "T: %.1f°C" % temp
		if temp > 60.0:
			temp_label.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2, 1.0))
		elif temp > 35.0:
			temp_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2, 1.0))
		else:
			temp_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.9, 1.0))
	
	if co2_label:
		co2_label.text = "CO2: %.2f%%" % co2
		if co2 > 0.8:
			co2_label.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2, 1.0))
		elif co2 > 0.2:
			co2_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2, 1.0))
		else:
			co2_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.9, 1.0))
	
	if status_badge:
		if has_breach or pressure < 40.0:
			status_badge.text = "⚡ DECOMPRESSIONE"
			status_badge.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2, 1.0))
		elif is_fire:
			status_badge.text = "🔥 INCENDIO ATTIVO"
			status_badge.add_theme_color_override("font_color", Color(0.95, 0.3, 0.1, 1.0))
		elif is_suppressing:
			status_badge.text = "💨 N2 INIEZIONE"
			status_badge.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0, 1.0))
		elif is_smoke:
			status_badge.text = "🌫️ FUMO RILEVATO"
			status_badge.add_theme_color_override("font_color", Color(0.95, 0.7, 0.2, 1.0))
		elif is_sealed:
			status_badge.text = "🚪 PARATIA SIGILLATA"
			status_badge.add_theme_color_override("font_color", Color(0.85, 0.6, 0.9, 1.0))
		elif o2 < 18.0:
			status_badge.text = "⚠️ IPOSSIA (O2 BASSO)"
			status_badge.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2, 1.0))
		elif co2 > 0.5:
			status_badge.text = "⚠️ CO2 ELEVATA"
			status_badge.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2, 1.0))
		else:
			status_badge.text = "● NORMALE"
			status_badge.add_theme_color_override("font_color", Color(0.2, 0.85, 0.4, 1.0))
	
	if btn_quick_seal:
		btn_quick_seal.text = "🔓 Apri" if is_sealed else "🚪 Sigilla"
		btn_quick_seal.disabled = not can_control
	
	if btn_quick_suppress:
		btn_quick_suppress.disabled = not can_control or is_suppressing

func set_controls_enabled(enabled: bool) -> void:
	can_control = enabled
	if btn_quick_seal:
		btn_quick_seal.disabled = not enabled
	if btn_quick_suppress:
		btn_quick_suppress.disabled = not enabled

func set_selected_visual(selected_flag: bool) -> void:
	is_selected = selected_flag
	if has_theme_stylebox_override("panel"):
		var sb := get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			sb.border_color = Color(0.2, 0.85, 1.0, 0.9) if selected_flag else Color(0.18, 0.28, 0.38, 0.6)
			sb.border_width_left = 2 if selected_flag else 1
			sb.border_width_right = 2 if selected_flag else 1
			sb.border_width_top = 2 if selected_flag else 1
			sb.border_width_bottom = 2 if selected_flag else 1

func _on_select_pressed() -> void:
	selected.emit(room_id)

func _on_quick_seal_pressed() -> void:
	if not can_control:
		return
	is_sealed = not is_sealed
	seal_toggled.emit(room_id, is_sealed)

func _on_quick_suppress_pressed() -> void:
	if not can_control:
		return
	fire_suppressed.emit(room_id)
