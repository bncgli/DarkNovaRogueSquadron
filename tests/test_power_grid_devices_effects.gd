extends SceneTree

class MockTerminal extends Terminal:
	var output_log: Array[String] = []
	var ship_hal: ShipHAL = null
	var ship_bus: ShipHardwareBus = null
	func push_line_to_output(text: String) -> void:
		output_log.append(text)
	func push_lines_to_output(lines: Array[String]) -> void:
		for l in lines:
			output_log.append(l)

func _init() -> void:
	print("================================================================================")
	print("--- STARTING POWER GRID 19 DEVICES & SHIP HAL OS VERIFICATION SUITE ---")
	print("================================================================================")
	
	const BP_PATH := "res://Outside/ShipSublayer/hal_test_ship_blueprint.tres"
	var bp := ResourceLoader.load(BP_PATH) as ShipBlueprint
	assert(bp != null, "hal_test_ship_blueprint.tres must load")
	
	var bus := ShipHardwareBus.new()
	bus.load_from_blueprint(bp)
	bus.step(0.1)
	
	var hal := ShipHAL.new(bus)
	var terminal := MockTerminal.new()
	terminal.ship_hal = hal
	terminal.ship_bus = bus
	
	# -------------------------------------------------------------------------
	# TEST 1: Canonical 19 Device Classes Verification
	# -------------------------------------------------------------------------
	print("\n[TEST 1] Verifying all 19 canonical physical component classes on bus...")
	var expected_devices: Dictionary = {
		"core_reactor": "ReactorComponent",
		"battery_01": "BatteryComponent",
		"cooling_01": "CoolingComponent",
		"engine_main": "ThrusterComponent",
		"rcs_pitch_l": "ThrusterComponent",
		"rcs_pitch_r": "ThrusterComponent",
		"helm_control": "HelmControlComponent",
		"nav_computer": "NavComputerComponent",
		"sensors_matrix": "SensorsMatrixComponent",
		"antenna_array": "AntennaArrayComponent",
		"armory_defense": "ArmoryDefenseComponent",
		"arm_sx_balancer": "ShieldBalancerComponent",
		"arm_dx_balancer": "ShieldBalancerComponent",
		"scrubber": "LifeSupportComponent",
		"heater": "LifeSupportComponent",
		"serra_idroponica": "LifeSupportComponent",
		"cargo_handling": "CargoHandlingComponent",
		"dronestation": "DroneStationComponent",
		"recharge_dock": "RechargeDockComponent",
		"server_rack": "ServerRackComponent",
		"cam_array": "CamArrayComponent"
	}
	
	for dev_id in expected_devices:
		assert(bus.has_component(dev_id), "Bus must have component: " + dev_id)
		var comp := bus.get_component(dev_id)
		var expected_cls: String = expected_devices[dev_id]
		var type_match := false
		match expected_cls:
			"ReactorComponent": type_match = (comp is ReactorComponent)
			"BatteryComponent": type_match = (comp is BatteryComponent)
			"CoolingComponent": type_match = (comp is CoolingComponent)
			"ThrusterComponent": type_match = (comp is ThrusterComponent)
			"HelmControlComponent": type_match = (comp is HelmControlComponent)
			"NavComputerComponent": type_match = (comp is NavComputerComponent)
			"SensorsMatrixComponent": type_match = (comp is SensorsMatrixComponent)
			"AntennaArrayComponent": type_match = (comp is AntennaArrayComponent)
			"ArmoryDefenseComponent": type_match = (comp is ArmoryDefenseComponent)
			"ShieldBalancerComponent": type_match = (comp is ShieldBalancerComponent)
			"LifeSupportComponent": type_match = (comp is LifeSupportComponent)
			"CargoHandlingComponent": type_match = (comp is CargoHandlingComponent)
			"DroneStationComponent": type_match = (comp is DroneStationComponent)
			"RechargeDockComponent": type_match = (comp is RechargeDockComponent)
			"ServerRackComponent": type_match = (comp is ServerRackComponent)
			"CamArrayComponent": type_match = (comp is CamArrayComponent)
		assert(type_match, "Component %s must be instance of %s" % [dev_id, expected_cls])
		assert(comp.is_online, "Component %s must initially be online" % dev_id)
		assert(hal.is_device_powered(dev_id), "Component %s must initially be powered" % dev_id)
	
	print("-> PASS: All 19 physical component classes instantiated and online.")
	
	# -------------------------------------------------------------------------
	# TEST 2: Dynamic Device Addition and Removal (Editor Blueprint support)
	# -------------------------------------------------------------------------
	print("\n[TEST 2] Testing dynamic device addition and removal on bus & HAL...")
	var lifecycle_events: Array[Dictionary] = []
	hal.device_lifecycle_changed.connect(func(id: String, act: String):
		lifecycle_events.append({"id": id, "action": act})
	)
	
	var custom_dev := ShipPhysicalComponent.new("custom_aux_dev", "cargo", "utility")
	bus.register_component(custom_dev)
	assert(bus.has_component("custom_aux_dev"), "Custom device must be registered on bus")
	assert(lifecycle_events.size() > 0 and lifecycle_events[-1]["id"] == "custom_aux_dev" and lifecycle_events[-1]["action"] == "REGISTERED", "HAL must receive device registered signal")
	
	bus.unregister_component("custom_aux_dev")
	assert(not bus.has_component("custom_aux_dev"), "Custom device must be unregistered from bus")
	assert(lifecycle_events[-1]["id"] == "custom_aux_dev" and lifecycle_events[-1]["action"] == "UNREGISTERED", "HAL must receive device unregistered signal")
	custom_dev.free()
	print("-> PASS: Dynamic device addition/removal correctly observed by HAL.")

	# -------------------------------------------------------------------------
	# TEST 3: Room Breaker Cascade & HAL Subsystems
	# -------------------------------------------------------------------------
	print("\n[TEST 3] Testing Room Breaker Cascade and HAL Typed Subsystems...")
	# Verify propulsion lock when helm_control room is off
	assert(hal.propulsion.can_control_flight(), "Flight controls must be enabled initially")
	hal.toggle_room_power("bridge", false)
	assert(not hal.is_device_powered("helm_control"), "helm_control must be unpowered when bridge is off")
	assert(not hal.propulsion.can_control_flight(), "Flight controls must be locked when helm_control is unpowered")
	assert(not hal.navigation.is_operational(), "Navigation must be offline when bridge is off")
	
	# Restore bridge
	hal.toggle_room_power("bridge", true)
	assert(hal.propulsion.can_control_flight(), "Flight controls must restore when bridge is powered")
	assert(hal.navigation.is_operational(), "Navigation must restore when bridge is powered")
	
	# Test Sensors Subsystem ping & sweep
	assert(hal.sensors.is_operational(), "Sensors must be operational")
	var ping_result := hal.sensors.trigger_active_ping()
	assert(ping_result is Array, "Active ping must return an array of contacts")
	
	# Test Defense Subsystem shields & emergency boost
	var defense_status := hal.defense.get_status()
	assert(defense_status.has("shields"), "Defense status must contain shields dictionary")
	assert(hal.defense.set_shield_distribution(Vector2(0.5, -0.2)), "Setting shield distribution must succeed")
	assert(hal.defense.activate_shield_boost("front"), "Emergency boost on front shield must succeed")
	
	# Test Logistics / Cargo Subsystem
	assert(hal.logistics.toggle_cargo_doors(true), "Opening cargo doors must succeed")
	assert(hal.logistics.get_status().get("doors_open") == true, "Cargo doors must report open")
	assert(hal.logistics.toggle_cargo_doors(false), "Closing cargo doors must succeed")
	
	# Test Duct Drone Charging via Recharge Dock
	var recharged_bat := hal.logistics.charge_duct_drone(50.0, 1.0)
	assert(recharged_bat > 50.0, "Duct drone must receive charge from dock")
	
	# Test Cyber Subsystem and Mainframe
	assert(hal.cyber.is_operational(), "Cyber subsystem must be operational")
	assert(hal.cyber.start_exploit("test_exploit"), "Starting exploit on online mainframe must succeed")
	hal.cyber.cancel_exploit()
	
	# Test Optics Subsystem
	assert(hal.optics.set_active_channel(3), "Setting active camera channel must succeed")
	assert(hal.optics.get_status().get("active_channel") == 3, "Optics status must report channel 3")
	
	print("-> PASS: Room breaker cascade and typed subsystems verified.")

	# -------------------------------------------------------------------------
	# TEST 4: Blackout Cascade (Reactor Off -> Battery Depletion -> Shutdown)
	# -------------------------------------------------------------------------
	print("\n[TEST 4] Testing Blackout Cascade on Reactor Shutdown & Battery Depletion...")
	var reactor := hal.find_component_for_device("core_reactor") as ReactorComponent
	var battery := hal.find_component_for_device("battery_01") as BatteryComponent
	assert(reactor != null and battery != null, "Reactor and Battery must exist")
	
	# Shut down reactor
	reactor.set_online(false)
	bus.step(0.1)
	assert(bus.total_generated_mw == 0.0, "Total generated power must be 0 MW with reactor offline")
	
	# Force battery depletion
	battery.charge_current = 0.0
	bus.step(0.1)
	assert(bus.is_blackout, "Bus must enter blackout when battery is empty")
	assert(bus.power_ratio == 0.0, "Power ratio must drop to 0.0 during blackout")
	assert(not hal.is_device_powered("engine_main"), "Consumers must lose power during blackout")
	assert(not hal.is_device_powered("sensors_matrix"), "Sensors must lose power during blackout")
	assert(not hal.propulsion.can_control_flight(), "Flight controls must be inhibited during blackout")
	
	# Restore reactor and recharge battery
	reactor.set_online(true)
	battery.charge_current = 500.0
	bus.step(0.1)
	assert(not bus.is_blackout, "Bus must recover from blackout after reactor is restored")
	assert(bus.power_ratio == 1.0, "Power ratio must restore to 1.0")
	print("-> PASS: Blackout cascade and grid recovery deterministically verified.")

	# -------------------------------------------------------------------------
	# TEST 5: CLI Commands Hardware Pre-checks and Execution
	# -------------------------------------------------------------------------
	print("\n[TEST 5] Testing CLI Commands ('flight', 'nav', 'sensors', 'comms', 'dev')...")
	var FlightCmd = load("res://Applications/Terminal/commands/flight_command.gd")
	var NavCmd = load("res://Applications/Terminal/commands/nav_command.gd")
	var SensorsCmd = load("res://Applications/Terminal/commands/sensors_command.gd")
	var CommsCmd = load("res://Applications/Terminal/commands/comms_command.gd")
	var DevCmd = load("res://Applications/Terminal/commands/dev_command.gd")
	
	assert(FlightCmd != null and NavCmd != null and SensorsCmd != null and CommsCmd != null and DevCmd != null, "All commands must load")
	
	var flight_cmd = FlightCmd.new()
	var nav_cmd = NavCmd.new()
	var sensors_cmd = SensorsCmd.new()
	var comms_cmd = CommsCmd.new()
	var dev_cmd = DevCmd.new()
	
	if terminal:
		# Test 'flight' commands
		terminal.output_log.clear()
		var args_fl1: Array[String] = ["toggle_inertia", "on"]
		flight_cmd.execute(terminal, args_fl1)
		assert(hal.propulsion.get_status().get("inertia_damping") == true, "flight toggle_inertia must update propulsion subsystem")
		
		terminal.output_log.clear()
		var args_fl2: Array[String] = ["set_speed", "1.5"]
		flight_cmd.execute(terminal, args_fl2)
		assert(hal.propulsion.get_status().get("speed_limiter") == 1.5, "flight set_speed must update speed limiter")
		
		# Test 'nav' command
		terminal.output_log.clear()
		var args_nav: Array[String] = ["position"]
		nav_cmd.execute(terminal, args_nav)
		assert(terminal.output_log.size() > 0, "'nav position' must return localization output")
		
		# Test 'sensors' command
		terminal.output_log.clear()
		var args_sens: Array[String] = ["sweep", "on"]
		sensors_cmd.execute(terminal, args_sens)
		assert(hal.sensors.get_status().get("is_sweeping") == true, "sensors sweep on must update sensors subsystem")
		
		# Test 'comms' command
		terminal.output_log.clear()
		var args_comm1: Array[String] = ["rotate", "180"]
		comms_cmd.execute(terminal, args_comm1)
		assert(int(hal.comms.get_status().get("azimuth")) == 180, "comms rotate must update antenna array azimuth")
		
		terminal.output_log.clear()
		var args_comm2: Array[String] = ["lock_frequency", "1420.0"]
		comms_cmd.execute(terminal, args_comm2)
		assert(hal.comms.get_status().get("locked_freq") == 1420.0, "comms lock_frequency must update locked frequency")
		
		# Test 'dev' command
		terminal.output_log.clear()
		var args_dev1: Array[String] = ["list"]
		dev_cmd.execute(terminal, args_dev1)
		assert(terminal.output_log.size() > 0, "'dev list' must list all registered components")
		
		terminal.output_log.clear()
		var args_dev2: Array[String] = ["status", "core_reactor"]
		dev_cmd.execute(terminal, args_dev2)
		assert(terminal.output_log.size() > 0, "'dev status core_reactor' must return device registers")
	
	print("-> PASS: CLI commands executed successfully via ShipHAL.")

	# -------------------------------------------------------------------------
	# TEST 6: Blueprint Canonical Devices & Room Migration (Sublayer Editor)
	# -------------------------------------------------------------------------
	print("\n[TEST 6] Testing Blueprint Canonical Devices & Room Migration...")
	assert(ShipDeviceData.CANONICAL_DEVICES.size() >= 20, "Canonical devices catalog must be present")
	var new_canonical_dev := ShipDeviceData.create_canonical_device("sensors_matrix", bp.get_unique_device_id("sensors_matrix"), "bridge", Vector2(100, 100))
	assert(new_canonical_dev != null and new_canonical_dev.component_class == "SensorsMatrixComponent", "Canonical device must be properly created")
	
	# Add to room and test move_device_to_room
	if bp.rooms.size() >= 2:
		var room_a := bp.rooms[0] as ShipRoomData
		var room_b := bp.rooms[1] as ShipRoomData
		var dev_to_move := ShipDeviceData.create_canonical_device("dronestation", bp.get_unique_device_id("dronestation"), room_a.name, room_a.rect.get_center())
		room_a.devices.append(dev_to_move)
		bp.recalculate_all_powers()
		
		var init_power_a := room_a.power_mw
		var init_power_b := room_b.power_mw
		
		assert(bp.find_room_by_device_id(dev_to_move.id) == room_a, "find_room_by_device_id must locate source room")
		assert(bp.move_device_to_room(dev_to_move.id, room_b.id), "move_device_to_room must succeed")
		assert(bp.find_room_by_device_id(dev_to_move.id) == room_b, "find_room_by_device_id must locate target room after move")
		assert(room_a.power_mw != init_power_a, "Source room power must be updated")
		assert(room_b.power_mw != init_power_b, "Target room power must be updated")
		assert(dev_to_move.pos == room_b.rect.get_center(), "Device pos must be recentered in target room")
		
		# Clean up added dev
		bp.remove_device(dev_to_move.id)
	
	print("-> PASS: Blueprint canonical device creation, unique IDs, and room migration verified.")

	print("\n================================================================================")
	print("--- ALL 19 DEVICES, SHIP HAL OS, AND CLI TESTS PASSED (100%) ---")
	print("================================================================================")
	
	hal.free()
	bus.clear_all_components()
	bus.free()
	if terminal:
		terminal.free()
	
	quit(0)
