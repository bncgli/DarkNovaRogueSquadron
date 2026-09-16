extends GutTest

## Suite di Collaudo Automatizzata per la Riscrittura della Flux Economy
## e il Modello a Baratto Titoli di Debito/Credito Corporativo.

var flux_mgr: FluxEconomyManagerSingleton = null
var blueprint: ShipBlueprint = null

func before_each() -> void:
	blueprint = ShipBlueprint.new()
	blueprint.ship_id = "CORVETTE-TEST-FLUX"
	blueprint.ship_name = "Void Barter"
	blueprint.flux = 300
	blueprint.setup_default_freemium_debt() # -700 FLUX "Ship Rent Service"
	
	flux_mgr = FluxEconomyManagerSingleton.new()
	add_child_autofree(flux_mgr)
	flux_mgr.set_active_blueprint(blueprint)
	flux_mgr.flux_score = 720.0

func after_each() -> void:
	blueprint = null

# ==============================================================================
# SCENARIO 1: SALDO NETTO E TRANCHE DI DEBITO
# ==============================================================================
func test_net_flux_and_debt_tranches_accounting() -> void:
	# Verifica saldo iniziale: 300 liquido, -700 debito noleggio
	assert_eq(flux_mgr.get_liquid_flux(), 300, "La liquidità iniziale deve essere di 300 FLUX")
	assert_eq(flux_mgr.get_total_debt(), 700, "Il debito complessivo passivo deve essere di 700 FLUX")
	assert_eq(flux_mgr.get_net_flux(), -400, "Il saldo netto contabile deve essere 300 - 700 = -400 FLUX")
	assert_eq(flux_mgr.get_rating_letter(), "B", "Il rating con 720 punti deve essere B")
	
	# Aggiunta di un titolo di credito attivo (+200 FLUX Titolo Minerario Titan-Alpha)
	var credit_title := flux_mgr.issue_credit_title("Titan Mining Consortium", "Buono minerario raffinazione", 200)
	assert_not_null(credit_title, "Il titolo di credito deve essere emesso con successo")
	assert_eq(credit_title.value, 200, "Il valore del titolo deve essere +200")
	assert_eq(flux_mgr.get_total_credit_titles(), 200, "Il totale crediti attivi deve salire a 200")
	assert_eq(flux_mgr.get_net_flux(), -200, "Il saldo netto contabile deve salire a -200 FLUX (-400 + 200)")
	
	# Verifica liste differenziate
	var debts := flux_mgr.get_debt_tranches()
	assert_eq(debts.size(), 1, "Deve essere presente una tranche di debito")
	assert_eq(debts[0].owner, "Ship Rent Service")
	
	var credits := flux_mgr.get_credit_titles()
	assert_eq(credits.size(), 1, "Deve essere presente un titolo di credito")
	assert_eq(credits[0].owner, "Titan Mining Consortium")

# ==============================================================================
# SCENARIO 2: TRANSAZIONE CON BARATTO ED EMISSIONE NUOVO DEBITO
# ==============================================================================
func test_barter_purchase_with_debt_issuance() -> void:
	# Setup: 100 FLUX liquidi e rating B
	blueprint.flux = 100
	var initial_debt := flux_mgr.get_total_debt()
	assert_eq(initial_debt, 700)
	
	# Costo fornitura cantiere: 250 FLUX
	var cost := 250
	assert_true(flux_mgr.can_afford(cost, true), "Con fido consentito e rating B, la nave può indebitarsi")
	
	# Esecuzione baratto: 100 liquidi offerti, residuo 150 a debito verso la stazione
	var summary := flux_mgr.barter_transaction(cost, 100, [], true, "Aegis Shipyard Repairs")
	assert_true(summary.get("success", false), "La transazione a baratto con emissione debito deve riuscire")
	assert_eq(summary.get("paid_liquid", 0), 100, "I 100 FLUX liquidi devono essere stati interamente versati")
	assert_eq(summary.get("debts_issued", 0), 150, "Deve essere stata emessa una nuova quota di debito da 150 FLUX")
	
	# Verifica stato risultante
	assert_eq(flux_mgr.get_liquid_flux(), 0, "La liquidità deve essere scesa a 0 FLUX")
	assert_eq(flux_mgr.get_total_debt(), 850, "Il debito totale deve essere salito a 700 + 150 = 850 FLUX")
	assert_eq(flux_mgr.get_net_flux(), -850, "Il saldo netto contabile deve essere -850 FLUX")
	
	# Verifica presenza del nuovo modificatore intestato alla stazione
	var debts := flux_mgr.get_debt_tranches()
	assert_eq(debts.size(), 2, "Devono essere presenti 2 tranche di debito")
	var found_station_debt := false
	for d in debts:
		if d.owner == "Aegis Shipyard Repairs" and d.value == -150:
			found_station_debt = true
			break
	assert_true(found_station_debt, "La tranche di debito verso Aegis Shipyard Repairs deve essere registrata nello scafo")

# ==============================================================================
# SCENARIO 3: RIMBORSO DEBITO TRAMITE LIQUIDAZIONE BOTTINO
# ==============================================================================
func test_debt_relief_from_salvage_liquidation() -> void:
	# Setup: Debito di 700 FLUX. Stiva con bottino per 400 FLUX.
	assert_eq(flux_mgr.get_total_debt(), 700)
	var cargo_mgr := CargoManagerSingleton.new()
	add_child_autofree(cargo_mgr)
	cargo_mgr.bind_flux_manager(flux_mgr)
	cargo_mgr.clear_cargo()
	
	var salvage_item := CargoItemData.new("derelict_avionics", "Avionica di Relitto", 2)
	salvage_item.category = "WRECK_COMPONENT"
	salvage_item.unit_base_value = 200.0
	salvage_item.is_scavenged = true
	cargo_mgr.add_item(salvage_item, 2)
	
	# Verifica stima bottino: 2 x 200 = 400 FLUX
	var val_est := cargo_mgr.calculate_scavenged_value()
	assert_eq(int(round(val_est.get("credits", 0.0))), 400)
	
	# Liquidazione con destinazione DEBT_RELIEF verso "Ship Rent Service"
	var liq_res := cargo_mgr.liquidate_scavenged_items(1.0, "DEBT_RELIEF", "Ship Rent Service")
	assert_eq(liq_res.get("liquidated_count", 0), 2, "Devono essere stati liquidati 2 pezzi")
	assert_eq(int(liq_res.get("debt_relief_applied", 0)), 400, "Devono essere stati applicati 400 FLUX di sgravio debito")
	
	# Verifica contabile
	assert_eq(flux_mgr.get_total_debt(), 300, "Il debito di noleggio residuo deve essere sceso da 700 a 300 FLUX")
	assert_eq(flux_mgr.get_net_flux(), 0, "Il saldo netto contabile deve essere salito da -400 a 0 FLUX (300 liq - 300 deb)")
	assert_eq(cargo_mgr.get_scavenged_items().size(), 0, "La stiva deve essere vuota")

# ==============================================================================
# SCENARIO 4: CONTRATTO FIXER A RICOMPENSA MISTA E SGRAVIO RATEALE
# ==============================================================================
func test_fixer_contract_flux_and_debt_relief_payout() -> void:
	var initial_liq := flux_mgr.get_liquid_flux() # 300
	var initial_debt := flux_mgr.get_total_debt() # 700
	
	var contract: Dictionary = {
		"id": "CNT_TEST_HYBRID",
		"title": "Bounty Speciale Fixer",
		"reward_liquid_flux": 500,
		"reward_debt_relief": 300,
		"creditor_relief_target": "Ship Rent Service",
		"status": "COMPLETED"
	}
	
	var payout := flux_mgr.receive_contract_reward(contract)
	assert_eq(payout.get("liquid_reward", 0), 500, "La ricompensa liquida deve essere 500 FLUX")
	assert_eq(payout.get("debt_relief_applied", 0), 300, "Lo sgravio debito deve essere 300 FLUX")
	
	assert_eq(flux_mgr.get_liquid_flux(), initial_liq + 500, "Il FLUX liquido deve essere salito a 800")
	assert_eq(flux_mgr.get_total_debt(), initial_debt - 300, "Il debito totale deve essere sceso a 400")
	assert_eq(flux_mgr.get_net_flux(), 400, "Il saldo netto contabile deve essere +400 (800 - 400)")

# ==============================================================================
# SCENARIO 5: BLOCCO INSOLVENZA RATING F E RISCHIO SEQUESTRO
# ==============================================================================
func test_insolvency_blocks_new_debt_and_triggers_impound_risk() -> void:
	# Abbassa il punteggio a 220 (Rating F - Insolvente)
	flux_mgr.flux_score = 220.0
	flux_mgr._update_rating_state()
	
	assert_eq(flux_mgr.get_rating_letter(), "F", "La lettera di rating deve essere F")
	assert_true(flux_mgr.is_insolvent(), "La nave deve essere in stato di insolvenza")
	assert_eq(flux_mgr.get_max_allowed_debt(), 0, "Il tetto di indebitamento per rating F deve essere 0")
	assert_gt(flux_mgr.disabled_os_features.size(), 0, "Funzionalità OS devono essere disabilitate da remoto")
	
	# Tentativo di acquistare a debito: deve essere respinto
	blueprint.flux = 50
	var can_debt := flux_mgr.can_afford(200, true)
	assert_false(can_debt, "Non deve essere concesso nuovo debito in stato insolvente")
	
	var barter_res := flux_mgr.barter_transaction(200, 50, [], true, "Aegis Shipyard Repairs")
	assert_false(barter_res.get("success", false), "Il baratto con emissione debito deve fallire per insolvenza")
	assert_true("Insolvente" in str(barter_res.get("reason", "")), "La causale deve indicare l'insolvenza")
	
	# Verifica timer rischio sequestro
	flux_mgr._process_impound_risk(1.0)
	assert_true(flux_mgr.is_impound_warning_active, "L'allarme rischio impound deve risultare attivo")
