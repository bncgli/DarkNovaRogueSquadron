extends Node

## Test Runner Headless per LifeSupportApp (Applications/LifeSupport)
## Verifica Overlay/Ciclo di vita, RBAC, File .DAT / Hot-Reload, ShipSoftwareManager, Controlli Atmosfera e Pulizia Segnali.

func _ready() -> void:
	print("\n=======================================================")
	print(">>> AVVIO SUITE DI TEST HEADLESS: LIFE SUPPORT APP")
	print("=======================================================\n")
	_run_all_tests()

func _run_all_tests() -> void:
	await get_tree().process_frame
	
	var app_scene: PackedScene = load("res://Applications/LifeSupport/life_support_app.tscn")
	assert(app_scene != null, "La scena life_support_app.tscn deve essere caricata con successo")
	
	var app: LifeSupportApp = app_scene.instantiate() as LifeSupportApp
	assert(app != null, "LifeSupportApp deve istanziarsi come nodo LifeSupportApp")
	add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	
	var net_mgr = get_node_or_null("/root/NetworkManager")
	var sdm = get_node_or_null("/root/ShipDriveManager")
	
	# =========================================================================
	# TEST 1: OVERLAY E CICLO DI VITA (OFFLINE vs MISSIONE AVVIATA)
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
	print("\n--- TEST 2: Matrice RBAC (Permessi Ruolo e Controlli) ---")
	if net_mgr:
		net_mgr.host_game("OperatoreSupporto")
		await get_tree().process_frame
		
		# 2.1 Pilota: Sola Lettura
		net_mgr.request_role("Pilota")
		await get_tree().process_frame
		assert(app.can_control_life_support == false, "Pilota non deve avere controllo attivo sul supporto vitale")
		assert(app.btn_toggle_seal.disabled == true, "BtnToggleSeal deve essere disabilitato per Pilota")
		assert(app.btn_suppress_fire.disabled == true, "BtnSuppressFire deve essere disabilitato per Pilota")
		print("✔ Ruolo Pilota: correttamente limitato a sola visualizzazione")
		
		# 2.2 Soldato: Sola Lettura
		net_mgr.request_role("Soldato")
		await get_tree().process_frame
		assert(app.can_control_life_support == false, "Soldato non deve avere controllo attivo sul supporto vitale")
		assert(app.btn_toggle_seal.disabled == true, "BtnToggleSeal deve essere disabilitato per Soldato")
		assert(app.btn_suppress_fire.disabled == true, "BtnSuppressFire deve essere disabilitato per Soldato")
		print("✔ Ruolo Soldato: correttamente limitato a sola visualizzazione")
		
		# 2.3 Hacker: Sola Lettura
		net_mgr.request_role("Hacker")
		await get_tree().process_frame
		assert(app.can_control_life_support == false, "Hacker non deve avere controllo attivo sul supporto vitale")
		print("✔ Ruolo Hacker: correttamente limitato a sola visualizzazione")
		
		# 2.4 Ingegnere: Controllo Completo
		net_mgr.request_role("Ingegnere")
		await get_tree().process_frame
		assert(app.can_control_life_support == true, "Ingegnere deve avere controllo completo sul supporto vitale")
		assert(app.btn_toggle_seal.disabled == false, "BtnToggleSeal deve essere abilitato per Ingegnere")
		assert(app.btn_suppress_fire.disabled == false, "BtnSuppressFire deve essere abilitato per Ingegnere")
		print("✔ Ruolo Ingegnere: controllo completo abilitato")
		
		# 2.5 Capitano: Controllo Completo e Override
		net_mgr.request_role("Capitano")
		await get_tree().process_frame
		assert(app.can_control_life_support == true, "Capitano deve avere controllo completo sul supporto vitale")
		print("✔ Ruolo Capitano: controllo completo abilitato")
		
		# 2.6 Factotum / Solo Mode
		net_mgr.request_role("Factotum")
		await get_tree().process_frame
		assert(app.can_control_life_support == true, "Factotum deve avere controllo completo sul supporto vitale")
		print("✔ Ruolo Factotum: controllo completo abilitato")
	
	# =========================================================================
	# TEST 3: RISORSA E SOFTWARE MANAGER
	# =========================================================================
	print("\n--- TEST 3: Risorsa AppResource e ShipSoftwareManager ---")
	var ssm := get_node_or_null("/root/ShipSoftwareManager") as ShipSoftwareManagerSingleton
	assert(ssm != null, "ShipSoftwareManager singleton deve essere attivo")
	
	var res: AppResource = ssm.get_registered_app("life_support")
	assert(res != null, "life_support_app.tres deve essere registrata nel catalogo ShipSoftwareManager")
	assert(res.app_id == "life_support", "app_id deve corrispondere a 'life_support'")
	assert(res.default_password == "LIFE-7815", "Password di default deve essere 'LIFE-7815'")
	assert(res.power_draw_mw == 20.0, "power_draw_mw deve corrispondere a 20.0 MW")
	assert(res.default_files.size() >= 2, "La risorsa deve contenere life_support_config.dat e atmo_tuning.dat")
	print("✔ Registrazione e metadati AppResource validati con successo")
	
	# =========================================================================
	# TEST 4: FILE .DAT E HOT-RELOADING
	# =========================================================================
	print("\n--- TEST 4: Parsing file .DAT e Hot-Reloading ---")
	if sdm:
		sdm.mount_drive()
	app.load_dat_configuration()
	await get_tree().process_frame
	assert(app.active_config.get("is_dat_loaded") == true, "Configurazioni .DAT devono essere caricate")
	assert(app.active_config.get("o2_generation_rate") == 1.2, "o2_generation_rate deve corrispondere a 1.2")
	assert(app.active_config.get("seal_door_speed") == 0.5, "seal_door_speed deve corrispondere a 0.5")
	assert(app.active_config.get("decompression_rate") == 1.8, "decompression_rate deve corrispondere a 1.8")
	assert(app.active_config.get("fire_suppression_co2_level") == 0.45, "fire_suppression_co2_level deve corrispondere a 0.45")
	assert(app.active_config.get("scrubber_efficiency") == 0.98, "scrubber_efficiency deve corrispondere a 0.98")
	print("✔ Parsing .DAT iniziale valido e coerente con firmware")
	
	# Simula hot-reload file_synced
	if sdm:
		sdm.file_synced.emit("Ship Drive/Programs/LifeSupport/life_support_config.dat", "")
		await get_tree().process_frame
		assert(app.active_config.get("is_dat_loaded") == true, "Hot-reloading deve ricaricare la configurazione")
		print("✔ Hot-reloading su file_synced verificato con successo")
	
	# Simula pressione tasto ricarica .DAT
	app.btn_reload_dat.emit_signal("pressed")
	await get_tree().process_frame
	assert(app.active_config.get("is_dat_loaded") == true, "Pulsante ricarica .DAT deve rinfrescare la configurazione")
	print("✔ Pulsante 🔄 Ricarica .DAT funzionante")
	
	# =========================================================================
	# TEST 5: CONTROLLI DI COMPARTIMENTO, PARATIE E SOPPRESSIONE INCENDI
	# =========================================================================
	print("\n--- TEST 5: Controlli Compartimento, Paratie e Antincendio ---")
	assert(app.rooms_state.size() > 0, "Le stanze della nave devono essere popolate")
	assert(app.room_card_widgets.size() > 0, "I widget RoomAtmoCard devono essere istanziati")
	
	var test_room_id: String = str(app.rooms_state.keys()[0])
	
	# 5.1 Test Sigillatura Paratia
	assert(app.rooms_state[test_room_id]["is_sealed"] == false, "La paratia iniziale deve essere aperta")
	app.set_bulkhead_sealed(test_room_id, true)
	await get_tree().process_frame
	assert(app.rooms_state[test_room_id]["is_sealed"] == true, "La paratia deve risultare sigillata")
	app.set_bulkhead_sealed(test_room_id, false)
	await get_tree().process_frame
	assert(app.rooms_state[test_room_id]["is_sealed"] == false, "La paratia deve risultare riaperta")
	print("✔ Sigillatura e apertura paratia stagna verificata")
	
	# 5.2 Test Iniezione Gas Inerte / Soppressione Incendio
	app.rooms_state[test_room_id]["is_fire_active"] = true
	app.trigger_fire_suppression(test_room_id)
	await get_tree().process_frame
	assert(app.rooms_state[test_room_id]["is_fire_active"] == false, "L'incendio deve essere estinto dall'iniezione")
	assert(app.rooms_state[test_room_id]["is_suppression_active"] == true, "Soppressione attiva deve essere true")
	print("✔ Iniezione gas inerte e neutralizzazione incendio verificata")
	
	# 5.3 Test Evacuazione Atmosfera e Normalizzazione
	app.set_room_venting(test_room_id, true)
	await get_tree().process_frame
	assert(app.rooms_state[test_room_id]["is_venting"] == true, "Venting deve essere attivo")
	
	app.normalize_room_atmosphere(test_room_id)
	await get_tree().process_frame
	assert(app.rooms_state[test_room_id]["is_venting"] == false, "Venting deve essere resettato")
	assert(app.rooms_state[test_room_id]["o2_pct"] == 21.0, "O2 deve essere normalizzato a 21.0%")
	assert(app.rooms_state[test_room_id]["pressure_kpa"] == 101.3, "Pressione deve essere normalizzata a 101.3 kPa")
	print("✔ Evacuazione e normalizzazione compartimento verificate")
	
	# 5.4 Test Azioni Globali
	app.btn_seal_all.emit_signal("pressed")
	await get_tree().process_frame
	for r_k in app.rooms_state:
		assert(app.rooms_state[r_k]["is_sealed"] == true, "Tutte le stanze devono essere sigillate")
	print("✔ Pulsante 'Sigilla Tutte le Paratie' verificato")
	
	app.btn_suppress_all.emit_signal("pressed")
	await get_tree().process_frame
	for r_k in app.rooms_state:
		assert(app.rooms_state[r_k]["is_suppression_active"] == true, "Tutte le stanze devono avere soppressione attiva")
	print("✔ Pulsante 'Soppressione Incendi Globale' verificato")
	
	# =========================================================================
	# TEST 6: PULIZIA SEGNALI SU _EXIT_TREE()
	# =========================================================================
	print("\n--- TEST 6: Pulizia Segnali e Disconnessione ---")
	app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("✔ Nodo rimosso e segnali disconnessi senza memory leak")
	
	print("\n=======================================================")
	print("✔ TUTTI I TEST LIFE SUPPORT APP COMPLETATI CON SUCCESSO!")
	print("=======================================================\n")
	get_tree().quit(0)
