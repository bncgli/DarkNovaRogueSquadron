extends TerminalCommand


func _init() -> void:
	call_name = "cat"


func execute(terminal: Terminal, args: Array[String]) -> void:
	if args.size() == 0 or args.size() > 1:
		terminal.push_line_to_output(
			"Invalid number of arguments, expected 1, found %s." % [args.size()]
		)
		return
	
	var current_path: String = terminal.virtual_path_manager.get_path()
	if current_path != "" and current_path[-1] != '/':
		current_path += '/'
	
	var file_path: String = args[0] if args[0].begins_with("/") else (current_path + args[0])
	
	if VirtualSysfsDriver.is_sysfs_path(file_path):
		var sysfs := terminal.virtual_path_manager._get_sysfs()
		if sysfs.is_valid_file(file_path):
			var content := sysfs.read_file(file_path)
			terminal.push_line_to_output(content)
		else:
			terminal.push_line_to_output(file_path + " does not exist or is a folder.")
		return

	if file_path.ends_with(".dat"):
		terminal.push_line_to_output("Errore: I file .dat sono file di configurazione binari/protetti e non sono leggibili dal visualizzatore di testo standard.")
		return
	
	if terminal.virtual_path_manager.path_is_valid_file(file_path):
		var file: FileAccess = terminal.virtual_path_manager.open_file(file_path, FileAccess.READ)
		var file_text: PackedStringArray = file.get_as_text().split("\n")
		
		for line: String in file_text:
			terminal.push_line_to_output(line)
	else:
		terminal.push_line_to_output(file_path + " does not exist or is a folder.")


func usage() -> Array[String]:
	return [
		"Cat - Prints all lines of a file.",
		"USAGE:",
		"Takes one argument, a valid .txt file name",
		"then pushes it to the terminal, line by line."
	]
