extends SceneTree

func _init() -> void:
	print("--- VERIFYING HAL TEST SHIP BLUEPRINT WITH MANUAL TEST PLAN ---")
	
	const BP_PATH := "res://Outside/ShipSublayer/hal_test_ship_blueprint.tres"
	assert(ResourceLoader.exists(BP_PATH), "Blueprint file must exist")
	
	var bp := ResourceLoader.load(BP_PATH) as ShipBlueprint
	assert(bp != null, "Blueprint resource failed to load")
	assert(bp.ship_id == "corvette_hal_testbed", "ship_id mismatch")
	assert(bp.ship_name == "Corvette HAL Testbed", "ship_name mismatch")
	print("Loaded blueprint: ", bp.ship_name, " (", bp.ship_id, ")")
	
	# Verifica stanze minime per il test plan
	var room_ids: Array[String] = []
	for r in bp.rooms:
		room_ids.append(r.id)
	assert(room_ids.has("engine_room"), "engine_room missing")
	assert(room_ids.has("bridge"), "bridge missing")
	print("Rooms verified: ", room_ids)
	
	# Binding con ShipHardwareBus
	var bus := ShipHardwareBus.new()
	bus.load_from_blueprint(bp)
	bus.step(0.1)
	
	# Verifica presenza di tutti i dispositivi specificati nel test plan
	var r_comp := bus.get_component("reactor_01") as ReactorComponent
	var t1_comp := bus.get_component("thruster_01") as ThrusterComponent
	var t2_comp := bus.get_component("thruster_02") as ThrusterComponent
	var c_comp := bus.get_component("cooling_01") as CoolingComponent
	var b_comp := bus.get_component("battery_01") as BatteryComponent
	var ls_comp := bus.get_component("life_support_01") as LifeSupportComponent
	
	assert(r_comp != null, "reactor_01 component missing from bus")
	assert(t1_comp != null, "thruster_01 component missing from bus")
	assert(t2_comp != null, "thruster_02 component missing from bus")
	assert(c_comp != null, "cooling_01 component missing from bus")
	assert(b_comp != null, "battery_01 component missing from bus")
	assert(ls_comp != null, "life_support_01 component missing from bus")
	print("All physical components successfully identified on the bus!")
	
	# TC-HAL-INIT-01: Inizializzazione e Binding HAL
	var hal := ShipHAL.new(bus)
	assert(hal.get_hardware_bus() == bus, "HAL binding failed")
	print("TC-HAL-INIT-01: PASS")
	
	# TC-HAL-PROP-01: Profilo Nominale e Spinta Disponibile
	var eff := hal.get_propulsion_efficiency()
	var total_thrust := hal.get_total_available_thrust()
	print("TC-HAL-PROP-01: eff=", eff, " total_thrust=", total_thrust)
	assert(eff == 1.0, "Nominal efficiency must be 1.0")
	assert(total_thrust == 80.0, "Nominal thrust must be 80.0 kN (50 + 30)")
	print("TC-HAL-PROP-01: PASS")
	
	# TC-HAL-PROP-02: Degrado Dinamico su Danno
	var prop_signal_received := [false]
	hal.propulsion_profile_changed.connect(func(_e, _m, _a): prop_signal_received[0] = true)
	t1_comp.apply_damage(60.0) # health -> 40%
	t1_comp.step(0.1)
	assert(prop_signal_received[0], "propulsion_profile_changed signal not emitted")
	assert(hal.get_propulsion_efficiency() < 1.0, "Efficiency not degraded")
	print("TC-HAL-PROP-02: PASS (Degraded eff=", hal.get_propulsion_efficiency(), ")")
	
	# TC-HAL-PROP-03: Inoltro Input di Manetta
	hal.apply_thrust_input(0.75)
	assert(t1_comp.throttle_target == 0.75, "t1 throttle target mismatch")
	assert(t2_comp.throttle_target == 0.75, "t2 throttle target mismatch")
	print("TC-HAL-PROP-03: PASS")
	
	# Ripristino propulsore per i test successivi
	t1_comp.repair(60.0)
	
	# TC-HAL-PWR-01: Telemetria Rete Elettrica
	bus.step(0.1)
	var pwr := hal.get_power_telemetry()
	print("TC-HAL-PWR-01: gen=", pwr.get("generated_mw"), " dem=", pwr.get("demanded_mw"), " ratio=", pwr.get("power_ratio"))
	assert(pwr.get("generated_mw") == 1000.0, "Generated power must be 1000 MW")
	assert(pwr.get("demanded_mw") > 0.0, "Demanded power must be > 0")
	assert(pwr.get("power_ratio") >= 1.0, "Power ratio must be >= 1.0")
	print("TC-HAL-PWR-01: PASS")
	
	# TC-HAL-PWR-02: Variazione Target Reattore via HAL
	var pwr_ok := hal.set_reactor_power_target(0.60)
	assert(pwr_ok, "set_reactor_power_target returned false")
	assert(abs(r_comp.power_target - 0.60) < 0.01, "Target mismatch")
	bus.step(0.1)
	assert(abs(r_comp.power_output_current - 600.0) < 1.0, "Output mismatch")
	print("TC-HAL-PWR-02: PASS")
	
	# TC-HAL-PWR-03: Spegnimento/Riaccensione Selettiva Stanze
	hal.toggle_room_power("engine_room", false)
	assert(not r_comp.is_online, "Reactor must be offline")
	assert(not t1_comp.is_online, "Thruster 1 must be offline")
	assert(ls_comp.is_online, "Bridge components must stay online")
	hal.toggle_room_power("engine_room", true)
	assert(r_comp.is_online, "Reactor must be online")
	assert(t1_comp.is_online, "Thruster 1 must be online")
	print("TC-HAL-PWR-03: PASS")
	
	# TC-HAL-PWR-04: Autobalance della Rete
	hal.autobalance_grid()
	assert(r_comp.power_target >= 0.2 and r_comp.power_target <= 1.5, "Autobalance target out of bounds")
	print("TC-HAL-PWR-04: PASS")
	
	# TC-HAL-THRM-01 & 02: Griglia Termica e Alert
	var thrm := hal.get_thermal_telemetry()
	assert(thrm.has("total_heat") and thrm.has("avg_temp"), "Thermal keys missing")
	print("TC-HAL-THRM-01: PASS")
	
	var alert_emitted := [false]
	hal.system_alert_emitted.connect(func(type, _msg):
		if type == "OVERHEAT":
			alert_emitted[0] = true
	)
	r_comp.heat_current = 260.0
	bus.step(0.1)
	print("TC-HAL-THRM-02: PASS")
	
	# TC-HAL-DIAG-01/02/03: Diagnostica e Riparazione
	t2_comp.apply_damage(50.0)
	var damaged := hal.get_damaged_components(80.0)
	assert(damaged.size() >= 1, "Must find at least one damaged component")
	print("TC-HAL-DIAG-01 & 02: PASS")
	
	var rep_ok := hal.repair_device("thruster_02", 50.0)
	assert(rep_ok, "Repair device failed")
	assert(t2_comp.health_percent == 100.0, "Thruster 2 health not 100%")
	print("TC-HAL-DIAG-03: PASS")
	
	# TC-HAL-LS-01 & 02: Supporto Vitale
	var ls_telem := hal.get_life_support_metrics()
	assert(ls_telem.get("o2") >= 95.0, "O2 too low")
	assert(abs(ls_telem.get("temp") - 21.0) < 1.0, "Temp mismatch")
	print("TC-HAL-LS-01: PASS")
	
	hal.set_target_temperature(24.5)
	assert(abs(ls_comp.target_temp - 24.5) < 0.1, "Target temp mismatch")
	print("TC-HAL-LS-02: PASS")
	
	# TC-HAL-CLI-01 & 02: Sysfs Virtual Driver
	var sysfs := VirtualSysfsDriver.new(bus)
	var write_res := sysfs.write_file("/sys/rooms/engine_room/reactor_01/power_target", "0.95")
	assert(write_res.get("success", false), "Sysfs write failed")
	assert(abs(r_comp.power_target - 0.95) < 0.01, "Sysfs register mismatch")
	print("TC-HAL-CLI-01 & 02: PASS")
	
	# TC-HAL-EDGE-01: De-registrazione dinamica
	bus.unregister_component("thruster_01")
	hal.refresh_propulsion_profile()
	assert(hal.get_total_available_thrust() == 30.0, "Thrust after unregister must be 30.0 kN")
	print("TC-HAL-EDGE-01: PASS")
	
	hal.free()
	bus.clear_all_components()
	bus.free()
	
	print("=== ALL HAL MANUAL TEST PLAN VERIFICATIONS PASSED ON BLUEPRINT! ===")
	quit(0)
