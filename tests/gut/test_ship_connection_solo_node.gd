extends GutTest

## Test GUT per lo Stato di Connessione Nave & Modalità Solo (Ship Connection & Solo Mode).
## Le funzioni condividono lo stato (`flight_app`, `cams_app`, `lobby_app`, overlay) creato/liberato
## manualmente in before_all/after_all (add_child_autofree libererebbe già al termine del
## singolo test, rompendo la sequenza che attraversa più fasi di connessione/disconnessione).

var flight_app: FlightControlApp
var cams_app: Node
var lobby_app: Node
var flight_overlay: Control
var cams_overlay: Control

func before_all() -> void:
	var flight_scene: PackedScene = load("res://Applications/FlightControl/flight_control_app.tscn")
	var cams_scene: PackedScene = load("res://Applications/Cams/cams_app.tscn")
	var lobby_scene: PackedScene = load("res://Applications/Lobby/lobby_app.tscn")

	assert_not_null(flight_scene, "Scena flight_control_app.tscn valida")
	assert_not_null(cams_scene, "Scena cams_app.tscn valida")
	assert_not_null(lobby_scene, "Scena lobby_app.tscn valida")

	flight_app = flight_scene.instantiate() as FlightControlApp
	cams_app = cams_scene.instantiate()
	lobby_app = lobby_scene.instantiate()

	add_child(flight_app)
	add_child(cams_app)
	add_child(lobby_app)
	await get_tree().process_frame

	flight_overlay = flight_app.get_node_or_null("%DisconnectedOverlay")
	cams_overlay = cams_app.get_node_or_null("%DisconnectedOverlay")

func after_all() -> void:
	if is_instance_valid(flight_app):
		flight_app.free()
	if is_instance_valid(cams_app):
		cams_app.free()
	if is_instance_valid(lobby_app):
		lobby_app.free()

func test_initial_state_is_disconnected() -> void:
	assert_false(SpaceWorldManager.is_ship_connected(), "Ship should be disconnected at startup")
	assert_false(NetworkManager.is_ship_connected(), "NetworkManager should report ship disconnected at startup")

func test_flight_control_and_cams_overlay_when_disconnected() -> void:
	assert_not_null(flight_overlay, "FlightControl disconnected overlay must exist")
	assert_true(flight_overlay.visible, "FlightControl disconnected overlay is not visible when disconnected")
	assert_not_null(cams_overlay, "Cams disconnected overlay must exist")
	assert_true(cams_overlay.visible, "Cams disconnected overlay is not visible when disconnected")

	# Verify camera won't open when disconnected
	var cam_win := SpaceWorldManager.open_camera_window("front")
	assert_null(cam_win, "Camera window opened while disconnected")

func test_solo_mode_lobby_and_mission_start() -> void:
	var solo_btn: Button = lobby_app.get_node_or_null("%SoloButton")
	assert_not_null(solo_btn, "SoloButton not found in LobbyApp")

	# Enter solo mode (lobby phase)
	NetworkManager.start_solo_game("Comandante Solo")
	await get_tree().process_frame

	assert_true(NetworkManager.is_solo_mode, "NetworkManager is_solo_mode should be true")
	assert_false(NetworkManager.is_mission_started, "Mission should NOT be started yet in solo lobby")
	assert_false(NetworkManager.is_ship_connected(), "Ship should NOT be connected before mission launch")
	assert_false(SpaceWorldManager.is_ship_connected(), "SpaceWorldManager should report disconnected before mission launch")

	flight_app._process(0.016)
	cams_app._update_status_summary()
	await get_tree().process_frame

	assert_true(flight_overlay.visible, "Flight overlay should remain visible in solo lobby before launch")
	assert_true(cams_overlay.visible, "Cams overlay should remain visible in solo lobby before launch")

	# Launch solo mission
	NetworkManager.start_mission()
	await get_tree().process_frame

	assert_true(NetworkManager.is_mission_started, "is_mission_started should be true after start_mission()")
	assert_true(NetworkManager.is_ship_connected(), "NetworkManager is_ship_connected should be true after start_mission()")
	assert_true(SpaceWorldManager.is_ship_connected(), "SpaceWorldManager is_ship_connected should be true after start_mission()")

	flight_app._process(0.016)
	cams_app._update_status_summary()
	await get_tree().process_frame

	assert_false(flight_overlay.visible, "Flight overlay should be hidden after mission launch")
	assert_false(cams_overlay.visible, "Cams overlay should be hidden after mission launch")

	# Test flight control in solo mode
	flight_app._ui_linear_input = Vector3(0, 0, -1)
	flight_app._process(0.016)
	await get_tree().process_frame

	var ship := SpaceWorldManager.get_spaceship()
	assert_eq(ship.linear_input.z, -1.0, "Flight input was not passed to ship during solo mode")

	# Test camera open in solo mode
	var cam_front_win := SpaceWorldManager.open_camera_window("front")
	assert_true(cam_front_win != null and SpaceWorldManager.is_camera_window_open("front"), "Camera window could not be opened in solo mode")

func test_disconnecting_from_solo_mode() -> void:
	NetworkManager.disconnect_game()
	await get_tree().process_frame

	assert_false(SpaceWorldManager.is_ship_connected(), "SpaceWorldManager should report disconnected after disconnect_game()")
	assert_false(NetworkManager.is_mission_started, "is_mission_started should be false after disconnect_game()")
	assert_true(flight_overlay.visible, "Flight overlay should reappear after disconnect")
	assert_true(cams_overlay.visible, "Cams overlay should reappear after disconnect")
	assert_false(SpaceWorldManager.is_camera_window_open("front"), "Camera windows should close upon disconnect")

func test_multiplayer_host_connection_and_mission_start() -> void:
	var err := NetworkManager.host_game("Capitano", 7815, "Nave Multiplayer", 4)
	assert_eq(err, OK, "Could not host game")
	await get_tree().process_frame

	assert_false(SpaceWorldManager.is_ship_connected(), "Ship should NOT be connected before multiplayer mission start")
	assert_true(flight_overlay.visible, "Flight overlay should be visible in multiplayer lobby before launch")

	# Launch multiplayer mission
	NetworkManager.start_mission()
	await get_tree().process_frame

	assert_true(SpaceWorldManager.is_ship_connected(), "Ship should be connected after start_mission() in multiplayer")
	assert_false(flight_overlay.visible, "Flight overlay should be hidden when multiplayer mission is running")

	NetworkManager.disconnect_game()
	await get_tree().process_frame
