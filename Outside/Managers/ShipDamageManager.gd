extends Node
class_name ShipDamageManager

## Gestore dei danni strutturali della nave (brecce, cortocircuiti, incendi):
## elenco dei danni attivi, rilevamento/rivelazione e avanzamento riparazioni.
## Estratto da SpaceWorldManager per eliminare la duplicazione di stato/logica.

signal damages_updated(damages: Array[ShipDamageRuntimeState])
signal damage_discovered(damage: ShipDamageRuntimeState)
signal damage_repaired(damage: ShipDamageRuntimeState)

const DAMAGE_TYPE_BREACH: String = "breach"
const DAMAGE_TYPE_SHORT_CIRCUIT: String = "short_circuit"
const DAMAGE_TYPE_FIRE: String = "fire"

var active_damages: Array[ShipDamageRuntimeState] = []
var next_damage_idx: int = 1

func get_damages() -> Array[ShipDamageRuntimeState]:
	return active_damages

func get_active_damages() -> Array[ShipDamageRuntimeState]:
	var active: Array[ShipDamageRuntimeState] = []
	for dmg in active_damages:
		if not dmg.repaired:
			active.append(dmg)
	return active

func get_damage_by_id(dmg_id: String) -> ShipDamageRuntimeState:
	for dmg in active_damages:
		if dmg.id == dmg_id:
			return dmg
	return null

func get_adjacent_damage(pos: Vector2, max_dist: float = 38.0) -> ShipDamageRuntimeState:
	var closest: ShipDamageRuntimeState = null
	var min_d := max_dist
	for dmg in active_damages:
		if dmg.repaired:
			continue
		var d: float = pos.distance_to(dmg.pos)
		if d <= min_d:
			min_d = d
			closest = dmg
	return closest

## Crea un nuovo danno e lo aggiunge all'elenco dei danni attivi. Emette `damages_updated`.
func spawn_damage(type: String, pos: Vector2, sector_name: String, duration: float) -> ShipDamageRuntimeState:
	var dmg_id := "dmg_%d" % next_damage_idx
	next_damage_idx += 1

	var dmg := ShipDamageRuntimeState.new(dmg_id, type, pos)
	dmg.sector = sector_name if sector_name != "" else "Condotto / Scafo"
	dmg.repair_duration = duration

	active_damages.append(dmg)
	damages_updated.emit(active_damages)
	return dmg

## Svuota l'elenco dei danni attivi ed emette `damages_updated` (il contatore ID non viene azzerato).
func clear_damages() -> void:
	active_damages.clear()
	damages_updated.emit(active_damages)

## Svuota l'elenco dei danni attivi e azzera il contatore ID, senza emettere segnali
## (usato in fase di generazione iniziale, dove ogni spawn successivo emette già l'update).
func reset_for_generation() -> void:
	active_damages.clear()
	next_damage_idx = 1

## Marca un danno come rivelato ed emette `damage_discovered`.
func reveal_damage(dmg: ShipDamageRuntimeState, revealed_by: String) -> void:
	dmg.revealed = true
	dmg.revealed_by = revealed_by
	damage_discovered.emit(dmg)

## Aggiorna il progresso di riparazione di un danno senza emettere segnali.
func set_repair_progress(damage_id: String, progress: float) -> void:
	var dmg := get_damage_by_id(damage_id)
	if dmg:
		dmg.repair_progress = progress

## Marca un danno come riparato ed emette `damage_repaired`.
func complete_repair(damage_id: String) -> ShipDamageRuntimeState:
	var dmg := get_damage_by_id(damage_id)
	if dmg == null or dmg.repaired:
		return null
	dmg.repaired = true
	damage_repaired.emit(dmg)
	return dmg

## Ricostruisce l'elenco dei danni da uno snapshot di rete (Array di Dictionary) ed emette `damages_updated`.
func sync_from_snapshot(p_damages: Array) -> void:
	active_damages.clear()
	for d_dict in p_damages:
		if d_dict is Dictionary:
			var dmg := ShipDamageRuntimeState.new()
			dmg.from_dict(d_dict)
			active_damages.append(dmg)
	damages_updated.emit(active_damages)
