extends BaseFileManager
class_name DesktopFileManager

## The desktop file manager.

func _ready() -> void:
	ensure_default_files()
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm:
		if not sdm.is_ship_connected():
			if DirAccess.dir_exists_absolute("user://files/Ship Drive"):
				sdm._delete_dir_recursive("user://files/Ship Drive")
			sdm._close_ship_drive_windows()
	
	var tdm := get_node_or_null("/root/TerminalDriveManager")
	if tdm and tdm.has_method("ensure_drive_exists"):
		tdm.ensure_drive_exists()
	
	populate_file_manager()
	if get_window():
		get_window().size_changed.connect(update_positions)
		get_window().focus_entered.connect(_on_window_focus)

func ensure_default_files() -> void:
	var user_dir: DirAccess = DirAccess.open("user://")
	if not user_dir:
		DirAccess.make_dir_recursive_absolute("user://files")
		user_dir = DirAccess.open("user://")
	
	if not user_dir.dir_exists("files"):
		user_dir.make_dir_recursive("files")

	if not user_dir.dir_exists("files/Welcome Folder"):
		user_dir.make_dir_recursive("files/Welcome Folder")
	if not user_dir.dir_exists("files/Wallpapers"):
		user_dir.make_dir_recursive("files/Wallpapers")

	var welcome_file := "user://files/Welcome Folder/Welcome.txt"
	if not FileAccess.file_exists(welcome_file):
		copy_from_res("res://Default Files/Welcome.txt", welcome_file)

	var credits_file := "user://files/Welcome Folder/Credits.txt"
	if not FileAccess.file_exists(credits_file):
		copy_from_res("res://Default Files/Credits.txt", credits_file)

	var handbook_file := "user://files/Welcome Folder/GodotOS Handbook.txt"
	if not FileAccess.file_exists(handbook_file):
		copy_from_res("res://Default Files/GodotOS Handbook.txt", handbook_file)

	var default_wall := "user://files/Wallpapers/default wall.webp"
	if not FileAccess.file_exists(default_wall):
		copy_from_res("res://Default Files/default wall.webp", default_wall)

	var chill_wall := "user://files/Wallpapers/chill.webp"
	if not FileAccess.file_exists(chill_wall):
		copy_from_res("res://Default Files/wallpaper_chill.webp", chill_wall)

	var minimalism_wall := "user://files/Wallpapers/minimalism.webp"
	if not FileAccess.file_exists(minimalism_wall):
		copy_from_res("res://Default Files/wallpaper_minimalism.webp", minimalism_wall)

	var user_default_wall := "user://default wall.webp"
	if not FileAccess.file_exists(user_default_wall):
		copy_from_res("res://Default Files/default wall.webp", user_default_wall)
		DefaultValues.wallpaper_name = "default wall.webp"
		DefaultValues.save_state()

	var wallpaper: Wallpaper = get_node_or_null("/root/Control/Wallpaper") as Wallpaper
	if wallpaper and is_instance_valid(wallpaper):
		wallpaper.apply_wallpaper_from_path("files/Wallpapers/default wall.webp")

func copy_from_res(from: String, to: String) -> void:
	var file_from: FileAccess = FileAccess.open(from, FileAccess.READ)
	if not file_from:
		return
	var base_dir := to.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)
	var file_to: FileAccess = FileAccess.open(to, FileAccess.WRITE)
	if not file_to:
		file_from.close()
		return
	file_to.store_buffer(file_from.get_buffer(file_from.get_length()))
	
	file_from.close()
	file_to.close()

## Checks if any files were changed on the desktop, and populates the file manager again if so.
func _on_window_focus() -> void:
	var current_file_names: Array[String] = []
	for child in get_children():
		if !(child is FakeFolder):
			continue
		
		current_file_names.append(child.folder_name)
	
	var new_file_names: Array[String] = []
	for file_name in DirAccess.get_files_at("user://files/"):
		new_file_names.append(file_name)
	for folder_name in DirAccess.get_directories_at("user://files/"):
		if folder_name == "Ship Drive":
			var sdm := get_node_or_null("/root/ShipDriveManager")
			if not sdm or not sdm.get("is_drive_mounted") or not sdm.is_ship_connected():
				continue
		elif folder_name == "Target Drive":
			var rdm := get_node_or_null("/root/RemoteDriveManager")
			if not rdm or not rdm.get("is_target_drive_mounted"):
				continue
		new_file_names.append(folder_name)
	
	if current_file_names.size() != new_file_names.size():
		populate_file_manager()
		return
	
	for file_name in new_file_names:
		if !current_file_names.has(file_name):
			populate_file_manager()
			return
