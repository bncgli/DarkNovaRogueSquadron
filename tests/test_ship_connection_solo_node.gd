extends Node

func _ready() -> void:
	print("--- TEST SHIP CONNECTION STATE & SOLO MODE ---")
	_run_tests.call_deferred()

func _run_tests() -> void:
	await get_tree().process_frame
	
	var swm: SpaceWorldManagerSingleton = get_node_or_null("/root/SpaceWorldManager") as SpaceWorldManagerSingleton
	var net: GameNetworkManager = get_node_or_null("/root/NetworkManager") as GameNetworkManager
	
	if swm == null or net == null:
		print("FAIL: Autoloads not found!")
		get_tree().quit(1)
		return
	
	print("\n--- Test 1: Initial state is disconnected ---")
	if swm.is_ship_connected():
		print("FAIL: Ship should be disconnected at startup!")
		get_tree().quit(1)
		return
	if net.is_ship_connected():
		print("FAIL: NetworkManager should report ship disconnected at startup!")
		get_tree().quit(1)
		return
	print("SUCCESS: Ship is properly disconnected initially.")
	
	print("\n--- Test 2: FlightControl & Cams behavior when disconnected ---")
	var flight_scene: PackedScene = load("res://Applications/FlightControl/flight_control_app.tscn")
	var cams_scene: PackedScene = load("res://Applications/Cams/cams_app.tscn")
	var lobby_scene: PackedScene = load("res://Applications/Lobby/lobby_app.tscn")
	
	if not flight_scene or not cams_scene or not lobby_scene:
		print("FAIL: Could not load application scenes!")
		get_tree().quit(1)
		return
	
	var flight_app: FlightControlApp = flight_scene.instantiate() as FlightControlApp
	var cams_app := cams_scene.instantiate()
	var lobby_app := lobby_scene.instantiate()
	
	add_child(flight_app)
	add_child(cams_app)
	add_child(lobby_app)
	await get_tree().process_frame
	
	var flight_overlay: Control = flight_app.get_node_or_null("%DisconnectedOverlay")
	var cams_overlay: Control = cams_app.get_node_or_null("%DisconnectedOverlay")
	
	if flight_overlay == null or not flight_overlay.visible:
		print("FAIL: FlightControl disconnected overlay is not visible when disconnected!")
		get_tree().quit(1)
		return
	if cams_overlay == null or not cams_overlay.visible:
		print("FAIL: Cams disconnected overlay is not visible when disconnected!")
		get_tree().quit(1)
		return
	print("SUCCESS: Overlays are visible and display 'Connettersi alla nave'.")
	
	# Verify camera won't open when disconnected
	var cam_win := swm.open_camera_window("front")
	if cam_win != null:
		print("FAIL: Camera window opened while disconnected!")
		get_tree().quit(1)
		return
	print("SUCCESS: Camera windows cannot be opened while disconnected.")
	
	print("\n--- Test 3: Starting Solo Mode (Lobby vs Mission Start) ---")
	var solo_btn: Button = lobby_app.get_node_or_null("%SoloButton")
	if solo_btn == null:
		print("FAIL: SoloButton not found in LobbyApp!")
		get_tree().quit(1)
		return
	
	# Enter solo mode (lobby phase)
	net.start_solo_game("Comandante Solo")
	await get_tree().process_frame
	
	if not net.is_solo_mode:
		print("FAIL: NetworkManager is_solo_mode should be true!")
		get_tree().quit(1)
		return
	if net.is_mission_started:
		print("FAIL: Mission should NOT be started yet in solo lobby!")
		get_tree().quit(1)
		return
	if net.is_ship_connected():
		print("FAIL: Ship should NOT be connected before mission launch!")
		get_tree().quit(1)
		return
	if swm.is_ship_connected():
		print("FAIL: SpaceWorldManager should report disconnected before mission launch!")
		get_tree().quit(1)
		return
	
	flight_app._process(0.016)
	cams_app._update_status_summary()
	await get_tree().process_frame
	
	if not flight_overlay.visible:
		print("FAIL: Flight overlay should remain visible in solo lobby before launch!")
		get_tree().quit(1)
		return
	if not cams_overlay.visible:
		print("FAIL: Cams overlay should remain visible in solo lobby before launch!")
		get_tree().quit(1)
		return
	print("SUCCESS: Solo lobby initialized; ship is in standby (not connected) until mission start.")
	
	# Launch solo mission
	net.start_mission()
	await get_tree().process_frame
	
	if not net.is_mission_started:
		print("FAIL: is_mission_started should be true after start_mission()!")
		get_tree().quit(1)
		return
	if not net.is_ship_connected():
		print("FAIL: NetworkManager is_ship_connected should be true after start_mission()!")
		get_tree().quit(1)
		return
	if not swm.is_ship_connected():
		print("FAIL: SpaceWorldManager is_ship_connected should be true after start_mission()!")
		get_tree().quit(1)
		return
	
	flight_app._process(0.016)
	cams_app._update_status_summary()
	await get_tree().process_frame
	
	if flight_overlay.visible:
		print("FAIL: Flight overlay should be hidden after mission launch!")
		get_tree().quit(1)
		return
	if cams_overlay.visible:
		print("FAIL: Cams overlay should be hidden after mission launch!")
		get_tree().quit(1)
		return
	print("SUCCESS: Solo mission started, ship is operational, overlays are hidden and apps are active.")
	
	# Test flight control in solo mode
	flight_app._ui_linear_input = Vector3(0, 0, -1)
	flight_app._process(0.016)
	await get_tree().process_frame
	
	var ship := swm.get_spaceship()
	if ship.linear_input.z != -1:
		print("FAIL: Flight input was not passed to ship during solo mode!")
		get_tree().quit(1)
		return
	print("SUCCESS: Flight input correctly passed to ship in Solo mode.")
	
	# Test camera open in solo mode
	var cam_front_win := swm.open_camera_window("front")
	if cam_front_win == null or not swm.is_camera_window_open("front"):
		print("FAIL: Camera window could not be opened in solo mode!")
		get_tree().quit(1)
		return
	print("SUCCESS: Camera window successfully opened in Solo mode.")
	
	print("\n--- Test 4: Disconnecting from Solo Mode ---")
	net.disconnect_game()
	await get_tree().process_frame
	
	if swm.is_ship_connected():
		print("FAIL: SpaceWorldManager should report disconnected after disconnect_game()!")
		get_tree().quit(1)
		return
	if net.is_mission_started:
		print("FAIL: is_mission_started should be false after disconnect_game()!")
		get_tree().quit(1)
		return
	if flight_overlay.visible == false:
		print("FAIL: Flight overlay should reappear after disconnect!")
		get_tree().quit(1)
		return
	if cams_overlay.visible == false:
		print("FAIL: Cams overlay should reappear after disconnect!")
		get_tree().quit(1)
		return
	if swm.is_camera_window_open("front"):
		print("FAIL: Camera windows should close upon disconnect!")
		get_tree().quit(1)
		return
	print("SUCCESS: Disconnection cleanly resets ship state, closes feeds, and shows overlays.")
	
	print("\n--- Test 5: Multiplayer Host Connection & Mission Start ---")
	var err := net.host_game("Capitano", 7815, "Nave Multiplayer", 4)
	if err != OK:
		print("FAIL: Could not host game: ", err)
		get_tree().quit(1)
		return
	await get_tree().process_frame
	
	if swm.is_ship_connected():
		print("FAIL: Ship should NOT be connected before multiplayer mission start!")
		get_tree().quit(1)
		return
	if not flight_overlay.visible:
		print("FAIL: Flight overlay should be visible in multiplayer lobby before launch!")
		get_tree().quit(1)
		return
	print("SUCCESS: Multiplayer lobby created; ship remains offline until mission start.")
	
	# Launch multiplayer mission
	net.start_mission()
	await get_tree().process_frame
	
	if not swm.is_ship_connected():
		print("FAIL: Ship should be connected after start_mission() in multiplayer!")
		get_tree().quit(1)
		return
	if flight_overlay.visible:
		print("FAIL: Flight overlay should be hidden when multiplayer mission is running!")
		get_tree().quit(1)
		return
	print("SUCCESS: Multiplayer mission launch properly activates ship connection and controls.")
	
	net.disconnect_game()
	await get_tree().process_frame
	
	flight_app.queue_free()
	cams_app.queue_free()
	lobby_app.queue_free()
	
	print("\n=== ALL SHIP CONNECTION & SOLO MODE TESTS PASSED! ===")
	get_tree().quit(0)
