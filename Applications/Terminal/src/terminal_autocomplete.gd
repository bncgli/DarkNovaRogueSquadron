class_name TerminalAutoComplete
## Autocomplete engine for GodotOS Terminal.
## Handles tab completion for commands and file/directory paths with LCP and ambiguity handling.


## Computes the Longest Common Prefix (LCP) of an array of strings.
static func get_longest_common_prefix(strings: Array[String]) -> String:
	if strings.is_empty():
		return ""
	if strings.size() == 1:
		return strings[0]
	
	var prefix: String = strings[0]
	for i in range(1, strings.size()):
		var s: String = strings[i]
		var common_len: int = 0
		var max_len: int = mini(prefix.length(), s.length())
		while common_len < max_len and prefix[common_len] == s[common_len]:
			common_len += 1
		prefix = prefix.substr(0, common_len)
		if prefix.is_empty():
			break
	return prefix


## Computes autocomplete suggestions based on current input and caret position.
static func autocomplete(
	input_text: String,
	caret_position: int,
	command_names: Array[String],
	virtual_path_manager: VirtualPathManager
) -> Dictionary:
	var prefix_text: String = input_text.substr(0, caret_position)
	var suffix_text: String = input_text.substr(caret_position)
	
	# Determine if within quotes
	var double_quote_count: int = prefix_text.count('"')
	var single_quote_count: int = prefix_text.count("'")
	
	var is_quoted: bool = false
	var quote_char: String = ""
	var before_token: String = ""
	var token: String = ""
	
	if double_quote_count % 2 == 1:
		is_quoted = true
		quote_char = '"'
		var last_q: int = prefix_text.rfind('"')
		before_token = prefix_text.substr(0, last_q)
		token = prefix_text.substr(last_q + 1)
	elif single_quote_count % 2 == 1:
		is_quoted = true
		quote_char = "'"
		var last_q: int = prefix_text.rfind("'")
		before_token = prefix_text.substr(0, last_q)
		token = prefix_text.substr(last_q + 1)
	else:
		if prefix_text.ends_with(" "):
			before_token = prefix_text
			token = ""
		else:
			var last_space: int = prefix_text.rfind(" ")
			if last_space == -1:
				before_token = ""
				token = prefix_text
			else:
				before_token = prefix_text.substr(0, last_space + 1)
				token = prefix_text.substr(last_space + 1)
	
	var is_command_mode: bool = before_token.strip_edges().is_empty() and not is_quoted
	var candidates: Array[String] = []
	
	if is_command_mode:
		for cmd_name: String in command_names:
			if cmd_name.to_lower().begins_with(token.to_lower()):
				candidates.append(cmd_name)
		candidates.sort()
	else:
		var base_folder: String = ""
		var search_prefix: String = token
		if "/" in token:
			var last_slash: int = token.rfind("/")
			base_folder = token.substr(0, last_slash)
			search_prefix = token.substr(last_slash + 1)
		
		var current_virt: String = ""
		if virtual_path_manager != null:
			current_virt = virtual_path_manager.get_path()
		
		var target_virt: String = current_virt
		if not base_folder.is_empty():
			if target_virt.is_empty():
				target_virt = base_folder
			else:
				target_virt = target_virt.path_join(base_folder)
		
		var dirs: PackedStringArray = PackedStringArray()
		var files: PackedStringArray = PackedStringArray()
		
		if virtual_path_manager != null and virtual_path_manager.path_is_valid_folder(target_virt):
			dirs = virtual_path_manager.list_directories(target_virt)
			files = virtual_path_manager.list_files(target_virt)
		
		for d: String in dirs:
			if d.to_lower().begins_with(search_prefix.to_lower()):
				var cand: String = d + "/"
				if not base_folder.is_empty():
					cand = base_folder + "/" + cand
				candidates.append(cand)
		
		for f: String in files:
			if f.to_lower().begins_with(search_prefix.to_lower()):
				var cand: String = f
				if not base_folder.is_empty():
					cand = base_folder + "/" + cand
				candidates.append(cand)
		
		candidates.sort()
	
	if candidates.is_empty():
		return {
			"new_text": input_text,
			"new_caret_position": caret_position,
			"candidates": candidates,
			"is_ambiguous": false,
			"completed": false
		}
	
	if candidates.size() == 1:
		var cand: String = candidates[0]
		var needs_quotes: bool = (" " in cand) and not is_quoted
		var completed_token: String = cand
		
		var insertion: String = ""
		if is_command_mode:
			insertion = completed_token + " "
		else:
			if completed_token.ends_with("/"):
				if needs_quotes:
					insertion = '"' + completed_token + '"'
				elif is_quoted:
					insertion = quote_char + completed_token + quote_char
				else:
					insertion = completed_token
			else:
				if needs_quotes:
					insertion = '"' + completed_token + '" '
				elif is_quoted:
					insertion = quote_char + completed_token + quote_char + " "
				else:
					insertion = completed_token + " "
		
		var new_text: String = before_token + insertion + suffix_text
		var new_pos: int = (before_token + insertion).length()
		return {
			"new_text": new_text,
			"new_caret_position": new_pos,
			"candidates": candidates,
			"is_ambiguous": false,
			"completed": true
		}
	
	# Multiple candidates: Ambiguous
	var lcp: String = get_longest_common_prefix(candidates)
	var completed: bool = false
	var new_text: String = input_text
	var new_pos: int = caret_position
	
	if lcp.length() > token.length():
		completed = true
		var insertion: String = ""
		if is_quoted:
			insertion = quote_char + lcp
		else:
			insertion = lcp
		new_text = before_token + insertion + suffix_text
		new_pos = (before_token + insertion).length()
	
	return {
		"new_text": new_text,
		"new_caret_position": new_pos,
		"candidates": candidates,
		"is_ambiguous": true,
		"completed": completed
	}
