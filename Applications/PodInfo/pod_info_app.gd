class_name PodInfoApp
extends Control

## Widget diegetico PodInfo per il monitoraggio dei parametri vitali (sempre attivo in Taskbar),
## microfono virtuale diegetico in plancia e gestione degli stati fisiologici dell'equipaggio.
## A differenza delle altre app GodotOS non è una finestra apribile/chiudibile: viene istanziato
## direttamente nella Taskbar all'avvio ed è sempre presente, poiché gestisce anche l'audio di bordo.

enum CrewPhysiologicalState {
	NORMAL,
	HYPOXIA,
	HYPERTHERMIA,
	HYPOTHERMIA,
	GLOC_BLACKOUT,
	REDOUT,
	DECEASED
}

signal vital_signs_updated(o2: float, temp: float, pressure: float, g_force: float)
signal crew_state_changed(old_state: int, new_state: int)
signal game_over_triggered(reason: String)
signal spatial_sound_played(sound_name: String, event_pos: Vector2, distance: float, vol_db: float, is_lowpass: bool)
signal biometric_pulse_updated(heart_rate: float, stress_level: float)
signal screen_shake_triggered(intensity: float, duration: float)

# --- RIFERIMENTI UI ---
@onready var oxygen_label: Label = %OxygenLabel
@onready var temp_label: Label = %TempLabel
@onready var pressure_label: Label = get_node_or_null("%PressureLabel")
@onready var g_force_label: Label = %GForceLabel

# --- RIFERIMENTI AUDIO ---
@onready var background_audio: AudioStreamPlayer = %BackgroundAudio
@onready var sfx_audio: AudioStreamPlayer = %SFXAudio
@onready var vocal_audio: AudioStreamPlayer = get_node_or_null("%VocalAudio")
@onready var drone_audio: AudioStreamPlayer = get_node_or_null("%DroneAudio")
@onready var spatial_audio: AudioStreamPlayer = get_node_or_null("%SpatialAudio")

# --- STATO PARAMETRI VITALI (Sincronizzati in tempo reale) ---
var oxygen_value: float = 21.0
var temp_value: float = 21.5
var pressure_value: float = 101.3
var g_force_value: float = 1.0
var heart_rate: float = 75.0
var stress_level: float = 0.0

var current_state: CrewPhysiologicalState = CrewPhysiologicalState.NORMAL
var blackout_intensity: float = 0.0
var redout_intensity: float = 0.0
var is_game_over: bool = false
var game_over_reason: String = ""

var high_g_timer: float = 0.0
var negative_g_timer: float = 0.0
var vocal_cooldown: float = 0.0

# --- SCREEN SHAKE DIEGETICO ---
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO
var _target_shake_node: Control = null

# --- MICROFONO VIRTUALE IN PLANCIA ---
var bridge_pos: Vector2 = Vector2(300, 80)
var last_calculated_attenuation: float = 1.0
var last_calculated_vol_db: float = 0.0
var last_applied_filter_lowpass: bool = false
var _cached_audio_streams: Dictionary = {}

# --- OVERLAY SCHERMO ---
var overlay_layer: CanvasLayer = null
var blackout_overlay: ColorRect = null
var redout_overlay: ColorRect = null
var alert_overlay: ColorRect = null
var game_over_panel: Control = null
var game_over_label: Label = null

# --- ALLERTA GENERALE NAVE ---
var alert_condition: int = 0
var alert_audio: AudioStreamPlayer = null
var _alert_pulse_timer: float = 0.0

func _ready() -> void:
	_init_procedural_audio()
	_setup_overlay()
	_connect_system_signals()
	_update_bridge_position()
	_simulate_vital_signs(0.0)
	_update_ui()

func _exit_tree() -> void:
	if SpaceWorldManager:
		if SpaceWorldManager.ship_damage_taken.is_connected(_on_ship_damage_taken):
			SpaceWorldManager.ship_damage_taken.disconnect(_on_ship_damage_taken)
		if SpaceWorldManager.electrical_short_sparked.is_connected(_on_electrical_short_sparked):
			SpaceWorldManager.electrical_short_sparked.disconnect(_on_electrical_short_sparked)
		if SpaceWorldManager.duct_drone_position_updated.is_connected(_on_duct_drone_position_updated):
			SpaceWorldManager.duct_drone_position_updated.disconnect(_on_duct_drone_position_updated)
		if SpaceWorldManager.has_signal("cruise_proximity_drop_occurred") and SpaceWorldManager.cruise_proximity_drop_occurred.is_connected(_on_cruise_proximity_drop):
			SpaceWorldManager.cruise_proximity_drop_occurred.disconnect(_on_cruise_proximity_drop)
		if SpaceWorldManager.has_signal("weather_wave_impacted") and SpaceWorldManager.weather_wave_impacted.is_connected(_on_weather_wave_impacted):
			SpaceWorldManager.weather_wave_impacted.disconnect(_on_weather_wave_impacted)
		if SpaceWorldManager.has_signal("ship_alert_condition_changed") and SpaceWorldManager.ship_alert_condition_changed.is_connected(_on_ship_alert_condition_changed):
			SpaceWorldManager.ship_alert_condition_changed.disconnect(_on_ship_alert_condition_changed)
	if overlay_layer and is_instance_valid(overlay_layer):
		overlay_layer.queue_free()
		overlay_layer = null

func _process(delta: float) -> void:
	_process_screen_shake(delta)
	if is_game_over:
		return
	_simulate_vital_signs(delta)
	_update_physiological_state(delta)
	_update_overlay_visuals()
	_update_ui()
	vital_signs_updated.emit(oxygen_value, temp_value, pressure_value, g_force_value)

func _connect_system_signals() -> void:
	if SpaceWorldManager:
		if not SpaceWorldManager.ship_damage_taken.is_connected(_on_ship_damage_taken):
			SpaceWorldManager.ship_damage_taken.connect(_on_ship_damage_taken)
		if not SpaceWorldManager.electrical_short_sparked.is_connected(_on_electrical_short_sparked):
			SpaceWorldManager.electrical_short_sparked.connect(_on_electrical_short_sparked)
		if not SpaceWorldManager.duct_drone_position_updated.is_connected(_on_duct_drone_position_updated):
			SpaceWorldManager.duct_drone_position_updated.connect(_on_duct_drone_position_updated)
		if SpaceWorldManager.has_signal("cruise_proximity_drop_occurred") and not SpaceWorldManager.cruise_proximity_drop_occurred.is_connected(_on_cruise_proximity_drop):
			SpaceWorldManager.cruise_proximity_drop_occurred.connect(_on_cruise_proximity_drop)
		if SpaceWorldManager.has_signal("weather_wave_impacted") and not SpaceWorldManager.weather_wave_impacted.is_connected(_on_weather_wave_impacted):
			SpaceWorldManager.weather_wave_impacted.connect(_on_weather_wave_impacted)
		if SpaceWorldManager.has_signal("ship_alert_condition_changed") and not SpaceWorldManager.ship_alert_condition_changed.is_connected(_on_ship_alert_condition_changed):
			SpaceWorldManager.ship_alert_condition_changed.connect(_on_ship_alert_condition_changed)
		if SpaceWorldManager.has_method("get_ship_alert_condition"):
			alert_condition = SpaceWorldManager.get_ship_alert_condition()
			if alert_condition != 0 and alert_audio and not alert_audio.playing:
				alert_audio.play()

func _on_cruise_proximity_drop(_obstacle_name: String, _distance: float) -> void:
	trigger_screen_shake(22.0, 1.2)
	record_biometric_stress(45.0)
	_play_spatial_ship_sound(bridge_pos, null, 6.0, "impact")

func _on_weather_wave_impacted(_hazard_type: int, effective_exposure: float) -> void:
	if effective_exposure > 0.15:
		var intensity := 16.0 * effective_exposure
		trigger_screen_shake(intensity, 1.0)
		record_biometric_stress(35.0 * effective_exposure)
		stress_level = clampf(stress_level + 0.4 * effective_exposure, 0.0, 1.0)
		_play_spatial_ship_sound(bridge_pos, null, 5.0, "breach")

func _on_ship_alert_condition_changed(cond: int) -> void:
	var prev := alert_condition
	alert_condition = cond
	if cond == 2: # RED
		if prev != 2:
			record_biometric_stress(30.0)
			trigger_screen_shake(8.0, 0.6)
		if alert_audio and not alert_audio.playing:
			alert_audio.play()
	elif cond == 1: # YELLOW
		if prev == 0:
			record_biometric_stress(10.0)
		if alert_audio and not alert_audio.playing:
			alert_audio.play()
	else:
		if alert_audio and alert_audio.playing:
			alert_audio.stop()
		if alert_overlay:
			alert_overlay.color.a = 0.0

func get_alert_condition() -> int:
	return alert_condition

func _update_bridge_position() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_method("get_bridge_position"):
		bridge_pos = SpaceWorldManager.get_bridge_position()

# --- SINCRONIZZAZIONE TELEMETRIA REALE ---

func _simulate_vital_signs(delta: float) -> void:
	if SpaceWorldManager:
		var atmo: Dictionary = SpaceWorldManager.get_bridge_atmo_state()
		oxygen_value = float(atmo.get("o2_pct", 21.0))
		temp_value = float(atmo.get("temperature_c", 21.5))
		pressure_value = float(atmo.get("pressure_kpa", 101.3))
		g_force_value = SpaceWorldManager.get_ship_g_force()
	
	# Rientro graduale della frequenza cardiaca e dello stress
	heart_rate = move_toward(heart_rate, 75.0, 15.0 * delta)
	stress_level = move_toward(stress_level, 0.0, 0.25 * delta)
	biometric_pulse_updated.emit(heart_rate, stress_level)

# --- MACCHINA A STATI FISIOLOGICA DELL'EQUIPAGGIO ---

func _update_physiological_state(delta: float) -> void:
	if is_game_over:
		return
		
	vocal_cooldown = maxf(0.0, vocal_cooldown - delta)
	var prev_state := current_state
	var target_blackout_g := 0.0
	var target_redout_g := 0.0
	var is_in_asphyxia := (oxygen_value < 12.0 or pressure_value < 20.0)
	var is_in_hyperthermia := (temp_value > 45.0)
	var is_in_hypothermia := (temp_value < 10.0)
	
	# 1. Effetti Forza G
	if g_force_value > 4.5:
		target_blackout_g = clampf((g_force_value - 4.5) / 2.5, 0.0, 1.0)
		if g_force_value > 7.0:
			high_g_timer += delta
			if high_g_timer > 3.0:
				_trigger_game_over("DECESSO PER ARRESTO CARDIACO (G-LOC POSITIVO)")
				return
		else:
			high_g_timer = maxf(0.0, high_g_timer - delta * 0.5)
	else:
		high_g_timer = maxf(0.0, high_g_timer - delta)
		
	if g_force_value < -1.5:
		target_redout_g = clampf((-g_force_value - 1.5) / 2.0, 0.0, 1.0)
		if g_force_value < -3.5:
			negative_g_timer += delta
			if negative_g_timer > 2.0:
				_trigger_game_over("DECESSO PER ROTTURA VASCOLARE (REDOUT NEGATIVO)")
				return
		else:
			negative_g_timer = maxf(0.0, negative_g_timer - delta * 0.5)
	else:
		negative_g_timer = maxf(0.0, negative_g_timer - delta)
		
	# 2. Stato Asfissia
	if is_in_asphyxia:
		current_state = CrewPhysiologicalState.HYPOXIA
		blackout_intensity += delta * 0.15
		_handle_asphyxia_vocal(delta)
		if blackout_intensity >= 1.0:
			_trigger_game_over("DECESSO PER ASFISSIA")
			return
	else:
		# Recupero progressivo Blackout
		if g_force_value <= 4.5 and temp_value >= 10.0:
			blackout_intensity = move_toward(blackout_intensity, 0.0, delta * 0.2)
			
	# 3. Stato Ipertermia
	if is_in_hyperthermia:
		if temp_value > 80.0:
			_trigger_game_over("DECESSO PER COMBUSTIONE TERMICA")
			return
		elif temp_value > 65.0:
			current_state = CrewPhysiologicalState.HYPERTHERMIA
			_handle_screaming_vocal(delta)
		else:
			current_state = CrewPhysiologicalState.HYPERTHERMIA
			_handle_panting_vocal(delta)
			
	# 4. Stato Ipotermia
	if is_in_hypothermia:
		if temp_value <= 0.0:
			_trigger_game_over("DECESSO PER IPOTERMIA")
			return
		else:
			current_state = CrewPhysiologicalState.HYPOTHERMIA
			blackout_intensity = minf(1.0, blackout_intensity + delta * 0.04)
			_handle_teeth_chatter_vocal(delta)
			
	# 5. Combinazione Overlays
	blackout_intensity = clampf(maxf(blackout_intensity, target_blackout_g), 0.0, 1.0)
	redout_intensity = clampf(target_redout_g, 0.0, 1.0)
	
	if not is_in_asphyxia and not is_in_hyperthermia and not is_in_hypothermia:
		if target_blackout_g > 0.0:
			current_state = CrewPhysiologicalState.GLOC_BLACKOUT
		elif target_redout_g > 0.0:
			current_state = CrewPhysiologicalState.REDOUT
		else:
			current_state = CrewPhysiologicalState.NORMAL
			
	if current_state != prev_state:
		crew_state_changed.emit(prev_state, current_state)

func _handle_asphyxia_vocal(delta: float) -> void:
	if vocal_cooldown <= 0.0:
		var interval := clampf(oxygen_value * 0.15, 0.6, 2.5)
		vocal_cooldown = interval
		_play_vocal_fx("asphyxia", 2.0)

func _handle_screaming_vocal(delta: float) -> void:
	if vocal_cooldown <= 0.0:
		vocal_cooldown = 1.0
		_play_vocal_fx("scream", 4.0)

func _handle_panting_vocal(delta: float) -> void:
	if vocal_cooldown <= 0.0:
		vocal_cooldown = 0.8
		_play_vocal_fx("panting", 0.0)

func _handle_teeth_chatter_vocal(delta: float) -> void:
	if vocal_cooldown <= 0.0:
		vocal_cooldown = 0.9
		_play_vocal_fx("teeth_chatter", 1.0)

func _play_vocal_fx(sfx_key: String, volume_boost: float = 0.0) -> void:
	var player: AudioStreamPlayer = vocal_audio if vocal_audio else sfx_audio
	if player and _cached_audio_streams.has(sfx_key):
		player.bus = &"SFX" if AudioServer.get_bus_index("SFX") != -1 else &"Master"
		player.volume_db = volume_boost
		player.stream = _cached_audio_streams[sfx_key]
		player.play()

# --- MICROFONO VIRTUALE IN PLANCIA & AUDIO SPAZIALE ---

func play_spatial_ship_sound(event_pos: Vector2, sfx_stream: AudioStream = null, base_vol: float = 0.0, sfx_name: String = "impact") -> void:
	_play_spatial_ship_sound(event_pos, sfx_stream, base_vol, sfx_name)

func _play_spatial_ship_sound(event_pos: Vector2, sfx_stream: AudioStream = null, base_vol: float = 0.0, sfx_name: String = "impact") -> void:
	_update_bridge_position()
	var d: float = bridge_pos.distance_to(event_pos)
	var A: float = 1.0 / (1.0 + 0.01 * d)
	var vol_db: float = base_vol + 20.0 * (log(maxf(A, 0.0001)) / log(10.0))
	vol_db = clampf(vol_db, -80.0, 12.0)
	var is_lowpass: bool = (d > 150.0)
	
	last_calculated_attenuation = A
	last_calculated_vol_db = vol_db
	last_applied_filter_lowpass = is_lowpass
	
	var player: AudioStreamPlayer = spatial_audio if spatial_audio else sfx_audio
	if player:
		if is_lowpass:
			player.bus = &"DiegeticMuffled"
		else:
			player.bus = &"SFX" if AudioServer.get_bus_index("SFX") != -1 else &"Master"
		player.volume_db = vol_db
		if sfx_stream:
			player.stream = sfx_stream
		elif _cached_audio_streams.has(sfx_name):
			player.stream = _cached_audio_streams[sfx_name]
		player.play()
		
	spatial_sound_played.emit(sfx_name, event_pos, d, vol_db, is_lowpass)

func _on_ship_damage_taken(pos: Vector2, type: String) -> void:
	var s_name := "impact"
	match type:
		"short_circuit", "spark":
			s_name = "spark"
		"decompression":
			s_name = "decompression"
		"fire", "fire_hiss":
			s_name = "fire_hiss"
		"breach", "impact", "ballistic", _:
			s_name = "impact"
	
	_play_spatial_ship_sound(pos, null, 0.0, s_name)
	
	# Screen shake diegetico proporzionale alla violenza dell'impatto
	var shake_power := 12.0
	if type == "impact" or type == "ballistic":
		shake_power = 18.0
	elif type == "breach" or type == "decompression":
		shake_power = 14.0
	elif type == "short_circuit":
		shake_power = 8.0
	trigger_screen_shake(shake_power, 0.45)
	
	# Reattività biometrica: picco di battito cardiaco e stress claustrofobico
	record_biometric_stress(25.0)

func _on_electrical_short_sparked(pos: Vector2) -> void:
	_play_spatial_ship_sound(pos, null, -2.0, "spark")

func _on_duct_drone_position_updated(pos: Vector2) -> void:
	_update_drone_spatial_sound(pos)

func _update_drone_spatial_sound(pos: Vector2) -> void:
	_update_bridge_position()
	var d: float = bridge_pos.distance_to(pos)
	var A: float = 1.0 / (1.0 + 0.01 * d)
	var vol_db: float = -6.0 + 20.0 * (log(maxf(A, 0.0001)) / log(10.0))
	vol_db = clampf(vol_db, -80.0, 6.0)
	var is_lowpass: bool = (d > 150.0)
	
	if drone_audio:
		if is_lowpass:
			drone_audio.bus = &"DiegeticMuffled"
		else:
			drone_audio.bus = &"Ambient" if AudioServer.get_bus_index("Ambient") != -1 else &"Master"
		drone_audio.volume_db = vol_db
		if drone_audio.stream == null and _cached_audio_streams.has("drone_hum"):
			drone_audio.stream = _cached_audio_streams["drone_hum"]
		if not drone_audio.playing and drone_audio.stream != null:
			drone_audio.play()

# --- OVERLAYS SCHERMO & GAME OVER ---

func _setup_overlay() -> void:
	if overlay_layer != null and is_instance_valid(overlay_layer):
		return
		
	overlay_layer = CanvasLayer.new()
	overlay_layer.name = "CrewVitalsOverlayLayer"
	overlay_layer.layer = 120
	
	blackout_overlay = ColorRect.new()
	blackout_overlay.name = "BlackoutOverlay"
	blackout_overlay.color = Color(0, 0, 0, 0)
	blackout_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blackout_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_layer.add_child(blackout_overlay)
	
	redout_overlay = ColorRect.new()
	redout_overlay.name = "RedoutOverlay"
	redout_overlay.color = Color(0.9, 0.05, 0.05, 0)
	redout_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	redout_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_layer.add_child(redout_overlay)
	
	alert_overlay = ColorRect.new()
	alert_overlay.name = "AlertOverlay"
	alert_overlay.color = Color(1.0, 0.05, 0.05, 0)
	alert_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_layer.add_child(alert_overlay)
	
	game_over_panel = _create_game_over_panel()
	game_over_panel.visible = false
	overlay_layer.add_child(game_over_panel)
	
	var root := get_tree().root if get_tree() else null
	if root:
		root.add_child.call_deferred(overlay_layer)
	else:
		add_child.call_deferred(overlay_layer)

func _create_game_over_panel() -> Control:
	var panel := Control.new()
	panel.name = "GameOverPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(400, 200)
	
	var title := Label.new()
	title.text = "✖ SEGNALE BIOMETRICO PERSO ✖"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	vbox.add_child(title)
	
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	game_over_label = Label.new()
	game_over_label.name = "GameOverReasonLabel"
	game_over_label.text = "CAUSA DEL DECESSO: COLLASSO VITALE"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 16)
	game_over_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.8))
	vbox.add_child(game_over_label)
	
	panel.add_child(vbox)
	return panel

func _update_overlay_visuals() -> void:
	if blackout_overlay:
		blackout_overlay.color.a = clampf(blackout_intensity, 0.0, 1.0)
	if redout_overlay:
		var red_alpha := clampf(redout_intensity * 0.85 + (stress_level * 0.25), 0.0, 0.95)
		redout_overlay.color.a = red_alpha
	if alert_overlay:
		if alert_condition == 2: # RED
			_alert_pulse_timer += get_process_delta_time()
			var pulse := (sin(_alert_pulse_timer * 4.0) * 0.5 + 0.5)
			alert_overlay.color = Color(0.95, 0.05, 0.05, 0.06 + pulse * 0.16)
		elif alert_condition == 1: # YELLOW
			_alert_pulse_timer += get_process_delta_time()
			var pulse := (sin(_alert_pulse_timer * 2.0) * 0.5 + 0.5)
			alert_overlay.color = Color(0.95, 0.75, 0.1, 0.03 + pulse * 0.06)
		else:
			alert_overlay.color.a = 0.0

func _trigger_game_over(reason: String) -> void:
	if is_game_over:
		return
	is_game_over = true
	current_state = CrewPhysiologicalState.DECEASED
	game_over_reason = reason
	
	if game_over_label:
		game_over_label.text = "CAUSA DEL DECESSO: " + reason
	if game_over_panel:
		game_over_panel.visible = true
	if blackout_overlay:
		blackout_overlay.color.a = 1.0
		
	game_over_triggered.emit(reason)
	if SpaceWorldManager and SpaceWorldManager.has_signal("crew_game_over"):
		SpaceWorldManager.crew_game_over.emit(reason)

# --- GESTIONE AUDIO E SINTESI ---

func _setup_diegetic_audio_bus() -> void:
	var bus_name := "DiegeticMuffled"
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		AudioServer.add_bus()
		bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_idx, bus_name)
		AudioServer.set_bus_send(bus_idx, "Master")
		var lpf := AudioEffectLowPassFilter.new()
		lpf.cutoff_hz = 800.0
		AudioServer.add_bus_effect(bus_idx, lpf)

func _init_procedural_audio() -> void:
	_setup_diegetic_audio_bus()
	_cached_audio_streams["asphyxia"] = _create_asphyxia_stream()
	_cached_audio_streams["panting"] = _create_panting_stream()
	_cached_audio_streams["scream"] = _create_scream_stream()
	_cached_audio_streams["teeth_chatter"] = _create_teeth_chatter_stream()
	_cached_audio_streams["impact"] = _create_impact_stream()
	_cached_audio_streams["spark"] = _create_spark_stream()
	_cached_audio_streams["drone_hum"] = _create_drone_hum_stream()
	_cached_audio_streams["decompression"] = _create_decompression_stream()
	_cached_audio_streams["fire_hiss"] = _create_fire_hiss_stream()
	_cached_audio_streams["siren"] = _create_siren_stream()
	
	alert_audio = AudioStreamPlayer.new()
	alert_audio.name = "AlertSirenAudio"
	alert_audio.bus = &"DiegeticMuffled" if AudioServer.get_bus_index("DiegeticMuffled") != -1 else &"Master"
	alert_audio.stream = _cached_audio_streams["siren"]
	alert_audio.volume_db = -10.0
	add_child(alert_audio)

static func _create_pcm_wav(duration: float, generator_fn: Callable, mix_rate: int = 22050) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	var num_samples := int(duration * mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t := float(i) / float(mix_rate)
		var val: float = generator_fn.call(t, duration)
		var s := int(clampf(val, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, s)
	wav.data = bytes
	return wav

static func _create_asphyxia_stream() -> AudioStreamWAV:
	return _create_pcm_wav(0.5, func(t: float, dur: float) -> float:
		var noise := randf() * 2.0 - 1.0
		var tone := sin(2.0 * PI * 180.0 * t)
		return (tone * 0.4 + noise * 0.6) * sin(PI * t / dur) * exp(-2.0 * t)
	)

static func _create_panting_stream() -> AudioStreamWAV:
	return _create_pcm_wav(0.35, func(t: float, dur: float) -> float:
		var noise := randf() * 2.0 - 1.0
		return noise * 0.6 * sin(PI * t / dur)
	)

static func _create_scream_stream() -> AudioStreamWAV:
	return _create_pcm_wav(0.8, func(t: float, dur: float) -> float:
		var freq := 750.0 + sin(t * 30.0) * 150.0
		var tone := sin(2.0 * PI * freq * t)
		var noise := randf() * 2.0 - 1.0
		return (tone * 0.7 + noise * 0.3) * sin(PI * t / dur)
	)

static func _create_teeth_chatter_stream() -> AudioStreamWAV:
	return _create_pcm_wav(0.45, func(t: float, _dur: float) -> float:
		var pulse := 1.0 if fmod(t, 0.08) < 0.02 else 0.0
		var noise := randf() * 2.0 - 1.0
		return pulse * noise * 0.8
	)

static func _create_impact_stream() -> AudioStreamWAV:
	return _create_pcm_wav(0.4, func(t: float, _dur: float) -> float:
		var tone := sin(2.0 * PI * 110.0 * t)
		var noise := randf() * 2.0 - 1.0
		return (tone * 0.5 + noise * 0.5) * exp(-8.0 * t)
	)

static func _create_spark_stream() -> AudioStreamWAV:
	return _create_pcm_wav(0.3, func(t: float, _dur: float) -> float:
		var buzz := sin(2.0 * PI * 440.0 * t) if fmod(t, 0.04) < 0.02 else 0.0
		var crackle := randf() * 2.0 - 1.0
		return (buzz * 0.5 + crackle * 0.5) * exp(-5.0 * t)
	)

static func _create_drone_hum_stream() -> AudioStreamWAV:
	var wav := _create_pcm_wav(0.5, func(t: float, _dur: float) -> float:
		return (sin(2.0 * PI * 120.0 * t) * 0.7 + sin(2.0 * PI * 240.0 * t) * 0.3) * 0.5
	)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return wav

static func _create_decompression_stream() -> AudioStreamWAV:
	return _create_pcm_wav(0.7, func(t: float, dur: float) -> float:
		var noise := randf() * 2.0 - 1.0
		var envelope := sin(PI * t / dur) * exp(-1.5 * t)
		return noise * envelope * 0.8
	)

static func _create_fire_hiss_stream() -> AudioStreamWAV:
	return _create_pcm_wav(0.6, func(t: float, dur: float) -> float:
		var noise := randf() * 2.0 - 1.0
		var crackle := 1.0 if fmod(t, 0.05) < 0.015 else 0.0
		return (noise * 0.5 + crackle * 0.5) * sin(PI * t / dur)
	)

static func _create_siren_stream() -> AudioStreamWAV:
	var wav := _create_pcm_wav(1.0, func(t: float, dur: float) -> float:
		var freq := 500.0 + sin(2.0 * PI * 1.5 * t) * 150.0
		var tone := sin(2.0 * PI * freq * t)
		return tone * 0.4 * sin(PI * t / dur)
	)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return wav

# --- SCREEN SHAKE & BIOMETRIC ACTIONS ---

## Attiva lo scuotimento dello schermo (Screen Shake diegetico) con decadimento smorzato
func trigger_screen_shake(intensity: float = 12.0, duration: float = 0.45) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_duration = maxf(_shake_duration, duration)
	_shake_timer = _shake_duration
	screen_shake_triggered.emit(intensity, duration)

## Elabora il decadimento dello shake e ne applica l'offset al desktop
func _process_screen_shake(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer = maxf(0.0, _shake_timer - delta)
		var factor := _shake_timer / maxf(_shake_duration, 0.001)
		var current_amp := _shake_intensity * (factor * factor)
		_shake_offset = Vector2(
			randf_range(-current_amp, current_amp),
			randf_range(-current_amp, current_amp)
		)
		_apply_shake_offset(_shake_offset)
	else:
		if _shake_offset != Vector2.ZERO:
			_shake_offset = Vector2.ZERO
			_apply_shake_offset(Vector2.ZERO)
			_shake_intensity = 0.0
			_shake_duration = 0.0

func _apply_shake_offset(offset: Vector2) -> void:
	if not is_inside_tree():
		return
	if _target_shake_node == null or not is_instance_valid(_target_shake_node):
		_target_shake_node = get_tree().get_first_node_in_group("desktop_root") as Control
		if _target_shake_node == null:
			var p := get_parent()
			while p and not (p is Window or p == get_tree().root):
				if p is Control and (p.get_parent() is Window or p.get_parent() == get_tree().root):
					_target_shake_node = p as Control
					break
				p = p.get_parent()
				
	if _target_shake_node and is_instance_valid(_target_shake_node):
		_target_shake_node.position = offset

## Restituisce l'offset istantaneo dello shake
func get_screen_shake_offset() -> Vector2:
	return _shake_offset

func get_shake_intensity() -> float:
	return _shake_intensity

## Incrementa i parametri di stress e battito cardiaco all'impatto o guasto
func record_biometric_stress(added_stress: float = 25.0) -> void:
	heart_rate = minf(185.0, heart_rate + added_stress)
	stress_level = minf(1.0, stress_level + (added_stress / 50.0))

func get_heart_rate() -> float:
	return heart_rate

func get_stress_level() -> float:
	return stress_level

# --- AGGIORNAMENTO UI ---

## Aggiorna il widget compatto in Taskbar: mostra solo i 4 valori vitali essenziali
## (Ossigeno, Temperatura, Pressione, G-Force), colorati in base alla criticità.
func _update_ui() -> void:
	if oxygen_label:
		oxygen_label.text = "O2 %.0f%%" % oxygen_value
		if oxygen_value < 12.0:
			oxygen_label.modulate = Color.RED
		elif oxygen_value < 18.0:
			oxygen_label.modulate = Color.YELLOW
		else:
			oxygen_label.modulate = Color.WHITE
		
	if temp_label:
		temp_label.text = "%.1f°C" % temp_value
		if temp_value > 65.0 or temp_value <= 0.0:
			temp_label.modulate = Color.RED
		elif temp_value > 45.0 or temp_value < 10.0:
			temp_label.modulate = Color.YELLOW
		else:
			temp_label.modulate = Color.WHITE
		
	if pressure_label:
		pressure_label.text = "%.0f kPa" % pressure_value
		if pressure_value < 20.0:
			pressure_label.modulate = Color.RED
		elif pressure_value < 70.0:
			pressure_label.modulate = Color.YELLOW
		else:
			pressure_label.modulate = Color.WHITE
		
	if g_force_label:
		g_force_label.text = "%.1fG" % g_force_value
		if g_force_value > 4.5 or g_force_value < -1.5:
			g_force_label.modulate = Color.RED
		elif g_force_value > 2.5 or g_force_value < 0.0:
			g_force_label.modulate = Color.YELLOW
		else:
			g_force_label.modulate = Color.WHITE
