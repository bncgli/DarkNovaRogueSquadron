extends GutTest

## Suite di Collaudo Automatizzato GUT per il Cruise Drive Avanzato & Proximity Drop
## Verifica:
## 1. Validazione dei 3 prerequisiti di warmup (quiete < 5 m/s, allineamento <= 3°, potenza >= 160 MW)
## 2. Aborto warmup per perdita di potenza da PowerGrid
## 3. Ingaggio a 160 m/s (8.0x) e blocco attuatori RCS
## 4. Rilevamento ostacolo Proximity Drop (< 250m) e frenata violenta
## 5. Picco di decelerazione estrema -5.8G, feedback termico (+60°C) e reazione biometrica PodInfo
## 6. Disingaggio ordinario morbido con cooldown breve (3.0s)
## 7. Integrazione interfaccia pilota in FlightControlApp

var _cdc: CruiseDriveController = null
var _ship: Spaceship = null
var _flight_app: FlightControlApp = null
var _pod_app: PodInfoApp = null

func before_each() -> void:
	NetworkManager.disconnect_game()
	if SpaceWorldManager:
		if SpaceWorldManager.has_method("clear_active_waypoint"):
			SpaceWorldManager.clear_active_waypoint()
		_ship = SpaceWorldManager.get_spaceship()
		if _ship and is_instance_valid(_ship):
			_ship.rotation_degrees = Vector3.ZERO
			_ship.linear_velocity = Vector3.ZERO
			_ship.angular_velocity = Vector3.ZERO
			_ship.linear_input = Vector3.ZERO
			_ship.angular_input = Vector3.ZERO
			_ship.inertia_dampening = true
			_ship.current_g_force = 1.0
		_cdc = SpaceWorldManager.get_cruise_drive_controller()
		if _cdc and is_instance_valid(_cdc):
			_cdc.disengage("Test Reset", false)
			_cdc.current_state = CruiseDriveController.State.IDLE
			_cdc.current_heat = 0.0
			_cdc.cooldown_timer = 0.0
			_cdc.clear_destination_target()
			_cdc.set_cruise_coils_power(160.0)

func after_each() -> void:
	if is_instance_valid(_flight_app):
		_flight_app.queue_free()
		_flight_app = null
	if is_instance_valid(_pod_app):
		_pod_app.queue_free()
		_pod_app = null
	if _cdc and is_instance_valid(_cdc):
		_cdc.disengage("Test Cleanup", false)
		_cdc.current_state = CruiseDriveController.State.IDLE
	NetworkManager.disconnect_game()

func _setup_solo_mission() -> void:
	NetworkManager.start_solo_game("Pilota Test")
	NetworkManager.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame
	if SpaceWorldManager and SpaceWorldManager.is_ship_docked():
		SpaceWorldManager.request_undock()
		await get_tree().process_frame
	if _ship:
		_ship.linear_velocity = Vector3.ZERO
		_ship.angular_velocity = Vector3.ZERO
		_ship.rotation_degrees = Vector3.ZERO

func test_warmup_preconditions_validation() -> void:
	assert_not_null(_cdc, "CruiseDriveController disponibile in SpaceWorldManager")
	assert_not_null(_ship, "Spaceship disponibile in SpaceWorldManager")
	
	# Caso 1A: Velocità eccessiva (> 5.0 m/s)
	_ship.linear_velocity = Vector3(0, 0, -8.0)
	var res_speed := _cdc.request_engage()
	assert_false(res_speed.get("success", true), "Ingaggio deve fallire se velocità > 5.0 m/s")
	assert_eq(_cdc.current_state, CruiseDriveController.State.IDLE, "Stato deve rimanere IDLE")
	
	# Caso 1B: Disallineamento rotta (> 3.0 gradi)
	_ship.linear_velocity = Vector3.ZERO
	# Imposta un waypoint a 45 gradi a destra
	_cdc.set_destination_target(_ship.global_position + Vector3(1000.0, 0.0, -1000.0))
	var res_align := _cdc.request_engage()
	assert_false(res_align.get("success", true), "Ingaggio deve fallire se allineamento > 3.0 gradi")
	assert_eq(_cdc.current_state, CruiseDriveController.State.IDLE, "Stato deve rimanere IDLE")
	_cdc.clear_destination_target()
	
	# Caso 1C: Potenza insufficiente (< 160 MW)
	_cdc.set_cruise_coils_power(80.0)
	var res_power := _cdc.request_engage()
	assert_false(res_power.get("success", true), "Ingaggio deve fallire se potenza < 160 MW")
	assert_eq(_cdc.current_state, CruiseDriveController.State.IDLE, "Stato deve rimanere IDLE")
	
	# Caso 1D: Tutti i requisiti soddisfatti -> Avvio Warmup
	_cdc.set_cruise_coils_power(160.0)
	var res_valid := _cdc.request_engage()
	assert_true(res_valid.get("success", false), "Ingaggio deve avere successo con tutti i requisiti validi")
	assert_eq(_cdc.current_state, CruiseDriveController.State.WARMUP, "Stato deve passare a WARMUP")
	assert_eq(_cdc.get_current_power_draw_mw(), 160.0, "Assorbimento elettrico deve essere 160 MW durante warmup")

func test_warmup_aborted_on_power_loss() -> void:
	# Avvia warmup valido
	_cdc.set_cruise_coils_power(160.0)
	var res := _cdc.request_engage()
	assert_true(res.get("success", false), "Warmup avviato")
	assert_eq(_cdc.current_state, CruiseDriveController.State.WARMUP, "Stato WARMUP")
	
	# Simula avanzamento temporale di 2 secondi
	_cdc._physics_process(2.0)
	assert_eq(_cdc.current_state, CruiseDriveController.State.WARMUP, "Warmup a metà percorso")
	
	# Taglio di potenza da PowerGrid (spegnimento reattore)
	_cdc.set_cruise_coils_power(0.0)
	_cdc._physics_process(0.1)
	
	assert_eq(_cdc.current_state, CruiseDriveController.State.IDLE, "Warmup deve abortire tornando a IDLE per caduta tensione")
	assert_eq(_cdc.get_current_power_draw_mw(), 0.0, "Carico elettrico azzerato")

func test_cruise_engagement_and_speed_multiplier() -> void:
	_cdc.set_cruise_coils_power(160.0)
	_ship.linear_velocity = Vector3.ZERO
	_ship.rotation_degrees = Vector3.ZERO
	_cdc.request_engage()
	assert_eq(_cdc.current_state, CruiseDriveController.State.WARMUP, "In warmup")
	
	# Completa il warmup (4.0 secondi)
	_cdc._physics_process(4.1)
	
	assert_eq(_cdc.current_state, CruiseDriveController.State.ENGAGED, "Stato deve passare a ENGAGED")
	assert_true(_cdc.is_rcs_locked, "Attuatori RCS devono essere bloccati in crociera")
	assert_almost_eq(_ship.linear_velocity.length(), 160.0, 1.0, "Velocità longitudinale corvetta deve raggiungere 160 m/s")
	assert_true(_ship.linear_velocity.z < -100.0, "Spinta diretta verso prua (-Z)")

func test_proximity_drop_detection_and_hard_braking() -> void:
	_cdc.set_cruise_coils_power(160.0)
	_cdc.engage_cruise()
	assert_eq(_cdc.current_state, CruiseDriveController.State.ENGAGED, "Crociera attiva")
	assert_almost_eq(_ship.linear_velocity.length(), 160.0, 1.0)
	
	# Posiziona un ostacolo a 200m lungo la traiettoria di prua
	var obs_pos := _ship.global_position + Vector3(0.0, 0.0, -200.0)
	_cdc.trigger_proximity_drop("Asteroide Metallico TX-9", 200.0)
	
	# Verifica transizione a EMERGENCY_DROP
	assert_eq(_cdc.current_state, CruiseDriveController.State.EMERGENCY_DROP, "Stato deve essere EMERGENCY_DROP")
	assert_almost_eq(_cdc.get_cooldown_remaining(), 6.0, 0.1, "Cooldown di sicurezza deve essere 6.0s")
	assert_true(_ship.linear_velocity.length() <= 20.0, "Frenata violenta deve abbattere la velocità a <= 20 m/s")
	assert_almost_eq(_cdc.get_current_heat(), 60.0, 0.1, "Penalità termica deve aumentare di +60°C")

func test_proximity_drop_negative_g_and_pod_shake() -> void:
	var pod_scene := load("res://Applications/PodInfo/pod_info_app.tscn") as PackedScene
	assert_not_null(pod_scene, "Scena pod_info_app.tscn caricata")
	_pod_app = pod_scene.instantiate() as PodInfoApp
	add_child(_pod_app)
	await get_tree().process_frame
	
	var initial_heart_rate := _pod_app.heart_rate
	
	# Attiva proximity drop
	_cdc.set_cruise_coils_power(160.0)
	_cdc.engage_cruise()
	_cdc.trigger_proximity_drop("Relitto Incrociatore", 180.0)
	
	# Verifica picco di decelerazione estrema -5.8G
	assert_almost_eq(_ship.current_g_force, -5.8, 0.01, "Picco di decelerazione Spaceship deve essere -5.8G")
	assert_almost_eq(SpaceWorldManager.get_ship_g_force(), -5.8, 0.01, "G-Force SpaceWorldManager deve essere -5.8G")
	
	# Verifica feedback biometrici e scuotimento nei Pod
	assert_almost_eq(_pod_app.get_shake_intensity(), 22.0, 0.1, "Intensità screen shake deve essere 22.0")
	assert_true(_pod_app.heart_rate >= initial_heart_rate + 40.0, "Battito cardiaco deve registrare un balzo di stress")

func test_manual_disengage_soft_transition() -> void:
	_cdc.set_cruise_coils_power(160.0)
	_cdc.engage_cruise()
	assert_eq(_cdc.current_state, CruiseDriveController.State.ENGAGED, "Crociera attiva")
	
	# Disingaggio manuale del pilota (senza ostacoli)
	_cdc.disengage("Disattivazione manuale pilota", false)
	
	assert_eq(_cdc.current_state, CruiseDriveController.State.COOLDOWN, "Stato deve passare a COOLDOWN ordinario")
	assert_almost_eq(_cdc.get_cooldown_remaining(), 3.0, 0.1, "Cooldown ordinario deve essere di 3.0s")
	assert_almost_eq(_cdc.get_current_heat(), 0.0, 0.1, "Nessuna penalità termica estrema per disingaggio manuale")
	assert_true(_ship.current_g_force >= 0.0, "Nessun picco negativo estremo di decelerazione")

func test_flight_control_ui_integration() -> void:
	await _setup_solo_mission()
	NetworkManager.request_role(NetworkManager.ROLE_PILOT)
	var fc_scene := load("res://Applications/FlightControl/flight_control_app.tscn") as PackedScene
	assert_not_null(fc_scene, "Scena flight_control_app.tscn caricata")
	_flight_app = fc_scene.instantiate() as FlightControlApp
	add_child(_flight_app)
	await get_tree().process_frame
	await get_tree().process_frame
	_flight_app._update_permissions()
	
	assert_not_null(_flight_app.cruise_toggle_button, "Pulsante crociera presente nella UI")
	assert_eq(_flight_app.cruise_toggle_button.text, "VELOCITÀ CROCIERA: OFF", "Testo iniziale OFF")
	
	# Pressione pulsante con requisiti validi
	_cdc.set_cruise_coils_power(160.0)
	_cdc.clear_destination_target()
	if SpaceWorldManager and SpaceWorldManager.has_method("clear_active_waypoint"):
		SpaceWorldManager.clear_active_waypoint()
	_ship.linear_velocity = Vector3.ZERO
	_ship.rotation_degrees = Vector3.ZERO
	_flight_app._on_cruise_toggle_pressed()
	
	assert_eq(_cdc.current_state, CruiseDriveController.State.WARMUP, "Pulsante avvia warmup nel controller")
	assert_true(_flight_app.cruise_toggle_button.text.contains("WARMUP"), "Pulsante mostra progresso WARMUP")
	
	# Pressione durante warmup annulla la sequenza
	_flight_app._on_cruise_toggle_pressed()
	assert_eq(_cdc.current_state, CruiseDriveController.State.IDLE, "Pulsante durante warmup annulla la sequenza")
	assert_eq(_flight_app.cruise_toggle_button.text, "VELOCITÀ CROCIERA: OFF", "Testo ritorna a OFF")
