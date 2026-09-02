extends Node

func _ready() -> void:
	print("--- INIZIO TEST COMPLETO COMMS, ELECTRONIC WARFARE & ARCHITECTURE STANDARD ---")
	_run_suite.call_deferred()

func _run_suite() -> void:
	await get_tree().process_frame
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	var net_mgr := get_node_or_null("/root/NetworkManager")
	
	# =========================================================================
	# FASE 1: TEST STATO OFFLINE / LOBBY (DISCONNECTED OVERLAY & LIFE CYCLE)
	# =========================================================================
	print("\n--- TEST 1: Stato Offline / Overlay Disconnesso ---")
	if net_mgr:
		net_mgr.disconnect_game()
	await get_tree().process_frame
	
	var comms_app_scene: PackedScene = load("res://Applications/Comms/comms_app.tscn")
	assert(comms_app_scene != null, "Scena comms_app.tscn valida")
	var comms_app: CommsApp = comms_app_scene.instantiate() as CommsApp
	add_child(comms_app)
	await get_tree().process_frame
	
	assert(not comms_app._is_ship_operational(), "L'app Comms non deve essere operativa a nave disconnessa")
	assert(comms_app.disconnected_overlay != null and comms_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve essere visibile da disconnesso")
	print("✔ Overlay di blocco visibile e operativo da disconnesso")
	
	# =========================================================================
	# FASE 2: AVVIO MISSIONE & STATO OPERATIVO
	# =========================================================================
	print("\n--- TEST 2: Avvio Missione & Connessione Nave ---")
	if net_mgr:
		net_mgr.start_solo_game("Hacker")
		net_mgr.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame
	
	assert(comms_app._is_ship_operational(), "L'app Comms deve essere operativa dopo l'avvio della missione")
	assert(comms_app.disconnected_overlay != null and not comms_app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve scomparire all'avvio della missione")
	print("✔ Overlay rimosso istantaneamente all'avvio della missione")
	
	# =========================================================================
	# FASE 3: CARTELLA DRIVE PROTETTA & FILE .DAT DI DEFAULT
	# =========================================================================
	print("\n--- TEST 3: Cartella Protetta Ship Drive/Programs/Comms e file .dat ---")
	assert(DirAccess.dir_exists_absolute("user://files/Ship Drive/Programs/Comms"), "Cartella Programs/Comms deve esistere in Ship Drive")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/Comms/comms_config.dat"), "comms_config.dat deve esistere in Ship Drive/Programs/Comms/")
	assert(FileAccess.file_exists("user://files/Ship Drive/Programs/Comms/crypto_tuning.dat"), "crypto_tuning.dat deve esistere in Ship Drive/Programs/Comms/")
	
	if fpm:
		assert(fpm.has_password("Ship Drive/Programs/Comms"), "La cartella Ship Drive/Programs/Comms deve essere protetta da password")
		assert(fpm.check_password("Ship Drive/Programs/Comms", "COMM-7815"), "La password predefinita della cartella deve essere COMM-7815")
	print("✔ Cartella e file .dat protetti creati con successo in Ship Drive con password COMM-7815")
	
	# =========================================================================
	# FASE 4: CARICAMENTO DINAMICO DEI PARAMETRI .DAT E HOT-RELOADING A RUNTIME
	# =========================================================================
	print("\n--- TEST 4: Caricamento dinamico ed effetto a runtime dei parametri .dat ---")
	comms_app.load_dat_configuration()
	assert(comms_app.active_config.get("is_dat_loaded") == true, "Configurazione .dat deve risultare caricata")
	assert(comms_app.active_config.get("bandwidth_hz") == 1420.0, "bandwidth_hz di fabbrica deve essere 1420.0")
	assert(comms_app.active_config.get("jamming_power_mw") == 120.0, "jamming_power_mw di fabbrica deve essere 120.0")
	print("✔ Valori iniziali .dat caricati con successo")
	
	# Modifica dinamica di comms_config.dat e crypto_tuning.dat
	var new_dat_content := "[SYSTEM]\napp_name=Comms\nversion=1.0.4\nstatus=OVERCLOCKED\ncomms_subsystem=ACTIVE\n\n[COMMS_SETTINGS]\nbandwidth_hz=1680.0\ndecryption_speed_multiplier=2.0\nsubspace_relay_active=true\nauto_tune_sos=true\nsignal_amplification=1.5\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/Comms/comms_config.dat", FileAccess.WRITE)
	f_out.store_string(new_dat_content)
	f_out.close()
	
	var new_tuning_content := "[ELECTRONIC_WARFARE]\njamming_power_mw=160.0\nsignal_noise_ratio=0.95\nspoofing_signature=MILITARY_ESCORT\njamming_radius=25000.0\noverclock_ew_boost=1.5\ncrypto_crack_speed=2.5\n"
	var f_tune := FileAccess.open("user://files/Ship Drive/Programs/Comms/crypto_tuning.dat", FileAccess.WRITE)
	f_tune.store_string(new_tuning_content)
	f_tune.close()
	
	# Notifica evento sincronizzazione drive
	if sdm:
		sdm.file_synced.emit("Ship Drive/Programs/Comms/comms_config.dat")
	else:
		comms_app.load_dat_configuration()
	await get_tree().process_frame
	
	assert(comms_app.active_config["bandwidth_hz"] == 1680.0, "bandwidth_hz aggiornato a runtime a 1680.0")
	assert(comms_app.active_config["decryption_speed_multiplier"] == 2.0, "decryption_speed_multiplier aggiornato a 2.0")
	assert(comms_app.active_config["jamming_power_mw"] == 160.0, "jamming_power_mw aggiornato a 160.0")
	assert(comms_app.active_config["spoofing_signature"] == "MILITARY_ESCORT", "spoofing_signature aggiornato a MILITARY_ESCORT")
	assert(comms_app.active_config["crypto_crack_speed"] == 2.5, "crypto_crack_speed aggiornato a 2.5")
	print("✔ Modifica del file .dat recepita in tempo reale tramite Hot-Reloading")
	
	# =========================================================================
	# FASE 5: CONTROLLO RUOLI RBAC
	# =========================================================================
	print("\n--- TEST 5: Controllo Ruoli RBAC ---")
	if net_mgr:
		net_mgr.is_solo_mode = false # Disabilita solo mode per verificare i singoli ruoli
		
		# Ruolo Hacker (Pieno controllo)
		net_mgr.request_role("Hacker")
		await get_tree().process_frame
		assert(comms_app.can_control_comms == true, "Hacker deve avere pieno controllo su Comms ed EW")
		assert(comms_app.freq_slider.editable == true, "Slider frequenza abilitato per Hacker")
		assert(comms_app.jammer_switch.disabled == false, "Interruttore Jammer abilitato per Hacker")
		assert(comms_app.btn_start_decrypt.disabled == false, "Pulsante decrittazione abilitato per Hacker")
		
		# Ruolo Capitano (Pieno controllo & Override)
		net_mgr.request_role("Capitano")
		await get_tree().process_frame
		assert(comms_app.can_control_comms == true, "Capitano deve avere pieno controllo su Comms ed EW")
		assert(comms_app.jammer_switch.disabled == false, "Interruttore Jammer abilitato per Capitano")
		
		# Ruolo Pilota (Sola visualizzazione)
		net_mgr.request_role("Pilota")
		await get_tree().process_frame
		assert(comms_app.can_control_comms == false, "Pilota non deve avere controllo su Comms ed EW")
		assert(comms_app.freq_slider.editable == false, "Slider frequenza in sola lettura per Pilota")
		assert(comms_app.jammer_switch.disabled == true, "Interruttore Jammer disabilitato per Pilota")
		assert(comms_app.btn_start_decrypt.disabled == true, "Pulsante decrittazione disabilitato per Pilota")
		
		# Ruolo Ingegnere (Sola visualizzazione)
		net_mgr.request_role("Ingegnere")
		await get_tree().process_frame
		assert(comms_app.can_control_comms == false, "Ingegnere non deve avere controllo su Comms ed EW")
		
		# Ruolo Soldato (Sola visualizzazione)
		net_mgr.request_role("Soldato")
		await get_tree().process_frame
		assert(comms_app.can_control_comms == false, "Soldato non deve avere controllo su Comms ed EW")
		
		# Ripristina Hacker
		net_mgr.request_role("Hacker")
		await get_tree().process_frame
		assert(comms_app.can_control_comms == true, "Ripristinato controllo per Hacker")
	print("✔ Matrice dei ruoli RBAC verificata con successo")
	
	# =========================================================================
	# FASE 6: SINTONIZZATORE RADIO & WATERFALL DISPLAY
	# =========================================================================
	print("\n--- TEST 6: Sintonizzatore Radio Subspaziale & Waterfall Display ---")
	# 1. Sintonizzazione su frequenza SOS
	comms_app._on_btn_tune_sos_pressed()
	assert(comms_app.current_frequency == 850.5, "Frequenza deve essere 850.5 MHz")
	var locked_sos: Variant = comms_app._get_locked_signal()
	assert(locked_sos != null and locked_sos.get("id") == "sos_scout")
	assert(comms_app.btn_listen_signal.disabled == false, "Pulsante ascolto abilitato per segnale agganciato")
	
	# 2. Trascrizione messaggio SOS nel log
	comms_app._on_btn_listen_signal_pressed()
	var log_str := comms_app.comms_log_text.get_parsed_text()
	if log_str.is_empty():
		log_str = comms_app.comms_log_text.text
	assert(log_str.contains("SOS") or log_str.contains("Relitto"), "Log comunicazioni deve contenere il messaggio SOS")
	
	# 3. Sintonizzazione su Relay Subspaziale 1420.0 MHz
	comms_app._on_btn_tune_subspace_pressed()
	var locked_subspace: Variant = comms_app._get_locked_signal()
	assert(locked_subspace != null and locked_subspace.get("id") == "subspace_corp")
	
	# 4. Sintonizzazione su canale pirata
	comms_app._on_btn_tune_pirate_pressed()
	assert(comms_app.current_frequency == 2185.2, "Frequenza deve essere 2185.2 MHz")
	print("✔ Sintonizzatore frequenze, waterfall display e aggancio portante convalidati")
	
	# =========================================================================
	# FASE 7: MODULO GUERRA ELETTRONICA (EW JAMMING & SPOOFING IFF)
	# =========================================================================
	print("\n--- TEST 7: Modulo Guerra Elettronica (Jamming & Spoofing) ---")
	# Attiva Jammer
	comms_app._on_jammer_toggled(true)
	assert(comms_app.is_jamming_active == true, "Jammer deve risultare attivo")
	assert(comms_app.status_badge.text.contains("JAMMING ATTIVO"), "Status badge deve indicare Jamming attivo")
	
	# Modifica potenza Jammer
	comms_app._on_jammer_power_changed(180.0)
	assert(comms_app.jamming_power_mw == 180.0, "Potenza Jammer impostata a 180 MW")
	assert(comms_app.power_badge.text.contains("230 MW"), "Potenza totale deve includere 50 base + 180 jamming")
	
	# Selezione firma Spoofing
	comms_app.spoof_signature_option.selected = 1
	comms_app._on_spoof_signature_selected(1)
	assert(comms_app.current_spoof_sig == "CARGO_HAULER_MINING", "Firma IFF falsificata in CARGO_HAULER_MINING")
	
	# Spegni Jammer
	comms_app._on_jammer_toggled(false)
	assert(comms_app.is_jamming_active == false, "Jammer disattivato")
	print("✔ Guerra Elettronica, assorbimento MW e spoofing transponder verificati con successo")
	
	# =========================================================================
	# FASE 8: MODULO HACKWARFARE & DECODIFICA CIFRARI
	# =========================================================================
	print("\n--- TEST 8: Modulo Hackwarfare & Decodifica Cifrari ---")
	# Seleziona pacchetto #0 (Sonda Drone Relitto - Password DRONE-7815)
	comms_app._on_cipher_package_selected(0)
	assert(comms_app.selected_package_index == 0, "Pacchetto 0 selezionato")
	
	# Avvia decrittazione
	comms_app._on_btn_start_decrypt_pressed()
	assert(comms_app.is_decrypting == true, "Decrittazione in corso")
	
	# Simula avanzamento processo decrittazione fino al 100%
	comms_app._process(10.0)
	assert(comms_app.is_decrypting == false, "Decrittazione deve essere completata")
	assert(comms_app.last_decrypted_text.contains("DRONE-7815"), "Testo decifrato deve contenere la password estratta DRONE-7815")
	assert(comms_app.btn_save_to_ship_drive.disabled == false, "Pulsante salva su drive deve essere abilitato")
	
	# Salva su Ship Drive
	comms_app._on_btn_save_to_ship_drive_pressed()
	assert(FileAccess.file_exists("user://files/Ship Drive/intercepted_crypto_key.txt"), "File intercepted_crypto_key.txt deve essere creato su Ship Drive")
	
	var saved_content := FileAccess.get_file_as_string("user://files/Ship Drive/intercepted_crypto_key.txt")
	assert(saved_content.contains("DRONE-7815"), "Il contenuto del file salvato deve contenere la password")
	print("✔ Decodifica crittografica Hackwarfare ed esportazione su Ship Drive validate con successo")
	
	# =========================================================================
	# FASE 9: INTEGRAZIONE SUBLAYER 3 (RETE ELETTRICA)
	# =========================================================================
	print("\n--- TEST 9: Integrazione Sublayer 3 (Rete Elettrica comms_ew) ---")
	if SpaceWorldManager:
		var devs := SpaceWorldManager.get_power_devices()
		var found_comms := false
		for d in devs:
			if d.get("id") == "comms_ew":
				found_comms = true
				assert(d.get("power_mw") == 120.0, "Potenza nominale comms_ew deve essere 120 MW")
				break
		assert(found_comms, "Dispositivo comms_ew deve esistere nella rete elettrica della nave")
		print("✔ Dispositivo comms_ew e assorbimento elettrico validati nel Sublayer 3")
	
	# =========================================================================
	# FASE 10: PROTEZIONE FILE .DAT DAL FILE READER ORDINARIO
	# =========================================================================
	print("\n--- TEST 10: Protezione .dat dal File Reader / Visualizzatore di testo ---")
	var is_comms_dat_protected := false
	if SpaceWorldManager:
		var ship_files := SpaceWorldManager.get_ship_drive_files()
		for f in ship_files:
			if f.get("path") == "Ship Drive/Programs/Comms/comms_config.dat":
				is_comms_dat_protected = f.get("is_protected")
				break
	assert(is_comms_dat_protected, "comms_config.dat deve avere il flag is_protected = true")
	print("✔ File .dat protetto dalla lettura in chiaro standard")
	
	# =========================================================================
	# FASE 11: PULIZIA RISORSE E EXIT TREE
	# =========================================================================
	print("\n--- TEST 11: Pulizia Risorse _exit_tree() ---")
	comms_app.queue_free()
	await get_tree().process_frame
	print("✔ Pulizia nodi e segnali completata senza errori")
	
	print("\n=======================================================")
	print("✔ TUTTI I TEST COMMS & ELECTRONIC WARFARE COMPLETATI CON SUCCESSO!")
	print("=======================================================")
	get_tree().quit(0)
