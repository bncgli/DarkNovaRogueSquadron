extends GutTest

## Test di integrazione GUT per ShipHardwareBus (Step 2).
## Valida throughput, registrazione dinamica, instradamento comandi, bilanciamento Power/Thermal Grid e blackout.

func test_hardware_bus_registration_and_indexing() -> void:
	var bus := ShipHardwareBus.new()
	var comp1 := ShipPhysicalComponent.new("dev_01", "bridge", "command")
	var comp2 := ThrusterComponent.new("dev_02", "engine_room", "propulsion")
	var comp3 := ReactorComponent.new("dev_03", "engine_room", "engineering")
	
	bus.register_component(comp1)
	bus.register_component(comp2)
	bus.register_component(comp3)
	
	assert_eq(bus.get_all_components().size(), 3)
	assert_true(bus.has_component("dev_01"))
	assert_true(bus.has_component("dev_02"))
	assert_true(bus.has_component("dev_03"))
	
	# Query per stanza
	var engine_devs := bus.get_components_in_room("engine_room")
	assert_eq(engine_devs.size(), 2)
	
	# Query per categoria
	var prop_devs := bus.get_components_by_category("propulsion")
	assert_eq(prop_devs.size(), 1)
	assert_eq(prop_devs[0].device_id, "dev_02")
	
	# Unregister
	var ok := bus.unregister_component("dev_01")
	assert_true(ok)
	assert_false(bus.has_component("dev_01"))
	assert_eq(bus.get_all_components().size(), 2)
	
	comp1.free()
	bus.clear_all_components()
	bus.free()

func test_hardware_bus_command_dispatch() -> void:
	var bus := ShipHardwareBus.new()
	var reactor := ReactorComponent.new("reactor_main", "engine_room", "engineering")
	bus.register_component(reactor)
	
	# Lettura registro
	var read_res := bus.dispatch_command("reactor_main", "read", ["status"])
	assert_true(read_res.get("success", false))
	assert_eq(read_res.get("result"), "ONLINE")
	
	# Scrittura registro
	var write_res := bus.dispatch_command("reactor_main", "write", ["power_target", 1.2])
	assert_true(write_res.get("success", false))
	assert_eq(reactor.power_target, 1.2)
	
	# Dispositivo inesistente
	var missing_res := bus.dispatch_command("non_existent_device", "read", ["status"])
	assert_false(missing_res.get("success", true))
	assert_true(str(missing_res.get("error")).contains("not found"))
	
	bus.clear_all_components()
	bus.free()

func test_hardware_bus_power_grid_balancing_and_battery() -> void:
	var bus := ShipHardwareBus.new()
	
	var reactor := ReactorComponent.new("reactor", "engine_room", "engineering")
	reactor.power_output_nominal = 100.0
	reactor.power_target = 1.0
	
	var battery := BatteryComponent.new("battery", "engine_room", "engineering")
	battery.capacity_max = 500.0
	battery.charge_current = 100.0
	
	var consumer := ThrusterComponent.new("thruster", "engine_room", "propulsion")
	consumer.power_draw_nominal = 40.0
	consumer.set_throttle(1.0) # richiede 40 MW
	
	bus.register_component(reactor)
	bus.register_component(battery)
	bus.register_component(consumer)
	
	# Step 1: Generati 100 MW, richiesti 40 MW. Surplus di 60 MW carica la batteria.
	bus.step(1.0)
	assert_eq(bus.power_ratio, 1.0)
	assert_almost_eq(consumer.power_supplied, 40.0, 0.01)
	assert_almost_eq(battery.charge_current, 160.0, 0.01, "La batteria deve assorbire il surplus")
	
	# Step 2: Spegnimento reattore. Deficit di 40 MW coperto dalla batteria.
	reactor.set_online(false)
	bus.step(1.0)
	assert_eq(bus.total_generated_mw, 0.0)
	assert_almost_eq(consumer.power_supplied, 40.0, 0.01, "La batteria deve alimentare il consumatore in assenza di reattore")
	assert_almost_eq(battery.charge_current, 120.0, 0.01)
	assert_false(bus.is_blackout)
	
	# Step 3: Batteria esaurita -> Blackout
	battery.charge_current = 0.0
	bus.step(1.0)
	assert_lt(bus.power_ratio, 0.5)
	assert_true(bus.is_blackout, "In assenza di generazione e batteria il bus deve entrare in blackout")
	assert_eq(consumer.power_supplied, 0.0)
	
	bus.clear_all_components()
	bus.free()

func test_hardware_bus_thermal_grid_cooling() -> void:
	var bus := ShipHardwareBus.new()
	
	var hot_comp := ShipPhysicalComponent.new("hot_cpu", "mainframe", "command")
	hot_comp.heat_current = 80.0
	hot_comp.ambient_temp = 20.0
	
	var cooler := CoolingComponent.new("cooler", "mainframe", "engineering")
	cooler.cooling_capacity = 60.0
	cooler.power_supplied = 12.0
	cooler.pump_speed = 1.0
	
	bus.register_component(hot_comp)
	bus.register_component(cooler)
	
	# Step di bilanciamento termico
	bus.step(1.0)
	assert_lt(hot_comp.heat_current, 80.0, "Il componente caldo deve essere raffreddato dal cooler")
	
	bus.clear_all_components()
	bus.free()

func test_spaceship_flight_physics_modulated_by_bus() -> void:
	var spaceship := Spaceship.new()
	var bus := ShipHardwareBus.new()
	var thruster := ThrusterComponent.new("thruster_main", "engine_room", "propulsion")
	thruster.max_thrust = 35.0
	thruster.health_percent = 100.0
	thruster.power_supplied = 30.0
	bus.register_component(thruster)
	spaceship.set_hardware_bus(bus)
	
	# Con propulsore al 100%
	assert_almost_eq(bus.get_propulsion_efficiency(), 1.0, 0.01)
	
	# Danneggiamo il propulsore al 50%
	thruster.health_percent = 50.0
	thruster.step(0.1)
	assert_almost_eq(bus.get_propulsion_efficiency(), 0.5, 0.01, "L'efficienza del bus deve scendere proporzionalmente al danno")
	
	# Simuliamo fisica volo con input in avanti
	spaceship.set_linear_input(Vector3(0, 0, -1))
	spaceship._apply_flight_physics(0.1)
	assert_lt(spaceship.linear_velocity.z, 0.0, "La nave deve accelerare in avanti modulata dal bus")
	
	spaceship.free()
	bus.clear_all_components()
	bus.free()

func test_hardware_bus_throughput_bench() -> void:
	var bus := ShipHardwareBus.new()
	for i in range(10):
		var dev := ShipPhysicalComponent.new("dev_%d" % i, "room_%d" % (i % 3), "utility")
		bus.register_component(dev)
		
	# 1.000 iterazioni rapide di dispatch e step per verificare stabilità e assenza di allocazioni incontrollate
	for j in range(1000):
		var dev_id := "dev_%d" % (j % 10)
		var res := bus.dispatch_command(dev_id, "read", ["health"])
		assert_true(res.get("success", false))
		
	bus.step(0.016)
	assert_eq(bus.get_all_components().size(), 10)
	
	bus.clear_all_components()
	bus.free()
