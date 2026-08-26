extends TerminalCommand


func _init() -> void:
	call_name = "cd"


func execute(terminal: Terminal, args: Array[String]) -> void:
	if args.size() > 1:
		terminal.push_line_to_output(
			"Invalid number of arguments, expected 1, found %s." % [args.size()]
		)
		return
	
	elif args.size() == 0:
		terminal.virtual_path_manager.set_path("")
		return
	
	var path_to: String = args[0].simplify_path()
	if path_to == "..":
		terminal.virtual_path_manager.set_path(
			terminal.virtual_path_manager.get_base_dir()
		)
		return
	
	var current_path: String = terminal.virtual_path_manager.get_path()
	if current_path != "" and current_path[-1] != '/':
		current_path += '/'
	
	var folder_path: String = (current_path + path_to).simplify_path()
	if folder_path == ".":
		folder_path = ""
	folder_path = folder_path.trim_prefix("/").trim_suffix("/")
	
	if terminal.virtual_path_manager.path_is_valid_folder(folder_path):
		var fpm := terminal.get_node_or_null("/root/FolderPasswordManager")
		if fpm and fpm.has_password(folder_path):
			var folder_name := folder_path.get_file()
			if folder_name.is_empty():
				folder_name = folder_path
			fpm.prompt_enter_password(folder_path, folder_name, func(_removed_pass: bool) -> void:
				terminal.virtual_path_manager.set_path(folder_path)
			)
		else:
			terminal.virtual_path_manager.set_path(folder_path)
	else:
		terminal.push_line_to_output(folder_path + " does not exist or is a file.")


func usage() -> Array[String]:
	return [
		"Cd - Change directory.",
		"USAGE:",
		"Expects either no arguments or a valid directory path.",
		"If no argument is given, it moves to the root directory.",
		"If \"..\" is given, it goes up one directory.",
		"If a valid path is given, it moves to that directory.",
	]
