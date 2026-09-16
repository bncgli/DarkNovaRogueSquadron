extends GutTest

## Test GUT per la Fase G: Chiusura del Ciclo, Debriefing e Rientro Persistente.
## Valida:
## 1. Identificazione e liquidazione in blocco del bottino di scavenging (merci ordinarie vs container/relitti).
## 2. Riscossione collettiva dei contratti e debriefing taglie dal Fixer in StationHub Tab 2.
## 3. Gestione discrezionale del debito di noleggio nave (Ship Rent Service) in StationHub Tab 4.
## 4. Persistenza e ricaricamento del blueprint nave (ShipBlueprint) su file disco utente (user://).
## 5. Integrazione modulare del flusso di rientro in StationHubApp.

var test_blueprint_path := "user://blueprints/test_phase_g_session.tres"

func before_each() -> void:
	if FileAccess.file_exists(test_blueprint_path):
		DirAccess.remove_absolute(test_blueprint_path)

func after_each() -> void:
	if FileAccess.file_exists(test_blueprint_path):
		DirAccess.remove_absolute(test_blueprint_path)

func test_scavenged_loot_filtering_and_quick_liquidation() -> void:
	var cargo_mgr := CargoManagerSingleton.new()
	add_child(cargo_mgr)
	cargo_mgr.clear_cargo()
	
	# 1. Aggiunta merci commerciali standard
	var item_titanium := CargoItemData.new("minerals_titanium", "Titanio Raffinato", 10)
	item_titanium.category = "MINERALS"
	item_titanium.unit_base_value = 120.0
	item_titanium.unit_mass_kg = 25.0
	item_titanium.unit_volume_m3 = 0.5
	item_titanium.is_scavenged = false
	cargo_mgr.add_item(item_titanium, 10)
	
	var item_energy := CargoItemData.new("energy_cells", "Celle Energetiche", 5)
	item_energy.category = "ENERGY"
	item_energy.unit_base_value = 80.0
	item_energy.unit_mass_kg = 5.0
	item_energy.unit_volume_m3 = 0.1
	item_energy.is_scavenged = false
	cargo_mgr.add_item(item_energy, 5)
	
	# 2. Aggiunta bottino di scavenging da relitti e container spaziali
	var item_scav1 := CargoItemData.new("salvaged_hull_plating", "Pannelli di Corazza", 4)
	item_scav1.category = "WRECK_COMPONENT"
	item_scav1.unit_base_value = 280.0
	item_scav1.unit_mass_kg = 35.0
	item_scav1.unit_volume_m3 = 0.6
	item_scav1.is_scavenged = true
	cargo_mgr.add_item(item_scav1, 4)
	
	var item_scav2 := CargoItemData.new("alien_relic_fragment", "Frammento Reliquia Precursore", 2)
	item_scav2.category = "SCAVENGED"
	item_scav2.unit_base_value = 950.0
	item_scav2.unit_mass_kg = 12.0
	item_scav2.unit_volume_m3 = 0.3
	item_scav2.is_scavenged = true
	cargo_mgr.add_item(item_scav2, 2)
	
	assert_eq(cargo_mgr.get_cargo_list().size(), 4, "La stiva deve contenere 4 voci distinte di carico")
	
	# 3. Verifica del filtraggio degli item scavenged
	var scav_items := cargo_mgr.get_scavenged_items()
	assert_eq(scav_items.size(), 2, "Il filtro deve identificare esattamente i 2 item di bottino scavenging")
	
	var summary := cargo_mgr.calculate_scavenged_value()
	assert_eq(summary.get("item_count", 0), 6, "Il conteggio totale delle unità scavenged deve essere 4 + 2 = 6")
	var expected_creds: float = (280.0 * 4.0) + (950.0 * 2.0) # 1120 + 1900 = 3020
	assert_almost_eq(float(summary.get("credits", 0.0)), expected_creds, 0.1, "Il controvalore crediti stimato deve corrispondere a 3020 CR")
	
	var mass_before := cargo_mgr.get_total_mass()
	var vol_before := cargo_mgr.get_total_volume()
	
	# 4. Esecuzione della liquidazione rapida in blocco
	var res := cargo_mgr.liquidate_scavenged_items()
	assert_eq(res.get("liquidated_count", 0), 6, "Devono essere state liquidate 6 unità totali di scavenging")
	assert_almost_eq(float(res.get("credits_earned", 0.0)), expected_creds, 0.1, "I crediti incassati devono essere 3020 CR")
	
	# 5. Verifica che le merci commerciali standard siano rimaste intatte in stiva
	var remaining_items := cargo_mgr.get_cargo_list()
	assert_eq(remaining_items.size(), 2, "In stiva devono rimanere solo le 2 merci commerciali standard")
	assert_not_null(cargo_mgr.get_item("minerals_titanium"), "I minerali di titanio standard non devono essere stati toccati")
	assert_not_null(cargo_mgr.get_item("energy_cells"), "Le celle energetiche non devono essere state toccate")
	assert_null(cargo_mgr.get_item("salvaged_hull_plating"), "Il bottino di corazza deve essere stato rimosso dalla stiva")
	assert_null(cargo_mgr.get_item("alien_relic_fragment"), "La reliquia aliena deve essere stata rimossa dalla stiva")
	
	# Verifica liberazione di massa e volume
	assert_lt(cargo_mgr.get_total_mass(), mass_before, "La massa totale in stiva deve essere diminuita")
	assert_lt(cargo_mgr.get_total_volume(), vol_before, "Il volume totale in stiva deve essere diminuito")
	
	cargo_mgr.queue_free()

func test_collective_contract_claim_and_payout() -> void:
	var mission_mgr := MissionManagerSingleton.new()
	add_child(mission_mgr)
	mission_mgr.reset_state()
	
	# 1. Configurazione contratti: 2 completati, 1 disponibile
	var c_bounty := {
		"id": "contract_bounty_alpha",
		"title": "Taglia Corsaro Alpha",
		"type": "BOUNTY",
		"status": "COMPLETED",
		"is_accepted": true,
		"is_completed": true,
		"reward_credits": 2500,
		"reward_flux": 150
	}
	var c_transport := {
		"id": "contract_transport_beta",
		"title": "Consegna Medica Beta",
		"type": "TRANSPORT",
		"status": "COMPLETED",
		"is_accepted": true,
		"is_completed": true,
		"reward_credits": 1200,
		"reward_flux": 80
	}
	var c_available := {
		"id": "contract_patrol_gamma",
		"title": "Pattugliamento Gamma",
		"type": "PATROL",
		"status": "AVAILABLE",
		"is_accepted": false,
		"is_completed": false,
		"reward_credits": 800,
		"reward_flux": 50
	}
	
	mission_mgr.completed_contracts.append(c_bounty)
	mission_mgr.completed_contracts.append(c_transport)
	mission_mgr.available_contracts.append(c_available)
	
	# 2. Verifica helper contratti completati non ancora riscossi
	var unclaimed := mission_mgr.get_unclaimed_completed_contracts()
	assert_eq(unclaimed.size(), 2, "Devono risultare 2 contratti completati in attesa di riscossione")
	
	# 3. Riscossione collettiva con un clic
	var claim_result: Dictionary = mission_mgr.claim_all_completed_contracts()
	assert_eq(claim_result.get("claimed_count", 0), 2, "Devono essere riscossi esattamente 2 contratti")
	assert_eq(claim_result.get("total_credits", 0), 3700, "I crediti totali riscossi devono essere 2500 + 1200 = 3700 CR")
	assert_eq(claim_result.get("total_flux", 0), 230, "I FLUX totali riscossi devono essere 150 + 80 = 230 FLUX")
	
	# 4. Verifica passaggio allo stato CLAIMED
	for c in mission_mgr.completed_contracts:
		assert_eq(str(c.get("status")), "CLAIMED", "I contratti completati devono passare allo stato CLAIMED")
		
	# 5. Verifica che il contratto disponibile non sia stato alterato
	var av_list: Array = mission_mgr.get_available_contracts()
	assert_eq(av_list.size(), 1, "Il contratto disponibile deve rimanere in bacheca")
	assert_eq(str(av_list[0].get("id")), "contract_patrol_gamma", "Il contratto disponibile deve rimanere contract_patrol_gamma")
	assert_eq(str(av_list[0].get("status")), "AVAILABLE", "Lo stato del contratto disponibile deve rimanere AVAILABLE")
	
	# 6. Tentativo di claim collettivo successivo (nessun contratto rimasto da riscuotere)
	var claim_empty := mission_mgr.claim_all_completed_contracts()
	assert_eq(claim_empty.get("claimed_count", 0), 0, "Non devono esserci contratti da riscuotere al secondo tentativo")
	
	mission_mgr.queue_free()

func test_discretionary_rent_debt_payment() -> void:
	var bp := ShipBlueprint.new()
	bp.flux = 500
	bp.setup_default_freemium_debt() # -700 FLUX
	
	assert_eq(bp.flux, 500, "Il saldo liquido iniziale deve essere di 500 FLUX")
	assert_eq(bp.get_rent_debt(), 700, "Il debito iniziale di noleggio deve essere di 700 FLUX")
	
	# 1. Versamento quota discrezionale di 200 FLUX
	var paid_first := bp.repay_rent_debt(200)
	assert_eq(paid_first, 200, "Devono essere stati versati esattamente 200 FLUX")
	assert_eq(bp.flux, 300, "Il saldo liquido deve essere sceso a 300 FLUX")
	assert_eq(bp.get_rent_debt(), 500, "Il debito residuo deve essere sceso a 500 FLUX")
	
	# 2. Versamento superiore al saldo liquido (tentativo di pagare 400 con 300 disponibili)
	var paid_clamped := bp.repay_rent_debt(400)
	assert_eq(paid_clamped, 300, "Il pagamento deve essere clampato al saldo liquido disponibile (300 FLUX)")
	assert_eq(bp.flux, 0, "Il saldo liquido deve risultare azzerato")
	assert_eq(bp.get_rent_debt(), 200, "Il debito residuo deve essere di 200 FLUX")
	
	# 3. Guadagno nuovi fondi e pagamento finale con estinzione debito
	bp.flux = 450
	var paid_final := bp.repay_rent_debt(200)
	assert_eq(paid_final, 200, "Devono essere stati saldati gli ultimi 200 FLUX")
	assert_eq(bp.get_rent_debt(), 0, "Il debito di noleggio deve essere completamente estinto")
	assert_eq(bp.flux, 250, "Il saldo liquido residuo deve essere di 250 FLUX")

func test_ship_blueprint_session_persistence_and_reload() -> void:
	var bp := ShipBlueprint.new()
	bp.ship_id = "CORVETTE-PHASE-G"
	bp.ship_name = "Void Wanderer"
	bp.ship_class = "Corvette"
	bp.flux = 420
	bp.setup_default_freemium_debt()
	bp.repay_rent_debt(300) # Debito residuo: 400 FLUX, Saldo: 120 FLUX
	
	assert_eq(bp.flux, 120)
	assert_eq(bp.get_rent_debt(), 400)
	
	# 1. Serializzazione su disco
	var save_err := bp.save_blueprint_state(test_blueprint_path)
	assert_eq(save_err, OK, "Il salvataggio del blueprint deve restituire OK")
	assert_true(FileAccess.file_exists(test_blueprint_path), "Il file .tres deve esistere sul disco")
	
	# 2. Caricamento risorsa salvata
	var loaded_bp: Resource = ResourceLoader.load(test_blueprint_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	assert_not_null(loaded_bp, "Il file del blueprint salvato deve essere caricato con successo")
	assert_true(loaded_bp is ShipBlueprint, "La risorsa caricata deve essere un'istanza valida di ShipBlueprint")
	
	var reloaded := loaded_bp as ShipBlueprint
	assert_eq(reloaded.ship_id, "CORVETTE-PHASE-G", "L'identificativo nave deve essere preservato")
	assert_eq(reloaded.ship_name, "Void Wanderer", "Il nome nave deve essere preservato")
	assert_eq(reloaded.ship_class, "Corvette", "La classe nave deve essere preservata")
	assert_eq(reloaded.flux, 120, "Il saldo FLUX deve essere esattamente 120")
	assert_eq(reloaded.get_rent_debt(), 400, "Il debito residuo del noleggio deve rimanere 400 FLUX")

func test_station_hub_modular_debriefing_flow() -> void:
	var hub_scene: PackedScene = load("res://Applications/StationHub/station_hub_app.tscn")
	assert_not_null(hub_scene, "La scena di StationHubApp deve essere caricabile")
	
	var hub_app: Node = hub_scene.instantiate()
	add_child(hub_app)
	
	# 1. Setup mock DockingManager nello stato docked
	var dm := DockingManager.new()
	add_child(dm)
	dm.is_docked = true
	hub_app.bind_docking_manager(dm)
	hub_app._on_docking_completed("STATION-01", 0, {"name": "Test Station", "iff": "Neutrale"})
	
	# 2. Verifica presenza dei nuovi controlli modulari di debriefing
	var btn_sell_scav: Button = hub_app.get_node_or_null("%BtnSellAllScavenged")
	assert_not_null(btn_sell_scav, "Il pulsante BtnSellAllScavenged deve esistere nella scena")
	
	var btn_claim_all: Button = hub_app.get_node_or_null("%BtnClaimAllContracts")
	assert_not_null(btn_claim_all, "Il pulsante BtnClaimAllContracts deve esistere nella scena")
	
	var btn_save_state: Button = hub_app.get_node_or_null("%BtnSaveShipState")
	assert_not_null(btn_save_state, "Il pulsante BtnSaveShipState deve esistere nella scena")
	
	# 3. Configurazione blueprint nave
	var bp := ShipBlueprint.new()
	bp.ship_id = "CORVETTE-HUB-TEST"
	bp.flux = 600
	bp.setup_default_freemium_debt()
	hub_app.set_ship_blueprint(bp)
	
	# 4. Configurazione cargo con item scavenged
	var cargo_mgr: CargoManagerSingleton = hub_app.cargo_mgr
	if cargo_mgr == null:
		cargo_mgr = CargoManagerSingleton.new()
		hub_app.cargo_mgr = cargo_mgr
		add_child(cargo_mgr)
	cargo_mgr.clear_cargo()
	
	var scav_item := CargoItemData.new("derelict_avionics_core", "Nucleo Avionica", 2)
	scav_item.category = "WRECK_COMPONENT"
	scav_item.unit_base_value = 520.0
	scav_item.is_scavenged = true
	cargo_mgr.add_item(scav_item, 2)
	
	hub_app._refresh_cargo_market_view()
	assert_false(btn_sell_scav.disabled, "Il pulsante di vendita rapida bottino deve essere abilitato quando c'è bottino in stiva")
	
	# 5. Simulazione pressione pulsante vendita bottino
	hub_app._on_btn_sell_all_scavenged_pressed()
	assert_eq(cargo_mgr.get_scavenged_items().size(), 0, "Tutto il bottino di scavenging deve essere stato liquidato")
	assert_true(btn_sell_scav.disabled, "Dopo la liquidazione, il pulsante deve risultare disabilitato")
	
	# 6. Verifica pagamento discrezionale del noleggio nel tab Cantiere
	hub_app._refresh_shipyard_view()
	var rent_lbl: Label = hub_app.get_node_or_null("%RentStatusLabel")
	assert_not_null(rent_lbl, "L'etichetta del debito di noleggio deve esistere")
	assert_true("700 FLUX" in rent_lbl.text, "L'etichetta deve mostrare 700 FLUX di debito residuo")
	
	hub_app._on_pay_rent_100_pressed()
	assert_eq(bp.get_rent_debt(), 600, "Dopo il versamento della quota, il debito deve scendere a 600 FLUX")
	
	# 7. Verifica salvataggio persistente blueprint
	var saved: bool = hub_app._persist_active_blueprint()
	assert_true(saved, "_persist_active_blueprint deve salvare con successo il blueprint della nave")
	assert_true(FileAccess.file_exists("user://blueprints/active_corvette_session.tres"), "Il file persistente deve essere creato in user://")
	
	# Pulizia nodi
	dm.queue_free()
	hub_app.queue_free()
