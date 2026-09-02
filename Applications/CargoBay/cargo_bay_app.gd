class_name CargoBayApp
extends BaseApp

## CargoBayApp (Applications/CargoBay)
## Interfaccia diegetica a finestre di GodotOS per la gestione della Stiva Cargo,
## Logistica trasferimenti merci (Corvetta, Service Drone, Stazioni),
## Rating finanziario FLUX (Credit score, sconti, abbonamenti) e violazione ICE Snapshot S-Net.

# Percorsi storage diegetico e file di configurazione
const CONFIG_PATH_PRIMARY: String = "Ship Drive/Programs/CargoBay/cargo_bay_config.dat"
const CONFIG_PATH_FALLBACK: String = "Terminal Drive/Programs/CargoBay/cargo_bay_config.dat"

# Riferimenti UI - Header & Overlays
@onready var disconnected_overlay: Control = get_node_or_null("%DisconnectedOverlay")
@onready var tab_container: TabContainer = get_node_or_null("%TabContainer")
@onready var credits_label: Label = get_node_or_null("%CreditsLabel")
@onready var flux_rating_label: Label = get_node_or_null("%FluxRatingLabel")
@onready var status_sub_label: Label = get_node_or_null("%StatusSubLabel")

# Tab 1: Inventario Stiva
@onready var mass_progress_bar: ProgressBar = get_node_or_null("%MassProgressBar")
@onready var mass_status_label: Label = get_node_or_null("%MassStatusLabel")
@onready var vol_progress_bar: ProgressBar = get_node_or_null("%VolProgressBar")
@onready var vol_status_label: Label = get_node_or_null("%VolStatusLabel")
@onready var cargo_item_list: ItemList = get_node_or_null("%CargoItemList")
@onready var item_details_label: RichTextLabel = get_node_or_null("%ItemDetailsLabel")
@onready var btn_jettison: Button = get_node_or_null("%BtnJettison")

# Tab 2: Trasferimenti
@onready var target_option_btn: OptionButton = get_node_or_null("%TargetOptionBtn")
@onready var direction_option_btn: OptionButton = get_node_or_null("%DirectionOptionBtn")
@onready var transfer_item_list: ItemList = get_node_or_null("%TransferItemList")
@onready var transfer_spinbox: SpinBox = get_node_or_null("%TransferSpinbox")
@onready var btn_execute_transfer: Button = get_node_or_null("%BtnExecuteTransfer")
@onready var transfer_status_label: Label = get_node_or_null("%TransferStatusLabel")

# Tab 3: Rating FLUX & Canoni
@onready var flux_score_bar: ProgressBar = get_node_or_null("%FluxScoreBar")
@onready var flux_score_num_label: Label = get_node_or_null("%FluxScoreNumLabel")
@onready var flux_tier_details_label: RichTextLabel = get_node_or_null("%FluxTierDetailsLabel")
@onready var impound_warning_panel: PanelContainer = get_node_or_null("%ImpoundWarningPanel")
@onready var impound_warning_label: Label = get_node_or_null("%ImpoundWarningLabel")
@onready var subscriptions_item_list: ItemList = get_node_or_null("%SubscriptionsItemList")
@onready var btn_pay_sub: Button = get_node_or_null("%BtnPaySub")
@onready var btn_pay_all_debt: Button = get_node_or_null("%BtnPayAllDebt")
@onready var os_lockout_label: RichTextLabel = get_node_or_null("%OsLockoutLabel")

# Tab 4: Array Snapshot S-Net & ICE Hack
@onready var snet_disk_list: ItemList = get_node_or_null("%SnetDiskList")
@onready var snet_disk_info_label: RichTextLabel = get_node_or_null("%SnetDiskInfoLabel")
@onready var btn_hack_ice: Button = get_node_or_null("%BtnHackIce")
@onready var hack_status_label: Label = get_node_or_null("%HackStatusLabel")
@onready var intel_output_box: RichTextLabel = get_node_or_null("%IntelOutputBox")

# Stato runtime
var is_ship_connected: bool = false
var can_hack: bool = true # RBAC (Hacker, Captain, Mozzo)
var selected_cargo_idx: int = -1
var selected_transfer_item_id: String = ""
var selected_sub_idx: int = -1
var selected_snet_idx: int = -1

# Riferimenti ai manager (Autoload con fallback a istanze runtime)
var cargo_mgr: CargoManagerSingleton = null
var flux_mgr: FluxEconomyManagerSingleton = null

func _ready() -> void:
	_init_managers()
	_init_runtime_files()
	_load_config()
	_connect_signals()
	_check_initial_state()
	_refresh_all_views()

func _init_managers() -> void:
	# Recupera Autoload se presenti nel SceneTree, altrimenti crea fallback
	if get_node_or_null("/root/CargoManager") is CargoManagerSingleton:
		cargo_mgr = get_node_or_null("/root/CargoManager") as CargoManagerSingleton
	elif cargo_mgr == null:
		cargo_mgr = CargoManagerSingleton.new()
		cargo_mgr.name = "CargoManagerFallback"
		add_child(cargo_mgr)

	if get_node_or_null("/root/FluxEconomyManager") is FluxEconomyManagerSingleton:
		flux_mgr = get_node_or_null("/root/FluxEconomyManager") as FluxEconomyManagerSingleton
	elif flux_mgr == null:
		flux_mgr = FluxEconomyManagerSingleton.new()
		flux_mgr.name = "FluxEconomyManagerFallback"
		add_child(flux_mgr)

func _connect_signals() -> void:
	# SpaceWorldManager
	if SpaceWorldManager:
		if SpaceWorldManager.has_signal("ship_connection_changed"):
			SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
	
	# NetworkManager (RBAC)
	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr:
		if net_mgr.has_signal("role_changed"):
			net_mgr.role_changed.connect(_on_role_changed)
		if net_mgr.has_signal("session_mode_changed"):
			net_mgr.session_mode_changed.connect(_on_session_mode_changed)
			
	# ShipDrive hot-reload
	var sdm = get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("file_synced"):
		sdm.file_synced.connect(_on_drive_file_synced)
	
	# CargoManager Signals
	if cargo_mgr:
		cargo_mgr.cargo_updated.connect(_on_cargo_updated)
		cargo_mgr.item_added.connect(_on_cargo_item_added)
		cargo_mgr.item_removed.connect(_on_cargo_item_removed)
		cargo_mgr.overload_prevented.connect(_on_overload_prevented)
		cargo_mgr.transfer_completed.connect(_on_transfer_completed)
		cargo_mgr.transfer_failed.connect(_on_transfer_failed)
	
	# FluxEconomyManager Signals
	if flux_mgr:
		flux_mgr.flux_score_changed.connect(_on_flux_score_changed)
		flux_mgr.credits_changed.connect(_on_credits_changed)
		flux_mgr.subscription_paid.connect(_on_subscription_paid)
		flux_mgr.subscription_overdue.connect(_on_subscription_overdue)
		flux_mgr.penalty_issued.connect(_on_penalty_issued)
		flux_mgr.os_feature_disabled.connect(_on_os_feature_disabled)
		flux_mgr.os_feature_restored.connect(_on_os_feature_restored)
		flux_mgr.impound_warning_issued.connect(_on_impound_warning_issued)
		flux_mgr.impound_warning_cleared.connect(_on_impound_warning_cleared)
		flux_mgr.impound_executed.connect(_on_impound_executed)
		flux_mgr.snet_ice_breached.connect(_on_snet_ice_breached)
		flux_mgr.snet_ice_hack_failed.connect(_on_snet_ice_hack_failed)
	
	# UI Signals
	if cargo_item_list:
		cargo_item_list.item_selected.connect(_on_cargo_item_selected)
	if btn_jettison:
		btn_jettison.pressed.connect(_on_btn_jettison_pressed)
	if transfer_item_list:
		transfer_item_list.item_selected.connect(_on_transfer_item_selected)
	if btn_execute_transfer:
		btn_execute_transfer.pressed.connect(_on_btn_execute_transfer_pressed)
	if subscriptions_item_list:
		subscriptions_item_list.item_selected.connect(_on_sub_item_selected)
	if btn_pay_sub:
		btn_pay_sub.pressed.connect(_on_btn_pay_sub_pressed)
	if btn_pay_all_debt:
		btn_pay_all_debt.pressed.connect(_on_btn_pay_all_debt_pressed)
	if snet_disk_list:
		snet_disk_list.item_selected.connect(_on_snet_disk_selected)
	if btn_hack_ice:
		btn_hack_ice.pressed.connect(_on_btn_hack_ice_pressed)

func _check_initial_state() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		_set_ship_connected(SpaceWorldManager.is_ship_connected())
	else:
		_set_ship_connected(true)
	
	_update_rbac()

func _set_ship_connected(connected: bool) -> void:
	is_ship_connected = connected
	if disconnected_overlay:
		disconnected_overlay.visible = not connected
	if tab_container:
		tab_container.visible = connected

func _on_ship_connection_changed(connected: bool) -> void:
	_set_ship_connected(connected)

func _on_role_changed(_new_role: String) -> void:
	_update_rbac()

func _on_session_mode_changed(_mode: int) -> void:
	_update_rbac()

func _update_rbac() -> void:
	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr:
		var role: String = str(net_mgr.get("player_role") if "player_role" in net_mgr else "Solo")
		can_hack = (role in ["Hacker", "Captain", "Capitano", "Mozzo", "Solo", ""])
	else:
		can_hack = true
	
	if btn_hack_ice:
		btn_hack_ice.disabled = not can_hack

# ==============================================================================
# GESTIONE .DAT CONFIG
# ==============================================================================

func _init_runtime_files() -> void:
	var sdm = get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_method("create_file"):
		if not sdm.has_file(CONFIG_PATH_PRIMARY):
			var default_content := "[SYSTEM]\napp_name=CargoBayApp\nversion=1.0.0\nstatus=OPERATIONAL\n\n[LIMITS]\nmax_mass_kg=2000.0\nmax_volume_m3=100.0\n\n[ECONOMY]\ndefault_flux_score=720.0\nimpound_warning_sec=120.0\n"
			sdm.create_file(CONFIG_PATH_PRIMARY, default_content, true, "Parametri stiva cargo, limiti massa e rating FLUX.")

func _load_config() -> void:
	var parsed := _parse_dat_file(CONFIG_PATH_PRIMARY)
	if parsed.is_empty():
		parsed = _parse_dat_file(CONFIG_PATH_FALLBACK)
	
	if parsed.has("max_mass_kg") and cargo_mgr:
		cargo_mgr.max_mass_kg = float(parsed["max_mass_kg"])
	if parsed.has("max_volume_m3") and cargo_mgr:
		cargo_mgr.max_volume_m3 = float(parsed["max_volume_m3"])
	if parsed.has("default_flux_score") and flux_mgr:
		flux_mgr.flux_score = float(parsed["default_flux_score"])

func _on_drive_file_synced(path: String) -> void:
	if path == CONFIG_PATH_PRIMARY or path == CONFIG_PATH_FALLBACK:
		_load_config()
		_refresh_all_views()

func _refresh_all_views() -> void:
	_update_header()
	_update_cargo_tab()
	_update_transfer_tab()
	_update_flux_tab()
	_update_snet_tab()

func _update_header() -> void:
	if not flux_mgr:
		return
	if credits_label:
		credits_label.text = "Crediti: %d CR" % flux_mgr.credits
	
	var letter := flux_mgr.get_rating_letter()
	var color_tag := "green"
	match letter:
		"S": color_tag = "#00ffff"
		"A": color_tag = "#55ff55"
		"B": color_tag = "#88ffff"
		"C": color_tag = "#ffff55"
		"D": color_tag = "#ffaa00"
		"F": color_tag = "#ff4444"
	
	if flux_rating_label:
		flux_rating_label.text = "FLUX Rating: [%s] %.1f pts" % [letter, flux_mgr.flux_score]
	
	if status_sub_label:
		if flux_mgr.is_insolvent():
			status_sub_label.text = "ATTENZIONE: STATO INSOLVENTE - FEATURE OS SOSPESE"
			status_sub_label.modulate = Color(1.0, 0.3, 0.3)
		else:
			status_sub_label.text = "Sistemi Cargo & Sublayer Operativi."
			status_sub_label.modulate = Color(0.7, 0.9, 1.0)

func _update_cargo_tab() -> void:
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
			var item_name := str(item.get("name"))
			var qty := int(item.get("quantity"))
			var mass := float(item.get("unit_mass_kg")) * qty
			var cat := str(item.get("category"))
			var flags := ""
			if bool(item.get("is_contraband")):
				flags += " [ILLEGALE]"
			if bool(item.get("is_snet_disk")):
				var meta: Dictionary = item.get("metadata")
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

func _display_cargo_details(item: Dictionary) -> void:
	if not item_details_label:
		return
	var text := "[b]%s[/b]\n" % str(item.get("name"))
	text += "Categoria: [color=#88ddff]%s[/color]\n" % str(item.get("category"))
	text += "Quantità: %d unità\n" % int(item.get("quantity"))
	text += "Massa unitaria: %.1f kg | Volume unitario: %.2f m³\n" % [float(item.get("unit_mass_kg")), float(item.get("unit_volume_m3"))]
	text += "Valore stimato: %d CR / unità\n" % int(item.get("unit_base_value"))
	if bool(item.get("is_contraband")):
		text += "[color=#ff5555]⚠ CARICO DI CONTRABBANDO - Rischio sequestro se scannerizzato da autorità SOL-NAV.[/color]\n"
	if bool(item.get("is_snet_disk")):
		text += "[color=#55ffff]💾 DISCO SNAPSHOT S-NET: Contiene archivi finanziari di settore.[/color]\n"
	text += "\nDescrizione:\n%s" % str(item.get("description"))
	item_details_label.text = text

func _update_transfer_tab() -> void:
	if not cargo_mgr:
		return
	if transfer_item_list:
		transfer_item_list.clear()
		var items := cargo_mgr.get_cargo_list()
		for item in items:
			var id := str(item.get("id"))
			var name := str(item.get("name"))
			var qty := int(item.get("quantity"))
			transfer_item_list.add_item("%s (Disp: %d)" % [name, qty])
	
	if target_option_btn and target_option_btn.item_count == 0:
		target_option_btn.add_item("Service Drone EVA (Baia Lancio)")
		target_option_btn.add_item("Magazzino Stazione Orbitale")
	
	if direction_option_btn and direction_option_btn.item_count == 0:
		direction_option_btn.add_item("Carica: Stiva Corvetta -> Bersaglio")
		direction_option_btn.add_item("Scarica: Bersaglio -> Stiva Corvetta")

func _update_flux_tab() -> void:
	if not flux_mgr:
		return
	
	var score := flux_mgr.flux_score
	var letter := flux_mgr.get_rating_letter()
	
	if flux_score_bar:
		flux_score_bar.max_value = 1000.0
		flux_score_bar.value = score
	
	if flux_score_num_label:
		flux_score_num_label.text = "Punteggio Creditizio: %.1f / 1000.0 [Rating %s]" % [score, letter]
	
	if flux_tier_details_label:
		var mult := flux_mgr.get_port_discount_multiplier()
		var mult_str := ""
		if mult < 1.0:
			mult_str = "[color=#55ff55]Sconto Portuale Applicato: %.0f%%[/color]" % ((1.0 - mult) * 100.0)
		elif mult > 1.0:
			mult_str = "[color=#ff5555]Sovraccosto Rischio Debito: +%.0f%%[/color]" % ((mult - 1.0) * 100.0)
		else:
			mult_str = "[color=#88ffff]Tariffa Standard di Mercato (0% Variazione)[/color]"
		
		var desc := "[b]Stato Finanziario FLUX:[/b] Rating %s\n" % letter
		desc += "%s\n" % mult_str
		desc += "Debito Attivo Registrato: %d CR\n" % int(flux_mgr.total_debt)
		if flux_mgr.is_insolvent():
			desc += "[color=#ff4444]STATO DI INSOLVENZA ATTIVO! La corporazione ha emesso un mandato di sequestro per la Corvetta Rogue.[/color]"
		else:
			desc += "[color=#55ff55]Affidabilità creditizia regolare. Nessun vincolo portuale.[/color]"
		flux_tier_details_label.text = desc
	
	# Impound Warning Panel
	if impound_warning_panel:
		impound_warning_panel.visible = flux_mgr.is_impound_warning_active or flux_mgr.is_insolvent()
	if impound_warning_label:
		impound_warning_label.text = "⚠ ALLERTA SEQUESTRO: Scadenza tra %.0f sec! Salda %d CR di debito prima dell'impound." % [
			flux_mgr.impound_countdown, int(flux_mgr.total_debt)
		]
	
	# Subscriptions List
	if subscriptions_item_list:
		subscriptions_item_list.clear()
		for sub in flux_mgr.subscriptions:
			var s_name := str(sub.get("name"))
			var cost := int(sub.get("cost"))
			var time_left := float(sub.get("time_left"))
			var is_od := bool(sub.get("is_overdue"))
			var status_str := "[SCADUTO - DEBITO]" if is_od else "Scade tra %.0fs" % time_left
			var item_text := "%s - %d CR (%s)" % [s_name, cost, status_str]
			subscriptions_item_list.add_item(item_text)
	
	# OS Lockout details
	if os_lockout_label:
		if flux_mgr.disabled_os_features.is_empty():
			os_lockout_label.text = "[color=#55ff55]Tutti i moduli OS e i protocolli di bordo sono pienamente autorizzati e operativi.[/color]"
		else:
			var lockout_text := "[color=#ff5555][b]Moduli OS Disattivati da Remoto per Insolvenza:[/b][/color]\n"
			for f in flux_mgr.disabled_os_features:
				lockout_text += " • %s\n" % f
			os_lockout_label.text = lockout_text

func _update_snet_tab() -> void:
	if not cargo_mgr:
		return
	
	var snet_disks: Array[Dictionary] = []
	for item in cargo_mgr.get_cargo_list():
		if bool(item.get("is_snet_disk")) or item.get("category") == "SNET_DISK":
			snet_disks.append(item)
	
	if snet_disk_list:
		snet_disk_list.clear()
		for disk in snet_disks:
			var d_name := str(disk.get("name"))
			var meta: Dictionary = disk.get("metadata")
			var status := "DECRIPTATO" if bool(meta.get("ice_broken")) else "ICE Liv. %d" % int(meta.get("ice_strength"))
			snet_disk_list.add_item("%s [%s]" % [d_name, status])
		
		if selected_snet_idx >= 0 and selected_snet_idx < snet_disks.size():
			snet_disk_list.select(selected_snet_idx)
			_display_snet_details(snet_disks[selected_snet_idx])
		else:
			if snet_disks.size() > 0:
				selected_snet_idx = 0
				snet_disk_list.select(0)
				_display_snet_details(snet_disks[0])
			else:
				selected_snet_idx = -1
				if snet_disk_info_label:
					snet_disk_info_label.text = "[color=#888888]Nessun supporto dati o array fisico S-Net presente nella stiva.[/color]"
				if btn_hack_ice:
					btn_hack_ice.disabled = true

func _display_snet_details(disk: Dictionary) -> void:
	if not snet_disk_info_label:
		return
	var meta: Dictionary = disk.get("metadata")
	var is_broken := bool(meta.get("ice_broken"))
	var ice_str := int(meta.get("ice_strength"))
	
	var text := "[b]%s[/b]\n" % str(disk.get("name"))
	text += "Settore Origine: [color=#88ddff]%s[/color]\n" % str(meta.get("sector"))
	text += "Stato Crittografia ICE: %s\n" % ("[color=#55ff55]VIOLATO / ACCESSO COMPLETO[/color]" if is_broken else "[color=#ff5555]ATTIVO (Difficoltà Livello %d)[/color]" % ice_str)
	text += "Valore Stimato Snapshot: %d CR\n" % int(meta.get("financial_snapshot"))
	text += "\nNote Tecniche:\nGli array dati S-Net superano il vincolo galattico di assenza di FTL mediante il trasporto fisico su corrieri corazzati. L'intercettazione e la violazione delle chiavi ICE consente di appropriarsi di listini riservati e codici bancari prima della diffusione pubblica."
	snet_disk_info_label.text = text
	
	if btn_hack_ice:
		btn_hack_ice.disabled = is_broken or not can_hack

# ==============================================================================
# SEGNALI ED EVENTI UI
# ==============================================================================

func _on_cargo_item_selected(index: int) -> void:
	selected_cargo_idx = index
	var items := cargo_mgr.get_cargo_list()
	if index >= 0 and index < items.size():
		_display_cargo_details(items[index])

func _on_btn_jettison_pressed() -> void:
	if not cargo_mgr or selected_cargo_idx < 0:
		return
	var items := cargo_mgr.get_cargo_list()
	if selected_cargo_idx < items.size():
		var item_id := str(items[selected_cargo_idx].get("id"))
		cargo_mgr.remove_item(item_id, 1)

func _on_transfer_item_selected(index: int) -> void:
	var items := cargo_mgr.get_cargo_list()
	if index >= 0 and index < items.size():
		selected_transfer_item_id = str(items[index].get("id"))

func _on_btn_execute_transfer_pressed() -> void:
	if not cargo_mgr or selected_transfer_item_id.is_empty():
		if transfer_status_label:
			transfer_status_label.text = "Seleziona un articolo da trasferire."
		return
	
	var qty := int(transfer_spinbox.value) if transfer_spinbox else 1
	var target_type := target_option_btn.selected if target_option_btn else 0 # 0: Drone, 1: Station
	var is_to_target := (direction_option_btn.selected == 0) if direction_option_btn else true
	
	var success := false
	if target_type == 0: # Drone
		var drone = null
		if SpaceWorldManager and SpaceWorldManager.has_method("get_service_drone"):
			drone = SpaceWorldManager.get_service_drone()
		
		if is_to_target:
			success = cargo_mgr.transfer_to_drone(selected_transfer_item_id, qty, drone)
		else:
			success = cargo_mgr.transfer_from_drone(selected_transfer_item_id, qty, drone)
	else: # Station
		var station = null
		if is_to_target:
			success = cargo_mgr.transfer_to_station(selected_transfer_item_id, qty, station)
		else:
			success = cargo_mgr.transfer_from_station(selected_transfer_item_id, qty, station)
	
	if transfer_status_label:
		if success:
			transfer_status_label.text = "Trasferimento completato con successo (x%d %s)." % [qty, selected_transfer_item_id]
		else:
			transfer_status_label.text = "Trasferimento fallito. Verifica spazio o disponibilità."

func _on_sub_item_selected(index: int) -> void:
	selected_sub_idx = index

func _on_btn_pay_sub_pressed() -> void:
	if not flux_mgr or selected_sub_idx < 0:
		return
	if selected_sub_idx < flux_mgr.subscriptions.size():
		var sub_id := str(flux_mgr.subscriptions[selected_sub_idx].get("id"))
		flux_mgr.pay_subscription_manually(sub_id)

func _on_btn_pay_all_debt_pressed() -> void:
	if flux_mgr:
		flux_mgr.pay_all_debts()

func _on_snet_disk_selected(index: int) -> void:
	selected_snet_idx = index
	var snet_disks: Array[Dictionary] = []
	for item in cargo_mgr.get_cargo_list():
		if bool(item.get("is_snet_disk")) or item.get("category") == "SNET_DISK":
			snet_disks.append(item)
	if index >= 0 and index < snet_disks.size():
		_display_snet_details(snet_disks[index])

func _on_btn_hack_ice_pressed() -> void:
	if not flux_mgr or not cargo_mgr or selected_snet_idx < 0:
		return
	
	var snet_disks: Array[Dictionary] = []
	for item in cargo_mgr.get_cargo_list():
		if bool(item.get("is_snet_disk")) or item.get("category") == "SNET_DISK":
			snet_disks.append(item)
	
	if selected_snet_idx < snet_disks.size():
		var disk := snet_disks[selected_snet_idx]
		var result := flux_mgr.hack_snet_disk(disk, 2.5) # Hacker skill standard
		if result.get("success"):
			if hack_status_label:
				hack_status_label.text = "ICE VIOLATO CON SUCCESSO! Dati estratti."
				hack_status_label.modulate = Color(0.3, 1.0, 0.4)
			if intel_output_box:
				var intel_text := "[b][color=#55ffff]REPORT DECRITTAZIONE SNAPSHOT S-NET:[/color][/b]\n"
				intel_text += "Crediti sottratti e iniettati: [color=#ffff55]+%d CR[/color]\n" % int(result.get("decrypted_credits"))
				intel_text += "Market Intelligence: %s\n" % str(result.get("market_intel"))
				intel_text += "Codici bypass generati: %s" % str(result.get("access_codes"))
				intel_output_box.text = intel_text
		else:
			if hack_status_label:
				hack_status_label.text = "VIOLAZIONE ICE FALLITA: Contromisura attiva."
				hack_status_label.modulate = Color(1.0, 0.3, 0.3)
			if intel_output_box:
				intel_output_box.text = "[color=#ff5555]ERRORE HACK: Barriera quantica non superata. Penalità applicata al rating FLUX.[/color]"
		
		_refresh_all_views()

# ==============================================================================
# CALLBACK SEGNALI MANAGERS
# ==============================================================================

func _on_cargo_updated(_items: Array[Dictionary], _total_mass: float, _total_vol: float) -> void:
	_refresh_all_views()

func _on_cargo_item_added(_item: Dictionary, _quantity: int) -> void:
	_refresh_all_views()

func _on_cargo_item_removed(_item: Dictionary, _quantity: int) -> void:
	_refresh_all_views()

func _on_overload_prevented(_item: Dictionary, _qty: int, reason: String) -> void:
	if transfer_status_label:
		transfer_status_label.text = "BLOCCO SOVRACCARICO: %s" % reason

func _on_transfer_completed(_src: String, _tgt: String, _item_id: String, _qty: int) -> void:
	_refresh_all_views()

func _on_transfer_failed(_src: String, _tgt: String, _item_id: String, _qty: int, reason: String) -> void:
	if transfer_status_label:
		transfer_status_label.text = "ERRORE TRASFERIMENTO: %s" % reason

func _on_flux_score_changed(_score: float, _rating: String, _delta: float, _reason: String) -> void:
	_refresh_all_views()

func _on_credits_changed(_credits: int, _delta: int) -> void:
	_refresh_all_views()

func _on_subscription_paid(_id: String, _amount: int) -> void:
	_refresh_all_views()

func _on_subscription_overdue(_id: String, _amount: int) -> void:
	_refresh_all_views()

func _on_penalty_issued(_type: String, _data: Dictionary) -> void:
	_refresh_all_views()

func _on_os_feature_disabled(_feat: String) -> void:
	_refresh_all_views()

func _on_os_feature_restored(_feat: String) -> void:
	_refresh_all_views()

func _on_impound_warning_issued(_timer: float, _debt: float) -> void:
	_refresh_all_views()

func _on_impound_warning_cleared() -> void:
	_refresh_all_views()

func _on_impound_executed() -> void:
	_refresh_all_views()

func _on_snet_ice_breached(_disk: Dictionary, _intel: Dictionary) -> void:
	_refresh_all_views()

func _on_snet_ice_hack_failed(_disk: Dictionary, _reason: String) -> void:
	_refresh_all_views()
