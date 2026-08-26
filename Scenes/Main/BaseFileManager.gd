extends SmoothContainer
class_name BaseFileManager

## The base file manager inherited by desktop file manager and the file manager window.

## The file manager's path (relative to user://files/)
@export var file_path: String

## Removes all current folders (if any) and populates the file manager from file path.
func populate_file_manager() -> void:
	for child in get_children():
		if child is FakeFolder:
			child.queue_free()
	for folder_name in DirAccess.get_directories_at("user://files/%s" % file_path):
		if file_path.is_empty() and folder_name == "Ship Drive":
			var sdm := get_node_or_null("/root/ShipDriveManager")
			if not sdm or not sdm.get("is_drive_mounted") or not sdm.is_ship_connected():
				continue
		if file_path.is_empty():
			instantiate_file(folder_name, folder_name, FakeFolder.file_type_enum.FOLDER)
		else:
			instantiate_file(folder_name, "%s/%s" % [file_path, folder_name], FakeFolder.file_type_enum.FOLDER)
	
	for file_name: String in DirAccess.get_files_at("user://files/%s" % file_path):
		if file_name.ends_with(".txt") or file_name.ends_with(".md"):
			instantiate_file(file_name, file_path, FakeFolder.file_type_enum.TEXT_FILE)
		elif file_name.ends_with(".png") or file_name.ends_with(".jpg") or file_name.ends_with(".jpeg")\
		or file_name.ends_with(".webp"):
			instantiate_file(file_name, file_path, FakeFolder.file_type_enum.IMAGE)
	
	await get_tree().process_frame
	await get_tree().process_frame # TODO fix whatever's causing a race condition :/
	sort_folders()

## Adds a folder as a child
func instantiate_file(file_name: String, path: String, file_type: FakeFolder.file_type_enum) -> void:
	var folder: FakeFolder = load("res://Scenes/Desktop/folder.tscn").instantiate()
	folder.folder_name = file_name
	folder.folder_path = path
	folder.file_type = file_type
	add_child(folder)

## Sorts all folders to their correct positions. 
func sort_folders() -> void:
	if len(get_children()) < 3:
		update_positions(false)
		return
	var sorted_children: Array[Node] = []
	for child in get_children():
		if child is FakeFolder:
			sorted_children.append(child)
			remove_child(child)
	sorted_children.sort_custom(_custom_folder_sort)
	sorted_children.sort_custom(_custom_folders_first_sort)
	for child in sorted_children:
		add_child(child)
	
	await get_tree().process_frame
	update_positions(false)

## Creates a new folder.
## Not to be confused with instantiating which adds an existing real folder, this function CREATES one. 
func new_folder(new_folder_name: String = "New Folder", folder_path: String = "") -> void:
	# Takes file_path as priority for folders added
	# by context menu, this is for backward compatibility
	if not file_path.is_empty():
		folder_path = file_path
	
	var clean_dir := folder_path.replace("\\", "/").strip_edges().trim_prefix("/").trim_suffix("/")
	var prefix := (clean_dir + "/") if not clean_dir.is_empty() else ""
	
	var candidate_name: String = new_folder_name
	if DirAccess.dir_exists_absolute("user://files/%s%s" % [prefix, candidate_name]):
		for i in range(2, 1000):
			var test_name := "%s %d" % [new_folder_name, i]
			if not DirAccess.dir_exists_absolute("user://files/%s%s" % [prefix, test_name]):
				candidate_name = test_name
				break
	
	DirAccess.make_dir_absolute("user://files/%s%s" % [prefix, candidate_name])
	var rel_folder := "%s%s" % [prefix, candidate_name]
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.get("is_drive_mounted"):
		sdm.sync_folder(rel_folder)
	
	for file_manager: FileManagerWindow in get_tree().get_nodes_in_group("file_manager_window"):
		if file_manager.file_path == clean_dir:
			file_manager.instantiate_file(candidate_name, rel_folder, FakeFolder.file_type_enum.FOLDER)
			await get_tree().process_frame # Waiting for child to get added...
			file_manager.sort_folders()
	
	if clean_dir.is_empty():
		instantiate_file(candidate_name, candidate_name, FakeFolder.file_type_enum.FOLDER)
		sort_folders()

## Creates a new file.
## Not to be confused with instantiating which adds an existing real folder, this function CREATES one. 
func new_file(extension: String, file_type: FakeFolder.file_type_enum, new_file_name: String = "New File", new_file_path: String = "") -> void:
	if not extension.begins_with("."):
		extension = "." + extension
	
	# Takes file_path as priority for folders added
	# by context menu, this is for backward compatibility
	if not file_path.is_empty():
		new_file_path = file_path
	
	var clean_dir := new_file_path.replace("\\", "/").strip_edges().trim_prefix("/").trim_suffix("/")
	var prefix := (clean_dir + "/") if not clean_dir.is_empty() else ""
	
	var base_name := new_file_name
	if base_name.ends_with(extension):
		base_name = base_name.trim_suffix(extension)
	
	var candidate_name := "%s%s" % [base_name, extension]
	if FileAccess.file_exists("user://files/%s%s" % [prefix, candidate_name]):
		for i in range(2, 1000):
			var test_name := "%s %d%s" % [base_name, i, extension]
			if not FileAccess.file_exists("user://files/%s%s" % [prefix, test_name]):
				candidate_name = test_name
				break
	
	# Just touches the file
	var _file: FileAccess = FileAccess.open("user://files/%s%s" % [prefix, candidate_name], FileAccess.WRITE)
	if _file:
		_file.close()
	
	var rel_file := "%s%s" % [prefix, candidate_name]
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.get("is_drive_mounted"):
		sdm.sync_file(rel_file, "")
	
	for file_manager: FileManagerWindow in get_tree().get_nodes_in_group("file_manager_window"):
		if file_manager.file_path == clean_dir:
			file_manager.instantiate_file(candidate_name, clean_dir, file_type)
			await get_tree().process_frame # Waiting for child to get added...
			file_manager.sort_folders()
	
	if clean_dir.is_empty():
		instantiate_file(candidate_name, clean_dir, file_type)
		sort_folders()

## Finds a file/folder based on name and frees it (but doesn't delete it from the actual system)
func delete_file_with_name(file_name: String) -> void:
	for child in get_children():
		if !(child is FakeFolder):
			continue
		
		if child.folder_name == file_name:
			child.queue_free()
	
	await get_tree().process_frame
	sort_folders()

## Keyboard controls for selecting files.
## Is kind of messy because the file manager can be horizontal or vertical, which changes which direction the next folder is.
func select_folder_up(current_folder: FakeFolder) -> void:
	if direction == "Horizontal":
		select_previous_line_folder(current_folder)
	elif direction == "Vertical":
		select_previous_folder(current_folder)

func select_folder_down(current_folder: FakeFolder) -> void:
	if direction == "Horizontal":
		select_next_line_folder(current_folder)
	elif direction == "Vertical":
		select_next_folder(current_folder)

func select_folder_left(current_folder: FakeFolder) -> void:
	if direction == "Horizontal":
		select_previous_folder(current_folder)
	elif direction == "Vertical":
		select_previous_line_folder(current_folder)

func select_folder_right(current_folder: FakeFolder) -> void:
	if direction == "Horizontal":
		select_next_folder(current_folder)
	elif direction == "Vertical":
		select_next_line_folder(current_folder)

func select_next_folder(current_folder: FakeFolder) -> void:
	var target_index: int = current_folder.get_index() + 1
	if target_index >= get_child_count():
		return
	var next_child: Node = get_child(target_index)
	if next_child is FakeFolder:
		current_folder.hide_selected_highlight()
		next_child.show_selected_highlight()

func select_next_line_folder(current_folder: FakeFolder) -> void:
	var target_index: int = current_folder.get_index() + line_count
	if target_index >= get_child_count():
		return
	var target_folder: Node = get_child(target_index)
	if target_folder is FakeFolder:
		current_folder.hide_selected_highlight()
		target_folder.show_selected_highlight()

func select_previous_folder(current_folder: FakeFolder) -> void:
	var target_index: int = current_folder.get_index() - 1
	if target_index < 0:
		return
	var previous_child: Node = get_child(target_index)
	if previous_child is FakeFolder:
		current_folder.hide_selected_highlight()
		previous_child.show_selected_highlight()

func select_previous_line_folder(current_folder: FakeFolder) -> void:
	var target_index: int = current_folder.get_index() - line_count
	if target_index < 0:
		return
	var target_folder: Node = get_child(target_index)
	if target_folder is FakeFolder:
		current_folder.hide_selected_highlight()
		target_folder.show_selected_highlight()


## Sorts folders based on their name
func _custom_folder_sort(a: FakeFolder, b: FakeFolder) -> bool:
	if a.folder_name.to_lower() < b.folder_name.to_lower():
		return true
	return false

## Puts folders first in the array (as opposed to files)
func _custom_folders_first_sort(a: FakeFolder, b: FakeFolder) -> bool:
	if a.file_type == FakeFolder.file_type_enum.FOLDER and a.file_type != b.file_type:
		return true
	return false
