extends TerminalCommand


func _init() -> void:
	call_name = "ls"


func execute(terminal: Terminal, args: Array[String]) -> void:
	if args.size() > 0:
		terminal.push_line_to_output(
			"Invalid number of arguments, expected 0, found %s." % [args.size()]
		)
		return
	
	var directories: PackedStringArray = terminal.virtual_path_manager.list_directories()
	var files: PackedStringArray = terminal.virtual_path_manager.list_files()
	
	if directories.is_empty() and files.is_empty():
		terminal.push_line_to_output("(directory is empty)")
		return
	
	for directory: String in directories:
		var dir_btn := TerminalUIButton.new()
		dir_btn.label_text = "DIR:  " + directory + "/"
		dir_btn.command_to_execute = 'cd "%s"' % directory
		dir_btn.custom_data = {"type": "directory", "name": directory}
		terminal.push_widget_to_output(dir_btn)
	
	for file: String in files:
		var file_btn := TerminalUIButton.new()
		file_btn.label_text = "FILE: " + file
		file_btn.command_to_execute = 'cat "%s"' % file
		file_btn.custom_data = {"type": "file", "name": file}
		terminal.push_widget_to_output(file_btn)


func usage() -> Array[String]:
	return [
		"Ls - List directory.",
		"USAGE:",
		"Takes no arguments.",
		"Prints all directories and files in the current path"
	]
