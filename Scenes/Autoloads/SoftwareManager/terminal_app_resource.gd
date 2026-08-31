@tool
class_name TerminalAppResource
extends AppResource

## Classe di supporto e retrocompatibilità per TerminalAppResource (ora unificata in AppResource).

func _init() -> void:
	if category == "Applicazioni":
		category = "Terminale Locale"
