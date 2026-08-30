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
	ADD_DEVICE,
	ADD_JUNCTION,
	ADD_CONDUIT,
	ADD_DAMAGE,
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
		queue_redraw()

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

var show_junctions: bool = true:
	set(val):
		show_junctions = val
		queue_redraw()

var show_conduits: bool = true:
	set(val):
		show_conduits = val
		queue_redraw()

var show_power_grid: bool:
	get:
		return show_devices or show_junctions or show_conduits
	set(val):
		show_devices = val
		show_junctions = val
		show_conduits = val
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
var selected_type: String = "" # "room", "duct", "device", "junction", "conduit", "damage", "spawn", "bounds"
var selected_id: String = ""
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
		emit_signal("cursor_coords_changed", snapped_w)
		_creation_preview_pos = snapped_w
		
		if is_panning:
			view_offset = pan_start_view_offset + (mouse_event.position - pan_start_mouse_pos)
			queue_redraw()
		elif is_dragging_element:
			_handle_element_drag(world_pos)
		elif _creation_step > 0:
			queue_redraw()
			
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
				if not room.is_empty():
					var r_rect: Rect2 = room.get("rect", Rect2())
					var handle_idx := _get_resize_handle_at(world_pos, r_rect)
					if handle_idx != -1:
						is_resizing_room = true
						resize_handle_index = handle_idx
						drag_start_world_pos = snapped_world
						drag_element_start_state = room.duplicate(true)
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
				emit_signal("element_selected", selected_type, selected_id, hit["data"])
			else:
				selected_type = ""
				selected_id = ""
				emit_signal("element_selected", "", "", {})
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

		ToolMode.ADD_DEVICE:
			_finish_add_device(snapped_world)
			queue_redraw()

		ToolMode.ADD_JUNCTION:
			_finish_add_junction(snapped_world)
			queue_redraw()

		ToolMode.ADD_CONDUIT:
			if _creation_step == 0:
				_creation_start_pos = snapped_world
				_creation_step = 1
			else:
				_finish_add_conduit(_creation_start_pos, snapped_world)
				_creation_step = 0
			queue_redraw()

		ToolMode.ADD_DAMAGE:
			_finish_add_damage(snapped_world)
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
			if _has_dragged_significantly:
				emit_signal("action_committed", "Ridimensiona Stanza")
			emit_signal("element_modified", "room", selected_id, room)
	elif is_dragging_element:
		is_dragging_element = false
		if _has_dragged_significantly:
			emit_signal("action_committed", "Sposta Elemento")
		if not selected_type.is_empty() and not selected_id.is_empty():
			var elem_data := _get_selected_element_data()
			emit_signal("element_modified", selected_type, selected_id, elem_data)

func _handle_element_drag(current_world_pos: Vector2) -> void:
	var snapped_world := snap_pos(current_world_pos)
	var delta_pos := snapped_world - drag_start_world_pos
	
	if is_resizing_room and selected_type == "room":
		var room := blueprint.get_room_by_id(selected_id)
		if room.is_empty():
			return
		var start_rect: Rect2 = drag_element_start_state.get("rect", Rect2())
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
			room["rect"] = new_rect
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
			if not r.is_empty():
				var orig_rect: Rect2 = drag_element_start_state.get("rect", Rect2())
				r["rect"] = Rect2(orig_rect.position + delta_pos, orig_rect.size)
				blueprint.emit_changed()
				queue_redraw()
		"duct":
			var d := blueprint.get_duct_by_id(selected_id)
			if not d.is_empty():
				var orig_from: Vector2 = drag_element_start_state.get("from", Vector2.ZERO)
				var orig_to: Vector2 = drag_element_start_state.get("to", Vector2.ZERO)
				d["from"] = orig_from + delta_pos
				d["to"] = orig_to + delta_pos
				blueprint.emit_changed()
				queue_redraw()
		"device":
			var dev := blueprint.get_device_by_id(selected_id)
			if not dev.is_empty():
				var orig_pos: Vector2 = drag_element_start_state.get("pos", Vector2.ZERO)
				dev["pos"] = orig_pos + delta_pos
				blueprint.emit_changed()
				queue_redraw()
		"junction":
			var j := blueprint.get_junction_by_id(selected_id)
			if not j.is_empty():
				var orig_pos: Vector2 = drag_element_start_state.get("pos", Vector2.ZERO)
				j["pos"] = orig_pos + delta_pos
				blueprint.emit_changed()
				queue_redraw()
		"conduit":
			var c := blueprint.get_conduit_by_id(selected_id)
			if not c.is_empty():
				var orig_from: Vector2 = drag_element_start_state.get("from_pos", Vector2.ZERO)
				var orig_to: Vector2 = drag_element_start_state.get("to_pos", Vector2.ZERO)
				c["from_pos"] = orig_from + delta_pos
				c["to_pos"] = orig_to + delta_pos
				blueprint.emit_changed()
				queue_redraw()
		"damage":
			var dmg := blueprint.get_damage_by_id(selected_id)
			if not dmg.is_empty():
				var orig_pos: Vector2 = drag_element_start_state.get("pos", Vector2.ZERO)
				dmg["pos"] = orig_pos + delta_pos
				blueprint.emit_changed()
				queue_redraw()
		"spawn":
			var orig_pos: Vector2 = drag_element_start_state.get("pos", Vector2.ZERO)
			blueprint.drone_spawn_pos = orig_pos + delta_pos
			blueprint.emit_changed()
			queue_redraw()
		"bounds":
			var orig_bounds: Rect2 = drag_element_start_state.get("bounds", Rect2())
			blueprint.ship_bounds = Rect2(orig_bounds.position + delta_pos, orig_bounds.size)
			blueprint.emit_changed()
			queue_redraw()

func _pick_element_at(world_pos: Vector2) -> Dictionary:
	var pick_rad := maxf(16.0, 14.0 / zoom_level)
	
	# Priorità di selezione: Spawn -> Danni -> Snodi -> Dispositivi -> Cablaggi -> Condotti -> Stanze -> Scafo
	if show_spawn:
		if world_pos.distance_to(blueprint.drone_spawn_pos) <= pick_rad:
			return {"type": "spawn", "id": "drone_spawn", "data": {"pos": blueprint.drone_spawn_pos, "heading": blueprint.drone_spawn_heading}}

	if show_damages:
		for dmg in blueprint.damages:
			var pos: Vector2 = dmg.get("pos", Vector2.ZERO)
			if world_pos.distance_to(pos) <= pick_rad:
				return {"type": "damage", "id": dmg.get("id", ""), "data": dmg}

	if show_junctions:
		for j in blueprint.junctions:
			var pos: Vector2 = j.get("pos", Vector2.ZERO)
			if world_pos.distance_to(pos) <= pick_rad:
				return {"type": "junction", "id": j.get("id", ""), "data": j}

	if show_devices:
		for dev in blueprint.devices:
			var pos: Vector2 = dev.get("pos", Vector2.ZERO)
			var box := Rect2(pos - Vector2(16, 16), Vector2(32, 32))
			if box.has_point(world_pos) or world_pos.distance_to(pos) <= pick_rad:
				return {"type": "device", "id": dev.get("id", ""), "data": dev}

	if show_conduits:
		for c in blueprint.conduits:
			var p1: Vector2 = c.get("from_pos", Vector2.ZERO)
			var p2: Vector2 = c.get("to_pos", Vector2.ZERO)
			if _distance_to_segment(world_pos, p1, p2) <= maxf(8.0, 6.0 / zoom_level):
				return {"type": "conduit", "id": c.get("id", ""), "data": c}

	if show_ducts:
		for d in blueprint.ducts:
			var p1: Vector2 = d.get("from", Vector2.ZERO)
			var p2: Vector2 = d.get("to", Vector2.ZERO)
			var w: float = float(d.get("width", 14.0))
			if _distance_to_segment(world_pos, p1, p2) <= maxf(w * 0.5 + 4.0, 8.0 / zoom_level):
				return {"type": "duct", "id": d.get("id", ""), "data": d}

	if show_rooms:
		for r in blueprint.rooms:
			var rect: Rect2 = r.get("rect", Rect2())
			if rect.has_point(world_pos):
				return {"type": "room", "id": r.get("id", ""), "data": r}

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

func _get_resize_handle_at(world_pos: Vector2, rect: Rect2) -> int:
	var handles: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]
	var hit_dist := maxf(8.0, 8.0 / zoom_level)
	for i in range(handles.size()):
		if world_pos.distance_to(handles[i]) <= hit_dist:
			return i
	return -1

func _get_selected_element_data() -> Dictionary:
	if not blueprint:
		return {}
	match selected_type:
		"room":
			return blueprint.get_room_by_id(selected_id)
		"duct":
			return blueprint.get_duct_by_id(selected_id)
		"device":
			return blueprint.get_device_by_id(selected_id)
		"junction":
			return blueprint.get_junction_by_id(selected_id)
		"conduit":
			return blueprint.get_conduit_by_id(selected_id)
		"damage":
			return blueprint.get_damage_by_id(selected_id)
		"spawn":
			return {"pos": blueprint.drone_spawn_pos, "heading": blueprint.drone_spawn_heading}
		"bounds":
			return {"bounds": blueprint.ship_bounds}
	return {}

# --- CREAZIONE NUOVI ELEMENTI ---

func _finish_add_room(p1: Vector2, p2: Vector2) -> void:
	var top_left := Vector2(minf(p1.x, p2.x), minf(p1.y, p2.y))
	var size_rect := (p2 - p1).abs()
	if size_rect.x < 20.0 or size_rect.y < 20.0:
		size_rect = Vector2(80, 60)
	var next_idx := blueprint.rooms.size() + 1
	var new_id := "room_%d" % next_idx
	var new_room: Dictionary = {
		"id": new_id,
		"name": "Nuovo Settore %d" % next_idx,
		"rect": Rect2(top_left, size_rect),
		"color": Color(0.2, 0.3, 0.45, 0.5),
		"border_color": Color(0.4, 0.7, 0.9, 0.8),
		"category": "utility"
	}
	emit_signal("action_committed", "Aggiungi Stanza")
	blueprint.rooms.append(new_room)
	blueprint.emit_changed()
	selected_type = "room"
	selected_id = new_id
	emit_signal("element_selected", selected_type, selected_id, new_room)
	current_tool = ToolMode.SELECT
	emit_signal("tool_changed", ToolMode.SELECT)

func _finish_add_duct(p1: Vector2, p2: Vector2) -> void:
	if p1.distance_to(p2) < 10.0:
		p2 = p1 + Vector2(60, 0)
	var next_idx := blueprint.ducts.size() + 1
	var new_id := "duct_%d" % next_idx
	var new_duct: Dictionary = {
		"id": new_id,
		"name": "Condotto %d" % next_idx,
		"from": p1,
		"to": p2,
		"width": 14.0,
		"is_blocked": false
	}
	emit_signal("action_committed", "Aggiungi Condotto")
	blueprint.ducts.append(new_duct)
	blueprint.emit_changed()
	selected_type = "duct"
	selected_id = new_id
	emit_signal("element_selected", selected_type, selected_id, new_duct)
	current_tool = ToolMode.SELECT
	emit_signal("tool_changed", ToolMode.SELECT)

func _finish_add_device(pos: Vector2) -> void:
	var next_idx := blueprint.devices.size() + 1
	var new_id := "device_%d" % next_idx
	var room_here := blueprint.get_room_at(pos)
	var sector_name := str(room_here.get("name", "Generale")) if not room_here.is_empty() else "Nave"
	var new_dev: Dictionary = {
		"id": new_id,
		"name": "Dispositivo %d" % next_idx,
		"sector": sector_name,
		"pos": pos,
		"is_generator": false,
		"power_mw": 100.0,
		"inputs_count": 1,
		"desc": "Nuovo dispositivo della rete elettrica."
	}
	emit_signal("action_committed", "Aggiungi Dispositivo")
	blueprint.devices.append(new_dev)
	blueprint.emit_changed()
	selected_type = "device"
	selected_id = new_id
	emit_signal("element_selected", selected_type, selected_id, new_dev)
	current_tool = ToolMode.SELECT
	emit_signal("tool_changed", ToolMode.SELECT)

func _finish_add_junction(pos: Vector2) -> void:
	var next_idx := blueprint.junctions.size() + 1
	var new_id := "J%d" % next_idx
	var new_junc: Dictionary = {
		"id": new_id,
		"name": "Snodo %s" % new_id,
		"pos": pos,
		"input_source": "reactor_main",
		"active_branch": 0,
		"branches": [
			{"name": "Ramo Principale", "target_type": "dead_end", "target_id": "DEAD_1", "line_id": "L_%s_B0" % new_id, "to_pos": pos + Vector2(40, 0)}
		]
	}
	emit_signal("action_committed", "Aggiungi Snodo")
	blueprint.junctions.append(new_junc)
	blueprint.emit_changed()
	selected_type = "junction"
	selected_id = new_id
	emit_signal("element_selected", selected_type, selected_id, new_junc)
	current_tool = ToolMode.SELECT
	emit_signal("tool_changed", ToolMode.SELECT)

func _finish_add_conduit(p1: Vector2, p2: Vector2) -> void:
	if p1.distance_to(p2) < 10.0:
		p2 = p1 + Vector2(60, 0)
	var next_idx := blueprint.conduits.size() + 1
	var new_id := "CND_%d" % next_idx
	var new_cnd: Dictionary = {
		"id": new_id,
		"from_pos": p1,
		"to_pos": p2,
		"from_junction": "",
		"target_id": ""
	}
	emit_signal("action_committed", "Aggiungi Cablaggio")
	blueprint.conduits.append(new_cnd)
	blueprint.emit_changed()
	selected_type = "conduit"
	selected_id = new_id
	emit_signal("element_selected", selected_type, selected_id, new_cnd)
	current_tool = ToolMode.SELECT
	emit_signal("tool_changed", ToolMode.SELECT)

func _finish_add_damage(pos: Vector2) -> void:
	var next_idx := blueprint.damages.size() + 1
	var new_id := "dmg_%d" % next_idx
	var room_here := blueprint.get_room_at(pos)
	var sector_name := str(room_here.get("name", "Settore Nave")) if not room_here.is_empty() else "Nave"
	var new_dmg: Dictionary = {
		"id": new_id,
		"type": "breach",
		"name": "Danno Strutturale %d" % next_idx,
		"pos": pos,
		"sector": sector_name,
		"severity": 5.0,
		"repair_cost": 10.0,
		"desc": "Falla o anomalia rilevata nel compartimento.",
		"system_impact": "integrity_warning"
	}
	emit_signal("action_committed", "Aggiungi Danno")
	blueprint.damages.append(new_dmg)
	blueprint.emit_changed()
	selected_type = "damage"
	selected_id = new_id
	emit_signal("element_selected", selected_type, selected_id, new_dmg)
	current_tool = ToolMode.SELECT
	emit_signal("tool_changed", ToolMode.SELECT)

func delete_element(elem_type: String, elem_id: String) -> void:
	if not blueprint:
		return
	emit_signal("action_committed", "Elimina Elemento")
	match elem_type:
		"room":
			blueprint.remove_room(elem_id)
		"duct":
			blueprint.remove_duct(elem_id)
		"device":
			blueprint.remove_device(elem_id)
		"junction":
			blueprint.remove_junction(elem_id)
		"conduit":
			blueprint.remove_conduit(elem_id)
		"damage":
			blueprint.remove_damage(elem_id)
	if selected_id == elem_id:
		selected_type = ""
		selected_id = ""
		emit_signal("element_selected", "", "", {})
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
		var screen_bounds_size := blueprint.ship_bounds.size * zoom_level
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

	if show_conduits:
		_draw_conduits()
		
	if show_devices or show_junctions:
		_draw_power_grid()
		
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
		var rect: Rect2 = r.get("rect", Rect2())
		var col: Color = r.get("color", Color(0.2, 0.3, 0.4, 0.5))
		var border_col: Color = r.get("border_color", Color(0.5, 0.7, 0.9, 0.8))
		var screen_rect := Rect2(world_to_screen(rect.position), rect.size * zoom_level)
		
		var is_selected: bool = (selected_type == "room" and selected_id == r.get("id", ""))
		
		# Riempimento
		draw_rect(screen_rect, col, true)
		# Bordo
		var b_color := COLOR_SELECTION if is_selected else border_col
		var b_width := 3.0 if is_selected else 1.5
		draw_rect(screen_rect, b_color, false, b_width)
		
		# Etichetta Nome Stanza
		if show_labels:
			var label_str: String = str(r.get("name", r.get("id", "")))
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
		draw_rect(Rect2(h - Vector2(4, 4), Vector2(8, 8)), COLOR_SELECTION, true)
		draw_rect(Rect2(h - Vector2(4, 4), Vector2(8, 8)), Color.BLACK, false, 1.0)

func _draw_ducts() -> void:
	var font: Font = ThemeDB.fallback_font
	for d in blueprint.ducts:
		var p1: Vector2 = d.get("from", Vector2.ZERO)
		var p2: Vector2 = d.get("to", Vector2.ZERO)
		var width: float = float(d.get("width", 14.0)) * zoom_level
		var is_selected: bool = (selected_type == "duct" and selected_id == d.get("id", ""))
		var sp1 := world_to_screen(p1)
		var sp2 := world_to_screen(p2)
		
		# Tubo / Condotto
		var pipe_color := Color(0.12, 0.45, 0.65, 0.7)
		if is_selected:
			pipe_color = COLOR_SELECTION
		elif d.get("is_blocked", false):
			pipe_color = Color(0.8, 0.25, 0.2, 0.7)
			
		draw_line(sp1, sp2, Color(0.04, 0.15, 0.22, 0.9), width + 4.0) # Bordo scuro
		draw_line(sp1, sp2, pipe_color, width)
		draw_circle(sp1, width * 0.5, pipe_color)
		draw_circle(sp2, width * 0.5, pipe_color)
		
		# Linea tratteggiata di flusso interna
		draw_dashed_line(sp1, sp2, Color(0.7, 0.9, 1.0, 0.8), 1.5, 6.0 * zoom_level)

		if show_labels and zoom_level >= 0.8:
			var mid_point := (sp1 + sp2) * 0.5
			var duct_name: String = str(d.get("name", d.get("id", "")))
			draw_string(font, mid_point + Vector2(4, -4), duct_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.8, 1.0, 0.85))

func _draw_conduits() -> void:
	var font: Font = ThemeDB.fallback_font
	for c in blueprint.conduits:
		var p1: Vector2 = c.get("from_pos", Vector2.ZERO)
		var p2: Vector2 = c.get("to_pos", Vector2.ZERO)
		var is_selected: bool = (selected_type == "conduit" and selected_id == c.get("id", ""))
		var sp1 := world_to_screen(p1)
		var sp2 := world_to_screen(p2)
		
		var c_col := COLOR_SELECTION if is_selected else Color(0.2, 0.8, 1.0, 0.85)
		var c_width := 3.0 * zoom_level if is_selected else 2.0 * zoom_level
		
		draw_line(sp1, sp2, Color(0.02, 0.1, 0.18, 0.9), c_width + 3.0)
		draw_dashed_line(sp1, sp2, c_col, c_width, 5.0 * zoom_level)
		draw_circle(sp1, 3.5 * zoom_level, c_col)
		draw_circle(sp2, 3.5 * zoom_level, c_col)
		
		if show_labels and zoom_level >= 0.8:
			var mid_point := (sp1 + sp2) * 0.5
			var c_id: String = str(c.get("id", "CND"))
			draw_string(font, mid_point + Vector2(4, -4), c_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, c_col)

func _draw_power_grid() -> void:
	var font: Font = ThemeDB.fallback_font
	
	# Disegna cablaggi dagli snodi
	if show_junctions:
		for j in blueprint.junctions:
			var j_pos: Vector2 = j.get("pos", Vector2.ZERO)
			var s_j_pos := world_to_screen(j_pos)
			var active_idx: int = int(j.get("active_branch", 0))
			var branches: Array = j.get("branches", [])
			
			for b_idx in range(branches.size()):
				var branch: Dictionary = branches[b_idx]
				var to_pos: Vector2 = branch.get("to_pos", j_pos)
				var s_to_pos := world_to_screen(to_pos)
				var is_active: bool = (b_idx == active_idx)
				
				var cable_col := Color(1.0, 0.9, 0.2, 0.95) if is_active else Color(0.35, 0.45, 0.35, 0.45)
				var cable_width := 2.5 * zoom_level if is_active else 1.2 * zoom_level
				
				draw_line(s_j_pos, s_to_pos, cable_col, cable_width)
				
				# Se terminazione morta, disegna una 'X'
				if branch.get("target_type", "") == "dead_end":
					draw_line(s_to_pos - Vector2(4, 4), s_to_pos + Vector2(4, 4), Color(0.9, 0.3, 0.3, 0.8), 2.0)
					draw_line(s_to_pos - Vector2(-4, 4), s_to_pos + Vector2(-4, 4), Color(0.9, 0.3, 0.3, 0.8), 2.0)

		# Disegna Snodi (Junctions)
		for j in blueprint.junctions:
			var pos: Vector2 = j.get("pos", Vector2.ZERO)
			var spos := world_to_screen(pos)
			var is_selected: bool = (selected_type == "junction" and selected_id == j.get("id", ""))
			var radius: float = 7.0 * zoom_level
			
			var junc_color := COLOR_SELECTION if is_selected else Color(1.0, 0.75, 0.1, 0.95)
			draw_circle(spos, radius + 2.0, Color.BLACK)
			draw_circle(spos, radius, junc_color)
			
			if show_labels:
				var j_id: String = str(j.get("id", "J"))
				draw_string(font, spos + Vector2(10, 4), j_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.9, 0.3, 0.9))

	# Disegna Dispositivi (Devices)
	if show_devices:
		for dev in blueprint.devices:
			var pos: Vector2 = dev.get("pos", Vector2.ZERO)
			var spos := world_to_screen(pos)
			var is_gen: bool = dev.get("is_generator", false)
			var is_selected: bool = (selected_type == "device" and selected_id == dev.get("id", ""))
			var box_size := Vector2(24, 24) * zoom_level
			var box_rect := Rect2(spos - box_size * 0.5, box_size)
			
			var dev_color := Color(1.0, 0.35, 0.15, 0.9) if is_gen else Color(0.2, 0.7, 1.0, 0.9)
			if is_selected:
				dev_color = COLOR_SELECTION
				
			draw_rect(box_rect, Color(0.1, 0.15, 0.2, 0.9), true)
			draw_rect(box_rect, dev_color, false, 2.0)
			
			# Simbolo icona (G per Generatore, L per Carico/Load)
			var icon_sym := "⚡" if is_gen else "⚙"
			var font_sz: int = int(clampf(12.0 * zoom_level, 9.0, 16.0))
			draw_string(font, box_rect.position + Vector2(4, 16 * zoom_level), icon_sym, HORIZONTAL_ALIGNMENT_CENTER, int(box_rect.size.x), font_sz, dev_color)

			if show_labels and zoom_level >= 0.7:
				var dev_name: String = str(dev.get("name", dev.get("id", "")))
				var mw_val: float = float(dev.get("power_mw", 0.0))
				var label_str := "%s (%d MW)" % [dev_name, int(mw_val)]
				draw_string(font, spos + Vector2(16, 4), label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.8, 0.95, 1.0, 0.9))

func _draw_damages() -> void:
	var font: Font = ThemeDB.fallback_font
	for dmg in blueprint.damages:
		var pos: Vector2 = dmg.get("pos", Vector2.ZERO)
		var spos := world_to_screen(pos)
		var is_selected: bool = (selected_type == "damage" and selected_id == dmg.get("id", ""))
		var dmg_type: String = str(dmg.get("type", "breach"))
		var sev: float = float(dmg.get("severity", 5.0))
		
		var radius := (8.0 + sev * 0.8) * zoom_level
		var dmg_color := Color(1.0, 0.25, 0.25, 0.75) if dmg_type == "breach" else Color(1.0, 0.8, 0.15, 0.75)
		if is_selected:
			dmg_color = COLOR_SELECTION
			
		# Area di danno circolare
		draw_circle(spos, radius, Color(dmg_color.r, dmg_color.g, dmg_color.b, 0.25))
		draw_circle(spos, radius, dmg_color, false, 2.0)
		draw_circle(spos, 3.0 * zoom_level, dmg_color, true)
		
		if show_labels and zoom_level >= 0.7:
			var dmg_name: String = str(dmg.get("name", dmg.get("id", "")))
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
		ToolMode.ADD_CONDUIT:
			draw_dashed_line(sp1, sp2, Color(0.3, 0.9, 1.0, 0.9), 3.0 * zoom_level, 6.0 * zoom_level)
