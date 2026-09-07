extends GutTest

## Test GUT per Cruise Mode Drive (`Outside/ShipSystems/cruise_drive_controller.gd`)
## e pannello UI (`Applications/FlightControl/Componenti/cruise_control_panel.gd`).
## Le funzioni sono eseguite in ordine di dichiarazione (comportamento di GUT) e
## condividono lo stato di `controller`/`ship` per convalidare l'intera sequenza
## di ingaggio Cruise Mode, come nel test manuale originale.

var controller: CruiseDriveController
var ship: Spaceship

func before_all() -> void:
	# controller e ship condividono lo stato attraverso l'intera sequenza di test
	# (come nel test manuale originale), quindi vengono creati una sola volta e
	# liberati esplicitamente in after_all: add_child_autofree li libererebbe
	# già al termine del singolo test, rompendo la sequenza.
	controller = CruiseDriveController.new()
	add_child(controller)
	ship = Spaceship.new()
	add_child(ship)
	controller.set_spaceship(ship)

func after_all() -> void:
	if is_instance_valid(controller):
		controller.free()
	if is_instance_valid(ship):
		ship.free()

func test_tuning_configuration_loaded() -> void:
	assert_eq(controller.cruise_multiplier, 8.0, "cruise_multiplier deve essere 8.0")
	assert_eq(controller.warmup_time_sec, 4.0, "warmup_time_sec deve essere 4.0")
	assert_eq(controller.proximity_drop_distance, 250.0, "proximity_drop_distance deve essere 250.0")
	assert_eq(controller.heat_penalty, 45.0, "heat_penalty deve essere 45.0")
	assert_eq(controller.required_power_mw, 160.0, "required_power_mw deve essere 160.0")

func test_engage_blocked_while_ship_is_moving() -> void:
	# Simula nave che si muove a 10 m/s
	ship.linear_velocity = Vector3(0, 0, -10.0)
	controller.set_cruise_coils_power(160.0) # Potenza OK
	controller.clear_destination_target()    # Allineato

	var rest_check: Dictionary = controller.check_rest_state()
	assert_false(rest_check["is_valid"], "check_rest_state deve fallire se la nave viaggia a 10 m/s")

	var engage_res: Dictionary = controller.request_engage()
	assert_false(engage_res["success"], "request_engage deve fallire se la nave è in movimento")
	assert_eq(controller.current_state, CruiseDriveController.State.IDLE, "Lo stato deve rimanere IDLE")

	# Riporta la nave in quiete
	ship.linear_velocity = Vector3.ZERO
	var rest_check_ok: Dictionary = controller.check_rest_state()
	assert_true(rest_check_ok["is_valid"], "check_rest_state deve passare con nave ferma")

func test_engage_blocked_on_vector_misalignment() -> void:
	# Nave orientata verso Vector3(0, 0, -1), impostiamo waypoint a 90 gradi verso destra Vector3(100, 0, 0)
	controller.set_destination_target(Vector3(100, 0, 0))
	var align_check: Dictionary = controller.check_vector_alignment()
	assert_false(align_check["is_valid"], "check_vector_alignment deve fallire se angolo > 3.0°")
	assert_gt(align_check["angle_deg"], 80.0, "Angolo calcolato deve essere ~90°")

	var engage_res_align: Dictionary = controller.request_engage()
	assert_false(engage_res_align["success"], "request_engage deve fallire con disallineamento")
	assert_eq(controller.current_state, CruiseDriveController.State.IDLE, "Lo stato deve rimanere IDLE")

	# Allinea la destinazione esattamente davanti alla prua Vector3(0, 0, -1000)
	controller.set_destination_target(Vector3(0, 0, -1000))
	var align_check_ok: Dictionary = controller.check_vector_alignment()
	assert_true(align_check_ok["is_valid"], "check_vector_alignment deve essere valido quando allineato (0° <= 3°)")

func test_engage_blocked_on_insufficient_power() -> void:
	controller.set_cruise_coils_power(80.0) # Insufficiente (< 160 MW)
	var pwr_check: Dictionary = controller.check_power_state()
	assert_false(pwr_check["is_valid"], "check_power_state deve fallire se potenza < 160 MW")

	var engage_res_pwr: Dictionary = controller.request_engage()
	assert_false(engage_res_pwr["success"], "request_engage deve fallire per potenza insufficiente")
	assert_eq(controller.current_state, CruiseDriveController.State.IDLE, "Lo stato deve rimanere IDLE")

	# Convoglia picco energetico a 160 MW
	controller.set_cruise_coils_power(160.0)
	var pwr_check_ok: Dictionary = controller.check_power_state()
	assert_true(pwr_check_ok["is_valid"], "check_power_state deve passare con 160 MW")

func test_warmup_sequence_and_cruise_engagement() -> void:
	# Posiziona la nave in un settore di spazio aperto privo di ostacoli immediati (es. Y = +2000)
	ship.position = Vector3(0, 2000, 0)
	controller.set_destination_target(Vector3(0, 2000, -5000))

	var warmup_started: Dictionary = controller.request_engage()
	assert_true(warmup_started["success"], "request_engage deve avere successo quando tutti i vincoli sono rispettati")
	assert_eq(controller.current_state, CruiseDriveController.State.WARMUP, "Lo stato deve passare a WARMUP")

	# Simula 2 secondi di warmup (a metà)
	controller._physics_process(2.0)
	assert_eq(controller.current_state, CruiseDriveController.State.WARMUP, "Stato deve rimanere WARMUP dopo 2s")
	assert_almost_eq(controller.warmup_timer, 2.0, 0.001, "warmup_timer deve essere 2.0s")

	# Simula completamento warmup (altri 2.1s -> oltre 4.0s)
	controller._physics_process(2.1)
	assert_eq(controller.current_state, CruiseDriveController.State.ENGAGED, "Al completamento dei 4.0s lo stato deve passare a ENGAGED")
	assert_true(controller.is_rcs_locked, "Il controllo RCS manuale deve essere BLOCCATO durante la crociera")

	# Simula processo in stato ENGAGED e verifica moltiplicatore di velocità
	controller._physics_process(1.0)
	var expected_cruise_speed: float = ship.max_linear_speed * controller.cruise_multiplier
	assert_eq(expected_cruise_speed, 160.0, "La velocità massima di crociera deve essere 20 * 8 = 160 m/s")
	assert_gt(ship.linear_velocity.length(), ship.max_linear_speed, "La velocità in crociera deve superare la velocità standard")

func test_proximity_drop_emergency_disengage() -> void:
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

	assert_true(drop_data["triggered"], "Il segnale proximity_drop_triggered deve essere emesso")
	assert_eq(drop_data["obstacle"], "ASTEROIDE GIGANTE ALPHA", "Nome ostacolo corretto")
	assert_eq(drop_data["distance"], 150.0, "Distanza ostacolo corretta")
	assert_eq(controller.current_state, CruiseDriveController.State.EMERGENCY_DROP, "Stato deve essere EMERGENCY_DROP")
	assert_false(controller.is_rcs_locked, "RCS deve essere sbloccato dopo il drop")
	assert_gte(controller.current_heat, 45.0, "Penalità termica di 45.0°C deve essere applicata ai propulsori")
	assert_lte(ship.linear_velocity.length(), ship.max_linear_speed, "Velocità deve essere ridotta alla velocità ordinaria (< 20 m/s)")

func test_cruise_control_panel_widget() -> void:
	var panel_scene: PackedScene = load("res://Applications/FlightControl/Componenti/cruise_control_panel.tscn")
	assert_not_null(panel_scene, "La scena cruise_control_panel.tscn deve essere caricata")

	var panel: CruiseControlPanel = panel_scene.instantiate() as CruiseControlPanel
	assert_not_null(panel, "L'istanza CruiseControlPanel deve essere valida")
	add_child_autofree(panel)
	panel.set_controller(controller)
	await get_tree().process_frame

	assert_not_null(panel.status_badge, "status_badge deve esistere")
	assert_not_null(panel.charge_progress_bar, "charge_progress_bar deve esistere")
	assert_not_null(panel.btn_toggle_cruise, "btn_toggle_cruise deve esistere")
	assert_not_null(panel.phase_power_label, "phase_power_label deve esistere")
	assert_not_null(panel.phase_align_label, "phase_align_label deve esistere")
	assert_not_null(panel.phase_rest_label, "phase_rest_label deve esistere")

func test_flight_control_app_integration() -> void:
	var app_scene: PackedScene = load("res://Applications/FlightControl/flight_control_app.tscn")
	var flight_app: FlightControlApp = app_scene.instantiate() as FlightControlApp
	add_child_autofree(flight_app)
	await get_tree().process_frame

	assert_not_null(flight_app.cruise_control_panel, "FlightControlApp deve contenere cruise_control_panel")
