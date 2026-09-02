extends Node

func _ready() -> void:
	print("--- TEST SHIP DRIVE MOUNT, UNMOUNT & SYNCHRONIZATION ---")
	_run_tests.call_deferred()

func _run_tests() -> void:
	await get_tree().process_frame
	
	var net: GameNetworkManager = get_node_or_null("/root/NetworkManager") as GameNetworkManager
	var sdm: ShipDriveManagerSingleton = get_node_or_null("/root/ShipDriveManager") as ShipDriveManagerSingleton
	
	if net == null or sdm == null:
		print("FAIL: Autoloads not found!")
		get_tree().quit(1)
		return
	
	print("\n--- Test 1: Initial state (Disconnected) ---")
	if sdm.is_drive_mounted:
		print("FAIL: Ship Drive should NOT be mounted initially!")
		get_tree().quit(1)
		return
	print("SUCCESS: Ship Drive is unmounted initially.")
	
	print("\n--- Test 2: Mount Ship Drive on Mission Launch (Solo & Multiplayer) ---")
	net.start_solo_game("Capitano")
	await get_tree().process_frame
	
	if sdm.is_drive_mounted:
		print("FAIL: Ship Drive should NOT be mounted in Lobby before mission start!")
		get_tree().quit(1)
		return
	print("SUCCESS: Ship Drive remains unmounted in Solo Lobby.")
	
	net.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not sdm.is_drive_mounted:
		print("FAIL: Ship Drive should be mounted when ship is connected (mission started)!")
		get_tree().quit(1)
		return
	
	if not DirAccess.dir_exists_absolute("user://files/Ship Drive"):
		print("FAIL: user://files/Ship Drive directory was not created!")
		get_tree().quit(1)
		return
	
	if not FileAccess.file_exists("user://files/Ship Drive/Ship Systems.txt"):
		print("FAIL: Default file 'Ship Systems.txt' not created!")
		get_tree().quit(1)
		return
	
	if not FileAccess.file_exists("user://files/Ship Drive/Flight Log.txt"):
		print("FAIL: Default file 'Flight Log.txt' not created!")
		get_tree().quit(1)
		return
	
	print("SUCCESS: Ship Drive mounted with default ship files.")
	
	print("\n--- Test 3: Create, Modify, Rename & Delete inside Ship Drive ---")
	# Create file via BaseFileManager.new_file
	var dummy_file_mgr := BaseFileManager.new()
	dummy_file_mgr.file_path = "Ship Drive"
	add_child(dummy_file_mgr)
	
	dummy_file_mgr.new_file(".txt", GlobalValues.FileType.TEXT_FILE, "New File", "Ship Drive")
	await get_tree().process_frame
	
	if not FileAccess.file_exists("user://files/Ship Drive/New File.txt"):
		print("FAIL: 'New File.txt' was not created with .txt extension!")
		get_tree().quit(1)
		return
	print("SUCCESS: 'New File.txt' created with proper extension.")
	
	# Create second file with collision
	dummy_file_mgr.new_file(".txt", GlobalValues.FileType.TEXT_FILE, "New File", "Ship Drive")
	await get_tree().process_frame
	if not FileAccess.file_exists("user://files/Ship Drive/New File 2.txt"):
		print("FAIL: 'New File 2.txt' was not created for colliding name!")
		get_tree().quit(1)
		return
	print("SUCCESS: 'New File 2.txt' created on name collision.")
	
	# Modify file and verify real-time sync with open TextEditor
	var text_editor_window: Node = (load("res://Scenes/Window/Text Editor/text_editor.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(text_editor_window)
	var te: CodeEdit = text_editor_window.get_node("%Text Editor") as CodeEdit
	te.populate_text("Ship Drive/New File.txt")
	
	sdm._apply_file_write("Ship Drive/New File.txt", "Multiplayer Synced Line 1\nMultiplayer Synced Line 2")
	if te.text != "Multiplayer Synced Line 1\nMultiplayer Synced Line 2":
		print("FAIL: Open text editor did not receive real-time sync update! Got: ", te.text)
		get_tree().quit(1)
		return
	print("SUCCESS: Open Text Editor updated in real-time on incoming sync.")
	text_editor_window.queue_free()
	dummy_file_mgr.queue_free()
	
	# Create custom file
	sdm._write_file_content("Ship Drive/TestFile.txt", "Original Content")
	if not FileAccess.file_exists("user://files/Ship Drive/TestFile.txt"):
		print("FAIL: TestFile.txt was not created!")
		get_tree().quit(1)
		return
	
	# Modify file
	sdm._apply_file_write("Ship Drive/TestFile.txt", "Updated Content")
	var read_f := FileAccess.open("user://files/Ship Drive/TestFile.txt", FileAccess.READ)
	if read_f == null or read_f.get_as_text() != "Updated Content":
		print("FAIL: TestFile.txt content was not updated!")
		get_tree().quit(1)
		return
	read_f.close()
	print("SUCCESS: File create and modify working.")
	
	# Create folder
	sdm._apply_folder_create("Ship Drive/Telemetry")
	if not DirAccess.dir_exists_absolute("user://files/Ship Drive/Telemetry"):
		print("FAIL: Subfolder 'Telemetry' was not created!")
		get_tree().quit(1)
		return
	print("SUCCESS: Subfolder created.")
	
	# Rename file
	sdm._apply_rename("Ship Drive/TestFile.txt", "Ship Drive/RenamedFile.txt", false)
	if FileAccess.file_exists("user://files/Ship Drive/TestFile.txt") or not FileAccess.file_exists("user://files/Ship Drive/RenamedFile.txt"):
		print("FAIL: Rename file failed!")
		get_tree().quit(1)
		return
	print("SUCCESS: File rename working.")
	
	# Delete file
	sdm._apply_delete("Ship Drive/RenamedFile.txt", false)
	if FileAccess.file_exists("user://files/Ship Drive/RenamedFile.txt"):
		print("FAIL: Delete file failed!")
		get_tree().quit(1)
		return
	print("SUCCESS: File delete working.")
	
	print("\n--- Test 3b: Ship Drive Folder Password Synchronization ---")
	var fpm = get_node_or_null("/root/FolderPasswordManager")
	if fpm == null:
		print("FAIL: FolderPasswordManager not found!")
		get_tree().quit(1)
		return
	
	sdm._apply_folder_create("Ship Drive/SecretDocs")
	sdm._apply_folder_password("Ship Drive/SecretDocs", "darknova99")
	if not fpm.has_password("Ship Drive/SecretDocs") or not fpm.check_password("Ship Drive/SecretDocs", "darknova99"):
		print("FAIL: Folder password was not applied to FolderPasswordManager via sync!")
		get_tree().quit(1)
		return
	print("SUCCESS: Folder password synced to FolderPasswordManager.")
	
	# Test folder rename password migration
	sdm._apply_rename("Ship Drive/SecretDocs", "Ship Drive/TopSecretDocs", true)
	if fpm.has_password("Ship Drive/SecretDocs") or not fpm.has_password("Ship Drive/TopSecretDocs"):
		print("FAIL: Password did not migrate on folder rename sync!")
		get_tree().quit(1)
		return
	print("SUCCESS: Password migrated on folder rename sync.")
	
	# Test folder password removal sync
	sdm._apply_remove_folder_password("Ship Drive/TopSecretDocs")
	if fpm.has_password("Ship Drive/TopSecretDocs"):
		print("FAIL: Password was not removed on password removal sync!")
		get_tree().quit(1)
		return
	print("SUCCESS: Password removed on password removal sync.")
	
	# Re-apply password for snapshot verification
	sdm._apply_folder_password("Ship Drive/TopSecretDocs", "alpha_omega")
	
	print("\n--- Test 4: Drive Snapshot for Join Sync ---")
	var snapshot: Array = sdm._gather_drive_snapshot()
	if snapshot.is_empty():
		print("FAIL: Drive snapshot should not be empty!")
		get_tree().quit(1)
		return
	
	var found_sys: bool = false
	var found_pwd: bool = false
	for item in snapshot:
		if item.get("path") == "Ship Drive/Ship Systems.txt":
			found_sys = true
		if item.get("path") == "Ship Drive/TopSecretDocs":
			if item.get("password") == "alpha_omega":
				found_pwd = true
	if not found_sys:
		print("FAIL: Ship Systems.txt not found in snapshot!")
		get_tree().quit(1)
		return
	if not found_pwd:
		print("FAIL: Folder password not included in drive snapshot!")
		get_tree().quit(1)
		return
	print("SUCCESS: Drive snapshot correctly generated with folder passwords.")
	
	# Test receive snapshot
	fpm.delete_path("Ship Drive")
	if fpm.has_password("Ship Drive/TopSecretDocs"):
		print("FAIL: Password should be cleared before full sync test!")
		get_tree().quit(1)
		return
	
	sdm._rpc_receive_full_sync(snapshot)
	if not fpm.has_password("Ship Drive/TopSecretDocs") or not fpm.check_password("Ship Drive/TopSecretDocs", "alpha_omega"):
		print("FAIL: Password was not restored on snapshot receive!")
		get_tree().quit(1)
		return
	print("SUCCESS: Password correctly restored from full sync snapshot.")
	
	print("\n--- Test 5: Unmount Ship Drive on Disconnect ---")
	net.disconnect_game()
	await get_tree().process_frame
	await get_tree().process_frame
	
	if sdm.is_drive_mounted:
		print("FAIL: Ship Drive should be unmounted after disconnect!")
		get_tree().quit(1)
		return
	
	if DirAccess.dir_exists_absolute("user://files/Ship Drive"):
		print("FAIL: user://files/Ship Drive should be removed upon unmount!")
		get_tree().quit(1)
		return
	
	print("SUCCESS: Ship Drive cleanly unmounted on disconnect.")
	
	print("\n--- Test 6: Multiplayer Lobby vs Mission Start ---")
	var err = net.host_game("Capitano", 7815, "Nave Multiplayer", 4)
	if err != OK:
		print("FAIL: Could not host game: ", err)
		get_tree().quit(1)
		return
	await get_tree().process_frame
	
	if sdm.is_drive_mounted:
		print("FAIL: Ship Drive should NOT be mounted in multiplayer lobby before mission start!")
		get_tree().quit(1)
		return
	print("SUCCESS: Ship Drive remains unmounted in Multiplayer Lobby.")
	
	net.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not sdm.is_drive_mounted:
		print("FAIL: Ship Drive should be mounted when multiplayer mission starts!")
		get_tree().quit(1)
		return
	print("SUCCESS: Ship Drive mounted when multiplayer mission starts.")
	
	net.disconnect_game()
	await get_tree().process_frame
	await get_tree().process_frame
	
	if sdm.is_drive_mounted:
		print("FAIL: Ship Drive should be unmounted after multiplayer disconnect!")
		get_tree().quit(1)
		return
	print("SUCCESS: Ship Drive unmounted on multiplayer disconnect.")
	
	print("\n--- Test 7: Leftover directory cleanup & window close when disconnected ---")
	# Crea forzatamente una directory e file di Ship Drive simulando una sessione precedente rimasta aperta o terminata bruscamente
	DirAccess.make_dir_recursive_absolute("user://files/Ship Drive")
	var stray_file := FileAccess.open("user://files/Ship Drive/StrayFile.txt", FileAccess.WRITE)
	stray_file.store_string("Stray content from prior session")
	stray_file.close()
	
	# Verifica che BaseFileManager non mostri Ship Drive quando disconnessi anche se la directory esiste su disco
	var desktop_mgr := DesktopFileManager.new()
	add_child(desktop_mgr)
	await desktop_mgr.populate_file_manager()
	var found_on_desktop: bool = false
	for child in desktop_mgr.get_children():
		if child is FakeFolder and child.folder_name == "Ship Drive":
			found_on_desktop = true
	if found_on_desktop:
		print("FAIL: DesktopFileManager should NOT show Ship Drive when not connected!")
		get_tree().quit(1)
		return
	print("SUCCESS: DesktopFileManager filters out Ship Drive when disconnected.")
	
	# Simula finestra rimasta aperta
	var text_editor_win: Node = (load("res://Scenes/Window/Text Editor/text_editor.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(text_editor_win)
	var stray_te: CodeEdit = text_editor_win.get_node("%Text Editor") as CodeEdit
	stray_te.populate_text("Ship Drive/StrayFile.txt")
	
	# Esegue l'aggiornamento dello stato di connessione (disconnesso)
	sdm._update_connection_state()
	await get_tree().process_frame
	await get_tree().process_frame
	
	if DirAccess.dir_exists_absolute("user://files/Ship Drive"):
		print("FAIL: user://files/Ship Drive should be cleaned up when disconnected!")
		get_tree().quit(1)
		return
	print("SUCCESS: Leftover Ship Drive directory removed upon connection state check.")
	
	desktop_mgr.queue_free()

	print("\n=== ALL SHIP DRIVE TESTS PASSED! ===")
	get_tree().quit(0)
