extends GutTest

## Migrato dal vecchio test manuale tests/test_terminal_drive_node.gd
## Verifica l'autoload TerminalDriveManager, la creazione automatica della
## cartella "Terminal Drive" con i suoi file di configurazione predefiniti,
## la protezione della sottocartella "systems", il parser get_setting(),
## l'isolamento da ShipDriveManager, e le utility di path.

func test_terminal_drive_manager_autoload_exists() -> void:
	var tdm: Node = get_node_or_null("/root/TerminalDriveManager")
	assert_not_null(tdm, "l'autoload TerminalDriveManager deve esistere!")

func test_terminal_drive_folder_created_on_startup() -> void:
	var tdm: Node = get_node_or_null("/root/TerminalDriveManager")
	assert_true(DirAccess.dir_exists_absolute("user://files/Terminal Drive"), "user://files/Terminal Drive deve esistere!")
	assert_true(tdm.get("is_drive_loaded"), "is_drive_loaded deve essere true!")

func test_default_configuration_files_exist() -> void:
	assert_true(FileAccess.file_exists("user://files/Terminal Drive/Terminal Settings.txt"), "Terminal Settings.txt deve esistere!")
	assert_true(FileAccess.file_exists("user://files/Terminal Drive/Commands Reference.txt"), "Commands Reference.txt deve esistere!")
	assert_true(FileAccess.file_exists("user://files/Terminal Drive/Environment.txt"), "Environment.txt deve esistere!")
	assert_true(FileAccess.file_exists("user://files/Terminal Drive/Aliases.txt"), "Aliases.txt deve esistere!")
	assert_true(FileAccess.file_exists("user://files/Terminal Drive/systems/terminal_config.dat"), "terminal_config.dat deve esistere in systems!")
	assert_true(FileAccess.file_exists("user://files/Terminal Drive/systems/godotos_core.dat"), "godotos_core.dat deve esistere in systems!")
	assert_true(FileAccess.file_exists("user://files/Terminal Drive/systems/desktop_config.dat"), "desktop_config.dat deve esistere in systems!")

	var fpm: Node = get_node_or_null("/root/FolderPasswordManager")
	if fpm:
		assert_true(fpm.has_password("Terminal Drive/systems"), "Terminal Drive/systems deve essere protetto da password!")
		assert_eq(fpm.get_password("Terminal Drive/systems"), "ROOT-7815", "La password di Terminal Drive/systems deve essere ROOT-7815")

func test_get_setting_parses_configuration() -> void:
	var tdm: Node = get_node_or_null("/root/TerminalDriveManager")
	var font_size: String = tdm.get_setting("FONT_SIZE", "0")
	assert_eq(font_size, "14", "FONT_SIZE atteso '14', ottenuto: %s" % font_size)
	var theme_accent: String = tdm.get_setting("THEME_ACCENT", "")
	assert_eq(theme_accent, "matrix_green", "THEME_ACCENT atteso 'matrix_green', ottenuto: %s" % theme_accent)
	var os_name: String = tdm.get_setting("OS_NAME", "")
	assert_eq(os_name, "GodotOS", "OS_NAME atteso 'GodotOS', ottenuto: %s" % os_name)

func test_ship_drive_manager_does_not_sync_terminal_drive() -> void:
	var sdm: Node = get_node_or_null("/root/ShipDriveManager")
	if sdm:
		assert_false(sdm._is_path_in_ship_drive("Terminal Drive"), "Terminal Drive non deve essere in Ship Drive!")
		assert_false(sdm._is_path_in_ship_drive("Terminal Drive/Terminal Settings.txt"), "I file di Terminal Drive non devono essere in Ship Drive!")

func test_is_path_in_terminal_drive_helper() -> void:
	var tdm: Node = get_node_or_null("/root/TerminalDriveManager")
	assert_true(tdm.is_path_in_terminal_drive("Terminal Drive"), "is_path_in_terminal_drive deve riconoscere la root")
	assert_true(tdm.is_path_in_terminal_drive("Terminal Drive/custom.txt"), "is_path_in_terminal_drive deve riconoscere un sottofile")
	assert_false(tdm.is_path_in_terminal_drive("Ship Drive"), "is_path_in_terminal_drive deve restituire false per Ship Drive")

func test_local_file_manipulation_inside_terminal_drive() -> void:
	var test_file_path: String = "user://files/Terminal Drive/local_test.txt"
	var f: FileAccess = FileAccess.open(test_file_path, FileAccess.WRITE)
	f.store_string("local terminal test data")
	f.close()
	assert_true(FileAccess.file_exists(test_file_path), "il file locale deve essere stato creato in Terminal Drive")
	DirAccess.remove_absolute(test_file_path)
