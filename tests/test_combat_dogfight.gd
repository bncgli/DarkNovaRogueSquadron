extends Node

## Suite di Test Headless per il Modulo Dogfight & Combattimento Spaziale Asimmetrico.
## Valida:
## 1. Comportamento ad albero decisionale / FSM dell'IA nemica in combattimento (EnemyShipAI).
## 2. Guerra Elettronica (Jamming puntamento ed exploit firmware motori).
## 3. Gestione impatti e danni sistemici localizzati su scudi a 4 quadranti e scafo (SystemicDamageHandler).
## 4. Trigger diegetico dei livelli di Allarme Giallo e Allarme Rosso.
## 5. Regia incontri, ondate e coordinamento tattico (CombatDirector).

func _ready() -> void:
	print("==================================================================")
	print("INIZIO SUITE DI TEST: COMBATTIMENTI SPAZIALI, DOGFIGHT & ASYMMETRIC TACTICS")
	print("==================================================================")

	test_enemy_ai_state_machine()
	test_enemy_ai_electronic_warfare()
	test_systemic_damage_and_quadrant_shields()
	test_alarm_level_triggers()
	test_combat_director_waves_and_coordination()

	print("==================================================================")
	print("✅ TUTTI I TEST COMBAT DOGFIGHT COMPLETATI CON SUCCESSO!")
	print("==================================================================")
	get_tree().quit(0)

func test_enemy_ai_state_machine() -> void:
	print("\n--- TEST 1: EnemyShipAI Decision Tree & State Machine ---")
	
	var fighter := EnemyShipAI.new()
	add_child(fighter)
	fighter.setup("PIRATE_01", EnemyShipAI.ShipType.PIRATE_FIGHTER, Vector3(0, 0, 100))
	
	# In assenza di bersagli o fuori portata -> PATROL
	fighter._evaluate_decision_tree(0.1)
	assert(fighter.current_state == EnemyShipAI.AIState.PATROL, "IA deve iniziare in stato PATROL senza bersaglio ravvicinato")

	# Bersaglio a portata di ingaggio (50m) -> SWARM_CHASE
	fighter.target_position = Vector3(0, 0, 50)
	fighter._evaluate_decision_tree(0.1)
	assert(fighter.current_state == EnemyShipAI.AIState.SWARM_CHASE, "Caccia pirata deve passare a SWARM_CHASE a portata di ingaggio")

	# Se molto vicino (15m, distanza tra 100 e 85 = 15m) -> EVASIVE_STRAFE
	fighter.target_position = Vector3(0, 0, 85)
	fighter._evaluate_decision_tree(0.1)
	assert(fighter.current_state == EnemyShipAI.AIState.EVASIVE_STRAFE, "Caccia pirata deve manovrare in EVASIVE_STRAFE a distanza ravvicinata")

	# Danno critico alla nave (sotto 25%) -> TACTICAL_RETREAT
	# max_shield = 50, max_health = 90. 50 assorbiti da scudo, 70 di danno allo scafo -> salute rimasta = 20 (20/90 = 22.2% <= 25%)
	fighter.take_damage(120.0)
	fighter._evaluate_decision_tree(0.1)
	assert(fighter.current_state == EnemyShipAI.AIState.TACTICAL_RETREAT, "Caccia gravemente danneggiato deve entrare in TACTICAL_RETREAT")

	# Test Corvette e Torpedo Bombing
	var corvette := EnemyShipAI.new()
	add_child(corvette)
	corvette.setup("CORVETTE_01", EnemyShipAI.ShipType.PATROL_CORVETTE, Vector3(0, 0, 80))
	corvette.target_position = Vector3(0, 0, 0)
	corvette._evaluate_decision_tree(0.1)
	assert(corvette.current_state == EnemyShipAI.AIState.TORPEDO_BOMBING, "Corvetta deve prediligere TORPEDO_BOMBING a distanza di ingaggio")

	fighter.queue_free()
	corvette.queue_free()
	print("✓ Test 1 superato: State Machine e Decision Tree convalidati.")

func test_enemy_ai_electronic_warfare() -> void:
	print("\n--- TEST 2: Guerra Elettronica (EW, Jamming, Firmware Exploit) ---")

	var enemy := EnemyShipAI.new()
	add_child(enemy)
	enemy.setup("TARGET_01", EnemyShipAI.ShipType.PIRATE_FIGHTER, Vector3(0, 0, 30))

	# Hacker inietta exploit firmware per spegnere i motori
	enemy.inject_firmware_exploit(5.0)
	assert(enemy.is_firmware_hacked == true, "L'exploit firmware deve impostare is_firmware_hacked a true")
	assert(enemy.current_state == EnemyShipAI.AIState.DISABLED, "La nave hackerata deve entrare in stato DISABLED")

	# Hacker attiva Comms Jamming
	enemy.apply_comms_jamming(4.0, 0.7)
	assert(enemy.is_jammed == true, "Comms jamming deve rendere is_jammed attivo")
	assert(enemy.accuracy_penalty >= 0.7, "Comms jamming deve infliggere penalità di puntamento")

	# Avanzamento tempo per scadenza effetti
	enemy._update_ew_effects(6.0)
	assert(enemy.is_jammed == false, "Jamming deve scadere dopo la durata")
	assert(enemy.is_firmware_hacked == false, "Firmware exploit deve scadere dopo la durata")

	enemy.queue_free()
	print("✓ Test 2 superato: Meccaniche di Guerra Elettronica & Hacker convalidate.")

func test_systemic_damage_and_quadrant_shields() -> void:
	print("\n--- TEST 3: Systemic Damage Handler & 4-GlobalValues.Quadrant Shields ---")

	var dmg_handler := SystemicDamageHandler.new()
	add_child(dmg_handler)
	dmg_handler.reset()

	# 1. Impatto da prua (FORE)
	var hit_front := dmg_handler.process_hit(Vector3(0, 0, -5), 40.0, "kinetic")
	assert(hit_front.quadrant == "FORE", "Impatto con Z negativa deve colpire quadrante FORE")
	assert(hit_front.shield_absorbed > 0.0, "Lo scudo frontale deve assorbire parte del danno")
	assert(dmg_handler.shields[GlobalValues.Quadrant.FORE] < 100.0, "Scudo FORE deve essere ridotto")

	# 2. Impatto da poppa (AFT)
	var hit_rear := dmg_handler.process_hit(Vector3(0, 0, 5), 30.0, "kinetic")
	assert(hit_rear.quadrant == "AFT", "Impatto con Z positiva deve colpire quadrante AFT")
	assert(dmg_handler.shields[GlobalValues.Quadrant.AFT] < 100.0, "Scudo AFT deve essere ridotto")

	# 3. Impatto da Babordo (PORT, -X) e Tribordo (STARBOARD, +X)
	var hit_port := dmg_handler.process_hit(Vector3(-5, 0, 0), 20.0, "kinetic")
	var hit_stbd := dmg_handler.process_hit(Vector3(5, 0, 0), 20.0, "kinetic")
	assert(hit_port.quadrant == "PORT", "Impatto -X deve colpire quadrante PORT")
	assert(hit_stbd.quadrant == "STARBOARD", "Impatto +X deve colpire quadrante STARBOARD")

	# 4. Colpo pesante che abbatte lo scudo e penetra nello scafo
	var heavy_hit := dmg_handler.process_hit(Vector3(0, 0, -5), 150.0, "plasma")
	assert(dmg_handler.shields[GlobalValues.Quadrant.FORE] == 0.0, "Scudo FORE deve essere esaurito")
	assert(heavy_hit.hull_damage > 0.0, "Danno penetrante deve intaccare lo scafo")
	assert(dmg_handler.hull_integrity < 100.0, "Integrità scafo deve diminuire")
	assert(not heavy_hit.systemic_events.is_empty(), "Danno penetrante deve generare avarie a sottosistemi di bordo")

	dmg_handler.queue_free()
	print("✓ Test 3 superato: Scudi a 4 quadranti e propagazione danni convalidati.")

func test_alarm_level_triggers() -> void:
	print("\n--- TEST 4: Trigger Diegetici Livelli di Allarme (Giallo / Rosso) ---")

	var dmg_handler := SystemicDamageHandler.new()
	add_child(dmg_handler)
	dmg_handler.reset()

	assert(dmg_handler.current_alarm_level == GlobalValues.AlarmLevel.NORMAL, "Stato iniziale allarme deve essere NORMAL")

	# Scarica uno scudo a zero -> Trigger ALLARME GIALLO
	dmg_handler.set_shield_quadrant_value(GlobalValues.Quadrant.FORE, 0.0)
	assert(dmg_handler.current_alarm_level == GlobalValues.AlarmLevel.YELLOW_ALERT, "Esaurimento scudo su un quadrante deve innescare YELLOW_ALERT")

	# Danno critico allo scafo (< 25%) -> Trigger ALLARME ROSSO
	dmg_handler.hull_integrity = 20.0
	dmg_handler._evaluate_alarm_level()
	assert(dmg_handler.current_alarm_level == GlobalValues.AlarmLevel.RED_ALERT, "Integrità scafo < 25% deve innescare RED_ALERT")

	# Riparazione scafo e scudi -> Ritorno a NORMAL
	dmg_handler.repair_hull(80.0)
	dmg_handler.set_shield_quadrant_value(GlobalValues.Quadrant.FORE, 100.0)
	assert(dmg_handler.current_alarm_level == GlobalValues.AlarmLevel.NORMAL, "Dopo riparazioni l'allarme deve tornare a NORMAL")

	dmg_handler.queue_free()
	print("✓ Test 4 superato: Allarme Giallo e Allarme Rosso convalidati.")

func test_combat_director_waves_and_coordination() -> void:
	print("\n--- TEST 5: CombatDirector Encounter Orchestration & Waves ---")

	var director := CombatDirector.new()
	var player_dummy := Node3D.new()
	add_child(player_dummy)
	add_child(director)
	director.setup(player_dummy)

	# Spawn Ondata 1 (2 Droni, 1 Caccia)
	var spawned_enemies := director.spawn_wave(1)
	assert(director.is_in_combat == true, "CombatDirector deve essere in combattimento dopo spawn ondata")
	assert(spawned_enemies.size() == 3, "Ondata 1 deve contenere 3 nemici")
	assert(director.active_enemies.size() == 3, "Active enemies deve tracciare 3 navi")

	# Test attacco soldato
	var target_id: String = spawned_enemies[0].ship_id
	var hit_res := director.fire_player_weapon_at(target_id, 100.0)
	assert(hit_res.is_destroyed == true, "Colpo ad alto danno deve distruggere il drone nemico")

	# Test EW Hacker tramite CombatDirector
	var target_fighter_id: String = spawned_enemies[2].ship_id
	var jam_ok := director.execute_ew_jamming(target_fighter_id, 6.0)
	assert(jam_ok == true, "EW Jamming tramite director deve avere successo")

	var hack_ok := director.execute_firmware_exploit(target_fighter_id, 8.0)
	assert(hack_ok == true, "Firmware Exploit tramite director deve avere successo")

	# Distruzione dei restanti nemici
	for e in director.active_enemies:
		if is_instance_valid(e):
			e.take_damage(500.0)

	director._process(0.1)
	assert(director.is_in_combat == false, "Dopo eliminazione nemici il combattimento deve terminare")

	director.queue_free()
	player_dummy.queue_free()
	print("✓ Test 5 superato: CombatDirector e cooperazione asimmetrica convalidati.")
