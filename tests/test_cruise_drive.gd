extends Node

## Test Runner Headless per Cruise Mode Drive (`Outside/ShipSystems/cruise_drive_controller.gd`)
## e pannello UI (`Applications/FlightControl/Componenti/cruise_control_panel.gd`).
## Esegue tutte le verifiche dei criteri di accettazione previsti dal task 06.

func _ready() -> void:
	print("\n=======================================================")
	print(">>> AVVIO SUITE DI TEST HEADLESS: CRUISE DRIVE (SUB-FTL)")
	print("=======================================================\n")
	_run_all_tests()

func _run_all_tests() -> void:
	await get_tree().process_frame
	
	# =========================================================================
	# TEST 1: CARICAMENTO CONFIGURAZIONE .DAT E TUNING
	# =========================================================================
	print("--- TEST 1: Caricamento Configurazione .DAT (thrusters_tuning.dat) ---")
	var controller := CruiseDriveController.new()
	add_child(controller)
	await get_tree().process_frame
	
	assert(controller.cruise_multiplier == 8.0, "cruise_multiplier deve essere 8.0 (trovato: %s)" % controller.cruise_multiplier)
	assert(controller.warmup_time_sec == 4.0, "warmup_time_sec deve essere 4.0 (trovato: %s)" % controller.warmup_time_sec)
	assert(controller.proximity_drop_distance == 250.0, "proximity_drop_distance deve essere 250.0 (trovato: %s)" % controller.proximity_drop_distance)
	assert(controller.heat_penalty == 45.0, "heat_penalty deve essere 45.0 (trovato: %s)" % controller.heat_penalty)
	assert(controller.required_power_mw == 160.0, "required_power_mw deve essere 160.0")
	print("✔ Parametri .DAT caricati e convalidati correttamente")
	
	# =========================================================================
	# TEST 2: BLOCCO INGAGGIO SE NAVE IN MOVIMENTO (QUIETE: SPEED >= 5.0 m/s)
	# =========================================================================
	print("\n--- TEST 2: Blocco Ingaggio in Movimento (Velocità >= 5.0 m/s) ---")
	var ship := Spaceship.new()
	add_child(ship)
	controller.set_spaceship(ship)
	
	# Simula nave che si muove a 10 m/s
	ship.linear_velocity = Vector3(0, 0, -10.0)
	controller.set_cruise_coils_power(160.0) # Potenza OK
	controller.clear_destination_target()    # Allineato
	
	var rest_check := controller.check_rest_state()
	assert(rest_check["is_valid"] == false, "check_rest_state deve fallire se la nave viaggia a 10 m/s")
	
	var engage_res := controller.request_engage()
	assert(engage_res["success"] == false, "request_engage deve fallire se la nave è in movimento")
	assert(controller.current_state == CruiseDriveController.State.IDLE, "Lo stato deve rimanere IDLE")
	print("✔ Ingaggio correttamente bloccato per velocità oltre la soglia di quiete (%.1f m/s)" % ship.linear_velocity.length())
	
	# Riporta la nave in quiete
	ship.linear_velocity = Vector3.ZERO
	var rest_check_ok := controller.check_rest_state()
	assert(rest_check_ok["is_valid"] == true, "check_rest_state deve passare con nave ferma")
	print("✔ Stato di quiete validato a velocità zero (< 5.0 m/s)")
	
	# =========================================================================
	# TEST 3: BLOCCO INGAGGIO PER DISALLINEAMENTO VETTORIALE (> 3.0°)
	# =========================================================================
	print("\n--- TEST 3: Blocco Ingaggio per Disallineamento Vettoriale (> 3.0°) ---")
	# Nave orientata verso Vector3(0, 0, -1), impostiamo waypoint a 90 gradi verso destra Vector3(100, 0, 0)
	controller.set_destination_target(Vector3(100, 0, 0))
	var align_check := controller.check_vector_alignment()
	assert(align_check["is_valid"] == false, "check_vector_alignment deve fallire se angolo > 3.0°")
	assert(align_check["angle_deg"] > 80.0, "Angolo calcolato deve essere ~90°")
	
	var engage_res_align := controller.request_engage()
	assert(engage_res_align["success"] == false, "request_engage deve fallire con disallineamento")
	assert(controller.current_state == CruiseDriveController.State.IDLE, "Lo stato deve rimanere IDLE")
	print("✔ Ingaggio correttamente bloccato per disallineamento rotte (angolo: %.1f°)" % align_check["angle_deg"])
	
	# Allinea la destinazione esattamente davanti alla prua Vector3(0, 0, -1000)
	controller.set_destination_target(Vector3(0, 0, -1000))
	var align_check_ok := controller.check_vector_alignment()
	assert(align_check_ok["is_valid"] == true, "check_vector_alignment deve essere valido quando allineato (0° <= 3°)")
	print("✔ Allineamento vettoriale rotta convalidato (< 3.0°)")
	
	# =========================================================================
	# TEST 4: REQUISITO POTENZA ENERGETICA POWERGRID (160 MW)
	# =========================================================================
	print("\n--- TEST 4: Requisito di Potenza Energetica (160 MW via PowerGrid) ---")
	controller.set_cruise_coils_power(80.0) # Insufficiente (< 160 MW)
	var pwr_check := controller.check_power_state()
	assert(pwr_check["is_valid"] == false, "check_power_state deve fallire se potenza < 160 MW")
	
	var engage_res_pwr := controller.request_engage()
	assert(engage_res_pwr["success"] == false, "request_engage deve fallire per potenza insufficiente")
	assert(controller.current_state == CruiseDriveController.State.IDLE, "Lo stato deve rimanere IDLE")
	print("✔ Ingaggio correttamente bloccato per alimentazione insufficiente (80 MW / 160 MW)")
	
	# Convoglia picco energetico a 160 MW
	controller.set_cruise_coils_power(160.0)
	var pwr_check_ok := controller.check_power_state()
	assert(pwr_check_ok["is_valid"] == true, "check_power_state deve passare con 160 MW")
	print("✔ Picco energetico bobine convalidato a 160 MW")
	
	# =========================================================================
	# TEST 5: PROCEDURA DI WARMUP E TRANSIZIONE A CRUISE MODE (BOOST 8.0x)
	# =========================================================================
	print("\n--- TEST 5: Warmup Sequenziale e Attivazione Cruise Mode (8.0x) ---")
	# Posiziona la nave in un settore di spazio aperto privo di ostacoli immediati (es. Y = +2000)
	ship.position = Vector3(0, 2000, 0)
	controller.set_destination_target(Vector3(0, 2000, -5000))
	
	var warmup_started := controller.request_engage()
	assert(warmup_started["success"] == true, "request_engage deve avere successo quando tutti i vincoli sono rispettati")
	assert(controller.current_state == CruiseDriveController.State.WARMUP, "Lo stato deve passare a WARMUP")
	print("✔ Sequenza di warmup avviata con successo")
	
	# Simula 2 secondi di warmup (a metà)
	controller._physics_process(2.0)
	assert(controller.current_state == CruiseDriveController.State.WARMUP, "Stato deve rimanere WARMUP dopo 2s")
	assert(is_equal_approx(controller.warmup_timer, 2.0), "warmup_timer deve essere 2.0s")
	
	# Simula completamento warmup (altri 2.1s -> oltre 4.0s)
	controller._physics_process(2.1)
	assert(controller.current_state == CruiseDriveController.State.ENGAGED, "Al completamento dei 4.0s lo stato deve passare a ENGAGED")
	assert(controller.is_rcs_locked == true, "Il controllo RCS manuale deve essere BLOCCATO durante la crociera")
	print("✔ Transizione a ENGAGED completata e blocco RCS attivo")
	
	# Simula processo in stato ENGAGED e verifica moltiplicatore di velocità
	controller._physics_process(1.0)
	var expected_cruise_speed := ship.max_linear_speed * controller.cruise_multiplier
	assert(expected_cruise_speed == 160.0, "La velocità massima di crociera deve essere 20 * 8 = 160 m/s")
	assert(ship.linear_velocity.length() > ship.max_linear_speed, "La velocità in crociera deve superare la velocità standard")
	print("✔ Spinta esponenziale lineare Cruise Mode attiva (velocità: %.1f m/s, target: %.1f m/s)" % [ship.linear_velocity.length(), expected_cruise_speed])
	
	# =========================================================================
	# TEST 6: PROXIMITY DROP (DISINGAGGIO D'EMERGENZA E PENALITÀ TERMICA)
	# =========================================================================
	print("\n--- TEST 6: Trigger Proximity Drop (Ostacolo <= 250m) ---")
	var drop_data := {
		"triggered": false,
		"obstacle": "",
		"distance": 0.0
	}
	
	controller.proximity_drop_triggered.connect(func(obs: String, d: float) -> void:
		drop_data["triggered"] = true
		drop_data["obstacle"] = obs
		drop_data["distance"] = d
	)
	
	controller.engage_cruise()
	
	# Trigger Proximity Drop con asteroide a 150m
	controller.trigger_proximity_drop("ASTEROIDE GIGANTE ALPHA", 150.0)
	
	assert(drop_data["triggered"] == true, "Il segnale proximity_drop_triggered deve essere emesso")
	assert(drop_data["obstacle"] == "ASTEROIDE GIGANTE ALPHA", "Nome ostacolo corretto")
	assert(drop_data["distance"] == 150.0, "Distanza ostacolo corretta")
	assert(controller.current_state == CruiseDriveController.State.EMERGENCY_DROP, "Stato deve essere EMERGENCY_DROP")
	assert(controller.is_rcs_locked == false, "RCS deve essere sbloccato dopo il drop")
	assert(controller.current_heat >= 45.0, "Penalità termica di 45.0°C deve essere applicata ai propulsori")
	assert(ship.linear_velocity.length() <= ship.max_linear_speed, "Velocità deve essere ridotta alla velocità ordinaria (< 20 m/s)")
	print("✔ Proximity Drop scattato con successo: de-accelerazione immediata, sblocco RCS e +%.1f calore" % controller.current_heat)
	
	# =========================================================================
	# TEST 7: WIDGET UI CRUISE CONTROL PANEL (FLIGHT CONTROL)
	# =========================================================================
	print("\n--- TEST 7: Componente UI CruiseControlPanel ---")
	var panel_scene: PackedScene = load("res://Applications/FlightControl/Componenti/cruise_control_panel.tscn")
	assert(panel_scene != null, "La scena cruise_control_panel.tscn deve essere caricata")
	
	var panel: CruiseControlPanel = panel_scene.instantiate() as CruiseControlPanel
	assert(panel != null, "L'istanza CruiseControlPanel deve essere valida")
	add_child(panel)
	panel.set_controller(controller)
	await get_tree().process_frame
	
	assert(panel.status_badge != null, "status_badge deve esistere")
	assert(panel.charge_progress_bar != null, "charge_progress_bar deve esistere")
	assert(panel.btn_toggle_cruise != null, "btn_toggle_cruise deve esistere")
	assert(panel.phase_power_label != null, "phase_power_label deve esistere")
	assert(panel.phase_align_label != null, "phase_align_label deve esistere")
	assert(panel.phase_rest_label != null, "phase_rest_label deve esistere")
	print("✔ Widget UI CruiseControlPanel inizializzato e sincronizzato con successo")
	
	# =========================================================================
	# TEST 8: INTEGRAZIONE FLIGHT CONTROL APP
	# =========================================================================
	print("\n--- TEST 8: Integrazione FlightControlApp con Cruise Control Panel ---")
	var app_scene: PackedScene = load("res://Applications/FlightControl/flight_control_app.tscn")
	var flight_app: FlightControlApp = app_scene.instantiate() as FlightControlApp
	add_child(flight_app)
	await get_tree().process_frame
	
	assert(flight_app.cruise_control_panel != null, "FlightControlApp deve contenere cruise_control_panel")
	print("✔ FlightControlApp include correttamente il pannello di crociera")
	
	print("\n=======================================================")
	print("=== TUTTI I TEST CRUISE MODE SUB-FTL COMPLETATI CON SUCCESSO! ===")
	print("=======================================================\n")
	get_tree().quit(0)
