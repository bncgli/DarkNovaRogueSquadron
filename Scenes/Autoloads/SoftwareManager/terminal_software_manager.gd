class_name TerminalSoftwareManagerSingleton
extends Node

## Singleton / Manager per la gestione dei software e utility locali del Terminale/GodotOS.
## Registra le risorse `AppResource`, popola file di configurazione locali
## su `TerminalDriveManager` e gestisce l'avvio delle utility di sistema.

signal terminal_app_installed(app_res: AppResource)
signal terminal_app_uninstalled(app_id: String)
signal registry_changed()

## Mappa di tutti i software locali del terminale { app_id: AppResource }
var _registered_apps: Dictionary = {}

## Percorsi predefiniti delle risorse software del terminale
const DEFAULT_TERMINAL_APP_PATHS: Array[String] = [
	"res://Applications/Terminal/terminal_app.tres",
	"res://Applications/ShipBuilder/ship_builder.tres",
	"res://Applications/Games/Godotris/godotris_app.tres",
	"res://Applications/Games/Pong/pong_app.tres",
	"res://Applications/Games/Snake/snake_app.tres",
	"res://Applications/Games/Super Bit Boy/super_bit_boy_app.tres",
	"res://Applications/Lobby/lobby_app.tres"
]

func _ready() -> void:
	_load_default_catalog()

## Carica le risorse predefinite del terminale
func _load_default_catalog() -> void:
	for path in DEFAULT_TERMINAL_APP_PATHS:
		if ResourceLoader.exists(path):
			var res := load(path)
			if res is AppResource:
				register_app(res)

## Registra un'applicazione locale del terminale ed eventualmente ne popola i file
func register_app(app_res: AppResource) -> void:
	if not app_res or app_res.app_id.is_empty():
		return
	_registered_apps[app_res.app_id] = app_res
	registry_changed.emit()

## Installa una nuova app terminale popolandone file e password sul Terminal Drive
func install_terminal_app(app_res: AppResource) -> void:
	if not app_res:
		return
	register_app(app_res)
	var tdm := get_node_or_null("/root/TerminalDriveManager")
	if tdm:
		tdm.ensure_drive_exists()
	populate_terminal_drive_for_app(app_res)
	terminal_app_installed.emit(app_res)

## Disinstalla un'applicazione locale rimuovendone i file di configurazione e la password
func uninstall_terminal_app(app_id: String) -> bool:
	var app_res := get_registered_app(app_id)
	if not app_res:
		return false
	
	# Rimuovi file da disco
	var files := app_res.get_formatted_drive_files("Terminal Drive")
	for file_data in files:
		var path: String = file_data["path"]
		var abs_path := "user://files/%s" % path
		if FileAccess.file_exists(abs_path):
			DirAccess.remove_absolute(abs_path)
			
	# Rimuovi password se presente
	if not app_res.drive_folder.is_empty():
		var fpm := get_node_or_null("/root/FolderPasswordManager")
		if fpm and fpm.has_method("remove_password"):
			var folder_rel: String = app_res.drive_folder.trim_prefix("/").trim_suffix("/")
			var full_folder := "Terminal Drive/%s" % folder_rel if not folder_rel.begins_with("Terminal Drive/") else folder_rel
			fpm.remove_password(full_folder)
			
	unregister_app(app_id)
	terminal_app_uninstalled.emit(app_id)
	return true

## Rimuove un'applicazione dal registro
func unregister_app(app_id: String) -> void:
	if _registered_apps.has(app_id):
		_registered_apps.erase(app_id)
		registry_changed.emit()

## Recupera una risorsa app del terminale per ID
func get_registered_app(app_id: String) -> AppResource:
	return _registered_apps.get(app_id, null)

## Restituisce tutte le risorse del terminale registrate
func get_all_registered_apps() -> Array[AppResource]:
	var list: Array[AppResource] = []
	for k in _registered_apps:
		list.append(_registered_apps[k])
	return list

## Popola i file di configurazione predefiniti nel Terminal Drive
func populate_terminal_drive_for_app(app_res: AppResource) -> void:
	if not app_res:
		return
		
	var files := app_res.get_formatted_drive_files("Terminal Drive")
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
			var full_folder := "Terminal Drive/%s" % folder_rel if not folder_rel.begins_with("Terminal Drive/") else folder_rel
			fpm.set_password(full_folder, app_res.default_password)

## Popola tutti i file per tutti i programmi terminale registrati
func populate_all_terminal_drive_apps() -> void:
	for app_id in _registered_apps:
		populate_terminal_drive_for_app(_registered_apps[app_id])

## Lancia la finestra del programma locale
func launch_app(app_id: String) -> FakeWindow:
	var app_res := get_registered_app(app_id)
	if not app_res:
		return null
		
	var scene := app_res.get_effective_scene()
	if not scene:
		return null
		
	var window: FakeWindow = load("res://Scenes/Window/Application Window/application_window.tscn").instantiate()
	var app_instance := scene.instantiate()
	window.get_node("%ApplicationContents").add_child(app_instance)
	window.title_text = app_res.title
	if app_res.default_window_size != Vector2.ZERO:
		window.size = app_res.default_window_size
	if app_res.min_window_size != Vector2.ZERO:
		window.custom_minimum_size = app_res.min_window_size
	
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
