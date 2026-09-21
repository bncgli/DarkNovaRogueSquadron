extends TerminalCommand

## Comando CLI 'sensors' per la gestione dello sweep radar, rilevamento contatti e telemetria sonde.
## Verifica preventivamente lo stato di alimentazione della matrice phased array 'sensors_matrix'.

func _init() -> void:
	call_name = "sensors"

func execute(terminal: Terminal, args: Array[String]) -> void:
	if args.is_empty() or args[0] in ["help", "-h", "--help"]:
		_print_help(terminal)
		return
		
	var subcmd := args[0].to_lower()
	var hal: ShipHAL = _get_hal(terminal)
	
	# Verifica alimentazione hardware matrice sensori (sensors_matrix)
	if hal and not hal.is_device_powered("sensors_matrix"):
		var st := hal.get_device_status("sensors_matrix")
		terminal.push_line_to_output("[color=#ff4040][ERRORE HARDWARE][/color] Dispositivo 'sensors_matrix' (%s) non alimentato. Radar e telemetria spaziale ciechi." % st.get("room_id", "matrice_sensori"))
		return
	
	match subcmd:
		"sweep", "swipe":
			if args.size() < 2 or not (args[1].to_lower() in ["on", "off", "1", "0"]):
				terminal.push_line_to_output("Uso: sensors sweep <on|off>")
				return
			var active := args[1].to_lower() in ["on", "1"]
			_execute_sweep_toggle(terminal, active)
			
		"get_targets", "targets", "list":
			_execute_get_targets(terminal)
			
		"get_probe_targets", "probe_targets":
			var probe_id := args[1] if args.size() >= 2 else ""
			_execute_get_probe_targets(terminal, probe_id)
			
		_:
			terminal.push_line_to_output("Sottocomando 'sensors %s' non riconosciuto. Digita 'sensors help' per la guida." % subcmd)

func _execute_sweep_toggle(terminal: Terminal, active: bool) -> void:
	var hal: ShipHAL = _get_hal(terminal)
	if hal and hal.sensors:
		hal.sensors.toggle_sweep(active)
	terminal.push_line_to_output("[color=#00ffcc][SENSORS][/color] Scansione sweep volumetrico a 360° impostata su: [b]%s[/b] (Frequenza: 12.0 Hz)" % ("ATTIVA" if active else "IN PAUSA"))

func _execute_get_targets(terminal: Terminal) -> void:
	var swm = terminal.get_node_or_null("/root/SpaceWorldManager")
	var targets: Array = []
	if swm and swm.has_method("get_sensor_entities"):
		targets = swm.get_sensor_entities()
		
	if targets.is_empty():
		terminal.push_line_to_output("[color=#888888]Nessun contatto tracciato nel raggio radar standard (1000m).[/color]")
		return
		
	terminal.push_line_to_output("================================================================================")
	terminal.push_line_to_output("  CONTATTI TRACCIATI DA MATRICE SENSORI (%d BERSAGLI)" % targets.size())
	terminal.push_line_to_output("================================================================================")
	terminal.push_line_to_output("%-18s | %-16s | %-14s | %-12s | %-10s" % ["ID BERSAGLIO", "NOME", "TIPO", "DISTANZA", "BEARING"])
	terminal.push_line_to_output("--------------------------------------------------------------------------------")
	
	for t in targets:
		var t_id: String = str(t.get("id", "N/A"))
		var t_name: String = str(t.get("name", t_id))
		var t_type: String = str(t.get("type", "UNKNOWN"))
		var rel_pos: Vector3 = t.get("local_rel_pos", t.get("rel_pos", t.get("pos", Vector3.ZERO)))
		var dist := rel_pos.length()
		var bearing := rad_to_deg(atan2(rel_pos.x, -rel_pos.z))
		if bearing < 0.0: bearing += 360.0
		
		terminal.push_line_to_output("%-18s | %-16s | %-14s | %10.1f m | %7.1f°" % [
			t_id.left(18),
			t_name.left(16),
			t_type.left(14),
			dist,
			bearing
		])
	terminal.push_line_to_output("================================================================================")

func _execute_get_probe_targets(terminal: Terminal, probe_id: String) -> void:
	var swm = terminal.get_node_or_null("/root/SpaceWorldManager")
	var probe: Dictionary = {}
	if swm and swm.has_method("get_active_probe"):
		probe = swm.get_active_probe()
		
	if probe.is_empty():
		terminal.push_line_to_output("[color=#ffaa00][SENSORS][/color] Nessuna sonda telemetrica attiva nello spazio circostante.")
		return
		
	var actual_id: String = str(probe.get("id", "PROBE-01"))
	if not probe_id.is_empty() and probe_id != actual_id:
		terminal.push_line_to_output("[color=#ffaa00][SENSORS][/color] Sonda '%s' non trovata (Sonda attiva presente: %s)." % [probe_id, actual_id])
		return
		
	var p_pos: Vector3 = probe.get("pos", Vector3.ZERO)
	var p_radius: float = float(probe.get("scan_radius", 1000.0))
	
	var raw_targets: Array = []
	if swm and swm.has_method("get_sensor_entities"):
		raw_targets = swm.get_sensor_entities()
		
	var probe_contacts: Array = []
	for t in raw_targets:
		var pos: Vector3 = t.get("pos", Vector3.ZERO)
		var dist := (pos - p_pos).length()
		if dist <= p_radius and str(t.get("id", "")) != actual_id:
			var item: Dictionary = t.duplicate()
			item["probe_dist"] = dist
			probe_contacts.append(item)
			
	terminal.push_line_to_output("================================================================================")
	terminal.push_line_to_output("  FEED TELEMETRICO SONDA [%s] (Raggio Scansione: %.0f m)" % [actual_id, p_radius])
	terminal.push_line_to_output("================================================================================")
	if probe_contacts.is_empty():
		terminal.push_line_to_output("[color=#888888]Nessun contatto entro la bolla di scansione della sonda.[/color]")
	else:
		terminal.push_line_to_output("%-18s | %-16s | %-14s | %-14s" % ["ID CONTATTO", "NOME", "TIPO", "DIST DA SONDA"])
		terminal.push_line_to_output("--------------------------------------------------------------------------------")
		for pc in probe_contacts:
			terminal.push_line_to_output("%-18s | %-16s | %-14s | %12.1f m" % [
				str(pc.get("id", "N/A")).left(18),
				str(pc.get("name", "N/A")).left(16),
				str(pc.get("type", "N/A")).left(14),
				float(pc.get("probe_dist", 0.0))
			])
	terminal.push_line_to_output("================================================================================")

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
	terminal.push_line_to_output("  SENSORS CLI - RADAR & TELEMETRIA SONDE")
	terminal.push_line_to_output("==================================================")
	terminal.push_line_to_output(" sensors sweep <on|off>                 : Attiva o sospende la scansione passiva")
	terminal.push_line_to_output(" sensors get_targets                    : Elenca tutti i contatti tracciati dal radar")
	terminal.push_line_to_output(" sensors get_probe_targets [probe_id]   : Elenca i bersagli rilevati dal feed della sonda")
	terminal.push_line_to_output("==================================================")

func usage() -> Array[String]:
	return [
		"sensors sweep <on|off>",
		"sensors get_targets",
		"sensors get_probe_targets [probe_id]"
	]
