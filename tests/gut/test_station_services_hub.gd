extends GutTest

## Test GUT per il flusso integrato dei Servizi di Stazione Spaziale.
## Migrato dal vecchio test manuale tests/test_station_services_hub.gd che usava
## assert() nudo (fragile in --headless senza debugger). Ogni condizione è stata
## ri-validata contro il comportamento reale di StationManager/DockingManager,
## CommsApp, StationHubApp, LogbookApp e SystemicDamageHandler.
##
## Le fasi sono state suddivise in funzioni test_xxx() sequenziali che condividono
## lo stato (station, station_mgr, comms, hub, logbook, cargo_mgr, flux_mgr) tramite
## variabili di istanza, dato che GUT esegue una sola istanza dello script per tutti
## i test del file, in ordine di dichiarazione.

var station: SpaceStationEntity = null
var station_mgr: StationManager = null
var comms: CommsApp = null
var hub: StationHubApp = null
var logbook: LogbookApp = null
var cargo_mgr: CargoManagerSingleton = null
var flux_mgr: FluxEconomyManagerSingleton = null

func before_all() -> void:
	var station_scene: PackedScene = load("res://Outside/Stations/space_station_entity.tscn")
	assert_not_null(station_scene, "La scena space_station_entity.tscn deve caricarsi correttamente")
	station = station_scene.instantiate() as SpaceStationEntity
	add_child(station)

	station_mgr = StationManager.new()
	add_child(station_mgr)
	station_mgr.register_station(station)

	var comms_scene: PackedScene = load("res://Applications/Comms/comms_app.tscn")
	if comms_scene != null:
		comms = comms_scene.instantiate() as CommsApp
		add_child(comms)
		comms.bind_docking_manager(station_mgr)

	var hub_scene: PackedScene = load("res://Applications/StationHub/station_hub_app.tscn")
	assert_not_null(hub_scene, "La scena station_hub_app.tscn deve caricarsi correttamente")
	hub = hub_scene.instantiate() as StationHubApp
	add_child(hub)
	hub.bind_docking_manager(station_mgr)

	var logbook_scene: PackedScene = load("res://Applications/Logbook/logbook_app.tscn")
	if logbook_scene != null:
		logbook = logbook_scene.instantiate() as LogbookApp
		add_child(logbook)

	cargo_mgr = hub.cargo_mgr
	flux_mgr = hub.flux_mgr

	await get_tree().process_frame
	await get_tree().process_frame

func after_all() -> void:
	for n in [station, station_mgr, comms, hub, logbook]:
		if is_instance_valid(n):
			n.free()

# =========================================================================
# TEST 1: DOCKING / UNDOCKING VIA COMMS & STATION MANAGER
# =========================================================================
func test_docking_undocking_procedure_and_is_docked_signal() -> void:
	assert_false(station_mgr.is_docked, "Stato iniziale deve essere non ancorato")
	assert_false(hub.is_station_docked, "StationHub deve essere inizialmente disconnesso")

	if comms:
		comms.can_control_comms = true
		comms.current_frequency = station.comms_frequency
		var comms_req := comms.request_station_docking(station, station_mgr)
		assert_true(comms_req, "Richiesta di attracco da Comms deve avere successo")
		assert_eq(station_mgr.current_state, DockingManager.DockingState.APPROACH_GUIDANCE, "Lo stato docking deve essere in guida approccio")

	# Completamento dell'attracco
	station_mgr.force_complete_docking(station, 0)
	assert_true(station_mgr.is_docked, "StationManager deve registrare is_docked = true")
	if comms:
		assert_true(comms.is_docked, "CommsApp deve aggiornare lo stato is_docked = true")
	assert_true(hub.is_station_docked, "StationHubApp deve riconoscere l'attracco completato")
	assert_eq(hub.current_station_id, station.station_id, "L'ID stazione deve essere associato a StationHub")
	assert_false(hub.undocked_overlay.visible, "L'overlay di non ancoraggio deve essere nascosto")

# =========================================================================
# TEST 2: COMPRAVENDITA MERCI, TRASFERIMENTO STIVA E SALDO FLUX
# =========================================================================
func test_cargo_market_trading_and_flux_rating() -> void:
	assert_not_null(cargo_mgr, "CargoManagerSingleton deve essere disponibile")
	assert_not_null(flux_mgr, "FluxEconomyManagerSingleton deve essere disponibile")

	var initial_credits: int = flux_mgr.credits
	var initial_mass: float = cargo_mgr.get_total_mass()
	var initial_vol: float = cargo_mgr.get_total_volume()
	var initial_flux_score: float = flux_mgr.flux_score

	# Acquisto merci dal mercato locale della stazione
	assert_gt(hub.station_market_goods.size(), 0, "Il catalogo merci del mercato stazione deve essere popolato")
	hub._on_station_market_selected(0) # Seleziona titanio grezzo
	if hub.buy_quantity_spin_box:
		hub.buy_quantity_spin_box.value = 2.0

	var buy_item := hub.station_market_goods[0]
	var buy_price := int(hub._get_effective_price(buy_item.get("unit_base_value"), true)) * 2

	hub._on_btn_buy_cargo_pressed()

	assert_eq(flux_mgr.credits, initial_credits - buy_price, "I crediti devono essere decurtati del prezzo d'acquisto")
	assert_gt(cargo_mgr.get_total_mass(), initial_mass, "La massa della stiva deve essere aumentata")
	assert_gt(cargo_mgr.get_total_volume(), initial_vol, "Il volume della stiva deve essere aumentato")
	assert_gte(cargo_mgr.get_item_quantity(buy_item.get("id")), 2, "La merce acquistata deve risultare nella stiva nave")
	assert_gte(flux_mgr.flux_score, initial_flux_score, "Il rating FLUX deve essere incrementato o premiato per la transazione")

	# Vendita merci dalla stiva della corvetta al porto
	var mass_before_sell := cargo_mgr.get_total_mass()
	var credits_before_sell := flux_mgr.credits
	var ship_items := cargo_mgr.get_cargo_list()
	assert_gt(ship_items.size(), 0, "La stiva deve contenere elementi vendibili")

	hub._on_ship_cargo_selected(0)
	if hub.sell_quantity_spin_box:
		hub.sell_quantity_spin_box.value = 1.0

	var sell_item: Variant = ship_items[0]
	var sell_payout := int(hub._get_effective_price(sell_item.get("unit_base_value"), false))

	hub._on_btn_sell_cargo_pressed()

	assert_eq(flux_mgr.credits, credits_before_sell + sell_payout, "I crediti devono aumentare dopo la vendita")
	assert_lt(cargo_mgr.get_total_mass(), mass_before_sell, "La massa della stiva deve diminuire dopo lo scarico")

# =========================================================================
# TEST 3: ACCETTAZIONE CONTRATTO E SINCRONIZZAZIONE CON LOGBOOK
# =========================================================================
func test_contract_acceptance_and_logbook_sync() -> void:
	assert_gt(hub.active_contracts.size(), 0, "La bacheca contratti deve contenere missioni")

	hub._on_contract_item_selected(0)
	var selected_cnt := hub.active_contracts[0]
	var target_cnt_id: String = selected_cnt.get("id")

	hub._on_accept_contract_pressed()
	assert_true(hub.active_contracts[0]["is_accepted"], "Il contratto deve risultare accettato su StationHub")

	if logbook:
		var found_in_logbook := false
		for c in logbook.active_contracts:
			if c.get("id") == target_cnt_id or c.get("title") == selected_cnt.get("title"):
				found_in_logbook = true
				assert_eq(c.get("status"), "IN_PROGRESS", "Il contratto sincronizzato deve avere stato IN_PROGRESS")
				break
		assert_true(found_in_logbook, "Il contratto accettato deve essere sincronizzato e visibile su Logbook")

# =========================================================================
# TEST 4: ACQUISTO SOFTWARE E SCRITTURA SU SHIP DRIVE/PROGRAMS/
# =========================================================================
func test_software_repository_purchase_writes_ship_drive_file() -> void:
	assert_gt(hub.active_software_items.size(), 0, "Il catalogo software repository deve contenere moduli")

	hub._on_software_item_selected(0)
	var sw_item := hub.active_software_items[0]
	var sw_price: int = sw_item.get("price")
	var credits_before_sw := flux_mgr.credits

	hub._on_buy_software_item_pressed()
	assert_eq(flux_mgr.credits, credits_before_sw - sw_price, "I crediti devono essere decurtati per l'acquisto software")

	var folder: String = sw_item.get("app_target_folder")
	var fname: String = sw_item.get("filename")
	var expected_path := "user://files/Ship Drive/Programs/%s/%s" % [folder, fname]

	assert_true(FileAccess.file_exists(expected_path), "Il modulo software acquistato deve essere scritto su: " + expected_path)
	var f := FileAccess.open(expected_path, FileAccess.READ)
	assert_not_null(f, "Il file software su Ship Drive deve essere leggibile")
	var file_content := f.get_as_text()
	f.close()
	assert_false(file_content.is_empty(), "Il file software non deve essere vuoto")

# =========================================================================
# TEST 5: RIPARAZIONE SCAFO, AZZERAMENTO BRECCE E DANNI SISTEMICI
# =========================================================================
func test_shipyard_hull_repair_clears_breaches_and_alarms() -> void:
	# Inietta danni/brecce nello scafo
	var dmg_handler := SystemicDamageHandler.new()
	dmg_handler.add_to_group("systemic_damage_handler")
	add_child_autofree(dmg_handler)
	dmg_handler.reset()

	# Infligge un impatto critico per generare breccia e abbassare lo scafo
	dmg_handler.process_hit(Vector3(0, 0, -5), 180.0, "plasma")
	assert_lt(dmg_handler.hull_integrity, 100.0, "Integrità scafo deve essere ridotta dopo l'impatto")

	if SpaceWorldManager:
		SpaceWorldManager.spawn_ship_damage("breach", Vector2(100, 50), "engines", 45.0)
		assert_gt(SpaceWorldManager.get_active_ship_damages().size(), 0, "Brecce attive devono risultare su SpaceWorldManager")

	hub._refresh_shipyard_view()

	# Esecuzione riparazione cantiere
	var credits_before_repair := flux_mgr.credits
	hub._on_repair_hull_pressed()

	assert_eq(flux_mgr.credits, credits_before_repair - 150, "Costo riparazione scafo (150 CR) deve essere scalato")
	assert_eq(hub.hull_bar.value, 100.0, "La barra di integrità scafo deve essere tornata al 100%")

	if SpaceWorldManager:
		assert_true(SpaceWorldManager.get_active_ship_damages().is_empty(), "Tutte le brecce scafo su SpaceWorldManager devono essere state azzerate")

	assert_eq(dmg_handler.hull_integrity, 100.0, "Integrità scafo su SystemicDamageHandler deve essere ripristinata al 100%")
	assert_eq(dmg_handler.current_alarm_level, GlobalValues.AlarmLevel.NORMAL, "Livello allarme deve tornare a NORMAL dopo le riparazioni")

# =========================================================================
# TEST 6: UNDOCKING FINALE
# =========================================================================
func test_undocking_restores_free_flight() -> void:
	hub._on_btn_undock_pressed()
	assert_false(station_mgr.is_docked, "StationManager deve risultare undocked")
	assert_false(hub.is_station_docked, "StationHubApp deve risultare disconnesso dalla stazione")
	assert_true(hub.undocked_overlay.visible, "Overlay undocked deve tornare visibile")
