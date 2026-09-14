extends GutTest

## Unit tests for the Terminal TUI Framework and mouse interactivity.

func test_tui_button() -> void:
	var btn := TerminalUIButton.new()
	btn.label_text = "Execute System Scan"
	btn.command_to_execute = "echo scanning"
	add_child_autofree(btn)
	await get_tree().process_frame
	
	var result := {"clicked": false}
	btn.clicked.connect(func(_b = null) -> void:
		result.clicked = true
	)
	
	# Simulate hover
	btn.set_hovered(true)
	assert_true(btn.is_hovered)
	
	# Simulate click
	btn._trigger_click()
	assert_true(result.clicked, "Il segnale clicked deve essere emesso al click")

func test_tui_options_single_selection() -> void:
	var options_widget := TerminalUIOptions.new()
	add_child_autofree(options_widget)
	
	var result := {"selected_idx": -1, "selected_data": {}}
	options_widget.option_selected.connect(func(idx, data) -> void:
		result.selected_idx = idx
		result.selected_data = data
	)
	
	options_widget.set_options([
		{"title": "Option Alpha", "description": "Desc A", "command": "echo A"},
		{"title": "Option Beta", "description": "Desc B", "command": "echo B"}
	], "TEST CHOICES")
	await get_tree().process_frame
	
	options_widget._on_option_clicked(1)
	assert_eq(result.selected_idx, 1, "Deve selezionare Option Beta")
	assert_eq(result.selected_data.get("title"), "Option Beta")

func test_tui_options_multi_selection() -> void:
	var options_widget := TerminalUIOptions.new()
	add_child_autofree(options_widget)
	
	var confirmed_indices: Array[int] = []
	options_widget.selection_confirmed.connect(func(indices: Array[int]) -> void:
		confirmed_indices = indices
	)
	
	options_widget.set_options([
		{"title": "Opt 1"},
		{"title": "Opt 2"},
		{"title": "Opt 3"}
	], "MULTI SELECT", true)
	await get_tree().process_frame
	
	# Toggle indices 0 and 2
	options_widget._on_option_clicked(0)
	options_widget._on_option_clicked(2)
	assert_eq(options_widget.selected_indices, [0, 2])
	
	# Toggle off 0
	options_widget._on_option_clicked(0)
	assert_eq(options_widget.selected_indices, [2])

func test_tui_card() -> void:
	var card := TerminalUICard.new()
	card.card_title = "SYSTEM STATUS"
	card.body_text = "All modules online."
	add_child_autofree(card)
	await get_tree().process_frame
	
	var custom_btn := TerminalUIButton.new()
	custom_btn.label_text = "Reboot"
	card.add_body_widget(custom_btn)
	assert_eq(custom_btn.get_parent(), card.get_node("%_content_box") if card.has_node("%_content_box") else card._content_box)

func test_tui_overlay_and_terminal_integration() -> void:
	var terminal_scene: PackedScene = load("res://Applications/Terminal/src/terminal_scene.tscn")
	var terminal: Terminal = terminal_scene.instantiate()
	add_child_autofree(terminal)
	await get_tree().process_frame
	
	assert_false(terminal.is_tui_overlay_active(), "L'overlay deve essere chiuso inizialmente")
	
	var overlay := TerminalUIOverlay.new()
	overlay.overlay_title = "MODAL TEST"
	terminal.open_tui_overlay(overlay)
	assert_true(terminal.is_tui_overlay_active(), "L'overlay deve risultare attivo dopo open_tui_overlay")
	
	terminal.close_tui_overlay()
	assert_false(terminal.is_tui_overlay_active(), "L'overlay deve essere disattivato dopo close_tui_overlay")

func test_clickable_ls_output() -> void:
	var terminal_scene: PackedScene = load("res://Applications/Terminal/src/terminal_scene.tscn")
	var terminal: Terminal = terminal_scene.instantiate()
	add_child_autofree(terminal)
	await get_tree().process_frame
	
	# Create dummy file and dir
	var test_dir := "user://files/LsTuiTest"
	if not DirAccess.dir_exists_absolute(test_dir):
		DirAccess.make_dir_recursive_absolute(test_dir)
	var sub_dir := test_dir + "/SubFolder"
	DirAccess.make_dir_recursive_absolute(sub_dir)
	var file_path := test_dir + "/sample.txt"
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	f.store_string("sample")
	f.close()
	
	terminal.virtual_path_manager.set_path("LsTuiTest")
	
	# Execute ls
	terminal.execute_command("ls")
	await get_tree().process_frame
	
	# Find TerminalUIButtons in output container
	var buttons: Array[TerminalUIButton] = []
	for child in terminal.command_output_container.get_children():
		if child is TerminalUIButton:
			buttons.append(child)
	
	assert_gt(buttons.size(), 0, "Il comando ls deve generare elementi TerminalUIButton cliccabili")
	
	var found_dir := false
	var found_file := false
	for b in buttons:
		if "SubFolder" in b.label_text:
			found_dir = true
			assert_true(b.command_to_execute.begins_with("cd"), "Il click sulla cartella deve eseguire cd")
		if "sample.txt" in b.label_text:
			found_file = true
			assert_true(b.command_to_execute.begins_with("cat"), "Il click sul file deve eseguire cat")
	
	assert_true(found_dir, "La cartella deve essere presente come pulsante")
	assert_true(found_file, "Il file deve essere presente come pulsante")
	
	# Cleanup
	DirAccess.remove_absolute(file_path)
	DirAccess.remove_absolute(sub_dir)
	DirAccess.remove_absolute(test_dir)
