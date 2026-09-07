class_name SystemicDamageHandler
extends Node

## Gestore dei Danni Sistemici Localizzati e Livelli di Allarme di Bordo.
## Calcola gli impatti fisici/balistici/energetici su scudi (4 quadranti: FORE, AFT, PORT, STARBOARD)
## e propaga i danni che penetrano lo scafo ai rispettivi sottosistemi di bordo:
## - Breccia scafo (dmg_breach)
## - Cortocircuiti elettrici (PowerGrid)
## - Avaria sensori (Sensors)
## - Focolai d'incendio e perdite O2 (LifeSupport)
## Gestisce ed emette gli allarmi diegetici di bordo (Allarme Giallo, Allarme Rosso, Normale).

signal damage_applied(damage_event: Dictionary)
signal alarm_level_changed(old_level: GlobalValues.AlarmLevel, new_level: GlobalValues.AlarmLevel, reason: String)
signal subsystem_malfunction(subsystem: String, malfunction_type: String, severity: float)

# --- STATO SCUDI ---
# Capacità scudi per quadrante (0.0 - 100.0)
var shields: Dictionary = {
	GlobalValues.Quadrant.FORE: 100.0,
	GlobalValues.Quadrant.AFT: 100.0,
	GlobalValues.Quadrant.PORT: 100.0,
	GlobalValues.Quadrant.STARBOARD: 100.0
}
var max_shield_per_quadrant: float = 100.0
var shield_absorption_rate: float = 0.85 # 85% assorbito dallo scudo, 15% bleeds through se scudo attivo

# --- STATO SCAFO E INTEGRITÀ DEI SOTTOSISTEMI ---
var hull_integrity: float = 100.0 # 0.0 - 100.0
var max_hull_integrity: float = 100.0
var is_reactor_critical: bool = false
var has_critical_breach: bool = false

# Integrità sottosistemi (100.0 = perfetto, 0.0 = distrutto/offline)
var subsystem_integrity: Dictionary = {
	"engines": 100.0,
	"weapons": 100.0,
	"sensors": 100.0,
	"life_support": 100.0,
	"power_grid": 100.0,
	"comms": 100.0
}

# --- STATO ALLARME ---
var current_alarm_level: GlobalValues.AlarmLevel = GlobalValues.AlarmLevel.NORMAL
var active_alarms_reasons: Array[String] = []

func _ready() -> void:
	reset()

func reset() -> void:
	for q in [GlobalValues.Quadrant.FORE, GlobalValues.Quadrant.AFT, GlobalValues.Quadrant.PORT, GlobalValues.Quadrant.STARBOARD]:
		shields[q] = max_shield_per_quadrant
	hull_integrity = max_hull_integrity
	is_reactor_critical = false
	has_critical_breach = false
	for sub in subsystem_integrity.keys():
		subsystem_integrity[sub] = 100.0
	current_alarm_level = GlobalValues.AlarmLevel.NORMAL
	active_alarms_reasons.clear()

## Calcola quale quadrante dello scudo viene colpito in base all'angolo/direzione di impatto
func get_quadrant_from_hit_direction(hit_dir_local: Vector3) -> GlobalValues.Quadrant:
	var dir_norm := hit_dir_local.normalized()
	# In coordinate locali nave Godot (-Z è prua/avanti, +Z è poppa/dietro, -X è babordo/sinistra, +X è tribordo/destra)
	var fwd_dot := -dir_norm.z # Se positivo, viene da davanti (FORE)
	var right_dot := dir_norm.x # Se positivo, viene da destra (STARBOARD)

	if abs(fwd_dot) >= abs(right_dot):
		return GlobalValues.Quadrant.FORE if fwd_dot >= 0.0 else GlobalValues.Quadrant.AFT
	else:
		return GlobalValues.Quadrant.STARBOARD if right_dot >= 0.0 else GlobalValues.Quadrant.PORT

## Processa un impatto di combattimento contro la nave
func process_hit(hit_position_local: Vector3, raw_damage: float, damage_type: String = "kinetic") -> Dictionary:
	var quadrant := get_quadrant_from_hit_direction(hit_position_local)
	var current_q_shield: float = shields.get(quadrant, 0.0)
	
	var shield_absorbed := 0.0
	var penetrating_damage := 0.0

	if current_q_shield > 0.0:
		var absorbed_potential := raw_damage * shield_absorption_rate
		if current_q_shield >= absorbed_potential:
			shields[quadrant] -= absorbed_potential
			shield_absorbed = absorbed_potential
			penetrating_damage = raw_damage - absorbed_potential
		else:
			shield_absorbed = current_q_shield
			var leftover := raw_damage - (current_q_shield / shield_absorption_rate)
			shields[quadrant] = 0.0
			penetrating_damage = leftover
	else:
		penetrating_damage = raw_damage

	# Danno allo scafo e propagazione ai sistemi se il danno penetra
	var hull_damage_dealt := 0.0
	var systemic_events: Array[Dictionary] = []

	if penetrating_damage > 0.0:
		hull_damage_dealt = penetrating_damage * 0.75
		hull_integrity = max(0.0, hull_integrity - hull_damage_dealt)
		systemic_events = _apply_penetrating_systemic_damage(hit_position_local, penetrating_damage, damage_type)

	var result := {
		"quadrant": GlobalValues.Quadrant.keys()[quadrant],
		"raw_damage": raw_damage,
		"shield_absorbed": shield_absorbed,
		"shield_remaining": shields[quadrant],
		"hull_damage": hull_damage_dealt,
		"hull_integrity": hull_integrity,
		"systemic_events": systemic_events,
		"hit_position": hit_position_local
	}

	damage_applied.emit(result)
	_evaluate_alarm_level()

	# Sincronizzazione con SpaceWorldManager se disponibile nel tree
	_sync_with_space_world_manager(systemic_events)

	return result

## Propaga il danno penetrato allo scafo ai componenti specifici in base alla posizione e tipo
func _apply_penetrating_systemic_damage(hit_pos: Vector3, dmg: float, dmg_type: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var norm_z := hit_pos.z # -Z prua, +Z poppa
	var norm_x := hit_pos.x # -X sinistra, +X destra
	var norm_y := hit_pos.y # Y altezza

	# Determinazione del sottosistema affetto in base alla zona della nave
	var target_subsystem := ""
	var malfunction_type := ""

	if norm_z < -1.0:
		# Sezione di Prua -> Sensori & Avionica o Armi frontali
		if abs(norm_x) < 1.0:
			target_subsystem = "sensors"
			malfunction_type = "sensor_blindness"
		else:
			target_subsystem = "weapons"
			malfunction_type = "weapon_offline"
	elif norm_z > 1.0:
		# Sezione di Poppa -> Motori o Power Grid / Reattore
		if abs(norm_y) < 0.5:
			target_subsystem = "engines"
			malfunction_type = "thruster_overheat"
		else:
			target_subsystem = "power_grid"
			malfunction_type = "short_circuit"
	else:
		# Sezione Centrale -> Supporto Vitale / Comunicazioni / Breccia Principale
		if abs(norm_x) < 1.5:
			target_subsystem = "life_support"
			malfunction_type = "oxygen_leak" if dmg < 25.0 else "fire_hazard"
		else:
			target_subsystem = "comms"
			malfunction_type = "antenna_array_fault"

	# Danno al sottosistema
	var sub_damage := dmg * 0.8
	var current_sub_hp: float = float(subsystem_integrity.get(target_subsystem, 100.0))
	var new_sub_hp: float = max(0.0, current_sub_hp - sub_damage)
	subsystem_integrity[target_subsystem] = new_sub_hp

	var evt := {
		"subsystem": target_subsystem,
		"malfunction_type": malfunction_type,
		"damage": sub_damage,
		"remaining_integrity": new_sub_hp,
		"is_critical": new_sub_hp <= 20.0
	}
	events.append(evt)
	subsystem_malfunction.emit(target_subsystem, malfunction_type, sub_damage)

	# Se danno elevato, genera anche una breccia nello scafo
	if dmg >= 20.0 or hull_integrity < 35.0:
		has_critical_breach = true
		events.append({
			"subsystem": "hull",
			"malfunction_type": "dmg_breach",
			"damage": dmg,
			"room": _get_nearest_duct_room(hit_pos),
			"is_critical": true
		})

	# Se il reattore o power grid scende a 0
	if target_subsystem == "power_grid" and new_sub_hp <= 0.0:
		is_reactor_critical = true

	return events

func _get_nearest_duct_room(hit_pos: Vector3) -> String:
	if hit_pos.z < -1.0:
		return "bridge" if hit_pos.x == 0 else "sensors"
	elif hit_pos.z > 1.0:
		return "reactor" if abs(hit_pos.x) < 1.0 else "engines"
	else:
		return "life_support" if hit_pos.x < 0 else "cargo"

## Valuta lo stato di allarme diegetico (Allarme Giallo, Allarme Rosso, Normale)
func _evaluate_alarm_level() -> void:
	var old_level := current_alarm_level
	var new_level := GlobalValues.AlarmLevel.NORMAL
	active_alarms_reasons.clear()

	# Condizioni per Allarme Rosso:
	# - Scafo sotto il 25%
	# - Breccia critica nello scafo
	# - Reattore critico / PowerGrid offline
	# - Più di 2 sottosistemi distrutti
	var destroyed_subsystems := 0
	for sub in subsystem_integrity.keys():
		if subsystem_integrity[sub] <= 0.0:
			destroyed_subsystems += 1

	if hull_integrity <= 25.0:
		new_level = GlobalValues.AlarmLevel.RED_ALERT
		active_alarms_reasons.append("INTEGRITÀ SCAFO CRITICA (<25%)")
	elif is_reactor_critical or subsystem_integrity.get("power_grid") <= 0.0:
		new_level = GlobalValues.AlarmLevel.RED_ALERT
		active_alarms_reasons.append("DISATTIVAZIONE REATTORE / POWER GRID COMPROMESSA")
	elif has_critical_breach and hull_integrity <= 40.0:
		new_level = GlobalValues.AlarmLevel.RED_ALERT
		active_alarms_reasons.append("BRECCIA SCAFO CRITICA RILEVATA")
	elif destroyed_subsystems >= 2:
		new_level = GlobalValues.AlarmLevel.RED_ALERT
		active_alarms_reasons.append("COLLASSO MULTIPLO SOTTOSISTEMI PRIMARI")

	# Condizioni per Allarme Giallo (se non è già Rosso):
	# - Avaria grave a un sottosistema primario (integrità < 35%)
	# - Scudi esauriti su almeno un quadrante
	# - Integrità scafo < 70%
	if new_level != GlobalValues.AlarmLevel.RED_ALERT:
		var has_depleted_shield := false
		for q in shields.keys():
			if shields[q] <= 0.0:
				has_depleted_shield = true
				active_alarms_reasons.append("SCUDI ESAURITI SU QUADRANTE " + GlobalValues.Quadrant.keys()[q])
				break

		var has_subsystem_failure := false
		for sub in subsystem_integrity.keys():
			if subsystem_integrity[sub] < 35.0:
				has_subsystem_failure = true
				active_alarms_reasons.append("AVARIA GRAVE A SOTTOSISTEMA " + sub.to_upper())
				break

		if has_depleted_shield or has_subsystem_failure or hull_integrity < 70.0:
			new_level = GlobalValues.AlarmLevel.YELLOW_ALERT
			if hull_integrity < 70.0 and not has_depleted_shield and not has_subsystem_failure:
				active_alarms_reasons.append("DANNO STRUTTURALE ALLO SCAFO (<70%)")

	if new_level != old_level:
		current_alarm_level = new_level
		var reason_str := ", ".join(active_alarms_reasons) if not active_alarms_reasons.is_empty() else "Stato normale ripristinato"
		alarm_level_changed.emit(old_level, new_level, reason_str)

func _sync_with_space_world_manager(systemic_events: Array[Dictionary]) -> void:
	if not Engine.has_singleton("SpaceWorldManagerSingleton"):
		var swm_node := get_node_or_null("/root/SpaceWorldManager")
		if swm_node and is_instance_valid(swm_node):
			for evt in systemic_events:
				var m_type: String = evt.get("malfunction_type")
				if m_type == "dmg_breach" or m_type == "short_circuit":
					var damage_type := "breach" if m_type == "dmg_breach" else "short_circuit"
					if swm_node.has_method("spawn_ship_damage"):
						swm_node.spawn_ship_damage(damage_type, Vector2.ZERO, str(evt.get("room", "")))

## Imposta il bilanciamento scudi (usato da ShieldMatrixApp)
func set_shield_quadrant_value(quadrant: GlobalValues.Quadrant, value: float) -> void:
	shields[quadrant] = clamp(value, 0.0, max_shield_per_quadrant)
	_evaluate_alarm_level()

## Ripara l'integrità di un sottosistema (usato da DuctDrone/ServiceDrone/Ingegnere)
func repair_subsystem(subsystem: String, amount: float) -> void:
	if subsystem_integrity.has(subsystem):
		subsystem_integrity[subsystem] = min(100.0, subsystem_integrity[subsystem] + amount)
		if subsystem == "power_grid" and subsystem_integrity[subsystem] > 20.0:
			is_reactor_critical = false
		_evaluate_alarm_level()

## Ripara l'integrità dello scafo
func repair_hull(amount: float) -> void:
	hull_integrity = min(max_hull_integrity, hull_integrity + amount)
	if hull_integrity > 50.0:
		has_critical_breach = false
	_evaluate_alarm_level()

func get_system_status() -> Dictionary:
	return {
		"alarm_level": GlobalValues.AlarmLevel.keys()[current_alarm_level],
		"active_alarms": active_alarms_reasons,
		"hull_integrity": hull_integrity,
		"shields": {
			"FORE": shields[GlobalValues.Quadrant.FORE],
			"AFT": shields[GlobalValues.Quadrant.AFT],
			"PORT": shields[GlobalValues.Quadrant.PORT],
			"STARBOARD": shields[GlobalValues.Quadrant.STARBOARD]
		},
		"subsystems": subsystem_integrity.duplicate()
	}
