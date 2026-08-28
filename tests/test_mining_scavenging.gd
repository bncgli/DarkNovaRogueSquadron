class_name TestMiningScavenging
extends Node

## Test Headless per Modulo "Mining ed Estrazione Risorse (Asteroidi & Scavenging)"
## Verifica:
## 1. Danneggiamento e generazione procedurale di frammenti minerari dagli asteroidi.
## 2. Riconoscimento del tipo di risorsa estratta e inserimento corretto in stiva.
## 3. Meccanica di violazione serrature/ICE sui relitti e raccolta moduli.
## 4. Spettrometria su sensori e integrazione taglio laser/harpoon drone.

const AsteroidScript = preload("res://Outside/asteroid.gd")
const MineralDepositScript = preload("res://Outside/Mining/mineral_deposit_entity.gd")
const DerelictShipScript = preload("res://Outside/Mining/derelict_ship_entity.gd")
const MiningManagerScript = preload("res://Gameplay/Mining/mining_manager.gd")
const CargoManagerScript = preload("res://Economy/cargo_manager.gd")

func _ready() -> void:
	print(">>> AVVIO TEST HEADLESS: MINING & SCAVENGING <<<")
	run_all_tests()
	print(">>> TUTTI I TEST DI MINING & SCAVENGING COMPLETATI CON SUCCESSO! <<<")
	get_tree().quit(0)

func run_all_tests() -> void:
	test_spectrometry_and_asteroid_state()
	test_asteroid_damage_and_fragment_generation()
	test_mineral_deposit_collection_and_cargo_storage()
	test_derelict_laser_cutting_and_bulkhead()
	test_derelict_ice_hacking_and_salvage()
	test_derelict_duct_drone_infiltration()

func test_spectrometry_and_asteroid_state() -> void:
	print("\n--- TEST 1: Analisi Spettrometrica e Stato Asteroide ---")
	var mining_mgr := MiningManagerScript.new()
	add_child(mining_mgr)
	
	var asteroid := AsteroidScript.new()
	asteroid.name = "Asteroid_Test_Alpha"
	add_child(asteroid)
	
	var scan_data: Dictionary = mining_mgr.perform_spectrometric_scan(asteroid)
	assert(scan_data.has("composition"), "Dati scansione devono contenere la composizione")
	assert(scan_data.has("purity_pct"), "Dati scansione devono contenere la percentuale di purezza")
	assert(scan_data.get("health_pct") == 100, "La salute iniziale dell'asteroide deve essere 100%")
	assert(scan_data.get("estimated_yield_fragments") >= 3, "Resa frammenti stimata deve essere almeno 3")
	
	print("✔ Spettrometria completata: Tipo=%s, Purezza=%d%%, Valore=%d Cr" % [
		scan_data["resource_name"],
		scan_data["purity_pct"],
		scan_data["base_value_credits"]
	])
	
	asteroid.queue_free()
	mining_mgr.queue_free()

func test_asteroid_damage_and_fragment_generation() -> void:
	print("\n--- TEST 2: Danneggiamento Asteroide e Generazione Procedurale Frammenti ---")
	var root_space := Node3D.new()
	add_child(root_space)
	
	var mining_mgr := MiningManagerScript.new()
	root_space.add_child(mining_mgr)
	
	var asteroid := AsteroidScript.new()
	asteroid.name = "Asteroid_Target"
	root_space.add_child(asteroid)
	
	var initial_state := mining_mgr.get_or_register_asteroid_state(asteroid)
	assert(initial_state["health"] == 200.0, "Salute iniziale asteroide = 200")
	assert(initial_state["spawned_fragments"] == 0, "Frammenti iniziali generati = 0")
	
	# Applica danno laser pari al 50%
	var fragments := mining_mgr.apply_mining_damage_to_asteroid(asteroid, 100.0, Vector3(0, 0, 5))
	assert(fragments.size() > 0, "Danno minerario sufficiente deve rilasciare frammenti fisici")
	assert(initial_state["health"] == 100.0, "Salute dopo danno deve essere 100")
	
	# Verifica proprietà del primo frammento generato
	var first_frag = fragments[0]
	assert(first_frag != null, "Il frammento deve essere un MineralDepositEntity valido")
	assert(first_frag.mass_kg > 0.0, "Il frammento deve avere una massa valida")
	assert(first_frag.resource_type == initial_state["resource_type"], "Tipo risorsa frammento coerente con asteroide")
	
	# Completa distruzione/frantumazione
	var remaining_frags := mining_mgr.apply_mining_damage_to_asteroid(asteroid, 100.0, Vector3(0, 0, 5))
	assert(initial_state["health"] == 0.0, "Salute asteroide esaurita = 0")
	assert(initial_state["spawned_fragments"] == initial_state["total_fragments"], "Tutti i frammenti previsti sono stati estratti")
	
	print("✔ Generazione frammenti validata: Totale frammenti estratti = %d" % initial_state["spawned_fragments"])
	
	root_space.queue_free()

func test_mineral_deposit_collection_and_cargo_storage() -> void:
	print("\n--- TEST 3: Riconoscimento Risorsa Estratta e Inserimento in Stiva ---")
	var cargo_mgr := CargoManagerScript.new()
	add_child(cargo_mgr)
	cargo_mgr.clear_cargo()
	
	var mining_mgr := MiningManagerScript.new()
	add_child(mining_mgr)
	
	var deposit := MineralDepositScript.new()
	deposit.deposit_id = "water_ice_fragment_01"
	deposit.mineral_name = "Ghiaccio d'Acqua Minerale"
	deposit.resource_type = "water_ice"
	deposit.mass_kg = 20.0
	deposit.volume_m3 = 0.5
	deposit.purity = 0.9
	deposit.life_support_water_units = 15.0
	add_child(deposit)
	
	var res_dict: Dictionary = deposit.get_resource_dict()
	assert(res_dict["type"] == "MINERAL", "Tipo risorsa deve essere MINERAL")
	assert(res_dict["resource_sub_type"] == "water_ice", "Sottotipo risorsa water_ice")
	
	# Cattura frammento e stivaggio
	var ok := mining_mgr.capture_deposit(deposit, null, cargo_mgr)
	assert(ok == true, "Cattura e inserimento in stiva riusciti")
	assert(cargo_mgr.has_item("water_ice_fragment_01", 1) == true, "L'oggetto deve essere registrato nella stiva")
	assert(cargo_mgr.get_total_mass() == 20.0, "Massa in stiva aggiornata a 20 kg")
	
	# Test attrazione magnetica
	var target_drone := Node3D.new()
	add_child(target_drone)
	target_drone.global_position = Vector3(10, 0, 0)
	
	var deposit2 := MineralDepositScript.new()
	add_child(deposit2)
	deposit2.global_position = Vector3(0, 0, 0)
	deposit2.start_magnetic_attraction(target_drone, 20.0)
	assert(deposit2.freeze == true, "RigidBody freeze attivo durante attrazione magnetica")
	deposit2.stop_magnetic_attraction()
	assert(deposit2.freeze == false, "RigidBody sbloccato dopo termine attrazione")
	
	print("✔ Stivaggio risorsa e dinamica attrazione verificate con successo")
	
	target_drone.queue_free()
	deposit2.queue_free()
	mining_mgr.queue_free()
	cargo_mgr.queue_free()

func test_derelict_laser_cutting_and_bulkhead() -> void:
	print("\n--- TEST 4: Scavenging Relitti - Taglio Laser Paratie Esterne ---")
	var derelict := DerelictShipScript.new()
	derelict.derelict_id = "derelict_beta_01"
	derelict.bulkhead_hp = 100.0
	derelict.bulkhead_intact = true
	add_child(derelict)
	
	var mining_mgr := MiningManagerScript.new()
	add_child(mining_mgr)
	
	# Taglio parziale
	var breached := mining_mgr.cut_derelict_bulkhead(derelict, 40.0)
	assert(breached == false, "Paratia non deve cedere con danno parziale")
	assert(derelict.bulkhead_hp == 60.0, "HP paratia rimasti = 60")
	assert(derelict.bulkhead_intact == true, "Paratia ancora intatta")
	
	# Taglio definitivo
	breached = mining_mgr.cut_derelict_bulkhead(derelict, 60.0)
	assert(breached == true, "Paratia deve essere perforata")
	assert(derelict.bulkhead_intact == false, "bulkhead_intact deve essere false")
	assert(derelict.bulkhead_hp == 0.0, "HP paratia = 0")
	
	print("✔ Meccanica taglio laser paratie relitto verificata con successo")
	
	derelict.queue_free()
	mining_mgr.queue_free()

func test_derelict_ice_hacking_and_salvage() -> void:
	print("\n--- TEST 5: Violazione ICE, Scasso Elettronico e Raccolta Moduli/Crediti ---")
	var derelict := DerelictShipScript.new()
	derelict.derelict_id = "derelict_gamma_02"
	derelict.ice_locked = true
	derelict.ice_security_level = 3
	derelict.bulkhead_intact = false # Già tagliata
	add_child(derelict)
	
	var cargo_mgr := CargoManagerScript.new()
	add_child(cargo_mgr)
	cargo_mgr.clear_cargo()
	
	var mining_mgr := MiningManagerScript.new()
	add_child(mining_mgr)
	
	# Tentativo di recupero prima dell'hacking ICE -> deve fallire
	var early_salvage := mining_mgr.scavenge_derelict_loot(derelict, cargo_mgr)
	assert(early_salvage.has("error") and early_salvage["error"] == "ICE_LOCKED", "Scavenging bloccato se ICE attivo")
	
	# Hacking con livello insufficiente (livello 1 vs sicurezza 3)
	var hack_fail := mining_mgr.hack_derelict_ice(derelict, 1)
	assert(hack_fail == false, "Hacking livello 1 deve fallire contro sicurezza 3")
	assert(derelict.ice_locked == true, "ICE deve rimanere attivo")
	
	# Hacking con override o livello 3
	var hack_ok := mining_mgr.hack_derelict_ice(derelict, 3)
	assert(hack_ok == true, "Hacking livello 3 deve avere successo")
	assert(derelict.ice_locked == false, "ICE deve essere disattivato")
	
	# Esecuzione scavenging completo
	var salvage_result := mining_mgr.scavenge_derelict_loot(derelict, cargo_mgr)
	assert(salvage_result.get("success") == true, "Scavenging deve avere esito positivo")
	assert(salvage_result.get("credits_recovered") == 1200, "Crediti recuperati = 1200")
	assert(salvage_result.get("flux_recovered") == 25.0, "FLUX recuperato = 25.0")
	assert(salvage_result.get("modules_recovered").size() == 2, "2 Moduli avionici recuperati")
	assert(derelict.is_salvaged() == true, "Il relitto deve essere segnato come completamente spogliato")
	
	print("✔ Scasso ICE e spoglio relitto (Moduli, FLUX, Crediti) validati")
	
	derelict.queue_free()
	cargo_mgr.queue_free()
	mining_mgr.queue_free()

func test_derelict_duct_drone_infiltration() -> void:
	print("\n--- TEST 6: Infiltrazione Condotti con Duct Drone ---")
	var derelict := DerelictShipScript.new()
	derelict.derelict_id = "derelict_delta_03"
	derelict.black_box_recovered = false
	add_child(derelict)
	
	var mining_mgr := MiningManagerScript.new()
	add_child(mining_mgr)
	
	var duct_result := mining_mgr.infiltrate_derelict_with_duct_drone(derelict, null)
	assert(duct_result.get("success") == true, "Infiltrazione condotti deve riuscire")
	assert(duct_result.get("found_items").size() > 0, "Duct drone deve recuperare la scatola nera")
	assert(derelict.black_box_recovered == true, "Scatola nera contrassegnata come recuperata")
	
	print("✔ Infiltrazione condotti Duct Drone con recupero Black Box validata")
	
	derelict.queue_free()
	mining_mgr.queue_free()
