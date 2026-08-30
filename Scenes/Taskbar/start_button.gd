extends MarginContainer

## The start menu in the taskbar. Handles showing and hiding the start menu.

@onready var start_menu: Panel = $"../../StartMenuAnchor/Start Menu"
@onready var scroll_container: ScrollContainer = $"../../StartMenuAnchor/Start Menu/ScrollContainer" if has_node("../../StartMenuAnchor/Start Menu/ScrollContainer") else null
@onready var vbox_container: VBoxContainer = ($"../../StartMenuAnchor/Start Menu/ScrollContainer/VBoxContainer" if has_node("../../StartMenuAnchor/Start Menu/ScrollContainer/VBoxContainer") else $"../../StartMenuAnchor/Start Menu/VBoxContainer") as VBoxContainer

var is_mouse_over_menu: bool
var is_mouse_over: bool
var _dynamic_ship_app_nodes: Array[Control] = []

func _ready() -> void:
	_connect_system_signals()
	_refresh_ship_apps.call_deferred()

func _exit_tree() -> void:
	_disconnect_system_signals()

func _connect_system_signals() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_signal("ship_connection_changed"):
		if not SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
	
	var ssm = get_node_or_null("/root/ShipSoftwareManager")
	if ssm:
		if ssm.has_signal("mission_started") and not ssm.mission_started.is_connected(_on_software_mission_started):
			ssm.mission_started.connect(_on_software_mission_started)
		if ssm.has_signal("mission_ended") and not ssm.mission_ended.is_connected(_on_software_mission_ended):
			ssm.mission_ended.connect(_on_software_mission_ended)
		if ssm.has_signal("role_changed") and not ssm.role_changed.is_connected(_on_software_role_changed):
			ssm.role_changed.connect(_on_software_role_changed)
		if ssm.has_signal("registry_changed") and not ssm.registry_changed.is_connected(_on_software_registry_changed):
			ssm.registry_changed.connect(_on_software_registry_changed)
	
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
	
	var ssm = get_node_or_null("/root/ShipSoftwareManager")
	if ssm:
		if ssm.has_signal("mission_started") and ssm.mission_started.is_connected(_on_software_mission_started):
			ssm.mission_started.disconnect(_on_software_mission_started)
		if ssm.has_signal("mission_ended") and ssm.mission_ended.is_connected(_on_software_mission_ended):
			ssm.mission_ended.disconnect(_on_software_mission_ended)
		if ssm.has_signal("role_changed") and ssm.role_changed.is_connected(_on_software_role_changed):
			ssm.role_changed.disconnect(_on_software_role_changed)
		if ssm.has_signal("registry_changed") and ssm.registry_changed.is_connected(_on_software_registry_changed):
			ssm.registry_changed.disconnect(_on_software_registry_changed)
	
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

func _on_mission_started() -> void:
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
	
	# Verifica se la connessione alla nave / missione è attiva
	var is_active: bool = false
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		is_active = SpaceWorldManager.is_ship_connected()
	elif _get_net_mgr() and _get_net_mgr().has_method("is_ship_connected"):
		is_active = _get_net_mgr().is_ship_connected()
	
	var ssm = get_node_or_null("/root/ShipSoftwareManager")
	if not is_active and ssm and ssm.get("is_mission_active"):
		is_active = true
	
	if is_active:
		var nm := _get_net_mgr()
		var my_role: String = ""
		var is_solo: bool = false
		
		if ssm and not ssm.current_role.is_empty():
			my_role = ssm.current_role
			is_solo = ssm.is_solo_mode
		elif nm:
			my_role = nm.get_local_player_role()
			is_solo = nm.is_solo_mode
		
		var apps: Array = []
		if ssm and ssm.has_method("get_apps_for_role"):
			var app_resources: Array = ssm.get_apps_for_role(my_role, is_solo)
			for r in app_resources:
				if r is Resource and r.has_method("to_dict"):
					apps.append(r.to_dict())
				elif r is Dictionary:
					apps.append(r)
		elif SpaceWorldManager and SpaceWorldManager.has_method("get_installed_apps_for_role"):
			apps = SpaceWorldManager.get_installed_apps_for_role(my_role, is_solo)
		elif SpaceWorldManager and SpaceWorldManager.has_method("get_ship_blueprint"):
			var bp = SpaceWorldManager.get_ship_blueprint()
			if bp:
				apps = bp.get_apps_for_role(my_role, is_solo)
		
		# Fallback su default blueprint se lista vuota ma sessione attiva
		if apps.is_empty():
			var def_bp := ShipBlueprint.get_default_blueprint()
			if def_bp:
				apps = def_bp.get_apps_for_role(my_role, is_solo)
		
		var option_scene := load("res://Scenes/Taskbar/start_menu_option.tscn")
		var insert_idx := 0
		for app in apps:
			var opt: Control = option_scene.instantiate() as Control
			var opt_title: String = str(app.get("title", app.get("name", "App Nave")))
			var opt_desc: String = str(app.get("description", ""))
			var opt_scene: String = str(app.get("scene_path", ""))
			var opt_color: Color = app.get("icon_color", Color(0, 0.79, 0.95, 1.0))
			var opt_id: String = str(app.get("id", ""))
			
			opt.name = "ShipApp_%s" % opt_id
			opt.set("title_text", opt_title)
			opt.set("description_text", opt_desc)
			opt.set("application_scene", opt_scene)
			opt.set("game_scene", "")
			opt.set("use_generic_pause_menu", false)
			opt.add_to_group("dynamic_ship_apps")
			
			vbox_container.add_child(opt)
			vbox_container.move_child(opt, insert_idx)
			insert_idx += 1
			
			if opt.has_method("configure_option"):
				opt.configure_option(opt_title, opt_desc, opt_scene, opt_color)
			
			_dynamic_ship_app_nodes.append(opt)
	
	_update_start_menu_size()
	if start_menu and start_menu.position.y < 0:
		start_menu.position.y = -start_menu.size.y - 5.0

func _update_start_menu_size() -> void:
	if not start_menu or not vbox_container:
		return
	var count := vbox_container.get_child_count()
	var vp_height: float = 720.0
	if is_inside_tree():
		var vp := get_viewport()
		if vp:
			vp_height = vp.get_visible_rect().size.y
	var max_allowed_height: float = maxf(vp_height - 60.0, 200.0)
	var desired_height: float = clampf(float(count) * 51.0 + 55.0, 200.0, max_allowed_height)
	start_menu.size.y = desired_height

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
	if is_mouse_over_menu: # Mouse clicked on empty space in menu, do nothing
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
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(start_menu, "position:y", 50, 0.3)

func _on_start_menu_mouse_entered() -> void:
	is_mouse_over_menu = true

func _on_start_menu_mouse_exited() -> void:
	is_mouse_over_menu = false
