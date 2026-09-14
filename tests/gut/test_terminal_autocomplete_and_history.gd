extends GutTest

## Unit tests for TerminalAutoComplete and TerminalInputHistoryManager.

func test_longest_common_prefix() -> void:
	assert_eq(TerminalAutoComplete.get_longest_common_prefix(["dataread", "decript"]), "d")
	assert_eq(TerminalAutoComplete.get_longest_common_prefix(["hello_world", "hello_earth"]), "hello_")
	assert_eq(TerminalAutoComplete.get_longest_common_prefix(["worm"]), "worm")
	assert_eq(TerminalAutoComplete.get_longest_common_prefix([]), "")
	assert_eq(TerminalAutoComplete.get_longest_common_prefix(["abc", "xyz"]), "")

func test_autocomplete_commands() -> void:
	var cmds: Array[String] = ["worm", "decript", "dataread", "cat", "cd", "ls"]
	
	# Unique command
	var res_unique := TerminalAutoComplete.autocomplete("wor", 3, cmds, null)
	assert_true(res_unique.completed, "Il comando univoco deve essere completato")
	assert_false(res_unique.is_ambiguous, "Il comando univoco non è ambiguo")
	assert_eq(res_unique.new_text, "worm ", "Deve aggiungere lo spazio al completamento univoco")
	assert_eq(res_unique.new_caret_position, 5)
	
	# Ambiguous command
	var res_ambiguous := TerminalAutoComplete.autocomplete("d", 1, cmds, null)
	assert_true(res_ambiguous.is_ambiguous, "d corrisponde a più comandi ed è ambiguo")
	assert_eq(res_ambiguous.candidates.size(), 2)
	assert_true("dataread" in res_ambiguous.candidates)
	assert_true("decript" in res_ambiguous.candidates)
	assert_false(res_ambiguous.completed, "LCP non aggiunge caratteri rispetto a 'd'")
	
	# Ambiguous command with partial completion (LCP)
	var extended_cmds: Array[String] = ["terminal_one", "terminal_two"]
	var res_lcp := TerminalAutoComplete.autocomplete("te", 2, extended_cmds, null)
	assert_true(res_lcp.is_ambiguous, "Deve rilevare ambiguità")
	assert_true(res_lcp.completed, "Deve estendere il testo fino all'LCP 'terminal_'")
	assert_eq(res_lcp.new_text, "terminal_")
	assert_eq(res_lcp.new_caret_position, 9)

func test_autocomplete_paths() -> void:
	var vpm := VirtualPathManager.new()
	var test_dir := "user://files/AutoTestDir"
	if not DirAccess.dir_exists_absolute(test_dir):
		DirAccess.make_dir_recursive_absolute(test_dir)
	
	var sub1 := test_dir + "/AlphaFolder"
	var sub2 := test_dir + "/Beta Space Folder"
	var file1 := test_dir + "/config.dat"
	DirAccess.make_dir_recursive_absolute(sub1)
	DirAccess.make_dir_recursive_absolute(sub2)
	var f := FileAccess.open(file1, FileAccess.WRITE)
	f.store_string("test")
	f.close()
	
	vpm.set_path("AutoTestDir")
	
	# Complete folder with trailing slash
	var res_folder := TerminalAutoComplete.autocomplete("cd Alp", 6, [], vpm)
	assert_true(res_folder.completed)
	assert_eq(res_folder.new_text, "cd AlphaFolder/")
	
	# Complete folder with space -> should quote
	var res_space := TerminalAutoComplete.autocomplete("cd Bet", 6, [], vpm)
	assert_true(res_space.completed)
	assert_eq(res_space.new_text, 'cd "Beta Space Folder/"')
	
	# Complete file
	var res_file := TerminalAutoComplete.autocomplete("cat conf", 8, [], vpm)
	assert_true(res_file.completed)
	assert_eq(res_file.new_text, "cat config.dat ")
	
	# Cleanup
	DirAccess.remove_absolute(file1)
	DirAccess.remove_absolute(sub1)
	DirAccess.remove_absolute(sub2)
	DirAccess.remove_absolute(test_dir)

func test_history_navigation_and_draft() -> void:
	var line_edit := LineEdit.new()
	add_child_autofree(line_edit)
	var hist_mgr := TerminalInputHistoryManager.new(line_edit)
	
	# Pushing commands
	hist_mgr.push_to_history("first_cmd")
	hist_mgr.push_to_history("second_cmd")
	hist_mgr.push_to_history("second_cmd") # Consecutive duplicate
	hist_mgr.push_to_history("   ")       # Whitespace
	
	assert_eq(hist_mgr.get_history().size(), 2, "I duplicati consecutivi e comandi vuoti non devono essere inseriti")
	
	# Current draft typing
	line_edit.text = "unfinished_draft"
	
	# Navigate UP
	var up1 := hist_mgr.get_next(TerminalInputHistoryManager.DIR.UP)
	assert_eq(up1, "second_cmd", "Primo UP deve caricare l'ultimo comando")
	
	var up2 := hist_mgr.get_next(TerminalInputHistoryManager.DIR.UP)
	assert_eq(up2, "first_cmd", "Secondo UP deve caricare il comando precedente")
	
	# UP at start
	var up3 := hist_mgr.get_next(TerminalInputHistoryManager.DIR.UP)
	assert_eq(up3, "first_cmd", "UP in cima rimane al comando più vecchio")
	
	# Navigate DOWN back
	var down1 := hist_mgr.get_next(TerminalInputHistoryManager.DIR.DOWN)
	assert_eq(down1, "second_cmd", "Primo DOWN scende verso il più recente")
	
	var down2 := hist_mgr.get_next(TerminalInputHistoryManager.DIR.DOWN)
	assert_eq(down2, "unfinished_draft", "DOWN fino in fondo deve ripristinare la bozza digitata")
