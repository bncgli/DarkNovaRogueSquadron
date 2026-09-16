extends GutTest

## Test suite GUT per la Fase F: Guerra Elettronica, Contrattacco Hacker & Feedback Diegetici Sensoriali.
## Valida l'iniezione sentinella EW, il tracking e gli allarmi in CombatDirector & Diagnostics,
## le anomalie sistemiche in tempo reale (drift Spaceship, glitch ottico Cams, sovraccarico PowerGrid),
## la disinfezione al delete del file da parte dell'Hacker, la detonazione al timeout e i feedback interni nei Pod.

var combat_dir: CombatDirector = null
var ship: Spaceship = null
var systemic_damage: SystemicDamageHandler = null
var pod_info: PodInfoApp = null

func before_each() -> void:
	systemic_damage = SystemicDamageHandler.new()
	systemic_damage.name = "SystemicDamageHandler"
	add_child(systemic_damage)
	
	ship = Spaceship.new()
	ship.name = "TestSpaceship"
	add_child(ship)
	
	combat_dir = CombatDirector.new()
	combat_dir.name = "CombatDirector"
	add_child(combat_dir)
	combat_dir.setup(ship, systemic_damage)
	combat_dir.auto_manage_encounters = false
	
	var pod_scene := load("res://Applications/PodInfo/pod_info_app.tscn") as PackedScene
	pod_info = pod_scene.instantiate() as PodInfoApp
	add_child(pod_info)
	
	await get_tree().process_frame

func after_each() -> void:
	for node in [pod_info, combat_dir, ship, systemic_damage]:
		if is_instance_valid(node):
			node.free()
			
	# Pulizia cartelle sentinelle di test
	var sentinels := [
		"user://files/Ship Drive/Programs/FlightControls/worm_thrust_override.dat",
		"user://files/Ship Drive/Programs/Cams/cams_jammer_sentinel.dat",
		"user://files/Ship Drive/Programs/PowerGrid/power_drain_virus.dat"
	]
	for path in sentinels:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

# =============================================================================
# TEST 1: INIEZIONE SENTINELLA EW E TRACCIAMENTO INTRUSIONE
# =============================================================================
func test_hostile_cyber_attack_sentinel_injection() -> void:
	watch_signals(combat_dir)
	
	var intrusion := combat_dir.trigger_hostile_cyber_attack("PROPULSION_WORM")
	assert_false(intrusion.is_empty(), "L'attacco informatico ostile deve restituire i dati dell'intrusione")
	assert_eq(intrusion.get("exploit_type"), "PROPULSION_WORM", "Il tipo di exploit deve corrispondere a PROPULSION_WORM")
	assert_gt(intrusion.get("remaining_time"), 0.0, "Il timer residuo deve essere maggiore di 0")
	
	# Verifica file sentinella scritto su disco nello Ship Drive
	var rel_path: String = intrusion.get("file_path", "")
	var abs_path := "user://files/%s" % rel_path
	assert_true(FileAccess.file_exists(abs_path), "Il file sentinella .dat deve essere creato fisicamente su disco in: %s" % abs_path)
	
	# Verifica segnale emesso
	assert_signal_emitted(combat_dir, "cyber_intrusion_detected", "Deve emettere cyber_intrusion_detected")
	
	# Verifica tracking in CombatDirector
	assert_true(combat_dir.is_exploit_active("PROPULSION_WORM"), "L'exploit PROPULSION_WORM deve risultare attivo")
	assert_eq(combat_dir.get_active_intrusions().size(), 1, "Deve esserci esattamente un'intrusione attiva")

# =============================================================================
# TEST 2: NEUTRALIZZAZIONE TRAMITE RIMOZIONE FILE DA PARTE DELL'HACKER
# =============================================================================
func test_hacker_countermeasure_file_deletion_neutralization() -> void:
	watch_signals(combat_dir)
	
	var intrusion := combat_dir.trigger_hostile_cyber_attack("BLIND_EYE")
	var rel_path: String = intrusion.get("file_path", "")
	var abs_path := "user://files/%s" % rel_path
	assert_true(FileAccess.file_exists(abs_path), "La sentinella BLIND EYE deve esistere su disco")
	assert_true(combat_dir.is_exploit_active("BLIND_EYE"), "BLIND_EYE deve essere attivo")
	
	# Simula rimozione del file da parte dell'Hacker (o CLI rm)
	DirAccess.remove_absolute(abs_path)
	assert_false(FileAccess.file_exists(abs_path), "Il file sentinella deve essere stato rimosso")
	
	# Propaga segnale di eliminazione item dallo Ship Drive
	combat_dir._on_ship_drive_item_deleted(rel_path)
	
	# Verifica neutralizzazione
	assert_signal_emitted(combat_dir, "cyber_intrusion_cleared", "Deve emettere cyber_intrusion_cleared")
	assert_false(combat_dir.is_exploit_active("BLIND_EYE"), "L'exploit BLIND_EYE deve risultare neutralizzato")
	assert_eq(combat_dir.get_active_intrusions().size(), 0, "Nessuna intrusione deve rimanere attiva")

# =============================================================================
# TEST 3: PERTURBAZIONE DERIVA COMANDI DI VOLO (PROPULSION_WORM)
# =============================================================================
func test_cyber_drift_perturbation_on_spaceship() -> void:
	ship.stop_engines()
	ship.set_inertia_dampening(false)
	assert_eq(ship.linear_velocity, Vector3.ZERO, "La nave parte ferma")
	assert_eq(ship.angular_velocity, Vector3.ZERO, "La nave parte senza rotazione")
	
	# Attiva cyber drift simulando PROPULSION_WORM
	ship.set_cyber_drift_active(true, 1.0)
	ship._apply_flight_physics(0.1)
	
	# Verifica che sia stata impressa perturbazione sia angolare che lineare
	assert_gt(ship.angular_velocity.length(), 0.0, "La deriva cyber deve applicare coppia angolare incontrollata")
	assert_gt(ship.linear_velocity.length(), 0.0, "La deriva cyber deve applicare forza lineare di traslazione")
	
	# Disattivazione deriva cyber
	ship.set_cyber_drift_active(false)
	assert_eq(ship.cyber_drift_intensity, 0.0, "L'intensità del drift cyber deve azzerarsi")

# =============================================================================
# TEST 4: GLITCH TELECAMERE E DISTURBO VISIVO (BLIND_EYE)
# =============================================================================
func test_optical_jammer_blind_eye_glitch_cams() -> void:
	var cams_app := CamsApp.new()
	add_child(cams_app)
	await get_tree().process_frame
	
	assert_false(cams_app.is_cyber_glitch_active, "Il glitch deve essere disattivo inizialmente")
	
	# Attiva exploit BLIND_EYE
	cams_app.set_cyber_glitch_active(true)
	assert_true(cams_app.is_cyber_glitch_active, "Il glitch deve risultare attivo in CamsApp")
	
	# Disattiva exploit
	cams_app.set_cyber_glitch_active(false)
	assert_false(cams_app.is_cyber_glitch_active, "Il glitch deve essere disattivato dopo la bonifica")
	
	cams_app.free()

# =============================================================================
# TEST 5: SOVRACCARICO RETE ENERGETICA (REACTOR_OVERLOAD)
# =============================================================================
func test_reactor_overload_power_drain_anomalies() -> void:
	var power_scene := load("res://Applications/PowerGrid/power_grid_app.tscn") as PackedScene
	var power_app := power_scene.instantiate() as PowerGridApp
	add_child(power_app)
	await get_tree().process_frame
	
	power_app.rooms_data = [
		{
			"id": "reactor_core",
			"name": "Nucleo Reattore",
			"category": "REACTOR",
			"is_on": true,
			"devices": [
				{"name": "Reattore Principale", "power_mw": 1200.0, "category": "REACTOR"}
			]
		}
	]
	power_app._refresh_power_logic()
	var base_gen: float = power_app.total_gen_mw
	assert_gt(base_gen, 0.0, "La generazione iniziale del reattore deve essere positiva")
	
	# Attiva attacco REACTOR_OVERLOAD in CombatDirector
	combat_dir.trigger_hostile_cyber_attack("REACTOR_OVERLOAD")
	assert_true(combat_dir.is_exploit_active("REACTOR_OVERLOAD"), "REACTOR_OVERLOAD deve essere attivo")
	
	# Ricalcola telemetria energetica con anomalia cyber
	power_app._refresh_power_logic()
	
	# Verifica penalità di output e carico addizionale
	assert_lt(power_app.total_gen_mw, base_gen, "La generazione deve diminuire a causa dell'infezione cyber")
	assert_gt(power_app.total_cons_mw, 0.0, "Il consumo deve aumentare per il sovraccarico parassita")
	
	# Neutralizza intrusione
	combat_dir.clear_cyber_intrusion(combat_dir.get_active_intrusions().keys()[0])
	power_app._refresh_power_logic()
	assert_eq(power_app.total_gen_mw, base_gen, "La generazione del reattore deve essere ripristinata al 100%")
	
	power_app.free()

# =============================================================================
# TEST 6: DETONAZIONE EXPLOIT ALLA SCADENZA DEL TIMEOUT E DANNO SISTEMICO
# =============================================================================
func test_cyber_intrusion_timeout_detonation_damage() -> void:
	watch_signals(combat_dir)
	
	var initial_health: float = systemic_damage.hull_integrity
	var intrusion := combat_dir.trigger_hostile_cyber_attack("REACTOR_OVERLOAD")
	var intrusion_id: String = intrusion.get("id", "")
	
	# Forza scadenza timer simulando il tempo
	combat_dir.active_intrusions[intrusion_id]["remaining_time"] = 0.05
	combat_dir.process_cyber_warfare(0.1)
	
	# Verifica emissione segnale di detonazione
	assert_signal_emitted(combat_dir, "cyber_intrusion_detonated", "Deve emettere cyber_intrusion_detonated")
	assert_false(combat_dir.is_exploit_active("REACTOR_OVERLOAD"), "L'intrusione detonata non deve più essere attiva")
	
	# Verifica danno sistemico applicato
	assert_lt(systemic_damage.hull_integrity, initial_health, "Lo scafo deve aver subito danni dalla detonazione")

# =============================================================================
# TEST 7: FEEDBACK SENSORIALI INTERNI (AUDIO OVATTATO & REATTIVITÀ BIOMETRICA)
# =============================================================================
func test_internal_muffled_spatial_audio_and_biometric_stress() -> void:
	watch_signals(pod_info)
	
	var resting_hr: float = pod_info.get_heart_rate()
	var resting_stress: float = pod_info.get_stress_level()
	assert_eq(resting_hr, 75.0, "Frequenza cardiaca basale 75 bpm")
	assert_eq(resting_stress, 0.0, "Livello di stress basale 0.0")
	
	# Simula impatto colpo balistico
	pod_info._on_ship_damage_taken(Vector2(250, 100), "impact")
	assert_signal_emitted(pod_info, "spatial_sound_played", "Deve essere riprodotto l'audio spaziale d'impatto")
	
	# Verifica picco biometrico
	assert_gt(pod_info.get_heart_rate(), resting_hr, "Il battito cardiaco deve accelerare all'impatto")
	assert_gt(pod_info.get_stress_level(), resting_stress, "Lo stress deve aumentare per la violenza dell'impatto")
	
	# Simula breccia decompressiva
	pod_info._on_ship_damage_taken(Vector2(50, 50), "breach")
	assert_signal_emitted(pod_info, "spatial_sound_played", "Deve essere riprodotto l'audio decompressivo")
	
	# Simula incendio
	pod_info._on_ship_damage_taken(Vector2(100, 80), "fire")
	assert_signal_emitted(pod_info, "spatial_sound_played", "Deve essere riprodotto l'audio sibilo di fiamma")
	
	# Verifica decadimento fisiologico verso la normalità
	pod_info._simulate_vital_signs(2.0)
	assert_lt(pod_info.get_heart_rate(), 185.0, "La frequenza cardiaca deve iniziare la stabilizzazione")

# =============================================================================
# TEST 8: SCREEN SHAKE DIEGETICO E DECADIMENTO SMORZATO
# =============================================================================
func test_screen_shake_decay_and_desktop_viewport_offset() -> void:
	watch_signals(pod_info)
	
	assert_eq(pod_info.get_screen_shake_offset(), Vector2.ZERO, "Offset shake iniziale nullo")
	
	# Attiva screen shake
	pod_info.trigger_screen_shake(16.0, 0.3)
	assert_signal_emitted(pod_info, "screen_shake_triggered", "Deve emettere segnale screen_shake_triggered")
	
	# Simula avanzamento frame
	pod_info._process_screen_shake(0.05)
	var offset := pod_info.get_screen_shake_offset()
	assert_ne(offset, Vector2.ZERO, "Durante lo shake l'offset deve essere diverso da zero")
	assert_lte(abs(offset.x), 16.0, "L'ampiezza X deve rimanere entro l'intensità massima")
	assert_lte(abs(offset.y), 16.0, "L'ampiezza Y deve rimanere entro l'intensità massima")
	
	# Avanza fino alla completa estinzione del timer di shake
	pod_info._process_screen_shake(0.4)
	assert_eq(pod_info.get_screen_shake_offset(), Vector2.ZERO, "Al termine del decadimento l'offset deve ritornare esattamente a (0, 0)")
