extends SceneTree

func _init() -> void:
	print("================================================================================")
	print("--- STARTING POWER GRID DEVICES & CLI SUBSYSTEM VERIFICATION SUITE ---")
	print("================================================================================")
	
	const BP_PATH := "res://Outside/ShipSublayer/hal_test_ship_blueprint.tres"
	var bp := ResourceLoader.load(BP_PATH) as ShipBlueprint
	assert(bp != null, "hal_test_ship_blueprint.tres must load")
	
	var bus := ShipHardwareBus.new()
	bus.load_from_blueprint(bp)
	bus.step(0.1)
	
	var hal := ShipHAL.new(bus)
	
	# Mock Terminal for command execution
	var terminal_script = load("res://Applications/Terminal/src/script_classes/terminal.gd")
	var terminal: Terminal = null
	if terminal_script:
		terminal = terminal_script.new()
	
	# Helper mock for output capturing if terminal is headless
	var output_log: Array[String] = []
	if terminal:
		terminal.line_output_received.connect(func(msg: String): output_log.append(msg))
	
	# -------------------------------------------------------------------------
	# TEST 1: Room-Device Power Cascade
	# -------------------------------------------------------------------------
	print("\n[TEST 1] Testing Room Breaker Cascade to Physical Components...")
	assert(hal.is_device_online("engine_main"), "engine_main must initially be online")
	assert(hal.is_device_powered("engine_main"), "engine_main must initially be powered")
	
	# Turn off engine_room
	hal.toggle_room_power("engine_room", false)
	assert(not hal.is_device_online("engine_main"), "engine_main must be offline after turning off engine_room")
	assert(not hal.is_device_powered("engine_main"), "engine_main must not be powered after turning off engine_room")
	
	# Restore engine_room
	hal.toggle_room_power("engine_room", true)
	assert(hal.is_device_online("engine_main"), "engine_main must be online after restoring engine_room")
	print("-> PASS: Room breaker cascade operates correctly.")
	
	# -------------------------------------------------------------------------
	# TEST 2: Reactor 250°C Thermal Scram Safety Trigger
	# -------------------------------------------------------------------------
	print("\n[TEST 2] Testing Reactor 250°C Thermal Scram...")
	var reactor := hal.find_component_for_device("core_reactor") as ReactorComponent
	assert(reactor != null, "core_reactor component must exist on bus")
	reactor.heat_current = 250.0
	reactor.step(0.1)
	assert(not reactor.is_online, "Reactor must be offline after thermal scram >= 250C")
	assert(reactor.power_output_current == 0.0, "Reactor power output must drop to 0 MW on scram")
	assert(reactor.status_string == "SCRAM", "Reactor status must be SCRAM")
	print("-> PASS: Thermal scram triggered at 250°C successfully.")
	
	# Re-arm reactor for CLI tests
	reactor.heat_current = 50.0
	reactor.set_online(true)
	reactor.step(0.1)
	
	# -------------------------------------------------------------------------
	# TEST 3: CLI Flight Command Hardware Lockout & Execution
	# -------------------------------------------------------------------------
	print("\n[TEST 3] Testing CLI 'flight' Command Hardware Pre-Checks...")
	var FlightCmd = load("res://Applications/Terminal/commands/flight_command.gd")
	assert(FlightCmd != null, "flight_command.gd must load")
	var flight_cmd = FlightCmd.new()
	
	if terminal:
		# Test unpowered engine_main lockout
		hal.toggle_room_power("engine_room", false)
		output_log.clear()
		flight_cmd.execute(terminal, ["forward", "10"])
		assert(output_log.size() > 0, "Flight command must produce an error log")
		var has_err := false
		for line in output_log:
			if "ERRORE HARDWARE" in line and "engine_main" in line:
				has_err = true
				break
		assert(has_err, "Flight forward command must reject execution when engine_main is offline")
		print("-> PASS: 'flight forward' hardware lockout verified.")
		
		# Test unpowered helm_control lockout
		hal.toggle_room_power("engine_room", true)
		hal.toggle_room_power("bridge", false)
		output_log.clear()
		flight_cmd.execute(terminal, ["set_speed", "1.5"])
		has_err = false
		for line in output_log:
			if "ERRORE HARDWARE" in line and "helm_control" in line:
				has_err = true
				break
		assert(has_err, "Flight command must reject when helm_control is offline")
		print("-> PASS: 'flight' helm_control lockout verified.")
		
		# Restore bridge & engine
		hal.toggle_room_power("bridge", true)
	
	# -------------------------------------------------------------------------
	# TEST 4: CLI Nav, Sensors & Comms Hardware Lockout
	# -------------------------------------------------------------------------
	print("\n[TEST 4] Testing CLI 'nav', 'sensors', and 'comms' Lockouts...")
	var NavCmd = load("res://Applications/Terminal/commands/nav_command.gd")
	var SensorsCmd = load("res://Applications/Terminal/commands/sensors_command.gd")
	var CommsCmd = load("res://Applications/Terminal/commands/comms_command.gd")
	assert(NavCmd != null and SensorsCmd != null and CommsCmd != null, "Commands must load")
	
	var nav_cmd = NavCmd.new()
	var sensors_cmd = SensorsCmd.new()
	var comms_cmd = CommsCmd.new()
	
	if terminal:
		# Nav lockout when nav_computer offline
		hal.toggle_room_power("bridge", false)
		output_log.clear()
		nav_cmd.execute(terminal, ["calculate", "5", "5"])
		var nav_rejected := false
		for line in output_log:
			if "ERRORE HARDWARE" in line and "nav_computer" in line:
				nav_rejected = true
				break
		assert(nav_rejected, "'nav calculate' must reject when nav_computer is unpowered")
		hal.toggle_room_power("bridge", true)
		print("-> PASS: 'nav' hardware lockout verified.")
		
		# Sensors lockout when sensors_matrix offline
		hal.toggle_room_power("sensors", false)
		output_log.clear()
		sensors_cmd.execute(terminal, ["get_targets"])
		var sensors_rejected := false
		for line in output_log:
			if "ERRORE HARDWARE" in line and "sensors_matrix" in line:
				sensors_rejected = true
				break
		assert(sensors_rejected, "'sensors get_targets' must reject when sensors_matrix is unpowered")
		hal.toggle_room_power("sensors", true)
		print("-> PASS: 'sensors' hardware lockout verified.")
		
		# Comms lockout when antenna_array offline
		hal.toggle_room_power("comms", false)
		output_log.clear()
		comms_cmd.execute(terminal, ["get_frequency"])
		var comms_rejected := false
		for line in output_log:
			if "ERRORE HARDWARE" in line and "antenna_array" in line:
				comms_rejected = true
				break
		assert(comms_rejected, "'comms get_frequency' must reject when antenna_array is unpowered")
		hal.toggle_room_power("comms", true)
		print("-> PASS: 'comms' hardware lockout verified.")
	
	# -------------------------------------------------------------------------
	# TEST 5: Interactive Radio Listener Mode ('comms listen_frequency')
	# -------------------------------------------------------------------------
	print("\n[TEST 5] Testing Interactive Radio Listener Mode...")
	if terminal:
		output_log.clear()
		comms_cmd.execute(terminal, ["listen_frequency", "1420.0"])
		assert(terminal.active_interactive_command == comms_cmd, "Terminal active_interactive_command must be set to comms_cmd")
		assert(comms_cmd.listening_frequency == 1420.0, "Listening frequency must be 1420.0 MHz")
		
		# Simulate stream packet reception
		comms_cmd.handle_interactive_input(terminal, "step")
		assert(output_log.size() > 0, "Interactive listening must produce packet output")
		
		# Terminate interactive listening with 'q'
		comms_cmd.handle_interactive_input(terminal, "q")
		assert(terminal.active_interactive_command == null, "Terminal interactive mode must exit after 'q'")
		print("-> PASS: Interactive radio listener start, packet stepping, and exit with 'q' verified.")
	
	print("\n================================================================================")
	print("--- ALL POWER GRID DEVICES & CLI SUBSYSTEM TESTS PASSED SUCCESSFULLY! ---")
	print("================================================================================")
	
	hal.free()
	bus.clear_all_components()
	bus.free()
	if terminal:
		terminal.free()
	
	quit(0)
