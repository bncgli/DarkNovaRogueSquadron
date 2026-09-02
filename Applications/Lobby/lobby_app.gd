extends Control

## Applicazione GodotOS per la gestione della Lobby e delle Comunicazioni di Bordo
## Conforme allo standard architetturale di bordo (APP_ARCHITECTURE_STANDARD.md).

## Configurazione standard della finestra GodotOS
const APP_TITLE: String = "Pannello Comunicazioni & Lobby Equipaggio"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(860, 580)

@onready var connection_view: Control = %ConnectionView
@onready var lobby_room_view: Control = %LobbyRoomView

# Connection View Elements
@onready var callsign_edit: LineEdit = %CallsignEdit
@onready var solo_button: Button = %SoloButton
@onready var host_room_name_edit: LineEdit = %HostRoomNameEdit
@onready var host_port_spin: SpinBox = %HostPortSpin
@onready var host_max_players_spin: SpinBox = %HostMaxPlayersSpin
@onready var host_button: Button = %HostButton
@onready var join_ip_edit: LineEdit = %JoinIpEdit
@onready var join_port_spin: SpinBox = %JoinPortSpin
@onready var join_button: Button = %JoinButton
@onready var lan_server_list: VBoxContainer = %LanServerList
@onready var lan_status_label: Label = %LanStatusLabel
@onready var rescan_lan_button: Button = %RescanLanButton

# Lobby Room View Elements
@onready var room_title_label: Label = %RoomTitleLabel
@onready var room_status_badge: Label = %RoomStatusBadge
@onready var disconnect_button: Button = %DisconnectButton
@onready var crew_count_label: Label = %CrewCountLabel
@onready var crew_list_container: VBoxContainer = %CrewListContainer
@onready var roles_container: VBoxContainer = %RolesContainer
@onready var chat_log: RichTextLabel = %ChatLog
@onready var chat_input: LineEdit = %ChatInput
@onready var send_chat_button: Button = %SendChatButton
@onready var ready_button: Button = %ReadyButton
@onready var launch_mission_button: Button = %LaunchMissionButton
@onready var client_waiting_label: Label = %ClientWaitingLabel

# Resource Selection Elements
@onready var resources_panel: Control = %ResourcesPanel
@onready var res_permission_badge: Label = %ResPermissionBadge
@onready var ship_blueprint_option: OptionButton = %ShipBlueprintOption
@onready var select_ship_file_button: Button = %SelectShipFileButton
@onready var ship_preview_label: Label = %ShipPreviewLabel
@onready var star_system_option: OptionButton = %StarSystemOption
@onready var select_system_file_button: Button = %SelectSystemFileButton
@onready var system_preview_label: Label = %SystemPreviewLabel
@onready var resource_file_dialog: FileDialog = %ResourceFileDialog

var role_buttons: Dictionary = {}
var _active_file_picker_target: String = "" # "ship" o "system"
var _available_ship_blueprints: Array[Dictionary] = [
	{ "name": "Dark Nova Corvette (Default)", "path": "res://Outside/ShipSublayer/default_ship_blueprint.tres" }
]
var _available_star_systems: Array[Dictionary] = [
	{ "name": "Helios Nova System (Default)", "path": "res://Outside/StarSystemGrid/default_star_system.tres" }
]

func _ready() -> void:
	_configure_window()
	_connect_system_signals()
	
	# Configura elementi UI iniziali
	if NetworkManager:
		callsign_edit.text = NetworkManager.local_player_name
	_build_role_buttons()
	_init_resource_selectors()
	_update_view_state()
	
	# Avvia ascolto LAN discovery per trovare subito server locali
	if NetworkManager and not NetworkManager.is_connected_to_network:
		_start_lan_scan()

func _configure_window() -> void:
	custom_minimum_size = DEFAULT_WINDOW_SIZE
	call_deferred("_setup_parent_window", APP_TITLE, DEFAULT_WINDOW_SIZE)

func _connect_system_signals() -> void:
	if NetworkManager:
		NetworkManager.connection_state_changed.connect(_on_connection_state_changed)
		NetworkManager.lobby_updated.connect(_on_lobby_updated)
		NetworkManager.session_resources_updated.connect(_on_session_resources_updated)
		NetworkManager.chat_received.connect(_on_chat_received)
		NetworkManager.game_launched.connect(_on_game_launched)
		NetworkManager.connection_failed.connect(_on_connection_failed)
		if NetworkManager.lan_discovery:
			NetworkManager.lan_discovery.server_found.connect(_on_lan_server_found)

func _exit_tree() -> void:
	if NetworkManager:
		if NetworkManager.connection_state_changed.is_connected(_on_connection_state_changed):
			NetworkManager.connection_state_changed.disconnect(_on_connection_state_changed)
		if NetworkManager.lobby_updated.is_connected(_on_lobby_updated):
			NetworkManager.lobby_updated.disconnect(_on_lobby_updated)
		if NetworkManager.session_resources_updated.is_connected(_on_session_resources_updated):
			NetworkManager.session_resources_updated.disconnect(_on_session_resources_updated)
		if NetworkManager.chat_received.is_connected(_on_chat_received):
			NetworkManager.chat_received.disconnect(_on_chat_received)
		if NetworkManager.game_launched.is_connected(_on_game_launched):
			NetworkManager.game_launched.disconnect(_on_game_launched)
		if NetworkManager.connection_failed.is_connected(_on_connection_failed):
			NetworkManager.connection_failed.disconnect(_on_connection_failed)
		if NetworkManager.lan_discovery and NetworkManager.lan_discovery.server_found.is_connected(_on_lan_server_found):
			NetworkManager.lan_discovery.server_found.disconnect(_on_lan_server_found)
		if not NetworkManager.is_connected_to_network and NetworkManager.lan_discovery:
			NetworkManager.lan_discovery.stop()

func _setup_parent_window(_title: String, _size: Vector2) -> void:
	var parent_window := _find_parent_window()
	if parent_window:
		parent_window.size = DEFAULT_WINDOW_SIZE
		parent_window.custom_minimum_size = Vector2(700, 500)
		parent_window.title_text = APP_TITLE
		var title_label = parent_window.get_node_or_null("Top Bar/Title Text")
		if title_label:
			title_label.text = "[center]" + APP_TITLE

func _find_parent_window() -> FakeWindow:
	var node: Node = get_parent()
	while node != null:
		if node is FakeWindow:
			return node
		node = node.get_parent()
	return null

func _build_role_buttons() -> void:
	for child in roles_container.get_children():
		child.queue_free()
	role_buttons.clear()
	
	var roles_data := [
		{ "id": NetworkManager.ROLE_CAPTAIN, "title": "👑 CAPITANO", "desc": "Comando generale, ordini e gestione risorse" },
		{ "id": NetworkManager.ROLE_PILOT, "title": "🕹️ PILOTA", "desc": "Navigazione, timone e manovre di volo" },
		{ "id": NetworkManager.ROLE_SOLDIER, "title": "⚔️ SOLDATO", "desc": "Puntamento armi, gestione sensori e difesa scafo" },
		{ "id": NetworkManager.ROLE_ENGINEER, "title": "⚡ INGEGNERE", "desc": "Reattore, distribuzione energia e riparazioni" },
		{ "id": NetworkManager.ROLE_HACKER, "title": "💾 HACKER", "desc": "Guerra elettronica, decrittazione e intrusione droni" },
		{ "id": NetworkManager.ROLE_STAGISTA, "title": "🔧 STAGISTA", "desc": "Supporto multiruolo e manutenzione generale" },
		{ "id": NetworkManager.ROLE_UNASSIGNED, "title": "⚪ NESSUNA POSTAZIONE", "desc": "In attesa di assegnazione postazione" }
	]
	
	for r in roles_data:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 44)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = "%s  -  %s" % [r["title"], r["desc"]]
		btn.pressed.connect(_on_role_button_pressed.bind(r["id"]))
		roles_container.add_child(btn)
		role_buttons[r["id"]] = {
			"button": btn,
			"title": r["title"],
			"desc": r["desc"]
		}

func _update_view_state() -> void:
	var connected: bool = NetworkManager.is_connected_to_network
	connection_view.visible = not connected
	lobby_room_view.visible = connected
	
	if connected:
		_refresh_lobby_ui()
	else:
		_start_lan_scan()

func _refresh_lobby_ui() -> void:
	var is_host: bool = NetworkManager.is_host
	var players: Dictionary = NetworkManager.players
	var local_id: int = NetworkManager.local_peer_id
	
	# Header
	var host_name := "Sconosciuto"
	var host_role := ""
	for pid in players:
		if players[pid].get("is_host"):
			host_name = players[pid].get("name")
			host_role = players[pid].get("role")
			break
	
	if NetworkManager.is_solo_mode:
		room_title_label.text = "ASTRONAVE: %s  |  COMANDANTE: %s" % [NetworkManager.server_room_name, host_name]
		room_status_badge.text = "[ MODALITÀ SOLO (OFFLINE) ]"
		room_status_badge.modulate = Color(0.3, 1.0, 0.6)
		crew_count_label.text = "EQUIPAGGIO: COMANDANTE SINGOLO (1/1)"
	elif host_role == NetworkManager.ROLE_HOST:
		room_title_label.text = "ASTRONAVE: %s  |  HOST: %s" % [NetworkManager.server_room_name, host_name]
		room_status_badge.text = "[ HOST / SERVER ]"
		room_status_badge.modulate = Color(1.0, 0.85, 0.2)
		crew_count_label.text = "MEMBRI DELL'EQUIPAGGIO (%d/%d)" % [players.size(), NetworkManager.max_crew_members]
	elif is_host:
		room_title_label.text = "ASTRONAVE: %s  |  COMANDANTE: %s" % [NetworkManager.server_room_name, host_name]
		room_status_badge.text = "[ HOST / SERVER ]"
		room_status_badge.modulate = Color(1.0, 0.85, 0.2)
		crew_count_label.text = "MEMBRI DELL'EQUIPAGGIO (%d/%d)" % [players.size(), NetworkManager.max_crew_members]
	else:
		room_title_label.text = "ASTRONAVE: %s  |  COMANDANTE: %s" % [NetworkManager.server_room_name, host_name]
		room_status_badge.text = "[ CLIENT CONNESSO ]"
		room_status_badge.modulate = Color(0.2, 0.9, 1.0)
		crew_count_label.text = "MEMBRI DELL'EQUIPAGGIO (%d/%d)" % [players.size(), NetworkManager.max_crew_members]
	
	# Lista equipaggio
	for child in crew_list_container.get_children():
		child.queue_free()
	
	for pid in players:
		var pinfo: Dictionary = players[pid]
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.12, 0.15, 0.2, 0.9) if pid == local_id else Color(0.08, 0.09, 0.12, 0.7)
		card_style.border_width_left = 3
		card_style.border_color = Color(0.2, 0.8, 1.0) if pid == local_id else Color(0.3, 0.35, 0.4)
		card_style.set_corner_radius_all(4)
		card.add_theme_stylebox_override("panel", card_style)
		
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		
		var label_name := Label.new()
		var name_prefix := "⭐ " if pinfo.get("is_host") else "👤 "
		var is_you_str := " (TU)" if pid == local_id else ""
		label_name.text = "%s%s%s" % [name_prefix, pinfo.get("name"), is_you_str]
		label_name.size_flags_horizontal = SIZE_EXPAND_FILL
		hbox.add_child(label_name)
		
		var label_role := Label.new()
		var r_name: String = pinfo.get("role")
		label_role.text = "[ %s ]" % r_name
		if r_name == NetworkManager.ROLE_HOST:
			label_role.modulate = Color(1.0, 0.85, 0.2)
		elif r_name != NetworkManager.ROLE_UNASSIGNED:
			label_role.modulate = Color(0.3, 1.0, 0.6)
		else:
			label_role.modulate = Color(0.7, 0.7, 0.7)
		hbox.add_child(label_role)
		
		# Badge stato Pronto
		var label_ready := Label.new()
		var is_pready: bool = pinfo.get("ready")
		if r_name == NetworkManager.ROLE_HOST:
			label_ready.text = "[ HOST ]"
			label_ready.modulate = Color(1.0, 0.85, 0.2)
		elif is_pready:
			label_ready.text = "[ PRONTO ]"
			label_ready.modulate = Color(0.4, 1.0, 0.5)
		else:
			label_ready.text = "[ IN ATTESA ]"
			label_ready.modulate = Color(0.9, 0.5, 0.5)
		hbox.add_child(label_ready)
		
		card.add_child(hbox)
		crew_list_container.add_child(card)
	
	# Aggiornamento pulsanti ruoli
	var local_role := ""
	if local_id in players:
		local_role = players[local_id].get("role")
	
	for role_id in role_buttons:
		var data: Dictionary = role_buttons[role_id]
		var btn: Button = data["button"]
		var title: String = data["title"]
		var desc: String = data["desc"]
		
		var occupant_name: String = ""
		var is_mine: bool = (local_role == role_id and role_id != NetworkManager.ROLE_UNASSIGNED)
		
		if role_id != NetworkManager.ROLE_UNASSIGNED:
			for pid in players:
				if players[pid].get("role") == role_id:
					occupant_name = players[pid].get("name")
					break
		
		if is_mine:
			btn.text = "%s  -  %s  [▶ TUA POSTAZIONE]" % [title, desc]
			btn.modulate = Color(0.4, 1.0, 0.5)
		elif not occupant_name.is_empty():
			btn.text = "%s  -  %s  [Occupato da: %s]" % [title, desc, occupant_name]
			btn.modulate = Color(1.0, 0.6, 0.6)
		else:
			btn.text = "%s  -  %s  [Libera]" % [title, desc]
			btn.modulate = Color(1.0, 1.0, 1.0)
	
	# Controlli avvio e stato Pronto
	var is_headless_host: bool = (host_role == NetworkManager.ROLE_HOST)
	var is_local_ready: bool = NetworkManager.is_local_player_ready()
	
	if is_local_ready:
		ready_button.text = "❌ NON PRONTO"
		ready_button.modulate = Color(1.0, 0.6, 0.6)
	else:
		ready_button.text = "✅ PRONTO"
		ready_button.modulate = Color(0.4, 1.0, 0.5)
	
	if NetworkManager.is_solo_mode:
		ready_button.visible = false
		launch_mission_button.visible = true
		launch_mission_button.text = "🚀 AVVIA VOLO (SOLO)"
		client_waiting_label.visible = false
	elif is_headless_host:
		ready_button.visible = true
		launch_mission_button.visible = false
		client_waiting_label.visible = true
		client_waiting_label.text = "⏳ Quando tutti i membri sono PRONTI, il decollo partirà automaticamente (3s)."
	else:
		ready_button.visible = true
		launch_mission_button.visible = is_host
		launch_mission_button.text = "🚀 AVVIA MISSIONE / DECOLLO"
		client_waiting_label.visible = not is_host
		client_waiting_label.text = "⏳ In attesa che il Capitano/Host dia l'ordine di decollo..."
	
	_refresh_resource_selection_ui()

func _init_resource_selectors() -> void:
	if not ship_blueprint_option or not star_system_option:
		return
	
	ship_blueprint_option.clear()
	for i in range(_available_ship_blueprints.size()):
		var bp_entry: Dictionary = _available_ship_blueprints[i]
		ship_blueprint_option.add_item(bp_entry.get("name"), i)
		ship_blueprint_option.set_item_metadata(i, bp_entry.get("path"))
	
	star_system_option.clear()
	for i in range(_available_star_systems.size()):
		var sys_entry: Dictionary = _available_star_systems[i]
		star_system_option.add_item(sys_entry.get("name"), i)
		star_system_option.set_item_metadata(i, sys_entry.get("path"))

func _refresh_resource_selection_ui() -> void:
	if not NetworkManager or not resources_panel:
		return
	
	var can_edit: bool = (NetworkManager.is_host or NetworkManager.is_solo_mode)
	
	ship_blueprint_option.disabled = not can_edit
	select_ship_file_button.disabled = not can_edit
	select_ship_file_button.visible = can_edit
	
	star_system_option.disabled = not can_edit
	select_system_file_button.disabled = not can_edit
	select_system_file_button.visible = can_edit
	
	if NetworkManager.is_solo_mode:
		res_permission_badge.text = "[SOLO: Modificabile]"
		res_permission_badge.modulate = Color(0.3, 1.0, 0.6)
	elif NetworkManager.is_host:
		res_permission_badge.text = "[HOST: Modificabile]"
		res_permission_badge.modulate = Color(1.0, 0.85, 0.2)
	else:
		res_permission_badge.text = "[CLIENT: Sola Lettura]"
		res_permission_badge.modulate = Color(0.2, 0.9, 1.0)
	
	var bp_info: Dictionary = NetworkManager.get_session_blueprint_info()
	var sys_info: Dictionary = NetworkManager.get_session_star_system_info()
	
	_update_blueprint_preview(bp_info)
	_update_star_system_preview(sys_info)

func _update_blueprint_preview(bp_info: Dictionary) -> void:
	if bp_info.is_empty():
		return
	var ship_name: String = bp_info.get("name")
	var ship_class: String = bp_info.get("class")
	var rooms_cnt: int = bp_info.get("rooms_count")
	var ducts_cnt: int = bp_info.get("ducts_count")
	var apps_cnt: int = bp_info.get("apps_count")
	var path: String = bp_info.get("path")
	
	ship_preview_label.text = "Nave: %s (%s) | Stanze: %d | Condotti: %d | App: %d" % [
		ship_name, ship_class, rooms_cnt, ducts_cnt, apps_cnt
	]
	
	# Sincronizza selezione OptionButton se presente
	var found_idx := -1
	for i in range(ship_blueprint_option.item_count):
		if ship_blueprint_option.get_item_metadata(i) == path or (path.is_empty() and i == 0):
			found_idx = i
			break
	
	if found_idx != -1:
		ship_blueprint_option.select(found_idx)
	else:
		# Aggiunge opzione custom
		var custom_name: String = "%s (Custom)" % ship_name
		var custom_idx: int = ship_blueprint_option.item_count
		ship_blueprint_option.add_item(custom_name, custom_idx)
		ship_blueprint_option.set_item_metadata(custom_idx, path)
		ship_blueprint_option.select(custom_idx)

func _update_star_system_preview(sys_info: Dictionary) -> void:
	if sys_info.is_empty():
		return
	var sys_name: String = sys_info.get("name")
	var star_coords: Vector3i = sys_info.get("primary_star_coords")
	var bodies_cnt: int = sys_info.get("bodies_count")
	var stations_cnt: int = sys_info.get("stations_count")
	var path: String = sys_info.get("path")
	
	system_preview_label.text = "Sistema: %s | Stella: (%d, %d, %d) | Corpi: %d | Stazioni: %d" % [
		sys_name, star_coords.x, star_coords.y, star_coords.z, bodies_cnt, stations_cnt
	]
	
	# Sincronizza selezione OptionButton se presente
	var found_idx := -1
	for i in range(star_system_option.item_count):
		if star_system_option.get_item_metadata(i) == path or (path.is_empty() and i == 0):
			found_idx = i
			break
	
	if found_idx != -1:
		star_system_option.select(found_idx)
	else:
		# Aggiunge opzione custom
		var custom_name: String = "%s (Custom)" % sys_name
		var custom_idx: int = star_system_option.item_count
		star_system_option.add_item(custom_name, custom_idx)
		star_system_option.set_item_metadata(custom_idx, path)
		star_system_option.select(custom_idx)

func _start_lan_scan() -> void:
	if NetworkManager.lan_discovery:
		lan_status_label.text = "Ricerca navi in ascolto sulla rete locale..."
		NetworkManager.lan_discovery.start_listening()
		_update_lan_list()

func _update_lan_list() -> void:
	for child in lan_server_list.get_children():
		child.queue_free()
	
	var servers: Array[Dictionary] = NetworkManager.lan_discovery.get_active_servers() if NetworkManager.lan_discovery else []
	if servers.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Nessuna astronave rilevata in LAN. Avvia un server o inserisci l'IP."
		empty_lbl.modulate = Color(0.6, 0.6, 0.6)
		lan_server_list.add_child(empty_lbl)
		return
	
	for sdata in servers:
		var pnl := PanelContainer.new()
		var pstyle := StyleBoxFlat.new()
		pstyle.bg_color = Color(0.1, 0.14, 0.2, 0.8)
		pstyle.set_corner_radius_all(4)
		pnl.add_theme_stylebox_override("panel", pstyle)
		
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 15)
		
		var info_lbl := Label.new()
		info_lbl.text = "🛰️ %s (%s:%d)" % [sdata.get("name"), sdata.get("ip"), sdata.get("port")]
		info_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		hbox.add_child(info_lbl)
		
		var join_btn := Button.new()
		join_btn.text = "Unisciti"
		var target_ip: String = sdata.get("ip")
		var target_port: int = int(sdata.get("port"))
		join_btn.pressed.connect(func() -> void:
			_apply_callsign()
			NetworkManager.join_game(callsign_edit.text, target_ip, target_port)
		)
		hbox.add_child(join_btn)
		
		pnl.add_child(hbox)
		lan_server_list.add_child(pnl)

func _apply_callsign() -> void:
	var cname := callsign_edit.text.strip_edges()
	if cname.is_empty():
		cname = "Operatore"
		callsign_edit.text = cname
	NetworkManager.local_player_name = cname

# --- SEGNALI UI ---

func _on_solo_button_pressed() -> void:
	_apply_callsign()
	NetworkManager.start_solo_game(callsign_edit.text)

func _on_host_button_pressed() -> void:
	_apply_callsign()
	var rname := host_room_name_edit.text.strip_edges()
	if rname.is_empty():
		rname = "Dark Nova"
	var port := int(host_port_spin.value)
	var max_p := int(host_max_players_spin.value)
	NetworkManager.host_game(callsign_edit.text, port, rname, max_p)

func _on_join_button_pressed() -> void:
	_apply_callsign()
	var ip := join_ip_edit.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var port := int(join_port_spin.value)
	NetworkManager.join_game(callsign_edit.text, ip, port)

func _on_disconnect_button_pressed() -> void:
	NetworkManager.disconnect_game()

func _on_role_button_pressed(role_id: String) -> void:
	NetworkManager.request_role(role_id)

func _on_send_chat_button_pressed() -> void:
	_submit_chat()

func _on_chat_input_text_submitted(_new_text: String) -> void:
	_submit_chat()

func _submit_chat() -> void:
	var msg := chat_input.text.strip_edges()
	if not msg.is_empty():
		NetworkManager.send_chat(msg)
		chat_input.clear()

func _on_launch_mission_button_pressed() -> void:
	NetworkManager.start_mission()

func _on_ready_button_pressed() -> void:
	NetworkManager.toggle_ready()

func _on_rescan_lan_button_pressed() -> void:
	_start_lan_scan()

# --- SELEZIONE RISORSE CUSTOM ---

func _on_ship_blueprint_option_item_selected(index: int) -> void:
	if not (NetworkManager.is_host or NetworkManager.is_solo_mode):
		return
	var path: String = ship_blueprint_option.get_item_metadata(index)
	NetworkManager.set_session_ship_blueprint(path)

func _on_star_system_option_item_selected(index: int) -> void:
	if not (NetworkManager.is_host or NetworkManager.is_solo_mode):
		return
	var path: String = star_system_option.get_item_metadata(index)
	NetworkManager.set_session_star_system(path)

func _on_select_ship_file_button_pressed() -> void:
	if not (NetworkManager.is_host or NetworkManager.is_solo_mode):
		return
	_active_file_picker_target = "ship"
	resource_file_dialog.title = "Seleziona Risorsa Nave (ShipBlueprint .tres / .json)"
	resource_file_dialog.popup_centered()

func _on_select_system_file_button_pressed() -> void:
	if not (NetworkManager.is_host or NetworkManager.is_solo_mode):
		return
	_active_file_picker_target = "system"
	resource_file_dialog.title = "Seleziona Risorsa Sistema Stellare (StarSystemData .tres / .json)"
	resource_file_dialog.popup_centered()

func _on_resource_file_dialog_file_selected(path: String) -> void:
	if _active_file_picker_target == "ship":
		NetworkManager.set_session_ship_blueprint(path)
	elif _active_file_picker_target == "system":
		NetworkManager.set_session_star_system(path)
	_active_file_picker_target = ""

# --- CALLBACKS DI RETE ---

func _on_connection_state_changed(_connected: bool, _is_host: bool) -> void:
	_update_view_state()

func _on_lobby_updated(_players: Dictionary) -> void:
	if NetworkManager.is_connected_to_network:
		_refresh_lobby_ui()

func _on_session_resources_updated(bp_info: Dictionary, sys_info: Dictionary) -> void:
	if NetworkManager.is_connected_to_network:
		_update_blueprint_preview(bp_info)
		_update_star_system_preview(sys_info)

func _on_chat_received(sender: String, message: String, is_system: bool) -> void:
	var time_str := Time.get_time_string_from_system().substr(0, 5)
	if is_system:
		chat_log.append_text("[color=#88bbff][%s] %s %s[/color]\n" % [time_str, sender, message])
	else:
		chat_log.append_text("[color=#cccccc][%s][/color] [b][color=#eedd88]%s:[/color][/b] %s\n" % [time_str, sender, message])

func _on_game_launched() -> void:
	var time_str := Time.get_time_string_from_system().substr(0, 5)
	chat_log.append_text("[b][color=#55ff88][%s] *** MISSIONE AVVIATA! TUTTE LE POSTAZIONI ATTIVE ***[/color][/b]\n" % time_str)

func _on_connection_failed(msg: String) -> void:
	lan_status_label.text = "Errore connessione: %s" % msg

func _on_lan_server_found(_sdata: Dictionary) -> void:
	if not NetworkManager.is_connected_to_network:
		_update_lan_list()
