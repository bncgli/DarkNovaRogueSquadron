extends TerminalCommand

## Interactive demo command showcasing the Terminal TUI framework.

func _init() -> void:
	call_name = "tui"


func execute(terminal: Terminal, args: Array[String]) -> void:
	if args.has("overlay") or args.has("--overlay"):
		var overlay := TerminalUIOverlay.new()
		overlay.overlay_title = "SYSTEM DIAGNOSTICS CONTROL PANEL"
		
		var card := TerminalUICard.new()
		card.card_title = "REACTOR STATUS"
		card.body_text = "Core Temperature: 450 K\nMagnetic Containment: STABLE (99.8%)\nCoolant Flow Rate: 12.4 L/s"
		overlay.add_content(card)
		
		var opts := TerminalUIOptions.new()
		opts.set_options([
			{"title": "Run Diagnostic Scan", "description": "Verify subsystem integrity", "command": "echo Diagnostic scan completed. All systems nominal."},
			{"title": "Purge System Cache", "description": "Flush temporary memory buffers", "command": "echo Cache flushed."},
			{"title": "Close Control Panel", "description": "Return to command line", "command": ""}
		], "AVAILABLE ACTIONS")
		
		opts.option_selected.connect(func(_idx: int, opt: Dictionary) -> void:
			if opt.get("title") == "Close Control Panel":
				terminal.close_tui_overlay()
		)
		
		overlay.add_content(opts)
		terminal.open_tui_overlay(overlay)
		return
	
	# Inline stream TUI demo
	var card := TerminalUICard.new()
	card.card_title = "GODOTOS TUI DEMO"
	card.body_text = "Welcome to the interactive diegetic TUI framework.\nClick the options below using your mouse or trigger commands."
	
	var opts := TerminalUIOptions.new()
	opts.set_options([
		{"title": "List Directory Contents", "description": "Execute 'ls' with clickable file entries", "command": "ls"},
		{"title": "Launch Diagnostics Overlay", "description": "Open full-screen modal TUI view", "command": "tui overlay"},
		{"title": "Print System Date", "description": "Execute 'date' command", "command": "date"}
	], "SELECT ACTION")
	
	card.add_body_widget(opts)
	terminal.push_widget_to_output(card)


func usage() -> Array[String]:
	return [
		"tui - Demonstrates interactive diegetic TUI widgets.",
		"USAGE:",
		"  tui          Show inline interactive card with buttons and options.",
		"  tui overlay  Open full-screen modal overlay dashboard."
	]
