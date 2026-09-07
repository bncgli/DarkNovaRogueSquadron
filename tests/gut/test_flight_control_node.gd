extends GutTest

## Test GUT per l'applicazione FlightControl (movimenti 6-DOF, inerzia,
## regolazione velocità, RBAC pilota e allineamento/ingaggio Hyperdrive).
## Migrato da tests/test_flight_control_node.gd (extends Node, assert() nudo).

var _app: FlightControlApp = null

func before_each() -> void:
	NetworkManager.disconnect_game()
	# La Spaceship persiste per l'intera sessione: resetta rotazione/velocità
	# per evitare interferenze tra test (es. allineamento Hyperdrive residuo).
	var ship: Spaceship = SpaceWorldManager.get_spaceship()
	if ship:
		ship.rotation_degrees = Vector3.ZERO
		ship.linear_velocity = Vector3.ZERO
		ship.angular_velocity = Vector3.ZERO
		ship.linear_input = Vector3.ZERO
		ship.angular_input = Vector3.ZERO
		ship.inertia_dampening = true

func after_each() -> void:
	if is_instance_valid(_app):
		_app.queue_free()
	_app = null
	NetworkManager.disconnect_game()

func _start_solo_mission(player_name: String = "Comandante Test") -> void:
	NetworkManager.start_solo_game(player_name)
	NetworkManager.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame

func _create_app() -> FlightControlApp:
	var scene: PackedScene = load("res://Applications/FlightControl/flight_control_app.tscn")
	assert_not_null(scene, "Scena flight_control_app.tscn deve essere caricabile")
	var app: FlightControlApp = scene.instantiate() as FlightControlApp
	add_child_autofree(app)
	await get_tree().process_frame
	return app

func test_disconnected_overlay_and_operational_state() -> void:
	_app = await _create_app()
	assert_false(_app.is_operational(), "L'app non deve essere operativa quando la nave è disconnessa")
	assert_not_null(_app.disconnected_overlay, "L'overlay DisconnectedOverlay deve esistere")
	assert_true(_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve essere visibile da disconnesso")
	
	await _start_solo_mission()
	
	assert_true(_app.is_operational(), "L'app deve essere operativa dopo l'avvio della missione")
	assert_false(_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve scomparire dopo l'avvio della missione")
	
	var ship: Spaceship = SpaceWorldManager.get_spaceship()
	assert_not_null(ship, "SpaceWorldManager deve restituire l'istanza Spaceship")

func test_ship_drive_folder_is_protected_by_default_password() -> void:
	await _start_solo_mission()
	assert_true(DirAccess.dir_exists_absolute("user://files/Ship Drive/Programs/FlightControls"), "Cartella Programs/FlightControls deve esistere in Ship Drive")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/FlightControls/flight_config.dat"), "flight_config.dat deve esistere in Ship Drive/Programs/FlightControls/")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/FlightControls/thrusters_tuning.dat"), "thrusters_tuning.dat deve esistere in Ship Drive/Programs/FlightControls/")
	
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	assert_not_null(fpm, "FolderPasswordManager deve essere disponibile come autoload")
	assert_true(fpm.has_password("Ship Drive/Programs/FlightControls"), "La cartella Ship Drive/Programs/FlightControls deve essere protetta da password")
	assert_true(fpm.check_password("Ship Drive/Programs/FlightControls", "FLIGHT-7815"), "La password predefinita della cartella deve essere FLIGHT-7815")

func test_dat_configuration_default_values_and_runtime_hot_reload() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	var ship: Spaceship = SpaceWorldManager.get_spaceship()
	
	var initial_cfg := _app.load_dat_configuration()
	assert_true(initial_cfg.get("is_dat_loaded"), "Configurazione .dat deve risultare caricata")
	assert_eq(ship.max_linear_speed, 20.0, "Velocità lineare iniziale nave deve essere 20.0")
	assert_eq(ship.linear_acceleration, 35.0, "Accelerazione lineare iniziale nave deve essere 35.0")
	
	var new_dat_content := "[SYSTEM]\napp_name=FlightControls\nversion=1.0.4\nstatus=OVERCLOCKED\n\n[FLIGHT_DYNAMICS]\nmax_linear_speed=50.0\nlinear_acceleration=90.0\nlinear_deceleration=40.0\nmax_angular_speed=5.0\nangular_acceleration=18.0\nangular_deceleration=12.0\n\n[SPEED_MODES]\nturbo_multiplier=3.0\nprecision_multiplier=0.2\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/FlightControls/flight_config.dat", FileAccess.WRITE)
	f_out.store_string(new_dat_content)
	f_out.close()
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("file_synced"):
		sdm.file_synced.emit("Ship Drive/Programs/FlightControls/flight_config.dat")
	else:
		_app.load_dat_configuration()
	await get_tree().process_frame
	
	assert_eq(ship.max_linear_speed, 50.0, "max_linear_speed aggiornato in tempo reale a 50.0")
	assert_eq(ship.linear_acceleration, 90.0, "linear_acceleration aggiornato in tempo reale a 90.0")
	assert_eq(ship.max_angular_speed, 5.0, "max_angular_speed aggiornato in tempo reale a 5.0")

func test_rbac_pilot_can_control_engineer_cannot() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	NetworkManager.request_role(NetworkManager.ROLE_PILOT)
	await get_tree().process_frame
	assert_true(_app.can_control_flight, "Il Pilota deve poter controllare il volo")
	assert_false(_app.btn_w.disabled, "I pulsanti devono essere attivi per il Pilota")
	assert_true(
		_app.thrusters_badge.text.contains("PROPULSORI PRONTI") or _app.thrusters_badge.text.contains("PROPULSORI ATTIVI") or _app.thrusters_badge.text.contains("IN VOLO"),
		"Badge per Pilota deve indicare stato propulsori operativo"
	)
	
	# NOTA: can_control_flight include un OR diretto su is_solo_mode (non solo come
	# fallback per ruolo vuoto), quindi va disattivata esplicitamente la modalità
	# Solo per validare davvero la restrizione RBAC sul ruolo Ingegnere.
	NetworkManager.request_role(NetworkManager.ROLE_ENGINEER)
	NetworkManager.is_solo_mode = false
	NetworkManager.player_role_changed.emit(1, NetworkManager.ROLE_ENGINEER)
	await get_tree().process_frame
	assert_false(_app.can_control_flight, "L'Ingegnere non deve poter manovrare l'astronave")
	assert_true(_app.btn_w.disabled, "I pulsanti devono essere disabilitati per l'Ingegnere")
	assert_eq(_app.thrusters_badge.text, "SOLO TELEMETRIA", "Badge deve indicare SOLO TELEMETRIA")
	
	# Ripristina ruolo Pilota / Solo per gli altri test
	NetworkManager.is_solo_mode = true
	NetworkManager.request_role(NetworkManager.ROLE_PILOT)
	NetworkManager.player_role_changed.emit(1, NetworkManager.ROLE_PILOT)
	await get_tree().process_frame

func test_six_dof_translation_and_rotation_input() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	var ship: Spaceship = SpaceWorldManager.get_spaceship()
	
	# Avanti (W)
	SpaceWorldManager.set_spaceship_inputs(Vector3(0, 0, -1), Vector3.ZERO)
	ship._physics_process(0.1)
	assert_true(ship.linear_velocity.z < 0.0, "Spostamento in avanti")
	
	# Rollio (Q ed E) tramite pulsanti UI
	_app.btn_q.button_down.emit()
	assert_true(_app._ui_angular_input.z > 0.0, "UI angular input Z con tasto Q")
	_app.btn_q.button_up.emit()
	assert_eq(_app._ui_angular_input.z, 0.0, "UI angular input Z ripristinato")

func test_inertia_dampening_toggle_and_newtonian_drift() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	var ship: Spaceship = SpaceWorldManager.get_spaceship()
	
	assert_true(_app.is_inertia_enabled, "Inerzia attiva di default")
	assert_true(ship.inertia_dampening, "Smorzamento nave attivo di default")
	assert_not_null(_app.inertia_toggle_button, "Pulsante InertiaToggleButton presente")
	assert_eq(_app.inertia_toggle_button.text, "INERZIA: ON", "Testo pulsante iniziale INERZIA: ON")
	
	ship.linear_velocity = Vector3(0, 0, -20.0)
	SpaceWorldManager.set_spaceship_inputs(Vector3.ZERO, Vector3.ZERO)
	ship._physics_process(0.2)
	assert_true(ship.linear_velocity.length() < 20.0, "Con Inerzia ON la nave deve decelerare quando non ci sono input")
	
	_app._on_inertia_toggle_pressed()
	assert_false(_app.is_inertia_enabled, "Inerzia disabilitata dopo toggle")
	assert_false(ship.inertia_dampening, "Smorzamento nave disabilitato")
	assert_eq(_app.inertia_toggle_button.text, "INERZIA: OFF", "Testo pulsante aggiornato a INERZIA: OFF")
	
	ship.linear_velocity = Vector3(0, 0, -15.0)
	ship._physics_process(0.2)
	assert_true(is_equal_approx(ship.linear_velocity.length(), 15.0), "Con Inerzia OFF la nave conserva la velocità (deriva newtoniana)")
	
	_app._on_inertia_toggle_pressed()
	assert_true(_app.is_inertia_enabled, "Inerzia ripristinata a ON")
	assert_true(ship.inertia_dampening, "Smorzamento nave ripristinato")

func test_speed_multiplier_adjustment_with_r_and_f_keys() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app._speed_multiplier = 1.0
	
	var ev_r := InputEventKey.new()
	ev_r.keycode = KEY_R
	ev_r.pressed = true
	_app._input(ev_r)
	assert_true(is_equal_approx(_app._speed_multiplier, 1.1), "Tasto R incrementa moltiplicatore a 1.1x")
	
	for _i in range(15):
		_app._input(ev_r)
	assert_true(is_equal_approx(_app._speed_multiplier, 2.0), "Moltiplicatore limitato a massimo 2.0x")
	
	var ev_f := InputEventKey.new()
	ev_f.keycode = KEY_F
	ev_f.pressed = true
	_app._input(ev_f)
	assert_true(is_equal_approx(_app._speed_multiplier, 1.9), "Tasto F decrementa moltiplicatore a 1.9x")
	
	for _i in range(20):
		_app._input(ev_f)
	assert_true(is_equal_approx(_app._speed_multiplier, 0.5), "Moltiplicatore limitato a minimo 0.5x")
	
	for _i in range(5):
		_app._input(ev_r)
	assert_true(is_equal_approx(_app._speed_multiplier, 1.0), "Moltiplicatore riportato a 1.0x")
	
	_app._update_telemetry_display(12.5, Vector3(10, 20, 30), Vector3(0, 45, 0))
	assert_true(_app.speed_value_label.text.contains("12.5 m/s"), "Display telemetria mostra velocità")
	assert_true(_app.speed_value_label.text.contains("1.0x"), "Display telemetria mostra moltiplicatore velocità")

func test_terminal_cat_command_rejects_reading_flight_dat_files() -> void:
	await _start_solo_mission()
	var terminal_res := load("res://Applications/Terminal/src/terminal_scene.tscn") as PackedScene
	assert_not_null(terminal_res, "Scena Terminal deve essere caricabile")
	
	var term: Terminal = terminal_res.instantiate() as Terminal
	add_child_autofree(term)
	await get_tree().process_frame
	
	var cat_script: GDScript = load("res://Applications/Terminal/commands/cat_command.gd")
	var cat_cmd = cat_script.new()
	term.virtual_path_manager.set_path("Ship Drive/Programs/FlightControls")
	var args: Array[String] = ["flight_config.dat"]
	cat_cmd.execute(term, args)
	
	var found_msg := false
	for c in term.command_output_container.get_children():
		if "text" in c and (c.text.contains("non sono leggibili") or c.text.contains(".dat")):
			found_msg = true
			break
	assert_true(found_msg, "Il comando cat deve rifiutare la lettura diretta del file .dat")

func test_hyperdrive_alignment_and_engage_transit() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	assert_not_null(StarSystemGridManager, "StarSystemGridManager deve essere disponibile come autoload")
	var target_sec := Vector3i(4, 15, 0)
	var plotted := StarSystemGridManager.plot_route(target_sec)
	assert_false(plotted.is_empty(), "Rotta verso (4,15,0) pianificata con successo")
	_app._update_hyperdrive_ui()
	assert_true(_app.hyperdrive_card != null and _app.hyperdrive_card.visible, "Card Hyperdrive visibile con rotta attiva")
	
	_app.align_to_hyperdrive_vector()
	assert_true(_app.is_hyperdrive_aligned(), "L'astronave deve risultare allineata al vettore Hyperdrive")
	assert_true(_app.btn_engage_hyperdrive != null and not _app.btn_engage_hyperdrive.disabled, "Pulsante Engage abilitato ad allineamento avvenuto")
	
	var res := _app.engage_hyperdrive()
	assert_true(res.get("success"), "Transito Hyperdrive completato con successo")
	assert_eq(StarSystemGridManager.get_current_sector_coords(), target_sec, "Coordinate settore aggiornate al target")
	assert_true(_app.active_hyperdrive_route.is_empty(), "Rotta ripulita dopo il transito")
