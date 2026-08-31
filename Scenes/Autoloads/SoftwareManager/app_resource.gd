@tool
class_name AppResource
extends Resource

## Risorsa unificata per la definizione dei programmi e software in GodotOS / Dark Nova.
## Gestisce sia le applicazioni del Terminale che quelle installate sulla Nave.
## Contiene i metadati dell'applicazione, permessi RBAC, consumi, requisiti,
## riferimenti alla scena UI, percorsi per le cartelle su disco (Drive), password e file predefiniti.

@export_group("Identificazione")
@export var app_id: String = "":
	set(val):
		app_id = val
		emit_changed()

@export var title: String = "":
	set(val):
		title = val
		emit_changed()

@export_multiline var description: String = "":
	set(val):
		description = val
		emit_changed()

@export var category: String = "Applicazioni":
	set(val):
		category = val
		emit_changed()

@export_group("Interfaccia & Finestra")
@export var icon: Texture2D = null:
	set(val):
		icon = val
		emit_changed()

@export var icon_color: Color = Color(0.0, 0.79, 0.95, 1.0):
	set(val):
		icon_color = val
		emit_changed()

@export_file("*.tscn") var scene_path: String = "":
	set(val):
		scene_path = val
		emit_changed()

@export var scene: PackedScene = null:
	set(val):
		scene = val
		emit_changed()

@export var default_window_size: Vector2 = Vector2(700, 500):
	set(val):
		default_window_size = val
		emit_changed()

@export var min_window_size: Vector2 = Vector2(400, 300):
	set(val):
		min_window_size = val
		emit_changed()

@export_group("Controllo Ruoli & Matrice Nave")
## Ruoli autorizzati ad accedere all'applicazione (es. ["Capitano", "Pilota", "Factotum"])
@export var roles: Array[String] = []:
	set(val):
		roles = val
		emit_changed()

## Assorbimento di potenza dalla rete elettrica della nave (MW)
@export var power_draw_mw: float = 0.0:
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

@export_group("Terminale & Sistema Locale")
## Se l'applicazione fa parte del core di sistema dell'OS
@export var is_system_app: bool = false:
	set(val):
		is_system_app = val
		emit_changed()

## Comando CLI associato (se eseguibile direttamente dal terminale shell)
@export var terminal_command: String = "":
	set(val):
		terminal_command = val
		emit_changed()

## Se l'applicazione deve essere visualizzata sempre nella Taskbar o desktop
@export var is_pinned_to_taskbar: bool = false:
	set(val):
		is_pinned_to_taskbar = val
		emit_changed()

@export_group("Integrazione Drive & Sicurezza")
## Percorso relativo della cartella all'interno del rispettivo Drive (es. "Programs/FlightControls")
@export var drive_folder: String = "":
	set(val):
		drive_folder = val
		emit_changed()

## Password di sblocco della cartella protetta (es. "FLIGHT-7815")
@export var default_password: String = "":
	set(val):
		default_password = val
		emit_changed()

## File di default (.dat, .txt, ecc.) da creare automaticamente all'installazione o al montaggio del Drive
## Ogni elemento: { "name": "config.dat" o "path": "Ship Drive/...", "content": "...", "is_protected": true, "desc": "..." }
@export var default_files: Array[Dictionary] = []:
	set(val):
		default_files = val
		emit_changed()

## Converte la risorsa in dizionario per retrocompatibilità con ShipBlueprint / StartMenu / Network
func to_dict() -> Dictionary:
	return {
		"id": app_id,
		"title": title,
		"description": description,
		"scene_path": scene_path,
		"icon_color": icon_color,
		"category": category,
		"drive_folder": drive_folder,
		"default_password": default_password,
		"default_window_size": [default_window_size.x, default_window_size.y],
		"min_window_size": [min_window_size.x, min_window_size.y],
		"roles": roles.duplicate(),
		"power_draw_mw": power_draw_mw,
		"required_subsystems": required_subsystems.duplicate(),
		"is_critical": is_critical,
		"is_system_app": is_system_app,
		"terminal_command": terminal_command,
		"is_pinned_to_taskbar": is_pinned_to_taskbar
	}

## Verifica se un determinato ruolo (o stato di gioco) ha i permessi per visualizzare/avviare l'app
func is_role_allowed(role_name: String, is_solo: bool = false) -> bool:
	var clean_role := role_name.strip_edges()
	var is_super := clean_role.is_empty() or clean_role == "Capitano" or clean_role == "Factotum" or clean_role == "Captain" or clean_role == "HOST"
	if is_super:
		return true
	if is_solo and (clean_role.is_empty() or clean_role == "Non Assegnato"):
		return true
	
	if roles.is_empty():
		return true
		
	for r in roles:
		var r_str: String = str(r).strip_edges().to_lower()
		var c_str: String = clean_role.to_lower()
		if r_str == "*" or r_str == "all":
			return true
		if r_str == c_str:
			return true
		if (c_str in ["pilota", "pilot"] and r_str in ["pilota", "pilot"]) or (c_str in ["ingegnere", "engineer"] and r_str in ["ingegnere", "engineer"]) or (c_str in ["soldato", "soldier", "tattico"] and r_str in ["soldato", "soldier", "tattico", "tattico / armi", "armi"]) or (c_str in ["hacker", "cyber"] and r_str in ["hacker", "cyber"]):
			return true
			
	return false

## Recupera la PackedScene effettiva (dalla proprietà `scene` o caricandola da `scene_path`)
func get_effective_scene() -> PackedScene:
	if scene != null:
		return scene
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		return load(scene_path) as PackedScene
	return null

## Genera la lista formattata dei file pronti per la scrittura sul Drive
func get_formatted_drive_files(drive_root_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for file_entry in default_files:
		var path: String = str(file_entry.get("path", ""))
		var file_name: String = str(file_entry.get("name", file_entry.get("file_name", "")))
		var content: String = str(file_entry.get("content", ""))
		var is_protected: bool = bool(file_entry.get("is_protected", true))
		var desc: String = str(file_entry.get("desc", file_entry.get("description", "")))
		
		var full_rel_path: String = ""
		if not path.is_empty():
			if path.begins_with(drive_root_name + "/"):
				full_rel_path = path
			elif path.begins_with("Ship Drive/") or path.begins_with("Terminal Drive/"):
				# Rimuovi il vecchio prefisso e metti quello corrente
				var parts := path.split("/", true, 1)
				full_rel_path = "%s/%s" % [drive_root_name, parts[1]]
			else:
				full_rel_path = "%s/%s" % [drive_root_name, path.trim_prefix("/")]
		elif not file_name.is_empty():
			var base_folder := drive_folder.trim_prefix("/").trim_suffix("/")
			if base_folder.begins_with(drive_root_name + "/"):
				full_rel_path = "%s/%s" % [base_folder, file_name]
			elif base_folder.is_empty():
				full_rel_path = "%s/%s" % [drive_root_name, file_name]
			else:
				full_rel_path = "%s/%s/%s" % [drive_root_name, base_folder, file_name]
		
		if not full_rel_path.is_empty():
			result.append({
				"path": full_rel_path,
				"content": content,
				"is_protected": is_protected,
				"desc": desc
			})
	return result
