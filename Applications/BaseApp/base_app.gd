class_name BaseApp
extends Control

## Classe base per le applicazioni GodotOS.
## Fornisce funzionalità comuni come il parsing di file .dat e la gestione della finestra.

var parent_window: FakeWindow = null

## Parsifica un file .dat formato INI/Key-Value
func _parse_dat_file(rel_path: String) -> Dictionary:
	var result: Dictionary = {}
	var abs_path := "user://files/%s" % rel_path
	if not FileAccess.file_exists(abs_path):
		return result
	
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if not file:
		return result
	
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#") or line.begins_with(";"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			continue
		
		var eq_pos := line.find("=")
		if eq_pos != -1:
			var key := line.substr(0, eq_pos).strip_edges()
			var val_str := line.substr(eq_pos + 1).strip_edges()
			if (val_str.begins_with("\"") and val_str.ends_with("\"") and val_str.length() >= 2) or (val_str.begins_with("'") and val_str.ends_with("'") and val_str.length() >= 2):
				val_str = val_str.substr(1, val_str.length() - 2).strip_edges()
			
			if key == "decryption_key":
				result[key] = val_str
			elif val_str.is_valid_float() and "." in val_str:
				result[key] = float(val_str)
			elif val_str.is_valid_int():
				result[key] = int(val_str)
			elif val_str.to_lower() == "true":
				result[key] = true
			elif val_str.to_lower() == "false":
				result[key] = false
			else:
				result[key] = val_str
	
	file.close()
	return result

## Configura le proprietà della finestra genitore
func _configure_window(title: String, size: Vector2, min_size: Vector2 = Vector2.ZERO) -> void:
	custom_minimum_size = size
	call_deferred("_setup_parent_window", title, size, min_size)

func _setup_parent_window(title: String, size: Vector2, min_size: Vector2 = Vector2.ZERO) -> void:
	parent_window = _find_parent_window()
	if parent_window:
		if "title_text" in parent_window:
			parent_window.title_text = title
		
		var title_label := parent_window.get_node_or_null("Top Bar/Title Text")
		if title_label and "text" in title_label:
			title_label.text = "[center]" + title
		
		var eff_min := min_size
		if eff_min == Vector2.ZERO:
			if custom_minimum_size != Vector2.ZERO:
				eff_min = Vector2(custom_minimum_size.x, custom_minimum_size.y + 30.0)
			elif size != Vector2.ZERO:
				eff_min = Vector2(size.x, size.y + 30.0)
		
		if eff_min != Vector2.ZERO:
			parent_window.custom_minimum_size = eff_min
		
		if size != Vector2.ZERO:
			var target_w := maxf(size.x, eff_min.x)
			var target_h := maxf(size.y, eff_min.y)
			if parent_window.size.x < target_w or parent_window.size.y < target_h:
				parent_window.size = Vector2(target_w, target_h)

func _find_parent_window() -> FakeWindow:
	var node: Node = get_parent()
	while node != null:
		if node is FakeWindow:
			return node
		node = node.get_parent()
	return null

## Helper per RBAC (Role-Based Access Control)
func _has_role(role: String) -> bool:
	var nm := get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("get_local_player_roles"):
		var roles: Array = nm.get_local_player_roles()
		return role in roles
	return true
