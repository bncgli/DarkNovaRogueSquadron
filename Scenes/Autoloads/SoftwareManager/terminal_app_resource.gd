@tool
class_name TerminalAppResource
extends AppResource

## Risorsa per la definizione delle applicazioni e utility locali del Terminale/Desktop in GodotOS.
## Gestisce i programmi non legati alla simulazione fisica nave, come shell, file manager,
## visualizzatori e configurazioni locali dell'OS.

@export_group("Terminale & Sistema Locale")
## Se l'applicazione fa parte del core di sistema dell'OS
@export var is_system_app: bool = false:
	set(val):
		is_system_app = val
		emit_changed()

## Comando CLI associato (se eseguibile direttamente dal terminale shell)
@export var terminal_command: String = "":
	set(val):
		terminal_command = val
		emit_changed()

## Se l'applicazione deve essere visualizzata sempre nella Taskbar o desktop
@export var is_pinned_to_taskbar: bool = false:
	set(val):
		is_pinned_to_taskbar = val
		emit_changed()

func _init() -> void:
	category = "Terminale Locale"

## Converte la risorsa in dizionario
func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["is_system_app"] = is_system_app
	d["terminal_command"] = terminal_command
	d["is_pinned_to_taskbar"] = is_pinned_to_taskbar
	return d
