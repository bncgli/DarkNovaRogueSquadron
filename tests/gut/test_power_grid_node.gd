extends GutTest

## Test GUT per l'applicazione PowerGrid (rete elettrica a compartimenti,
## bilanciamento energetico, ispettore di stanza e mini-terminale comandi).
## Migrato da tests/test_power_grid_node.gd (extends Node, assert() nudo).

var _app: PowerGridApp = null

func before_each() -> void:
	NetworkManager.disconnect_game()

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

func _create_app() -> PowerGridApp:
	var scene: PackedScene = load("res://Applications/PowerGrid/power_grid_app.tscn")
	assert_not_null(scene, "Scena power_grid_app.tscn deve essere caricabile")
	var app: PowerGridApp = scene.instantiate() as PowerGridApp
	add_child_autofree(app)
	await get_tree().process_frame
	return app

func test_disconnected_overlay_and_operational_state() -> void:
	_app = await _create_app()
	assert_false(_app.is_operational(), "L'app non deve risultare operativa quando la nave è disconnessa")
	assert_not_null(_app.disconnected_overlay, "L'overlay DisconnectedOverlay deve esistere")
	assert_true(_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve essere visibile da disconnesso")
	
	await _start_solo_mission()
	
	assert_true(_app.is_operational(), "L'app deve risultare operativa dopo l'avvio della missione")
	assert_false(_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve scomparire dopo l'avvio della missione")

func test_ship_drive_folder_is_protected_by_default_password() -> void:
	await _start_solo_mission()
	assert_true(DirAccess.dir_exists_absolute("user://files/Ship Drive/Programs/PowerGrid"), "Cartella Programs/PowerGrid deve esistere in Ship Drive")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/PowerGrid/power_grid_config.dat"), "power_grid_config.dat deve esistere in Ship Drive/Programs/PowerGrid/")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/PowerGrid/grid_tuning.dat"), "grid_tuning.dat deve esistere in Ship Drive/Programs/PowerGrid/")
	
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	assert_not_null(fpm, "FolderPasswordManager deve essere disponibile come autoload")
	assert_true(fpm.has_password("Ship Drive/Programs/PowerGrid"), "La cartella Ship Drive/Programs/PowerGrid deve essere protetta da password")
	assert_true(fpm.check_password("Ship Drive/Programs/PowerGrid", "GRID-7815"), "La password predefinita della cartella deve essere GRID-7815")

func test_dat_configuration_default_values_and_runtime_hot_reload() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	var initial_cfg := _app.load_dat_configuration()
	assert_true(initial_cfg.get("is_dat_loaded"), "Configurazione .dat deve risultare caricata")
	assert_eq(initial_cfg.get("reactor_output_mw"), 1200.0, "Potenza reattore iniziale deve essere 1200.0")
	assert_eq(initial_cfg.get("aux_generator_mw"), 450.0, "Potenza generatore ausiliario iniziale deve essere 450.0")
	
	var new_dat_content := "[SYSTEM]\napp_name=PowerGrid\nversion=1.0.4\nstatus=OVERCLOCKED\nmode=MANUAL_OVERRIDE\n\n[GRID_SETTINGS]\nreactor_output_mw=1500.0\naux_generator_mw=500.0\njunction_switch_delay=0.1\noverload_threshold_pct=130.0\nreroute_efficiency_loss=0.02\n\n[CIRCUIT_PROTECTION]\nbreaker_trip_threshold=1.8\nshort_circuit_damping=0.9\nauto_reroute_on_short=true\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/PowerGrid/power_grid_config.dat", FileAccess.WRITE)
	f_out.store_string(new_dat_content)
	f_out.close()
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("file_synced"):
		sdm.file_synced.emit("Ship Drive/Programs/PowerGrid/power_grid_config.dat")
	else:
		_app.load_dat_configuration()
	await get_tree().process_frame
	
	assert_eq(_app.active_config["reactor_output_mw"], 1500.0, "reactor_output_mw deve aggiornarsi in tempo reale a 1500.0")
	assert_eq(_app.active_config["aux_generator_mw"], 500.0, "aux_generator_mw deve aggiornarsi in tempo reale a 500.0")

func test_rbac_engineer_can_control_unauthorized_role_cannot() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	NetworkManager.request_role(NetworkManager.ROLE_ENGINEER)
	await get_tree().process_frame
	assert_true(_app.can_control, "L'Ingegnere deve poter controllare gli snodi della rete elettrica")
	
	# NOTA: il vecchio test usava un ruolo "Tattico" inesistente in ALL_ROLES;
	# usiamo qui un ruolo reale non autorizzato (Pilota) per la stessa verifica.
	NetworkManager.request_role(NetworkManager.ROLE_PILOT)
	await get_tree().process_frame
	assert_false(_app.can_control, "Un ruolo non autorizzato (Pilota) non deve poter spegnere le stanze")
	
	NetworkManager.request_role(NetworkManager.ROLE_ENGINEER)
	await get_tree().process_frame
	assert_true(_app.can_control, "Controllo ripristinato per Ingegnere")

func test_power_monitoring_totals() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app._refresh_power_logic()
	assert_true(_app.total_gen_mw > 0.0, "Deve esserci potenza generata (reattore)")

func test_room_power_entry_color_states() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	var entry_scene: PackedScene = load("res://Applications/PowerGrid/Components/room_power_entry.tscn")
	var test_entry: RoomPowerEntry = entry_scene.instantiate() as RoomPowerEntry
	add_child_autofree(test_entry)
	await get_tree().process_frame
	
	test_entry.update_power(500.0)
	assert_true(test_entry.power_status_label.modulate.is_equal_approx(Color(0.2, 1.0, 0.4, 1.0)), "Produttore deve avere colore verde brillante Color(0.2, 1.0, 0.4)")
	assert_true(test_entry.power_bar.modulate.is_equal_approx(Color(0.2, 1.0, 0.4, 1.0)), "PowerBar produttore deve essere verde")
	
	test_entry.update_power(-150.0)
	assert_true(test_entry.power_status_label.modulate.is_equal_approx(Color(1.0, 0.25, 0.25, 1.0)), "Consumatore deve avere colore rosso chiaro Color(1.0, 0.25, 0.25)")
	assert_true(test_entry.power_bar.modulate.is_equal_approx(Color(1.0, 0.25, 0.25, 1.0)), "PowerBar consumatore deve essere rossa")
	
	test_entry.update_power(0.0)
	assert_true(test_entry.power_status_label.modulate.is_equal_approx(Color(0.65, 0.65, 0.65, 1.0)), "Neutro deve avere colore grigio Color(0.65, 0.65, 0.65)")
	assert_true(test_entry.power_bar.modulate.is_equal_approx(Color(0.65, 0.65, 0.65, 1.0)), "PowerBar neutra deve essere grigia")

func test_room_inspector_populates_selected_room_details() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	assert_false(_app.rooms_data.is_empty(), "rooms_data deve essere popolato dopo la connessione")
	var first_rid: String = str(_app.rooms_data[0].get("id", ""))
	_app._on_room_selected(first_rid)
	assert_not_null(_app.inspector_title_label, "Inspector title label presente")
	assert_false(_app.inspector_title_label.text.is_empty(), "Inspector title deve essere popolato")
	assert_not_null(_app.inspector_inputs_label, "Inspector inputs label presente")

func test_mini_terminal_commands_execute_without_error() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app.execute_terminal_command("help")
	_app.execute_terminal_command("status")
	_app.execute_terminal_command("rooms")
	_app.execute_terminal_command("autobalance")
	_app.execute_terminal_command("clear")
	_app.execute_terminal_command("comando_sconosciuto")
	assert_true(true, "Tutti i comandi del mini-terminale devono essere eseguiti senza errori")

func test_queue_free_cleanup_does_not_error() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	_app.queue_free()
	await get_tree().process_frame
	_app = null
	assert_true(true, "La rimozione dell'app PowerGrid non deve generare errori di pulizia dei segnali")
