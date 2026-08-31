@tool
class_name ShipAppResource
extends AppResource

## Classe di supporto e retrocompatibilità per ShipAppResource (ora unificata in AppResource).

func _init() -> void:
	if category == "Applicazioni":
		category = "Sistemi Nave"
