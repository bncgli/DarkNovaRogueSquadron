extends Node

## Test Runner Headless per Modulo Economia FLUX, Stiva Cargo ed S-Net
## Verifica tutti i criteri di accettazione specificati in task_queue/08_flux_economy_cargo.md

func _ready() -> void:
	print("\n=======================================================")
	print(">>> AVVIO SUITE DI TEST HEADLESS: FLUX ECONOMY & CARGO BAY")
	print("=======================================================\n")
	_run_all_tests()

func _run_all_tests() -> void:
	await get_tree().process_frame
	
	# =========================================================================
	# TEST 1: CARGO BAY - CALCOLO MASSA, VOLUME E INVENTARIO
	# =========================================================================
	print("--- TEST 1: CargoManager - Calcolo Massa, Volume e Inventario ---")
	var cargo_mgr := CargoManagerSingleton.new()
	add_child(cargo_mgr)
	await get_tree().process_frame
	
	cargo_mgr.clear_cargo()
	assert(cargo_mgr.get_total_mass() == 0.0, "La massa iniziale dopo clear deve essere 0.0 kg")
	assert(cargo_mgr.get_total_volume() == 0.0, "Il volume iniziale dopo clear deve essere 0.0 m³")
	assert(cargo_mgr.max_mass_kg == 2000.0, "Capacità massima di massa deve essere 2000.0 kg")
	assert(cargo_mgr.max_volume_m3 == 100.0, "Capacità volumetrica deve essere 100.0 m³")
	
	# Aggiungi 10 celle energetiche (10 kg ciascuna = 100 kg, 0.3 m³ ciascuna = 3.0 m³)
	var ok_add := cargo_mgr.add_item_by_id("energy_cell", 10)
	assert(ok_add == true, "Aggiunta di 10 celle energetiche deve avere successo")
	assert(cargo_mgr.get_total_mass() == 100.0, "Massa totale deve essere 100.0 kg (trovato: %s)" % cargo_mgr.get_total_mass())
	assert(is_equal_approx(cargo_mgr.get_total_volume(), 3.0), "Volume totale deve essere 3.0 m³ (trovato: %s)" % cargo_mgr.get_total_volume())
	assert(cargo_mgr.has_item("energy_cell", 10) == true, "has_item('energy_cell', 10) deve restituire true")
	
	# Aggiungi 5 lingotti durasteel (40 kg ciascuno = 200 kg, 0.5 m³ ciascuno = 2.5 m³)
	cargo_mgr.add_item_by_id("alloys_durasteel", 5)
	assert(cargo_mgr.get_total_mass() == 300.0, "Massa totale dopo durasteel deve essere 300.0 kg")
	assert(is_equal_approx(cargo_mgr.get_total_volume(), 5.5), "Volume totale deve essere 5.5 m³")
	
	# Rimozione parziale
	var removed := cargo_mgr.remove_item("alloys_durasteel", 2)
	assert(removed.get("quantity") == 2, "Devono essere state rimosse 2 unità di durasteel")
	assert(cargo_mgr.get_total_mass() == 220.0, "Massa totale dopo rimozione 2 durasteel (80 kg) deve essere 220.0 kg")
	print("✔ Calcolo di massa, volume e inventario verificato con successo")
	
	# =========================================================================
	# TEST 2: CARGO BAY - PREVENZIONE E BLOCCO SOVRACCARICO (MASS & VOLUME)
	# =========================================================================
	print("\n--- TEST 2: CargoManager - Blocco Sovraccarico di Massa e Volume ---")
	var overload_state := {
		"received": false,
		"reason": ""
	}
	
	cargo_mgr.overload_prevented.connect(func(_item: Variant, _qty: int, reason: String) -> void:
		overload_state["received"] = true
		overload_state["reason"] = reason
	)
	
	# Tentativo di inserire 100 lingotti durasteel (4000 kg > limite 2000 kg)
	var heavy_item := {
		"id": "super_heavy_crate",
		"name": "Cassa Superpesante",
		"unit_mass_kg": 2500.0,
		"unit_volume_m3": 10.0
	}
	var add_heavy_res := cargo_mgr.add_item(heavy_item, 1)
	assert(add_heavy_res == false, "L'inserimento di un carico eccedente 2000 kg deve essere RIFIUTATO")
	assert(overload_state["received"] == true, "Il segnale overload_prevented deve essere emesso")
	assert(cargo_mgr.get_total_mass() == 220.0, "La massa della stiva non deve subire variazioni dopo il blocco")
	
	# Tentativo di inserire carico con volume eccessivo (> 100 m³)
	overload_state["received"] = false
	var bulky_item := {
		"id": "bulky_gas_tank",
		"name": "Serbatoio Gas Rado",
		"unit_mass_kg": 10.0,
		"unit_volume_m3": 150.0
	}
	var add_bulky_res := cargo_mgr.add_item(bulky_item, 1)
	assert(add_bulky_res == false, "L'inserimento con volume > 100 m³ deve essere RIFIUTATO")
	assert(overload_state["received"] == true, "Il segnale overload_prevented per volume deve essere emesso")
	
	print("✔ Prevenzione e blocco del sovraccarico validati con successo")
	
	# =========================================================================
	# TEST 3: TRASFERIMENTO BIDIREZIONALE (NAVE <-> SERVICE DRONE <-> STAZIONE)
	# =========================================================================
	print("\n--- TEST 3: Trasferimento Merci con Service Drone e Stazione ---")
	var drone := ServiceDroneEntity.new()
	add_child(drone)
	drone.cargo_capacity_kg = 500.0
	drone.clear_cargo()
	
	# Trasferimento da Corvetta a Service Drone
	assert(cargo_mgr.has_item("energy_cell", 4) == true, "La nave ha le celle energetiche")
	var xfer_to_drone_ok := cargo_mgr.transfer_to_drone("energy_cell", 4, drone)
	assert(xfer_to_drone_ok == true, "Trasferimento a Service Drone deve riuscire")
	assert(drone.cargo_weight_kg == 40.0, "Il drone deve ora contenere 40.0 kg di carico (trovato: %s)" % drone.cargo_weight_kg)
	assert(cargo_mgr.has_item("energy_cell", 7) == false, "Le 4 celle devono essere state rimosse dalla nave (rimaste 6)")
	
	# Trasferimento inverso da Service Drone a Corvetta
	var xfer_from_drone_ok := cargo_mgr.transfer_from_drone("energy_cell", 4, drone)
	assert(xfer_from_drone_ok == true, "Trasferimento dal Service Drone alla Corvetta deve riuscire")
	assert(drone.cargo_weight_kg == 0.0, "Il carico del drone deve essere tornato a 0.0 kg")
	assert(cargo_mgr.has_item("energy_cell", 10) == true, "Le celle devono essere tornate a 10 nella stiva della nave")
	
	# Trasferimento con Stazione Spaziale
	var station := SpaceStationEntity.new()
	add_child(station)
	station.warehouse_cargo.clear()
	
	var xfer_to_sttn := cargo_mgr.transfer_to_station("energy_cell", 3, station)
	assert(xfer_to_sttn == true, "Trasferimento a magazzino stazione deve riuscire")
	assert(station.warehouse_cargo.size() == 1, "La stazione deve avere 1 lotto registrato nel magazzino")
	
	var xfer_from_sttn := cargo_mgr.transfer_from_station("energy_cell", 3, station)
	assert(xfer_from_sttn == true, "Prelievo dal magazzino stazione deve riuscire")
	assert(station.warehouse_cargo.size() == 0, "Il lotto deve essere prelevato dalla stazione")
	print("✔ Trasferimento bidirezionale Nave-Drone-Stazione verificato con successo")
	
	# =========================================================================
	# TEST 4: FLUX ECONOMY - RATING CREDITIZIO DINAMICO, SCONTI E CANONI
	# =========================================================================
	print("\n--- TEST 4: FluxEconomyManager - Rating Dinamico, Sconti e Canoni ---")
	var flux_mgr := FluxEconomyManagerSingleton.new()
	add_child(flux_mgr)
	await get_tree().process_frame
	
	# Punteggio iniziale 720.0 -> Rating B
	assert(flux_mgr.get_rating_letter() == "B", "Rating iniziale 720 deve essere B")
	assert(flux_mgr.get_port_discount_multiplier() == 1.0, "Rating B deve avere moltiplicatore 1.0 (tariffa standard)")
	
	# Innalzamento punteggio a Rating A e Rating S
	flux_mgr.adjust_flux_score(60.0, "Volume commerciale elevato")
	assert(flux_mgr.flux_score == 780.0, "Punteggio deve essere 780.0")
	assert(flux_mgr.get_rating_letter() == "A", "780.0 punti corrisponde a Rating A")
	assert(flux_mgr.get_port_discount_multiplier() == 0.90, "Rating A garantisce 10% di sconto portuale (0.90)")
	
	flux_mgr.adjust_flux_score(150.0, "Liquidità e transazioni prestigiose")
	assert(flux_mgr.flux_score == 930.0, "Punteggio deve essere 930.0")
	assert(flux_mgr.get_rating_letter() == "S", "930.0 punti corrisponde a Rating S")
	assert(flux_mgr.get_port_discount_multiplier() == 0.80, "Rating S garantisce 20% di sconto portuale (0.80)")
	print("✔ Scala di rating FLUX e calcolo sconti portuali convalidati")
	
	# =========================================================================
	# TEST 5: INSOLVENZA, PENALITÀ OS E ALLERTA SEQUESTRO (IMPOUND)
	# =========================================================================
	print("\n--- TEST 5: Insolvenza, Disattivazione Remota OS e Allerta Sequestro ---")
	var flags := {
		"penalty": false,
		"os_lockout": false,
		"impound_warn": false,
		"impound_exec": false,
		"snet_breached": false
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
	flux_mgr.adjust_flux_score(-700.0, "Mancato pagamento canoni e sanzioni")
	assert(flux_mgr.flux_score == 230.0, "Score deve essere 230.0")
	assert(flux_mgr.get_rating_letter() == "F", "Score < 300 deve risultare in Rating F (Insolvente)")
	assert(flux_mgr.is_insolvent() == true, "is_insolvent() deve restituire true")
	assert(flux_mgr.get_port_discount_multiplier() == 1.35, "Insolvente comporta sovraccosto +35% (1.35)")
	assert(flags["penalty"] == true, "Deve essere emesso evento di penalità per rating insolvente")
	assert(flags["os_lockout"] == true, "Le feature OS devono essere disabilitate da remoto")
	assert(flux_mgr.disabled_os_features.size() > 0, "Lista feature disabilitate non vuota")
	
	# Verifica allerta sequestro (Impound risk processing)
	flux_mgr._process(1.0)
	assert(flags["impound_warn"] == true, "L'allerta sequestro deve essere emessa")
	assert(flux_mgr.is_impound_warning_active == true, "Allerta impound attiva")
	
	# Simula decorso del tempo di impound e Game Over
	flux_mgr._process(150.0)
	assert(flags["impound_exec"] == true, "Allo scadere del timer deve essere scattato l'impound della nave")
	assert(flux_mgr.is_corvette_impounded == true, "Nave in stato sequestrato")
	print("✔ Gestione insolvenza, disattivazione remota moduli e sequenza impound convalidate")
	
	# =========================================================================
	# TEST 6: MECCANICA HACKER - ARRAY SNAPSHOT S-NET E VIOLAZIONE BARRIERE ICE
	# =========================================================================
	print("\n--- TEST 6: S-Net Snapshot e Violazione ICE Hacker ---")
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
	
	flux_mgr.snet_ice_breached.connect(func(_disk: Dictionary, _intel: Dictionary) -> void:
		flags["snet_breached"] = true
	)
	
	var initial_credits: int = flux_mgr.credits
	var hack_result := flux_mgr.hack_snet_disk(snet_disk, 3.5) # Hacker abile
	
	assert(hack_result.get("success") == true, "La violazione ICE con hacker skill deve avere successo")
	assert(snet_disk["metadata"]["ice_broken"] == true, "Il disco deve risultare decrittato")
	assert(flags["snet_breached"] == true, "Il segnale snet_ice_breached deve essere emesso")
	assert(flux_mgr.credits == initial_credits + 3500, "I crediti estratti dallo snapshot (+3500 CR) devono essere iniettati")
	print("✔ Meccanica Hacker violazione ICE ed estrazione dati finanziari S-Net verificata")
	
	# =========================================================================
	# TEST 7: CARGO BAY APP UI & APP RESOURCE INTEGRITY
	# =========================================================================
	print("\n--- TEST 7: Integrazione Scena UI CargoBayApp e AppResource ---")
	var app_scene_res: PackedScene = load("res://Applications/CargoBay/cargo_bay_app.tscn")
	assert(app_scene_res != null, "La scena cargo_bay_app.tscn deve essere caricata con successo")
	
	var cargo_app: CargoBayApp = app_scene_res.instantiate() as CargoBayApp
	assert(cargo_app != null, "CargoBayApp deve essere istanziabile")
	add_child(cargo_app)
	await get_tree().process_frame
	
	assert(cargo_app.mass_progress_bar != null, "mass_progress_bar presente")
	assert(cargo_app.vol_progress_bar != null, "vol_progress_bar presente")
	assert(cargo_app.cargo_item_list != null, "cargo_item_list presente")
	assert(cargo_app.flux_score_bar != null, "flux_score_bar presente")
	assert(cargo_app.subscriptions_item_list != null, "subscriptions_item_list presente")
	assert(cargo_app.snet_disk_list != null, "snet_disk_list presente")
	assert(cargo_app.btn_hack_ice != null, "btn_hack_ice presente")
	
	# Verifica risorsa AppResource
	var app_tres := load("res://Applications/CargoBay/cargo_bay_app.tres") as AppResource
	assert(app_tres != null, "La risorsa cargo_bay_app.tres deve essere caricata")
	assert(app_tres.app_id == "cargo_bay", "app_id deve essere 'cargo_bay'")
	assert(app_tres.default_password == "CARG-7815", "Password di debug deve essere CARG-7815")
	print("✔ UI CargoBayApp e configurazione AppResource verificate con successo")
	
	print("\n=======================================================")
	print("=== TUTTI I TEST FLUX ECONOMY & CARGO BAY COMPLETATI CON SUCCESSO! ===")
	print("=======================================================\n")
	get_tree().quit(0)
