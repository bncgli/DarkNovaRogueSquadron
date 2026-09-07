extends GutTest

## Test GUT per il Modulo Economia FLUX, Stiva Cargo ed S-Net.
## Migrato dal vecchio test manuale tests/test_flux_economy_cargo.gd che usava
## assert() nudo (fragile in --headless senza debugger). Ogni condizione è stata
## ri-validata contro il comportamento reale di Economy/cargo_manager.gd e
## Economy/flux_economy_manager.gd.

func test_cargo_mass_volume_and_inventory_calculation() -> void:
	var cargo_mgr := CargoManagerSingleton.new()
	add_child_autofree(cargo_mgr)
	cargo_mgr.clear_cargo()

	assert_eq(cargo_mgr.get_total_mass(), 0.0, "La massa iniziale dopo clear deve essere 0.0 kg")
	assert_eq(cargo_mgr.get_total_volume(), 0.0, "Il volume iniziale dopo clear deve essere 0.0 m³")
	assert_eq(cargo_mgr.max_mass_kg, 2000.0, "Capacità massima di massa deve essere 2000.0 kg")
	assert_eq(cargo_mgr.max_volume_m3, 100.0, "Capacità volumetrica deve essere 100.0 m³")

	# Aggiungi 10 celle energetiche (10 kg ciascuna = 100 kg, 0.3 m³ ciascuna = 3.0 m³)
	var ok_add := cargo_mgr.add_item_by_id("energy_cell", 10)
	assert_true(ok_add, "Aggiunta di 10 celle energetiche deve avere successo")
	assert_eq(cargo_mgr.get_total_mass(), 100.0, "Massa totale deve essere 100.0 kg")
	assert_almost_eq(cargo_mgr.get_total_volume(), 3.0, 0.001, "Volume totale deve essere 3.0 m³")
	assert_true(cargo_mgr.has_item("energy_cell", 10), "has_item('energy_cell', 10) deve restituire true")

	# Aggiungi 5 lingotti durasteel (40 kg ciascuno = 200 kg, 0.5 m³ ciascuno = 2.5 m³)
	cargo_mgr.add_item_by_id("alloys_durasteel", 5)
	assert_eq(cargo_mgr.get_total_mass(), 300.0, "Massa totale dopo durasteel deve essere 300.0 kg")
	assert_almost_eq(cargo_mgr.get_total_volume(), 5.5, 0.001, "Volume totale deve essere 5.5 m³")

	# Rimozione parziale
	var removed: CargoItemData = cargo_mgr.remove_item("alloys_durasteel", 2)
	assert_eq(removed.quantity, 2, "Devono essere state rimosse 2 unità di durasteel")
	assert_eq(cargo_mgr.get_total_mass(), 220.0, "Massa totale dopo rimozione 2 durasteel (80 kg) deve essere 220.0 kg")

func test_cargo_overload_prevention_mass_and_volume() -> void:
	var cargo_mgr := CargoManagerSingleton.new()
	add_child_autofree(cargo_mgr)
	cargo_mgr.clear_cargo()
	cargo_mgr.add_item_by_id("energy_cell", 10)
	cargo_mgr.add_item_by_id("alloys_durasteel", 5)
	cargo_mgr.remove_item("alloys_durasteel", 2) # Massa 220 kg, Volume 4.5 m³

	var overload_state := {
		"received": false,
		"reason": ""
	}
	cargo_mgr.overload_prevented.connect(func(_item: Variant, _qty: int, reason: String) -> void:
		overload_state["received"] = true
		overload_state["reason"] = reason
	)

	# Tentativo di inserire un carico eccedente 2000 kg -> RIFIUTATO
	var heavy_item := {
		"id": "super_heavy_crate",
		"name": "Cassa Superpesante",
		"unit_mass_kg": 2500.0,
		"unit_volume_m3": 10.0
	}
	var add_heavy_res := cargo_mgr.add_item(heavy_item, 1)
	assert_false(add_heavy_res, "L'inserimento di un carico eccedente 2000 kg deve essere RIFIUTATO")
	assert_true(overload_state["received"], "Il segnale overload_prevented deve essere emesso")
	assert_eq(cargo_mgr.get_total_mass(), 220.0, "La massa della stiva non deve subire variazioni dopo il blocco")

	# Tentativo di inserire carico con volume eccessivo (> 100 m³) -> RIFIUTATO
	overload_state["received"] = false
	var bulky_item := {
		"id": "bulky_gas_tank",
		"name": "Serbatoio Gas Rado",
		"unit_mass_kg": 10.0,
		"unit_volume_m3": 150.0
	}
	var add_bulky_res := cargo_mgr.add_item(bulky_item, 1)
	assert_false(add_bulky_res, "L'inserimento con volume > 100 m³ deve essere RIFIUTATO")
	assert_true(overload_state["received"], "Il segnale overload_prevented per volume deve essere emesso")

func test_cargo_transfer_ship_drone_and_station() -> void:
	var cargo_mgr := CargoManagerSingleton.new()
	add_child_autofree(cargo_mgr)
	cargo_mgr.clear_cargo()
	cargo_mgr.add_item_by_id("energy_cell", 10)

	var drone := ServiceDroneEntity.new()
	add_child_autofree(drone)
	drone.cargo_capacity_kg = 500.0
	drone.clear_cargo()

	# Trasferimento da Corvetta a Service Drone
	assert_true(cargo_mgr.has_item("energy_cell", 4), "La nave ha le celle energetiche")
	var xfer_to_drone_ok := cargo_mgr.transfer_to_drone("energy_cell", 4, drone)
	assert_true(xfer_to_drone_ok, "Trasferimento a Service Drone deve riuscire")
	assert_eq(drone.cargo_weight_kg, 40.0, "Il drone deve ora contenere 40.0 kg di carico")
	assert_false(cargo_mgr.has_item("energy_cell", 7), "Le 4 celle devono essere state rimosse dalla nave (rimaste 6)")

	# Trasferimento inverso da Service Drone a Corvetta
	var xfer_from_drone_ok := cargo_mgr.transfer_from_drone("energy_cell", 4, drone)
	assert_true(xfer_from_drone_ok, "Trasferimento dal Service Drone alla Corvetta deve riuscire")
	assert_eq(drone.cargo_weight_kg, 0.0, "Il carico del drone deve essere tornato a 0.0 kg")
	assert_true(cargo_mgr.has_item("energy_cell", 10), "Le celle devono essere tornate a 10 nella stiva della nave")

	# Trasferimento con Stazione Spaziale
	var station := SpaceStationEntity.new()
	add_child_autofree(station)
	station.warehouse_cargo.clear()

	var xfer_to_sttn := cargo_mgr.transfer_to_station("energy_cell", 3, station)
	assert_true(xfer_to_sttn, "Trasferimento a magazzino stazione deve riuscire")
	assert_eq(station.warehouse_cargo.size(), 1, "La stazione deve avere 1 lotto registrato nel magazzino")

	var xfer_from_sttn := cargo_mgr.transfer_from_station("energy_cell", 3, station)
	assert_true(xfer_from_sttn, "Prelievo dal magazzino stazione deve riuscire")
	assert_eq(station.warehouse_cargo.size(), 0, "Il lotto deve essere prelevato dalla stazione")

func test_flux_rating_scale_and_port_discounts() -> void:
	var flux_mgr := FluxEconomyManagerSingleton.new()
	add_child_autofree(flux_mgr)

	# Punteggio iniziale 720.0 -> Rating B
	assert_eq(flux_mgr.get_rating_letter(), "B", "Rating iniziale 720 deve essere B")
	assert_eq(flux_mgr.get_port_discount_multiplier(), 1.0, "Rating B deve avere moltiplicatore 1.0 (tariffa standard)")

	# Innalzamento punteggio a Rating A
	flux_mgr.adjust_flux_score(60.0, "Volume commerciale elevato")
	assert_eq(flux_mgr.flux_score, 780.0, "Punteggio deve essere 780.0")
	assert_eq(flux_mgr.get_rating_letter(), "A", "780.0 punti corrisponde a Rating A")
	assert_eq(flux_mgr.get_port_discount_multiplier(), 0.90, "Rating A garantisce 10% di sconto portuale (0.90)")

	# Innalzamento punteggio a Rating S
	flux_mgr.adjust_flux_score(150.0, "Liquidità e transazioni prestigiose")
	assert_eq(flux_mgr.flux_score, 930.0, "Punteggio deve essere 930.0")
	assert_eq(flux_mgr.get_rating_letter(), "S", "930.0 punti corrisponde a Rating S")
	assert_eq(flux_mgr.get_port_discount_multiplier(), 0.80, "Rating S garantisce 20% di sconto portuale (0.80)")

func test_flux_insolvency_penalty_and_impound_sequence() -> void:
	var flux_mgr := FluxEconomyManagerSingleton.new()
	add_child_autofree(flux_mgr)

	var flags := {
		"penalty": false,
		"os_lockout": false,
		"impound_warn": false,
		"impound_exec": false
	}
	flux_mgr.penalty_issued.connect(func(_type: String, _data: Dictionary) -> void:
		flags["penalty"] = true
	)
	flux_mgr.os_feature_disabled.connect(func(_feat: String) -> void:
		flags["os_lockout"] = true
	)
	flux_mgr.impound_warning_issued.connect(func(_t: float, _debt: float) -> void:
		flags["impound_warn"] = true
	)
	flux_mgr.impound_executed.connect(func() -> void:
		flags["impound_exec"] = true
	)

	# Crollo del credit score a stato di insolvenza (< 300.0 / Rating F)
	flux_mgr.adjust_flux_score(-490.0, "Mancato pagamento canoni e sanzioni")
	assert_eq(flux_mgr.flux_score, 230.0, "Score deve essere 230.0")
	assert_eq(flux_mgr.get_rating_letter(), "F", "Score < 300 deve risultare in Rating F (Insolvente)")
	assert_true(flux_mgr.is_insolvent(), "is_insolvent() deve restituire true")
	assert_eq(flux_mgr.get_port_discount_multiplier(), 1.35, "Insolvente comporta sovraccosto +35% (1.35)")
	assert_true(flags["penalty"], "Deve essere emesso evento di penalità per rating insolvente")
	assert_true(flags["os_lockout"], "Le feature OS devono essere disabilitate da remoto")
	assert_gt(flux_mgr.disabled_os_features.size(), 0, "Lista feature disabilitate non vuota")

	# Verifica allerta sequestro (Impound risk processing)
	flux_mgr._process(1.0)
	assert_true(flags["impound_warn"], "L'allerta sequestro deve essere emessa")
	assert_true(flux_mgr.is_impound_warning_active, "Allerta impound attiva")

	# Simula decorso del tempo di impound e Game Over
	flux_mgr._process(150.0)
	assert_true(flags["impound_exec"], "Allo scadere del timer deve essere scattato l'impound della nave")
	assert_true(flux_mgr.is_corvette_impounded, "Nave in stato sequestrato")

func test_flux_snet_ice_hack_and_credit_injection() -> void:
	var flux_mgr := FluxEconomyManagerSingleton.new()
	add_child_autofree(flux_mgr)

	var snet_disk := {
		"id": "snet_courier_disk_omega",
		"name": "Array Dati Corrente Subspazio S-Net",
		"category": "SNET_DISK",
		"is_snet_disk": true,
		"unit_mass_kg": 5.0,
		"unit_volume_m3": 0.1,
		"metadata": {
			"ice_strength": 3,
			"ice_broken": false,
			"sector": "Theta-9 Outpost",
			"financial_snapshot": 3500,
			"market_intel": "Speculazione sui prezzi del combustibile al plasma nel settore."
		}
	}

	var signal_state := { "breached": false }
	flux_mgr.snet_ice_breached.connect(func(_disk: Dictionary, _intel: Dictionary) -> void:
		signal_state["breached"] = true
	)

	var initial_credits: int = flux_mgr.credits
	# hacker_skill >= 3.0 garantisce il successo (bypass del roll casuale)
	var hack_result := flux_mgr.hack_snet_disk(snet_disk, 3.5)

	assert_true(hack_result.get("success"), "La violazione ICE con hacker skill deve avere successo")
	assert_true(snet_disk["metadata"]["ice_broken"], "Il disco deve risultare decrittato")
	assert_true(signal_state["breached"], "Il segnale snet_ice_breached deve essere emesso")
	assert_eq(flux_mgr.credits, initial_credits + 3500, "I crediti estratti dallo snapshot (+3500 CR) devono essere iniettati")

func test_cargo_bay_app_ui_and_app_resource_integrity() -> void:
	var app_scene_res: PackedScene = load("res://Applications/CargoBay/cargo_bay_app.tscn")
	assert_not_null(app_scene_res, "La scena cargo_bay_app.tscn deve essere caricata con successo")

	var cargo_app: CargoBayApp = app_scene_res.instantiate() as CargoBayApp
	assert_not_null(cargo_app, "CargoBayApp deve essere istanziabile")
	add_child_autofree(cargo_app)
	await get_tree().process_frame

	assert_not_null(cargo_app.mass_progress_bar, "mass_progress_bar presente")
	assert_not_null(cargo_app.vol_progress_bar, "vol_progress_bar presente")
	assert_not_null(cargo_app.mass_status_label, "mass_status_label presente")
	assert_not_null(cargo_app.vol_status_label, "vol_status_label presente")
	assert_not_null(cargo_app.cargo_item_list, "cargo_item_list presente")
	assert_not_null(cargo_app.item_details_label, "item_details_label presente")
	assert_not_null(cargo_app.btn_jettison, "btn_jettison presente")

	# Test interazione: selezione elemento ed espulsione
	assert_gt(cargo_app.cargo_item_list.item_count, 0, "La lista deve contenere elementi di stiva")
	cargo_app._on_cargo_item_selected(0)
	assert_false(cargo_app.item_details_label.text.is_empty(), "I dettagli dell'elemento devono essere mostrati")

	var initial_item_count: int = cargo_app.cargo_mgr.get_cargo_list().size()
	var initial_qty: int = cargo_app.cargo_mgr.get_cargo_list()[0].quantity
	cargo_app._on_jettison_pressed()

	var post_qty: int = cargo_app.cargo_mgr.get_item_quantity(cargo_app.cargo_mgr.get_cargo_list()[0].id) if cargo_app.cargo_mgr.get_cargo_list().size() > 0 else 0
	var jettison_ok := post_qty == initial_qty - 1 or cargo_app.cargo_mgr.get_cargo_list().size() == initial_item_count - 1
	assert_true(jettison_ok, "L'espulsione deve decrementare la quantità dell'oggetto selezionato")

	# Verifica risorsa AppResource
	var app_tres := load("res://Applications/CargoBay/cargo_bay_app.tres") as AppResource
	assert_not_null(app_tres, "La risorsa cargo_bay_app.tres deve essere caricata")
	assert_eq(app_tres.app_id, "cargo_bay", "app_id deve essere 'cargo_bay'")
	assert_eq(app_tres.default_password, "CARG-7815", "Password di debug deve essere CARG-7815")
