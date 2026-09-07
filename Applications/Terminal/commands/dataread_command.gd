extends TerminalCommand


func _init() -> void:
	call_name = "dataread"


func execute(terminal: Terminal, args: Array[String]) -> void:
	if args.size() != 2:
		terminal.push_line_to_output(
			"Invalid number of arguments, expected 2, found %s." % [args.size()]
		)
		terminal.push_lines_to_output(usage())
		return
	
	var key_arg: String = args[0].strip_edges()
	var file_arg: String = args[1].strip_edges()
	
	if not file_arg.ends_with(".dat"):
		terminal.push_line_to_output("Errore: Il file '%s' non e' un file .dat." % [file_arg])
		return
	
	var current_path: String = terminal.virtual_path_manager.get_path()
	var file_path: String = ""
	if file_arg.begins_with("/"):
		file_path = file_arg.simplify_path().trim_prefix("/").trim_suffix("/")
	else:
		if current_path != "":
			file_path = current_path.path_join(file_arg).simplify_path().trim_prefix("/").trim_suffix("/")
		else:
			file_path = file_arg.simplify_path().trim_prefix("/").trim_suffix("/")
	
	var abs_path: String = "user://files/%s" % file_path
	if not FileAccess.file_exists(abs_path) and not terminal.virtual_path_manager.path_is_valid_file(file_path):
		terminal.push_line_to_output("Errore: File '%s' non trovato." % [file_path])
		return
	
	var file: FileAccess = FileAccess.open(abs_path, FileAccess.READ)
	if not file:
		terminal.push_line_to_output("Errore: Impossibile leggere il file '%s'." % [file_path])
		return
	
	var dat_content: String = file.get_as_text()
	file.close()
	
	var real_key: String = _extract_decryption_key(dat_content)
	if not real_key.is_empty() and key_arg != real_key:
		terminal.push_line_to_output("Errore: Chiave di decriptazione non valida per '%s'." % [file_path])
		return
	
	terminal.push_line_to_output("Chiave verificata. Apertura file protetto '%s' nel lettore di sistema..." % [file_path])
	
	var window: FakeWindow = load("res://Scenes/Window/Text Editor/text_editor.tscn").instantiate()
	var text_editor: CodeEdit = window.get_node_or_null("%Text Editor")
	if text_editor:
		if text_editor.has_method("open_dat_file"):
			text_editor.open_dat_file(file_path)
		else:
			text_editor.set("allow_dat_editing", true)
			text_editor.populate_text(file_path)
	
	window.title_text = file_path.get_file()
	var tree := terminal.get_tree()
	if tree:
		var parent_node: Node = tree.current_scene
		if parent_node == null:
			parent_node = tree.root
		parent_node.add_child(window)
		var taskbar_group := tree.get_first_node_in_group("taskbar_buttons")
		if taskbar_group:
			var taskbar_button: Control = load("res://Scenes/Taskbar/taskbar_button.tscn").instantiate()
			taskbar_button.target_window = window
			taskbar_button.active_color = Color("9c82f9")
			taskbar_group.add_child(taskbar_button)


func _extract_decryption_key(content: String) -> String:
	var lines: PackedStringArray = content.split("\n")
	for line: String in lines:
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("decryption_key"):
			var eq_idx: int = trimmed.find("=")
			if eq_idx != -1:
				var val: String = trimmed.substr(eq_idx + 1).strip_edges()
				if (val.begins_with("\"") and val.ends_with("\"")) or (val.begins_with("'") and val.ends_with("'")):
					val = val.substr(1, val.length() - 2).strip_edges()
				return val
	return ""


func usage() -> Array[String]:
	return [
		"dataread - Apre un file .dat protetto nell'Editor di Testo autorizzandone la lettura e modifica.",
		"USAGE:",
		"  dataread <chiave> <file.dat>",
		"Esempio:",
		"  dataread ROOT-7815 'Terminal Drive/systems/terminal_config.dat'"
	]
