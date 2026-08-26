class_name PowerGridMapCanvas
extends Control

## Canvas 2D per il rendering della mappa stilizzata dell'impianto elettrico della nave.
## Disegna la sagoma dello scafo, i condotti/connessioni (attivi, inattivi, in cortocircuito),
## gli snodi con biforcazioni e i dispositivi con indicatori di input e regime.

signal junction_clicked(junction_id: String)
signal device_clicked(device_id: String)

var app: Node = null
var hovered_junction_id: String = ""
var hovered_device_id: String = ""

func _ready() -> void:
	_find_app()
	mouse_filter = MOUSE_FILTER_PASS

func _find_app() -> void:
	var p: Node = get_parent()
	while p != null:
		if p.has_method("draw_power_grid"):
			app = p
			break
		p = p.get_parent()

func _draw() -> void:
	if app == null:
		_find_app()
	if app != null and is_instance_valid(app):
		app.draw_power_grid(self)

func _gui_input(event: InputEvent) -> void:
	if app == null:
		_find_app()
	if app == null or not is_instance_valid(app):
		return
	
	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = event.position
		var old_junc := hovered_junction_id
		var old_dev := hovered_device_id
		
		if app.has_method("get_junction_at_pos"):
			hovered_junction_id = app.get_junction_at_pos(mouse_pos, self)
		if app.has_method("get_device_at_pos"):
			hovered_device_id = app.get_device_at_pos(mouse_pos, self)
		
		if hovered_junction_id != old_junc or hovered_device_id != old_dev:
			queue_redraw()
	
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos: Vector2 = event.position
		var junc_id: String = ""
		var dev_id: String = ""
		
		if app.has_method("get_junction_at_pos"):
			junc_id = app.get_junction_at_pos(mouse_pos, self)
		if app.has_method("get_device_at_pos"):
			dev_id = app.get_device_at_pos(mouse_pos, self)
		
		if junc_id != "":
			junction_clicked.emit(junc_id)
			if app.has_method("on_canvas_junction_clicked"):
				app.on_canvas_junction_clicked(junc_id)
			queue_redraw()
			accept_event()
		elif dev_id != "":
			device_clicked.emit(dev_id)
			if app.has_method("on_canvas_device_clicked"):
				app.on_canvas_device_clicked(dev_id)
			queue_redraw()
			accept_event()
