extends TerminalCommand
class_name TerminalAppCommand
## CLI command to launch additional instances of the terminal shell.

func _init() -> void:
	call_name = "terminal"
	regex_pattern = r"^term$"


func execute(terminal: Terminal, args: Array[String]) -> void:
	var target_path: String = ""
	if args.size() > 0:
		target_path = args[0]
	
	var sw_mgr: Node = terminal.get_node_or_null("/root/TerminalSoftwareManager")
	if sw_mgr == null:
		terminal.push_line_to_output("Error: TerminalSoftwareManager not found.")
		return
	
	var new_window = sw_mgr.launch_app("terminal")
	if new_window == null:
		terminal.push_line_to_output("Error: Could not launch terminal instance.")
		return
	
	terminal.push_line_to_output("Launched new terminal window.")
	
	if not target_path.is_empty():
		var contents = new_window.get_node_or_null("%ApplicationContents")
		if contents != null:
			for child in contents.get_children():
				if child is Terminal:
					if child.virtual_path_manager.path_is_valid_folder(target_path):
						child.virtual_path_manager.set_path(target_path)
						child.update_window_title()
					break


func usage() -> Array[String]:
	return [
		"terminal - Launches a new terminal shell instance.",
		"USAGE:",
		"  terminal          Launch a new terminal window at default location.",
		"  terminal [path]   Launch a new terminal window initialized at path.",
		"ALIAS:",
		"  term"
	]
