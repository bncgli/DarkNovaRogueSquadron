class_name GameNetworkManager
extends Node

## NetworkManager: Singleton per la gestione multiplayer, ciurma, ruoli e comunicazioni.
## Progettato per essere agnostico rispetto al trasporto (ENet, Steamworks, Nakama).

signal lobby_updated(players_dict: Dictionary)
signal player_joined(peer_id: int, player_data: Dictionary)
signal player_left(peer_id: int)
signal player_role_changed(peer_id: int, role: String)
signal player_ready_changed(peer_id: int, is_ready: bool)
signal chat_received(sender: String, message: String, is_system: bool)
signal connection_state_changed(is_connected: bool, is_host: bool)
signal connection_failed(error_message: String)
signal game_launched()
signal mission_started()
signal mission_ended()

const ROLE_HOST: String = "HOST"
const ROLE_UNASSIGNED: String = "Non Assegnato"
const ROLE_CAPTAIN: String = "Capitano"
const ROLE_PILOT: String = "Pilota"
const ROLE_ENGINEER: String = "Ingegnere"
const ROLE_TACTICAL: String = "Tattico / Armi"
const ROLE_SENSORS: String = "Sensori / Radar"
const ROLE_COMMS: String = "Comunicazioni"

const ALL_ROLES: Array[String] = [
	ROLE_CAPTAIN,
	ROLE_PILOT,
	ROLE_ENGINEER,
	ROLE_TACTICAL,
	ROLE_SENSORS,
	ROLE_COMMS,
]

var transport: NetworkTransport = null
var lan_discovery: LANDiscovery = null

var local_player_name: String = "Operatore"
var local_peer_id: int = 1
var is_host: bool = false
var is_connected_to_network: bool = false
var is_solo_mode: bool = false
var is_mission_started: bool = false

## Registro della ciurma: peer_id (int) -> { "name": String, "role": String, "is_host": bool, "ready": bool }
var players: Dictionary = {}

var default_port: int = 7777
var server_room_name: String = "Astronave Dark Nova"
var max_crew_members: int = 6
var is_headless_server: bool = false
var lan_broadcast_enabled: bool = true

var _countdown_active: bool = false
var _headless_countdown_id: int = 0

func _init() -> void:
	lan_discovery = LANDiscovery.new()

func _ready() -> void:
	if lan_discovery.get_parent() == null:
		add_child(lan_discovery)
	
	# Inizializza il trasporto predefinito (ENet)
	set_transport(ENetTransport.new(self))
	
	# Controlla parametri riga di comando per avvio automatico come server/host
	call_deferred("_check_cli_startup")

## Consente in futuro di cambiare il backend (ad es. SteamTransport o NakamaTransport) senza toccare il resto del gioco
func set_transport(new_transport: NetworkTransport) -> void:
	if transport != null:
		transport.close_network()
		if transport.peer_connected.is_connected(_on_transport_peer_connected):
			transport.peer_connected.disconnect(_on_transport_peer_connected)
		if transport.peer_disconnected.is_connected(_on_transport_peer_disconnected):
			transport.peer_disconnected.disconnect(_on_transport_peer_disconnected)
		if transport.server_started.is_connected(_on_transport_server_started):
			transport.server_started.disconnect(_on_transport_server_started)
		if transport.connection_succeeded.is_connected(_on_transport_connection_succeeded):
			transport.connection_succeeded.disconnect(_on_transport_connection_succeeded)
		if transport.connection_failed.is_connected(_on_transport_connection_failed):
			transport.connection_failed.disconnect(_on_transport_connection_failed)
		if transport.disconnected.is_connected(_on_transport_disconnected):
			transport.disconnected.disconnect(_on_transport_disconnected)
	
	transport = new_transport
	if transport != null:
		transport.peer_connected.connect(_on_transport_peer_connected)
		transport.peer_disconnected.connect(_on_transport_peer_disconnected)
		transport.server_started.connect(_on_transport_server_started)
		transport.connection_succeeded.connect(_on_transport_connection_succeeded)
		transport.connection_failed.connect(_on_transport_connection_failed)
		transport.disconnected.connect(_on_transport_disconnected)

## Avvia un server / lobby come Host della nave
func host_game(player_name: String, port: int = 7777, room_name: String = "Dark Nova", max_players: int = 6) -> Error:
	if player_name.strip_edges().is_empty():
		player_name = "Capitano"
	
	local_player_name = player_name
	default_port = port
	server_room_name = room_name
	max_crew_members = max_players
	
	if transport == null:
		set_transport(ENetTransport.new(self))
	
	var err := transport.create_server(port, max_players)
	if err != OK:
		var err_msg := "Errore nell'avvio del server sulla porta %d (Codice: %d)" % [port, err]
		_notify(err_msg)
		connection_failed.emit(err_msg)
		return err
	
	is_host = true
	is_connected_to_network = true
	local_peer_id = 1
	
	var initial_role: String = ROLE_HOST if (is_headless_server or DisplayServer.get_name() == "headless") else ROLE_CAPTAIN
	var initial_ready: bool = true if (is_headless_server or DisplayServer.get_name() == "headless") else false
	
	players.clear()
	players[1] = {
		"name": local_player_name,
		"role": initial_role,
		"is_host": true,
		"ready": initial_ready
	}
	
	lan_discovery.start_broadcasting(room_name, port, max_players)
	
	connection_state_changed.emit(true, true)
	lobby_updated.emit(players)
	
	_notify("Stanza creata. Sei l'Host.")
	
	_add_local_system_chat("Sistema di bordo online. In attesa dell'equipaggio...")
	return OK

## Si connette a una nave esistente come membro della ciurma
func join_game(player_name: String, address: String = "127.0.0.1", port: int = 7777) -> Error:
	if player_name.strip_edges().is_empty():
		player_name = "Operatore"
	
	local_player_name = player_name
	default_port = port
	
	if transport == null:
		set_transport(ENetTransport.new(self))
	
	var err := transport.create_client(address, port)
	if err != OK:
		var err_msg := "Impossibile contattare %s:%d (Codice: %d)" % [address, port, err]
		_notify(err_msg)
		connection_failed.emit(err_msg)
		return err
	
	is_host = false
	is_connected_to_network = false # diventerà true su connection_succeeded
	players.clear()
	
	_notify("Tentativo di connessione a %s:%d..." % [address, port])
	
	return OK

## Avvia una sessione in modalità Solo (locale offline, nessun server di rete)
func start_solo_game(player_name: String = "Comandante") -> Error:
	if is_connected_to_network or is_solo_mode:
		disconnect_game()
	
	if player_name.strip_edges().is_empty():
		player_name = "Comandante"
	
	local_player_name = player_name
	server_room_name = "Astronave Locale (Solo)"
	max_crew_members = 1
	is_solo_mode = true
	is_host = true
	is_connected_to_network = true
	is_mission_started = false
	local_peer_id = 1
	
	players.clear()
	players[1] = {
		"name": local_player_name,
		"role": ROLE_CAPTAIN,
		"is_host": true,
		"ready": true
	}
	
	connection_state_changed.emit(true, true)
	lobby_updated.emit(players)
	
	_notify("Modalità Solo avviata. Configura la nave e premi Avvia Volo per decollare.")
	_add_local_system_chat("Sistemi di bordo in standby locale (Solo). Premi 'Avvia Volo' per inizializzare la nave.")
	return OK

## Chiude la connessione e resetta lo stato
func disconnect_game() -> void:
	lan_discovery.stop()
	if transport != null:
		transport.close_network()
	
	_cancel_headless_countdown()
	
	var was_solo := is_solo_mode
	var was_mission := is_mission_started
	players.clear()
	is_host = false
	is_connected_to_network = false
	is_solo_mode = false
	is_mission_started = false
	local_peer_id = 1
	
	if was_mission:
		mission_ended.emit()
	
	connection_state_changed.emit(false, false)
	lobby_updated.emit(players)
	
	if was_solo:
		_notify("Sessione in Singolo terminata.")
	else:
		_notify("Disconnesso dalla rete.")

## Richiede un ruolo nella ciurma
func request_role(role_name: String) -> void:
	if not is_connected_to_network:
		return
	
	# Il ruolo HOST non è selezionabile dai giocatori
	if role_name == ROLE_HOST:
		return
	
	if is_host:
		_server_set_player_role(1, role_name)
	else:
		_rpc_request_role.rpc_id(1, role_name)

## Invia un messaggio nella chat di bordo
func send_chat(text: String) -> void:
	if not is_connected_to_network or text.strip_edges().is_empty():
		return
	
	if is_host:
		_server_broadcast_chat(local_player_name, text, false)
	else:
		_rpc_send_chat.rpc_id(1, text)

## Imposta lo stato di prontezza del giocatore locale
func set_ready(is_ready: bool) -> void:
	if not is_connected_to_network:
		return
	if is_host:
		_server_set_player_ready(1, is_ready)
	else:
		_rpc_set_player_ready.rpc_id(1, is_ready)

## Inverte lo stato di prontezza del giocatore locale
func toggle_ready() -> void:
	set_ready(not is_local_player_ready())

## Verifica se il giocatore locale è pronto
func is_local_player_ready() -> bool:
	return players.get(local_peer_id, {}).get("ready", false)

## Avvia la missione (solo Host)
func start_mission() -> void:
	if not (is_connected_to_network or is_solo_mode) or not is_host:
		return
	
	if is_mission_started:
		return
	
	if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_rpc_launch_game.rpc()
	_rpc_launch_game()

## Restituisce il giocatore locale
func get_local_player_info() -> Dictionary:
	return players.get(local_peer_id, {})

func get_local_player_data() -> Dictionary:
	return get_local_player_info()

## Restituisce il ruolo del giocatore locale
func get_local_player_role() -> String:
	var info := get_local_player_info()
	return info.get("role", ROLE_UNASSIGNED if is_connected_to_network else "")

func is_active() -> bool:
	return is_connected_to_network

## Restituisce true se la missione è attiva e i sistemi dell'astronave sono operativi
func is_ship_connected() -> bool:
	return (is_connected_to_network or is_solo_mode) and is_mission_started

func is_mission_active() -> bool:
	return is_mission_started

## Restituisce chi occupa un determinato ruolo (o dizionario vuoto se libero)
func get_player_by_role(role_name: String) -> Dictionary:
	for id in players:
		if players[id].get("role") == role_name:
			return players[id]
	return {}

## Verifica se un ruolo è libero
func is_role_available(role_name: String) -> bool:
	if role_name == ROLE_HOST:
		return false
	if role_name == ROLE_UNASSIGNED:
		return true
	for id in players:
		if players[id].get("role") == role_name:
			return false
	return true

# --- GESTIONE TRASPORTO SEGNALI ---

func _on_transport_server_started() -> void:
	is_connected_to_network = true

func _on_transport_connection_succeeded() -> void:
	is_connected_to_network = true
	local_peer_id = transport.get_unique_id()
	connection_state_changed.emit(true, false)
	
	_notify("Connesso all'astronave!")
	
	# Invia registrazione al server
	_rpc_register_player.rpc_id(1, local_player_name)

func _on_transport_connection_failed(msg: String) -> void:
	is_connected_to_network = false
	_notify(msg)
	connection_failed.emit(msg)
	connection_state_changed.emit(false, false)

func _on_transport_disconnected() -> void:
	if is_connected_to_network:
		_notify("Connessione persa.")
	_cancel_headless_countdown()
	var was_mission := is_mission_started
	is_connected_to_network = false
	is_host = false
	is_mission_started = false
	players.clear()
	if was_mission:
		mission_ended.emit()
	connection_state_changed.emit(false, false)
	lobby_updated.emit(players)

func _on_transport_peer_connected(peer_id: int) -> void:
	if is_host:
		# Il client invierà _rpc_register_player
		pass

func _on_transport_peer_disconnected(peer_id: int) -> void:
	if is_host:
		if peer_id in players:
			var player_name: String = players[peer_id].get("name", "Operatore")
			players.erase(peer_id)
			player_left.emit(peer_id)
			lobby_updated.emit(players)
			
			_server_broadcast_chat("[SISTEMA]", "%s ha abbandonato l'astronave." % player_name, true)
			if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
				_rpc_sync_lobby.rpc(players)
			
			_notify("%s si è disconnesso." % player_name)
			_check_headless_auto_start()
			_check_headless_all_players_disconnected()

# --- RPC MULTIPLAYER ---

@rpc("any_peer", "call_remote", "reliable")
func _rpc_register_player(player_name: String) -> void:
	if not is_host:
		return
	
	var sender_id := multiplayer.get_remote_sender_id()
	var clean_name := player_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "MembroCiurma_%d" % sender_id
	
	players[sender_id] = {
		"name": clean_name,
		"role": ROLE_UNASSIGNED,
		"is_host": false,
		"ready": false
	}
	
	player_joined.emit(sender_id, players[sender_id])
	lobby_updated.emit(players)
	
	_server_broadcast_chat("[SISTEMA]", "%s è salito a bordo." % clean_name, true)
	if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_rpc_sync_lobby.rpc(players)
		if is_mission_started:
			_rpc_launch_game.rpc_id(sender_id)
	
	_notify("%s è salito a bordo." % clean_name)
	_check_headless_auto_start()

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_lobby(synced_players: Dictionary) -> void:
	players = synced_players
	local_peer_id = transport.get_unique_id()
	lobby_updated.emit(players)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_player_ready(is_ready: bool) -> void:
	if not is_host:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_server_set_player_ready(sender_id, is_ready)

func _server_set_player_ready(peer_id: int, is_ready: bool) -> void:
	if peer_id not in players:
		return
	
	players[peer_id]["ready"] = is_ready
	player_ready_changed.emit(peer_id, is_ready)
	lobby_updated.emit(players)
	
	if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_rpc_sync_lobby.rpc(players)
	
	var p_name: String = players[peer_id].get("name", "Operatore")
	var status_text: String = "è PRONTO!" if is_ready else "non è più pronto."
	_server_broadcast_chat("[SISTEMA]", "%s %s" % [p_name, status_text], true)
	
	_check_headless_auto_start()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_role(role_name: String) -> void:
	if not is_host:
		return
	
	var sender_id := multiplayer.get_remote_sender_id()
	_server_set_player_role(sender_id, role_name)

func _server_set_player_role(peer_id: int, role_name: String) -> void:
	if peer_id not in players:
		return
	
	# Il ruolo HOST non può essere selezionato da nessun altro giocatore
	if role_name == ROLE_HOST and (peer_id != 1 or not is_headless_server):
		return
	
	# Se l'host è un server headless, il suo ruolo resta bloccato su HOST
	if is_headless_server and peer_id == 1 and role_name != ROLE_HOST:
		return
	
	# Se il ruolo è già occupato da qualcun altro (e non è UNASSIGNED), liberiamo il vecchio possessore
	if role_name != ROLE_UNASSIGNED:
		for id in players:
			if id != peer_id and players[id].get("role") == role_name:
				players[id]["role"] = ROLE_UNASSIGNED
				player_role_changed.emit(id, ROLE_UNASSIGNED)
	
	players[peer_id]["role"] = role_name
	player_role_changed.emit(peer_id, role_name)
	lobby_updated.emit(players)
	
	var p_name: String = players[peer_id].get("name", "Operatore")
	_server_broadcast_chat("[SISTEMA]", "%s ha preso la postazione: %s" % [p_name, role_name], true)
	if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_rpc_sync_lobby.rpc(players)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_send_chat(message: String) -> void:
	if not is_host:
		return
	
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id in players:
		var sender_name: String = players[sender_id].get("name", "Operatore")
		_server_broadcast_chat(sender_name, message, false)

func _server_broadcast_chat(sender: String, message: String, is_system: bool) -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_rpc_receive_chat.rpc(sender, message, is_system)
	chat_received.emit(sender, message, is_system)
	if is_headless_server or DisplayServer.get_name() == "headless":
		print("[Chat][%s]: %s" % [sender, message])
		if not is_system:
			var clean_cmd := message.strip_edges().to_lower()
			if clean_cmd in ["/startgame", "/start_game", "/start"]:
				print("[NetworkManager] Comando /startgame ricevuto da '%s'. Avvio missione in corso..." % sender)
				_server_broadcast_chat("[SISTEMA]", "Comando /startgame ricevuto da %s. Decollo in corso..." % sender, true)
				start_mission()

# --- HEADLESS AUTO START & COUNTDOWN ---

func _check_headless_auto_start() -> void:
	if not is_host or not (is_headless_server or DisplayServer.get_name() == "headless"):
		return
	
	var client_count := 0
	var all_ready := true
	for id in players:
		if id == 1 and players[id].get("role", "") == ROLE_HOST:
			continue
		client_count += 1
		if not players[id].get("ready", false):
			all_ready = false
			break
	
	if client_count > 0 and all_ready:
		if not _countdown_active:
			_start_headless_countdown()
	else:
		if _countdown_active:
			_cancel_headless_countdown()

func _start_headless_countdown() -> void:
	_countdown_active = true
	_headless_countdown_id += 1
	var current_id := _headless_countdown_id
	
	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree == null:
		return
	
	_server_broadcast_chat("[SISTEMA]", "Tutti i membri sono pronti! Decollo tra 3...", true)
	
	await tree.create_timer(1.0).timeout
	if not _countdown_active or _headless_countdown_id != current_id:
		return
	_server_broadcast_chat("[SISTEMA]", "Decollo tra 2...", true)
	
	await tree.create_timer(1.0).timeout
	if not _countdown_active or _headless_countdown_id != current_id:
		return
	_server_broadcast_chat("[SISTEMA]", "Decollo tra 1...", true)
	
	await tree.create_timer(1.0).timeout
	if not _countdown_active or _headless_countdown_id != current_id:
		return
	
	_countdown_active = false
	_server_broadcast_chat("[SISTEMA]", "🚀 DECOLLO! Missione avviata!", true)
	start_mission()

func _cancel_headless_countdown() -> void:
	if _countdown_active:
		_countdown_active = false
		_headless_countdown_id += 1
		_server_broadcast_chat("[SISTEMA]", "Countdown decollo annullato: l'equipaggio non è più pronto.", true)

func _check_headless_all_players_disconnected() -> void:
	if not is_host or not (is_headless_server or DisplayServer.get_name() == "headless"):
		return
	
	var client_count := 0
	for id in players:
		if id == 1 and players[id].get("role", "") == ROLE_HOST:
			continue
		client_count += 1
	
	if client_count == 0:
		print("[NetworkManager] Tutti i giocatori si sono disconnessi dal server headless.")
		print("[NetworkManager] Riavvio e ri-hosting della stanza '%s' sulla porta %d..." % [server_room_name, default_port])
		call_deferred("_restart_headless_server")

func _restart_headless_server() -> void:
	var saved_callsign := local_player_name
	var saved_port := default_port
	var saved_room_name := server_room_name
	var saved_max_players := max_crew_members
	var should_broadcast_lan := lan_broadcast_enabled
	
	_cancel_headless_countdown()
	
	# Resetta lo stato fisico e i motori se SpaceWorldManager è attivo
	var space_world_mgr = get_node_or_null("/root/SpaceWorldManager")
	if space_world_mgr:
		if space_world_mgr.has_method("reset_spaceship_position"):
			space_world_mgr.reset_spaceship_position()
		if space_world_mgr.has_method("stop_spaceship_engines"):
			space_world_mgr.stop_spaceship_engines()
	
	disconnect_game()
	
	# Assicura che la modalità headless rimanga attiva per il nuovo hosting
	is_headless_server = true
	lan_broadcast_enabled = should_broadcast_lan
	
	var err := host_game(saved_callsign, saved_port, saved_room_name, saved_max_players)
	if err == OK:
		if not should_broadcast_lan and lan_discovery:
			lan_discovery.stop()
		print("[NetworkManager] Server headless riavviato con successo. Nuova stanza '%s' attiva in attesa di connessioni." % saved_room_name)
	else:
		push_error("[NetworkManager] Errore nel ri-hosting del server headless: %d" % err)

@rpc("authority", "call_remote", "reliable")
func _rpc_receive_chat(sender: String, message: String, is_system: bool) -> void:
	chat_received.emit(sender, message, is_system)

@rpc("authority", "call_remote", "reliable")
func _rpc_launch_game() -> void:
	is_mission_started = true
	game_launched.emit()
	mission_started.emit()
	_notify("🚀 Missione Avviata! Tutti alle postazioni!")

func _add_local_system_chat(msg: String) -> void:
	chat_received.emit("[SISTEMA]", msg, true)

func _notify(text: String) -> void:
	if is_headless_server or DisplayServer.get_name() == "headless":
		print("[NetworkManager] %s" % text)
	if is_inside_tree() and get_tree().root.has_node("NotificationManager"):
		get_node("/root/NotificationManager").spawn_notification(text)

# --- CLI & ARGUMENTS HANDLING ---

func _parse_command_line() -> Dictionary:
	var result := {
		"server": false,
		"client": false,
		"port": 7777,
		"room_name": "Astronave Dark Nova",
		"callsign": "Host Server",
		"max_players": 6,
		"role": ROLE_CAPTAIN,
		"lan": true,
		"connect_address": "127.0.0.1",
		"has_custom_params": false
	}
	
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	
	var i := 0
	while i < args.size():
		var arg := args[i].strip_edges()
		var lower := arg.to_lower()
		
		if lower in ["--server", "-server", "--host", "-host", "--dedicated", "--dedicated-server"]:
			result["server"] = true
			result["has_custom_params"] = true
		elif lower.begins_with("--port="):
			result["port"] = lower.substr(7).to_int()
			result["has_custom_params"] = true
		elif (lower == "--port" or lower == "-p") and i + 1 < args.size():
			i += 1
			result["port"] = args[i].to_int()
			result["has_custom_params"] = true
		elif lower.begins_with("--name="):
			result["room_name"] = arg.substr(7)
			result["has_custom_params"] = true
		elif lower.begins_with("--room="):
			result["room_name"] = arg.substr(7)
			result["has_custom_params"] = true
		elif lower.begins_with("--ship="):
			result["room_name"] = arg.substr(7)
			result["has_custom_params"] = true
		elif (lower in ["--name", "--room", "--ship"]) and i + 1 < args.size():
			i += 1
			result["room_name"] = args[i]
			result["has_custom_params"] = true
		elif lower.begins_with("--callsign="):
			result["callsign"] = arg.substr(11)
			result["has_custom_params"] = true
		elif lower.begins_with("--player-name="):
			result["callsign"] = arg.substr(14)
			result["has_custom_params"] = true
		elif lower.begins_with("--host-name="):
			result["callsign"] = arg.substr(12)
			result["has_custom_params"] = true
		elif (lower in ["--callsign", "--player-name", "--host-name"]) and i + 1 < args.size():
			i += 1
			result["callsign"] = args[i]
			result["has_custom_params"] = true
		elif lower.begins_with("--max-players="):
			result["max_players"] = lower.substr(14).to_int()
			result["has_custom_params"] = true
		elif lower.begins_with("--max-crew="):
			result["max_players"] = lower.substr(11).to_int()
			result["has_custom_params"] = true
		elif (lower in ["--max-players", "--max-crew", "-m"]) and i + 1 < args.size():
			i += 1
			result["max_players"] = args[i].to_int()
			result["has_custom_params"] = true
		elif lower.begins_with("--role="):
			result["role"] = arg.substr(7)
			result["has_custom_params"] = true
		elif lower == "--role" and i + 1 < args.size():
			i += 1
			result["role"] = args[i]
			result["has_custom_params"] = true
		elif lower in ["--no-lan", "--disable-lan"]:
			result["lan"] = false
			result["has_custom_params"] = true
		elif lower.begins_with("--connect="):
			result["client"] = true
			result["connect_address"] = arg.substr(10)
			result["has_custom_params"] = true
		elif lower.begins_with("--join="):
			result["client"] = true
			result["connect_address"] = arg.substr(7)
			result["has_custom_params"] = true
		elif (lower in ["--connect", "--join"]) and i + 1 < args.size():
			result["client"] = true
			i += 1
			result["connect_address"] = args[i]
			result["has_custom_params"] = true
		elif lower in ["--client", "-client"]:
			result["client"] = true
			result["has_custom_params"] = true
		
		i += 1
		
	return result

func _check_cli_startup() -> void:
	var cli := _parse_command_line()
	var is_dedicated_export: bool = OS.has_feature("dedicated_server")
	var is_server_flag: bool = bool(cli.get("server", false))
	var is_client_flag: bool = bool(cli.get("client", false))
	var should_run_server: bool = is_server_flag or is_dedicated_export
	
	if should_run_server:
		is_headless_server = true
		lan_broadcast_enabled = bool(cli.get("lan", true))
		print("==================================================")
		print("🚀 DarkNova RogueSquadron - Server Headless / Host")
		print("   Porta:           %d" % cli["port"])
		print("   Nome Nave/Lobby: %s" % cli["room_name"])
		print("   Callsign Host:   %s" % cli["callsign"])
		print("   Ruolo Host:      %s" % ROLE_HOST)
		print("   Posti Ciurma:    %d" % cli["max_players"])
		print("   LAN Broadcast:   %s" % ("Attivo" if cli["lan"] else "Disattivato"))
		print("==================================================")
		
		var err := host_game(cli["callsign"], cli["port"], cli["room_name"], cli["max_players"])
		if err == OK:
			if not cli["lan"]:
				lan_discovery.stop()
			print("[NetworkManager] Server in ascolto e pronto a ricevere connessioni con ruolo %s." % ROLE_HOST)
		else:
			push_error("[NetworkManager] Errore durante l'avvio del server: %d" % err)
	elif is_client_flag:
		print("[NetworkManager] Avvio automatico Client: connessione a %s:%d..." % [cli["connect_address"], cli["port"]])
		join_game(cli["callsign"], cli["connect_address"], cli["port"])
