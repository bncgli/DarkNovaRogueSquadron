extends TerminalCommand


func _init() -> void:
	call_name = "echo"


func execute(terminal: Terminal, args: Array[String]) -> void:
	# Controlla redirezione '>' o '>>'
	var redirect_idx := -1
	for i in range(args.size()):
		if args[i] == ">" or args[i] == ">>":
			redirect_idx = i
			break
			
	if redirect_idx != -1:
		if redirect_idx >= args.size() - 1:
			terminal.push_line_to_output("Syntax error: missing target file after redirection.")
			return
		var text_tokens := args.slice(0, redirect_idx)
		var target_file := args[redirect_idx + 1]
		var content := " ".join(text_tokens).strip_edges()
		
		var current_path: String = terminal.virtual_path_manager.get_path()
		if current_path != "" and current_path[-1] != '/':
			current_path += '/'
		var full_target := target_file if target_file.begins_with("/") else (current_path + target_file)
		
		if VirtualSysfsDriver.is_sysfs_path(full_target):
			var sysfs := terminal.virtual_path_manager._get_sysfs()
			var res := sysfs.write_file(full_target, content)
			if not res.get("success", false):
				terminal.push_line_to_output("Errore: %s" % res.get("error", "Write failed"))
			return
		else:
			var abs_path := terminal.virtual_path_manager._get_real_path(full_target)
			var file := FileAccess.open(abs_path, FileAccess.WRITE)
			if file:
				file.store_string(content)
				file.close()
			return

	var output: String = ""
	for arg: String in args:
		output += arg + " "
	
	# Remove all non-printable characters from the edges of the string. 
	output = output.strip_edges()
	
	terminal.push_line_to_output(output)


func usage() -> Array[String]:
	return [
		"Echo - Prints text to the terminal.",
		"USAGE:",
		"Expects zero or more arguments.",
		"Prints all given arguments as one line in the terminal."
	]
