class_name PodInfoApp
extends Control

## Applicazione Terminale PodInfo per il monitoraggio dei parametri vitali.
## Segue lo standard APP_ARCHITECTURE_STANDARD.md.

const APP_TITLE: String = "POD INFO - MONITOR VITALI"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(450, 350)

# --- RIFERIMENTI UI ---
@onready var hr_label: Label = %HRLabel
@onready var oxygen_label: Label = %OxygenLabel
@onready var temp_label: Label = %TempLabel
@onready var air_quality_label: Label = %AirQualityLabel
@onready var g_force_label: Label = %GForceLabel
@onready var heart_rate_timer: Timer = %HeartRateTimer

# --- RIFERIMENTI AUDIO ---
@onready var background_audio: AudioStreamPlayer = %BackgroundAudio
@onready var sfx_audio: AudioStreamPlayer = %SFXAudio

# --- STATO SIMULATO ---
var hr_value: float = 72.0
var oxygen_value: float = 98.5
var temp_value: float = 36.6
var air_quality_value: float = 99.8
var g_force_value: float = 1.0

func _ready() -> void:
	_configure_window()
	_setup_timers()
	_setup_audio()
	_update_ui()

func _process(delta: float) -> void:
	_simulate_vital_signs(delta)
	_update_audio_pacing()
	_update_ui()

func _configure_window() -> void:
	custom_minimum_size = DEFAULT_WINDOW_SIZE
	var parent_win := get_parent()
	while parent_win:
		if "window_title" in parent_win:
			parent_win.window_title = APP_TITLE
			break
		parent_win = parent_win.get_parent()

func _setup_timers() -> void:
	# Timer per simulare il battito cardiaco se necessario
	if heart_rate_timer:
		heart_rate_timer.wait_time = 60.0 / hr_value
		heart_rate_timer.start()

func _simulate_vital_signs(delta: float) -> void:
	# Frequenza cardiaca: fluttuazione naturale
	hr_value += randf_range(-0.2, 0.2)
	hr_value = clamp(hr_value, 60.0, 110.0)
	
	# Ossigeno: legge da LifeSupport se disponibile, altrimenti simula
	# Per ora simulazione, in futuro integrazione con LifeSupportManager
	oxygen_value += randf_range(-0.05, 0.05)
	oxygen_value = clamp(oxygen_value, 94.0, 100.0)
	
	# Temperatura: simulata in Celsius
	temp_value += randf_range(-0.01, 0.01)
	temp_value = clamp(temp_value, 36.4, 37.2)
	
	# Qualità dell'aria: simulata
	air_quality_value += randf_range(-0.02, 0.02)
	air_quality_value = clamp(air_quality_value, 98.0, 100.0)
	
	# G della nave: simulata fissa a 1.0 (o basata su accelerazione nave)
	g_force_value = 1.0 # TODO: Leggere accelerazione da ShipMovementManager

func _update_ui() -> void:
	if hr_label:
		hr_label.text = "FREQ. CARDIACA: %.1f BPM" % hr_value
		if hr_value > 100.0: hr_label.modulate = Color.RED
		elif hr_value < 65.0: hr_label.modulate = Color.CYAN
		else: hr_label.modulate = Color.WHITE
		
	if oxygen_label:
		oxygen_label.text = "OSSIGENO: %.1f%%" % oxygen_value
		if oxygen_value < 95.0: oxygen_label.modulate = Color.YELLOW
		else: oxygen_label.modulate = Color.WHITE
		
	if temp_label:
		temp_label.text = "TEMPERATURA: %.1f °C" % temp_value
		
	if air_quality_label:
		air_quality_label.text = "QUALITÀ ARIA: %.1f%%" % air_quality_value
		
	if g_force_label:
		g_force_label.text = "GRAVITÀ NAVE: %.2f G" % g_force_value

# --- GESTIONE AUDIO ---

func _setup_audio() -> void:
	# Inizializza i player audio
	if background_audio and not background_audio.playing:
		# background_audio.stream = load("res://Art/Audio/Ambience/ship_hum.ogg")
		# background_audio.play()
		pass
	
	if heart_rate_timer:
		heart_rate_timer.timeout.connect(_on_heart_rate_beat)

func _update_audio_pacing() -> void:
	# Aggiorna la velocità del battito cardiaco in base a hr_value
	if heart_rate_timer:
		heart_rate_timer.wait_time = 60.0 / hr_value

func _on_heart_rate_beat() -> void:
	# Riproduce il suono del battito
	if sfx_audio:
		# sfx_audio.stream = load("res://Art/Audio/SFX/heartbeat.wav")
		# sfx_audio.play()
		pass

# --- TODO: GESTIONE SUONI BACKGROUND ---
# 1. Implementare AudioStreamPlayer2D per rumori ambientali della nave.
# 2. Implementare rumori di 'humming' dei sistemi di supporto vitale.
# 3. Aggiungere effetti sonori per allarmi (O2 basso, HR alto).
