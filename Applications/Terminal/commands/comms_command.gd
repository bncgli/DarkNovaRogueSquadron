extends TerminalCommand

## Comando CLI 'comms' per il controllo dell'antenna direzionale, scansione frequenze e ascolto radio streaming.
## Verifica preventivamente lo stato di alimentazione dell'antenna subspaziale 'antenna_array'.

var listening_frequency: float = 1420.0
var _listening_terminal: Terminal = null
var _sample_packets: Array[String] = []
var _packet_index: int = 0

func _init() -> void:
	call_name = "comms"

func execute(terminal: Terminal, args: Array[String]) -> void:
	if args.is_empty() or args[0] in ["help", "-h", "--help"]:
		_print_help(terminal)
		return
		
	var subcmd := args[0].to_lower()
	var hal: ShipHAL = _get_hal(terminal)
	
	# Verifica alimentazione hardware antenna_array
	if hal and not hal.is_device_powered("antenna_array"):
		var st := hal.get_device_status("antenna_array")
		terminal.push_line_to_output("[color=#ff4040][ERRORE HARDWARE][/color] Dispositivo 'antenna_array' (%s) non alimentato. Ricetrasmettitore subspaziale e antenna disattivati." % st.get("room_id", "comunicazioni"))
		return
	
	match subcmd:
		"rotate":
			if args.size() < 2 or not args[1].is_valid_float():
				terminal.push_line_to_output("Uso: comms rotate <gradi_azimuth_0_360>")
				return
			_execute_rotate(terminal, float(args[1]))
			
		"scan":
			if args.size() < 2 or not (args[1].to_lower() in ["on", "off", "1", "0"]):
				terminal.push_line_to_output("Uso: comms scan <on|off>")
				return
			var active := args[1].to_lower() in ["on", "1"]
			_execute_scan(terminal, active)
			
		"get_frequency", "frequency", "freq":
			_execute_get_frequency(terminal)
			
		"lock_frequency", "lock":
			if args.size() < 2 or not args[1].is_valid_float():
				terminal.push_line_to_output("Uso: comms lock_frequency <frequenza_mhz>")
				return
			_execute_lock_frequency(terminal, float(args[1]))
			
		"listen_frequency", "listen":
			if args.size() < 2 or not args[1].is_valid_float():
				terminal.push_line_to_output("Uso: comms listen_frequency <frequenza_mhz>")
				return
			_start_interactive_listen(terminal, float(args[1]))
			
		_:
			terminal.push_line_to_output("Sottocomando 'comms %s' non riconosciuto. Digita 'comms help' per la guida." % subcmd)

func _execute_rotate(terminal: Terminal, deg: float) -> void:
	var norm_deg := fposmod(deg, 360.0)
	var hal: ShipHAL = _get_hal(terminal)
	if hal and hal.comms:
		hal.comms.rotate_antenna(norm_deg)
	var comms_app = _get_comms_app(terminal)
	if comms_app:
		comms_app.antenna_azimuth_deg = norm_deg
		if comms_app.antenna_heading_slider:
			comms_app.antenna_heading_slider.set_value_no_signal(norm_deg)
		if comms_app.has_method("_refresh_antenna_ui"):
			comms_app._refresh_antenna_ui()
	terminal.push_line_to_output("[color=#00ffff][COMMS][/color] Orientamento azimuth antenna impostato a: [b]%03d°[/b]" % int(norm_deg))

func _execute_scan(terminal: Terminal, active: bool) -> void:
	var hal: ShipHAL = _get_hal(terminal)
	if hal and hal.comms:
		hal.comms.toggle_scan(active)
	var comms_app = _get_comms_app(terminal)
	if comms_app:
		comms_app.is_auto_rotating = active
		if comms_app.has_method("_refresh_antenna_ui"):
			comms_app._refresh_antenna_ui()
	terminal.push_line_to_output("[color=#00ffff][COMMS][/color] Scansione continua rotante 360°: [b]%s[/b]" % ("ATTIVA" if active else "DISATTIVATA"))

func _execute_get_frequency(terminal: Terminal) -> void:
	var comms_app = _get_comms_app(terminal)
	var hal: ShipHAL = _get_hal(terminal)
	var freq: float = 1420.0
	if comms_app:
		freq = comms_app.current_frequency
	elif hal and hal.comms:
		freq = float(hal.comms.get_status().get("locked_freq", 1420.0))
		if freq == 0.0: freq = 1420.0
	terminal.push_line_to_output("[color=#00ffff][COMMS][/color] Frequenza sintonizzata attuale: [b]%.1f MHz[/b]" % freq)

func _execute_lock_frequency(terminal: Terminal, freq: float) -> void:
	var hal: ShipHAL = _get_hal(terminal)
	if hal and hal.comms:
		hal.comms.lock_frequency(freq)
	var comms_app = _get_comms_app(terminal)
	if comms_app:
		comms_app.current_frequency = freq
		comms_app.is_frequency_locked = true
		if comms_app.has_method("_refresh_tuner_state"):
			comms_app._refresh_tuner_state()
	terminal.push_line_to_output("[color=#00ff88][COMMS][/color] Frequency Lock agganciato su: [b]%.1f MHz[/b] (Tracking antenna attivato)" % freq)

func _start_interactive_listen(terminal: Terminal, freq: float) -> void:
	listening_frequency = freq
	_listening_terminal = terminal
	_packet_index = 0
	
	_sample_packets = [
		"[color=#66ccff]TRANSMISSION ID #4092[/color]: ...vettore confermato, autorizzazione corridoio vettore 4...",
		"[color=#ffdd55]TELEMETRY PACKET[/color]: PING_SNR=0.88 | SYNC_BURST=OK | RSSI=-42dBm",
		"[color=#66ccff]BEACON REPORT[/color]: Beacon automatico di settore attivo. Frequenza di sicurezza 1420 MHz.",
		"[color=#ff66aa]INTERCEPTED COMMS[/color]: ...attenzione a detriti e formazioni asteroidali in quadrante 3..."
	]
	
	terminal.push_line_to_output("==================================================")
	terminal.push_line_to_output("  STREAMING RADIO INTERATTIVO - FREQUENZA %.1f MHz" % freq)
	terminal.push_line_to_output("==================================================")
	terminal.push_line_to_output("Ascolto subspaziale attivo. Digita [b]'q'[/b] o [b]'exit'[/b] per uscire.")
	terminal.push_line_to_output("--------------------------------------------------")
	terminal.push_line_to_output(_sample_packets[0])
	
	terminal.active_interactive_command = self

func handle_interactive_input(terminal: Terminal, input: String) -> void:
	var cmd := input.strip_edges().to_lower()
	if cmd in ["q", "exit", "quit", "close", "stop"]:
		terminal.push_line_to_output("[color=#00ffff][COMMS][/color] Ascolto radio terminato. Ritorno al prompt principale.")
		terminal.active_interactive_command = null
		_listening_terminal = null
		return
	
	_packet_index = (_packet_index + 1) % _sample_packets.size()
	terminal.push_line_to_output(_sample_packets[_packet_index])
	terminal.push_line_to_output("[color=#888888](Premi 'q' per uscire dalla modalità ascolto radio)[/color]")

func _get_comms_app(terminal: Terminal) -> Node:
	var sw_mgr = terminal.get_node_or_null("/root/ShipSoftwareManager") if terminal.is_inside_tree() else null
	if sw_mgr and sw_mgr.has_method("get_running_app"):
		return sw_mgr.get_running_app("comms")
	return null

func _get_hal(terminal: Terminal) -> ShipHAL:
	if terminal and "ship_hal" in terminal and terminal.ship_hal != null:
		return terminal.ship_hal
	var swm = null
	if terminal and terminal.is_inside_tree():
		swm = terminal.get_node_or_null("/root/SpaceWorldManager")
	elif Engine.get_main_loop() is SceneTree:
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			swm = tree.root.get_node_or_null("SpaceWorldManager")
	if swm and swm.has_method("get_ship_hal"):
		return swm.get_ship_hal()
	return null

func _print_help(terminal: Terminal) -> void:
	terminal.push_line_to_output("==================================================")
	terminal.push_line_to_output("  COMMS CLI - COMUNICAZIONI & ANTENNA")
	terminal.push_line_to_output("==================================================")
	terminal.push_line_to_output(" comms rotate <deg>                     : Orienta azimuth antenna (0-360°)")
	terminal.push_line_to_output(" comms scan <on|off>                    : Attiva o ferma rotazione antenna automatica")
	terminal.push_line_to_output(" comms get_frequency                    : Mostra la frequenza radio sintonizzata")
	terminal.push_line_to_output(" comms lock_frequency <freq>            : Blocca frequenza e attiva auto-tracking")
	terminal.push_line_to_output(" comms listen_frequency <freq>          : Avvia streaming interattivo (uscita con 'q')")
	terminal.push_line_to_output("==================================================")

func usage() -> Array[String]:
	return [
		"comms rotate <deg>",
		"comms scan <on|off>",
		"comms get_frequency",
		"comms lock_frequency <freq>",
		"comms listen_frequency <freq>"
	]
