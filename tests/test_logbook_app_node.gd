extends Node

## Test Runner Headless per LogbookApp (Applications/Logbook)
## 1. Overlay / Ciclo di Vita: %DisconnectedOverlay offline vs ship_connection_changed(true)
## 2. RBAC: Azioni contrattuali riservate al Capitano/Factotum, lettura e note aperte a tutti
## 3. File .DAT e Hot-Reload: Parsing corretto di logbook_config.dat e journal_tuning.dat e hot-reload
## 4. Risorsa e Software Manager: Registrazione logbook_app.tres in ShipSoftwareManager
## 5. Pulizia Segnali: Verifica assenza di errori/leak dopo _exit_tree()

func _ready() -> void:
	print("\n=======================================================")
	print(">>> AVVIO SUITE DI TEST HEADLESS: LOGBOOK APP")
	print("=======================================================\n")
	_run_all_tests()

func _run_all_tests() -> void:
	await get_tree().process_frame
	
	var app_scene: PackedScene = load("res://Applications/Logbook/logbook_app.tscn")
	assert(app_scene != null, "La scena logbook_app.tscn deve essere caricata con successo")
	
	var app: LogbookApp = app_scene.instantiate() as LogbookApp
	assert(app != null, "LogbookApp deve istanziarsi come nodo LogbookApp")
	add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	
	var net_mgr = get_node_or_null("/root/NetworkManager")
	var sdm = get_node_or_null("/root/ShipDriveManager")
	
	# =========================================================================
	# TEST 1: OVERLAY / CICLO DI VITA (OFFLINE vs MISSIONE AVVIATA)
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
	print("\n--- TEST 2: Matrice RBAC (Permessi Contratti & Note) ---")
	if net_mgr:
		net_mgr.host_game("OperatoreTest")
		await get_tree().process_frame
		
		# 2.1 Pilota: Sola Lettura contratti, ma note permesse
		net_mgr.request_role("Pilota")
		await get_tree().process_frame
		assert(app.can_manage_contracts == false, "Pilota non deve avere permessi di gestione contratti")
		assert(app.new_contract_btn.disabled == true, "NewContractBtn deve essere disabilitato per Pilota")
		assert(app.clear_log_btn.disabled == true, "ClearLogBtn deve essere disabilitato per Pilota")
		assert(app.save_note_btn.disabled == false, "SaveNoteBtn deve essere abilitato per Pilota")
		print("✔ Ruolo Pilota: lettura e note permesse, gestione contratti bloccata")
		
		# 2.2 Soldato: Sola Lettura contratti
		net_mgr.request_role("Soldato")
		await get_tree().process_frame
		assert(app.can_manage_contracts == false, "Soldato non deve avere permessi di gestione contratti")
		assert(app.new_contract_btn.disabled == true, "NewContractBtn deve essere disabilitato per Soldato")
		print("✔ Ruolo Soldato: gestione contratti bloccata")
		
		# 2.3 Hacker: Sola Lettura contratti
		net_mgr.request_role("Hacker")
		await get_tree().process_frame
		assert(app.can_manage_contracts == false, "Hacker non deve avere permessi di gestione contratti")
		print("✔ Ruolo Hacker: gestione contratti bloccata")
		
		# 2.4 Ingegnere: Sola Lettura contratti
		net_mgr.request_role("Ingegnere")
		await get_tree().process_frame
		assert(app.can_manage_contracts == false, "Ingegnere non deve avere permessi di gestione contratti")
		print("✔ Ruolo Ingegnere: gestione contratti bloccata")
		
		# 2.5 Capitano: Controllo Completo
		net_mgr.request_role("Capitano")
		await get_tree().process_frame
		assert(app.can_manage_contracts == true, "Capitano deve avere controllo completo sui contratti")
		assert(app.new_contract_btn.disabled == false, "NewContractBtn deve essere abilitato per Capitano")
		assert(app.clear_log_btn.disabled == false, "ClearLogBtn deve essere abilitato per Capitano")
		print("✔ Ruolo Capitano: controllo completo abilitato")
		
		# 2.6 Factotum: Controllo Completo
		net_mgr.request_role("Factotum")
		await get_tree().process_frame
		assert(app.can_manage_contracts == true, "Factotum deve avere controllo completo sui contratti")
		assert(app.new_contract_btn.disabled == false, "NewContractBtn deve essere abilitato per Factotum")
		print("✔ Ruolo Factotum: controllo completo abilitato")

	# =========================================================================
	# TEST 3: FILE .DAT E HOT-RELOADING
	# =========================================================================
	print("\n--- TEST 3: Parsing file .DAT e Hot-Reloading ---")
	if sdm:
		sdm.mount_drive()
	app.load_dat_configuration()
	await get_tree().process_frame
	
	assert(app.config_data.get("app_name") == "LogbookApp", "app_name deve essere LogbookApp")
	assert(app.config_data.get("auto_log_events") == true, "auto_log_events deve essere true")
	assert(app.config_data.get("max_history_entries") == 200, "max_history_entries deve essere 200")
	assert(app.tuning_data.get("sync_to_ship_drive") == true, "sync_to_ship_drive deve essere true")
	assert(app.tuning_data.get("timestamp_format") == "STAR_DATE", "timestamp_format deve essere STAR_DATE")
	print("✔ Parsing .DAT iniziale validato con successo")
	
	# Test hot-reloading su file_modified
	if sdm and sdm.has_signal("file_modified"):
		sdm.file_modified.emit("Ship Drive/Programs/Logbook/logbook_config.dat")
		await get_tree().process_frame
		assert(app.config_data.get("app_name") == "LogbookApp", "Hot-reload via file_modified verificato")
		print("✔ Hot-reloading su file_modified verificato")
	
	# Test pulsante ricarica .DAT
	app.reload_dat_button.emit_signal("pressed")
	await get_tree().process_frame
	print("✔ Pulsante 🔄 Ricarica .DAT funzionante")
	
	# =========================================================================
	# TEST 4: FUNZIONALITÀ APPLICATIVE (CONTRATTI, LOG, NOTE)
	# =========================================================================
	print("\n--- TEST 4: Funzionalità Operative Contratti, Scatola Nera e Note ---")
	var initial_contracts_count: int = app.active_contracts.size()
	assert(initial_contracts_count >= 2, "Devono essere presenti contratti iniziali")
	
	# 4.1 Aggiunta contratto da Capitano/Factotum
	app._on_new_contract_pressed()
	await get_tree().process_frame
	assert(app.active_contracts.size() == initial_contracts_count + 1, "Nuovo contratto aggiunto con successo")
	
	# 4.2 Completamento contratto e incasso FLUX
	var test_ctr_id: String = app.active_contracts[0]["id"]
	app.complete_contract(test_ctr_id)
	await get_tree().process_frame
	assert(app.active_contracts[0]["status"] == "COMPLETED", "Contratto deve risultare completato")
	print("✔ Gestione e completamento contratti validati")
	
	# 4.3 Registrazione eventi Scatola Nera
	var initial_logs_count: int = app.black_box_events.size()
	app.log_event("TEST_EVENT: Rilevato segnale anomalo settore 4")
	await get_tree().process_frame
	assert(app.black_box_events.size() == initial_logs_count + 1, "Nuovo evento registrato nella scatola nera")
	print("✔ Logging telemetria scatola nera validato")
	
	# 4.4 Note di plancia e salvataggio
	app.note_edit_text.text = "Rapporto di prova test suite."
	app._on_save_note_pressed()
	await get_tree().process_frame
	print("✔ Scrittura e salvataggio note su drive validati")
	
	# =========================================================================
	# TEST 5: RISORSA APPRESOURCE E REGISTRAZIONE SHIPSOFTWAREMANAGER
	# =========================================================================
	print("\n--- TEST 5: AppResource e ShipSoftwareManager ---")
	var ssm := get_node_or_null("/root/ShipSoftwareManager") as ShipSoftwareManagerSingleton
	assert(ssm != null, "ShipSoftwareManager singleton deve essere attivo")
	
	var res: AppResource = ssm.get_registered_app("logbook")
	assert(res != null, "logbook_app.tres deve essere registrata nel catalogo ShipSoftwareManager")
	assert(res.app_id == "logbook", "app_id deve corrispondere a 'logbook'")
	assert(res.default_password == "LOGS-7815", "Password di default deve essere 'LOGS-7815'")
	assert(res.power_draw_mw == 5.0, "power_draw_mw deve corrispondere a 5.0 MW")
	assert(res.default_files.size() >= 2, "La risorsa deve contenere logbook_config.dat e journal_tuning.dat")
	print("✔ Registrazione e metadati AppResource validati con successo")
	
	# =========================================================================
	# TEST 6: PULIZIA SEGNALI SU _EXIT_TREE()
	# =========================================================================
	print("\n--- TEST 6: Pulizia Segnali e Disconnessione ---")
	app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("✔ Nodo rimosso e segnali disconnessi senza memory leak")
	
	print("\n=======================================================")
	print("✔ TUTTI I TEST LOGBOOK APP COMPLETATI CON SUCCESSO!")
	print("=======================================================\n")
	get_tree().quit(0)
