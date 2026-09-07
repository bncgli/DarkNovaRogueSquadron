extends GutTest

## Migrato dal vecchio test manuale tests/test_folder_password_node.gd
## Copre FolderPasswordManager, i dialoghi password, l'icona di lock su
## FakeFolder, l'integrazione col comando "cd" del terminale e le
## restrizioni su cartelle protette da password (copia/taglia/elimina/
## menu contestuale).

func after_each() -> void:
	for path in ["SecretFolder", "RenamedFolder", "CopiedFolder", "TestFolder", "LockedFolder", "TerminalTestDir", "ProtectedFolder"]:
		if FolderPasswordManager.has_password(path):
			FolderPasswordManager.remove_password(path)
	if DirAccess.dir_exists_absolute("user://files/TerminalTestDir"):
		DirAccess.remove_absolute("user://files/TerminalTestDir")
	if DirAccess.dir_exists_absolute("user://files/ProtectedFolder"):
		DirAccess.remove_absolute("user://files/ProtectedFolder")

func test_folder_password_manager_core_logic() -> void:
	var fpm := FolderPasswordManager
	assert_not_null(fpm, "FolderPasswordManager deve esistere")

	# Normalizzazione
	assert_eq(fpm.normalize_path("user://files/SecretFolder"), "SecretFolder", "normalize_path fallita")
	assert_eq(fpm.normalize_path("/SecretFolder/Sub/"), "SecretFolder/Sub", "normalize_path fallita")
	assert_eq(fpm.normalize_path("SecretFolder\\Sub"), "SecretFolder/Sub", "normalize_path fallita")

	# Set e verifica password
	fpm.set_password("SecretFolder", "my_pass_123")
	assert_true(fpm.has_password("SecretFolder"), "has_password deve essere true")
	assert_true(fpm.has_password("user://files/SecretFolder/"), "has_password con path completo deve essere true")
	assert_true(fpm.check_password("SecretFolder", "my_pass_123"), "check_password con password corretta deve restituire true")
	assert_false(fpm.check_password("SecretFolder", "wrong_pass"), "check_password con password errata deve restituire false")

	# Rinomina path
	fpm.rename_path("SecretFolder", "RenamedFolder")
	assert_false(fpm.has_password("SecretFolder"), "il vecchio path non deve avere la password")
	assert_true(fpm.has_password("RenamedFolder"), "il nuovo path deve avere la password")
	assert_true(fpm.check_password("RenamedFolder", "my_pass_123"), "la password deve corrispondere dopo la rinomina")

	# Copia path
	fpm.copy_path("RenamedFolder", "CopiedFolder")
	assert_true(fpm.has_password("CopiedFolder"), "il path copiato deve avere la password")
	assert_true(fpm.check_password("CopiedFolder", "my_pass_123"), "la password copiata deve corrispondere")

	# Rimozione password
	fpm.remove_password("RenamedFolder")
	assert_false(fpm.has_password("RenamedFolder"), "la password deve essere rimossa")

	# Eliminazione path
	fpm.delete_path("CopiedFolder")
	assert_false(fpm.has_password("CopiedFolder"), "la password deve essere eliminata")

func test_dialog_logic_and_signals() -> void:
	var set_dlg_scene: PackedScene = load("res://Scenes/Window/Password Dialog/set_password_dialog.tscn")
	assert_not_null(set_dlg_scene, "set_password_dialog.tscn deve caricarsi")
	var set_dlg: Node = set_dlg_scene.instantiate()
	set_dlg.setup("TestFolder", "TestFolder")
	add_child_autofree(set_dlg)

	var set_pwd_edit: LineEdit = set_dlg.get_node("%PasswordEdit")
	set_pwd_edit.text = "test_pass"
	set_dlg._on_ok_pressed()

	assert_true(FolderPasswordManager.has_password("TestFolder"), "La password deve essere impostata dopo OK")
	assert_true(FolderPasswordManager.check_password("TestFolder", "test_pass"), "La password deve corrispondere")

	# Test dialogo inserimento password - password sbagliata
	var enter_dlg_scene: PackedScene = load("res://Scenes/Window/Password Dialog/enter_password_dialog.tscn")
	assert_not_null(enter_dlg_scene, "enter_password_dialog.tscn deve caricarsi")
	var enter_dlg: Node = enter_dlg_scene.instantiate()
	var test_state := {
		"success_called": false,
		"removed_pass_val": false,
		"cancel_called": false
	}

	enter_dlg.setup("TestFolder", "TestFolder", func(rem: bool):
		test_state["success_called"] = true
		test_state["removed_pass_val"] = rem
	, func():
		test_state["cancel_called"] = true
	)
	add_child_autofree(enter_dlg)

	var enter_pwd_edit: LineEdit = enter_dlg.get_node("%PasswordEdit")
	enter_pwd_edit.text = "wrong_pass"
	enter_dlg._on_ok_pressed()
	assert_false(test_state["success_called"], "Il callback di successo NON deve essere chiamato con password errata")
	assert_eq(enter_dlg.get_node("%ErrorLabel").text, "Password errata!", "L'etichetta di errore deve indicare la password errata")

	# Test dialogo inserimento password - password corretta + OK
	enter_pwd_edit.text = "test_pass"
	enter_dlg._on_ok_pressed()
	assert_true(test_state["success_called"], "Il callback di successo deve essere chiamato con password corretta")
	assert_false(test_state["removed_pass_val"], "il flag remove_password deve essere false su OK")
	assert_true(FolderPasswordManager.has_password("TestFolder"), "La password deve esistere ancora dopo OK")

	# Test dialogo inserimento password - OK e rimuovi password
	var enter_dlg2: Node = enter_dlg_scene.instantiate()
	var test_state2 := {
		"success_called": false,
		"removed_pass_val": false
	}
	enter_dlg2.setup("TestFolder", "TestFolder", func(rem: bool):
		test_state2["success_called"] = true
		test_state2["removed_pass_val"] = rem
	)
	add_child_autofree(enter_dlg2)
	var enter_pwd_edit2: LineEdit = enter_dlg2.get_node("%PasswordEdit")
	enter_pwd_edit2.text = "test_pass"
	enter_dlg2._on_ok_remove_pressed()
	assert_true(test_state2["success_called"], "Il callback di successo deve essere chiamato su OK e rimuovi")
	assert_true(test_state2["removed_pass_val"], "il flag remove_password deve essere true su OK e rimuovi")
	assert_false(FolderPasswordManager.has_password("TestFolder"), "La password deve essere rimossa dal manager")

	# Test dialogo inserimento password - Annulla
	var enter_dlg3: Node = enter_dlg_scene.instantiate()
	var test_state3 := {
		"success_called": false,
		"cancel_called": false
	}
	enter_dlg3.setup("TestFolder", "TestFolder", func(_r: bool):
		test_state3["success_called"] = true
	, func():
		test_state3["cancel_called"] = true
	)
	add_child_autofree(enter_dlg3)
	enter_dlg3._on_cancel_pressed()
	assert_false(test_state3["success_called"], "Il successo non deve essere chiamato su annulla")
	assert_true(test_state3["cancel_called"], "Il callback di annullamento deve essere chiamato su annulla")

func test_folder_node_lock_icon_updates() -> void:
	var folder_scene: PackedScene = load("res://Scenes/Desktop/folder.tscn")
	var folder_node: FakeFolder = folder_scene.instantiate()
	folder_node.folder_name = "LockedFolder"
	folder_node.folder_path = "LockedFolder"
	folder_node.file_type = GlobalValues.FileType.FOLDER
	add_child_autofree(folder_node)

	# Inizialmente nessuna password
	assert_false(folder_node.get_node("%LockIcon").visible, "LockIcon deve essere nascosta inizialmente")

	# Impostazione password -> l'icona di lock diventa visibile
	FolderPasswordManager.set_password("LockedFolder", "secret123")
	assert_true(folder_node.get_node("%LockIcon").visible, "LockIcon deve diventare visibile dopo l'impostazione della password")

	# Rimozione password -> l'icona di lock diventa nascosta
	FolderPasswordManager.remove_password("LockedFolder")
	assert_false(folder_node.get_node("%LockIcon").visible, "LockIcon deve diventare nascosta dopo la rimozione della password")

func test_terminal_cd_command_with_password() -> void:
	# Assicura che la cartella di test esista su disco in user://files/
	DirAccess.make_dir_absolute("user://files/TerminalTestDir")
	FolderPasswordManager.set_password("TerminalTestDir", "term_pass")

	var terminal_scene: PackedScene = load("res://Applications/Terminal/src/terminal_scene.tscn")
	var terminal: Node = terminal_scene.instantiate()
	add_child_autofree(terminal)

	# Esegue il comando cd
	var cd_cmd_script: GDScript = load("res://Applications/Terminal/commands/cd_command.gd")
	var cd_cmd = cd_cmd_script.new()
	var args: Array[String] = ["TerminalTestDir"]
	cd_cmd.execute(terminal, args)

	# Il terminale deve aver aperto il dialogo invece di cambiare subito il path
	assert_ne(terminal.virtual_path_manager.get_path(), "TerminalTestDir", "Il path non deve cambiare prima dell'inserimento della password")

func test_restrictions_on_password_protected_folders() -> void:
	var folder_scene: PackedScene = load("res://Scenes/Desktop/folder.tscn")
	var protected_folder: FakeFolder = folder_scene.instantiate()
	protected_folder.folder_name = "ProtectedFolder"
	protected_folder.folder_path = "ProtectedFolder"
	protected_folder.file_type = GlobalValues.FileType.FOLDER
	add_child_autofree(protected_folder)

	DirAccess.make_dir_absolute("user://files/ProtectedFolder")
	FolderPasswordManager.set_password("ProtectedFolder", "secure_pwd")

	# Test 1: restrizione copia
	CopyPasteManager.target_folder_name = ""
	CopyPasteManager.target_folder = null
	CopyPasteManager.copy_folder(protected_folder)
	assert_true(CopyPasteManager.target_folder_name.is_empty(), "La cartella protetta non deve poter essere copiata")

	# Test 2: restrizione taglia
	CopyPasteManager.target_folder_name = ""
	CopyPasteManager.target_folder = null
	CopyPasteManager.cut_folder(protected_folder)
	assert_true(CopyPasteManager.target_folder_name.is_empty(), "La cartella protetta non deve poter essere tagliata")

	# Test 3: restrizione eliminazione
	protected_folder.delete_file()
	assert_true(DirAccess.dir_exists_absolute("user://files/ProtectedFolder"), "La cartella protetta non deve poter essere eliminata")

	# Test 4: non si può aggiungere un'altra password
	var set_dlg_scene: PackedScene = load("res://Scenes/Window/Password Dialog/set_password_dialog.tscn")
	var set_dlg: Node = set_dlg_scene.instantiate()
	set_dlg.setup("ProtectedFolder", "ProtectedFolder")
	add_child_autofree(set_dlg)
	set_dlg.get_node("%PasswordEdit").text = "another_password"
	set_dlg._on_ok_pressed()
	assert_true(FolderPasswordManager.check_password("ProtectedFolder", "secure_pwd"), "La vecchia password deve rimanere invariata")
	assert_false(FolderPasswordManager.check_password("ProtectedFolder", "another_password"), "La nuova password NON deve essere applicata")

	# Test 5: opzioni del menu contestuale
	var context_menu_scene: PackedScene = load("res://Scenes/Autoloads/Context Menu/context_menu.tscn")
	var context_menu: Node = context_menu_scene.instantiate()
	add_child_autofree(context_menu)
	context_menu.target = protected_folder
	context_menu.add_folder_options()

	var option_texts: Array[String] = []
	for child in context_menu.get_node("VBoxContainer").get_children():
		var opt_text_node: Node = child.get_node_or_null("%Option Text")
		if opt_text_node:
			option_texts.append(opt_text_node.text)

	assert_false(option_texts.has("Copy Folder"), "Copy Folder non deve essere nel menu contestuale")
	assert_false(option_texts.has("Cut Folder"), "Cut Folder non deve essere nel menu contestuale")
	assert_false(option_texts.has("Move to trash"), "Move to trash non deve essere nel menu contestuale")
	assert_false(option_texts.has("Aggiungi password"), "Aggiungi password non deve essere nel menu contestuale")
