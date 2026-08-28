@tool
class_name AppResource
extends Resource

## Risorsa di base per la definizione dei programmi e software in GodotOS / Dark Nova.
## Contiene i metadati dell'applicazione, riferimenti alla scena UI,
## percorsi per le cartelle su disco (Drive), password e file di configurazione predefiniti.

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

## Converte la risorsa in dizionario per retrocompatibilità con ShipBlueprint / StartMenu
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
		"min_window_size": [min_window_size.x, min_window_size.y]
	}

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
