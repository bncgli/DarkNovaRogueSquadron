class_name TerminalParserOutput
## A helper Class for TerminalInputParser.
##
## Is intended to be used only in the parser logic.[br]
## Example:
## [codeblock]
## var output := TerminalParserOutput.new("echo", ["hello", "world"])
## print(output.command_call_name)# prints "echo"
## print(output.command_args)# prints ["hello", "world"]
## [/codeblock]

## The name used for calling the command.
var command_call_name: String
## The arguments used in the command (positional arguments).
var command_args: Array[String]
## Positional arguments excluding parsed flags.
var positional_args: Array[String]
## Raw arguments before flag separation.
var raw_args: PackedStringArray
## Parsed named flags and boolean options (e.g. {"flag": true, "key": "value"}).
var flags: Dictionary
## The original command string before tokenization.
var raw_command: String


func _init(
	call_name: String = "",
	args: Array[String] = [],
	in_flags: Dictionary = {},
	in_raw_args: PackedStringArray = PackedStringArray(),
	in_raw_command: String = ""
) -> void:
	command_call_name = call_name
	command_args = args
	positional_args = args
	flags = in_flags
	if in_raw_args.is_empty():
		raw_args = PackedStringArray()
		for a in args:
			raw_args.append(a)
	else:
		raw_args = in_raw_args
	raw_command = in_raw_command


## Checks whether a flag was passed in this command.
func has_flag(flag_name: String) -> bool:
	return flags.has(flag_name)


## Returns the value of a flag or the default value if absent.
func get_flag(flag_name: String, default_value: Variant = null) -> Variant:
	return flags.get(flag_name, default_value)
