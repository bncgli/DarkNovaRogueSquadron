class_name Asteroid
extends StaticBody3D

## Rappresenta un asteroide nello spazio esterno con rotazione e collisione.

@export var rotation_speed: Vector3 = Vector3(0.05, 0.08, 0.03)
@export var wobble_speed: float = 0.0

@export var composition: Dictionary = {
	"Ferro (Fe)": 45.0,
	"Nichel (Ni)": 28.0,
	"Silicati": 18.0,
	"Cobalto": 9.0
}
@export var integrity: float = 100.0
@export var mass_tons: float = 2400.0
@export var radius_m: float = 4.0
@export var iff_tag: String = "NEUTRAL"
@export var signal_signature: float = 0.80

@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")

var _time_elapsed: float = 0.0

func _ready() -> void:
	add_to_group("asteroids")
	add_to_group("scannable_entities")
	var max_scale := maxf(scale.x, maxf(scale.y, scale.z))
	radius_m = 4.0 * max_scale
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
