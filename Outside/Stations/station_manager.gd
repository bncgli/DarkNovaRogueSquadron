class_name StationManager
extends DockingManager

## StationManager (Outside/Stations/station_manager.gd)
## Orchestratore di alto livello per Stazioni Spaziali, Gestione del Traffico Portuale,
## Procedura di Docking / Undocking e Sincronizzazione con GodotOS e StationHub.

signal station_registered(station: SpaceStationEntity)
signal station_unregistered(station_id: String)
signal port_traffic_updated(active_stations_count: int)

var active_stations: Array[SpaceStationEntity] = []

func _ready() -> void:
	# Cerca automaticamente eventuali SpaceStationEntity presenti nella scena
	_discover_scene_stations()

func _discover_scene_stations() -> void:
	if not is_inside_tree():
		return
	var root := get_tree().root
	_scan_for_stations_recursive(root)

func _scan_for_stations_recursive(node: Node) -> void:
	if not node:
		return
	if node is SpaceStationEntity and not active_stations.has(node):
		register_station(node)
	for child in node.get_children():
		_scan_for_stations_recursive(child)

## Registra una stazione spaziale gestita dal manager
func register_station(station: SpaceStationEntity) -> void:
	if not station or active_stations.has(station):
		return
	active_stations.append(station)
	station_registered.emit(station)
	port_traffic_updated.emit(active_stations.size())

## Rimuove una stazione dal registro
func unregister_station(station_id: String) -> void:
	for i in range(active_stations.size() - 1, -1, -1):
		if active_stations[i].station_id == station_id:
			active_stations.remove_at(i)
			station_unregistered.emit(station_id)
			port_traffic_updated.emit(active_stations.size())
			break

## Recupera una stazione dato il suo ID
func get_station_by_id(station_id: String) -> SpaceStationEntity:
	for st in active_stations:
		if is_instance_valid(st) and st.station_id == station_id:
			return st
	return null

## Recupera la stazione più vicina a una posizione data entro un raggio
func get_nearby_station(pos: Vector3, max_range: float = 5000.0) -> SpaceStationEntity:
	var closest: SpaceStationEntity = null
	var min_dist := max_range
	for st in active_stations:
		if is_instance_valid(st):
			var dist := st.global_position.distance_to(pos)
			if dist <= min_dist:
				min_dist = dist
				closest = st
	return closest

## Trova una stazione in base alla frequenza radio impostata su Comms
func get_station_by_frequency(freq: float, tolerance: float = 5.0) -> SpaceStationEntity:
	for st in active_stations:
		if is_instance_valid(st) and absf(st.comms_frequency - freq) <= tolerance:
			return st
	return null

## Richiesta di docking agevolata tramite frequenza radio
func request_docking_by_frequency(freq: float, ship_id: String = "", iff_code: String = "") -> bool:
	var st := get_station_by_frequency(freq)
	if not st and not active_stations.is_empty():
		st = active_stations[0]
	if st:
		return request_docking_clearance(st, ship_id, iff_code)
	return false
