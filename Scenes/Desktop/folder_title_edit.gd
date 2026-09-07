extends TextEdit

## Handles renaming of a folder.

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("rename") and $"../../../Selected Highlight".visible:
		show_rename()
	
	if !get_parent().visible:
		return
	
	if event.is_action_pressed("ui_accept"):
		accept_event()
		trigger_rename()
	
	if event.is_action_pressed("ui_cancel"):
		cancel_rename()
	
	if event is InputEventMouseButton and event.is_pressed():
		var evLocal: InputEvent = make_input_local(event)
		if !Rect2(Vector2(0,0), size).has_point(evLocal.position):
			cancel_rename()

func show_rename() -> void:
	get_parent().visible = true
	grab_focus()
	var folder: FakeFolder = $"../../.."
	var full_name: String = %"Folder Title".text.trim_prefix("[center]")
	if folder.file_type == GlobalValues.FileType.FOLDER:
		text = full_name
	else:
		text = full_name.get_basename()
	select_all()

func trigger_rename() -> void:
	if text.contains('/') or text.contains('\\') or text.contains('¥') or text.contains('₩'):
		NotificationManagerSingleton.spawn_notification("Error: File name can't include slashes!")
		return
	
	if text.is_empty():
		NotificationManagerSingleton.spawn_notification("Error: File name can't be empty!")
		return
	
	get_parent().visible = false
	var folder: FakeFolder = $"../../.."
	
	if folder.folder_name == "Ship Drive" and (folder.folder_path == "Ship Drive" or folder.folder_path == ""):
		NotificationManagerSingleton.spawn_notification("Non e' possibile rinominare 'Ship Drive'.")
		cancel_rename()
		return
	
	if folder.folder_name == "Terminal Drive" and (folder.folder_path == "Terminal Drive" or folder.folder_path == ""):
		NotificationManagerSingleton.spawn_notification("Non e' possibile rinominare 'Terminal Drive'.")
		cancel_rename()
		return

	if folder.folder_name == "Target Drive" and (folder.folder_path == "Target Drive" or folder.folder_path == ""):
		NotificationManagerSingleton.spawn_notification("Non e' possibile rinominare 'Target Drive'.")
		cancel_rename()
		return
	
	if folder.file_type != GlobalValues.FileType.FOLDER:
		var old_folder_name: String = folder.folder_name
		var ext: String = old_folder_name.get_extension()
		var new_folder_name: String
		if not ext.is_empty():
			new_folder_name = "%s.%s" % [text.trim_suffix("." + ext), ext]
		else:
			new_folder_name = text
		
		var clean_dir := folder.folder_path.replace("\\", "/").strip_edges().trim_prefix("/").trim_suffix("/")
		var prefix := (clean_dir + "/") if not clean_dir.is_empty() else ""
		
		var old_abs := "user://files/%s%s" % [prefix, old_folder_name]
		var new_abs := "user://files/%s%s" % [prefix, new_folder_name]
		
		if FileAccess.file_exists(new_abs):
			cancel_rename()
			NotificationManagerSingleton.spawn_notification("That file already exists!")
			return
		
		folder.folder_name = new_folder_name
		DirAccess.rename_absolute(old_abs, new_abs)
		%"Folder Title".text = "[center]%s" % folder.folder_name
		
		var sdm := get_node_or_null("/root/ShipDriveManager")
		if sdm and sdm.get("is_drive_mounted"):
			var old_file_rel := "%s%s" % [prefix, old_folder_name]
			var new_file_rel := "%s%s" % [prefix, new_folder_name]
			sdm.sync_rename(old_file_rel, new_file_rel, false)
		
		if folder.get_parent() is DesktopFileManager:
			folder.get_parent().sort_folders()
		else:
			# Reloads open windows
			for file_manager: FileManagerWindow in get_tree().get_nodes_in_group("file_manager_window"):
				if file_manager.file_path == clean_dir:
					file_manager.sort_folders()
		for text_editor in get_tree().get_nodes_in_group("text_editor_window"):
			var old_rel := "%s%s" % [prefix, old_folder_name]
			var new_rel := "%s%s" % [prefix, new_folder_name]
			if text_editor.file_path == old_rel:
				text_editor.file_path = new_rel
			elif clean_dir.is_empty() and text_editor.file_path == old_folder_name:
				text_editor.file_path = new_folder_name
	
	elif folder.file_type == GlobalValues.FileType.FOLDER:
		var old_folder_name: String = folder.folder_name
		var old_folder_path: String = folder.folder_path.replace("\\", "/").strip_edges().trim_prefix("/").trim_suffix("/")
		
		var parent_dir := old_folder_path.get_base_dir()
		var prefix := (parent_dir + "/") if not parent_dir.is_empty() else ""
		var new_folder_path := "%s%s" % [prefix, text]
		
		if DirAccess.dir_exists_absolute("user://files/%s" % new_folder_path):
			cancel_rename()
			NotificationManagerSingleton.spawn_notification("That folder already exists!")
			return
		
		folder.folder_path = new_folder_path
		folder.folder_name = text
		%"Folder Title".text = "[center]%s" % folder.folder_name
		DirAccess.rename_absolute("user://files/%s" % old_folder_path, "user://files/%s" % folder.folder_path)
		
		var fpm := get_node_or_null("/root/FolderPasswordManager")
		if fpm:
			fpm.rename_path(old_folder_path, folder.folder_path)
		
		var sdm := get_node_or_null("/root/ShipDriveManager")
		if sdm and sdm.get("is_drive_mounted"):
			sdm.sync_rename(old_folder_path, folder.folder_path, true)
		
		if folder.get_parent() is DesktopFileManager:
			folder.get_parent().sort_folders()
		for file_manager: FileManagerWindow in get_tree().get_nodes_in_group("file_manager_window"):
			if file_manager.file_path.begins_with(old_folder_path):
				file_manager.file_path = file_manager.file_path.replace(old_folder_path, folder.folder_path)
				file_manager.reload_window(file_manager.file_path)
			elif file_manager.file_path == parent_dir:
				file_manager.sort_folders()
	
	text = ""

func cancel_rename() -> void:
	get_parent().visible = false
	text = ""
