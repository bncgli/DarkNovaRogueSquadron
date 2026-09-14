class_name TerminalCommandManager
## Utility class for working with terminal commands.
##
## Example:
## [codeblock]
## var cmd_manager := TerminalCommandManager.new()
## var echo_cmd: TerminalCommand = cmd_manager.load_command("echo")
## echo_cmd.execute(terminal, args)
## [/codeblock]

## Path to a folder containing all command scripts.
const COMMANDS_DIR: String = "res://Applications/Terminal/commands/"

## Map of call_name -> GDScript for standard commands.
var _commands: Dictionary = {}

## Map of call_name -> TerminalCommand for dynamically registered commands.
var _custom_commands: Dictionary = {}

## List of commands that define regex patterns.
var _regex_commands: Array[TerminalCommand] = []

## Whether built-in commands have been scanned and indexed.
var _loaded: bool = false


func _init() -> void:
	_ensure_commands_loaded()


## Ensures that all command scripts in COMMANDS_DIR are scanned and indexed.
func _ensure_commands_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	
	for cmd_file: String in get_commands_folder_contents():
		var script_res: Resource = load(COMMANDS_DIR + cmd_file)
		if script_res == null or not script_res is GDScript:
			continue
		
		var instance = script_res.new()
		if instance is TerminalCommand:
			if not instance.call_name.is_empty():
				_commands[instance.call_name] = script_res
			if instance.get_regex() != null or not instance.regex_pattern.is_empty() or instance.regex != null:
				_regex_commands.append(instance)


## Registers a TerminalCommand instance manually (e.g. at runtime or from tests).
func register_command(cmd: TerminalCommand) -> void:
	_ensure_commands_loaded()
	if not cmd.call_name.is_empty():
		_custom_commands[cmd.call_name] = cmd
	if (cmd.get_regex() != null or not cmd.regex_pattern.is_empty() or cmd.regex != null) and not _regex_commands.has(cmd):
		_regex_commands.append(cmd)


## Unregisters a command by call name.
func unregister_command(command_call_name: String) -> void:
	_ensure_commands_loaded()
	if _custom_commands.has(command_call_name):
		var cmd: TerminalCommand = _custom_commands[command_call_name]
		_regex_commands.erase(cmd)
		_custom_commands.erase(command_call_name)
	if _commands.has(command_call_name):
		_commands.erase(command_call_name)


## Returns an array of all active commands supporting regex patterns.
func get_regex_commands() -> Array[TerminalCommand]:
	_ensure_commands_loaded()
	return _regex_commands


## Searches for a matching command, checking exact call_name first, then regex patterns.
## Returns a Dictionary with keys {"command": TerminalCommand, "regex_match": RegExMatch}.
func find_command(command_str: String) -> Dictionary:
	_ensure_commands_loaded()
	
	if cmd_exists(command_str):
		return {
			"command": load_command(command_str),
			"regex_match": null
		}
	
	for regex_cmd: TerminalCommand in _regex_commands:
		var match_result: RegExMatch = regex_cmd.matches_input(command_str)
		if match_result != null:
			return {
				"command": regex_cmd,
				"regex_match": match_result
			}
	
	return {
		"command": null,
		"regex_match": null
	}


## Returns an instance of the command whose call_name matches given command_call_name.
## The program will assert if an invalid call_name is given; check cmd_exists() first.
func load_command(command_call_name: String) -> TerminalCommand:
	_ensure_commands_loaded()
	
	if _custom_commands.has(command_call_name):
		return _custom_commands[command_call_name]
	
	if _commands.has(command_call_name):
		var script_res: GDScript = _commands[command_call_name]
		return script_res.new()
	
	# Fallback search directly in folder if newly created
	for cmd_file: String in get_commands_folder_contents():
		var cmd_res: Resource = load(COMMANDS_DIR + cmd_file)
		if cmd_res is GDScript:
			var instance = cmd_res.new()
			if instance is TerminalCommand and instance.call_name == command_call_name:
				_commands[command_call_name] = cmd_res
				return instance
	
	assert(false, "Trying to load an invalid command: %s" % [command_call_name])
	return null


## Returns a list of all valid command call_names.
func get_command_call_names() -> Array[String]:
	_ensure_commands_loaded()
	var names: Array[String] = []
	for name: String in _commands.keys():
		if not names.has(name):
			names.append(name)
	for name: String in _custom_commands.keys():
		if not names.has(name):
			names.append(name)
	return names


## Checks if a command with the given call_name is registered.
func cmd_exists(command_call_name: String) -> bool:
	_ensure_commands_loaded()
	return _custom_commands.has(command_call_name) or _commands.has(command_call_name)


## Returns a list with all valid command files found in COMMANDS_DIR.
func get_commands_folder_contents() -> PackedStringArray:
	var folder_contents: PackedStringArray = ResourceLoader.list_directory(COMMANDS_DIR)
	var filtered: PackedStringArray = PackedStringArray()
	
	for file in folder_contents:
		if file.ends_with(".gd") and file != "terminal_command.gd":
			filtered.append(file)
	
	return filtered
