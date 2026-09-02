class_name CruiseControlPanel
extends PanelContainer

## Pannello di controllo Cruise Mode (Velocità di Crociera sub-FTL) per Flight Control.
## Mostra lo stato di carica (warmup), le fasi sequenziali di ingaggio, allineamento,
## potenza energetica da PowerGrid e gli allarmi di proximity drop.

signal engage_requested()
signal abort_requested()

@onready var status_badge: Label = %StatusBadge
@onready var charge_progress_bar: ProgressBar = %ChargeProgressBar
@onready var charge_label: Label = %ChargeLabel

@onready var phase_rest_label: Label = %PhaseRestLabel
@onready var phase_align_label: Label = %PhaseAlignLabel
@onready var phase_power_label: Label = %PhasePowerLabel
@onready var phase_boost_label: Label = %PhaseBoostLabel

@onready var target_waypoint_label: Label = %TargetWaypointLabel
@onready var speed_mult_label: Label = %SpeedMultLabel
@onready var alert_label: Label = %AlertLabel
@onready var btn_toggle_cruise: Button = %BtnToggleCruise

var controller_ref: CruiseDriveController = null
var can_control: bool = true

func _ready() -> void:
	_setup_ui_events()
	_connect_controller()
	_update_ui_state()

func _setup_ui_events() -> void:
	if btn_toggle_cruise:
		btn_toggle_cruise.pressed.connect(_on_btn_toggle_cruise_pressed)

func set_controller(controller: CruiseDriveController) -> void:
	controller_ref = controller
	_connect_controller()
	_update_ui_state()

func _connect_controller() -> void:
	if controller_ref == null:
		if SpaceWorldManager:
			controller_ref = SpaceWorldManager.get_cruise_drive_controller()
	
	if controller_ref and is_instance_valid(controller_ref):
		if not controller_ref.state_changed.is_connected(_on_state_changed):
			controller_ref.state_changed.connect(_on_state_changed)
		if not controller_ref.warmup_progress_updated.is_connected(_on_warmup_progress_updated):
			controller_ref.warmup_progress_updated.connect(_on_warmup_progress_updated)
		if not controller_ref.proximity_drop_triggered.is_connected(_on_proximity_drop_triggered):
			controller_ref.proximity_drop_triggered.connect(_on_proximity_drop_triggered)
		if not controller_ref.power_state_changed.is_connected(_on_power_state_changed):
			controller_ref.power_state_changed.connect(_on_power_state_changed)
		if not controller_ref.alignment_updated.is_connected(_on_alignment_updated):
			controller_ref.alignment_updated.connect(_on_alignment_updated)
		if not controller_ref.rest_state_updated.is_connected(_on_rest_state_updated):
			controller_ref.rest_state_updated.connect(_on_rest_state_updated)
		if not controller_ref.destination_target_updated.is_connected(_on_destination_target_updated):
			controller_ref.destination_target_updated.connect(_on_destination_target_updated)

func _process(_delta: float) -> void:
	if controller_ref and is_instance_valid(controller_ref):
		_update_ui_state()

func _on_btn_toggle_cruise_pressed() -> void:
	if not can_control or controller_ref == null:
		return
	
	if controller_ref.current_state == CruiseDriveController.State.IDLE:
		var res := controller_ref.request_engage()
		if not res.get("success"):
			_show_alert(res.get("reason"), true)
		else:
			_show_alert("Sequenza di Warmup avviata...", false)
			engage_requested.emit()
	elif controller_ref.current_state == CruiseDriveController.State.WARMUP:
		controller_ref.abort_warmup("Annullamento manuale pilota")
		abort_requested.emit()
	elif controller_ref.current_state == CruiseDriveController.State.ENGAGED:
		controller_ref.disengage("Disingaggio manuale pilota")
		abort_requested.emit()

func _on_state_changed(new_state: int, _old_state: int) -> void:
	_update_ui_state()
	match new_state:
		CruiseDriveController.State.IDLE:
			_show_alert("Sistema Crociera pronto in standby", false)
		CruiseDriveController.State.WARMUP:
			_show_alert("Carica bobine sub-FTL in corso...", false)
		CruiseDriveController.State.ENGAGED:
			_show_alert("CRUISE MODE INGAGGIATA (8.0x SPINTA)", false)
		CruiseDriveController.State.COOLDOWN:
			_show_alert("Cooldown termico propulsori attivo", false)
		CruiseDriveController.State.EMERGENCY_DROP:
			_show_alert("EMERGENCY PROXIMITY DROP ATTIVATO!", true)

func _on_warmup_progress_updated(cur_time: float, total_time: float, ratio: float) -> void:
	if charge_progress_bar:
		charge_progress_bar.value = ratio * 100.0
	if charge_label:
		charge_label.text = "CARICA BOBINE: %3.0f%% (%.1fs / %.1fs)" % [ratio * 100.0, cur_time, total_time]

func _on_proximity_drop_triggered(obstacle_name: String, distance: float) -> void:
	_show_alert("ALLARME PROSSIMITA': %s a %.1fm!" % [obstacle_name, distance], true)

func _on_power_state_changed(_is_powered: bool, cur_mw: float, req_mw: float) -> void:
	if phase_power_label:
		if cur_mw >= req_mw:
			phase_power_label.text = "3. POTENZA: OK (%.0f/%.0f MW)" % [cur_mw, req_mw]
			phase_power_label.modulate = Color(0.2, 1.0, 0.4)
		else:
			phase_power_label.text = "3. POTENZA: INSUFFICIENTE (%.0f/%.0f MW)" % [cur_mw, req_mw]
			phase_power_label.modulate = Color(1.0, 0.4, 0.2)

func _on_alignment_updated(angle_deg: float, is_aligned: bool) -> void:
	if phase_align_label:
		if is_aligned:
			phase_align_label.text = "2. ROTTA: ALLINEATA (%.1f° <= 3.0°)" % angle_deg
			phase_align_label.modulate = Color(0.2, 1.0, 0.4)
		else:
			phase_align_label.text = "2. ROTTA: DISALLINEATA (%.1f° > 3.0°)" % angle_deg
			phase_align_label.modulate = Color(1.0, 0.4, 0.2)

func _on_rest_state_updated(cur_speed: float, is_rest: bool) -> void:
	if phase_rest_label:
		if is_rest:
			phase_rest_label.text = "1. QUIETE: OK (%.1f m/s < 5.0 m/s)" % cur_speed
			phase_rest_label.modulate = Color(0.2, 1.0, 0.4)
		else:
			phase_rest_label.text = "1. QUIETE: VELOCITA' ALTA (%.1f m/s)" % cur_speed
			phase_rest_label.modulate = Color(1.0, 0.4, 0.2)

func _on_destination_target_updated(target_pos: Vector3, has_target: bool) -> void:
	if target_waypoint_label:
		if has_target:
			target_waypoint_label.text = "DESTINAZIONE: [%.0f, %.0f, %.0f]" % [target_pos.x, target_pos.y, target_pos.z]
		else:
			target_waypoint_label.text = "DESTINAZIONE: VETTORE PRUA LIBERO"

func _update_ui_state() -> void:
	if controller_ref == null:
		return
	
	var state := controller_ref.current_state
	if status_badge:
		match state:
			CruiseDriveController.State.IDLE:
				status_badge.text = "STANDBY"
				status_badge.modulate = Color(0.7, 0.7, 0.7)
			CruiseDriveController.State.WARMUP:
				status_badge.text = "WARMUP IN CORSO"
				status_badge.modulate = Color(1.0, 0.8, 0.2)
			CruiseDriveController.State.ENGAGED:
				status_badge.text = "CRUISE ACTIVE (8.0x)"
				status_badge.modulate = Color(0.2, 1.0, 0.5)
			CruiseDriveController.State.COOLDOWN:
				status_badge.text = "COOLDOWN (%.1fs)" % controller_ref.cooldown_timer
				status_badge.modulate = Color(1.0, 0.6, 0.2)
			CruiseDriveController.State.EMERGENCY_DROP:
				status_badge.text = "EMERGENCY DROP (%.1fs)" % controller_ref.cooldown_timer
				status_badge.modulate = Color(1.0, 0.2, 0.2)
	
	if btn_toggle_cruise:
		match state:
			CruiseDriveController.State.IDLE:
				btn_toggle_cruise.text = "INGAGGIA CRUISE MODE"
				btn_toggle_cruise.disabled = not can_control
			CruiseDriveController.State.WARMUP:
				btn_toggle_cruise.text = "ANNULLA WARMUP"
				btn_toggle_cruise.disabled = not can_control
			CruiseDriveController.State.ENGAGED:
				btn_toggle_cruise.text = "DISINGAGGIA CROCIERA"
				btn_toggle_cruise.disabled = not can_control
			CruiseDriveController.State.COOLDOWN, CruiseDriveController.State.EMERGENCY_DROP:
				btn_toggle_cruise.text = "COOLDOWN ATTIVO"
				btn_toggle_cruise.disabled = true
	
	if speed_mult_label:
		speed_mult_label.text = "MOLTIPLICATORE: %.1fx" % controller_ref.cruise_multiplier
	
	# Aggiornamento indicatori di fase
	var rest_check := controller_ref.check_rest_state()
	_on_rest_state_updated(rest_check["speed"], rest_check["is_valid"])
	
	var align_check := controller_ref.check_vector_alignment()
	_on_alignment_updated(align_check["angle_deg"], align_check["is_valid"])
	
	var pwr_check := controller_ref.check_power_state()
	_on_power_state_changed(pwr_check["is_valid"], pwr_check["current_power_mw"], pwr_check["required_power_mw"])
	
	if phase_boost_label:
		if state == CruiseDriveController.State.ENGAGED:
			phase_boost_label.text = "4. BOOST: ATTIVO (RCS BLOCCATO)"
			phase_boost_label.modulate = Color(0.2, 1.0, 0.4)
		else:
			phase_boost_label.text = "4. BOOST: STANDBY"
			phase_boost_label.modulate = Color(0.6, 0.6, 0.6)

func _show_alert(msg: String, is_danger: bool) -> void:
	if alert_label:
		alert_label.text = msg
		alert_label.modulate = Color(1.0, 0.2, 0.2) if is_danger else Color(0.3, 0.8, 1.0)

func set_permission_control(enabled: bool) -> void:
	can_control = enabled
	if btn_toggle_cruise:
		btn_toggle_cruise.disabled = not enabled or (controller_ref and (controller_ref.current_state == CruiseDriveController.State.COOLDOWN or controller_ref.current_state == CruiseDriveController.State.EMERGENCY_DROP))
