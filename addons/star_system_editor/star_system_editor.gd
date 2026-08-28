@tool
class_name StarSystemEditor
extends Control

## Editor visivo per la creazione e modifica dei Sistemi Stellari in Godot Engine / GodotOS.
## Funziona sia integrato nell'Editor di Godot (Bottom Panel / Main Screen) sia come applicazione o scena standalone.

const DEFAULT_SYSTEM_PATH := "res://Outside/StarSystemGrid/default_star_system.tres"

var current_system: StarSystemData = null
var current_file_path: String = ""

# UI Components
var canvas: StarSystemCanvas = null

# Toolbar Controlli
var lbl_current_file: Label = null
var btn_new: Button = null
var btn_open: Button = null
var btn_save: Button = null
var btn_save_as: Button = null
var btn_export_json: Button = null
var btn_import_json: Button = null

# Toolbar Aggiunta Rapida Entità
var btn_add_star: Button = null
var btn_add_planet: Button = null
var btn_add_gas_giant: Button = null
var btn_add_moon: Button = null
var btn_add_station: Button = null
var btn_add_asteroid: Button = null
var btn_add_wreck: Button = null
var btn_add_patrol: Button = null
var btn_delete_selected: Button = null

# Layer Toggles
var chk_grid: CheckBox = null
var chk_orbits: CheckBox = null
var chk_shadows: CheckBox = null
var chk_labels: CheckBox = null
var chk_sec_ids: CheckBox = null

# Zoom & View
var zoom_slider: HSlider = null
var lbl_zoom: Label = null
var btn_reset_view: Button = null

# Inspector & Outliner
var outliner_tree: Tree = null
var prop_editor_vbox: VBoxContainer = null
var lbl_selected_title: Label = null

# Status Bar
var lbl_status_coords: Label = null
var lbl_status_selection: Label = null
var lbl_status_stats: Label = null
var lbl_status_msg: Label = null

# Dialogs
var file_dialog: FileDialog = null
var confirm_dialog: ConfirmationDialog = null
var _pending_file_action: String = ""

func _ready() -> void:
	custom_minimum_size = Vector2(850, 550)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	_load_initial_system()

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
	
	sys.add_or_update_body({
		"id": "STAR_SOL_PRIME",
		"name": "Helios Nova (Stella Primaria)",
		"type": "STAR",
		"coords": Vector3i(0, 0, 0),
		"radius_km": 696340.0,
		"mass_tons": 1.989e27,
		"luminosity": 1.0,
		"color": Color(1.0, 0.96, 0.9, 1.0),
		"occluding": false,
		"description": "Stella di sequenza principale."
	})
	sys.add_or_update_body({
		"id": "PLANET_VULCAN",
		"name": "Vulcanus",
		"type": "PLANET",
		"coords": Vector3i(1, 3, 0),
		"radius_km": 4800.0,
		"mass_tons": 3.3e20,
		"occluding": true,
		"description": "Pianeta lavico interno."
	})
	sys.add_or_update_body({
		"id": "PLANET_TERRA_NOVA",
		"name": "Terra Nova Prime",
		"type": "PLANET",
		"coords": Vector3i(4, 8, 0),
		"radius_km": 6371.0,
		"mass_tons": 5.97e21,
		"occluding": true,
		"description": "Mondo abitabile centrale."
	})
	sys.add_or_update_body({
		"id": "MOON_LUNA_SEC",
		"name": "Selene Secundus",
		"type": "MOON",
		"coords": Vector3i(4, 9, 0),
		"radius_km": 1737.0,
		"mass_tons": 7.35e19,
		"occluding": true,
		"description": "Luna mineraria."
	})
	sys.add_or_update_body({
		"id": "BELT_CERES",
		"name": "Fascia Asteroidi Interna",
		"type": "ASTEROID_FIELD",
		"coords": Vector3i(3, 10, 0),
		"radius_km": 25000.0,
		"mass_tons": 1.5e18,
		"occluding": false,
		"description": "Denso campo di detriti."
	})
	sys.add_or_update_body({
		"id": "STATION_VALKYRIE",
		"name": "Stazione Spaziale Valkyrie",
		"type": "STATION",
		"coords": Vector3i(4, 12, 0),
		"radius_km": 15.0,
		"mass_tons": 8.5e10,
		"occluding": false,
		"description": "Avamposto orbitale."
	})
	sys.add_or_update_body({
		"id": "GAS_GIANT_KRONOS",
		"name": "Kronos Titan",
		"type": "GAS_GIANT",
		"coords": Vector3i(8, 20, 0),
		"radius_km": 69911.0,
		"mass_tons": 1.89e24,
		"occluding": true,
		"description": "Gigante gassoso anellato."
	})

func load_star_system(sys: StarSystemData, path: String = "") -> void:
	current_system = sys
	current_file_path = path
	
	if canvas:
		canvas.system_data = current_system
		canvas.reset_view()
		
	if lbl_current_file:
		lbl_current_file.text = path.get_file() if not path.is_empty() else "Nuovo Sistema Stellare (non salvato)"
		lbl_current_file.tooltip_text = path
		
	_refresh_outliner()
	_update_stats_label()
	_show_system_global_props()
	_set_status_msg("Sistema stellare caricato con successo.")

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()
		
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_vbox)
	
	# Toolbar File & Operazioni
	var top_toolbar := _create_top_toolbar()
	main_vbox.add_child(top_toolbar)
	
	# Toolbar Aggiunta Rapida Entità Celesti & Toggles
	var creation_toolbar := _create_creation_toolbar()
	main_vbox.add_child(creation_toolbar)
	
	# Area Centrale (Outliner | Canvas Grafico | Inspector Proprietà)
	var hsplit_main := HSplitContainer.new()
	hsplit_main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit_main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(hsplit_main)
	
	# Outliner Sinistro
	var left_panel := _create_left_outliner()
	hsplit_main.add_child(left_panel)
	
	# Split Centrale-Destro
	var hsplit_right := HSplitContainer.new()
	hsplit_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit_right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit_main.add_child(hsplit_right)
	
	# Canvas Centrale
	var canvas_container := _create_canvas_container()
	hsplit_right.add_child(canvas_container)
	
	# Inspector Destro
	var right_panel := _create_right_inspector()
	hsplit_right.add_child(right_panel)
	
	# Status Bar Inferiore
	var status_bar := _create_status_bar()
	main_vbox.add_child(status_bar)
	
	# Setup Dialogs
	_setup_dialogs()

func _create_top_toolbar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 32)
	
	btn_new = Button.new()
	btn_new.text = "Nuovo"
	btn_new.tooltip_text = "Crea un nuovo sistema stellare vuoto"
	btn_new.pressed.connect(_on_btn_new_pressed)
	bar.add_child(btn_new)
	
	btn_open = Button.new()
	btn_open.text = "Apri..."
	btn_open.tooltip_text = "Carica una risorsa .tres/.res di sistema stellare"
	btn_open.pressed.connect(_on_btn_open_pressed)
	bar.add_child(btn_open)
	
	btn_save = Button.new()
	btn_save.text = "Salva"
	btn_save.tooltip_text = "Salva il sistema stellare corrente"
	btn_save.pressed.connect(_on_btn_save_pressed)
	bar.add_child(btn_save)
	
	btn_save_as = Button.new()
	btn_save_as.text = "Salva con nome..."
	btn_save_as.tooltip_text = "Salva con un nuovo nome di file"
	btn_save_as.pressed.connect(_on_btn_save_as_pressed)
	bar.add_child(btn_save_as)
	
	bar.add_child(VSeparator.new())
	
	btn_export_json = Button.new()
	btn_export_json.text = "Esporta JSON"
	btn_export_json.tooltip_text = "Esporta la configurazione del sistema in formato JSON"
	btn_export_json.pressed.connect(_on_btn_export_json_pressed)
	bar.add_child(btn_export_json)
	
	btn_import_json = Button.new()
	btn_import_json.text = "Importa JSON"
	btn_import_json.tooltip_text = "Importa la configurazione da file JSON"
	btn_import_json.pressed.connect(_on_btn_import_json_pressed)
	bar.add_child(btn_import_json)
	
	bar.add_child(VSeparator.new())
	
	lbl_current_file = Label.new()
	lbl_current_file.text = "Helios Nova System"
	lbl_current_file.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(lbl_current_file)
	
	return bar

func _create_creation_toolbar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 30)
	
	var lbl_add := Label.new()
	lbl_add.text = "Aggiungi:"
	bar.add_child(lbl_add)
	
	btn_add_star = Button.new()
	btn_add_star.text = "+ Stella"
	btn_add_star.pressed.connect(func(): _add_celestial_body("STAR"))
	bar.add_child(btn_add_star)
	
	btn_add_planet = Button.new()
	btn_add_planet.text = "+ Pianeta"
	btn_add_planet.pressed.connect(func(): _add_celestial_body("PLANET"))
	bar.add_child(btn_add_planet)
	
	btn_add_gas_giant = Button.new()
	btn_add_gas_giant.text = "+ Gigante Gassoso"
	btn_add_gas_giant.pressed.connect(func(): _add_celestial_body("GAS_GIANT"))
	bar.add_child(btn_add_gas_giant)
	
	btn_add_moon = Button.new()
	btn_add_moon.text = "+ Luna"
	btn_add_moon.pressed.connect(func(): _add_celestial_body("MOON"))
	bar.add_child(btn_add_moon)
	
	btn_add_station = Button.new()
	btn_add_station.text = "+ Stazione"
	btn_add_station.pressed.connect(func(): _add_celestial_body("STATION"))
	bar.add_child(btn_add_station)
	
	btn_add_asteroid = Button.new()
	btn_add_asteroid.text = "+ Asteroidi"
	btn_add_asteroid.pressed.connect(func(): _add_celestial_body("ASTEROID_FIELD"))
	bar.add_child(btn_add_asteroid)
	
	btn_add_wreck = Button.new()
	btn_add_wreck.text = "+ Relitto"
	btn_add_wreck.pressed.connect(func(): _add_celestial_body("WRECK"))
	bar.add_child(btn_add_wreck)
	
	btn_add_patrol = Button.new()
	btn_add_patrol.text = "+ Pattuglia"
	btn_add_patrol.pressed.connect(func(): _add_celestial_body("PATROL"))
	bar.add_child(btn_add_patrol)
	
	bar.add_child(VSeparator.new())
	
	btn_delete_selected = Button.new()
	btn_delete_selected.text = "Elimina"
	btn_delete_selected.tooltip_text = "Elimina l'entità celeste selezionata"
	btn_delete_selected.pressed.connect(_on_btn_delete_selected_pressed)
	bar.add_child(btn_delete_selected)
	
	bar.add_child(VSeparator.new())
	
	# Layer checkboxes
	chk_grid = CheckBox.new()
	chk_grid.text = "Griglia"
	chk_grid.button_pressed = true
	chk_grid.toggled.connect(func(v): canvas.show_grid = v; canvas.queue_redraw())
	bar.add_child(chk_grid)
	
	chk_orbits = CheckBox.new()
	chk_orbits.text = "Orbite"
	chk_orbits.button_pressed = true
	chk_orbits.toggled.connect(func(v): canvas.show_orbits = v; canvas.queue_redraw())
	bar.add_child(chk_orbits)
	
	chk_shadows = CheckBox.new()
	chk_shadows.text = "Coni Ombra"
	chk_shadows.button_pressed = true
	chk_shadows.toggled.connect(func(v): canvas.show_shadow_cones = v; canvas.queue_redraw())
	bar.add_child(chk_shadows)
	
	chk_labels = CheckBox.new()
	chk_labels.text = "Etichette"
	chk_labels.button_pressed = true
	chk_labels.toggled.connect(func(v): canvas.show_labels = v; canvas.queue_redraw())
	bar.add_child(chk_labels)
	
	return bar

func _create_left_outliner() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(220, 0)
	
	var lbl := Label.new()
	lbl.text = "Corpi Celesti & Macro-Entità"
	vbox.add_child(lbl)
	
	outliner_tree = Tree.new()
	outliner_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outliner_tree.hide_root = true
	outliner_tree.item_selected.connect(_on_outliner_item_selected)
	vbox.add_child(outliner_tree)
	
	return vbox

func _create_canvas_container() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Barra controlli zoom e reset
	var view_bar := HBoxContainer.new()
	btn_reset_view = Button.new()
	btn_reset_view.text = "Centra Vista"
	btn_reset_view.pressed.connect(func(): if canvas: canvas.reset_view())
	view_bar.add_child(btn_reset_view)
	
	var lbl_z := Label.new()
	lbl_z.text = " Zoom:"
	view_bar.add_child(lbl_z)
	
	zoom_slider = HSlider.new()
	zoom_slider.min_value = 0.2
	zoom_slider.max_value = 3.0
	zoom_slider.step = 0.05
	zoom_slider.value = 1.0
	zoom_slider.custom_minimum_size = Vector2(100, 0)
	zoom_slider.value_changed.connect(func(val): if canvas: canvas.zoom_level = val; canvas.queue_redraw(); _update_zoom_label())
	view_bar.add_child(zoom_slider)
	
	lbl_zoom = Label.new()
	lbl_zoom.text = "100%"
	view_bar.add_child(lbl_zoom)
	
	vbox.add_child(view_bar)
	
	# Canvas 2D
	canvas = StarSystemCanvas.new()
	canvas.entity_selected.connect(_on_canvas_entity_selected)
	canvas.sector_clicked.connect(_on_canvas_sector_clicked)
	canvas.entity_moved.connect(_on_canvas_entity_moved)
	canvas.cursor_coords_changed.connect(_on_canvas_cursor_coords_changed)
	vbox.add_child(canvas)
	
	return vbox

func _create_right_inspector() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(260, 0)
	
	lbl_selected_title = Label.new()
	lbl_selected_title.text = "Proprietà Sistema"
	vbox.add_child(lbl_selected_title)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	
	prop_editor_vbox = VBoxContainer.new()
	prop_editor_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(prop_editor_vbox)
	
	return vbox

func _create_status_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 24)
	
	lbl_status_coords = Label.new()
	lbl_status_coords.text = "Cursore: [0, 0, 0] (SEC-00-00)"
	bar.add_child(lbl_status_coords)
	
	bar.add_child(VSeparator.new())
	
	lbl_status_selection = Label.new()
	lbl_status_selection.text = "Nessuna selezione"
	lbl_status_selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(lbl_status_selection)
	
	bar.add_child(VSeparator.new())
	
	lbl_status_stats = Label.new()
	lbl_status_stats.text = "Entità: 0"
	bar.add_child(lbl_status_stats)
	
	bar.add_child(VSeparator.new())
	
	lbl_status_msg = Label.new()
	lbl_status_msg.text = "Pronto"
	bar.add_child(lbl_status_msg)
	
	return bar

func _setup_dialogs() -> void:
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.file_selected.connect(_on_file_dialog_selected)
	add_child(file_dialog)
	
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
	add_child(confirm_dialog)

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
		var b_type: String = body.get("type", "PLANET").to_upper()
		var b_name: String = body.get("name", "Entità")
		var b_id: String = body.get("id", "")
		var c: Vector3i = body.get("coords", Vector3i.ZERO)
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
	
	_add_text_field("ID Sistema:", current_system.system_id, func(v): current_system.system_id = v)
	_add_text_field("Nome Sistema:", current_system.system_name, func(v): current_system.system_name = v; _refresh_outliner())
	_add_text_field("Descrizione:", current_system.description, func(v): current_system.description = v)
	
	_add_separator()
	_add_heading("Parametri Stella Primaria")
	_add_text_field("Nome Stella:", current_system.primary_star_name, func(v): current_system.primary_star_name = v)
	_add_vector3i_field("Coordinate Stella:", current_system.primary_star_coords, func(v): current_system.primary_star_coords = v; if canvas: canvas.queue_redraw())
	_add_float_field("Energia Base:", current_system.primary_star_energy, func(v): current_system.primary_star_energy = v)
	_add_float_field("Raggio (km):", current_system.primary_star_radius_km, func(v): current_system.primary_star_radius_km = v)
	_add_color_field("Colore Luce:", current_system.primary_star_color, func(v): current_system.primary_star_color = v; if canvas: canvas.queue_redraw())

func _show_body_props(body: Dictionary) -> void:
	if prop_editor_vbox == null:
		return
	_clear_prop_editor()
	var b_id: String = body.get("id", "")
	var b_name: String = body.get("name", "Entità")
	lbl_selected_title.text = "Modifica: %s" % b_name
	
	_add_text_field("ID Entità:", b_id, func(v): body["id"] = v; _refresh_outliner())
	_add_text_field("Nome:", b_name, func(v): body["name"] = v; _refresh_outliner(); if canvas: canvas.queue_redraw())
	
	var types: Array[String] = ["STAR", "PLANET", "GAS_GIANT", "MOON", "STATION", "ASTEROID_FIELD", "WRECK", "PATROL"]
	_add_option_field("Tipo:", types, body.get("type", "PLANET"), func(v): body["type"] = v; _refresh_outliner(); if canvas: canvas.queue_redraw())
	
	var coords: Vector3i = body.get("coords", Vector3i.ZERO)
	_add_vector3i_field("Coordinate Griglia:", coords, func(v): body["coords"] = v; if canvas: canvas.queue_redraw(); _refresh_outliner())
	
	_add_float_field("Raggio (km):", float(body.get("radius_km", 5000.0)), func(v): body["radius_km"] = v; if canvas: canvas.queue_redraw())
	_add_float_field("Massa (Tonnellate):", float(body.get("mass_tons", 1.0e20)), func(v): body["mass_tons"] = v)
	_add_bool_field("Proietta Cono d'Ombra:", bool(body.get("occluding", false)), func(v): body["occluding"] = v; if canvas: canvas.queue_redraw())
	_add_text_field("Descrizione:", body.get("description", ""), func(v): body["description"] = v)
	
	if body.has("color"):
		var col: Color = body.get("color", Color.WHITE)
		_add_color_field("Colore Display:", col, func(v): body["color"] = v; if canvas: canvas.queue_redraw())
		
	var btn_del := Button.new()
	btn_del.text = "🗑️ Rimuovi Entità"
	btn_del.pressed.connect(func(): _delete_body(b_id))
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

func _add_text_field(label: String, val: String, callback: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(90, 0)
	h.add_child(l)
	var le := LineEdit.new()
	le.text = val
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_changed.connect(callback)
	h.add_child(le)
	prop_editor_vbox.add_child(h)

func _add_float_field(label: String, val: float, callback: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(90, 0)
	h.add_child(l)
	var sb := SpinBox.new()
	sb.min_value = 0.0
	sb.max_value = 1.0e30
	sb.step = 0.1
	sb.value = val
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sb.value_changed.connect(func(v): callback.call(v))
	h.add_child(sb)
	prop_editor_vbox.add_child(h)

func _add_vector3i_field(label: String, val: Vector3i, callback: Callable) -> void:
	var vbox := VBoxContainer.new()
	var l := Label.new()
	l.text = label
	vbox.add_child(l)
	var h := HBoxContainer.new()
	
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
		callback.call(vec)
		
	sb_x.value_changed.connect(func(_v): update_vec.call())
	sb_y.value_changed.connect(func(_v): update_vec.call())
	sb_z.value_changed.connect(func(_v): update_vec.call())
	
	vbox.add_child(h)
	prop_editor_vbox.add_child(vbox)

func _add_bool_field(label: String, val: bool, callback: Callable) -> void:
	var cb := CheckBox.new()
	cb.text = label
	cb.button_pressed = val
	cb.toggled.connect(callback)
	prop_editor_vbox.add_child(cb)

func _add_color_field(label: String, val: Color, callback: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(90, 0)
	h.add_child(l)
	var cp := ColorPickerButton.new()
	cp.color = val
	cp.custom_minimum_size = Vector2(50, 24)
	cp.color_changed.connect(callback)
	h.add_child(cp)
	prop_editor_vbox.add_child(h)

func _add_option_field(label: String, options: Array[String], current_val: String, callback: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(90, 0)
	h.add_child(l)
	var opt := OptionButton.new()
	for i in range(options.size()):
		opt.add_item(options[i], i)
		if options[i] == current_val:
			opt.selected = i
	opt.item_selected.connect(func(idx): callback.call(options[idx]))
	h.add_child(opt)
	prop_editor_vbox.add_child(h)

# =============================================================================
# OPERAZIONI SU CORPI CELESTI
# =============================================================================

func _add_celestial_body(type: String) -> void:
	if current_system == null:
		return
	var count := current_system.celestial_bodies.size() + 1
	var new_body := {
		"id": "BODY_%s_%d" % [type, count],
		"name": "Nuovo %s %d" % [type.capitalize(), count],
		"type": type,
		"coords": Vector3i(randi_range(-8, 8), randi_range(-8, 8), 0),
		"radius_km": 5000.0,
		"mass_tons": 1.0e20,
		"occluding": (type in ["PLANET", "GAS_GIANT", "MOON"]),
		"description": "Entità celeste aggiunta tramite Star System Editor."
	}
	
	if type == "STAR":
		new_body["radius_km"] = 500000.0
		new_body["mass_tons"] = 1.0e27
		new_body["occluding"] = false
		new_body["color"] = Color(1.0, 0.9, 0.4, 1.0)
	elif type == "GAS_GIANT":
		new_body["radius_km"] = 60000.0
		new_body["mass_tons"] = 1.5e24
		new_body["occluding"] = true
	elif type == "STATION":
		new_body["radius_km"] = 10.0
		new_body["mass_tons"] = 5.0e9
		new_body["occluding"] = false
		
	current_system.add_or_update_body(new_body)
	if canvas:
		canvas.selected_body_id = new_body["id"]
		canvas.queue_redraw()
	_refresh_outliner()
	_update_stats_label()
	_show_body_props(new_body)
	_set_status_msg("Aggiunta entità '%s'." % new_body["name"])

func _delete_body(body_id: String) -> void:
	if current_system == null or body_id.is_empty():
		return
	if current_system.remove_body(body_id):
		if canvas and canvas.selected_body_id == body_id:
			canvas.selected_body_id = ""
			canvas.queue_redraw()
		_refresh_outliner()
		_update_stats_label()
		_show_system_global_props()
		_set_status_msg("Entità rimossa.")

func _on_btn_delete_selected_pressed() -> void:
	if canvas and not canvas.selected_body_id.is_empty():
		_delete_body(canvas.selected_body_id)

# =============================================================================
# EVENTI SELEZIONE & INTERAZIONE CANVAS
# =============================================================================

func _on_canvas_entity_selected(body: Dictionary) -> void:
	lbl_status_selection.text = "Selezionato: %s (%s)" % [body.get("name", ""), body.get("id", "")]
	_show_body_props(body)
	_refresh_outliner()

func _on_canvas_sector_clicked(coords: Vector3i) -> void:
	lbl_status_selection.text = "Settore cliccato: %s" % SectorData.format_coords_to_id(coords)
	if canvas:
		canvas.selected_body_id = ""
		canvas.queue_redraw()
	_show_system_global_props()
	_refresh_outliner()

func _on_canvas_entity_moved(body_id: String, new_coords: Vector3i) -> void:
	if current_system == null:
		return
	var b := current_system.get_body(body_id)
	if not b.is_empty():
		b["coords"] = new_coords
		_show_body_props(b)
		_refresh_outliner()
		_set_status_msg("Entità '%s' spostata in %s." % [b.get("name", ""), SectorData.format_coords_to_id(new_coords)])

func _on_canvas_cursor_coords_changed(coords: Vector3i) -> void:
	lbl_status_coords.text = "Cursore: [%d, %d, %d] (%s)" % [coords.x, coords.y, coords.z, SectorData.format_coords_to_id(coords)]

func _on_outliner_item_selected() -> void:
	var it := outliner_tree.get_selected()
	if it == null:
		return
	var meta = it.get_metadata(0)
	if meta is Dictionary:
		var type: String = meta.get("type", "")
		if type == "SYSTEM":
			if canvas:
				canvas.selected_body_id = ""
				canvas.queue_redraw()
			_show_system_global_props()
		elif type == "BODY":
			var b_id: String = meta.get("id", "")
			if canvas:
				canvas.selected_body_id = b_id
				canvas.queue_redraw()
			var b_data := current_system.get_body(b_id)
			if not b_data.is_empty():
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
