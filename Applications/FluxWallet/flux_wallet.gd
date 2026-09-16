extends Control

## Titolo e dimensioni preferite per la finestra di GodotOS
const APP_TITLE: String = "FLUX WALLET"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(550, 480)
const MIN_WINDOW_SIZE: Vector2 = Vector2(550, 480)

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
	custom_minimum_size = Vector2(550, 450)
	# Se istanziata all'interno di una FakeWindow di GodotOS:
	var parent_window := get_parent()
	while parent_window:
		if parent_window is FakeWindow:
			parent_window.title_text = APP_TITLE
			parent_window.size = DEFAULT_WINDOW_SIZE
			parent_window.custom_minimum_size = MIN_WINDOW_SIZE
			break
		parent_window = parent_window.get_parent()

func _connect_system_signals() -> void:
	# 1. Collegamento allo stato di connessione/missione della nave
	if SpaceWorldManager:
		if not SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
	
	# 2. Collegamento ai cambiamenti della blueprint
	var bp := _get_blueprint()
	if bp:
		if not bp.blueprint_changed.is_connected(_refresh_data):
			bp.blueprint_changed.connect(_refresh_data)

	# 3. Collegamento a FluxEconomyManager se disponibile
	var fem = _get_flux_economy_manager()
	if fem:
		if fem.has_signal("flux_balance_changed") and not fem.flux_balance_changed.is_connected(_on_flux_balance_changed):
			fem.flux_balance_changed.connect(_on_flux_balance_changed)
		if fem.has_signal("flux_score_changed") and not fem.flux_score_changed.is_connected(_on_flux_score_changed):
			fem.flux_score_changed.connect(_on_flux_score_changed)

func _exit_tree() -> void:
	# Disconnessione segnali e pulizia
	if SpaceWorldManager and SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
		SpaceWorldManager.ship_connection_changed.disconnect(_on_ship_connection_changed)
	
	var bp := _get_blueprint()
	if bp and bp.blueprint_changed.is_connected(_refresh_data):
		bp.blueprint_changed.disconnect(_refresh_data)

	var fem = _get_flux_economy_manager()
	if fem:
		if fem.has_signal("flux_balance_changed") and fem.flux_balance_changed.is_connected(_on_flux_balance_changed):
			fem.flux_balance_changed.disconnect(_on_flux_balance_changed)
		if fem.has_signal("flux_score_changed") and fem.flux_score_changed.is_connected(_on_flux_score_changed):
			fem.flux_score_changed.disconnect(_on_flux_score_changed)

func _get_flux_economy_manager() -> Node:
	if is_inside_tree() and get_tree().root.has_node("FluxEconomyManager"):
		return get_tree().root.get_node("FluxEconomyManager")
	return null

func _on_flux_balance_changed(_net: int, _liq: int, _deb: int) -> void:
	_refresh_data()

func _on_flux_score_changed(_score: float, _rating: String, _delta: float, _reason: String) -> void:
	_refresh_data()

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
	var bp := _get_blueprint()
	if not bp:
		return
	
	# Calcola il saldo netto contabile (saldo disponibile + somma algebrica dei modificatori)
	var total_mods: int = 0
	for mod in bp.flux_modifiers:
		if mod:
			total_mods += int(mod.value)
	var net_balance: int = bp.flux + total_mods

	# Aggiorna il valore principale di Flux
	if flux_label:
		var fem = _get_flux_economy_manager()
		var rating_str := ""
		if fem and fem.has_method("get_rating_letter"):
			rating_str = " | Rating: %s (%.0f)" % [fem.get_rating_letter(), fem.flux_score]
			
		if total_mods != 0:
			flux_label.text = "%d FLUX  (Netto Contabile: %+d FLUX)%s" % [bp.flux, net_balance, rating_str]
		else:
			flux_label.text = "%d FLUX%s" % [bp.flux, rating_str]
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
			var val: float = mod.value if mod else 0.0
			val_label.text = str(val)
			var is_rent_debt: bool = (mod != null and mod.owner == "Ship Rent Service")
			var is_credit_title: bool = (mod != null and mod.value > 0)
			
			if val >= 0:
				val_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4))
				val_label.text = "+" + val_label.text
			else:
				val_label.add_theme_color_override("font_color", Color.CRIMSON)
			val_label.custom_minimum_size.x = 80
			row.add_child(val_label)
			
			var owner_label := Label.new()
			if is_rent_debt:
				owner_label.text = "🔒 " + (mod.owner if mod else "") + " [BLOCKED]"
				owner_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.3))
			elif is_credit_title:
				owner_label.text = "💎 " + (mod.owner if mod else "") + " [TITOLO]"
				owner_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
			else:
				owner_label.text = "⚠️ " + (mod.owner if mod else "N/D") + " [DEBITO]"
				owner_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
			owner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(owner_label)
			
			var reason_label := Label.new()
			reason_label.text = mod.reason if mod else "N/D"
			if is_rent_debt:
				reason_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
			reason_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(reason_label)
			
			modifiers_container.add_child(row)
