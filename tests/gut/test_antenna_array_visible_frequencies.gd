extends GutTest

## Test Unitario GUT per AntennaArrayComponent e il calcolo direzionale di visible_frequencies.
## Verifica che le frequenze visibili dipendano dalla direzione dell'antenna (azimuth_deg e reception_cone_deg)
## e che includano segnali emessi da navi, stazioni, beacon, relé nello spazio corrente e nella mappa stellare.

var antenna: AntennaArrayComponent

func before_each() -> void:
	antenna = AntennaArrayComponent.new("antenna_array", "comunicazioni", "comms")
	antenna.is_online = true
	antenna.power_ratio = 1.0
	antenna.power_supplied = 15.0

func after_each() -> void:
	if is_instance_valid(antenna):
		antenna.free()
	antenna = null

func test_default_initialization_and_registers() -> void:
	assert_not_null(antenna)
	assert_eq(antenna.azimuth_deg, 0.0)
	assert_eq(antenna.reception_cone_deg, 45.0)
	assert_eq(antenna.max_range_quadrants, 5.0)
	assert_almost_eq(antenna.get_effective_range_quadrants(), 5.0, 0.01)
	
	# Inizialmente a 0 gradi e piena potenza, deve rilevare segnali allineati a prua entro i 5 quadranti
	var freqs := antenna.get_frequencies()
	assert_gt(freqs.size(), 0, "A 0 gradi devono essere visibili le frequenze allineate a prua")
	assert_eq(antenna.read_register("visible_freq_count"), freqs.size())
	assert_eq(antenna.read_register("azimuth"), 0.0)
	assert_eq(antenna.read_register("reception_cone"), 45.0)
	assert_almost_eq(antenna.read_register("range_quadrants"), 5.0, 0.01)

func test_frequency_visibility_changes_with_antenna_azimuth() -> void:
	# A 180 gradi (relé subspaziale a 180 gradi: 1420.0 MHz, dist 2.5 quadranti)
	antenna.rotate_antenna(180.0)
	assert_almost_eq(antenna.azimuth_deg, 180.0, 0.01)
	var freqs_180 := antenna.get_frequencies()
	assert_true(freqs_180.has(1420.0), "A 180 gradi la frequenza 1420.0 MHz del relé deve essere visibile")
	assert_false(freqs_180.has(850.5), "A 180 gradi la frequenza 850.5 MHz (a 40 gradi) non deve essere visibile")
	
	# A 270 gradi (stazione spaziale a 270 gradi: 1840.0 MHz, dist 3.5 quadranti)
	antenna.rotate_antenna(270.0)
	assert_almost_eq(antenna.azimuth_deg, 270.0, 0.01)
	var freqs_270 := antenna.get_frequencies()
	assert_true(freqs_270.has(1840.0), "A 270 gradi la frequenza 1840.0 MHz della stazione deve essere visibile")
	assert_false(freqs_270.has(1420.0), "A 270 gradi la frequenza 1420.0 MHz non deve essere visibile")
	
	# A 45 gradi (SOS beacon relitto a 40 gradi: 850.5 MHz, dist 2.0 quadranti)
	antenna.rotate_antenna(45.0)
	var freqs_45 := antenna.get_frequencies()
	assert_true(freqs_45.has(850.5), "A 45 gradi la frequenza 850.5 MHz del beacon deve essere visibile")
	assert_false(freqs_45.has(1420.0), "A 45 gradi la frequenza 1420.0 MHz non deve essere visibile")
	
	# A 90 gradi (nessun segnale in quella direzione nel raggio d'azione)
	antenna.rotate_antenna(90.0)
	var freqs_90 := antenna.get_frequencies()
	assert_eq(freqs_90.size(), 0, "A 90 gradi non deve essere visibile alcun segnale nel waterfall o nei registri")

func test_custom_emitters_ships_stations_beacons_relays() -> void:
	antenna.clear_custom_emitters()
	
	# Registra 4 emettitori a diverse angolazioni entro portata (1 quadrante):
	# 1. Nave pattuglia a 30° su 1920.0 MHz
	# 2. Relitto beacon a 90° su 850.5 MHz
	# 3. Relé subspazio a 180° su 1420.0 MHz
	# 4. Stazione a 270° su 1840.0 MHz
	antenna.add_emitter(1920.0, 30.0, "SHIP", "Nave Pattuglia", 1.0)
	antenna.add_emitter(850.5, 90.0, "BEACON", "Faro Emergenza", 1.0)
	antenna.add_emitter(1420.0, 180.0, "RELAY", "Relé Subspaziale", 1.0)
	antenna.add_emitter(1840.0, 270.0, "STATION", "Stazione Avamposto", 1.0)
	
	# Punta l'antenna a 30° (entro cono 45°, visibile da 345° a 75°)
	antenna.rotate_antenna(30.0)
	var freqs := antenna.get_frequencies()
	assert_true(freqs.has(1920.0), "Nave su 1920 MHz deve essere visibile a 30°")
	assert_false(freqs.has(850.5), "Beacon a 90° fuori cono da 30°")
	assert_false(freqs.has(1420.0), "Relé a 180° fuori cono da 30°")
	assert_false(freqs.has(1840.0), "Stazione a 270° fuori cono da 30°")
	
	# Punta l'antenna a 90°
	antenna.rotate_antenna(90.0)
	freqs = antenna.get_frequencies()
	assert_true(freqs.has(850.5), "Beacon a 90° deve essere visibile")
	assert_false(freqs.has(1920.0), "Nave a 30° fuori cono da 90°")
	
	# Rimozione emettitore
	antenna.remove_emitter(850.5)
	freqs = antenna.get_frequencies()
	assert_false(freqs.has(850.5), "Beacon rimosso non deve più comparire")

func test_reception_cone_adjustment_45_to_60_degrees() -> void:
	antenna.clear_custom_emitters()
	# Emettitore a 50° di bearing, a 1.0 quadrante di distanza
	antenna.add_emitter(1920.0, 50.0, "SHIP", "Nave Test", 1.0)
	
	# Azimut a 0° con cono a 45°: la differenza è 50° > 45°, quindi FUORI raggio d'azione
	antenna.rotate_antenna(0.0)
	antenna.set_reception_cone(45.0)
	assert_eq(antenna.reception_cone_deg, 45.0)
	assert_false(antenna.get_frequencies().has(1920.0), "Nave a 50° deve essere fuori dal cono di 45° con azimut 0°")
	
	# Allarga il raggio d'azione a 60°: la differenza è 50° <= 60°, quindi DENTRO raggio d'azione
	antenna.set_reception_cone(60.0)
	assert_eq(antenna.reception_cone_deg, 60.0)
	assert_true(antenna.get_frequencies().has(1920.0), "Nave a 50° deve essere visibile quando il raggio d'azione è a 60°")

func test_distance_in_quadrants_based_on_power_supplied() -> void:
	antenna.clear_custom_emitters()
	antenna.rotate_antenna(0.0)
	antenna.set_reception_cone(45.0)
	
	# Tre emettitori allineati a prua (0°) a distanze diverse in quadranti:
	# - Vicino: 1.0 quadrante
	# - Medio: 3.0 quadranti
	# - Lontano: 6.0 quadranti
	antenna.add_emitter(1111.0, 0.0, "SHIP", "Segnale Vicino (1q)", 1.0)
	antenna.add_emitter(2222.0, 0.0, "RELAY", "Segnale Medio (3q)", 3.0)
	antenna.add_emitter(3333.0, 0.0, "BEACON", "Segnale Lontano (6q)", 6.0)
	
	# Caso 1: Piena Potenza Nominale (power_ratio = 1.0, portata = 5.0 quadranti)
	antenna.power_ratio = 1.0
	assert_almost_eq(antenna.get_effective_range_quadrants(), 5.0, 0.01)
	var freqs_full := antenna.get_frequencies()
	assert_true(freqs_full.has(1111.0), "Segnale a 1 quadrante visibile a piena potenza")
	assert_true(freqs_full.has(2222.0), "Segnale a 3 quadranti visibile a piena potenza")
	assert_false(freqs_full.has(3333.0), "Segnale a 6 quadranti fuori portata massima nominale (5q)")
	
	# Caso 2: Potenza Ridotta / Calo Energetico (power_ratio = 0.4 -> portata = 5.0 * 0.4 = 2.0 quadranti)
	antenna.power_ratio = 0.4
	assert_almost_eq(antenna.get_effective_range_quadrants(), 2.0, 0.01)
	var freqs_low := antenna.get_frequencies()
	assert_true(freqs_low.has(1111.0), "Segnale a 1 quadrante ancora visibile a 2.0 quadranti di portata")
	assert_false(freqs_low.has(2222.0), "Segnale a 3 quadranti ora fuori portata (max 2.0q)")
	assert_false(freqs_low.has(3333.0), "Segnale a 6 quadranti fuori portata")
	
	# Caso 3: Sovralimentazione / Overclock (power_ratio = 1.5 -> portata = 5.0 * 1.5 = 7.5 quadranti)
	antenna.power_ratio = 1.5
	assert_almost_eq(antenna.get_effective_range_quadrants(), 7.5, 0.01)
	var freqs_over := antenna.get_frequencies()
	assert_true(freqs_over.has(1111.0), "Segnale a 1 quadrante visibile")
	assert_true(freqs_over.has(2222.0), "Segnale a 3 quadranti visibile")
	assert_true(freqs_over.has(3333.0), "Segnale a 6 quadranti ora visibile grazie alla sovralimentazione (7.5q)")

func test_power_and_offline_states_clear_frequencies() -> void:
	antenna.rotate_antenna(270.0)
	assert_gt(antenna.get_frequencies().size(), 0)
	
	# Spegni antenna (offline)
	antenna.set_online(false)
	assert_eq(antenna.get_frequencies().size(), 0, "Da offline le frequenze devono essere azzerate")
	assert_eq(antenna.read_register("visible_freq_count"), 0)
	
	# Riaccendi ma togli alimentazione (power_ratio < 0.2)
	antenna.set_online(true)
	antenna.power_ratio = 0.1
	assert_eq(antenna.get_frequencies().size(), 0, "Sotto il 20% di alimentazione nessuna frequenza deve essere visibile")
	assert_eq(antenna.read_register("visible_freq_count"), 0)
	
	# Ripristina alimentazione piena
	antenna.power_ratio = 1.0
	assert_gt(antenna.get_frequencies().size(), 0, "Ad alimentazione ripristinata le frequenze tornano visibili")

func test_scanning_rotation_sweeps_frequencies() -> void:
	antenna.rotate_antenna(0.0)
	antenna.toggle_scan(true)
	assert_true(antenna.is_scanning)
	
	var initial_azimuth := antenna.azimuth_deg
	# Esegui diversi step di simulazione
	antenna.step(1.0) # Con 45°/sec, azimuth ruota di 45°
	assert_gt(antenna.azimuth_deg, initial_azimuth, "Durante la scansione l'azimut deve ruotare")
	assert_eq(antenna.read_register("is_scanning"), true)

func test_default_star_system_comms_frequencies() -> void:
	var sys: StarSystemData = load("res://Outside/StarSystemGrid/default_star_system.tres")
	assert_not_null(sys, "default_star_system.tres deve essere caricabile")
	assert_gt(sys.celestial_bodies.size(), 0)
	
	var station_body: CelestialBodyData = sys.get_body("STATION_VALKYRIE")
	assert_not_null(station_body)
	assert_almost_eq(station_body.comms_frequency, 1840.0, 0.01)
	
	var patrol_body: CelestialBodyData = sys.get_body("PATROL_VANGUARD")
	assert_not_null(patrol_body)
	assert_almost_eq(patrol_body.comms_frequency, 1920.0, 0.01)
	
	var wreck_body: CelestialBodyData = sys.get_body("WRECK_TITAN_GRAVE")
	assert_not_null(wreck_body)
	assert_almost_eq(wreck_body.comms_frequency, 850.5, 0.01)
	
	var planet_terra: CelestialBodyData = sys.get_body("PLANET_TERRA_NOVA")
	assert_not_null(planet_terra)
	assert_almost_eq(planet_terra.comms_frequency, 1420.0, 0.01)
	
	var moon_luna: CelestialBodyData = sys.get_body("MOON_LUNA_SEC")
	assert_not_null(moon_luna)
	assert_almost_eq(moon_luna.comms_frequency, 433.0, 0.01)
	
	var belt_ceres: CelestialBodyData = sys.get_body("BELT_CERES_EX")
	assert_not_null(belt_ceres)
	assert_almost_eq(belt_ceres.comms_frequency, 2750.0, 0.01)
	
	var kronos: CelestialBodyData = sys.get_body("GAS_GIANT_KRONOS")
	assert_not_null(kronos)
	assert_almost_eq(kronos.comms_frequency, 2400.0, 0.01)
	
	var aetheris: CelestialBodyData = sys.get_body("GAS_GIANT_AETHER")
	assert_not_null(aetheris)
	assert_almost_eq(aetheris.comms_frequency, 2185.2, 0.01)

func test_waterfall_canvas_zero_signals_at_90_degrees() -> void:
	var canvas := CommsWaterfallCanvas.new()
	assert_not_null(canvas)
	
	# Quando i segnali attivi sono vuoti (es. antenna puntata a 90° verso il vuoto)
	canvas.update_state(1420.0, false, 90.0, true, [])
	assert_eq(canvas.active_signals.size(), 0)
	
	# La riga generata non deve contenere picchi di segnale (> 0.25), solo rumore di fondo
	canvas._update_waterfall_row(0.016)
	var top_row: PackedFloat32Array = canvas.waterfall_history[0]
	assert_eq(top_row.size(), canvas.SPECTRUM_BINS)
	var max_val := 0.0
	for v in top_row:
		if v > max_val:
			max_val = v
	assert_lt(max_val, 0.25, "In assenza di segnali nel cono il waterfall deve contenere solo rumore di fondo (< 0.25)")
	
	# Se riceve un segnale attivo (es. riallineata verso una stazione su 1840 MHz)
	var active_sig := [{"freq": 1840.0, "strength": 0.95}]
	canvas.update_state(1840.0, false, 270.0, true, active_sig)
	assert_eq(canvas.active_signals.size(), 1)
	canvas._update_waterfall_row(0.016)
	var signal_row: PackedFloat32Array = canvas.waterfall_history[0]
	var max_signal_val := 0.0
	for v in signal_row:
		if v > max_signal_val:
			max_signal_val = v
	assert_gt(max_signal_val, 0.35, "Con segnale visibile nel cono il waterfall deve mostrare il picco di potenza")
	
	# Ritorno a 90° (nessun segnale): azzeramento immediato
	canvas.update_state(1840.0, false, 90.0, true, [])
	assert_eq(canvas.active_signals.size(), 0)
	var cleared_top: PackedFloat32Array = canvas.waterfall_history[0]
	var max_cleared := 0.0
	for v in cleared_top:
		if v > max_cleared:
			max_cleared = v
	assert_lt(max_cleared, 0.25, "Tornando a 90° il waterfall deve tornare immediatamente vuoto (solo rumore)")
	
	canvas.free()
