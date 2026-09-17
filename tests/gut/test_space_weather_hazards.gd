extends GutTest

## Suite di test GUT per i Pericoli Spaziali Dinamici & Eventi Meteo Settore (SpaceWeatherManager).
## Verifica ciclo vitale a 4 fasi (DORMANT, WARNING, ACTIVE, DISSIPATING),
## cono d'ombra macro planetario e micro 3D, mitigazione deflettori in ShieldMatrix,
## telemetria diegetica in SensorsApp e aborto al salto iperspaziale.

var _weather_mgr: SpaceWeatherManager = null
var _sensors_app: SensorsApp = null
var _shield_app: ShieldMatrixApp = null

func before_each() -> void:
	_weather_mgr = SpaceWeatherManager.new()
	_weather_mgr.set_process(false)
	add_child_autofree(_weather_mgr)
	if SpaceWorldManager:
		SpaceWorldManager.abort_active_weather()

func after_each() -> void:
	if is_instance_valid(_sensors_app):
		_sensors_app.queue_free()
		_sensors_app = null
	if is_instance_valid(_shield_app):
		_shield_app.queue_free()
		_shield_app = null
	if SpaceWorldManager:
		SpaceWorldManager.abort_active_weather()

func test_weather_lifecycle_transitions() -> void:
	var state_history: Array[int] = []
	var flags := {
		"impact_received": false,
		"cleared_received": false
	}
	
	_weather_mgr.weather_state_changed.connect(func(st, _ht, _tr):
		state_history.append(st)
	)
	_weather_mgr.weather_wave_impacted.connect(func(_ht, _exp):
		flags["impact_received"] = true
	)
	_weather_mgr.weather_cleared.connect(func():
		flags["cleared_received"] = true
	)
	
	# 1. Trigger WARNING (5.0s pre-allerta, 10.0s attiva)
	_weather_mgr.trigger_weather_event(SpaceWeatherManager.WeatherHazardType.SOLAR_CME, 5.0, 10.0)
	
	assert_eq(_weather_mgr.current_state, SpaceWeatherManager.WeatherState.WARNING, "Stato iniziale deve essere WARNING")
	assert_eq(_weather_mgr.current_hazard_type, SpaceWeatherManager.WeatherHazardType.SOLAR_CME, "Tipo pericolo deve essere SOLAR_CME")
	assert_almost_eq(_weather_mgr.state_timer, 5.0, 0.1, "Timer warning impostato a 5s")
	
	# 2. Transizione a ACTIVE (dopo 5.1s)
	_weather_mgr._process(5.1)
	assert_eq(_weather_mgr.current_state, SpaceWeatherManager.WeatherState.ACTIVE, "Stato deve passare ad ACTIVE")
	assert_almost_eq(_weather_mgr.state_timer, 10.0, 0.1, "Timer active impostato a 10s")
	assert_true(flags["impact_received"], "Segnale weather_wave_impacted deve essere stato emesso all'impatto")
	
	# 3. Transizione a DISSIPATING (dopo 10.1s)
	_weather_mgr._process(10.1)
	assert_eq(_weather_mgr.current_state, SpaceWeatherManager.WeatherState.DISSIPATING, "Stato deve passare a DISSIPATING")
	assert_almost_eq(_weather_mgr.state_timer, 5.0, 0.1, "Timer dissipazione impostato a 5s")
	
	# 4. Transizione a DORMANT (dopo 5.1s)
	_weather_mgr._process(5.1)
	assert_eq(_weather_mgr.current_state, SpaceWeatherManager.WeatherState.DORMANT, "Stato finale deve tornare a DORMANT")
	assert_true(flags["cleared_received"], "Segnale weather_cleared deve essere stato emesso al ritorno in quiete")
	assert_true(state_history.size() >= 4, "Tutte e 4 le transizioni di stato devono essere state notificate")

func test_planetary_macro_shadow_shelter() -> void:
	# Simula settore situato nel cono d'ombra del pianeta (occlusion_factor >= 0.75)
	_weather_mgr.set_custom_macro_shelter(true, 0.08, "PLANETARY_SHADOW")
	
	var status: Dictionary = _weather_mgr.evaluate_ship_shelter()
	assert_true(status.get("is_sheltered", false), "Nave deve risultare riparata nel cono d'ombra planetario")
	assert_eq(status.get("shelter_source", ""), "PLANETARY_SHADOW", "Sorgente riparo deve essere PLANETARY_SHADOW")
	assert_lt(float(status.get("exposure_factor", 1.0)), 0.15, "Fattore di esposizione deve essere <= 0.15 (schermatura > 85%)")
	assert_gt(float(status.get("occlusion_factor", 0.0)), 0.85, "Occlusion factor deve essere > 0.85")

func test_local_asteroid_micro_shadow_shelter() -> void:
	# Stella a (0, 0, -1000) -> sun_vector verso (0, 0, -1).
	# Asteroide massiccio a (0, 0, 0) con raggio 40m.
	# Nave a (0, 0, 50) -> situata nel cono d'ombra posteriore.
	_weather_mgr.set_sun_vector(Vector3(0, 0, -1))
	_weather_mgr.set_custom_ship_position(Vector3(0, 0, 50))
	_weather_mgr.set_custom_obstacles([
		{
			"pos": Vector3(0, 0, 0),
			"radius_m": 40.0,
			"type": "ASTEROID"
		}
	])
	
	var shelter: Dictionary = _weather_mgr._calculate_micro_occlusion()
	assert_true(shelter.get("is_sheltered", false), "La nave deve beneficiare del riparo geometrico 3D dell'asteroide")
	assert_eq(shelter.get("shelter_source", ""), "ASTEROID", "Sorgente riparo locale deve essere ASTEROID")
	assert_true(float(shelter.get("exposure_factor", 1.0)) <= 0.20, "Esposizione effettiva deve essere <= 0.20")
	
	# Sposta la nave lateralmente a (100, 0, 50) fuori dal cono d'ombra
	_weather_mgr.set_custom_ship_position(Vector3(100, 0, 50))
	var exposed_shelter: Dictionary = _weather_mgr._calculate_micro_occlusion()
	assert_false(exposed_shelter.get("is_sheltered", false), "Fuori dal cono d'ombra l'occlusione locale deve essere false")
	assert_almost_eq(float(exposed_shelter.get("exposure_factor", 1.0)), 1.0, 0.05, "Esposizione al 100% in spazio aperto")

func test_shield_matrix_weather_mitigation() -> void:
	var shield_scene: PackedScene = load("res://Applications/ShieldMatrix/shield_matrix_app.tscn")
	assert_not_null(shield_scene, "Scena shield_matrix_app.tscn deve essere caricabile")
	_shield_app = shield_scene.instantiate() as ShieldMatrixApp
	add_child_autofree(_shield_app)
	await get_tree().process_frame
	
	# Configura quadrante FORE al 50% di potenza con armoniche sincronizzate
	_shield_app.ratio_fore = 0.50
	_shield_app.ratio_aft = 0.20
	_shield_app.ratio_port = 0.15
	_shield_app.ratio_starboard = 0.15
	_shield_app.is_phase_synced = true
	
	# Flare solare frontale (proveniente da prua: sun_dir_local = (0, 0, -1))
	var sun_dir := Vector3(0, 0, -1)
	var raw_damage := 100.0
	
	var residual_damage := _shield_app.mitigate_space_weather_impact(0, sun_dir, raw_damage)
	assert_eq(residual_damage, 0.0, "Con ratio >= 0.40 e fasi sincronizzate il danno allo scafo deve essere interamente azzerato")
	
	# Test caso negativo: fasi asincrone
	_shield_app.is_phase_synced = false
	var unmitigated_damage := _shield_app.mitigate_space_weather_impact(0, sun_dir, raw_damage)
	assert_gt(unmitigated_damage, 50.0, "Senza sincronizzazione di fase la schermatura è inefficiente (danno scafo elevato)")

func test_sensors_weather_telemetry_integration() -> void:
	var sensors_scene: PackedScene = load("res://Applications/Sensors/sensors_app.tscn")
	assert_not_null(sensors_scene, "Scena sensors_app.tscn deve essere caricabile")
	_sensors_app = sensors_scene.instantiate() as SensorsApp
	add_child_autofree(_sensors_app)
	await get_tree().process_frame
	
	# 1. Stato WARNING: deve mostrare il banner arancione con conto alla rovescia ed esposizione
	_sensors_app.update_weather_telemetry(1, 0, 25.0, false, 1.0, "NONE")
	assert_true(_sensors_app.weather_alert_banner.visible, "WeatherAlertBanner deve essere visibile in stato WARNING")
	assert_true(_sensors_app.weather_alert_label.text.contains("SOLAR CME"), "Banner deve riportare SOLAR CME")
	assert_true(_sensors_app.weather_alert_label.text.contains("100% ESPOSTO"), "Banner deve indicare 100% ESPOSTO")
	
	# 2. Stato ACTIVE al riparo: deve mostrare l'impatto con schermatura planetaria
	_sensors_app.update_weather_telemetry(2, 0, 12.0, true, 0.05, "PLANETARY_SHADOW")
	assert_true(_sensors_app.weather_alert_banner.visible, "WeatherAlertBanner deve essere visibile in stato ACTIVE")
	assert_true(_sensors_app.weather_alert_label.text.contains("IMPATTO METEO IN CORSO"), "Banner deve segnalare impatto in corso")
	assert_true(_sensors_app.weather_alert_label.text.contains("RIPARO: 95%"), "Banner deve indicare 95% di riparo")
	
	# 3. Stato DORMANT: banner deve scomparire
	_sensors_app.update_weather_telemetry(0, 0, 0.0, false, 1.0, "NONE")
	assert_false(_sensors_app.weather_alert_banner.visible, "WeatherAlertBanner deve essere nascosto in stato DORMANT")

func test_sector_jump_aborts_active_weather() -> void:
	if not SpaceWorldManager:
		pass_test("SpaceWorldManager non disponibile")
		return
	
	# Avvia un evento di tempesta ionica
	SpaceWorldManager.trigger_space_weather(SpaceWeatherManager.WeatherHazardType.ION_EMP_STORM, 18.0, 25.0)
	var active_info: Dictionary = SpaceWorldManager.get_active_weather_info()
	assert_eq(int(active_info.get("state", -1)), SpaceWeatherManager.WeatherState.WARNING, "Tempesta deve essere in stato WARNING")
	
	# Simula salto o caricamento nuovo settore (abort_active_weather)
	SpaceWorldManager.abort_active_weather()
	var reset_info: Dictionary = SpaceWorldManager.get_active_weather_info()
	assert_eq(int(reset_info.get("state", -1)), SpaceWeatherManager.WeatherState.DORMANT, "Dopo l'aborto lo stato deve tornare a DORMANT")
	assert_almost_eq(float(reset_info.get("time_remaining", -1.0)), 0.0, 0.01, "Timer resettato a zero")
