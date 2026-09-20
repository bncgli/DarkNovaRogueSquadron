extends GutTest

## Test end-to-end GUT del flusso Hardware -> Bus -> HAL -> Applicazioni GUI (Step 4).
## Verifica la propagazione atomica e reattiva degli stati senza disallineamenti.

var bus: ShipHardwareBus
var hal: ShipHAL
var reactor: ReactorComponent
var thruster: ThrusterComponent
var life_support: LifeSupportComponent

func before_each() -> void:
	bus = ShipHardwareBus.new()
	bus.name = "ShipHardwareBus"
	
	reactor = ReactorComponent.new("reactor_01", "engine_room", "engineering")
	reactor.power_output_nominal = 1000.0
	reactor.power_target = 1.0
	
	thruster = ThrusterComponent.new("thruster_01", "engine_room", "propulsion")
	thruster.max_thrust = 50.0
	
	life_support = LifeSupportComponent.new("life_support_01", "bridge", "life_support")
	
	bus.register_component(reactor)
	bus.register_component(thruster)
	bus.register_component(life_support)
	
	hal = ShipHAL.new(bus)
	hal.name = "ShipHAL"

func after_each() -> void:
	if hal:
		hal.free()
	if bus:
		bus.clear_all_components()
		bus.free()

func test_hal_propulsion_domain_contract() -> void:
	watch_signals(hal)
	
	# Condizione iniziale a pieno regime
	assert_almost_eq(hal.get_propulsion_efficiency(), 1.0, 0.01)
	assert_almost_eq(hal.get_total_available_thrust(), 50.0, 0.01)
	
	# Danneggiamento fisico del propulsore (simulazione impatto o guasto)
	thruster.apply_damage(50.0)
	thruster.step(0.1)
	
	# Verifica che HAL segnali la variazione del profilo
	assert_signal_emitted(hal, "propulsion_profile_changed")
	assert_almost_eq(hal.get_propulsion_efficiency(), 0.5, 0.01)
	assert_almost_eq(hal.get_total_available_thrust(), 25.0, 0.01)

func test_hal_power_and_grid_autobalance() -> void:
	watch_signals(hal)
	
	# Simuliamo carico consumatore
	thruster.set_throttle(1.0)
	bus.step(0.1)
	
	var telem := hal.get_power_telemetry()
	assert_gt(telem.get("generated_mw", 0.0), 0.0)
	assert_gt(telem.get("demanded_mw", 0.0), 0.0)
	assert_eq(telem.get("power_ratio", 0.0), 1.0)
	
	# Spegnimento stanza tramite HAL
	hal.toggle_room_power("engine_room", false)
	assert_false(thruster.is_online)
	assert_false(reactor.is_online)
	
	# Riaccensione
	hal.toggle_room_power("engine_room", true)
	assert_true(thruster.is_online)
	assert_true(reactor.is_online)

func test_hal_diagnostics_and_system_integrity() -> void:
	# A 100% per tutti i 3 componenti
	assert_almost_eq(hal.get_overall_system_integrity(), 100.0, 0.01)
	
	# Danneggiamo un componente
	reactor.apply_damage(30.0) # 70% salute
	# Media: (70 + 100 + 100) / 3 = 90%
	assert_almost_eq(hal.get_overall_system_integrity(), 90.0, 0.1)
	
	var damaged := hal.get_damaged_components(95.0)
	assert_eq(damaged.size(), 1)
	assert_eq(damaged[0].get("device_id"), "reactor_01")
	
	# Riparazione via HAL
	var repaired := hal.repair_device("reactor_01", 30.0)
	assert_true(repaired)
	assert_almost_eq(hal.get_overall_system_integrity(), 100.0, 0.01)

func test_hal_to_flight_control_app_reactive_flow() -> void:
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		nm.start_solo_game("Test Pilot")
		nm.start_mission()
		
	var flight_scene: PackedScene = load("res://Applications/FlightControl/flight_control_app.tscn")
	var flight_app: FlightControlApp = flight_scene.instantiate()
	add_child_autofree(flight_app)
	flight_app.can_control_flight = true
	
	# Simuliamo il cambio profilo propulsione tramite HAL
	hal.refresh_propulsion_profile()
	flight_app._on_hal_propulsion_changed(0.5, 50.0, 25.0)
	
	assert_almost_eq(flight_app.hal_efficiency, 0.5, 0.01)
	assert_almost_eq(flight_app.hal_available_thrust, 25.0, 0.01)
	if flight_app.thrusters_badge:
		assert_true(flight_app.thrusters_badge.text.contains("PROPULSORI DEGRADATI") or flight_app.thrusters_badge.text.contains("50%"))
		
	if nm:
		nm.disconnect_game()

func test_cli_sysfs_mutation_propagates_to_hal() -> void:
	var sysfs := VirtualSysfsDriver.new(bus)
	watch_signals(hal)
	
	# Modifica di un registro hardware da riga di comando sysfs
	var write_res := sysfs.write_file("/sys/rooms/engine_room/reactor_01/power_target", "0.5")
	assert_true(write_res.get("success", false))
	
	bus.step(0.1)
	
	# HAL rileva la variazione di erogazione e di stato
	var telem := hal.get_power_telemetry()
	assert_almost_eq(float(reactor.power_target), 0.5, 0.01)
	assert_almost_eq(float(reactor.power_output_current), 500.0, 0.01)

func test_hal_life_support_temperature_propagation() -> void:
	watch_signals(hal)
	
	# Initial condition
	var metrics := hal.get_life_support_metrics()
	assert_almost_eq(float(metrics.get("target_temp")), 21.0, 0.1)
	
	# Change target temp via HAL
	hal.set_target_temperature(24.5)
	assert_almost_eq(life_support.target_temp, 24.5, 0.1)
	
	# Step simulation
	for i in range(10):
		bus.step(1.0)
	
	var updated_metrics := hal.get_life_support_metrics()
	assert_almost_eq(float(updated_metrics.get("target_temp")), 24.5, 0.1)
	assert_gt(float(updated_metrics.get("temp")), 21.0)
