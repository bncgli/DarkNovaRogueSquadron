extends MarginContainer

## The start menu in the taskbar. Handles showing and hiding the start menu.

@onready var start_menu: Panel = $"../../StartMenuAnchor/Start Menu"
@onready var scroll_container: ScrollContainer = $"../../StartMenuAnchor/Start Menu/ScrollContainer" if has_node("../../StartMenuAnchor/Start Menu/ScrollContainer") else null
@onready var vbox_container: VBoxContainer = ($"../../StartMenuAnchor/Start Menu/ScrollContainer/VBoxContainer" if has_node("../../StartMenuAnchor/Start Menu/ScrollContainer/VBoxContainer") else $"../../StartMenuAnchor/Start Menu/VBoxContainer") as VBoxContainer

var is_mouse_over_menu: bool
var is_mouse_over: bool
var _dynamic_ship_app_nodes: Array[Control] = []
var _open_submenus: Array[Panel] = []

func _ready() -> void:
	add_to_group("start_button_controller")
	if start_menu:
		start_menu.add_to_group("start_menu_panels")
	_connect_system_signals()
	_refresh_ship_apps.call_deferred()

func _exit_tree() -> void:
	_disconnect_system_signals()

func _connect_system_signals() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_signal("ship_connection_changed"):
		if not SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
	
	var ssm := get_node_or_null("/root/ShipSoftwareManager")
	if ssm:
		if ssm.has_signal("mission_started") and not ssm.mission_started.is_connected(_on_software_mission_started):
			ssm.mission_started.connect(_on_software_mission_started)
		if ssm.has_signal("mission_ended") and not ssm.mission_ended.is_connected(_on_software_mission_ended):
			ssm.mission_ended.connect(_on_software_mission_ended)
		if ssm.has_signal("role_changed") and not ssm.role_changed.is_connected(_on_software_role_changed):
			ssm.role_changed.connect(_on_software_role_changed)
		if ssm.has_signal("registry_changed") and not ssm.registry_changed.is_connected(_on_software_registry_changed):
			ssm.registry_changed.connect(_on_software_registry_changed)
	
	var tsm := get_node_or_null("/root/TerminalSoftwareManager")
	if tsm:
		if tsm.has_signal("registry_changed") and not tsm.registry_changed.is_connected(_on_software_registry_changed):
			tsm.registry_changed.connect(_on_software_registry_changed)
	
	var nm := _get_net_mgr()
	if nm:
		if nm.has_signal("mission_started") and not nm.mission_started.is_connected(_on_mission_started):
			nm.mission_started.connect(_on_mission_started)
		if nm.has_signal("game_launched") and not nm.game_launched.is_connected(_on_mission_started):
			nm.game_launched.connect(_on_mission_started)
		if nm.has_signal("mission_ended") and not nm.mission_ended.is_connected(_on_mission_ended):
			nm.mission_ended.connect(_on_mission_ended)
		if nm.has_signal("player_role_changed") and not nm.player_role_changed.is_connected(_on_player_role_changed):
			nm.player_role_changed.connect(_on_player_role_changed)
		if nm.has_signal("connection_state_changed") and not nm.connection_state_changed.is_connected(_on_connection_state_changed):
			nm.connection_state_changed.connect(_on_connection_state_changed)
		if nm.has_signal("lobby_updated") and not nm.lobby_updated.is_connected(_on_lobby_updated):
			nm.lobby_updated.connect(_on_lobby_updated)

func _disconnect_system_signals() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_signal("ship_connection_changed"):
		if SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.disconnect(_on_ship_connection_changed)
	
	var ssm := get_node_or_null("/root/ShipSoftwareManager")
	if ssm:
		if ssm.has_signal("mission_started") and ssm.mission_started.is_connected(_on_software_mission_started):
			ssm.mission_started.disconnect(_on_software_mission_started)
		if ssm.has_signal("mission_ended") and ssm.mission_ended.is_connected(_on_software_mission_ended):
			ssm.mission_ended.disconnect(_on_software_mission_ended)
		if ssm.has_signal("role_changed") and ssm.role_changed.is_connected(_on_software_role_changed):
			ssm.role_changed.disconnect(_on_software_role_changed)
		if ssm.has_signal("registry_changed") and ssm.registry_changed.is_connected(_on_software_registry_changed):
			ssm.registry_changed.disconnect(_on_software_registry_changed)
	
	var tsm := get_node_or_null("/root/TerminalSoftwareManager")
	if tsm:
		if tsm.has_signal("registry_changed") and tsm.registry_changed.is_connected(_on_software_registry_changed):
			tsm.registry_changed.disconnect(_on_software_registry_changed)
	
	var nm := _get_net_mgr()
	if nm:
		if nm.has_signal("mission_started") and nm.mission_started.is_connected(_on_mission_started):
			nm.mission_started.disconnect(_on_mission_started)
		if nm.has_signal("game_launched") and nm.game_launched.is_connected(_on_mission_started):
			nm.game_launched.disconnect(_on_mission_started)
		if nm.has_signal("mission_ended") and nm.mission_ended.is_connected(_on_mission_ended):
			nm.mission_ended.disconnect(_on_mission_ended)
		if nm.has_signal("player_role_changed") and nm.player_role_changed.is_connected(_on_player_role_changed):
			nm.player_role_changed.disconnect(_on_player_role_changed)
		if nm.has_signal("connection_state_changed") and nm.connection_state_changed.is_connected(_on_connection_state_changed):
			nm.connection_state_changed.disconnect(_on_connection_state_changed)
		if nm.has_signal("lobby_updated") and nm.lobby_updated.is_connected(_on_lobby_updated):
			nm.lobby_updated.disconnect(_on_lobby_updated)

func _get_net_mgr() -> Node:
	return get_node_or_null("/root/NetworkManager")

func _on_ship_connection_changed(_is_connected: bool) -> void:
	_refresh_ship_apps()

func _on_software_mission_started(_role: String, _is_solo: bool) -> void:
	_refresh_ship_apps()

func _on_software_mission_ended() -> void:
	_refresh_ship_apps()

func _on_software_role_changed(_new_role: String) -> void:
	_refresh_ship_apps()

func _on_software_registry_changed() -> void:
	_refresh_ship_apps()

func _on_mission_started(_role: String = "", _is_solo: bool = false) -> void:
	_refresh_ship_apps()

func _on_mission_ended() -> void:
	_refresh_ship_apps()

func _on_player_role_changed(_peer_id: int, _role: String) -> void:
	_refresh_ship_apps()

func _on_connection_state_changed(_is_connected: bool, _is_host: bool = false) -> void:
	_refresh_ship_apps()

func _on_lobby_updated(_players: Dictionary) -> void:
	_refresh_ship_apps()

## Aggiorna le applicazioni della nave mostrate nel menu Start in base allo stato di connessione e al ruolo
func _refresh_ship_apps() -> void:
	if not is_inside_tree() or not vbox_container:
		return
	
	# Rimuovi opzioni dinamiche precedenti
	for node in _dynamic_ship_app_nodes:
		if is_instance_valid(node):
			if node.get_parent():
				node.get_parent().remove_child(node)
			node.queue_free()
	_dynamic_ship_app_nodes.clear()
	
	var apps: Array = []
	var seen_ids: Dictionary = {}
	var seen_paths: Dictionary = {}
	
	# Mappa i nodi statici già presenti nel VBoxContainer per evitare duplicati
	for child in vbox_container.get_children():
		if child is Control and not child.is_in_group("dynamic_ship_apps"):
			var app_path := str(child.get("application_scene"))
			var game_path := str(child.get("game_scene"))
			if not app_path.is_empty(): seen_paths[app_path] = true
			if not game_path.is_empty(): seen_paths[game_path] = true
	
	# 1. Carica Local Terminal Apps (sempre visibili se registrate)
	var tsm := get_node_or_null("/root/TerminalSoftwareManager")
	if tsm:
		var term_apps: Array = tsm.get_all_registered_apps()
		for app_res in term_apps:
			var d: Dictionary = app_res.to_dict()
			d["is_ship_app"] = false
			var app_id: String = d.get("id")
			var s_path: Variant = d.get("scene_path")
			if not app_id.is_empty() and not seen_ids.has(app_id) and not seen_paths.has(s_path):
				apps.append(d)
				seen_ids[app_id] = true
				if not s_path.is_empty(): seen_paths[s_path] = true

	# 2. Verifica se la connessione alla nave / missione è attiva per aggiungere Ship Apps
	var is_active: bool = false
	var nm := _get_net_mgr()
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		is_active = SpaceWorldManager.is_ship_connected()
	elif nm and nm.has_method("is_ship_connected"):
		is_active = nm.is_ship_connected()
	
	var ssm := get_node_or_null("/root/ShipSoftwareManager")
	if not is_active and ssm and ssm.get("is_mission_active"):
		is_active = true
	
	if is_active:
		var my_role: String = ""
		var is_solo: bool = false
		
		if ssm and not ssm.current_role.is_empty():
			my_role = ssm.current_role
			is_solo = ssm.is_solo_mode
		elif nm:
			my_role = nm.get_local_player_role()
			is_solo = nm.is_solo_mode
		
		var ship_apps: Array = []
		if ssm and ssm.has_method("get_apps_for_role"):
			var app_resources: Array = ssm.get_apps_for_role(my_role, is_solo)
			for r in app_resources:
				if r is Resource and r.has_method("to_dict"):
					var item: Dictionary = r.to_dict()
					item["is_ship_app"] = true
					ship_apps.append(item)
				elif r is Dictionary:
					var item := (r as Dictionary).duplicate(true)
					item["is_ship_app"] = true
					ship_apps.append(item)
		elif SpaceWorldManager and SpaceWorldManager.has_method("get_installed_apps_for_role"):
			for a in SpaceWorldManager.get_installed_apps_for_role(my_role, is_solo):
				var item: Dictionary = a.to_dict() if (a is Resource and a.has_method("to_dict")) else (a as Dictionary if a is Dictionary else {})
				item["is_ship_app"] = true
				ship_apps.append(item)
		elif SpaceWorldManager and SpaceWorldManager.has_method("get_ship_blueprint"):
			var bp: ShipBlueprint = SpaceWorldManager.get_ship_blueprint()
			if bp:
				for a in bp.get_apps_for_role(my_role, is_solo):
					var item: Dictionary = a.to_dict()
					item["is_ship_app"] = true
					ship_apps.append(item)
		
		# Fallback su default blueprint se lista vuota ma sessione attiva
		if ship_apps.is_empty():
			var def_bp := ShipBlueprint.get_default_blueprint()
			if def_bp:
				for a in def_bp.get_apps_for_role(my_role, is_solo):
					var item: Dictionary = a.to_dict()
					item["is_ship_app"] = true
					ship_apps.append(item)
		
		for app in ship_apps:
			var app_id: String = app.get("id")
			var s_path: Variant = app.get("scene_path")
			if not app_id.is_empty() and not seen_ids.has(app_id) and not seen_paths.has(s_path):
				apps.append(app)
				seen_ids[app_id] = true
				if not s_path.is_empty(): seen_paths[s_path] = true
	
	if true: # Invece di 'if is_active', ora usiamo sempre la lista apps popolata
		var root_tree := {"subfolders": {}, "apps": []}
		for app in apps:
			var path := str(app.get("menu_path")).strip_edges()
			
			var current := root_tree
			if not path.is_empty():
				var parts := path.split("/")
				for part in parts:
					part = part.strip_edges()
					if part.is_empty(): continue
					if not current["subfolders"].has(part):
						current["subfolders"][part] = {"subfolders": {}, "apps": []}
					current = current["subfolders"][part]
			current["apps"].append(app)
		
		var insert_idx := 0
		_render_menu_tree(vbox_container, root_tree, 0, insert_idx, start_menu)
	
	_update_start_menu_size()
	if start_menu and start_menu.position.y < 0:
		start_menu.position.y = -start_menu.size.y - 5.0

func _update_start_menu_size() -> void:
	if not start_menu or not vbox_container:
		return
	
	var visible_rows := _count_visible_rows(vbox_container)

	var vp_height: float = 720.0
	if is_inside_tree():
		var vp := get_viewport()
		if vp:
			vp_height = vp.get_visible_rect().size.y
	var max_allowed_height: float = maxf(vp_height - 60.0, 200.0)
	var desired_height: float = clampf(float(visible_rows) * 49.0 + 55.0, 200.0, max_allowed_height)
	start_menu.size.y = desired_height
	
	# Se il menu è già visibile, aggiorna la posizione Y per farlo crescere verso l'alto
	if start_menu.position.y < 0:
		start_menu.position.y = -start_menu.size.y - 5.0

func _count_visible_rows(container: Control) -> int:
	var count := 0
	for child in container.get_children():
		if child is Control and child.visible:
			if child.is_in_group("dynamic_ship_apps"):
				if child.name.begins_with("ShipApp_") or child is Panel: # StartMenuOption è un Panel
					count += 1
				elif child is MarginContainer or child is VBoxContainer:
					count += _count_visible_rows(child)
			else:
				# Nodi statici
				count += 1
	return count

func _tree_has_ship_apps(tree: Dictionary) -> bool:
	for app in tree.get("apps", []):
		if bool(app.get("is_ship_app", false)):
			return true
	for sub in tree.get("subfolders", {}).values():
		if _tree_has_ship_apps(sub):
			return true
	return false

func _render_menu_tree(container: Control, level: Dictionary, _depth: int, insert_idx: int, current_menu: Control) -> int:
	var option_scene := load("res://Scenes/Taskbar/start_menu_option.tscn")
	
	# Subfolders first
	var subfolder_names: Array = level["subfolders"].keys()
	subfolder_names.sort()
	for folder_name in subfolder_names:
		var opt: Control = option_scene.instantiate() as Control
		var sub_tree: Variant = level["subfolders"][folder_name]
		if _tree_has_ship_apps(sub_tree):
			opt.add_to_group("dynamic_ship_apps")
		else:
			opt.add_to_group("dynamic_term_apps")
		container.add_child(opt)
		if insert_idx >= 0:
			container.move_child(opt, insert_idx)
			insert_idx += 1
		
		opt.configure_option(folder_name, "Cartella", "", Color.WHITE, null, "", true, sub_tree)
		_dynamic_ship_app_nodes.append(opt)
		
		opt.folder_pressed.connect(func(o): _on_folder_pressed(o, current_menu))
	
	# Apps
	for app in level["apps"]:
		var is_ship := bool(app.get("is_ship_app", false))
		var opt: Control = option_scene.instantiate() as Control
		var opt_title: String = str(app.get("title"))
		var opt_desc: String = str(app.get("description"))
		var opt_dev: String = str(app.get("developer"))
		var opt_scene: String = str(app.get("scene_path"))
		var opt_color: Color = app.get("icon_color")
		var opt_id: String = str(app.get("id"))
		
		var opt_icon: Texture2D = null
		if app.has("icon"):
			var raw_icon: Variant = app.get("icon")
			if raw_icon is Texture2D:
				opt_icon = raw_icon
			elif raw_icon is String and not (raw_icon as String).is_empty():
				if ResourceLoader.exists(raw_icon):
					opt_icon = load(raw_icon) as Texture2D
		
		var is_game: bool = str(app.get("category")).contains("Giochi")
		
		opt.name = "ShipApp_%s" % opt_id if is_ship else "TermApp_%s" % opt_id
		opt.set("title_text", opt_title)
		opt.set("description_text", opt_desc)
		opt.set("developer_text", opt_dev)
		if is_game:
			opt.set("game_scene", opt_scene)
			opt.set("application_scene", "")
			opt.set("use_generic_pause_menu", true)
		else:
			opt.set("application_scene", opt_scene)
			opt.set("game_scene", "")
			opt.set("use_generic_pause_menu", false)
		if is_ship:
			opt.add_to_group("dynamic_ship_apps")
		else:
			opt.add_to_group("dynamic_term_apps")
		
		container.add_child(opt)
		if insert_idx >= 0:
			container.move_child(opt, insert_idx)
			insert_idx += 1
		
		if opt.has_method("configure_option"):
			var opt_def_size := Vector2.ZERO
			var opt_min_size := Vector2.ZERO
			if app.has("default_window_size"):
				var d: Variant = app.get("default_window_size")
				if d is Vector2: opt_def_size = d
				elif d is Array and d.size() >= 2: opt_def_size = Vector2(d[0], d[1])
			if app.has("min_window_size"):
				var m: Variant = app.get("min_window_size")
				if m is Vector2: opt_min_size = m
				elif m is Array and m.size() >= 2: opt_min_size = Vector2(m[0], m[1])
			opt.configure_option(opt_title, opt_desc, opt_scene, opt_color, opt_icon, opt_dev, false, {}, is_game, opt_def_size, opt_min_size)
		
		_dynamic_ship_app_nodes.append(opt)
	
	return insert_idx

func _on_folder_pressed(option: Control, parent_menu: Control) -> void:
	# Close submenus of the same level or deeper
	if parent_menu.has_method("close_submenus"):
		parent_menu.call("close_submenus")
	elif parent_menu == start_menu:
		_close_all_submenus()
	
	var sub_menu_scene := load("res://Scenes/Taskbar/start_sub_menu.tscn")
	var sub_menu: Control = sub_menu_scene.instantiate()
	sub_menu.add_to_group("start_menu_panels")
	$"../../StartMenuAnchor".add_child(sub_menu)
	
	sub_menu.populate(option.get("sub_tree"), parent_menu, option)
	
	if "submenus" in parent_menu:
		parent_menu.submenus.append(sub_menu)
	else:
		_open_submenus.append(sub_menu)

func _close_all_submenus() -> void:
	for sub in _open_submenus:
		if is_instance_valid(sub):
			sub.close()
	_open_submenus.clear()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == 1 and event.is_pressed():
		handle_mouse_click()

func _on_mouse_entered() -> void:
	add_theme_constant_override("margin_bottom", 5)
	add_theme_constant_override("margin_left", 5)
	add_theme_constant_override("margin_right", 5)
	add_theme_constant_override("margin_top", 5)
	is_mouse_over = true

func _on_mouse_exited() -> void:
	add_theme_constant_override("margin_bottom", 3)
	add_theme_constant_override("margin_left", 3)
	add_theme_constant_override("margin_right", 3)
	add_theme_constant_override("margin_top", 3)
	is_mouse_over = false

func handle_mouse_click() -> void:
	for menu in get_tree().get_nodes_in_group("start_menu_panels"):
		if is_instance_valid(menu) and menu.visible and menu.get_global_rect().has_point(get_global_mouse_position()):
			return
	
	if is_mouse_over:
		if start_menu.position.y > 0:
			show_start_menu()
		else:
			hide_start_menu()
	else:
		hide_start_menu()

func show_start_menu() -> void:
	_refresh_ship_apps()
	_update_start_menu_size()
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var target_y: float = -start_menu.size.y - 5.0
	tween.tween_property(start_menu, "position:y", target_y, 0.3).from(-50)

func hide_start_menu() -> void:
	# Called from clicking on desktop
	_close_all_submenus()
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(start_menu, "position:y", 50, 0.3)

func _on_start_menu_mouse_entered() -> void:
	is_mouse_over_menu = true

func _on_start_menu_mouse_exited() -> void:
	is_mouse_over_menu = false
