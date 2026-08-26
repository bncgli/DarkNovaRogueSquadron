@tool
class_name ShipSublayerEditor
extends Control

## Editor visivo per i Sublayer / Blueprint della nave in GodotOS.
## Funziona sia come pannello integrato nell'Editor di Godot sia come applicazione standalone.

const DEFAULT_BLUEPRINT_PATH := "res://Outside/ShipSublayer/default_ship_blueprint.tres"

var current_blueprint: ShipBlueprint = null
var current_file_path: String = DEFAULT_BLUEPRINT_PATH

# Riferimenti UI interni
var canvas: ShipBlueprintCanvas = null
var tool_btn_group: ButtonGroup = ButtonGroup.new()

# Toolbar Controlli
var lbl_current_file: Label = null
var btn_select: Button = null
var btn_add_room: Button = null
var btn_add_duct: Button = null
var btn_add_device: Button = null
var btn_add_junction: Button = null
var btn_add_damage: Button = null
var btn_delete: Button = null

var chk_layer_rooms: CheckBox = null
var chk_layer_ducts: CheckBox = null
var chk_layer_power: CheckBox = null
var chk_layer_damages: CheckBox = null
var chk_layer_spawn: CheckBox = null
var chk_layer_grid: CheckBox = null
var chk_layer_labels: CheckBox = null

var chk_snap: CheckBox = null
var opt_snap_size: OptionButton = null
var zoom_slider: HSlider = null
var lbl_zoom: Label = null

# Inspector & Outliner
var outliner_tree: Tree = null
var prop_container: VBoxContainer = null
var lbl_selected_title: Label = null
var prop_editor_vbox: VBoxContainer = null

# Status Bar
var lbl_status_coords: Label = null
var lbl_status_selection: Label = null
var lbl_status_stats: Label = null
var lbl_status_msg: Label = null

# Dialogs
var file_dialog: FileDialog = null
var confirm_dialog: ConfirmationDialog = null
var _pending_file_action: String = "" # "open_tres", "save_tres", "export_json", "import_json"

func _ready() -> void:
	custom_minimum_size = Vector2(800, 500)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	_load_initial_blueprint()

func _load_initial_blueprint() -> void:
	if ResourceLoader.exists(DEFAULT_BLUEPRINT_PATH):
		var res := ResourceLoader.load(DEFAULT_BLUEPRINT_PATH)
		if res is ShipBlueprint:
			load_blueprint(res as ShipBlueprint, DEFAULT_BLUEPRINT_PATH)
			return
	var bp := ShipBlueprint.new()
	bp.create_default_ship()
	load_blueprint(bp, DEFAULT_BLUEPRINT_PATH)

func load_blueprint(bp: ShipBlueprint, path: String = "") -> void:
	if current_blueprint and current_blueprint.blueprint_changed.is_connected(_on_blueprint_changed):
		current_blueprint.blueprint_changed.disconnect(_on_blueprint_changed)
		
	current_blueprint = bp
	current_file_path = path
	
	if current_blueprint:
		if not current_blueprint.blueprint_changed.is_connected(_on_blueprint_changed):
			current_blueprint.blueprint_changed.connect(_on_blueprint_changed)
			
	if canvas:
		canvas.blueprint = current_blueprint
		canvas.reset_view()
		
	if lbl_current_file:
		lbl_current_file.text = path.get_file() if not path.is_empty() else "Nuova Blueprint (non salvata)"
		lbl_current_file.tooltip_text = path
		
	_refresh_outliner()
	_update_stats_label()
	_show_blueprint_metadata_props()
	_set_status_msg("Blueprint caricata con successo.")

func _on_blueprint_changed() -> void:
	if canvas:
		canvas.queue_redraw()
	_refresh_outliner()
	_update_stats_label()

func _build_ui() -> void:
	# Pulisce figli preesistenti
	for c in get_children():
		c.queue_free()
		
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_vbox)
	
	# 1. TOP TOOLBAR
	var toolbar := _create_toolbar()
	main_vbox.add_child(toolbar)
	
	# 2. MAIN SPLIT (Canvas a sinistra, Inspector/Outliner a destra)
	var hsplit := HSplitContainer.new()
	hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.split_offset = 640
	main_vbox.add_child(hsplit)
	
	# Canvas Viewport
	var canvas_panel := PanelContainer.new()
	canvas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.add_child(canvas_panel)
	
	canvas = ShipBlueprintCanvas.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.element_selected.connect(_on_canvas_element_selected)
	canvas.element_modified.connect(_on_canvas_element_modified)
	canvas.cursor_coords_changed.connect(_on_canvas_cursor_coords_changed)
	canvas_panel.add_child(canvas)
	
	# Right Panel (TabContainer per Inspector e Outliner)
	var right_panel := _create_right_panel()
	hsplit.add_child(right_panel)
	
	# 3. BOTTOM STATUS BAR
	var status_bar := _create_status_bar()
	main_vbox.add_child(status_bar)
	
	# 4. DIALOGS
	_create_dialogs()

func _create_toolbar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 36)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	bar.add_child(hbox)
	
	# Menu File / Azioni Rapide
	var btn_new := Button.new()
	btn_new.text = "Nuovo"
	btn_new.pressed.connect(_on_btn_new_pressed)
	hbox.add_child(btn_new)
	
	var btn_open := Button.new()
	btn_open.text = "Apri .tres"
	btn_open.pressed.connect(_on_btn_open_tres_pressed)
	hbox.add_child(btn_open)
	
	var btn_save := Button.new()
	btn_save.text = "Salva"
	btn_save.pressed.connect(_on_btn_save_tres_pressed)
	hbox.add_child(btn_save)

	var btn_save_as := Button.new()
	btn_save_as.text = "Salva come..."
	btn_save_as.pressed.connect(_on_btn_save_as_tres_pressed)
	hbox.add_child(btn_save_as)
	
	var btn_json_export := Button.new()
	btn_json_export.text = "Exp JSON"
	btn_json_export.pressed.connect(_on_btn_export_json_pressed)
	hbox.add_child(btn_json_export)

	var btn_json_import := Button.new()
	btn_json_import.text = "Imp JSON"
	btn_json_import.pressed.connect(_on_btn_import_json_pressed)
	hbox.add_child(btn_json_import)
	
	var btn_reset_def := Button.new()
	btn_reset_def.text = "Reset Default"
	btn_reset_def.pressed.connect(_on_btn_reset_default_pressed)
	hbox.add_child(btn_reset_def)
	
	hbox.add_child(VSeparator.new())
	
	# Strumenti di modifica (ToolButtons)
	btn_select = _create_tool_button("🖐️ Sposta", ShipBlueprintCanvas.ToolMode.SELECT, true)
	hbox.add_child(btn_select)
	
	btn_add_room = _create_tool_button("🔲 Stanza", ShipBlueprintCanvas.ToolMode.ADD_ROOM, false)
	hbox.add_child(btn_add_room)
	
	btn_add_duct = _create_tool_button("🔧 Condotto", ShipBlueprintCanvas.ToolMode.ADD_DUCT, false)
	hbox.add_child(btn_add_duct)
	
	btn_add_device = _create_tool_button("⚡ Dispositivo", ShipBlueprintCanvas.ToolMode.ADD_DEVICE, false)
	hbox.add_child(btn_add_device)
	
	btn_add_junction = _create_tool_button("🟡 Snodo", ShipBlueprintCanvas.ToolMode.ADD_JUNCTION, false)
	hbox.add_child(btn_add_junction)
	
	btn_add_damage = _create_tool_button("💥 Danno", ShipBlueprintCanvas.ToolMode.ADD_DAMAGE, false)
	hbox.add_child(btn_add_damage)
	
	btn_delete = _create_tool_button("🗑️ Elimina", ShipBlueprintCanvas.ToolMode.DELETE, false)
	hbox.add_child(btn_delete)
	
	hbox.add_child(VSeparator.new())
	
	# Layer Toggles
	var lbl_layers := Label.new()
	lbl_layers.text = "Layer:"
	hbox.add_child(lbl_layers)
	
	chk_layer_rooms = _create_layer_check("Stanze", true, func(v): canvas.show_rooms = v)
	hbox.add_child(chk_layer_rooms)
	
	chk_layer_ducts = _create_layer_check("Condotti", true, func(v): canvas.show_ducts = v)
	hbox.add_child(chk_layer_ducts)
	
	chk_layer_power = _create_layer_check("Rete", true, func(v): canvas.show_power_grid = v)
	hbox.add_child(chk_layer_power)
	
	chk_layer_damages = _create_layer_check("Danni", true, func(v): canvas.show_damages = v)
	hbox.add_child(chk_layer_damages)
	
	chk_layer_spawn = _create_layer_check("Spawn", true, func(v): canvas.show_spawn = v)
	hbox.add_child(chk_layer_spawn)
	
	chk_layer_grid = _create_layer_check("Griglia", true, func(v): canvas.show_grid = v)
	hbox.add_child(chk_layer_grid)
	
	chk_layer_labels = _create_layer_check("Testo", true, func(v): canvas.show_labels = v)
	hbox.add_child(chk_layer_labels)
	
	hbox.add_child(VSeparator.new())
	
	# Snap
	chk_snap = CheckBox.new()
	chk_snap.text = "Snap"
	chk_snap.button_pressed = true
	chk_snap.toggled.connect(func(v: bool): canvas.snap_enabled = v)
	hbox.add_child(chk_snap)
	
	opt_snap_size = OptionButton.new()
	opt_snap_size.add_item("5px", 0)
	opt_snap_size.add_item("10px", 1)
	opt_snap_size.add_item("20px", 2)
	opt_snap_size.add_item("50px", 3)
	opt_snap_size.select(1) # 10px default
	opt_snap_size.item_selected.connect(_on_snap_size_selected)
	hbox.add_child(opt_snap_size)
	
	hbox.add_child(VSeparator.new())
	
	# Zoom & Reset View
	var btn_zoom_out := Button.new()
	btn_zoom_out.text = "－"
	btn_zoom_out.pressed.connect(func(): canvas.set_zoom(canvas.zoom_level / 1.25))
	hbox.add_child(btn_zoom_out)
	
	var btn_zoom_in := Button.new()
	btn_zoom_in.text = "＋"
	btn_zoom_in.pressed.connect(func(): canvas.set_zoom(canvas.zoom_level * 1.25))
	hbox.add_child(btn_zoom_in)
	
	var btn_reset_view := Button.new()
	btn_reset_view.text = "Centra"
	btn_reset_view.pressed.connect(func(): canvas.reset_view())
	hbox.add_child(btn_reset_view)
	
	lbl_current_file = Label.new()
	lbl_current_file.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_current_file.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_current_file.text = "default_ship_blueprint.tres"
	hbox.add_child(lbl_current_file)
	
	return bar

func _create_tool_button(btn_text: String, tool_mode: int, is_default: bool) -> Button:
	var btn := Button.new()
	btn.text = btn_text
	btn.toggle_mode = true
	btn.button_group = tool_btn_group
	btn.button_pressed = is_default
	btn.pressed.connect(func(): canvas.current_tool = tool_mode)
	return btn

func _create_layer_check(lbl_text: String, is_active: bool, callback: Callable) -> CheckBox:
	var chk := CheckBox.new()
	chk.text = lbl_text
	chk.button_pressed = is_active
	chk.toggled.connect(callback)
	return chk

func _create_right_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(tabs)
	
	# TAB 1: Inspector Proprietà
	var scroll_insp := ScrollContainer.new()
	scroll_insp.name = "Inspector"
	scroll_insp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_insp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(scroll_insp)
	
	prop_container = VBoxContainer.new()
	prop_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prop_container.add_theme_constant_override("separation", 6)
	scroll_insp.add_child(prop_container)
	
	lbl_selected_title = Label.new()
	lbl_selected_title.text = "Nessun elemento selezionato"
	lbl_selected_title.add_theme_font_size_override("font_size", 14)
	prop_container.add_child(lbl_selected_title)
	
	prop_editor_vbox = VBoxContainer.new()
	prop_editor_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prop_container.add_child(prop_editor_vbox)
	
	# TAB 2: Gerarchia / Outliner
	var vbox_tree := VBoxContainer.new()
	vbox_tree.name = "Gerarchia Sublayer"
	vbox_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(vbox_tree)
	
	outliner_tree = Tree.new()
	outliner_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outliner_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outliner_tree.hide_root = true
	outliner_tree.item_selected.connect(_on_outliner_tree_item_selected)
	vbox_tree.add_child(outliner_tree)
	
	return panel

func _create_status_bar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 24)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	bar.add_child(hbox)
	
	lbl_status_coords = Label.new()
	lbl_status_coords.text = "X: 0 | Y: 0"
	hbox.add_child(lbl_status_coords)
	
	hbox.add_child(VSeparator.new())
	
	lbl_status_selection = Label.new()
	lbl_status_selection.text = "Nessuna selezione"
	hbox.add_child(lbl_status_selection)
	
	hbox.add_child(VSeparator.new())
	
	lbl_status_stats = Label.new()
	lbl_status_stats.text = "10 Stanze | 14 Condotti | 11 Dispositivi | 7 Snodi | 8 Danni"
	hbox.add_child(lbl_status_stats)
	
	lbl_status_msg = Label.new()
	lbl_status_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_status_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_status_msg.text = "Pronto."
	hbox.add_child(lbl_status_msg)
	
	return bar

func _create_dialogs() -> void:
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.file_selected.connect(_on_file_dialog_file_selected)
	add_child(file_dialog)
	
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Ripristinare la blueprint ai valori di fabbrica Dark Nova Corvette?"
	confirm_dialog.confirmed.connect(_on_confirm_reset_default)
	add_child(confirm_dialog)

func _set_status_msg(msg: String) -> void:
	if lbl_status_msg:
		lbl_status_msg.text = msg

func _on_snap_size_selected(index: int) -> void:
	match index:
		0: canvas.snap_grid_size = 5.0
		1: canvas.snap_grid_size = 10.0
		2: canvas.snap_grid_size = 20.0
		3: canvas.snap_grid_size = 50.0

func _on_canvas_cursor_coords_changed(world_pos: Vector2) -> void:
	if lbl_status_coords:
		lbl_status_coords.text = "X: %d | Y: %d" % [int(world_pos.x), int(world_pos.y)]

func _on_canvas_element_selected(elem_type: String, elem_id: String, elem_data: Dictionary) -> void:
	if lbl_status_selection:
		lbl_status_selection.text = "Selezione: [%s] %s" % [elem_type.to_upper(), elem_id] if not elem_type.is_empty() else "Nessuna selezione"
	_populate_property_editor(elem_type, elem_id, elem_data)

func _on_canvas_element_modified(elem_type: String, elem_id: String, elem_data: Dictionary) -> void:
	_populate_property_editor(elem_type, elem_id, elem_data)
	_refresh_outliner()
	_update_stats_label()

func _update_stats_label() -> void:
	if not current_blueprint or not lbl_status_stats:
		return
	lbl_status_stats.text = "%d Stanze | %d Condotti | %d Dispositivi | %d Snodi | %d Danni" % [
		current_blueprint.rooms.size(),
		current_blueprint.ducts.size(),
		current_blueprint.devices.size(),
		current_blueprint.junctions.size(),
		current_blueprint.damages.size()
	]

# --- PROPERTY INSPECTOR BUILDER ---

func _clear_prop_editor() -> void:
	for c in prop_editor_vbox.get_children():
		c.queue_free()

func _show_blueprint_metadata_props() -> void:
	_clear_prop_editor()
	if not current_blueprint:
		return
	lbl_selected_title.text = "Blueprint Astronave"
	
	_add_string_field("ID Nave:", current_blueprint.ship_id, func(v): current_blueprint.ship_id = v)
	_add_string_field("Nome Nave:", current_blueprint.ship_name, func(v): current_blueprint.ship_name = v)
	_add_string_field("Classe Nave:", current_blueprint.ship_class, func(v): current_blueprint.ship_class = v)
	_add_vector2_field("Spawn Drone (X, Y):", current_blueprint.drone_spawn_pos, func(v): current_blueprint.drone_spawn_pos = v; canvas.queue_redraw())
	_add_float_field("Heading Drone (Gradi):", rad_to_deg(current_blueprint.drone_spawn_heading), func(v): current_blueprint.drone_spawn_heading = deg_to_rad(v); canvas.queue_redraw())

func _populate_property_editor(elem_type: String, elem_id: String, elem_data: Dictionary) -> void:
	_clear_prop_editor()
	if elem_type.is_empty():
		_show_blueprint_metadata_props()
		return

	lbl_selected_title.text = "[%s] %s" % [elem_type.to_upper(), elem_id]
	
	match elem_type:
		"room":
			var room := current_blueprint.get_room_by_id(elem_id)
			if room.is_empty():
				return
			_add_string_field("ID Stanza:", str(room.get("id", "")), func(v): room["id"] = v; current_blueprint.emit_changed())
			_add_string_field("Nome Settore:", str(room.get("name", "")), func(v): room["name"] = v; current_blueprint.emit_changed())
			_add_string_field("Categoria:", str(room.get("category", "command")), func(v): room["category"] = v; current_blueprint.emit_changed())
			
			var r_rect: Rect2 = room.get("rect", Rect2())
			_add_vector2_field("Posizione (X, Y):", r_rect.position, func(v): room["rect"] = Rect2(v, room["rect"].size); current_blueprint.emit_changed(); canvas.queue_redraw())
			_add_vector2_field("Dimensioni (W, H):", r_rect.size, func(v): room["rect"] = Rect2(room["rect"].position, v); current_blueprint.emit_changed(); canvas.queue_redraw())
			_add_color_field("Colore Sfondo:", room.get("color", Color.WHITE), func(c): room["color"] = c; current_blueprint.emit_changed(); canvas.queue_redraw())
			_add_color_field("Colore Bordo:", room.get("border_color", Color.CYAN), func(c): room["border_color"] = c; current_blueprint.emit_changed(); canvas.queue_redraw())

		"duct":
			var duct := current_blueprint.get_duct_by_id(elem_id)
			if duct.is_empty():
				return
			_add_string_field("ID Condotto:", str(duct.get("id", "")), func(v): duct["id"] = v; current_blueprint.emit_changed())
			_add_string_field("Nome Condotto:", str(duct.get("name", "")), func(v): duct["name"] = v; current_blueprint.emit_changed())
			_add_vector2_field("Da Punto (X, Y):", duct.get("from", Vector2.ZERO), func(v): duct["from"] = v; current_blueprint.emit_changed(); canvas.queue_redraw())
			_add_vector2_field("A Punto (X, Y):", duct.get("to", Vector2.ZERO), func(v): duct["to"] = v; current_blueprint.emit_changed(); canvas.queue_redraw())
			_add_float_field("Larghezza:", float(duct.get("width", 14.0)), func(v): duct["width"] = v; current_blueprint.emit_changed(); canvas.queue_redraw())
			_add_bool_field("Bloccato / Ostruito:", bool(duct.get("is_blocked", false)), func(v): duct["is_blocked"] = v; current_blueprint.emit_changed(); canvas.queue_redraw())

		"device":
			var dev := current_blueprint.get_device_by_id(elem_id)
			if dev.is_empty():
				return
			_add_string_field("ID Dispositivo:", str(dev.get("id", "")), func(v): dev["id"] = v; current_blueprint.emit_changed())
			_add_string_field("Nome:", str(dev.get("name", "")), func(v): dev["name"] = v; current_blueprint.emit_changed())
			_add_string_field("Settore:", str(dev.get("sector", "")), func(v): dev["sector"] = v; current_blueprint.emit_changed())
			_add_vector2_field("Posizione (X, Y):", dev.get("pos", Vector2.ZERO), func(v): dev["pos"] = v; current_blueprint.emit_changed(); canvas.queue_redraw())
			_add_bool_field("È Generatore:", bool(dev.get("is_generator", false)), func(v): dev["is_generator"] = v; current_blueprint.emit_changed(); canvas.queue_redraw())
			_add_float_field("Potenza (MW):", float(dev.get("power_mw", 100.0)), func(v): dev["power_mw"] = v; current_blueprint.emit_changed(); canvas.queue_redraw())
			_add_int_field("Numero Input:", int(dev.get("inputs_count", 1)), func(v): dev["inputs_count"] = v; current_blueprint.emit_changed())
			_add_string_field("Descrizione:", str(dev.get("desc", "")), func(v): dev["desc"] = v; current_blueprint.emit_changed())

		"junction":
			var junc := current_blueprint.get_junction_by_id(elem_id)
			if junc.is_empty():
				return
			_add_string_field("ID Snodo:", str(junc.get("id", "")), func(v): junc["id"] = v; current_blueprint.emit_changed())
			_add_string_field("Nome Snodo:", str(junc.get("name", "")), func(v): junc["name"] = v; current_blueprint.emit_changed())
			_add_vector2_field("Posizione (X, Y):", junc.get("pos", Vector2.ZERO), func(v): junc["pos"] = v; current_blueprint.emit_changed(); canvas.queue_redraw())
			_add_string_field("Fonte Input:", str(junc.get("input_source", "")), func(v): junc["input_source"] = v; current_blueprint.emit_changed())
			_add_int_field("Ramo Attivo:", int(junc.get("active_branch", 0)), func(v): junc["active_branch"] = v; current_blueprint.emit_changed(); canvas.queue_redraw())
			_add_branches_editor(junc)

		"damage":
			var dmg := current_blueprint.get_damage_by_id(elem_id)
			if dmg.is_empty():
				return
			_add_string_field("ID Danno:", str(dmg.get("id", "")), func(v): dmg["id"] = v; current_blueprint.emit_changed())
			_add_string_field("Tipo Danno:", str(dmg.get("type", "breach")), func(v): dmg["type"] = v; current_blueprint.emit_changed(); canvas.queue_redraw())
			_add_string_field("Nome:", str(dmg.get("name", "")), func(v): dmg["name"] = v; current_blueprint.emit_changed())
			_add_vector2_field("Posizione (X, Y):", dmg.get("pos", Vector2.ZERO), func(v): dmg["pos"] = v; current_blueprint.emit_changed(); canvas.queue_redraw())
			_add_string_field("Settore:", str(dmg.get("sector", "")), func(v): dmg["sector"] = v; current_blueprint.emit_changed())
			_add_float_field("Gravità (Severity):", float(dmg.get("severity", 5.0)), func(v): dmg["severity"] = v; current_blueprint.emit_changed(); canvas.queue_redraw())
			_add_float_field("Costo Riparazione:", float(dmg.get("repair_cost", 10.0)), func(v): dmg["repair_cost"] = v; current_blueprint.emit_changed())
			_add_string_field("Impatto Sistema:", str(dmg.get("system_impact", "")), func(v): dmg["system_impact"] = v; current_blueprint.emit_changed())
			_add_string_field("Descrizione:", str(dmg.get("desc", "")), func(v): dmg["desc"] = v; current_blueprint.emit_changed())

		"spawn":
			_add_vector2_field("Posizione Spawn Drone:", current_blueprint.drone_spawn_pos, func(v): current_blueprint.drone_spawn_pos = v; current_blueprint.emit_changed(); canvas.queue_redraw())
			_add_float_field("Heading Spawn (Gradi):", rad_to_deg(current_blueprint.drone_spawn_heading), func(v): current_blueprint.drone_spawn_heading = deg_to_rad(v); current_blueprint.emit_changed(); canvas.queue_redraw())

	# Pulsante per eliminare l'elemento
	var btn_del_this := Button.new()
	btn_del_this.text = "Elimina Elemento"
	btn_del_this.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	btn_del_this.pressed.connect(func(): canvas.delete_element(elem_type, elem_id))
	prop_editor_vbox.add_child(btn_del_this)

# Helper Campi UI
func _add_string_field(lbl: String, current_val: String, callback: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = lbl
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ed := LineEdit.new()
	ed.text = current_val
	ed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ed.text_changed.connect(callback)
	h.add_child(l)
	h.add_child(ed)
	prop_editor_vbox.add_child(h)

func _add_float_field(lbl: String, current_val: float, callback: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = lbl
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spin := SpinBox.new()
	spin.min_value = -9999.0
	spin.max_value = 9999.0
	spin.step = 0.5
	spin.value = current_val
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(func(v: float): callback.call(v))
	h.add_child(l)
	h.add_child(spin)
	prop_editor_vbox.add_child(h)

func _add_int_field(lbl: String, current_val: int, callback: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = lbl
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = 100
	spin.step = 1
	spin.value = current_val
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(func(v: float): callback.call(int(v)))
	h.add_child(l)
	h.add_child(spin)
	prop_editor_vbox.add_child(h)

func _add_bool_field(lbl: String, current_val: bool, callback: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = lbl
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chk := CheckBox.new()
	chk.button_pressed = current_val
	chk.toggled.connect(callback)
	h.add_child(l)
	h.add_child(chk)
	prop_editor_vbox.add_child(h)

func _add_vector2_field(lbl: String, current_val: Vector2, callback: Callable) -> void:
	var v_box := VBoxContainer.new()
	var l := Label.new()
	l.text = lbl
	v_box.add_child(l)
	
	var h := HBoxContainer.new()
	var spin_x := SpinBox.new()
	spin_x.min_value = -9999.0
	spin_x.max_value = 9999.0
	spin_x.step = 5.0
	spin_x.value = current_val.x
	spin_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var spin_y := SpinBox.new()
	spin_y.min_value = -9999.0
	spin_y.max_value = 9999.0
	spin_y.step = 5.0
	spin_y.value = current_val.y
	spin_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	spin_x.value_changed.connect(func(v: float): callback.call(Vector2(v, spin_y.value)))
	spin_y.value_changed.connect(func(v: float): callback.call(Vector2(spin_x.value, v)))
	
	h.add_child(spin_x)
	h.add_child(spin_y)
	v_box.add_child(h)
	prop_editor_vbox.add_child(v_box)

func _add_color_field(lbl: String, current_val: Color, callback: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = lbl
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cp := ColorPickerButton.new()
	cp.color = current_val
	cp.edit_alpha = true
	cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cp.color_changed.connect(callback)
	h.add_child(l)
	h.add_child(cp)
	prop_editor_vbox.add_child(h)

func _add_branches_editor(junc: Dictionary) -> void:
	var v_box := VBoxContainer.new()
	var l := Label.new()
	l.text = "Rami dello Snodo:"
	v_box.add_child(l)
	
	var branches: Array = junc.get("branches", [])
	for b_idx in range(branches.size()):
		var b: Dictionary = branches[b_idx]
		var b_box := PanelContainer.new()
		var b_vbox := VBoxContainer.new()
		b_box.add_child(b_vbox)
		
		var b_lbl := Label.new()
		b_lbl.text = "Ramo %d: %s" % [b_idx, str(b.get("name", "Ramo"))]
		b_vbox.add_child(b_lbl)
		
		var ed_name := LineEdit.new()
		ed_name.text = str(b.get("name", ""))
		ed_name.text_changed.connect(func(v: String): b["name"] = v; current_blueprint.emit_changed())
		b_vbox.add_child(ed_name)
		
		var ed_target := LineEdit.new()
		ed_target.text = str(b.get("target_id", ""))
		ed_target.text_changed.connect(func(v: String): b["target_id"] = v; current_blueprint.emit_changed())
		b_vbox.add_child(ed_target)
		
		v_box.add_child(b_box)
		
	var btn_add_branch := Button.new()
	btn_add_branch.text = "+ Aggiungi Ramo"
	btn_add_branch.pressed.connect(func():
		var j_pos: Vector2 = junc.get("pos", Vector2.ZERO)
		var new_b := {"name": "Nuovo Ramo", "target_type": "dead_end", "target_id": "DEAD_%d" % (branches.size() + 1), "line_id": "L_%s_B%d" % [junc.get("id", "J"), branches.size()], "to_pos": j_pos + Vector2(30, 0)}
		branches.append(new_b)
		current_blueprint.emit_changed()
		_populate_property_editor("junction", str(junc.get("id", "")), junc)
		canvas.queue_redraw()
	)
	v_box.add_child(btn_add_branch)
	prop_editor_vbox.add_child(v_box)

# --- OUTLINER TREE ---

func _refresh_outliner() -> void:
	if not outliner_tree or not current_blueprint:
		return
	outliner_tree.clear()
	var root := outliner_tree.create_item()
	
	# Gruppo 1: Stanze
	var cat_rooms := outliner_tree.create_item(root)
	cat_rooms.set_text(0, "🔲 Stanze e Settori (%d)" % current_blueprint.rooms.size())
	for r in current_blueprint.rooms:
		var item := outliner_tree.create_item(cat_rooms)
		item.set_text(0, "[%s] %s" % [str(r.get("id", "")), str(r.get("name", ""))])
		item.set_metadata(0, {"type": "room", "id": str(r.get("id", ""))})
		
	# Gruppo 2: Condotti
	var cat_ducts := outliner_tree.create_item(root)
	cat_ducts.set_text(0, "🔧 Condotti di Manutenzione (%d)" % current_blueprint.ducts.size())
	for d in current_blueprint.ducts:
		var item := outliner_tree.create_item(cat_ducts)
		item.set_text(0, "[%s] %s" % [str(d.get("id", "")), str(d.get("name", ""))])
		item.set_metadata(0, {"type": "duct", "id": str(d.get("id", ""))})

	# Gruppo 3: Rete Elettrica
	var cat_power := outliner_tree.create_item(root)
	cat_power.set_text(0, "⚡ Rete Elettrica (%d Dev / %d Snodi)" % [current_blueprint.devices.size(), current_blueprint.junctions.size()])
	for dev in current_blueprint.devices:
		var item := outliner_tree.create_item(cat_power)
		var gen_tag := " [GEN]" if dev.get("is_generator", false) else ""
		item.set_text(0, "⚡ [%s] %s%s" % [str(dev.get("id", "")), str(dev.get("name", "")), gen_tag])
		item.set_metadata(0, {"type": "device", "id": str(dev.get("id", ""))})
	for j in current_blueprint.junctions:
		var item := outliner_tree.create_item(cat_power)
		item.set_text(0, "🟡 [%s] %s" % [str(j.get("id", "")), str(j.get("name", ""))])
		item.set_metadata(0, {"type": "junction", "id": str(j.get("id", ""))})

	# Gruppo 4: Danni
	var cat_damages := outliner_tree.create_item(root)
	cat_damages.set_text(0, "💥 Zone Danni & Anomalie (%d)" % current_blueprint.damages.size())
	for dmg in current_blueprint.damages:
		var item := outliner_tree.create_item(cat_damages)
		item.set_text(0, "💥 [%s] %s" % [str(dmg.get("id", "")), str(dmg.get("name", ""))])
		item.set_metadata(0, {"type": "damage", "id": str(dmg.get("id", ""))})

func _on_outliner_tree_item_selected() -> void:
	var selected_item := outliner_tree.get_selected()
	if not selected_item:
		return
	var meta = selected_item.get_metadata(0)
	if meta is Dictionary:
		var elem_type: String = str(meta.get("type", ""))
		var elem_id: String = str(meta.get("id", ""))
		canvas.selected_type = elem_type
		canvas.selected_id = elem_id
		var elem_data := canvas._get_selected_element_data()
		_populate_property_editor(elem_type, elem_id, elem_data)
		canvas.queue_redraw()

# --- AZIONI TOOLBAR & SALVATAGGIO ---

func _on_btn_new_pressed() -> void:
	var bp := ShipBlueprint.new()
	bp.create_default_ship()
	load_blueprint(bp, "")
	_set_status_msg("Nuova Blueprint creata.")

func _on_btn_open_tres_pressed() -> void:
	_pending_file_action = "open_tres"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = ["*.tres, *.res ; Godot Resources"]
	file_dialog.current_path = DEFAULT_BLUEPRINT_PATH
	file_dialog.popup_centered(Vector2i(700, 500))

func _on_btn_save_tres_pressed() -> void:
	if current_file_path.is_empty():
		_on_btn_save_as_tres_pressed()
		return
	_save_to_path(current_file_path)

func _on_btn_save_as_tres_pressed() -> void:
	_pending_file_action = "save_tres"
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.filters = ["*.tres, *.res ; Godot Resources"]
	file_dialog.current_path = current_file_path if not current_file_path.is_empty() else DEFAULT_BLUEPRINT_PATH
	file_dialog.popup_centered(Vector2i(700, 500))

func _on_btn_export_json_pressed() -> void:
	_pending_file_action = "export_json"
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.filters = ["*.json ; JSON Files"]
	file_dialog.current_path = "res://Outside/ShipSublayer/ship_blueprint.json"
	file_dialog.popup_centered(Vector2i(700, 500))

func _on_btn_import_json_pressed() -> void:
	_pending_file_action = "import_json"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = ["*.json ; JSON Files"]
	file_dialog.current_path = "res://Outside/ShipSublayer/ship_blueprint.json"
	file_dialog.popup_centered(Vector2i(700, 500))

func _on_btn_reset_default_pressed() -> void:
	confirm_dialog.popup_centered()

func _on_confirm_reset_default() -> void:
	if current_blueprint:
		current_blueprint.create_default_ship()
		_save_to_path(DEFAULT_BLUEPRINT_PATH)
		_refresh_outliner()
		_update_stats_label()
		canvas.reset_view()
		_set_status_msg("Blueprint ripristinata ai valori standard Dark Nova.")

func _on_file_dialog_file_selected(path: String) -> void:
	match _pending_file_action:
		"open_tres":
			if ResourceLoader.exists(path):
				var res := ResourceLoader.load(path)
				if res is ShipBlueprint:
					load_blueprint(res as ShipBlueprint, path)
					_set_status_msg("Caricata: %s" % path)
		"save_tres":
			_save_to_path(path)
		"export_json":
			if current_blueprint:
				var err := current_blueprint.export_to_json(path)
				if err == OK:
					_set_status_msg("Esportato JSON: %s" % path)
				else:
					_set_status_msg("Errore esportazione JSON (codice %d)" % err)
		"import_json":
			if current_blueprint:
				var err := current_blueprint.import_from_json(path)
				if err == OK:
					_refresh_outliner()
					_update_stats_label()
					canvas.reset_view()
					_set_status_msg("Importato JSON: %s" % path)
				else:
					_set_status_msg("Errore importazione JSON (codice %d)" % err)

func _save_to_path(path: String) -> void:
	if not current_blueprint:
		return
	var err := ResourceSaver.save(current_blueprint, path)
	if err == OK:
		current_file_path = path
		if lbl_current_file:
			lbl_current_file.text = path.get_file()
			lbl_current_file.tooltip_text = path
		_set_status_msg("Blueprint salvata con successo in %s" % path)
	else:
		_set_status_msg("Errore durante il salvataggio (codice %d)" % err)
