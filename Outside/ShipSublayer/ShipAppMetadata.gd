@tool
class_name ShipAppMetadata
extends Resource

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var developer: String = ""
@export var category: String = "Applicazioni"
@export var scene_path: String = ""
@export var icon_color: Color = Color(0, 0.79, 0.95, 1.0)
@export var roles: Array[String] = []
@export var drive_folder: String = ""

func _init(p_id: String = "", p_title: String = "", p_scene: String = "") -> void:
	id = p_id
	title = p_title
	scene_path = p_scene

func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"description": description,
		"developer": developer,
		"category": category,
		"scene_path": scene_path,
		"icon_color": [icon_color.r, icon_color.g, icon_color.b, icon_color.a],
		"roles": roles.duplicate(),
		"drive_folder": drive_folder
	}

func from_dict(data: Dictionary) -> void:
	id = data.get("id", id)
	title = data.get("title", title)
	description = data.get("description", description)
	developer = data.get("developer", developer)
	category = data.get("category", category)
	scene_path = data.get("scene_path", scene_path)
	drive_folder = data.get("drive_folder", drive_folder)
	if data.has("icon_color"):
		var ic = data["icon_color"]
		if ic is Array and ic.size() >= 3:
			var a := float(ic[3]) if ic.size() > 3 else 1.0
			icon_color = Color(float(ic[0]), float(ic[1]), float(ic[2]), a)
		elif ic is Color:
			icon_color = ic
	if data.has("roles") and data["roles"] is Array:
		roles.clear()
		for r in data["roles"]:
			roles.append(str(r))
