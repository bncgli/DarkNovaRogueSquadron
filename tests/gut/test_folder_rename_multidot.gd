extends GutTest

## Migrato dal vecchio test manuale tests/test_folder_rename_multidot.gd
## Verifica che show_rename() non tronchi il nome al primo punto invece che
## all'ultimo, per file con più punti nel nome (es. "my.file.txt").

func test_rename_field_truncates_only_last_extension() -> void:
	var folder_scene: PackedScene = load("res://Scenes/Desktop/folder.tscn")
	var folder: FakeFolder = folder_scene.instantiate()
	folder.folder_name = "my.file.txt"
	folder.folder_path = ""
	folder.file_type = GlobalValues.FileType.TEXT_FILE
	add_child_autofree(folder)
	await get_tree().process_frame

	var edit: TextEdit = folder.get_node("%Folder Title Edit")
	edit.show_rename()
	await get_tree().process_frame

	assert_eq(edit.text, "my.file", "Il campo di rename dovrebbe contenere 'my.file' (senza estensione)")
