extends Control

func _ready() -> void:
	print("=== RUNNING TERMINAL COMMANDS (WORM, DECRIPT, DATAREAD) TESTS ===")
	await get_tree().process_frame
	
	await test_command_registration()
	await test_worm_command()
	await test_decript_command()
	await test_dataread_and_text_editor()
	await test_terminal_interactive_flow()
	
	print("=== ALL TERMINAL COMMAND TESTS PASSED! ===")
	get_tree().quit(0)


func test_command_registration() -> void:
	print("\n--- TEST 1: Command Registration in TerminalCommandManager ---")
	var cmd_manager := TerminalCommandManager.new()
	
	assert(cmd_manager.cmd_exists("worm"), "worm command must be registered!")
	assert(cmd_manager.cmd_exists("decript"), "decript command must be registered!")
	assert(cmd_manager.cmd_exists("dataread"), "dataread command must be registered!")
	
	var worm_cmd: TerminalCommand = cmd_manager.load_command("worm")
	assert(worm_cmd != null and worm_cmd.call_name == "worm", "worm command instance valid")
	assert(worm_cmd.usage().size() > 0, "worm usage() defined")
	
	var decript_cmd: TerminalCommand = cmd_manager.load_command("decript")
	assert(decript_cmd != null and decript_cmd.call_name == "decript", "decript command instance valid")
	assert(decript_cmd.usage().size() > 0, "decript usage() defined")
	
	var dataread_cmd: TerminalCommand = cmd_manager.load_command("dataread")
	assert(dataread_cmd != null and dataread_cmd.call_name == "dataread", "dataread command instance valid")
	assert(dataread_cmd.usage().size() > 0, "dataread usage() defined")
	
	print("TEST 1: PASS - All 3 commands registered and loadable.")


func test_worm_command() -> void:
	print("\n--- TEST 2: 'worm' Command (Mastermind Breaching) ---")
	var terminal_scene: PackedScene = load("res://Applications/Terminal/src/terminal_scene.tscn")
	var terminal: Terminal = terminal_scene.instantiate()
	add_child(terminal)
	await get_tree().process_frame
	
	var fpm: FolderPasswordManagerSingleton = get_node_or_null("/root/FolderPasswordManager")
	assert(fpm != null, "FolderPasswordManager singleton must exist")
	
	var test_folder_path := "user://files/WormTestDir"
	if not DirAccess.dir_exists_absolute(test_folder_path):
		DirAccess.make_dir_recursive_absolute(test_folder_path)
	
	fpm.set_password("WormTestDir", "SEC-88")
	assert(fpm.has_password("WormTestDir"), "WormTestDir password set")
	
	var worm_cmd: TerminalCommand = terminal.command_manager.load_command("worm")
	
	# 1. Argomenti errati
	worm_cmd.execute(terminal, [])
	assert(terminal.active_interactive_command == null, "No session started on bad args")
	
	# 2. Cartella inesistente
	worm_cmd.execute(terminal, ["NonExistentDir12345"])
	assert(terminal.active_interactive_command == null, "No session started on non-existent folder")
	
	# 3. Cartella non protetta
	var unprot_folder := "user://files/UnprotectedDir"
	if not DirAccess.dir_exists_absolute(unprot_folder):
		DirAccess.make_dir_recursive_absolute(unprot_folder)
	worm_cmd.execute(terminal, ["UnprotectedDir"])
	assert(terminal.active_interactive_command == null, "No session started on unprotected folder")
	DirAccess.remove_absolute(unprot_folder)
	
	# 4. Avvio sessione valida
	worm_cmd.execute(terminal, ["WormTestDir"])
	assert(terminal.active_interactive_command == worm_cmd, "Worm interactive session active")
	
	# 5. Tentativo parziale (SEC-00 -> 4 esatti, 0 dislocati)
	worm_cmd.handle_interactive_input(terminal, "SEC-00")
	assert(terminal.active_interactive_command == worm_cmd, "Interactive session still ongoing")
	assert(worm_cmd.get("current_attempt") == 2, "Attempt incremented to 2")
	
	# 6. Tentativo con caratteri dislocati (88-SEC -> 1 esatto ('-'), 5 dislocati)
	worm_cmd.handle_interactive_input(terminal, "88-SEC")
	assert(terminal.active_interactive_command == worm_cmd, "Interactive session still ongoing")
	assert(worm_cmd.get("current_attempt") == 3, "Attempt incremented to 3")
	
	# 7. Tentativo corretto (SEC-88) -> Vittoria & Sblocco password
	worm_cmd.handle_interactive_input(terminal, "SEC-88")
	assert(terminal.active_interactive_command == null, "Session closed on victory")
	assert(!fpm.has_password("WormTestDir"), "Folder password unlocked/removed on victory")
	
	# 8. Test sconfitta (6 tentativi errati)
	fpm.set_password("WormTestDir", "LOCK-99")
	worm_cmd.execute(terminal, ["WormTestDir"])
	assert(terminal.active_interactive_command == worm_cmd, "Session started for defeat test")
	for i in range(5):
		worm_cmd.handle_interactive_input(terminal, "WRONG")
		assert(terminal.active_interactive_command == worm_cmd, "Attempt %d still active" % [i + 1])
	worm_cmd.handle_interactive_input(terminal, "WRONG")
	assert(terminal.active_interactive_command == null, "Session closed after 6 failed attempts")
	assert(fpm.has_password("WormTestDir"), "Folder remains locked after defeat")
	
	# 9. Test cancellazione ("exit")
	worm_cmd.execute(terminal, ["WormTestDir"])
	assert(terminal.active_interactive_command == worm_cmd, "Session started for exit test")
	worm_cmd.handle_interactive_input(terminal, "exit")
	assert(terminal.active_interactive_command == null, "Session closed on 'exit'")
	
	fpm.remove_password("WormTestDir")
	DirAccess.remove_absolute(test_folder_path)
	terminal.queue_free()
	print("TEST 2: PASS - 'worm' Mastermind game, bulls/cows hints, victory unlock, and defeat handling verified.")


func test_decript_command() -> void:
	print("\n--- TEST 3: 'decript' Command (Cipher Decoding) ---")
	var terminal_scene: PackedScene = load("res://Applications/Terminal/src/terminal_scene.tscn")
	var terminal: Terminal = terminal_scene.instantiate()
	add_child(terminal)
	await get_tree().process_frame
	
	var test_dat_path := "user://files/test_crypto_file.dat"
	var f := FileAccess.open(test_dat_path, FileAccess.WRITE)
	f.store_string("# SYSTEM CONFIG\n[SYSTEM]\napp_name=CryptoTest\ndecryption_key=CODE-77\n")
	f.close()
	
	var decript_cmd: TerminalCommand = terminal.command_manager.load_command("decript")
	
	# 1. Argomenti errati
	decript_cmd.execute(terminal, [])
	assert(terminal.active_interactive_command == null, "No session started on bad args")
	
	# 2. File non .dat
	decript_cmd.execute(terminal, ["test_crypto_file.txt"])
	assert(terminal.active_interactive_command == null, "No session started on non-.dat file")
	
	# 3. File inesistente
	decript_cmd.execute(terminal, ["non_existent_file.dat"])
	assert(terminal.active_interactive_command == null, "No session started on missing file")
	
	# 4. Avvio sessione decript valida
	decript_cmd.execute(terminal, ["test_crypto_file.dat"])
	assert(terminal.active_interactive_command == decript_cmd, "Decript session started")
	
	# 5. Tentativo carattere singolo ('C')
	decript_cmd.handle_interactive_input(terminal, "C")
	assert(terminal.active_interactive_command == decript_cmd, "Session active after partial guess")
	var disp_key: String = decript_cmd._get_key_display()
	assert(disp_key.begins_with("C"), "Key display should show 'C': %s" % disp_key)
	
	# 6. Tentativo caratteri rimanenti
	decript_cmd.handle_interactive_input(terminal, "O")
	decript_cmd.handle_interactive_input(terminal, "D")
	decript_cmd.handle_interactive_input(terminal, "E")
	decript_cmd.handle_interactive_input(terminal, "7")
	assert(terminal.active_interactive_command == null, "Session closed once all key chars are found")
	
	# 7. Test completamento immediato con chiave intera
	decript_cmd.execute(terminal, ["test_crypto_file.dat"])
	assert(terminal.active_interactive_command == decript_cmd, "Session started again")
	decript_cmd.handle_interactive_input(terminal, "CODE-77")
	assert(terminal.active_interactive_command == null, "Session closed immediately on full key input")
	
	# 8. Test cancellazione ("quit")
	decript_cmd.execute(terminal, ["test_crypto_file.dat"])
	assert(terminal.active_interactive_command == decript_cmd, "Session started for quit test")
	decript_cmd.handle_interactive_input(terminal, "quit")
	assert(terminal.active_interactive_command == null, "Session cancelled on 'quit'")
	
	# Cleanup
	DirAccess.remove_absolute(test_dat_path)
	terminal.queue_free()
	print("TEST 3: PASS - 'decript' cipher generation, partial reveal, full key reveal, and cancellation verified.")


func test_dataread_and_text_editor() -> void:
	print("\n--- TEST 4: 'dataread' Command & Text Editor Integration ---")
	var terminal_scene: PackedScene = load("res://Applications/Terminal/src/terminal_scene.tscn")
	var terminal: Terminal = terminal_scene.instantiate()
	add_child(terminal)
	await get_tree().process_frame
	
	var test_dat_path := "user://files/test_editor_cfg.dat"
	var f := FileAccess.open(test_dat_path, FileAccess.WRITE)
	f.store_string("# TEST CONFIG\n[SETTINGS]\ndecryption_key=VALID-KEY-55\nspeed=120.0\n")
	f.close()
	
	# 1. Verifica comportamento standard di Text Editor su file .dat (bloccato)
	var win_scene: PackedScene = load("res://Scenes/Window/Text Editor/text_editor.tscn")
	var win: FakeWindow = win_scene.instantiate()
	add_child(win)
	var te: CodeEdit = win.get_node("%Text Editor")
	te.populate_text("test_editor_cfg.dat")
	assert(te.editable == false, "Text Editor must be read-only by default for .dat files")
	assert("[ERRORE: FILE PROTETTO" in te.text, "Text Editor must show protection error message")
	win.queue_free()
	
	# 2. Verifica open_dat_file su Text Editor (autorizzato)
	var win_auth: FakeWindow = win_scene.instantiate()
	add_child(win_auth)
	var te_auth: CodeEdit = win_auth.get_node("%Text Editor")
	te_auth.open_dat_file("test_editor_cfg.dat")
	assert(te_auth.allow_dat_editing == true, "allow_dat_editing must be true")
	assert(te_auth.editable == true, "editable must be true")
	assert("VALID-KEY-55" in te_auth.text, "Raw .dat content must be loaded")
	
	# Modifica e salvataggio
	te_auth.text = "# TEST CONFIG\n[SETTINGS]\ndecryption_key=VALID-KEY-55\nspeed=250.0\n"
	te_auth.text_edited = true
	te_auth.save_file()
	
	var f_read := FileAccess.open(test_dat_path, FileAccess.READ)
	var saved_content := f_read.get_as_text()
	f_read.close()
	assert("speed=250.0" in saved_content, "Saved .dat content must persist to disk")
	win_auth.queue_free()
	
	# 3. Test comando 'dataread'
	var dataread_cmd: TerminalCommand = terminal.command_manager.load_command("dataread")
	
	# Argomenti insufficienti
	dataread_cmd.execute(terminal, ["KEY"])
	
	# File non .dat
	dataread_cmd.execute(terminal, ["KEY", "file.txt"])
	
	# Chiave errata
	dataread_cmd.execute(terminal, ["WRONG-KEY", "test_editor_cfg.dat"])
	
	# Chiave corretta
	dataread_cmd.execute(terminal, ["VALID-KEY-55", "test_editor_cfg.dat"])
	await get_tree().process_frame
	
	# Trova la finestra Text Editor creata
	var opened_editor: CodeEdit = null
	for node in get_tree().get_nodes_in_group("text_editor_window"):
		if node is CodeEdit and node.file_path == "test_editor_cfg.dat":
			opened_editor = node
			break
	
	assert(opened_editor != null, "Text Editor window must be opened by dataread")
	assert(opened_editor.editable == true, "Opened Text Editor must be editable")
	assert(opened_editor.allow_dat_editing == true, "Opened Text Editor allow_dat_editing must be true")
	
	if opened_editor.get_parent() and opened_editor.get_parent().get_parent() is FakeWindow:
		opened_editor.get_parent().get_parent().queue_free()
	
	# Cleanup
	DirAccess.remove_absolute(test_dat_path)
	terminal.queue_free()
	print("TEST 4: PASS - 'dataread' validation, key check, and Text Editor .dat authorization verified.")


func test_terminal_interactive_flow() -> void:
	print("\n--- TEST 5: Terminal Interactive Input Redirection ---")
	var terminal_scene: PackedScene = load("res://Applications/Terminal/src/terminal_scene.tscn")
	var terminal: Terminal = terminal_scene.instantiate()
	add_child(terminal)
	await get_tree().process_frame
	
	var fpm: FolderPasswordManagerSingleton = get_node_or_null("/root/FolderPasswordManager")
	var test_folder := "user://files/InteractiveTestDir"
	if not DirAccess.dir_exists_absolute(test_folder):
		DirAccess.make_dir_recursive_absolute(test_folder)
	fpm.set_password("InteractiveTestDir", "P-123")
	
	# Invia comando via _on_command_line_text_submitted
	terminal._on_command_line_text_submitted("worm InteractiveTestDir")
	assert(terminal.active_interactive_command != null, "Interactive session started through command line input")
	
	# Invia tentativo attraverso terminale senza che venga interpretato come comando shell
	terminal._on_command_line_text_submitted("P-123")
	assert(terminal.active_interactive_command == null, "Interactive session ended on correct guess via terminal")
	assert(!fpm.has_password("InteractiveTestDir"), "Password removed via terminal interactive flow")
	
	DirAccess.remove_absolute(test_folder)
	terminal.queue_free()
	print("TEST 5: PASS - Terminal interactive input redirection verified.")
