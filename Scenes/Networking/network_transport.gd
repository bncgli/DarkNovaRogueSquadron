class_name NetworkTransport
extends RefCounted

## Interfaccia / Classe base astratta per i trasporti di rete (ENet, Steam, Nakama, WebSocket, ecc.)

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal server_started()
signal server_closed()
signal connection_succeeded()
signal connection_failed(error_message: String)
signal disconnected()

func create_server(_port: int = 7777, _max_clients: int = 6) -> Error:
	return ERR_UNAVAILABLE

func create_client(_address: String = "127.0.0.1", _port: int = 7777) -> Error:
	return ERR_UNAVAILABLE

func close_network() -> void:
	pass

func get_unique_id() -> int:
	return 1

func is_server() -> bool:
	return false

func is_network_active() -> bool:
	return false

func get_transport_name() -> String:
	return "Abstract Transport"
