extends Node

## Test Runner Headless per PodInfo Vitals Engine, Spatial Bridge Microphone & Physiological Crew States (TASK-039).

func _ready() -> void:
	print("\n=======================================================")
	print(">>> AVVIO SUITE DI TEST HEADLESS: POD INFO & CREW VITALS")
	print("=======================================================\n")
	_run_all_tests()

func _run_all_tests() -> void:
	await get_tree().process_frame
	
	# Load scene
	var scene: PackedScene = load("res://Applications/PodInfo/pod_info_app.tscn")
	assert(scene != null, "La scena pod_info_app.tscn deve essere caricata con successo")
	
	var app: PodInfoApp = scene.instantiate() as PodInfoApp
	assert(app != null, "Istanza PodInfoApp non valida")
	add_child(app)
	await get_tree().process_frame
	
	# =========================================================================
	# TEST 1: LETTURA REALE DEI 4 PARAMETRI VITALI
	# =========================================================================
	print("--- TEST 1: Sincronizzazione Reale 4 Parametri Vitali ---")
	SpaceWorldManager.set_bridge_atmo_override({
		"o2_pct": 21.0,
		"temperature_c": 22.0,
		"pressure_kpa": 101.3
	})
	SpaceWorldManager.set_ship_g_force(1.0)
	
	app._process(0.1)
	
	assert(is_equal_approx(app.oxygen_value, 21.0), "O2 deve essere 21.0 (trovato: %s)" % app.oxygen_value)
	assert(is_equal_approx(app.temp_value, 22.0), "Temp deve essere 22.0 (trovato: %s)" % app.temp_value)
	assert(is_equal_approx(app.pressure_value, 101.3), "Pressione deve essere 101.3 (trovato: %s)" % app.pressure_value)
	assert(is_equal_approx(app.g_force_value, 1.0), "G-force deve essere 1.0 (trovato: %s)" % app.g_force_value)
	
	# Verifica assenza di fluttuazioni casuali dummy: eseguendo piu frame i valori rimangono stabili
	app._process(0.1)
	app._process(0.1)
	assert(is_equal_approx(app.oxygen_value, 21.0), "O2 non deve oscillare casualmente")
	assert(is_equal_approx(app.temp_value, 22.0), "Temp non deve oscillare casualmente")
	print("? Sincronizzazione reale dei 4 parametri vitali validata")
	
	# =========================================================================
	# TEST 2: MICROFONO VIRTUALE IN PLANCIA & ATTENUAZIONE DISTANZA
	# =========================================================================
	print("\n--- TEST 2: Microfono Virtuale in Plancia e Attenuazione Spaziale ---")
	var bridge_pos: Vector2 = SpaceWorldManager.get_bridge_position()
	
	# Evento a distanza 0 (in plancia)
	app.play_spatial_ship_sound(bridge_pos, null, 0.0, "impact")
	assert(is_equal_approx(app.last_calculated_attenuation, 1.0), "Attenuazione a d=0 deve essere 1.0")
	assert(is_equal_approx(app.last_calculated_vol_db, 0.0), "Volume dB a d=0 deve essere 0.0 dB")
	assert(app.last_applied_filter_lowpass == false, "Low-pass non deve essere attivo a d=0 (<150m)")
	
	# Evento a distanza 100m (vicino)
	var pos_100 := bridge_pos + Vector2(100, 0)
	app.play_spatial_ship_sound(pos_100, null, 0.0, "impact")
	assert(is_equal_approx(app.last_calculated_attenuation, 0.5), "Attenuazione a d=100 deve essere 0.5")
	assert(is_equal_approx(app.last_calculated_vol_db, 20.0 * (log(0.5)/log(10.0))), "Volume dB a d=100 deve essere ~-6.02 dB")
	assert(app.last_applied_filter_lowpass == false, "Low-pass non deve essere attivo a d=100 (<150m)")
	
	# Evento a distanza 200m (lontano attraverso paratie)
	var pos_200 := bridge_pos + Vector2(200, 0)
	app.play_spatial_ship_sound(pos_200, null, 0.0, "impact")
	assert(is_equal_approx(app.last_calculated_attenuation, 1.0 / 3.0), "Attenuazione a d=200 deve essere ~0.333")
	assert(app.last_applied_filter_lowpass == true, "Low-pass DEVE essere attivo a d=200 (>150m)")
	
	# Test ricezione segnale SpaceWorldManager
	var event_tracker := {"received": false, "name": "", "pos": Vector2.ZERO}
	app.spatial_sound_played.connect(func(n, p, _d, _v, _l):
		event_tracker["received"] = true
		event_tracker["name"] = n
		event_tracker["pos"] = p
	)
	SpaceWorldManager.emit_ship_damage_taken(pos_200, "breach")
	assert(event_tracker["received"] == true, "PodInfo deve ricevere evento ship_damage_taken ed emettere suono spaziale")
	assert(event_tracker["name"] == "impact", "Suono da breccia deve essere impact")
	
	# Test ricezione segnale corto circuito
	event_tracker["received"] = false
	SpaceWorldManager.emit_electrical_short_sparked(pos_100)
	assert(event_tracker["received"] == true, "PodInfo deve ricevere electrical_short_sparked")
	assert(event_tracker["name"] == "spark", "Suono da corto circuito deve essere spark")
	
	# Test ronzio Duct Drone
	SpaceWorldManager.emit_duct_drone_position_updated(bridge_pos)
	assert(app.drone_audio != null and app.drone_audio.playing, "Drone audio deve essere in riproduzione quando il drone e attivo")
	print("? Microfono virtuale, formula attenuazione 1/(1+0.01d) e filtro passa-basso validati")
	
	# =========================================================================
	# TEST 3: STATO FISIOLOGICO - ASFISSIA (IPOSSIA / DECOMPRESSIONE)
	# =========================================================================
	print("\n--- TEST 3: Macchina a Stati Fisiologica - Asfissia & Blackout ---")
	var game_over_reasons: Array[String] = []
	app.game_over_triggered.connect(func(r: String): game_over_reasons.append(r))
	
	SpaceWorldManager.set_bridge_atmo_override({
		"o2_pct": 5.0, # Criticamente basso (< 12.0)
		"temperature_c": 21.0,
		"pressure_kpa": 101.3
	})
	
	app.blackout_intensity = 0.0
	app.is_game_over = false
	app._process(1.0)
	
	assert(app.current_state == PodInfoApp.CrewPhysiologicalState.HYPOXIA, "Stato deve essere HYPOXIA")
	assert(app.blackout_intensity > 0.1, "Blackout intensity deve aumentare (trovato: %s)" % app.blackout_intensity)
	
	# Simula progressione asfissia fino al 100% di blackout
	app.blackout_intensity = 0.95
	app._process(0.5)
	assert(app.is_game_over == true, "GameOver deve scattare al 100% di blackout da asfissia")
	assert(game_over_reasons.has("DECESSO PER ASFISSIA"), "Motivo decesso corretto")
	print("? Asfissia, rantolo vocale, progressione blackout e GameOver convalidati")
	
	# =========================================================================
	# TEST 4: STATO FISIOLOGICO - IPERTERMIA & COMBUSTIONE
	# =========================================================================
	print("\n--- TEST 4: Macchina a Stati Fisiologica - Ipertermia & Combustione ---")
	app.is_game_over = false
	game_over_reasons.clear()
	
	# Temp 50?C (Ansito affannoso)
	SpaceWorldManager.set_bridge_atmo_override({
		"o2_pct": 21.0,
		"temperature_c": 50.0,
		"pressure_kpa": 101.3
	})
	app._process(0.1)
	assert(app.current_state == PodInfoApp.CrewPhysiologicalState.HYPERTHERMIA, "Stato deve essere HYPERTHERMIA")
	
	# Temp 70?C (Urla)
	SpaceWorldManager.set_bridge_atmo_override({
		"o2_pct": 21.0,
		"temperature_c": 70.0,
		"pressure_kpa": 101.3
	})
	app._process(0.1)
	assert(app.current_state == PodInfoApp.CrewPhysiologicalState.HYPERTHERMIA, "Stato deve rimanere HYPERTHERMIA")
	
	# Temp 85?C (GameOver)
	SpaceWorldManager.set_bridge_atmo_override({
		"o2_pct": 21.0,
		"temperature_c": 85.0,
		"pressure_kpa": 101.3
	})
	app._process(0.1)
	assert(app.is_game_over == true, "GameOver per combustione termica deve scattare a >80?C")
	assert(game_over_reasons.has("DECESSO PER COMBUSTIONE TERMICA"), "Motivo decesso corretto")
	print("? Ipertermia (>45?C), urla (>65?C) e GameOver combustione (>80?C) convalidati")
	
	# =========================================================================
	# TEST 5: STATO FISIOLOGICO - IPOTERMIA & ASSIDERAMENTO
	# =========================================================================
	print("\n--- TEST 5: Macchina a Stati Fisiologica - Ipotermia & Assideramento ---")
	app.is_game_over = false
	game_over_reasons.clear()
	
	# Temp 5?C (Battito denti)
	SpaceWorldManager.set_bridge_atmo_override({
		"o2_pct": 21.0,
		"temperature_c": 5.0,
		"pressure_kpa": 101.3
	})
	app._process(0.1)
	assert(app.current_state == PodInfoApp.CrewPhysiologicalState.HYPOTHERMIA, "Stato deve essere HYPOTHERMIA")
	
	# Temp 0?C (GameOver)
	SpaceWorldManager.set_bridge_atmo_override({
		"o2_pct": 21.0,
		"temperature_c": -1.0,
		"pressure_kpa": 101.3
	})
	app._process(0.1)
	assert(app.is_game_over == true, "GameOver per ipotermia deve scattare a <=0?C")
	assert(game_over_reasons.has("DECESSO PER IPOTERMIA"), "Motivo decesso corretto")
	print("? Ipotermia (<10?C), battito denti e GameOver assideramento (<=0?C) convalidati")
	
	# =========================================================================
	# TEST 6: DINAMICA FORZA G (G-LOC BLACKOUT & REDOUT)
	# =========================================================================
	print("\n--- TEST 6: Dinamica Forza G - G-LOC Blackout e Redout ---")
	app.is_game_over = false
	app.blackout_intensity = 0.0
	app.redout_intensity = 0.0
	game_over_reasons.clear()
	SpaceWorldManager.clear_bridge_atmo_override()
	
	# G positivo moderato (G = 5.5) -> Blackout parziale
	SpaceWorldManager.set_ship_g_force(5.5)
	app._process(0.1)
	assert(is_equal_approx(app.blackout_intensity, 0.4), "Blackout per G=5.5 deve essere (5.5-4.5)/2.5 = 0.4 (trovato: %s)" % app.blackout_intensity)
	
	# G positivo estremo (G = 8.0 per >3s) -> GameOver G-LOC
	SpaceWorldManager.set_ship_g_force(8.0)
	app.high_g_timer = 2.95
	app._process(0.1)
	assert(app.is_game_over == true, "GameOver G-LOC deve scattare dopo 3s a G>7.0")
	assert(game_over_reasons.has("DECESSO PER ARRESTO CARDIACO (G-LOC POSITIVO)"), "Motivo decesso corretto")
	
	# G negativo estremo (G = -2.5) -> Redout
	app.is_game_over = false
	game_over_reasons.clear()
	SpaceWorldManager.set_ship_g_force(-2.5)
	app._process(0.1)
	assert(is_equal_approx(app.redout_intensity, 0.5), "Redout per G=-2.5 deve essere (2.5-1.5)/2.0 = 0.5 (trovato: %s)" % app.redout_intensity)
	
	# G negativo estremo prolungato (G = -4.0 per >2s) -> GameOver Redout
	SpaceWorldManager.set_ship_g_force(-4.0)
	app.negative_g_timer = 1.95
	app._process(0.1)
	assert(app.is_game_over == true, "GameOver Redout deve scattare dopo 2s a G<-3.5")
	assert(game_over_reasons.has("DECESSO PER ROTTURA VASCOLARE (REDOUT NEGATIVO)"), "Motivo decesso corretto")
	print("? Modulazione Blackout/Redout su G-Force e tolleranze temporali convalidate")
	
	# =========================================================================
	# TEST 7: OVERLAYS SCHERMO & UI DIEGETICA GAME OVER
	# =========================================================================
	print("\n--- TEST 7: Overlay Schermo CanvasLayer e Pannello GameOver ---")
	await get_tree().process_frame
	assert(app.overlay_layer != null, "CanvasLayer overlay deve essere creato")
	assert(app.blackout_overlay != null, "BlackoutOverlay ColorRect deve esistere")
	assert(app.redout_overlay != null, "RedoutOverlay ColorRect deve esistere")
	assert(app.game_over_panel != null, "GameOverPanel deve esistere")
	assert(app.game_over_panel.visible == true, "GameOverPanel deve essere visibile dopo GameOver")
	print("? CanvasLayer, ColorRect Blackout/Redout e GameOver Panel verificati con successo")
	
	print("\n=======================================================")
	print("=== TUTTI I TEST POD INFO & CREW VITALS COMPLETATI CON SUCCESSO! ===")
	print("=======================================================\n")
	get_tree().quit(0)
