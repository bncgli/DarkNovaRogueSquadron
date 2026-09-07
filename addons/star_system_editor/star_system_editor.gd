@tool
class_name StarSystemEditor
extends Control

## Editor visivo per la creazione e modifica dei Sistemi Stellari in Godot Engine / GodotOS.
## Funziona sia integrato nell'Editor di Godot (Bottom Panel / Main Screen) sia come applicazione o scena standalone.
## La UI statica è definita in star_system_editor.tscn; questo script contiene solo logica ed event handling.

const DEFAULT_SYSTEM_PATH := "res://Outside/StarSystemGrid/default_star_system.tres"

var current_system: StarSystemData = null
var current_file_path: String = ""

## Gestore di Undo/Redo: se il plugin lo assegna prima di _ready() (EditorUndoRedoManager,
## caso EditorPlugin integrato), viene riusato. Altrimenti viene creato un UndoRedo nativo
## locale per l'uso standalone, con Ctrl+Z / Ctrl+Y gestiti manualmente.
var undo_redo: Object = null
var _using_local_undo_redo: bool = false

var _pending_file_action: String = ""

# UI Components (definiti in star_system_editor.tscn, referenziati via Unique Name)
@onready var canvas: StarSystemCanvas = %Canvas

# Toolbar Controlli
@onready var lbl_current_file: Label = %LblCurrentFile
@onready var btn_new: Button = %BtnNew
@onready var btn_open: Button = %BtnOpen
@onready var btn_save: Button = %BtnSave
@onready var btn_save_as: Button = %BtnSaveAs
@onready var btn_export_json: Button = %BtnExportJson
@onready var btn_import_json: Button = %BtnImportJson

# Toolbar Aggiunta Rapida Entità
@onready var btn_add_star: Button = %BtnAddStar
@onready var btn_add_planet: Button = %BtnAddPlanet
@onready var btn_add_gas_giant: Button = %BtnAddGasGiant
@onready var btn_add_moon: Button = %BtnAddMoon
@onready var btn_add_station: Button = %BtnAddStation
@onready var btn_add_asteroid: Button = %BtnAddAsteroid
@onready var btn_add_wreck: Button = %BtnAddWreck
@onready var btn_add_patrol: Button = %BtnAddPatrol
@onready var btn_delete_selected: Button = %BtnDeleteSelected

# Layer Toggles
@onready var chk_grid: CheckBox = %ChkGrid
@onready var chk_orbits: CheckBox = %ChkOrbits
@onready var chk_shadows: CheckBox = %ChkShadows
@onready var chk_labels: CheckBox = %ChkLabels
@onready var chk_sec_ids: CheckBox = %ChkSecIds

# Zoom & View
@onready var zoom_slider: HSlider = %ZoomSlider
@onready var lbl_zoom: Label = %LblZoom
@onready var btn_reset_view: Button = %BtnResetView

# Inspector & Outliner
@onready var outliner_tree: Tree = %OutlinerTree
@onready var prop_editor_vbox: VBoxContainer = %PropEditorVBox
@onready var lbl_selected_title: Label = %LblSelectedTitle

# Status Bar
@onready var lbl_status_coords: Label = %LblStatusCoords
@onready var lbl_status_selection: Label = %LblStatusSelection
@onready var lbl_status_stats: Label = %LblStatusStats
@onready var lbl_status_msg: Label = %LblStatusMsg

# Dialogs
@onready var file_dialog: FileDialog = %FileDialog
@onready var confirm_dialog: ConfirmationDialog = %ConfirmDialog

func _ready() -> void:
	_ensure_undo_redo()
	_connect_signals()
	_load_initial_system()

func _ensure_undo_redo() -> void:
	if undo_redo == null:
		undo_redo = UndoRedo.new()
		_using_local_undo_redo = true

## Ctrl+Z / Ctrl+Y solo quando si usa lo stack di Undo/Redo locale (uso standalone).
## Quando integrato come EditorPlugin, l'EditorUndoRedoManager è già collegato
## al menu Modifica > Annulla/Ripristina dell'editor di Godot.
func _unhandled_key_input(event: InputEvent) -> void:
	if not _using_local_undo_redo:
		return
	if not (event is InputEventKey and event.pressed):
		return
	var k := event as InputEventKey
	if not k.ctrl_pressed:
		return
	if k.keycode == KEY_Z and not k.shift_pressed:
		if undo_redo.has_undo():
			undo_redo.undo()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_Y or (k.keycode == KEY_Z and k.shift_pressed):
		if undo_redo.has_redo():
			undo_redo.redo()
		get_viewport().set_input_as_handled()

func _connect_signals() -> void:
	btn_new.pressed.connect(_on_btn_new_pressed)
	btn_open.pressed.connect(_on_btn_open_pressed)
	btn_save.pressed.connect(_on_btn_save_pressed)
	btn_save_as.pressed.connect(_on_btn_save_as_pressed)
	btn_export_json.pressed.connect(_on_btn_export_json_pressed)
	btn_import_json.pressed.connect(_on_btn_import_json_pressed)

	btn_add_star.pressed.connect(func(): _add_celestial_body("STAR"))
	btn_add_planet.pressed.connect(func(): _add_celestial_body("PLANET"))
	btn_add_gas_giant.pressed.connect(func(): _add_celestial_body("GAS_GIANT"))
	btn_add_moon.pressed.connect(func(): _add_celestial_body("MOON"))
	btn_add_station.pressed.connect(func(): _add_celestial_body("STATION"))
	btn_add_asteroid.pressed.connect(func(): _add_celestial_body("ASTEROID_FIELD"))
	btn_add_wreck.pressed.connect(func(): _add_celestial_body("WRECK"))
	btn_add_patrol.pressed.connect(func(): _add_celestial_body("PATROL"))
	btn_delete_selected.pressed.connect(_on_btn_delete_selected_pressed)

	chk_grid.toggled.connect(func(v): canvas.show_grid = v; canvas.queue_redraw())
	chk_orbits.toggled.connect(func(v): canvas.show_orbits = v; canvas.queue_redraw())
	chk_shadows.toggled.connect(func(v): canvas.show_shadow_cones = v; canvas.queue_redraw())
	chk_labels.toggled.connect(func(v): canvas.show_labels = v; canvas.queue_redraw())
	chk_sec_ids.toggled.connect(func(v): canvas.show_sectors_id = v; canvas.queue_redraw())

	btn_reset_view.pressed.connect(func(): if canvas: canvas.reset_view())
	zoom_slider.value_changed.connect(func(val): if canvas: canvas.zoom_level = val; canvas.queue_redraw(); _update_zoom_label())

	outliner_tree.item_selected.connect(_on_outliner_item_selected)

	canvas.entity_selected.connect(_on_canvas_entity_selected)
	canvas.sector_clicked.connect(_on_canvas_sector_clicked)
	canvas.entity_moved.connect(_on_canvas_entity_moved)
	canvas.cursor_coords_changed.connect(_on_canvas_cursor_coords_changed)

	file_dialog.file_selected.connect(_on_file_dialog_selected)
	confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)

func _load_initial_system() -> void:
	if ResourceLoader.exists(DEFAULT_SYSTEM_PATH):
		var res := ResourceLoader.load(DEFAULT_SYSTEM_PATH)
		if res is StarSystemData:
			load_star_system(res as StarSystemData, DEFAULT_SYSTEM_PATH)
			return
	# Altrimenti genera sistema iniziale predefinito
	var sys := StarSystemData.new("SYS-HELIOS-01", "Helios Nova System")
	_populate_default_bodies(sys)
	load_star_system(sys, "")

func _populate_default_bodies(sys: StarSystemData) -> void:
	# Stella primaria
	sys.primary_star_name = "Helios Nova"
	sys.primary_star_coords = Vector3i.ZERO
	sys.primary_star_color = Color(1.0, 0.96, 0.9, 1.0)
	sys.primary_star_energy = 1.3
	sys.primary_star_radius_km = 696340.0
	
	var star := CelestialBodyData.new("STAR_SOL_PRIME", "Helios Nova (Stella Primaria)", "STAR", Vector3i(0, 0, 0))
	star.radius_km = 696340.0
	star.mass_tons = 1.989e27
	star.luminosity = 1.0
	star.color = Color(1.0, 0.96, 0.9, 1.0)
	star.occluding = false
	star.description = "Stella di sequenza principale."
	sys.add_or_update_body(star)

	var vulcan := CelestialBodyData.new("PLANET_VULCAN", "Vulcanus", "PLANET", Vector3i(1, 3, 0))
	vulcan.radius_km = 4800.0
	vulcan.mass_tons = 3.3e20
	vulcan.occluding = true
	vulcan.description = "Pianeta lavico interno."
	sys.add_or_update_body(vulcan)

	var terra := CelestialBodyData.new("PLANET_TERRA_NOVA", "Terra Nova Prime", "PLANET", Vector3i(4, 8, 0))
	terra.radius_km = 6371.0
	terra.mass_tons = 5.97e21
	terra.occluding = true
	terra.description = "Mondo abitabile centrale."
	sys.add_or_update_body(terra)

	var moon := CelestialBodyData.new("MOON_LUNA_SEC", "Selene Secundus", "MOON", Vector3i(4, 9, 0))
	moon.radius_km = 1737.0
	moon.mass_tons = 7.35e19
	moon.occluding = true
	moon.description = "Luna mineraria."
	sys.add_or_update_body(moon)

	var belt := CelestialBodyData.new("BELT_CERES", "Fascia Asteroidi Interna", "ASTEROID_FIELD", Vector3i(3, 10, 0))
	belt.radius_km = 25000.0
	belt.mass_tons = 1.5e18
	belt.occluding = false
	belt.description = "Denso campo di detriti."
	sys.add_or_update_body(belt)

	var station := CelestialBodyData.new("STATION_VALKYRIE", "Stazione Spaziale Valkyrie", "STATION", Vector3i(4, 12, 0))
	station.radius_km = 15.0
	station.mass_tons = 8.5e10
	station.occluding = false
	station.description = "Avamposto orbitale."
	sys.add_or_update_body(station)

	var kronos := CelestialBodyData.new("GAS_GIANT_KRONOS", "Kronos Titan", "GAS_GIANT", Vector3i(8, 20, 0))
	kronos.radius_km = 69911.0
	kronos.mass_tons = 1.89e24
	kronos.occluding = true
	kronos.description = "Gigante gassoso anellato."
	sys.add_or_update_body(kronos)

func load_star_system(sys: StarSystemData, path: String = "") -> void:
	current_system = sys
	current_file_path = path

	if undo_redo:
		undo_redo.clear_history()

	if canvas:
		canvas.system_data = current_system
		canvas.selected_body_id = ""
		canvas.reset_view()

	if lbl_current_file:
		lbl_current_file.text = path.get_file() if not path.is_empty() else "Nuovo Sistema Stellare (non salvato)"
		lbl_current_file.tooltip_text = path

	_refresh_outliner()
	_update_stats_label()
	_show_system_global_props()
	_set_status_msg("Sistema stellare caricato con successo.")

# =============================================================================
# GESTIONE OUTLINER & PROPRIETÀ
# =============================================================================

func _refresh_outliner() -> void:
	if outliner_tree == null or current_system == null:
		return
		
	outliner_tree.clear()
	var root := outliner_tree.create_item()
	
	# Item radice sistema
	var sys_item := outliner_tree.create_item(root)
	sys_item.set_text(0, "🌌 %s" % current_system.system_name)
	sys_item.set_metadata(0, {"type": "SYSTEM"})
	
	# Gruppi di entità
	var stars_group := outliner_tree.create_item(sys_item)
	stars_group.set_text(0, "⭐ Stelle")
	
	var planets_group := outliner_tree.create_item(sys_item)
	planets_group.set_text(0, "🪐 Pianeti & Giganti")
	
	var others_group := outliner_tree.create_item(sys_item)
	others_group.set_text(0, "🛰️ Stazioni, Asteroidi & Relitti")
	
	for body in current_system.celestial_bodies:
		var b_type: String = body.type.to_upper()
		var b_name: String = body.name
		var b_id: String = body.id
		var c: Vector3i = body.coords
		var sec_str := SectorData.format_coords_to_id(c)
		
		var parent_item := others_group
		if b_type == "STAR":
			parent_item = stars_group
		elif b_type in ["PLANET", "GAS_GIANT", "MOON"]:
			parent_item = planets_group
			
		var it := outliner_tree.create_item(parent_item)
		it.set_text(0, "%s (%s)" % [b_name, sec_str])
		it.set_metadata(0, {"type": "BODY", "id": b_id, "data": body})
		
		if canvas and canvas.selected_body_id == b_id:
			it.select(0)

func _show_system_global_props() -> void:
	if prop_editor_vbox == null or current_system == null:
		return
	_clear_prop_editor()
	lbl_selected_title.text = "Proprietà Globali Sistema"
	
	_add_text_field("ID Sistema:", current_system, "system_id", "Modifica ID Sistema")
	_add_text_field("Nome Sistema:", current_system, "system_name", "Modifica Nome Sistema", _refresh_outliner)
	_add_text_field("Descrizione:", current_system, "description", "Modifica Descrizione Sistema")
	
	_add_separator()
	_add_heading("Parametri Stella Primaria")
	_add_text_field("Nome Stella:", current_system, "primary_star_name", "Modifica Nome Stella Primaria")
	_add_vector3i_field("Coordinate Stella:", current_system, "primary_star_coords", "Sposta Stella Primaria", _redraw_canvas)
	_add_float_field("Energia Base:", current_system, "primary_star_energy", "Modifica Energia Stella Primaria")
	_add_float_field("Raggio (km):", current_system, "primary_star_radius_km", "Modifica Raggio Stella Primaria")
	_add_color_field("Colore Luce:", current_system, "primary_star_color", "Modifica Colore Stella Primaria", _redraw_canvas)

func _show_body_props(body: CelestialBodyData) -> void:
	if prop_editor_vbox == null:
		return
	_clear_prop_editor()
	lbl_selected_title.text = "Modifica: %s" % body.name
	
	_add_text_field("ID Entità:", body, "id", "Modifica ID Entità", func(): if canvas: canvas.selected_body_id = body.id; _refresh_outliner())
	_add_text_field("Nome:", body, "name", "Rinomina Entità", func(): _refresh_outliner(); _redraw_canvas())
	
	var types: Array[String] = ["STAR", "PLANET", "GAS_GIANT", "MOON", "STATION", "ASTEROID_FIELD", "WRECK", "PATROL"]
	_add_option_field("Tipo:", types, body, "type", "Modifica Tipo Entità", func(): _refresh_outliner(); _redraw_canvas())
	
	_add_vector3i_field("Coordinate Griglia:", body, "coords", "Sposta Entità", func(): _redraw_canvas(); _refresh_outliner())
	
	_add_float_field("Raggio (km):", body, "radius_km", "Modifica Raggio Entità", _redraw_canvas)
	_add_float_field("Massa (Tonnellate):", body, "mass_tons", "Modifica Massa Entità")
	_add_bool_field("Proietta Cono d'Ombra:", body, "occluding", "Modifica Occlusione Entità", _redraw_canvas)
	_add_text_field("Descrizione:", body, "description", "Modifica Descrizione Entità")
	
	if body.color is Color:
		_add_color_field("Colore Display:", body, "color", "Modifica Colore Entità", _redraw_canvas)
		
	var btn_del := Button.new()
	btn_del.text = "🗑️ Rimuovi Entità"
	btn_del.pressed.connect(func(): _delete_body(body.id))
	prop_editor_vbox.add_child(btn_del)

func _clear_prop_editor() -> void:
	for c in prop_editor_vbox.get_children():
		c.queue_free()

func _add_heading(title: String) -> void:
	var l := Label.new()
	l.text = title
	l.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	prop_editor_vbox.add_child(l)

func _add_separator() -> void:
	prop_editor_vbox.add_child(HSeparator.new())

func _redraw_canvas() -> void:
	if canvas:
		canvas.queue_redraw()

# =============================================================================
# UNDO/REDO - HELPER GENERICO PER MODIFICA PROPRIETÀ
# =============================================================================

## Registra un'azione di Undo/Redo per la modifica di una singola proprietà di un oggetto
## (Resource dei dati del sistema stellare). Il valore nuovo viene applicato immediatamente
## tramite add_do_property; refresh_callback (se valido) viene eseguito sia sul do che sull'undo
## per aggiornare la UI (outliner, canvas, ecc.).
func _commit_property_change(action_name: String, obj: Object, prop: StringName, old_value: Variant, new_value: Variant, refresh_callback: Callable = Callable()) -> void:
	if typeof(old_value) == typeof(new_value) and old_value == new_value:
		return
	_ensure_undo_redo()
	undo_redo.create_action(action_name)
	undo_redo.add_do_property(obj, prop, new_value)
	undo_redo.add_undo_property(obj, prop, old_value)
	if refresh_callback.is_valid():
		undo_redo.add_do_method(refresh_callback)
		undo_redo.add_undo_method(refresh_callback)
	undo_redo.commit_action()

# =============================================================================
# CAMPI DINAMICI DELL'INSPECTOR (generati a runtime, dipendono dai dati selezionati)
# =============================================================================

func _add_text_field(label: String, obj: Object, prop: StringName, action_name: String, extra_refresh: Callable = Callable()) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(90, 0)
	h.add_child(l)
	var le := LineEdit.new()
	le.text = str(obj.get(prop))
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var baseline := {"value": obj.get(prop)}
	le.focus_entered.connect(func(): baseline.value = obj.get(prop))
	le.text_changed.connect(func(v):
		obj.set(prop, v)
		if extra_refresh.is_valid():
			extra_refresh.call()
	)
	le.focus_exited.connect(func():
		_commit_property_change(action_name, obj, prop, baseline.value, obj.get(prop), extra_refresh)
		baseline.value = obj.get(prop)
	)
	h.add_child(le)
	prop_editor_vbox.add_child(h)

func _add_float_field(label: String, obj: Object, prop: StringName, action_name: String, extra_refresh: Callable = Callable()) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(90, 0)
	h.add_child(l)
	var sb := SpinBox.new()
	sb.min_value = 0.0
	sb.max_value = 1.0e30
	sb.step = 0.1
	sb.value = float(obj.get(prop))
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var baseline := {"value": obj.get(prop)}
	var le := sb.get_line_edit()
	le.focus_entered.connect(func(): baseline.value = obj.get(prop))
	sb.value_changed.connect(func(v):
		obj.set(prop, v)
		if extra_refresh.is_valid():
			extra_refresh.call()
	)
	le.focus_exited.connect(func():
		_commit_property_change(action_name, obj, prop, baseline.value, obj.get(prop), extra_refresh)
		baseline.value = obj.get(prop)
	)
	h.add_child(sb)
	prop_editor_vbox.add_child(h)

func _add_vector3i_field(label: String, obj: Object, prop: StringName, action_name: String, extra_refresh: Callable = Callable()) -> void:
	var val: Vector3i = obj.get(prop)
	var vbox := VBoxContainer.new()
	var l := Label.new()
	l.text = label
	vbox.add_child(l)
	var h := HBoxContainer.new()
	
	var baseline := {"value": val}
	
	var sb_x := SpinBox.new()
	sb_x.min_value = -100
	sb_x.max_value = 100
	sb_x.value = val.x
	sb_x.prefix = "X:"
	h.add_child(sb_x)
	
	var sb_y := SpinBox.new()
	sb_y.min_value = -100
	sb_y.max_value = 100
	sb_y.value = val.y
	sb_y.prefix = "Y:"
	h.add_child(sb_y)
	
	var sb_z := SpinBox.new()
	sb_z.min_value = -100
	sb_z.max_value = 100
	sb_z.value = val.z
	sb_z.prefix = "Z:"
	h.add_child(sb_z)
	
	var update_vec := func():
		var vec := Vector3i(int(sb_x.value), int(sb_y.value), int(sb_z.value))
		obj.set(prop, vec)
		if extra_refresh.is_valid():
			extra_refresh.call()
	
	var commit_vec := func():
		_commit_property_change(action_name, obj, prop, baseline.value, obj.get(prop), extra_refresh)
		baseline.value = obj.get(prop)
	
	sb_x.value_changed.connect(func(_v): update_vec.call())
	sb_y.value_changed.connect(func(_v): update_vec.call())
	sb_z.value_changed.connect(func(_v): update_vec.call())
	
	for sb in [sb_x, sb_y, sb_z]:
		var le: LineEdit = sb.get_line_edit()
		le.focus_entered.connect(func(): baseline.value = obj.get(prop))
		le.focus_exited.connect(func(): commit_vec.call())
	
	vbox.add_child(h)
	prop_editor_vbox.add_child(vbox)

func _add_bool_field(label: String, obj: Object, prop: StringName, action_name: String, extra_refresh: Callable = Callable()) -> void:
	var cb := CheckBox.new()
	cb.text = label
	cb.button_pressed = bool(obj.get(prop))
	cb.toggled.connect(func(v):
		var old_v: Variant = obj.get(prop)
		_commit_property_change(action_name, obj, prop, old_v, v, extra_refresh)
	)
	prop_editor_vbox.add_child(cb)

func _add_color_field(label: String, obj: Object, prop: StringName, action_name: String, extra_refresh: Callable = Callable()) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(90, 0)
	h.add_child(l)
	var cp := ColorPickerButton.new()
	cp.color = obj.get(prop)
	cp.custom_minimum_size = Vector2(50, 24)
	var baseline := {"value": cp.color}
	cp.button_down.connect(func(): baseline.value = obj.get(prop))
	cp.color_changed.connect(func(v):
		obj.set(prop, v)
		if extra_refresh.is_valid():
			extra_refresh.call()
	)
	cp.popup_closed.connect(func():
		_commit_property_change(action_name, obj, prop, baseline.value, obj.get(prop), extra_refresh)
		baseline.value = obj.get(prop)
	)
	h.add_child(cp)
	prop_editor_vbox.add_child(h)

func _add_option_field(label: String, options: Array[String], obj: Object, prop: StringName, action_name: String, extra_refresh: Callable = Callable()) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(90, 0)
	h.add_child(l)
	var opt := OptionButton.new()
	var current_val: Variant = obj.get(prop)
	for i in range(options.size()):
		opt.add_item(options[i], i)
		if options[i] == current_val:
			opt.selected = i
	opt.item_selected.connect(func(idx):
		var old_v: Variant = obj.get(prop)
		_commit_property_change(action_name, obj, prop, old_v, options[idx], extra_refresh)
	)
	h.add_child(opt)
	prop_editor_vbox.add_child(h)

# =============================================================================
# OPERAZIONI SU CORPI CELESTI (con supporto Undo/Redo)
# =============================================================================

func _add_celestial_body(type: String) -> void:
	if current_system == null:
		return
	var count := current_system.celestial_bodies.size() + 1
	var new_body := CelestialBodyData.new(
		"BODY_%s_%d" % [type, count],
		"Nuovo %s %d" % [type.capitalize(), count],
		type,
		Vector3i(randi_range(-8, 8), randi_range(-8, 8), 0)
	)
	new_body.radius_km = 5000.0
	new_body.mass_tons = 1.0e20
	new_body.occluding = (type in ["PLANET", "GAS_GIANT", "MOON"])
	new_body.description = "Entità celeste aggiunta tramite Star System Editor."
	
	if type == "STAR":
		new_body.radius_km = 500000.0
		new_body.mass_tons = 1.0e27
		new_body.occluding = false
		new_body.color = Color(1.0, 0.9, 0.4, 1.0)
	elif type == "GAS_GIANT":
		new_body.radius_km = 60000.0
		new_body.mass_tons = 1.5e24
		new_body.occluding = true
	elif type == "STATION":
		new_body.radius_km = 10.0
		new_body.mass_tons = 5.0e9
		new_body.occluding = false
	
	_ensure_undo_redo()
	undo_redo.create_action("Aggiungi %s" % type)
	undo_redo.add_do_method(_do_add_body.bind(new_body))
	undo_redo.add_undo_method(_do_remove_body.bind(new_body.id))
	undo_redo.add_do_reference(new_body)
	undo_redo.commit_action()

func _do_add_body(body: CelestialBodyData) -> void:
	current_system.add_or_update_body(body)
	if canvas:
		canvas.selected_body_id = body.id
		canvas.queue_redraw()
	_refresh_outliner()
	_update_stats_label()
	_show_body_props(body)
	_set_status_msg("Aggiunta entità '%s'." % body.name)

func _do_remove_body(body_id: String) -> void:
	current_system.remove_body(body_id)
	if canvas and canvas.selected_body_id == body_id:
		canvas.selected_body_id = ""
	if canvas:
		canvas.queue_redraw()
	_refresh_outliner()
	_update_stats_label()
	_show_system_global_props()
	_set_status_msg("Entità rimossa.")

func _delete_body(body_id: String) -> void:
	if current_system == null or body_id.is_empty():
		return
	var body := current_system.get_body(body_id)
	if body == null:
		return
	_ensure_undo_redo()
	undo_redo.create_action("Rimuovi %s" % body.name)
	undo_redo.add_do_method(_do_remove_body.bind(body_id))
	undo_redo.add_undo_method(_do_add_body.bind(body))
	undo_redo.add_undo_reference(body)
	undo_redo.commit_action()

func _on_btn_delete_selected_pressed() -> void:
	if canvas and not canvas.selected_body_id.is_empty():
		_delete_body(canvas.selected_body_id)

# =============================================================================
# EVENTI SELEZIONE & INTERAZIONE CANVAS
# =============================================================================

func _on_canvas_entity_selected(body: CelestialBodyData) -> void:
	lbl_status_selection.text = "Selezionato: %s (%s)" % [body.name, body.id]
	_show_body_props(body)
	_refresh_outliner()

func _on_canvas_sector_clicked(coords: Vector3i) -> void:
	lbl_status_selection.text = "Settore selezionato: %s" % SectorData.format_coords_to_id(coords)
	if canvas:
		canvas.selected_body_id = ""
		canvas.queue_redraw()
	_show_sector_props(coords)
	_refresh_outliner()

func _show_sector_props(coords: Vector3i) -> void:
	if prop_editor_vbox == null or current_system == null:
		return
	_clear_prop_editor()
	
	var sec_id := SectorData.format_coords_to_id(coords)
	lbl_selected_title.text = "Settore: %s" % sec_id
	
	var sector: SectorData = null
	for s in current_system.custom_sectors:
		if s.sector_id == sec_id:
			sector = s
			break

	if not sector:
		var btn_create := Button.new()
		btn_create.text = "Personalizza Settore"
		btn_create.pressed.connect(func() -> void:
			var new_sec := SectorData.new()
			new_sec.sector_id = sec_id
			new_sec.coordinates = coords
			_ensure_undo_redo()
			undo_redo.create_action("Personalizza Settore %s" % sec_id)
			undo_redo.add_do_method(_do_add_custom_sector.bind(new_sec))
			undo_redo.add_undo_method(_do_remove_custom_sector.bind(sec_id, coords))
			undo_redo.add_do_reference(new_sec)
			undo_redo.commit_action()
		)
		prop_editor_vbox.add_child(btn_create)
		return

	_add_text_field("Nome Locale:", sector, "sector_name", "Modifica Nome Settore")
	
	_add_separator()
	_add_heading("Pericoli Ambientali")
	
	var hazards_vbox := VBoxContainer.new()
	prop_editor_vbox.add_child(hazards_vbox)
	
	for i in range(sector.environmental_hazards.size()):
		var h_data: EnvironmentalHazardData = sector.environmental_hazards[i]
		var frame := PanelContainer.new()
		var inner_vbox := VBoxContainer.new()
		frame.add_child(inner_vbox)
		
		_add_hazard_item_editor(inner_vbox, h_data, sector, i, coords)
		hazards_vbox.add_child(frame)
		hazards_vbox.add_child(HSeparator.new())
		
	var btn_add_h := Button.new()
	btn_add_h.text = "+ Aggiungi Pericolo"
	btn_add_h.pressed.connect(func():
		var new_h := EnvironmentalHazardData.new("HAZARD_%d" % sector.environmental_hazards.size(), "RAD", 0.5)
		var insert_index := sector.environmental_hazards.size()
		_ensure_undo_redo()
		undo_redo.create_action("Aggiungi Pericolo Ambientale")
		undo_redo.add_do_method(_do_insert_hazard_at.bind(sector, insert_index, new_h, coords))
		undo_redo.add_undo_method(_do_remove_hazard_at.bind(sector, insert_index, coords))
		undo_redo.add_do_reference(new_h)
		undo_redo.commit_action()
	)
	prop_editor_vbox.add_child(btn_add_h)

func _do_add_custom_sector(sec: SectorData) -> void:
	current_system.add_or_update_custom_sector(sec)
	_show_sector_props(sec.coordinates)

func _do_remove_custom_sector(sec_id: String, coords: Vector3i) -> void:
	current_system.remove_custom_sector(sec_id)
	_show_sector_props(coords)

func _do_insert_hazard_at(sector: SectorData, index: int, hazard: EnvironmentalHazardData, coords: Vector3i) -> void:
	sector.environmental_hazards.insert(index, hazard)
	_show_sector_props(coords)

func _do_remove_hazard_at(sector: SectorData, index: int, coords: Vector3i) -> void:
	if index >= 0 and index < sector.environmental_hazards.size():
		sector.environmental_hazards.remove_at(index)
	_show_sector_props(coords)

func _add_hazard_item_editor(container: Control, hazard: EnvironmentalHazardData, sector: SectorData, index: int, coords: Vector3i) -> void:
	var h_type_hbox := HBoxContainer.new()
	var l_type := Label.new()
	l_type.text = "Tipo:"
	l_type.custom_minimum_size = Vector2(70, 0)
	h_type_hbox.add_child(l_type)
	
	var opt_type := OptionButton.new()
	var types := ["ion_storm", "radiation", "asteroid_drift", "emp_field", "gravity_well", "thermal_vent"]
	for i in range(types.size()):
		opt_type.add_item(types[i], i)
		if types[i] == hazard.type:
			opt_type.selected = i
	opt_type.item_selected.connect(func(idx):
		var old_v: String = hazard.type
		_commit_property_change("Modifica Tipo Pericolo", hazard, "type", old_v, types[idx])
	)
	h_type_hbox.add_child(opt_type)
	
	var btn_del := Button.new()
	btn_del.text = "X"
	btn_del.modulate = Color.CRIMSON
	btn_del.pressed.connect(func():
		_ensure_undo_redo()
		undo_redo.create_action("Rimuovi Pericolo Ambientale")
		undo_redo.add_do_method(_do_remove_hazard_at.bind(sector, index, coords))
		undo_redo.add_undo_method(_do_insert_hazard_at.bind(sector, index, hazard, coords))
		undo_redo.add_undo_reference(hazard)
		undo_redo.commit_action()
	)
	h_type_hbox.add_child(btn_del)
	container.add_child(h_type_hbox)
	
	var h_name_hbox := HBoxContainer.new()
	var l_name := Label.new()
	l_name.text = "Nome:"
	l_name.custom_minimum_size = Vector2(70, 0)
	h_name_hbox.add_child(l_name)
	var le_name := LineEdit.new()
	le_name.text = hazard.name
	le_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var baseline_name := {"value": hazard.name}
	le_name.focus_entered.connect(func(): baseline_name.value = hazard.name)
	le_name.text_changed.connect(func(v): hazard.name = v)
	le_name.focus_exited.connect(func():
		_commit_property_change("Modifica Nome Pericolo", hazard, "name", baseline_name.value, hazard.name)
		baseline_name.value = hazard.name
	)
	h_name_hbox.add_child(le_name)
	container.add_child(h_name_hbox)
	
	var h_sev_hbox := HBoxContainer.new()
	var l_sev := Label.new()
	l_sev.text = "Severità:"
	l_sev.custom_minimum_size = Vector2(70, 0)
	h_sev_hbox.add_child(l_sev)
	var sb_sev := SpinBox.new()
	sb_sev.min_value = 0.0
	sb_sev.max_value = 100.0
	sb_sev.value = hazard.severity
	var baseline_sev := {"value": hazard.severity}
	var sev_le := sb_sev.get_line_edit()
	sev_le.focus_entered.connect(func(): baseline_sev.value = hazard.severity)
	sb_sev.value_changed.connect(func(v): hazard.severity = v)
	sev_le.focus_exited.connect(func():
		_commit_property_change("Modifica Severità Pericolo", hazard, "severity", baseline_sev.value, hazard.severity)
		baseline_sev.value = hazard.severity
	)
	h_sev_hbox.add_child(sb_sev)
	container.add_child(h_sev_hbox)

func _on_canvas_entity_moved(body_id: String, old_coords: Vector3i, new_coords: Vector3i) -> void:
	if current_system == null or old_coords == new_coords:
		return
	var b := current_system.get_body(body_id)
	if b == null:
		return
	_ensure_undo_redo()
	undo_redo.create_action("Sposta Entità")
	undo_redo.add_do_property(b, "coords", new_coords)
	undo_redo.add_undo_property(b, "coords", old_coords)
	undo_redo.add_do_method(_refresh_after_move.bind(body_id))
	undo_redo.add_undo_method(_refresh_after_move.bind(body_id))
	undo_redo.commit_action()

func _refresh_after_move(body_id: String) -> void:
	var b := current_system.get_body(body_id)
	if b:
		if canvas:
			canvas.queue_redraw()
		_show_body_props(b)
		_refresh_outliner()
		_set_status_msg("Entità '%s' spostata in %s." % [b.name, SectorData.format_coords_to_id(b.coords)])

func _on_canvas_cursor_coords_changed(coords: Vector3i) -> void:
	lbl_status_coords.text = "Cursore: [%d, %d, %d] (%s)" % [coords.x, coords.y, coords.z, SectorData.format_coords_to_id(coords)]

func _on_outliner_item_selected() -> void:
	var it := outliner_tree.get_selected()
	if it == null:
		return
	var meta: Variant = it.get_metadata(0)
	if meta is Dictionary:
		var type: String = meta.get("type")
		if type == "SYSTEM":
			if canvas:
				canvas.selected_body_id = ""
				canvas.queue_redraw()
			_show_system_global_props()
		elif type == "BODY":
			var b_id: String = meta.get("id")
			if canvas:
				canvas.selected_body_id = b_id
				canvas.queue_redraw()
			var b_data := current_system.get_body(b_id)
			if b_data:
				_show_body_props(b_data)

func _update_zoom_label() -> void:
	if lbl_zoom and canvas:
		lbl_zoom.text = "%d%%" % int(canvas.zoom_level * 100)

func _update_stats_label() -> void:
	if lbl_status_stats and current_system:
		lbl_status_stats.text = "Entità: %d" % current_system.celestial_bodies.size()

func _set_status_msg(msg: String) -> void:
	if lbl_status_msg:
		lbl_status_msg.text = msg

# =============================================================================
# SALVATAGGIO, CARICAMENTO ED ESPORTAZIONE
# =============================================================================

func _on_btn_new_pressed() -> void:
	_pending_file_action = "new"
	confirm_dialog.dialog_text = "Creare un nuovo sistema stellare? Le modifiche non salvate andranno perse."
	confirm_dialog.popup_centered()

func _on_btn_open_pressed() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = ["*.tres, *.res ; Godot Resource"]
	_pending_file_action = "open_tres"
	file_dialog.popup_centered(Vector2i(700, 500))

func _on_btn_save_pressed() -> void:
	if current_file_path.is_empty():
		_on_btn_save_as_pressed()
	else:
		_save_system_to_path(current_file_path)

func _on_btn_save_as_pressed() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.filters = ["*.tres, *.res ; Godot Resource"]
	_pending_file_action = "save_tres"
	file_dialog.popup_centered(Vector2i(700, 500))

func _on_btn_export_json_pressed() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.filters = ["*.json ; JSON File"]
	_pending_file_action = "export_json"
	file_dialog.popup_centered(Vector2i(700, 500))

func _on_btn_import_json_pressed() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = ["*.json ; JSON File"]
	_pending_file_action = "import_json"
	file_dialog.popup_centered(Vector2i(700, 500))

func _on_file_dialog_selected(path: String) -> void:
	match _pending_file_action:
		"open_tres":
			var res := ResourceLoader.load(path)
			if res is StarSystemData:
				load_star_system(res as StarSystemData, path)
			else:
				_set_status_msg("Errore: il file selezionato non è un StarSystemData.")
		"save_tres":
			_save_system_to_path(path)
		"export_json":
			_export_system_to_json(path)
		"import_json":
			_import_system_from_json(path)

func _on_confirm_dialog_confirmed() -> void:
	if _pending_file_action == "new":
		var sys := StarSystemData.new("SYS-NEW", "Nuovo Sistema Stellare")
		load_star_system(sys, "")

func _save_system_to_path(path: String) -> void:
	if current_system == null:
		return
	var err := ResourceSaver.save(current_system, path)
	if err == OK:
		current_file_path = path
		lbl_current_file.text = path.get_file()
		lbl_current_file.tooltip_text = path
		_set_status_msg("Sistema stellare salvato con successo in %s." % path)
	else:
		_set_status_msg("Errore nel salvataggio: %d." % err)

func _export_system_to_json(path: String) -> void:
	if current_system == null:
		return
	var dict := current_system.to_dict()
	var json_str := JSON.stringify(dict, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		_set_status_msg("Esportazione JSON completata in %s." % path)
	else:
		_set_status_msg("Errore nell'apertura del file JSON in scrittura.")

func _import_system_from_json(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		_set_status_msg("Errore nell'apertura del file JSON.")
		return
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(content)
	if err == OK and json.data is Dictionary:
		var sys := StarSystemData.new()
		sys.from_dict(json.data)
		load_star_system(sys, "")
		_set_status_msg("Sistema importato con successo da JSON.")
	else:
		_set_status_msg("Errore nel parsing del file JSON.")
