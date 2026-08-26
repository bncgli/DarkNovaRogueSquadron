class_name ENetTransport
extends NetworkTransport

## Implementazione ENet per connessioni LAN e Direct IP

var peer: ENetMultiplayerPeer = null
var node_context: Node = null

func _init(context: Node = null) -> void:
	node_context = context

func _get_api() -> MultiplayerAPI:
	if node_context and node_context.is_inside_tree():
		return node_context.get_multiplayer()
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and (main_loop as SceneTree).root:
		return (main_loop as SceneTree).root.get_multiplayer()
	return null

func create_server(port: int = 7777, max_clients: int = 6) -> Error:
	close_network()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_clients)
	if err != OK:
		peer = null
		return err
	
	var api := _get_api()
	if api:
		api.multiplayer_peer = peer
		_connect_signals(api)
	server_started.emit()
	return OK

func create_client(address: String = "127.0.0.1", port: int = 7777) -> Error:
	close_network()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		peer = null
		return err
	
	var api := _get_api()
	if api:
		api.multiplayer_peer = peer
		_connect_signals(api)
	return OK

func close_network() -> void:
	if peer != null:
		var api := _get_api()
		if api:
			_disconnect_signals(api)
			if api.multiplayer_peer == peer:
				api.multiplayer_peer = null
		peer.close()
		peer = null
		disconnected.emit()

func get_unique_id() -> int:
	var api := _get_api()
	if api and api.multiplayer_peer:
		return api.get_unique_id()
	return 1

func is_server() -> bool:
	var api := _get_api()
	if api and api.multiplayer_peer:
		return api.is_server()
	return false

func is_network_active() -> bool:
	if peer == null:
		return false
	return peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED

func get_transport_name() -> String:
	return "ENet (LAN / Direct IP)"

func _connect_signals(api: MultiplayerAPI) -> void:
	if not api:
		return
	if not api.peer_connected.is_connected(_on_peer_connected):
		api.peer_connected.connect(_on_peer_connected)
	if not api.peer_disconnected.is_connected(_on_peer_disconnected):
		api.peer_disconnected.connect(_on_peer_disconnected)
	if not api.connected_to_server.is_connected(_on_connected_to_server):
		api.connected_to_server.connect(_on_connected_to_server)
	if not api.connection_failed.is_connected(_on_connection_failed):
		api.connection_failed.connect(_on_connection_failed)
	if not api.server_disconnected.is_connected(_on_server_disconnected):
		api.server_disconnected.connect(_on_server_disconnected)

func _disconnect_signals(api: MultiplayerAPI) -> void:
	if not api:
		return
	if api.peer_connected.is_connected(_on_peer_connected):
		api.peer_connected.disconnect(_on_peer_connected)
	if api.peer_disconnected.is_connected(_on_peer_disconnected):
		api.peer_disconnected.disconnect(_on_peer_disconnected)
	if api.connected_to_server.is_connected(_on_connected_to_server):
		api.connected_to_server.disconnect(_on_connected_to_server)
	if api.connection_failed.is_connected(_on_connection_failed):
		api.connection_failed.disconnect(_on_connection_failed)
	if api.server_disconnected.is_connected(_on_server_disconnected):
		api.server_disconnected.disconnect(_on_server_disconnected)

func _on_peer_connected(id: int) -> void:
	peer_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	peer_disconnected.emit(id)

func _on_connected_to_server() -> void:
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	connection_failed.emit("Connessione fallita. Verifica IP e Porta.")

func _on_server_disconnected() -> void:
	close_network()
