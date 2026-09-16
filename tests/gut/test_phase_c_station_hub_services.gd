extends GutTest

## Test suite GUT per la Fase C: Servizi Portuali Avanzati su StationHub e MissionManager Autonomo.
## Valida il ciclo vitale dei contratti, risoluzione bounty e trasporto, rumors volumetrici 3D e borsa merci X4.

var station_mining: SpaceStationEntity = null
var station_industrial: SpaceStationEntity = null
var docking_mgr: DockingManager = null
var mission_mgr: MissionManagerSingleton = null
var hub: StationHubApp = null
var cargo_mgr: CargoManagerSingleton = null
var flux_mgr: FluxEconomyManagerSingleton = null

func before_each() -> void:
	# Inizializza Stazione Mineraria
	station_mining = SpaceStationEntity.new()
	station_mining.station_id = "STATION_MINING_01"
	station_mining.station_name = "Avamposto Estrattivo Caelum-9"
	station_mining.economy_archetype = SpaceStationEntity.StationEconomyArchetype.MINING_OUTPOST
	add_child(station_mining)

	# Inizializza Stazione Industriale
	station_industrial = SpaceStationEntity.new()
	station_industrial.station_id = "STATION_IND_02"
	station_industrial.station_name = "Raffineria Industriale Vulcan-Forge"
	station_industrial.economy_archetype = SpaceStationEntity.StationEconomyArchetype.INDUSTRIAL_REFINERY
	add_child(station_industrial)

	# Inizializza DockingManager
	docking_mgr = DockingManager.new()
	add_child(docking_mgr)

	# Inizializza MissionManager
	mission_mgr = MissionManagerSingleton.new()
	add_child(mission_mgr)
	mission_mgr.reset_state()

	# Inizializza StationHubApp
	var hub_scene: PackedScene = load("res://Applications/StationHub/station_hub_app.tscn")
	assert_not_null(hub_scene, "station_hub_app.tscn deve essere caricabile")
	hub = hub_scene.instantiate() as StationHubApp
	add_child(hub)

	hub.mission_mgr = mission_mgr
	hub.bind_docking_manager(docking_mgr)
	cargo_mgr = hub.cargo_mgr
	flux_mgr = hub.flux_mgr
	if cargo_mgr:
		cargo_mgr.clear_cargo()

	await get_tree().process_frame

func after_each() -> void:
	for n in [hub, docking_mgr, station_mining, station_industrial, mission_mgr]:
		if is_instance_valid(n):
			n.free()

# =============================================================================
# TEST 1: CICLO VITALE MISSIONE BOUNTY IN MISSIONMANAGER
# =============================================================================
func test_mission_manager_lifecycle_bounty_flow() -> void:
	var contracts := mission_mgr.generate_station_contracts(station_mining)
	assert_gt(contracts.size(), 0, "MissionManager deve generare contratti procedurali")

	# Trova il contratto bounty
	var bounty_cnt: Dictionary = {}
	for c in contracts:
		if str(c.get("type")) == "BOUNTY":
			bounty_cnt = c
			break
	assert_false(bounty_cnt.is_empty(), "Deve essere presente almeno un contratto BOUNTY")
	assert_eq(bounty_cnt.get("status"), "AVAILABLE", "Stato iniziale deve essere AVAILABLE")

	# Verifica coordinate 3D volumetriche (quota Y != 0)
	var coords_3d: Vector3 = bounty_cnt.get("target_coords_3d", Vector3.ZERO)
	assert_ne(coords_3d.y, 0.0, "La quota altimetrica Y deve essere non-zero (volumetrica)")

	var cid: String = str(bounty_cnt.get("id"))
	
	# 1. Accettazione contratto
	var accept_ok := mission_mgr.accept_contract(cid)
	assert_true(accept_ok, "accept_contract deve avere successo")
	var active_contract := mission_mgr.get_contract_by_id(cid)
	assert_eq(active_contract.get("status"), "IN_PROGRESS", "Lo stato deve passare a IN_PROGRESS")
	assert_true(active_contract.get("is_accepted"), "is_accepted deve essere true")

	# 2. Risoluzione Bounty tramite distruzione bersaglio
	var initial_completed := mission_mgr.get_completed_contracts().size()
	var foe_id: String = str(active_contract.get("target_entity_id"))
	mission_mgr.on_enemy_destroyed(foe_id, "PIRATES", coords_3d)

	var comp_contract := mission_mgr.get_contract_by_id(cid)
	assert_eq(comp_contract.get("status"), "COMPLETED", "Lo stato del contratto deve essere COMPLETED dopo la distruzione del bersaglio")
	assert_true(comp_contract.get("is_completed"), "is_completed deve essere true")
	assert_eq(mission_mgr.get_completed_contracts().size(), initial_completed + 1)

	# 3. Riscossione ricompensa (Claim)
	var initial_credits := flux_mgr.credits if flux_mgr else 0
	var claim_res := mission_mgr.claim_contract_reward(cid)
	assert_true(claim_res.get("success", false), "claim_contract_reward deve avere successo")
	assert_gt(claim_res.get("credits", 0), 0, "I crediti della ricompensa devono essere positivi")

	var claimed_contract := mission_mgr.get_contract_by_id(cid)
	assert_eq(claimed_contract.get("status"), "CLAIMED", "Lo stato deve essere CLAIMED")
	if flux_mgr:
		assert_gt(flux_mgr.credits, initial_credits, "I crediti del giocatore devono essere stati accreditati")

	# Tentativo di doppio incasso
	var double_claim := mission_mgr.claim_contract_reward(cid)
	assert_true(double_claim.is_empty(), "Un contratto già riscosso non può essere reclamato nuovamente")

# =============================================================================
# TEST 2: INTERFACCIA FIXER & STATIONHUB CONTRATTI
# =============================================================================
func test_fixer_contract_acceptance_and_claim_payout() -> void:
	# Attracco forzato alla stazione mineraria
	docking_mgr.force_complete_docking(station_mining, 0)
	assert_true(hub.is_station_docked, "StationHub deve risultare attraccato")

	hub._refresh_contracts_view()
	assert_gt(hub.active_contracts.size(), 0, "La bacheca contratti deve contenere missioni disponibili")

	# Seleziona primo contratto disponibile
	hub._on_contract_item_selected(0)
	var selected_cnt: Dictionary = hub.active_contracts[0]
	var cid: String = str(selected_cnt.get("id"))
	assert_false(hub.btn_accept_contract.disabled, "Il pulsante Accetta deve essere abilitato per contratti AVAILABLE")
	assert_eq(hub.btn_accept_contract.text, "Accetta Incarico")

	# Clicca Accetta
	hub._on_accept_contract_pressed()
	var in_prog := mission_mgr.get_contract_by_id(cid)
	assert_eq(in_prog.get("status"), "IN_PROGRESS", "Il contratto deve essere registrato IN_PROGRESS")

	# Trova l'indice del contratto accettato nella UI
	var target_idx := -1
	for i in range(hub.active_contracts.size()):
		if str(hub.active_contracts[i].get("id")) == cid:
			target_idx = i
			break
	assert_gt(target_idx, -1, "Il contratto deve essere presente nella lista UI")
	hub._on_contract_item_selected(target_idx)
	assert_true(hub.btn_accept_contract.disabled, "Il pulsante deve essere disabilitato se il contratto è IN_PROGRESS")

	# Completa il contratto via MissionManager
	mission_mgr.complete_contract(cid)
	hub._refresh_contracts_view()

	target_idx = -1
	for i in range(hub.active_contracts.size()):
		if str(hub.active_contracts[i].get("id")) == cid:
			target_idx = i
			break
	assert_gt(target_idx, -1, "Il contratto completato deve essere presente nella lista UI")
	hub._on_contract_item_selected(target_idx)

	assert_eq(hub.btn_accept_contract.text, "Riscuoti Taglia / Ricompensa", "Il pulsante deve mostrare Riscuoti Taglia")
	assert_false(hub.btn_accept_contract.disabled, "Il pulsante Riscuoti deve essere abilitato")

	# Riscossione dal Fixer
	var pre_credits := flux_mgr.credits if flux_mgr else 0
	hub._on_accept_contract_pressed()
	if flux_mgr:
		assert_gt(flux_mgr.credits, pre_credits, "I crediti devono essere stati riscossi su FluxEconomyManager")

	assert_eq(hub.btn_accept_contract.text, "Contratto Riscosso")
	assert_true(hub.btn_accept_contract.disabled, "Il pulsante deve essere disabilitato a riscatto avvenuto")

# =============================================================================
# TEST 3: TAVERNA, RUMORS E WAYPOINT 3D VOLUMETRICO
# =============================================================================
func test_tavern_rumor_volumetric_3d_waypoint_injection() -> void:
	docking_mgr.force_complete_docking(station_mining, 0)
	hub._refresh_tavern_view()
	assert_gt(hub.active_rumors.size(), 0, "La taverna deve offrire dicerie spaziali")

	# Seleziona il primo rumor
	hub._on_rumor_item_selected(0)
	var rumor: Dictionary = hub.active_rumors[0]
	var r_coords: Vector3 = rumor.get("coordinates", Vector3.ZERO)
	assert_ne(r_coords.y, 0.0, "Le coordinate della diceria devono avere quota Y disallineata dall'eclittica")

	# Premi pulsante invio waypoint
	hub._on_record_coordinates_pressed()

	# Verifica registrazione su SpaceWorldManager
	if SpaceWorldManager:
		var wp := SpaceWorldManager.get_active_waypoint()
		assert_false(wp.is_empty(), "SpaceWorldManager deve avere un waypoint attivo impostato")
		var wp_pos: Vector3 = wp.get("pos", Vector3.ZERO)
		assert_eq(wp_pos, r_coords, "Le coordinate del waypoint devono coincidere esattamente con quelle del rumor")
		assert_ne(wp_pos.y, 0.0, "La quota 3D del waypoint deve essere conservata")

# =============================================================================
# TEST 4: BORSA MERCI X4, DIFFERENZIALI DI PREZZO E PROFITTO COMMERCIALE
# =============================================================================
func test_x4_market_price_differentials_and_trading_profit() -> void:
	# 1. Stazione A: Mining Outpost (Surplus minerali -35%, alta domanda naniti +40%)
	assert_eq(station_mining.get_category_price_modifier("MINERAL"), -0.35)
	assert_eq(station_mining.get_category_price_modifier("NANITES"), 0.40)
	assert_true(station_mining.get_market_rating_label("MINERAL").contains("SURPLUS"))
	assert_true(station_mining.get_market_rating_label("NANITES").contains("DOMANDA ELEVATA"))

	# 2. Stazione B: Industrial Refinery (Alta domanda minerali +30%, surplus leghe -25%)
	assert_eq(station_industrial.get_category_price_modifier("MINERAL"), 0.30)
	assert_true(station_industrial.get_market_rating_label("MINERAL").contains("DOMANDA ELEVATA"))

	var base_val := 120.0 # Valore base del titanio grezzo

	# Prezzo di acquisto minerali alla stazione mineraria
	var buy_price_mining := station_mining.get_trade_price("MINERAL", base_val, true)
	# Prezzo di vendita minerali alla stazione industriale
	var sell_price_industrial := station_industrial.get_trade_price("MINERAL", base_val, false)

	# Margine commerciale inter-settore deve essere nettamente positivo!
	assert_lt(buy_price_mining, sell_price_industrial, "Il prezzo d'acquisto alla miniera deve essere inferiore al prezzo di vendita alla raffineria")
	var unit_profit := sell_price_industrial - buy_price_mining
	assert_gt(unit_profit, 20.0, "Il margine commerciale per unità deve garantire un profitto congruo")

	# Verifica bid/ask spread sulla stessa stazione per eliminare loop di profitto infinito locale
	var sell_price_mining := station_mining.get_trade_price("MINERAL", base_val, false)
	assert_lt(sell_price_mining, buy_price_mining, "Sulla stessa stazione il prezzo di vendita deve essere rigorosamente inferiore al prezzo di acquisto (no loop locale)")

	# Esecuzione compravendita simulata
	docking_mgr.force_complete_docking(station_mining, 0)
	hub._refresh_cargo_market_view()

	# Compra 5 unità di titanio
	var pre_trade_credits := flux_mgr.credits if flux_mgr else 5000
	hub._on_station_market_selected(0)
	if hub.buy_quantity_spin_box:
		hub.buy_quantity_spin_box.value = 5.0
	hub._on_btn_buy_cargo_pressed()

	assert_eq(cargo_mgr.get_item_quantity("minerals_titanium"), 5, "La corvetta deve avere 5 unità di titanio in stiva")

	# Trasferimento e attracco alla stazione industriale
	docking_mgr.request_undock()
	docking_mgr.force_complete_docking(station_industrial, 0)
	hub._refresh_cargo_market_view()

	# Vendi le 5 unità di titanio
	hub._on_ship_cargo_selected(0)
	if hub.sell_quantity_spin_box:
		hub.sell_quantity_spin_box.value = 5.0
	hub._on_btn_sell_cargo_pressed()

	assert_eq(cargo_mgr.get_item_quantity("minerals_titanium"), 0, "La stiva deve essere vuota dopo la vendita")
	if flux_mgr:
		assert_gt(flux_mgr.credits, pre_trade_credits, "Il saldo finale dei crediti deve essere superiore al saldo iniziale (plusvalenza commerciale positiva)")

# =============================================================================
# TEST 5: MISSIONE TRASPORTO MERCI E ATTRACCO ALLA STAZIONE DESTINAZIONE
# =============================================================================
func test_cargo_transport_mission_docking_fulfillment() -> void:
	var contracts := mission_mgr.generate_station_contracts(station_mining)
	var transport_cnt: Dictionary = {}
	for c in contracts:
		if str(c.get("type")) == "TRANSPORT":
			transport_cnt = c
			break
	assert_false(transport_cnt.is_empty(), "Deve essere generata una missione di trasporto")

	var cid: String = str(transport_cnt.get("id"))
	var dest_id: String = str(transport_cnt.get("destination_station_id"))
	mission_mgr.accept_contract(cid)

	assert_eq(mission_mgr.get_contract_by_id(cid).get("status"), "IN_PROGRESS")

	# Attracco a stazione errata -> non deve completare
	mission_mgr.on_station_docked("SOME_OTHER_STATION")
	assert_eq(mission_mgr.get_contract_by_id(cid).get("status"), "IN_PROGRESS", "Attracco a stazione non target non deve completare la missione")

	# Attracco alla stazione corretta di destinazione
	mission_mgr.on_station_docked(dest_id)
	assert_eq(mission_mgr.get_contract_by_id(cid).get("status"), "COMPLETED", "L'attracco alla stazione di destinazione deve completare automaticamente il trasporto")
