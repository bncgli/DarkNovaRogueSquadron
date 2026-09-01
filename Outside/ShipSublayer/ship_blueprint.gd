@tool
class_name ShipBlueprint
extends Resource

## Struttura dati (Sublayer / Blueprint) per l'astronave in Dark Nova: Rogue Squadron.
## Contiene in modo unificato la geometria delle stanze, i condotti per i droni,
## la rete energetica (dispositivi nelle stanze) e le zone di danno strutturale.

signal blueprint_changed()

# --- METADATI GENERALI ---
const SHIP_CLASSES = ["Corvette", "Frigate", "Destroyer", "Cruiser", "Freighter", "Science Vessel", "Scout", "Carrier", "Station"]
const DEVICE_CATEGORIES = ["command", "propulsion", "life_support", "engineering", "tactical", "sensors", "comms", "mainframe", "defense", "cargo", "service", "utility"]

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

@export var ship_bounds: Rect2 = Rect2(60, 30, 480, 420):
	set(val):
		ship_bounds = val
		emit_changed()

@export var drone_spawn_pos: Vector2 = Vector2(300, 80):
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

@export var flux_modifiers: Array[Dictionary] = []:
	set(val):
		flux_modifiers = val
		emit_changed()

# --- TASK-019: Zona Ricarica ---
@export var recharge_room_id: String = "":
	set(val):
		recharge_room_id = val
		emit_changed()

# --- SUBLAYER 1: STANZE E SETTORI (Rooms / Hull Layout) ---
# Ogni elemento: { "id": str, "name": str, "rect": Rect2, "color": Color, "border_color": Color, "devices": Array[Dictionary], "power_mw": float, "is_on": bool }
@export var rooms: Array[Dictionary] = []:
	set(val):
		rooms = val
		emit_changed()

# --- SUBLAYER 2: CONDOTTI DI MANUTENZIONE (Ducts System) ---
# Ogni elemento: { "id": str, "name": str, "from": Vector2, "to": Vector2, "width": float, "is_blocked": bool }
@export var ducts: Array[Dictionary] = []:
	set(val):
		ducts = val
		emit_changed()

# --- SUBLAYER 4: ZONE E PUNTI DI DANNO (Damage Zones) ---
# Ogni elemento: { "id": str, "type": str, "name": str, "pos": Vector2, "sector": str, "severity": float, "repair_cost": float, "desc": str, "system_impact": str }
@export var damages: Array[Dictionary] = []:
	set(val):
		damages = val
		emit_changed()

# --- SUBLAYER 5 / SEZIONE SHIP DRIVE: FILE SYSTEM & PASSWORD ---
# Ogni elemento in drive_files: { "path": str, "content": str, "is_protected": bool, "desc": str }
@export var drive_files: Array[Dictionary] = []:
	set(val):
		drive_files = val
		emit_changed()

# Mappa percorsi cartella -> password (es. "Ship Drive/Programs/FlightControls": "FLIGHT-7815")
@export var drive_passwords: Dictionary = {}:
	set(val):
		drive_passwords = val
		emit_changed()

# --- SUBLAYER 6 / SEZIONE APPLICAZIONI MAINFRAME INSTALLATE ---
# Ogni elemento in installed_apps: { "id": str, "title": str, "description": str, "scene_path": str, "icon_color": Color, "roles": Array[String] }
@export var installed_apps: Array[Dictionary] = []:
	set(val):
		installed_apps = val
		emit_changed()

## Ricalcola la potenza totale di una stanza sommando i power_mw dei suoi dispositivi.
func update_room_power(room_id: String) -> void:
	for r in rooms:
		if r.get("id", "") == room_id:
			var total: float = 0.0
			var devs: Array = r.get("devices", [])
			for d in devs:
				total += float(d.get("power_mw", 0.0))
			r["power_mw"] = total
			emit_changed()
			return

## Ricalcola la potenza di tutte le stanze.
func recalculate_all_powers() -> void:
	for r in rooms:
		var total: float = 0.0
		var devs: Array = r.get("devices", [])
		for d in devs:
			total += float(d.get("power_mw", 0.0))
		r["power_mw"] = total
	emit_changed()

func _init() -> void:
	if rooms.is_empty() and ducts.is_empty():
		create_default_ship()

## Inizializza la blueprint con la nave vuota.
func create_default_ship() -> void:
	ship_id = "new ship"
	ship_name = "new ship"
	ship_class = ""
	ship_bounds = Rect2(60, 30, 500, 500)
	drone_spawn_pos = Vector2(65, 35)
	drone_spawn_heading = 0
	
## Generazione procedurale del layout della nave (TASK-019).
func generate_random_layout(grid_size: float = 20.0) -> void:
	rooms.clear()
	ducts.clear()
	damages.clear()
	recharge_room_id = ""
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var bounds := ship_bounds
	var margin := grid_size * 2
	
	var room_templates := RoomDatabase.get_room_ids()
	if room_templates.is_empty():
		return

	# 1. Genera Stanze
	var room_count := rng.randi_range(5, 10)
	var generated_rects: Array[Rect2] = []
	var attempts := 0
	
	while generated_rects.size() < room_count and attempts < 150:
		attempts += 1
		var template_id: String = room_templates[rng.randi() % room_templates.size()]
		var template_data := RoomDatabase.get_room_data(template_id)
		
		var min_size: Vector2 = template_data.get("min_size", Vector2(60, 60))
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
			var new_room := {
				"id": room_id,
				"name": template_data.get("name", room_id),
				"category": template_data.get("category", "utility"),
				"rect": new_rect,
				"color": template_data.get("color", Color(0.3, 0.3, 0.3, 0.5)),
				"border_color": template_data.get("color", Color(0.3, 0.3, 0.3, 0.5)).lightened(0.3),
				"devices": [],
				"is_on": true,
				"power_mw": 0.0
			}
			
			var def_devs: Array = template_data.get("default_devices", [])
			for d_name in def_devs:
				new_room["devices"].append({
					"id": room_id + "_" + str(d_name),
					"name": str(d_name),
					"pos": new_rect.get_center(),
					"is_generator": str(d_name).contains("reattore"),
					"power_mw": 10.0 if not str(d_name).contains("reattore") else 0.0,
					"is_on": true
				})
			
			rooms.append(new_room)
			generated_rects.append(new_rect)
	
	# 2. Connetti stanze con condotti (L-shape)
	for i in range(rooms.size() - 1):
		var p1: Vector2 = rooms[i]["rect"].get_center()
		var p2: Vector2 = rooms[i+1]["rect"].get_center()
		p1 = (p1 / grid_size).round() * grid_size
		p2 = (p2 / grid_size).round() * grid_size
		
		var mid := Vector2(p2.x, p1.y)
		
		ducts.append({
			"id": "duct_" + str(i) + "_a",
			"from": p1,
			"to": mid,
			"width": 14.0,
			"is_blocked": false
		})
		ducts.append({
			"id": "duct_" + str(i) + "_b",
			"from": mid,
			"to": p2,
			"width": 14.0,
			"is_blocked": false
		})

	if not rooms.is_empty():
		drone_spawn_pos = rooms[0]["rect"].position - Vector2(grid_size, grid_size)
		recharge_room_id = rooms[0]["id"]
		
	recalculate_all_powers()
	emit_changed()
	
# --- METODI DI QUERY E RICERCA ---

func get_room_by_id(room_id: String) -> Dictionary:
	for r in rooms:
		if r.get("id", "") == room_id:
			return r
	return {}

func get_room_at(pos: Vector2) -> Dictionary:
	for r in rooms:
		var rect: Rect2 = r.get("rect", Rect2())
		if rect.has_point(pos):
			return r
	return {}

func get_duct_by_id(duct_id: String) -> Dictionary:
	for d in ducts:
		if d.get("id", "") == duct_id:
			return d
	return {}

func get_device_by_id(dev_id: String) -> Dictionary:
	for r in rooms:
		var devs: Array = r.get("devices", [])
		for dev in devs:
			if dev.get("id", "") == dev_id:
				return dev
	return {}

func get_damage_by_id(dmg_id: String) -> Dictionary:
	for d in damages:
		if d.get("id", "") == dmg_id:
			return d
	return {}

func remove_room(room_id: String) -> bool:
	for i in range(rooms.size()):
		if rooms[i].get("id", "") == room_id:
			rooms.remove_at(i)
			emit_changed()
			return true
	return false

func remove_duct(duct_id: String) -> bool:
	for i in range(ducts.size()):
		if ducts[i].get("id", "") == duct_id:
			ducts.remove_at(i)
			emit_changed()
			return true
	return false

func remove_device(dev_id: String) -> bool:
	for r in rooms:
		var devs: Array = r.get("devices", [])
		for i in range(devs.size()):
			if devs[i].get("id", "") == dev_id:
				devs.remove_at(i)
				update_room_power(r.get("id", ""))
				emit_changed()
				return true
	return false

func remove_damage(dmg_id: String) -> bool:
	for i in range(damages.size()):
		if damages[i].get("id", "") == dmg_id:
			damages.remove_at(i)
			emit_changed()
			return true
	return false

func get_drive_file_by_path(path: String) -> Dictionary:
	for f in drive_files:
		if f.get("path", "") == path:
			return f
	return {}

func set_drive_file(path: String, content: String, is_protected: bool = false, desc: String = "") -> void:
	for i in range(drive_files.size()):
		if drive_files[i].get("path", "") == path:
			drive_files[i]["content"] = content
			drive_files[i]["is_protected"] = is_protected
			if desc != "":
				drive_files[i]["desc"] = desc
			emit_changed()
			return
	drive_files.append({
		"path": path,
		"content": content,
		"is_protected": is_protected,
		"desc": desc
	})
	emit_changed()

func remove_drive_file(path: String) -> bool:
	for i in range(drive_files.size()):
		if drive_files[i].get("path", "") == path:
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

func get_installed_app_by_id(app_id: String) -> Dictionary:
	for app in installed_apps:
		if app.get("id", "") == app_id:
			return app
	return {}

func set_installed_app(app_id: String, app_data: Dictionary) -> void:
	for i in range(installed_apps.size()):
		if installed_apps[i].get("id", "") == app_id:
			installed_apps[i] = app_data.duplicate(true)
			installed_apps[i]["id"] = app_id
			emit_changed()
			return
	var new_app := app_data.duplicate(true)
	new_app["id"] = app_id
	installed_apps.append(new_app)
	emit_changed()

func remove_installed_app(app_id: String) -> bool:
	for i in range(installed_apps.size()):
		if installed_apps[i].get("id", "") == app_id:
			installed_apps.remove_at(i)
			emit_changed()
			return true
	return false

func get_apps_for_role(role_name: String, is_solo: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var clean_role := role_name.strip_edges()
	var is_super := (is_solo and (clean_role.is_empty() or clean_role == "Non Assegnato")) or clean_role.is_empty() or clean_role == "Capitano" or clean_role == "Captain" or clean_role == "Factotum" or clean_role == "HOST"
	
	for app in installed_apps:
		if is_super:
			result.append(app.duplicate(true))
			continue
		
		var allowed: Array = app.get("roles", [])
		if allowed.is_empty():
			result.append(app.duplicate(true))
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
			result.append(app.duplicate(true))
	
	if result.is_empty() and (clean_role == "Non Assegnato" or clean_role == ""):
		for app in installed_apps:
			result.append(app.duplicate(true))
	
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
			var f_path: String = drive_files[i].get("path", "")
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
		var folder: String = str(app_dict.get("drive_folder", ""))
		if not folder.is_empty():
			var folder_rel := folder.trim_prefix("/").trim_suffix("/")
			var full_folder := "Ship Drive/%s" % folder_rel if not folder_rel.begins_with("Ship Drive/") else folder_rel
			remove_drive_password(full_folder)
			var prefix := full_folder + "/"
			var i := drive_files.size() - 1
			while i >= 0:
				var f_path: String = drive_files[i].get("path", "")
				if f_path.begins_with(prefix) or f_path == full_folder:
					drive_files.remove_at(i)
					emit_changed()
				i -= 1
	return removed

## Restituisce le AppResource installate (usando ShipSoftwareManager o ricostruendole dai dati)
func get_installed_app_resources() -> Array[AppResource]:
	var result: Array[AppResource] = []
	for app_dict in installed_apps:
		var app_id: String = str(app_dict.get("id", ""))
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
			res.title = str(app_dict.get("title", app_id))
			res.description = str(app_dict.get("description", ""))
			res.scene_path = str(app_dict.get("scene_path", ""))
			res.icon_color = app_dict.get("icon_color", Color(0, 0.79, 0.95, 1.0))
			var raw_roles = app_dict.get("roles", [])
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
	for r: Dictionary in rooms:
		var rc: Dictionary = r.duplicate(true)
		if rc.has("rect") and rc["rect"] is Rect2:
			var rect: Rect2 = rc["rect"]
			rc["rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		if rc.has("color") and rc["color"] is Color:
			var col: Color = rc["color"]
			rc["color"] = [col.r, col.g, col.b, col.a]
		if rc.has("border_color") and rc["border_color"] is Color:
			var col: Color = rc["border_color"]
			rc["border_color"] = [col.r, col.g, col.b, col.a]
		rooms_copy.append(rc)
	
	var ducts_copy: Array = []
	for d: Dictionary in ducts:
		var dc: Dictionary = d.duplicate(true)
		if dc.has("from") and dc["from"] is Vector2:
			dc["from"] = [dc["from"].x, dc["from"].y]
		if dc.has("to") and dc["to"] is Vector2:
			dc["to"] = [dc["to"].x, dc["to"].y]
		ducts_copy.append(dc)
		
	var damages_copy: Array = []
	for dmg: Dictionary in damages:
		var dmg_c: Dictionary = dmg.duplicate(true)
		if dmg_c.has("pos") and dmg_c["pos"] is Vector2:
			dmg_c["pos"] = [dmg_c["pos"].x, dmg_c["pos"].y]
		damages_copy.append(dmg_c)
		
	var drive_files_copy: Array = []
	for df: Dictionary in drive_files:
		drive_files_copy.append(df.duplicate(true))
		
	var installed_apps_copy: Array = []
	for app: Dictionary in installed_apps:
		var ac: Dictionary = app.duplicate(true)
		if ac.has("icon_color") and ac["icon_color"] is Color:
			var col: Color = ac["icon_color"]
			ac["icon_color"] = [col.r, col.g, col.b, col.a]
		installed_apps_copy.append(ac)
		
	return {
		"ship_id": ship_id,
		"ship_name": ship_name,
		"ship_class": ship_class,
		"ship_mesh_path": ship_mesh_path,
		"ship_bounds": [ship_bounds.position.x, ship_bounds.position.y, ship_bounds.size.x, ship_bounds.size.y],
		"drone_spawn_pos": [drone_spawn_pos.x, drone_spawn_pos.y],
		"drone_spawn_heading": drone_spawn_heading,
		"flux": flux,
		"flux_modifiers": flux_modifiers.duplicate(true),
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
	if data.has("ship_bounds") and data["ship_bounds"] is Array and data["ship_bounds"].size() == 4:
		var b: Array = data["ship_bounds"]
		ship_bounds = Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3]))
	if data.has("drone_spawn_pos") and data["drone_spawn_pos"] is Array and data["drone_spawn_pos"].size() == 2:
		var p: Array = data["drone_spawn_pos"]
		drone_spawn_pos = Vector2(float(p[0]), float(p[1]))
	if data.has("drone_spawn_heading"):
		drone_spawn_heading = float(data["drone_spawn_heading"])
	
	if data.has("flux"):
		flux = int(data["flux"])
	if data.has("flux_modifiers") and data["flux_modifiers"] is Array:
		flux_modifiers = (data["flux_modifiers"] as Array).duplicate(true)
		
	if data.has("recharge_room_id"):
		recharge_room_id = str(data["recharge_room_id"])
		
	if data.has("rooms") and data["rooms"] is Array:
		var new_rooms: Array[Dictionary] = []
		for r in data["rooms"]:
			if r is Dictionary:
				var rd := (r as Dictionary).duplicate(true)
				if rd.has("rect") and rd["rect"] is Array and rd["rect"].size() == 4:
					var arr: Array = rd["rect"]
					rd["rect"] = Rect2(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
				if rd.has("color") and rd["color"] is Array and rd["color"].size() >= 3:
					var arr: Array = rd["color"]
					var a := float(arr[3]) if arr.size() > 3 else 1.0
					rd["color"] = Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
				if rd.has("border_color") and rd["border_color"] is Array and rd["border_color"].size() >= 3:
					var arr: Array = rd["border_color"]
					var a := float(arr[3]) if arr.size() > 3 else 1.0
					rd["border_color"] = Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
				new_rooms.append(rd)
		rooms = new_rooms
		
	if data.has("ducts") and data["ducts"] is Array:
		var new_ducts: Array[Dictionary] = []
		for d in data["ducts"]:
			if d is Dictionary:
				var dd := (d as Dictionary).duplicate(true)
				if dd.has("from") and dd["from"] is Array and dd["from"].size() == 2:
					var arr: Array = dd["from"]
					dd["from"] = Vector2(float(arr[0]), float(arr[1]))
				if dd.has("to") and dd["to"] is Array and dd["to"].size() == 2:
					var arr: Array = dd["to"]
					dd["to"] = Vector2(float(arr[0]), float(arr[1]))
				new_ducts.append(dd)
		ducts = new_ducts

	if data.has("damages") and data["damages"] is Array:
		var new_damages: Array[Dictionary] = []
		for dmg in data["damages"]:
			if dmg is Dictionary:
				var dmg_d := (dmg as Dictionary).duplicate(true)
				if dmg_d.has("pos") and dmg_d["pos"] is Array and dmg_d["pos"].size() == 2:
					var arr: Array = dmg_d["pos"]
					dmg_d["pos"] = Vector2(float(arr[0]), float(arr[1]))
				new_damages.append(dmg_d)
		damages = new_damages

	if data.has("drive_files") and data["drive_files"] is Array:
		var new_df: Array[Dictionary] = []
		for item in data["drive_files"]:
			if item is Dictionary:
				new_df.append((item as Dictionary).duplicate(true))
		drive_files = new_df

	if data.has("drive_passwords") and data["drive_passwords"] is Dictionary:
		drive_passwords = (data["drive_passwords"] as Dictionary).duplicate(true)

	if data.has("installed_apps") and data["installed_apps"] is Array:
		var new_apps: Array[Dictionary] = []
		for app in data["installed_apps"]:
			if app is Dictionary:
				var ad := (app as Dictionary).duplicate(true)
				if ad.has("icon_color") and ad["icon_color"] is Array and ad["icon_color"].size() >= 3:
					var arr: Array = ad["icon_color"]
					var a := float(arr[3]) if arr.size() > 3 else 1.0
					ad["icon_color"] = Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
				elif ad.has("icon_color") and ad["icon_color"] is String:
					ad["icon_color"] = Color.from_string(ad["icon_color"], Color.WHITE)
				new_apps.append(ad)
		installed_apps = new_apps

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
