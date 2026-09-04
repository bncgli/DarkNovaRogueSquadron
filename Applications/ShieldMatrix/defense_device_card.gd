class_name DefenseDeviceCard
extends PanelContainer

## Componente UI Scheda Dispositivo di Difesa Attiva (Point-Defense Gatling / Flack Launcher).
## Mostra telemetria, munizioni, cooldown e permette la riassegnazione del settore difeso.

signal sector_changed(device_id: String, new_sector: int)

@onready var icon_label: Label = get_node_or_null("%IconLabel")
@onready var name_label: Label = get_node_or_null("%NameLabel")
@onready var status_badge: Label = get_node_or_null("%StatusBadge")
@onready var type_label: Label = get_node_or_null("%TypeLabel")
@onready var ammo_label: Label = get_node_or_null("%AmmoLabel")
@onready var ammo_bar: ProgressBar = get_node_or_null("%AmmoBar")
@onready var cooldown_bar: ProgressBar = get_node_or_null("%CooldownBar")
@onready var sector_option_button: OptionButton = get_node_or_null("%SectorOptionButton")

var device_id: String = ""
var device_data: Dictionary = {}
var can_edit: bool = true
var _is_updating_ui: bool = false

func _ready() -> void:
	_init_sector_options()
	if sector_option_button and not sector_option_button.item_selected.is_connected(_on_sector_selected):
		sector_option_button.item_selected.connect(_on_sector_selected)

func _init_sector_options() -> void:
	if not sector_option_button:
		return
	sector_option_button.clear()
	# Enum settori: 0: FORE (Prua), 1: PORT (Babordo), 2: STARBOARD (Tribordo), 3: AFT (Poppa)
	sector_option_button.add_item("Prua (FORE)", 0)
	sector_option_button.add_item("Babordo (PORT)", 1)
	sector_option_button.add_item("Tribordo (STARBOARD)", 2)
	sector_option_button.add_item("Poppa (AFT)", 3)

func setup(p_data: Dictionary, p_can_edit: bool = true) -> void:
	device_data = p_data.duplicate(true)
	device_id = str(device_data.get("id", ""))
	can_edit = p_can_edit
	_init_sector_options()
	update_state(device_data, can_edit)

func update_state(p_data: Dictionary, p_can_edit: bool = true) -> void:
	device_data = p_data
	device_id = str(device_data.get("id", device_id))
	can_edit = p_can_edit
	_is_updating_ui = true
	
	var dev_name: String = str(device_data.get("name", "Dispositivo Difesa"))
	var dev_type: String = str(device_data.get("type", "GATLING")).to_upper()
	var ammo: int = int(device_data.get("ammo", 0))
	var max_ammo: int = int(device_data.get("max_ammo", ammo if ammo > 0 else 800))
	var sector: int = int(device_data.get("sector", 0))
	var cooldown: float = float(device_data.get("cooldown", 0.0))
	var cooldown_max: float = float(device_data.get("cooldown_max", 0.5 if dev_type == "GATLING" else 3.0))
	var status: String = str(device_data.get("status", "READY")).to_upper()
	
	if name_label:
		name_label.text = dev_name
	
	if icon_label:
		if dev_type == "GATLING":
			icon_label.text = "🔫"
		elif dev_type == "FLACK":
			icon_label.text = "✨"
		else:
			icon_label.text = "🛡️"
	
	if type_label:
		type_label.text = "TIPO: %s" % dev_type
	
	if ammo_label:
		ammo_label.text = "MUNIZIONI: %d / %d" % [ammo, max_ammo]
	
	if ammo_bar:
		ammo_bar.max_value = max_ammo
		ammo_bar.value = ammo
	
	if cooldown_bar:
		cooldown_bar.max_value = cooldown_max if cooldown_max > 0.0 else 1.0
		cooldown_bar.value = cooldown
		cooldown_bar.visible = (cooldown > 0.0)
	
	if status_badge:
		if ammo <= 0:
			status_badge.text = "● ESAURITO"
			status_badge.modulate = Color(1.0, 0.25, 0.25)
		elif cooldown > 0.0:
			status_badge.text = "⏳ RICARICA (%.1fs)" % cooldown
			status_badge.modulate = Color(1.0, 0.75, 0.2)
		else:
			status_badge.text = "● %s" % status
			status_badge.modulate = Color(0.25, 1.0, 0.4)
	
	if sector_option_button:
		_init_sector_options()
		for i in range(sector_option_button.item_count):
			if sector_option_button.get_item_id(i) == sector:
				sector_option_button.select(i)
				break
		sector_option_button.disabled = not can_edit
	
	_is_updating_ui = false

func set_permissions(p_can_edit: bool) -> void:
	can_edit = p_can_edit
	if sector_option_button:
		sector_option_button.disabled = not can_edit

func _on_sector_selected(index: int) -> void:
	if _is_updating_ui:
		return
	if not sector_option_button:
		return
	var selected_sector_id := sector_option_button.get_item_id(index)
	device_data["sector"] = selected_sector_id
	sector_changed.emit(device_id, selected_sector_id)
