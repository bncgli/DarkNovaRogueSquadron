extends Control

func _ready() -> void:
	print("=== RUNNING TERMINAL DRIVE TESTS ===")
	await get_tree().process_frame
	
	# 1. Verifica presenza dell'Autoload TerminalDriveManager
	var tdm: Node = get_node_or_null("/root/TerminalDriveManager")
	assert(tdm != null, "TerminalDriveManager autoload deve esistere!")
	print("TEST 1: TerminalDriveManager autoload trovato -> OK")
	
	# 2. Verifica creazione automatica della cartella "Terminal Drive"
	assert(DirAccess.dir_exists_absolute("user://files/Terminal Drive"), "user://files/Terminal Drive deve esistere!")
	assert(tdm.get("is_drive_loaded") == true, "is_drive_loaded deve essere true!")
	print("TEST 2: Cartella 'Terminal Drive' presente su disco all'avvio -> OK")
	
	# 3. Verifica presenza dei file predefiniti di configurazione
	var files: PackedStringArray = DirAccess.get_files_at("user://files/Terminal Drive")
	print("File in Terminal Drive: ", files)
	assert(FileAccess.file_exists("user://files/Terminal Drive/Terminal Settings.txt"), "Terminal Settings.txt deve esistere!")
	assert(FileAccess.file_exists("user://files/Terminal Drive/Commands Reference.txt"), "Commands Reference.txt deve esistere!")
	assert(FileAccess.file_exists("user://files/Terminal Drive/Environment.txt"), "Environment.txt deve esistere!")
	assert(FileAccess.file_exists("user://files/Terminal Drive/Aliases.txt"), "Aliases.txt deve esistere!")
	print("TEST 3: File predefiniti di configurazione presenti -> OK")
	
	# 4. Verifica lettura configurazioni con get_setting
	var font_size: String = tdm.get_setting("FONT_SIZE", "0")
	assert(font_size == "14", "FONT_SIZE atteso '14', ottenuto: %s" % font_size)
	var theme_accent: String = tdm.get_setting("THEME_ACCENT", "")
	assert(theme_accent == "matrix_green", "THEME_ACCENT atteso 'matrix_green', ottenuto: %s" % theme_accent)
	var os_name: String = tdm.get_setting("OS_NAME", "")
	assert(os_name == "GodotOS", "OS_NAME atteso 'GodotOS', ottenuto: %s" % os_name)
	print("TEST 4: get_setting() parser configurazione -> OK")
	
	# 5. Verifica che ShipDriveManager non sincronizzi i percorsi di Terminal Drive
	var sdm: Node = get_node_or_null("/root/ShipDriveManager")
	if sdm:
		assert(not sdm._is_path_in_ship_drive("Terminal Drive"), "Terminal Drive non deve essere in Ship Drive!")
		assert(not sdm._is_path_in_ship_drive("Terminal Drive/Terminal Settings.txt"), "I file di Terminal Drive non devono essere in Ship Drive!")
		print("TEST 5: ShipDriveManager isolamento (nessuna sincronizzazione di rete per Terminal Drive) -> OK")
	
	# 6. Verifica helper is_path_in_terminal_drive
	assert(tdm.is_path_in_terminal_drive("Terminal Drive"), "is_path_in_terminal_drive root -> OK")
	assert(tdm.is_path_in_terminal_drive("Terminal Drive/custom.txt"), "is_path_in_terminal_drive subfile -> OK")
	assert(not tdm.is_path_in_terminal_drive("Ship Drive"), "is_path_in_terminal_drive false check -> OK")
	print("TEST 6: is_path_in_terminal_drive verifiche percorso -> OK")
	
	# 7. Verifica creazione file locale all'interno di Terminal Drive
	var test_file_path: String = "user://files/Terminal Drive/local_test.txt"
	var f: FileAccess = FileAccess.open(test_file_path, FileAccess.WRITE)
	f.store_string("local terminal test data")
	f.close()
	assert(FileAccess.file_exists(test_file_path), "File locale creato in Terminal Drive")
	DirAccess.remove_absolute(test_file_path)
	print("TEST 7: Manipolazione file locale all'interno di Terminal Drive -> OK")
	
	print("=== ALL TERMINAL DRIVE TESTS PASSED! ===")
	get_tree().quit(0)
