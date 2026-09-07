extends GutTest

## Test GUT per il Modulo "Mining ed Estrazione Risorse (Asteroidi & Scavenging)".
## Migrato dal vecchio test manuale tests/test_mining_scavenging.gd che usava
## assert() nudo (fragile in --headless senza debugger). Ogni condizione è stata
## ri-validata contro il comportamento reale di Gameplay/Mining/mining_manager.gd,
## Outside/asteroid.gd, Outside/Mining/mineral_deposit_entity.gd ed
## Outside/Mining/derelict_ship_entity.gd.
##
## BUGFIX (produzione): DerelictShipEntity.scavenge_module_by_index/scavenge_all_available
## passavano i moduli a CargoManager.add_item() con le chiavi "mass_kg"/"volume_m3"/
## "value_credits", non riconosciute da CargoItemData.from_dict() (che si aspetta
## "unit_mass_kg"/"unit_volume_m3"/"unit_base_value"). I moduli recuperati finivano quindi
## in stiva con massa/volume/valore azzerati. Corretto introducendo _to_cargo_item_dict().

const AsteroidScript = preload("res://Outside/asteroid.gd")
const MineralDepositScript = preload("res://Outside/Mining/mineral_deposit_entity.gd")
const DerelictShipScript = preload("res://Outside/Mining/derelict_ship_entity.gd")
const MiningManagerScript = preload("res://Gameplay/Mining/mining_manager.gd")
const CargoManagerScript = preload("res://Economy/cargo_manager.gd")

func test_spectrometry_and_asteroid_state() -> void:
	var mining_mgr := MiningManagerScript.new()
	add_child_autofree(mining_mgr)

	var asteroid := AsteroidScript.new()
	asteroid.name = "Asteroid_Test_Alpha"
	add_child_autofree(asteroid)

	var scan_data: Dictionary = mining_mgr.perform_spectrometric_scan(asteroid)
	assert_true(scan_data.has("composition"), "Dati scansione devono contenere la composizione")
	assert_true(scan_data.has("purity_pct"), "Dati scansione devono contenere la percentuale di purezza")
	assert_eq(scan_data.get("health_pct"), 100, "La salute iniziale dell'asteroide deve essere 100%")
	assert_gte(scan_data.get("estimated_yield_fragments"), 3, "Resa frammenti stimata deve essere almeno 3")

func test_asteroid_damage_and_fragment_generation() -> void:
	var root_space := Node3D.new()
	add_child_autofree(root_space)

	var mining_mgr := MiningManagerScript.new()
	root_space.add_child(mining_mgr)

	var asteroid := AsteroidScript.new()
	asteroid.name = "Asteroid_Target"
	root_space.add_child(asteroid)

	var initial_state := mining_mgr.get_or_register_asteroid_state(asteroid)
	assert_eq(initial_state["health"], 200.0, "Salute iniziale asteroide = 200")
	assert_eq(initial_state["spawned_fragments"], 0, "Frammenti iniziali generati = 0")

	# Applica danno laser pari al 50%
	var fragments := mining_mgr.apply_mining_damage_to_asteroid(asteroid, 100.0, Vector3(0, 0, 5))
	assert_gt(fragments.size(), 0, "Danno minerario sufficiente deve rilasciare frammenti fisici")
	assert_eq(initial_state["health"], 100.0, "Salute dopo danno deve essere 100")

	# Verifica proprietà del primo frammento generato
	var first_frag: Variant = fragments[0]
	assert_not_null(first_frag, "Il frammento deve essere un MineralDepositEntity valido")
	assert_gt(first_frag.mass_kg, 0.0, "Il frammento deve avere una massa valida")
	assert_eq(first_frag.resource_type, initial_state["resource_type"], "Tipo risorsa frammento coerente con asteroide")

	# Completa distruzione/frantumazione
	mining_mgr.apply_mining_damage_to_asteroid(asteroid, 100.0, Vector3(0, 0, 5))
	assert_eq(initial_state["health"], 0.0, "Salute asteroide esaurita = 0")
	assert_eq(initial_state["spawned_fragments"], initial_state["total_fragments"], "Tutti i frammenti previsti sono stati estratti")

func test_mineral_deposit_collection_and_cargo_storage() -> void:
	var cargo_mgr := CargoManagerScript.new()
	add_child_autofree(cargo_mgr)
	cargo_mgr.clear_cargo()

	var mining_mgr := MiningManagerScript.new()
	add_child_autofree(mining_mgr)

	var deposit := MineralDepositScript.new()
	deposit.deposit_id = "water_ice_fragment_01"
	deposit.mineral_name = "Ghiaccio d'Acqua Minerale"
	deposit.resource_type = "water_ice"
	deposit.mass_kg = 20.0
	deposit.volume_m3 = 0.5
	deposit.purity = 0.9
	deposit.life_support_water_units = 15.0
	add_child_autofree(deposit)

	var res_dict: Dictionary = deposit.get_resource_dict()
	assert_eq(res_dict["type"], "MINERAL", "Tipo risorsa deve essere MINERAL")
	assert_eq(res_dict["resource_sub_type"], "water_ice", "Sottotipo risorsa water_ice")

	# Cattura frammento e stivaggio
	var ok := mining_mgr.capture_deposit(deposit, null, cargo_mgr)
	assert_true(ok, "Cattura e inserimento in stiva riusciti")
	assert_true(cargo_mgr.has_item("water_ice_fragment_01", 1), "L'oggetto deve essere registrato nella stiva")
	assert_eq(cargo_mgr.get_total_mass(), 20.0, "Massa in stiva aggiornata a 20 kg")

	# Test attrazione magnetica
	var target_drone := Node3D.new()
	add_child_autofree(target_drone)
	target_drone.global_position = Vector3(10, 0, 0)

	var deposit2 := MineralDepositScript.new()
	add_child_autofree(deposit2)
	deposit2.global_position = Vector3(0, 0, 0)
	deposit2.start_magnetic_attraction(target_drone, 20.0)
	assert_true(deposit2.freeze, "RigidBody freeze attivo durante attrazione magnetica")
	deposit2.stop_magnetic_attraction()
	assert_false(deposit2.freeze, "RigidBody sbloccato dopo termine attrazione")

func test_derelict_laser_cutting_and_bulkhead() -> void:
	var derelict := DerelictShipScript.new()
	derelict.derelict_id = "derelict_beta_01"
	derelict.bulkhead_hp = 100.0
	derelict.bulkhead_intact = true
	add_child_autofree(derelict)

	var mining_mgr := MiningManagerScript.new()
	add_child_autofree(mining_mgr)

	# Taglio parziale
	var breached := mining_mgr.cut_derelict_bulkhead(derelict, 40.0)
	assert_false(breached, "Paratia non deve cedere con danno parziale")
	assert_eq(derelict.bulkhead_hp, 60.0, "HP paratia rimasti = 60")
	assert_true(derelict.bulkhead_intact, "Paratia ancora intatta")

	# Taglio definitivo
	breached = mining_mgr.cut_derelict_bulkhead(derelict, 60.0)
	assert_true(breached, "Paratia deve essere perforata")
	assert_false(derelict.bulkhead_intact, "bulkhead_intact deve essere false")
	assert_eq(derelict.bulkhead_hp, 0.0, "HP paratia = 0")

func test_derelict_ice_hacking_and_salvage() -> void:
	var derelict := DerelictShipScript.new()
	derelict.derelict_id = "derelict_gamma_02"
	derelict.ice_locked = true
	derelict.ice_security_level = 3
	derelict.bulkhead_intact = false # Già tagliata
	add_child_autofree(derelict)

	var cargo_mgr := CargoManagerScript.new()
	add_child_autofree(cargo_mgr)
	cargo_mgr.clear_cargo()

	var mining_mgr := MiningManagerScript.new()
	add_child_autofree(mining_mgr)

	# Tentativo di recupero prima dell'hacking ICE -> deve fallire
	var early_salvage := mining_mgr.scavenge_derelict_loot(derelict, cargo_mgr)
	assert_true(early_salvage.has("error") and early_salvage["error"] == "ICE_LOCKED", "Scavenging bloccato se ICE attivo")

	# Hacking con livello insufficiente (livello 1 vs sicurezza 3)
	var hack_fail := mining_mgr.hack_derelict_ice(derelict, 1)
	assert_false(hack_fail, "Hacking livello 1 deve fallire contro sicurezza 3")
	assert_true(derelict.ice_locked, "ICE deve rimanere attivo")

	# Hacking con livello 3 (pari alla sicurezza) -> successo
	var hack_ok := mining_mgr.hack_derelict_ice(derelict, 3)
	assert_true(hack_ok, "Hacking livello 3 deve avere successo")
	assert_false(derelict.ice_locked, "ICE deve essere disattivato")

	# Esecuzione scavenging completo
	var salvage_result := mining_mgr.scavenge_derelict_loot(derelict, cargo_mgr)
	assert_true(salvage_result.get("success"), "Scavenging deve avere esito positivo")
	assert_eq(salvage_result.get("credits_recovered"), 1200, "Crediti recuperati = 1200")
	assert_eq(salvage_result.get("flux_recovered"), 25.0, "FLUX recuperato = 25.0")
	assert_eq(salvage_result.get("modules_recovered").size(), 2, "2 Moduli avionici recuperati")
	assert_true(derelict.is_salvaged(), "Il relitto deve essere segnato come completamente spogliato")

	# BUGFIX: i moduli recuperati devono ora avere massa/volume/valore corretti in stiva
	# (prima della correzione, add_item() li scartava con massa/volume/valore azzerati)
	assert_true(cargo_mgr.has_item("avionics_core_mk2", 1), "Il modulo avionico deve essere registrato nella stiva")
	assert_true(cargo_mgr.has_item("nav_computer_subsystem", 1), "Il sottosistema di navigazione deve essere registrato nella stiva")
	assert_almost_eq(cargo_mgr.get_total_mass(), 65.0, 0.001, "Massa totale stiva (45 kg + 20 kg) deve essere 65 kg dopo il recupero moduli")

func test_derelict_duct_drone_infiltration() -> void:
	var derelict := DerelictShipScript.new()
	derelict.derelict_id = "derelict_delta_03"
	derelict.black_box_recovered = false
	add_child_autofree(derelict)

	var mining_mgr := MiningManagerScript.new()
	add_child_autofree(mining_mgr)

	var duct_result := mining_mgr.infiltrate_derelict_with_duct_drone(derelict, null)
	assert_true(duct_result.get("success"), "Infiltrazione condotti deve riuscire")
	assert_gt(duct_result.get("found_items").size(), 0, "Duct drone deve recuperare la scatola nera")
	assert_true(derelict.black_box_recovered, "Scatola nera contrassegnata come recuperata")
