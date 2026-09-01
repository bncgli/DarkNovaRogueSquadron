extends Control

## Titolo e dimensioni preferite per la finestra di GodotOS
const APP_TITLE: String = "ShipBuilder"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(1000, 700)

@onready var canvas: ShipBlueprintCanvas = %ShipBlueprintCanvas
@onready var inspector_container: VBoxContainer = %InspectorContainer
@onready var layer_list: VBoxContainer = %LayerList
@onready var tool_selector: OptionButton = %ToolSelector
@onready var room_list: OptionButton = %RoomList
@onready var status_label: Label = %StatusLabel
@onready var file_menu_btn: MenuButton = $MainLayout/TopToolbar/FileMenuBtn

var current_blueprint: ShipBlueprint = null

func _ready() -> void:
	_configure_window()
	_setup_canvas()
	_setup_ui()
	_setup_file_menu()
	_new_blueprint()

func _setup_file_menu() -> void:
	var popup = file_menu_btn.get_popup()
	popup.clear()
	popup.add_item("Nuovo", 2)
	popup.add_item("Salva", 0)
	popup.add_item("Carica", 1)
	if not popup.id_pressed.is_connected(_on_file_menu_id_pressed):
		popup.id_pressed.connect(_on_file_menu_id_pressed)

func _on_file_menu_id_pressed(id: int) -> void:
	match id:
		0: _on_save_pressed()
		1: _on_load_pressed()
		2: _on_new_pressed()

func _configure_window() -> void:
	custom_minimum_size = DEFAULT_WINDOW_SIZE
	var parent_window = get_parent()
	if parent_window and "window_title" in parent_window:
		parent_window.window_title = APP_TITLE

func _setup_canvas() -> void:
	canvas.element_selected.connect(_on_element_selected)
	canvas.element_modified.connect(_on_element_modified)
	canvas.tool_changed.connect(_on_canvas_tool_changed)
	canvas.cursor_coords_changed.connect(_on_cursor_coords_changed)

func _setup_ui() -> void:
	# Setup tool selector
	tool_selector.clear()
	tool_selector.add_item("Select", ShipBlueprintCanvas.ToolMode.SELECT)
	tool_selector.add_item("Add Room", ShipBlueprintCanvas.ToolMode.ADD_ROOM)
	tool_selector.add_item("Add Duct", ShipBlueprintCanvas.ToolMode.ADD_DUCT)
	tool_selector.add_item("Delete", ShipBlueprintCanvas.ToolMode.DELETE)
	tool_selector.item_selected.connect(_on_tool_selected)
	
	# Setup room list from RoomDatabase
	room_list.clear()
	for room_id in RoomDatabase.get_room_ids():
		room_list.add_item(RoomDatabase.get_room_name(room_id))
		room_list.set_item_metadata(room_list.get_item_count() - 1, room_id)
	room_list.item_selected.connect(_on_room_template_selected)
	if room_list.get_item_count() > 0:
		canvas.selected_room_template = room_list.get_item_metadata(0)
	
	# Setup Layer Visibility Checkboxes
	_add_layer_checkbox("Rooms", "show_rooms")
	_add_layer_checkbox("Ducts", "show_ducts")
	_add_layer_checkbox("Spawn", "show_spawn")
	_add_layer_checkbox("Bounds", "show_bounds")
	_add_layer_checkbox("Grid", "show_grid")
	_add_layer_checkbox("Labels", "show_labels")

func _add_layer_checkbox(label_text: String, property: String) -> void:
	var cb := CheckBox.new()
	cb.text = label_text
	cb.button_pressed = canvas.get(property)
	cb.toggled.connect(func(pressed): canvas.set(property, pressed))
	layer_list.add_child(cb)

func _new_blueprint() -> void:
	current_blueprint = ShipBlueprint.new()
	current_blueprint.create_default_ship()
	canvas.blueprint = current_blueprint
	_update_status("New blueprint created.")

func _on_new_pressed() -> void:
	_new_blueprint()
	_rebuild_inspector("", "", {})

func _on_tool_selected(index: int) -> void:
	var mode = tool_selector.get_item_id(index)
	canvas.current_tool = mode

func _on_room_template_selected(index: int) -> void:
	var room_id = room_list.get_item_metadata(index)
	canvas.selected_room_template = room_id

func _on_canvas_tool_changed(new_tool: int) -> void:
	for i in range(tool_selector.get_item_count()):
		if tool_selector.get_item_id(i) == new_tool:
			tool_selector.select(i)
			break

func _on_element_selected(type: String, id: String, data: Dictionary) -> void:
	_rebuild_inspector(type, id, data)

func _on_element_modified(type: String, id: String, data: Dictionary) -> void:
	_rebuild_inspector(type, id, data)

func _on_cursor_coords_changed(world_pos: Vector2) -> void:
	_update_status("Coords: %s" % str(world_pos))

func _rebuild_inspector(type: String, id: String, data: Dictionary) -> void:
	for child in inspector_container.get_children():
		child.queue_free()
	
	if type.is_empty():
		_rebuild_ship_inspector()
		return
	
	var title := Label.new()
	title.text = "%s: %s" % [type.capitalize(), id]
	title.add_theme_font_size_override("font_size", 16)
	inspector_container.add_child(title)
	inspector_container.add_child(HSeparator.new())
	
	if type == "room":
		var room = current_blueprint.get_room_by_id(id)
		var lbl_w := Label.new()
		lbl_w.text = "Power Consumption: %.2f MW" % float(room.get("power_mw", 0.0))
		lbl_w.add_theme_color_override("font_color", Color.YELLOW)
		inspector_container.add_child(lbl_w)
		inspector_container.add_child(HSeparator.new())
	
	for key in data.keys():
		if key == "id" or key == "devices": continue
		
		var hbx := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = key.capitalize()
		lbl.custom_minimum_size.x = 80
		hbx.add_child(lbl)
		
		var val = data[key]
		if val is String:
			if key == "category":
				var opt := OptionButton.new()
				var cats = ShipBlueprint.DEVICE_CATEGORIES
				for c in cats:
					opt.add_item(c.capitalize())
				var idx = cats.find(val)
				if idx != -1: opt.select(idx)
				opt.item_selected.connect(func(i): _update_element_property(type, id, key, cats[i]))
				opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hbx.add_child(opt)
			else:
				var edit := LineEdit.new()
				edit.text = val
				edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				edit.text_submitted.connect(func(new_text): _update_element_property(type, id, key, new_text))
				hbx.add_child(edit)
		elif val is float or val is int:
			var spin := SpinBox.new()
			spin.allow_greater = true
			spin.allow_lesser = true
			spin.value = float(val)
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.value_changed.connect(func(new_val): _update_element_property(type, id, key, new_val))
			hbx.add_child(spin)
		elif val is Color:
			var picker := ColorPickerButton.new()
			picker.color = val
			picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			picker.color_changed.connect(func(new_col): _update_element_property(type, id, key, new_col))
			hbx.add_child(picker)
		elif val is Rect2:
			var v_hbx := VBoxContainer.new()
			v_hbx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var pos_hbx := HBoxContainer.new()
			var sx := SpinBox.new(); sx.value = val.position.x; sx.prefix = "X:"
			var sy := SpinBox.new(); sy.value = val.position.y; sy.prefix = "Y:"
			pos_hbx.add_child(sx); pos_hbx.add_child(sy)
			var size_hbx := HBoxContainer.new()
			var sw := SpinBox.new(); sw.value = val.size.x; sw.prefix = "W:"
			var sh := SpinBox.new(); sh.value = val.size.y; sh.prefix = "H:"
			size_hbx.add_child(sw); size_hbx.add_child(sh)
			v_hbx.add_child(pos_hbx); v_hbx.add_child(size_hbx)
			hbx.add_child(v_hbx)
			
			sx.value_changed.connect(func(v): _update_element_property(type, id, key, Rect2(Vector2(v, sy.value), Vector2(sw.value, sh.value))))
			sy.value_changed.connect(func(v): _update_element_property(type, id, key, Rect2(Vector2(sx.value, v), Vector2(sw.value, sh.value))))
			sw.value_changed.connect(func(v): _update_element_property(type, id, key, Rect2(val.position, Vector2(v, sh.value))))
			sh.value_changed.connect(func(v): _update_element_property(type, id, key, Rect2(val.position, Vector2(sw.value, v))))
		elif val is Vector2:
			var v_hbx := HBoxContainer.new()
			v_hbx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var sx := SpinBox.new(); sx.value = val.x; sx.prefix = "X:"
			var sy := SpinBox.new(); sy.value = val.y; sy.prefix = "Y:"
			sx.value_changed.connect(func(v): _update_element_property(type, id, key, Vector2(v, sy.value)))
			sy.value_changed.connect(func(v): _update_element_property(type, id, key, Vector2(sx.value, v)))
			v_hbx.add_child(sx); v_hbx.add_child(sy)
			hbx.add_child(v_hbx)
		
		inspector_container.add_child(hbx)
	
	if type == "room":
		inspector_container.add_child(HSeparator.new())
		var dev_lbl := Label.new()
		dev_lbl.text = "Devices:"
		inspector_container.add_child(dev_lbl)
		
		var room = current_blueprint.get_room_by_id(id)
		var devs: Array = room.get("devices", [])
		for i in range(devs.size()):
			var dev = devs[i]
			var dev_hbx := HBoxContainer.new()
			var dev_name := Label.new()
			dev_name.text = "- %s (%.0f MW)" % [dev.get("name", "Unknown"), dev.get("power_mw", 0.0)]
			dev_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			dev_hbx.add_child(dev_name)
			
			var btn_del := Button.new()
			btn_del.text = "X"
			btn_del.pressed.connect(func():
				devs.remove_at(i)
				current_blueprint.update_room_power(id)
				_rebuild_inspector(type, id, room)
			)
			dev_hbx.add_child(btn_del)
			inspector_container.add_child(dev_hbx)
			
		var btn_add := Button.new()
		btn_add.text = "Add Device"
		btn_add.pressed.connect(func():
			devs.append({
				"id": "new_dev_" + str(devs.size()),
				"name": "New Device",
				"power_mw": -50.0,
				"category": "utility"
			})
			current_blueprint.update_room_power(id)
			_rebuild_inspector(type, id, room)
		)
		inspector_container.add_child(btn_add)

func _rebuild_ship_inspector() -> void:
	var title := Label.new()
	title.text = "Ship Blueprint"
	title.add_theme_font_size_override("font_size", 16)
	inspector_container.add_child(title)
	inspector_container.add_child(HSeparator.new())
	
	var fields = [
		{"name": "ship_id", "label": "Ship ID"},
		{"name": "ship_name", "label": "Ship Name"},
		{"name": "ship_class", "label": "Category"},
		{"name": "ship_mesh_path", "label": "Mesh Path"}
	]
	
	for field in fields:
		var hbx := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = field.label
		lbl.custom_minimum_size.x = 80
		hbx.add_child(lbl)
		
		if field.name == "ship_class":
			var opt := OptionButton.new()
			var classes = ShipBlueprint.SHIP_CLASSES
			for c in classes:
				opt.add_item(c)
			var cur_val = str(current_blueprint.get(field.name))
			var idx = classes.find(cur_val)
			if idx != -1: opt.select(idx)
			opt.item_selected.connect(func(i): 
				current_blueprint.set(field.name, classes[i])
				current_blueprint.emit_changed()
			)
			opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbx.add_child(opt)
		else:
			var edit := LineEdit.new()
			edit.text = str(current_blueprint.get(field.name))
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.text_submitted.connect(func(new_text): 
				current_blueprint.set(field.name, new_text)
				current_blueprint.emit_changed()
			)
			hbx.add_child(edit)
			
			if field.name == "ship_mesh_path":
				var btn_browse := Button.new()
				btn_browse.text = "..."
				btn_browse.pressed.connect(func():
					var fd := FileDialog.new()
					fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
					fd.access = FileDialog.ACCESS_RESOURCES
					fd.filters = PackedStringArray(["*.tres ; Resource", "*.obj ; Wavefront OBJ", "*.scn ; Scene"])
					fd.file_selected.connect(func(path):
						edit.text = path
						current_blueprint.set(field.name, path)
						current_blueprint.emit_changed()
						fd.queue_free()
					)
					fd.close_requested.connect(fd.queue_free)
					add_child(fd)
					fd.popup_centered(Vector2(600, 400))
				)
				hbx.add_child(btn_browse)
		inspector_container.add_child(hbx)

func _update_element_property(type: String, id: String, key: String, value: Variant) -> void:
	if not current_blueprint: return
	var elem = {}
	match type:
		"room": elem = current_blueprint.get_room_by_id(id)
		"duct": elem = current_blueprint.get_duct_by_id(id)
		"damage": elem = current_blueprint.get_damage_by_id(id)
		"device": elem = current_blueprint.get_device_by_id(id)
	
	if not elem.is_empty():
		elem[key] = value
		if type == "device" and key == "power_mw":
			current_blueprint.recalculate_all_powers()
		current_blueprint.emit_changed()
		canvas.queue_redraw()

func _update_status(msg: String) -> void:
	status_label.text = msg

func _on_save_pressed() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.tres ; Godot Resource"])
	
	var base_dir = "user://files/Terminal Drive/Programs/ShipBuilder"
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)
	fd.current_dir = base_dir
	
	fd.file_selected.connect(func(path):
		var err = ResourceSaver.save(current_blueprint, path)
		if err == OK:
			_update_status("Saved to %s" % path.get_file())
		else:
			_update_status("Save failed: %d" % err)
		fd.queue_free()
	)
	fd.close_requested.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered(Vector2(700, 500))

func _on_load_pressed() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.tres ; Godot Resource"])
	fd.current_dir = "user://files/Terminal Drive/Programs/ShipBuilder"
	
	fd.file_selected.connect(func(path):
		var res = load(path)
		if res is ShipBlueprint:
			current_blueprint = res
			canvas.blueprint = current_blueprint
			_rebuild_inspector("", "", {})
			_update_status("Loaded %s" % path.get_file())
		else:
			_update_status("Load failed: Not a ShipBlueprint.")
		fd.queue_free()
	)
	fd.close_requested.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered(Vector2(700, 500))

func _on_software_pressed() -> void:
	var window = Window.new()
	window.title = "Software Manager"
	window.size = Vector2(600, 450)
	window.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	window.close_requested.connect(window.queue_free)
	
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.add_child(panel)
	
	var hbx = HBoxContainer.new()
	panel.add_child(hbx)
	
	var market_vb = VBoxContainer.new()
	market_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl_m = Label.new(); lbl_m.text = "Marketplace (Available)"; market_vb.add_child(lbl_m)
	var market_list = ItemList.new()
	market_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	market_vb.add_child(market_list)
	hbx.add_child(market_vb)
	
	var mid_vb = VBoxContainer.new()
	mid_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	var btn_add = Button.new(); btn_add.text = " Install >> "
	var btn_rem = Button.new(); btn_rem.text = " << Uninstall "
	mid_vb.add_child(btn_add); mid_vb.add_child(btn_rem)
	hbx.add_child(mid_vb)
	
	var inst_vb = VBoxContainer.new()
	inst_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl_i = Label.new(); lbl_i.text = "Installed Software"; inst_vb.add_child(lbl_i)
	var inst_list = ItemList.new()
	inst_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inst_vb.add_child(inst_list)
	hbx.add_child(inst_vb)
	
	var refresh_lists = func():
		market_list.clear()
		inst_list.clear()
		var all_apps = []
		if Engine.has_singleton("ShipSoftwareManager"):
			all_apps = Engine.get_singleton("ShipSoftwareManager").get_all_registered_apps()
		elif get_node_or_null("/root/ShipSoftwareManager"):
			all_apps = get_node("/root/ShipSoftwareManager").get_all_registered_apps()
			
		var installed_ids = []
		for app in current_blueprint.installed_apps:
			installed_ids.append(app.get("id"))
			inst_list.add_item(app.get("title", app.get("id")))
			inst_list.set_item_metadata(inst_list.get_item_count() - 1, app.get("id"))
			
		for app in all_apps:
			if not app.app_id in installed_ids:
				market_list.add_item(app.title)
				market_list.set_item_metadata(market_list.get_item_count() - 1, app.app_id)
				
	refresh_lists.call()
	
	btn_add.pressed.connect(func():
		var sel = market_list.get_selected_items()
		if sel.size() > 0:
			var app_id = market_list.get_item_metadata(sel[0])
			var app_res = null
			if get_node_or_null("/root/ShipSoftwareManager"):
				app_res = get_node("/root/ShipSoftwareManager").get_registered_app(app_id)
			if app_res:
				current_blueprint.install_app_resource(app_res)
				refresh_lists.call()
	)
	
	btn_rem.pressed.connect(func():
		var sel = inst_list.get_selected_items()
		if sel.size() > 0:
			var app_id = inst_list.get_item_metadata(sel[0])
			current_blueprint.uninstall_app_by_id(app_id)
			refresh_lists.call()
	)
	
	add_child(window)
	window.popup()

func _on_drive_files_pressed() -> void:
	var window = Window.new()
	window.title = "Drive Files"
	window.size = Vector2(500, 400)
	window.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	window.close_requested.connect(window.queue_free)
	
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.add_child(panel)
	
	var vb = VBoxContainer.new()
	panel.add_child(vb)
	
	var tree = Tree.new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(tree)
	
	var root = tree.create_item()
	tree.hide_root = true
	var drive = tree.create_item(root)
	drive.set_text(0, "Ship Drive")
	
	for file in current_blueprint.drive_files:
		var item = tree.create_item(drive)
		item.set_text(0, file.get("path", "unnamed"))
	
	var btn_hbx = HBoxContainer.new()
	var btn_new = Button.new(); btn_new.text = "New File"
	var btn_del = Button.new(); btn_del.text = "Delete"
	btn_hbx.add_child(btn_new); btn_hbx.add_child(btn_del)
	vb.add_child(btn_hbx)
	
	add_child(window)
	window.popup()
