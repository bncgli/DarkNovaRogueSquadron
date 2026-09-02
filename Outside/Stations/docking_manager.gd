class_name DockingManager
extends Node

## Gestisce il ciclo di vita del protocollo di docking tra nave giocatore e Stazioni Spaziali.
## Include:
## - Negoziazione radio e autorizzazione IFF (Clearance / Slot reservation)
## - Controllo vettori telemetrici di approccio e allineamento cono magnetico
## - Cattura magnetica e ancoraggio / blocco cinematico della nave
## - Sblocco / Notifica dell'applicazione StationHub di bordo
## - Procedura diegetica di Undocking e disinnesto magnetico

signal docking_clearance_granted(station_id: String, bay_id: int, message: String)
signal docking_clearance_denied(station_id: String, reason: String)
signal docking_approach_guidance_updated(guidance_data: Dictionary)
signal docking_capture_started(station_id: String, bay_id: int)
signal docking_completed(station_id: String, bay_id: int, station_data: Dictionary)
signal undocking_started(station_id: String, bay_id: int)
signal undocking_completed()
signal docking_aborted(reason: String)

enum DockingState {
	UNDOCKED,
	CLEARANCE_REQUESTED,
	APPROACH_GUIDANCE,
	MAGNETIC_CAPTURE,
	DOCKED,
	UNDOCKING
}

var current_state: DockingState = DockingState.UNDOCKED
var target_station: SpaceStationEntity = null
var assigned_bay_id: int = -1
var player_ship_id: String = "NOVA-ROGUE-01"
var ship_iff_code: String = "SOL-NAV-DEFENSE"

# Telemetria di approccio
var distance_to_bay: float = 9999.0
var angle_alignment_deg: float = 0.0
var approach_speed: float = 0.0
var is_within_capture_cone: bool = false
var is_docked: bool = false

# Parametri di cattura magnetica
var capture_timer: float = 0.0
const CAPTURE_DURATION: float = 2.0 # Secondi per aggancio completo una volta in zona

func _process(delta: float) -> void:
	if current_state == DockingState.APPROACH_GUIDANCE or current_state == DockingState.MAGNETIC_CAPTURE:
		_update_approach_telemetry(delta)

## Invia una richiesta radio di autorizzazione attracco (tramite Comms / Transponder)
func request_docking_clearance(station: SpaceStationEntity, ship_id: String = "", iff_code: String = "") -> bool:
	if not station:
		docking_clearance_denied.emit("", "Nessuna stazione bersaglio specificata.")
		return false
	
	if current_state == DockingState.DOCKED:
		docking_clearance_denied.emit(station.station_id, "Nave già ancorata a una stazione.")
		return false
		
	target_station = station
	if not ship_id.is_empty():
		player_ship_id = ship_id
	if not iff_code.is_empty():
		ship_iff_code = iff_code
		
	current_state = DockingState.CLEARANCE_REQUESTED
	
	# Verifica clearance IFF (se la stazione richiede una specifica fazione o clearance)
	var available_bay := station.get_available_docking_bay()
	if available_bay == -1:
		current_state = DockingState.UNDOCKED
		docking_clearance_denied.emit(station.station_id, "Tutte le baie di attracco sono occupate.")
		return false
		
	# Assegnazione bay con successo
	var assigned := station.assign_docking_bay(available_bay, player_ship_id)
	if not assigned:
		current_state = DockingState.UNDOCKED
		docking_clearance_denied.emit(station.station_id, "Errore nella prenotazione del modulo bay.")
		return false
		
	assigned_bay_id = available_bay
	current_state = DockingState.APPROACH_GUIDANCE
	capture_timer = 0.0
	
	var clearance_msg := "Autorizzazione concessa a [%s]. Dirigersi al corridoio di avvicinamento %s." % [
		player_ship_id,
		_get_bay_name(station, assigned_bay_id)
	]
	
	docking_clearance_granted.emit(station.station_id, assigned_bay_id, clearance_msg)
	return true

## Calcola e aggiorna la telemetria di guida per Flight Control
func _update_approach_telemetry(delta: float) -> void:
	if not target_station or assigned_bay_id == -1:
		return
		
	var bay_transform := target_station.get_bay_global_transform(assigned_bay_id)
	var ship_pos := Vector3.ZERO
	var ship_vel := Vector3.ZERO
	var ship_forward := Vector3.FORWARD
	
	if SpaceWorldManager and SpaceWorldManager.has_method("get_ship_transform"):
		var s_trans: Transform3D = SpaceWorldManager.get_ship_transform()
		ship_pos = s_trans.origin
		ship_forward = -s_trans.basis.z
		if SpaceWorldManager.has_method("get_ship_velocity"):
			ship_vel = SpaceWorldManager.get_ship_velocity()
	
	var to_bay := bay_transform.origin - ship_pos
	distance_to_bay = to_bay.length()
	approach_speed = ship_vel.length()
	
	# Vettore di approccio ideale (direzione uscente dalla baia)
	var bay_normal := Vector3.FORWARD
	for bay in target_station.docking_bays:
		if bay.get("id") == assigned_bay_id:
			bay_normal = (target_station.global_transform.basis * bay.get("approach_vector")).normalized()
			break
			
	# Angolo di allineamento tra la prua della nave e l'asse del dock
	var dot_align := ship_forward.dot(-bay_normal)
	dot_align = clampf(dot_align, -1.0, 1.0)
	angle_alignment_deg = rad_to_deg(acos(dot_align))
	
	# Verifica se è dentro il cono di cattura
	var in_radius := distance_to_bay <= target_station.capture_radius
	var in_angle := angle_alignment_deg <= target_station.alignment_tolerance_angle_deg
	var in_speed := approach_speed <= target_station.max_approach_speed
	
	is_within_capture_cone = in_radius and in_angle
	
	var guidance_info := {
		"station_id": target_station.station_id,
		"bay_id": assigned_bay_id,
		"distance": distance_to_bay,
		"angle_error_deg": angle_alignment_deg,
		"speed": approach_speed,
		"in_cone": is_within_capture_cone,
		"speed_warning": not in_speed,
		"state": current_state
	}
	docking_approach_guidance_updated.emit(guidance_info)
	
	# Transizione allo stato di aggancio magnetico
	if distance_to_bay <= target_station.magnetic_lock_distance and is_within_capture_cone:
		if current_state == DockingState.APPROACH_GUIDANCE:
			current_state = DockingState.MAGNETIC_CAPTURE
			docking_capture_started.emit(target_station.station_id, assigned_bay_id)
			
		if current_state == DockingState.MAGNETIC_CAPTURE:
			capture_timer += delta
			if capture_timer >= CAPTURE_DURATION:
				_complete_docking()

## Esegue l'aggancio completato
func _complete_docking() -> void:
	current_state = DockingState.DOCKED
	is_docked = true
	
	# Blocco cinematico nave se SpaceWorldManager supporta
	if SpaceWorldManager and SpaceWorldManager.has_method("lock_ship_movement"):
		SpaceWorldManager.lock_ship_movement(true)
		
	var st_data := target_station.get_telemetry_data()
	docking_completed.emit(target_station.station_id, assigned_bay_id, st_data)

## Metodo forzato per test o docking guidato automatico
func force_complete_docking(station: SpaceStationEntity, bay_id: int = 0) -> void:
	target_station = station
	assigned_bay_id = bay_id
	station.assign_docking_bay(bay_id, player_ship_id)
	_complete_docking()

## Richiesta diegetica di sgancio / Undocking
func request_undock() -> void:
	if current_state != DockingState.DOCKED:
		return
		
	current_state = DockingState.UNDOCKING
	undocking_started.emit(target_station.station_id, assigned_bay_id)
	
	# Rilascio blocco cinematico nave
	if SpaceWorldManager and SpaceWorldManager.has_method("lock_ship_movement"):
		SpaceWorldManager.lock_ship_movement(false)
		
	if target_station:
		target_station.release_docking_bay(assigned_bay_id)
		
	current_state = DockingState.UNDOCKED
	is_docked = false
	assigned_bay_id = -1
	target_station = null
	
	undocking_completed.emit()

## Abort manuale o forzato dell'approccio
func abort_docking(reason: String = "Procedura abortita dall'operatore") -> void:
	if target_station and assigned_bay_id != -1:
		target_station.release_docking_bay(assigned_bay_id)
		
	current_state = DockingState.UNDOCKED
	assigned_bay_id = -1
	target_station = null
	is_within_capture_cone = false
	docking_aborted.emit(reason)

func _get_bay_name(station: SpaceStationEntity, bay_id: int) -> String:
	for b in station.docking_bays:
		if b.get("id") == bay_id:
			return b.get("name")
	return "Bay %d" % bay_id

func get_docking_state_string() -> String:
	match current_state:
		DockingState.UNDOCKED: return "UNDOCKED"
		DockingState.CLEARANCE_REQUESTED: return "CLEARANCE_REQUESTED"
		DockingState.APPROACH_GUIDANCE: return "APPROACH_GUIDANCE"
		DockingState.MAGNETIC_CAPTURE: return "MAGNETIC_CAPTURE"
		DockingState.DOCKED: return "DOCKED"
		DockingState.UNDOCKING: return "UNDOCKING"
	return "UNKNOWN"
