@tool
class_name ShipAppResource
extends AppResource

## Risorsa per la definizione delle applicazioni della Nave in Dark Nova: Rogue Squadron.
## Include i ruoli autorizzati (RBAC), i requisiti di sistema nave e l'alimentazione richiesta.

@export_group("Controllo Ruoli & Matrice Nave")
## Ruoli autorizzati ad accedere all'applicazione (es. ["Capitano", "Pilota", "Factotum"])
@export var roles: Array[String] = []:
	set(val):
		roles = val
		emit_changed()

## Assorbimento di potenza dalla rete elettrica della nave (MW)
@export var power_draw_mw: float = 5.0:
	set(val):
		power_draw_mw = val
		emit_changed()

## Sottosistemi della nave richiesti per l'operatività (es. ["nav_computer", "reactor"])
@export var required_subsystems: Array[String] = []:
	set(val):
		required_subsystems = val
		emit_changed()

## Se l'applicazione è critica per la sopravvivenza o le manovre di combattimento
@export var is_critical: bool = false:
	set(val):
		is_critical = val
		emit_changed()

func _init() -> void:
	category = "Sistemi Nave"

## Converte la risorsa in dizionario per la ShipBlueprint e lo Start Menu
func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["roles"] = roles.duplicate()
	d["power_draw_mw"] = power_draw_mw
	d["required_subsystems"] = required_subsystems.duplicate()
	d["is_critical"] = is_critical
	return d

## Verifica se un determinato ruolo (o stato di gioco) ha i permessi per visualizzare/avviare l'app
func is_role_allowed(role_name: String, _is_solo: bool = false) -> bool:
	var clean_role := role_name.strip_edges()
	var is_super := clean_role.is_empty() or clean_role == "Capitano" or clean_role == "Factotum" or clean_role == "Captain" or clean_role == "HOST"
	if is_super:
		return true
	
	if roles.is_empty():
		return true
		
	for r in roles:
		var r_str: String = str(r).strip_edges()
		if r_str == "*" or r_str.to_lower() == "all":
			return true
		if r_str.to_lower() == clean_role.to_lower():
			return true
		if clean_role != "" and (r_str.to_lower() in clean_role.to_lower() or clean_role.to_lower() in r_str.to_lower()):
			return true
			
	return false
