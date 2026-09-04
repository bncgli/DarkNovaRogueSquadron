extends Node
class_name DuctDroneManager

## Gestore della logica del drone di manutenzione (Duct Drone).
## Estratto da SpaceWorldManager per migliorare la manutenibilità.

signal state_changed(pos: Vector2, heading: float, speed: float, battery: float, lights: bool, scan_active: bool, scan_radius: float)
signal reset_performed()
signal repair_state_changed(is_repairing: bool, damage_id: String, progress: float)

# Costanti estratte da SpaceWorldManager
const INITIAL_POS := Vector2(300, 80)
const INITIAL_HEADING := -PI * 0.5
const BASE_LINEAR_SPEED: float = 175.0
const BASE_ROTATE_SPEED: float = 3.0
const ACCELERATION: float = 650.0
const DECELERATION: float = 750.0

# Stato del drone
var pos: Vector2 = INITIAL_POS
var heading: float = INITIAL_HEADING
var speed: float = 0.0
var battery: float = 100.0
var lights: bool = false
var scan_active: bool = false
var scan_radius: float = 80.0

var is_repairing: bool = false
var current_repair_damage_id: String = ""
var repair_progress: float = 0.0

func _process(delta: float) -> void:
	# Logica di movimento semplificata (da rifinire se necessario)
	if speed != 0:
		var dir := Vector2.UP.rotated(heading)
		pos += dir * speed * delta
		emit_state_changed()

func emit_state_changed() -> void:
	state_changed.emit(pos, heading, speed, battery, lights, scan_active, scan_radius)

func reset_drone() -> void:
	if SpaceWorldManager:
		pos = SpaceWorldManager.get_drone_spawn_pos()
		heading = SpaceWorldManager.get_drone_spawn_heading()
	else:
		pos = INITIAL_POS
		heading = INITIAL_HEADING
	speed = 0.0
	battery = 100.0
	is_repairing = false
	reset_performed.emit()
	emit_state_changed()

func set_lights(enabled: bool) -> void:
	lights = enabled
	emit_state_changed()

func start_repair(damage_id: String) -> void:
	is_repairing = true
	current_repair_damage_id = damage_id
	repair_progress = 0.0
	repair_state_changed.emit(true, damage_id, 0.0)
