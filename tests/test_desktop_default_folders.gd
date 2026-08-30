extends SceneTree

func _init() -> void:
	print("--- INIZIO TEST DESKTOP DEFAULT FOLDERS ---")
	
	# Simula la situazione in cui user://files esiste prima dell'inizializzazione del Desktop (creata da Autoload)
	if not DirAccess.dir_exists_absolute("user://files"):
		DirAccess.make_dir_recursive_absolute("user://files")
	
	# Istanzia DesktopFileManager
	var desktop_script: GDScript = load("res://Scenes/Main/desktop_file_manager.gd")
	var desktop: DesktopFileManager = desktop_script.new()
	
	# Esegui ensure_default_files
	desktop.ensure_default_files()
	
	# Verifiche
	var user_dir := DirAccess.open("user://")
	assert(user_dir.dir_exists("files/Welcome Folder"), "ERRORE: Welcome Folder non esiste!")
	assert(user_dir.dir_exists("files/Wallpapers"), "ERRORE: Wallpapers non esiste!")
	
	assert(FileAccess.file_exists("user://files/Welcome Folder/Welcome.txt"), "ERRORE: Welcome.txt non esiste!")
	assert(FileAccess.file_exists("user://files/Welcome Folder/Credits.txt"), "ERRORE: Credits.txt non esiste!")
	assert(FileAccess.file_exists("user://files/Welcome Folder/GodotOS Handbook.txt"), "ERRORE: GodotOS Handbook.txt non esiste!")
	assert(FileAccess.file_exists("user://files/Wallpapers/default wall.webp"), "ERRORE: default wall.webp non esiste!")
	assert(FileAccess.file_exists("user://files/Wallpapers/chill.webp"), "ERRORE: chill.webp non esiste!")
	assert(FileAccess.file_exists("user://files/Wallpapers/minimalism.webp"), "ERRORE: minimalism.webp non esiste!")
	
	print("[OK] Tutte le cartelle e i file di default sono stati generati correttamente!")
	print("--- TEST COMPLETATO CON SUCCESSO ---")
	desktop.free()
	quit(0)
