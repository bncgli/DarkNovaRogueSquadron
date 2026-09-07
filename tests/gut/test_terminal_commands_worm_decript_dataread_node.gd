extends GutTest

## Migrato dal vecchio test manuale
## tests/test_terminal_commands_worm_decript_dataread_node.gd
## Copre la registrazione dei comandi terminale "worm", "decript" e
## "dataread", la meccanica interattiva di ciascuno, l'integrazione con il
## Text Editor per i file .dat, e il flusso interattivo tramite la command
## line del terminale.

func test_command_registration() -> void:
	var cmd_manager := TerminalCommandManager.new()

	assert_true(cmd_manager.cmd_exists("worm"), "il comando worm deve essere registrato!")
	assert_true(cmd_manager.cmd_exists("decript"), "il comando decript deve essere registrato!")
	assert_true(cmd_manager.cmd_exists("dataread"), "il comando dataread deve essere registrato!")

	var worm_cmd: TerminalCommand = cmd_manager.load_command("worm")
	assert_not_null(worm_cmd, "l'istanza del comando worm deve essere valida")
	assert_eq(worm_cmd.call_name, "worm", "il call_name del comando worm deve essere 'worm'")
	assert_gt(worm_cmd.usage().size(), 0, "usage() di worm deve essere definita")

	var decript_cmd: TerminalCommand = cmd_manager.load_command("decript")
	assert_not_null(decript_cmd, "l'istanza del comando decript deve essere valida")
	assert_eq(decript_cmd.call_name, "decript", "il call_name del comando decript deve essere 'decript'")
	assert_gt(decript_cmd.usage().size(), 0, "usage() di decript deve essere definita")

	var dataread_cmd: TerminalCommand = cmd_manager.load_command("dataread")
	assert_not_null(dataread_cmd, "l'istanza del comando dataread deve essere valida")
	assert_eq(dataread_cmd.call_name, "dataread", "il call_name del comando dataread deve essere 'dataread'")
	assert_gt(dataread_cmd.usage().size(), 0, "usage() di dataread deve essere definita")

func test_worm_command() -> void:
	var terminal_scene: PackedScene = load("res://Applications/Terminal/src/terminal_scene.tscn")
	var terminal: Terminal = terminal_scene.instantiate()
	add_child_autofree(terminal)
	await get_tree().process_frame

	var fpm: FolderPasswordManagerSingleton = get_node_or_null("/root/FolderPasswordManager")
	assert_not_null(fpm, "il singleton FolderPasswordManager deve esistere")

	var test_folder_path := "user://files/WormTestDir"
	if not DirAccess.dir_exists_absolute(test_folder_path):
		DirAccess.make_dir_recursive_absolute(test_folder_path)

	fpm.set_password("WormTestDir", "SEC-88")
	assert_true(fpm.has_password("WormTestDir"), "la password di WormTestDir deve essere impostata")

	var worm_cmd: TerminalCommand = terminal.command_manager.load_command("worm")

	# 1. Argomenti errati
	worm_cmd.execute(terminal, [])
	assert_null(terminal.active_interactive_command, "nessuna sessione avviata con argomenti errati")

	# 2. Cartella inesistente
	worm_cmd.execute(terminal, ["NonExistentDir12345"])
	assert_null(terminal.active_interactive_command, "nessuna sessione avviata su cartella inesistente")

	# 3. Cartella non protetta
	var unprot_folder := "user://files/UnprotectedDir"
	if not DirAccess.dir_exists_absolute(unprot_folder):
		DirAccess.make_dir_recursive_absolute(unprot_folder)
	worm_cmd.execute(terminal, ["UnprotectedDir"])
	assert_null(terminal.active_interactive_command, "nessuna sessione avviata su cartella non protetta")
	DirAccess.remove_absolute(unprot_folder)

	# 4. Avvio sessione valida
	worm_cmd.execute(terminal, ["WormTestDir"])
	assert_eq(terminal.active_interactive_command, worm_cmd, "sessione interattiva worm attiva")

	# 5. Tentativo parziale (SEC-00 -> 4 esatti, 0 dislocati)
	worm_cmd.handle_interactive_input(terminal, "SEC-00")
	assert_eq(terminal.active_interactive_command, worm_cmd, "la sessione interattiva è ancora in corso")
	assert_eq(worm_cmd.get("current_attempt"), 2, "il tentativo deve essere incrementato a 2")

	# 6. Tentativo con caratteri dislocati (88-SEC -> 1 esatto ('-'), 5 dislocati)
	worm_cmd.handle_interactive_input(terminal, "88-SEC")
	assert_eq(terminal.active_interactive_command, worm_cmd, "la sessione interattiva è ancora in corso")
	assert_eq(worm_cmd.get("current_attempt"), 3, "il tentativo deve essere incrementato a 3")

	# 7. Tentativo corretto (SEC-88) -> Vittoria & Sblocco password
	worm_cmd.handle_interactive_input(terminal, "SEC-88")
	assert_null(terminal.active_interactive_command, "la sessione si chiude alla vittoria")
	assert_false(fpm.has_password("WormTestDir"), "la password della cartella deve essere rimossa alla vittoria")

	# 8. Test sconfitta (6 tentativi errati)
	fpm.set_password("WormTestDir", "LOCK-99")
	worm_cmd.execute(terminal, ["WormTestDir"])
	assert_eq(terminal.active_interactive_command, worm_cmd, "sessione avviata per il test di sconfitta")
	for i in range(5):
		worm_cmd.handle_interactive_input(terminal, "WRONG")
		assert_eq(terminal.active_interactive_command, worm_cmd, "il tentativo %d deve essere ancora attivo" % [i + 1])
	worm_cmd.handle_interactive_input(terminal, "WRONG")
	assert_null(terminal.active_interactive_command, "la sessione si chiude dopo 6 tentativi falliti")
	assert_true(fpm.has_password("WormTestDir"), "la cartella rimane bloccata dopo la sconfitta")

	# 9. Test cancellazione ("exit")
	worm_cmd.execute(terminal, ["WormTestDir"])
	assert_eq(terminal.active_interactive_command, worm_cmd, "sessione avviata per il test di uscita")
	worm_cmd.handle_interactive_input(terminal, "exit")
	assert_null(terminal.active_interactive_command, "la sessione si chiude su 'exit'")

	fpm.remove_password("WormTestDir")
	DirAccess.remove_absolute(test_folder_path)

func test_decript_command() -> void:
	var terminal_scene: PackedScene = load("res://Applications/Terminal/src/terminal_scene.tscn")
	var terminal: Terminal = terminal_scene.instantiate()
	add_child_autofree(terminal)
	await get_tree().process_frame

	var test_dat_path := "user://files/test_crypto_file.dat"
	var f := FileAccess.open(test_dat_path, FileAccess.WRITE)
	f.store_string("# SYSTEM CONFIG\n[SYSTEM]\napp_name=CryptoTest\ndecryption_key=CODE-77\n")
	f.close()

	var decript_cmd: TerminalCommand = terminal.command_manager.load_command("decript")

	# 1. Argomenti errati
	decript_cmd.execute(terminal, [])
	assert_null(terminal.active_interactive_command, "nessuna sessione avviata con argomenti errati")

	# 2. File non .dat
	decript_cmd.execute(terminal, ["test_crypto_file.txt"])
	assert_null(terminal.active_interactive_command, "nessuna sessione avviata su file non .dat")

	# 3. File inesistente
	decript_cmd.execute(terminal, ["non_existent_file.dat"])
	assert_null(terminal.active_interactive_command, "nessuna sessione avviata su file mancante")

	# 4. Avvio sessione decript valida
	decript_cmd.execute(terminal, ["test_crypto_file.dat"])
	assert_eq(terminal.active_interactive_command, decript_cmd, "sessione decript avviata")

	# 5. Tentativo carattere singolo ('C')
	decript_cmd.handle_interactive_input(terminal, "C")
	assert_eq(terminal.active_interactive_command, decript_cmd, "sessione attiva dopo tentativo parziale")
	var disp_key: String = decript_cmd._get_key_display()
	assert_true(disp_key.begins_with("C"), "il display della chiave deve mostrare 'C': %s" % disp_key)

	# 6. Tentativo caratteri rimanenti
	decript_cmd.handle_interactive_input(terminal, "O")
	decript_cmd.handle_interactive_input(terminal, "D")
	decript_cmd.handle_interactive_input(terminal, "E")
	decript_cmd.handle_interactive_input(terminal, "7")
	assert_null(terminal.active_interactive_command, "la sessione si chiude quando tutti i caratteri della chiave sono trovati")

	# 7. Test completamento immediato con chiave intera
	decript_cmd.execute(terminal, ["test_crypto_file.dat"])
	assert_eq(terminal.active_interactive_command, decript_cmd, "sessione riavviata")
	decript_cmd.handle_interactive_input(terminal, "CODE-77")
	assert_null(terminal.active_interactive_command, "la sessione si chiude immediatamente con la chiave intera")

	# 8. Test cancellazione ("quit")
	decript_cmd.execute(terminal, ["test_crypto_file.dat"])
	assert_eq(terminal.active_interactive_command, decript_cmd, "sessione avviata per il test di quit")
	decript_cmd.handle_interactive_input(terminal, "quit")
	assert_null(terminal.active_interactive_command, "la sessione è annullata su 'quit'")

	# Cleanup
	DirAccess.remove_absolute(test_dat_path)

func test_dataread_and_text_editor() -> void:
	var terminal_scene: PackedScene = load("res://Applications/Terminal/src/terminal_scene.tscn")
	var terminal: Terminal = terminal_scene.instantiate()
	add_child_autofree(terminal)
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
	assert_false(te.editable, "Text Editor deve essere di sola lettura di default per i file .dat")
	assert_true("[ERRORE: FILE PROTETTO" in te.text, "Text Editor deve mostrare il messaggio di protezione")
	win.queue_free()
	await get_tree().process_frame

	# 2. Verifica open_dat_file su Text Editor (autorizzato)
	var win_auth: FakeWindow = win_scene.instantiate()
	add_child(win_auth)
	var te_auth: CodeEdit = win_auth.get_node("%Text Editor")
	te_auth.open_dat_file("test_editor_cfg.dat")
	assert_true(te_auth.allow_dat_editing, "allow_dat_editing deve essere true")
	assert_true(te_auth.editable, "editable deve essere true")
	assert_true("VALID-KEY-55" in te_auth.text, "il contenuto grezzo del .dat deve essere caricato")

	# Modifica e salvataggio
	te_auth.text = "# TEST CONFIG\n[SETTINGS]\ndecryption_key=VALID-KEY-55\nspeed=250.0\n"
	te_auth.text_edited = true
	te_auth.save_file()

	var f_read := FileAccess.open(test_dat_path, FileAccess.READ)
	var saved_content := f_read.get_as_text()
	f_read.close()
	assert_true("speed=250.0" in saved_content, "il contenuto .dat salvato deve persistere su disco")
	win_auth.queue_free()
	await get_tree().process_frame

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

	assert_not_null(opened_editor, "la finestra Text Editor deve essere aperta da dataread")
	assert_true(opened_editor.editable, "il Text Editor aperto deve essere editabile")
	assert_true(opened_editor.allow_dat_editing, "allow_dat_editing del Text Editor aperto deve essere true")

	if opened_editor and opened_editor.get_parent() and opened_editor.get_parent().get_parent() is FakeWindow:
		autofree(opened_editor.get_parent().get_parent())

	# Cleanup
	DirAccess.remove_absolute(test_dat_path)

func test_terminal_interactive_flow() -> void:
	var terminal_scene: PackedScene = load("res://Applications/Terminal/src/terminal_scene.tscn")
	var terminal: Terminal = terminal_scene.instantiate()
	add_child_autofree(terminal)
	await get_tree().process_frame

	var fpm: FolderPasswordManagerSingleton = get_node_or_null("/root/FolderPasswordManager")
	var test_folder := "user://files/InteractiveTestDir"
	if not DirAccess.dir_exists_absolute(test_folder):
		DirAccess.make_dir_recursive_absolute(test_folder)
	fpm.set_password("InteractiveTestDir", "P-123")

	# Invia comando via _on_command_line_text_submitted
	terminal._on_command_line_text_submitted("worm InteractiveTestDir")
	assert_not_null(terminal.active_interactive_command, "sessione interattiva avviata tramite input da command line")

	# Invia tentativo attraverso terminale senza che venga interpretato come comando shell
	terminal._on_command_line_text_submitted("P-123")
	assert_null(terminal.active_interactive_command, "sessione interattiva terminata al tentativo corretto via terminale")
	assert_false(fpm.has_password("InteractiveTestDir"), "password rimossa tramite il flusso interattivo del terminale")

	DirAccess.remove_absolute(test_folder)
