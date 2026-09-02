@tool
class_name ShipSublayerEditor
extends Control

## Editor visivo per i Sublayer / Blueprint della nave in GodotOS.
## Funziona sia come pannello integrato nell'Editor di Godot sia come applicazione standalone.

const DEFAULT_BLUEPRINT_PATH := "res://Outside/ShipSublayer/default_ship_blueprint.tres"
const MAX_UNDO_DEPTH := 50

var current_blueprint: ShipBlueprint = null
var current_file_path: String = DEFAULT_BLUEPRINT_PATH

# Stack per Undo / Redo
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []

# Riferimenti UI interni
var main_vbox: VBoxContainer = null
var menu_bar: MenuBar = null
var file_menu: PopupMenu = null
var edit_menu: PopupMenu = null
var tools_menu: PopupMenu = null
var view_menu: PopupMenu = null
var layer_menu: PopupMenu = null

var canvas: ShipBlueprintCanvas = null
var tool_btn_group: ButtonGroup = ButtonGroup.new()

# Toolbar Controlli
var lbl_current_file: Label = null
var btn_undo: Button = null
var btn_redo: Button = null
var btn_copy: Button = null
var btn_paste: Button = null

var btn_select: Button = null
var btn_add_room: Button = null
var btn_add_duct: Button = null
var btn_add_device: Button = null
var btn_add_damage: Button = null
var btn_delete: Button = null
var opt_room_template: OptionButton = null

var chk_layer_rooms: CheckBox = null
var chk_layer_ducts: CheckBox = null
var chk_layer_devices: CheckBox = null
var chk_layer_damages: CheckBox = null
var chk_layer_spawn: CheckBox = null
var chk_layer_bounds: CheckBox = null
var chk_layer_grid: CheckBox = null
var chk_layer_labels: CheckBox = null

var chk_snap: CheckBox = null
var opt_snap_size: OptionButton = null
var lbl_zoom: Label = null

# Inspector & Outliner
var outliner_tree: Tree = null
var software_list_vbox: VBoxContainer = null
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
var confirm_random_dialog: ConfirmationDialog = null
var _pending_file_action: String = ""

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
	
	_undo_stack.clear()
	_redo_stack.clear()
	_update_undo_redo_buttons()
	
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
	_refresh_software_panel()
	_update_stats_label()
	_show_blueprint_metadata_props()
	_set_status_msg("Blueprint caricata con successo.")

func _on_blueprint_changed() -> void:
	if canvas:
		canvas.queue_redraw()
	_refresh_outliner()
	_refresh_software_panel()
	_update_stats_label()

# --- GESTIONE UNDO / REDO ---

func save_undo_state(action_name: String = "") -> void:
	if not current_blueprint:
		return
	var snapshot: Dictionary = {
		"action": action_name,
		"data": current_blueprint.to_dict(),
		"selected_type": canvas.selected_type if canvas else "",
		"selected_id": canvas.selected_id if canvas else ""
	}
	_undo_stack.append(snapshot)
	if _undo_stack.size() > MAX_UNDO_DEPTH:
		_undo_stack.pop_front()
	_redo_stack.clear()
	_update_undo_redo_buttons()

func undo() -> void:
	if _undo_stack.is_empty() or not current_blueprint:
		_set_status_msg("Nessuna azione da annullare.")
		return
	
	# Salva stato attuale nello stack di Redo
	var current_snapshot: Dictionary = {
		"data": current_blueprint.to_dict(),
		"selected_type": canvas.selected_type if canvas else "",
		"selected_id": canvas.selected_id if canvas else ""
	}
	_redo_stack.append(current_snapshot)
	
	var prev_state: Dictionary = _undo_stack.pop_back()
	current_blueprint.from_dict(prev_state.get("data"))
	
	var sel_type: String = str(prev_state.get("selected_type"))
	var sel_id: String = str(prev_state.get("selected_id"))
	if canvas:
		canvas.selected_type = sel_type
		canvas.selected_id = sel_id
		canvas.queue_redraw()
	
	_refresh_outliner()
	_refresh_software_panel()
	_update_stats_label()
	if canvas:
		_populate_property_editor(sel_type, sel_id, canvas._get_selected_element_data())
	_update_undo_redo_buttons()
	var act_name: String = str(prev_state.get("action"))
	_set_status_msg("Annullata azione: %s" % act_name if not act_name.is_empty() else "Annullata ultima azione.")

func redo() -> void:
	if _redo_stack.is_empty() or not current_blueprint:
		_set_status_msg("Nessuna azione da ripristinare.")
		return
	
	# Salva stato attuale nello stack di Undo
	var current_snapshot: Dictionary = {
		"data": current_blueprint.to_dict(),
		"selected_type": canvas.selected_type if canvas else "",
		"selected_id": canvas.selected_id if canvas else ""
	}
	_undo_stack.append(current_snapshot)
	
	var next_state: Dictionary = _redo_stack.pop_back()
	current_blueprint.from_dict(next_state.get("data"))
	
	var sel_type: String = str(next_state.get("selected_type"))
	var sel_id: String = str(next_state.get("selected_id"))
	if canvas:
		canvas.selected_type = sel_type
		canvas.selected_id = sel_id
		canvas.queue_redraw()
		
	_refresh_outliner()
	_refresh_software_panel()
	_update_stats_label()
	if canvas:
		_populate_property_editor(sel_type, sel_id, canvas._get_selected_element_data())
	_update_undo_redo_buttons()
	_set_status_msg("Ripristinata azione.")

func _update_undo_redo_buttons() -> void:
	if btn_undo:
		btn_undo.disabled = _undo_stack.is_empty()
		if not _undo_stack.is_empty():
			var last_act: String = str(_undo_stack.back().get("action"))
			btn_undo.tooltip_text = "Annulla: %s (Ctrl+Z)" % last_act if not last_act.is_empty() else "Annulla (Ctrl+Z)"
		else:
			btn_undo.tooltip_text = "Annulla (Ctrl+Z)"
			
	if btn_redo:
		btn_redo.disabled = _redo_stack.is_empty()
		btn_redo.tooltip_text = "Ripristina (Ctrl+Y / Ctrl+Shift+Z)"

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		var is_ctrl := key_event.ctrl_pressed or key_event.meta_pressed
		
		# Undo (Ctrl+Z) / Redo (Ctrl+Y o Ctrl+Shift+Z)
		if is_ctrl:
			if key_event.keycode == KEY_Z:
				if key_event.shift_pressed:
					redo()
				else:
					undo()
				get_viewport().set_input_as_handled()
				return
			elif key_event.keycode == KEY_Y:
				redo()
				get_viewport().set_input_as_handled()
				return
			elif key_event.keycode == KEY_C:
				if canvas:
					canvas.copy_selection()
				get_viewport().set_input_as_handled()
				return
			elif key_event.keycode == KEY_V:
				if canvas:
					canvas.paste_selection()
				get_viewport().set_input_as_handled()
				return
		
		# Tasto Cancella / Backspace per eliminare l'elemento selezionato
		if (key_event.keycode == KEY_DELETE or key_event.keycode == KEY_BACKSPACE) and not is_ctrl:
			var focused := get_viewport().gui_get_focus_owner()
			if focused is LineEdit or focused is TextEdit:
				return # Lascia scrivere nei campi di testo
			if canvas and not canvas.selected_type.is_empty() and not canvas.selected_id.is_empty():
				save_undo_state("Elimina " + canvas.selected_type)
				canvas.delete_element(canvas.selected_type, canvas.selected_id)
				_refresh_outliner()
				_refresh_software_panel()
				_update_stats_label()
				_show_blueprint_metadata_props()
				get_viewport().set_input_as_handled()
				return

# --- COSTRUZIONE INTERFACCIA UTENTE ---

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()
		
	main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_vbox)
	
	# 1. MENU BAR & TOP TOOLBAR
	menu_bar = _create_menu_bar()
	main_vbox.add_child(menu_bar)
	
	var toolbar := _create_toolbar()
	main_vbox.add_child(toolbar)
	
	# 2. MAIN SPLIT (Pannello Tabs a sinistra, Canvas al centro, Inspector a destra)
	var main_hsplit := HSplitContainer.new()
	main_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hsplit.split_offset = 280
	main_vbox.add_child(main_hsplit)
	
	# Left Side: TabContainer per Outliner e Software Manager
	var left_tabs := TabContainer.new()
	left_tabs.custom_minimum_size = Vector2(280, 0)
	main_hsplit.add_child(left_tabs)
	
	# Tab 1: Outliner (esistente)
	var left_panel := _create_left_panel()
	left_panel.name = "Outliner"
	left_tabs.add_child(left_panel)
	
	# Tab 2: Software Manager (nuovo)
	var software_panel := _create_software_panel()
	software_panel.name = "Software"
	left_tabs.add_child(software_panel)
	
	# Sub Split: Canvas al centro e Inspector a destra
	var right_hsplit := HSplitContainer.new()
	right_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_hsplit.split_offset = 580
	main_hsplit.add_child(right_hsplit)
	
	# Canvas Panel (Centro)
	var canvas_panel := PanelContainer.new()
	canvas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_hsplit.add_child(canvas_panel)
	
	canvas = ShipBlueprintCanvas.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.element_selected.connect(_on_canvas_element_selected)
	canvas.element_modified.connect(func(elem_type, elem_id, elem_data):
		_populate_property_editor(elem_type, elem_id, elem_data)
		_refresh_outliner()
		_refresh_software_panel()
		_update_stats_label()
	)
	canvas.cursor_coords_changed.connect(_on_canvas_cursor_coords_changed)
	canvas.action_committed.connect(_on_canvas_action_committed)
	canvas.tool_changed.connect(_on_canvas_tool_changed)
	canvas_panel.add_child(canvas)
	
	if opt_room_template and opt_room_template.get_item_count() > 0:
		canvas.selected_room_template = opt_room_template.get_item_metadata(opt_room_template.selected if opt_room_template.selected >= 0 else 0)
	
	# Right Panel: Inspector Proprietà (Destra)
	var right_panel := _create_right_panel()
	right_hsplit.add_child(right_panel)
	
	# 3. BOTTOM STATUS BAR
	var status_bar := _create_status_bar()
	main_vbox.add_child(status_bar)
	
	# 4. DIALOGS
	_create_dialogs()

func _create_menu_bar() -> MenuBar:
	var mb := MenuBar.new()
	
	# --- MENU FILE ---
	file_menu = PopupMenu.new()
	file_menu.name = "File"
	file_menu.add_item("Nuovo", 0)
	file_menu.add_item("Apri .tres", 1)
	file_menu.add_item("Salva", 2)
	file_menu.add_item("Salva come...", 3)
	file_menu.add_separator()
	file_menu.add_item("Esporta JSON", 4)
	file_menu.add_item("Importa JSON", 5)
	file_menu.add_separator()
	file_menu.add_item("Reset Default", 6)
	file_menu.id_pressed.connect(_on_file_menu_id_pressed)
	mb.add_child(file_menu)
	
	# --- MENU MODIFICA ---
	edit_menu = PopupMenu.new()
	edit_menu.name = "Modifica"
	edit_menu.add_item("Undo (Annulla)", 0)
	edit_menu.add_item("Redo (Ripristina)", 1)
	edit_menu.add_separator()
	edit_menu.add_item("Copia", 2)
	edit_menu.add_item("Incolla", 3)
	edit_menu.add_item("Elimina Selezionato", 4)
	edit_menu.add_separator()
	edit_menu.add_item("Genera Layout Casuale", 5)
	edit_menu.id_pressed.connect(_on_edit_menu_id_pressed)
	mb.add_child(edit_menu)
	
	# --- MENU STRUMENTI ---
	tools_menu = PopupMenu.new()
	tools_menu.name = "Strumenti"
	tools_menu.add_radio_check_item("Seleziona", 0)
	tools_menu.add_radio_check_item("Aggiungi Stanza", 1)
	tools_menu.add_radio_check_item("Aggiungi Condotto", 2)
	tools_menu.add_radio_check_item("Elimina (Tool)", 3)
	tools_menu.set_item_checked(0, true)
	tools_menu.add_separator()
	tools_menu.add_item("Nuovo File Drive", 10)
	tools_menu.add_item("Nuova Password Sistema", 11)
	tools_menu.add_item("Installa Applicazione", 12)
	tools_menu.add_item("Aggiungi Zona di Danno", 13)
	tools_menu.id_pressed.connect(_on_tools_menu_id_pressed)
	mb.add_child(tools_menu)
	
	# --- MENU VISUALIZZA ---
	view_menu = PopupMenu.new()
	view_menu.name = "Visualizza"
	
	# Sottomenu Layer
	layer_menu = PopupMenu.new()
	layer_menu.name = "Layers"
	layer_menu.add_check_item("Stanze", 0)
	layer_menu.add_check_item("Condotti", 1)
	layer_menu.add_check_item("Dispositivi", 2)
	layer_menu.add_check_item("Danni", 3)
	layer_menu.add_check_item("Spawn Drone", 4)
	layer_menu.add_check_item("Scafo", 5)
	layer_menu.add_check_item("Griglia", 6)
	layer_menu.add_check_item("Etichette", 7)
	for i in range(8): layer_menu.set_item_checked(i, true)
	layer_menu.id_pressed.connect(_on_layer_menu_id_pressed)
	view_menu.add_child(layer_menu)
	view_menu.add_submenu_item("Layers Visibili", "Layers")
	
	view_menu.add_separator()
	view_menu.add_check_item("Snap alla Griglia", 10)
	view_menu.set_item_checked(view_menu.get_item_index(10), true)
	view_menu.add_separator()
	view_menu.add_item("Zoom In", 11)
	view_menu.add_item("Zoom Out", 12)
	view_menu.add_item("Centra Vista", 13)
	view_menu.id_pressed.connect(_on_view_menu_id_pressed)
	mb.add_child(view_menu)
	
	return mb

func _on_file_menu_id_pressed(id: int) -> void:
	match id:
		0: _on_btn_new_pressed()
		1: _on_btn_open_tres_pressed()
		2: _on_btn_save_tres_pressed()
		3: _on_btn_save_as_tres_pressed()
		4: _on_btn_export_json_pressed()
		5: _on_btn_import_json_pressed()
		6: _on_btn_reset_default_pressed()

func _on_edit_menu_id_pressed(id: int) -> void:
	if id == 0:
		undo()
	elif id == 1:
		redo()
	elif id == 2 and canvas:
		canvas.copy_selection()
	elif id == 3 and canvas:
		canvas.paste_selection()
	elif id == 4 and canvas and not canvas.selected_type.is_empty():
		save_undo_state("Elimina " + canvas.selected_type)
		canvas.delete_element(canvas.selected_type, canvas.selected_id)
	elif id == 5:
		_on_btn_random_pressed()
	else:
		push_error("Opzione non disponibile")

func _on_tools_menu_id_pressed(id: int) -> void:
	if id < 10:
		var mode: int = ShipBlueprintCanvas.ToolMode.SELECT
		match id:
			0: mode = ShipBlueprintCanvas.ToolMode.SELECT
			1: mode = ShipBlueprintCanvas.ToolMode.ADD_ROOM
			2: mode = ShipBlueprintCanvas.ToolMode.ADD_DUCT
			3: mode = ShipBlueprintCanvas.ToolMode.DELETE
		
		if canvas:
			canvas.current_tool = mode
		
		# Aggiorna check nel menu
		if tools_menu:
			for i in range(4):
				tools_menu.set_item_checked(i, i == id)
	else:
		match id:
			10: _on_btn_add_drive_file_pressed()
			11: _on_btn_add_drive_password_pressed()
			12: _on_btn_install_software_pressed()
			13: _on_btn_add_damage_pressed()

func _on_layer_menu_id_pressed(id: int) -> void:
	if not canvas or not layer_menu: return
	var new_val: bool = not layer_menu.is_item_checked(id)
	layer_menu.set_item_checked(id, new_val)
	
	match id:
		0: canvas.show_rooms = new_val
		1: canvas.show_ducts = new_val
		2: canvas.show_devices = new_val
		3: canvas.show_damages = new_val
		4: canvas.show_spawn = new_val
		5: canvas.show_bounds = new_val
		6: canvas.show_grid = new_val
		7: canvas.show_labels = new_val
	
	# Sincronizza checkbox toolbar
	if id == 0:
		if chk_layer_rooms: chk_layer_rooms.button_pressed = new_val
	elif id == 1:
		if chk_layer_ducts: chk_layer_ducts.button_pressed = new_val
	elif id == 2:
		if chk_layer_devices: chk_layer_devices.button_pressed = new_val
	elif id == 3:
		if chk_layer_damages: chk_layer_damages.button_pressed = new_val
	elif id == 4:
		if chk_layer_spawn: chk_layer_spawn.button_pressed = new_val
	elif id == 5:
		if chk_layer_bounds: chk_layer_bounds.button_pressed = new_val
	elif id == 6:
		if chk_layer_grid: chk_layer_grid.button_pressed = new_val
	elif id == 7:
		if chk_layer_labels: chk_layer_labels.button_pressed = new_val

func _on_view_menu_id_pressed(id: int) -> void:
	match id:
		10: # Snap
			if view_menu:
				var idx: int = view_menu.get_item_index(10)
				var new_val: bool = not view_menu.is_item_checked(idx)
				view_menu.set_item_checked(idx, new_val)
				if canvas: canvas.snap_enabled = new_val
				if chk_snap: chk_snap.button_pressed = new_val
		11: # Zoom In
			if canvas:
				canvas.set_zoom(canvas.zoom_level * 1.25)
				_update_zoom_label()
		12: # Zoom Out
			if canvas:
				canvas.set_zoom(canvas.zoom_level / 1.25)
				_update_zoom_label()
		13: # Centra
			if canvas:
				canvas.reset_view()
				_update_zoom_label()

func _create_toolbar() -> Control:
	var bar := PanelContainer.new()
	var toolbar_vbox := VBoxContainer.new()
	toolbar_vbox.add_theme_constant_override("separation", 3)
	bar.add_child(toolbar_vbox)
	
	# --- RIGA 1: STRUMENTI DI BASE & MODIFICA ---
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 5)
	toolbar_vbox.add_child(row1)
	
	# Undo / Redo
	btn_undo = Button.new()
	btn_undo.text = "↩️"
	btn_undo.tooltip_text = "Annulla (Ctrl+Z)"
	btn_undo.disabled = true
	btn_undo.pressed.connect(undo)
	row1.add_child(btn_undo)
	
	btn_redo = Button.new()
	btn_redo.text = "↪️"
	btn_redo.tooltip_text = "Ripristina (Ctrl+Y / Ctrl+Shift+Z)"
	btn_redo.disabled = true
	btn_redo.pressed.connect(redo)
	row1.add_child(btn_redo)
	
	row1.add_child(VSeparator.new())
	
	# Strumenti di modifica (ToolButtons)
	btn_select = _create_tool_button("🔍 Seleziona", ShipBlueprintCanvas.ToolMode.SELECT, true)
	row1.add_child(btn_select)
	
	btn_add_room = _create_tool_button("🔲 Stanza", ShipBlueprintCanvas.ToolMode.ADD_ROOM, false)
	row1.add_child(btn_add_room)
	
	opt_room_template = OptionButton.new()
	opt_room_template.tooltip_text = "Tipo di stanza da aggiungere"
	opt_room_template.visible = false
	
	# Carica il database delle stanze
	for room_id in RoomDatabase.get_room_ids():
		opt_room_template.add_item(RoomDatabase.get_room_name(room_id))
		opt_room_template.set_item_metadata(opt_room_template.get_item_count() - 1, room_id)
	opt_room_template.item_selected.connect(func(idx):
		if canvas:
			canvas.selected_room_template = opt_room_template.get_item_metadata(idx)
	)
	row1.add_child(opt_room_template)
	
	btn_add_duct = _create_tool_button("🔧 Condotto", ShipBlueprintCanvas.ToolMode.ADD_DUCT, false)
	row1.add_child(btn_add_duct)
	
	btn_delete = _create_tool_button("🗑️ Elimina", ShipBlueprintCanvas.ToolMode.DELETE, false)
	row1.add_child(btn_delete)
	
	# Label File Corrente
	lbl_current_file = Label.new()
	lbl_current_file.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_current_file.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_current_file.text = "default_ship_blueprint.tres"
	row1.add_child(lbl_current_file)
	
	# --- RIGA 2: VISIBILITÀ TUTTI I LAYER, SNAP & ZOOM ---
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	toolbar_vbox.add_child(row2)
	
	var lbl_layers := Label.new()
	lbl_layers.text = "Layer Visibili:"
	row2.add_child(lbl_layers)
	
	chk_layer_rooms = _create_layer_check("Stanze", true, func(v): canvas.show_rooms = v, 0)
	row2.add_child(chk_layer_rooms)
	
	chk_layer_ducts = _create_layer_check("Condotti", true, func(v): canvas.show_ducts = v, 1)
	row2.add_child(chk_layer_ducts)
	
	chk_layer_devices = _create_layer_check("Dispositivi", true, func(v): canvas.show_devices = v, 2)
	row2.add_child(chk_layer_devices)
	
	chk_layer_damages = _create_layer_check("Danni", true, func(v): canvas.show_damages = v, 3)
	row2.add_child(chk_layer_damages)
	
	chk_layer_spawn = _create_layer_check("Spawn Drone", true, func(v): canvas.show_spawn = v, 4)
	row2.add_child(chk_layer_spawn)
	
	chk_layer_bounds = _create_layer_check("Scafo", true, func(v): canvas.show_bounds = v, 5)
	row2.add_child(chk_layer_bounds)
	
	chk_layer_grid = _create_layer_check("Griglia", true, func(v): canvas.show_grid = v, 6)
	row2.add_child(chk_layer_grid)
	
	chk_layer_labels = _create_layer_check("Testo", true, func(v): canvas.show_labels = v, 7)
	row2.add_child(chk_layer_labels)
	
	row2.add_child(VSeparator.new())
	
	# Snap
	chk_snap = CheckBox.new()
	chk_snap.text = "Snap"
	chk_snap.button_pressed = true
	chk_snap.toggled.connect(func(v: bool):
		canvas.snap_enabled = v
		if view_menu:
			view_menu.set_item_checked(view_menu.get_item_index(10), v)
	)
	row2.add_child(chk_snap)
	
	opt_snap_size = OptionButton.new()
	opt_snap_size.add_item("5px", 0)
	opt_snap_size.add_item("10px", 1)
	opt_snap_size.add_item("20px", 2)
	opt_snap_size.add_item("50px", 3)
	opt_snap_size.select(1) # 10px default
	opt_snap_size.item_selected.connect(_on_snap_size_selected)
	row2.add_child(opt_snap_size)
	
	row2.add_child(VSeparator.new())
	
	# Zoom & Reset View
	var btn_zoom_out := Button.new()
	btn_zoom_out.text = "－"
	btn_zoom_out.tooltip_text = "Zoom Out"
	btn_zoom_out.pressed.connect(func():
		canvas.set_zoom(canvas.zoom_level / 1.25)
		_update_zoom_label()
	)
	row2.add_child(btn_zoom_out)
	
	var btn_zoom_in := Button.new()
	btn_zoom_in.text = "＋"
	btn_zoom_in.tooltip_text = "Zoom In"
	btn_zoom_in.pressed.connect(func():
		canvas.set_zoom(canvas.zoom_level * 1.25)
		_update_zoom_label()
	)
	row2.add_child(btn_zoom_in)
	
	var btn_reset_view := Button.new()
	btn_reset_view.text = "Centra"
	btn_reset_view.tooltip_text = "Centra Vista su Scafo"
	btn_reset_view.pressed.connect(func():
		canvas.reset_view()
		_update_zoom_label()
	)
	row2.add_child(btn_reset_view)
	
	lbl_zoom = Label.new()
	lbl_zoom.text = "100%"
	row2.add_child(lbl_zoom)
	
	return bar

func _update_zoom_label() -> void:
	if lbl_zoom and canvas:
		lbl_zoom.text = "%d%%" % int(canvas.zoom_level * 100.0)

func _create_tool_button(btn_text: String, tool_mode: int, is_default: bool) -> Button:
	var btn := Button.new()
	btn.text = btn_text
	btn.toggle_mode = true
	btn.button_group = tool_btn_group
	btn.button_pressed = is_default
	btn.pressed.connect(func(): canvas.current_tool = tool_mode)
	return btn

func _create_layer_check(lbl_text: String, is_active: bool, callback: Callable, layer_id: int) -> CheckBox:
	var chk := CheckBox.new()
	chk.text = lbl_text
	chk.button_pressed = is_active
	chk.toggled.connect(func(v):
		callback.call(v)
		if layer_menu:
			layer_menu.set_item_checked(layer_id, v)
	)
	return chk

func _create_left_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var vbox_tree := VBoxContainer.new()
	vbox_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox_tree.add_theme_constant_override("separation", 6)
	panel.add_child(vbox_tree)
	
	# Header
	var lbl_header := Label.new()
	lbl_header.text = "🗂️ Tutti i Layer (Outliner)"
	lbl_header.add_theme_font_size_override("font_size", 13)
	vbox_tree.add_child(lbl_header)
	
	# Pulsanti di creazione rapida nell'outliner
	var outliner_toolbar := HFlowContainer.new()
	outliner_toolbar.add_theme_constant_override("h_separation", 4)
	outliner_toolbar.add_theme_constant_override("v_separation", 4)
	vbox_tree.add_child(outliner_toolbar)
	
	var btn_add_df := Button.new()
	btn_add_df.text = "+ File Drive"
	btn_add_df.tooltip_text = "Aggiungi file di configurazione (.dat / script)"
	btn_add_df.pressed.connect(_on_btn_add_drive_file_pressed)
	outliner_toolbar.add_child(btn_add_df)
	
	var btn_add_pwd := Button.new()
	btn_add_pwd.text = "+ Password"
	btn_add_pwd.tooltip_text = "Imposta password per una cartella di sistema"
	btn_add_pwd.pressed.connect(_on_btn_add_drive_password_pressed)
	outliner_toolbar.add_child(btn_add_pwd)
	
	var btn_add_ap := Button.new()
	btn_add_ap.text = "+ App"
	btn_add_ap.tooltip_text = "Registra una nuova applicazione mainframe"
	btn_add_ap.pressed.connect(_on_btn_add_app_pressed)
	outliner_toolbar.add_child(btn_add_ap)
	
	var btn_add_dmg := Button.new()
	btn_add_dmg.text = "+ Danno"
	btn_add_dmg.tooltip_text = "Aggiungi una zona di danno strutturale"
	btn_add_dmg.pressed.connect(_on_btn_add_damage_pressed)
	outliner_toolbar.add_child(btn_add_dmg)
	
	outliner_tree = Tree.new()
	outliner_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outliner_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outliner_tree.hide_root = true
	outliner_tree.item_selected.connect(_on_outliner_tree_item_selected)
	vbox_tree.add_child(outliner_tree)
	
	return panel

func _create_software_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	var header_hbox := HBoxContainer.new()
	vbox.add_child(header_hbox)
	
	var lbl_header := Label.new()
	lbl_header.text = "💾 Software Manager"
	lbl_header.add_theme_font_size_override("font_size", 13)
	lbl_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(lbl_header)
	
	var btn_add_sw := Button.new()
	btn_add_sw.text = "➕ App"
	btn_add_sw.tooltip_text = "Installa una nuova applicazione (.tres)"
	btn_add_sw.pressed.connect(_on_btn_install_software_pressed)
	header_hbox.add_child(btn_add_sw)
	
	var btn_add_pwd := Button.new()
	btn_add_pwd.text = "➕ Pass"
	btn_add_pwd.tooltip_text = "Aggiungi una nuova password di sistema"
	btn_add_pwd.pressed.connect(_on_btn_add_drive_password_pressed)
	header_hbox.add_child(btn_add_pwd)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	software_list_vbox = VBoxContainer.new()
	software_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	software_list_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(software_list_vbox)
	
	return panel

func _refresh_software_panel() -> void:
	if not software_list_vbox or not current_blueprint:
		return
		
	for c in software_list_vbox.get_children():
		c.queue_free()
		
	if current_blueprint.installed_apps.is_empty() and current_blueprint.drive_passwords.is_empty():
		var lbl := Label.new()
		lbl.text = "Nessuna app installata."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color.GRAY)
		software_list_vbox.add_child(lbl)
		return
		
	var displayed_passwords := []

	for app in current_blueprint.installed_apps:
		var app_id: String = str(app.get("id"))
		var title: String = str(app.get("title"))
		var scene_path: String = str(app.get("scene_path"))
		
		var item_bg := PanelContainer.new()
		item_bg.add_theme_stylebox_override("panel", get_theme_stylebox("panel", "Tree"))
		software_list_vbox.add_child(item_bg)
		
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		item_bg.add_child(row)
		
		var lbl_title := Label.new()
		lbl_title.text = "📦 " + title
		lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_title.add_theme_font_size_override("font_size", 11)
		lbl_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl_title.tooltip_text = "App ID: " + app_id
		row.add_child(lbl_title)
		
		# Recupera la risorsa dell'applicazione per estrarre la password e i dati corretti
		var app_res: AppResource = null
		var res_path := scene_path.replace(".tscn", ".tres")
		if ResourceLoader.exists(res_path):
			app_res = load(res_path) as AppResource
			
		# Determina la chiave per identificare se questa password è già visualizzata
		var pwd_key := ""
		if app_res and not app_res.drive_folder.is_empty():
			var folder_rel: String = app_res.drive_folder.trim_prefix("/").trim_suffix("/")
			pwd_key = "Ship Drive/" + folder_rel if not folder_rel.begins_with("Ship Drive/") else folder_rel
		else:
			pwd_key = scene_path
			
		displayed_passwords.append(pwd_key)
		
		var edit_pwd := LineEdit.new()
		# La password viene presa prioritariamente dal file risorsa come richiesto
		if app_res:
			edit_pwd.text = app_res.default_password
		else:
			edit_pwd.text = current_blueprint.drive_passwords.get(pwd_key, "")
			
		edit_pwd.custom_minimum_size = Vector2(80, 0)
		edit_pwd.placeholder_text = "Pass"
		edit_pwd.alignment = HORIZONTAL_ALIGNMENT_CENTER
		edit_pwd.add_theme_font_size_override("font_size", 10)
		
		edit_pwd.text_submitted.connect((func(new_pwd: String, key: String, t: String):
			save_undo_state("Cambia Password " + t)
			if new_pwd.is_empty():
				current_blueprint.remove_drive_password(key)
			else:
				current_blueprint.set_drive_password(key, new_pwd)
			_refresh_software_panel()
		).bind(pwd_key, title))
		row.add_child(edit_pwd)
		
		var btn_uninstall := Button.new()
		btn_uninstall.text = "🗑️"
		btn_uninstall.tooltip_text = "Disinstalla software"
		btn_uninstall.pressed.connect((func(id: String, t: String):
			save_undo_state("Disinstalla " + t)
			current_blueprint.uninstall_app_by_id(id)
			_refresh_software_panel()
			_refresh_outliner()
		).bind(app_id, title))
		row.add_child(btn_uninstall)

	# Password di Sistema (quelle non associate ad app specifiche)
	var system_passwords := []
	for k in current_blueprint.drive_passwords.keys():
		if not k in displayed_passwords:
			system_passwords.append(k)
			
	if not system_passwords.is_empty():
		for skey in system_passwords:
			var item_bg := PanelContainer.new()
			item_bg.add_theme_stylebox_override("panel", get_theme_stylebox("panel", "Tree"))
			software_list_vbox.add_child(item_bg)
			
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			item_bg.add_child(row)
			
			var slbl := Label.new()
			slbl.text = "🔑 " + skey.get_file()
			slbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slbl.add_theme_font_size_override("font_size", 11)
			slbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			slbl.tooltip_text = skey
			row.add_child(slbl)
			
			var sedit := LineEdit.new()
			sedit.text = current_blueprint.drive_passwords[skey]
			sedit.custom_minimum_size = Vector2(80, 0)
			sedit.placeholder_text = "Pass"
			sedit.alignment = HORIZONTAL_ALIGNMENT_CENTER
			sedit.add_theme_font_size_override("font_size", 10)
			
			sedit.text_submitted.connect((func(v, k):
				save_undo_state("Cambia Password Sistema")
				current_blueprint.set_drive_password(k, v)
				_refresh_software_panel()
			).bind(skey))
			row.add_child(sedit)
			
			var sdel := Button.new()
			sdel.text = "🗑️"
			sdel.tooltip_text = "Rimuovi password di sistema"
			sdel.pressed.connect((func(k):
				save_undo_state("Rimuovi Password Sistema")
				current_blueprint.remove_drive_password(k)
				_refresh_software_panel()
			).bind(skey))
			row.add_child(sdel)

func _create_right_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	
	var lbl_header := Label.new()
	lbl_header.text = "🔍 Inspector Proprietà"
	lbl_header.add_theme_font_size_override("font_size", 13)
	vbox.add_child(lbl_header)
	
	# ScrollContainer per Inspector Proprietà
	var scroll_insp := ScrollContainer.new()
	scroll_insp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_insp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll_insp)
	
	prop_container = VBoxContainer.new()
	prop_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prop_container.add_theme_constant_override("separation", 6)
	scroll_insp.add_child(prop_container)
	
	lbl_selected_title = Label.new()
	lbl_selected_title.text = "Nessun elemento selezionato"
	lbl_selected_title.add_theme_font_size_override("font_size", 12)
	prop_container.add_child(lbl_selected_title)
	
	prop_editor_vbox = VBoxContainer.new()
	prop_editor_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prop_container.add_child(prop_editor_vbox)
	
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
	lbl_status_stats.text = "0 Stanze | 0 Condotti | 0 Dispositivi | 0 Snodi | 0 Cablaggi | 0 Danni"
	hbox.add_child(lbl_status_stats)
	
	lbl_status_msg = Label.new()
	lbl_status_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_status_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_status_msg.text = "Pronto."
	hbox.add_child(lbl_status_msg)
	
	return bar

func _create_dialogs() -> void:
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.file_selected.connect(_on_file_dialog_file_selected)
	add_child(file_dialog)
	
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Ripristinare la blueprint ai valori di fabbrica Dark Nova Corvette?"
	confirm_dialog.confirmed.connect(_on_confirm_reset_default)
	add_child(confirm_dialog)
	
	confirm_random_dialog = ConfirmationDialog.new()
	confirm_random_dialog.dialog_text = "Generare un nuovo layout procedurale? L'attuale layout verrà sovrascritto."
	confirm_random_dialog.confirmed.connect(_on_confirm_random_generated)
	add_child(confirm_random_dialog)

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

func _on_canvas_action_committed(action_name: String) -> void:
	save_undo_state(action_name)
	_refresh_outliner()
	_refresh_software_panel()
	_update_stats_label()

func _on_canvas_tool_changed(new_tool: int) -> void:
	if opt_room_template:
		opt_room_template.visible = (new_tool == ShipBlueprintCanvas.ToolMode.ADD_ROOM)
		
	if new_tool == ShipBlueprintCanvas.ToolMode.SELECT and btn_select:
		btn_select.button_pressed = true
	
	# Sincronizza Menu Strumenti
	if tools_menu:
		var id: int = 0
		match new_tool:
			ShipBlueprintCanvas.ToolMode.SELECT: id = 0
			ShipBlueprintCanvas.ToolMode.ADD_ROOM: id = 1
			ShipBlueprintCanvas.ToolMode.ADD_DUCT: id = 2
			ShipBlueprintCanvas.ToolMode.DELETE: id = 3
		for i in range(4):
			tools_menu.set_item_checked(i, i == id)

func _update_stats_label() -> void:
	if not current_blueprint or not lbl_status_stats:
		return
		
	var all_devs_count := 0
	for r in current_blueprint.rooms:
		all_devs_count += (r.get("devices") as Array).size()
		
	lbl_status_stats.text = "%d Stanze | %d Condotti | %d Dispositivi | %d Danni | %d File | %d App" % [
		current_blueprint.rooms.size(),
		current_blueprint.ducts.size(),
		all_devs_count,
		current_blueprint.damages.size(),
		current_blueprint.drive_files.size(),
		current_blueprint.installed_apps.size()
	]

# --- PROPERTY INSPECTOR BUILDER (SUPPORTO PER TUTTI I LAYER E MODIFICA COMPLETA) ---

func _clear_prop_editor() -> void:
	for c in prop_editor_vbox.get_children():
		c.queue_free()

func _show_blueprint_metadata_props() -> void:
	_clear_prop_editor()
	if not current_blueprint:
		return
	lbl_selected_title.text = "Blueprint Astronave & Scafo"
	
	_add_string_field("ID Nave:", current_blueprint.ship_id, func(v):
		save_undo_state("Modifica ID Nave")
		current_blueprint.ship_id = v
	)
	_add_string_field("Nome Nave:", current_blueprint.ship_name, func(v):
		save_undo_state("Modifica Nome Nave")
		current_blueprint.ship_name = v
	)
	_add_string_field("Classe Nave:", current_blueprint.ship_class, func(v):
		save_undo_state("Modifica Classe Nave")
		current_blueprint.ship_class = v
	)
	
	# Limiti Scafo (Bounds)
	_add_rect2_field("Limiti Scafo (Pos X,Y / Dim W,H):", current_blueprint.ship_bounds, func(v: Rect2):
		save_undo_state("Modifica Limiti Scafo")
		current_blueprint.ship_bounds = v
		if canvas:
			canvas.queue_redraw()
	)
	
	_add_vector2_field("Spawn Drone (X, Y):", current_blueprint.drone_spawn_pos, func(v):
		save_undo_state("Modifica Spawn Drone")
		current_blueprint.drone_spawn_pos = v
		if canvas:
			canvas.queue_redraw()
	)
	_add_float_field("Heading Drone (Gradi):", rad_to_deg(current_blueprint.drone_spawn_heading), func(v):
		save_undo_state("Modifica Heading Drone")
		current_blueprint.drone_spawn_heading = deg_to_rad(v)
		if canvas:
			canvas.queue_redraw()
	)
	
	prop_editor_vbox.add_child(HSeparator.new())
	_add_int_field("Valore FLUX Nave:", current_blueprint.flux, func(v):
		save_undo_state("Modifica Flux")
		current_blueprint.flux = v
	)
	_add_flux_modifiers_editor()
	prop_editor_vbox.add_child(HSeparator.new())
	
func _populate_property_editor(elem_type: String, elem_id: String, elem_data: Variant) -> void:
	_clear_prop_editor()
	if elem_type.is_empty():
		_show_blueprint_metadata_props()
		return

	lbl_selected_title.text = "[%s] %s" % [elem_type.to_upper(), elem_id]
	
	match elem_type:
		"bounds":
			_show_blueprint_metadata_props()
			return

		"room":
			var room := current_blueprint.get_room_by_id(elem_id)
			if not room:
				return
			_add_string_field("ID Stanza:", str(room.id), func(v):
				save_undo_state("Rinomina Stanza")
				room.id = v
				canvas.selected_id = v
				current_blueprint.emit_changed()
			)
			_add_string_field("Nome Settore:", str(room.name), func(v):
				save_undo_state("Modifica Nome Stanza")
				room.name = v
				current_blueprint.emit_changed()
			)
			_add_string_field("Categoria:", str(room.category), func(v):
				save_undo_state("Modifica Categoria Stanza")
				room.category = v
				current_blueprint.emit_changed()
			)
			_add_bool_field("Alimentazione Attiva (Is On):", room.is_on, func(v):
				save_undo_state("Stato Alimentazione Stanza")
				room.is_on = v
				current_blueprint.recalculate_all_powers()
				canvas.queue_redraw()
			)
			
			var r_rect: Rect2 = room.rect
			_add_vector2_field("Posizione (X, Y):", r_rect.position, func(v):
				save_undo_state("Sposta Stanza")
				room.rect = Rect2(v, room.rect.size)
				current_blueprint.emit_changed()
				canvas.queue_redraw()
			)
			_add_vector2_field("Dimensioni (W, H):", r_rect.size, func(v):
				save_undo_state("Ridimensiona Stanza")
				room.rect = Rect2(room.rect.position, v)
				current_blueprint.emit_changed()
				canvas.queue_redraw()
			)
			_add_color_field("Colore Sfondo:", room.color, func(c):
				save_undo_state("Colore Stanza")
				room.color = c
				current_blueprint.emit_changed()
				canvas.queue_redraw()
			)
			_add_color_field("Colore Bordo:", room.border_color, func(c):
				save_undo_state("Colore Bordo Stanza")
				room.border_color = c
				current_blueprint.emit_changed()
				canvas.queue_redraw()
			)
			
			prop_editor_vbox.add_child(HSeparator.new())
			var dev_header := Label.new()
			dev_header.text = "⚡ Dispositivi in questa stanza:"
			prop_editor_vbox.add_child(dev_header)
			
			var room_devs := room.devices
			for i in range(room_devs.size()):
				var dev = room_devs[i]
				var d_h := HBoxContainer.new()
				var d_lbl := Label.new()
				d_lbl.text = "- %s (%.0f MW)" % [dev.name, dev.power_mw]
				d_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				d_lbl.add_theme_font_size_override("font_size", 10)
				d_h.add_child(d_lbl)
				
				var d_edit := Button.new()
				d_edit.text = "📝"
				d_edit.pressed.connect(func():
					canvas.selected_type = "device"
					canvas.selected_id = dev.id
					_populate_property_editor("device", canvas.selected_id, dev)
				)
				d_h.add_child(d_edit)
				
				var d_del := Button.new()
				d_del.text = "🗑️"
				d_del.pressed.connect((func(idx):
					save_undo_state("Rimuovi Dispositivo")
					room_devs.remove_at(idx)
					current_blueprint.emit_changed()
					_populate_property_editor("room", elem_id, elem_data)
				).bind(i))
				d_h.add_child(d_del)
				prop_editor_vbox.add_child(d_h)
				
			var btn_add_d := Button.new()
			btn_add_d.text = "+ Aggiungi Dispositivo"
			btn_add_d.pressed.connect(func():
				save_undo_state("Aggiungi Dispositivo")
				var new_dev_id := "dev_%d_%d" % [Time.get_ticks_msec(), room_devs.size()]
				var new_dev := ShipDeviceData.new(
					new_dev_id,
					"Nuovo Dispositivo",
					room.rect.get_center()
				)
				new_dev.category = "utility"
				new_dev.power_mw = -10.0
				new_dev.sector = room.name
				room_devs.append(new_dev)
				
				# Seleziona automaticamente il nuovo dispositivo e passa al suo inspector
				if canvas:
					canvas.selected_type = "device"
					canvas.selected_id = new_dev_id
					canvas.queue_redraw()
				
				current_blueprint.emit_changed()
				_populate_property_editor("device", new_dev_id, new_dev)
				_refresh_outliner()
			)
			prop_editor_vbox.add_child(btn_add_d)

		"duct":
			var duct := current_blueprint.get_duct_by_id(elem_id)
			if not duct:
				return
			_add_string_field("ID Condotto:", str(duct.id), func(v):
				save_undo_state("Rinomina Condotto")
				duct.id = v
				canvas.selected_id = v
				current_blueprint.emit_changed()
			)
			_add_string_field("Nome Condotto:", str(duct.name), func(v):
				save_undo_state("Modifica Nome Condotto")
				duct.name = v
				current_blueprint.emit_changed()
			)
			_add_vector2_field("Da Punto (X, Y):", duct.from, func(v):
				save_undo_state("Sposta Inizio Condotto")
				duct.from = v
				current_blueprint.emit_changed()
				canvas.queue_redraw()
			)
			_add_vector2_field("A Punto (X, Y):", duct.to, func(v):
				save_undo_state("Sposta Fine Condotto")
				duct.to = v
				current_blueprint.emit_changed()
				canvas.queue_redraw()
			)
			_add_float_field("Larghezza:", float(duct.width), func(v):
				save_undo_state("Larghezza Condotto")
				duct.width = v
				current_blueprint.emit_changed()
				canvas.queue_redraw()
			)
			_add_bool_field("Bloccato / Ostruito:", bool(duct.is_blocked), func(v):
				save_undo_state("Stato Blocco Condotto")
				duct.is_blocked = v
				current_blueprint.emit_changed()
				canvas.queue_redraw()
			)

		"device":
			var dev := current_blueprint.get_device_by_id(elem_id)
			if not dev:
				return
			_add_string_field("ID Dispositivo:", dev.id, func(v):
				save_undo_state("Rinomina Dispositivo")
				dev.id = v
				canvas.selected_id = v
				current_blueprint.emit_changed()
			)
			_add_string_field("Nome:", dev.name, func(v):
				save_undo_state("Modifica Nome Dispositivo")
				dev.name = v
				current_blueprint.emit_changed()
			)
			
			prop_editor_vbox.add_child(HSeparator.new())
			
			_add_option_field("Categoria:", dev.category, ShipBlueprint.DEVICE_CATEGORIES, func(v):
				save_undo_state("Modifica Categoria Dispositivo")
				dev.category = v
				current_blueprint.emit_changed()
			)
			_add_sector_selector_field("Settore:", dev.sector, func(v):
				save_undo_state("Modifica Settore Dispositivo")
				dev.sector = v
				current_blueprint.emit_changed()
			)
			
			prop_editor_vbox.add_child(HSeparator.new())
			
			_add_float_field("Potenza (MW):", dev.power_mw, func(v):
				save_undo_state("Modifica Potenza Dispositivo")
				dev.power_mw = v
				current_blueprint.recalculate_all_powers()
				canvas.queue_redraw()
			)
			
			prop_editor_vbox.add_child(HSeparator.new())
			
			_add_multiline_text_field("Descrizione:", dev.desc, func(v):
				save_undo_state("Modifica Descrizione Dispositivo")
				dev.desc = v
				current_blueprint.emit_changed()
			)


		"damage":
			var dmg := current_blueprint.get_damage_by_id(elem_id)
			if not dmg:
				return
			_add_string_field("ID Danno:", dmg.id, func(v):
				save_undo_state("Rinomina Danno")
				dmg.id = v
				canvas.selected_id = v
				current_blueprint.emit_changed()
			)
			_add_option_field("Tipo Danno:", dmg.type, [
				"breach", "fire", "electrical_short", "radiation_leak", "hull_crack", "system_failure", "coolant_leak"
			], func(v):
				save_undo_state("Tipo Danno")
				dmg.type = v
				current_blueprint.emit_changed()
				canvas.queue_redraw()
			)
			_add_string_field("Nome:", dmg.name, func(v):
				save_undo_state("Modifica Nome Danno")
				dmg.name = v
				current_blueprint.emit_changed()
			)
			_add_vector2_field("Posizione (X, Y):", dmg.pos, func(v):
				save_undo_state("Sposta Danno")
				dmg.pos = v
				current_blueprint.emit_changed()
				canvas.queue_redraw()
			)
			_add_sector_selector_field("Settore:", dmg.sector, func(v):
				save_undo_state("Modifica Settore Danno")
				dmg.sector = v
				current_blueprint.emit_changed()
			)
			_add_float_field("Gravità (Severity):", dmg.severity, func(v):
				save_undo_state("Modifica Gravità Danno")
				dmg.severity = v
				current_blueprint.emit_changed()
				canvas.queue_redraw()
			)
			_add_float_field("Costo Riparazione:", dmg.repair_cost, func(v):
				save_undo_state("Modifica Costo Riparazione Danno")
				dmg.repair_cost = v
				current_blueprint.emit_changed()
			)
			_add_option_field("Impatto Sistema:", dmg.system_impact, [
				"integrity_warning", "life_support_compromised", "power_conduit_cut", "weapons_offline", "shields_destabilized", "sensor_blind", "engines_disabled", "none"
			], func(v):
				save_undo_state("Impatto Sistema Danno")
				dmg.system_impact = v
				current_blueprint.emit_changed()
			)
			_add_multiline_text_field("Descrizione:", dmg.desc, func(v):
				save_undo_state("Descrizione Danno")
				dmg.desc = v
				current_blueprint.emit_changed()
			)

		"spawn":
			_add_vector2_field("Posizione Spawn Drone:", current_blueprint.drone_spawn_pos, func(v):
				save_undo_state("Sposta Spawn Drone")
				current_blueprint.drone_spawn_pos = v
				current_blueprint.emit_changed()
				canvas.queue_redraw()
			)
			_add_float_field("Heading Spawn (Gradi):", rad_to_deg(current_blueprint.drone_spawn_heading), func(v):
				save_undo_state("Heading Drone")
				current_blueprint.drone_spawn_heading = deg_to_rad(v)
				current_blueprint.emit_changed()
				canvas.queue_redraw()
			)
			
			# TASK-019: Selezione Stanza Ricarica
			var room_names: Array[String] = ["(Nessuna)"]
			var room_ids: Array[String] = [""]
			var current_sel_name := "(Nessuna)"
			
			for r in current_blueprint.rooms:
				var r_id: String = r.id
				var r_name: String = r.name if not r.name.is_empty() else r_id
				room_names.append(r_name)
				room_ids.append(r_id)
				if r_id == current_blueprint.recharge_room_id:
					current_sel_name = r_name
			
			_add_option_field("Stanza Ricarica Drone:", current_sel_name, room_names, func(new_name):
				save_undo_state("Cambia Stanza Ricarica")
				var idx := room_names.find(new_name)
				if idx >= 0:
					current_blueprint.recharge_room_id = room_ids[idx]
					canvas.queue_redraw()
			)

		"drive_file":
			var df := current_blueprint.get_drive_file_by_path(elem_id)
			if not df:
				return
			_add_string_field("Percorso File:", df.path, func(v):
				save_undo_state("Percorso File Drive")
				df.path = v
				current_blueprint.emit_changed()
				_refresh_outliner()
			)
			_add_bool_field("File Protetto (.dat):", df.is_protected, func(v):
				save_undo_state("Protezione File Drive")
				df.is_protected = v
				current_blueprint.emit_changed()
				_refresh_outliner()
			)
			_add_string_field("Descrizione:", df.desc, func(v):
				save_undo_state("Descrizione File Drive")
				df.desc = v
				current_blueprint.emit_changed()
			)
			_add_multiline_text_field("Contenuto File:", df.content, func(v):
				save_undo_state("Contenuto File Drive")
				df.content = v
				current_blueprint.emit_changed()
			)

		"installed_app":
			var app := current_blueprint.get_installed_app_by_id(elem_id)
			if not app:
				return
			_add_string_field("ID Applicazione:", app.id, func(v):
				save_undo_state("ID App Mainframe")
				app.id = v
				current_blueprint.emit_changed()
				_refresh_outliner()
				_refresh_software_panel()
			)
			_add_string_field("Titolo Menu:", app.title, func(v):
				save_undo_state("Titolo App Mainframe")
				app.title = v
				current_blueprint.emit_changed()
				_refresh_outliner()
				_refresh_software_panel()
			)
			_add_string_field("Descrizione:", app.description, func(v):
				save_undo_state("Descrizione App Mainframe")
				app.description = v
				current_blueprint.emit_changed()
			)
			_add_string_field("Percorso Scena (.tscn):", app.scene_path, func(v):
				save_undo_state("Scena App Mainframe")
				app.scene_path = v
				current_blueprint.emit_changed()
			)
			_add_color_field("Colore Icona:", app.icon_color, func(c):
				save_undo_state("Colore App Mainframe")
				app.icon_color = c
				current_blueprint.emit_changed()
			)
			_add_roles_editor(app)

	# Pulsante per eliminare l'elemento
	var btn_del_this := Button.new()
	btn_del_this.text = "🗑️ Elimina Questo Elemento"
	btn_del_this.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	btn_del_this.pressed.connect(func():
		save_undo_state("Elimina " + elem_type)
		if elem_type == "drive_file":
			current_blueprint.remove_drive_file(elem_id)
			_refresh_outliner()
			_update_stats_label()
			_show_blueprint_metadata_props()
		elif elem_type == "installed_app":
			current_blueprint.remove_installed_app(elem_id)
			_refresh_outliner()
			_refresh_software_panel()
			_update_stats_label()
			_show_blueprint_metadata_props()
		else:
			canvas.delete_element(elem_type, elem_id)
	)
	prop_editor_vbox.add_child(btn_del_this)

# --- HELPER CAMPI UI INSPECTOR ---

func _add_string_field(lbl: String, current_val: String, callback: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = lbl
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ed := LineEdit.new()
	ed.text = current_val
	ed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ed.text_submitted.connect(callback)
	ed.focus_exited.connect(func(): callback.call(ed.text))
	h.add_child(l)
	h.add_child(ed)
	prop_editor_vbox.add_child(h)

func _add_option_field(lbl: String, current_val: String, options: Array, callback: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = lbl
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var sel_idx := 0
	for i in range(options.size()):
		opt.add_item(options[i], i)
		if options[i] == current_val:
			sel_idx = i
	opt.select(sel_idx)
	opt.item_selected.connect(func(idx: int):
		callback.call(options[idx])
	)
	h.add_child(l)
	h.add_child(opt)
	prop_editor_vbox.add_child(h)

func _add_sector_selector_field(lbl: String, current_val: String, callback: Callable) -> void:
	var v_box := VBoxContainer.new()
	var l := Label.new()
	l.text = lbl
	v_box.add_child(l)
	
	var h := HBoxContainer.new()
	var ed := LineEdit.new()
	ed.text = current_val
	ed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ed.text_submitted.connect(callback)
	ed.focus_exited.connect(func(): callback.call(ed.text))
	h.add_child(ed)
	
	var opt := OptionButton.new()
	opt.text = "Scegli Settore..."
	opt.add_item("(Seleziona Stanza)", 0)
	var room_names: Array[String] = []
	if current_blueprint:
		for r in current_blueprint.rooms:
			var r_name: String = r.name if not r.name.is_empty() else r.id
			room_names.append(r_name)
			opt.add_item(r_name)
	opt.item_selected.connect(func(idx: int):
		if idx > 0 and idx - 1 < room_names.size():
			ed.text = room_names[idx - 1]
			callback.call(room_names[idx - 1])
	)
	h.add_child(opt)
	v_box.add_child(h)
	prop_editor_vbox.add_child(v_box)

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
	spin_x.prefix = "X: "
	spin_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var spin_y := SpinBox.new()
	spin_y.min_value = -9999.0
	spin_y.max_value = 9999.0
	spin_y.step = 5.0
	spin_y.value = current_val.y
	spin_y.prefix = "Y: "
	spin_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	spin_x.value_changed.connect(func(v: float): callback.call(Vector2(v, spin_y.value)))
	spin_y.value_changed.connect(func(v: float): callback.call(Vector2(spin_x.value, v)))
	
	h.add_child(spin_x)
	h.add_child(spin_y)
	v_box.add_child(h)
	prop_editor_vbox.add_child(v_box)

func _add_rect2_field(lbl: String, current_val: Rect2, callback: Callable) -> void:
	var v_box := VBoxContainer.new()
	var l := Label.new()
	l.text = lbl
	v_box.add_child(l)
	
	var h1 := HBoxContainer.new()
	var spin_x := SpinBox.new()
	spin_x.min_value = -9999.0
	spin_x.max_value = 9999.0
	spin_x.step = 5.0
	spin_x.value = current_val.position.x
	spin_x.prefix = "Pos X: "
	spin_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var spin_y := SpinBox.new()
	spin_y.min_value = -9999.0
	spin_y.max_value = 9999.0
	spin_y.step = 5.0
	spin_y.value = current_val.position.y
	spin_y.prefix = "Pos Y: "
	spin_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h1.add_child(spin_x)
	h1.add_child(spin_y)
	v_box.add_child(h1)
	
	var h2 := HBoxContainer.new()
	var spin_w := SpinBox.new()
	spin_w.min_value = 20.0
	spin_w.max_value = 9999.0
	spin_w.step = 5.0
	spin_w.value = current_val.size.x
	spin_w.prefix = "W: "
	spin_w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var spin_h := SpinBox.new()
	spin_h.min_value = 20.0
	spin_h.max_value = 9999.0
	spin_h.step = 5.0
	spin_h.value = current_val.size.y
	spin_h.prefix = "H: "
	spin_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h2.add_child(spin_w)
	h2.add_child(spin_h)
	v_box.add_child(h2)
	
	var update_rect := func():
		var r := Rect2(Vector2(spin_x.value, spin_y.value), Vector2(spin_w.value, spin_h.value))
		callback.call(r)
	
	spin_x.value_changed.connect(func(_v): update_rect.call())
	spin_y.value_changed.connect(func(_v): update_rect.call())
	spin_w.value_changed.connect(func(_v): update_rect.call())
	spin_h.value_changed.connect(func(_v): update_rect.call())
	
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

func _add_multiline_text_field(lbl: String, current_val: String, callback: Callable) -> void:
	var v_box := VBoxContainer.new()
	var l := Label.new()
	l.text = lbl
	v_box.add_child(l)
	
	var text_edit := TextEdit.new()
	text_edit.custom_minimum_size = Vector2(0, 120)
	text_edit.text = current_val
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.focus_exited.connect(func(): callback.call(text_edit.text))
	v_box.add_child(text_edit)
	prop_editor_vbox.add_child(v_box)

func _add_flux_modifiers_editor() -> void:
	if not current_blueprint:
		return
		
	var v_box := VBoxContainer.new()
	var l_main := Label.new()
	l_main.text = "Modificatori FLUX:"
	l_main.add_theme_color_override("font_color", Color.GOLD)
	v_box.add_child(l_main)
	
	var list_vbox := VBoxContainer.new()
	v_box.add_child(list_vbox)
	
	for i in range(current_blueprint.flux_modifiers.size()):
		var mod := current_blueprint.flux_modifiers[i]
		var h := HBoxContainer.new()
		
		var spin := SpinBox.new()
		spin.min_value = -1000
		spin.max_value = 1000
		spin.step = 1
		spin.value = mod.value
		spin.custom_minimum_size.x = 80
		spin.value_changed.connect((func(v, m: ShipFluxModifier):
			m.value = int(v)
			current_blueprint.emit_changed()
		).bind(mod))
		h.add_child(spin)
		
		var owner_edit := LineEdit.new()
		owner_edit.text = mod.owner
		owner_edit.placeholder_text = "Proprietario"
		owner_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var apply_owner := func(v: String, m: ShipFluxModifier):
			m.owner = v
			current_blueprint.emit_changed()
		owner_edit.text_submitted.connect(apply_owner.bind(mod))
		owner_edit.focus_exited.connect(func(): apply_owner.call(owner_edit.text, mod))
		h.add_child(owner_edit)
		
		var del_btn := Button.new()
		del_btn.text = "X"
		del_btn.modulate = Color.CRIMSON
		del_btn.pressed.connect((func(index):
			save_undo_state("Rimuovi Modificatore")
			current_blueprint.flux_modifiers.remove_at(index)
			current_blueprint.emit_changed()
			_show_blueprint_metadata_props()
		).bind(i))
		h.add_child(del_btn)
		list_vbox.add_child(h)
		
		var reason_edit := LineEdit.new()
		reason_edit.text = mod.reason
		reason_edit.placeholder_text = "Causale/Motivazione"
		reason_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var apply_reason := func(v: String, m: ShipFluxModifier):
			m.reason = v
			current_blueprint.emit_changed()
		reason_edit.text_submitted.connect(apply_reason.bind(mod))
		reason_edit.focus_exited.connect(func(): apply_reason.call(reason_edit.text, mod))
		list_vbox.add_child(reason_edit)
		list_vbox.add_child(HSeparator.new())
	
	var add_btn := Button.new()
	add_btn.text = "+ Aggiungi Modificatore"
	add_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_btn.pressed.connect(func():
		save_undo_state("Aggiungi Modificatore")
		current_blueprint.flux_modifiers.append(ShipFluxModifier.new(0, "Manuale", "Modificatore editor"))
		current_blueprint.emit_changed()
		_show_blueprint_metadata_props()
	)
	v_box.add_child(add_btn)
	
	prop_editor_vbox.add_child(v_box)

func _add_passwords_editor() -> void:
	if not current_blueprint:
		return
	var v_box := VBoxContainer.new()
	var l := Label.new()
	l.text = "Password Cartelle Ship Drive (%d registrate):" % current_blueprint.drive_passwords.size()
	v_box.add_child(l)
	
	for path in current_blueprint.drive_passwords.keys():
		var h := HBoxContainer.new()
		var lbl_p := Label.new()
		lbl_p.text = str(path).get_file() + ":"
		lbl_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ed_pwd := LineEdit.new()
		ed_pwd.text = str(current_blueprint.drive_passwords[path])
		ed_pwd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cur_path: String = str(path)
		var apply_pwd := func(v: String, cp: String):
			save_undo_state("Modifica Password " + cp)
			current_blueprint.drive_passwords[cp] = v
			current_blueprint.emit_changed()
		ed_pwd.text_submitted.connect(apply_pwd.bind(cur_path))
		ed_pwd.focus_exited.connect(func(): apply_pwd.call(ed_pwd.text, cur_path))
		var btn_del_pwd := Button.new()
		btn_del_pwd.text = "🗑️"
		btn_del_pwd.tooltip_text = "Rimuovi Password"
		btn_del_pwd.pressed.connect((func(cp):
			save_undo_state("Rimuovi Password")
			current_blueprint.remove_drive_password(cp)
			_show_blueprint_metadata_props()
		).bind(cur_path))
		h.add_child(lbl_p)
		h.add_child(ed_pwd)
		h.add_child(btn_del_pwd)
		v_box.add_child(h)
		
	var btn_add_p := Button.new()
	btn_add_p.text = "+ Aggiungi Nuova Password"
	btn_add_p.pressed.connect(_on_btn_add_drive_password_pressed)
	v_box.add_child(btn_add_p)
	
	prop_editor_vbox.add_child(v_box)

func _add_roles_editor(app: ShipAppMetadata) -> void:
	var v_box := VBoxContainer.new()
	var l := Label.new()
	l.text = "Ruoli Autorizzati (RBAC):"
	v_box.add_child(l)
	
	var ed_roles := LineEdit.new()
	var current_roles: Array[String] = app.roles
	var roles_str_arr: PackedStringArray = []
	for r in current_roles:
		roles_str_arr.append(str(r))
	ed_roles.text = ", ".join(roles_str_arr)
	ed_roles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var apply_roles := func(v: String):
		save_undo_state("Modifica Ruoli App")
		var parts := v.split(",")
		var new_arr: Array[String] = []
		for p in parts:
			var s := p.strip_edges()
			if not s.is_empty():
				new_arr.append(s)
		app.roles = new_arr
		current_blueprint.emit_changed()
	ed_roles.text_submitted.connect(apply_roles)
	ed_roles.focus_exited.connect(func(): apply_roles.call(ed_roles.text))
	v_box.add_child(ed_roles)
	prop_editor_vbox.add_child(v_box)

# --- OUTLINER TREE (GERARCHIA COMPLETA DI TUTTI I LAYER) ---

func _refresh_outliner() -> void:
	if not outliner_tree or not current_blueprint:
		return
	outliner_tree.clear()
	var root := outliner_tree.create_item()
	
	# Gruppo 0: Parametri Nave & Scafo
	var cat_hull := outliner_tree.create_item(root)
	cat_hull.set_text(0, "🚀 Scafo & Metadati Nave")
	cat_hull.set_metadata(0, {"type": "bounds", "id": "ship_bounds"})
	
	var item_spawn := outliner_tree.create_item(cat_hull)
	item_spawn.set_text(0, "🎯 Spawn Drone (Pos: %s)" % str(current_blueprint.drone_spawn_pos))
	item_spawn.set_metadata(0, {"type": "spawn", "id": "drone_spawn"})
	
	# Gruppo 1: Stanze e Settori
	var cat_rooms := outliner_tree.create_item(root)
	cat_rooms.set_text(0, "🔲 Stanze e Settori (%d)" % current_blueprint.rooms.size())
	for r in current_blueprint.rooms:
		var item := outliner_tree.create_item(cat_rooms)
		item.set_text(0, "[%s] %s" % [r.id, r.name])
		item.set_metadata(0, {"type": "room", "id": r.id})
		
	# Gruppo 2: Condotti di Manutenzione
	var cat_ducts := outliner_tree.create_item(root)
	cat_ducts.set_text(0, "🔧 Condotti di Manutenzione (%d)" % current_blueprint.ducts.size())
	for d in current_blueprint.ducts:
		var item := outliner_tree.create_item(cat_ducts)
		var blk := " [BLOCCATO]" if d.is_blocked else ""
		item.set_text(0, "[%s] %s%s" % [d.id, d.name, blk])
		item.set_metadata(0, {"type": "duct", "id": d.id})

	# Gruppo 3: Rete Elettrica
	var all_devices: Array[ShipDeviceData] = []
	for r in current_blueprint.rooms:
		all_devices.append_array(r.devices)
		
	var cat_power := outliner_tree.create_item(root)
	cat_power.set_text(0, "⚡ Rete Elettrica (%d Dispositivi)" % all_devices.size())
	
	# Sottogruppo Dispositivi
	for dev in all_devices:
		var item := outliner_tree.create_item(cat_power)
		var gen_tag := " [GEN %d MW]" % int(dev.power_mw) if dev.is_generator else ""
		item.set_text(0, "⚡ [%s] %s%s" % [dev.id, dev.name, gen_tag])
		item.set_metadata(0, {"type": "device", "id": dev.id})

	# Gruppo 4: Zone di Danno
	var cat_damages := outliner_tree.create_item(root)
	cat_damages.set_text(0, "💥 Zone di Danno (%d)" % current_blueprint.damages.size())
	for dmg in current_blueprint.damages:
		var item := outliner_tree.create_item(cat_damages)
		item.set_text(0, "💥 [%s] %s (%s, Sev: %d)" % [dmg.id, dmg.name, dmg.type, int(dmg.severity)])
		item.set_metadata(0, {"type": "damage", "id": dmg.id})

	# Gruppo 5: Ship Drive (File System & Password)
	var cat_drive := outliner_tree.create_item(root)
	cat_drive.set_text(0, "📁 Ship Drive File & Passwords (%d File)" % current_blueprint.drive_files.size())
	for df in current_blueprint.drive_files:
		var item := outliner_tree.create_item(cat_drive)
		var prot_tag := " 🔒" if df.is_protected else ""
		item.set_text(0, "📄 %s%s" % [df.path, prot_tag])
		item.set_metadata(0, {"type": "drive_file", "id": df.path})

	# Gruppo 6: Applicazioni Mainframe Installate
	var cat_apps := outliner_tree.create_item(root)
	cat_apps.set_text(0, "🖥️ Applicazioni Mainframe (%d App)" % current_blueprint.installed_apps.size())
	for app in current_blueprint.installed_apps:
		var item := outliner_tree.create_item(cat_apps)
		var app_id: String = app.id
		var app_title: String = app.title if not app.title.is_empty() else app_id
		item.set_text(0, "📱 %s (%s)" % [app_title, app_id])
		item.set_metadata(0, {"type": "installed_app", "id": app_id})

func _on_outliner_tree_item_selected() -> void:
	var selected_item := outliner_tree.get_selected()
	if not selected_item:
		return
	var meta = selected_item.get_metadata(0)
	if meta is Dictionary:
		var elem_type: String = str(meta.get("type", ""))
		var elem_id: String = str(meta.get("id", ""))
		if elem_type == "drive_file":
			canvas.selected_type = ""
			canvas.selected_id = ""
			var file_data := current_blueprint.get_drive_file_by_path(elem_id)
			_populate_property_editor(elem_type, elem_id, file_data)
			canvas.queue_redraw()
			return
		if elem_type == "installed_app":
			canvas.selected_type = ""
			canvas.selected_id = ""
			var app_data := current_blueprint.get_installed_app_by_id(elem_id)
			_populate_property_editor(elem_type, elem_id, app_data)
			canvas.queue_redraw()
			return
		if elem_type == "bounds":
			canvas.selected_type = "bounds"
			canvas.selected_id = "ship_bounds"
			_show_blueprint_metadata_props()
			canvas.queue_redraw()
			return
			
		canvas.selected_type = elem_type
		canvas.selected_id = elem_id
		var elem_data := canvas._get_selected_element_data()
		_populate_property_editor(elem_type, elem_id, elem_data)
		canvas.queue_redraw()

# --- AZIONI DI AGGIUNTA FILE / APP / PASSWORD ---

func _on_btn_add_drive_file_pressed() -> void:
	save_undo_state("Aggiungi File Drive")
	var next_idx := current_blueprint.drive_files.size() + 1
	var new_path := "Ship Drive/documents/doc_%d.txt" % next_idx
	current_blueprint.set_drive_file(new_path, "# Nuovo documento Dark Nova\n", false, "Documento utente")
	_refresh_outliner()
	_update_stats_label()
	_populate_property_editor("drive_file", new_path, current_blueprint.get_drive_file_by_path(new_path))
	_set_status_msg("File creato: %s" % new_path)

func _on_btn_add_drive_password_pressed() -> void:
	save_undo_state("Aggiungi Password")
	var path_key := "Ship Drive/Programs/SecureFolder_%d" % (current_blueprint.drive_passwords.size() + 1)
	current_blueprint.set_drive_password(path_key, "SEC-%04d" % randi_range(1000, 9999))
	_refresh_software_panel()
	_set_status_msg("Nuova password cartella creata.")

func _on_btn_add_damage_pressed() -> void:
	save_undo_state("Aggiungi Danno")
	var dmg_id := "dmg_%d" % Time.get_ticks_msec()
	var new_dmg := ShipDamageData.new(
		dmg_id,
		"Nuovo Danno",
		current_blueprint.ship_bounds.position + current_blueprint.ship_bounds.size / 2.0
	)
	new_dmg.type = "breach"
	new_dmg.severity = 5.0
	new_dmg.repair_cost = 20.0
	new_dmg.system_impact = "integrity_warning"
	new_dmg.desc = "Danno rilevato allo scafo."
	
	current_blueprint.damages.append(new_dmg)
	_refresh_outliner()
	_update_stats_label()
	_populate_property_editor("damage", dmg_id, new_dmg)
	_set_status_msg("Danno aggiunto: %s" % dmg_id)

func _on_btn_add_app_pressed() -> void:
	save_undo_state("Aggiungi App Mainframe")
	var next_idx := current_blueprint.installed_apps.size() + 1
	var app_id := "custom_app_%d" % next_idx
	var new_app := ShipAppMetadata.new(
		app_id,
		"Nuova App %d" % next_idx,
		""
	)
	new_app.description = "Applicazione personalizzata Dark Nova."
	new_app.icon_color = Color.CYAN
	new_app.roles = ["Capitano", "Stagista"]
	
	current_blueprint.set_installed_app(app_id, new_app)
	_refresh_outliner()
	_refresh_software_panel()
	_update_stats_label()
	_populate_property_editor("installed_app", app_id, new_app)
	_set_status_msg("App creata: %s" % app_id)

func _on_btn_install_software_pressed() -> void:
	_pending_file_action = "install_software"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = ["*.tres ; App Resources"]
	file_dialog.current_dir = "res://Applications/"
	file_dialog.popup_centered(Vector2i(700, 500))

# --- AZIONI TOOLBAR & SALVATAGGIO ---

func _on_btn_new_pressed() -> void:
	save_undo_state("Nuova Blueprint")
	var bp := ShipBlueprint.new()
	bp.create_default_ship()
	load_blueprint(bp, "")
	_set_status_msg("Nuova Blueprint creata.")

func _on_btn_random_pressed() -> void:
	if confirm_random_dialog:
		confirm_random_dialog.popup_centered()

func _on_confirm_random_generated() -> void:
	if not current_blueprint:
		return
	save_undo_state("Generazione Casuale")
	var grid_size := 20.0
	if canvas:
		grid_size = canvas.snap_grid_size
	current_blueprint.generate_random_layout(grid_size)
	_refresh_outliner()
	_refresh_software_panel()
	_update_stats_label()
	if canvas:
		canvas.reset_view()
		canvas.queue_redraw()
	_set_status_msg("Layout procedurale generato.")

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
		save_undo_state("Reset Default Blueprint")
		current_blueprint.create_default_ship()
		_save_to_path(DEFAULT_BLUEPRINT_PATH)
		_refresh_outliner()
		_refresh_software_panel()
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
		"install_software":
			if ResourceLoader.exists(path):
				var res: Resource = ResourceLoader.load(path)
				if res is AppResource:
					save_undo_state("Installa Software " + res.title)
					current_blueprint.install_app_resource(res)
					_refresh_software_panel()
					_refresh_outliner()
					_update_stats_label()
					_set_status_msg("Installata: %s" % res.title)
				else:
					_set_status_msg("Il file selezionato non è una risorsa AppResource valida.")
		"export_json":
			if current_blueprint:
				var err := current_blueprint.export_to_json(path)
				if err == OK:
					_set_status_msg("Esportato JSON: %s" % path)
				else:
					_set_status_msg("Errore esportazione JSON (codice %d)" % err)
		"import_json":
			if current_blueprint:
				save_undo_state("Import JSON")
				var err := current_blueprint.import_from_json(path)
				if err == OK:
					_refresh_outliner()
					_refresh_software_panel()
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
		_set_status_msg("Salvata con successo: %s" % path)
	else:
		_set_status_msg("Errore nel salvataggio della Blueprint (codice %d)" % err)
