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
@onready var lidar_overlay: Control = %LidarOverlay
@onready var hyperdrive_loss_overlay: Control = %HyperdriveLossOverlay
@onready var hyperdrive_loss_label: Label = %HyperdriveLossLabel
@onready var hyperdrive_sync_label: Label = %HyperdriveSyncLabel

# Controlli
@onready var zoom_in_btn: Button = %ZoomInBtn
@onready var zoom_out_btn: Button = %ZoomOutBtn
@onready var zoom_reset_btn: Button = %ZoomResetBtn
@onready var btn_headlights: Button = %BtnHeadlights
@onready var filter_cycle_btn: Button = %FilterCycleBtn
@onready var grid_toggle_btn: Button = %GridToggleBtn

var is_in_hyperdrive_transition: bool = false
var _hyperdrive_progress: Dictionary = {"loaded": 1, "total": 1}

const THERMAL_SHADER: Shader = preload("res://Applications/Cams/CameraFeed/Shaders/thermal.gdshader")

const LAYOUT_SAVE_PATH: String = "user://camera_feed_layout.json"

static var _cached_layouts: Dictionary = {}
static var _layouts_loaded: bool = false

var _thermal_mat: ShaderMaterial = null

const LIDAR_COLS_SPACING: float = 10.0
const LIDAR_ROWS_SPACING: float = 10.0

const LIDAR_SCAN_INTERVAL: float = 0.04 # 25 Hz
const LIDAR_MAX_RANGE: float = 200.0
const LIDAR_MIN_RANGE: float = 15.0

var _lidar_timer: float = 0.0
var _lidar_points: Array[Dictionary] = []
var _lidar_closest_distance: float = -1.0

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
	add_to_group("camera_feed_window")

	# Assicura world_3d condiviso
	_setup_viewport_world()
	_connect_hud_controls()
	_update_hud_display()

	if SpaceWorldManager and SpaceWorldManager.has_method("is_hyperdrive_transit_active") and SpaceWorldManager.is_hyperdrive_transit_active():
		set_hyperdrive_transition(true, SpaceWorldManager.get_hyperdrive_loading_progress())

## Chiude la finestra del feed telecamera
func close_window() -> void:
	save_window_layout()
	_on_close_button_pressed()

func _exit_tree() -> void:
	save_window_layout()
	_lidar_points.clear()
	_lidar_timer = 0.0
	_lidar_closest_distance = -1.0
	if SpaceWorldManager and SpaceWorldManager.camera_headlight_toggled.is_connected(_on_global_headlight_changed):
		SpaceWorldManager.camera_headlight_toggled.disconnect(_on_global_headlight_changed)
	super._exit_tree()

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
	if SpaceWorldManager:
		var target_trans: Transform3D = SpaceWorldManager.get_camera_transform(camera_id)
		camera_3d.global_transform = target_trans
	_update_hud_display()
	restore_window_layout()

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
	if lidar_overlay and not lidar_overlay.draw.is_connected(_on_lidar_overlay_draw):
		lidar_overlay.draw.connect(_on_lidar_overlay_draw)

	var resize_spot: Control = get_node_or_null("Resize Drag Spot")
	if resize_spot and not resize_spot.gui_input.is_connected(_on_resize_spot_gui_input):
		resize_spot.gui_input.connect(_on_resize_spot_gui_input)

	if SpaceWorldManager and not SpaceWorldManager.camera_headlight_toggled.is_connected(_on_global_headlight_changed):
		SpaceWorldManager.camera_headlight_toggled.connect(_on_global_headlight_changed)

func _process(delta: float) -> void:
	super._process(delta)
	_time_passed += delta

	# Sincronizza trasformazione telecamera con l'astronave se non in warp totale
	if SpaceWorldManager:
		var target_trans: Transform3D = SpaceWorldManager.get_camera_transform(camera_id)
		camera_3d.global_transform = target_trans

	# Scansione Lidar a frequenza fissa (25 Hz) solo quando non siamo in transito Hyperdrive
	if _filter_mode == 2 and not is_in_hyperdrive_transition:
		_lidar_timer += delta
		if _lidar_timer >= LIDAR_SCAN_INTERVAL:
			_lidar_timer = fmod(_lidar_timer, LIDAR_SCAN_INTERVAL)
			_update_lidar_scan()

	# Aggiorna telemetria HUD
	_update_telemetry(delta)

## Attiva o disattiva lo stato visivo di transizione Hyperdrive (perdita segnale telecamere)
func set_hyperdrive_transition(active: bool, progress_dict: Dictionary = {}) -> void:
	is_in_hyperdrive_transition = active
	if not progress_dict.is_empty():
		_hyperdrive_progress = progress_dict
	
	if hyperdrive_loss_overlay:
		hyperdrive_loss_overlay.visible = active
		
	if crosshair_overlay:
		crosshair_overlay.visible = not active
		
	_set_hud_buttons_disabled(active)
	
	if active:
		if live_badge:
			live_badge.text = "● NO SIGNAL"
			live_badge.modulate = Color(1.0, 0.45, 0.2)
		update_hyperdrive_progress(_hyperdrive_progress.get("loaded", 1), _hyperdrive_progress.get("total", 1))
	else:
		if live_badge:
			live_badge.text = "● REC LIVE"
			live_badge.modulate = Color(1.0, 0.3, 0.3)
		_update_hud_display()

## Aggiorna il testo dell'overlay con il numero di giocatori sincronizzati
func update_hyperdrive_progress(loaded: int, total: int) -> void:
	_hyperdrive_progress = {"loaded": loaded, "total": total}
	if not is_in_hyperdrive_transition:
		return
	if hyperdrive_sync_label:
		hyperdrive_sync_label.text = "SINCRONIZZAZIONE EQUIPAGGIO: %d / %d CARICATI" % [loaded, total]
	if status_info_label:
		status_info_label.text = "IPERSPAZIO • EQUIPAGGIO %d/%d • ATTESA ZONA..." % [loaded, total]

func _set_hud_buttons_disabled(p_disabled: bool) -> void:
	if zoom_in_btn:
		zoom_in_btn.disabled = p_disabled
	if zoom_out_btn:
		zoom_out_btn.disabled = p_disabled
	if zoom_reset_btn:
		zoom_reset_btn.disabled = p_disabled
	if btn_headlights:
		btn_headlights.disabled = p_disabled
	if filter_cycle_btn:
		filter_cycle_btn.disabled = p_disabled
	if grid_toggle_btn:
		grid_toggle_btn.disabled = p_disabled

func _update_hud_display() -> void:
	if cam_code_label:
		var code_str: String = camera_metadata.code if camera_metadata else "CAM-??"
		var dir_str: String = camera_metadata.direction if camera_metadata else "N/D"
		cam_code_label.text = "● %s  [%s]" % [code_str, dir_str]

	_apply_filter_mode()
	_update_headlights_btn_state()

func _update_telemetry(_delta: float) -> void:
	if is_in_hyperdrive_transition:
		if telemetry_label:
			telemetry_label.text = "DISTORSIONE TACHIONICA • SEGNALE PERSO"
		if status_info_label:
			status_info_label.text = "OFFLINE • SALTO HYPERDRIVE • %d/%d PRONTI" % [_hyperdrive_progress.get("loaded", 1), _hyperdrive_progress.get("total", 1)]
		if live_badge:
			live_badge.modulate.a = 0.4 + sin(_time_passed * 6.0) * 0.5
		return

	if telemetry_label:
		if _filter_mode == 2:
			if _lidar_points.size() > 0:
				telemetry_label.text = "LIDAR: %d PKT • MIN: %.1fm" % [_lidar_points.size(), _lidar_closest_distance]
			else:
				telemetry_label.text = "LIDAR: 0 PKT • NESSUN CONTATTO"
		else:
			var gain_str := " [OC x%.1f]" % overclock_gain if overclock_gain != 1.0 else ""
			telemetry_label.text = "FOV: %.1f°%s" % [camera_3d.fov, gain_str]

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

	var feed_tex: ViewportTexture = feed_viewport.get_texture() if feed_viewport else null

	match _filter_mode:
		0: # Ottica Normale
			filter_rect.visible = false
			filter_rect.material = null
			if lidar_overlay:
				lidar_overlay.visible = false
			_lidar_points.clear()
			_lidar_closest_distance = -1.0
			_lidar_timer = 0.0
			if lidar_overlay:
				lidar_overlay.queue_redraw()
			if filter_cycle_btn:
				filter_cycle_btn.text = "Filtro: Normale"
		1: # Termico (Ironbow / FLIR)
			filter_rect.visible = true
			if lidar_overlay:
				lidar_overlay.visible = false
			_lidar_points.clear()
			_lidar_closest_distance = -1.0
			_lidar_timer = 0.0
			if lidar_overlay:
				lidar_overlay.queue_redraw()
			if _thermal_mat == null:
				_thermal_mat = ShaderMaterial.new()
				_thermal_mat.shader = THERMAL_SHADER
			if feed_tex:
				_thermal_mat.set_shader_parameter("feed_texture", feed_tex)
			_thermal_mat.set_shader_parameter("thermal_intensity", clampf(thermal_intensity * 4.0, 0.5, 3.0) if thermal_intensity > 0.0 else 1.0)
			filter_rect.material = _thermal_mat
			if filter_cycle_btn:
				filter_cycle_btn.text = "Filtro: Termico"
		2: # Lidar (Scansione Raycast / Matrice Punti & Profondità)
			filter_rect.visible = false
			filter_rect.material = null
			if lidar_overlay:
				lidar_overlay.visible = true
			_lidar_timer = 0.0
			_update_lidar_scan()
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
	btn_headlights.text = "💡"
	btn_headlights.modulate = Color(1.0, 0.9, 0.3) if is_on else Color(0.6, 0.6, 0.6)
	btn_headlights.tooltip_text = "Fari: ON" if is_on else "Fari: OFF"

func _on_global_headlight_changed(cam_id: String, _enabled: bool) -> void:
	if cam_id == camera_id:
		_update_headlights_btn_state()

func _on_grid_toggle_pressed() -> void:
	if crosshair_overlay:
		crosshair_overlay.visible = not crosshair_overlay.visible
		if grid_toggle_btn:
			grid_toggle_btn.text = "Reticolo: ON" if crosshair_overlay.visible else "Reticolo: OFF"

## Esegue il campionamento a matrice dei raycast nello spazio 3D circostante
func _update_lidar_scan() -> void:
	if not is_inside_tree() or camera_3d == null or feed_viewport == null:
		return

	if SpaceWorldManager:
		var target_trans: Transform3D = SpaceWorldManager.get_camera_transform(camera_id)
		camera_3d.global_transform = target_trans

	var world: World3D = camera_3d.get_world_3d() if camera_3d else (feed_viewport.world_3d if feed_viewport else null)
	if world == null:
		return

	var space_state := world.direct_space_state
	if space_state == null:
		return

	var vp_size: Vector2 = Vector2(feed_viewport.size)
	if vp_size.x <= 0 or vp_size.y <= 0:
		return

	if LIDAR_COLS_SPACING <= 0.0 or LIDAR_ROWS_SPACING <= 0.0:
		return

	var cols: int = int(vp_size.x / LIDAR_COLS_SPACING)
	var rows: int = int(vp_size.y / LIDAR_ROWS_SPACING)
	if cols <= 0 or rows <= 0:
		return

	var offset_x: float = (vp_size.x - float(cols) * LIDAR_COLS_SPACING) * 0.5
	var offset_y: float = (vp_size.y - float(rows) * LIDAR_ROWS_SPACING) * 0.5

	var excludes: Array[RID] = []
	if SpaceWorldManager:
		var ship := SpaceWorldManager.get_spaceship()
		if ship and is_instance_valid(ship):
			excludes.append(ship.get_rid())

	var new_points: Array[Dictionary] = []
	var min_dist: float = 999999.0
	var cam_pos: Vector3 = camera_3d.global_position

	for ix in range(cols):
		var sx: float = offset_x + (float(ix) + 0.5) * LIDAR_COLS_SPACING
		for iy in range(rows):
			var sy: float = offset_y + (float(iy) + 0.5) * LIDAR_ROWS_SPACING
			var screen_pt := Vector2(sx, sy)
			var ray_origin := camera_3d.project_ray_origin(screen_pt)
			var ray_normal := camera_3d.project_ray_normal(screen_pt)
			var ray_end := ray_origin + ray_normal * LIDAR_MAX_RANGE

			var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
			query.collide_with_areas = false
			query.collide_with_bodies = true
			query.exclude = excludes

			var hit := space_state.intersect_ray(query)
			if not hit.is_empty():
				var hit_pos: Vector3 = hit.position
				var dist: float = cam_pos.distance_to(hit_pos)
				if dist < min_dist:
					min_dist = dist
				var pt_color := _get_lidar_depth_color(dist)
				new_points.append({"pos": screen_pt, "dist": dist, "color": pt_color})

	_lidar_points = new_points
	_lidar_closest_distance = min_dist if min_dist < 999999.0 else -1.0
	if lidar_overlay:
		lidar_overlay.queue_redraw()

## Disegna i punti di impatto Lidar sul nodo overlay 2D
func _on_lidar_overlay_draw() -> void:
	if _filter_mode != 2 or lidar_overlay == null:
		return
	for pt in _lidar_points:
		var pos: Vector2 = pt.pos
		var col: Color = pt.color
		lidar_overlay.draw_circle(pos, 1, col)

## Mappatura termocromatica della profondità per i punti Lidar:
## Vicino (<= 15m) -> Rosso, Distanza media (30-80m) -> Giallo/Verde, Lontano (>= 150m) -> Blu
func _get_lidar_depth_color(dist: float) -> Color:
	var clamped := clampf(dist, 15.0, 150.0)
	var t := (clamped - 15.0) / (150.0 - 15.0)
	if t < 0.25:
		var seg_t := t / 0.25
		return Color(1.0, 0.15, 0.1, 0.95).lerp(Color(1.0, 0.85, 0.1, 0.9), seg_t)
	elif t < 0.5:
		var seg_t := (t - 0.25) / 0.25
		return Color(1.0, 0.85, 0.1, 0.9).lerp(Color(0.2, 1.0, 0.4, 0.85), seg_t)
	elif t < 0.75:
		var seg_t := (t - 0.5) / 0.25
		return Color(0.2, 1.0, 0.4, 0.85).lerp(Color(0.1, 0.85, 1.0, 0.8), seg_t)
	else:
		var seg_t := (t - 0.75) / 0.25
		return Color(0.1, 0.85, 1.0, 0.8).lerp(Color(0.15, 0.35, 1.0, 0.75), seg_t)

# ==============================================================================
# PERSISTENZA LAYOUT FINESTRA (POSIZIONE E DIMENSIONE TRA SESSIONI)
# ==============================================================================

static func _load_all_layouts_from_file() -> void:
	_cached_layouts.clear()
	_layouts_loaded = true
	if not FileAccess.file_exists(LAYOUT_SAVE_PATH):
		return
	var file := FileAccess.open(LAYOUT_SAVE_PATH, FileAccess.READ)
	if file:
		var content := file.get_as_text()
		file.close()
		var json := JSON.new()
		var parse_result := json.parse(content)
		if parse_result == OK and json.data is Dictionary:
			_cached_layouts = json.data
		else:
			_cached_layouts = {}

static func save_camera_layout(cam_id: String, win_pos: Vector2, win_size: Vector2) -> void:
	if cam_id.is_empty():
		return
	if not _layouts_loaded:
		_load_all_layouts_from_file()
	_cached_layouts[cam_id] = {
		"x": win_pos.x,
		"y": win_pos.y,
		"width": win_size.x,
		"height": win_size.y
	}
	var file := FileAccess.open(LAYOUT_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_cached_layouts, "\t"))
		file.close()

static func get_saved_camera_layout(cam_id: String) -> Dictionary:
	if cam_id.is_empty():
		return {}
	if not _layouts_loaded:
		_load_all_layouts_from_file()
	return _cached_layouts.get(cam_id, {})

static func has_saved_camera_layout(cam_id: String) -> bool:
	return not get_saved_camera_layout(cam_id).is_empty()

static func clear_saved_camera_layouts() -> void:
	_cached_layouts.clear()
	_layouts_loaded = true
	if FileAccess.file_exists(LAYOUT_SAVE_PATH):
		DirAccess.remove_absolute(LAYOUT_SAVE_PATH)

static func reload_saved_layouts() -> void:
	_layouts_loaded = false
	_load_all_layouts_from_file()

func has_saved_layout() -> bool:
	return has_saved_camera_layout(camera_id)

func save_window_layout() -> void:
	if camera_id.is_empty():
		return
	if is_minimized:
		return
	var save_pos: Vector2 = old_unmaximized_position if is_maximized else position
	var save_sz: Vector2 = old_unmaximized_size if is_maximized else size

	if save_sz.x < 100.0 or save_sz.y < 100.0:
		return
	if not is_finite(save_pos.x) or not is_finite(save_pos.y) or not is_finite(save_sz.x) or not is_finite(save_sz.y):
		return
	save_camera_layout(camera_id, save_pos, save_sz)

func restore_window_layout() -> bool:
	if camera_id.is_empty():
		return false
	var layout := get_saved_camera_layout(camera_id)
	if layout.is_empty():
		return false
	var w: float = float(layout.get("width", 0.0))
	var h: float = float(layout.get("height", 0.0))
	var px: float = float(layout.get("x", 0.0))
	var py: float = float(layout.get("y", 0.0))
	if w < 100.0 or h < 100.0 or not is_finite(w) or not is_finite(h) or not is_finite(px) or not is_finite(py):
		return false
	size = Vector2(w, h)
	position = Vector2(px, py)
	if is_inside_tree() and get_viewport_rect().size.x > 100.0 and get_viewport_rect().size.y > 100.0:
		clamp_window_inside_viewport()
	return true

func _on_top_bar_gui_input(event: InputEvent) -> void:
	super._on_top_bar_gui_input(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.is_pressed():
		save_window_layout()

func _on_resize_spot_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.is_pressed():
		save_window_layout()
