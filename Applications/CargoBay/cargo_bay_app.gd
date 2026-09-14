class_name CargoBayApp
extends BaseApp

## CargoBayApp (Applications/CargoBay)
## Interfaccia diegetica a finestre di GodotOS per la gestione della Stiva Cargo:
## visualizzazione merci a bordo, monitoraggio capacità massa/volume ed espulsione carico.

const APP_TITLE: String = "Cargo Bay - Gestione Stiva"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(760, 560)
const MIN_WINDOW_SIZE: Vector2 = Vector2(600, 420)

# Percorsi storage diegetico e file di configurazione
const CONFIG_PATH_PRIMARY: String = "Ship Drive/Programs/CargoBay/cargo_bay_config.dat"
const CONFIG_PATH_FALLBACK: String = "Terminal Drive/Programs/CargoBay/cargo_bay_config.dat"

# Riferimenti UI - Header & Overlays
@onready var disconnected_overlay: Control = get_node_or_null("%DisconnectedOverlay")
@onready var status_sub_label: Label = get_node_or_null("%StatusSubLabel")

# Riferimenti UI - Inventario Stiva
@onready var mass_progress_bar: ProgressBar = get_node_or_null("%MassProgressBar")
@onready var mass_status_label: Label = get_node_or_null("%MassStatusLabel")
@onready var vol_progress_bar: ProgressBar = get_node_or_null("%VolProgressBar")
@onready var vol_status_label: Label = get_node_or_null("%VolStatusLabel")
@onready var cargo_item_list: ItemList = get_node_or_null("%CargoItemList")
@onready var item_details_label: RichTextLabel = get_node_or_null("%ItemDetailsLabel")
@onready var btn_jettison: Button = get_node_or_null("%BtnJettison")

# Stato runtime
var is_ship_connected: bool = false
var selected_cargo_idx: int = -1

# Riferimento al manager stiva (Autoload con fallback runtime)
var cargo_mgr: CargoManagerSingleton = null

func _ready() -> void:
	_configure_window(APP_TITLE, DEFAULT_WINDOW_SIZE, MIN_WINDOW_SIZE)
	_init_managers()
	_init_runtime_files()
	_load_config()
	_connect_signals()
	_check_initial_state()
	_refresh_all_views()

func _init_managers() -> void:
	if get_node_or_null("/root/CargoManager") is CargoManagerSingleton:
		cargo_mgr = get_node_or_null("/root/CargoManager") as CargoManagerSingleton
	elif cargo_mgr == null:
		cargo_mgr = CargoManagerSingleton.new()
		cargo_mgr.name = "CargoManagerFallback"
		add_child(cargo_mgr)

func _connect_signals() -> void:
	# SpaceWorldManager
	if SpaceWorldManager:
		if SpaceWorldManager.has_signal("ship_connection_changed"):
			SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
	
	# ShipDrive hot-reload
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("file_synced"):
		sdm.file_synced.connect(_on_drive_file_synced)
	
	# CargoManager Signals
	if cargo_mgr:
		cargo_mgr.cargo_updated.connect(_on_cargo_updated)
		cargo_mgr.item_added.connect(_on_cargo_item_added)
		cargo_mgr.item_removed.connect(_on_cargo_item_removed)
		cargo_mgr.overload_prevented.connect(_on_overload_prevented)
	
	# UI Signals
	if cargo_item_list:
		cargo_item_list.item_selected.connect(_on_cargo_item_selected)
	if btn_jettison:
		btn_jettison.pressed.connect(_on_jettison_pressed)

func _check_initial_state() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		_set_ship_connected(SpaceWorldManager.is_ship_connected())
	else:
		_set_ship_connected(true)

func _set_ship_connected(connected: bool) -> void:
	is_ship_connected = connected
	if disconnected_overlay:
		disconnected_overlay.visible = not connected

func _on_ship_connection_changed(connected: bool) -> void:
	_set_ship_connected(connected)

# ==============================================================================
# GESTIONE .DAT CONFIG
# ==============================================================================

func _init_runtime_files() -> void:
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_method("create_file"):
		if not sdm.has_file(CONFIG_PATH_PRIMARY):
			var default_content := "[SYSTEM]\napp_name=CargoBayApp\nversion=1.0.0\nstatus=OPERATIONAL\n\n[LIMITS]\nmax_mass_kg=2000.0\nmax_volume_m3=100.0\n"
			sdm.create_file(CONFIG_PATH_PRIMARY, default_content, true, "Parametri stiva cargo e limiti massa/volume.")

func _load_config() -> void:
	var parsed := _parse_dat_file(CONFIG_PATH_PRIMARY)
	if parsed.is_empty():
		parsed = _parse_dat_file(CONFIG_PATH_FALLBACK)
	
	if parsed.has("max_mass_kg") and cargo_mgr:
		cargo_mgr.max_mass_kg = float(parsed["max_mass_kg"])
	if parsed.has("max_volume_m3") and cargo_mgr:
		cargo_mgr.max_volume_m3 = float(parsed["max_volume_m3"])

func _on_drive_file_synced(path: String) -> void:
	if path == CONFIG_PATH_PRIMARY or path == CONFIG_PATH_FALLBACK:
		_load_config()
		_refresh_all_views()

# ==============================================================================
# LOGICA VISTA INVENTARIO
# ==============================================================================

func _refresh_all_views() -> void:
	_refresh_cargo_inventory()

func _refresh_cargo_inventory() -> void:
	if not cargo_mgr:
		return
	
	var total_mass := cargo_mgr.get_total_mass()
	var max_mass := cargo_mgr.max_mass_kg
	var total_vol := cargo_mgr.get_total_volume()
	var max_vol := cargo_mgr.max_volume_m3
	
	if mass_progress_bar:
		mass_progress_bar.max_value = max_mass
		mass_progress_bar.value = total_mass
	if mass_status_label:
		var mass_pct := (total_mass / max_mass * 100.0) if max_mass > 0 else 0.0
		mass_status_label.text = "Massa Stiva: %.1f / %.1f kg (%.1f%%)" % [total_mass, max_mass, mass_pct]
	
	if vol_progress_bar:
		vol_progress_bar.max_value = max_vol
		vol_progress_bar.value = total_vol
	if vol_status_label:
		var vol_pct := (total_vol / max_vol * 100.0) if max_vol > 0 else 0.0
		vol_status_label.text = "Volume Stiva: %.1f / %.1f m³ (%.1f%%)" % [total_vol, max_vol, vol_pct]
	
	if cargo_item_list:
		cargo_item_list.clear()
		var items := cargo_mgr.get_cargo_list()
		for item in items:
			var item_name := item.name if item else "N/D"
			var qty := item.quantity if item else 0
			var mass := (item.unit_mass_kg if item else 0.0) * qty
			var cat := item.category if item else "GENERAL"
			var flags := ""
			if item and item.is_contraband:
				flags += " [ILLEGALE]"
			if item and item.is_snet_disk:
				var meta: Dictionary = item.metadata if item else {}
				if bool(meta.get("ice_broken")):
					flags += " [S-NET: DECRIPTATO]"
				else:
					flags += " [S-NET: ICE-BLOCCATO]"
			
			var line := "%s (x%d) - %.1f kg [%s]%s" % [item_name, qty, mass, cat, flags]
			cargo_item_list.add_item(line)
		
		if selected_cargo_idx >= 0 and selected_cargo_idx < items.size():
			cargo_item_list.select(selected_cargo_idx)
			_display_cargo_details(items[selected_cargo_idx])
		else:
			if items.size() > 0:
				selected_cargo_idx = 0
				cargo_item_list.select(0)
				_display_cargo_details(items[0])
			else:
				selected_cargo_idx = -1
				if item_details_label:
					item_details_label.text = "[color=#888888]Stiva vuota. Nessun carico a bordo.[/color]"

func _display_cargo_details(item: Variant) -> void:
	if not item_details_label:
		return
	if item == null:
		item_details_label.text = "[color=#888888]Seleziona un articolo dalla stiva per i dettagli.[/color]"
		return
	
	var i_name: String = item.name if item is CargoItemData else item.get("name", "Unknown")
	var i_cat: String = item.category if item is CargoItemData else item.get("category", "GENERAL")
	var i_qty: int = item.quantity if item is CargoItemData else item.get("quantity", 0)
	var i_mass: float = item.unit_mass_kg if item is CargoItemData else item.get("unit_mass_kg", 0.0)
	var i_vol: float = item.unit_volume_m3 if item is CargoItemData else item.get("unit_volume_m3", 0.0)
	var i_val: float = item.unit_base_value if item is CargoItemData else item.get("unit_base_value", 0.0)
	var i_contraband: bool = item.is_contraband if item is CargoItemData else bool(item.get("is_contraband", false))
	var i_snet: bool = item.is_snet_disk if item is CargoItemData else bool(item.get("is_snet_disk", false))
	var i_desc: String = item.description if item is CargoItemData else item.get("description", "")
	var total_mass := i_mass * float(i_qty)
	var total_vol := i_vol * float(i_qty)

	var text := "[b]%s[/b]\n\n" % str(i_name)
	text += "Categoria: [color=#88ddff]%s[/color]\n" % str(i_cat)
	text += "Quantità: %d unità\n" % int(i_qty)
	text += "Massa: %.1f kg unitario (%.1f kg totale)\n" % [float(i_mass), total_mass]
	text += "Volume: %.2f m³ unitario (%.2f m³ totale)\n" % [float(i_vol), total_vol]
	text += "Valore stimato: %d CR / unità (%d CR totale)\n" % [int(i_val), int(i_val * i_qty)]
	if i_contraband:
		text += "[color=#ff5555]⚠ CARICO DI CONTRABBANDO - Rischio sequestro se scannerizzato da autorità SOL-NAV.[/color]\n"
	if i_snet:
		text += "[color=#55ffff]💾 DISCO SNAPSHOT S-NET: Contiene archivi finanziari di settore.[/color]\n"
	text += "\nDescrizione:\n%s" % str(i_desc)
	item_details_label.text = text

# ==============================================================================
# SEGNALI ED EVENTI UI
# ==============================================================================

func _on_cargo_item_selected(index: int) -> void:
	selected_cargo_idx = index
	var items := cargo_mgr.get_cargo_list() if cargo_mgr else []
	if index >= 0 and index < items.size():
		_display_cargo_details(items[index])

func _on_jettison_pressed() -> void:
	if not cargo_mgr or selected_cargo_idx < 0:
		return
	var items := cargo_mgr.get_cargo_list()
	if selected_cargo_idx < items.size():
		var item_id := items[selected_cargo_idx].id if items[selected_cargo_idx] else ""
		cargo_mgr.remove_item(item_id, 1)

func _on_btn_jettison_pressed() -> void:
	_on_jettison_pressed()

# ==============================================================================
# CALLBACK SEGNALI MANAGERS
# ==============================================================================

func _on_cargo_updated(_items: Array[CargoItemData] = [], _total_mass: float = 0.0, _total_vol: float = 0.0) -> void:
	_refresh_all_views()

func _on_cargo_item_added(_item: Variant = null, _quantity: int = 0) -> void:
	_refresh_all_views()

func _on_cargo_item_removed(_item: Variant = null, _quantity: int = 0) -> void:
	_refresh_all_views()

func _on_overload_prevented(_item: Variant = null, _qty: int = 0, reason: String = "") -> void:
	if status_sub_label:
		status_sub_label.text = "BLOCCO SOVRACCARICO: %s" % reason
