extends Control

## Titolo e dimensioni preferite per la finestra di GodotOS
const APP_TITLE: String = "FLUX WALLET"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(550, 450)

## Riferimenti ai nodi UI (utilizzando Unique Names %)
@onready var flux_label: Label = %FluxLabel
@onready var modifiers_container: VBoxContainer = %ModifiersContainer
@onready var disconnected_overlay: Control = %DisconnectedOverlay

func _ready() -> void:
	_configure_window()
	_connect_system_signals()
	_update_connection_state()
	_refresh_data()

func _configure_window() -> void:
	custom_minimum_size = DEFAULT_WINDOW_SIZE
	# Se istanziata all'interno di una FakeWindow di GodotOS:
	var parent_window = get_parent()
	if parent_window and "window_title" in parent_window:
		parent_window.window_title = APP_TITLE

func _connect_system_signals() -> void:
	# 1. Collegamento allo stato di connessione/missione della nave
	if SpaceWorldManager:
		SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
	
	# 2. Collegamento ai cambiamenti della blueprint
	var bp = _get_blueprint()
	if bp:
		if not bp.blueprint_changed.is_connected(_refresh_data):
			bp.blueprint_changed.connect(_refresh_data)

func _exit_tree() -> void:
	# Disconnessione segnali e pulizia
	if SpaceWorldManager and SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
		SpaceWorldManager.ship_connection_changed.disconnect(_on_ship_connection_changed)
	
	var bp = _get_blueprint()
	if bp and bp.blueprint_changed.is_connected(_refresh_data):
		bp.blueprint_changed.disconnect(_refresh_data)

func _on_ship_connection_changed(_is_connected: bool) -> void:
	_update_connection_state()
	_refresh_data()

func _update_connection_state() -> void:
	var is_operational: bool = false
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		is_operational = SpaceWorldManager.is_ship_connected()
	
	# Mostra o nasconde l'overlay di blocco
	if disconnected_overlay:
		disconnected_overlay.visible = not is_operational
	
	# Abilita/disabilita l'input di processing
	set_process(is_operational)

func _get_blueprint() -> ShipBlueprint:
	if SpaceWorldManager and SpaceWorldManager.has_method("get_ship_blueprint"):
		return SpaceWorldManager.get_ship_blueprint()
	return null

func _refresh_data() -> void:
	var bp = _get_blueprint()
	if not bp:
		return
	
	# Aggiorna il valore principale di Flux
	if flux_label:
		flux_label.text = str(bp.flux) + " FLUX"
		if bp.flux >= 0:
			flux_label.add_theme_color_override("font_color", Color.WHITE)
		else:
			flux_label.add_theme_color_override("font_color", Color.CORAL)
	
	# Aggiorna la lista dei modificatori
	if modifiers_container:
		# Pulisce la lista precedente
		for child in modifiers_container.get_children():
			child.queue_free()
		
		if bp.flux_modifiers.is_empty():
			var empty_label := Label.new()
			empty_label.text = "Nessun modificatore attivo."
			empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			modifiers_container.add_child(empty_label)
			return
		
		# Intestazione Tabella
		var header := HBoxContainer.new()
		var h_mod := Label.new()
		h_mod.text = "MOD."
		h_mod.custom_minimum_size.x = 80
		h_mod.add_theme_color_override("font_color", Color.GRAY)
		header.add_child(h_mod)
		
		var h_owner := Label.new()
		h_owner.text = "PROPRIETARIO"
		h_owner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_owner.add_theme_color_override("font_color", Color.GRAY)
		header.add_child(h_owner)
		
		var h_reason := Label.new()
		h_reason.text = "CAUSALE"
		h_reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_reason.add_theme_color_override("font_color", Color.GRAY)
		header.add_child(h_reason)
		
		modifiers_container.add_child(header)
		modifiers_container.add_child(HSeparator.new())
		
		# Righe Modificatori
		for mod in bp.flux_modifiers:
			var row := HBoxContainer.new()
			
			var val_label := Label.new()
			var val = mod.get("value")
			val_label.text = str(val)
			if val >= 0:
				val_label.add_theme_color_override("font_color", Color.GREEN)
				val_label.text = "+" + val_label.text
			else:
				val_label.add_theme_color_override("font_color", Color.CRIMSON)
			val_label.custom_minimum_size.x = 80
			row.add_child(val_label)
			
			var owner_label := Label.new()
			owner_label.text = str(mod.get("owner"))
			owner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(owner_label)
			
			var reason_label := Label.new()
			reason_label.text = str(mod.get("reason"))
			reason_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(reason_label)
			
			modifiers_container.add_child(row)
