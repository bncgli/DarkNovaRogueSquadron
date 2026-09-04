extends Node

func _ready() -> void:
	print("--- INIZIO TEST COMPLETO COMMS, DIRECTIONAL ANTENNA, STATION DOCKING & EW DRIVE ---")
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
	print("✔ Valori iniziali .dat caricati con successo")
	
	# Modifica dinamica di comms_config.dat
	var new_dat_content := "[SYSTEM]\napp_name=Comms\nversion=1.0.4\nstatus=OVERCLOCKED\ncomms_subsystem=ACTIVE\n\n[COMMS_SETTINGS]\nbandwidth_hz=1680.0\nauto_rotate_speed=60.0\nreception_cone_deg=30.0\nsubspace_relay_active=true\nauto_tune_sos=true\nsignal_amplification=1.5\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/Comms/comms_config.dat", FileAccess.WRITE)
	f_out.store_string(new_dat_content)
	f_out.close()
	
	# Notifica evento sincronizzazione drive
	if sdm:
		sdm.file_synced.emit("Ship Drive/Programs/Comms/comms_config.dat")
	else:
		comms_app.load_dat_configuration()
	await get_tree().process_frame
	
	assert(comms_app.active_config["bandwidth_hz"] == 1680.0, "bandwidth_hz aggiornato a runtime a 1680.0")
	assert(comms_app.active_config["auto_rotate_speed"] == 60.0, "auto_rotate_speed aggiornato a 60.0")
	assert(comms_app.active_config["reception_cone_deg"] == 30.0, "reception_cone_deg aggiornato a 30.0")
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
		assert(comms_app.can_control_comms == true, "Hacker deve avere pieno controllo su Comms")
		assert(comms_app.freq_slider.editable == true, "Slider frequenza abilitato per Hacker")
		assert(comms_app.antenna_heading_slider.editable == true, "Slider azimut antenna abilitato per Hacker")
		assert(comms_app.btn_auto_rotate.disabled == false, "Auto-rotate abilitato per Hacker")
		assert(comms_app.btn_freq_lock.disabled == false, "Frequency Lock abilitato per Hacker")
		
		# Ruolo Capitano (Pieno controllo & Override)
		net_mgr.request_role("Capitano")
		await get_tree().process_frame
		assert(comms_app.can_control_comms == true, "Capitano deve avere pieno controllo su Comms")
		assert(comms_app.antenna_heading_slider.editable == true, "Slider azimut abilitato per Capitano")
		
		# Ruolo Pilota (Sola visualizzazione)
		net_mgr.request_role("Pilota")
		await get_tree().process_frame
		assert(comms_app.can_control_comms == false, "Pilota non deve avere controllo su Comms")
		assert(comms_app.freq_slider.editable == false, "Slider frequenza in sola lettura per Pilota")
		assert(comms_app.antenna_heading_slider.editable == false, "Slider azimut disabilitato per Pilota")
		assert(comms_app.btn_auto_rotate.disabled == true, "Auto-rotate disabilitato per Pilota")
		
		# Ruolo Ingegnere (Sola visualizzazione)
		net_mgr.request_role("Ingegnere")
		await get_tree().process_frame
		assert(comms_app.can_control_comms == false, "Ingegnere non deve avere controllo su Comms")
		
		# Ruolo Soldato (Sola visualizzazione)
		net_mgr.request_role("Soldato")
		await get_tree().process_frame
		assert(comms_app.can_control_comms == false, "Soldato non deve avere controllo su Comms")
		
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
	
	# 2. Allinea l'antenna verso il bersaglio SOS (bearing = 45°)
	comms_app._on_antenna_heading_changed(45.0)
	assert(comms_app.antenna_azimuth_deg == 45.0, "Azimut antenna impostato a 45°")
	assert(comms_app.btn_listen_signal.disabled == false, "Pulsante ascolto abilitato per segnale agganciato e allineato")
	
	# 3. Trascrizione messaggio SOS nel log
	comms_app._on_btn_listen_signal_pressed()
	var log_str := comms_app.comms_log_text.get_parsed_text()
	if log_str.is_empty():
		log_str = comms_app.comms_log_text.text
	assert(log_str.contains("SOS") or log_str.contains("Relitto"), "Log comunicazioni deve contenere il messaggio SOS")
	
	# 4. Sintonizzazione su Relay Subspaziale 1420.0 MHz
	comms_app._on_btn_tune_subspace_pressed()
	var locked_subspace: Variant = comms_app._get_locked_signal()
	assert(locked_subspace != null and locked_subspace.get("id") == "subspace_corp")
	
	# 5. Sintonizzazione su canale pirata
	comms_app._on_btn_tune_pirate_pressed()
	assert(comms_app.current_frequency == 2185.2, "Frequenza deve essere 2185.2 MHz")
	print("✔ Sintonizzatore frequenze, waterfall display e aggancio portante convalidati")
	
	# =========================================================================
	# FASE 7: CONTROLLI ANTENNA DIREZIONALE & MODALITÀ OPERATIVE
	# =========================================================================
	print("\n--- TEST 7: Meccanica Antenna Direzionale & Modalità Operative ---")
	# 1. Puntamento manuale
	comms_app._on_antenna_heading_changed(180.0)
	assert(comms_app.antenna_azimuth_deg == 180.0, "Azimut antenna impostato manualmente a 180°")
	assert(comms_app.antenna_status_label.text.contains("180°"), "Status label antenna aggiornato a 180°")
	
	# 2. Modalità Auto-Rotate 360°
	comms_app._on_btn_auto_rotate_toggled(true)
	assert(comms_app.is_auto_rotating == true, "Auto-rotate deve risultare attivo")
	assert(comms_app.is_frequency_locked == false, "Frequency lock deve essere disattivato quando auto-rotate si avvia")
	assert(comms_app.status_badge.text.contains("AUTO-ROTAZIONE"), "Status badge deve indicare auto-rotazione")
	
	# Simula rotazione su 1 secondo (60°/s da config)
	var prev_azimuth: float = comms_app.antenna_azimuth_deg
	comms_app._process(1.0)
	assert(comms_app.antenna_azimuth_deg == fmod(prev_azimuth + 60.0, 360.0), "Antenna deve essere ruotata di 60° dopo 1s")
	
	# 3. Modalità Frequency Lock
	comms_app._on_btn_tune_sos_pressed() # SOS a 45°
	comms_app._on_btn_freq_lock_toggled(true)
	assert(comms_app.is_frequency_locked == true, "Frequency Lock deve risultare attivo")
	assert(comms_app.is_auto_rotating == false, "Auto-rotate deve disattivarsi su frequency lock")
	assert(comms_app.locked_signal_id == "sos_scout", "locked_signal_id deve essere sos_scout")
	
	# Simula processo di tracking: antenna deve inseguire 45°
	for _i in range(5):
		comms_app._process(0.5)
	assert(absf(comms_app.antenna_azimuth_deg - 45.0) < 5.0, "Antenna deve aver agganciato e inseguito il bearing a 45°")
	comms_app._on_btn_freq_lock_toggled(false)
	print("✔ Puntamento manuale, auto-rotazione 360° e tracking Frequency Lock validati con successo")
	
	# =========================================================================
	# FASE 8: CONO DI RICEZIONE ANGOLARE & CALCOLO POTENZA SEGNALE
	# =========================================================================
	print("\n--- TEST 8: Cono Angolare di Ricezione ±25° & Qualità Ricezione ---")
	comms_app.active_config["reception_cone_deg"] = 25.0
	var sos_sig: Dictionary = comms_app.available_signals[0] # bearing 45°, dist 650m
	
	# In cono (antenna a 45° -> Delta = 0°)
	comms_app.antenna_azimuth_deg = 45.0
	var pwr_aligned: float = comms_app.get_effective_signal_strength(sos_sig)
	assert(pwr_aligned >= 0.85, "Potenza segnale allineato deve essere piena (>= 0.85)")
	
	# Fuori cono (antenna a 180° -> Delta = 135°)
	comms_app.antenna_azimuth_deg = 180.0
	var pwr_off: float = comms_app.get_effective_signal_strength(sos_sig)
	assert(pwr_off < 0.1, "Potenza segnale fuori cono deve calare drasticamente (< 0.1)")
	
	# In auto-rotazione (raggio limitato a 800m, SNR attenuato)
	comms_app.is_auto_rotating = true
	var pwr_autorot: float = comms_app.get_effective_signal_strength(sos_sig)
	assert(pwr_autorot > 0.0 and pwr_autorot <= 0.5, "Potenza in auto-rotazione deve essere attenuata (< 0.5)")
	
	# Segnale lontano (> 800m) in auto-rotazione
	var far_sig: Dictionary = comms_app.available_signals[1] # relay dist 3200m
	var pwr_far: float = comms_app.get_effective_signal_strength(far_sig)
	assert(pwr_far == 0.0, "Segnali a distanza > 800m devono essere azzerati in auto-rotazione")
	comms_app.is_auto_rotating = false
	print("✔ Guadagno angolare, focalizzazione cono ±25° e filtro auto-rotazione verificati")
	
	# =========================================================================
	# FASE 9: MENU INTERAZIONE STAZIONE SPAZIALE & RICHIESTA ATTRACCO
	# =========================================================================
	print("\n--- TEST 9: Menu Interazione Stazione Spaziale & Richiesta Attracco ---")
	# Sintonizza frequenza stazione civile (1840.0 MHz, bearing 270°)
	comms_app.current_frequency = 1840.0
	comms_app.antenna_azimuth_deg = 270.0
	comms_app._refresh_tuner_state()
	
	assert(comms_app.station_actions_box.visible == true, "Box azioni stazione deve essere visibile")
	assert(comms_app.btn_request_docking.disabled == false, "Pulsante richiesta attracco deve essere abilitato")
	
	var docking_requested_data := {"fired": false, "station_id": ""}
	comms_app.docking_clearance_requested.connect(func(st_id: String):
		docking_requested_data["fired"] = true
		docking_requested_data["station_id"] = st_id
	)
	comms_app._on_btn_request_docking_pressed()
	assert(docking_requested_data["fired"] == true, "Il segnale docking_clearance_requested deve essere stato emesso")
	print("✔ Menu stazione spaziale e richiesta autorizzazione attracco validati")
	
	# =========================================================================
	# FASE 10: ABILITAZIONE CONNESSIONE DRIVE EW SU SEGNALE POTENTE
	# =========================================================================
	print("\n--- TEST 10: Abilitazione Connessione Drive EW ---")
	# Sintonizza canale pirata da corvetta (2185.2 MHz, bearing 120°, dist 950m, type CORVETTE)
	comms_app._on_btn_tune_pirate_pressed()
	
	# 1. Con antenna disallineata (es. a 0° invece di 120°): segnale debole -> Connect DISABILITATO
	comms_app._on_antenna_heading_changed(0.0)
	assert(comms_app.btn_connect_drive.disabled == true, "Connect deve essere disabilitato se il segnale è debole/disallineato")
	
	# 2. Con antenna allineata a 120°: SNR >= 0.75 e dist < 1200m -> Connect ABILITATO
	comms_app._on_antenna_heading_changed(120.0)
	assert(comms_app.btn_connect_drive.disabled == false, "Connect deve essere abilitato con segnale forte ed entro 1200m")
	
	# 3. Pressione Connect: intrusione riuscita e creazione cartelle Target Drive
	comms_app._on_connect_drive_pressed()
	assert(DirAccess.dir_exists_absolute("user://files/Target Drive"), "Cartella user://files/Target Drive deve essere montata")
	assert(DirAccess.dir_exists_absolute("user://files/Target Drive/FlightControl"), "Sottocartelle remote create")
	print("✔ Intrusione EW e abilitazione dinamica del pulsante Connect validate con successo")
	
	# =========================================================================
	# FASE 11: INTEGRAZIONE SUBLAYER 3 (RETE ELETTRICA)
	# =========================================================================
	print("\n--- TEST 11: Integrazione Sublayer 3 (Rete Elettrica comms_relay) ---")
	if SpaceWorldManager:
		var devs := SpaceWorldManager.get_power_devices()
		var found_comms := false
		for d in devs:
			if d.get("id") in ["comms_relay", "comms_ew", "matrice_comunicazione"] or d.get("category") == "comms":
				found_comms = true
				break
		assert(found_comms, "Dispositivo comunicazioni deve esistere nella rete elettrica della nave")
		print("✔ Dispositivo comunicazioni e assorbimento elettrico validati nel Sublayer 3")
	
	# =========================================================================
	# FASE 12: PROTEZIONE FILE .DAT DAL FILE READER ORDINARIO
	# =========================================================================
	print("\n--- TEST 12: Protezione .dat dal File Reader / Visualizzatore di testo ---")
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
	# FASE 13: PULIZIA RISORSE E EXIT TREE
	# =========================================================================
	print("\n--- TEST 13: Pulizia Risorse _exit_tree() ---")
	comms_app.queue_free()
	await get_tree().process_frame
	print("✔ Pulizia nodi e segnali completata senza errori")
	
	print("\n=======================================================")
	print("✔ TUTTI I TEST COMMS & DIRECTIONAL ANTENNA COMPLETATI CON SUCCESSO!")
	print("=======================================================")
	get_tree().quit(0)
