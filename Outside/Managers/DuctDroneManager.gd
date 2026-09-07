extends Node
class_name DuctDroneManager

## Gestore della logica del drone di manutenzione (Duct Drone): stato, fisica di
## movimento, consumo batteria, rilevamento dei danni nave e avanzamento riparazioni.
## Estratto da SpaceWorldManager per eliminare la duplicazione di stato/logica.

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

# Stato sincronizzato del drone
var pos: Vector2 = INITIAL_POS
var heading: float = INITIAL_HEADING
var speed: float = 0.0
var battery: float = 100.0
var lights: bool = false
var scan_active: bool = false
var scan_radius: float = 0.0

var linear_input: float = 0.0
var angular_input: float = 0.0
var speed_mult: float = 1.0

var is_repairing: bool = false
var repairing_damage_id: String = ""

# Configurazione runtime (velocità, consumi batteria, range di riparazione, ecc.)
var active_config: Dictionary = {
	"linear_speed": 175.0,
	"linear_acceleration": 650.0,
	"linear_deceleration": 750.0,
	"rotate_speed": 3.0,
	"battery_max": 100.0,
	"battery_drain_move": 0.35,
	"battery_drain_lights": 0.75,
	"battery_drain_radar": 3.5,
	"battery_drain_repair": 6.0,
	"radar_scan_radius_max": 160.0,
	"repair_range": 42.0,
	"repair_speed_multiplier": 1.0,
	"repair_efficiency": 1.0,
	"turbo_multiplier": 2.0,
	"precision_multiplier": 0.5,
	"is_dat_loaded": false
}

func emit_state_changed() -> void:
	state_changed.emit(pos, heading, speed, battery, lights, scan_active, scan_radius)

func get_state() -> Dictionary:
	return {
		"pos": pos,
		"heading": heading,
		"speed": speed,
		"battery": battery,
		"lights": lights,
		"scan_active": scan_active,
		"scan_radius": scan_radius
	}

func set_inputs(linear_in: float, angular_in: float, mult: float = 1.0) -> void:
	linear_input = linear_in
	angular_input = angular_in
	speed_mult = mult

func stop() -> void:
	linear_input = 0.0
	angular_input = 0.0
	speed = 0.0

func reset(spawn_pos: Vector2, spawn_heading: float) -> void:
	pos = spawn_pos
	heading = spawn_heading
	speed = 0.0
	linear_input = 0.0
	angular_input = 0.0
	battery = 100.0
	scan_active = false
	scan_radius = 0.0
	reset_performed.emit()

func set_lights(enabled: bool) -> void:
	lights = enabled

func trigger_scan() -> void:
	scan_active = true
	scan_radius = 0.0

func apply_synced_state(p_pos: Vector2, p_heading: float, p_speed: float, p_battery: float, p_lights: bool, p_scan_active: bool, p_scan_radius: float) -> void:
	pos = p_pos
	heading = p_heading
	speed = p_speed
	battery = p_battery
	lights = p_lights
	scan_active = p_scan_active
	scan_radius = p_scan_radius
	emit_state_changed()

func set_config(cfg: Dictionary) -> void:
	for k in cfg:
		active_config[k] = cfg[k]
	active_config["is_dat_loaded"] = true

func get_config() -> Dictionary:
	return active_config

func start_repair(damage_id: String, progress: float = 0.0) -> void:
	is_repairing = true
	repairing_damage_id = damage_id
	repair_state_changed.emit(true, damage_id, progress)

func stop_repair(final_progress: float = 0.0) -> void:
	is_repairing = false
	repairing_damage_id = ""
	repair_state_changed.emit(false, "", final_progress)

func _is_position_valid(p: Vector2, rooms: Array[DuctRoomData], ducts: Array[ShipDuctData]) -> bool:
	for room in rooms:
		var r: Rect2 = room.rect
		if r.grow(-2.0).has_point(p):
			return true

	for duct in ducts:
		var p1: Vector2 = duct.from
		var p2: Vector2 = duct.to
		var width: float = duct.width
		var seg_dist := _distance_to_segment_2d(p, p1, p2)
		if seg_dist <= width * 0.8:
			return true

	return false

func _distance_to_segment_2d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ab_len_sq := ab.length_squared()
	if ab_len_sq < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var projection := a + t * ab
	return p.distance_to(projection)

func _can_move(from_pos: Vector2, to_pos: Vector2, rooms: Array[DuctRoomData], ducts: Array[ShipDuctData], sealed_rooms: Array) -> bool:
	if not _is_position_valid(to_pos, rooms, ducts):
		return false

	for room in sealed_rooms:
		var rect: Rect2 = room.rect if "rect" in room else room.get("rect", Rect2())
		if rect.size == Vector2.ZERO:
			continue
		var was_inside := rect.has_point(from_pos)
		var will_be_inside := rect.has_point(to_pos)
		if was_inside != will_be_inside:
			return false
	return true

func _constrain_movement(old_pos: Vector2, new_pos: Vector2, rooms: Array[DuctRoomData], ducts: Array[ShipDuctData], sealed_rooms: Array) -> Vector2:
	if _can_move(old_pos, new_pos, rooms, ducts, sealed_rooms):
		return new_pos

	var test_x := Vector2(new_pos.x, old_pos.y)
	if _can_move(old_pos, test_x, rooms, ducts, sealed_rooms):
		return test_x

	var test_y := Vector2(old_pos.x, new_pos.y)
	if _can_move(old_pos, test_y, rooms, ducts, sealed_rooms):
		return test_y

	return old_pos

## Esegue un passo di simulazione fisica del drone: rotazione, movimento lineare vincolato,
## consumo/ricarica batteria, sonar, rilevamento danni invisibili e avanzamento della
## riparazione in corso. Ritorna true se lo stato dei danni nave è cambiato in questo tick
## (rivelazione di un danno o completamento di una riparazione).
func update_physics(delta: float, damage_manager: ShipDamageManager) -> bool:
	var base_rot_speed: float = float(active_config.get("rotate_speed"))
	var base_lin_speed: float = float(active_config.get("linear_speed"))
	var drain_move: float = float(active_config.get("battery_drain_move"))
	var drain_lights: float = float(active_config.get("battery_drain_lights"))
	var drain_radar: float = float(active_config.get("battery_drain_radar"))
	var drain_repair: float = float(active_config.get("battery_drain_repair"))
	var scan_max: float = float(active_config.get("radar_scan_radius_max"))
	var repair_rng: float = float(active_config.get("repair_range"))
	var repair_mult: float = float(active_config.get("repair_speed_multiplier", 1.0)) * float(active_config.get("repair_efficiency", 1.0))

	# 1. Rotazione Tank (gira sul posto)
	if absf(angular_input) > 0.01 and battery > 0.0:
		var rot_step := angular_input * base_rot_speed * speed_mult * delta
		heading += rot_step
		heading = wrapf(heading, -PI, PI)

	# Se la batteria è esaurita (<= 0.0), il robottino non può muoversi né riparare
	var effective_linear_input := linear_input
	if battery <= 0.0:
		effective_linear_input = 0.0
		if is_repairing and SpaceWorldManager:
			SpaceWorldManager.stop_duct_drone_repair()

	# 2. Spostamento Lineare (avanti/indietro su vettore prua)
	var target_speed := effective_linear_input * base_lin_speed * speed_mult
	speed = target_speed

	# Consumo batteria differenziato da parametri attivi
	if absf(effective_linear_input) > 0.01:
		battery = maxf(0.0, battery - drain_move * delta * speed_mult)

	if lights:
		battery = maxf(0.0, battery - drain_lights * delta)

	if scan_active:
		battery = maxf(0.0, battery - drain_radar * delta)

	if is_repairing:
		battery = maxf(0.0, battery - drain_repair * delta)

	var rooms := SpaceWorldManager.get_duct_rooms() if SpaceWorldManager else []
	var ducts := SpaceWorldManager.get_duct_corridors() if SpaceWorldManager else []

	if absf(speed) > 0.1:
		var forward_dir := Vector2.from_angle(heading)
		var movement := forward_dir * speed * delta
		var new_pos := pos + movement
		var sealed_rooms: Array = SpaceWorldManager.get_sealed_rooms() if SpaceWorldManager else []
		pos = _constrain_movement(pos, new_pos, rooms, ducts, sealed_rooms)
	else:
		# Ricarica se il robottino è all'interno della stanza di ricarica
		var bp := SpaceWorldManager.get_ship_blueprint() if SpaceWorldManager else null
		var recharge_room: Variant = null
		if bp and bp.recharge_room_id != "":
			recharge_room = bp.get_room_by_id(bp.recharge_room_id)
		if recharge_room and recharge_room.rect.has_point(pos):
			var max_bat: float = float(active_config.get("battery_max"))
			battery = minf(max_bat, battery + 15.0 * delta)

	# 3. Sonar pulse
	if scan_active:
		scan_radius += 180.0 * delta
		if scan_radius > scan_max:
			scan_active = false
			scan_radius = 0.0

	# 4. Rilevamento Danni Invisibili
	var damages_changed := false
	for dmg in damage_manager.active_damages:
		if dmg.repaired:
			continue

		var dmg_type: String = dmg.type
		var dmg_pos: Vector2 = dmg.pos
		var is_revealed: bool = dmg.revealed

		if not is_revealed:
			if dmg_type == damage_manager.DAMAGE_TYPE_BREACH and lights:
				var dist := pos.distance_to(dmg_pos)
				if dist <= 35.0:
					damage_manager.reveal_damage(dmg, "light")
					damages_changed = true
				elif dist <= 90.0:
					var to_dmg := (dmg_pos - pos).normalized()
					var forward := Vector2.from_angle(heading)
					var angle_diff := absf(forward.angle_to(to_dmg))
					if angle_diff <= 0.55: # cono fari (~31 gradi)
						damage_manager.reveal_damage(dmg, "light")
						damages_changed = true

			elif dmg_type == damage_manager.DAMAGE_TYPE_SHORT_CIRCUIT and scan_active:
				var dist := pos.distance_to(dmg_pos)
				if dist <= scan_radius:
					damage_manager.reveal_damage(dmg, "radar")
					damages_changed = true

			elif (dmg_type == damage_manager.DAMAGE_TYPE_FIRE or dmg_type == "dmg_fire" or dmg_type == "FIRE" or dmg_type == "fire"):
				var dist := pos.distance_to(dmg_pos)
				if dist <= 45.0:
					damage_manager.reveal_damage(dmg, "thermal")
					damages_changed = true
				elif lights and dist <= 90.0:
					var to_dmg := (dmg_pos - pos).normalized()
					var forward := Vector2.from_angle(heading)
					var angle_diff := absf(forward.angle_to(to_dmg))
					if angle_diff <= 0.55:
						damage_manager.reveal_damage(dmg, "light")
						damages_changed = true
				elif scan_active and dist <= scan_radius:
					damage_manager.reveal_damage(dmg, "radar")
					damages_changed = true

	# 5. Elaborazione Riparazione in corso
	if is_repairing and repairing_damage_id != "":
		var target_dmg: ShipDamageRuntimeState = damage_manager.get_damage_by_id(repairing_damage_id)

		if target_dmg == null or target_dmg.repaired:
			stop_repair(0.0)
		else:
			var d: float = pos.distance_to(target_dmg.pos)
			if d > repair_rng or battery <= 0.0:
				# Troppo lontano o batteria esaurita: interrompi riparazione
				stop_repair(target_dmg.repair_progress)
			else:
				var duration: float = maxf(1.0, float(target_dmg.repair_duration))
				var progress: float = float(target_dmg.repair_progress)
				progress = clampf(progress + ((delta * repair_mult) / duration), 0.0, 1.0)
				damage_manager.set_repair_progress(repairing_damage_id, progress)
				repair_state_changed.emit(true, repairing_damage_id, progress)

				if progress >= 1.0:
					damage_manager.complete_repair(repairing_damage_id)
					damages_changed = true
					stop_repair(1.0)

	emit_state_changed()
	return damages_changed
