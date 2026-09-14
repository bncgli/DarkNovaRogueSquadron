@tool
class_name RadarDisplay
extends Control

## Radar Display 2D/3D polare e cartesiano per l'applicazione Sensors (1 km standard, 2 km ping).
## Supporta sweep passivo, ombreggiamento Line of Sight da ostacoli, feed radar Probe e ping energetico.

signal entity_selected(entity_data: Dictionary)
signal entity_locked(entity_data: Dictionary)
signal waypoint_placed(world_pos: Vector3)
signal range_changed(new_range: float)

enum DisplayMode {
	ORBIT_3D = 0,
	TOP_DOWN = 1,
	FRONTAL_ELEVATION = 2,
	POLAR_2D = 0,
	CARTESIAN_GRID = 1,
	ELEVATION_3D = 2
}

const SPHERE_RADIUS: float = 5.0

# --- RIFERIMENTI 3D VIEWPORT ---
@onready var sub_viewport_container: SubViewportContainer = get_node_or_null("%SubViewportContainer")
@onready var sub_viewport: SubViewport = get_node_or_null("%SubViewport")
@onready var radar_3d_world: Node3D = get_node_or_null("%Radar3DWorld")
@onready var orbit_pivot: Node3D = get_node_or_null("%OrbitPivot")
@onready var pitch_pivot: Node3D = get_node_or_null("%PitchPivot")
@onready var camera_3d: Camera3D = get_node_or_null("%Camera3D")
@onready var sphere_content: Node3D = get_node_or_null("%SphereContent")
@onready var hud_overlay: Control = get_node_or_null("%HUDOverlay")

# Nodi 3D generati all'interno di SphereContent
var cyan_sphere_mesh: MeshInstance3D = null
var cyan_sphere_inner: MeshInstance3D = null
var equatorial_grid_mesh: MeshInstance3D = null
var center_ship: Node3D = null
var blips_container: Node3D = null
var stems_mesh_inst: MeshInstance3D = null
var stems_material: StandardMaterial3D = null
var sweep_pivot_3d: Node3D = null
var sweep_fan_mesh: MeshInstance3D = null
var ping_wave_mesh: MeshInstance3D = null

# --- STATO E PARAMETRI RUNTIME ---
var entities: Array[Dictionary] = []
var selected_entity_id: String = ""
var locked_entity_id: String = ""
var max_range: float = 1000.0 # Metri (default 1 km standard)
var current_mode: DisplayMode = DisplayMode.ORBIT_3D:
	set(val):
		current_mode = val
		set_display_mode(val)
var filter_category: String = "ALL"

# Parametri Controlli Orbita Mouse e Telecamera 3D
const MIN_ZOOM: float = 7.0
const MAX_ZOOM: float = 24.0
const ZOOM_STEP: float = 1.0
const DRAG_THRESHOLD: float = 5.0 # pixel di soglia prima di attivare rotazione

const MIN_RADAR_RANGE: float = 200.0
const MAX_RADAR_RANGE: float = 2000.0
const RADAR_RANGE_PRESETS: Array[float] = [200.0, 500.0, 1000.0, 2000.0]

var orbit_yaw: float = 25.0 # gradi
var orbit_pitch: float = -25.0 # gradi
var camera_zoom: float = 13.5
var _is_dragging_orbit: bool = false
var _mouse_is_down: bool = false
var _mouse_press_pos: Vector2 = Vector2.ZERO
var _orbit_sensitivity: float = 0.35 # gradi per pixel

# Feed sonda telemetrica (Probe)
var probe_data: Dictionary = {}

# Parametri Sweep e Ping
var sweep_angle: float = 0.0
var sweep_frequency_hz: float = 12.0
var is_sweep_active: bool = true
var ping_active: bool = false
var ping_radius_progress: float = 0.0
var ping_max_radius: float = 2000.0 # 2 km
var ping_speed: float = 1000.0 # m/s

# Parametri Tuning e Danni
var noise_filter: float = 0.92
var spectrum_sensitivity: float = 1.0
var iff_auto_tag: bool = true
var stealth_threshold: float = 0.35
var has_radar_ghosts: bool = false
var is_powered: bool = true

# Ghost Contacts generati se danneggiato
var _ghost_timer: float = 0.0
var _ghosts: Array[Dictionary] = []

func _ready() -> void:
	custom_minimum_size = Vector2(380, 380)
	_setup_3d_scene()
	if hud_overlay and not hud_overlay.draw.is_connected(_on_hud_draw):
		hud_overlay.draw.connect(_on_hud_draw)

func _setup_3d_scene() -> void:
	if not is_instance_valid(sphere_content):
		return
	
	if is_instance_valid(orbit_pivot):
		orbit_pivot.rotation_degrees.y = 25.0
	if is_instance_valid(pitch_pivot):
		pitch_pivot.rotation_degrees.x = -25.0
	if is_instance_valid(camera_3d):
		camera_3d.position = Vector3(0.0, 0.0, 13.5)
	
	for child in sphere_content.get_children():
		child.queue_free()
	
	_build_holographic_sphere()
	_build_equatorial_grid()
	_build_center_ship()
	_build_sweep_and_ping_effects()
	_build_blips_container()

func _build_holographic_sphere() -> void:
	var sphere_node := Node3D.new()
	sphere_node.name = "CyanSphere"
	sphere_content.add_child(sphere_node)
	
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(0.1, 0.85, 1.0, 0.45)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var equator_mat := StandardMaterial3D.new()
	equator_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	equator_mat.albedo_color = Color(0.2, 0.95, 1.0, 0.85)
	equator_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_material(line_mat)

	var segments: int = 48
	var lats: Array[float] = [-75.0, -60.0, -45.0, -30.0, -15.0, 15.0, 30.0, 45.0, 60.0, 75.0]
	for lat_deg in lats:
		var phi: float = deg_to_rad(lat_deg)
		var y: float = sin(phi) * SPHERE_RADIUS
		var r: float = cos(phi) * SPHERE_RADIUS
		for i in range(segments):
			var a1 := float(i) * TAU / float(segments)
			var a2 := float(i + 1) * TAU / float(segments)
			st.add_vertex(Vector3(cos(a1) * r, y, sin(a1) * r))
			st.add_vertex(Vector3(cos(a2) * r, y, sin(a2) * r))

	var lons: Array[float] = [0.0, 30.0, 60.0, 90.0, 120.0, 150.0]
	for lon_deg in lons:
		var theta: float = deg_to_rad(lon_deg)
		var cos_t: float = cos(theta)
		var sin_t: float = sin(theta)
		for i in range(segments):
			var a1 := float(i) * TAU / float(segments)
			var a2 := float(i + 1) * TAU / float(segments)
			var p1 := Vector3(cos(a1) * SPHERE_RADIUS * sin_t, sin(a1) * SPHERE_RADIUS, cos(a1) * SPHERE_RADIUS * cos_t)
			var p2 := Vector3(cos(a2) * SPHERE_RADIUS * sin_t, sin(a2) * SPHERE_RADIUS, cos(a2) * SPHERE_RADIUS * cos_t)
			st.add_vertex(p1)
			st.add_vertex(p2)

	var lines_mesh := st.commit()
	var lines_inst := MeshInstance3D.new()
	lines_inst.name = "WireframeLines"
	lines_inst.mesh = lines_mesh
	sphere_node.add_child(lines_inst)

	var st_eq := SurfaceTool.new()
	st_eq.begin(Mesh.PRIMITIVE_LINES)
	st_eq.set_material(equator_mat)
	for i in range(segments):
		var a1 := float(i) * TAU / float(segments)
		var a2 := float(i + 1) * TAU / float(segments)
		st_eq.add_vertex(Vector3(cos(a1) * SPHERE_RADIUS, 0.0, sin(a1) * SPHERE_RADIUS))
		st_eq.add_vertex(Vector3(cos(a2) * SPHERE_RADIUS, 0.0, sin(a2) * SPHERE_RADIUS))
	var eq_mesh := st_eq.commit()
	var eq_inst := MeshInstance3D.new()
	eq_inst.name = "EquatorRing"
	eq_inst.mesh = eq_mesh
	sphere_node.add_child(eq_inst)

	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = SPHERE_RADIUS * 0.995
	sphere_mesh.height = SPHERE_RADIUS * 1.99
	sphere_mesh.radial_segments = 32
	sphere_mesh.rings = 16

	var inner_mat := StandardMaterial3D.new()
	inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner_mat.albedo_color = Color(0.02, 0.15, 0.22, 0.10)
	inner_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	inner_mat.roughness = 0.2
	inner_mat.metallic = 0.1

	cyan_sphere_inner = MeshInstance3D.new()
	cyan_sphere_inner.name = "HoloVolume"
	cyan_sphere_inner.mesh = sphere_mesh
	cyan_sphere_inner.material_override = inner_mat
	sphere_node.add_child(cyan_sphere_inner)
	
	cyan_sphere_mesh = lines_inst

func _build_equatorial_grid() -> void:
	var grid_node := Node3D.new()
	grid_node.name = "EquatorialGrid"
	sphere_content.add_child(grid_node)
	
	var grid_mat := StandardMaterial3D.new()
	grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_mat.albedo_color = Color(0.1, 0.85, 1.0, 0.35)
	grid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_material(grid_mat)

	var segments: int = 48
	var fractions: Array[float] = [0.25, 0.5, 0.75]
	for frac in fractions:
		var r: float = SPHERE_RADIUS * frac
		for i in range(segments):
			var a1 := float(i) * TAU / float(segments)
			var a2 := float(i + 1) * TAU / float(segments)
			st.add_vertex(Vector3(cos(a1) * r, 0.0, sin(a1) * r))
			st.add_vertex(Vector3(cos(a2) * r, 0.0, sin(a2) * r))

	st.add_vertex(Vector3(-SPHERE_RADIUS, 0.0, 0.0))
	st.add_vertex(Vector3(SPHERE_RADIUS, 0.0, 0.0))
	
	st.add_vertex(Vector3(0.0, 0.0, -SPHERE_RADIUS))
	st.add_vertex(Vector3(0.0, 0.0, SPHERE_RADIUS))
	
	st.add_vertex(Vector3(0.0, -SPHERE_RADIUS, 0.0))
	st.add_vertex(Vector3(0.0, SPHERE_RADIUS, 0.0))

	st.add_vertex(Vector3(-0.3, 0.0, -SPHERE_RADIUS + 0.4))
	st.add_vertex(Vector3(0.0, 0.0, -SPHERE_RADIUS))
	st.add_vertex(Vector3(0.3, 0.0, -SPHERE_RADIUS + 0.4))
	st.add_vertex(Vector3(0.0, 0.0, -SPHERE_RADIUS))

	var grid_mesh := st.commit()
	equatorial_grid_mesh = MeshInstance3D.new()
	equatorial_grid_mesh.name = "GridLines"
	equatorial_grid_mesh.mesh = grid_mesh
	grid_node.add_child(equatorial_grid_mesh)

func _build_center_ship() -> void:
	center_ship = Node3D.new()
	center_ship.name = "CenterShip"
	sphere_content.add_child(center_ship)

	# Freccia tattica tridimensionale proporzionata che indica la nave e la sua prua (-Z)
	var arrow_mat := StandardMaterial3D.new()
	arrow_mat.albedo_color = Color(0.15, 0.9, 1.0, 0.9)
	arrow_mat.emission_enabled = true
	arrow_mat.emission = Color(0.18, 0.92, 1.0)
	arrow_mat.emission_energy_multiplier = 2.0
	arrow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	arrow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	var outline_mat := StandardMaterial3D.new()
	outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_mat.albedo_color = Color(0.8, 1.0, 1.0, 0.95)

	# Geometria solida della freccia (delta con spessore e cresta dorsale/ventrale)
	var tip := Vector3(0.0, 0.0, -0.42)
	var left_wing := Vector3(-0.20, 0.0, 0.22)
	var right_wing := Vector3(0.20, 0.0, 0.22)
	var rear_notch := Vector3(0.0, 0.0, 0.08)
	var top_ridge := Vector3(0.0, 0.038, -0.05)
	var bottom_ridge := Vector3(0.0, -0.038, -0.05)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(arrow_mat)

	# Faccia superiore (4 triangoli)
	st.add_vertex(tip)
	st.add_vertex(left_wing)
	st.add_vertex(top_ridge)

	st.add_vertex(tip)
	st.add_vertex(top_ridge)
	st.add_vertex(right_wing)

	st.add_vertex(left_wing)
	st.add_vertex(rear_notch)
	st.add_vertex(top_ridge)

	st.add_vertex(top_ridge)
	st.add_vertex(rear_notch)
	st.add_vertex(right_wing)

	# Faccia inferiore (4 triangoli)
	st.add_vertex(tip)
	st.add_vertex(bottom_ridge)
	st.add_vertex(left_wing)

	st.add_vertex(tip)
	st.add_vertex(right_wing)
	st.add_vertex(bottom_ridge)

	st.add_vertex(left_wing)
	st.add_vertex(bottom_ridge)
	st.add_vertex(rear_notch)

	st.add_vertex(right_wing)
	st.add_vertex(rear_notch)
	st.add_vertex(bottom_ridge)

	st.generate_normals()
	var arrow_mesh := st.commit()

	var arrow_body := MeshInstance3D.new()
	arrow_body.name = "ShipArrowBody"
	arrow_body.mesh = arrow_mesh
	center_ship.add_child(arrow_body)

	# Bordo luminoso wireframe per massima nitidezza a qualsiasi distanza/zoom
	var st_lines := SurfaceTool.new()
	st_lines.begin(Mesh.PRIMITIVE_LINES)
	st_lines.set_material(outline_mat)

	# Perimetro
	st_lines.add_vertex(tip)
	st_lines.add_vertex(left_wing)

	st_lines.add_vertex(left_wing)
	st_lines.add_vertex(rear_notch)

	st_lines.add_vertex(rear_notch)
	st_lines.add_vertex(right_wing)

	st_lines.add_vertex(right_wing)
	st_lines.add_vertex(tip)

	# Linee dorsali e ventrali
	st_lines.add_vertex(top_ridge)
	st_lines.add_vertex(tip)
	st_lines.add_vertex(top_ridge)
	st_lines.add_vertex(rear_notch)
	st_lines.add_vertex(bottom_ridge)
	st_lines.add_vertex(tip)
	st_lines.add_vertex(bottom_ridge)
	st_lines.add_vertex(rear_notch)

	var outline_mesh := st_lines.commit()
	var arrow_outline := MeshInstance3D.new()
	arrow_outline.name = "ShipArrowOutline"
	arrow_outline.mesh = outline_mesh
	center_ship.add_child(arrow_outline)

func _build_sweep_and_ping_effects() -> void:
	sweep_pivot_3d = Node3D.new()
	sweep_pivot_3d.name = "SweepPivot3D"
	sphere_content.add_child(sweep_pivot_3d)

	var sweep_st := SurfaceTool.new()
	sweep_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sweep_mat := StandardMaterial3D.new()
	sweep_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sweep_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sweep_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sweep_mat.albedo_color = Color(0.1, 0.9, 1.0, 0.15)
	sweep_st.set_material(sweep_mat)

	var arc_steps := 12
	var sweep_arc := deg_to_rad(35.0)
	for i in range(arc_steps):
		var a1 := float(i) * sweep_arc / float(arc_steps)
		var a2 := float(i + 1) * sweep_arc / float(arc_steps)
		sweep_st.add_vertex(Vector3.ZERO)
		sweep_st.add_vertex(Vector3(sin(a1) * SPHERE_RADIUS, 0.0, -cos(a1) * SPHERE_RADIUS))
		sweep_st.add_vertex(Vector3(sin(a2) * SPHERE_RADIUS, 0.0, -cos(a2) * SPHERE_RADIUS))

	sweep_fan_mesh = MeshInstance3D.new()
	sweep_fan_mesh.name = "SweepFan"
	sweep_fan_mesh.mesh = sweep_st.commit()
	sweep_pivot_3d.add_child(sweep_fan_mesh)

	ping_wave_mesh = MeshInstance3D.new()
	ping_wave_mesh.name = "PingWave3D"
	var ping_sph := SphereMesh.new()
	ping_sph.radius = 1.0
	ping_sph.height = 2.0
	ping_sph.radial_segments = 32
	ping_sph.rings = 16
	ping_wave_mesh.mesh = ping_sph
	var ping_mat := StandardMaterial3D.new()
	ping_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ping_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ping_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ping_mat.albedo_color = Color(0.2, 0.9, 1.0, 0.25)
	ping_wave_mesh.material_override = ping_mat
	ping_wave_mesh.visible = false
	sphere_content.add_child(ping_wave_mesh)

func _build_blips_container() -> void:
	blips_container = Node3D.new()
	blips_container.name = "BlipsContainer"
	sphere_content.add_child(blips_container)

	stems_mesh_inst = MeshInstance3D.new()
	stems_mesh_inst.name = "StemsAndBlips"
	blips_container.add_child(stems_mesh_inst)

	stems_material = StandardMaterial3D.new()
	stems_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stems_material.vertex_color_use_as_albedo = true
	stems_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stems_material.cull_mode = BaseMaterial3D.CULL_DISABLED

func _get_entity_rel_pos(e: Dictionary) -> Vector3:
	if e.has("local_rel_pos") and e["local_rel_pos"] is Vector3 and e["local_rel_pos"] != Vector3.ZERO:
		return e["local_rel_pos"]
	if e.has("rel_pos") and e["rel_pos"] is Vector3 and e["rel_pos"] != Vector3.ZERO:
		return e["rel_pos"]
	if e.has("bearing_deg") and e.has("distance"):
		var d: float = float(e.get("distance", 0.0))
		var b: float = deg_to_rad(float(e.get("bearing_deg", 0.0)))
		var el: float = deg_to_rad(float(e.get("elevation_deg", 0.0)))
		var d_h: float = d * cos(el)
		return Vector3(d_h * sin(b), d * sin(el), -d_h * cos(b))
	if e.has("pos") and e["pos"] is Vector3 and e["pos"] != Vector3.ZERO:
		return e["pos"]
	return Vector3.ZERO

func _update_3d_blips() -> void:
	if not is_instance_valid(blips_container) or not is_instance_valid(stems_mesh_inst):
		return
	if not is_powered:
		blips_container.visible = false
		return
	blips_container.visible = true

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_material(stems_material)

	var has_geometry := false

	# Entities
	for e in entities:
		if not _passes_filter(e):
			continue
		var e_type: String = str(e.get("type", ""))
		var is_occluded: bool = bool(e.get("is_occluded", false))
		var is_revealed_by_probe: bool = bool(e.get("is_revealed_by_probe", false))
		if is_occluded and not ping_active and not is_revealed_by_probe and e_type != "WAYPOINT":
			continue

		var rel_pos := _get_entity_rel_pos(e)
		var dist := rel_pos.length()
		var e_id: String = str(e.get("id", ""))
		var is_sel: bool = (e_id == selected_entity_id)
		var is_lock: bool = (e_id == locked_entity_id)
		if dist > max_range * 1.05 and not ping_active and not is_revealed_by_probe and e_type != "WAYPOINT" and not is_sel and not is_lock:
			continue
		var stealth: float = float(e.get("stealth_level", 0.0))
		if stealth > stealth_threshold and not ping_active:
			continue

		var clamped_rel := rel_pos
		if dist > max_range:
			clamped_rel = rel_pos.normalized() * max_range
		var pos_3d := (clamped_rel / max_range) * SPHERE_RADIUS
		var base_pos := Vector3(pos_3d.x, 0.0, pos_3d.z)

		var col := Color(0.3, 0.95, 0.45, 0.95)
		if e_type == "WAYPOINT":
			col = Color(0.95, 0.3, 1.0, 1.0)
		elif e_type == "PROBE":
			col = Color(0.2, 0.88, 1.0, 1.0)
		elif is_revealed_by_probe:
			col = Color(0.25, 0.9, 1.0, 0.95)

		# Stem drop-line to equatorial plane
		if absf(pos_3d.y) > 0.04:
			var stem_col := Color(col.r, col.g, col.b, 0.35)
			st.set_color(stem_col)
			st.add_vertex(base_pos)
			st.set_color(col)
			st.add_vertex(pos_3d)

			# Ground anchor cross / ring on equatorial plane
			var gr := 0.08
			st.set_color(stem_col)
			st.add_vertex(base_pos + Vector3(-gr, 0, 0))
			st.set_color(stem_col)
			st.add_vertex(base_pos + Vector3(gr, 0, 0))
			st.set_color(stem_col)
			st.add_vertex(base_pos + Vector3(0, 0, -gr))
			st.set_color(stem_col)
			st.add_vertex(base_pos + Vector3(0, 0, gr))

		# 3D Blip diamond / octahedron wireframe
		var bs := 0.12
		var p_top := pos_3d + Vector3(0, bs, 0)
		var p_bot := pos_3d + Vector3(0, -bs, 0)
		var p_pts: Array[Vector3] = [
			pos_3d + Vector3(-bs, 0, 0),
			pos_3d + Vector3(0, 0, -bs),
			pos_3d + Vector3(bs, 0, 0),
			pos_3d + Vector3(0, 0, bs)
		]
		for i in range(4):
			var cur_p: Vector3 = p_pts[i]
			var next_p: Vector3 = p_pts[(i + 1) % 4]
			st.set_color(col)
			st.add_vertex(cur_p)
			st.set_color(col)
			st.add_vertex(next_p)

			st.set_color(col)
			st.add_vertex(p_top)
			st.set_color(col)
			st.add_vertex(cur_p)

			st.set_color(col)
			st.add_vertex(p_bot)
			st.set_color(col)
			st.add_vertex(cur_p)

		# Relative velocity line
		var vel: Vector3 = e.get("local_velocity", e.get("velocity", Vector3.ZERO))
		if vel.length_squared() > 0.05:
			var v_len := clampf(vel.length() * 0.05, 0.1, 0.8)
			var vel_end := pos_3d + vel.normalized() * v_len
			st.set_color(Color(col.r, col.g, col.b, 0.75))
			st.add_vertex(pos_3d)
			st.set_color(Color(col.r, col.g, col.b, 0.15))
			st.add_vertex(vel_end)

		has_geometry = true

	# Ghost contacts if damaged
	if has_radar_ghosts:
		for g in _ghosts:
			var g_rel := _get_entity_rel_pos(g)
			var g_pos3d := (g_rel / max_range) * SPHERE_RADIUS
			var g_col := Color(0.9, 0.45, 0.2, randf_range(0.3, 0.8))
			var gs := 0.09
			st.set_color(g_col)
			st.add_vertex(g_pos3d + Vector3(-gs, 0, 0))
			st.set_color(g_col)
			st.add_vertex(g_pos3d + Vector3(gs, 0, 0))
			st.set_color(g_col)
			st.add_vertex(g_pos3d + Vector3(0, 0, -gs))
			st.set_color(g_col)
			st.add_vertex(g_pos3d + Vector3(0, 0, gs))
			has_geometry = true

	if has_geometry:
		stems_mesh_inst.mesh = st.commit()
		stems_mesh_inst.visible = true
	else:
		stems_mesh_inst.mesh = null
		stems_mesh_inst.visible = false

func _on_hud_draw() -> void:
	if not is_instance_valid(hud_overlay):
		return
	var center := size * 0.5
	var radius := minf(center.x, center.y) - 15.0
	if radius <= 20.0:
		return
	if not is_powered:
		return

	for e in entities:
		if not _passes_filter(e):
			continue
		var is_occluded: bool = bool(e.get("is_occluded", false))
		var is_revealed_by_probe: bool = bool(e.get("is_revealed_by_probe", false))
		var e_type: String = str(e.get("type", ""))
		if is_occluded and not ping_active and not is_revealed_by_probe and e_type != "WAYPOINT":
			continue
		var dist: float = float(e.get("distance", 0.0))
		if dist > max_range * 1.05 and not ping_active and not is_revealed_by_probe:
			continue
		var stealth: float = float(e.get("stealth_level", 0.0))
		if stealth > stealth_threshold and not ping_active:
			continue

		var s_pos := _world_to_screen(e, center, radius)
		var e_id: String = str(e.get("id", ""))
		var is_sel: bool = (e_id == selected_entity_id)
		var is_lock: bool = (e_id == locked_entity_id)

		if is_sel:
			var box := 16.0
			var b_rect := Rect2(s_pos - Vector2(box, box) * 0.5, Vector2(box, box))
			hud_overlay.draw_rect(b_rect, Color(1.0, 0.9, 0.2, 0.9), false, 1.5)
			
			var d_str: String = "%.0f m" % dist if dist < 1000.0 else "%.2f km" % (dist / 1000.0)
			var info_txt := "ECO #%s [%s]" % [e_id, d_str]
			if e_type == "WAYPOINT":
				info_txt = "WAYPOINT [%s]" % d_str
			elif e_type == "PROBE":
				info_txt = "PROBE [%s]" % d_str
			elif is_revealed_by_probe:
				info_txt = "ECO (PROBE) #%s [%s]" % [e_id, d_str]
			hud_overlay.draw_string(ThemeDB.fallback_font, s_pos + Vector2(12, 4), info_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.95, 0.5, 0.95))

		if is_lock:
			hud_overlay.draw_arc(s_pos, 11.0, 0, TAU, 24, Color(1.0, 0.2, 0.2, 0.9), 1.5, true)
			hud_overlay.draw_line(s_pos - Vector2(14, 0), s_pos + Vector2(14, 0), Color(1.0, 0.2, 0.2, 0.8), 1.0)
			hud_overlay.draw_line(s_pos - Vector2(0, 14), s_pos + Vector2(0, 14), Color(1.0, 0.2, 0.2, 0.8), 1.0)

	if not probe_data.is_empty():
		var p_pos: Vector3 = probe_data.get("pos", Vector3.ZERO)
		var p_screen := _world_pos_to_screen(p_pos, center, radius)
		hud_overlay.draw_circle(p_screen, 4.0, Color(0.2, 0.9, 1.0, 0.9))
		hud_overlay.draw_string(ThemeDB.fallback_font, p_screen + Vector2(8, 4), "SONDA ATTIVA", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.3, 0.9, 1.0, 0.9))

	var zoom_label := "1x"
	if max_range < 1000.0:
		zoom_label = "ZOOM %.0fx" % (1000.0 / max_range)
	elif max_range > 1000.0:
		zoom_label = "PANORAMICO"
	else:
		zoom_label = "STANDARD"

	var r_str := "%.0f M" % max_range if max_range < 1000.0 else "%.1f KM" % (max_range / 1000.0)
	var scale_str := "RADAR 3D: %s (%s) | %s" % [
		r_str,
		zoom_label,
		"ORBITALE" if current_mode == DisplayMode.ORBIT_3D else ("ZENITALE" if current_mode == DisplayMode.TOP_DOWN else "FRONTALE")
	]
	hud_overlay.draw_string(ThemeDB.fallback_font, center + Vector2(-radius + 8, -radius + 18), scale_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.85, 1.0, 0.85))

func _process(delta: float) -> void:
	if is_sweep_active and is_powered:
		sweep_angle = fmod(sweep_angle + delta * (sweep_frequency_hz * 0.15), TAU)
	
	if ping_active:
		ping_radius_progress += ping_speed * delta
		if ping_radius_progress >= ping_max_radius:
			ping_active = false
			ping_radius_progress = 0.0
	
	if has_radar_ghosts:
		_ghost_timer += delta
		if _ghost_timer >= 2.0:
			_ghost_timer = 0.0
			_generate_ghosts()
	else:
		_ghosts.clear()

	if is_instance_valid(sweep_pivot_3d):
		sweep_pivot_3d.visible = is_sweep_active and is_powered
		if is_sweep_active and is_powered:
			sweep_pivot_3d.rotation.y = -sweep_angle
	
	if is_instance_valid(ping_wave_mesh):
		if ping_active and is_powered:
			ping_wave_mesh.visible = true
			var progress_ratio := clampf(ping_radius_progress / maxf(1.0, ping_max_radius), 0.0, 1.0)
			var cur_r := progress_ratio * SPHERE_RADIUS
			ping_wave_mesh.scale = Vector3(cur_r, cur_r, cur_r)
			var mat := ping_wave_mesh.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color.a = (1.0 - progress_ratio) * 0.35
		else:
			ping_wave_mesh.visible = false
	
	if is_instance_valid(sub_viewport_container):
		sub_viewport_container.modulate = Color(1, 1, 1, 1) if is_powered else Color(0.2, 0.2, 0.2, 0.4)

	_update_3d_blips()
	queue_redraw()
	if is_instance_valid(hud_overlay):
		hud_overlay.queue_redraw()

func _generate_ghosts() -> void:
	_ghosts.clear()
	var count := randi_range(2, 4)
	for i in range(count):
		var ang := randf_range(0, TAU)
		var d := randf_range(150.0, max_range * 0.95)
		_ghosts.append({
			"id": "GHOST_%d" % i,
			"name": "ECO ANOMALO [Ghost-%d]" % i,
			"distance": d,
			"bearing_deg": rad_to_deg(ang),
			"elevation_deg": randf_range(-15, 15),
			"type": "GHOST",
			"iff_tag": "UNKNOWN",
			"stealth_level": 0.0,
			"signal_signature": 0.5,
			"pos": Vector3(cos(ang) * d, 0, sin(ang) * d)
		})

func trigger_ping(radius: float = 2000.0) -> void:
	ping_active = true
	ping_radius_progress = 0.0
	ping_max_radius = radius
	queue_redraw()

func set_range(r: float) -> void:
	max_range = clampf(r, MIN_RADAR_RANGE, MAX_RADAR_RANGE)
	range_changed.emit(max_range)
	_update_3d_blips()
	queue_redraw()
	if is_instance_valid(hud_overlay):
		hud_overlay.queue_redraw()

func zoom_in_range() -> void:
	if max_range > 1000.0:
		set_range(1000.0)
	elif max_range > 500.0:
		set_range(500.0)
	elif max_range > 200.0:
		set_range(200.0)

func zoom_out_range() -> void:
	if max_range < 500.0:
		set_range(500.0)
	elif max_range < 1000.0:
		set_range(1000.0)
	elif max_range < 2000.0:
		set_range(2000.0)

func set_display_mode(mode: DisplayMode) -> void:
	match mode:
		DisplayMode.TOP_DOWN:
			orbit_yaw = 0.0
			orbit_pitch = -85.0
		DisplayMode.FRONTAL_ELEVATION:
			orbit_yaw = 0.0
			orbit_pitch = 0.0
		DisplayMode.ORBIT_3D, _:
			orbit_yaw = 25.0
			orbit_pitch = -25.0
	_update_camera_transform()
	queue_redraw()

func _update_camera_transform() -> void:
	if is_instance_valid(orbit_pivot):
		orbit_pivot.rotation_degrees.y = orbit_yaw
	if is_instance_valid(pitch_pivot):
		pitch_pivot.rotation_degrees.x = orbit_pitch
	if is_instance_valid(camera_3d):
		camera_3d.position = Vector3(0.0, 0.0, camera_zoom)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_mouse_is_down = true
				_is_dragging_orbit = false
				_mouse_press_pos = event.position
			else:
				if _mouse_is_down:
					_mouse_is_down = false
					if not _is_dragging_orbit:
						_handle_left_click(event.position)
					_is_dragging_orbit = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if event.shift_pressed or event.is_command_or_control_pressed():
				zoom_in_range()
			else:
				camera_zoom = clampf(camera_zoom - ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
				_update_camera_transform()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if event.shift_pressed or event.is_command_or_control_pressed():
				zoom_out_range()
			else:
				camera_zoom = clampf(camera_zoom + ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
				_update_camera_transform()
			accept_event()
	
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_EQUAL or event.keycode == KEY_PLUS or event.keycode == KEY_KP_ADD:
			zoom_in_range()
			accept_event()
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			zoom_out_range()
			accept_event()
	
	elif event is InputEventMouseMotion:
		if _mouse_is_down and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			if not _is_dragging_orbit:
				if event.position.distance_to(_mouse_press_pos) >= DRAG_THRESHOLD:
					_is_dragging_orbit = true
			if _is_dragging_orbit:
				orbit_yaw -= event.relative.x * _orbit_sensitivity
				orbit_pitch += event.relative.y * _orbit_sensitivity
				orbit_pitch = clampf(orbit_pitch, -85.0, 85.0)
				_update_camera_transform()
				accept_event()

func _handle_left_click(m_pos: Vector2) -> void:
	var clicked_target := _find_entity_at_screen_pos(m_pos, 18.0)
	if not clicked_target.is_empty():
		selected_entity_id = str(clicked_target.get("id"))
		entity_selected.emit(clicked_target)
	else:
		selected_entity_id = ""
		entity_selected.emit({})

func _handle_right_click(m_pos: Vector2) -> void:
	var wp_pos := Vector3.ZERO
	var placed := false
	if is_instance_valid(camera_3d) and is_instance_valid(sub_viewport):
		var ray_origin := camera_3d.project_ray_origin(m_pos)
		var ray_normal := camera_3d.project_ray_normal(m_pos)
		if absf(ray_normal.y) > 0.0001:
			var t := -ray_origin.y / ray_normal.y
			if t > 0.0:
				var hit_pt := ray_origin + ray_normal * t
				var dist_norm := Vector2(hit_pt.x, hit_pt.z).length() / SPHERE_RADIUS
				if dist_norm <= 1.08:
					wp_pos = Vector3(hit_pt.x / SPHERE_RADIUS * max_range, 0.0, hit_pt.z / SPHERE_RADIUS * max_range)
					placed = true
	if not placed:
		var center := size * 0.5
		var radius := minf(center.x, center.y) - 15.0
		var delta_pos := m_pos - center
		var click_dist_ratio := delta_pos.length() / radius
		if click_dist_ratio <= 1.05:
			var world_dist: float = click_dist_ratio * max_range
			var angle := atan2(delta_pos.y, delta_pos.x) + PI * 0.5
			var wx: float = sin(angle) * world_dist
			var wz: float = -cos(angle) * world_dist
			wp_pos = Vector3(wx, 0.0, wz)
			placed = true

	if placed:
		waypoint_placed.emit(wp_pos)

func _find_entity_at_screen_pos(screen_pos: Vector2, hit_radius: float) -> Dictionary:
	var center := size * 0.5
	var r := minf(center.x, center.y) - 15.0
	
	for e in entities:
		if not _passes_filter(e):
			continue
		if bool(e.get("is_occluded", false)) and not ping_active and not bool(e.get("is_revealed_by_probe", false)):
			continue
		var s_pos := _world_to_screen(e, center, r)
		if screen_pos.distance_to(s_pos) <= hit_radius:
			return e
	
	for g in _ghosts:
		var s_pos := _world_to_screen(g, center, r)
		if screen_pos.distance_to(s_pos) <= hit_radius:
			return g
	
	return {}

func _passes_filter(e: Dictionary) -> bool:
	var t: String = str(e.get("type", ""))
	var iff: String = str(e.get("iff_tag", ""))
	
	match filter_category:
		"MINERALS":
			return t in ["ASTEROID", "MINERAL_ASTEROID"]
		"WRECKS":
			return t in ["WRECK", "DERELICT"]
		"THREATS":
			return iff in ["HOSTILE", "HAZARD"] or t in ["SHIP_HOSTILE"]
		"BEACONS":
			return t in ["BEACON", "STATION", "WAYPOINT"]
		_:
			return true

func _world_to_screen(e: Dictionary, center: Vector2, radius: float) -> Vector2:
	var rel_pos := _get_entity_rel_pos(e)
	if is_instance_valid(camera_3d) and is_instance_valid(sub_viewport):
		var d := rel_pos.length()
		var clamped_rel := rel_pos
		if d > max_range:
			clamped_rel = rel_pos.normalized() * max_range
		var p_3d := (clamped_rel / max_range) * SPHERE_RADIUS
		if not camera_3d.is_position_behind(p_3d):
			return camera_3d.unproject_position(p_3d)
	
	var dist: float = float(e.get("distance", 0.0))
	var norm_dist := clampf(dist / max_range, 0.0, 1.1)
	var bearing: float = deg_to_rad(float(e.get("bearing_deg", 0.0)) - 90.0)
	
	if current_mode == DisplayMode.ELEVATION_3D:
		var elev: float = deg_to_rad(float(e.get("elevation_deg", 0.0)))
		var x := cos(bearing) * norm_dist * radius
		var y := sin(bearing) * norm_dist * radius * 0.5 - sin(elev) * (radius * 0.35)
		return center + Vector2(x, y)
	
	return center + Vector2(cos(bearing), sin(bearing)) * (norm_dist * radius)

func _world_pos_to_screen(world_pos: Vector3, center: Vector2, radius: float) -> Vector2:
	if is_instance_valid(camera_3d) and is_instance_valid(sub_viewport):
		var d := world_pos.length()
		var clamped_pos := world_pos
		if d > max_range:
			clamped_pos = world_pos.normalized() * max_range
		var p_3d := (clamped_pos / max_range) * SPHERE_RADIUS
		if not camera_3d.is_position_behind(p_3d):
			return camera_3d.unproject_position(p_3d)
	
	var dist := Vector2(world_pos.x, world_pos.z).length()
	var norm_dist := clampf(dist / max_range, 0.0, 1.2)
	var bearing_deg := rad_to_deg(atan2(world_pos.x, -world_pos.z))
	var bearing := deg_to_rad(bearing_deg - 90.0)
	
	if current_mode == DisplayMode.ELEVATION_3D:
		var elev_deg := rad_to_deg(atan2(world_pos.y, maxf(0.001, dist)))
		var elev := deg_to_rad(elev_deg)
		var x := cos(bearing) * norm_dist * radius
		var y := sin(bearing) * norm_dist * radius * 0.5 - sin(elev) * (radius * 0.35)
		return center + Vector2(x, y)
	
	return center + Vector2(cos(bearing), sin(bearing)) * (norm_dist * radius)

# --- DRAW ROUTINE ---

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(center.x, center.y) - 15.0
	if radius <= 20.0:
		return
	
	if not is_powered:
		_draw_unpowered_screen(center, radius)
		return

	# Sfondo base radar diegetico
	draw_circle(center, radius, Color(0.02, 0.05, 0.08, 0.95))
	draw_arc(center, radius, 0, TAU, 72, Color(0.1, 0.85, 1.0, 0.75), 1.5, true)

	# Se il SubViewport 3D è presente ed operativo, il rendering 3D e l'HUD gestiscono la scena
	if is_instance_valid(sub_viewport):
		return
	
	# Fallback rendering 2D se SubViewport non disponibile
	if current_mode == DisplayMode.POLAR_2D:
		_draw_polar_grid(center, radius)
	elif current_mode == DisplayMode.CARTESIAN_GRID:
		_draw_cartesian_grid(center, radius)
	elif current_mode == DisplayMode.ELEVATION_3D:
		_draw_elevation_3d_grid(center, radius)
	
	_draw_obstacle_shadows(center, radius)
	_draw_probe_feed(center, radius)
	
	if ping_active and ping_max_radius > 0.0:
		var ping_norm := clampf(ping_radius_progress / max_range, 0.0, 1.0)
		var p_r := ping_norm * radius
		var alpha := 1.0 - (ping_radius_progress / ping_max_radius)
		draw_arc(center, p_r, 0, TAU, 64, Color(0.1, 0.9, 1.0, alpha * 0.75), 2.5, true)
		draw_circle(center, p_r, Color(0.1, 0.9, 1.0, alpha * 0.08))
	
	if is_sweep_active:
		var sweep_len := radius
		var sweep_dir := Vector2(cos(sweep_angle), sin(sweep_angle))
		var sweep_end := center + sweep_dir * sweep_len
		draw_line(center, sweep_end, Color(0.2, 0.9, 0.5, 0.6), 1.5)
		var trail_segments := 8
		for i in range(1, trail_segments + 1):
			var trail_ang := sweep_angle - float(i) * 0.04
			var trail_end := center + Vector2(cos(trail_ang), sin(trail_ang)) * sweep_len
			var t_alpha := (1.0 - float(i) / float(trail_segments)) * 0.25
			draw_line(center, trail_end, Color(0.2, 0.9, 0.5, t_alpha), 1.2)
	
	_draw_entities(center, radius)
	if has_radar_ghosts:
		_draw_ghosts(center, radius)
	
	var ship_pts := PackedVector2Array([
		center + Vector2(0, -8),
		center + Vector2(6, 7),
		center + Vector2(0, 4),
		center + Vector2(-6, 7)
	])
	draw_colored_polygon(ship_pts, Color(0.2, 0.9, 1.0, 0.95))
	draw_polyline(ship_pts, Color(0.8, 1.0, 1.0, 1.0), 1.0)
	
	var scale_str := "PORTATA: %.1f KM" % (max_range / 1000.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-radius + 5, -radius + 15), scale_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.85, 1.0, 0.8))

func _draw_unpowered_screen(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, Color(0.04, 0.04, 0.04, 0.9))
	draw_arc(center, radius, 0, TAU, 64, Color(0.5, 0.2, 0.2, 0.6), 1.5, true)
	draw_line(center - Vector2(radius * 0.5, 0), center + Vector2(radius * 0.5, 0), Color(0.8, 0.2, 0.2, 0.5), 1.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-90, 4), "⚠️ ALIMENTAZIONE INSUFFICIENTE", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1.0, 0.3, 0.3, 0.9))

func _draw_polar_grid(center: Vector2, radius: float) -> void:
	var rings := 4
	for i in range(1, rings + 1):
		var frac := float(i) / float(rings)
		var r := radius * frac
		var ring_col := Color(0.12, 0.35, 0.45, 0.35)
		draw_arc(center, r, 0, TAU, 48, ring_col, 1.0, true)
		
		var m_val := max_range * frac
		var label_str := "%.0f m" % m_val if max_range <= 1500.0 else "%.1f km" % (m_val / 1000.0)
		draw_string(ThemeDB.fallback_font, center + Vector2(4, -r + 11), label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.3, 0.7, 0.8, 0.5))
	
	# Assi primari ortogonali (N, S, E, O)
	draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(0.15, 0.45, 0.55, 0.3), 1.0)
	draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color(0.15, 0.45, 0.55, 0.3), 1.0)
	
	# Assi diagonali (45°, 135°, 225°, 315°)
	var diag := radius * 0.7071
	draw_line(center - Vector2(diag, diag), center + Vector2(diag, diag), Color(0.12, 0.35, 0.45, 0.2), 1.0)
	draw_line(center - Vector2(diag, -diag), center + Vector2(diag, -diag), Color(0.12, 0.35, 0.45, 0.2), 1.0)

func _draw_cartesian_grid(center: Vector2, radius: float) -> void:
	var grid_steps := 6
	var step_size := (radius * 2.0) / float(grid_steps)
	
	for i in range(grid_steps + 1):
		var offset := -radius + float(i) * step_size
		var half_h := sqrt(maxf(0.0, radius * radius - offset * offset))
		draw_line(center + Vector2(offset, -half_h), center + Vector2(offset, half_h), Color(0.12, 0.38, 0.48, 0.25), 1.0)
		var half_w := sqrt(maxf(0.0, radius * radius - offset * offset))
		draw_line(center + Vector2(-half_w, offset), center + Vector2(half_w, offset), Color(0.12, 0.38, 0.48, 0.25), 1.0)
	
	draw_arc(center, radius, 0, TAU, 64, Color(0.2, 0.5, 0.6, 0.4), 1.0, true)

func _draw_elevation_3d_grid(center: Vector2, radius: float) -> void:
	for i in range(1, 4):
		var frac := float(i) / 3.0
		var rx := radius * frac
		var ry := radius * frac * 0.5
		draw_arc(center, rx, 0, TAU, 48, Color(0.15, 0.4, 0.5, 0.3), 1.0, true)
	
	draw_line(center - Vector2(0, radius * 0.8), center + Vector2(0, radius * 0.8), Color(0.2, 0.7, 0.9, 0.4), 1.0)

## Disegna le proiezioni dei coni d'ombra proiettati dai corpi massivi / asteroidi
func _draw_obstacle_shadows(center: Vector2, radius: float) -> void:
	for e in entities:
		var t: String = str(e.get("type", ""))
		var r_m: float = float(e.get("radius_m", 0.0))
		if r_m <= 0.0 and t not in ["ASTEROID", "MINERAL_ASTEROID", "STATION", "WRECK"]:
			continue
		
		if r_m <= 0.0:
			r_m = 25.0
		
		var dist: float = float(e.get("distance", 0.0))
		if dist <= 5.0 or dist > max_range * 1.5:
			continue
		
		var obs_screen := _world_to_screen(e, center, radius)
		var d_vec := obs_screen - center
		var d_len := d_vec.length()
		if d_len <= 2.0:
			continue
		
		var obs_rad := clampf((r_m / max_range) * radius, 4.0, 28.0)
		var ang := atan2(d_vec.y, d_vec.x)
		var ratio := clampf(obs_rad / maxf(d_len, obs_rad + 0.1), 0.0, 0.99)
		var delta_ang := asin(ratio)
		
		var t1 := obs_screen + Vector2(cos(ang - PI * 0.5 + delta_ang), sin(ang - PI * 0.5 + delta_ang)) * obs_rad
		var t2 := obs_screen + Vector2(cos(ang + PI * 0.5 - delta_ang), sin(ang + PI * 0.5 - delta_ang)) * obs_rad
		var f_len := radius * 1.3
		var t3 := center + Vector2(cos(ang + delta_ang), sin(ang + delta_ang)) * f_len
		var t4 := center + Vector2(cos(ang - delta_ang), sin(ang - delta_ang)) * f_len
		
		# Disegna il poligono d'ombra radar
		var shadow_poly := PackedVector2Array([t1, t2, t3, t4])
		draw_colored_polygon(shadow_poly, Color(0.01, 0.02, 0.04, 0.55))
		draw_line(t1, t4, Color(0.12, 0.22, 0.32, 0.25), 1.0)
		draw_line(t2, t3, Color(0.12, 0.22, 0.32, 0.25), 1.0)

## Disegna l'area di copertura e il feed radar della sonda telemetrica secondaria
func _draw_probe_feed(center: Vector2, radius: float) -> void:
	if probe_data.is_empty():
		return
	
	var probe_pos: Vector3 = probe_data.get("pos", Vector3.ZERO)
	var probe_scan_r: float = float(probe_data.get("scan_radius", 1000.0))
	var p_screen := _world_pos_to_screen(probe_pos, center, radius)
	var p_screen_r := (probe_scan_r / max_range) * radius
	
	# Cerchio di copertura radar della sonda
	draw_circle(p_screen, p_screen_r, Color(0.08, 0.55, 0.85, 0.07))
	draw_arc(p_screen, p_screen_r, 0, TAU, 48, Color(0.2, 0.85, 1.0, 0.4), 1.2, true)
	
	# Indicatore icona sonda
	var probe_diamond := PackedVector2Array([
		p_screen + Vector2(0, -4),
		p_screen + Vector2(4, 0),
		p_screen + Vector2(0, 4),
		p_screen + Vector2(-4, 0)
	])
	draw_colored_polygon(probe_diamond, Color(0.3, 0.95, 1.0, 0.9))
	draw_polyline(probe_diamond, Color(0.8, 1.0, 1.0, 1.0), 1.0)
	draw_string(ThemeDB.fallback_font, p_screen + Vector2(7, 3), "PROBE FEED", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.35, 0.9, 1.0, 0.85))

func _draw_entities(center: Vector2, radius: float) -> void:
	for e in entities:
		if not _passes_filter(e):
			continue
		
		var dist: float = float(e.get("distance", 0.0))
		var is_occluded: bool = bool(e.get("is_occluded", false))
		var is_revealed_by_probe: bool = bool(e.get("is_revealed_by_probe", false))
		var e_type: String = str(e.get("type", ""))
		
		# Se il contatto è in ombra rispetto alla nave e non è rivelato da una sonda (e non c'è ping attivo)
		if is_occluded and not ping_active and not is_revealed_by_probe and e_type != "WAYPOINT":
			continue
		
		if dist > max_range * 1.05 and not ping_active and not is_revealed_by_probe:
			continue
		
		# Controllo stealth
		var stealth: float = float(e.get("stealth_level", 0.0))
		if stealth > stealth_threshold and not ping_active:
			continue
		
		var s_pos := _world_to_screen(e, center, radius)
		var e_id: String = str(e.get("id", ""))
		var is_sel: bool = (e_id == selected_entity_id)
		var is_lock: bool = (e_id == locked_entity_id)
		
		# --- RENDERING RADAR DIEGETICO PURO ---
		# Nessuna classificazione magica o colore fazioni IFF automatico cheat!
		if e_type == "WAYPOINT":
			var wp_col := Color(0.9, 0.3, 1.0)
			draw_arc(s_pos, 7.0, 0, TAU, 20, wp_col, 1.5, true)
			draw_line(s_pos, s_pos + Vector2(0, -10), wp_col, 1.5)
			draw_colored_polygon(PackedVector2Array([
				s_pos + Vector2(0, -10),
				s_pos + Vector2(6, -7),
				s_pos + Vector2(0, -4)
			]), wp_col)
		elif e_type == "PROBE":
			var prb_col := Color(0.2, 0.85, 1.0)
			draw_circle(s_pos, 3.5, prb_col)
			draw_arc(s_pos, 6.0, 0, TAU, 16, prb_col, 1.0, true)
		else:
			# Blip / Eco diegetico
			var blip_col: Color = Color(0.3, 0.95, 0.45, 0.9)
			if is_revealed_by_probe:
				blip_col = Color(0.2, 0.88, 1.0, 0.95) # Feed sonda (ciano)
			
			var sig: float = float(e.get("signal_signature", 0.5))
			var blip_size: float = clampf(3.0 + sig * 2.5, 3.0, 6.0)
			
			draw_circle(s_pos, blip_size, blip_col)
			draw_arc(s_pos, blip_size + 2.0, 0, TAU, 16, Color(blip_col.r, blip_col.g, blip_col.b, 0.35), 1.0, true)
			
			# Vettore di velocità relativa
			var vel: Vector3 = e.get("local_velocity", e.get("velocity", Vector3.ZERO))
			if vel.length_squared() > 0.05:
				var vel_2d := Vector2(vel.x, -vel.z) * 3.0
				draw_line(s_pos, s_pos + vel_2d, Color(blip_col.r, blip_col.g, blip_col.b, 0.5), 1.0)
		
		# Proiezione gambo in 3D Elevation
		if current_mode == DisplayMode.ELEVATION_3D:
			var bearing: float = deg_to_rad(float(e.get("bearing_deg", 0.0)) - 90.0)
			var norm_dist := clampf(dist / max_range, 0.0, 1.0)
			var base_plane_pos := center + Vector2(cos(bearing) * norm_dist * radius, sin(bearing) * norm_dist * radius * 0.5)
			draw_dashed_line(base_plane_pos, s_pos, Color(0.3, 0.8, 0.9, 0.4), 1.0, 2.0)
			draw_circle(base_plane_pos, 1.5, Color(0.3, 0.8, 0.9, 0.5))
		
		# Rettangolo di Selezione
		if is_sel:
			var box := 14.0
			var b_rect := Rect2(s_pos - Vector2(box, box) * 0.5, Vector2(box, box))
			draw_rect(b_rect, Color(1.0, 0.9, 0.2, 0.9), false, 1.5)
			
			var d_km: float = dist / 1000.0
			var info_txt := "ECO #%s [%.2f km]" % [e_id, d_km]
			if e_type == "WAYPOINT":
				info_txt = "WAYPOINT [%.2f km]" % d_km
			elif e_type == "PROBE":
				info_txt = "PROBE [%.2f km]" % d_km
			elif is_revealed_by_probe:
				info_txt = "ECO (PROBE) #%s [%.2f km]" % [e_id, d_km]
			
			draw_string(ThemeDB.fallback_font, s_pos + Vector2(10, 3), info_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.95, 0.5, 0.9))
		
		# Riconoscimento Lock
		if is_lock:
			draw_arc(s_pos, 10.0, 0, TAU, 24, Color(1.0, 0.2, 0.2, 0.9), 1.5, true)
			draw_line(s_pos - Vector2(12, 0), s_pos + Vector2(12, 0), Color(1.0, 0.2, 0.2, 0.7), 1.0)
			draw_line(s_pos - Vector2(0, 12), s_pos + Vector2(0, 12), Color(1.0, 0.2, 0.2, 0.7), 1.0)

func _draw_ghosts(center: Vector2, radius: float) -> void:
	for g in _ghosts:
		var s_pos := _world_to_screen(g, center, radius)
		var f_alpha := randf_range(0.3, 0.8)
		draw_circle(s_pos, 3.0, Color(0.9, 0.8, 0.3, f_alpha))
		draw_arc(s_pos, 6.0, 0, TAU, 12, Color(0.9, 0.4, 0.2, f_alpha * 0.6), 1.0, true)
