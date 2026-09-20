class_name VirtualSysfsDriver
extends RefCounted

## Driver per il filesystem virtuale /sys nel Terminale (Ship OS).
## Mappa in tempo reale stanze, componenti fisici e registri del bus hardware
## sui percorsi gerarchici:
##   /sys/rooms/[room_id]/[device_id]/[register]
##   /sys/devices/[device_id]/[register]

var custom_bus: ShipHardwareBus = null

func _init(p_bus: ShipHardwareBus = null) -> void:
	custom_bus = p_bus

## Ritorna l'istanza attiva del bus hardware
func get_bus() -> ShipHardwareBus:
	if custom_bus != null and is_instance_valid(custom_bus):
		return custom_bus
	
	if Engine.get_main_loop() is SceneTree:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			var swm := tree.root.get_node_or_null("SpaceWorldManager")
			if swm:
				if swm.has_method("is_ship_connected") and not swm.is_ship_connected():
					return null
				if swm.has_method("get_hardware_bus"):
					var bus = swm.get_hardware_bus()
					if bus is ShipHardwareBus:
						return bus
	return null

## Normalizza un percorso rimuovendo slash e ritornando formato standard (es. "sys/rooms/...")
static func normalize_path(path: String) -> String:
	return path.replace("\\", "/").strip_edges().trim_prefix("/").trim_suffix("/")

## Controlla se il percorso appartiene al filesystem virtuale /sys
static func is_sysfs_path(path: String) -> bool:
	var norm := normalize_path(path)
	return norm == "sys" or norm.begins_with("sys/")

## Verifica se il percorso corrisponde a una cartella valida in /sys
func is_valid_folder(path: String) -> bool:
	if not is_sysfs_path(path):
		return false
	var bus := get_bus()
	if not bus:
		return false
	var norm := normalize_path(path)
	if norm in ["sys", "sys/rooms", "sys/devices"]:
		return true
		
	var parts := norm.split("/")
	if parts.size() == 3:
		if parts[1] == "rooms":
			return bus.get_all_room_ids().has(parts[2])
		elif parts[1] == "devices":
			return bus.has_component(parts[2])
	elif parts.size() == 4 and parts[1] == "rooms":
		var room_id := parts[2]
		var dev_id := parts[3]
		var devs := bus.get_components_in_room(room_id)
		for d in devs:
			if d.device_id == dev_id:
				return true
	return false

## Verifica se il percorso corrisponde a un file di registro valido in /sys
func is_valid_file(path: String) -> bool:
	if not is_sysfs_path(path):
		return false
	var bus := get_bus()
	if not bus:
		return false
	var target := _resolve_device_and_register(path)
	return target.get("valid", false)

## Elenca le sottocartelle per il percorso specificato
func list_directories(path: String) -> PackedStringArray:
	var res := PackedStringArray()
	if not is_sysfs_path(path):
		return res
	var bus := get_bus()
	if not bus:
		return res
	var norm := normalize_path(path)
	
	if norm == "sys":
		res.append("rooms")
		res.append("devices")
		return res
		
	if not bus:
		return res
		
	var parts := norm.split("/")
	if parts.size() == 2:
		if parts[1] == "rooms":
			for r in bus.get_all_room_ids():
				res.append(r)
		elif parts[1] == "devices":
			for d in bus.get_all_device_ids():
				res.append(d)
	elif parts.size() == 3 and parts[1] == "rooms":
		var room_id := parts[2]
		var devs := bus.get_components_in_room(room_id)
		for d in devs:
			res.append(d.device_id)
			
	return res

## Elenca i file (registri) per il percorso specificato
func list_files(path: String) -> PackedStringArray:
	var res := PackedStringArray()
	if not is_sysfs_path(path):
		return res
	var norm := normalize_path(path)
	var bus := get_bus()
	if not bus:
		return res
		
	var parts := norm.split("/")
	var comp: ShipPhysicalComponent = null
	
	if parts.size() == 3 and parts[1] == "devices":
		comp = bus.get_component(parts[2])
	elif parts.size() == 4 and parts[1] == "rooms":
		var room_id := parts[2]
		var dev_id := parts[3]
		var devs := bus.get_components_in_room(room_id)
		for d in devs:
			if d.device_id == dev_id:
				comp = d
				break
				
	if comp:
		for reg_name in comp.registers.keys():
			res.append(str(reg_name))
	return res

## Legge il contenuto del registro corrispondente al file virtuale
func read_file(path: String) -> String:
	var target := _resolve_device_and_register(path)
	if not target.get("valid", false):
		return "ERR_FILE_NOT_FOUND"
		
	var comp: ShipPhysicalComponent = target["component"]
	var reg: String = target["register"]
	var val = comp.read_register(reg)
	if val == null:
		return ""
	if val is float:
		return str(snappedf(val, 0.001))
	return str(val)

## Scrive un nuovo valore sul registro virtuale
func write_file(path: String, content: String) -> Dictionary:
	var target := _resolve_device_and_register(path)
	if not target.get("valid", false):
		return {"success": false, "error": "ERR_FILE_NOT_FOUND"}
		
	var comp: ShipPhysicalComponent = target["component"]
	var reg: String = target["register"]
	var clean_val: String = content.strip_edges()
	
	var ok := comp.write_register(reg, clean_val)
	if ok:
		return {"success": true, "error": ""}
	else:
		return {"success": false, "error": "ERR_WRITE_FAILED (ReadOnly or Invalid Value)"}

func _resolve_device_and_register(path: String) -> Dictionary:
	var norm := normalize_path(path)
	var parts := norm.split("/")
	var bus := get_bus()
	if not bus:
		return {"valid": false}
		
	var comp: ShipPhysicalComponent = null
	var reg_name := ""
	
	if parts.size() == 4 and parts[1] == "devices":
		# sys/devices/[device_id]/[register]
		comp = bus.get_component(parts[2])
		reg_name = parts[3]
	elif parts.size() == 5 and parts[1] == "rooms":
		# sys/rooms/[room_id]/[device_id]/[register]
		var room_id := parts[2]
		var dev_id := parts[3]
		reg_name = parts[4]
		var devs := bus.get_components_in_room(room_id)
		for d in devs:
			if d.device_id == dev_id:
				comp = d
				break
				
	if comp and (comp.registers.has(reg_name) or reg_name in comp.readonly_registers):
		return {
			"valid": true,
			"component": comp,
			"register": reg_name
		}
	return {"valid": false}
