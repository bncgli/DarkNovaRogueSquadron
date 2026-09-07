extends GutTest

## Test GUT per il Re-Host Automatico Headless quando tutti i giocatori si disconnettono
## (`NetworkManager._check_headless_all_players_disconnected` / `_restart_headless_server`).
## Le funzioni condividono lo stato reale dell'autoload NetworkManager e sono eseguite in
## ordine di dichiarazione (comportamento di GUT), replicando la sequenza del test manuale originale.

const TEST_ROOM_NAME: String = "Incrociatore Stellare 42"
const TEST_PORT: int = 7999

func after_all() -> void:
	NetworkManager.disconnect_game()

func test_start_headless_server() -> void:
	NetworkManager.is_headless_server = true
	var err := NetworkManager.host_game("ServerHeadless", TEST_PORT, TEST_ROOM_NAME, 4)
	assert_eq(err, OK, "host_game failed")

	assert_true(NetworkManager.is_host and NetworkManager.is_connected_to_network, "Server should be host and connected to network")
	assert_eq(NetworkManager.server_room_name, TEST_ROOM_NAME, "Server room name mismatch")

func test_simulate_clients_connecting() -> void:
	NetworkManager.players[2] = {
		"name": "Pilota Alpha",
		"role": NetworkManager.ROLE_PILOT,
		"is_host": false,
		"ready": true
	}
	NetworkManager.players[3] = {
		"name": "Ingegnere Beta",
		"role": NetworkManager.ROLE_ENGINEER,
		"is_host": false,
		"ready": true
	}
	NetworkManager.player_joined.emit(2, NetworkManager.players[2])
	NetworkManager.player_joined.emit(3, NetworkManager.players[3])
	NetworkManager.lobby_updated.emit(NetworkManager.players)
	await get_tree().process_frame

	assert_eq(NetworkManager.players.size(), 3, "Players count should be 3")

func test_disconnect_one_of_two_clients_should_not_rehost_yet() -> void:
	NetworkManager._on_transport_peer_disconnected(2)
	await get_tree().process_frame

	assert_false(NetworkManager.players.has(2), "Peer 2 should have been erased from players")
	assert_true(NetworkManager.is_host and NetworkManager.is_connected_to_network, "Server should still be running because Peer 3 is connected")
	assert_true(NetworkManager.players.has(3), "Peer 3 should still be in lobby")

func test_disconnect_last_client_triggers_auto_rehost() -> void:
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
			state["rehost_room_name"] = NetworkManager.server_room_name

	NetworkManager.connection_state_changed.connect(on_conn_state)

	NetworkManager._on_transport_peer_disconnected(3)

	# Allow frames for call_deferred("_restart_headless_server")
	for i in range(10):
		await get_tree().process_frame

	NetworkManager.connection_state_changed.disconnect(on_conn_state)

	assert_true(state["disconnected"], "Auto re-host was not triggered: disconnection signal missing")
	assert_true(state["rehost_detected"], "Auto re-host was not triggered when all players disconnected")
	assert_eq(state["rehost_room_name"], TEST_ROOM_NAME, "Re-hosted server room name does not match original")

	assert_true(NetworkManager.is_host and NetworkManager.is_connected_to_network and NetworkManager.is_headless_server, "Server state invalid after auto re-host")
	assert_true(NetworkManager.players.size() == 1 and NetworkManager.players[1].get("role") == NetworkManager.ROLE_HOST, "Server players list should contain only Host after re-host")

func test_rehost_with_active_mission_ends_mission_and_resets_ship() -> void:
	# Start mission
	NetworkManager.start_mission()
	await get_tree().process_frame

	assert_true(NetworkManager.is_mission_active(), "Mission should be active")

	# Add a client in mission
	NetworkManager.players[4] = {
		"name": "Hacker Gamma",
		"role": NetworkManager.ROLE_HACKER,
		"is_host": false,
		"ready": true
	}
	NetworkManager.player_joined.emit(4, NetworkManager.players[4])
	await get_tree().process_frame

	# Disconnect the only client
	NetworkManager._on_transport_peer_disconnected(4)

	for i in range(10):
		await get_tree().process_frame

	assert_false(NetworkManager.is_mission_active(), "Mission should be ended after all players disconnect and re-host")
	assert_eq(NetworkManager.server_room_name, TEST_ROOM_NAME, "Re-hosted room name mismatch after mission reset")
	assert_true(NetworkManager.is_connected_to_network and NetworkManager.is_host, "Server should be online and hosting fresh room")
