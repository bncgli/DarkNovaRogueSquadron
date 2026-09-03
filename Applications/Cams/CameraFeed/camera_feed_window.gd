class_name CameraFeedWindow
extends FakeWindow

## Finestra GodotOS per la visualizzazione in tempo reale del feed di una telecamera dell'astronave.

@onready var sub_viewport_container: SubViewportContainer = %SubViewportContainer
@onready var feed_viewport: SubViewport = %FeedViewport
@onready var camera_3d: Camera3D = %FeedCamera3D

# Elementi HUD
@onready var cam_code_label: Label = %CamCodeLabel
@onready var live_badge: Label = %LiveBadge
@onready var status_info_label: Label = %StatusInfoLabel
@onready var telemetry_label: Label = %TelemetryLabel
@onready var crosshair_overlay: Control = %CrosshairOverlay
@onready var filter_rect: ColorRect = %FilterColorRect

# Controlli
@onready var zoom_in_btn: Button = %ZoomInBtn
@onready var zoom_out_btn: Button = %ZoomOutBtn
@onready var zoom_reset_btn: Button = %ZoomResetBtn
@onready var btn_headlights: Button = %BtnHeadlights
@onready var filter_cycle_btn: Button = %FilterCycleBtn
@onready var grid_toggle_btn: Button = %GridToggleBtn

const THERMAL_SHADER: Shader = preload("res://Applications/Cams/CameraFeed/Shaders/thermal.gdshader")
const LIDAR_SHADER: Shader = preload("res://Applications/Cams/CameraFeed/Shaders/lidar.gdshader")

var _thermal_mat: ShaderMaterial = null
var _lidar_mat: ShaderMaterial = null

var camera_id: String = "front"
var camera_metadata: CameraMetadata = null

var default_fov: float = 75.0
var current_fov: float = 75.0
var min_fov: float = 30.0
var max_fov: float = 100.0
var zoom_step: float = 10.0

var night_vision_intensity: float = 0.18
var tactical_hud_contrast: float = 0.18
var thermal_intensity: float = 0.22
var signal_boost: float = 1.0
var noise_reduction: float = 1.0
var overclock_gain: float = 1.0

var _time_passed: float = 0.0
var _filter_mode: int = 0 # 0 = Normal, 1 = Thermal, 2 = Lidar

func _ready() -> void:
	super._ready()
	
	# Assicura world_3d condiviso
	_setup_viewport_world()
	_connect_hud_controls()
	_update_hud_display()

## Applica i parametri runtime caricati dal file .dat (APP_ARCHITECTURE_STANDARD.md)
func apply_optics_config(config: Dictionary) -> void:
	if config.has("default_fov"):
		default_fov = float(config["default_fov"])
	if config.has("min_fov"):
		min_fov = float(config["min_fov"])
	if config.has("max_fov"):
		max_fov = float(config["max_fov"])
	if config.has("zoom_step"):
		zoom_step = float(config["zoom_step"])
	if config.has("night_vision_intensity"):
		night_vision_intensity = float(config["night_vision_intensity"])
	if config.has("tactical_hud_contrast"):
		tactical_hud_contrast = float(config["tactical_hud_contrast"])
	if config.has("thermal_intensity"):
		thermal_intensity = float(config["thermal_intensity"])
	if config.has("signal_boost"):
		signal_boost = float(config["signal_boost"])
	if config.has("noise_reduction"):
		noise_reduction = float(config["noise_reduction"])
	if config.has("overclock_gain"):
		overclock_gain = float(config["overclock_gain"])
	
	current_fov = clampf(current_fov, min_fov, max_fov)
	if camera_3d:
		camera_3d.fov = current_fov
	
	_apply_filter_mode()
	_update_telemetry(0.0)

func setup_camera(p_cam_id: String, p_info: CameraMetadata) -> void:
	camera_id = p_cam_id
	camera_metadata = p_info
	
	title_text = "%s - Feed Esterno" % [p_info.code if p_info else p_cam_id.to_upper()]
	var title_lbl: Node = get_node_or_null("Top Bar/Title Text")
	if title_lbl:
		title_lbl.text = "[center]" + title_text
	
	_setup_viewport_world()
	_update_hud_display()

func _setup_viewport_world() -> void:
	if not is_inside_tree():
		return
	
	if SpaceWorldManager:
		feed_viewport.world_3d = SpaceWorldManager.get_world_3d()
	
	feed_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	feed_viewport.handle_input_locally = false
	feed_viewport.own_world_3d = false
	
	camera_3d.current = true
	camera_3d.fov = current_fov

func _connect_hud_controls() -> void:
	if zoom_in_btn:
		zoom_in_btn.pressed.connect(_on_zoom_in_pressed)
	if zoom_out_btn:
		zoom_out_btn.pressed.connect(_on_zoom_out_pressed)
	if zoom_reset_btn:
		zoom_reset_btn.pressed.connect(_on_zoom_reset_pressed)
	if btn_headlights:
		btn_headlights.pressed.connect(_on_headlights_toggled)
	if filter_cycle_btn:
		filter_cycle_btn.pressed.connect(_on_filter_cycle_pressed)
	if grid_toggle_btn:
		grid_toggle_btn.pressed.connect(_on_grid_toggle_pressed)
	
	if SpaceWorldManager and not SpaceWorldManager.camera_headlight_toggled.is_connected(_on_global_headlight_changed):
		SpaceWorldManager.camera_headlight_toggled.connect(_on_global_headlight_changed)

func _process(delta: float) -> void:
	super._process(delta)
	_time_passed += delta
	
	# Sincronizza trasformazione telecamera con l'astronave
	if SpaceWorldManager:
		var target_trans: Transform3D = SpaceWorldManager.get_camera_transform(camera_id)
		camera_3d.global_transform = target_trans
	
	# Aggiorna telemetria HUD
	_update_telemetry(delta)

func _update_hud_display() -> void:
	if cam_code_label:
		var code_str: String = camera_metadata.code if camera_metadata else "CAM-??"
		var dir_str: String = camera_metadata.direction if camera_metadata else "N/D"
		cam_code_label.text = "● %s  [%s]" % [code_str, dir_str]
	
	_apply_filter_mode()
	_update_headlights_btn_state()

func _update_telemetry(_delta: float) -> void:
	if telemetry_label:
		var rot := camera_3d.global_rotation_degrees
		var facing_str := "Y: %+.1f°  P: %+.1f°  R: %+.1f°" % [rot.y, rot.x, rot.z]
		var gain_str := " [OC x%.1f]" % overclock_gain if overclock_gain != 1.0 else ""
		telemetry_label.text = "ORIENTAMENTO: %s | FOV: %.1f°%s" % [facing_str, camera_3d.fov, gain_str]
	
	if status_info_label:
		var fps := Engine.get_frames_per_second()
		var base_sig := 98.5 * signal_boost
		var noise_var := (sin(_time_passed * 2.0) * 1.2) / maxf(noise_reduction, 0.1)
		var signal_strength := clampf(base_sig + noise_var, 0.0, 100.0)
		status_info_label.text = "LIVE • %d FPS • SEGNALE %.1f%%" % [fps, signal_strength]
	
	# Effetto blink sul badge LIVE
	if live_badge:
		live_badge.modulate.a = 0.6 + sin(_time_passed * 4.0) * 0.4

func _on_zoom_in_pressed() -> void:
	current_fov = clampf(current_fov - zoom_step, min_fov, max_fov)
	camera_3d.fov = current_fov

func _on_zoom_out_pressed() -> void:
	current_fov = clampf(current_fov + zoom_step, min_fov, max_fov)
	camera_3d.fov = current_fov

func _on_zoom_reset_pressed() -> void:
	current_fov = clampf(default_fov, min_fov, max_fov)
	camera_3d.fov = current_fov

func _on_filter_cycle_pressed() -> void:
	_filter_mode = (_filter_mode + 1) % 3
	_apply_filter_mode()

func _apply_filter_mode() -> void:
	if not filter_rect:
		return
	
	match _filter_mode:
		0: # Ottica Normale
			filter_rect.visible = false
			filter_rect.material = null
			if filter_cycle_btn:
				filter_cycle_btn.text = "Filtro: Normale"
		1: # Termico (Ironbow / FLIR)
			filter_rect.visible = true
			if _thermal_mat == null:
				_thermal_mat = ShaderMaterial.new()
				_thermal_mat.shader = THERMAL_SHADER
			_thermal_mat.set_shader_parameter("thermal_intensity", clampf(thermal_intensity * 4.0, 0.5, 3.0) if thermal_intensity > 0.0 else 1.0)
			filter_rect.material = _thermal_mat
			if filter_cycle_btn:
				filter_cycle_btn.text = "Filtro: Termico"
		2: # Lidar (Scansione Raycast / Matrice Punti & Profondità)
			filter_rect.visible = true
			if _lidar_mat == null:
				_lidar_mat = ShaderMaterial.new()
				_lidar_mat.shader = LIDAR_SHADER
			filter_rect.material = _lidar_mat
			if filter_cycle_btn:
				filter_cycle_btn.text = "Filtro: Lidar"

func _on_headlights_toggled() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_method("toggle_camera_headlight"):
		SpaceWorldManager.toggle_camera_headlight(camera_id)
	_update_headlights_btn_state()

func _update_headlights_btn_state() -> void:
	if not btn_headlights:
		return
	var is_on := false
	if SpaceWorldManager and SpaceWorldManager.has_method("is_camera_headlight_on"):
		is_on = SpaceWorldManager.is_camera_headlight_on(camera_id)
	btn_headlights.text = "Fari: ON" if is_on else "Fari: OFF"

func _on_global_headlight_changed(cam_id: String, _enabled: bool) -> void:
	if cam_id == camera_id:
		_update_headlights_btn_state()

func _on_grid_toggle_pressed() -> void:
	if crosshair_overlay:
		crosshair_overlay.visible = not crosshair_overlay.visible
		if grid_toggle_btn:
			grid_toggle_btn.text = "Reticolo: ON" if crosshair_overlay.visible else "Reticolo: OFF"
