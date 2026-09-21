extends TerminalCommand

## Comando CLI 'flight' per il controllo del volo, spinta, manovre 3D e stabilizzazione inerziale.
## Verifica preventivamente lo stato di alimentazione di helm_control, engine_main e degli attuatori RCS.

func _init() -> void:
	call_name = "flight"

func execute(terminal: Terminal, args: Array[String]) -> void:
	if args.is_empty() or args[0] in ["help", "-h", "--help"]:
		_print_help(terminal)
		return
	
	var subcmd := args[0].to_lower()
	var hal: ShipHAL = _get_hal(terminal)
	
	# Verifica Consolle di comando (helm_control)
	if hal and not hal.is_device_powered("helm_control"):
		var st := hal.get_device_status("helm_control")
		terminal.push_line_to_output("[color=#ff4040][ERRORE HARDWARE][/color] Dispositivo 'helm_control' (%s) non alimentato. Consolle pilota disconnessa." % st.get("room_id", "ponte_comando"))
		return
	
	match subcmd:
		"cruise_mode":
			if args.size() < 2 or not (args[1].to_lower() in ["start", "stop", "on", "off"]):
				terminal.push_line_to_output("Uso: flight cruise_mode <start|stop>")
				return
			var start := args[1].to_lower() in ["start", "on"]
			_execute_cruise(terminal, hal, start)
			
		"toggle_inertia":
			if args.size() < 2 or not (args[1].to_lower() in ["on", "off", "1", "0"]):
				terminal.push_line_to_output("Uso: flight toggle_inertia <on|off>")
				return
			var enabled := args[1].to_lower() in ["on", "1"]
			_execute_toggle_inertia(terminal, hal, enabled)
			
		"set_speed":
			if args.size() < 2 or not args[1].is_valid_float():
				terminal.push_line_to_output("Uso: flight set_speed <valore_moltiplicatore_o_ms>")
				return
			_execute_set_speed(terminal, hal, float(args[1]))
			
		"forward":
			if args.size() < 2 or not args[1].is_valid_float():
				terminal.push_line_to_output("Uso: flight forward <quantità>")
				return
			_execute_linear_thrust(terminal, hal, -absf(float(args[1])))
			
		"backward":
			if args.size() < 2 or not args[1].is_valid_float():
				terminal.push_line_to_output("Uso: flight backward <quantità>")
				return
			_execute_linear_thrust(terminal, hal, absf(float(args[1])))
			
		"rotate":
			if args.size() < 4 or not (args[1].is_valid_float() and args[2].is_valid_float() and args[3].is_valid_float()):
				terminal.push_line_to_output("Uso: flight rotate <pitch_deg> <yaw_deg> <roll_deg>")
				return
			_execute_rotate(terminal, hal, float(args[1]), float(args[2]), float(args[3]), false)
			
		"rotate_to":
			if args.size() < 4 or not (args[1].is_valid_float() and args[2].is_valid_float() and args[3].is_valid_float()):
				terminal.push_line_to_output("Uso: flight rotate_to <pitch_deg> <yaw_deg> <roll_deg>")
				return
			_execute_rotate(terminal, hal, float(args[1]), float(args[2]), float(args[3]), true)
			
		"slide":
			if args.size() < 3 or not (args[1].is_valid_float() and args[2].is_valid_float()):
				terminal.push_line_to_output("Uso: flight slide <x_strife> <y_vertical>")
				return
			_execute_slide(terminal, hal, float(args[1]), float(args[2]))
			
		_:
			terminal.push_line_to_output("Sottocomando 'flight %s' sconosciuto. Digita 'flight help' per la lista dei comandi." % subcmd)

func _execute_cruise(terminal: Terminal, hal: ShipHAL, start: bool) -> void:
	if start and hal and not hal.is_device_powered("engine_main"):
		var st := hal.get_device_status("engine_main")
		terminal.push_line_to_output("[color=#ff4040][ERRORE HARDWARE][/color] Dispositivo 'engine_main' (%s) non alimentato. Impossibile avviare Cruise Drive." % st.get("room_id", "sala_motori"))
		return
	
	if hal and hal.propulsion:
		hal.propulsion.toggle_cruise(start)
	
	var swm = terminal.get_node_or_null("/root/SpaceWorldManager")
	var ship = swm.get_spaceship() if swm and swm.has_method("get_spaceship") else null
	var cdc = ship.cruise_controller if ship and "cruise_controller" in ship else null
	
	if cdc:
		if start:
			cdc.request_cruise_engagement()
			terminal.push_line_to_output("[color=#33ccff][FLIGHT][/color] Sequenza di warmup Cruise Drive avviata.")
		else:
			cdc.request_cruise_disengagement()
			terminal.push_line_to_output("[color=#33ccff][FLIGHT][/color] Cruise Drive disingaggiato. Ritorno a spinta sub-luce ordinaria.")
	else:
		terminal.push_line_to_output("[color=#ffaa00][FLIGHT][/color] Controller di crociera non trovato sul vascello.")

func _execute_toggle_inertia(terminal: Terminal, hal: ShipHAL, enabled: bool) -> void:
	if hal and not (hal.is_device_powered("rcs_pitch_l") or hal.is_device_powered("rcs_pitch_r")):
		var st := hal.get_device_status("rcs_pitch_l")
		terminal.push_line_to_output("[color=#ff4040][ERRORE HARDWARE][/color] Attuatori RCS (%s) non alimentati. Impossibile attivare smorzamento inerziale." % st.get("room_id", "rcs_left"))
		return
	
	if hal and hal.propulsion:
		hal.propulsion.toggle_inertia(enabled)
		
	var swm = terminal.get_node_or_null("/root/SpaceWorldManager") if terminal.is_inside_tree() else null
	if swm and swm.has_method("set_inertia_dampening"):
		swm.set_inertia_dampening(enabled)
	var ship = swm.get_spaceship() if swm and swm.has_method("get_spaceship") else null
	if ship and ship.has_method("set_inertia_dampening"):
		ship.set_inertia_dampening(enabled)
		
	terminal.push_line_to_output("[color=#33ccff][FLIGHT][/color] Smorzamento inerziale impostato su: %s" % ("ATTIVO" if enabled else "DISATTIVATO"))

func _execute_set_speed(terminal: Terminal, hal: ShipHAL, val: float) -> void:
	if hal and not hal.is_device_powered("engine_main"):
		var st := hal.get_device_status("engine_main")
		terminal.push_line_to_output("[color=#ff4040][ERRORE HARDWARE][/color] Dispositivo 'engine_main' (%s) non alimentato. Regolazione velocità non consentita." % st.get("room_id", "sala_motori"))
		return
	
	if hal and hal.propulsion:
		hal.propulsion.set_speed_limiter(clampf(val, 0.1, 2.0))
		
	var swm = terminal.get_node_or_null("/root/SpaceWorldManager") if terminal.is_inside_tree() else null
	if swm and swm.has_method("set_ship_max_linear_speed"):
		var target_speed := val if val > 2.0 else val * 20.0
		swm.set_ship_max_linear_speed(target_speed)
		terminal.push_line_to_output("[color=#33ccff][FLIGHT][/color] Limite velocità propulsori impostato a %.1f m/s." % target_speed)
	else:
		terminal.push_line_to_output("[color=#ffaa00][FLIGHT][/color] SpaceWorldManager non disponibile.")

func _execute_linear_thrust(terminal: Terminal, hal: ShipHAL, amount: float) -> void:
	if hal and not hal.is_device_powered("engine_main"):
		var st := hal.get_device_status("engine_main")
		terminal.push_line_to_output("[color=#ff4040][ERRORE HARDWARE][/color] Dispositivo 'engine_main' (%s) non alimentato. Spinta longitudinale non disponibile." % st.get("room_id", "sala_motori"))
		return
		
	var swm = terminal.get_node_or_null("/root/SpaceWorldManager")
	var ship = swm.get_spaceship() if swm and swm.has_method("get_spaceship") else null
	if ship and is_instance_valid(ship):
		var impulse_vec: Vector3 = ship.global_transform.basis * Vector3(0.0, 0.0, amount * 2.0)
		ship.linear_velocity += impulse_vec
		terminal.push_line_to_output("[color=#33ccff][FLIGHT][/color] Spinta longitudinale applicata: %+.1f m/s (Velocità attuale: %.1f m/s)" % [-amount, ship.linear_velocity.length()])
	else:
		terminal.push_line_to_output("[color=#ffaa00][FLIGHT][/color] Vascello non agganciato.")

func _execute_rotate(terminal: Terminal, hal: ShipHAL, pitch: float, yaw: float, roll: float, is_absolute: bool) -> void:
	if hal and not (hal.is_device_powered("rcs_pitch_l") or hal.is_device_powered("rcs_pitch_r")):
		var st := hal.get_device_status("rcs_pitch_l")
		terminal.push_line_to_output("[color=#ff4040][ERRORE HARDWARE][/color] Attuatori RCS (%s) non alimentati. Rotazione nave inibita." % st.get("room_id", "rcs_left"))
		return
		
	var swm = terminal.get_node_or_null("/root/SpaceWorldManager")
	var ship = swm.get_spaceship() if swm and swm.has_method("get_spaceship") else null
	if ship and is_instance_valid(ship):
		if is_absolute:
			ship.rotation_degrees = Vector3(pitch, yaw, roll)
			terminal.push_line_to_output("[color=#33ccff][FLIGHT][/color] Assetto angolare orientato a: Pitch %.1f°, Yaw %.1f°, Roll %.1f°" % [pitch, yaw, roll])
		else:
			ship.rotate_object_local(Vector3(1, 0, 0), deg_to_rad(pitch))
			ship.rotate_object_local(Vector3(0, 1, 0), deg_to_rad(yaw))
			ship.rotate_object_local(Vector3(0, 0, 1), deg_to_rad(roll))
			var rot: Vector3 = ship.rotation_degrees
			terminal.push_line_to_output("[color=#33ccff][FLIGHT][/color] Rotazione relativa applicata. Assetto attuale: Pitch %.1f°, Yaw %.1f°, Roll %.1f°" % [rot.x, rot.y, rot.z])
	else:
		terminal.push_line_to_output("[color=#ffaa00][FLIGHT][/color] Vascello non agganciato.")

func _execute_slide(terminal: Terminal, hal: ShipHAL, x: float, y: float) -> void:
	if hal and not (hal.is_device_powered("rcs_pitch_l") or hal.is_device_powered("rcs_pitch_r")):
		var st := hal.get_device_status("rcs_pitch_l")
		terminal.push_line_to_output("[color=#ff4040][ERRORE HARDWARE][/color] Attuatori RCS (%s) non alimentati. Traslazione laterale/verticale inibita." % st.get("room_id", "rcs_left"))
		return
		
	var swm = terminal.get_node_or_null("/root/SpaceWorldManager")
	var ship = swm.get_spaceship() if swm and swm.has_method("get_spaceship") else null
	if ship and is_instance_valid(ship):
		var slide_vec: Vector3 = ship.global_transform.basis * Vector3(x, y, 0.0)
		ship.linear_velocity += slide_vec
		terminal.push_line_to_output("[color=#33ccff][FLIGHT][/color] Impulso di slide applicato: X %+.1f, Y %+.1f (Velocità attuale: %.1f m/s)" % [x, y, ship.linear_velocity.length()])
	else:
		terminal.push_line_to_output("[color=#ffaa00][FLIGHT][/color] Vascello non agganciato.")

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
	terminal.push_line_to_output("  FLIGHT CONTROL CLI - COMANDI DI VOLO")
	terminal.push_line_to_output("==================================================")
	terminal.push_line_to_output(" flight cruise_mode <start|stop>        : Attiva o disattiva il Cruise Drive a 160 m/s")
	terminal.push_line_to_output(" flight toggle_inertia <on|off>         : Attiva o disattiva la stabilizzazione inerziale")
	terminal.push_line_to_output(" flight set_speed <valore>              : Imposta il limitatore di velocità o moltiplicatore")
	terminal.push_line_to_output(" flight forward <quantità>              : Applica spinta in avanti")
	terminal.push_line_to_output(" flight backward <quantità>             : Applica spinta all'indietro (retromarcia)")
	terminal.push_line_to_output(" flight rotate <p> <y> <r>              : Ruota la nave per valori relativi di pitch, yaw e roll")
	terminal.push_line_to_output(" flight rotate_to <p> <y> <r>           : Orienta la nave all'angolo assoluto specificato")
	terminal.push_line_to_output(" flight slide <x> <y>                   : Esegue una traslazione laterale/verticale RCS")
	terminal.push_line_to_output("==================================================")

func usage() -> Array[String]:
	return [
		"flight cruise_mode <start|stop>",
		"flight toggle_inertia <on|off>",
		"flight set_speed <valore>",
		"flight forward <quantità>",
		"flight backward <quantità>",
		"flight rotate <pitch> <yaw> <roll>",
		"flight rotate_to <pitch> <yaw> <roll>",
		"flight slide <x> <y>"
	]
