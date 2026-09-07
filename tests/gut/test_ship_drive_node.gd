extends GutTest

## Test GUT per Ship Drive Mount, Unmount & Synchronization (`ShipDriveManager`).
## Le funzioni sono eseguite in ordine di dichiarazione (comportamento di GUT) e condividono
## lo stato reale degli autoload NetworkManager / ShipDriveManager, come nel test manuale originale.

func test_initial_state_disconnected() -> void:
	assert_false(ShipDriveManager.is_drive_mounted, "Ship Drive should NOT be mounted initially")

func test_mount_on_mission_launch_solo() -> void:
	NetworkManager.start_solo_game("Capitano")
	await get_tree().process_frame

	assert_false(ShipDriveManager.is_drive_mounted, "Ship Drive should NOT be mounted in Lobby before mission start")

	NetworkManager.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(ShipDriveManager.is_drive_mounted, "Ship Drive should be mounted when ship is connected (mission started)")
	assert_true(DirAccess.dir_exists_absolute("user://files/Ship Drive"), "user://files/Ship Drive directory was not created")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Ship Systems.txt"), "Default file 'Ship Systems.txt' not created")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Flight Log.txt"), "Default file 'Flight Log.txt' not created")

func test_decryption_keys_in_default_dat_files_and_base_app_parser() -> void:
	var expected_keys: Dictionary = {
		"Ship Drive/Programs/FlightControls/flight_config.dat": "FLIGHT-CFG-7815",
		"Ship Drive/Programs/FlightControls/thrusters_tuning.dat": "THRUST-TUN-7815",
		"Ship Drive/Programs/Cams/cams_config.dat": "CAMS-CFG-7815",
		"Ship Drive/Programs/Cams/optics_tuning.dat": "OPTIC-TUN-7815",
		"Ship Drive/Programs/DuctDrone/duct_drone_config.dat": "DUCT-CFG-7815",
		"Ship Drive/Programs/DuctDrone/drone_tuning.dat": "DRONE-TUN-7815",
		"Ship Drive/Programs/PowerGrid/power_grid_config.dat": "GRID-CFG-7815",
		"Ship Drive/Programs/PowerGrid/grid_tuning.dat": "GRID-TUN-7815",
		"Ship Drive/Programs/Weapons/weapons_config.dat": "WEAP-CFG-7815",
		"Ship Drive/Programs/Weapons/ammo_tuning.dat": "AMMO-TUN-7815",
		"Ship Drive/Programs/ShieldMatrix/shields_config.dat": "SHLD-CFG-7815",
		"Ship Drive/Programs/ShieldMatrix/deflector_tuning.dat": "DEFL-TUN-7815",
		"Ship Drive/Programs/Comms/comms_config.dat": "COMM-CFG-7815",
		"Ship Drive/Programs/Comms/crypto_tuning.dat": "CRYP-TUN-7815",
		"Ship Drive/Programs/Diagnostics/diagnostics_config.dat": "DIAG-CFG-7815",
		"Ship Drive/Programs/Diagnostics/security_tuning.dat": "SECU-TUN-7815",
		"Ship Drive/Programs/Sensors/sensors_config.dat": "SENS-CFG-7815",
		"Ship Drive/Programs/Sensors/radar_tuning.dat": "RADR-TUN-7815",
		"Ship Drive/systems/ship_blueprint.dat": "BLUP-SYS-7815",
		"Ship Drive/systems/hull_specs.dat": "HULL-SYS-7815"
	}

	var base_app_instance := BaseApp.new()
	add_child_autofree(base_app_instance)

	for file_path in expected_keys:
		var expected_key: String = expected_keys[file_path]
		var file_content := FileAccess.get_file_as_string("user://files/" + file_path)
		assert_false(file_content.is_empty(), "File not found or empty: " + file_path)
		assert_true(("decryption_key=" + expected_key) in file_content, "File " + file_path + " missing expected decryption_key=" + expected_key)

		# Test BaseApp parsing
		var parsed: Dictionary = base_app_instance._parse_dat_file(file_path)
		assert_true(parsed.has("decryption_key"), "Parsed dictionary missing decryption_key for " + file_path)
		assert_true(typeof(parsed["decryption_key"]) == TYPE_STRING and parsed["decryption_key"] == expected_key, "decryption_key is not String or mismatch for " + file_path)

	# Verify BaseApp preserves typed parameters (float, int, bool, string)
	var fc_parsed: Dictionary = base_app_instance._parse_dat_file("Ship Drive/Programs/FlightControls/flight_config.dat")
	assert_true(typeof(fc_parsed.get("max_linear_speed")) == TYPE_FLOAT and fc_parsed.get("max_linear_speed") == 20.0, "Float parameter corrupted in BaseApp._parse_dat_file")
	assert_true(typeof(fc_parsed.get("app_name")) == TYPE_STRING and fc_parsed.get("app_name") == "FlightControls", "String parameter corrupted in BaseApp._parse_dat_file")

	var wp_parsed: Dictionary = base_app_instance._parse_dat_file("Ship Drive/Programs/Weapons/weapons_config.dat")
	assert_true(typeof(wp_parsed.get("auto_pdg_enabled")) == TYPE_BOOL and wp_parsed.get("auto_pdg_enabled") == true, "Bool parameter corrupted in BaseApp._parse_dat_file")
	assert_true(typeof(wp_parsed.get("torpedo_max_ammo")) == TYPE_INT and wp_parsed.get("torpedo_max_ammo") == 12, "Int parameter corrupted in BaseApp._parse_dat_file")

func test_create_modify_rename_delete_inside_ship_drive() -> void:
	# Create file via BaseFileManager.new_file
	var dummy_file_mgr := BaseFileManager.new()
	dummy_file_mgr.file_path = "Ship Drive"
	add_child_autofree(dummy_file_mgr)

	dummy_file_mgr.new_file(".txt", GlobalValues.FileType.TEXT_FILE, "New File", "Ship Drive")
	await get_tree().process_frame

	assert_true(FileAccess.file_exists("user://files/Ship Drive/New File.txt"), "'New File.txt' was not created with .txt extension")

	# Create second file with collision
	dummy_file_mgr.new_file(".txt", GlobalValues.FileType.TEXT_FILE, "New File", "Ship Drive")
	await get_tree().process_frame
	assert_true(FileAccess.file_exists("user://files/Ship Drive/New File 2.txt"), "'New File 2.txt' was not created for colliding name")

	# Modify file and verify real-time sync with open TextEditor
	var text_editor_window: Node = (load("res://Scenes/Window/Text Editor/text_editor.tscn") as PackedScene).instantiate()
	add_child_autofree(text_editor_window)
	var te: CodeEdit = text_editor_window.get_node("%Text Editor") as CodeEdit
	te.populate_text("Ship Drive/New File.txt")

	ShipDriveManager._apply_file_write("Ship Drive/New File.txt", "Multiplayer Synced Line 1\nMultiplayer Synced Line 2")
	assert_eq(te.text, "Multiplayer Synced Line 1\nMultiplayer Synced Line 2", "Open text editor did not receive real-time sync update")

	# Create custom file
	ShipDriveManager._write_file_content("Ship Drive/TestFile.txt", "Original Content")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/TestFile.txt"), "TestFile.txt was not created")

	# Modify file
	ShipDriveManager._apply_file_write("Ship Drive/TestFile.txt", "Updated Content")
	var read_f := FileAccess.open("user://files/Ship Drive/TestFile.txt", FileAccess.READ)
	assert_true(read_f != null and read_f.get_as_text() == "Updated Content", "TestFile.txt content was not updated")
	if read_f:
		read_f.close()

	# Create folder
	ShipDriveManager._apply_folder_create("Ship Drive/Telemetry")
	assert_true(DirAccess.dir_exists_absolute("user://files/Ship Drive/Telemetry"), "Subfolder 'Telemetry' was not created")

	# Rename file
	ShipDriveManager._apply_rename("Ship Drive/TestFile.txt", "Ship Drive/RenamedFile.txt", false)
	assert_true(not FileAccess.file_exists("user://files/Ship Drive/TestFile.txt") and FileAccess.file_exists("user://files/Ship Drive/RenamedFile.txt"), "Rename file failed")

	# Delete file
	ShipDriveManager._apply_delete("Ship Drive/RenamedFile.txt", false)
	assert_false(FileAccess.file_exists("user://files/Ship Drive/RenamedFile.txt"), "Delete file failed")

func test_folder_password_synchronization() -> void:
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	assert_not_null(fpm, "FolderPasswordManager not found")

	ShipDriveManager._apply_folder_create("Ship Drive/SecretDocs")
	ShipDriveManager._apply_folder_password("Ship Drive/SecretDocs", "darknova99")
	assert_true(fpm.has_password("Ship Drive/SecretDocs") and fpm.check_password("Ship Drive/SecretDocs", "darknova99"), "Folder password was not applied to FolderPasswordManager via sync")

	# Test folder rename password migration
	ShipDriveManager._apply_rename("Ship Drive/SecretDocs", "Ship Drive/TopSecretDocs", true)
	assert_true(not fpm.has_password("Ship Drive/SecretDocs") and fpm.has_password("Ship Drive/TopSecretDocs"), "Password did not migrate on folder rename sync")

	# Test folder password removal sync
	ShipDriveManager._apply_remove_folder_password("Ship Drive/TopSecretDocs")
	assert_false(fpm.has_password("Ship Drive/TopSecretDocs"), "Password was not removed on password removal sync")

	# Re-apply password for snapshot verification
	ShipDriveManager._apply_folder_password("Ship Drive/TopSecretDocs", "alpha_omega")

func test_drive_snapshot_for_join_sync() -> void:
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	var snapshot: Array = ShipDriveManager._gather_drive_snapshot()
	assert_false(snapshot.is_empty(), "Drive snapshot should not be empty")

	var found_sys: bool = false
	var found_pwd: bool = false
	for item in snapshot:
		if item.get("path") == "Ship Drive/Ship Systems.txt":
			found_sys = true
		if item.get("path") == "Ship Drive/TopSecretDocs":
			if item.get("password") == "alpha_omega":
				found_pwd = true
	assert_true(found_sys, "Ship Systems.txt not found in snapshot")
	assert_true(found_pwd, "Folder password not included in drive snapshot")

	# Test receive snapshot
	fpm.delete_path("Ship Drive")
	assert_false(fpm.has_password("Ship Drive/TopSecretDocs"), "Password should be cleared before full sync test")

	ShipDriveManager._rpc_receive_full_sync(snapshot)
	assert_true(fpm.has_password("Ship Drive/TopSecretDocs") and fpm.check_password("Ship Drive/TopSecretDocs", "alpha_omega"), "Password was not restored on snapshot receive")

func test_unmount_on_disconnect() -> void:
	NetworkManager.disconnect_game()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(ShipDriveManager.is_drive_mounted, "Ship Drive should be unmounted after disconnect")
	assert_false(DirAccess.dir_exists_absolute("user://files/Ship Drive"), "user://files/Ship Drive should be removed upon unmount")

func test_multiplayer_lobby_vs_mission_start() -> void:
	var err := NetworkManager.host_game("Capitano", 7815, "Nave Multiplayer", 4)
	assert_eq(err, OK, "Could not host game")
	await get_tree().process_frame

	assert_false(ShipDriveManager.is_drive_mounted, "Ship Drive should NOT be mounted in multiplayer lobby before mission start")

	NetworkManager.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(ShipDriveManager.is_drive_mounted, "Ship Drive should be mounted when multiplayer mission starts")

	NetworkManager.disconnect_game()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(ShipDriveManager.is_drive_mounted, "Ship Drive should be unmounted after multiplayer disconnect")

func test_leftover_directory_cleanup_and_window_close_when_disconnected() -> void:
	# Crea forzatamente una directory e file di Ship Drive simulando una sessione precedente rimasta aperta o terminata bruscamente
	DirAccess.make_dir_recursive_absolute("user://files/Ship Drive")
	var stray_file := FileAccess.open("user://files/Ship Drive/StrayFile.txt", FileAccess.WRITE)
	stray_file.store_string("Stray content from prior session")
	stray_file.close()

	# Verifica che BaseFileManager non mostri Ship Drive quando disconnessi anche se la directory esiste su disco
	var desktop_mgr := DesktopFileManager.new()
	add_child_autofree(desktop_mgr)
	await desktop_mgr.populate_file_manager()
	var found_on_desktop: bool = false
	for child in desktop_mgr.get_children():
		if child is FakeFolder and child.folder_name == "Ship Drive":
			found_on_desktop = true
	assert_false(found_on_desktop, "DesktopFileManager should NOT show Ship Drive when not connected")

	# Simula finestra rimasta aperta
	var text_editor_win: Node = (load("res://Scenes/Window/Text Editor/text_editor.tscn") as PackedScene).instantiate()
	add_child_autofree(text_editor_win)
	var stray_te: CodeEdit = text_editor_win.get_node("%Text Editor") as CodeEdit
	stray_te.populate_text("Ship Drive/StrayFile.txt")

	# Esegue l'aggiornamento dello stato di connessione (disconnesso)
	ShipDriveManager._update_connection_state()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(DirAccess.dir_exists_absolute("user://files/Ship Drive"), "user://files/Ship Drive should be cleaned up when disconnected")
