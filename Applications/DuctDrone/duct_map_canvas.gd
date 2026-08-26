class_name DuctMapCanvas
extends Control

## Canvas 2D per il rendering dello schema della nave, dei condotti e del robottino (Duct Drone).

var app: DuctDroneApp = null

func _ready() -> void:
	_find_app()

func _find_app() -> void:
	var p: Node = get_parent()
	while p != null:
		if p is DuctDroneApp:
			app = p as DuctDroneApp
			break
		p = p.get_parent()

func _draw() -> void:
	if app == null:
		_find_app()
	if app != null and is_instance_valid(app):
		app.draw_blueprint(self)
