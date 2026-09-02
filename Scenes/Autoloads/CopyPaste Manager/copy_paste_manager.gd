extends Node
## Managed copying and pasting of files and folders.

## The target folder. NOT used for variables since it could be freed by a file manager window!
var target_folder: FakeFolder

## The target folder's name. Gets emptied after a paste.
var target_folder_name: String

var target_folder_path: String
var target_folder_type: GlobalValues.FileType

enum StateEnum{COPY, CUT}
var state: StateEnum = StateEnum.COPY

func _ready() -> void:
	get_viewport().files_dropped.connect(_handle_dropped_folders)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_paste"):
		var selected_window: FakeWindow = GlobalValues.selected_window
		# Paste in desktop if no selected window. Paste in file manager if file manager is selected.
		if selected_window == null:
			paste_folder("")
			return
		
		var file_manager_window: FileManagerWindow = selected_window.get_node_or_null("%File Manager Window")
		if selected_window and file_manager_window != null:
			paste_folder(file_manager_window.file_path)

func copy_folder(folder: FakeFolder) -> void:
	if folder.file_type == GlobalValues.FileType.FOLDER:
		var fpm := get_node_or_null("/root/FolderPasswordManager")
		if fpm and fpm.has_password(folder.folder_path):
			NotificationManager.spawn_notification("Non e' possibile copiare una cartella protetta da password.")
			return
	if target_folder:
		target_folder.modulate.a = 1
	target_folder = folder
	
	target_folder_name = folder.folder_name
	target_folder_path = folder.folder_path
	target_folder_type = folder.file_type
	folder.modulate.a = 0.8
	state = StateEnum.COPY
	NotificationManager.spawn_notification("Copied [color=59ea90][wave freq=7]%s[/wave][/color]" % target_folder_name)

func cut_folder(folder: FakeFolder) -> void:
	if folder.folder_name == "Ship Drive" and (folder.folder_path == "Ship Drive" or folder.folder_path == ""):
		NotificationManager.spawn_notification("Non e' possibile tagliare 'Ship Drive'.")
		return
	if folder.folder_name == "Terminal Drive" and (folder.folder_path == "Terminal Drive" or folder.folder_path == ""):
		NotificationManager.spawn_notification("Non e' possibile tagliare 'Terminal Drive'.")
		return
	if folder.file_type == GlobalValues.FileType.FOLDER:
		var fpm := get_node_or_null("/root/FolderPasswordManager")
		if fpm and fpm.has_password(folder.folder_path):
			NotificationManager.spawn_notification("Non e' possibile tagliare o spostare una cartella protetta da password.")
			return
	
	if target_folder:
		target_folder.modulate.a = 1
	target_folder = folder
	target_folder.modulate.a = 0.8
	
	target_folder_name = folder.folder_name
	target_folder_path = folder.folder_path
	target_folder_type = folder.file_type
	state = StateEnum.CUT
	NotificationManager.spawn_notification("Cutting [color=59ea90][wave freq=7]%s[/wave][/color]" % target_folder_name)

## Pastes the folder, caling paste_folder_copy() or paste_folder_cut() depending on the state selected
func paste_folder(to_path: String) -> void:
	if target_folder_name.is_empty():
		NotificationManager.spawn_notification("Error: Nothing to copy")
		return
	
	if target_folder_type == GlobalValues.FileType.FOLDER:
		var fpm := get_node_or_null("/root/FolderPasswordManager")
		if fpm and fpm.has_password(target_folder_path):
			NotificationManager.spawn_notification("Operazione non consentita per una cartella protetta da password.")
			target_folder_name = ""
			target_folder = null
			return
	
	if state == StateEnum.COPY:
		paste_folder_copy(to_path)
	elif state == StateEnum.CUT:
		paste_folder_cut(to_path)

func paste_folder_copy(to_path: String) -> void:
	var clean_dir := to_path.replace("\\", "/").strip_edges().trim_prefix("/").trim_suffix("/")
	var prefix := (clean_dir + "/") if not clean_dir.is_empty() else ""
	var to: String = "user://files/%s%s" % [prefix, target_folder_name]
	if target_folder_type == GlobalValues.FileType.FOLDER:
		var from: String = "user://files/%s" % target_folder_path
		if from != to:
			DirAccess.make_dir_absolute(to)
			copy_directory_recursively(from, to)
			var fpm := get_node_or_null("/root/FolderPasswordManager")
			if fpm:
				var dest_rel: String = "%s%s" % [prefix, target_folder_name]
				fpm.copy_path(target_folder_path, dest_rel)
	else:
		var from_dir := target_folder_path.replace("\\", "/").strip_edges().trim_prefix("/").trim_suffix("/")
		var from_prefix := (from_dir + "/") if not from_dir.is_empty() else ""
		var from: String = "user://files/%s%s" % [from_prefix, target_folder_name]
		if from != to:
			DirAccess.copy_absolute(from, to)
	
	if target_folder != null:
		target_folder.modulate.a = 1
	if clean_dir.is_empty():
		var desktop_file_manager: DesktopFileManager = get_tree().get_first_node_in_group("desktop_file_manager")
		if desktop_file_manager:
			desktop_file_manager.delete_file_with_name(target_folder_name)
			instantiate_file_and_sort(desktop_file_manager, clean_dir)
	else:
		for file_manager: FileManagerWindow in get_tree().get_nodes_in_group("file_manager_window"):
			if file_manager.file_path == clean_dir:
				file_manager.delete_file_with_name(target_folder_name)
				instantiate_file_and_sort(file_manager, clean_dir)
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.get("is_drive_mounted"):
		var dest_rel: String = "%s%s" % [prefix, target_folder_name]
		sdm.sync_path_recursive(dest_rel)
	
	target_folder_name = ""
	target_folder = null

func paste_folder_cut(to_path: String) -> void:
	var clean_dir := to_path.replace("\\", "/").strip_edges().trim_prefix("/").trim_suffix("/")
	var prefix := (clean_dir + "/") if not clean_dir.is_empty() else ""
	var to: String = "user://files/%s%s" % [prefix, target_folder_name]
	
	var from_dir := target_folder_path.replace("\\", "/").strip_edges().trim_prefix("/").trim_suffix("/")
	var from_prefix := (from_dir + "/") if not from_dir.is_empty() else ""
	var old_from_rel: String = "%s%s" % [from_prefix, target_folder_name]
	
	if target_folder_type == GlobalValues.FileType.FOLDER:
		var from: String = "user://files/%s" % target_folder_path
		old_from_rel = target_folder_path
		DirAccess.rename_absolute(from, to)
		var fpm := get_node_or_null("/root/FolderPasswordManager")
		if fpm:
			var dest_rel: String = "%s%s" % [prefix, target_folder_name]
			fpm.rename_path(old_from_rel, dest_rel)
		for file_manager: FileManagerWindow in get_tree().get_nodes_in_group("file_manager_window"):
			if file_manager.file_path.begins_with(target_folder_path):
				file_manager.close_window()
			elif file_manager.file_path == clean_dir:
				instantiate_file_and_sort(file_manager, clean_dir)
	else:
		var from: String = "user://files/%s%s" % [from_prefix, target_folder_name]
		DirAccess.rename_absolute(from, to)
		for file_manager: FileManagerWindow in get_tree().get_nodes_in_group("file_manager_window"):
			if file_manager.file_path == clean_dir:
				instantiate_file_and_sort(file_manager, clean_dir)
	
	if target_folder != null:
		target_folder.get_parent().delete_file_with_name(target_folder_name)
	
	if clean_dir.is_empty():
		var desktop_file_manager: DesktopFileManager = get_tree().get_first_node_in_group("desktop_file_manager")
		if desktop_file_manager:
			instantiate_file_and_sort(desktop_file_manager, clean_dir)
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.get("is_drive_mounted"):
		var dest_rel: String = "%s%s" % [prefix, target_folder_name]
		sdm.sync_rename(old_from_rel, dest_rel, target_folder_type == GlobalValues.FileType.FOLDER)
	
	target_folder = null

func copy_directory_recursively(dir_path: String, to_path: String) -> void:
	if to_path.begins_with(dir_path):
		NotificationManager.spawn_notification("ERROR: Can't copy a folder into itself!")
		return
	for dir_name in DirAccess.get_directories_at(dir_path):
		DirAccess.make_dir_absolute("%s/%s" % [to_path, dir_name])
		copy_directory_recursively("%s/%s" % [dir_path, dir_name], "%s/%s" % [to_path, dir_name])
	for file_name in DirAccess.get_files_at(dir_path):
		DirAccess.copy_absolute("%s/%s" % [dir_path, file_name], "%s/%s" % [to_path, file_name])

## Instantiates a new file in the file manager then refreshes. Used for adding a single file without causing a full refresh.
func instantiate_file_and_sort(file_manager: BaseFileManager, to_path: String) -> void:
	if target_folder_type == GlobalValues.FileType.FOLDER:
		file_manager.instantiate_file(target_folder_name, "%s/%s" % [to_path, target_folder_name], target_folder_type)
	else:
		file_manager.instantiate_file(target_folder_name, to_path, target_folder_type)
	file_manager.sort_folders()

## Copies files that get dragged and dropped into GodotOS (if the file format is supported).
func _handle_dropped_folders(files: PackedStringArray) -> void:
	for file_name: String in files:
		var extension: String = file_name.split(".")[-1]
		match extension:
			"txt", "md", "jpg", "jpeg", "png", "webp":
				var new_file_name: String
				if OS.has_feature("windows"):
					new_file_name = file_name.replace("\\", "/").split("/")[-1]
				else:
					new_file_name = file_name.split("/")[-1]
				DirAccess.copy_absolute(file_name, "user://files/%s" % new_file_name)
				get_tree().get_first_node_in_group("desktop_file_manager").populate_file_manager()
