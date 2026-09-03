@tool
class_name ShipBlueprintCanvas
extends Control

## Canvas 2D interattivo per la visualizzazione e modifica di tutti i layer della nave.

signal element_selected(element_type: String, element_id: String, element_data: Dictionary)
signal element_modified(element_type: String, element_id: String, element_data: Dictionary)
signal cursor_coords_changed(world_pos: Vector2)
signal action_committed(action_name: String)
signal tool_changed(new_tool: int)

enum ToolMode {
	SELECT,
	ADD_ROOM,
	ADD_DUCT,
	DELETE
}

# Riferimento alla blueprint attiva
var blueprint: ShipBlueprint = null:
	set(val):
		blueprint = val
		selected_type = ""
		selected_id = ""
		queue_redraw()

# Modalità tool attiva
var current_tool: ToolMode = ToolMode.SELECT:
	set(val):
		current_tool = val
		_creation_step = 0
		is_dragging_element = false
		is_resizing_room = false
		is_panning = false
		queue_redraw()
		tool_changed.emit(val)

# Visibilità dei layer
var show_rooms: bool = true:
	set(val):
		show_rooms = val
		queue_redraw()

var show_ducts: bool = true:
	set(val):
		show_ducts = val
		queue_redraw()

var show_devices: bool = true:
	set(val):
		show_devices = val
		queue_redraw()

var show_damages: bool = true:
	set(val):
		show_damages = val
		queue_redraw()

var show_spawn: bool = true:
	set(val):
		show_spawn = val
		queue_redraw()

var show_bounds: bool = true:
	set(val):
		show_bounds = val
		queue_redraw()

var show_grid: bool = true:
	set(val):
		show_grid = val
		queue_redraw()

var show_labels: bool = true:
	set(val):
		show_labels = val
		queue_redraw()

var snap_enabled: bool = true
var snap_grid_size: float = 10.0

# Trasformazione vista (Pan & Zoom)
var view_offset: Vector2 = Vector2(80, 40)
var zoom_level: float = 1.0

# Stato selezione e manipolazione
var selected_type: String = "" # "room", "duct", "device", "damage", "spawn", "bounds"
var selected_id: String = ""
var selected_room_template: String = "ponte_comando":
	set(val):
		selected_room_template = val
		queue_redraw()
var _clipboard_type: String = ""
var _clipboard_data: Dictionary = {}
var is_dragging_element: bool = false
var drag_start_world_pos: Vector2 = Vector2.ZERO
var drag_element_start_state: Dictionary = {}
var _has_dragged_significantly: bool = false
var is_resizing_room: bool = false
var resize_handle_index: int = -1

# Navigazione vista (Pan)
var is_panning: bool = false
var pan_start_mouse_pos: Vector2 = Vector2.ZERO
var pan_start_view_offset: Vector2 = Vector2.ZERO

# Stato per creazione interattiva
var _creation_step: int = 0
var _creation_start_pos: Vector2 = Vector2.ZERO
var _creation_preview_pos: Vector2 = Vector2.ZERO

# Colori tema rendering
const COLOR_GRID_MAJOR: Color = Color(0.2, 0.25, 0.35, 0.45)
const COLOR_GRID_MINOR: Color = Color(0.15, 0.18, 0.24, 0.25)
const COLOR_SELECTION: Color = Color(1.0, 0.85, 0.2, 0.95)
const COLOR_BOUNDS: Color = Color(0.4, 0.6, 0.8, 0.6)

func _ready() -> void:
	clip_contents = true
	mouse_filter = MOUSE_FILTER_PASS

func _dict_to_rect2(v: Variant) -> Rect2:
	if v is Rect2: return v
	if v is Array and v.size() >= 4:
		return Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
	return Rect2()

func _dict_to_vec2(v: Variant) -> Vector2:
	if v is Vector2: return v
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return Vector2.ZERO

func set_zoom(new_zoom: float) -> void:
	zoom_level = clampf(new_zoom, 0.25, 4.0)
	queue_redraw()

func reset_view() -> void:
	if blueprint:
		var bounds: Rect2 = blueprint.ship_bounds
		var center: Vector2 = bounds.get_center()
		view_offset = (size * 0.5) - center
	else:
		view_offset = Vector2(80, 40)
	zoom_level = 1.0
	queue_redraw()

func world_to_screen(world_pos: Vector2) -> Vector2:
	return (world_pos * zoom_level) + view_offset

func screen_to_world(screen_pos: Vector2) -> Vector2:
	return (screen_pos - view_offset) / zoom_level

func snap_pos(raw_pos: Vector2) -> Vector2:
	if not snap_enabled or snap_grid_size <= 0.0:
		return raw_pos
	return (raw_pos / snap_grid_size).round() * snap_grid_size

func _gui_input(event: InputEvent) -> void:
	if not blueprint:
		return
		
	if event is InputEventMouseMotion:
		var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
		var world_pos: Vector2 = screen_to_world(mouse_event.position)
		var snapped_w: Vector2 = snap_pos(world_pos)
		cursor_coords_changed.emit(snapped_w)
		_creation_preview_pos = snapped_w
		
		if is_panning:
			view_offset = pan_start_view_offset + (mouse_event.position - pan_start_mouse_pos)
			queue_redraw()
		elif is_dragging_element or is_resizing_room:
			_handle_element_drag(world_pos)
		elif _creation_step > 0:
			queue_redraw()
		else:
			_update_mouse_cursor(world_pos)
			
	elif event is InputEventMouseButton:
		var btn_event: InputEventMouseButton = event as InputEventMouseButton
		var world_pos: Vector2 = screen_to_world(btn_event.position)
		var snapped_world: Vector2 = snap_pos(world_pos)
		
		# Zoom con rotellina del mouse centrato sul cursore
		if btn_event.button_index == MOUSE_BUTTON_WHEEL_UP and btn_event.pressed:
			var prev_world := screen_to_world(btn_event.position)
			zoom_level = clampf(zoom_level * 1.15, 0.25, 4.0)
			view_offset = btn_event.position - (prev_world * zoom_level)
			queue_redraw()
			accept_event()
			return
		elif btn_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and btn_event.pressed:
			var prev_world := screen_to_world(btn_event.position)
			zoom_level = clampf(zoom_level / 1.15, 0.25, 4.0)
			view_offset = btn_event.position - (prev_world * zoom_level)
			queue_redraw()
			accept_event()
			return
			
		# Pan con tasto centrale o tasto destro
		if btn_event.button_index == MOUSE_BUTTON_MIDDLE or btn_event.button_index == MOUSE_BUTTON_RIGHT:
			if btn_event.pressed:
				is_panning = true
				pan_start_mouse_pos = btn_event.position
				pan_start_view_offset = view_offset
			else:
				is_panning = false
			accept_event()
			return
			
		# Click sinistro per interazioni e strumenti
		if btn_event.button_index == MOUSE_BUTTON_LEFT:
			if btn_event.pressed:
				_handle_left_click_pressed(world_pos, snapped_world)
			else:
				_handle_left_click_released(world_pos, snapped_world)
			accept_event()
			return

func _handle_left_click_pressed(world_pos: Vector2, snapped_world: Vector2) -> void:
	match current_tool:
		ToolMode.SELECT:
			# Controlla se abbiamo cliccato su una maniglia di resize della stanza selezionata
			if selected_type == "room":
				var room := blueprint.get_room_by_id(selected_id)
				if room:
					var r_rect: Rect2 = room.rect
					var handle_idx := _get_resize_handle_at(world_pos, r_rect)
					if handle_idx != -1:
						is_resizing_room = true
						resize_handle_index = handle_idx
						drag_start_world_pos = snapped_world
						drag_element_start_state = room.to_dict()
						_has_dragged_significantly = false
						return

			# Altrimenti prova a selezionare un elemento cliccato
			var hit := _pick_element_at(world_pos)
			if not hit.is_empty():
				selected_type = str(hit["type"])
				selected_id = str(hit["id"])
				is_dragging_element = true
				drag_start_world_pos = snapped_world
				drag_element_start_state = (hit["data"] as Dictionary).duplicate(true)
				_has_dragged_significantly = false
				element_selected.emit(selected_type, selected_id, hit["data"])
			else:
				selected_type = ""
				selected_id = ""
				element_selected.emit("", "", {})
			queue_redraw()

		ToolMode.ADD_ROOM:
			if _creation_step == 0:
				_creation_start_pos = snapped_world
				_creation_step = 1
			else:
				_finish_add_room(_creation_start_pos, snapped_world)
				_creation_step = 0
			queue_redraw()

		ToolMode.ADD_DUCT:
			if _creation_step == 0:
				_creation_start_pos = snapped_world
				_creation_step = 1
			else:
				_finish_add_duct(_creation_start_pos, snapped_world)
				_creation_step = 0
			queue_redraw()

		ToolMode.DELETE:
			var hit_del := _pick_element_at(world_pos)
			if not hit_del.is_empty():
				delete_element(str(hit_del["type"]), str(hit_del["id"]))
			queue_redraw()

func _handle_left_click_released(world_pos: Vector2, snapped_world: Vector2) -> void:
	if is_resizing_room:
		is_resizing_room = false
		resize_handle_index = -1
		if selected_type == "room":
			var room := blueprint.get_room_by_id(selected_id)
			if _has_dragged_significantly and room:
				var new_rect: Rect2 = room.rect
				var old_rect := _dict_to_rect2(drag_element_start_state.get("rect"))
				room.rect = old_rect
				action_committed.emit("Ridimensiona Stanza")
				room.rect = new_rect
				blueprint.emit_changed()
			_has_dragged_significantly = false
			element_modified.emit("room", selected_id, room.to_dict() if room else {})
	elif is_dragging_element:
		is_dragging_element = false
		if _has_dragged_significantly and not selected_type.is_empty() and not selected_id.is_empty():
			var elem_current_data := _get_selected_element_data()
			_apply_element_state(selected_type, selected_id, drag_element_start_state)
			action_committed.emit("Sposta Elemento")
			_apply_element_state(selected_type, selected_id, elem_current_data)
			blueprint.emit_changed()
		_has_dragged_significantly = false
		if not selected_type.is_empty() and not selected_id.is_empty():
			var elem_data := _get_selected_element_data()
			element_modified.emit(selected_type, selected_id, elem_data)

func _apply_element_state(elem_type: String, elem_id: String, state: Dictionary) -> void:
	if not blueprint or state.is_empty():
		return
	match elem_type:
		"room":
			var r := blueprint.get_room_by_id(elem_id)
			if r and state.has("rect"):
				r.rect = _dict_to_rect2(state["rect"])
		"duct":
			var d := blueprint.get_duct_by_id(elem_id)
			if d:
				if state.has("from"): d.from = _dict_to_vec2(state["from"])
				if state.has("to"): d.to = _dict_to_vec2(state["to"])
		"damage":
			var dmg := blueprint.get_damage_by_id(elem_id)
			if dmg and state.has("pos"):
				dmg.pos = _dict_to_vec2(state["pos"])
		"spawn":
			if state.has("pos"): blueprint.drone_spawn_pos = _dict_to_vec2(state["pos"])
		"bounds":
			if state.has("bounds"): blueprint.ship_bounds = _dict_to_rect2(state["bounds"])

func _handle_element_drag(current_world_pos: Vector2) -> void:
	var snapped_world := snap_pos(current_world_pos)
	var delta_pos := snapped_world - drag_start_world_pos
	
	if is_resizing_room and selected_type == "room":
		var room := blueprint.get_room_by_id(selected_id)
		if not room:
			return
		var start_rect := _dict_to_rect2(drag_element_start_state.get("rect"))
		var new_rect := start_rect
		match resize_handle_index:
			0: # Top-Left
				new_rect.position += delta_pos
				new_rect.size -= delta_pos
			1: # Top-Right
				new_rect.position.y += delta_pos.y
				new_rect.size.y -= delta_pos.y
				new_rect.size.x += delta_pos.x
			2: # Bottom-Right
				new_rect.size += delta_pos
			3: # Bottom-Left
				new_rect.position.x += delta_pos.x
				new_rect.size.x -= delta_pos.x
				new_rect.size.y += delta_pos.y
		if new_rect.size.x >= 20.0 and new_rect.size.y >= 20.0:
			room.rect = new_rect
			_has_dragged_significantly = true
			blueprint.emit_changed()
			queue_redraw()
		return

	if not is_dragging_element or delta_pos == Vector2.ZERO:
		return

	_has_dragged_significantly = true

	match selected_type:
		"room":
			var r := blueprint.get_room_by_id(selected_id)
			if r:
				var orig_rect := _dict_to_rect2(drag_element_start_state.get("rect"))
				r.rect = Rect2(orig_rect.position + delta_pos, orig_rect.size)
				blueprint.emit_changed()
				queue_redraw()
		"duct":
			var d := blueprint.get_duct_by_id(selected_id)
			if d:
				var orig_from := _dict_to_vec2(drag_element_start_state.get("from"))
				var orig_to := _dict_to_vec2(drag_element_start_state.get("to"))
				d.from = orig_from + delta_pos
				d.to = orig_to + delta_pos
				blueprint.emit_changed()
				queue_redraw()
		"damage":
			var dmg := blueprint.get_damage_by_id(selected_id)
			if dmg:
				var orig_pos := _dict_to_vec2(drag_element_start_state.get("pos"))
				dmg.pos = orig_pos + delta_pos
				blueprint.emit_changed()
				queue_redraw()
		"spawn":
			var orig_pos := _dict_to_vec2(drag_element_start_state.get("pos"))
			blueprint.drone_spawn_pos = orig_pos + delta_pos
			blueprint.emit_changed()
			queue_redraw()
		"bounds":
			var orig_bounds := _dict_to_rect2(drag_element_start_state.get("bounds"))
			blueprint.ship_bounds = Rect2(orig_bounds.position + delta_pos, orig_bounds.size)
			blueprint.emit_changed()
			queue_redraw()

func _pick_element_at(world_pos: Vector2) -> Dictionary:
	var pick_rad := maxf(16.0, 14.0 / zoom_level)
	
	# Priorità di selezione: Spawn -> Danni -> Dispositivi -> Condotti -> Stanze -> Scafo
	if show_spawn:
		if world_pos.distance_to(blueprint.drone_spawn_pos) <= pick_rad:
			return {"type": "spawn", "id": "drone_spawn", "data": {"pos": blueprint.drone_spawn_pos, "heading": blueprint.drone_spawn_heading}}

	if show_damages:
		for dmg in blueprint.damages:
			var pos: Vector2 = dmg.pos
			if world_pos.distance_to(pos) <= pick_rad:
				return {"type": "damage", "id": dmg.id, "data": dmg.to_dict()}

	if show_ducts:
		for d in blueprint.ducts:
			var p1: Vector2 = d.from
			var p2: Vector2 = d.to
			var w: float = d.width
			if _distance_to_segment(world_pos, p1, p2) <= maxf(w * 0.5 + 4.0, 8.0 / zoom_level):
				return {"type": "duct", "id": d.id, "data": d.to_dict()}

	if show_rooms:
		for r in blueprint.rooms:
			var rect: Rect2 = r.rect
			if rect.has_point(world_pos):
				return {"type": "room", "id": r.id, "data": r.to_dict(), "rect": rect}

	if show_bounds:
		var b: Rect2 = blueprint.ship_bounds
		var border_box := Rect2(b.position - Vector2(8, 8), b.size + Vector2(16, 16))
		var inner_box := Rect2(b.position + Vector2(8, 8), b.size - Vector2(16, 16))
		if border_box.has_point(world_pos) and not inner_box.has_point(world_pos):
			return {"type": "bounds", "id": "ship_bounds", "data": {"bounds": blueprint.ship_bounds}}

	return {}

func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ab_len_sq := ab.length_squared()
	if ab_len_sq == 0.0:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var projection := a + ab * t
	return p.distance_to(projection)

func _update_mouse_cursor(world_pos: Vector2) -> void:
	if current_tool != ToolMode.SELECT:
		mouse_default_cursor_shape = Control.CURSOR_CROSS
		return
		
	if selected_type == "room":
		var room := blueprint.get_room_by_id(selected_id)
		if room:
			var handle_idx := _get_resize_handle_at(world_pos, room.rect)
			match handle_idx:
				0, 2: 
					mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
					return
				1, 3:
					mouse_default_cursor_shape = Control.CURSOR_BDIAGSIZE
					return
					
	var hit := _pick_element_at(world_pos)
	if not hit.is_empty():
		mouse_default_cursor_shape = Control.CURSOR_MOVE
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW

func _get_resize_handle_at(world_pos: Vector2, rect: Rect2) -> int:
	var handles: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]
	var hit_dist := maxf(10.0, 10.0 / zoom_level)
	for i in range(handles.size()):
		if world_pos.distance_to(handles[i]) <= hit_dist:
			return i
	return -1

func _get_selected_element_data() -> Dictionary:
	if not blueprint:
		return {}
	match selected_type:
		"room":
			return blueprint.get_room_by_id(selected_id).to_dict()
		"duct":
			return blueprint.get_duct_by_id(selected_id).to_dict()
		"damage":
			return blueprint.get_damage_by_id(selected_id).to_dict()
		"device":
			var dev := blueprint.get_device_by_id(selected_id)
			return dev.to_dict() if dev else {}
		"spawn":
			return {"pos": blueprint.drone_spawn_pos, "heading": blueprint.drone_spawn_heading}
		"bounds":
			return {"bounds": blueprint.ship_bounds}
	return {}

# --- CLIPBOARD (COPY-PASTE) ---

func copy_selection() -> void:
	if selected_type.is_empty() or selected_id.is_empty():
		return
	
	var data := _get_selected_element_data()
	if not data.is_empty():
		_clipboard_type = selected_type
		_clipboard_data = data.duplicate(true)
		# Se è uno spawn o i bordi, non ha senso copiarli di solito, ma seguiamo la logica
		# Per le stanze/nodi, rimuoviamo l'ID in modo che il paste ne generi uno nuovo
		if _clipboard_data.has("id"):
			_clipboard_data.erase("id")

func paste_selection(offset: Vector2 = Vector2(20, 20)) -> void:
	if _clipboard_type.is_empty() or _clipboard_data.is_empty():
		return
		
	var data_to_paste := _clipboard_data.duplicate(true)
	
	match _clipboard_type:
		"room":
			var rect := _dict_to_rect2(data_to_paste.get("rect"))
			var new_p1 := rect.position + offset
			var new_p2 := new_p1 + rect.size
			_finish_add_room(new_p1, new_p2)
			var new_room := blueprint.get_room_by_id(selected_id)
			if new_room:
				var old_id := new_room.id
				new_room.from_dict(data_to_paste)
				new_room.id = old_id
				new_room.rect = Rect2(new_p1, rect.size)
		"duct":
			var p1 := _dict_to_vec2(data_to_paste.get("from"))
			var p2 := _dict_to_vec2(data_to_paste.get("to"))
			_finish_add_duct(p1 + offset, p2 + offset)
			var new_duct := blueprint.get_duct_by_id(selected_id)
			if new_duct:
				var old_id := new_duct.id
				new_duct.from_dict(data_to_paste)
				new_duct.id = old_id
				new_duct.from = p1 + offset
				new_duct.to = p2 + offset
		"damage":
			var pos := _dict_to_vec2(data_to_paste.get("pos"))
			_finish_add_damage(pos + offset)
			var new_dmg: ShipDamageData = blueprint.get_damage_by_id(selected_id)
			if new_dmg:
				var old_id := new_dmg.id
				new_dmg.from_dict(data_to_paste)
				new_dmg.id = old_id
				new_dmg.pos = pos + offset
	
	blueprint.emit_changed()
	queue_redraw()

# --- CREAZIONE NUOVI ELEMENTI ---

func _finish_add_room(p1: Vector2, p2: Vector2) -> void:
	var template_data := RoomDatabase.get_room_data(selected_room_template)
	var min_size: Vector2 = template_data.min_size
	
	var top_left := Vector2(minf(p1.x, p2.x), minf(p1.y, p2.y))
	var size_rect := (p2 - p1).abs()
	
	# Applica dimensioni minime
	if size_rect.x < min_size.x: size_rect.x = min_size.x
	if size_rect.y < min_size.y: size_rect.y = min_size.y
	
	var next_idx := blueprint.rooms.size() + 1
	var new_id := "room_%d" % next_idx
	while blueprint.get_room_by_id(new_id):
		next_idx += 1
		new_id = "room_%d" % next_idx
		
	var room_name: String = template_data.name
	
	var new_room := ShipRoomData.new(new_id, room_name, Rect2(top_left, size_rect))
	new_room.color = template_data.color
	new_room.border_color = Color(0.4, 0.7, 0.9, 0.8)
	new_room.category = template_data.category
	new_room.default_devices = template_data.default_devices
	
	action_committed.emit("Aggiungi Stanza: " + room_name)
	blueprint.rooms.append(new_room)
	
	blueprint.emit_changed()
	selected_type = "room"
	selected_id = new_id
	element_selected.emit(selected_type, selected_id, new_room.to_dict())
	current_tool = ToolMode.SELECT
	tool_changed.emit(ToolMode.SELECT)

func _finish_add_duct(p1: Vector2, p2: Vector2) -> void:
	if p1.distance_to(p2) < 10.0:
		p2 = p1 + Vector2(60, 0)
	var next_idx := blueprint.ducts.size() + 1
	var new_id := "duct_%d" % next_idx
	while blueprint.get_duct_by_id(new_id):
		next_idx += 1
		new_id = "duct_%d" % next_idx
	var new_duct := ShipDuctData.new(new_id, "Condotto %d" % next_idx, p1, p2)
	new_duct.width = 14.0
	new_duct.is_blocked = false
	
	action_committed.emit("Aggiungi Condotto")
	blueprint.ducts.append(new_duct)
	blueprint.emit_changed()
	selected_type = "duct"
	selected_id = new_id
	element_selected.emit(selected_type, selected_id, new_duct.to_dict())
	current_tool = ToolMode.SELECT
	tool_changed.emit(ToolMode.SELECT)

func _finish_add_damage(pos: Vector2) -> void:
	var next_idx := blueprint.damages.size() + 1
	var new_id := "dmg_%d" % next_idx
	while blueprint.get_damage_by_id(new_id):
		next_idx += 1
		new_id = "dmg_%d" % next_idx
	
	var new_dmg := ShipDamageData.new(new_id, "Nuovo Punto di Danno %d" % next_idx, pos)
	new_dmg.type = "breach"
	new_dmg.sector = "Sconosciuto"
	new_dmg.severity = 5.0
	new_dmg.repair_cost = 10.0
	new_dmg.desc = "Nuovo danno strutturale."
	new_dmg.system_impact = "none"
	
	action_committed.emit("Aggiungi Danno")
	blueprint.damages.append(new_dmg)
	blueprint.emit_changed()
	selected_type = "damage"
	selected_id = new_id
	element_selected.emit(selected_type, selected_id, new_dmg.to_dict())
	current_tool = ToolMode.SELECT
	tool_changed.emit(ToolMode.SELECT)

func delete_element(elem_type: String, elem_id: String) -> void:
	if not blueprint:
		return
	action_committed.emit("Elimina Elemento")
	match elem_type:
		"room":
			blueprint.remove_room(elem_id)
		"duct":
			blueprint.remove_duct(elem_id)
		"device":
			blueprint.remove_device(elem_id)
		"damage":
			blueprint.remove_damage(elem_id)
	if selected_id == elem_id:
		selected_type = ""
		selected_id = ""
		element_selected.emit("", "", {})
	blueprint.emit_changed()
	queue_redraw()

# --- RENDERING CANVAS (_draw) ---

func _draw() -> void:
	# Sfondo scuro viewport
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.08, 0.12, 1.0), true)
	
	if show_grid:
		_draw_grid()
		
	if not blueprint:
		var font: Font = ThemeDB.fallback_font
		draw_string(font, size * 0.5 - Vector2(120, 0), "Nessuna Blueprint Caricata", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0.6, 0.6, 0.6))
		return

	# Disegna limite scafo/bounds
	if show_bounds:
		var screen_bounds_pos := world_to_screen(blueprint.ship_bounds.position)
		var screen_bounds_size: Vector2 = blueprint.ship_bounds.size * zoom_level
		var is_bounds_sel := (selected_type == "bounds")
		var b_col := COLOR_SELECTION if is_bounds_sel else COLOR_BOUNDS
		var b_w := 3.0 if is_bounds_sel else 2.0
		draw_rect(Rect2(screen_bounds_pos, screen_bounds_size), b_col, false, b_w)
		if show_labels and zoom_level >= 0.7:
			var font: Font = ThemeDB.fallback_font
			draw_string(font, screen_bounds_pos + Vector2(6, -6), "Scafo / Limiti: %s" % str(blueprint.ship_bounds.size), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, b_col)

	if show_rooms:
		_draw_rooms()
		
	if show_ducts:
		_draw_ducts()
		
	if show_damages:
		_draw_damages()
		
	if show_spawn:
		_draw_drone_spawn()
		
	# Disegna anteprima di creazione in corso
	_draw_creation_preview()

func _draw_grid() -> void:
	var step := snap_grid_size * zoom_level
	if step < 6.0:
		step *= 5.0 # evita linee troppo fitte con zoom ridotto
	var start_x := fmod(view_offset.x, step)
	var start_y := fmod(view_offset.y, step)
	
	var x := start_x
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), COLOR_GRID_MINOR, 1.0)
		x += step
		
	var y := start_y
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), COLOR_GRID_MINOR, 1.0)
		y += step

func _draw_rooms() -> void:
	var font: Font = ThemeDB.fallback_font
	for r in blueprint.rooms:
		var rect: Rect2 = r.rect
		var col: Color = r.color
		var border_col: Color = r.border_color
		var screen_rect := Rect2(world_to_screen(rect.position), rect.size * zoom_level)
		
		var is_selected: bool = (selected_type == "room" and selected_id == r.id)
		
		# Riempimento (se spenta, scuriamo)
		var is_on: bool = r.is_on
		var fill_col := col
		if not is_on:
			fill_col = col.lerp(Color.BLACK, 0.4)
			fill_col.a = col.a * 0.8
			
		draw_rect(screen_rect, fill_col, true)
		
		# Bordo
		var b_color := COLOR_SELECTION if is_selected else border_col
		if not is_on and not is_selected:
			b_color = border_col.lerp(Color.BLACK, 0.3)
		var b_width := 3.0 if is_selected else 1.5
		draw_rect(screen_rect, b_color, false, b_width)
		
		# Feedback speciale TASK-019: Stanza Ricarica
		if blueprint.recharge_room_id == r.id:
			var recharge_col := Color(0.9, 1.0, 0.2, 0.9)
			var pulse := (sin(Time.get_ticks_msec() * 0.005) * 0.5 + 0.5) * 0.3 + 0.7
			recharge_col.a *= pulse
			draw_rect(screen_rect.grow(4 * zoom_level), recharge_col, false, 2.5 * zoom_level)
		
		# Etichetta Nome Stanza
		if show_labels:
			var label_str: String = r.name
			var label_pos := screen_rect.position + Vector2(6, 16 * zoom_level)
			var font_sz: int = int(clampf(12.0 * zoom_level, 9.0, 16.0))
			draw_string(font, label_pos, label_str, HORIZONTAL_ALIGNMENT_LEFT, int(screen_rect.size.x - 12), font_sz, Color(0.9, 0.95, 1.0, 0.9))
			
		# Maniglie di ridimensionamento se selezionata
		if is_selected:
			_draw_resize_handles(screen_rect)

func _draw_resize_handles(screen_rect: Rect2) -> void:
	var handles: Array[Vector2] = [
		screen_rect.position,
		Vector2(screen_rect.end.x, screen_rect.position.y),
		screen_rect.end,
		Vector2(screen_rect.position.x, screen_rect.end.y)
	]
	for h in handles:
		draw_rect(Rect2(h - Vector2(5, 5), Vector2(10, 10)), COLOR_SELECTION, true)
		draw_rect(Rect2(h - Vector2(5, 5), Vector2(10, 10)), Color.BLACK, false, 1.0)

func _draw_ducts() -> void:
	var font: Font = ThemeDB.fallback_font
	for d in blueprint.ducts:
		var p1: Vector2 = d.from
		var p2: Vector2 = d.to
		var width: float = d.width * zoom_level
		var is_selected: bool = (selected_type == "duct" and selected_id == d.id)
		var sp1 := world_to_screen(p1)
		var sp2 := world_to_screen(p2)
		
		# Tubo / Condotto
		var pipe_color := Color(0.12, 0.45, 0.65, 0.7)
		if is_selected:
			pipe_color = COLOR_SELECTION
		elif d.is_blocked:
			pipe_color = Color(0.8, 0.25, 0.2, 0.7)
			
		draw_line(sp1, sp2, Color(0.04, 0.15, 0.22, 0.9), width + 4.0) # Bordo scuro
		draw_line(sp1, sp2, pipe_color, width)
		draw_circle(sp1, width * 0.5, pipe_color)
		draw_circle(sp2, width * 0.5, pipe_color)
		
		# Linea tratteggiata di flusso interna
		draw_dashed_line(sp1, sp2, Color(0.7, 0.9, 1.0, 0.8), 1.5, 6.0 * zoom_level)

		if show_labels and zoom_level >= 0.8:
			var mid_point := (sp1 + sp2) * 0.5
			var duct_name: String = d.name
			draw_string(font, mid_point + Vector2(4, -4), duct_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.8, 1.0, 0.85))

func _draw_damages() -> void:
	var font: Font = ThemeDB.fallback_font
	for dmg in blueprint.damages:
		var pos: Vector2 = dmg.pos
		var spos := world_to_screen(pos)
		var is_selected: bool = (selected_type == "damage" and selected_id == dmg.id)
		var dmg_type: String = dmg.type
		var sev: float = dmg.severity
		
		var radius := (8.0 + sev * 0.8) * zoom_level
		var dmg_color := Color(1.0, 0.25, 0.25, 0.75) if dmg_type == "breach" else Color(1.0, 0.8, 0.15, 0.75)
		if is_selected:
			dmg_color = COLOR_SELECTION
			
		# Area di danno circolare
		draw_circle(spos, radius, Color(dmg_color.r, dmg_color.g, dmg_color.b, 0.25))
		draw_circle(spos, radius, dmg_color, false, 2.0)
		draw_circle(spos, 3.0 * zoom_level, dmg_color, true)
		
		if show_labels and zoom_level >= 0.7:
			var dmg_name: String = dmg.name
			draw_string(font, spos + Vector2(12, -4), dmg_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.5, 0.5, 0.9))

func _draw_drone_spawn() -> void:
	var spos := world_to_screen(blueprint.drone_spawn_pos)
	var is_selected: bool = (selected_type == "spawn")
	var spawn_col := COLOR_SELECTION if is_selected else Color(0.2, 0.9, 0.4, 0.95)
	
	# Cerchio spawn
	draw_circle(spos, 10.0 * zoom_level, Color(0.1, 0.3, 0.15, 0.6))
	draw_circle(spos, 10.0 * zoom_level, spawn_col, false, 2.0)
	
	# Freccia heading
	var heading: float = blueprint.drone_spawn_heading
	var arrow_dir := Vector2(cos(heading), sin(heading)) * 18.0 * zoom_level
	draw_line(spos, spos + arrow_dir, spawn_col, 2.5)

func _draw_creation_preview() -> void:
	if _creation_step <= 0:
		return
	var sp1 := world_to_screen(_creation_start_pos)
	var sp2 := world_to_screen(_creation_preview_pos)

	match current_tool:
		ToolMode.ADD_ROOM:
			var top_left := Vector2(minf(sp1.x, sp2.x), minf(sp1.y, sp2.y))
			var sz := (sp2 - sp1).abs()
			draw_rect(Rect2(top_left, sz), Color(0.2, 0.6, 0.9, 0.3), true)
			draw_rect(Rect2(top_left, sz), Color(0.4, 0.8, 1.0, 0.9), false, 2.0)
		ToolMode.ADD_DUCT:
			draw_line(sp1, sp2, Color(0.2, 0.8, 1.0, 0.8), 14.0 * zoom_level)
		ToolMode.SELECT:
			pass
		ToolMode.DELETE:
			pass
