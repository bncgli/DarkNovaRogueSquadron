extends SceneTree

func _init() -> void:
	print("--- GENERATING HAL TEST SHIP BLUEPRINT ---")
	
	const DEFAULT_BP_PATH := "res://Outside/ShipSublayer/default_ship_blueprint.tres"
	const TARGET_BP_PATH := "res://Outside/ShipSublayer/hal_test_ship_blueprint.tres"
	
	var default_res := ResourceLoader.load(DEFAULT_BP_PATH) as ShipBlueprint
	if default_res == null:
		printerr("Failed to load default_ship_blueprint.tres")
		quit(1)
		return
	
	var bp := ShipBlueprint.new()
	bp.from_dict(default_res.to_dict())
	
	bp.ship_id = "corvette_hal_testbed"
	bp.ship_name = "Corvette HAL Testbed"
	bp.ship_class = "Corvette"
	
	# Costruzione dispositivi specifici per il collaudo HAL
	# 1. reactor_01
	var dev_reactor := ShipDeviceData.new("reactor_01", "Reattore Tokamak Primario", Vector2(250, 340))
	dev_reactor.category = "engineering"
	dev_reactor.component_class = "ReactorComponent"
	dev_reactor.power_mw = 1000.0
	dev_reactor.sector = "Sala Macchine & Propulsione"
	dev_reactor.desc = "Reattore a fusione primario tokamak con potenza nominale di 1000 MW."
	dev_reactor.custom_properties = {
		"power_output_nominal": 1000.0,
		"power_target": 1.0,
		"heat_max": 250.0
	}
	
	# 2. thruster_01
	var dev_thruster_1 := ShipDeviceData.new("thruster_01", "Propulsore Principale SX", Vector2(205, 360))
	dev_thruster_1.category = "propulsion"
	dev_thruster_1.component_class = "ThrusterComponent"
	dev_thruster_1.power_mw = -50.0
	dev_thruster_1.sector = "Sala Macchine & Propulsione"
	dev_thruster_1.desc = "Propulsore ionico vettoriale di babordo da 50 kN."
	dev_thruster_1.custom_properties = {
		"max_thrust": 50.0,
		"thruster_type": "main"
	}
	
	# 3. thruster_02
	var dev_thruster_2 := ShipDeviceData.new("thruster_02", "Propulsore Principale DX", Vector2(375, 360))
	dev_thruster_2.category = "propulsion"
	dev_thruster_2.component_class = "ThrusterComponent"
	dev_thruster_2.power_mw = -30.0
	dev_thruster_2.sector = "Sala Macchine & Propulsione"
	dev_thruster_2.desc = "Propulsore ionico vettoriale di tribordo da 30 kN."
	dev_thruster_2.custom_properties = {
		"max_thrust": 30.0,
		"thruster_type": "main"
	}
	
	# 4. cooling_01
	var dev_cooling := ShipDeviceData.new("cooling_01", "Radiatore Criogenico", Vector2(300, 325))
	dev_cooling.category = "engineering"
	dev_cooling.component_class = "CoolingComponent"
	dev_cooling.power_mw = -20.0
	dev_cooling.sector = "Sala Macchine & Propulsione"
	dev_cooling.desc = "Scambiatore e radiatore termico criogenico ad alta efficienza."
	dev_cooling.custom_properties = {
		"cooling_capacity": 60.0,
		"coolant_level": 100.0
	}
	
	# 5. battery_01
	var dev_battery := ShipDeviceData.new("battery_01", "Banco Batterie Emergenza", Vector2(320, 325))
	dev_battery.category = "engineering"
	dev_battery.component_class = "BatteryComponent"
	dev_battery.power_mw = 0.0
	dev_battery.sector = "Sala Macchine & Propulsione"
	dev_battery.desc = "Batterie al grafene ad alta densità per stabilizzazione e riserva di emergenza."
	dev_battery.custom_properties = {
		"capacity_max": 500.0,
		"charge_current": 500.0
	}
	
	# 6. life_support_01
	var dev_life_support := ShipDeviceData.new("life_support_01", "Unità Supporto Vitale Cabina", Vector2(260, 65))
	dev_life_support.category = "life_support"
	dev_life_support.component_class = "LifeSupportComponent"
	dev_life_support.power_mw = -30.0
	dev_life_support.sector = "Ponte di Comando"
	dev_life_support.desc = "Unità combinata generatore O2, scrubber CO2 e termoregolatore cabina."
	dev_life_support.custom_properties = {
		"oxygen_level": 100.0,
		"co2_level": 0.0,
		"cabin_temp": 21.0,
		"target_temp": 21.0
	}
	
	# Aggiorniamo le stanze nel blueprint
	var new_rooms: Array = []
	for r in default_res.rooms:
		var room_dict: Dictionary = r.to_dict() if r.has_method("to_dict") else {}
		var r_obj := ShipRoomData.new()
		r_obj.from_dict(room_dict)
		
		# Se è la sala motori / engine, rinominiamola id="engine_room" e associamo i componenti dedicati
		if r_obj.id == "engine" or r_obj.id == "engine_room":
			r_obj.id = "engine_room"
			r_obj.name = "Sala Macchine & Propulsione"
			r_obj.devices = [dev_reactor, dev_thruster_1, dev_thruster_2, dev_cooling, dev_battery]
			r_obj.power_mw = 900.0
		# Se è la bridge, aggiungiamo life_support_01
		elif r_obj.id == "bridge":
			r_obj.devices = [dev_life_support]
			for d in r.devices:
				if d.id != "reactor_main" and d.id != "life_support_gen":
					r_obj.devices.append(d)
			r_obj.power_mw = -45.0
		elif r_obj.id == "reactor":
			# Il reattore ora è integrato in engine_room, svuotiamo o convertiamo
			r_obj.devices = []
			r_obj.power_mw = 0.0
		
		new_rooms.append(r_obj)
	
	bp.rooms = new_rooms
	bp.ducts = default_res.ducts
	bp.drive_files = default_res.drive_files
	bp.drive_passwords = default_res.drive_passwords
	bp.installed_apps = default_res.installed_apps
	bp.recharge_room_id = "cargo"
	bp.drone_spawn_pos = default_res.drone_spawn_pos
	
	# Verifica dell'istanziamento fisico
	var physical_comps := bp.instantiate_physical_components()
	print("Instantiated physical components count: ", physical_comps.size())
	for c in physical_comps:
		print(" - Comp: id=", c.device_id, " class=", c.get_class(), " room=", c.room_id, " cat=", c.category)
	
	var bus := ShipHardwareBus.new()
	bus.load_from_blueprint(bp)
	bus.step(0.1)
	var hal := ShipHAL.new(bus)
	
	print("HAL Telemetry Verification:")
	print(" - Propulsion efficiency: ", hal.get_propulsion_efficiency())
	print(" - Total available thrust: ", hal.get_total_available_thrust())
	assert(hal.get_total_available_thrust() == 80.0, "Total thrust must be 80.0 kN")
	
	var pwr := hal.get_power_telemetry()
	print(" - Power gen: ", pwr.get("generated_mw"), " dem: ", pwr.get("demanded_mw"))
	assert(pwr.get("generated_mw") == 1000.0, "Generated power must be 1000.0 MW")
	
	var ls := hal.get_life_support_metrics()
	print(" - Life support: O2=", ls.get("o2"), " Temp=", ls.get("temp"))
	assert(ls.get("o2") >= 95.0, "O2 must be >= 95%")
	assert(abs(ls.get("temp") - 21.0) < 1.0, "Temp must be ~21C")
	
	var integ := hal.get_overall_system_integrity()
	print(" - Integrity: ", integ)
	assert(integ == 100.0, "Integrity must be 100%")
	
	hal.free()
	bus.clear_all_components()
	bus.free()
	
	# Salvataggio come risorsa Godot .tres
	var err := ResourceSaver.save(bp, TARGET_BP_PATH)
	if err != OK:
		printerr("ResourceSaver.save failed with error code: ", err)
		quit(1)
		return
	
	print("SUCCESS: Blueprint saved to ", TARGET_BP_PATH)
	quit(0)
