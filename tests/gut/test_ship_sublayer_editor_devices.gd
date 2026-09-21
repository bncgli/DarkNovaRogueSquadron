extends GutTest

## Test Unitario GUT per la gestione vincolata dei dispositivi di bordo
## e le operazioni di customizzazione e trasferimento nello ShipSublayerEditor.

var bp: ShipBlueprint
var room_bridge: ShipRoomData
var room_sensors: ShipRoomData

func before_each() -> void:
	bp = ShipBlueprint.new()
	bp.ship_id = "test_ship"
	bp.ship_name = "Test Corvette"
	
	room_bridge = ShipRoomData.new("bridge", "Ponte di Comando", Rect2(0, 0, 100, 100))
	room_sensors = ShipRoomData.new("sensors", "Matrice Sensori", Rect2(200, 0, 100, 100))
	
	bp.rooms.append(room_bridge)
	bp.rooms.append(room_sensors)

func after_each() -> void:
	if bp:
		bp = null

func test_canonical_devices_definitions() -> void:
	assert_true(ShipDeviceData.CANONICAL_DEVICES.size() >= 20, "Must have all canonical devices defined")
	var req_keys := [
		"core_reactor", "battery_01", "cooling_01", "engine_main", "rcs_pitch_l", "rcs_pitch_r",
		"helm_control", "nav_computer", "sensors_matrix", "antenna_array", "armory_defense",
		"arm_sx_balancer", "arm_dx_balancer", "scrubber", "heater", "serra_idroponica",
		"cargo_handling", "dronestation", "recharge_dock", "server_rack", "cam_array"
	]
	for k in req_keys:
		assert_true(ShipDeviceData.CANONICAL_DEVICES.has(k), "Missing canonical key: " + k)
		var c_def: Dictionary = ShipDeviceData.get_canonical_def(k)
		assert_true(c_def.has("name") and not c_def["name"].is_empty())
		assert_true(c_def.has("category") and not c_def["category"].is_empty())
		assert_true(c_def.has("component_class") and not c_def["component_class"].is_empty())

func test_create_canonical_device_helper() -> void:
	var dev := ShipDeviceData.create_canonical_device("sensors_matrix", "sensors_matrix_01", "Matrice Sensori", Vector2(250, 50))
	assert_not_null(dev)
	assert_eq(dev.id, "sensors_matrix_01")
	assert_eq(dev.name, "Matrice Sensori Phased Array")
	assert_eq(dev.category, "sensors")
	assert_almost_eq(dev.power_mw, -25.0, 0.01)
	assert_eq(dev.component_class, "SensorsMatrixComponent")
	assert_eq(dev.sector, "Matrice Sensori")
	assert_eq(dev.pos, Vector2(250, 50))

func test_unique_device_id_generation() -> void:
	assert_eq(bp.get_unique_device_id("battery_01"), "battery_01")
	
	var dev1 := ShipDeviceData.create_canonical_device("battery_01", "battery_01", "bridge", Vector2(50, 50))
	room_bridge.devices.append(dev1)
	
	assert_eq(bp.get_unique_device_id("battery_01"), "battery_02")
	
	var dev2 := ShipDeviceData.create_canonical_device("battery_01", "battery_02", "bridge", Vector2(50, 50))
	room_bridge.devices.append(dev2)
	
	assert_eq(bp.get_unique_device_id("battery_01"), "battery_03")

func test_custom_power_and_name_recalculation() -> void:
	var dev := ShipDeviceData.create_canonical_device("engine_main", "engine_main_01", "bridge", Vector2(50, 50))
	room_bridge.devices.append(dev)
	bp.recalculate_all_powers()
	assert_almost_eq(room_bridge.power_mw, -50.0, 0.01)
	
	# Personalizzazione del nome
	dev.name = "Motore Ionico Sovralimentato"
	assert_eq(dev.name, "Motore Ionico Sovralimentato")
	
	# Personalizzazione della potenza (es. sovralimentato a -75 MW)
	dev.power_mw = -75.0
	bp.recalculate_all_powers()
	assert_almost_eq(room_bridge.power_mw, -75.0, 0.01)
	
	# Aggiunta generatore (es. +200 MW)
	var gen := ShipDeviceData.create_canonical_device("core_reactor", "core_reactor_01", "bridge", Vector2(50, 50))
	gen.power_mw = 200.0
	room_bridge.devices.append(gen)
	bp.recalculate_all_powers()
	assert_almost_eq(room_bridge.power_mw, 125.0, 0.01)

func test_move_device_between_rooms() -> void:
	var dev := ShipDeviceData.create_canonical_device("sensors_matrix", "sensors_matrix_01", "bridge", Vector2(50, 50))
	room_bridge.devices.append(dev)
	bp.recalculate_all_powers()
	
	assert_almost_eq(room_bridge.power_mw, -25.0, 0.01)
	assert_almost_eq(room_sensors.power_mw, 0.0, 0.01)
	assert_eq(bp.find_room_by_device_id("sensors_matrix_01"), room_bridge)
	
	# Spostamento nella stanza sensors
	var moved := bp.move_device_to_room("sensors_matrix_01", "sensors")
	assert_true(moved)
	
	assert_eq(bp.find_room_by_device_id("sensors_matrix_01"), room_sensors)
	assert_eq(room_bridge.devices.size(), 0)
	assert_eq(room_sensors.devices.size(), 1)
	assert_almost_eq(room_bridge.power_mw, 0.0, 0.01)
	assert_almost_eq(room_sensors.power_mw, -25.0, 0.01)
	assert_eq(dev.sector, "Matrice Sensori")
	assert_eq(dev.pos, room_sensors.rect.get_center())

func test_find_room_by_device_id_nonexistent() -> void:
	assert_null(bp.find_room_by_device_id("nonexistent_device"))
	assert_false(bp.move_device_to_room("nonexistent_device", "sensors"))
	assert_false(bp.move_device_to_room("sensors_matrix_01", "nonexistent_room"))
