extends GutTest

## Unit tests for Multiple Terminal Instances and dynamic titles.

func test_multiple_instances_have_unique_ids() -> void:
	var terminal_scene: PackedScene = load("res://Applications/Terminal/src/terminal_scene.tscn")
	var term1: Terminal = terminal_scene.instantiate()
	var term2: Terminal = terminal_scene.instantiate()
	add_child_autofree(term1)
	add_child_autofree(term2)
	await get_tree().process_frame
	
	assert_gt(term1.instance_id, 0, "Term1 deve avere un ID istanza positivo")
	assert_gt(term2.instance_id, 0, "Term2 deve avere un ID istanza positivo")
	assert_ne(term1.instance_id, term2.instance_id, "Le istanze devono avere ID univoci e distinti")
	assert_eq(term2.instance_id, term1.instance_id + 1, "Gli ID devono incrementare progressivamente")

func test_dynamic_window_title_updates() -> void:
	var test_dir := "user://files/InstTitleTest"
	if not DirAccess.dir_exists_absolute(test_dir):
		DirAccess.make_dir_recursive_absolute(test_dir)
	
	var window_scene: PackedScene = load("res://Scenes/Window/Application Window/application_window.tscn")
	var window: FakeWindow = window_scene.instantiate()
	add_child_autofree(window)
	
	var terminal_scene: PackedScene = load("res://Applications/Terminal/src/terminal_scene.tscn")
	var terminal: Terminal = terminal_scene.instantiate()
	window.get_node("%ApplicationContents").add_child(terminal)
	await get_tree().process_frame
	
	assert_true(window.title_text.begins_with("Terminale Shell UNIX #"), "Il titolo deve indicare il terminale e l'ID")
	assert_true(str(terminal.instance_id) in window.title_text, "Il titolo della finestra deve includere l'ID istanza")
	
	# Change directory
	terminal.virtual_path_manager.set_path("InstTitleTest")
	await get_tree().process_frame
	
	assert_true("InstTitleTest" in window.title_text, "Il titolo della finestra deve aggiornarsi con la cartella corrente")
	DirAccess.remove_absolute(test_dir)

func test_instance_isolation() -> void:
	var test_dir := "user://files/InstIsoTest"
	if not DirAccess.dir_exists_absolute(test_dir):
		DirAccess.make_dir_recursive_absolute(test_dir)
	
	var terminal_scene: PackedScene = load("res://Applications/Terminal/src/terminal_scene.tscn")
	var term1: Terminal = terminal_scene.instantiate()
	var term2: Terminal = terminal_scene.instantiate()
	add_child_autofree(term1)
	add_child_autofree(term2)
	await get_tree().process_frame
	
	# Paths are isolated
	term1.virtual_path_manager.set_path("InstIsoTest")
	assert_eq(term1.virtual_path_manager.get_path(), "InstIsoTest")
	assert_ne(term2.virtual_path_manager.get_path(), "InstIsoTest", "Il cambio percorso su term1 non deve influenzare term2")
	
	# Histories are isolated
	term1.input_history_manager.push_to_history("secret_command_1")
	assert_true("secret_command_1" in term1.input_history_manager.get_history())
	assert_false("secret_command_1" in term2.input_history_manager.get_history(), "La cronologia deve rimanere isolata")
	DirAccess.remove_absolute(test_dir)

func test_terminal_command_registration_and_alias() -> void:
	var cmd_mgr := TerminalCommandManager.new()
	assert_true(cmd_mgr.cmd_exists("terminal"), "Il comando terminal deve essere registrato")
	
	var res_alias := cmd_mgr.find_command("term")
	assert_not_null(res_alias.get("command"), "L'alias 'term' deve corrispondere al comando terminal tramite regex")
	assert_eq(res_alias.get("command").call_name, "terminal")
