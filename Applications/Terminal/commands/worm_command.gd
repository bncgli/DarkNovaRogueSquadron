extends TerminalCommand

var target_folder: String = ""
var target_password: String = ""
var max_attempts: int = 6
var current_attempt: int = 1


func _init() -> void:
	call_name = "worm"


func execute(terminal: Terminal, args: Array[String]) -> void:
	if args.size() != 1:
		terminal.push_line_to_output(
			"Invalid number of arguments, expected 1, found %s." % [args.size()]
		)
		terminal.push_lines_to_output(usage())
		return
	
	var current_path: String = terminal.virtual_path_manager.get_path()
	var folder_arg: String = args[0].strip_edges()
	var folder_path: String = ""
	
	if folder_arg.begins_with("/"):
		folder_path = folder_arg.simplify_path().trim_prefix("/").trim_suffix("/")
	else:
		if current_path != "":
			folder_path = current_path.path_join(folder_arg).simplify_path().trim_prefix("/").trim_suffix("/")
		else:
			folder_path = folder_arg.simplify_path().trim_prefix("/").trim_suffix("/")
	
	if not terminal.virtual_path_manager.path_is_valid_folder(folder_path):
		terminal.push_line_to_output("Errore: Cartella '%s' non trovata o e' un file." % [folder_path])
		return
	
	var fpm: FolderPasswordManagerSingleton = terminal.get_node_or_null("/root/FolderPasswordManager")
	if not fpm or not fpm.has_password(folder_path):
		terminal.push_line_to_output("La cartella '%s' non e' protetta da password." % [folder_path])
		return
	
	target_folder = folder_path
	target_password = fpm.get_password(folder_path)
	max_attempts = 6
	current_attempt = 1
	
	terminal.push_line_to_output("[WORM V1.0] Inizializzazione breach pattern su '%s'..." % [target_folder])
	terminal.push_line_to_output("Password rilevata: %d caratteri. Tentativi a disposizione: %d." % [target_password.length(), max_attempts])
	terminal.push_line_to_output("Digita un tentativo (oppure 'exit'/'quit' per annullare):")
	terminal.active_interactive_command = self


func handle_interactive_input(terminal: Terminal, input: String) -> void:
	var guess: String = input.strip_edges()
	if guess.to_lower() in ["exit", "quit", "cancel", "abort"]:
		terminal.push_line_to_output("[WORM] Sessione breach terminata dall'utente.")
		terminal.active_interactive_command = null
		return
	
	var exact: int = 0
	var misplaced: int = 0
	var secret: String = target_password
	var min_len: int = mini(secret.length(), guess.length())
	
	var matched_secret: Array[bool] = []
	matched_secret.resize(secret.length())
	matched_secret.fill(false)
	
	var matched_guess: Array[bool] = []
	matched_guess.resize(guess.length())
	matched_guess.fill(false)
	
	for i in range(min_len):
		if secret[i] == guess[i]:
			exact += 1
			matched_secret[i] = true
			matched_guess[i] = true
	
	for i in range(guess.length()):
		if matched_guess[i]:
			continue
		for j in range(secret.length()):
			if not matched_secret[j] and guess[i] == secret[j]:
				misplaced += 1
				matched_secret[j] = true
				matched_guess[j] = true
				break
	
	terminal.push_line_to_output('TENTATIVO [%d/%d]: "%s" -> ESATTI: %d | DISLOCATI: %d' % [current_attempt, max_attempts, guess, exact, misplaced])
	
	if guess == target_password:
		terminal.push_line_to_output("[ACCESSO CONFERMATO] Password cartella violata con successo: %s" % [target_password])
		var fpm: FolderPasswordManagerSingleton = terminal.get_node_or_null("/root/FolderPasswordManager")
		if fpm:
			fpm.remove_password(target_folder)
		terminal.active_interactive_command = null
		return
	
	if current_attempt >= max_attempts:
		terminal.push_line_to_output("[ERRORE] Tentativi esauriti. Violazione di sicurezza fallita per '%s'." % [target_folder])
		terminal.active_interactive_command = null
		return
	
	current_attempt += 1
	terminal.push_line_to_output("Tentativi rimasti: %d. Prossimo tentativo:" % [max_attempts - current_attempt + 1])


func usage() -> Array[String]:
	return [
		"worm - Esegue un attacco Mastermind per forzare la password di una cartella.",
		"USAGE:",
		"  worm <nome_cartella>",
		"Esempio:",
		"  worm 'Terminal Drive/systems'"
	]
