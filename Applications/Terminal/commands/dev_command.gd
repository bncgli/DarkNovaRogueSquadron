extends TerminalCommand

## Comando CLI avanzato 'dev' per la gestione a basso livello dei dispositivi hardware della nave.
## Consente ispezione, telemetria in tempo reale, modifica registri, reboot e diagnostica.

func _init() -> void:
	call_name = "dev"

func execute(terminal: Terminal, args: Array[String]) -> void:
	if args.is_empty() or args[0] in ["help", "-h", "--help"]:
		_print_help(terminal)
		return

	var bus := _get_bus(terminal)
	if bus == null:
		terminal.push_line_to_output("Errore: Hardware Bus non disponibile o nave non inizializzata")
		return
		
	var subcmd := args[0].to_lower()
	match subcmd:
		"list", "ls":
			_execute_list(terminal, bus)
		"status", "info":
			if args.size() < 2:
				_execute_bus_status(terminal, bus)
			else:
				_execute_status(terminal, bus, args[1])
		"bus", "hal":
			_execute_bus_status(terminal, bus)
		"get", "read":
			if args.size() < 3:
				terminal.push_line_to_output("Uso: dev get <device_id> <register_name>")
			else:
				_execute_get(terminal, bus, args[1], args[2])
		"set", "write":
			if args.size() < 4:
				terminal.push_line_to_output("Uso: dev set <device_id> <register_name> <value>")
			else:
				_execute_set(terminal, bus, args[1], args[2], args[3])
		"reboot", "restart":
			if args.size() < 2:
				terminal.push_line_to_output("Uso: dev reboot <device_id>")
			else:
				_execute_reboot(terminal, bus, args[1])
		"online":
			if args.size() < 3:
				terminal.push_line_to_output("Uso: dev online <device_id> <1|0|on|off>")
			else:
				_execute_online(terminal, bus, args[1], args[2])
		_:
			terminal.push_line_to_output("Sottocomando 'dev %s' non riconosciuto. Digita 'dev help' per la guida." % subcmd)

func _execute_bus_status(terminal: Terminal, bus: ShipHardwareBus) -> void:
	var swm = terminal.get_node_or_null("/root/SpaceWorldManager")
	var hal = null
	if swm and swm.has_method("get_ship_hal"):
		hal = swm.get_ship_hal()
		
	terminal.push_line_to_output("==================================================")
	terminal.push_line_to_output("  STATO SOTTOSISTEMA HARDWARE (BUS & HAL)")
	terminal.push_line_to_output("==================================================")
	var comps := bus.get_all_components()
	terminal.push_line_to_output(" Hardware Bus:    ATTIVO (%d componenti registrati)" % comps.size())
	if hal != null:
		terminal.push_line_to_output(" HAL Controller:  CONNESSO E SINCRONIZZATO")
		terminal.push_line_to_output(" Propulsione:     Efficienza %.1f%% | Spinta Disponibile: %.1f kN" % [
			hal.get_propulsion_efficiency() * 100.0,
			hal.get_total_available_thrust()
		])
		var pwr: Dictionary = hal.get_power_telemetry()
		terminal.push_line_to_output(" Rete Elettrica:  Gen: %.1f MW | Carico: %.1f MW | Ratio: %.2f%s" % [
			pwr.get("generated_mw", 0.0),
			pwr.get("demanded_mw", 0.0),
			pwr.get("power_ratio", 1.0),
			" (BLACKOUT!)" if pwr.get("is_blackout", false) else ""
		])
		var thrm: Dictionary = hal.get_thermal_telemetry()
		terminal.push_line_to_output(" Termica:         Calore: %.1f | Temp Media: %.1f C" % [
			thrm.get("total_heat", 0.0),
			thrm.get("avg_temp", 0.0)
		])
		terminal.push_line_to_output(" Integrità Scafo: %.1f%%" % hal.get_overall_system_integrity())
		var ls: Dictionary = hal.get_life_support_metrics()
		terminal.push_line_to_output(" Supporto Vitale: O2: %.1f%% | Temp Cabina: %.1f C" % [
			ls.get("o2", 0.0),
			ls.get("temp", 0.0)
		])
	else:
		terminal.push_line_to_output(" HAL Controller:  NON COLLEGATO (Standalone Bus)")
	terminal.push_line_to_output("==================================================")

func _execute_list(terminal: Terminal, bus: ShipHardwareBus) -> void:
	var comps := bus.get_all_components()
	if comps.is_empty():
		terminal.push_line_to_output("Nessun componente hardware registrato sul bus.")
		return
		
	terminal.push_line_to_output("=== COMPONENTI HARDWARE REGISTRATI (%d) ===" % comps.size())
	terminal.push_line_to_output(
		"%-20s | %-16s | %-14s | %-8s | %-7s | %-6s" % 
		["DEVICE ID", "ROOM", "CATEGORY", "STATUS", "HEALTH", "TEMP"]
	)
	terminal.push_line_to_output("--------------------------------------------------------------------------------")
	
	for c: ShipPhysicalComponent in comps:
		terminal.push_line_to_output(
			"%-20s | %-16s | %-14s | %-8s | %5.1f%% | %5.1fC" % [
				c.device_id,
				c.room_id,
				c.category,
				c.status_string,
				c.health_percent,
				c.heat_current
			]
		)

func _execute_status(terminal: Terminal, bus: ShipHardwareBus, device_id: String) -> void:
	var comp := bus.get_component(device_id)
	if comp == null:
		terminal.push_line_to_output("Errore: Dispositivo '%s' non trovato sul bus hardware." % device_id)
		return
		
	var telem := comp.get_telemetry()
	terminal.push_line_to_output("==================================================")
	terminal.push_line_to_output("  SCHEDA DIAGNOSTICA DISPOSITIVO: %s" % device_id)
	terminal.push_line_to_output("==================================================")
	terminal.push_line_to_output(" Nome:         %s" % telem.get("component_name", comp.name))
	terminal.push_line_to_output(" Stanza:       %s" % telem.get("room_id", "N/A"))
	terminal.push_line_to_output(" Categoria:    %s" % telem.get("category", "N/A"))
	terminal.push_line_to_output(" Stato:        %s" % telem.get("status", "UNKNOWN"))
	terminal.push_line_to_output(" Integrità:    %.1f%%" % telem.get("health", 0.0))
	terminal.push_line_to_output(" Temperatura:  %.1f C (Max: %.1f C)" % [telem.get("temp", 0.0), telem.get("heat_max", 120.0)])
	terminal.push_line_to_output(" Potenza Nom:  %.1f MW" % telem.get("power_nominal", 0.0))
	terminal.push_line_to_output(" Assorbimento: %.1f MW (Fornita: %.1f MW, Ratio: %.2f)" % [
		telem.get("power_draw", 0.0),
		telem.get("power_supplied", 0.0),
		telem.get("power_ratio", 1.0)
	])
	
	# Campi specifici di sottoclasse
	if telem.has("power_output"):
		terminal.push_line_to_output(" Erogazione:   %.1f MW (Target: %.2f, Carburante: %.1f%%)" % [
			telem.get("power_output", 0.0),
			telem.get("power_target", 1.0),
			telem.get("fuel", 0.0)
		])
	if telem.has("thrust_output"):
		terminal.push_line_to_output(" Spinta:       %.1f kN / %.1f kN (Throttle: %.2f)" % [
			telem.get("thrust_output", 0.0),
			telem.get("max_thrust", 0.0),
			telem.get("throttle_target", 0.0)
		])
	if telem.has("o2_level"):
		terminal.push_line_to_output(" Atmosfera:    O2: %.1f%% | CO2: %.1f%% | Temp: %.1f C" % [
			telem.get("o2_level", 0.0),
			telem.get("co2_level", 0.0),
			telem.get("cabin_temp", 0.0)
		])
	if telem.has("charge_percent"):
		terminal.push_line_to_output(" Accumulo:     Carica: %.1f MJ / %.1f MJ (%.1f%%)" % [
			telem.get("charge_current", 0.0),
			telem.get("capacity_max", 0.0),
			telem.get("charge_percent", 0.0)
		])
		
	terminal.push_line_to_output("---------------- REGISTRI HARDWARE ---------------")
	for reg in comp.registers.keys():
		var is_ro := comp.readonly_registers.has(reg)
		var val = comp.read_register(reg)
		var mode := "[RO]" if is_ro else "[RW]"
		terminal.push_line_to_output("  %-16s %-4s = %s" % [reg, mode, str(val)])
	terminal.push_line_to_output("==================================================")

func _execute_get(terminal: Terminal, bus: ShipHardwareBus, device_id: String, reg_name: String) -> void:
	var res := bus.dispatch_command(device_id, "read", [reg_name])
	if res.get("success", false):
		terminal.push_line_to_output("%s.%s = %s" % [device_id, reg_name, str(res.get("result"))])
	else:
		terminal.push_line_to_output("Errore: %s" % res.get("error", "Lettura fallita"))

func _execute_set(terminal: Terminal, bus: ShipHardwareBus, device_id: String, reg_name: String, val_str: String) -> void:
	var res := bus.dispatch_command(device_id, "write", [reg_name, val_str])
	if res.get("success", false):
		terminal.push_line_to_output("OK: %s.%s impostato a '%s'" % [device_id, reg_name, val_str])
	else:
		terminal.push_line_to_output("Errore scrittura su %s.%s: %s" % [device_id, reg_name, res.get("error", "Fallito")])

func _execute_reboot(terminal: Terminal, bus: ShipHardwareBus, device_id: String) -> void:
	var res := bus.dispatch_command(device_id, "reboot")
	if res.get("success", false):
		terminal.push_line_to_output("Reboot avviato per il dispositivo '%s'." % device_id)
	else:
		terminal.push_line_to_output("Errore reboot %s: %s" % [device_id, res.get("error", "Fallito")])

func _execute_online(terminal: Terminal, bus: ShipHardwareBus, device_id: String, state_str: String) -> void:
	var target := state_str.to_lower() in ["1", "true", "on", "yes"]
	var res := bus.dispatch_command(device_id, "set_online", [target])
	if res.get("success", false):
		terminal.push_line_to_output("Stato dispositivo '%s' impostato a: %s" % [device_id, "ONLINE" if target else "OFFLINE"])
	else:
		terminal.push_line_to_output("Errore modifica stato %s: %s" % [device_id, res.get("error", "Fallito")])

func _get_bus(terminal: Terminal) -> ShipHardwareBus:
	var tdm := terminal.get_node_or_null("/root/TerminalDriveManager")
	if tdm and tdm.has_method("get_sysfs_driver"):
		var drv: VirtualSysfsDriver = tdm.get_sysfs_driver()
		if drv and drv.custom_bus != null:
			return drv.custom_bus

	var swm := terminal.get_node_or_null("/root/SpaceWorldManager")
	if swm and swm.has_method("is_ship_connected") and not swm.is_ship_connected():
		return null

	if tdm and tdm.has_method("get_sysfs_driver"):
		var drv: VirtualSysfsDriver = tdm.get_sysfs_driver()
		if drv:
			var b := drv.get_bus()
			if b:
				return b
				
	if swm and swm.has_method("get_hardware_bus"):
		return swm.get_hardware_bus()
		
	return null

func _print_help(terminal: Terminal) -> void:
	terminal.push_lines_to_output([
		"Comando 'dev' - Gestione e Diagnostica Hardware di Bordo",
		"Sintassi:",
		"  dev bus / dev status                  Mostra lo stato globale del bus e dell'HAL",
		"  dev list                              Elenca tutti i dispositivi registrati sul bus",
		"  dev status <device_id>                Mostra la scheda diagnostica completa del componente",
		"  dev get <device_id> <reg>             Legge il valore di un registro hardware",
		"  dev set <device_id> <reg> <valore>    Imposta un nuovo valore su un registro hardware",
		"  dev reboot <device_id>                Riavvia in sicurezza il dispositivo",
		"  dev online <device_id> <1|0>          Accende o spegne il dispositivo"
	])

func usage() -> Array[String]:
	return [
		"Dev - Hardware Device Control & Diagnostic Tool",
		"USAGE:",
		"  dev bus",
		"  dev list",
		"  dev status [<id>]",
		"  dev get <id> <register>",
		"  dev set <id> <register> <value>",
		"  dev reboot <id>",
		"  dev online <id> <1|0>"
	]
