extends Resource
class_name TerminalCommand
## Base class that all commands need inherit from.
##
## If not setup correctly the program will [b]CRASH[/b].

## Name used to match user input with a command.
var call_name: String = ""

## Optional regular expression pattern for matching user input.
var regex_pattern: String = ""

## Compiled RegEx object (can be set directly or generated from regex_pattern).
var regex: RegEx = null

## The last RegExMatch produced when this command matched input.
var last_regex_match: RegExMatch = null


## Called when the command is instantiated.[br]
## Used to setup command properties, like [param call_name] for example.
func _init() -> void:
	pass


## Returns or compiles the RegEx instance for this command.
func get_regex() -> RegEx:
	if regex != null:
		return regex
	if not regex_pattern.is_empty():
		var r := RegEx.new()
		if r.compile(regex_pattern) == OK:
			regex = r
			return regex
	return null


## Checks if the input matches this command's regular expression.
func matches_input(input_str: String) -> RegExMatch:
	var r: RegEx = get_regex()
	if r != null:
		return r.search(input_str)
	return null


## The main entry point of the command, all core logic goes here.
@warning_ignore("unused_parameter")
func execute(terminal: Terminal, args: Array[String]) -> void:
	assert(false, "Not implemented, the command main code goes here")


## Entry point when invoked through a regular expression match.
## Passes the RegExMatch object along with raw arguments.
@warning_ignore("unused_parameter")
func execute_regex(terminal: Node, match: RegExMatch, raw_args: PackedStringArray) -> void:
	last_regex_match = match
	var args_array: Array[String] = []
	for arg in raw_args:
		args_array.append(arg)
	if terminal is Terminal:
		execute(terminal as Terminal, args_array)


## Called by "help" command or arbitrary by the command itself.
func usage() -> Array[String]:
	assert(false, "Not implemented, the command usage instructions goes here")
	
	return []


## Called when an interactive session is active and user submits text.
@warning_ignore("unused_parameter")
func handle_interactive_input(terminal: Terminal, input: String) -> void:
	pass
