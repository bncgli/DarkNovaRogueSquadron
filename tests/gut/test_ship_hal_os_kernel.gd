extends GutTest

## Test Unitario GUT per il Kernel OS di ShipHAL e i suoi 10 sottosistemi tipizzati.
## Verifica la gestione delle chiamate di sistema, il ciclo di vita dei dispositivi e la resilienza ai guasti.

var bus: ShipHardwareBus
var hal: ShipHAL
var reactor: ReactorComponent
var battery: BatteryComponent
var helm: HelmControlComponent
var nav: NavComputerComponent
var sensors: SensorsMatrixComponent
var antenna: AntennaArrayComponent
var armory: ArmoryDefenseComponent
var shield_sx: ShieldBalancerComponent
var cargo: CargoHandlingComponent
var dock: RechargeDockComponent
var server: ServerRackComponent
var cam: CamArrayComponent

func before_each() -> void:
	bus = ShipHardwareBus.new()
	bus.name = "ShipHardwareBus"
	
	reactor = ReactorComponent.new("core_reactor", "reactor", "reactor")
	reactor.power_output_nominal = 1000.0
	battery = BatteryComponent.new("battery_01", "reactor", "engineering")
	helm = HelmControlComponent.new("helm_control", "bridge", "command")
	nav = NavComputerComponent.new("nav_computer", "bridge", "command")
	sensors = SensorsMatrixComponent.new("sensors_matrix", "sensors", "sensors")
	antenna = AntennaArrayComponent.new("antenna_array", "comms", "comms")
	armory = ArmoryDefenseComponent.new("armory_defense", "armory", "tactical")
	shield_sx = ShieldBalancerComponent.new("arm_sx_balancer", "room_14", "defense")
	cargo = CargoHandlingComponent.new("cargo_handling", "cargo", "cargo")
	dock = RechargeDockComponent.new("recharge_dock", "cargo", "engineering")
	server = ServerRackComponent.new("server_rack", "mainframe", "cyber")
	cam = CamArrayComponent.new("cam_array", "bridge", "sensors")
	
	bus.register_component(reactor)
	bus.register_component(battery)
	bus.register_component(helm)
	bus.register_component(nav)
	bus.register_component(sensors)
	bus.register_component(antenna)
	bus.register_component(armory)
	bus.register_component(shield_sx)
	bus.register_component(cargo)
	bus.register_component(dock)
	bus.register_component(server)
	bus.register_component(cam)
	
	bus.step(0.1)
	hal = ShipHAL.new(bus)
	hal.name = "ShipHAL"

func after_each() -> void:
	if hal:
		hal.free()
	if bus:
		bus.clear_all_components()
		bus.free()

func test_device_lifecycle_reactive_events() -> void:
	watch_signals(hal)
	
	var aux_device := ShipPhysicalComponent.new("aux_thruster", "engine", "propulsion")
	bus.register_component(aux_device)
	
	assert_signal_emitted_with_parameters(hal, "device_lifecycle_changed", ["aux_thruster", "REGISTERED"])
	assert_true(hal.is_device_online("aux_thruster"))
	
	bus.unregister_component("aux_thruster")
	assert_signal_emitted_with_parameters(hal, "device_lifecycle_changed", ["aux_thruster", "UNREGISTERED"])
	assert_null(hal.find_component_for_device("aux_thruster"))
	aux_device.free()

func test_power_subsystem_telemetry_and_blackout() -> void:
	watch_signals(hal)
	
	var balance := hal.power.get_balance()
	assert_gt(balance.get("generated_mw", 0.0), 0.0)
	assert_false(hal.power.is_blackout())
	assert_true(hal.power.is_operational())
	
	# Spegnimento reattore e svuotamento batterie
	reactor.set_online(false)
	battery.charge_current = 0.0
	bus.step(0.1)
	
	assert_true(hal.power.is_blackout())
	assert_almost_eq(hal.power.get_balance().get("power_ratio", 1.0), 0.0, 0.01)
	assert_false(hal.is_device_powered("helm_control"))
	assert_false(hal.propulsion.can_control_flight())

func test_propulsion_and_flight_controls_coupling() -> void:
	watch_signals(hal)
	assert_true(hal.propulsion.can_control_flight())
	
	# Spegnimento stanza bridge (helm_control)
	hal.toggle_room_power("bridge", false)
	assert_false(helm.is_online)
	assert_false(hal.propulsion.can_control_flight())
	
	# Riaccensione
	hal.toggle_room_power("bridge", true)
	assert_true(helm.is_online)
	assert_true(hal.propulsion.can_control_flight())

func test_navigation_subsystem_route_calculation() -> void:
	var solution := hal.navigation.calculate_route(Vector2(10.0, 20.0))
	assert_true(solution.get("success", false))
	assert_gt(solution.get("distance", 0.0), 0.0)
	assert_gt(solution.get("eta", 0.0), 0.0)
	
	# Se nav_computer è offline, il calcolo fallisce
	nav.set_online(false)
	bus.step(0.1)
	var fail_sol := hal.navigation.calculate_route(Vector2(5.0, 5.0))
	assert_false(fail_sol.get("success", true))

func test_sensors_subsystem_sweep_and_ping() -> void:
	assert_true(hal.sensors.is_operational())
	assert_true(hal.sensors.toggle_sweep(true))
	
	var ping_contacts := hal.sensors.trigger_active_ping()
	assert_not_null(ping_contacts)
	assert_true(ping_contacts is Array)

func test_comms_subsystem_azimuth_and_frequencies() -> void:
	assert_true(hal.comms.rotate_antenna(270.0))
	assert_almost_eq(float(antenna.azimuth_deg), 270.0, 0.1)
	
	assert_true(hal.comms.lock_frequency(1420.0))
	assert_almost_eq(antenna.locked_frequency, 1420.0, 0.1)
	
	var freqs := hal.comms.get_visible_frequencies()
	assert_true(freqs.size() > 0)

func test_defense_subsystem_shield_balancer() -> void:
	assert_true(hal.defense.set_shield_distribution(Vector2(0.5, 0.5)))
	assert_almost_eq(shield_sx.distribution.x, 0.5, 0.01)
	assert_almost_eq(shield_sx.distribution.y, 0.5, 0.01)
	
	assert_true(hal.defense.activate_shield_boost("front"))
	assert_gt(shield_sx.front_hp, 100.0)

func test_logistics_and_cargo_subsystem() -> void:
	assert_true(hal.logistics.toggle_cargo_doors(true))
	assert_true(cargo.doors_open)
	assert_true(hal.logistics.toggle_cargo_doors(false))
	assert_false(cargo.doors_open)
	
	var charged := hal.logistics.charge_duct_drone(40.0, 1.0)
	assert_gt(charged, 40.0)

func test_cyber_subsystem_mainframe_and_exploits() -> void:
	assert_true(hal.cyber.is_operational())
	assert_true(hal.cyber.start_exploit("test_worm"))
	assert_eq(server.active_exploit, "test_worm")
	
	hal.cyber.cancel_exploit()
	assert_eq(server.active_exploit, "")

func test_optics_subsystem_channels() -> void:
	assert_true(hal.optics.set_active_channel(4))
	assert_eq(cam.active_camera_channel, 4)
	assert_true(hal.optics.toggle_all_floodlights(true))
	assert_gt(cam.floodlights_mask, 0)

func test_atomic_hardware_actions_dispatch() -> void:
	var act_res := hal.execute_hardware_action("propulsion", "speed_limit", {"value": 1.8})
	assert_true(act_res.get("success", false))
	assert_almost_eq(helm.speed_limiter, 1.8, 0.01)
	
	var q_health := hal.query_subsystem_health("cyber")
	assert_eq(q_health.get("status"), "ONLINE")
	assert_almost_eq(float(q_health.get("health")), 100.0, 0.1)
