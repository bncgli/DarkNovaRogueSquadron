class_name SpaceScene
extends Node3D

## Gestione della scena spaziale e fornitura dei riferimenti all'astronave.

@onready var spaceship: Spaceship = $Spaceship
@onready var sun_light: DirectionalLight3D = $SunLight

func _ready() -> void:
	pass

func get_spaceship() -> Spaceship:
	if spaceship == null:
		spaceship = get_node_or_null("Spaceship")
	return spaceship

func get_camera_global_transform(cam_id: String) -> Transform3D:
	if spaceship and is_instance_valid(spaceship):
		return spaceship.get_camera_global_transform(cam_id)
	return Transform3D.IDENTITY

func get_asteroids() -> Node3D:
	return get_node_or_null("Asteroids")
