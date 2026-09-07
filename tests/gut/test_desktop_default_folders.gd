extends GutTest

## Migrato dal vecchio test manuale tests/test_desktop_default_folders.gd
## Verifica che DesktopFileManager.ensure_default_files() crei correttamente
## le cartelle e i file di default sul "desktop" (user://files/...).

func before_each() -> void:
	# Simula la situazione in cui user://files esiste già prima
	# dell'inizializzazione del Desktop (creata da un Autoload).
	if not DirAccess.dir_exists_absolute("user://files"):
		DirAccess.make_dir_recursive_absolute("user://files")

func test_ensure_default_files_creates_default_folders_and_files() -> void:
	var desktop_script: GDScript = load("res://Scenes/Main/desktop_file_manager.gd")
	var desktop: DesktopFileManager = desktop_script.new()
	# Il nodo deve appartenere all'albero della scena prima di chiamare
	# ensure_default_files(), perché il metodo cerca autoload/nodi con
	# percorsi assoluti (es. "/root/Control/Wallpaper") e questo fallisce
	# con un errore del motore se il nodo è scollegato dall'albero.
	add_child_autofree(desktop)

	desktop.ensure_default_files()

	var user_dir := DirAccess.open("user://")
	assert_true(user_dir.dir_exists("files/Welcome Folder"), "La cartella 'Welcome Folder' deve esistere")
	assert_true(user_dir.dir_exists("files/Wallpapers"), "La cartella 'Wallpapers' deve esistere")

	assert_true(FileAccess.file_exists("user://files/Welcome Folder/Welcome.txt"), "Welcome.txt deve esistere")
	assert_true(FileAccess.file_exists("user://files/Welcome Folder/Credits.txt"), "Credits.txt deve esistere")
	assert_true(FileAccess.file_exists("user://files/Welcome Folder/GodotOS Handbook.txt"), "GodotOS Handbook.txt deve esistere")
	assert_true(FileAccess.file_exists("user://files/Wallpapers/default wall.webp"), "default wall.webp deve esistere")
	assert_true(FileAccess.file_exists("user://files/Wallpapers/chill.webp"), "chill.webp deve esistere")
	assert_true(FileAccess.file_exists("user://files/Wallpapers/minimalism.webp"), "minimalism.webp deve esistere")
