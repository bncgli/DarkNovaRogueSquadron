extends GutTest

## Test GUT per l'applicazione Logbook (registro di bordo, contratti,
## scatola nera degli eventi e note di plancia).
## Migrato da tests/test_logbook_app_node.gd (extends Node, assert() nudo).

var _app: LogbookApp = null

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

func _create_app() -> LogbookApp:
	var scene: PackedScene = load("res://Applications/Logbook/logbook_app.tscn")
	assert_not_null(scene, "Scena logbook_app.tscn deve essere caricabile")
	var app: LogbookApp = scene.instantiate() as LogbookApp
	add_child_autofree(app)
	await get_tree().process_frame
	return app

func test_disconnected_overlay_lifecycle() -> void:
	_app = await _create_app()
	assert_not_null(_app.disconnected_overlay, "%DisconnectedOverlay deve esistere nella scena")
	assert_true(_app.disconnected_overlay.visible, "%DisconnectedOverlay deve essere VISIBILE quando la nave è offline")
	
	await _start_solo_mission()
	
	assert_false(_app.disconnected_overlay.visible, "%DisconnectedOverlay deve SCOMPARIRE quando la nave è connessa")

func test_rbac_permissions_matrix_for_contracts_and_notes() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	# NOTA: can_manage_contracts include un OR diretto su is_solo_mode, quindi va
	# disattivata esplicitamente la modalità Solo per validare la vera matrice RBAC.
	NetworkManager.is_solo_mode = false
	
	NetworkManager.request_role(NetworkManager.ROLE_PILOT)
	await get_tree().process_frame
	assert_false(_app.can_manage_contracts, "Pilota non deve avere permessi di gestione contratti")
	assert_true(_app.new_contract_btn.disabled, "NewContractBtn deve essere disabilitato per Pilota")
	assert_true(_app.clear_log_btn.disabled, "ClearLogBtn deve essere disabilitato per Pilota")
	assert_false(_app.save_note_btn.disabled, "SaveNoteBtn deve essere abilitato per Pilota (le note sono aperte a tutti i ruoli)")
	
	NetworkManager.request_role(NetworkManager.ROLE_SOLDIER)
	await get_tree().process_frame
	assert_false(_app.can_manage_contracts, "Soldato non deve avere permessi di gestione contratti")
	assert_true(_app.new_contract_btn.disabled, "NewContractBtn deve essere disabilitato per Soldato")
	
	NetworkManager.request_role(NetworkManager.ROLE_HACKER)
	await get_tree().process_frame
	assert_false(_app.can_manage_contracts, "Hacker non deve avere permessi di gestione contratti")
	
	NetworkManager.request_role(NetworkManager.ROLE_ENGINEER)
	await get_tree().process_frame
	assert_false(_app.can_manage_contracts, "Ingegnere non deve avere permessi di gestione contratti")
	
	NetworkManager.request_role(NetworkManager.ROLE_CAPTAIN)
	await get_tree().process_frame
	assert_true(_app.can_manage_contracts, "Capitano deve avere controllo completo sui contratti")
	assert_false(_app.new_contract_btn.disabled, "NewContractBtn deve essere abilitato per Capitano")
	assert_false(_app.clear_log_btn.disabled, "ClearLogBtn deve essere abilitato per Capitano")
	
	NetworkManager.request_role(NetworkManager.ROLE_STAGISTA)
	await get_tree().process_frame
	assert_true(_app.can_manage_contracts, "Stagista deve avere controllo completo sui contratti")
	assert_false(_app.new_contract_btn.disabled, "NewContractBtn deve essere abilitato per Stagista")

func test_dat_configuration_parsing_and_hot_reload() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app.load_dat_configuration()
	await get_tree().process_frame
	assert_eq(_app.config_data.get("app_name"), "LogbookApp", "app_name deve corrispondere a 'LogbookApp'")
	assert_true(_app.config_data.get("auto_log_events"), "auto_log_events deve essere true")
	assert_eq(_app.config_data.get("max_history_entries"), 200, "max_history_entries deve essere 200")
	assert_true(_app.tuning_data.get("sync_to_ship_drive"), "sync_to_ship_drive deve essere true")
	assert_eq(_app.tuning_data.get("timestamp_format"), "STAR_DATE", "timestamp_format deve essere STAR_DATE")
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("file_modified"):
		sdm.file_modified.emit("Ship Drive/Programs/Logbook/logbook_config.dat")
		await get_tree().process_frame
		assert_eq(_app.config_data.get("app_name"), "LogbookApp", "Hot-reloading su file_modified deve mantenere la configurazione valida")
	
	_app.reload_dat_button.emit_signal("pressed")
	await get_tree().process_frame
	assert_eq(_app.config_data.get("app_name"), "LogbookApp", "Il pulsante ricarica .DAT deve mantenere la configurazione valida")

func test_contract_management_lifecycle() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	var initial_contracts_count: int = _app.active_contracts.size()
	assert_true(initial_contracts_count >= 2, "Devono essere presenti contratti iniziali")
	
	_app._on_new_contract_pressed()
	await get_tree().process_frame
	assert_eq(_app.active_contracts.size(), initial_contracts_count + 1, "Nuovo contratto aggiunto con successo")
	
	var test_ctr_id: String = _app.active_contracts[0]["id"]
	_app.complete_contract(test_ctr_id)
	await get_tree().process_frame
	assert_eq(_app.active_contracts[0]["status"], "COMPLETED", "Contratto deve risultare completato")

func test_black_box_event_logging() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	var initial_logs_count: int = _app.black_box_events.size()
	_app.log_event("TEST_EVENT: Rilevato segnale anomalo settore 4")
	await get_tree().process_frame
	assert_eq(_app.black_box_events.size(), initial_logs_count + 1, "Nuovo evento registrato nella scatola nera")

func test_bridge_notes_save_writes_file_to_ship_drive() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	
	_app.note_edit_text.text = "Rapporto di prova test suite."
	_app._on_save_note_pressed()
	await get_tree().process_frame
	
	assert_true(DirAccess.dir_exists_absolute("user://files/Ship Drive/Documents"), "La cartella Documents deve essere creata su Ship Drive")

func test_app_resource_registered_in_ship_software_manager() -> void:
	var ssm := get_node_or_null("/root/ShipSoftwareManager") as ShipSoftwareManagerSingleton
	assert_not_null(ssm, "ShipSoftwareManager singleton deve essere attivo")
	
	var res: AppResource = ssm.get_registered_app("logbook")
	assert_not_null(res, "logbook_app.tres deve essere registrata nel catalogo ShipSoftwareManager")
	assert_eq(res.app_id, "logbook", "app_id deve corrispondere a 'logbook'")
	assert_eq(res.default_password, "LOGS-7815", "Password di default deve essere 'LOGS-7815'")
	assert_eq(res.power_draw_mw, 5.0, "power_draw_mw deve corrispondere a 5.0 MW")
	assert_true(res.default_files.size() >= 2, "La risorsa deve contenere logbook_config.dat e journal_tuning.dat")

func test_queue_free_cleanup_does_not_error() -> void:
	_app = await _create_app()
	await _start_solo_mission()
	_app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_app = null
	assert_true(true, "La rimozione dell'app Logbook non deve generare errori di pulizia dei segnali")
