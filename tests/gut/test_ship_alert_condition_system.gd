extends GutTest

## Test GUT per il protocollo di allerta generale nave (Condition Green / Yellow / Red).
## Valuta la transizione automatica dello stato di allerta in base a brecce,
## scudi critici, tempeste solari, intrusioni cyber e i relativi feedback nei pod.

var _pod_info_scene: PackedScene = null
var _pod_app: PodInfoApp = null

func before_each() -> void:
	if SpaceWorldManager:
		SpaceWorldManager.set_ship_alert_condition(SpaceWorldManager.ShipAlertCondition.GREEN)
		SpaceWorldManager.clear_all_ship_damages()
		SpaceWorldManager.abort_active_weather()

func after_each() -> void:
	if is_instance_valid(_pod_app):
		_pod_app.queue_free()
	_pod_app = null
	if SpaceWorldManager:
		SpaceWorldManager.clear_all_ship_damages()
		SpaceWorldManager.abort_active_weather()
		SpaceWorldManager.set_ship_alert_condition(SpaceWorldManager.ShipAlertCondition.GREEN)

func test_initial_alert_condition_is_green() -> void:
	var cond := SpaceWorldManager.evaluate_ship_alert_condition()
	assert_eq(cond, SpaceWorldManager.ShipAlertCondition.GREEN, "In condizioni nominali l'allerta deve essere GREEN")
	assert_eq(SpaceWorldManager.get_ship_alert_condition(), SpaceWorldManager.ShipAlertCondition.GREEN)

func test_hull_breach_triggers_condition_red() -> void:
	# Aggiunge un danno di tipo breccia
	var dmg := SpaceWorldManager.spawn_ship_damage(SpaceWorldManager.DAMAGE_TYPE_BREACH, Vector2(250, 100), "Scafo di Prua", 5.0)
	assert_not_null(dmg)
	
	var cond := SpaceWorldManager.evaluate_ship_alert_condition()
	assert_eq(cond, SpaceWorldManager.ShipAlertCondition.RED, "Una breccia nello scafo non sigillata deve forzare CONDITION RED")
	assert_eq(SpaceWorldManager.get_ship_alert_condition(), SpaceWorldManager.ShipAlertCondition.RED)
	
	# Riparazione della breccia
	SpaceWorldManager.repair_ship_damage(dmg.id)
	cond = SpaceWorldManager.evaluate_ship_alert_condition()
	assert_eq(cond, SpaceWorldManager.ShipAlertCondition.GREEN, "Riparata la breccia, lo stato deve tornare GREEN")

func test_weather_active_wave_triggers_condition_red() -> void:
	SpaceWorldManager.trigger_space_weather(0, 1.0, 10.0) # SOLAR_CME
	var cond := SpaceWorldManager.evaluate_ship_alert_condition()
	assert_eq(cond, SpaceWorldManager.ShipAlertCondition.YELLOW, "In stato WARNING meteo deve essere CONDITION YELLOW")
	
	# Simula passaggio a stato ACTIVE senza riparo
	if SpaceWorldManager.weather_manager:
		SpaceWorldManager.weather_manager.current_state = SpaceWeatherManager.WeatherState.ACTIVE
		SpaceWorldManager.weather_manager.current_exposure_factor = 1.0
	
	cond = SpaceWorldManager.evaluate_ship_alert_condition()
	assert_eq(cond, SpaceWorldManager.ShipAlertCondition.RED, "Onda attiva non schermata deve scatenare CONDITION RED")
	
	# Aborto meteo
	SpaceWorldManager.abort_active_weather()
	cond = SpaceWorldManager.evaluate_ship_alert_condition()
	assert_eq(cond, SpaceWorldManager.ShipAlertCondition.GREEN, "Cessata la tempesta solare, lo stato deve rientrare a GREEN")

func test_electrical_or_minor_damage_triggers_condition_yellow() -> void:
	var dmg := SpaceWorldManager.spawn_ship_damage(SpaceWorldManager.DAMAGE_TYPE_SHORT_CIRCUIT, Vector2(300, 200), "Quadro Secondario", 4.0)
	assert_not_null(dmg)
	
	var cond := SpaceWorldManager.evaluate_ship_alert_condition()
	assert_eq(cond, SpaceWorldManager.ShipAlertCondition.YELLOW, "Danni minori o corti circuiti devono attivare CONDITION YELLOW")
	
	SpaceWorldManager.repair_ship_damage(dmg.id)
	cond = SpaceWorldManager.evaluate_ship_alert_condition()
	assert_eq(cond, SpaceWorldManager.ShipAlertCondition.GREEN, "Riparato il corto circuito, si torna a GREEN")

func test_pod_info_app_audiovisual_reaction_to_condition_red() -> void:
	_pod_info_scene = load("res://Applications/PodInfo/pod_info_app.tscn")
	assert_not_null(_pod_info_scene, "Scena pod_info_app.tscn caricabile")
	_pod_app = _pod_info_scene.instantiate() as PodInfoApp
	add_child_autofree(_pod_app)
	await get_tree().process_frame
	
	var initial_stress: float = _pod_app.get_stress_level()
	
	# Innesca CONDITION RED
	SpaceWorldManager.set_ship_alert_condition(SpaceWorldManager.ShipAlertCondition.RED)
	await get_tree().process_frame
	
	assert_eq(_pod_app.get_alert_condition(), 2, "PodInfoApp deve recepire CONDITION RED")
	assert_not_null(_pod_app.alert_overlay, "Overlay di allerta deve esistere")
	assert_true(_pod_app.get_stress_level() >= initial_stress, "Stress biometrico deve aumentare durante CONDITION RED")
	
	if _pod_app.alert_audio:
		assert_true(_pod_app.alert_audio.playing, "Sirena d'allarme deve essere attiva in CONDITION RED")
	
	# Ripristino CONDITION GREEN
	SpaceWorldManager.set_ship_alert_condition(SpaceWorldManager.ShipAlertCondition.GREEN)
	await get_tree().process_frame
	
	assert_eq(_pod_app.get_alert_condition(), 0, "PodInfoApp deve tornare a CONDITION GREEN")
	if _pod_app.alert_audio:
		assert_false(_pod_app.alert_audio.playing, "Sirena d'allarme deve spegnersi in CONDITION GREEN")
