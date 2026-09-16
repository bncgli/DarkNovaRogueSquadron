class_name SystemDiscoverApp
extends BaseApp

## Applicazione diegetica GodotOS "System Discover" (Applications/SystemDiscover).
## Consente la generazione deterministica da seed di sistemi stellari completi
## con archetipi galattici, quote altimetriche volumetriche 3D, mappa olografica
## interattiva e persistenza su disco con hook diretto verso la Lobby.

const APP_TITLE: String = "System Discover"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(800, 560)
const MIN_WINDOW_SIZE: Vector2 = Vector2(760, 520)

const EXPORT_DIR_DIEGETIC: String = "user://files/Terminal Drive/Programs/SystemDiscover/"
const EXPORT_DIR_SYSTEMS: String = "user://star_systems/"

# Nodi UI - Pannello Sinistro
@onready var seed_input: LineEdit = %SeedInput
@onready var btn_reroll_seed: Button = %BtnRerollSeed
@onready var archetype_option: OptionButton = %ArchetypeOption
@onready var archetype_desc_label: Label = %ArchetypeDescLabel
@onready var spin_planets: SpinBox = %SpinPlanets
@onready var spin_spread_z: SpinBox = %SpinSpreadZ
@onready var btn_generate: Button = %BtnGenerate
@onready var btn_save: Button = %BtnSave
@onready var btn_send_lobby: Button = %BtnSendLobby
@onready var status_label: Label = %StatusLabel

# Nodi UI - Pannello Destro & Mappa Olografica
@onready var system_title_label: Label = %SystemTitleLabel
@onready var system_info_label: Label = %SystemInfoLabel
@onready var holographic_map: Control = %HolographicMap
@onready var body_inspector_label: RichTextLabel = %BodyInspectorLabel
@onready var btn_zoom_in: Button = %BtnZoomIn
@onready var btn_zoom_out: Button = %BtnZoomOut
@onready var btn_zoom_reset: Button = %BtnZoomReset

# Stato Corrente
var current_system: StarSystemData = null
var current_archetype: StarSystemGenerator.Archetype = StarSystemGenerator.Archetype.FRONTIER_EXPANSE
var selected_body_id: String = ""

# Parametri Canvas Olografico
var map_zoom: float = 1.0
var map_pan: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_pan: Vector2 = Vector2.ZERO

func _ready() -> void:
	_configure_window(APP_TITLE, DEFAULT_WINDOW_SIZE, MIN_WINDOW_SIZE)
	_init_archetype_options()
	_connect_ui_signals()
	
	# Seed iniziale casuale diegetico
	if seed_input and seed_input.text.is_empty():
		seed_input.text = StarSystemGenerator.generate_random_seed()
		
	# Generazione iniziale del sistema di default
	generate_system_from_ui()

func _init_archetype_options() -> void:
	if not archetype_option:
		return
	archetype_option.clear()
	archetype_option.add_item(StarSystemGenerator.get_archetype_name(StarSystemGenerator.Archetype.FRONTIER_EXPANSE), int(StarSystemGenerator.Archetype.FRONTIER_EXPANSE))
	archetype_option.add_item(StarSystemGenerator.get_archetype_name(StarSystemGenerator.Archetype.CORE_INDUSTRIAL), int(StarSystemGenerator.Archetype.CORE_INDUSTRIAL))
	archetype_option.add_item(StarSystemGenerator.get_archetype_name(StarSystemGenerator.Archetype.ANARCHY_PIRATE_SECTOR), int(StarSystemGenerator.Archetype.ANARCHY_PIRATE_SECTOR))
	archetype_option.add_item(StarSystemGenerator.get_archetype_name(StarSystemGenerator.Archetype.DEEP_EXPLORATION), int(StarSystemGenerator.Archetype.DEEP_EXPLORATION))
	archetype_option.selected = 0
	_update_archetype_description(0)

func _connect_ui_signals() -> void:
	if btn_reroll_seed:
		btn_reroll_seed.pressed.connect(_on_reroll_pressed)
	if archetype_option:
		archetype_option.item_selected.connect(_on_archetype_selected)
	if btn_generate:
		btn_generate.pressed.connect(_on_generate_pressed)
	if btn_save:
		btn_save.pressed.connect(_on_save_pressed)
	if btn_send_lobby:
		btn_send_lobby.pressed.connect(_on_send_to_lobby_pressed)
		
	if btn_zoom_in:
		btn_zoom_in.pressed.connect(func(): map_zoom = clampf(map_zoom * 1.25, 0.4, 3.5); if holographic_map: holographic_map.queue_redraw())
	if btn_zoom_out:
		btn_zoom_out.pressed.connect(func(): map_zoom = clampf(map_zoom / 1.25, 0.4, 3.5); if holographic_map: holographic_map.queue_redraw())
	if btn_zoom_reset:
		btn_zoom_reset.pressed.connect(func(): map_zoom = 1.0; map_pan = Vector2.ZERO; if holographic_map: holographic_map.queue_redraw())
		
	if holographic_map:
		holographic_map.draw.connect(_on_holographic_map_draw)
		holographic_map.gui_input.connect(_on_holographic_map_gui_input)

func _on_reroll_pressed() -> void:
	if seed_input:
		seed_input.text = StarSystemGenerator.generate_random_seed()
	generate_system_from_ui()

func _on_archetype_selected(index: int) -> void:
	var arch_id := archetype_option.get_item_id(index) as StarSystemGenerator.Archetype
	current_archetype = arch_id
	_update_archetype_description(index)
	generate_system_from_ui()

func _update_archetype_description(index: int) -> void:
	if archetype_desc_label and archetype_option:
		var arch_id := archetype_option.get_item_id(index) as StarSystemGenerator.Archetype
		archetype_desc_label.text = StarSystemGenerator.get_archetype_description(arch_id)

func _on_generate_pressed() -> void:
	generate_system_from_ui()

## Genera il sistema leggendo i parametri correnti dell'interfaccia
func generate_system_from_ui() -> void:
	var seed_text := seed_input.text.strip_edges() if seed_input else ""
	if seed_text.is_empty():
		seed_text = StarSystemGenerator.generate_random_seed()
		if seed_input:
			seed_input.text = seed_text
			
	var custom_params: Dictionary = {}
	if spin_planets and spin_planets.value > 0:
		custom_params["num_planets"] = int(spin_planets.value)
	if spin_spread_z and spin_spread_z.value > 0:
		custom_params["vertical_spread"] = int(spin_spread_z.value)
		
	current_system = StarSystemGenerator.generate_system(seed_text, current_archetype, custom_params)
	selected_body_id = ""
	
	_update_header_info()
	_update_body_inspector()
	
	if holographic_map:
		holographic_map.queue_redraw()
		
	if status_label:
		status_label.text = "Sistema %s generato con successo." % current_system.system_id
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))

func _update_header_info() -> void:
	if not current_system:
		return
	if system_title_label:
		system_title_label.text = "%s  [%s]" % [current_system.system_name, current_system.system_id]
	if system_info_label:
		var planet_count: int = 0
		var station_count: int = 0
		var wreck_count: int = 0
		for b in current_system.celestial_bodies:
			if b.type in ["PLANET", "GAS_GIANT"]:
				planet_count += 1
			elif b.type == "STATION":
				station_count += 1
			elif b.type == "WRECK":
				wreck_count += 1
		system_info_label.text = "Stella: %s | Pianeti: %d | Stazioni: %d | Relitti: %d" % [
			current_system.primary_star_name, planet_count, station_count, wreck_count
		]

func _update_body_inspector() -> void:
	if not body_inspector_label:
		return
	if not current_system:
		body_inspector_label.text = "[color=#888888]Nessun sistema caricato.[/color]"
		return
		
	if selected_body_id.is_empty():
		body_inspector_label.text = "[b]Riepilogo Sistema:[/b]\n%s\n[i]Clicca su un corpo per visualizzare telemetria astronomica e quota volumetrica.[/i]" % current_system.description
		return
		
	var body: CelestialBodyData = current_system.get_body(selected_body_id)
	if not body:
		body_inspector_label.text = "[color=#888888]Corpo non trovato.[/color]"
		return
		
	var elev_y: float = body.local_elevation if "local_elevation" in body else 0.0
	var z_coord: int = body.coords.z
	var text := "[b]%s[/b]  (Tipo: %s)\n" % [body.name, body.type]
	text += "Coordinate Griglia: [b](%d, %d, %d)[/b] | Quota 3D: [color=#00e5ff]%+.0f m[/color]\n" % [
		body.coords.x, body.coords.y, body.coords.z, elev_y
	]
	text += "Raggio: %.0f km | Massa: %.2e t | Temp: %.1f °C | Atmosfera: %s\n" % [
		body.radius_km, body.mass_tons, body.temperature, body.atmosphere
	]
	if body.resources.size() > 0:
		text += "Risorse Rilevate: [color=#aaffaa]%s[/color]\n" % ", ".join(body.resources)
	text += "[i]%s[/i]" % body.description
	body_inspector_label.text = text

## Rendering del Canvas Olografico Orbitale
func _on_holographic_map_draw() -> void:
	if not current_system or not holographic_map:
		return
		
	var center := holographic_map.size * 0.5 + map_pan
	var grid_scale := 16.0 * map_zoom
	
	# Assi e anelli di coordinate diegetici
	var ring_color := Color(0.12, 0.22, 0.35, 0.5)
	for r in [4, 8, 12, 16, 20]:
		holographic_map.draw_arc(center, float(r) * grid_scale, 0.0, TAU, 64, ring_color, 1.0)
	
	holographic_map.draw_line(Vector2(0, center.y), Vector2(holographic_map.size.x, center.y), Color(0.1, 0.18, 0.28, 0.6), 1.0)
	holographic_map.draw_line(Vector2(center.x, 0), Vector2(center.x, holographic_map.size.y), Color(0.1, 0.18, 0.28, 0.6), 1.0)
	
	# Disegna corpi celesti
	for b in current_system.celestial_bodies:
		var pos_2d := center + Vector2(float(b.coords.x) * grid_scale, float(b.coords.y) * grid_scale)
		var is_selected: bool = (b.id == selected_body_id)
		
		# Disegna indicatore quota altimetrica volumetrica 3D (leader line verticale)
		var z_val: int = b.coords.z
		var elev_y: float = b.local_elevation if "local_elevation" in b else 0.0
		if z_val != 0 or elev_y != 0.0:
			var height_offset_px := -float(z_val) * 7.0 * map_zoom
			var height_color := Color(0.0, 0.9, 1.0, 0.85) if z_val > 0 else Color(1.0, 0.4, 0.5, 0.85)
			# Linea di elevazione dal piano alla quota
			holographic_map.draw_line(pos_2d, pos_2d + Vector2(0, height_offset_px), height_color, 1.2)
			# Punto proiettato sul piano
			holographic_map.draw_circle(pos_2d, 2.0, Color(0.4, 0.6, 0.8, 0.5))
			# Etichetta altimetrica
			var elev_str := "z:%+d" % z_val
			holographic_map.draw_string(ThemeDB.fallback_font, pos_2d + Vector2(6, height_offset_px + 4), elev_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, height_color)
			pos_2d.y += height_offset_px

		# Disegna il corpo specifico
		match b.type:
			"STAR":
				var star_col: Color = current_system.primary_star_color
				holographic_map.draw_circle(pos_2d, 12.0 * map_zoom, star_col)
				holographic_map.draw_arc(pos_2d, 16.0 * map_zoom, 0.0, TAU, 32, Color(star_col.r, star_col.g, star_col.b, 0.4), 2.0)
			"PLANET":
				var p_col: Color = b.color if "color" in b else Color.AQUAMARINE
				holographic_map.draw_circle(pos_2d, 6.0 * map_zoom, p_col)
			"GAS_GIANT":
				var g_col: Color = b.color if "color" in b else Color.ORANGE
				holographic_map.draw_circle(pos_2d, 9.0 * map_zoom, g_col)
				holographic_map.draw_arc(pos_2d, 12.0 * map_zoom, -0.4, 3.5, 24, Color(1, 1, 1, 0.5), 1.5)
			"MOON":
				holographic_map.draw_circle(pos_2d, 3.5 * map_zoom, Color(0.8, 0.85, 0.9))
			"STATION":
				# Rombetto dorato per la stazione
				var size_st := 7.0 * map_zoom
				var points := PackedVector2Array([
					pos_2d + Vector2(0, -size_st),
					pos_2d + Vector2(size_st, 0),
					pos_2d + Vector2(0, size_st),
					pos_2d + Vector2(-size_st, 0)
				])
				holographic_map.draw_colored_polygon(points, Color(1.0, 0.85, 0.2))
			"ASTEROID_FIELD":
				holographic_map.draw_circle(pos_2d, 5.0 * map_zoom, Color(0.7, 0.6, 0.5, 0.8))
			"WRECK":
				# Icona a croce rossa
				var w_sz := 5.0 * map_zoom
				holographic_map.draw_line(pos_2d - Vector2(w_sz, w_sz), pos_2d + Vector2(w_sz, w_sz), Color(1.0, 0.3, 0.3), 1.5)
				holographic_map.draw_line(pos_2d - Vector2(-w_sz, w_sz), pos_2d + Vector2(-w_sz, w_sz), Color(1.0, 0.3, 0.3), 1.5)
			"BOUNTY_ZONE":
				# Triangolino corsaro
				var b_sz := 6.0 * map_zoom
				var b_pts := PackedVector2Array([
					pos_2d + Vector2(0, -b_sz),
					pos_2d + Vector2(b_sz, b_sz * 0.7),
					pos_2d + Vector2(-b_sz, b_sz * 0.7)
				])
				holographic_map.draw_colored_polygon(b_pts, Color(1.0, 0.2, 0.2))
			_:
				holographic_map.draw_circle(pos_2d, 4.0 * map_zoom, Color.WHITE)

		# Evidenziazione selezione
		if is_selected:
			holographic_map.draw_arc(pos_2d, 14.0 * map_zoom, 0.0, TAU, 32, Color(0.2, 1.0, 0.4), 1.5)
			
		# Nome etichetta corpo
		if b.type != "STAR" and map_zoom >= 0.7:
			var label_str: String = b.name.split(" ")[0]
			holographic_map.draw_string(ThemeDB.fallback_font, pos_2d + Vector2(8, 4), label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.75, 0.85, 0.95))

## Gestione input mouse e drag/selezione nella mappa olografica
func _on_holographic_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_start_mouse = event.position
				drag_start_pan = map_pan
				_check_click_body(event.position)
			else:
				is_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			map_zoom = clampf(map_zoom * 1.12, 0.4, 3.5)
			if holographic_map:
				holographic_map.queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			map_zoom = clampf(map_zoom / 1.12, 0.4, 3.5)
			if holographic_map:
				holographic_map.queue_redraw()
				
	elif event is InputEventMouseMotion and is_dragging:
		map_pan = drag_start_pan + (event.position - drag_start_mouse)
		if holographic_map:
			holographic_map.queue_redraw()

func _check_click_body(click_pos: Vector2) -> void:
	if not current_system or not holographic_map:
		return
	var center := holographic_map.size * 0.5 + map_pan
	var grid_scale := 16.0 * map_zoom
	var best_dist: float = 18.0 * map_zoom
	var clicked_id: String = ""
	
	for b in current_system.celestial_bodies:
		var pos_2d := center + Vector2(float(b.coords.x) * grid_scale, float(b.coords.y) * grid_scale)
		var z_val: int = b.coords.z
		if z_val != 0:
			pos_2d.y -= float(z_val) * 7.0 * map_zoom
		var d := click_pos.distance_to(pos_2d)
		if d < best_dist:
			best_dist = d
			clicked_id = b.id
			
	if not clicked_id.is_empty():
		selected_body_id = clicked_id
		_update_body_inspector()
		if holographic_map:
			holographic_map.queue_redraw()

## Salvataggio su disco in user://files/Terminal Drive/Programs/SystemDiscover/ e user://star_systems/
func _on_save_pressed() -> void:
	if not current_system:
		return
		
	var safe_id := current_system.system_id.to_lower().replace(" ", "_").replace("-", "_")
	var file_name := "%s.tres" % safe_id
	var json_name := "%s.json" % safe_id
	
	DirAccess.make_dir_recursive_absolute(EXPORT_DIR_DIEGETIC)
	DirAccess.make_dir_recursive_absolute(EXPORT_DIR_SYSTEMS)
	
	var diegetic_path := EXPORT_DIR_DIEGETIC + file_name
	var systems_path := EXPORT_DIR_SYSTEMS + file_name
	var json_path := EXPORT_DIR_DIEGETIC + json_name
	
	# Salva formato .tres nativo
	var err1 := ResourceSaver.save(current_system, diegetic_path)
	var err2 := ResourceSaver.save(current_system, systems_path)
	
	# Salva formato .json
	var jfile := FileAccess.open(json_path, FileAccess.WRITE)
	if jfile:
		jfile.store_string(JSON.stringify(current_system.to_dict(), "\t"))
		jfile.close()
		
	if err1 == OK or err2 == OK:
		if status_label:
			status_label.text = "Sistema salvato in Terminal Drive e star_systems."
			status_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	else:
		if status_label:
			status_label.text = "Errore durante il salvataggio su disco (%d)" % err1
			status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

## Invio diretto del sistema alla sessione attiva (Lobby & SpaceWorldManager)
func _on_send_to_lobby_pressed() -> void:
	send_to_lobby()

func send_to_lobby() -> void:
	if not current_system:
		return
		
	# Salva preliminarmente per sicurezza
	_on_save_pressed()
	
	# Aggiorna NetworkManager se presente
	var nm := get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("set_session_star_system"):
		nm.set_session_star_system(current_system)
		
	# Aggiorna SpaceWorldManager
	var swm := get_node_or_null("/root/SpaceWorldManager")
	if swm and swm.has_method("set_star_system_data"):
		swm.set_star_system_data(current_system)
		
	# Aggiorna StarSystemGridManager
	var grid_mgr := get_node_or_null("/root/StarSystemGridManager")
	if grid_mgr and grid_mgr.has_method("load_star_system"):
		grid_mgr.load_star_system(current_system)
		
	if status_label:
		status_label.text = "Sistema inviato con successo alla Lobby & Sessione attiva!"
		status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
