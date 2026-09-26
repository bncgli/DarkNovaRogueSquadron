extends BaseFileManager
class_name FileManagerWindow

## The file manager window.

@onready var reset_button: Button = get_node_or_null("../../Top Bar/Reset Button")

func _ready() -> void:
	populate_file_manager()
	sort_folders()
	
	$"../../Resize Drag Spot".window_resized.connect(update_positions)
	_update_reset_button_visibility()

func reload_window(folder_path: String) -> void:
	# Reload the same path if not given folder_path
	if !folder_path.is_empty():
		file_path = folder_path
	
	for child in get_children():
		if child is FakeFolder:
			child.queue_free()
	
	populate_file_manager()
	
	#TODO make this less dumb
	$"../../Top Bar/Title Text".text = "[center]%s" % file_path
	_update_reset_button_visibility()

func _update_reset_button_visibility() -> void:
	if reset_button == null:
		reset_button = get_node_or_null("../../Top Bar/Reset Button")
	if reset_button:
		var is_ship_drive := (file_path == "Ship Drive" or file_path.begins_with("Ship Drive/") or file_path.begins_with("Ship Drive\\"))
		reset_button.visible = is_ship_drive

func close_window() -> void:
	$"../.."._on_close_button_pressed()

## Goes to the folder above the currently shown one. Can't go higher than user://files/
func _on_back_button_pressed() -> void:
	#TODO move it to a position that's less stupid
	if file_path.is_empty():
		return
	
	var split_path: PackedStringArray = file_path.split("/")
	split_path.remove_at(split_path.size() - 1)
	file_path = "/".join(split_path)
	
	reload_window(file_path)

func request_reset_to_default(prompt_confirm: bool = true) -> void:
	var reset_action := func() -> void:
		var sdm := get_node_or_null("/root/ShipDriveManager")
		if sdm and sdm.has_method("reset_ship_drive_to_default"):
			sdm.reset_ship_drive_to_default()
		elif sdm and sdm.has_method("restore_default_ship_drive_files"):
			sdm.restore_default_ship_drive_files()
		reload_window(file_path)
	
	if not prompt_confirm:
		reset_action.call()
		return
		
	ConfirmDialog.show_dialog(
		get_tree(),
		"Ripristino Ship Drive",
		"Sei sicuro di voler ripristinare tutti i file di bordo ai valori di fabbrica?\nEventuali modifiche andranno perse.",
		reset_action,
		Callable(),
		"Ripristina",
		"Annulla"
	)

func _on_reset_button_pressed() -> void:
	request_reset_to_default(true)
