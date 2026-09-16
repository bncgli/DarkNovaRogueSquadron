extends GutTest

## Suite di Test GUT per la Fisica Balistica Newtoniana & Combattimento Hard Sci-Fi (Fase E).
## Valida:
## 1. Addizione vettoriale galileiana della velocità nave alle munizioni (v_proj = v_ship + d_aim * v_muzzle).
## 2. Variazione del danno cinetico relativo tra ingaggi frontali (head-on) e in allontanamento (tail-chase).
## 3. Impatto dei colpi nemici sulla nave corvetta modulato dalle manovre evasive del pilota.
## 4. Accuratezza del mirino predittivo (Lead Indicator) sul vettore di moto relativo (v_target - v_ship).
## 5. Rilevamento continuo delle collisioni tramite segment-sweep anti-tunneling.

func before_each() -> void:
	SpaceWorldManager.clear_active_ballistic_projectiles()
	SpaceWorldManager.clear_incoming_projectiles()
	SpaceWorldManager.clear_custom_ballistic_targets()
	SpaceWorldManager.clear_spaceship_velocity_override()

func after_each() -> void:
	SpaceWorldManager.clear_active_ballistic_projectiles()
	SpaceWorldManager.clear_incoming_projectiles()
	SpaceWorldManager.clear_custom_ballistic_targets()
	SpaceWorldManager.clear_spaceship_velocity_override()

## Scenario 1: Relatività Galileiana e Addizione Vettoriale di Volata
func test_galilean_velocity_addition() -> void:
	# Nave si muove in avanti verso -Z a 20 m/s
	var ship_v := Vector3(0, 0, -20)
	SpaceWorldManager.set_spaceship_velocity_override(ship_v)
	assert_eq(SpaceWorldManager.get_spaceship_velocity(), ship_v, "La velocità della nave deve riflettere il vettore impostato")

	# 1. Fuoco in avanti (d_aim = (0, 0, -1) con HEAVY_MG a muzzle_speed 180 m/s)
	var fire_front: Dictionary = SpaceWorldManager.request_fire_weapon("HEAVY_MG", "", Vector3(0, 0, -1))
	var p_front: Dictionary = fire_front.get("projectile", {})
	assert_false(p_front.is_empty(), "Proiettile frontale deve essere stato istanziato")
	var v_front: Vector3 = p_front.get("velocity", Vector3.ZERO)
	# v_proj = (0, 0, -20) + (0, 0, -1) * 180 = (0, 0, -200)
	assert_almost_eq(v_front.x, 0.0, 0.01, "Velocità X frontale deve essere 0")
	assert_almost_eq(v_front.y, 0.0, 0.01, "Velocità Y frontale deve essere 0")
	assert_almost_eq(v_front.z, -200.0, 0.01, "Velocità Z frontale deve essere -200 m/s (-20 + -180)")
	assert_almost_eq(v_front.length(), 200.0, 0.01, "Magnitudine velocità proiettile frontale = 200 m/s")

	# 2. Fuoco all'indietro (d_aim = (0, 0, 1) con HEAVY_CANNON a muzzle_speed 120 m/s)
	var fire_rear: Dictionary = SpaceWorldManager.request_fire_weapon("HEAVY_CANNON", "", Vector3(0, 0, 1))
	var p_rear: Dictionary = fire_rear.get("projectile", {})
	var v_rear: Vector3 = p_rear.get("velocity", Vector3.ZERO)
	# v_proj = (0, 0, -20) + (0, 0, 1) * 120 = (0, 0, 100)
	assert_almost_eq(v_rear.z, 100.0, 0.01, "Velocità Z posteriore deve essere 100 m/s (-20 + 120)")
	assert_almost_eq(v_rear.length(), 100.0, 0.01, "Magnitudine velocità posteriore = 100 m/s")

	# 3. Fuoco laterale a destra (d_aim = (1, 0, 0) con muzzle_speed 100 m/s fittizia / test)
	var p_lat := SpaceWorldManager.spawn_ballistic_projectile("TEST_CUSTOM", Vector3.ZERO, ship_v + Vector3(100, 0, 0), 100.0, 50.0)
	var v_lat: Vector3 = p_lat.get("velocity", Vector3.ZERO)
	# v_proj = (100, 0, -20)
	assert_almost_eq(v_lat.x, 100.0, 0.01)
	assert_almost_eq(v_lat.z, -20.0, 0.01)
	var expected_len := sqrt(100.0 * 100.0 + (-20.0) * (-20.0)) # ~101.98 m/s
	assert_almost_eq(v_lat.length(), expected_len, 0.05, "Magnitudine velocità laterale deve rispettare Pitagora (~101.98 m/s)")

## Scenario 2: Danno Cinetico Relativo all'Impatto (Head-On vs Tail-Chase)
func test_relative_kinetic_damage_head_on_vs_tail_chase() -> void:
	var base_dmg: float = 50.0
	var muzzle_spd: float = 100.0
	var v_proj := Vector3(0, 0, -100)

	# 2A: Head-On / Bersaglio viene incontro a v_target = (0, 0, 50) (+Z)
	var v_target_head_on := Vector3(0, 0, 50)
	var v_rel_head_on := v_proj - v_target_head_on # (0, 0, -150) -> length = 150
	var res_head_on := SpaceWorldManager.calculate_relative_kinetic_damage(base_dmg, v_rel_head_on, muzzle_spd, true)
	assert_almost_eq(float(res_head_on["multiplier"]), 1.5, 0.01, "Moltiplicatore head-on deve essere 150/100 = 1.5")
	assert_almost_eq(float(res_head_on["damage"]), 75.0, 0.01, "Danno head-on deve essere 50 * 1.5 = 75.0")

	# 2B: Tail-Chase / Bersaglio fugge nella stessa direzione a v_target = (0, 0, -50) (-Z)
	var v_target_tail_chase := Vector3(0, 0, -50)
	var v_rel_tail_chase := v_proj - v_target_tail_chase # (0, 0, -50) -> length = 50
	var res_tail_chase := SpaceWorldManager.calculate_relative_kinetic_damage(base_dmg, v_rel_tail_chase, muzzle_spd, true)
	assert_almost_eq(float(res_tail_chase["multiplier"]), 0.5, 0.01, "Moltiplicatore tail-chase deve essere 50/100 = 0.5")
	assert_almost_eq(float(res_tail_chase["damage"]), 25.0, 0.01, "Danno tail-chase deve essere 50 * 0.5 = 25.0")

	# 2C: Clamp inferiore di sicurezza (bersaglio fugge quasi alla stessa velocità o più veloce)
	var v_target_faster := Vector3(0, 0, -95)
	var v_rel_slow := v_proj - v_target_faster # length = 5.0 -> 5/100 = 0.05 < clamp min (0.25)
	var res_clamp_min := SpaceWorldManager.calculate_relative_kinetic_damage(base_dmg, v_rel_slow, muzzle_spd, true)
	assert_almost_eq(float(res_clamp_min["multiplier"]), 0.25, 0.01, "Moltiplicatore minimo deve essere clampato a 0.25")
	assert_almost_eq(float(res_clamp_min["damage"]), 12.5, 0.01, "Danno minimo non deve scendere sotto il 25% del base")

	# 2D: Clamp superiore di sicurezza (impatto ad altissima velocità relativa)
	var v_target_hypersonic := Vector3(0, 0, 300) # v_rel length = 400 -> 400/100 = 4.0 > clamp max (2.5)
	var res_clamp_max := SpaceWorldManager.calculate_relative_kinetic_damage(base_dmg, v_proj - v_target_hypersonic, muzzle_spd, true)
	assert_almost_eq(float(res_clamp_max["multiplier"]), 2.5, 0.01, "Moltiplicatore massimo deve essere clampato a 2.5")
	assert_almost_eq(float(res_clamp_max["damage"]), 125.0, 0.01, "Danno massimo non deve superare il 250% del base")

	# 2E: Proiettili non cinetici (es. missili/sonde)
	var res_non_kinetic := SpaceWorldManager.calculate_relative_kinetic_damage(base_dmg, v_rel_head_on, muzzle_spd, false)
	assert_almost_eq(float(res_non_kinetic["multiplier"]), 1.0, 0.01, "Armi non cinetiche non subiscono scaling cinetico")
	assert_almost_eq(float(res_non_kinetic["damage"]), 50.0, 0.01, "Danno non cinetico rimane identico al base")

## Scenario 3: Impatto Newtoniano dei Colpi Nemici sulla Corvetta e Manovra Evasiva
func test_enemy_incoming_projectile_relative_damage() -> void:
	var director := CombatDirector.new()
	var player_dummy := Node3D.new()
	var dmg_handler := SystemicDamageHandler.new()
	add_child_autofree(director)
	add_child_autofree(player_dummy)
	add_child_autofree(dmg_handler)
	
	director.setup(player_dummy, dmg_handler)
	
	var enemy := EnemyShipAI.new()
	add_child_autofree(enemy)
	enemy.setup("PIRATE_TEST", EnemyShipAI.ShipType.PIRATE_FIGHTER, Vector3(0, 0, -40))
	enemy.velocity = Vector3(0, 0, 10) # Nemico avanza verso la corvetta a 10 m/s
	
	# Caso A: Corvetta ferma (v_ship = 0)
	SpaceWorldManager.set_spaceship_velocity_override(Vector3.ZERO)
	dmg_handler.reset()
	var initial_shield: float = dmg_handler.shields[GlobalValues.Quadrant.FORE]
	director._on_enemy_weapon_fired("laser_burst", enemy.global_position, player_dummy.global_position, 20.0, enemy)
	var dmg_static: float = initial_shield - dmg_handler.shields[GlobalValues.Quadrant.FORE]
	
	# Caso B: Corvetta accelera in avanti incontro al colpo (Head-On charge: v_ship = (0, 0, -20))
	SpaceWorldManager.set_spaceship_velocity_override(Vector3(0, 0, -20))
	dmg_handler.reset()
	director._on_enemy_weapon_fired("laser_burst", enemy.global_position, player_dummy.global_position, 20.0, enemy)
	var dmg_charge: float = initial_shield - dmg_handler.shields[GlobalValues.Quadrant.FORE]
	
	# Caso C: Corvetta accelera in fuga (Evasive burn away: v_ship = (0, 0, 20))
	SpaceWorldManager.set_spaceship_velocity_override(Vector3(0, 0, 20))
	dmg_handler.reset()
	director._on_enemy_weapon_fired("laser_burst", enemy.global_position, player_dummy.global_position, 20.0, enemy)
	var dmg_evade: float = initial_shield - dmg_handler.shields[GlobalValues.Quadrant.FORE]
	
	assert_gt(dmg_charge, dmg_static, "La corvetta che carica frontalmente deve subire maggiore danno d'impatto")
	assert_lt(dmg_evade, dmg_static, "La manovra evasiva in fuga deve ridurre il danno cinetico subito")

## Scenario 4: Precisione del Lead Indicator Relativo
func test_weapons_lead_indicator_relative_velocity() -> void:
	# Bersaglio trasla lateralmente a 15 m/s (+X)
	var t_vel := Vector3(15, 0, 0)
	var t_dist: float = 150.0
	var muzzle_speed: float = 150.0 # Flight time = 1.0 secondo
	
	# Caso A: Nave madre ferma
	var ship_v_zero := Vector3.ZERO
	var rel_vel_static := t_vel - ship_v_zero
	var flight_time := t_dist / muzzle_speed
	var lead_offset_static := rel_vel_static * flight_time
	assert_almost_eq(lead_offset_static.x, 15.0, 0.01, "A nave ferma il lead punta a +15m")
	
	# Caso B: Nave madre vola in parallelo alla stessa velocità (v_ship = v_target = (15, 0, 0))
	var ship_v_parallel := Vector3(15, 0, 0)
	var rel_vel_parallel := t_vel - ship_v_parallel
	var lead_offset_parallel := rel_vel_parallel * flight_time
	assert_almost_eq(lead_offset_parallel.x, 0.0, 0.001, "A velocità concorde il moto relativo laterale deve essere 0")
	assert_almost_eq(lead_offset_parallel.length(), 0.0, 0.001, "Lead indicator deve coincidere col centro bersaglio")

## Scenario 5: Collisione Segment-Sweep e Risoluzione Danno su Bersaglio
func test_ballistic_projectile_segment_sweep_collision() -> void:
	# Crea caccia nemico con 100 HP di scafo
	var dummy_enemy := EnemyShipAI.new()
	add_child_autofree(dummy_enemy)
	dummy_enemy.setup("TARGET_SWEEP", EnemyShipAI.ShipType.PIRATE_FIGHTER, Vector3(0, 0, 0))
	dummy_enemy.current_shield = 0.0
	dummy_enemy.current_health = 100.0
	dummy_enemy.velocity = Vector3(0, 0, 50) # Avanza verso +Z a 50 m/s
	
	# Registra bersaglio
	SpaceWorldManager.register_ballistic_target(dummy_enemy)
	
	# Spawna proiettile ad altissima velocità che salta da (0, 0, -60) a (0, 0, 60) in un singolo delta
	# Muzzle speed = 100, Base damage = 40
	# v_proj = (0, 0, 600) -> in delta = 0.1s si muove di 60m attraversando l'origine (0, 0, 0)
	var p_data := SpaceWorldManager.spawn_ballistic_projectile(
		"HEAVY_CANNON",
		Vector3(0, 0, -40),
		Vector3(0, 0, 400), # Verso +Z
		100.0,
		40.0,
		2.5,
		5.0,
		true
	)
	
	assert_eq(SpaceWorldManager.get_active_ballistic_projectiles().size(), 1, "Proiettile registrato nel buffer")
	
	# Esegui tick di aggiornamento della simulazione balistica
	SpaceWorldManager._update_ballistic_projectiles(0.2)
	
	# Verifica impatto e rimozione proiettile
	assert_eq(SpaceWorldManager.get_active_ballistic_projectiles().size(), 0, "Proiettile deve essersi distrutto all'impatto")
	# v_rel = (0, 0, 400) - (0, 0, 50) = (0, 0, 350) -> mult clampato a 2.5
	# Danno = 40 * 2.5 = 100.0
	assert_lte(dummy_enemy.current_health, 0.0, "Il caccia nemico deve aver subito il colpo letale da danno cinetico moltiplicato")
