extends GutTest

## Suite di Test GUT per il Deep Core Asteroid Mining & Raffinazione.
## Valida l'intero loop diegetico hard sci-fi:
## 1. Impatto balistico e danneggiamento continuo dell'asteroide tramite sweep anti-tunneling.
## 2. Frantumazione dell'asteroide ed espulsione fisica dei nodi 3D MineralDepositEntity.
## 3. Spettrometria avanzata e rilevamento nel catalogo radar/sensori.
## 4. Attrazione magnetica e raccolta tramite Service Drone con scarico alla corvetta.
## 5. Intake automatico al portello cargo della corvetta (Spaceship.CargoHatchArea3D).
## 6. Conversione vitale del ghiaccio d'acqua per i sistemi di Life Support.

var space_world: SpaceWorldManager = null
var ship: Spaceship = null
var drone: ServiceDroneEntity = null
var cargo_mgr: CargoManagerSingleton = null

func before_each() -> void:
	space_world = SpaceWorldManager
	space_world.clear_active_ballistic_projectiles()
	space_world.clear_incoming_projectiles()
	space_world.clear_spaceship_velocity_override()

	cargo_mgr = get_node_or_null("/root/CargoManager")
	if cargo_mgr == null:
		cargo_mgr = CargoManagerSingleton.new()
		add_child(cargo_mgr)
	cargo_mgr.clear_cargo()

	ship = Spaceship.new()
	add_child(ship)
	ship.cargo_manager = cargo_mgr
	ship.global_position = Vector3.ZERO
	if space_world and space_world.has_method("set_spaceship"):
		space_world.set_spaceship(ship)

	drone = ServiceDroneEntity.new()
	add_child(drone)
	drone.undock()

	await get_tree().process_frame

func after_each() -> void:
	if space_world and space_world.has_method("set_spaceship"):
		space_world.set_spaceship(null)
	for node in [drone, ship]:
		if is_instance_valid(node):
			node.free()
	if cargo_mgr and is_instance_valid(cargo_mgr):
		cargo_mgr.clear_cargo()
		if cargo_mgr != get_node_or_null("/root/CargoManager"):
			cargo_mgr.free()
	if space_world:
		space_world.clear_active_ballistic_projectiles()
		space_world.clear_incoming_projectiles()
		space_world.clear_spaceship_velocity_override()
	
	# Pulisce eventuali asteroidi o depositi residui
	var tree := get_tree()
	if tree:
		for ast in tree.get_nodes_in_group("asteroids"):
			if is_instance_valid(ast) and ast != null:
				ast.free()
		for dep in tree.get_nodes_in_group("mineral_deposits"):
			if is_instance_valid(dep) and dep != null:
				dep.free()

# =============================================================================
# SCENARIO 1: DANNEGGIAMENTO BALISTICO DELL'ASTEROIDE TRAMITE SWEEP
# =============================================================================
func test_ballistic_projectile_hits_and_damages_asteroid() -> void:
	var asteroid := Asteroid.new()
	asteroid.integrity = 100.0
	asteroid.radius_m = 6.0
	asteroid.name = "AST_TEST_TARGET"
	add_child(asteroid)
	asteroid.global_position = Vector3(0, 0, -30)

	# Spawna proiettile ad alta velocità che attraversa la posizione dell'asteroide
	# Posizione iniziale: (0, 0, -10), Velocità: (0, 0, -100) -> in 0.3s copre 30m raggiungendo Z = -40
	var p_data := space_world.spawn_ballistic_projectile(
		"HEAVY_CANNON",
		Vector3(0, 0, -10),
		Vector3(0, 0, -100),
		100.0,
		35.0,
		2.5,
		4.0,
		true
	)
	assert_eq(space_world.get_active_ballistic_projectiles().size(), 1, "Proiettile registrato nel buffer")

	# Simula step balistico
	space_world._update_ballistic_projectiles(0.3)

	# Il proiettile deve essersi infranto contro l'asteroide
	assert_eq(space_world.get_active_ballistic_projectiles().size(), 0, "Proiettile distrutto all'impatto")
	assert_lt(asteroid.integrity, 100.0, "L'asteroide deve aver subito il danno cinetico d'impatto")
	assert_almost_eq(asteroid.integrity, 65.0, 5.0, "L'integrità deve essersi ridotta di circa 35 HP")

# =============================================================================
# SCENARIO 2: FRANTUMAZIONE ASTEROIDE E GENERAZIONE NODI MINERALI
# =============================================================================
func test_asteroid_fracture_spawns_mineral_deposits() -> void:
	var asteroid := Asteroid.new()
	asteroid.integrity = 50.0
	asteroid.composition = {
		"Titanio (Ti)": 40.0,
		"Ghiaccio d'Acqua": 35.0,
		"Cristalli FLUX": 25.0
	}
	add_child(asteroid)
	asteroid.global_position = Vector3(10, 5, -20)

	var tracker := {
		"signal_emitted": false,
		"received_deposits": []
	}
	asteroid.asteroid_fractured.connect(func(deps: Array):
		tracker["signal_emitted"] = true
		tracker["received_deposits"] = deps
	)

	# Colpo letale che azzera l'integrità
	asteroid.take_damage(60.0)

	assert_true(asteroid.is_fractured, "L'asteroide deve risultare frantumato")
	assert_true(tracker["signal_emitted"], "Il segnale asteroid_fractured deve essere stato emesso")
	var received_deposits: Array = tracker["received_deposits"]
	assert_gte(received_deposits.size(), 2, "Devono essere stati generati almeno 2 frammenti minerali")
	assert_lte(received_deposits.size(), 4, "Non devono essere superati 4 frammenti per bilanciamento fisico")

	# Verifica proprietà fisiche ed espulsione newtoniana
	for dep in received_deposits:
		assert_true(dep is MineralDepositEntity, "I nodi generati devono essere istanze di MineralDepositEntity")
		assert_gt(dep.mass_kg, 0.0, "La massa del minerale deve essere positiva")
		assert_gt(dep.linear_velocity.length(), 0.0, "Il minerale deve possedere velocità di espulsione newtoniana")
		assert_true(dep.is_in_group("mineral_deposits"), "Il deposito deve essere registrato nel gruppo mineral_deposits")

# =============================================================================
# SCENARIO 3: SPETTROMETRIA E SENSORI DI BORDO
# =============================================================================
func test_mineral_deposit_spectrometry_and_sensor_listing() -> void:
	var ice_deposit := MineralDepositEntity.new()
	ice_deposit.deposit_id = "water_ice_block"
	ice_deposit.mineral_name = "Blocco Ghiaccio d'Acqua"
	ice_deposit.resource_type = "water_ice"
	ice_deposit.mass_kg = 32.0
	ice_deposit.purity = 0.95
	ice_deposit.base_value_credits = 200
	ice_deposit.life_support_water_units = 40.0
	ice_deposit.flux_yield = 0.5
	add_child(ice_deposit)
	ice_deposit.global_position = Vector3(0, 0, -25)

	# Verifica dati spettrometrici
	var spec := ice_deposit.get_spectrometry_data()
	assert_eq(spec.get("deposit_id"), "water_ice_block")
	assert_eq(spec.get("composition"), "water_ice")
	assert_almost_eq(float(spec.get("water_units")), 38.0, 1.0, "Resa vitale calcolata dalla purezza (40 * 0.95 = 38)")
	assert_gt(int(spec.get("estimated_credits")), 0, "Quotazione crediti presente")

	# Verifica presenza nel catalogo sensori
	var sensor_entities := space_world.get_sensor_entities()
	var found := false
	for ent in sensor_entities:
		if str(ent.get("type")) == "MINERAL_DEPOSIT" and str(ent.get("id")) == "water_ice_block":
			found = true
			assert_almost_eq(float(ent.get("water_units")), 38.0, 1.0)
			assert_almost_eq(float(ent.get("distance")), 25.0, 1.0)
			break
	assert_true(found, "Il deposito di ghiaccio deve comparire nel catalogo sensori come MINERAL_DEPOSIT")

# =============================================================================
# SCENARIO 4: ATTRAZIONE MAGNETICA E RACCOLTA TRAMITE SERVICE DRONE
# =============================================================================
func test_service_drone_magnet_attraction_and_collection() -> void:
	drone.global_position = Vector3.ZERO
	drone.battery = 100.0

	var ore_deposit := MineralDepositEntity.new()
	ore_deposit.deposit_id = "durasteel_ore"
	ore_deposit.mineral_name = "Minerale Grezzo Durasteel"
	ore_deposit.mass_kg = 35.0
	add_child(ore_deposit)
	ore_deposit.global_position = Vector3(0, 0, -10) # Entro il magnet_range di 18m

	drone.set_active_tool("magnet")
	drone.set_tool_trigger(true)

	# Il drone avvia l'attrazione magnetica
	drone._process_magnet(0.1)
	assert_not_null(ore_deposit._attractor_target, "Il deposito minerario deve aver agganciato il target di attrazione")
	assert_eq(ore_deposit._attractor_target, drone, "L'attractor deve essere il drone")

	# Avvicina il deposito a contatto ravvicinato (<= 2.5m)
	ore_deposit.global_position = Vector3(0, 0, -1.5)
	drone._process_magnet(0.1)

	# Il deposito viene raccolto nel carico del drone
	assert_eq(drone.cargo_items.size(), 1, "Il minerale deve essere stivato nel vano del drone")
	assert_almost_eq(drone.cargo_weight_kg, 35.0, 0.1, "Il peso stiva del drone deve riflettere la massa del minerale")

	# Docking alla corvetta e scarico automatico a bordo
	drone.dock()
	assert_true(drone.is_docked, "Il drone deve risultare attraccato")
	assert_eq(drone.cargo_items.size(), 0, "Il carico del drone deve essere trasferito alla nave")
	assert_true(cargo_mgr.has_item("durasteel_ore", 1), "Il minerale deve essere approdato nella stiva di CargoManager")

# =============================================================================
# SCENARIO 5: INTAKE DIRETTO PORTELLO CARGO NAVE
# =============================================================================
func test_spaceship_cargo_hatch_mineral_intake_and_stowage() -> void:
	var crystal := MineralDepositEntity.new()
	crystal.deposit_id = "exocrystal_shard"
	crystal.mineral_name = "Frammento Cristallo Esotico"
	crystal.mass_kg = 15.0
	crystal.base_value_credits = 550
	crystal.flux_yield = 8.0
	add_child(crystal)
	crystal.global_position = Vector3(0, 0, -60) # Fuori dal portello all'inizio

	var stowed_tracker := {
		"emitted": false,
		"data": {}
	}
	ship.cargo_stowed_in_ship.connect(func(data: Dictionary):
		stowed_tracker["emitted"] = true
		stowed_tracker["data"] = data
	)

	# Il cristallo entra nel portello cargo della corvetta
	var intake_ok := ship.intake_mineral_deposit(crystal)
	assert_true(intake_ok, "L'intake del minerale deve andare a buon fine")
	assert_true(stowed_tracker["emitted"], "Il segnale cargo_stowed_in_ship deve essere stato emesso")
	assert_eq(stowed_tracker["data"].get("id"), "exocrystal_shard")
	assert_true(cargo_mgr.has_item("exocrystal_shard", 1), "Il cristallo esotico deve essere presente in CargoManager")
	assert_true(crystal.is_collected, "Il nodo 3D deve essere contrassegnato come raccolto")

# =============================================================================
# SCENARIO 6: CONVERSIONE GHIACCIO D'ACQUA PER SUPPORTO VITALE
# =============================================================================
func test_water_ice_conversion_to_life_support_reserves() -> void:
	# Aggiungi blocchi di ghiaccio d'acqua in stiva
	cargo_mgr.add_item_by_id("water_ice_block", 3)
	assert_eq(cargo_mgr.get_item_quantity("water_ice_block"), 3, "Devono essere presenti 3 blocchi di ghiaccio")

	# Converte 2 blocchi in acqua per Life Support
	var conv_res := cargo_mgr.convert_ice_to_life_support(2)
	assert_true(conv_res.get("success", false), "La conversione del ghiaccio deve riuscire")
	assert_eq(conv_res.get("converted_count", 0), 2, "Devono essere stati convertiti esattamente 2 blocchi")
	assert_almost_eq(float(conv_res.get("water_units_produced", 0.0)), 70.0, 1.0, "Resa: 2 x 35 = 70 unità d'acqua")
	assert_eq(cargo_mgr.get_item_quantity("water_ice_block"), 1, "Deve rimanere 1 blocco di ghiaccio in stiva")
	assert_almost_eq(float(conv_res.get("mass_freed", 0.0)), 60.0, 1.0, "Massa liberata in stiva: 60 kg")
