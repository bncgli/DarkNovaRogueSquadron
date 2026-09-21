extends TerminalCommand

## Comando CLI 'nav' per il rilevamento della posizione di settore e il calcolo delle rotte interplanetarie.
## Verifica preventivamente lo stato di alimentazione dell'elaboratore di bordo nav_computer.

func _init() -> void:
	call_name = "nav"

func execute(terminal: Terminal, args: Array[String]) -> void:
	if args.is_empty() or args[0] in ["help", "-h", "--help"]:
		_print_help(terminal)
		return
		
	var subcmd := args[0].to_lower()
	var hal: ShipHAL = _get_hal(terminal)
	
	# Verifica alimentazione hardware elaboratore rotte (nav_computer)
	if hal and not hal.is_device_powered("nav_computer"):
		var st := hal.get_device_status("nav_computer")
		terminal.push_line_to_output("[color=#ff4040][ERRORE HARDWARE][/color] Dispositivo 'nav_computer' (%s) non alimentato. Elaborazione rotta e vettori salto non disponibili." % st.get("room_id", "ponte_comando"))
		return
	
	match subcmd:
		"position", "pos", "where":
			_execute_position(terminal)
			
		"calculate", "calc", "route":
			if args.size() < 3 or not (args[1].is_valid_int() and args[2].is_valid_int()):
				terminal.push_line_to_output("Uso: nav calculate <coord_x> <coord_y> [coord_z]")
				return
			var target_z := int(args[3]) if args.size() >= 4 and args[3].is_valid_int() else 0
			_execute_calculate(terminal, int(args[1]), int(args[2]), target_z)
			
		_:
			terminal.push_line_to_output("Sottocomando 'nav %s' non riconosciuto. Digita 'nav help' per la guida." % subcmd)

func _execute_position(terminal: Terminal) -> void:
	var ssm = terminal.get_node_or_null("/root/StarSystemGridManager") if terminal.is_inside_tree() else null
	var swm = terminal.get_node_or_null("/root/SpaceWorldManager") if terminal.is_inside_tree() else null
	var ship = swm.get_spaceship() if swm and swm.has_method("get_spaceship") else null
	
	var sec_id := "SEC-00-00"
	var sec_coords := Vector3i.ZERO
	if ssm and ssm.has_method("get_current_sector_id"):
		sec_id = ssm.get_current_sector_id()
		sec_coords = ssm.get_current_sector_coords()
	
	var local_pos := Vector3.ZERO
	if ship and is_instance_valid(ship):
		local_pos = ship.global_position if ship.is_inside_tree() else ship.position
	
	terminal.push_line_to_output("==================================================")
	terminal.push_line_to_output("  LOCALIZZAZIONE VETTORIALE NAVE (NAV_COMPUTER)")
	terminal.push_line_to_output("==================================================")
	terminal.push_line_to_output(" Settore Corrente: [color=#00ffcc]%s[/color] (Griglia: X:%d, Y:%d, Z:%d)" % [sec_id, sec_coords.x, sec_coords.y, sec_coords.z])
	terminal.push_line_to_output(" Coordinate Locali: X: %+.1f m | Y: %+.1f m | Z: %+.1f m" % [local_pos.x, local_pos.y, local_pos.z])
	if ship and is_instance_valid(ship):
		terminal.push_line_to_output(" Vettore Velocità:  %.1f m/s (Heading: %.1f°)" % [ship.linear_velocity.length(), ship.rotation_degrees.y])
	terminal.push_line_to_output("==================================================")

func _execute_calculate(terminal: Terminal, tx: int, ty: int, tz: int) -> void:
	var hal: ShipHAL = _get_hal(terminal)
	if hal and hal.navigation:
		hal.navigation.calculate_route(Vector2(tx, ty))
	
	var ssm = terminal.get_node_or_null("/root/StarSystemGridManager")
	if ssm == null:
		terminal.push_line_to_output("[color=#ffaa00][NAV][/color] StarSystemGridManager non disponibile per il calcolo.")
		return
	
	var target_coords := Vector3i(tx, ty, tz)
	var route_info: Dictionary = ssm.plot_route(target_coords)
	
	terminal.push_line_to_output("==================================================")
	terminal.push_line_to_output("  ELABORAZIONE ROTTA IPERSPAZIALE (NAV_COMPUTER)")
	terminal.push_line_to_output("==================================================")
	terminal.push_line_to_output(" Origine:          %s (%s)" % [route_info.get("from_sector_id", "N/A"), str(route_info.get("from_coords", ""))])
	terminal.push_line_to_output(" Destinazione:     %s (%s)" % [route_info.get("target_sector_id", "N/A"), str(route_info.get("target_coords", ""))])
	terminal.push_line_to_output(" Distanza Griglia: %.2f Settori (%.0f km)" % [float(route_info.get("distance_sectors", 0.0)), float(route_info.get("distance_km", 0.0))])
	terminal.push_line_to_output(" Vettore di Salto: %s" % str(route_info.get("course_vector", Vector3.ZERO)))
	terminal.push_line_to_output(" Tempo di Transito: ~%.1f s" % float(route_info.get("eta_seconds", 0.0)))
	terminal.push_line_to_output(" Fabbisogno Energetico: %.1f MW" % float(route_info.get("energy_cost_mw", 0.0)))
	terminal.push_line_to_output(" Stato: [color=#00ff88]VETTORE CALCOLATO E TRASMESSO A FLIGHT CONTROL[/color]")
	terminal.push_line_to_output("==================================================")

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
	terminal.push_line_to_output("  NAV COMPUTER CLI - NAVIGAZIONE & ROTTE")
	terminal.push_line_to_output("==================================================")
	terminal.push_line_to_output(" nav position                           : Mostra settore e coordinate correnti del vascello")
	terminal.push_line_to_output(" nav calculate <x> <y> [z]              : Calcola rotta, distanza e vettore verso le coordinate")
	terminal.push_line_to_output("==================================================")

func usage() -> Array[String]:
	return [
		"nav position",
		"nav calculate <x> <y> [z]"
	]
