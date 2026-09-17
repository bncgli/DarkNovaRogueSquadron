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
signal enemy_ship_destroyed(ship_id: String, ship_type: String, pos: Vector3)
signal scavenger_ambush_triggered(scavengers: Array[EnemyShipAI])
signal scavenger_threat_alert(threat_level: float)
signal cyber_intrusion_detected(intrusion_id: String, exploit_type: String, file_path: String, timeout_sec: float)
signal cyber_intrusion_cleared(intrusion_id: String, exploit_type: String)
signal cyber_intrusion_detonated(intrusion_id: String, exploit_type: String)

const HOSTILE_EXPLOIT_TYPES := {
	"PROPULSION_WORM": {
		"file_name": "worm_thrust_override.dat",
		"folder": "Ship Drive/Programs/FlightControls",
		"timeout": 30.0,
		"description": "Worm malevolo che dirotta gli attuatori RCS provocando deriva continua."
	},
	"BLIND_EYE": {
		"file_name": "cams_jammer_sentinel.dat",
		"folder": "Ship Drive/Programs/Cams",
		"timeout": 25.0,
		"description": "Infezione al bus ottico che acceca i sensori e le telecamere esterne."
	},
	"REACTOR_OVERLOAD": {
		"file_name": "power_drain_virus.dat",
		"folder": "Ship Drive/Programs/PowerGrid",
		"timeout": 35.0,
		"description": "Sovraccarico software al regolatore energetico con rischio di cortocircuito critico."
	}
}

@export var auto_manage_encounters: bool = false
@export var default_spawn_radius: float = 120.0
@export var scavenger_ambush_interval: float = 30.0
@export var scavenger_ambush_chance: float = 0.35
@export var cyber_attack_interval: float = 35.0
@export var cyber_attack_chance: float = 0.65

var active_enemies: Array[EnemyShipAI] = []
var active_wave_index: int = 0
var is_in_combat: bool = false
var scavenger_ambush_timer: float = 0.0
var is_scavenger_alert_active: bool = false
var cyber_attack_timer: float = 0.0
var active_intrusions: Dictionary = {}
var _next_intrusion_seq: int = 1
var systemic_damage_handler: SystemicDamageHandler = null
var player_ship_node: Node3D = null

func _ready() -> void:
	add_to_group("combat_directors")
	if not systemic_damage_handler:
		systemic_damage_handler = get_node_or_null("SystemicDamageHandler") as SystemicDamageHandler
		if not systemic_damage_handler:
			systemic_damage_handler = SystemicDamageHandler.new()
			systemic_damage_handler.name = "SystemicDamageHandler"
			add_child(systemic_damage_handler)
	call_deferred("_connect_ship_drive_signals")

func _exit_tree() -> void:
	var sdm = get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("item_deleted"):
		if sdm.item_deleted.is_connected(_on_ship_drive_item_deleted):
			sdm.item_deleted.disconnect(_on_ship_drive_item_deleted)

func _connect_ship_drive_signals() -> void:
	var sdm = get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("item_deleted"):
		if not sdm.item_deleted.is_connected(_on_ship_drive_item_deleted):
			sdm.item_deleted.connect(_on_ship_drive_item_deleted)

func setup(p_player_ship: Node3D = null, p_damage_handler: SystemicDamageHandler = null) -> void:
	player_ship_node = p_player_ship
	if p_damage_handler:
		systemic_damage_handler = p_damage_handler

func _process(delta: float) -> void:
	process_cyber_warfare(delta)
	
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

## Valuta periodicamente la minaccia sciacalli durante operazioni nel campo detriti o attività EVA
func process_scavenger_threat(delta: float, in_debris_field: bool, drone_active: bool) -> bool:
	if is_in_combat:
		scavenger_ambush_timer = 0.0
		return false
		
	if in_debris_field or drone_active:
		scavenger_ambush_timer += delta
		var threat_pct := clampf(scavenger_ambush_timer / maxf(scavenger_ambush_interval, 1.0), 0.0, 1.0)
		scavenger_threat_alert.emit(threat_pct)
		
		if scavenger_ambush_timer >= scavenger_ambush_interval:
			scavenger_ambush_timer = 0.0
			if randf() <= scavenger_ambush_chance:
				trigger_scavenger_ambush(2)
				return true
	else:
		scavenger_ambush_timer = maxf(0.0, scavenger_ambush_timer - delta * 0.5)
		
	return false

## Genera un'imboscata di sciacalli pirata attratti dalle attività di scavenging prolungate
func trigger_scavenger_ambush(count: int = 2) -> Array[EnemyShipAI]:
	var scavengers: Array[EnemyShipAI] = []
	var comp: Array[Dictionary] = [
		{"type": EnemyShipAI.ShipType.PIRATE_FIGHTER, "count": clampi(count, 1, 4)}
	]
	var spawned := spawn_wave(99, comp)
	for s in spawned:
		s.ship_name = "Sciacallo Corsaro [%s]" % s.ship_id
		scavengers.append(s)
		
	is_scavenger_alert_active = true
	scavenger_ambush_triggered.emit(scavengers)
	
	if SpaceWorldManager and SpaceWorldManager.has_method("_send_spawn_notification"):
		SpaceWorldManager._send_spawn_notification("⚠️ ALLARME: Sciacalli pirata rilevati in rotta d'intercettazione!")
		
	return scavengers

## Spawna un corriere dati S-Net con carico caveau e radiofaro subspaziale dedicato
func spawn_data_courier(spawn_pos: Vector3 = Vector3.ZERO) -> EnemyShipAI:
	var pos := spawn_pos
	if pos == Vector3.ZERO and player_ship_node and is_instance_valid(player_ship_node):
		pos = player_ship_node.global_position + Vector3(250.0, 50.0, -300.0)
	elif pos == Vector3.ZERO:
		pos = Vector3(200.0, 40.0, -250.0)
		
	var courier := EnemyShipAI.new()
	courier.name = "SNet_Courier_01"
	add_child(courier)
	courier.setup("COURIER_SNET_01", EnemyShipAI.ShipType.DATA_COURIER, pos)
	courier.ship_name = "S-Net Courier Aegis"
	courier.comms_frequency = 1920.0
	
	courier.weapon_fired.connect(_on_enemy_weapon_fired.bind(courier))
	courier.ship_destroyed.connect(_on_enemy_destroyed)
	
	active_enemies.append(courier)
	if not is_in_combat:
		is_in_combat = true
		combat_engagement_started.emit()
		
	if SpaceWorldManager and SpaceWorldManager.has_method("_send_spawn_notification"):
		SpaceWorldManager._send_spawn_notification("📡 Rilevato convoglio corriere dati S-Net a 1920.0 MHz!")
		
	return courier

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

		var player_vel: Vector3 = Vector3.ZERO
		if SpaceWorldManager and SpaceWorldManager.has_method("get_spaceship_velocity"):
			player_vel = SpaceWorldManager.get_spaceship_velocity()
		elif player_ship_node and "linear_velocity" in player_ship_node:
			player_vel = player_ship_node.linear_velocity

		var muzzle_spd: float = 40.0
		var enemy_vel: Vector3 = enemy.velocity if enemy and is_instance_valid(enemy) else Vector3.ZERO
		var aim_dir := (player_pos - origin).normalized() if (player_pos - origin).length_squared() > 0.001 else Vector3.FORWARD
		var proj_vel: Vector3 = enemy_vel + (aim_dir * muzzle_spd)
		var is_kin: bool = (weapon_type != "torpedo")
		var v_rel: Vector3 = proj_vel - player_vel
		var applied_damage: float = damage
		if SpaceWorldManager and SpaceWorldManager.has_method("calculate_relative_kinetic_damage"):
			var dmg_calc: Dictionary = SpaceWorldManager.calculate_relative_kinetic_damage(damage, v_rel, muzzle_spd, is_kin)
			applied_damage = float(dmg_calc.get("damage", damage))

		if SpaceWorldManager and SpaceWorldManager.has_method("spawn_incoming_projectile"):
			var p_type := "TORPEDO" if weapon_type == "torpedo" else "KINETIC"
			SpaceWorldManager.spawn_incoming_projectile(p_type, origin, proj_vel, applied_damage, player_pos, muzzle_spd, is_kin)

		if systemic_damage_handler and is_instance_valid(systemic_damage_handler):
			systemic_damage_handler.process_hit(hit_dir_local, applied_damage, "plasma" if weapon_type == "torpedo" else "kinetic")

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
	enemy_ship_destroyed.emit(ship_id, ship_type, pos)
	
	# Notifica MissionManager autonomo se disponibile
	var mm = get_node_or_null("/root/MissionManager")
	if mm == null and ClassDB.class_exists("MissionManagerSingleton") and MissionManagerSingleton.instance:
		mm = MissionManagerSingleton.instance
	if mm and mm.has_method("on_enemy_destroyed"):
		mm.on_enemy_destroyed(ship_id, "PIRATES", pos)

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

# =============================================================================
# GUERRA ELETTRONICA NEMICA (EW) & INIEZIONE EXPLOIT .DAT
# =============================================================================

## Elabora il ciclo di guerra elettronica: timeout intrusioni attive e tentativi di attacco nemico
func process_cyber_warfare(delta: float) -> void:
	# 1. Avanzamento e controllo timeout delle intrusioni attive
	var expired_ids: Array[String] = []
	for intrusion_id in active_intrusions.keys():
		var intrusion: Dictionary = active_intrusions[intrusion_id]
		var cur_rem: float = float(intrusion.get("remaining_time", 0.0)) - delta
		intrusion["remaining_time"] = cur_rem
		if cur_rem <= 0.0:
			expired_ids.append(intrusion_id)
			
	for exp_id in expired_ids:
		detonate_cyber_intrusion(exp_id)
		
	# 2. Timer attacco EW nemico durante scontro a fuoco
	if not is_in_combat or active_enemies.is_empty():
		cyber_attack_timer = 0.0
		return
		
	cyber_attack_timer += delta
	if cyber_attack_timer >= cyber_attack_interval:
		cyber_attack_timer = 0.0
		var has_ew_threat := false
		for enemy in active_enemies:
			if is_instance_valid(enemy) and enemy.current_health > 0:
				has_ew_threat = true
				break
		if has_ew_threat and randf() <= cyber_attack_chance:
			trigger_hostile_cyber_attack()

## Sferra un attacco informatico ostile iniettando un file sentinella .dat nello Ship Drive
func trigger_hostile_cyber_attack(exploit_type: String = "") -> Dictionary:
	if exploit_type.is_empty() or not HOSTILE_EXPLOIT_TYPES.has(exploit_type):
		var keys := HOSTILE_EXPLOIT_TYPES.keys()
		exploit_type = keys[randi() % keys.size()]
		
	var profile: Dictionary = HOSTILE_EXPLOIT_TYPES[exploit_type]
	var folder: String = profile.get("folder", "Ship Drive/Programs")
	var file_name: String = profile.get("file_name", "malware_sentinel.dat")
	var rel_file_path := "%s/%s" % [folder, file_name]
	var timeout: float = float(profile.get("timeout", 30.0))
	var desc: String = profile.get("description", "Intrusione malware ostile.")
	
	var intrusion_id := "EW_INTRUSION_%d_%s" % [_next_intrusion_seq, exploit_type]
	_next_intrusion_seq += 1
	
	# Inietta il file malevolo nello Ship Drive tramite ShipDriveManager
	var sdm = get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_method("inject_intrusion_file"):
		var content := "# INTRUSION EXPLOIT SENTINEL [%s]\n[PAYLOAD]\nid=%s\ntype=%s\ntarget=%s\nexpiry=%.1f\n" % [
			intrusion_id, intrusion_id, exploit_type, rel_file_path, timeout
		]
		sdm.inject_intrusion_file(rel_file_path, content)
	else:
		# Fallback di scrittura file se il singleton non è montato nel tree
		var abs_path := "user://files/%s" % rel_file_path
		var dir := abs_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)
		var f := FileAccess.open(abs_path, FileAccess.WRITE)
		if f:
			f.store_string("# INTRUSION EXPLOIT SENTINEL\n")
			f.close()
			
	var intrusion_info := {
		"id": intrusion_id,
		"exploit_type": exploit_type,
		"file_path": rel_file_path,
		"remaining_time": timeout,
		"total_timeout": timeout,
		"description": desc
	}
	active_intrusions[intrusion_id] = intrusion_info
	
	# Emetti segnale intrusione
	cyber_intrusion_detected.emit(intrusion_id, exploit_type, rel_file_path, timeout)
	
	# Notifica diegetica prioritaria su GodotOS
	var notif = get_node_or_null("/root/NotificationManager")
	var alert_msg := "⚠️ INTRUSIONE EW NEMICA! %s iniettato in %s. Timeout: %.0fs!" % [exploit_type, rel_file_path.get_file(), timeout]
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification(alert_msg)
	elif ClassDB.class_exists("NotificationManagerSingleton") and NotificationManagerSingleton.instance:
		NotificationManagerSingleton.instance.spawn_notification(alert_msg)
		
	return intrusion_info

## Rileva l'eliminazione di file dallo Ship Drive per neutralizzare le intrusioni
func _on_ship_drive_item_deleted(deleted_path: String) -> void:
	var norm_deleted := deleted_path.replace("\\", "/").strip_edges().trim_prefix("/").trim_suffix("/")
	var cleared_ids: Array[String] = []
	for intrusion_id in active_intrusions.keys():
		var intrusion: Dictionary = active_intrusions[intrusion_id]
		var file_path: String = str(intrusion.get("file_path", "")).replace("\\", "/").strip_edges().trim_prefix("/").trim_suffix("/")
		if norm_deleted == file_path or norm_deleted.ends_with(file_path.get_file()) or file_path.ends_with(norm_deleted):
			cleared_ids.append(intrusion_id)
			
	for c_id in cleared_ids:
		clear_cyber_intrusion(c_id)

## Neutralizza l'intrusione malware rimuovendo le anomalie sistemiche
func clear_cyber_intrusion(intrusion_id: String) -> bool:
	if not active_intrusions.has(intrusion_id):
		return false
	var intrusion: Dictionary = active_intrusions[intrusion_id]
	var exploit_type: String = intrusion.get("exploit_type", "")
	var file_path: String = intrusion.get("file_path", "")
	active_intrusions.erase(intrusion_id)
	
	# Se il file esiste ancora su disco, rimuovilo
	var abs_path := "user://files/%s" % file_path
	if FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)
		
	cyber_intrusion_cleared.emit(intrusion_id, exploit_type)
	
	var notif = get_node_or_null("/root/NotificationManager")
	var success_msg := "✔ THREAT NEUTRALIZED: Exploit %s disinfettato dallo Ship Drive." % exploit_type
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification(success_msg)
	elif ClassDB.class_exists("NotificationManagerSingleton") and NotificationManagerSingleton.instance:
		NotificationManagerSingleton.instance.spawn_notification(success_msg)
		
	return true

## Detona l'exploit alla scadenza del timeout, scatenando guasti fisici diegetici
func detonate_cyber_intrusion(intrusion_id: String) -> void:
	if not active_intrusions.has(intrusion_id):
		return
	var intrusion: Dictionary = active_intrusions[intrusion_id]
	var exploit_type: String = intrusion.get("exploit_type", "")
	var file_path: String = intrusion.get("file_path", "")
	active_intrusions.erase(intrusion_id)
	
	# Rimuovi file residuo per evitare detonazioni duplicate
	var abs_path := "user://files/%s" % file_path
	if FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)
		
	# Danno critico diegetico sui sottosistemi di bordo
	if systemic_damage_handler and is_instance_valid(systemic_damage_handler):
		match exploit_type:
			"REACTOR_OVERLOAD":
				# Cortocircuito critico alla sezione poppiera
				systemic_damage_handler.process_hit(Vector3(0.0, 1.2, 2.0), 45.0, "emp")
			"PROPULSION_WORM":
				# Danno propulsori con incendio
				systemic_damage_handler.process_hit(Vector3(0.0, 0.0, 2.5), 40.0, "kinetic")
			"BLIND_EYE", _:
				# Danno sensori e telecamere anteriori
				systemic_damage_handler.process_hit(Vector3(0.0, 0.0, -2.0), 35.0, "plasma")
				
	cyber_intrusion_detonated.emit(intrusion_id, exploit_type)
	
	var notif = get_node_or_null("/root/NotificationManager")
	var det_msg := "💥 CRITICAL FAILURE: Exploit %s detonato! Danni sistemici a bordo." % exploit_type
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification(det_msg)
	elif ClassDB.class_exists("NotificationManagerSingleton") and NotificationManagerSingleton.instance:
		NotificationManagerSingleton.instance.spawn_notification(det_msg)

## Verifica se una determinata anomalia exploit è attualmente attiva
func is_exploit_active(exploit_type: String) -> bool:
	for intrusion in active_intrusions.values():
		if intrusion.get("exploit_type") == exploit_type:
			return true
	return false

## Restituisce il dizionario di tutte le intrusioni cyber attive
func get_active_intrusions() -> Dictionary:
	return active_intrusions

## Verifica se sono presenti intrusioni cyber nemiche non neutralizzate
func has_active_intrusion() -> bool:
	return not active_intrusions.is_empty()
