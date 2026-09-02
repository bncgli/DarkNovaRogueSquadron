@tool
class_name ShipBlueprint
extends Resource

## Struttura dati (Sublayer / Blueprint) per l'astronave in Dark Nova: Rogue Squadron.
## Contiene in modo unificato la geometria delle stanze, i condotti per i droni,
## la rete energetica (dispositivi nelle stanze) e le zone di danno strutturale.

signal blueprint_changed()

# --- METADATI GENERALI ---
const SHIP_CLASSES: Array[String] = ["Corvette", "Frigate", "Destroyer", "Cruiser", "Freighter", "Science Vessel", "Scout", "Carrier", "Station"]
const DEVICE_CATEGORIES: Array[String] = ["command", "propulsion", "life_support", "engineering", "tactical", "sensors", "comms", "mainframe", "defense", "cargo", "service", "utility"]

@export var ship_id: String = "new ship":
	set(val):
		ship_id = val
		emit_changed()

@export var ship_name: String = "new ship":
	set(val):
		ship_name = val
		emit_changed()

@export_enum("Corvette", "Frigate", "Destroyer", "Cruiser", "Freighter", "Science Vessel", "Scout", "Carrier", "Station") var ship_class: String = "Corvette":
	set(val):
		ship_class = val
		emit_changed()

@export_file("*.tscn") var ship_mesh_path: String = "":
	set(val):
		ship_mesh_path = val
		emit_changed()

@export var ship_bounds := Rect2(60, 30, 480, 420):
	set(val):
		ship_bounds = val
		emit_changed()

@export var drone_spawn_pos := Vector2(300, 80):
	set(val):
		drone_spawn_pos = val
		emit_changed()

@export var drone_spawn_heading: float = -PI * 0.5:
	set(val):
		drone_spawn_heading = val
		emit_changed()

@export var flux: int = 100:
	set(val):
		flux = val
		emit_changed()

@export var flux_modifiers: Array[ShipFluxModifier] = []:
	set(val):
		flux_modifiers = val
		emit_changed()


# --- TASK-019: Zona Ricarica ---
@export var recharge_room_id: String = "":
	set(val):
		recharge_room_id = val
		emit_changed()

# --- SUBLAYER 1: STANZE E SETTORI (Rooms / Hull Layout) ---
# ogni elemento: ShipRoomData
@export var rooms: Array[ShipRoomData] = []:
	set(val):
		rooms = val
		emit_changed()

# --- SUBLAYER 2: CONDOTTI DI MANUTENZIONE (Ducts System) ---
# Ogni elemento: ShipDuctData
@export var ducts: Array[ShipDuctData] = []:
	set(val):
		ducts = val
		emit_changed()

# --- SUBLAYER 4: ZONE E PUNTI DI DANNO (Damage Zones) ---
# Ogni elemento: ShipDamageData
@export var damages: Array[ShipDamageData] = []:
	set(val):
		damages = val
		emit_changed()

# --- SUBLAYER 5 / SEZIONE SHIP DRIVE: FILE SYSTEM & PASSWORD ---
# Ogni elemento in drive_files: ShipDriveFile
@export var drive_files: Array[ShipDriveFile] = []:
	set(val):
		drive_files = val
		emit_changed()

# Mappa percorsi cartella -> password (es. "Ship Drive/Programs/FlightControls": "FLIGHT-7815")
@export var drive_passwords: Dictionary = {}:
	set(val):
		drive_passwords = val
		emit_changed()

# --- SUBLAYER 6 / SEZIONE APPLICAZIONI MAINFRAME INSTALLATE ---
# Ogni elemento in installed_apps: ShipAppMetadata
@export var installed_apps: Array[ShipAppMetadata] = []:
	set(val):
		installed_apps = val
		emit_changed()

## Ricalcola la potenza totale di una stanza sommando i power_mw dei suoi dispositivi.
func update_room_power(room_id: String) -> void:
	for r in rooms:
		if r.id == room_id:
			var total: float = 0.0
			for d in r.devices:
				total += d.power_mw
			r.power_mw = total
			emit_changed()
			return

## Ricalcola la potenza di tutte le stanze.
func recalculate_all_powers() -> void:
	for r in rooms:
		var total: float = 0.0
		for d in r.devices:
			total += d.power_mw
		r.power_mw = total
	emit_changed()

## Generazione procedurale del layout della nave (TASK-019).
func get_ship_bounds() -> Rect2:
	if ship_bounds is Rect2:
		return ship_bounds
	return Rect2(30, 30, 500, 500)

func get_drone_spawn_pos() -> Vector2:
	if drone_spawn_pos is Vector2:
		return drone_spawn_pos
	return Vector2(10, 10)

func generate_random_layout(grid_size: float = 20.0) -> void:
	rooms.clear()
	ducts.clear()
	damages.clear()
	installed_apps.clear()
	drive_files.clear()
	drive_passwords.clear()
	recharge_room_id = ""
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var bounds: Rect2 = get_ship_bounds()
	var margin := grid_size * 2
	
	var room_templates := RoomDatabase.get_room_ids()
	if room_templates.is_empty():
		return

	# Garantiamo che ci siano alcune stanze fondamentali
	var mandatory := ["ponte_comando", "reattore_fusione", "supporto_vitale_min", "mainframe", "pod_drone"]
	
	# 1. Genera Stanze
	var room_count := rng.randi_range(8, 14)
	var generated_rects: Array[Rect2] = []
	var attempts := 0
	
	while generated_rects.size() < room_count and attempts < 300:
		attempts += 1
		var template_id: String = ""
		if generated_rects.size() < mandatory.size():
			template_id = mandatory[generated_rects.size()]
		else:
			template_id = room_templates[rng.randi() % room_templates.size()]
			
		var template_data := RoomDatabase.get_room_data(template_id)
		
		var min_size: Vector2 = template_data.min_size
		var w:float = ceil(min_size.x / grid_size) * grid_size
		var h:float = ceil(min_size.y / grid_size) * grid_size
		
		var max_x:float = floor((bounds.size.x - w - margin*2) / grid_size)
		var max_y:float = floor((bounds.size.y - h - margin*2) / grid_size)
		
		if max_x <= 0 or max_y <= 0: continue
		
		var rx := bounds.position.x + margin + (rng.randi() % int(max_x)) * grid_size
		var ry := bounds.position.y + margin + (rng.randi() % int(max_y)) * grid_size
		var new_rect := Rect2(rx, ry, w, h)
		
		var overlap := false
		for r in generated_rects:
			if new_rect.intersects(r.grow(grid_size)): 
				overlap = true
				break
		
		if not overlap:
			var room_id := "room_" + str(generated_rects.size() + 1)
			var new_room := ShipRoomData.new(room_id, template_data.name, new_rect)
			new_room.color = template_data.color
			new_room.border_color = new_room.color.lightened(0.3)
			new_room.is_on = true
			
			var def_devs: Array[String] = template_data.default_devices
			for d_name in def_devs:
				var is_reactor := str(d_name).contains("reattore")
				var new_dev := ShipDeviceData.new(
					room_id + "_" + str(d_name),
					str(d_name),
					new_rect.get_center()
				)
				new_dev.power_mw = 0.0 if is_reactor else 10.0
				new_dev.sector = new_room.name
				new_room.devices.append(new_dev)
			
			rooms.append(new_room)
			generated_rects.append(new_rect)
	
	# 2. Connetti stanze con condotti (L-shape)
	for i in range(rooms.size() - 1):
		var r1 = rooms[i]
		var r2 = rooms[i+1]
		var p1: Vector2 = r1.rect.get_center()
		var p2: Vector2 = r2.rect.get_center()
		p1 = (p1 / grid_size).round() * grid_size
		p2 = (p2 / grid_size).round() * grid_size
		
		var mid := Vector2(p2.x, p1.y)
		
		ducts.append(ShipDuctData.new("duct_" + str(i) + "_a", "Duct " + str(i) + " A", p1, mid))
		ducts.append(ShipDuctData.new("duct_" + str(i) + "_b", "Duct " + str(i) + " B", mid, p2))

	if not rooms.is_empty():
		var r0 = rooms[0]
		drone_spawn_pos = r0.rect.position - Vector2(grid_size, grid_size)
		recharge_room_id = r0.id
		
	# 3. Installa Applicazioni Base
	var base_apps := ["FlightControl", "PowerGrid", "Cams", "LifeSupport", "Diagnostics", "Terminal", "SystemMap", "Logbook"]
	for app_name in base_apps:
		var res_path := "res://Applications/%s/%s_app.tres" % [app_name, app_name.to_snake_case()]
		if ResourceLoader.exists(res_path):
			var res = load(res_path)
			if res is AppResource:
				install_app_resource(res)
				
	recalculate_all_powers()
	emit_changed()
	
# --- METODI DI QUERY E RICERCA ---

func get_room_by_id(room_id: String) -> ShipRoomData:
	for r in rooms:
		if r.id == room_id:
			return r
	return null

func get_room_at(pos: Vector2) -> ShipRoomData:
	for r in rooms:
		if r.rect.has_point(pos):
			return r
	return null

func get_duct_by_id(duct_id: String) -> ShipDuctData:
	for d in ducts:
		if d.id == duct_id:
			return d
	return null

func get_device_by_id(dev_id: String) -> ShipDeviceData:
	for r in rooms:
		for dev in r.devices:
			if dev.id == dev_id:
				return dev
	return null

func get_damage_by_id(dmg_id: String) -> ShipDamageData:
	for d in damages:
		if d.id == dmg_id:
			return d
	return null

func remove_room(room_id: String) -> bool:
	for i in range(rooms.size()):
		if rooms[i].id == room_id:
			rooms.remove_at(i)
			emit_changed()
			return true
	return false

func remove_duct(duct_id: String) -> bool:
	for i in range(ducts.size()):
		if ducts[i].id == duct_id:
			ducts.remove_at(i)
			emit_changed()
			return true
	return false

func remove_device(dev_id: String) -> bool:
	for r in rooms:
		for j in range(r.devices.size()):
			if r.devices[j].id == dev_id:
				r.devices.remove_at(j)
				update_room_power(r.id)
				emit_changed()
				return true
	return false

func remove_damage(dmg_id: String) -> bool:
	for i in range(damages.size()):
		if damages[i].id == dmg_id:
			damages.remove_at(i)
			emit_changed()
			return true
	return false

func get_drive_file_by_path(path: String) -> ShipDriveFile:
	for f in drive_files:
		if f.path == path:
			return f
	return null

func set_drive_file(path: String, content: String, is_protected: bool = false, desc: String = "") -> void:
	for i in range(drive_files.size()):
		if drive_files[i].path == path:
			drive_files[i].content = content
			drive_files[i].is_protected = is_protected
			if desc != "":
				drive_files[i].desc = desc
			emit_changed()
			return
	drive_files.append(ShipDriveFile.new(path, content, is_protected, desc))
	emit_changed()

func remove_drive_file(path: String) -> bool:
	for i in range(drive_files.size()):
		if drive_files[i].path == path:
			drive_files.remove_at(i)
			emit_changed()
			return true
	return false

func get_drive_password(path: String) -> String:
	return drive_passwords.get(path, "")

func set_drive_password(path: String, password: String) -> void:
	drive_passwords[path] = password
	emit_changed()

func remove_drive_password(path: String) -> bool:
	if drive_passwords.has(path):
		drive_passwords.erase(path)
		emit_changed()
		return true
	return false

func get_installed_app_by_id(app_id: String) -> ShipAppMetadata:
	for app in installed_apps:
		if app.id == app_id:
			return app
	return null

func set_installed_app(app_id: String, app_data: Variant) -> void:
	var metadata: ShipAppMetadata = null
	if app_data is ShipAppMetadata:
		metadata = app_data
	elif app_data is Dictionary:
		metadata = ShipAppMetadata.new()
		metadata.from_dict(app_data)
	
	if not metadata: return
	metadata.id = app_id

	for i in range(installed_apps.size()):
		if installed_apps[i].id == app_id:
			installed_apps[i] = metadata
			emit_changed()
			return
	installed_apps.append(metadata)
	emit_changed()

func remove_installed_app(app_id: String) -> bool:
	for i in range(installed_apps.size()):
		if installed_apps[i].id == app_id:
			installed_apps.remove_at(i)
			emit_changed()
			return true
	return false

func get_apps_for_role(role_name: String, is_solo: bool = false) -> Array[ShipAppMetadata]:
	var result: Array[ShipAppMetadata] = []
	var clean_role := role_name.strip_edges()
	var is_super := (is_solo and (clean_role.is_empty() or clean_role == "Non Assegnato")) or clean_role.is_empty() or clean_role == "Capitano" or clean_role == "Captain" or clean_role == "Stagista" or clean_role == "HOST"
	
	for app in installed_apps:
		if is_super:
			result.append(app)
			continue
		
		var allowed: Array = app.roles
		if allowed.is_empty():
			result.append(app)
			continue
			
		var role_matched := false
		for r in allowed:
			var r_str: String = str(r).strip_edges().to_lower()
			var c_str: String = clean_role.to_lower()
			if r_str == "*" or r_str == "all":
				role_matched = true
				break
			if r_str == c_str:
				role_matched = true
				break
			# Verifica sinonimi comuni (es. Pilota / Pilot, Soldato / Soldier, Ingegnere / Engineer)
			if (c_str in ["pilota", "pilot"] and r_str in ["pilota", "pilot"]) or (c_str in ["ingegnere", "engineer"] and r_str in ["ingegnere", "engineer"]) or (c_str in ["soldato", "soldier", "tattico"] and r_str in ["soldato", "soldier", "tattico", "tattico / armi", "armi"]) or (c_str in ["hacker", "cyber"] and r_str in ["hacker", "cyber"]):
				role_matched = true
				break
		
		if role_matched:
			result.append(app)
	
	if result.is_empty() and (clean_role == "Non Assegnato" or clean_role == ""):
		for app in installed_apps:
			result.append(app)
	
	return result

## Installa una AppResource nel blueprint registrando app, file di drive e password
func install_app_resource(res: AppResource) -> void:
	if not res:
		return
	set_installed_app(res.app_id, res.to_dict())
	var df_list := res.get_formatted_drive_files("Ship Drive")
	for df in df_list:
		set_drive_file(df["path"], df["content"], df["is_protected"], df["desc"])
	if not res.drive_folder.is_empty() and not res.default_password.is_empty():
		var folder_rel: String = res.drive_folder.trim_prefix("/").trim_suffix("/")
		var full_folder := "Ship Drive/%s" % folder_rel if not folder_rel.begins_with("Ship Drive/") else folder_rel
		set_drive_password(full_folder, res.default_password)

## Disinstalla una AppResource dal blueprint rimuovendo app, i suoi file di drive e la password
func uninstall_app_resource(res: AppResource) -> bool:
	if not res:
		return false
	var removed := remove_installed_app(res.app_id)
	
	# Rimuovi file associati alla risorsa
	var df_list := res.get_formatted_drive_files("Ship Drive")
	for df in df_list:
		remove_drive_file(df["path"])
		
	# Rimuovi anche eventuali file nella cartella dell'applicazione
	if not res.drive_folder.is_empty():
		var folder_rel: String = res.drive_folder.trim_prefix("/").trim_suffix("/")
		var full_folder := "Ship Drive/%s" % folder_rel if not folder_rel.begins_with("Ship Drive/") else folder_rel
		remove_drive_password(full_folder)
		
		# Rimuovi tutti i drive_files che iniziano con la cartella dell'app
		var prefix := full_folder + "/"
		var i := drive_files.size() - 1
		while i >= 0:
			var f_path: String = drive_files[i].get("path")
			if f_path.begins_with(prefix) or f_path == full_folder:
				drive_files.remove_at(i)
				emit_changed()
			i -= 1
			
	return removed

## Disinstalla un'app tramite ID rimuovendo l'app, i relativi file di drive e password
func uninstall_app_by_id(app_id: String, app_res: AppResource = null) -> bool:
	var res := app_res
	if not res:
		var ssm = Engine.get_singleton("ShipSoftwareManager") if Engine.has_singleton("ShipSoftwareManager") else null
		if ssm and ssm.has_method("get_registered_app"):
			res = ssm.get_registered_app(app_id)
	if not res:
		var res_path := "res://Applications/%s/%s_app.tres" % [app_id.to_pascal_case(), app_id]
		if ResourceLoader.exists(res_path):
			res = load(res_path) as AppResource
			
	if res:
		return uninstall_app_resource(res)
		
	# Fallback basato sui metadati presenti in installed_apps
	var app_dict := get_installed_app_by_id(app_id)
	var removed := remove_installed_app(app_id)
	if not app_dict.is_empty():
		var folder: String = str(app_dict.get("drive_folder"))
		if not folder.is_empty():
			var folder_rel := folder.trim_prefix("/").trim_suffix("/")
			var full_folder := "Ship Drive/%s" % folder_rel if not folder_rel.begins_with("Ship Drive/") else folder_rel
			remove_drive_password(full_folder)
			var prefix := full_folder + "/"
			var i := drive_files.size() - 1
			while i >= 0:
				var f_path: String = drive_files[i].get("path")
				if f_path.begins_with(prefix) or f_path == full_folder:
					drive_files.remove_at(i)
					emit_changed()
				i -= 1
	return removed

## Restituisce le AppResource installate (usando ShipSoftwareManager o ricostruendole dai dati)
func get_installed_app_resources() -> Array[AppResource]:
	var result: Array[AppResource] = []
	for app_dict in installed_apps:
		var app_id: String = str(app_dict.get("id"))
		var ssm = Engine.get_singleton("ShipSoftwareManager") if Engine.has_singleton("ShipSoftwareManager") else null
		var res: AppResource = null
		if ssm and ssm.has_method("get_registered_app"):
			res = ssm.get_registered_app(app_id)
		if not res:
			var res_path := "res://Applications/%s/%s_app.tres" % [app_id.to_pascal_case(), app_id]
			if ResourceLoader.exists(res_path):
				res = load(res_path) as AppResource
		if not res:
			res = AppResource.new()
			res.app_id = app_id
			res.title = str(app_dict.get("title"))
			res.description = str(app_dict.get("description"))
			res.scene_path = str(app_dict.get("scene_path"))
			res.icon_color = app_dict.get("icon_color")
			var raw_roles = app_dict.get("roles")
			if raw_roles is Array:
				for r in raw_roles:
					res.roles.append(str(r))
		result.append(res)
	return result

## Restituisce le AppResource autorizzate per il ruolo specificato
func get_app_resources_for_role(role_name: String, is_solo: bool = false) -> Array[AppResource]:
	var all_res := get_installed_app_resources()
	var filtered: Array[AppResource] = []
	for r in all_res:
		if r.is_role_allowed(role_name, is_solo):
			filtered.append(r)
	return filtered

## Converte l'intera Blueprint in un dizionario serializzabile (es. per JSON o salvataggi di rete)
func to_dict() -> Dictionary:
	var rooms_copy: Array = []
	for r in rooms:
		rooms_copy.append(r.to_dict())
	
	var ducts_copy: Array = []
	for d in ducts:
		ducts_copy.append(d.to_dict())
		
	var damages_copy: Array = []
	for dmg in damages:
		damages_copy.append(dmg.to_dict())
		
	var drive_files_copy: Array = []
	for df in drive_files:
		drive_files_copy.append(df.to_dict())
		
	var installed_apps_copy: Array = []
	for app in installed_apps:
		installed_apps_copy.append(app.to_dict())
		
	var flux_modifiers_copy: Array = []
	for fm in flux_modifiers:
		flux_modifiers_copy.append(fm.to_dict())

	return {
		"ship_id": ship_id,
		"ship_name": ship_name,
		"ship_class": ship_class,
		"ship_mesh_path": ship_mesh_path,
		"ship_bounds": [ship_bounds.position.x, ship_bounds.position.y, ship_bounds.size.x, ship_bounds.size.y],
		"drone_spawn_pos": [drone_spawn_pos.x, drone_spawn_pos.y],
		"drone_spawn_heading": drone_spawn_heading,
		"flux": flux,
		"flux_modifiers": flux_modifiers_copy,
		"recharge_room_id": recharge_room_id,
		"rooms": rooms_copy,
		"ducts": ducts_copy,
		"damages": damages_copy,
		"drive_files": drive_files_copy,
		"drive_passwords": drive_passwords.duplicate(true),
		"installed_apps": installed_apps_copy
	}

## Ricostruisce la blueprint a partire da un dizionario deserializzato
func from_dict(data: Dictionary) -> void:
	if data.has("ship_id"):
		ship_id = str(data["ship_id"])
	if data.has("ship_name"):
		ship_name = str(data["ship_name"])
	if data.has("ship_class"):
		ship_class = str(data["ship_class"])
	if data.has("ship_mesh_path"):
		ship_mesh_path = str(data["ship_mesh_path"])
		
	if data.has("ship_bounds"):
		var b = data["ship_bounds"]
		if b is Array and b.size() == 4:
			ship_bounds = Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3]))
		elif b is Rect2:
			ship_bounds = b
			
	if data.has("drone_spawn_pos"):
		var p = data["drone_spawn_pos"]
		if p is Array and p.size() == 2:
			drone_spawn_pos = Vector2(float(p[0]), float(p[1]))
		elif p is Vector2:
			drone_spawn_pos = p
			
	if data.has("drone_spawn_heading"):
		drone_spawn_heading = float(data["drone_spawn_heading"])
	
	if data.has("flux"):
		flux = int(data["flux"])
	if data.has("flux_modifiers") and data["flux_modifiers"] is Array:
		flux_modifiers.clear()
		for fm in data["flux_modifiers"]:
			if fm is Dictionary:
				var mod := ShipFluxModifier.new()
				mod.from_dict(fm)
				flux_modifiers.append(mod)
			elif fm is ShipFluxModifier:
				flux_modifiers.append(fm)
		
	if data.has("recharge_room_id"):
		recharge_room_id = str(data["recharge_room_id"])
		
	if data.has("rooms") and data["rooms"] is Array:
		rooms.clear()
		for r in data["rooms"]:
			if r is Dictionary:
				var body := ShipRoomData.new()
				body.from_dict(r)
				rooms.append(body)
			elif r is ShipRoomData:
				rooms.append(r)
		
	if data.has("ducts") and data["ducts"] is Array:
		ducts.clear()
		for d in data["ducts"]:
			if d is Dictionary:
				var body := ShipDuctData.new()
				body.from_dict(d)
				ducts.append(body)
			elif d is ShipDuctData:
				ducts.append(d)

	if data.has("damages") and data["damages"] is Array:
		damages.clear()
		for dmg in data["damages"]:
			if dmg is Dictionary:
				var body := ShipDamageData.new()
				body.from_dict(dmg)
				damages.append(body)
			elif dmg is ShipDamageData:
				damages.append(dmg)

	if data.has("drive_files") and data["drive_files"] is Array:
		drive_files.clear()
		for item in data["drive_files"]:
			if item is Dictionary:
				var body := ShipDriveFile.new()
				body.from_dict(item)
				drive_files.append(body)
			elif item is ShipDriveFile:
				drive_files.append(item)

	if data.has("drive_passwords") and data["drive_passwords"] is Dictionary:
		drive_passwords = (data["drive_passwords"] as Dictionary).duplicate(true)

	if data.has("installed_apps") and data["installed_apps"] is Array:
		installed_apps.clear()
		for app in data["installed_apps"]:
			if app is Dictionary:
				var body := ShipAppMetadata.new()
				body.from_dict(app)
				installed_apps.append(body)
			elif app is ShipAppMetadata:
				installed_apps.append(app)

	emit_changed()

## Esporta la Blueprint in formato JSON su disco
func export_to_json(file_path: String) -> Error:
	var dict := to_dict()
	var json_text := JSON.stringify(dict, "\t")
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(json_text)
	file.close()
	return OK

## Importa la Blueprint da formato JSON
func import_from_json(file_path: String) -> Error:
	if not FileAccess.file_exists(file_path):
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var json_text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_err := json.parse(json_text)
	if parse_err != OK:
		return parse_err
	if json.data is Dictionary:
		from_dict(json.data as Dictionary)
		return OK
	return ERR_INVALID_DATA

## Clona l'istanza corrente
func clone() -> ShipBlueprint:
	var copy := ShipBlueprint.new()
	copy.from_dict(to_dict())
	return copy

static func get_default_blueprint() -> ShipBlueprint:
	const PATH := "res://Outside/ShipSublayer/default_ship_blueprint.tres"
	if ResourceLoader.exists(PATH):
		var res = ResourceLoader.load(PATH)
		if res is ShipBlueprint:
			return res as ShipBlueprint
	var bp := ShipBlueprint.new()
	bp.create_default_ship()
	return bp
