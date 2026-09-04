class_name CombatDirector
extends Node

## Regia degli Incontri Ostili, Spawn Ondate e Coordinamento Tattico.
## Gestisce l'orchestrazione degli squadroni nemici (caccia, droni, corvette),
## il targeting coordinato, le risposte alle contromisure EW (jammer / firmware exploits)
## e l'interfacciamento con SystemicDamageHandler per i colpi subiti.

signal wave_spawned(wave_index: int, enemies_count: int)
signal wave_cleared(wave_index: int)
signal combat_engagement_started()
signal combat_engagement_ended(victory: bool)
signal hostile_targeted(enemy_id: String, role: String)
signal hacker_exploit_broadcast(target_id: String, exploit_type: String)

@export var auto_manage_encounters: bool = false
@export var default_spawn_radius: float = 120.0

var active_enemies: Array[EnemyShipAI] = []
var active_wave_index: int = 0
var is_in_combat: bool = false
var systemic_damage_handler: SystemicDamageHandler = null
var player_ship_node: Node3D = null

func _ready() -> void:
	if not systemic_damage_handler:
		systemic_damage_handler = get_node_or_null("SystemicDamageHandler") as SystemicDamageHandler
		if not systemic_damage_handler:
			systemic_damage_handler = SystemicDamageHandler.new()
			systemic_damage_handler.name = "SystemicDamageHandler"
			add_child(systemic_damage_handler)

func setup(p_player_ship: Node3D = null, p_damage_handler: SystemicDamageHandler = null) -> void:
	player_ship_node = p_player_ship
	if p_damage_handler:
		systemic_damage_handler = p_damage_handler

func _process(delta: float) -> void:
	if not is_in_combat:
		return

	# Pulisce nemici non più validi o distrutti
	var valid_enemies: Array[EnemyShipAI] = []
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.current_health > 0.0:
			valid_enemies.append(enemy)
	active_enemies = valid_enemies

	if active_enemies.is_empty() and is_in_combat:
		_on_all_enemies_defeated()

## Spawna un'ondata nemica configurata o procedurale
func spawn_wave(wave_index: int, composition: Array[Dictionary] = []) -> Array[EnemyShipAI]:
	active_wave_index = wave_index
	var spawned: Array[EnemyShipAI] = []

	var target_comp := composition
	if target_comp.is_empty():
		# Composizione predefinita per l'ondata
		match wave_index:
			1:
				target_comp = [
					{"type": EnemyShipAI.ShipType.HOSTILE_DRONE, "count": 2},
					{"type": EnemyShipAI.ShipType.PIRATE_FIGHTER, "count": 1}
				]
			2:
				target_comp = [
					{"type": EnemyShipAI.ShipType.PIRATE_FIGHTER, "count": 3}
				]
			3, _:
				target_comp = [
					{"type": EnemyShipAI.ShipType.PATROL_CORVETTE, "count": 1},
					{"type": EnemyShipAI.ShipType.PIRATE_FIGHTER, "count": 2}
				]

	var enemy_counter := 0
	for entry in target_comp:
		var type: EnemyShipAI.ShipType = entry.get("type")
		var count: int = entry.get("count")

		for i in range(count):
			enemy_counter += 1
			var enemy_id := "WAVE%d_FOE_%d" % [wave_index, enemy_counter]
			var angle := randf_range(0, TAU)
			var elevation := randf_range(-0.3, 0.3)
			var spawn_pos := Vector3(cos(angle) * default_spawn_radius, elevation * default_spawn_radius, sin(angle) * default_spawn_radius)
			if player_ship_node and is_instance_valid(player_ship_node):
				spawn_pos += player_ship_node.global_position

			var enemy := EnemyShipAI.new()
			enemy.name = enemy_id
			add_child(enemy)
			enemy.setup(enemy_id, type, spawn_pos)
			
			if player_ship_node and is_instance_valid(player_ship_node):
				enemy.target_node = player_ship_node
			else:
				enemy.target_position = Vector3.ZERO

			# Connetti segnali nemico
			enemy.weapon_fired.connect(_on_enemy_weapon_fired.bind(enemy))
			enemy.ship_destroyed.connect(_on_enemy_destroyed)

			active_enemies.append(enemy)
			spawned.append(enemy)

	if not is_in_combat and not active_enemies.is_empty():
		is_in_combat = true
		combat_engagement_started.emit()

	wave_spawned.emit(wave_index, active_enemies.size())
	return spawned

## Gestisce il fuoco proveniente da un'astronave nemica
func _on_enemy_weapon_fired(weapon_type: String, origin: Vector3, target_pos: Vector3, damage: float, enemy: EnemyShipAI) -> void:
	# Calcola se colpisce la nave del giocatore
	var player_pos := player_ship_node.global_position if player_ship_node and is_instance_valid(player_ship_node) else Vector3.ZERO
	var dist_to_player := target_pos.distance_to(player_pos)

	# Se il colpo è vicino alla nave o mirato ad essa
	if dist_to_player < 15.0 or (enemy.target_node == player_ship_node and not enemy.is_jammed):
		var hit_dir_local := (origin - player_pos).normalized()
		if player_ship_node and is_instance_valid(player_ship_node):
			hit_dir_local = player_ship_node.global_transform.basis.inverse() * (origin - player_pos)

		if SpaceWorldManager and SpaceWorldManager.has_method("spawn_incoming_projectile"):
			var p_type := "TORPEDO" if weapon_type == "torpedo" else "KINETIC"
			var proj_vel := (player_pos - origin).normalized() * 40.0
			SpaceWorldManager.spawn_incoming_projectile(p_type, origin, proj_vel, damage, player_pos)

		if systemic_damage_handler and is_instance_valid(systemic_damage_handler):
			systemic_damage_handler.process_hit(hit_dir_local, damage, "plasma" if weapon_type == "torpedo" else "kinetic")

## Verifica se un colpo in arrivo viene intercettato da dispositivi di difesa point-defense
func evaluate_defensive_interception(hit_dir_local: Vector3, weapon_type: String, devices: Array[Dictionary]) -> Dictionary:
	var dir_norm := hit_dir_local.normalized()
	var bearing_deg := rad_to_deg(atan2(dir_norm.x, -dir_norm.z))
	
	var sector := 0
	if bearing_deg >= -45.0 and bearing_deg <= 45.0:
		sector = 0 # FORE
	elif bearing_deg > 45.0 and bearing_deg <= 135.0:
		sector = 2 # STARBOARD
	elif bearing_deg < -45.0 and bearing_deg >= -135.0:
		sector = 1 # PORT
	else:
		sector = 3 # AFT
	
	for dev in devices:
		if dev.get("sector", -1) != sector:
			continue
		if dev.get("ammo", 0) <= 0:
			continue
		
		var dev_type: String = str(dev.get("type", "")).to_upper()
		var is_missile_or_torp: bool = weapon_type.to_lower() in ["torpedo", "missile", "homing_missile", "rocket"]
		
		if dev_type == "GATLING":
			return {
				"intercepted": true,
				"action": "DESTROYED",
				"device_id": dev.get("id", ""),
				"sector": sector
			}
		elif dev_type == "FLACK" and is_missile_or_torp:
			return {
				"intercepted": true,
				"action": "DEFLECTED",
				"device_id": dev.get("id", ""),
				"sector": sector
			}
	
	return {
		"intercepted": false,
		"action": "NONE",
		"sector": sector
	}

## Notifica distruzione nemico
func _on_enemy_destroyed(ship_id: String, ship_type: String, pos: Vector3) -> void:
	# Rimozione da active_enemies gestita nel tick o immediata
	var remaining := 0
	for e in active_enemies:
		if is_instance_valid(e) and e.ship_id != ship_id and e.current_health > 0.0:
			remaining += 1

	if remaining == 0 and is_in_combat:
		_on_all_enemies_defeated()

func _on_all_enemies_defeated() -> void:
	is_in_combat = false
	wave_cleared.emit(active_wave_index)
	combat_engagement_ended.emit(true)

# --- INTEGRAZIONE RUOLI ASIMMETRICI (Soldato, Ingegnere, Hacker, Pilota) ---

## Esecuzione fuoco torretta / armi da parte del Soldato
func fire_player_weapon_at(target_enemy_id: String, damage: float, is_emp: bool = false) -> Dictionary:
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.ship_id == target_enemy_id:
			return enemy.take_damage(damage, is_emp)
	return {"error": "Target not found"}

## Esecuzione Guerra Elettronica da parte dell'Hacker: Jamming su caccia/corvetta
func execute_ew_jamming(target_enemy_id: String, duration: float = 8.0) -> bool:
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.ship_id == target_enemy_id:
			enemy.apply_comms_jamming(duration)
			hacker_exploit_broadcast.emit(target_enemy_id, "JAMMING")
			return true
	return false

## Esecuzione Guerra Elettronica da parte dell'Hacker: Firmware Exploit (Disabilita motori)
func execute_firmware_exploit(target_enemy_id: String, duration: float = 10.0) -> bool:
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.ship_id == target_enemy_id:
			enemy.inject_firmware_exploit(duration)
			hacker_exploit_broadcast.emit(target_enemy_id, "FIRMWARE_EXPLOIT")
			return true
	return false

## Ottiene lo stato dell'ingaggio tattico corrente (per Radar, Cams e UI tattica)
func get_combat_overview() -> Dictionary:
	var enemy_data: Array[Dictionary] = []
	for e in active_enemies:
		if is_instance_valid(e):
			enemy_data.append(e.get_tactical_status())

	var damage_status := {}
	if systemic_damage_handler and is_instance_valid(systemic_damage_handler):
		damage_status = systemic_damage_handler.get_system_status()

	return {
		"is_in_combat": is_in_combat,
		"wave_index": active_wave_index,
		"enemies_count": enemy_data.size(),
		"enemies": enemy_data,
		"ship_systemic_status": damage_status
	}
