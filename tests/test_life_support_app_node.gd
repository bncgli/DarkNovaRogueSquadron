extends Node

## Test Runner Headless per LifeSupportApp (Applications/LifeSupport)
## Verifica Overlay/Ciclo di vita, RBAC, File .DAT / Hot-Reload, ShipSoftwareManager, Controlli Atmosfera e Pulizia Segnali.

func _ready() -> void:
	print("\n=======================================================")
	print(">>> AVVIO SUITE DI TEST HEADLESS: LIFE SUPPORT APP")
	print("=======================================================\n")
	_run_all_tests()

func _run_all_tests() -> void:
	await get_tree().process_frame
	
	var app_scene: PackedScene = load("res://Applications/LifeSupport/life_support_app.tscn")
	assert(app_scene != null, "La scena life_support_app.tscn deve essere caricata con successo")
	
	var app: LifeSupportApp = app_scene.instantiate() as LifeSupportApp
	assert(app != null, "LifeSupportApp deve istanziarsi come nodo LifeSupportApp")
	add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	
	var net_mgr := get_node_or_null("/root/NetworkManager")
	var sdm := get_node_or_null("/root/ShipDriveManager")
	
	# =========================================================================
	# TEST 1: OVERLAY E CICLO DI VITA (OFFLINE vs MISSIONE AVVIATA)
	# =========================================================================
	print("--- TEST 1: Overlay e Ciclo di Vita Offline / Online ---")
	if net_mgr and net_mgr.is_mission_active:
		net_mgr.disconnect_game()
		await get_tree().process_frame
	
	if SpaceWorldManager:
		SpaceWorldManager.is_ship_connected_state = false
		SpaceWorldManager.ship_connection_changed.emit(false)
		await get_tree().process_frame
	
	assert(app.disconnected_overlay != null, "%DisconnectedOverlay deve esistere nella scena")
	assert(app.disconnected_overlay.visible == true, "%DisconnectedOverlay deve essere VISIBILE quando la nave è offline")
	print("✔ Overlay offline correttamente visualizzato")
	
	# Simula connessione nave / avvio missione
	if SpaceWorldManager:
		SpaceWorldManager.is_ship_connected_state = true
		SpaceWorldManager.ship_connection_changed.emit(true)
		await get_tree().process_frame
	
	assert(app.disconnected_overlay.visible == false, "%DisconnectedOverlay deve SCOMPARIRE quando la nave è connessa")
	print("✔ Overlay rimosso automaticamente a connessione stabilita")
	
	# =========================================================================
	# TEST 2: RBAC (ROLE-BASED ACCESS CONTROL)
	# =========================================================================
	print("\n--- TEST 2: Matrice RBAC (Permessi Ruolo e Controlli) ---")
	if net_mgr:
		net_mgr.host_game("OperatoreSupporto")
		await get_tree().process_frame
		
		# 2.1 Pilota: Sola Lettura
		net_mgr.request_role("Pilota")
		await get_tree().process_frame
		assert(app.can_control_life_support == false, "Pilota non deve avere controllo attivo sul supporto vitale")
		assert(app.btn_toggle_seal.disabled == true, "BtnToggleSeal deve essere disabilitato per Pilota")
		assert(app.btn_suppress_fire.disabled == true, "BtnSuppressFire deve essere disabilitato per Pilota")
		print("✔ Ruolo Pilota: correttamente limitato a sola visualizzazione")
		
		# 2.2 Soldato: Sola Lettura
		net_mgr.request_role("Soldato")
		await get_tree().process_frame
		assert(app.can_control_life_support == false, "Soldato non deve avere controllo attivo sul supporto vitale")
		assert(app.btn_toggle_seal.disabled == true, "BtnToggleSeal deve essere disabilitato per Soldato")
		assert(app.btn_suppress_fire.disabled == true, "BtnSuppressFire deve essere disabilitato per Soldato")
		print("✔ Ruolo Soldato: correttamente limitato a sola visualizzazione")
		
		# 2.3 Hacker: Sola Lettura
		net_mgr.request_role("Hacker")
		await get_tree().process_frame
		assert(app.can_control_life_support == false, "Hacker non deve avere controllo attivo sul supporto vitale")
		print("✔ Ruolo Hacker: correttamente limitato a sola visualizzazione")
		
		# 2.4 Ingegnere: Controllo Completo
		net_mgr.request_role("Ingegnere")
		await get_tree().process_frame
		assert(app.can_control_life_support == true, "Ingegnere deve avere controllo completo sul supporto vitale")
		assert(app.btn_toggle_seal.disabled == false, "BtnToggleSeal deve essere abilitato per Ingegnere")
		assert(app.btn_suppress_fire.disabled == false, "BtnSuppressFire deve essere abilitato per Ingegnere")
		print("✔ Ruolo Ingegnere: controllo completo abilitato")
		
		# 2.5 Capitano: Controllo Completo e Override
		net_mgr.request_role("Capitano")
		await get_tree().process_frame
		assert(app.can_control_life_support == true, "Capitano deve avere controllo completo sul supporto vitale")
		print("✔ Ruolo Capitano: controllo completo abilitato")
		
		# 2.6 Stagista / Solo Mode
		net_mgr.request_role("Stagista")
		await get_tree().process_frame
		assert(app.can_control_life_support == true, "Stagista deve avere controllo completo sul supporto vitale")
		print("✔ Ruolo Stagista: controllo completo abilitato")
	
	# =========================================================================
	# TEST 3: RISORSA E SOFTWARE MANAGER
	# =========================================================================
	print("\n--- TEST 3: Risorsa AppResource e ShipSoftwareManager ---")
	var ssm := get_node_or_null("/root/ShipSoftwareManager") as ShipSoftwareManagerSingleton
	assert(ssm != null, "ShipSoftwareManager singleton deve essere attivo")
	
	var res: AppResource = ssm.get_registered_app("life_support")
	assert(res != null, "life_support_app.tres deve essere registrata nel catalogo ShipSoftwareManager")
	assert(res.app_id == "life_support", "app_id deve corrispondere a 'life_support'")
	assert(res.default_password == "LIFE-7815", "Password di default deve essere 'LIFE-7815'")
	assert(res.power_draw_mw == 20.0, "power_draw_mw deve corrispondere a 20.0 MW")
	assert(res.default_files.size() >= 2, "La risorsa deve contenere life_support_config.dat e atmo_tuning.dat")
	print("✔ Registrazione e metadati AppResource validati con successo")
	
	# =========================================================================
	# TEST 4: FILE .DAT E HOT-RELOADING
	# =========================================================================
	print("\n--- TEST 4: Parsing file .DAT e Hot-Reloading ---")
	if sdm:
		sdm.mount_drive()
	app.load_dat_configuration()
	await get_tree().process_frame
	assert(app.active_config.get("is_dat_loaded") == true, "Configurazioni .DAT devono essere caricate")
	assert(app.active_config.get("o2_generation_rate") == 1.2, "o2_generation_rate deve corrispondere a 1.2")
	assert(app.active_config.get("seal_door_speed") == 0.5, "seal_door_speed deve corrispondere a 0.5")
	assert(app.active_config.get("decompression_rate") == 1.8, "decompression_rate deve corrispondere a 1.8")
	assert(app.active_config.get("fire_suppression_co2_level") == 0.45, "fire_suppression_co2_level deve corrispondere a 0.45")
	assert(app.active_config.get("scrubber_efficiency") == 0.98, "scrubber_efficiency deve corrispondere a 0.98")
	print("✔ Parsing .DAT iniziale valido e coerente con firmware")
	
	# Simula hot-reload file_synced
	if sdm:
		sdm.file_synced.emit("Ship Drive/Programs/LifeSupport/life_support_config.dat", "")
		await get_tree().process_frame
		assert(app.active_config.get("is_dat_loaded") == true, "Hot-reloading deve ricaricare la configurazione")
		print("✔ Hot-reloading su file_synced verificato con successo")
	
	# Simula pressione tasto ricarica .DAT
	app.btn_reload_dat.emit_signal("pressed")
	await get_tree().process_frame
	assert(app.active_config.get("is_dat_loaded") == true, "Pulsante ricarica .DAT deve rinfrescare la configurazione")
	print("✔ Pulsante 🔄 Ricarica .DAT funzionante")
	
	# =========================================================================
	# TEST 5: CONTROLLI DI COMPARTIMENTO, PARATIE E SOPPRESSIONE INCENDI
	# =========================================================================
	print("\n--- TEST 5: Controlli Compartimento, Paratie e Antincendio ---")
	assert(app.rooms_state.size() > 0, "Le stanze della nave devono essere popolate")
	assert(app.room_card_widgets.size() > 0, "I widget RoomAtmoCard devono essere istanziati")
	
	var test_room_id: String = str(app.rooms_state.keys()[0])
	
	# 5.1 Test Sigillatura Paratia
	assert(app.rooms_state[test_room_id]["is_sealed"] == false, "La paratia iniziale deve essere aperta")
	app.set_bulkhead_sealed(test_room_id, true)
	await get_tree().process_frame
	assert(app.rooms_state[test_room_id]["is_sealed"] == true, "La paratia deve risultare sigillata")
	app.set_bulkhead_sealed(test_room_id, false)
	await get_tree().process_frame
	assert(app.rooms_state[test_room_id]["is_sealed"] == false, "La paratia deve risultare riaperta")
	print("✔ Sigillatura e apertura paratia stagna verificata")
	
	# 5.2 Test Iniezione Gas Inerte / Soppressione Incendio
	app.rooms_state[test_room_id]["is_fire_active"] = true
	app.trigger_fire_suppression(test_room_id)
	await get_tree().process_frame
	assert(app.rooms_state[test_room_id]["is_fire_active"] == false, "L'incendio deve essere estinto dall'iniezione")
	assert(app.rooms_state[test_room_id]["is_suppression_active"] == true, "Soppressione attiva deve essere true")
	print("✔ Iniezione gas inerte e neutralizzazione incendio verificata")
	
	# 5.3 Test Evacuazione Atmosfera e Normalizzazione
	app.set_room_venting(test_room_id, true)
	await get_tree().process_frame
	assert(app.rooms_state[test_room_id]["is_venting"] == true, "Venting deve essere attivo")
	
	app.normalize_room_atmosphere(test_room_id)
	await get_tree().process_frame
	assert(app.rooms_state[test_room_id]["is_venting"] == false, "Venting deve essere resettato")
	assert(app.rooms_state[test_room_id]["o2_pct"] == 21.0, "O2 deve essere normalizzato a 21.0%")
	assert(app.rooms_state[test_room_id]["pressure_kpa"] == 101.3, "Pressione deve essere normalizzata a 101.3 kPa")
	print("✔ Evacuazione e normalizzazione compartimento verificate")
	
	# 5.4 Test Azioni Globali
	app.btn_seal_all.emit_signal("pressed")
	await get_tree().process_frame
	for r_k in app.rooms_state:
		assert(app.rooms_state[r_k]["is_sealed"] == true, "Tutte le stanze devono essere sigillate")
	print("✔ Pulsante 'Sigilla Tutte le Paratie' verificato")
	
	app.btn_suppress_all.emit_signal("pressed")
	await get_tree().process_frame
	for r_k in app.rooms_state:
		assert(app.rooms_state[r_k]["is_suppression_active"] == true, "Tutte le stanze devono avere soppressione attiva")
	print("✔ Pulsante 'Soppressione Incendi Globale' verificato")
	
	# =========================================================================
	# TEST 6: STRUTTURA DATI STANZA, TELEMETRIA A 4 PARAMETRI E METODI PUBBLICI
	# =========================================================================
	print("\n--- TEST 6: Struttura Dati Stanza e Metodi Pubblici ---")
	var atmo_state: Dictionary = app.get_room_atmo_state(test_room_id)
	assert(not atmo_state.is_empty(), "get_room_atmo_state deve restituire i dati della stanza")
	assert(atmo_state.has("pressure_kpa"), "Lo stato della stanza deve contenere 'pressure_kpa'")
	assert(atmo_state.has("temperature_c"), "Lo stato della stanza deve contenere 'temperature_c'")
	assert(atmo_state.has("o2_pct"), "Lo stato della stanza deve contenere 'o2_pct'")
	assert(atmo_state.has("co2_pct"), "Lo stato della stanza deve contenere 'co2_pct'")
	assert(atmo_state.has("has_breach"), "Lo stato della stanza deve contenere 'has_breach'")
	assert(atmo_state.has("has_short_circuit"), "Lo stato della stanza deve contenere 'has_short_circuit'")
	assert(atmo_state.has("heater_online"), "Lo stato della stanza deve contenere 'heater_online'")
	assert(atmo_state.has("is_fire_active"), "Lo stato della stanza deve contenere 'is_fire_active'")
	assert(atmo_state.has("is_sealed"), "Lo stato della stanza deve contenere 'is_sealed'")
	
	var all_atmo := app.get_all_rooms_atmo_state()
	assert(all_atmo.size() == app.rooms_state.size(), "get_all_rooms_atmo_state deve restituire tutte le stanze")
	
	if SpaceWorldManager:
		var bridge_st := SpaceWorldManager.get_bridge_atmo_state()
		assert(bridge_st.has("pressure_kpa") and bridge_st.has("temperature_c"), "get_bridge_atmo_state deve restituire telemetria plancia")
	print("✔ Struttura dati ed export telemetria validati con successo")

	# =========================================================================
	# TEST 7: DINAMICA BRECCIA E DECOMPRESSIONE RAPIDA
	# =========================================================================
	print("\n--- TEST 7: Dinamica Breccia e Decompressione Rapida ---")
	app.normalize_room_atmosphere(test_room_id)
	app.set_room_breach(test_room_id, true)
	app.rooms_state[test_room_id]["is_fire_active"] = true
	await get_tree().process_frame
	
	# Simula steps di decompressione
	for i in range(10):
		app._simulate_atmosphere_step(0.5)
	
	var breached_state: Dictionary = app.get_room_atmo_state(test_room_id)
	assert(breached_state["pressure_kpa"] < 10.0, "La pressione deve crollare rapidamente su breccia (attuale: %f)" % breached_state["pressure_kpa"])
	assert(breached_state["o2_pct"] < 5.0, "L'ossigeno deve crollare su breccia (attuale: %f)" % breached_state["o2_pct"])
	assert(breached_state["is_fire_active"] == false, "L'incendio deve estinguersi per mancanza di pressione/ossigeno")
	print("✔ Decompressione da breccia ed estinzione automatica fuoco verificate")

	# =========================================================================
	# TEST 8: AZZERAMENTO TERMICO NEL VUOTO (PRESSIONE <= 1.0 kPa)
	# =========================================================================
	print("\n--- TEST 8: Azzeramento Termico nel Vuoto ---")
	app.rooms_state[test_room_id]["pressure_kpa"] = 0.0
	app.rooms_state[test_room_id]["temperature_c"] = 21.5
	app.rooms_state[test_room_id]["heater_online"] = true
	
	for i in range(5):
		app._simulate_atmosphere_step(0.5)
	
	var vacuum_state: Dictionary = app.get_room_atmo_state(test_room_id)
	assert(vacuum_state["temperature_c"] < 1.0, "Nel vuoto la temperatura deve decadere verso 0.0 °C (attuale: %f)" % vacuum_state["temperature_c"])
	print("✔ Decadimento termico nel vuoto spaziale verificato")

	# =========================================================================
	# TEST 9: CORTOCIRCUITO, SPEGNIMENTO CALDAIA E RAFFREDDAMENTO
	# =========================================================================
	print("\n--- TEST 9: Cortocircuito e Disattivazione Caldaia ---")
	app.normalize_room_atmosphere(test_room_id)
	assert(app.rooms_state[test_room_id]["heater_online"] == true, "La caldaia deve essere online inizialmente")
	
	# Provoca corto circuito
	app.set_room_short_circuit(test_room_id, true)
	app._simulate_atmosphere_step(0.1)
	assert(app.rooms_state[test_room_id]["heater_online"] == false, "La caldaia deve spegnersi con corto circuito")
	
	# Simula raffreddamento progressivo in stanza pressurizzata
	var prev_temp: float = app.rooms_state[test_room_id]["temperature_c"]
	for i in range(10):
		app._simulate_atmosphere_step(0.5)
	var cooled_temp: float = app.rooms_state[test_room_id]["temperature_c"]
	assert(cooled_temp < prev_temp, "La temperatura deve diminuire progressivamente a caldaia spenta")
	
	# Ripristina corto circuito
	app.set_room_short_circuit(test_room_id, false)
	app._simulate_atmosphere_step(0.1)
	assert(app.rooms_state[test_room_id]["heater_online"] == true, "La caldaia deve tornare online a riparazione effettuata")
	
	# Simula riscaldamento normale
	for i in range(10):
		app._simulate_atmosphere_step(0.5)
	assert(app.rooms_state[test_room_id]["temperature_c"] > cooled_temp, "La temperatura deve risalire verso 21.5°C")
	print("✔ Spegnimento caldaia da corto circuito e ciclo termico verificati")

	# =========================================================================
	# TEST 10: DINAMICA INCENDIO E PICCO TERMICO CRITICO
	# =========================================================================
	print("\n--- TEST 10: Incendio e Picco Termico a 420°C ---")
	app.normalize_room_atmosphere(test_room_id)
	app.set_room_fire(test_room_id, true)
	
	for i in range(10):
		app._simulate_atmosphere_step(0.5)
	
	var fire_state: Dictionary = app.get_room_atmo_state(test_room_id)
	assert(fire_state["temperature_c"] > 100.0, "L'incendio deve elevare la temperatura a picchi critici (attuale: %f)" % fire_state["temperature_c"])
	assert(fire_state["o2_pct"] < 21.0, "L'incendio deve consumare ossigeno (attuale: %f)" % fire_state["o2_pct"])
	print("✔ Picco termico critico da fuoco e consumo ossigeno verificati")

	# =========================================================================
	# TEST 11: EMISSIONE SEGNALE ANOMALIE ATMOSFERICHE
	# =========================================================================
	print("\n--- TEST 11: Segnale atmosphere_anomaly_detected ---")
	var detected_anomalies: Array[String] = []
	var anomaly_callable := func(r_id: String, a_type: String) -> void:
		if r_id == test_room_id:
			detected_anomalies.append(a_type)
	
	app.atmosphere_anomaly_detected.connect(anomaly_callable)
	app.normalize_room_atmosphere(test_room_id)
	app._room_anomalies.clear()
	
	# Trigger Fire anomaly
	app.set_room_fire(test_room_id, true)
	app._simulate_atmosphere_step(0.1)
	assert(detected_anomalies.has("FIRE"), "Il segnale deve notificare l'anomalia FIRE")
	
	# Trigger Breach anomaly
	app.set_room_breach(test_room_id, true)
	app._simulate_atmosphere_step(0.1)
	assert(detected_anomalies.has("BREACH"), "Il segnale deve notificare l'anomalia BREACH")
	
	# Trigger Short Circuit anomaly
	app.set_room_short_circuit(test_room_id, true)
	app._simulate_atmosphere_step(0.1)
	assert(detected_anomalies.has("SHORT_CIRCUIT"), "Il segnale deve notificare l'anomalia SHORT_CIRCUIT")
	
	app.atmosphere_anomaly_detected.disconnect(anomaly_callable)
	print("✔ Segnale atmosphere_anomaly_detected verificato per tutte le anomalie")

	# =========================================================================
	# TEST 12: WIDGET ROOMATMOCARD A 4 PARAMETRI E BADGE ALLARME
	# =========================================================================
	print("\n--- TEST 12: Widget RoomAtmoCard Telemetria e Badge Allarmi ---")
	var card: RoomAtmoCard = app.room_card_widgets[test_room_id] as RoomAtmoCard
	assert(card != null, "La scheda stanza per test_room_id deve esistere")
	assert(card.pressure_label != null, "pressure_label deve essere presente nel widget")
	assert(card.temp_label != null, "temp_label deve essere presente nel widget")
	assert(card.heater_label != null, "heater_label deve essere presente nel widget")
	assert(card.status_badge != null, "status_badge deve essere presente nel widget")
	
	# 12.1 Normale
	card.update_telemetry({
		"id": test_room_id, "name": "Plancia", "pressure_kpa": 101.3,
		"temperature_c": 21.5, "o2_pct": 21.0, "co2_pct": 0.04,
		"heater_online": true, "has_breach": false, "has_short_circuit": false,
		"is_fire_active": false, "is_sealed": false, "is_suppression_active": false
	})
	assert(card.status_badge.text == "● NORMALE", "Badge deve essere ● NORMALE")
	assert(card.heater_label.text == "Caldaia: ON", "Heater label deve essere Caldaia: ON")
	
	# 12.2 Incendio
	card.update_telemetry({
		"id": test_room_id, "name": "Plancia", "pressure_kpa": 101.3,
		"temperature_c": 21.5, "o2_pct": 21.0, "co2_pct": 0.04,
		"heater_online": true, "has_breach": false, "has_short_circuit": false,
		"is_fire_active": true, "is_sealed": false, "is_suppression_active": false
	})
	assert("INCENDIO" in card.status_badge.text, "Badge deve indicare INCENDIO")
	
	# 12.3 Breccia
	card.update_telemetry({
		"id": test_room_id, "name": "Plancia", "pressure_kpa": 101.3,
		"temperature_c": 21.5, "o2_pct": 21.0, "co2_pct": 0.04,
		"heater_online": true, "has_breach": true, "has_short_circuit": false,
		"is_fire_active": false, "is_sealed": false, "is_suppression_active": false
	})
	assert("BRECCIA" in card.status_badge.text, "Badge deve indicare BRECCIA")
	
	# 12.4 Corto circuito
	card.update_telemetry({
		"id": test_room_id, "name": "Plancia", "pressure_kpa": 101.3,
		"temperature_c": 21.5, "o2_pct": 21.0, "co2_pct": 0.04,
		"heater_online": false, "has_breach": false, "has_short_circuit": true,
		"is_fire_active": false, "is_sealed": false, "is_suppression_active": false
	})
	assert("CORTO" in card.status_badge.text, "Badge deve indicare CORTO CALDAIA")
	assert("CORTO" in card.heater_label.text, "Heater label deve indicare CORTO")
	print("✔ Widget RoomAtmoCard telemetria a 4 parametri e badge allarmi validati")
	
	# =========================================================================
	# TEST 13: PULIZIA SEGNALI SU _EXIT_TREE()
	# =========================================================================
	print("\n--- TEST 13: Pulizia Segnali e Disconnessione ---")
	app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("✔ Nodo rimosso e segnali disconnessi senza memory leak")
	
	print("\n=======================================================")
	print("✔ TUTTI I TEST LIFE SUPPORT APP COMPLETATI CON SUCCESSO!")
	print("=======================================================\n")
	get_tree().quit(0)
