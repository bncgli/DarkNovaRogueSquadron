extends Node

## Autoload to manage password protection on folders.

signal passwords_changed

const SAVE_PATH: String = "user://folder_passwords.json"

var _passwords: Dictionary = {}

func _ready() -> void:
	load_passwords()

func normalize_path(path: String) -> String:
	var clean := path.replace("\\", "/").strip_edges()
	clean = clean.trim_prefix("user://files/")
	clean = clean.trim_prefix("user://files")
	clean = clean.trim_prefix("/").trim_suffix("/")
	return clean

func has_password(path: String) -> bool:
	var norm := normalize_path(path)
	if norm.is_empty():
		return false
	return _passwords.has(norm) and str(_passwords[norm]).length() > 0

func get_password(path: String) -> String:
	var norm := normalize_path(path)
	return str(_passwords.get(norm, ""))

func check_password(path: String, password_input: String) -> bool:
	var norm := normalize_path(path)
	if not has_password(norm):
		return true
	return str(_passwords.get(norm, "")) == password_input

func set_password(path: String, password_str: String) -> void:
	var norm := normalize_path(path)
	if norm.is_empty():
		return
	if password_str.is_empty():
		remove_password(norm)
		return
	_passwords[norm] = password_str
	save_passwords()
	passwords_changed.emit()
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.get("is_drive_mounted"):
		sdm.sync_folder_password(norm, password_str)

func remove_password(path: String) -> void:
	var norm := normalize_path(path)
	if _passwords.has(norm):
		_passwords.erase(norm)
		save_passwords()
		passwords_changed.emit()
		
		var sdm := get_node_or_null("/root/ShipDriveManager")
		if sdm and sdm.get("is_drive_mounted"):
			sdm.sync_remove_folder_password(norm)

func rename_path(old_path: String, new_path: String) -> void:
	var norm_old := normalize_path(old_path)
	var norm_new := normalize_path(new_path)
	if norm_old.is_empty() or norm_new.is_empty() or norm_old == norm_new:
		return
	
	var changed := false
	var keys_to_move: Array[String] = []
	for k: String in _passwords.keys():
		if k == norm_old or k.begins_with(norm_old + "/"):
			keys_to_move.append(k)
	
	for old_k in keys_to_move:
		var pass_val = _passwords[old_k]
		var suffix = old_k.substr(norm_old.length())
		var new_k = norm_new + suffix
		_passwords.erase(old_k)
		_passwords[new_k] = pass_val
		changed = true
	
	if changed:
		save_passwords()
		passwords_changed.emit()

func copy_path(from_path: String, to_path: String) -> void:
	var norm_from := normalize_path(from_path)
	var norm_to := normalize_path(to_path)
	if norm_from.is_empty() or norm_to.is_empty():
		return
	
	var changed := false
	for k: String in _passwords.keys():
		if k == norm_from or k.begins_with(norm_from + "/"):
			var pass_val = _passwords[k]
			var suffix = k.substr(norm_from.length())
			var new_k = norm_to + suffix
			_passwords[new_k] = pass_val
			changed = true
	
	if changed:
		save_passwords()
		passwords_changed.emit()

func delete_path(path: String) -> void:
	var norm := normalize_path(path)
	if norm.is_empty():
		return
	var changed := false
	var keys_to_remove: Array[String] = []
	for k: String in _passwords.keys():
		if k == norm or k.begins_with(norm + "/"):
			keys_to_remove.append(k)
	for k in keys_to_remove:
		_passwords.erase(k)
		changed = true
	if changed:
		save_passwords()
		passwords_changed.emit()

func save_passwords() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_passwords))
		file.close()

func load_passwords() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_passwords = {}
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content := file.get_as_text()
		file.close()
		var json := JSON.new()
		var parse_result := json.parse(content)
		if parse_result == OK and json.data is Dictionary:
			_passwords = json.data
		else:
			_passwords = {}

func prompt_set_password(folder_path: String, folder_name: String) -> void:
	if has_password(folder_path):
		NotificationManager.spawn_notification("La cartella ha gia' una password.")
		return
	var scene: PackedScene = load("res://Scenes/Window/Password Dialog/set_password_dialog.tscn")
	var dlg = scene.instantiate()
	dlg.setup(folder_path, folder_name)
	var parent_node = get_tree().current_scene
	if parent_node == null:
		parent_node = get_tree().root
	parent_node.add_child(dlg)

func prompt_enter_password(folder_path: String, folder_name: String, on_success: Callable, on_cancel: Callable = Callable()) -> void:
	var scene: PackedScene = load("res://Scenes/Window/Password Dialog/enter_password_dialog.tscn")
	var dlg = scene.instantiate()
	dlg.setup(folder_path, folder_name, on_success, on_cancel)
	var parent_node = get_tree().current_scene
	if parent_node == null:
		parent_node = get_tree().root
	parent_node.add_child(dlg)
