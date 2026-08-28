class_name ShipSoftwareManagerSingleton
extends Node

## Singleton / Manager per la gestione dei software e delle applicazioni installate sulla Nave.
## Si occupa di registrare le risorse `ShipAppResource`, integrarsi con la `ShipBlueprint`
## e sincronizzare i file e le password protette su `ShipDriveManager`.

signal software_installed(app_res: ShipAppResource)
signal software_uninstalled(app_id: String)
signal registry_changed()

## Mappa di tutti i software nave conosciuti/registrati nel sistema { app_id: ShipAppResource }
var _registered_apps: Dictionary = {}

## Percorsi predefiniti delle risorse software della nave
const DEFAULT_SHIP_APP_PATHS: Array[String] = [
	"res://Applications/FlightControl/flight_control_app.tres",
	"res://Applications/Cams/cams_app.tres",
	"res://Applications/DuctDrone/duct_drone_app.tres",
	"res://Applications/PowerGrid/power_grid_app.tres",
	"res://Applications/Weapons/weapons_app.tres",
	"res://Applications/ShieldMatrix/shield_matrix_app.tres",
	"res://Applications/Diagnostics/diagnostics_app.tres",
	"res://Applications/Sensors/sensors_app.tres",
	"res://Applications/LifeSupport/life_support_app.tres"
]

func _ready() -> void:
	_load_default_catalog()

## Carica le risorse predefinite della nave
func _load_default_catalog() -> void:
	for path in DEFAULT_SHIP_APP_PATHS:
		if ResourceLoader.exists(path):
			var res := load(path)
			if res is ShipAppResource:
				register_app(res)

## Registra un'applicazione della nave nel catalogo
func register_app(app_res: ShipAppResource) -> void:
	if not app_res or app_res.app_id.is_empty():
		return
	_registered_apps[app_res.app_id] = app_res
	registry_changed.emit()

## Rimuove un'applicazione dal catalogo registrato
func unregister_app(app_id: String) -> void:
	if _registered_apps.has(app_id):
		_registered_apps.erase(app_id)
		registry_changed.emit()

## Recupera una risorsa app registrata per ID
func get_registered_app(app_id: String) -> ShipAppResource:
	return _registered_apps.get(app_id, null)

## Restituisce tutte le risorse app registrate
func get_all_registered_apps() -> Array[ShipAppResource]:
	var list: Array[ShipAppResource] = []
	for k in _registered_apps:
		list.append(_registered_apps[k])
	return list

## Recupera la Blueprint attiva corrente
func get_active_blueprint() -> ShipBlueprint:
	if SpaceWorldManager and SpaceWorldManager.has_method("get_ship_blueprint"):
		var bp = SpaceWorldManager.get_ship_blueprint()
		if bp:
			return bp
	return ShipBlueprint.get_default_blueprint()

## Restituisce l'elenco delle risorse app installate nella Blueprint
func get_installed_apps(bp: ShipBlueprint = null) -> Array[ShipAppResource]:
	var blueprint := bp if bp != null else get_active_blueprint()
	var result: Array[ShipAppResource] = []
	if not blueprint:
		return get_all_registered_apps()
	
	for item in blueprint.installed_apps:
		var app_id: String = str(item.get("id", ""))
		if _registered_apps.has(app_id):
			result.append(_registered_apps[app_id])
		else:
			# Crea dinamicamente un ShipAppResource dal dizionario di fallback
			var dynamic_res := ShipAppResource.new()
			dynamic_res.app_id = app_id
			dynamic_res.title = str(item.get("title", app_id))
			dynamic_res.description = str(item.get("description", ""))
			dynamic_res.scene_path = str(item.get("scene_path", ""))
			dynamic_res.icon_color = item.get("icon_color", Color(0, 0.79, 0.95, 1.0))
			dynamic_res.roles.clear()
			var raw_roles = item.get("roles", [])
			if raw_roles is Array:
				for r in raw_roles:
					dynamic_res.roles.append(str(r))
			result.append(dynamic_res)
			
	return result

## Restituisce le risorse app autorizzate per un dato ruolo
func get_apps_for_role(role_name: String, is_solo: bool = false, bp: ShipBlueprint = null) -> Array[ShipAppResource]:
	var apps := get_installed_apps(bp)
	var filtered: Array[ShipAppResource] = []
	for app in apps:
		if app.is_role_allowed(role_name, is_solo):
			filtered.append(app)
	return filtered

## Installa un'applicazione software nella Blueprint della nave
func install_app_to_blueprint(app_res: ShipAppResource, bp: ShipBlueprint = null) -> void:
	if not app_res:
		return
	var blueprint := bp if bp != null else get_active_blueprint()
	if not blueprint:
		return
	
	blueprint.set_installed_app(app_res.app_id, app_res.to_dict())
	
	# Registra i file di default nel sublayer drive della blueprint
	var drive_files := app_res.get_formatted_drive_files("Ship Drive")
	for df in drive_files:
		blueprint.set_drive_file(df["path"], df["content"], df["is_protected"], df["desc"])
		
	# Registra la password della cartella nella blueprint se specificata
	if not app_res.drive_folder.is_empty() and not app_res.default_password.is_empty():
		var folder_rel: String = app_res.drive_folder.trim_prefix("/").trim_suffix("/")
		var full_folder := "Ship Drive/%s" % folder_rel if not folder_rel.begins_with("Ship Drive/") else folder_rel
		blueprint.set_drive_password(full_folder, app_res.default_password)
		
	# Se lo ShipDriveManager è attualmente montato, scrivi i file sul disco
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.get("is_drive_mounted"):
		populate_ship_drive_for_app(app_res)
		
	software_installed.emit(app_res)

## Disinstalla un'applicazione dalla Blueprint
func uninstall_app_from_blueprint(app_id: String, bp: ShipBlueprint = null) -> bool:
	var blueprint := bp if bp != null else get_active_blueprint()
	if not blueprint:
		return false
	
	var removed := blueprint.remove_installed_app(app_id)
	if removed:
		software_uninstalled.emit(app_id)
	return removed

## Popola i file e imposta la password su ShipDrive per una specifica app
func populate_ship_drive_for_app(app_res: ShipAppResource) -> void:
	if not app_res:
		return
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	var files := app_res.get_formatted_drive_files("Ship Drive")
	for file_data in files:
		var path: String = file_data["path"]
		var content: String = file_data["content"]
		var abs_path := "user://files/%s" % path
		if not FileAccess.file_exists(abs_path):
			var base_dir := abs_path.get_base_dir()
			if not DirAccess.dir_exists_absolute(base_dir):
				DirAccess.make_dir_recursive_absolute(base_dir)
			var f := FileAccess.open(abs_path, FileAccess.WRITE)
			if f:
				f.store_string(content)
				f.close()
				
	if not app_res.drive_folder.is_empty() and not app_res.default_password.is_empty():
		var fpm := get_node_or_null("/root/FolderPasswordManager")
		if fpm:
			var folder_rel: String = app_res.drive_folder.trim_prefix("/").trim_suffix("/")
			var full_folder := "Ship Drive/%s" % folder_rel if not folder_rel.begins_with("Ship Drive/") else folder_rel
			fpm.set_password(full_folder, app_res.default_password)

## Popola tutti i file e password per tutte le app installate
func populate_all_installed_ship_drive_apps(bp: ShipBlueprint = null) -> void:
	var apps := get_installed_apps(bp)
	for app in apps:
		populate_ship_drive_for_app(app)

## Lancia la finestra dell'applicazione
func launch_app(app_id: String) -> FakeWindow:
	var app_res := get_registered_app(app_id)
	if not app_res:
		for app in get_installed_apps():
			if app.app_id == app_id:
				app_res = app
				break
	if not app_res:
		return null
		
	var scene := app_res.get_effective_scene()
	if not scene:
		return null
		
	var window: FakeWindow = load("res://Scenes/Window/Application Window/application_window.tscn").instantiate()
	var app_instance := scene.instantiate()
	window.get_node("%ApplicationContents").add_child(app_instance)
	window.title_text = app_res.title
	
	var tree := get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(window)
		
		# Crea pulsante nella taskbar
		var taskbar_group := tree.get_first_node_in_group("taskbar_buttons")
		if taskbar_group:
			var taskbar_button: Control = load("res://Scenes/Taskbar/taskbar_button.tscn").instantiate()
			taskbar_button.target_window = window
			if app_res.icon:
				taskbar_button.get_node("TextureMargin/TextureRect").texture = app_res.icon
			taskbar_button.active_color = app_res.icon_color
			taskbar_group.add_child(taskbar_button)
			
	return window
