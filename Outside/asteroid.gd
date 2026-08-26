class_name Asteroid
extends StaticBody3D

## Rappresenta un asteroide nello spazio esterno con rotazione e collisione.

@export var rotation_speed: Vector3 = Vector3(0.05, 0.08, 0.03)
@export var wobble_speed: float = 0.0

@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")

var _time_elapsed: float = 0.0

func _ready() -> void:
	# Randomizza leggermente la fase di rotazione per non avere asteroidi sincronizzati
	rotation_degrees += Vector3(
		randf_range(-180, 180),
		randf_range(-180, 180),
		randf_range(-180, 180)
	)

func _process(delta: float) -> void:
	_time_elapsed += delta
	rotate_x(rotation_speed.x * delta)
	rotate_y(rotation_speed.y * delta)
	rotate_z(rotation_speed.z * delta)
