extends TerminalCommand


func _init() -> void:
	call_name = "ls"


func execute(terminal: Terminal, args: Array[String]) -> void:
	var target_path := ""
	if args.size() > 0:
		var current_path: String = terminal.virtual_path_manager.get_path()
		if current_path != "" and current_path[-1] != '/':
			current_path += '/'
		target_path = args[0] if args[0].begins_with("/") else (current_path + args[0])
		target_path = target_path.trim_prefix("/").trim_suffix("/")
	
	var directories: PackedStringArray
	var files: PackedStringArray
	if target_path.is_empty():
		directories = terminal.virtual_path_manager.list_directories()
		files = terminal.virtual_path_manager.list_files()
	else:
		directories = terminal.virtual_path_manager.list_directories(target_path)
		files = terminal.virtual_path_manager.list_files(target_path)
	
	if directories.is_empty() and files.is_empty():
		terminal.push_line_to_output("(directory is empty)")
		return
	
	for directory: String in directories:
		var dir_btn := TerminalUIButton.new()
		dir_btn.label_text = "DIR:  " + directory + "/"
		var cd_target := (target_path + "/" + directory).trim_prefix("/") if not target_path.is_empty() else directory
		dir_btn.command_to_execute = 'cd "%s"' % cd_target
		dir_btn.custom_data = {"type": "directory", "name": directory}
		terminal.push_widget_to_output(dir_btn)
	
	for file: String in files:
		var file_btn := TerminalUIButton.new()
		file_btn.label_text = "FILE: " + file
		var cat_target := (target_path + "/" + file).trim_prefix("/") if not target_path.is_empty() else file
		file_btn.command_to_execute = 'cat "%s"' % cat_target
		file_btn.custom_data = {"type": "file", "name": file}
		terminal.push_widget_to_output(file_btn)


func usage() -> Array[String]:
	return [
		"Ls - List directory.",
		"USAGE:",
		"Takes no arguments.",
		"Prints all directories and files in the current path"
	]
