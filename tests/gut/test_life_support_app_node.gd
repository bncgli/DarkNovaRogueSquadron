extends GutTest

## Test GUT per l'applicazione LifeSupport (O2/CO2, pressione, temperatura,
## paratie stagne, soppressione incendi e simulazione atmosferica per stanza).
## Migrato da tests/test_life_support_app_node.gd (extends Node, assert() nudo).

var _app: LifeSupportApp = null

func before_each() -> void:
	_app = null
	if SpaceWorldManager and "sealed_rooms" in SpaceWorldManager:
		SpaceWorldManager.sealed_rooms.clear()
	NetworkManager.disconnect_game()

func after_each() -> void:
	if is_instance_valid(_app):
		_app.queue_free()
	_app = null
	if SpaceWorldManager and "sealed_rooms" in SpaceWorldManager:
		SpaceWorldManager.sealed_rooms.clear()
	NetworkManager.disconnect_game()

func _start_solo_mission(player_name: String = "Comandante Test") -> void:
	NetworkManager.start_solo_game(player_name)
	NetworkManager.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame

func _create_app() -> LifeSupportApp:
	var scene: PackedScene = load("res://Applications/LifeSupport/life_support_app.tscn")
	assert_not_null(scene, "Scena life_support_app.tscn deve essere caricabile")
	var app: LifeSupportApp = scene.instantiate() as LifeSupportApp
	add_child_autofree(app)
	await get_tree().process_frame
	return app

func test_disconnected_overlay_lifecycle() -> void:
	_app = await _create_app()
	assert_not_null(_app.disconnected_overlay, "%DisconnectedOverlay deve esistere nella scena")
	assert_true(_app.disconnected_overlay.visible, "%DisconnectedOverlay deve essere VISIBILE quando la nave è offline")
	
	await _start_solo_mission()
	
	assert_false(_app.disconnected_overlay.visible, "%DisconnectedOverlay deve SCOMPARIRE quando la nave è connessa")

func test_rbac_permissions_matrix_for_crew_roles() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	# NOTA: a differenza di altre app (es. FlightControl), can_control_life_support
	# usa is_solo_mode SOLO come fallback per ruolo vuoto: una volta assegnato un
	# ruolo esplicito con request_role(), la modalità Solo non ha più effetto,
	# quindi non serve disattivarla per validare la matrice RBAC sui ruoli.
	NetworkManager.request_role(NetworkManager.ROLE_PILOT)
	await get_tree().process_frame
	assert_false(_app.can_control_life_support, "Pilota non deve avere controllo attivo sul supporto vitale")
	assert_true(_app.btn_toggle_seal.disabled, "BtnToggleSeal deve essere disabilitato per Pilota")
	assert_true(_app.btn_suppress_fire.disabled, "BtnSuppressFire deve essere disabilitato per Pilota")
	
	NetworkManager.request_role(NetworkManager.ROLE_SOLDIER)
	await get_tree().process_frame
	assert_false(_app.can_control_life_support, "Soldato non deve avere controllo attivo sul supporto vitale")
	assert_true(_app.btn_toggle_seal.disabled, "BtnToggleSeal deve essere disabilitato per Soldato")
	assert_true(_app.btn_suppress_fire.disabled, "BtnSuppressFire deve essere disabilitato per Soldato")
	
	NetworkManager.request_role(NetworkManager.ROLE_HACKER)
	await get_tree().process_frame
	assert_false(_app.can_control_life_support, "Hacker non deve avere controllo attivo sul supporto vitale")
	
	NetworkManager.request_role(NetworkManager.ROLE_ENGINEER)
	await get_tree().process_frame
	assert_true(_app.can_control_life_support, "Ingegnere deve avere controllo completo sul supporto vitale")
	assert_false(_app.btn_toggle_seal.disabled, "BtnToggleSeal deve essere abilitato per Ingegnere")
	assert_false(_app.btn_suppress_fire.disabled, "BtnSuppressFire deve essere abilitato per Ingegnere")
	
	NetworkManager.request_role(NetworkManager.ROLE_CAPTAIN)
	await get_tree().process_frame
	assert_true(_app.can_control_life_support, "Capitano deve avere controllo completo sul supporto vitale")
	
	NetworkManager.request_role(NetworkManager.ROLE_STAGISTA)
	await get_tree().process_frame
	assert_true(_app.can_control_life_support, "Stagista deve avere controllo completo sul supporto vitale")

func test_app_resource_registered_in_ship_software_manager() -> void:
	var ssm := get_node_or_null("/root/ShipSoftwareManager") as ShipSoftwareManagerSingleton
	assert_not_null(ssm, "ShipSoftwareManager singleton deve essere attivo")
	
	var res: AppResource = ssm.get_registered_app("life_support")
	assert_not_null(res, "life_support_app.tres deve essere registrata nel catalogo ShipSoftwareManager")
	assert_eq(res.app_id, "life_support", "app_id deve corrispondere a 'life_support'")
	assert_eq(res.default_password, "LIFE-7815", "Password di default deve essere 'LIFE-7815'")
	assert_eq(res.power_draw_mw, 20.0, "power_draw_mw deve corrispondere a 20.0 MW")
	assert_true(res.default_files.size() >= 2, "La risorsa deve contenere life_support_config.dat e atmo_tuning.dat")

func test_dat_configuration_default_values_and_hot_reload() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app.load_dat_configuration()
	await get_tree().process_frame
	assert_true(_app.active_config.get("is_dat_loaded"), "Configurazioni .DAT devono essere caricate")
	assert_eq(_app.active_config.get("o2_generation_rate"), 1.2, "o2_generation_rate deve corrispondere a 1.2")
	assert_eq(_app.active_config.get("seal_door_speed"), 0.5, "seal_door_speed deve corrispondere a 0.5")
	assert_eq(_app.active_config.get("decompression_rate"), 1.8, "decompression_rate deve corrispondere a 1.8")
	assert_eq(_app.active_config.get("fire_suppression_co2_level"), 0.45, "fire_suppression_co2_level deve corrispondere a 0.45")
	assert_eq(_app.active_config.get("scrubber_efficiency"), 0.98, "scrubber_efficiency deve corrispondere a 0.98")
	
	# NOTA: il segnale file_synced e' dichiarato con un solo parametro (path); il
	# vecchio test lo emetteva erroneamente con un secondo argomento extra, il che
	# causa un errore quando altri listener con firma stretta (es. controller nave)
	# sono connessi allo stesso segnale. Emettiamo qui con la firma corretta.
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("file_synced"):
		sdm.file_synced.emit("Ship Drive/Programs/LifeSupport/life_support_config.dat")
		await get_tree().process_frame
		assert_true(_app.active_config.get("is_dat_loaded"), "Hot-reloading deve ricaricare la configurazione")
	
	_app.btn_reload_dat.emit_signal("pressed")
	await get_tree().process_frame
	assert_true(_app.active_config.get("is_dat_loaded"), "Pulsante ricarica .DAT deve rinfrescare la configurazione")

func test_bulkhead_seal_and_fire_suppression_controls() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	assert_true(_app.rooms_state.size() > 0, "Le stanze della nave devono essere popolate")
	assert_true(_app.room_card_widgets.size() > 0, "I widget RoomAtmoCard devono essere istanziati")
	var test_room_id: String = str(_app.rooms_state.keys()[0])
	
	assert_false(_app.rooms_state[test_room_id]["is_sealed"], "La paratia iniziale deve essere aperta")
	_app.set_bulkhead_sealed(test_room_id, true)
	await get_tree().process_frame
	assert_true(_app.rooms_state[test_room_id]["is_sealed"], "La paratia deve risultare sigillata")
	_app.set_bulkhead_sealed(test_room_id, false)
	await get_tree().process_frame
	assert_false(_app.rooms_state[test_room_id]["is_sealed"], "La paratia deve risultare riaperta")
	
	_app.rooms_state[test_room_id]["is_fire_active"] = true
	_app.trigger_fire_suppression(test_room_id)
	await get_tree().process_frame
	assert_false(_app.rooms_state[test_room_id]["is_fire_active"], "L'incendio deve essere estinto dall'iniezione")
	assert_true(_app.rooms_state[test_room_id]["is_suppression_active"], "Soppressione attiva deve essere true")
	
	_app.set_room_venting(test_room_id, true)
	await get_tree().process_frame
	assert_true(_app.rooms_state[test_room_id]["is_venting"], "Venting deve essere attivo")
	
	_app.normalize_room_atmosphere(test_room_id)
	await get_tree().process_frame
	assert_false(_app.rooms_state[test_room_id]["is_venting"], "Venting deve essere resettato")
	assert_eq(_app.rooms_state[test_room_id]["o2_pct"], 21.0, "O2 deve essere normalizzato a 21.0%")
	assert_eq(_app.rooms_state[test_room_id]["pressure_kpa"], 101.3, "Pressione deve essere normalizzata a 101.3 kPa")
	
	_app.btn_seal_all.emit_signal("pressed")
	await get_tree().process_frame
	for r_k in _app.rooms_state:
		assert_true(_app.rooms_state[r_k]["is_sealed"], "Tutte le stanze devono essere sigillate")
	
	_app.btn_suppress_all.emit_signal("pressed")
	await get_tree().process_frame
	for r_k in _app.rooms_state:
		assert_true(_app.rooms_state[r_k]["is_suppression_active"], "Tutte le stanze devono avere soppressione attiva")

func test_room_data_structure_and_public_telemetry_methods() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	var test_room_id: String = str(_app.rooms_state.keys()[0])
	
	var atmo_state: Dictionary = _app.get_room_atmo_state(test_room_id)
	assert_false(atmo_state.is_empty(), "get_room_atmo_state deve restituire i dati della stanza")
	for key in ["pressure_kpa", "temperature_c", "o2_pct", "co2_pct", "has_breach", "has_short_circuit", "heater_online", "is_fire_active", "is_sealed"]:
		assert_true(atmo_state.has(key), "Lo stato della stanza deve contenere '%s'" % key)
	
	var all_atmo := _app.get_all_rooms_atmo_state()
	assert_eq(all_atmo.size(), _app.rooms_state.size(), "get_all_rooms_atmo_state deve restituire tutte le stanze")
	
	var bridge_st := SpaceWorldManager.get_bridge_atmo_state()
	assert_true(bridge_st.has("pressure_kpa") and bridge_st.has("temperature_c"), "get_bridge_atmo_state deve restituire telemetria plancia")

func test_breach_rapid_decompression_extinguishes_fire() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	var test_room_id: String = str(_app.rooms_state.keys()[0])
	
	_app.normalize_room_atmosphere(test_room_id)
	_app.set_room_breach(test_room_id, true)
	_app.rooms_state[test_room_id]["is_fire_active"] = true
	await get_tree().process_frame
	
	for _i in range(10):
		_app._simulate_atmosphere_step(0.5)
	
	var breached_state: Dictionary = _app.get_room_atmo_state(test_room_id)
	assert_true(breached_state["pressure_kpa"] < 10.0, "La pressione deve crollare rapidamente su breccia (attuale: %f)" % breached_state["pressure_kpa"])
	assert_true(breached_state["o2_pct"] < 5.0, "L'ossigeno deve crollare su breccia (attuale: %f)" % breached_state["o2_pct"])
	assert_false(breached_state["is_fire_active"], "L'incendio deve estinguersi per mancanza di pressione/ossigeno")

func test_vacuum_thermal_decay_below_one_kpa() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	var test_room_id: String = str(_app.rooms_state.keys()[0])
	
	# NOTA: il vecchio test impostava solo pressure_kpa=0.0 senza has_breach=true.
	# Nel codice attuale, senza una breccia attiva la stanza si ripressurizza
	# automaticamente verso 101.3 kPa PRIMA del controllo termico nello stesso step
	# di simulazione, quindi la condizione "pressure_kpa <= 1.0" non si verifica mai
	# e la temperatura non decade: era una condizione di test obsoleta/irrealistica.
	# Simuliamo invece una vera decompressione da breccia, che mantiene la stanza
	# nel vuoto e attiva correttamente il decadimento termico.
	_app.rooms_state[test_room_id]["pressure_kpa"] = 0.0
	_app.rooms_state[test_room_id]["temperature_c"] = 21.5
	_app.rooms_state[test_room_id]["heater_online"] = true
	_app.set_room_breach(test_room_id, true)
	
	for _i in range(5):
		_app._simulate_atmosphere_step(0.5)
	
	var vacuum_state: Dictionary = _app.get_room_atmo_state(test_room_id)
	assert_true(vacuum_state["pressure_kpa"] <= 1.0, "La stanza in breccia deve rimanere nel vuoto (attuale: %f kPa)" % vacuum_state["pressure_kpa"])
	assert_true(vacuum_state["temperature_c"] < 1.0, "Nel vuoto la temperatura deve decadere verso 0.0 °C (attuale: %f)" % vacuum_state["temperature_c"])

func test_short_circuit_disables_heater_and_cools_room() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	var test_room_id: String = str(_app.rooms_state.keys()[0])
	
	_app.normalize_room_atmosphere(test_room_id)
	assert_true(_app.rooms_state[test_room_id]["heater_online"], "La caldaia deve essere online inizialmente")
	
	_app.set_room_short_circuit(test_room_id, true)
	_app._simulate_atmosphere_step(0.1)
	assert_false(_app.rooms_state[test_room_id]["heater_online"], "La caldaia deve spegnersi con corto circuito")
	
	var prev_temp: float = _app.rooms_state[test_room_id]["temperature_c"]
	for _i in range(10):
		_app._simulate_atmosphere_step(0.5)
	var cooled_temp: float = _app.rooms_state[test_room_id]["temperature_c"]
	assert_true(cooled_temp < prev_temp, "La temperatura deve diminuire progressivamente a caldaia spenta")
	
	_app.set_room_short_circuit(test_room_id, false)
	_app._simulate_atmosphere_step(0.1)
	assert_true(_app.rooms_state[test_room_id]["heater_online"], "La caldaia deve tornare online a riparazione effettuata")
	
	for _i in range(10):
		_app._simulate_atmosphere_step(0.5)
	assert_true(_app.rooms_state[test_room_id]["temperature_c"] > cooled_temp, "La temperatura deve risalire verso 21.5°C")

func test_fire_dynamics_and_critical_thermal_peak() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	var test_room_id: String = str(_app.rooms_state.keys()[0])
	
	_app.normalize_room_atmosphere(test_room_id)
	_app.set_room_fire(test_room_id, true)
	
	for _i in range(10):
		_app._simulate_atmosphere_step(0.5)
	
	var fire_state: Dictionary = _app.get_room_atmo_state(test_room_id)
	assert_true(fire_state["temperature_c"] > 100.0, "L'incendio deve elevare la temperatura a picchi critici (attuale: %f)" % fire_state["temperature_c"])
	assert_true(fire_state["o2_pct"] < 21.0, "L'incendio deve consumare ossigeno (attuale: %f)" % fire_state["o2_pct"])

func test_atmosphere_anomaly_signal_emission() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	var test_room_id: String = str(_app.rooms_state.keys()[0])
	
	var detected_anomalies: Array[String] = []
	var anomaly_callable := func(r_id: String, a_type: String) -> void:
		if r_id == test_room_id:
			detected_anomalies.append(a_type)
	
	_app.atmosphere_anomaly_detected.connect(anomaly_callable)
	_app.normalize_room_atmosphere(test_room_id)
	_app._room_anomalies.clear()
	
	_app.set_room_fire(test_room_id, true)
	_app._simulate_atmosphere_step(0.1)
	assert_true(detected_anomalies.has("FIRE"), "Il segnale deve notificare l'anomalia FIRE")
	
	_app.set_room_breach(test_room_id, true)
	_app._simulate_atmosphere_step(0.1)
	assert_true(detected_anomalies.has("BREACH"), "Il segnale deve notificare l'anomalia BREACH")
	
	_app.set_room_short_circuit(test_room_id, true)
	_app._simulate_atmosphere_step(0.1)
	assert_true(detected_anomalies.has("SHORT_CIRCUIT"), "Il segnale deve notificare l'anomalia SHORT_CIRCUIT")
	
	_app.atmosphere_anomaly_detected.disconnect(anomaly_callable)

func test_room_atmo_card_widget_telemetry_and_alarm_badges() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	var test_room_id: String = str(_app.rooms_state.keys()[0])
	
	var card: RoomAtmoCard = _app.room_card_widgets[test_room_id] as RoomAtmoCard
	assert_not_null(card, "La scheda stanza per test_room_id deve esistere")
	assert_not_null(card.pressure_label, "pressure_label deve essere presente nel widget")
	assert_not_null(card.temp_label, "temp_label deve essere presente nel widget")
	assert_not_null(card.heater_label, "heater_label deve essere presente nel widget")
	assert_not_null(card.status_badge, "status_badge deve essere presente nel widget")
	
	card.update_telemetry({
		"id": test_room_id, "name": "Plancia", "pressure_kpa": 101.3,
		"temperature_c": 21.5, "o2_pct": 21.0, "co2_pct": 0.04,
		"heater_online": true, "has_breach": false, "has_short_circuit": false,
		"is_fire_active": false, "is_sealed": false, "is_suppression_active": false
	})
	assert_eq(card.status_badge.text, "● NORMALE", "Badge deve essere ● NORMALE")
	assert_eq(card.heater_label.text, "Caldaia: ON", "Heater label deve essere Caldaia: ON")
	
	card.update_telemetry({
		"id": test_room_id, "name": "Plancia", "pressure_kpa": 101.3,
		"temperature_c": 21.5, "o2_pct": 21.0, "co2_pct": 0.04,
		"heater_online": true, "has_breach": false, "has_short_circuit": false,
		"is_fire_active": true, "is_sealed": false, "is_suppression_active": false
	})
	assert_true("INCENDIO" in card.status_badge.text, "Badge deve indicare INCENDIO")
	
	card.update_telemetry({
		"id": test_room_id, "name": "Plancia", "pressure_kpa": 101.3,
		"temperature_c": 21.5, "o2_pct": 21.0, "co2_pct": 0.04,
		"heater_online": true, "has_breach": true, "has_short_circuit": false,
		"is_fire_active": false, "is_sealed": false, "is_suppression_active": false
	})
	assert_true("BRECCIA" in card.status_badge.text, "Badge deve indicare BRECCIA")
	
	card.update_telemetry({
		"id": test_room_id, "name": "Plancia", "pressure_kpa": 101.3,
		"temperature_c": 21.5, "o2_pct": 21.0, "co2_pct": 0.04,
		"heater_online": false, "has_breach": false, "has_short_circuit": true,
		"is_fire_active": false, "is_sealed": false, "is_suppression_active": false
	})
	assert_true("CORTO" in card.status_badge.text, "Badge deve indicare CORTO CALDAIA")
	assert_true("CORTO" in card.heater_label.text, "Heater label deve indicare CORTO")

func test_queue_free_cleanup_does_not_error() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	_app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_app = null
	assert_true(true, "La rimozione dell'app LifeSupport non deve generare errori di pulizia dei segnali")

func test_ship_blueprint_canvas_and_interactive_room_selection() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	NetworkManager.request_role(NetworkManager.ROLE_ENGINEER)
	await get_tree().process_frame
	
	assert_not_null(_app.map_canvas, "MapCanvas deve esistere nella scena LifeSupport")
	assert_true(_app.rooms.size() > 0, "Le stanze blueprint devono essere caricate")
	
	# Verifica che ogni stanza sia selezionabile
	var target_room: Dictionary = _app.rooms[1]
	var target_id: String = str(target_room.get("id"))
	var target_rect: Rect2 = target_room.get("rect")
	
	# Simula click del mouse al centro della stanza nel canvas blueprint
	_app.map_canvas.custom_minimum_size = Vector2(600, 480)
	_app.map_canvas.size = Vector2(600, 480)
	
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = target_rect.get_center()
	
	_app.handle_blueprint_gui_input(_app.map_canvas, click_event)
	await get_tree().process_frame
	
	assert_eq(_app.selected_room_id, target_id, "La stanza cliccata deve diventare selected_room_id")
	assert_true(target_room.get("name") in _app.selected_room_title.text, "Il pannello destro deve mostrare il nome della stanza selezionata")
	
	# Test selezione esplicita e verifica funzionalità del pannello di destra
	var engines_room_id := ""
	for r in _app.rooms:
		if r.get("id") == "engines":
			engines_room_id = "engines"
			break
	if engines_room_id.is_empty():
		engines_room_id = str(_app.rooms[0].get("id"))
	
	_app.select_room(engines_room_id)
	await get_tree().process_frame
	assert_eq(_app.selected_room_id, engines_room_id, "select_room deve impostare la stanza selezionata")
	assert_true(_app.can_control_life_support, "Controllo attivo abilitato")
	
	# Test azione di sigillatura dal pannello destro per la stanza selezionata
	_app._on_toggle_seal_pressed()
	await get_tree().process_frame
	assert_true(_app.is_room_sealed(engines_room_id), "Il pulsante destro deve sigillare la stanza selezionata")
	assert_eq(_app.btn_toggle_seal.text, "🔓 Apri Paratia", "Il testo del pulsante deve indicare 'Apri Paratia'")
	
	# Dissigilla
	_app._on_toggle_seal_pressed()
	await get_tree().process_frame
	assert_false(_app.is_room_sealed(engines_room_id), "Il pulsante destro deve riaprire la paratia")
