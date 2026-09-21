extends SceneTree

func _init() -> void:
	print("--- GENERATING CANONICAL SHIP BLUEPRINTS ---")
	
	const DEFAULT_BP_PATH := "res://Outside/ShipSublayer/default_ship_blueprint.tres"
	const HAL_TEST_BP_PATH := "res://Outside/ShipSublayer/hal_test_ship_blueprint.tres"
	
	var default_res := ResourceLoader.load(DEFAULT_BP_PATH) as ShipBlueprint
	if default_res == null:
		printerr("Failed to load default_ship_blueprint.tres")
		quit(1)
		return
	
	# Helper per costruire i 19 dispositivi ufficiali
	var d_core_reactor := ShipDeviceData.new("core_reactor", "Reattore Tokamak Primario", Vector2(250, 240))
	d_core_reactor.category = "reactor"
	d_core_reactor.component_class = "ReactorComponent"
	d_core_reactor.power_mw = 1000.0
	d_core_reactor.sector = "Nucleo Reattore & Fusione"
	d_core_reactor.desc = "Generatore primario a fusione tokamak."
	d_core_reactor.custom_properties = {"power_output_nominal": 1000.0, "heat_max": 250.0}

	var d_battery := ShipDeviceData.new("battery_01", "Banco Batterie Emergenza", Vector2(320, 240))
	d_battery.category = "engineering"
	d_battery.component_class = "BatteryComponent"
	d_battery.power_mw = 0.0
	d_battery.sector = "Nucleo Reattore & Fusione"
	d_battery.desc = "Accumulatore tampone di emergenza al grafene da 500 MJ."
	d_battery.custom_properties = {"capacity_max": 500.0, "charge_current": 500.0}

	var d_cooling := ShipDeviceData.new("cooling_01", "Radiatore Criogenico", Vector2(300, 340))
	d_cooling.category = "engineering"
	d_cooling.component_class = "CoolingComponent"
	d_cooling.power_mw = -20.0
	d_cooling.sector = "Sala Motori Principale"
	d_cooling.desc = "Circuito radiatore termico criogenico ad alta dissipazione."
	d_cooling.custom_properties = {"cooling_capacity": 60.0, "coolant_level": 100.0}

	var d_engine := ShipDeviceData.new("engine_main", "Propulsore a Scarica Ionica", Vector2(300, 360))
	d_engine.category = "propulsion"
	d_engine.component_class = "ThrusterComponent"
	d_engine.power_mw = -50.0
	d_engine.sector = "Sala Motori Principale"
	d_engine.desc = "Propulsore ionico principale longitudinale e Cruise Drive."
	d_engine.custom_properties = {"max_thrust": 80.0, "thruster_type": "main"}

	var d_rcs_l := ShipDeviceData.new("rcs_pitch_l", "Attuatore RCS Babordo", Vector2(55, 260))
	d_rcs_l.category = "propulsion"
	d_rcs_l.component_class = "ThrusterComponent"
	d_rcs_l.power_mw = -15.0
	d_rcs_l.sector = "Pod RCS Sinistro"
	d_rcs_l.desc = "Attuatore di manovra e controllo inerziale Babordo."
	d_rcs_l.custom_properties = {"max_thrust": 15.0, "thruster_type": "rcs_pitch"}

	var d_rcs_r := ShipDeviceData.new("rcs_pitch_r", "Attuatore RCS Tribordo", Vector2(545, 260))
	d_rcs_r.category = "propulsion"
	d_rcs_r.component_class = "ThrusterComponent"
	d_rcs_r.power_mw = -15.0
	d_rcs_r.sector = "Pod RCS Destro"
	d_rcs_r.desc = "Attuatore di manovra e controllo inerziale Tribordo."
	d_rcs_r.custom_properties = {"max_thrust": 15.0, "thruster_type": "rcs_pitch"}

	var d_helm := ShipDeviceData.new("helm_control", "Consolle Pilotaggio e Plancia", Vector2(270, 75))
	d_helm.category = "command"
	d_helm.component_class = "HelmControlComponent"
	d_helm.power_mw = -15.0
	d_helm.sector = "Ponte di Comando"
	d_helm.desc = "Interfaccia diegetica controlli pilota WASD/QE."

	var d_nav := ShipDeviceData.new("nav_computer", "Elaboratore Rotte & Salto", Vector2(330, 75))
	d_nav.category = "command"
	d_nav.component_class = "NavComputerComponent"
	d_nav.power_mw = -10.0
	d_nav.sector = "Ponte di Comando"
	d_nav.desc = "Calcolo rotte orbitali, vettori salto Hyperdrive e waypoint."

	var d_cams := ShipDeviceData.new("cam_array", "Array Telecamere Esterne", Vector2(300, 50))
	d_cams.category = "sensors"
	d_cams.component_class = "CamArrayComponent"
	d_cams.power_mw = -5.0
	d_cams.sector = "Ponte di Comando"
	d_cams.desc = "Telecamere scafo perimetrali 6CH e proiettori fari."

	var d_sensors := ShipDeviceData.new("sensors_matrix", "Matrice Sensori Phased Array", Vector2(165, 145))
	d_sensors.category = "sensors"
	d_sensors.component_class = "SensorsMatrixComponent"
	d_sensors.power_mw = -25.0
	d_sensors.sector = "Sensori & Avionica"
	d_sensors.desc = "Radar volumetrico 3D, scansione passiva e ping attivo 120 MW."

	var d_comms := ShipDeviceData.new("antenna_array", "Transceiver Sub-Spazio", Vector2(440, 145))
	d_comms.category = "comms"
	d_comms.component_class = "AntennaArrayComponent"
	d_comms.power_mw = -15.0
	d_comms.sector = "Comunicazioni & EW"
	d_comms.desc = "Antenna telecomunicazioni subspazio e stabilizzatore link EW."

	var d_armory := ShipDeviceData.new("armory_defense", "Alimentazione Armeria & Torrette", Vector2(300, 165))
	d_armory.category = "tactical"
	d_armory.component_class = "ArmoryDefenseComponent"
	d_armory.power_mw = -30.0
	d_armory.sector = "Armeria & Sicurezza"
	d_armory.desc = "Condensatori laser, puntamento torrette e dispenser missili."

	var d_server := ShipDeviceData.new("server_rack", "Mainframe Cyber-Guerra", Vector2(160, 235))
	d_server.category = "cyber"
	d_server.component_class = "ServerRackComponent"
	d_server.power_mw = -10.0
	d_server.sector = "MainFrame"
	d_server.desc = "Mainframe quantistico per firewall, exploit e crittografia."

	var d_cargo := ShipDeviceData.new("cargo_handling", "Manipolatore Stiva", Vector2(420, 235))
	d_cargo.category = "cargo"
	d_cargo.component_class = "CargoHandlingComponent"
	d_cargo.power_mw = -10.0
	d_cargo.sector = "Baia di Carico Principale"
	d_cargo.desc = "Serrande portelloni cargo e bloccaggio magnetico merci."

	var d_dock := ShipDeviceData.new("recharge_dock", "Dock Ricarica Duct Drone", Vector2(460, 235))
	d_dock.category = "engineering"
	d_dock.component_class = "RechargeDockComponent"
	d_dock.power_mw = -10.0
	d_dock.sector = "Baia di Carico Principale"
	d_dock.desc = "Nodo ricarica ad induzione per drone condotti interno."

	var d_scrubber := ShipDeviceData.new("scrubber", "Filtro CO2 Primario", Vector2(100, 340))
	d_scrubber.category = "life_support"
	d_scrubber.component_class = "LifeSupportComponent"
	d_scrubber.power_mw = -10.0
	d_scrubber.sector = "Supporto vitale minimale"
	d_scrubber.desc = "Scrubber chimico per purificazione CO2 e ricircolo aria."

	var d_heater := ShipDeviceData.new("heater", "Caldaia Termoregolatrice", Vector2(120, 340))
	d_heater.category = "life_support"
	d_heater.component_class = "LifeSupportComponent"
	d_heater.power_mw = -10.0
	d_heater.sector = "Supporto vitale minimale"
	d_heater.desc = "Caldaia termoregolatrice della cabina (21°C)."

	var d_serra := ShipDeviceData.new("serra_idroponica", "Serra Idroponica O2", Vector2(110, 360))
	d_serra.category = "life_support"
	d_serra.component_class = "LifeSupportComponent"
	d_serra.power_mw = -15.0
	d_serra.sector = "Supporto vitale minimale"
	d_serra.desc = "Serra idroponica biologica per ossigeno continuo e razioni."

	var d_dronestation := ShipDeviceData.new("dronestation", "Baia Ricarica Drone EVA", Vector2(490, 340))
	d_dronestation.category = "service"
	d_dronestation.component_class = "DroneStationComponent"
	d_dronestation.power_mw = -10.0
	d_dronestation.sector = "Pod drone di servizio"
	d_dronestation.desc = "Culla di attracco e ricarica drone spaziale esterno."

	var d_shld_sx := ShipDeviceData.new("arm_sx_balancer", "Bilanciatore Scudi Babordo", Vector2(70, 120))
	d_shld_sx.category = "defense"
	d_shld_sx.component_class = "ShieldBalancerComponent"
	d_shld_sx.power_mw = -45.0
	d_shld_sx.sector = "Armatura adattiva SX"
	d_shld_sx.desc = "Generazione e bilanciamento bolla scudi Babordo."

	var d_shld_dx := ShipDeviceData.new("arm_dx_balancer", "Bilanciatore Scudi Tribordo", Vector2(540, 120))
	d_shld_dx.category = "defense"
	d_shld_dx.component_class = "ShieldBalancerComponent"
	d_shld_dx.power_mw = -45.0
	d_shld_dx.sector = "Armatura adattiva DX"
	d_shld_dx.desc = "Generazione e bilanciamento bolla scudi Tribordo."

	# Creiamo una funzione helper per popolare le stanze canoniche
	var make_blueprint := func(ship_id_str: String, ship_name_str: String) -> ShipBlueprint:
		var bp := ShipBlueprint.new()
		bp.from_dict(default_res.to_dict())
		bp.ship_id = ship_id_str
		bp.ship_name = ship_name_str
		bp.ship_class = "Corvette"
		bp.recharge_room_id = "cargo"
		
		var rooms: Array = []
		for r in default_res.rooms:
			var r_dict: Dictionary = r.to_dict() if r.has_method("to_dict") else {}
			var room_obj := ShipRoomData.new()
			room_obj.from_dict(r_dict)
			
			match room_obj.id:
				"bridge":
					room_obj.devices = [d_helm, d_nav, d_cams]
				"sensors":
					room_obj.devices = [d_sensors]
				"comms":
					room_obj.devices = [d_comms]
				"armory":
					room_obj.devices = [d_armory]
				"mainframe":
					room_obj.devices = [d_server]
				"cargo":
					room_obj.devices = [d_cargo, d_dock]
				"reactor":
					room_obj.devices = [d_core_reactor, d_battery]
				"engine", "engine_room":
					room_obj.id = "engine_room"
					room_obj.name = "Sala Motori Principale"
					room_obj.devices = [d_engine, d_cooling]
				"rcs_left":
					room_obj.devices = [d_rcs_l]
				"rcs_right":
					room_obj.devices = [d_rcs_r]
				"room_11":
					room_obj.name = "Supporto Vitale"
					room_obj.devices = [d_scrubber, d_heater, d_serra]
				"room_13":
					room_obj.name = "Pod Drone di Servizio"
					room_obj.devices = [d_dronestation]
				"room_14":
					room_obj.name = "Armatura Adattiva SX"
					room_obj.devices = [d_shld_sx]
				"room_15":
					room_obj.name = "Armatura Adattiva DX"
					room_obj.devices = [d_shld_dx]
				_:
					room_obj.devices = []
			
			# Ricalcola potenza stanza
			var pwr: float = 0.0
			for dev in room_obj.devices:
				pwr += dev.power_mw
			room_obj.power_mw = pwr
			rooms.append(room_obj)
			
		bp.rooms = rooms
		bp.recalculate_all_powers()
		return bp

	# Salva default_ship_blueprint.tres
	var default_bp = make_blueprint.call("dark_nova_corvette", "Dark Nova Corvette")
	var err1 := ResourceSaver.save(default_bp, DEFAULT_BP_PATH)
	if err1 != OK:
		printerr("Failed to save default_ship_blueprint.tres: ", err1)
		quit(1)
		return
	print("Saved canonical default_ship_blueprint.tres")

	# Salva hal_test_ship_blueprint.tres
	var hal_bp = make_blueprint.call("corvette_hal_testbed", "Corvette HAL Testbed")
	var err2 := ResourceSaver.save(hal_bp, HAL_TEST_BP_PATH)
	if err2 != OK:
		printerr("Failed to save hal_test_ship_blueprint.tres: ", err2)
		quit(1)
		return
	print("Saved canonical hal_test_ship_blueprint.tres")

	# Test bus loading
	var bus := ShipHardwareBus.new()
	bus.load_from_blueprint(hal_bp)
	bus.step(0.1)
	print("Components on bus: ", bus._components.size())
	for id_k in bus._components:
		var c = bus._components[id_k]
		print(" - [", id_k, "] ", c.get_class(), " in ", c.room_id)
	assert(bus._components.size() == 21, "Must have exactly 21 device instances registered")
	
	bus.clear_all_components()
	bus.free()
	
	print("SUCCESS: Both blueprints updated and verified!")
	quit(0)
