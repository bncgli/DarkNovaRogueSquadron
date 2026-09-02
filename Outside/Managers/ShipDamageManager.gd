extends Node
class_name ShipDamageManager

## Gestore dei danni strutturali della nave.
## Estratto da SpaceWorldManager.

signal damages_updated(damages: Array)
signal damage_discovered(damage: Dictionary)
signal damage_repaired(damage: Dictionary)

var active_damages: Array[Dictionary] = []

func add_damage(damage_data: Dictionary) -> void:
	active_damages.append(damage_data)
	damage_discovered.emit(damage_data)
	damages_updated.emit(active_damages)

func repair_damage(damage_id: String) -> bool:
	for i in range(active_damages.size()):
		if active_damages[i].get("id") == damage_id:
			var dmg = active_damages[i]
			active_damages.remove_at(i)
			damage_repaired.emit(dmg)
			damages_updated.emit(active_damages)
			return true
	return false

func get_damages() -> Array:
	return active_damages
