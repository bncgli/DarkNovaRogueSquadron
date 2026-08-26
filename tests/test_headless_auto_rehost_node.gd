extends Node

func _ready() -> void:
	print("--- TEST HEADLESS AUTO RE-HOST ON ALL PLAYERS DISCONNECT ---")
	_run_tests.call_deferred()

func _run_tests() -> void:
	await get_tree().process_frame
	
	var net: GameNetworkManager = get_node_or_null("/root/NetworkManager") as GameNetworkManager
	var swm: SpaceWorldManagerSingleton = get_node_or_null("/root/SpaceWorldManager") as SpaceWorldManagerSingleton
	
	if net == null or swm == null:
		print("FAIL: Autoloads NetworkManager or SpaceWorldManager not found!")
		get_tree().quit(1)
		return
	
	print("\n--- Test 1: Start Headless Server ---")
	net.is_headless_server = true
	var test_room_name: String = "Incrociatore Stellare 42"
	var test_port: int = 7999
	var err := net.host_game("ServerHeadless", test_port, test_room_name, 4)
	if err != OK:
		print("FAIL: host_game failed with error: %d" % err)
		get_tree().quit(1)
		return
	
	if not net.is_host or not net.is_connected_to_network:
		print("FAIL: Server should be host and connected to network!")
		get_tree().quit(1)
		return
	
	if net.server_room_name != test_room_name:
		print("FAIL: Server room name mismatch!")
		get_tree().quit(1)
		return
	print("SUCCESS: Headless server started with room name '%s'." % test_room_name)
	
	print("\n--- Test 2: Simulate Client 1 (Peer 2) and Client 2 (Peer 3) connecting ---")
	net.players[2] = {
		"name": "Pilota Alpha",
		"role": net.ROLE_PILOT,
		"is_host": false,
		"ready": true
	}
	net.players[3] = {
		"name": "Ingegnere Beta",
		"role": net.ROLE_ENGINEER,
		"is_host": false,
		"ready": true
	}
	net.player_joined.emit(2, net.players[2])
	net.player_joined.emit(3, net.players[3])
	net.lobby_updated.emit(net.players)
	await get_tree().process_frame
	
	if net.players.size() != 3:
		print("FAIL: Players count should be 3!")
		get_tree().quit(1)
		return
	print("SUCCESS: 2 clients registered in lobby.")
	
	print("\n--- Test 3: Disconnect Peer 2 (1 client remaining) -> Should NOT re-host yet ---")
	net._on_transport_peer_disconnected(2)
	await get_tree().process_frame
	
	if net.players.has(2):
		print("FAIL: Peer 2 should have been erased from players!")
		get_tree().quit(1)
		return
	if not net.is_host or not net.is_connected_to_network:
		print("FAIL: Server should still be running because Peer 3 is connected!")
		get_tree().quit(1)
		return
	if not net.players.has(3):
		print("FAIL: Peer 3 should still be in lobby!")
		get_tree().quit(1)
		return
	print("SUCCESS: Peer 2 disconnected, server remains active with remaining crew.")
	
	print("\n--- Test 4: Disconnect Peer 3 (Last client) -> Should trigger auto re-host ---")
	var state := {
		"rehost_detected": false,
		"rehost_room_name": "",
		"disconnected": false
	}
	
	var on_conn_state := func(is_conn: bool, is_h: bool):
		if not is_conn:
			state["disconnected"] = true
		elif is_conn and is_h and state["disconnected"]:
			state["rehost_detected"] = true
			state["rehost_room_name"] = net.server_room_name
	
	net.connection_state_changed.connect(on_conn_state)
	
	net._on_transport_peer_disconnected(3)
	
	# Allow frames for call_deferred("_restart_headless_server")
	for i in range(10):
		await get_tree().process_frame
	
	net.connection_state_changed.disconnect(on_conn_state)
	
	if not state["disconnected"] or not state["rehost_detected"]:
		print("FAIL: Auto re-host was not triggered when all players disconnected! Disconnected: %s, Rehost: %s" % [state["disconnected"], state["rehost_detected"]])
		get_tree().quit(1)
		return
	
	if state["rehost_room_name"] != test_room_name:
		print("FAIL: Re-hosted server room name '%s' does not match original '%s'!" % [state["rehost_room_name"], test_room_name])
		get_tree().quit(1)
		return
	
	if not net.is_host or not net.is_connected_to_network or not net.is_headless_server:
		print("FAIL: Server state invalid after auto re-host!")
		get_tree().quit(1)
		return
	
	if net.players.size() != 1 or net.players[1].get("role") != net.ROLE_HOST:
		print("FAIL: Server players list should contain only Host after re-host!")
		get_tree().quit(1)
		return
	print("SUCCESS: Server disconnected and successfully re-hosted new room '%s'." % test_room_name)
	
	print("\n--- Test 5: Re-host with active mission -> Should end mission and reset ship ---")
	# Start mission
	net.start_mission()
	await get_tree().process_frame
	
	if not net.is_mission_active():
		print("FAIL: Mission should be active!")
		get_tree().quit(1)
		return
	
	# Add a client in mission
	net.players[4] = {
		"name": "Comms Gamma",
		"role": net.ROLE_COMMS,
		"is_host": false,
		"ready": true
	}
	net.player_joined.emit(4, net.players[4])
	await get_tree().process_frame
	
	# Disconnect the only client
	net._on_transport_peer_disconnected(4)
	
	for i in range(10):
		await get_tree().process_frame
	
	if net.is_mission_active():
		print("FAIL: Mission should be ended after all players disconnect and re-host!")
		get_tree().quit(1)
		return
	
	if net.server_room_name != test_room_name:
		print("FAIL: Re-hosted room name mismatch after mission reset!")
		get_tree().quit(1)
		return
	
	if not net.is_connected_to_network or not net.is_host:
		print("FAIL: Server should be online and hosting fresh room!")
		get_tree().quit(1)
		return
	print("SUCCESS: Mission ended cleanly, ship reset, and server re-hosted room '%s'." % test_room_name)
	
	print("\n==========================================")
	print("=== ALL HEADLESS RE-HOST TESTS PASSED! ===")
	print("==========================================")
	get_tree().quit(0)
