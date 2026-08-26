extends Node

func _ready() -> void:
	print("--- INIZIO TEST DUCT DRONE CON AUTOLOADS ATTIVI ---")
	
	# 1. Verifica avvio a freddo (prima di qualsiasi connessione / missione)
	var app_scene: PackedScene = load("res://Applications/DuctDrone/duct_drone_app.tscn")
	assert(app_scene != null, "Scena duct_drone_app.tscn caricata con successo")
	
	var app: DuctDroneApp = app_scene.instantiate() as DuctDroneApp
	assert(app != null, "Istanza DuctDroneApp creata con successo")
	add_child(app)
	print("✔ DuctDroneApp aggiunta all'albero di scena")
	
	# Verifica che l'app sia operativa all'avvio a freddo (senza blocchi overlay)
	assert(app.is_operational() == true, "L'app deve risultare operativa all'avvio a freddo")
	assert(app.disconnected_overlay.visible == false, "DisconnectedOverlay deve essere nascosto all'avvio")
	assert(app.can_control == true, "Controllo attivo all'avvio")
	
	# 2. Verifica che tutti i pulsanti abbiano focus_mode disabilitato per evitare focus trapping da tastiera
	var buttons: Array[Button] = [
		app.btn_forward, app.btn_backward, app.btn_rot_left, app.btn_rot_right,
		app.btn_stop, app.btn_reset, app.btn_speed_mode, app.btn_lights_toggle, app.btn_scan_pulse
	]
	for b in buttons:
		assert(b != null, "Pulsante UI deve esistere")
		assert(b.focus_mode == Control.FOCUS_NONE, "Il focus_mode del pulsante %s deve essere FOCUS_NONE" % b.name)
	print("✔ Focus mode di tutti i pulsanti impostato correttamente su FOCUS_NONE")
	
	# 3. Avvia sessione Solo e missione
	if NetworkManager:
		NetworkManager.start_solo_game("TesterDrone")
		NetworkManager.start_mission()
	
	assert(SpaceWorldManager != null, "SpaceWorldManager autoload deve essere attivo")
	print("✔ Connessione Spaziale e NetworkManager attivi")
	
	# 4. Verifica stato iniziale
	var initial_pos := app.drone_pos
	var initial_heading := app.drone_heading
	print("✔ Posizione iniziale robottino: %s, Prua iniziale: %f" % [initial_pos, initial_heading])
	
	# 5. Test Rotazione Tank (Ruota a Sinistra / Ruota a Destra)
	print("✔ Test Rotazioni Tank (Sinistra / Destra)...")
	# Ruota a Destra (Oraria)
	app._ui_angular_input = 1.0
	app._process(0.2)
	SpaceWorldManager._physics_process(0.2)
	app._process(0.01)
	assert(app.drone_heading > initial_heading, "Rotazione oraria (a destra) avvenuta con successo")
	app._ui_angular_input = 0.0
	
	var turned_heading := app.drone_heading
	# Ruota a Sinistra (Antioraria)
	app._ui_angular_input = -1.0
	app._process(0.2)
	SpaceWorldManager._physics_process(0.2)
	app._process(0.01)
	assert(app.drone_heading < turned_heading, "Rotazione antioraria (a sinistra) avvenuta con successo")
	app._ui_angular_input = 0.0
	
	# 6. Test Movimento Tank (Avanti / Indietro)
	print("✔ Test Movimento Tank Lineare (Avanti / Indietro)...")
	# Imposta orientamento verso il basso/Sud (PI/2) per scendere lungo il condotto dorsale
	SpaceWorldManager.duct_drone_heading = PI * 0.5
	app.drone_heading = PI * 0.5
	app._ui_linear_input = 1.0
	for i in range(10):
		app._process(0.05)
		SpaceWorldManager._physics_process(0.05)
	app._process(0.01)
	assert(app.drone_pos.y > initial_pos.y, "Spostamento in avanti nella direzione di prua avvenuto con successo")
	assert(app.drone_current_speed > 0.0, "Velocità lineare positiva durante avanzamento")
	app._ui_linear_input = 0.0
	
	# Freno
	app._on_stop_pressed()
	SpaceWorldManager._physics_process(0.05)
	app._process(0.01)
	assert(app.drone_current_speed == 0.0, "Pulsante Stop arresta immediatamente il robottino")
	
	var advanced_pos := app.drone_pos
	# Retromarcia
	app._ui_linear_input = -1.0
	for i in range(5):
		app._process(0.05)
		SpaceWorldManager._physics_process(0.05)
	app._process(0.01)
	assert(app.drone_pos.y < advanced_pos.y, "Retromarcia indietro avvenuta con successo")
	app._ui_linear_input = 0.0
	app._on_stop_pressed()
	
	# 7. Test Ciclo Modalità Velocità
	print("✔ Test Modalità Velocità...")
	assert(app._speed_multiplier == 1.0, "Velocità iniziale 1.0x")
	app._on_speed_mode_toggle()
	assert(app._speed_multiplier == 2.0, "Velocità Turbo 2.0x")
	app._on_speed_mode_toggle()
	assert(app._speed_multiplier == 0.5, "Velocità Precisione 0.5x")
	app._on_speed_mode_toggle()
	assert(app._speed_multiplier == 1.0, "Ritorno a Normale 1.0x")
	
	# 8. Test Fari e Sonar
	print("✔ Test Toggle Fari e Sonar Scanner...")
	assert(app.lights_enabled == true, "Fari inizialmente ON")
	app._on_lights_toggle()
	app._process(0.01)
	assert(app.lights_enabled == false, "Fari impostati su OFF")
	app._on_lights_toggle()
	app._process(0.01)
	assert(app.lights_enabled == true, "Fari riaccesi su ON")
	
	app._on_scan_pulse_pressed()
	app._process(0.01)
	assert(app.scan_pulse_active == true, "Impulso Sonar attivato")
	SpaceWorldManager._physics_process(0.1)
	app._process(0.01)
	assert(app.scan_pulse_radius > 5.0, "Raggio impulso Sonar in espansione")
	
	# 9. Test Reset alla Base Dock
	print("✔ Test Reset Posizione...")
	app._on_reset_pressed()
	SpaceWorldManager._physics_process(0.01)
	app._process(0.01)
	assert(app.drone_pos == app.initial_drone_pos, "Robottino riposizionato alla base dock")
	assert(app.drone_battery == 100.0, "Batteria ricaricata al 100% dopo reset")
	
	# 10. Test Sincronizzazione Multiplayer tra Client e Host
	print("✔ Test Sincronizzazione Multiplayer Posizione e Stato...")
	# Simula arrivo di stato sincronizzato da remoto su SpaceWorldManager
	var synced_test_pos := Vector2(300, 250)
	var synced_test_heading := 0.785
	SpaceWorldManager.apply_synced_duct_drone_state(synced_test_pos, synced_test_heading, 42.0, 85.0, false, false, 0.0)
	app._process(0.01)
	assert(app.drone_pos == synced_test_pos, "Posizione robottino sincronizzata correttamente da remoto")
	assert(app.drone_heading == synced_test_heading, "Prua robottino sincronizzata correttamente da remoto")
	assert(app.drone_battery == 85.0, "Batteria sincronizzata da remoto")
	assert(app.lights_enabled == false, "Fari sincronizzati da remoto")
	
	# Test ricezione reset sincronizzato da host
	SpaceWorldManager._rpc_sync_duct_drone_reset()
	app._process(0.01)
	assert(app.drone_pos == app.initial_drone_pos, "Reset sincronizzato da remoto applicato correttamente")
	
	# 11. Test Sistema Danni Nave (Brecce & Cortocircuiti), Rilevamento e Riparazione
	print("✔ Test Sistema Danni Nave: Brecce, Cortocircuiti, Fari, Radar e Riparazioni...")
	SpaceWorldManager.clear_ship_damages()
	
	# Crea una breccia a (300, 160) e un cortocircuito a (300, 240)
	var breach_dmg := SpaceWorldManager.spawn_ship_damage(SpaceWorldManager.DAMAGE_TYPE_BREACH, Vector2(300, 160), "Condotto Dorsale", 4.0)
	var short_dmg := SpaceWorldManager.spawn_ship_damage(SpaceWorldManager.DAMAGE_TYPE_SHORT_CIRCUIT, Vector2(300, 240), "Condotto Reattore", 5.0)
	
	assert(breach_dmg.get("revealed") == false, "Le brecce devono essere inizialmente invisibili")
	assert(short_dmg.get("revealed") == false, "I cortocircuiti devono essere inizialmente invisibili")
	assert(breach_dmg.get("repair_duration") >= 3.0 and breach_dmg.get("repair_duration") <= 8.0, "Durata riparazione breccia tra 3 e 8 secondi")
	assert(short_dmg.get("repair_duration") >= 3.0 and short_dmg.get("repair_duration") <= 8.0, "Durata riparazione corto tra 3 e 8 secondi")
	
	# Test Rilevamento Breccia tramite Luce / Fari
	# Posiziona il drone sopra la breccia con fari spenti: non deve scoprirla
	SpaceWorldManager.duct_drone_pos = Vector2(300, 155)
	SpaceWorldManager.duct_drone_lights = false
	SpaceWorldManager._physics_process(0.1)
	assert(breach_dmg.get("revealed") == false, "Breccia invisibile se i fari sono spenti")
	
	# Accendi i fari: la breccia deve essere scoperta
	SpaceWorldManager.duct_drone_lights = true
	SpaceWorldManager._physics_process(0.1)
	assert(breach_dmg.get("revealed") == true, "Breccia rivelata quando illuminata dai fari/luce")
	assert(breach_dmg.get("revealed_by") == "light", "Breccia scoperta tramite luce")
	
	# Test Rilevamento Cortocircuito tramite Radar / Sonar
	# Posiziona il drone vicino al cortocircuito con fari accesi: i fari NON devono scoprire il corto
	SpaceWorldManager.duct_drone_pos = Vector2(300, 235)
	SpaceWorldManager._physics_process(0.1)
	assert(short_dmg.get("revealed") == false, "I cortocircuiti NON vengono scoperti dalla luce")
	
	# Attiva impulso sonar: quando l'onda radar raggiunge il corto, viene scoperto
	SpaceWorldManager.trigger_duct_drone_scan()
	SpaceWorldManager._physics_process(0.3)
	assert(short_dmg.get("revealed") == true, "Cortocircuito rilevato con successo dall'impulso Radar")
	assert(short_dmg.get("revealed_by") == "radar", "Cortocircuito scoperto tramite radar")
	
	# Test Prossimità e Azione di Riparazione con Barra di Caricamento (3-8s)
	print("✔ Test Riparazione con Barra di Progresso...")
	SpaceWorldManager.duct_drone_pos = Vector2(300, 160) # Adiacente alla breccia
	SpaceWorldManager._physics_process(0.01)
	app._process(0.01)
	assert(not app.nearby_damage.is_empty(), "Danno adiacente rilevato dall'app")
	assert(app.nearby_damage.get("id") == breach_dmg.get("id"), "Danno adiacente corrisponde alla breccia")
	
	# Avvia riparazione (simulando pressione tasto E / click pulsante)
	app._on_repair_button_pressed()
	assert(app.is_repairing == true or SpaceWorldManager.is_duct_drone_repairing == true, "Azione di riparazione avviata")
	
	var initial_batt := SpaceWorldManager.duct_drone_battery
	# Avanza la simulazione per metà della durata
	for step in range(25):
		SpaceWorldManager._physics_process(0.1)
		app._process(0.01)
	
	assert(breach_dmg.get("repair_progress") > 0.4, "Progresso di riparazione in avanzamento")
	assert(breach_dmg.get("repaired") == false, "Riparazione non ancora completata a metà tempo")
	assert(SpaceWorldManager.duct_drone_battery < initial_batt, "La riparazione e i sistemi attivi scaricano la batteria più velocemente")
	
	# Completa la riparazione
	for step in range(30):
		SpaceWorldManager._physics_process(0.1)
		app._process(0.01)
	
	assert(breach_dmg.get("repaired") == true, "Breccia riparata con successo dopo 4.0s")
	assert(SpaceWorldManager.is_duct_drone_repairing == false, "Stato di riparazione disattivato a fine lavoro")
	
	# 12. Test Disegno Canvas
	print("✔ Test Rendering Blueprint Canvas...")
	app.map_canvas.size = Vector2(480, 380)
	app.map_canvas.queue_redraw()
	assert(app.rooms.size() >= 8, "Stanze blueprint definite")
	assert(app.ducts.size() >= 10, "Rete condotti definita")
	
	# 13. Test Stato Connessione e Continuità Operativa
	print("✔ Test Stato Connessione e Continuità Operativa...")
	if NetworkManager:
		NetworkManager.is_solo_mode = false
		NetworkManager.is_mission_started = false
	app._update_connection_state()
	assert(app.is_operational() == true, "Duct Drone rimane operativo internamente anche se la missione spaziale termina")
	assert(app.disconnected_overlay.visible == false, "DisconnectedOverlay rimane nascosto per consentire uso autonomo")
	
	print("=== TUTTI I TEST DEL SISTEMA DUCT DRONE COMPLETATI CON SUCCESSO! ===")
	get_tree().quit(0)
