extends Control
class_name SystemMapApp

## Applicazione GodotOS diegetica "System Map" (Applications/SystemMap).
## Fornisce una mappa interattiva 2D della griglia a settori del sistema stellare,
## visualizza i macro-corpi celesti (stella, pianeti, stazioni, asteroidi, relitti),
## la posizione corrente della nave con vettore di prua, e consente la selezione di settori
## e il calcolo/invio di rotte di transito Hyperdrive verso Flight Control.

const APP_TITLE: String = "System Map & Hyperdrive Navigation"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(720, 520)

signal route_plotted(target_sector_coords: Vector3i, course_vector: Vector3)

const CONFIG_PATH: String = "Ship Drive/Programs/SystemMap/system_map_config.dat"

# Nodi UI
@onready var system_name_label: Label = %SystemNameLabel
@onready var current_sector_label: Label = %CurrentSectorLabel
@onready var ship_heading_label: Label = %ShipHeadingLabel
@onready var selected_sector_label: Label = %SelectedSectorLabel
@onready var route_distance_label: Label = %RouteDistanceLabel
@onready var route_eta_label: Label = %RouteEtaLabel
@onready var route_cost_label: Label = %RouteCostLabel
@onready var btn_plot_route: Button = %BtnPlotRoute
@onready var btn_send_route: Button = %BtnSendRoute
@onready var btn_clear_route: Button = %BtnClearRoute
@onready var btn_center_ship: Button = %BtnCenterShip
@onready var btn_zoom_in: Button = %BtnZoomIn
@onready var btn_zoom_out: Button = %BtnZoomOut
@onready var btn_zoom_reset: Button = %BtnZoomReset
@onready var search_box: LineEdit = %SearchBox
@onready var sector_info_text: RichTextLabel = %SectorInfoText
@onready var grid_display: Control = %GridDisplay

var can_control_map: bool = true
var parent_window: FakeWindow = null

# Stato navigazione e griglia
var selected_sector_coords: Vector3i = Vector3i.ZERO
var has_selected_sector: bool = false
var calculated_route: Dictionary = {}

# Parametri griglia / rendering
var zoom_level: float = 1.0
const MIN_ZOOM: float = 0.4
const MAX_ZOOM: float = 2.5
var pan_offset: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_start_pan: Vector2 = Vector2.ZERO
const CELL_BASE_SIZE: float = 48.0 # pixel per settore a zoom 1.0

# Dati di configurazione
var app_config: Dictionary = {
	"transit_speed_c": 120.0,
	"energy_cost_per_sector": 15.0,
	"fuel_cost_per_sector": 2.5,
	"auto_route_safety": true
}

func _ready() -> void:
	_configure_window()
	_load_config()
	_connect_signals()
	_update_permissions()
	
	if StarSystemGridManager:
		selected_sector_coords = StarSystemGridManager.get_current_sector_coords()
		has_selected_sector = true
		_center_on_sector(selected_sector_coords)
	
	_update_system_info()
	_update_route_info()
	if grid_display:
		grid_display.queue_redraw()

func _configure_window() -> void:
	custom_minimum_size = DEFAULT_WINDOW_SIZE
	call_deferred("_setup_parent_window", APP_TITLE, DEFAULT_WINDOW_SIZE)

func _setup_parent_window(_title: String, _size: Vector2) -> void:
	parent_window = _find_parent_window()
	if parent_window:
		parent_window.size = DEFAULT_WINDOW_SIZE
		parent_window.custom_minimum_size = Vector2(600, 420)
		parent_window.title_text = APP_TITLE
		var title_label := parent_window.get_node_or_null("Top Bar/Title Text")
		if title_label:
			title_label.text = "[center]" + APP_TITLE

func _find_parent_window() -> FakeWindow:
	var curr: Node = get_parent()
	while curr:
		if curr is FakeWindow:
			return curr
		curr = curr.get_parent()
	return null

func _connect_signals() -> void:
	if btn_plot_route:
		btn_plot_route.pressed.connect(_on_plot_route_pressed)
	if btn_send_route:
		btn_send_route.pressed.connect(_on_send_route_pressed)
	if btn_clear_route:
		btn_clear_route.pressed.connect(_on_clear_route_pressed)
	if btn_center_ship:
		btn_center_ship.pressed.connect(_on_center_ship_pressed)
	if btn_zoom_in:
		btn_zoom_in.pressed.connect(_on_zoom_in_pressed)
	if btn_zoom_out:
		btn_zoom_out.pressed.connect(_on_zoom_out_pressed)
	if btn_zoom_reset:
		btn_zoom_reset.pressed.connect(_on_zoom_reset_pressed)
	if search_box:
		search_box.text_submitted.connect(_on_search_submitted)
	
	if grid_display:
		grid_display.draw.connect(_on_grid_display_draw)
		grid_display.gui_input.connect(_on_grid_gui_input)

	if StarSystemGridManager:
		if not StarSystemGridManager.sector_changed.is_connected(_on_sector_changed):
			StarSystemGridManager.sector_changed.connect(_on_sector_changed)
		if not StarSystemGridManager.route_plotted.is_connected(_on_system_route_plotted):
			StarSystemGridManager.route_plotted.connect(_on_system_route_plotted)

	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("file_synced"):
		if not sdm.file_synced.is_connected(_on_file_synced):
			sdm.file_synced.connect(_on_file_synced)

func _update_permissions() -> void:
	if NetworkManager and NetworkManager.has_method("get_local_player_role"):
		var current_role: String = NetworkManager.get_local_player_role()
		var is_solo: bool = NetworkManager.is_solo_mode
		var allowed_roles := ["Pilota", "Capitano", "Hacker", "Tattico", "Pilot", "Captain", "Hacker", "Stagista", "Soldier", "Soldato", ""]
		can_control_map = allowed_roles.has(current_role) or is_solo
	else:
		can_control_map = true

	if btn_plot_route:
		btn_plot_route.disabled = not can_control_map
	if btn_send_route:
		btn_send_route.disabled = not can_control_map or calculated_route.is_empty()

func _on_file_synced(path: String) -> void:
	if "system_map_config.dat" in path:
		_load_config()

func _load_config() -> void:
	var path_to_load := "user://files/" + CONFIG_PATH
	if not FileAccess.file_exists(path_to_load):
		return
	var file := FileAccess.open(path_to_load, FileAccess.READ)
	if not file:
		return
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("#") or line.begins_with(";") or line.begins_with("[") or line.is_empty():
			continue
		var parts := line.split("=", false, 1)
		if parts.size() == 2:
			var key: String = parts[0].strip_edges().to_lower()
			var val_str: Variant = parts[1].strip_edges()
			match key:
				"transit_speed_c":
					app_config["transit_speed_c"] = val_str.to_float()
				"energy_cost_per_sector":
					app_config["energy_cost_per_sector"] = val_str.to_float()
				"fuel_cost_per_sector":
					app_config["fuel_cost_per_sector"] = val_str.to_float()
				"auto_route_safety":
					app_config["auto_route_safety"] = (val_str.to_lower() == "true")

func _process(_delta: float) -> void:
	_update_system_info()
	if grid_display:
		grid_display.queue_redraw()

func _update_system_info() -> void:
	var cur_coords := Vector3i(4, 11, 0)
	var sys_name := "Helios Nova System"
	if StarSystemGridManager:
		cur_coords = StarSystemGridManager.get_current_sector_coords()
		if StarSystemGridManager.current_system_data:
			sys_name = StarSystemGridManager.current_system_data.system_name

	if system_name_label:
		system_name_label.text = sys_name
	if current_sector_label:
		current_sector_label.text = "SETTORE NAVE: %s" % SectorData.format_coords_to_id(cur_coords)

	# Vettore di prua della nave (da Spaceship o SpaceWorldManager)
	var heading_deg: float = 0.0
	if SpaceWorldManager and SpaceWorldManager.has_method("get_spaceship"):
		var ship := SpaceWorldManager.get_spaceship()
		if ship and is_instance_valid(ship):
			heading_deg = rad_to_deg(ship.rotation.y)
	if ship_heading_label:
		ship_heading_label.text = "PRUA: %03.0f°" % fposmod(heading_deg, 360.0)

func _update_route_info() -> void:
	if not has_selected_sector:
		if selected_sector_label:
			selected_sector_label.text = "SETTORE SELEZIONATO: --"
		if sector_info_text:
			sector_info_text.text = "[color=#888888]Seleziona un settore sulla griglia per calcolare una rotta.[/color]"
		if route_distance_label:
			route_distance_label.text = "DISTANZA: --"
		if route_eta_label:
			route_eta_label.text = "ETA TRANSITO: --"
		if route_cost_label:
			route_cost_label.text = "STIMA ENERGIA/CARB: --"
		if btn_send_route:
			btn_send_route.disabled = true
		return

	var sel_id := SectorData.format_coords_to_id(selected_sector_coords)
	if selected_sector_label:
		selected_sector_label.text = "SETTORE TARGET: %s" % sel_id

	# Informazioni sul corpo celeste nel settore selezionato
	var body_desc := "Spazio profondo aperto."
	if StarSystemGridManager:
		for b in StarSystemGridManager.system_celestial_bodies:
			if b.get("coords") == selected_sector_coords:
				body_desc = "[b]%s[/b] (%s)\n%s" % [b.get("name"), b.get("type"), b.get("description")]
				break
	if sector_info_text:
		sector_info_text.text = body_desc

	var cur_coords := StarSystemGridManager.get_current_sector_coords() if StarSystemGridManager else Vector3i(4, 11, 0)
	var dist_sectors := (Vector3(selected_sector_coords) - Vector3(cur_coords)).length()
	var dist_km := dist_sectors * 100000.0
	
	if route_distance_label:
		route_distance_label.text = "DISTANZA: %.1f settori (%.0f km)" % [dist_sectors, dist_km]
	
	var eta_s := maxf(3.0, dist_sectors * 4.5) if dist_sectors > 0 else 0.0
	if route_eta_label:
		route_eta_label.text = "ETA TRANSITO: %.1f s" % eta_s
	
	var energy: float = dist_sectors * float(app_config.get("energy_cost_per_sector"))
	var fuel: float = dist_sectors * float(app_config.get("fuel_cost_per_sector"))
	if route_cost_label:
		route_cost_label.text = "STIMA ENERGIA: %.1f MW | CARB: %.1f U" % [energy, fuel]

	if btn_send_route:
		btn_send_route.disabled = not can_control_map or calculated_route.is_empty()

func select_sector(coords: Vector3i) -> void:
	selected_sector_coords = coords
	has_selected_sector = true
	_calculate_route_to_selected()
	_update_route_info()
	if grid_display:
		grid_display.queue_redraw()

func _calculate_route_to_selected() -> void:
	if not has_selected_sector or StarSystemGridManager == null:
		calculated_route.clear()
		return
	
	var cur_coords := StarSystemGridManager.get_current_sector_coords()
	var dist_sectors := StarSystemGridManager.get_sector_distance(cur_coords, selected_sector_coords)
	var course_vec := StarSystemGridManager.get_route_vector(cur_coords, selected_sector_coords)
	var dist_km := StarSystemGridManager.calculate_kinematic_distance_km(cur_coords, selected_sector_coords)
	var eta_s := maxf(3.0, dist_sectors * 4.5) if dist_sectors > 0 else 0.0
	var energy: float = dist_sectors * float(app_config.get("energy_cost_per_sector"))
	var fuel: float = dist_sectors * float(app_config.get("fuel_cost_per_sector"))

	calculated_route = {
		"from_coords": cur_coords,
		"from_sector_id": SectorData.format_coords_to_id(cur_coords),
		"target_coords": selected_sector_coords,
		"target_sector_id": SectorData.format_coords_to_id(selected_sector_coords),
		"distance_sectors": dist_sectors,
		"distance_km": dist_km,
		"course_vector": course_vec,
		"eta_seconds": eta_s,
		"energy_cost_mw": energy,
		"fuel_cost": fuel
	}

func _on_plot_route_pressed() -> void:
	if not has_selected_sector:
		return
	_calculate_route_to_selected()
	_update_route_info()
	if grid_display:
		grid_display.queue_redraw()

func _on_send_route_pressed() -> void:
	send_route_to_flight_control()

## Invia la rotta calcolata a Flight Control ed emette il segnale di navigazione
func send_route_to_flight_control() -> Dictionary:
	if not has_selected_sector:
		return {}

	if calculated_route.is_empty():
		_calculate_route_to_selected()
	
	var target_coords: Vector3i = selected_sector_coords
	var course_vec: Vector3 = Vector3.ZERO
	if not calculated_route.is_empty():
		target_coords = calculated_route.get("target_coords", selected_sector_coords)
		course_vec = calculated_route.get("course_vector", Vector3.ZERO)
	elif StarSystemGridManager:
		var cur := StarSystemGridManager.get_current_sector_coords()
		course_vec = StarSystemGridManager.get_route_vector(cur, target_coords)

	var mgr := get_node_or_null("/root/StarSystemGridManager")
	if mgr and mgr.has_method("plot_route"):
		mgr.plot_route(target_coords)
	elif StarSystemGridManager and StarSystemGridManager.has_method("plot_route"):
		StarSystemGridManager.plot_route(target_coords)

	route_plotted.emit(target_coords, course_vec)

	# Feedback visivo
	if route_eta_label:
		route_eta_label.text = "[ROTTA TRASMESSA A FLIGHT CONTROL]"
	
	return calculated_route

func _on_clear_route_pressed() -> void:
	calculated_route.clear()
	if StarSystemGridManager:
		StarSystemGridManager.clear_plotted_route()
	_update_route_info()
	if grid_display:
		grid_display.queue_redraw()

func _on_center_ship_pressed() -> void:
	var cur_coords := Vector3i(4, 11, 0)
	if StarSystemGridManager:
		cur_coords = StarSystemGridManager.get_current_sector_coords()
	_center_on_sector(cur_coords)

func _center_on_sector(coords: Vector3i) -> void:
	if grid_display == null:
		return
	var center_pos := grid_display.size * 0.5
	var cell_size := CELL_BASE_SIZE * zoom_level
	var sector_center := Vector2(coords.x * cell_size, coords.y * cell_size)
	pan_offset = center_pos - sector_center
	if grid_display:
		grid_display.queue_redraw()

func _on_zoom_in_pressed() -> void:
	zoom_level = clampf(zoom_level * 1.25, MIN_ZOOM, MAX_ZOOM)
	if grid_display:
		grid_display.queue_redraw()

func _on_zoom_out_pressed() -> void:
	zoom_level = clampf(zoom_level / 1.25, MIN_ZOOM, MAX_ZOOM)
	if grid_display:
		grid_display.queue_redraw()

func _on_zoom_reset_pressed() -> void:
	zoom_level = 1.0
	_on_center_ship_pressed()

func _on_search_submitted(text: String) -> void:
	var clean := text.strip_edges().to_upper()
	if clean.is_empty():
		return
	
	# Verifica se è un identificatore di coordinate es. SEC-04-12
	if clean.begins_with("SEC-"):
		var coords := SectorData.parse_id_to_coords(clean)
		select_sector(coords)
		_center_on_sector(coords)
		return

	# Cerca per nome corpo celeste
	if StarSystemGridManager:
		for b in StarSystemGridManager.system_celestial_bodies:
			if b == null: continue
			var b_name: String = str(b.get("name")).to_upper()
			var b_id: String = str(b.get("id")).to_upper()
			if clean in b_name or clean in b_id:
				var coords: Vector3i = b.get("coords")
				select_sector(coords)
				_center_on_sector(coords)
				return

func _on_sector_changed(_old: Vector3i, new_c: Vector3i, _data: SectorData) -> void:
	_update_system_info()
	if grid_display:
		grid_display.queue_redraw()

func _on_system_route_plotted(target_coords: Vector3i, course_vec: Vector3) -> void:
	selected_sector_coords = target_coords
	has_selected_sector = true
	_calculate_route_to_selected()
	_update_route_info()
	if grid_display:
		grid_display.queue_redraw()

# --- INPUT E RENDERING DELLA GRIGLIA 2D INTERATTIVA ---

func _on_grid_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				is_dragging = true
				drag_start_pos = mb.position
				drag_start_pan = pan_offset
			else:
				if is_dragging:
					# Se il movimento è stato minimo, consideralo un click di selezione
					if (mb.position - drag_start_pos).length() < 6.0:
						_handle_sector_click(mb.position)
				is_dragging = false
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_level = clampf(zoom_level * 1.15, MIN_ZOOM, MAX_ZOOM)
			grid_display.queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_level = clampf(zoom_level / 1.15, MIN_ZOOM, MAX_ZOOM)
			grid_display.queue_redraw()

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if is_dragging:
			pan_offset = drag_start_pan + (mm.position - drag_start_pos)
			grid_display.queue_redraw()

func _handle_sector_click(screen_pos: Vector2) -> void:
	var cell_size := CELL_BASE_SIZE * zoom_level
	var grid_pos := screen_pos - pan_offset
	var sx := floori((grid_pos.x + cell_size * 0.5) / cell_size)
	var sy := floori((grid_pos.y + cell_size * 0.5) / cell_size)
	var click_coords := Vector3i(sx, sy, 0)
	select_sector(click_coords)

func _on_grid_display_draw() -> void:
	if grid_display == null:
		return
	
	var canvas := grid_display
	var size := canvas.size
	var cell_size := CELL_BASE_SIZE * zoom_level
	var font := ThemeDB.fallback_font
	var font_size := int(clampf(10 * zoom_level, 8, 14))

	# Disegna sfondo griglia
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.07, 1.0), true)

	# Determina range visibile di settori
	var min_grid_x := floori((-pan_offset.x - cell_size) / cell_size) - 1
	var max_grid_x := floori((size.x - pan_offset.x + cell_size) / cell_size) + 1
	var min_grid_y := floori((-pan_offset.y - cell_size) / cell_size) - 1
	var max_grid_y := floori((size.y - pan_offset.y + cell_size) / cell_size) + 1

	# Linee griglia
	var grid_color := Color(0.1, 0.25, 0.4, 0.35)
	for x in range(min_grid_x, max_grid_x + 1):
		var px := pan_offset.x + x * cell_size - cell_size * 0.5
		canvas.draw_line(Vector2(px, 0), Vector2(px, size.y), grid_color, 1.0)
	for y in range(min_grid_y, max_grid_y + 1):
		var py := pan_offset.y + y * cell_size - cell_size * 0.5
		canvas.draw_line(Vector2(0, py), Vector2(size.x, py), grid_color, 1.0)

	# Assi principali (0,0)
	var origin_x := pan_offset.x - cell_size * 0.5
	var origin_y := pan_offset.y - cell_size * 0.5
	canvas.draw_line(Vector2(origin_x, 0), Vector2(origin_x, size.y), Color(0.2, 0.5, 0.8, 0.6), 1.5)
	canvas.draw_line(Vector2(0, origin_y), Vector2(size.x, origin_y), Color(0.2, 0.5, 0.8, 0.6), 1.5)

	# Coordinate sui settori
	if zoom_level >= 0.7:
		for x in range(min_grid_x, max_grid_x + 1):
			for y in range(min_grid_y, max_grid_y + 1):
				var cell_center := pan_offset + Vector2(x * cell_size, y * cell_size)
				var coord_str := "%02d,%02d" % [x, y]
				canvas.draw_string(font, cell_center - Vector2(16, -16), coord_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.3, 0.5, 0.7, 0.4))

	# Macro-corpi celesti
	var celestial_bodies: Array[Dictionary] = []
	if StarSystemGridManager:
		var mgr_bodies := StarSystemGridManager.system_celestial_bodies
		for b in mgr_bodies:
			if b is CelestialBodyData:
				celestial_bodies.append({
					"coords": b.coords,
					"type": b.type,
					"name": b.name
				})
			else:
				celestial_bodies.append(b)

	for body in celestial_bodies:
		var b_coords: Vector3i = body.get("coords")
		var b_pos := pan_offset + Vector2(b_coords.x * cell_size, b_coords.y * cell_size)
		var b_type: String = body.get("type").to_upper()
		var b_name: String = body.get("name")
		
		var icon_color := Color.WHITE
		var icon_radius := 6.0 * zoom_level
		match b_type:
			"STAR":
				icon_color = Color(1.0, 0.9, 0.3)
				icon_radius = 12.0 * zoom_level
			"PLANET":
				icon_color = Color(0.2, 0.7, 1.0)
				icon_radius = 8.0 * zoom_level
			"GAS_GIANT":
				icon_color = Color(0.9, 0.5, 0.2)
				icon_radius = 10.0 * zoom_level
			"MOON":
				icon_color = Color(0.7, 0.8, 0.8)
				icon_radius = 4.5 * zoom_level
			"STATION":
				icon_color = Color(0.2, 1.0, 0.4)
				icon_radius = 6.0 * zoom_level
			"ASTEROID_FIELD", "ASTEROID_BELT":
				icon_color = Color(0.8, 0.6, 0.3)
				icon_radius = 7.0 * zoom_level
			"WRECK":
				icon_color = Color(1.0, 0.3, 0.3)
				icon_radius = 5.0 * zoom_level
			"PATROL":
				icon_color = Color(0.4, 0.9, 1.0)
				icon_radius = 4.0 * zoom_level

		canvas.draw_circle(b_pos, icon_radius, icon_color)
		canvas.draw_arc(b_pos, icon_radius + 2.0, 0, TAU, 16, icon_color * Color(1, 1, 1, 0.5), 1.0)
		
		if zoom_level >= 0.6:
			canvas.draw_string(font, b_pos + Vector2(icon_radius + 4.0, 4.0), b_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, icon_color)

	# Posizione attuale nave
	var cur_ship_coords := Vector3i(4, 11, 0)
	if StarSystemGridManager:
		cur_ship_coords = StarSystemGridManager.get_current_sector_coords()
	var ship_pos := pan_offset + Vector2(cur_ship_coords.x * cell_size, cur_ship_coords.y * cell_size)
	
	# Evidenziazione settore nave
	var cell_rect := Rect2(ship_pos - Vector2(cell_size * 0.5, cell_size * 0.5), Vector2(cell_size, cell_size))
	canvas.draw_rect(cell_rect, Color(0.2, 0.8, 1.0, 0.15), true)
	canvas.draw_rect(cell_rect, Color(0.2, 0.8, 1.0, 0.8), false, 1.5)

	# Icona e vettore di prua nave
	var heading_deg: float = 0.0
	if SpaceWorldManager and SpaceWorldManager.has_method("get_spaceship"):
		var ship := SpaceWorldManager.get_spaceship()
		if ship and is_instance_valid(ship):
			heading_deg = rad_to_deg(ship.rotation.y)

	var heading_rad := deg_to_rad(heading_deg - 90.0) # -90 per allineare 0 deg a nord
	var forward_vec := Vector2(cos(heading_rad), sin(heading_rad))
	var arrow_len := 18.0 * zoom_level
	canvas.draw_line(ship_pos, ship_pos + forward_vec * arrow_len, Color(0.2, 1.0, 0.5, 1.0), 2.5)
	canvas.draw_circle(ship_pos, 4.0 * zoom_level, Color(0.2, 1.0, 0.5, 1.0))

	# Settore selezionato
	if has_selected_sector:
		var sel_pos := pan_offset + Vector2(selected_sector_coords.x * cell_size, selected_sector_coords.y * cell_size)
		var sel_rect := Rect2(sel_pos - Vector2(cell_size * 0.5, cell_size * 0.5), Vector2(cell_size, cell_size))
		canvas.draw_rect(sel_rect, Color(1.0, 0.85, 0.2, 0.2), true)
		canvas.draw_rect(sel_rect, Color(1.0, 0.85, 0.2, 0.9), false, 2.0)

		# Tracciamento linea di rotta se diversa da posizione nave
		if selected_sector_coords != cur_ship_coords:
			canvas.draw_line(ship_pos, sel_pos, Color(1.0, 0.8, 0.2, 0.75), 2.0)
			# Freccia di navigazione al termine
			var dir := (sel_pos - ship_pos).normalized()
			var p1 := sel_pos - dir * 12.0 + Vector2(-dir.y, dir.x) * 6.0
			var p2 := sel_pos - dir * 12.0 - Vector2(-dir.y, dir.x) * 6.0
			canvas.draw_line(sel_pos, p1, Color(1.0, 0.8, 0.2, 1.0), 2.0)
			canvas.draw_line(sel_pos, p2, Color(1.0, 0.8, 0.2, 1.0), 2.0)
