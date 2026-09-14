extends GutTest

## Unit tests for RegEx parsing, tokenization, flags, and regex command dispatching.

func test_parser_quotes_and_flags() -> void:
	var parser := TerminalInputParser.new()
	var outputs := parser.parse('cat "my file with spaces.txt" --verbose --mode=fast -x -abc')
	assert_eq(outputs.size(), 1, "Deve produrre esattamente 1 output di comando")
	
	var out: TerminalParserOutput = outputs[0]
	assert_eq(out.command_call_name, "cat", "Il nome del comando deve essere 'cat'")
	assert_eq(out.command_args.size(), 1, "Deve contenere 1 argomento posizionale")
	assert_eq(out.command_args[0], "my file with spaces.txt", "Le virgolette devono preservare gli spazi e rimosse")
	assert_true(out.has_flag("verbose"), "La flag --verbose deve essere presente")
	assert_eq(out.get_flag("mode"), "fast", "La flag --mode deve valere 'fast'")
	assert_true(out.has_flag("x"), "La flag -x deve essere presente")
	assert_true(out.has_flag("a"), "La flag -a deve essere estratta da -abc")
	assert_true(out.has_flag("b"), "La flag -b deve essere estratta da -abc")
	assert_true(out.has_flag("c"), "La flag -c deve essere estratta da -abc")

func test_parser_command_chaining_with_quotes() -> void:
	var parser := TerminalInputParser.new()
	var outputs := parser.parse('echo "part 1 && still part 1" && ls --all')
	assert_eq(outputs.size(), 2, "La concatenazione con && fuori dalle virgolette deve separare 2 comandi")
	assert_eq(outputs[0].command_call_name, "echo")
	assert_eq(outputs[0].command_args[0], "part 1 && still part 1", "I doppi && interni alle virgolette non devono essere divisi")
	assert_eq(outputs[1].command_call_name, "ls")
	assert_true(outputs[1].has_flag("all"))

func test_regex_command_matching_and_dispatch() -> void:
	var cmd_manager := TerminalCommandManager.new()
	
	var custom_cmd := TerminalCommand.new()
	custom_cmd.call_name = "test_regex_calc"
	custom_cmd.regex_pattern = r"^calc\s+(?P<a>\d+)\+(?P<b>\d+)$"
	cmd_manager.register_command(custom_cmd)
	
	var res := cmd_manager.find_command("calc 10+20")
	assert_not_null(res.get("command"), "Il comando regex deve essere trovato")
	var match_res: RegExMatch = res.get("regex_match")
	assert_not_null(match_res, "Il RegExMatch deve essere presente")
	assert_eq(match_res.get_string("a"), "10", "Gruppo 'a' catturato correttamente")
	assert_eq(match_res.get_string("b"), "20", "Gruppo 'b' catturato correttamente")
	
	# Verifica priorità matching esatto
	var exact_cmd := TerminalCommand.new()
	exact_cmd.call_name = "calc"
	cmd_manager.register_command(exact_cmd)
	
	var res_exact := cmd_manager.find_command("calc")
	assert_eq(res_exact.get("command"), exact_cmd, "Il match esatto ha priorità sul pattern regex")
	assert_null(res_exact.get("regex_match"), "Per match esatto il regex_match è null")
