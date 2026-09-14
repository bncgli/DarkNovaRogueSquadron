class_name LifeSupportMapCanvas
extends Control

## Canvas 2D per il rendering dello schema blueprint della nave
## e la selezione delle stanze in LifeSupport.

var app: LifeSupportApp = null

func _ready() -> void:
	_find_app()
	mouse_exited.connect(_on_mouse_exited)

func _find_app() -> void:
	var p: Node = get_parent()
	while p != null:
		if p is LifeSupportApp:
			app = p as LifeSupportApp
			break
		p = p.get_parent()

func _draw() -> void:
	if app == null:
		_find_app()
	if app != null and is_instance_valid(app):
		app.draw_blueprint(self)

func _gui_input(event: InputEvent) -> void:
	if app == null:
		_find_app()
	if app != null and is_instance_valid(app):
		app.handle_blueprint_gui_input(self, event)

func _on_mouse_exited() -> void:
	if app == null:
		_find_app()
	if app != null and is_instance_valid(app):
		app.handle_blueprint_mouse_exited()
