class_name LANDiscovery
extends Node

## Helper per il discovery automatico delle partite nella rete locale (UDP Broadcast)

signal server_found(server_data: Dictionary)

const BROADCAST_PORT: int = 7778
const BROADCAST_INTERVAL: float = 1.5

var udp_peer: PacketPeerUDP = null
var broadcast_timer: float = 0.0
var is_broadcasting: bool = false
var is_listening: bool = false

var broadcast_data: Dictionary = {}
var known_servers: Dictionary = {} # ip:port -> { "data": dict, "last_seen": float }

func _ready() -> void:
	set_process(false)

func start_broadcasting(server_name: String, game_port: int, max_players: int = 6) -> Error:
	stop()
	udp_peer = PacketPeerUDP.new()
	udp_peer.set_broadcast_enabled(true)
	var err := udp_peer.set_dest_address("255.255.255.255", BROADCAST_PORT)
	if err != OK:
		return err
	
	broadcast_data = {
		"game": "DarkNova",
		"name": server_name,
		"port": game_port,
		"max_players": max_players
	}
	is_broadcasting = true
	broadcast_timer = 0.0
	set_process(true)
	return OK

func start_listening() -> Error:
	stop()
	udp_peer = PacketPeerUDP.new()
	var err := udp_peer.bind(BROADCAST_PORT)
	if err != OK:
		return err
	
	is_listening = true
	known_servers.clear()
	set_process(true)
	return OK

func stop() -> void:
	is_broadcasting = false
	is_listening = false
	set_process(false)
	if udp_peer != null:
		udp_peer.close()
		udp_peer = null

func _process(delta: float) -> void:
	if is_broadcasting:
		broadcast_timer += delta
		if broadcast_timer >= BROADCAST_INTERVAL:
			broadcast_timer = 0.0
			_send_broadcast()
	
	if is_listening:
		_poll_incoming_packets()
		_clean_expired_servers()

func _send_broadcast() -> void:
	if udp_peer == null:
		return
	var json_str := JSON.stringify(broadcast_data)
	var bytes := json_str.to_utf8_buffer()
	udp_peer.put_packet(bytes)

func _poll_incoming_packets() -> void:
	if udp_peer == null:
		return
	while udp_peer.get_available_packet_count() > 0:
		var packet := udp_peer.get_packet()
		var ip := udp_peer.get_packet_ip()
		var json_str := packet.get_string_from_utf8()
		var json := JSON.new()
		if json.parse(json_str) == OK and typeof(json.data) == TYPE_DICTIONARY:
			var data: Dictionary = json.data
			if data.get("game") == "DarkNova":
				data["ip"] = ip
				var key := "%s:%s" % [ip, data.get("port")]
				data["key"] = key
				known_servers[key] = {
					"data": data,
					"last_seen": Time.get_ticks_msec() / 1000.0
				}
				server_found.emit(data)

func _clean_expired_servers() -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	var keys_to_remove: Array = []
	for key in known_servers:
		if current_time - known_servers[key]["last_seen"] > 5.0:
			keys_to_remove.append(key)
	for key in keys_to_remove:
		known_servers.erase(key)

func get_active_servers() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for key in known_servers:
		list.append(known_servers[key]["data"])
	return list
