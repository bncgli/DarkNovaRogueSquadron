class_name InputSettingsTab
extends Control

## InputSettingsTab
## Gestisce la configurazione dei controlli, il rilevamento dei joypad/controller,
## la calibrazione di deadzone e sensibilità, e la rimappatura tasti con salvataggio su user://input_config.json.

signal config_saved()
signal config_reset()

const CONFIG_PATH := "user://input_config.json"
const DEFAULT_DEADZONE := 0.15
const DEFAULT_SENSITIVITY := 1.0

const MANAGED_ACTIONS: Array[Dictionary] = [
	{"action": "ship_forward", "label": "Volo: Accelera / Avanti", "category": "Volo"},
	{"action": "ship_backward", "label": "Volo: Frena / Indietro", "category": "Volo"},
	{"action": "ship_strife_left", "label": "Volo: Trasla a Sinistra", "category": "Volo"},
	{"action": "ship_strife_right", "label": "Volo: Trasla a Destra", "category": "Volo"},
	{"action": "ship_vertical_up", "label": "Volo: Quota Su", "category": "Volo"},
	{"action": "ship_vertical_down", "label": "Volo: Quota Giù", "category": "Volo"},
	{"action": "ship_rotate_up", "label": "Volo: Beccheggio Su", "category": "Volo"},
	{"action": "ship_rotate_down", "label": "Volo: Beccheggio Giù", "category": "Volo"},
	{"action": "ship_rotate_left", "label": "Volo: Imbardata Sinistra", "category": "Volo"},
	{"action": "ship_rotate_right", "label": "Volo: Imbardata Destra", "category": "Volo"},
	{"action": "ship_roll_left", "label": "Volo: Rollio Sinistra", "category": "Volo"},
	{"action": "ship_roll_right", "label": "Volo: Rollio Destra", "category": "Volo"},
	{"action": "weapon_fire", "label": "Armi: Fuoco Principale", "category": "Armi"},
	{"action": "weapon_aim", "label": "Armi: Cattura / Mira Torretta", "category": "Armi"}
]

# Stato calibrazione
var current_deadzone: float = DEFAULT_DEADZONE
var current_sensitivity: float = DEFAULT_SENSITIVITY
var remapping_action: String = ""
var remapping_button: Button = null

# Riferimenti nodi UI
var joypad_label: Label
var deadzone_slider: HSlider
var deadzone_value_label: Label
var sensitivity_slider: HSlider
var sensitivity_value_label: Label
var live_axes_label: Label
var action_list_container: VBoxContainer
var save_button: Button
var reset_button: Button

func _ready() -> void:
	ensure_default_actions()
	_build_ui()
	load_and_apply_config()
	_update_ui_state()
	
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)

func _process(_delta: float) -> void:
	_update_live_axes()

# --- ASSICURA CHE LE AZIONI ESISTANO IN INPUTMAP ---

static func ensure_default_actions() -> void:
	if not InputMap.has_action("weapon_fire"):
		InputMap.add_action("weapon_fire")
		var mouse_fire := InputEventMouseButton.new()
		mouse_fire.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("weapon_fire", mouse_fire)
		var joy_fire := InputEventJoypadButton.new()
		joy_fire.button_index = JOY_BUTTON_RIGHT_SHOULDER
		InputMap.action_add_event("weapon_fire", joy_fire)

	if not InputMap.has_action("weapon_aim"):
		InputMap.add_action("weapon_aim")
		var key_aim := InputEventKey.new()
		key_aim.physical_keycode = KEY_SPACE
		InputMap.action_add_event("weapon_aim", key_aim)
		var joy_aim := InputEventJoypadButton.new()
		joy_aim.button_index = JOY_BUTTON_LEFT_SHOULDER
		InputMap.action_add_event("weapon_aim", joy_aim)

# --- COSTRUZIONE UI PROGRAMMATICA ---

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(margin)
	
	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)
	
	# 1. Sezione Periferiche Rilevate
	var joy_section := VBoxContainer.new()
	var joy_title := Label.new()
	joy_title.text = "Periferiche Connesse:"
	joy_title.add_theme_font_size_override("font_size", 16)
	joy_section.add_child(joy_title)
	
	joypad_label = Label.new()
	joypad_label.text = "Scansione periferiche..."
	joypad_label.modulate = Color(0.7, 0.9, 1.0)
	joy_section.add_child(joypad_label)
	root_vbox.add_child(joy_section)
	
	# 2. Sezione Calibrazione Assi (Deadzone & Sensibilità)
	var calib_section := VBoxContainer.new()
	var calib_title := Label.new()
	calib_title.text = "Calibrazione Controller / Joystick:"
	calib_title.add_theme_font_size_override("font_size", 16)
	calib_section.add_child(calib_title)
	
	# Deadzone row
	var dz_box := HBoxContainer.new()
	var dz_lbl := Label.new()
	dz_lbl.text = "Deadzone Assi (Zona Morta):"
	dz_lbl.custom_minimum_size = Vector2(200, 0)
	dz_box.add_child(dz_lbl)
	
	deadzone_slider = HSlider.new()
	deadzone_slider.min_value = 0.05
	deadzone_slider.max_value = 0.35
	deadzone_slider.step = 0.01
	deadzone_slider.value = current_deadzone
	deadzone_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deadzone_slider.value_changed.connect(_on_deadzone_slider_changed)
	dz_box.add_child(deadzone_slider)
	
	deadzone_value_label = Label.new()
	deadzone_value_label.custom_minimum_size = Vector2(60, 0)
	deadzone_value_label.text = "%.2f" % current_deadzone
	dz_box.add_child(deadzone_value_label)
	calib_section.add_child(dz_box)
	
	# Sensitivity row
	var sens_box := HBoxContainer.new()
	var sens_lbl := Label.new()
	sens_lbl.text = "Sensibilità / Moltiplicatore:"
	sens_lbl.custom_minimum_size = Vector2(200, 0)
	sens_box.add_child(sens_lbl)
	
	sensitivity_slider = HSlider.new()
	sensitivity_slider.min_value = 0.5
	sensitivity_slider.max_value = 3.0
	sensitivity_slider.step = 0.1
	sensitivity_slider.value = current_sensitivity
	sensitivity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sensitivity_slider.value_changed.connect(_on_sensitivity_slider_changed)
	sens_box.add_child(sensitivity_slider)
	
	sensitivity_value_label = Label.new()
	sensitivity_value_label.custom_minimum_size = Vector2(60, 0)
	sensitivity_value_label.text = "%.1fx" % current_sensitivity
	sens_box.add_child(sensitivity_value_label)
	calib_section.add_child(sens_box)
	
	# Live axes feedback
	live_axes_label = Label.new()
	live_axes_label.text = "Assi Live: -"
	live_axes_label.modulate = Color(0.8, 0.8, 0.8)
	calib_section.add_child(live_axes_label)
	root_vbox.add_child(calib_section)
	
	# Separatore
	root_vbox.add_child(HSeparator.new())
	
	# 3. Sezione Rimappatura Azioni
	var remap_title := Label.new()
	remap_title.text = "Mappatura Comandi (Tastiera, Mouse & Joypad):"
	remap_title.add_theme_font_size_override("font_size", 16)
	root_vbox.add_child(remap_title)
	
	action_list_container = VBoxContainer.new()
	action_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_list_container.add_theme_constant_override("separation", 6)
	root_vbox.add_child(action_list_container)
	
	# Separatore
	root_vbox.add_child(HSeparator.new())
	
	# 4. Pulsanti Salvataggio & Reset
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_END
	btn_box.add_theme_constant_override("separation", 10)
	
	reset_button = Button.new()
	reset_button.text = "Ripristina Predefiniti"
	reset_button.pressed.connect(_on_reset_pressed)
	btn_box.add_child(reset_button)
	
	save_button = Button.new()
	save_button.text = "Salva Configurazione"
	save_button.pressed.connect(_on_save_pressed)
	btn_box.add_child(save_button)
	
	root_vbox.add_child(btn_box)

func _update_ui_state() -> void:
	_update_joypad_info()
	if deadzone_slider:
		deadzone_slider.value = current_deadzone
	if deadzone_value_label:
		deadzone_value_label.text = "%.2f" % current_deadzone
	if sensitivity_slider:
		sensitivity_slider.value = current_sensitivity
	if sensitivity_value_label:
		sensitivity_value_label.text = "%.1fx" % current_sensitivity
	_populate_action_list()

func _update_joypad_info() -> void:
	if joypad_label == null:
		return
	var connected := Input.get_connected_joypads()
	if connected.is_empty():
		joypad_label.text = "Nessun controller/joystick connesso (Tastiera/Mouse attivo)"
	else:
		var list_str := ""
		for id in connected:
			var joy_name := Input.get_joy_name(id)
			list_str += "[%d] %s  " % [id, joy_name]
		joypad_label.text = list_str.strip_edges()

func _update_live_axes() -> void:
	if live_axes_label == null:
		return
	var connected := Input.get_connected_joypads()
	if connected.is_empty():
		live_axes_label.text = "Assi Live: Nessun joypad connesso"
		return
	var primary_id: int = connected[0]
	var lx := Input.get_joy_axis(primary_id, JOY_AXIS_LEFT_X)
	var ly := Input.get_joy_axis(primary_id, JOY_AXIS_LEFT_Y)
	var rx := Input.get_joy_axis(primary_id, JOY_AXIS_RIGHT_X)
	var ry := Input.get_joy_axis(primary_id, JOY_AXIS_RIGHT_Y)
	var lt := Input.get_joy_axis(primary_id, JOY_AXIS_TRIGGER_LEFT)
	var rt := Input.get_joy_axis(primary_id, JOY_AXIS_TRIGGER_RIGHT)
	live_axes_label.text = "Assi Live (Pad %d) -> LX: %+.2f | LY: %+.2f | RX: %+.2f | RY: %+.2f | L2: %+.2f | R2: %+.2f" % [
		primary_id, lx, ly, rx, ry, lt, rt
	]

func _populate_action_list() -> void:
	if action_list_container == null:
		return
	for child in action_list_container.get_children():
		child.queue_free()
	
	for item in MANAGED_ACTIONS:
		var action_name: String = item["action"]
		var action_label: String = item["label"]
		
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var lbl := Label.new()
		lbl.text = action_label
		lbl.custom_minimum_size = Vector2(230, 0)
		row.add_child(lbl)
		
		var binding_lbl := Label.new()
		binding_lbl.text = get_action_binding_text(action_name)
		binding_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		binding_lbl.modulate = Color(0.9, 0.9, 0.5)
		row.add_child(binding_lbl)
		
		var remap_btn := Button.new()
		remap_btn.text = "Rimappa"
		remap_btn.custom_minimum_size = Vector2(90, 0)
		remap_btn.pressed.connect(_on_remap_button_pressed.bind(action_name, remap_btn))
		row.add_child(remap_btn)
		
		action_list_container.add_child(row)

static func get_action_binding_text(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "Non assegnato"
	var events := InputMap.action_get_events(action_name)
	if events.is_empty():
		return "Non assegnato"
	var names: Array[String] = []
	for ev in events:
		if ev is InputEventKey:
			var code: int = int(ev.physical_keycode) if ev.physical_keycode != 0 else int(ev.keycode)
			names.append("Key: " + OS.get_keycode_string(code))
		elif ev is InputEventJoypadButton:
			names.append("Pad Btn: %d" % ev.button_index)
		elif ev is InputEventJoypadMotion:
			var sign_str := "+" if ev.axis_value > 0 else "-"
			names.append("Pad Asse %d%s" % [ev.axis, sign_str])
		elif ev is InputEventMouseButton:
			names.append("Mouse Btn: %d" % ev.button_index)
	return " / ".join(names)

# --- RIMAPPATURA TASTI & EVENTI ---

func _on_remap_button_pressed(action_name: String, btn: Button) -> void:
	if remapping_action != "":
		_cancel_remapping()
	remapping_action = action_name
	remapping_button = btn
	btn.text = "Premi un tasto..."
	btn.modulate = Color(1.5, 1.2, 0.3)

func _cancel_remapping() -> void:
	if remapping_button and is_instance_valid(remapping_button):
		remapping_button.text = "Rimappa"
		remapping_button.modulate = Color(1.0, 1.0, 1.0)
	remapping_action = ""
	remapping_button = null

func _unhandled_input(event: InputEvent) -> void:
	if remapping_action == "":
		return
	
	if event is InputEventKey:
		if event.pressed and not event.is_echo():
			if event.keycode == KEY_ESCAPE:
				_cancel_remapping()
				get_viewport().set_input_as_handled()
				return
			_apply_remapping(remapping_action, event)
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		if event.pressed:
			_apply_remapping(remapping_action, event)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.pressed:
			_apply_remapping(remapping_action, event)
			get_viewport().set_input_as_handled()

func _apply_remapping(action_name: String, event: InputEvent) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	
	# Cancella eventi precedenti e assegna il nuovo
	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, event)
	InputMap.action_set_deadzone(action_name, current_deadzone)
	
	_cancel_remapping()
	_populate_action_list()

# --- HANDLER SLIDER & PULSANTI ---

func _on_deadzone_slider_changed(val: float) -> void:
	current_deadzone = val
	if deadzone_value_label:
		deadzone_value_label.text = "%.2f" % val
	apply_deadzone_to_actions(current_deadzone)

func _on_sensitivity_slider_changed(val: float) -> void:
	current_sensitivity = val
	if sensitivity_value_label:
		sensitivity_value_label.text = "%.1fx" % val

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_update_joypad_info()

func _on_save_pressed() -> void:
	save_config_to_file()
	config_saved.emit()

func _on_reset_pressed() -> void:
	reset_defaults()
	config_reset.emit()

# --- SERIALIZZAZIONE E PERSISTENZA JSON ---

static func apply_deadzone_to_actions(deadzone: float) -> void:
	for item in MANAGED_ACTIONS:
		var act: String = item["action"]
		if InputMap.has_action(act):
			InputMap.action_set_deadzone(act, deadzone)

func save_config_to_file(path: String = CONFIG_PATH) -> Error:
	var data: Dictionary = {
		"deadzone": current_deadzone,
		"sensitivity": current_sensitivity,
		"actions": {}
	}
	
	for item in MANAGED_ACTIONS:
		var act: String = item["action"]
		if InputMap.has_action(act):
			var ev_list: Array = []
			for ev in InputMap.action_get_events(act):
				var d := event_to_dict(ev)
				if not d.is_empty():
					ev_list.append(d)
			data["actions"][act] = ev_list
			
	var json_str := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Impossibile salvare config input su %s: %s" % [path, FileAccess.get_open_error()])
		return FileAccess.get_open_error()
	file.store_string(json_str)
	file.close()
	return OK

func load_and_apply_config(path: String = CONFIG_PATH) -> bool:
	if not FileAccess.file_exists(path):
		apply_deadzone_to_actions(current_deadzone)
		return false
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var content := file.get_as_text()
	file.close()
	
	var test_json := JSON.new()
	if test_json.parse(content) != OK:
		push_warning("Errore di parsing JSON per input config in %s" % path)
		return false
	
	var data: Dictionary = test_json.data
	if data.has("deadzone"):
		current_deadzone = float(data["deadzone"])
	if data.has("sensitivity"):
		current_sensitivity = float(data["sensitivity"])
	
	apply_deadzone_to_actions(current_deadzone)
	
	if data.has("actions") and data["actions"] is Dictionary:
		var actions_dict: Dictionary = data["actions"]
		for act in actions_dict.keys():
			if not InputMap.has_action(act):
				InputMap.add_action(act)
			var ev_dicts: Array = actions_dict[act]
			if not ev_dicts.is_empty():
				InputMap.action_erase_events(act)
				for ed in ev_dicts:
					var ev := dict_to_event(ed)
					if ev != null:
						InputMap.action_add_event(act, ev)
				InputMap.action_set_deadzone(act, current_deadzone)
				
	_update_ui_state()
	return true

static func load_and_apply_config_static(path: String = CONFIG_PATH) -> bool:
	ensure_default_actions()
	if not FileAccess.file_exists(path):
		apply_deadzone_to_actions(DEFAULT_DEADZONE)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var content := file.get_as_text()
	file.close()
	var test_json := JSON.new()
	if test_json.parse(content) != OK:
		return false
	var data: Dictionary = test_json.data
	var dz: float = float(data.get("deadzone", DEFAULT_DEADZONE))
	apply_deadzone_to_actions(dz)
	if data.has("actions") and data["actions"] is Dictionary:
		var actions_dict: Dictionary = data["actions"]
		for act in actions_dict.keys():
			if not InputMap.has_action(act):
				InputMap.add_action(act)
			var ev_dicts: Array = actions_dict[act]
			if not ev_dicts.is_empty():
				InputMap.action_erase_events(act)
				for ed in ev_dicts:
					var ev := dict_to_event(ed)
					if ev != null:
						InputMap.action_add_event(act, ev)
				InputMap.action_set_deadzone(act, dz)
	return true

func reset_defaults() -> void:
	current_deadzone = DEFAULT_DEADZONE
	current_sensitivity = DEFAULT_SENSITIVITY
	
	# Reimposta InputMap ai default caricando da project settings
	InputMap.load_from_project_settings()
	ensure_default_actions()
	apply_deadzone_to_actions(current_deadzone)
	_update_ui_state()
	save_config_to_file()

# --- CONVERSIONE EVENTI <-> DICTIONARY ---

static func event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {
			"type": "key",
			"keycode": event.keycode,
			"physical_keycode": event.physical_keycode
		}
	elif event is InputEventJoypadButton:
		return {
			"type": "joy_button",
			"button_index": event.button_index
		}
	elif event is InputEventJoypadMotion:
		return {
			"type": "joy_motion",
			"axis": event.axis,
			"axis_value": event.axis_value
		}
	elif event is InputEventMouseButton:
		return {
			"type": "mouse_button",
			"button_index": event.button_index
		}
	return {}

static func dict_to_event(dict: Dictionary) -> InputEvent:
	var t: String = dict.get("type", "")
	match t:
		"key":
			var ev := InputEventKey.new()
			ev.keycode = dict.get("keycode", 0)
			ev.physical_keycode = dict.get("physical_keycode", 0)
			return ev
		"joy_button":
			var ev := InputEventJoypadButton.new()
			ev.button_index = dict.get("button_index", 0)
			return ev
		"joy_motion":
			var ev := InputEventJoypadMotion.new()
			ev.axis = dict.get("axis", 0)
			ev.axis_value = dict.get("axis_value", 0.0)
			return ev
		"mouse_button":
			var ev := InputEventMouseButton.new()
			ev.button_index = dict.get("button_index", 1)
			return ev
	return null
