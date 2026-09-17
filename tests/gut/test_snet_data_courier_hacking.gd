extends GutTest

## Suite di Test GUT per i Corrieri Dati S-Net & Intercettazione Hacker.
## Valida l'intero ciclo diegetico:
## 1. Setup dell'archetipo EnemyShipAI.ShipType.DATA_COURIER con parametri corazzati e radiofaro a 1920.0 MHz.
## 2. Riconoscimento del beacon e allineamento antenna direzionale in CommsApp.
## 3. Montaggio Target Drive con la cartella DataVault/ e i file .dat cifrati.
## 4. Esecuzione exploit dump_vault da HackExploitsApp con forzatura espulsione fisica del caveau.
## 5. Aggancio container DATA_CORE con Service Drone e stivaggio nel cargo hatch della corvetta con valorizzazione FLUX.

var courier: EnemyShipAI = null
var comms_app: CommsApp = null
var hack_app: HackExploitsApp = null
var ship: Spaceship = null
var drone: ServiceDroneEntity = null
var cargo_mgr: CargoManagerSingleton = null
var rdm: RemoteDriveManagerSingleton = null

func before_each() -> void:
	rdm = get_node_or_null("/root/RemoteDriveManager")
	if rdm and rdm.is_target_drive_mounted:
		rdm.unmount_target_drive()

	cargo_mgr = get_node_or_null("/root/CargoManager")
	if cargo_mgr == null:
		cargo_mgr = CargoManagerSingleton.new()
		add_child(cargo_mgr)
	cargo_mgr.clear_cargo()

	ship = Spaceship.new()
	add_child(ship)
	ship.cargo_manager = cargo_mgr
	ship.global_position = Vector3.ZERO
	if SpaceWorldManager and SpaceWorldManager.has_method("set_spaceship"):
		SpaceWorldManager.set_spaceship(ship)

	drone = ServiceDroneEntity.new()
	add_child(drone)
	drone.undock()

	await get_tree().process_frame

func after_each() -> void:
	if rdm and is_instance_valid(rdm) and rdm.is_target_drive_mounted:
		rdm.unmount_target_drive()

	if SpaceWorldManager and SpaceWorldManager.has_method("set_spaceship"):
		SpaceWorldManager.set_spaceship(null)

	for node in [courier, comms_app, hack_app, drone, ship]:
		if is_instance_valid(node) and node != null:
			node.free()

	if cargo_mgr and is_instance_valid(cargo_mgr):
		cargo_mgr.clear_cargo()
		if cargo_mgr != get_node_or_null("/root/CargoManager"):
			cargo_mgr.free()

	var tree := get_tree()
	if tree:
		for c in tree.get_nodes_in_group("cargo_containers"):
			if is_instance_valid(c) and c != null:
				c.free()
		for e in tree.get_nodes_in_group("enemy_ships"):
			if is_instance_valid(e) and e != null:
				e.free()

# =============================================================================
# SCENARIO 1: SETUP DELL'ARCHETIPO CORRIERE DATI E COMBAT DIRECTOR
# =============================================================================
func test_data_courier_setup_and_parameters() -> void:
	courier = EnemyShipAI.new()
	add_child(courier)
	courier.setup("COURIER_TEST_01", EnemyShipAI.ShipType.DATA_COURIER, Vector3(0, 50, -200))

	assert_eq(courier.ship_type, EnemyShipAI.ShipType.DATA_COURIER, "La nave deve essere di tipo DATA_COURIER")
	assert_eq(courier.comms_frequency, 1920.0, "La frequenza subspaziale del corriere deve essere 1920.0 MHz")
	assert_eq(courier.has_data_vault, true, "Il corriere deve possedere un caveau dati a bordo")
	assert_eq(courier.is_vault_jettisoned, false, "Il caveau dati non deve essere ancora stato espulso")
	assert_eq(courier.max_health, 180.0, "Lo scafo corazzato del corriere deve essere 180 HP")
	assert_eq(courier.max_shield, 120.0, "Gli scudi difensivi del corriere devono essere 120 HP")

	var cd := CombatDirector.new()
	add_child(cd)
	var spawned_courier := cd.spawn_data_courier(Vector3(100, 20, -150))
	assert_not_null(spawned_courier, "CombatDirector deve istanziare correttamente il corriere")
	assert_eq(spawned_courier.comms_frequency, 1920.0, "Il corriere spawnato deve operare a 1920.0 MHz")
	cd.free()

# =============================================================================
# SCENARIO 2: SINTONIZZAZIONE RADIOFARO E ANTENNA DIREZIONALE IN COMMS
# =============================================================================
func test_comms_courier_beacon_and_directional_tuning() -> void:
	var comms_scene: PackedScene = load("res://Applications/Comms/comms_app.tscn")
	comms_app = comms_scene.instantiate() as CommsApp
	add_child(comms_app)
	comms_app.can_control_comms = true
	comms_app._refresh_signals()
	await get_tree().process_frame

	# Sintonizza frequenza S-Net corrieri (1920.0 MHz)
	comms_app.current_frequency = 1920.0
	var locked_sig: Variant = comms_app._get_locked_signal()
	assert_not_null(locked_sig, "CommsApp deve agganciare la trasmissione del corriere su 1920.0 MHz")
	assert_eq(str(locked_sig.get("id")), "snet_courier", "Il segnale deve corrispondere all'ID snet_courier")
	assert_eq(str(locked_sig.get("type")), "COURIER", "Il tipo segnale deve essere COURIER")

	# Puntamento antenna: allinea verso bearing 65° del corriere
	comms_app.antenna_azimuth_deg = 65.0
	var eff_str := comms_app.get_effective_signal_strength(locked_sig)
	assert_gte(eff_str, 0.75, "Con antenna allineata a 65° la forza del segnale deve superare la soglia del 75%")

# =============================================================================
# SCENARIO 3: MONTAGGIO TARGET DRIVE E CAVEAU DATI CIFRATO DATAVAULT
# =============================================================================
func test_target_drive_datavault_mounting_and_file_structure() -> void:
	assert_not_null(rdm, "RemoteDriveManager deve essere presente come singleton")
	
	rdm.mount_target_drive("SNET-COURIER-01", "S-Net Data Courier Aegis")
	assert_true(rdm.is_target_drive_mounted, "Target Drive deve risultare montato")

	var vault_dir := "user://files/Target Drive/DataVault"
	assert_true(DirAccess.dir_exists_absolute(vault_dir), "La cartella DataVault deve esistere su Target Drive")

	var ledger_path := vault_dir + "/corporate_ledger.dat"
	var charts_path := vault_dir + "/sector_jump_charts.dat"
	var exploit_path := vault_dir + "/exploit_payload.dat"
	var manifest_path := vault_dir + "/Manifest_SNet.txt"

	assert_true(FileAccess.file_exists(ledger_path), "corporate_ledger.dat deve essere presente nel caveau")
	assert_true(FileAccess.file_exists(charts_path), "sector_jump_charts.dat deve essere presente nel caveau")
	assert_true(FileAccess.file_exists(exploit_path), "exploit_payload.dat deve essere presente nel caveau")
	assert_true(FileAccess.file_exists(manifest_path), "Manifest_SNet.txt deve essere presente nel caveau")

	# Verifica password configurata su FolderPasswordManager
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	if fpm:
		assert_true(fpm.check_password("Target Drive/DataVault", "VAULT-SEC-88"), "La password del DataVault deve essere VAULT-SEC-88")

	rdm.unmount_target_drive()
	assert_false(rdm.is_target_drive_mounted, "Target Drive deve risultare smontato")
	assert_false(DirAccess.dir_exists_absolute(vault_dir), "La cartella DataVault deve essere eliminata allo smontaggio")

# =============================================================================
# SCENARIO 4: ESECUZIONE EXPLOIT DUMP_VAULT DA HACK EXPLOITS APP
# =============================================================================
func test_hack_exploits_dump_vault_ejection() -> void:
	rdm.mount_target_drive("COURIER_SNET_01", "S-Net Data Courier Aegis")

	courier = EnemyShipAI.new()
	courier.ship_id = "COURIER_SNET_01"
	courier.ship_type = EnemyShipAI.ShipType.DATA_COURIER
	courier.has_data_vault = true
	courier.is_vault_jettisoned = false
	add_child(courier)
	courier.add_to_group("enemy_ships")

	var app_scene: PackedScene = load("res://Applications/HackExploits/hack_exploits_app.tscn")
	hack_app = app_scene.instantiate() as HackExploitsApp
	add_child(hack_app)
	hack_app.can_control_exploits = true
	await get_tree().process_frame

	# Esecuzione con password o chiave errata
	var fail_res := hack_app.execute_dump_vault("WRONG_PASS", "VAULT-PURGE-884")
	assert_false(fail_res, "L'exploit deve fallire con password errata")

	var fail_key := hack_app.execute_dump_vault("VAULT-SEC-88", "WRONG_KEY")
	assert_false(fail_key, "L'exploit deve fallire con chiave payload errata")

	# Esecuzione con credenziali corrette estratte da exploit_payload.dat
	var ok_res := hack_app.execute_dump_vault("VAULT-SEC-88", "VAULT-PURGE-884")
	assert_true(ok_res, "L'exploit dump_vault deve andare a buon fine")
	assert_true(rdm.is_exploit_active("dump_vault"), "L'exploit dump_vault deve risultare attivo in RemoteDriveManager")
	assert_true(courier.is_vault_jettisoned, "Il corriere deve aver espulso il caveau dati a seguito dell'exploit")

# =============================================================================
# SCENARIO 5: RECUPERO CONTAINER HARD DISK, TRAINO DRONE E STIVAGGIO CARGO
# =============================================================================
func test_physical_container_drone_tether_and_cargo_hatch_intake() -> void:
	courier = EnemyShipAI.new()
	courier.ship_id = "COURIER_SNET_02"
	courier.ship_type = EnemyShipAI.ShipType.DATA_COURIER
	courier.has_data_vault = true
	add_child(courier)
	courier.global_position = Vector3(0, 0, -50)

	var container: CargoContainerEntity = courier.jettison_data_vault()
	assert_not_null(container, "jettison_data_vault deve restituire un container 3D valido")
	assert_eq(container.item_data.get("category"), "DATA_CORE", "Il container deve essere di categoria DATA_CORE")
	assert_eq(float(container.item_data.get("unit_base_value")), 1800.0, "Il valore base del disco deve essere 1800 FLUX")

	# Traino magnetico con Service Drone
	var latched := drone.latch_cargo(container)
	assert_true(latched, "Il Service Drone deve poter agganciare il container con l'arpione magnetico")
	assert_eq(drone.get_latched_container(), container, "Il drone deve memorizzare il container agganciato")
	assert_true(container.is_latched, "Il container deve risultare vincolato")

	# Consegna e stivaggio al portello cargo della corvetta
	var intake_ok := ship.intake_cargo_container(container)
	assert_true(intake_ok, "Il portello cargo deve imbarcare con successo la banca dati quantistica")
	assert_true(container.is_collected, "Il container deve essere contrassegnato come raccolto")
	assert_null(drone.get_latched_container(), "L'arpione del drone deve rilasciare il carico dopo lo stivaggio")

	# Verifica presenza nella stiva nave
	assert_true(cargo_mgr.has_item("snet_quantum_core", 1), "La stiva deve contenere l'oggetto snet_quantum_core")
	var scav_items := cargo_mgr.get_scavenged_items()
	assert_gt(scav_items.size(), 0, "Il container deve comparire nell'elenco bottino di scavenging")

	# Liquidazione rapida del bottino a valore FLUX
	var liq_res := cargo_mgr.liquidate_scavenged_items(1.0, "LIQUID")
	assert_gte(float(liq_res.get("flux_earned", 0.0)), 1800.0, "La liquidazione del disco deve fruttare almeno 1800 FLUX")
	assert_false(cargo_mgr.has_item("snet_quantum_core", 1), "La stiva deve essere svuotata dopo la vendita")
