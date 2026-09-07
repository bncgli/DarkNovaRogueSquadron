extends GutTest

## Migrato dal vecchio test manuale tests/test_file_manager_navigation.gd
## Verifica il tasto "Back" da una cartella di primo livello e l'assenza di
## duplicati quando si crea una nuova cartella mentre il File Manager Window
## è alla radice.

func before_each() -> void:
	if not DirAccess.dir_exists_absolute("user://files"):
		DirAccess.make_dir_recursive_absolute("user://files")
	if not DirAccess.dir_exists_absolute("user://files/TestTopLevelFolder"):
		DirAccess.make_dir_recursive_absolute("user://files/TestTopLevelFolder")

func after_each() -> void:
	if DirAccess.dir_exists_absolute("user://files/TestDedupFolder"):
		DirAccess.remove_absolute("user://files/TestDedupFolder")
	if DirAccess.dir_exists_absolute("user://files/TestTopLevelFolder"):
		DirAccess.remove_absolute("user://files/TestTopLevelFolder")

func test_back_button_returns_to_root_from_top_level_folder() -> void:
	var fmw_scene: PackedScene = load("res://Scenes/Window/File Manager/file_manager_window.tscn")
	var fmw_window: FakeWindow = fmw_scene.instantiate()
	add_child_autofree(fmw_window)
	await get_tree().process_frame

	var fmw: FileManagerWindow = fmw_window.get_node("%File Manager Window")
	fmw.file_path = "TestTopLevelFolder"
	fmw._on_back_button_pressed()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(fmw.file_path, "", "Il tasto Back deve tornare alla radice da una cartella di primo livello")

func test_new_folder_at_root_does_not_duplicate_folder() -> void:
	var fmw_scene: PackedScene = load("res://Scenes/Window/File Manager/file_manager_window.tscn")
	var fmw_window: FakeWindow = fmw_scene.instantiate()
	add_child_autofree(fmw_window)
	await get_tree().process_frame

	var fmw: FileManagerWindow = fmw_window.get_node("%File Manager Window")

	await fmw.new_folder("TestDedupFolder")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var matches: int = 0
	for child in fmw.get_children():
		if child is FakeFolder and child.folder_name == "TestDedupFolder":
			matches += 1

	assert_eq(matches, 1, "La cartella 'TestDedupFolder' non deve essere duplicata né mancante")
