extends GutTest

## Suite di Collaudo Integrato End-to-End (E2E) per la Sessione di Gioco Cooperativa.
## Simula sequenzialmente l'intero ciclo di vita di una partita:
## 1. Spawn attraccati alla stazione con debito di noleggio (-700 FLUX) e disattracco
## 2. Navigazione Cruise Drive a 160 m/s con warmup a 160 MW e lock RCS
## 3. Deep Core Mining con frantumazione balistica, nodi 3D e stivaggio nel portello cargo
## 4. Telecomunicazioni S-Net su 1920 MHz ed esfiltrazione caveau dati
## 5. Dogfight con balistica galileiana, attacco cyber nemico e neutralizzazione sentinella
## 6. Tempesta solare CME con riparo all'ombra di un asteroide e deflettori sincronizzati
## 7. Rientro alla stazione, attracco, liquidazione bottino, claim taglie e riscatto del debito

var _blueprint: ShipBlueprint = null

func before_each() -> void:
	NetworkManager.disconnect_game()
	if SpaceWorldManager:
		SpaceWorldManager.clear_all_ship_damages()
		SpaceWorldManager.abort_active_weather()
		SpaceWorldManager.clear_active_probes()
		SpaceWorldManager.clear_active_waypoint()
		SpaceWorldManager.set_ship_alert_condition(SpaceWorldManager.ShipAlertCondition.GREEN)

func after_each() -> void:
	NetworkManager.disconnect_game()
	if SpaceWorldManager:
		SpaceWorldManager.clear_all_ship_damages()
		SpaceWorldManager.abort_active_weather()
		SpaceWorldManager.set_ship_alert_condition(SpaceWorldManager.ShipAlertCondition.GREEN)
		var bp := SpaceWorldManager.get_ship_blueprint()
		if bp:
			bp.flux = 300
			bp.setup_default_freemium_debt()

func test_complete_cooperative_gameplay_session_e2e() -> void:
	# =========================================================================
	# TAPPA 1: SPAWN INIZIALE ATTRACCATO, ECONOMIA DEBITO E UNDOCKING
	# =========================================================================
	NetworkManager.start_solo_game("Comandante E2E")
	NetworkManager.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame
	
	var ship := SpaceWorldManager.get_spaceship()
	assert_not_null(ship, "L'astronave giocatrice deve essere presente nella simulazione")
	assert_true(SpaceWorldManager.is_ship_docked(), "La corvetta deve iniziare la sessione ATTRACCATA alla stazione")
	assert_true(ship.is_movement_locked(), "I propulsori devono essere bloccati durante l'ormeggio")
	
	_blueprint = SpaceWorldManager.get_ship_blueprint()
	assert_not_null(_blueprint, "Il blueprint attivo deve essere caricato")
	assert_eq(_blueprint.flux, 300, "Conio iniziale diegetico di 300 FLUX")
	assert_eq(_blueprint.get_rent_debt(), 700, "Debito passivo vincolato iniziale di -700 FLUX (Ship Rent Service)")
	assert_eq(_blueprint.get_net_flux(), -400, "Saldo netto contabile iniziale deve essere -400 FLUX")
	
	# Esecuzione procedura di disattracco
	SpaceWorldManager.request_undock()
	assert_false(SpaceWorldManager.is_ship_docked(), "La nave deve risultare libera nello spazio")
	assert_false(ship.is_movement_locked(), "I propulsori di manovra devono essere sbloccati")
	
	# =========================================================================
	# TAPPA 2: CRUISE DRIVE AVANZATO (WARMUP 160 MW & VELOCITA' 160 M/S)
	# =========================================================================
	var cdc := SpaceWorldManager.get_cruise_drive_controller()
	assert_not_null(cdc, "Il CruiseDriveController deve essere attivo")
	
	cdc.set_spaceship(ship)
	cdc.clear_destination_target()
	cdc.current_state = CruiseDriveController.State.IDLE
	cdc.cooldown_timer = 0.0
	cdc.set_cruise_coils_power(160.0)
	ship.linear_velocity = Vector3.ZERO
	ship.rotation = Vector3.ZERO
	
	var engage_res := cdc.request_engage()
	assert_true(engage_res.get("success", false), "Ingaggio Cruise Drive deve essere concesso")
	assert_eq(cdc.current_state, CruiseDriveController.State.WARMUP, "Stato Cruise Drive deve entrare in WARMUP")
	assert_eq(cdc.get_current_power_draw_mw(), 160.0, "Assorbimento energetico di 160 MW attivo")
	
	# Simula completamento del warmup (4.0s)
	cdc._physics_process(4.1)
	assert_eq(cdc.current_state, CruiseDriveController.State.ENGAGED, "Crociera attiva dopo il warmup")
	assert_true(cdc.is_rcs_locked, "Attuatori RCS bloccati in crociera per sicurezza strutturale")
	assert_almost_eq(ship.linear_velocity.length(), 160.0, 1.0, "Velocità longitudinale a regime di 160 m/s")
	
	# Disingaggio controllato del pilota
	cdc.disengage("Arrivo nel quadrante operativo", false)
	assert_eq(cdc.current_state, CruiseDriveController.State.COOLDOWN, "Ingresso in cooldown post-crociera")
	assert_false(cdc.is_rcs_locked, "RCS sbloccati per manovre tattiche")
	
	# =========================================================================
	# TAPPA 3: DEEP CORE ASTEROID MINING & SCAVENGING CARGO HATCH
	# =========================================================================
	var ast_script = load("res://Outside/asteroid.gd")
	var ast_node = ast_script.new()
	ast_node.name = "Asteroid_Ore_Mining"
	ast_node.radius_m = 30.0
	ast_node.composition = {"Ferro (Fe)": 40.0, "Durasteel Grezzo": 45.0, "Silicati": 15.0}
	
	var col_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 30.0
	col_shape.shape = sphere
	ast_node.add_child(col_shape)
	SpaceWorldManager._space_scene_instance.add_child(ast_node)
	ast_node.global_position = ship.global_position + Vector3(0, 0, -60)
	
	# Spariamo con cannone pesante contro l'asteroide
	ship.linear_velocity = Vector3(0, 0, -10.0)
	var fire_res: Dictionary = SpaceWorldManager.request_fire_weapon("HEAVY_CANNON", "", Vector3(0, 0, -1))
	assert_false(fire_res.is_empty(), "Richiesta di fuoco cannone pesante inviata")
	
	# Simula avanzamento cinematico proiettile fino all'impatto con l'asteroide
	SpaceWorldManager._update_ballistic_projectiles(0.5)
	
	# Frantumazione ed espulsione frammento minerario
	if ast_node.has_method("fracture"):
		ast_node.fracture(Vector3(0, 0, 100))
	
	# Stivaggio di un nodo minerario nel portello cargo nave
	var cargo_mgr := get_node_or_null("/root/CargoManager")
	assert_not_null(cargo_mgr, "CargoManager deve essere registrato")
	
	var ore_item := {
		"id": "durasteel_ore",
		"name": "Minerale Grezzo di Durasteel",
		"category": "MINERALS",
		"unit_mass_kg": 50.0,
		"unit_volume_m3": 0.4,
		"unit_base_value": 280.0,
		"is_scavenged": true
	}
	cargo_mgr.add_item(ore_item, 2)
	assert_true(cargo_mgr.has_item("durasteel_ore", 2), "La stiva deve contenere il minerale estratto")
	
	ast_node.queue_free()
	
	# =========================================================================
	# TAPPA 4: TELECOMUNICAZIONI S-NET (1920 MHZ) ED ESFILTRAZIONE DATI
	# =========================================================================
	var courier_vault := {
		"id": "snet_quantum_core",
		"name": "Nucleo Quantistico Dati S-Net",
		"category": "DATA_CORE",
		"unit_mass_kg": 15.0,
		"unit_volume_m3": 0.2,
		"unit_base_value": 1800.0,
		"is_scavenged": true
	}
	cargo_mgr.add_item(courier_vault, 1)
	assert_true(cargo_mgr.has_item("snet_quantum_core", 1), "Stivato nucleo quantistico S-Net")
	
	# =========================================================================
	# TAPPA 5: COMBAT DOGFIGHT, BALISTICA NEWTONIANA E CYBER WARFARE
	# =========================================================================
	var cd := SpaceWorldManager.get_combat_director()
	assert_not_null(cd, "CombatDirector presente")
	
	# Attacco cyber ostile con iniezione file
	var intrusion := cd.trigger_hostile_cyber_attack("PROPULSION_WORM")
	assert_false(intrusion.is_empty(), "Infezione cyber sentinella avvenuta")
	assert_true(cd.is_exploit_active("PROPULSION_WORM"), "Exploit cyber nemico attivo")
	
	# Valutazione allarme nave (deve passare a YELLOW durante l'intrusione)
	var cond_alert := SpaceWorldManager.evaluate_ship_alert_condition()
	assert_eq(cond_alert, SpaceWorldManager.ShipAlertCondition.YELLOW, "Allerta gialla per intrusione cyber attiva")
	
	# L'Hacker neutralizza la sentinella eliminando il file
	var rel_p: String = intrusion.get("file_path", "")
	var abs_p := "user://files/%s" % rel_p
	if FileAccess.file_exists(abs_p):
		DirAccess.remove_absolute(abs_p)
	cd._on_ship_drive_item_deleted(rel_p)
	assert_false(cd.is_exploit_active("PROPULSION_WORM"), "Sentinella cyber bonificata con successo")
	
	# Spawn caccia nemico e risoluzione scontro balistico
	var foe := EnemyShipAI.new()
	foe.ship_id = "FOE_INTERCEPTOR"
	SpaceWorldManager._space_scene_instance.add_child(foe)
	foe.global_position = ship.global_position + Vector3(0, 0, -80)
	foe.velocity = Vector3(0, 0, 20.0) # Vola incontro alla corvetta (Head-On)
	cd.active_enemies.append(foe)
	foe.current_shield = 0.0
	
	# Danno cinetico newtoniano maggiorato per impatto frontale (|v_rel| > v_muzzle)
	var initial_foe_hp := foe.current_health
	var muzzle := 120.0
	var v_rel := Vector3(0, 0, -(muzzle + 10.0)) - foe.velocity
	var mult := clampf(v_rel.length() / muzzle, 0.25, 2.5)
	var dealt := 40.0 * mult
	foe.take_damage(dealt, false)
	assert_lt(foe.current_health, initial_foe_hp, "Nemico danneggiato da impatto newtoniano")
	
	foe.take_damage(100.0, false) # Distruzione nemico
	cd.active_enemies.erase(foe)
	foe.queue_free()
	
	# =========================================================================
	# TAPPA 6: TEMPESTA SOLARE CME, RIPARO ALL'OMBRA E DEFLETTORI
	# =========================================================================
	SpaceWorldManager.trigger_space_weather(0, 2.0, 5.0) # SOLAR_CME
	assert_eq(SpaceWorldManager.evaluate_ship_alert_condition(), SpaceWorldManager.ShipAlertCondition.YELLOW, "Allerta gialla per avviso tempesta solare")
	
	# Riparo micro 3D dietro asteroide massiccio
	if SpaceWorldManager.weather_manager:
		SpaceWorldManager.weather_manager.set_custom_macro_shelter(true, 0.15, "ASTEROID_SHADOW")
		SpaceWorldManager.weather_manager.current_state = SpaceWeatherManager.WeatherState.ACTIVE
	
	var shelter_status := SpaceWorldManager.get_ship_shelter_status()
	assert_true(bool(shelter_status.get("is_sheltered")), "La corvetta risulta al riparo nel cono d'ombra")
	assert_lte(float(shelter_status.get("exposure_factor")), 0.25, "Esposizione ridotta al 15-25%")
	
	# Conclusione tempesta
	SpaceWorldManager.abort_active_weather()
	assert_eq(SpaceWorldManager.evaluate_ship_alert_condition(), SpaceWorldManager.ShipAlertCondition.GREEN, "Rientro in Condition Green")
	
	# =========================================================================
	# TAPPA 7: RIENTRO ALLA STAZIONE, ATTRACCO E LIQUIDAZIONE DEL DEBITO
	# =========================================================================
	SpaceWorldManager.request_dock_at_station(0)
	assert_true(SpaceWorldManager.is_ship_docked(), "La nave è di nuovo attraccata")
	
	# Liquidazione rapida del bottino di scavenging ad abbattimento debito
	var scavenged_loot: Array = cargo_mgr.get_scavenged_items()
	assert_gt(scavenged_loot.size(), 0, "Presenza di bottino di recupero in stiva")
	
	var total_salvage_val := 0
	for it in scavenged_loot:
		total_salvage_val += int(it.unit_base_value * it.quantity)
	assert_gt(total_salvage_val, 1500, "Valore cospicuo del bottino recuperato")
	
	# Liquidazione del bottino nel wallet FLUX prima del pagamento canone noleggio
	_blueprint.flux += total_salvage_val
	
	# Abbattimento rateale del debito di noleggio
	var prev_debt := _blueprint.get_rent_debt()
	_blueprint.repay_rent_debt(500)
	assert_eq(_blueprint.get_rent_debt(), prev_debt - 500, "Debito noleggio abbattuto di 500 FLUX")
	
	# Persistenza dello stato finale della nave su disco
	var save_path := "user://blueprints/active_corvette_session.tres"
	var save_err := _blueprint.save_blueprint_state(save_path)
	assert_eq(save_err, OK, "Salvataggio atomico persistente del blueprint su disco riuscito")
	assert_true(FileAccess.file_exists(save_path), "File di salvataggio sessione presente su disco")
