extends TerminalCommand

## Comando 'pod' per avviare l'applicazione PodInfo.
## Registrato in Applications/Terminal/commands/.

func _init() -> void:
	call_name = "pod"

func execute(terminal: Terminal, _args: Array[String]) -> void:
	# Recupera il manager dei software tramite l'autoload
	var tsm := terminal.get_node_or_null("/root/TerminalSoftwareManager")
	if tsm:
		if tsm.has_method("launch_app"):
			tsm.launch_app("pod_info")
			terminal.push_line_to_output("Inizializzazione PodInfo biometrics...")
		else:
			terminal.push_line_to_output("Errore: Metodo launch_app non trovato in TerminalSoftwareManager.")
	else:
		terminal.push_line_to_output("Errore: TerminalSoftwareManager non accessibile.")

func usage() -> Array[String]:
	return [
		"pod - Monitoraggio bioconnessione e parametri vitali del pilota.",
		"USAGE:",
		"  pod"
	]
