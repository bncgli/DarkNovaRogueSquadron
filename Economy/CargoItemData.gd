@tool
class_name CargoItemData
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var category: String = "GENERAL"
@export var unit_mass_kg: float = 0.0
@export var unit_volume_m3: float = 0.0
@export var unit_base_value: float = 0.0
@export var is_contraband: bool = false
@export var is_snet_disk: bool = false
@export var description: String = ""
@export var quantity: int = 0
@export var metadata: Dictionary = {}

func _init(p_id: String = "", p_name: String = "", p_qty: int = 0) -> void:
	id = p_id
	name = p_name
	quantity = p_qty

func get_total_mass() -> float:
	return unit_mass_kg * float(quantity)

func get_total_volume() -> float:
	return unit_volume_m3 * float(quantity)

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"category": category,
		"unit_mass_kg": unit_mass_kg,
		"unit_volume_m3": unit_volume_m3,
		"unit_base_value": unit_base_value,
		"is_contraband": is_contraband,
		"is_snet_disk": is_snet_disk,
		"description": description,
		"quantity": quantity,
		"metadata": metadata.duplicate(true)
	}

func from_dict(data: Dictionary) -> void:
	id = data.get("id", id)
	name = data.get("name", name)
	category = data.get("category", category)
	unit_mass_kg = float(data.get("unit_mass_kg", unit_mass_kg))
	unit_volume_m3 = float(data.get("unit_volume_m3", unit_volume_m3))
	unit_base_value = float(data.get("unit_base_value", unit_base_value))
	is_contraband = bool(data.get("is_contraband", is_contraband))
	is_snet_disk = bool(data.get("is_snet_disk", is_snet_disk))
	description = data.get("description", description)
	quantity = int(data.get("quantity", quantity))
	if data.has("metadata") and data["metadata"] is Dictionary:
		metadata = data["metadata"].duplicate(true)
