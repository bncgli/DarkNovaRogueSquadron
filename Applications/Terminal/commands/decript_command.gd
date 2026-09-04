extends TerminalCommand

const STANDARD_PHRASE: String = "the quick brown fox jumps over the lazy dog"

var target_file: String = ""
var target_key: String = ""
var shift: int = 4
var cipher_map: Dictionary = {}
var inv_cipher_map: Dictionary = {}
var revealed_chars: Dictionary = {}


func _init() -> void:
	call_name = "decript"


func execute(terminal: Terminal, args: Array[String]) -> void:
	if args.size() != 1:
		terminal.push_line_to_output(
			"Invalid number of arguments, expected 1, found %s." % [args.size()]
		)
		terminal.push_lines_to_output(usage())
		return
	
	var file_arg: String = args[0].strip_edges()
	if not file_arg.ends_with(".dat"):
		terminal.push_line_to_output("Errore: Il file '%s' non e' un file .dat." % [file_arg])
		return
	
	var current_path: String = terminal.virtual_path_manager.get_path()
	var file_path: String = ""
	if file_arg.begins_with("/"):
		file_path = file_arg.simplify_path().trim_prefix("/").trim_suffix("/")
	else:
		if current_path != "":
			file_path = current_path.path_join(file_arg).simplify_path().trim_prefix("/").trim_suffix("/")
		else:
			file_path = file_arg.simplify_path().trim_prefix("/").trim_suffix("/")
	
	var abs_path: String = "user://files/%s" % file_path
	if not FileAccess.file_exists(abs_path) and not terminal.virtual_path_manager.path_is_valid_file(file_path):
		terminal.push_line_to_output("Errore: File '%s' non trovato." % [file_path])
		return
	
	var file: FileAccess = FileAccess.open(abs_path, FileAccess.READ)
	if not file:
		terminal.push_line_to_output("Errore: Impossibile leggere il file '%s'." % [file_path])
		return
	
	var dat_content: String = file.get_as_text()
	file.close()
	
	var parsed_key: String = _extract_decryption_key(dat_content)
	if parsed_key.is_empty():
		terminal.push_line_to_output("Errore: Impossibile trovare 'decryption_key' nel file '%s'." % [file_path])
		return
	
	target_file = file_path
	target_key = parsed_key
	revealed_chars = {}
	
	# Svela automaticamente caratteri non alfanumerici (come '-' o spazi)
	for i in range(target_key.length()):
		var c: String = target_key[i]
		if not c.is_empty() and not ((c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or (c >= "0" and c <= "9")):
			revealed_chars[c.to_upper()] = true
	
	_setup_cipher()
	
	terminal.push_line_to_output("[DECRIPT V1.0] Inizializzazione decodifica del file '%s'..." % [target_file])
	terminal.push_line_to_output("Frase intercettata:")
	terminal.push_line_to_output("  " + _get_displayed_phrase())
	terminal.push_line_to_output("Stato chiave: " + _get_key_display())
	terminal.push_line_to_output("Inserisci un carattere o la chiave completa (oppure 'exit'/'quit' per annullare):")
	terminal.active_interactive_command = self


func _extract_decryption_key(content: String) -> String:
	var lines: PackedStringArray = content.split("\n")
	for line: String in lines:
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("decryption_key"):
			var eq_idx: int = trimmed.find("=")
			if eq_idx != -1:
				var val: String = trimmed.substr(eq_idx + 1).strip_edges()
				if (val.begins_with("\"") and val.ends_with("\"")) or (val.begins_with("'") and val.ends_with("'")):
					val = val.substr(1, val.length() - 2).strip_edges()
				return val
	return ""


func _setup_cipher() -> void:
	var sum_val: int = 0
	for i in range(target_key.length()):
		sum_val += target_key.unicode_at(i)
	shift = (sum_val % 25) + 1
	
	cipher_map.clear()
	inv_cipher_map.clear()
	for i in range(26):
		var plain_c: String = String.chr(97 + i)
		var cipher_c: String = String.chr(97 + ((i + shift) % 26))
		cipher_map[plain_c] = cipher_c
		inv_cipher_map[cipher_c] = plain_c


func _is_key_fully_revealed() -> bool:
	for i in range(target_key.length()):
		var c: String = target_key[i].to_upper()
		if not revealed_chars.has(c):
			return false
	return true


func _get_key_display() -> String:
	var out: String = ""
	for i in range(target_key.length()):
		var c: String = target_key[i]
		if revealed_chars.has(c.to_upper()):
			out += c
		else:
			out += "_"
	return out


func _get_displayed_phrase() -> String:
	if _is_key_fully_revealed():
		return STANDARD_PHRASE
	
	var out: String = ""
	for i in range(STANDARD_PHRASE.length()):
		var c: String = STANDARD_PHRASE[i]
		if c == " ":
			out += " "
		else:
			var cipher_c: String = cipher_map.get(c, c)
			if revealed_chars.has(c.to_upper()) or revealed_chars.has(c):
				out += c
			else:
				out += cipher_c
	return out


func handle_interactive_input(terminal: Terminal, input: String) -> void:
	var guess: String = input.strip_edges()
	if guess.to_lower() in ["exit", "quit", "cancel", "abort"]:
		terminal.push_line_to_output("[DECRIPT] Sessione di decodifica interrotta dall'utente.")
		terminal.active_interactive_command = null
		return
	
	if guess.to_upper() == target_key.to_upper():
		for i in range(target_key.length()):
			revealed_chars[target_key[i].to_upper()] = true
	else:
		var found_any: bool = false
		for i in range(guess.length()):
			var c: String = guess[i].to_upper()
			if target_key.to_upper().contains(c):
				revealed_chars[c] = true
				found_any = true
		if not found_any:
			terminal.push_line_to_output("Carattere/i non presente/i nella chiave.")
	
	if _is_key_fully_revealed():
		terminal.push_line_to_output("Frase decifrata: " + STANDARD_PHRASE)
		terminal.push_line_to_output("[CHIAVE DECRIPTAZIONE IDENTIFICATA: %s]" % [target_key])
		_save_key_to_drive(target_file, target_key)
		terminal.active_interactive_command = null
		return
	
	terminal.push_line_to_output("Frase corrente: " + _get_displayed_phrase())
	terminal.push_line_to_output("Stato chiave:   " + _get_key_display())
	terminal.push_line_to_output("Inserisci prossimo tentativo:")


func _save_key_to_drive(file_rel: String, key_val: String) -> void:
	var log_dir: String = "user://files/Terminal Drive"
	if DirAccess.dir_exists_absolute(log_dir):
		var log_path: String = log_dir + "/decrypted_keys.txt"
		var mode := FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE
		var file := FileAccess.open(log_path, mode)
		if file:
			file.seek_end()
			file.store_line("[%s] %s -> %s" % [Time.get_datetime_string_from_system(), file_rel, key_val])
			file.close()


func usage() -> Array[String]:
	return [
		"decript - Avvia il minigioco di decodifica cifrata per scoprire la chiave di un file .dat.",
		"USAGE:",
		"  decript <file.dat>",
		"Esempio:",
		"  decript 'Terminal Drive/systems/terminal_config.dat'"
	]
