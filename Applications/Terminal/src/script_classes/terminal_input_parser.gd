class_name TerminalInputParser
## Utility class used for sanitizing and parsing Strings with RegEx support.
##
## Example:
## [codeblock]
## var parser := TerminalInputParser.new()
## var outputs: Array[TerminalParserOutput] = parser.parse("echo hello && echo world")
##
## print(outputs[0].command_call_name) # prints "echo"
## print(outputs[0].command_args)      # prints ["hello"]
## print(outputs[1].command_args)      # prints ["world"]
## [/codeblock]

## RegEx pattern for extracting tokens, including flags, quoted strings, and words.
const TOKEN_REGEX_PATTERN: String = r'(--?[a-zA-Z0-9_\-]+=(?:"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'|\S+)|"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'|\S+)'

var _token_regex: RegEx


func _init() -> void:
	_token_regex = RegEx.new()
	_token_regex.compile(TOKEN_REGEX_PATTERN)


## Splits the input string on '&&' delimiters that are outside of quotes.
func split_commands(input: String) -> PackedStringArray:
	var commands: PackedStringArray = []
	var current: String = ""
	var in_double_quote: bool = false
	var in_single_quote: bool = false
	var i: int = 0
	var total_len: int = input.length()
	
	while i < total_len:
		var c: String = input[i]
		if c == "\\" and i + 1 < total_len:
			current += c + input[i + 1]
			i += 2
			continue
		elif c == '"' and not in_single_quote:
			in_double_quote = not in_double_quote
			current += c
		elif c == "'" and not in_double_quote:
			in_single_quote = not in_single_quote
			current += c
		elif c == "&" and not in_double_quote and not in_single_quote:
			if i + 1 < total_len and input[i + 1] == "&":
				var trimmed := current.strip_edges()
				if not trimmed.is_empty():
					commands.append(trimmed)
				current = ""
				i += 2
				continue
			else:
				current += c
		else:
			current += c
		i += 1
	
	var final_trimmed := current.strip_edges()
	if not final_trimmed.is_empty():
		commands.append(final_trimmed)
	
	return commands


## Unescapes backslash-escaped characters in a string.
func unescape_string(s: String) -> String:
	return s.replace('\\"', '"').replace("\\'", "'").replace("\\\\", "\\")


## Strips enclosing quotes and unescapes internal characters.
func clean_token_value(token: String) -> String:
	if token.length() >= 2:
		if (token.begins_with('"') and token.ends_with('"')) or (token.begins_with("'") and token.ends_with("'")):
			return unescape_string(token.substr(1, token.length() - 2))
	return unescape_string(token)


## Sanitize and parse the given String, returning all founded commands.
func parse(input: String) -> Array[TerminalParserOutput]:
	if input.strip_edges().is_empty():
		return []
	
	var sub_inputs: PackedStringArray = split_commands(input)
	var outputs: Array[TerminalParserOutput] = []
	
	for inp: String in sub_inputs:
		var matches: Array[RegExMatch] = _token_regex.search_all(inp)
		if matches.is_empty():
			continue
		
		var raw_tokens: Array[String] = []
		for m: RegExMatch in matches:
			raw_tokens.append(m.get_string())
		
		if raw_tokens.is_empty():
			continue
		
		var call_name: String = clean_token_value(raw_tokens[0])
		var positional_args: Array[String] = []
		var flags: Dictionary = {}
		var raw_args: PackedStringArray = PackedStringArray()
		var only_positional: bool = false
		
		for idx in range(1, raw_tokens.size()):
			var token: String = raw_tokens[idx]
			raw_args.append(token)
			
			if only_positional:
				positional_args.append(clean_token_value(token))
				continue
			
			if token == "--":
				only_positional = true
				continue
			
			if token.begins_with("--"):
				if "=" in token:
					var eq_idx: int = token.find("=")
					var key: String = token.substr(2, eq_idx - 2)
					var val: String = clean_token_value(token.substr(eq_idx + 1))
					flags[key] = val
				else:
					var key: String = token.substr(2)
					flags[key] = true
			elif token.begins_with("-") and token.length() > 1 and not (token.is_valid_float() or token.is_valid_int()):
				if "=" in token:
					var eq_idx: int = token.find("=")
					var key: String = token.substr(1, eq_idx - 1)
					var val: String = clean_token_value(token.substr(eq_idx + 1))
					flags[key] = val
				elif token.length() == 2:
					flags[token.substr(1)] = true
				else:
					flags[token.substr(1)] = true
					for c_idx in range(1, token.length()):
						flags[token[c_idx]] = true
			else:
				positional_args.append(clean_token_value(token))
		
		outputs.append(
			TerminalParserOutput.new(
				call_name,
				positional_args,
				flags,
				raw_args,
				inp
			)
		)
	
	return outputs
