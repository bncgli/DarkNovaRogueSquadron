extends Node

func _ready() -> void:
	print("--- Starting Folder Password Tests ---")
	test_folder_password_manager()
	test_dialog_logic()
	test_folder_node_lock_and_open()
	test_terminal_cd_with_password()
	test_restrictions_on_password_protected_folders()
	print("--- All tests passed successfully! ---")
	get_tree().quit(0)

func test_folder_password_manager() -> void:
	print("1. Testing FolderPasswordManager basic logic...")
	var fpm = FolderPasswordManager
	assert(fpm != null, "FolderPasswordManager must exist")
	
	# Normalization
	assert(fpm.normalize_path("user://files/SecretFolder") == "SecretFolder", "normalize failed")
	assert(fpm.normalize_path("/SecretFolder/Sub/") == "SecretFolder/Sub", "normalize failed")
	assert(fpm.normalize_path("SecretFolder\\Sub") == "SecretFolder/Sub", "normalize failed")
	
	# Set and Check password
	fpm.set_password("SecretFolder", "my_pass_123")
	assert(fpm.has_password("SecretFolder"), "has_password should be true")
	assert(fpm.has_password("user://files/SecretFolder/"), "has_password with full path should be true")
	assert(fpm.check_password("SecretFolder", "my_pass_123"), "check_password with correct pass should return true")
	assert(!fpm.check_password("SecretFolder", "wrong_pass"), "check_password with wrong pass should return false")
	
	# Rename path
	fpm.rename_path("SecretFolder", "RenamedFolder")
	assert(!fpm.has_password("SecretFolder"), "old path should not have password")
	assert(fpm.has_password("RenamedFolder"), "new path should have password")
	assert(fpm.check_password("RenamedFolder", "my_pass_123"), "password should match after rename")
	
	# Copy path
	fpm.copy_path("RenamedFolder", "CopiedFolder")
	assert(fpm.has_password("CopiedFolder"), "copied path should have password")
	assert(fpm.check_password("CopiedFolder", "my_pass_123"), "copied password should match")
	
	# Remove password
	fpm.remove_password("RenamedFolder")
	assert(!fpm.has_password("RenamedFolder"), "password should be removed")
	
	# Delete path
	fpm.delete_path("CopiedFolder")
	assert(!fpm.has_password("CopiedFolder"), "password should be deleted")
	print("   FolderPasswordManager core logic: PASS")

func test_dialog_logic() -> void:
	print("2. Testing Dialog Scenes instantiation and signals...")
	var set_dlg_scene = load("res://Scenes/Window/Password Dialog/set_password_dialog.tscn")
	assert(set_dlg_scene != null, "set_password_dialog.tscn should load")
	var set_dlg = set_dlg_scene.instantiate()
	set_dlg.setup("TestFolder", "TestFolder")
	add_child(set_dlg)
	
	var set_pwd_edit = set_dlg.get_node("%PasswordEdit")
	set_pwd_edit.text = "test_pass"
	set_dlg._on_ok_pressed()
	
	assert(FolderPasswordManager.has_password("TestFolder"), "Password should be set after OK")
	assert(FolderPasswordManager.check_password("TestFolder", "test_pass"), "Password should match")
	
	# Test enter password dialog - wrong pass
	var enter_dlg_scene = load("res://Scenes/Window/Password Dialog/enter_password_dialog.tscn")
	assert(enter_dlg_scene != null, "enter_password_dialog.tscn should load")
	var enter_dlg = enter_dlg_scene.instantiate()
	var test_state = {
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
	add_child(enter_dlg)
	
	var enter_pwd_edit = enter_dlg.get_node("%PasswordEdit")
	enter_pwd_edit.text = "wrong_pass"
	enter_dlg._on_ok_pressed()
	assert(!test_state["success_called"], "Success callback must NOT be called on wrong pass")
	assert(enter_dlg.get_node("%ErrorLabel").text == "Password errata!", "Error label should indicate wrong password")
	
	# Test enter password dialog - right pass + OK
	enter_pwd_edit.text = "test_pass"
	enter_dlg._on_ok_pressed()
	assert(test_state["success_called"], "Success callback must be called on right pass")
	assert(!test_state["removed_pass_val"], "remove_password flag should be false on OK")
	assert(FolderPasswordManager.has_password("TestFolder"), "Password should still exist after OK")
	
	# Test enter password dialog - OK e rimuovi password
	var enter_dlg2 = enter_dlg_scene.instantiate()
	var test_state2 = {
		"success_called": false,
		"removed_pass_val": false
	}
	enter_dlg2.setup("TestFolder", "TestFolder", func(rem: bool):
		test_state2["success_called"] = true
		test_state2["removed_pass_val"] = rem
	)
	add_child(enter_dlg2)
	var enter_pwd_edit2 = enter_dlg2.get_node("%PasswordEdit")
	enter_pwd_edit2.text = "test_pass"
	enter_dlg2._on_ok_remove_pressed()
	assert(test_state2["success_called"], "Success callback must be called on OK e rimuovi")
	assert(test_state2["removed_pass_val"], "remove_password flag should be true on OK e rimuovi")
	assert(!FolderPasswordManager.has_password("TestFolder"), "Password should be removed from manager")
	
	# Test enter password dialog - Annulla
	var enter_dlg3 = enter_dlg_scene.instantiate()
	var test_state3 = {
		"success_called": false,
		"cancel_called": false
	}
	enter_dlg3.setup("TestFolder", "TestFolder", func(_r: bool):
		test_state3["success_called"] = true
	, func():
		test_state3["cancel_called"] = true
	)
	add_child(enter_dlg3)
	enter_dlg3._on_cancel_pressed()
	assert(!test_state3["success_called"], "Success must not be called on cancel")
	assert(test_state3["cancel_called"], "Cancel callback must be called on cancel")
	
	print("   Dialog logic and callbacks: PASS")

func test_folder_node_lock_and_open() -> void:
	print("3. Testing FakeFolder node lock icon and open...")
	var folder_scene = load("res://Scenes/Desktop/folder.tscn")
	var folder_node: FakeFolder = folder_scene.instantiate()
	folder_node.folder_name = "LockedFolder"
	folder_node.folder_path = "LockedFolder"
	folder_node.file_type = GlobalValues.FileType.FOLDER
	add_child(folder_node)
	
	# Initially no password
	assert(!folder_node.get_node("%LockIcon").visible, "LockIcon should be hidden initially")
	
	# Set password -> lock icon becomes visible
	FolderPasswordManager.set_password("LockedFolder", "secret123")
	assert(folder_node.get_node("%LockIcon").visible, "LockIcon should become visible after setting password")
	
	# Remove password -> lock icon becomes hidden
	FolderPasswordManager.remove_password("LockedFolder")
	assert(!folder_node.get_node("%LockIcon").visible, "LockIcon should become hidden after removing password")
	
	print("   FakeFolder lock icon updates: PASS")

func test_terminal_cd_with_password() -> void:
	print("4. Testing Terminal cd command integration...")
	# Ensure test folder exists on disk in user://files/
	DirAccess.make_dir_absolute("user://files/TerminalTestDir")
	FolderPasswordManager.set_password("TerminalTestDir", "term_pass")
	
	var terminal_scene = load("res://Applications/Terminal/src/terminal_scene.tscn")
	var terminal = terminal_scene.instantiate()
	add_child(terminal)
	
	# Execute cd command
	var cd_cmd = load("res://Applications/Terminal/commands/cd_command.gd").new()
	var args: Array[String] = ["TerminalTestDir"]
	cd_cmd.execute(terminal, args)
	
	# Terminal should have spawned the dialog rather than changing path immediately
	assert(terminal.virtual_path_manager.get_path() != "TerminalTestDir", "Path should not change before password entered")
	
	# Clean up
	FolderPasswordManager.remove_password("TerminalTestDir")
	DirAccess.remove_absolute("user://files/TerminalTestDir")
	print("   Terminal cd integration: PASS")

func test_restrictions_on_password_protected_folders() -> void:
	print("5. Testing Restrictions (Cannot copy, cut, delete, or add another password)...")
	var folder_scene = load("res://Scenes/Desktop/folder.tscn")
	var protected_folder: FakeFolder = folder_scene.instantiate()
	protected_folder.folder_name = "ProtectedFolder"
	protected_folder.folder_path = "ProtectedFolder"
	protected_folder.file_type = GlobalValues.FileType.FOLDER
	add_child(protected_folder)
	
	DirAccess.make_dir_absolute("user://files/ProtectedFolder")
	FolderPasswordManager.set_password("ProtectedFolder", "secure_pwd")
	
	# Test 1: Copy restriction
	CopyPasteManager.target_folder_name = ""
	CopyPasteManager.target_folder = null
	CopyPasteManager.copy_folder(protected_folder)
	assert(CopyPasteManager.target_folder_name.is_empty(), "Protected folder must NOT be copied")
	
	# Test 2: Cut restriction
	CopyPasteManager.target_folder_name = ""
	CopyPasteManager.target_folder = null
	CopyPasteManager.cut_folder(protected_folder)
	assert(CopyPasteManager.target_folder_name.is_empty(), "Protected folder must NOT be cut")
	
	# Test 3: Delete restriction
	protected_folder.delete_file()
	assert(DirAccess.dir_exists_absolute("user://files/ProtectedFolder"), "Protected folder must NOT be deleted")
	
	# Test 4: Cannot add another password
	var set_dlg_scene = load("res://Scenes/Window/Password Dialog/set_password_dialog.tscn")
	var set_dlg = set_dlg_scene.instantiate()
	set_dlg.setup("ProtectedFolder", "ProtectedFolder")
	add_child(set_dlg)
	set_dlg.get_node("%PasswordEdit").text = "another_password"
	set_dlg._on_ok_pressed()
	assert(FolderPasswordManager.check_password("ProtectedFolder", "secure_pwd"), "Old password must remain unchanged")
	assert(!FolderPasswordManager.check_password("ProtectedFolder", "another_password"), "New password must NOT be applied")
	
	# Test 5: Context menu options
	var context_menu_scene = load("res://Scenes/Autoloads/Context Menu/context_menu.tscn")
	var context_menu = context_menu_scene.instantiate()
	add_child(context_menu)
	context_menu.target = protected_folder
	context_menu.add_folder_options()
	
	var option_texts: Array[String] = []
	for child in context_menu.get_node("VBoxContainer").get_children():
		var opt_text_node = child.get_node_or_null("%Option Text")
		if opt_text_node:
			option_texts.append(opt_text_node.text)
	
	assert(!option_texts.has("Copy Folder"), "Copy Folder should NOT be in context menu")
	assert(!option_texts.has("Cut Folder"), "Cut Folder should NOT be in context menu")
	assert(!option_texts.has("Move to trash"), "Move to trash should NOT be in context menu")
	assert(!option_texts.has("Aggiungi password"), "Aggiungi password should NOT be in context menu")
	
	# Clean up
	FolderPasswordManager.remove_password("ProtectedFolder")
	DirAccess.remove_absolute("user://files/ProtectedFolder")
	print("   Restrictions on password protected folders: PASS")
