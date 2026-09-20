extends GutTest

## Suite di test unitari GUT per i componenti fisici autonomi della nave (Step 1).
## Verifica determinismo, cicli di vita, registri I/O, usura e mappatura blueprint.

func test_base_physical_component_registers_and_io() -> void:
	var comp := ShipPhysicalComponent.new("test_comp", "room_01", "utility")
	comp.power_draw_nominal = 20.0
	comp.power_supplied = 20.0
	
	# Verifica registri iniziali
	assert_eq(comp.read_register("status"), "ONLINE")
	assert_eq(comp.read_register("health"), 100.0)
	assert_eq(comp.read_register("power_nominal"), 20.0)
	
	# Scrittura su registro scrivibile
	var write_success := comp.write_register("power_target", 1.5)
	assert_true(write_success, "La scrittura su power_target deve riuscire")
	assert_eq(comp.read_register("power_target"), 1.5)
	
	# Scrittura con stringa (come da echo da terminale)
	var write_str_success := comp.write_register("power_target", "0.8")
	assert_true(write_str_success, "La scrittura da stringa deve fare auto-parse a float")
	assert_almost_eq(float(comp.read_register("power_target")), 0.8, 0.001)
	
	# Scrittura su registro readonly deve fallire
	var ro_write := comp.write_register("status", "FAULT")
	assert_false(ro_write, "La scrittura su un registro readonly come 'status' deve essere respinta")
	assert_eq(comp.read_register("status"), "ONLINE")

	# Scrittura su health consentita per diagnostica e test (FR-03)
	var health_write := comp.write_register("health", 50.0)
	assert_true(health_write, "La scrittura su 'health' deve essere consentita per diagnostica")
	assert_eq(comp.read_register("health"), 50.0)
	
	comp.free()

func test_base_component_offline_and_damage_lifecycle() -> void:
	var comp := ShipPhysicalComponent.new("test_lifecycle", "room_01", "utility")
	comp.power_draw_nominal = 50.0
	comp.power_supplied = 50.0
	comp.heat_current = 80.0
	comp.ambient_temp = 20.0
	
	# Step quando online: dissipa passivamente
	comp.step(1.0)
	assert_lt(comp.heat_current, 80.0, "Il calore deve dissiparsi verso la temperatura ambiente")
	
	# Spegnimento
	comp.set_online(false)
	assert_false(comp.is_online)
	assert_eq(comp.read_register("status"), "OFFLINE")
	comp.step(1.0)
	assert_eq(comp.power_draw_current, 0.0, "Un componente offline non deve richiedere potenza")
	
	# Danno e guasto (FAULT)
	comp.set_online(true)
	comp.apply_damage(120.0)
	assert_eq(comp.health_percent, 0.0)
	assert_eq(comp.read_register("status"), "FAULT")
	assert_false(comp.is_online, "Un componente a zero integrità deve entrare in blocco FAULT")
	
	# Riparazione
	comp.repair(50.0)
	assert_eq(comp.health_percent, 50.0)
	assert_eq(comp.read_register("status"), "ONLINE")
	
	comp.free()

func test_reactor_component_generation_and_depletion() -> void:
	var reactor := ReactorComponent.new("reactor_01", "engine_room", "engineering")
	reactor.power_output_nominal = 1000.0
	reactor.power_target = 1.0
	reactor.fuel_level = 10.0
	reactor.fuel_consumption_rate = 2.0
	
	# Step 1 secondo a 100% target
	reactor.step(1.0)
	assert_eq(reactor.power_output_current, 1000.0, "Il reattore deve generare 1000 MW nominali")
	assert_almost_eq(reactor.fuel_level, 8.0, 0.01, "Il consumo carburante deve essere scalato per delta")
	assert_gt(reactor.heat_current, 20.0, "La produzione energetica deve scaldare il reattore")
	
	# Overclock a 150%
	reactor.write_register("power_target", 1.5)
	reactor.step(1.0)
	assert_eq(reactor.power_output_current, 1500.0, "Il reattore con target 1.5 deve erogare 1500 MW")
	assert_almost_eq(reactor.fuel_level, 5.0, 0.01)
	
	# Esaurimento carburante
	reactor.fuel_level = 0.0
	reactor.step(1.0)
	assert_eq(reactor.power_output_current, 0.0, "Senza carburante il reattore non eroga potenza")
	assert_eq(reactor.read_register("status"), "DEPLETED")
	
	reactor.free()

func test_battery_component_charge_and_discharge() -> void:
	var battery := BatteryComponent.new("battery_01", "engine_room", "engineering")
	battery.capacity_max = 500.0
	battery.charge_current = 250.0 # 50%
	battery.charge_rate_max = 100.0
	battery.discharge_rate_max = 100.0
	
	assert_almost_eq(battery.get_charge_percent(), 50.0, 0.01)
	
	# Carica con 60 MW per 1 sec -> assorbe 60 MJ
	var absorbed := battery.charge(60.0, 1.0)
	assert_eq(absorbed, 60.0)
	assert_almost_eq(battery.charge_current, 310.0, 0.01)
	
	# Scarica verso la rete con 80 MW per 1 sec
	var delivered := battery.discharge(80.0, 1.0)
	assert_eq(delivered, 80.0)
	assert_almost_eq(battery.charge_current, 230.0, 0.01)
	
	# Richiesta che supera la capacità rimanente
	battery.charge_current = 20.0
	var drained := battery.discharge(50.0, 1.0)
	assert_almost_eq(drained, 20.0, 0.01, "Non può scaricare più della carica immagazzinata")
	assert_eq(battery.charge_current, 0.0)
	
	battery.free()

func test_thruster_component_throttle_and_power_dependency() -> void:
	var thruster := ThrusterComponent.new("main_thruster", "engine_room", "propulsion")
	thruster.max_thrust = 40.0
	thruster.power_draw_nominal = 20.0
	
	# Throttle al 100% con piena alimentazione
	thruster.set_throttle(1.0)
	thruster.power_supplied = 20.0
	thruster.step(1.0)
	assert_eq(thruster.current_thrust, 40.0, "La spinta deve essere piena a 100% potenza")
	
	# Deficit energetico (fornita solo metà potenza)
	thruster.power_supplied = 10.0
	thruster.step(1.0)
	assert_almost_eq(thruster.current_thrust, 20.0, 0.01, "Deficit energetico dimezza la spinta generata")
	
	# Throttle parziale al 50%
	thruster.power_supplied = 20.0
	thruster.set_throttle(0.5)
	thruster.step(1.0)
	assert_almost_eq(thruster.current_thrust, 20.0, 0.01)
	assert_almost_eq(thruster.power_draw_current, 10.0, 0.01)
	
	thruster.free()

func test_life_support_component_air_and_temperature() -> void:
	var ls := LifeSupportComponent.new("life_support_01", "bridge", "life_support")
	ls.power_draw_nominal = 15.0
	ls.power_supplied = 15.0
	ls.oxygen_level = 95.0
	ls.co2_level = 5.0
	ls.cabin_temp = 18.0
	ls.target_temp = 21.0
	
	# Quando alimentato, aumenta O2 e riallinea temperatura
	ls.step(2.0)
	assert_gt(ls.oxygen_level, 95.0, "O2 deve salire con supporto vitale attivo")
	assert_lt(ls.co2_level, 5.0, "CO2 deve essere depurato")
	assert_gt(ls.cabin_temp, 18.0, "Temperatura deve avvicinarsi a target_temp")
	
	# Quando spento, aria si degrada
	ls.set_online(false)
	var prev_o2 := ls.oxygen_level
	ls.step(2.0)
	assert_lt(ls.oxygen_level, prev_o2, "Senza supporto vitale l'O2 deve calare")
	
	ls.free()

func test_cooling_component_heat_dissipation() -> void:
	var cooling := CoolingComponent.new("radiator_01", "engine_room", "engineering")
	cooling.cooling_capacity = 50.0
	cooling.power_draw_nominal = 10.0
	cooling.power_supplied = 10.0
	cooling.pump_speed = 1.0
	
	cooling.step(1.0)
	# Dissipazione calore da carico esterno
	var dissipated := cooling.dissipate_heat(30.0, 1.0)
	assert_eq(dissipated, 30.0, "Deve dissipare il calore entro la capacità massima")
	
	# Richiesta superiore a capacità massima (50.0)
	var excess_dissipated := cooling.dissipate_heat(80.0, 1.0)
	assert_eq(excess_dissipated, 50.0, "Non può dissipare oltre cooling_capacity")
	
	cooling.free()

func test_blueprint_physical_components_instantiation() -> void:
	var bp := ShipBlueprint.get_default_blueprint()
	assert_not_null(bp, "Default ship blueprint deve esistere")
	
	var comps := bp.instantiate_physical_components()
	assert_gt(comps.size(), 0, "Deve istanziare componenti per i dispositivi del blueprint")
	
	var found_reactor := false
	var found_thruster := false
	var found_life_support := false
	
	for c in comps:
		assert_not_null(c)
		assert_false(c.device_id.is_empty(), "Ogni componente deve avere device_id valido")
		if c is ReactorComponent:
			found_reactor = true
		elif c is ThrusterComponent:
			found_thruster = true
		elif c is LifeSupportComponent:
			found_life_support = true
		c.free()
	
	assert_true(found_reactor, "Deve essere presente almeno un ReactorComponent nel blueprint")
	assert_true(found_thruster, "Deve essere presente almeno un ThrusterComponent nel blueprint")
	assert_true(found_life_support, "Deve essere presente almeno un LifeSupportComponent nel blueprint")
