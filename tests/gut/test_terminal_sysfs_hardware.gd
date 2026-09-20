extends GutTest

## Test di integrazione GUT per VirtualSysfsDriver e comandi Terminale (cat, echo, ls, dev) (Step 3).

var bus: ShipHardwareBus
var reactor: ReactorComponent
var thruster: ThrusterComponent
var sysfs: VirtualSysfsDriver

func before_each() -> void:
	bus = ShipHardwareBus.new()
	reactor = ReactorComponent.new("reactor_01", "engine_room", "engineering")
	reactor.power_output_nominal = 1000.0
	reactor.power_target = 1.0
	
	thruster = ThrusterComponent.new("thruster_01", "engine_room", "propulsion")
	thruster.max_thrust = 40.0
	
	bus.register_component(reactor)
	bus.register_component(thruster)
	sysfs = VirtualSysfsDriver.new(bus)

func after_each() -> void:
	if bus:
		bus.clear_all_components()
		bus.free()
	sysfs = null

func test_sysfs_path_resolution_and_validation() -> void:
	# Percorsi validi
	assert_true(sysfs.is_valid_folder("sys"))
	assert_true(sysfs.is_valid_folder("/sys/rooms"))
	assert_true(sysfs.is_valid_folder("/sys/rooms/engine_room"))
	assert_true(sysfs.is_valid_folder("/sys/devices"))
	
	# File di registro validi
	assert_true(sysfs.is_valid_file("/sys/rooms/engine_room/reactor_01/status"))
	assert_true(sysfs.is_valid_file("/sys/rooms/engine_room/reactor_01/power_target"))
	assert_true(sysfs.is_valid_file("/sys/devices/thruster_01/throttle_target"))
	
	# Percorsi non esistenti
	assert_false(sysfs.is_valid_folder("/sys/rooms/non_existent_room"))
	assert_false(sysfs.is_valid_file("/sys/rooms/engine_room/reactor_01/fake_register"))
	assert_false(sysfs.is_valid_file("/sys/rooms/fake_room/fake_device/status"))

func test_sysfs_directory_and_file_listing() -> void:
	var root_dirs := sysfs.list_directories("sys")
	assert_true(root_dirs.has("rooms"))
	assert_true(root_dirs.has("devices"))
	
	var rooms := sysfs.list_directories("/sys/rooms")
	assert_true(rooms.has("engine_room"))
	
	var engine_devs := sysfs.list_directories("/sys/rooms/engine_room")
	assert_true(engine_devs.has("reactor_01"))
	assert_true(engine_devs.has("thruster_01"))
	
	var reactor_regs := sysfs.list_files("/sys/rooms/engine_room/reactor_01")
	assert_true(reactor_regs.has("status"))
	assert_true(reactor_regs.has("power_target"))
	assert_true(reactor_regs.has("temp"))

func test_sysfs_read_and_write_file() -> void:
	# Lettura
	var status_val := sysfs.read_file("/sys/rooms/engine_room/reactor_01/status")
	assert_eq(status_val, "ONLINE")
	
	# Scrittura su power_target
	var write_res := sysfs.write_file("/sys/rooms/engine_room/reactor_01/power_target", "1.4")
	assert_true(write_res.get("success", false))
	assert_almost_eq(reactor.power_target, 1.4, 0.01)
	
	# Verifica rilettura nuovo valore
	var read_new := sysfs.read_file("/sys/rooms/engine_room/reactor_01/power_target")
	assert_almost_eq(float(read_new), 1.4, 0.01)
	
	# Scrittura su registro readonly (es. status o health) deve fallire
	var ro_res := sysfs.write_file("/sys/rooms/engine_room/reactor_01/status", "OFFLINE")
	assert_false(ro_res.get("success", true))
	assert_eq(reactor.status_string, "ONLINE")

func test_virtual_path_manager_sysfs_integration() -> void:
	var vpm := VirtualPathManager.new()
	vpm._sysfs_driver = sysfs
	
	# Controlla che vpm riconosca sysfs come cartella
	assert_true(vpm.path_is_valid_folder("sys"))
	assert_true(vpm.path_is_valid_folder("/sys/rooms/engine_room"))
	
	# Controlla navigazione e listing
	vpm.set_path("sys/rooms/engine_room")
	assert_eq(vpm.get_current_folder(), "engine_room")
	
	var devs := vpm.list_directories()
	assert_true(devs.has("reactor_01"))
	
	var regs := vpm.list_files("sys/rooms/engine_room/reactor_01")
	assert_true(regs.has("status"))

func test_dev_command_execution() -> void:
	var dev_cmd: TerminalCommand = load("res://Applications/Terminal/commands/dev_command.gd").new()
	var tdm: TerminalDriveManagerSingleton = get_node_or_null("/root/TerminalDriveManager")
	if tdm:
		tdm.sysfs_driver = sysfs
		
	# Creiamo un terminal mock / leggero
	var term_scene: PackedScene = load("res://Applications/Terminal/src/terminal_scene.tscn")
	var terminal: Terminal = term_scene.instantiate()
	add_child_autofree(terminal)
	terminal.virtual_path_manager._sysfs_driver = sysfs
	
	# Test dev list
	dev_cmd.execute(terminal, ["list"])
	var output_text: String = str(terminal.command_output_container.get_child(terminal.command_output_container.get_child_count() - 1).text)
	assert_true(output_text.contains("reactor_01") or output_text.contains("thruster_01"))
	
	# Test dev status
	dev_cmd.execute(terminal, ["status", "reactor_01"])
	# Test dev set
	dev_cmd.execute(terminal, ["set", "reactor_01", "power_target", "0.9"])
	assert_almost_eq(reactor.power_target, 0.9, 0.01)
	
	# Test dev get
	dev_cmd.execute(terminal, ["get", "reactor_01", "power_target"])
	
	# Test dev online
	dev_cmd.execute(terminal, ["online", "reactor_01", "0"])
	assert_false(reactor.is_online)
	dev_cmd.execute(terminal, ["online", "reactor_01", "1"])
	assert_true(reactor.is_online)

func test_dev_command_disconnected_ship() -> void:
	var dev_cmd: TerminalCommand = load("res://Applications/Terminal/commands/dev_command.gd").new()
	var tdm: TerminalDriveManagerSingleton = get_node_or_null("/root/TerminalDriveManager")
	var old_driver = null
	if tdm:
		old_driver = tdm.sysfs_driver
		tdm.sysfs_driver = VirtualSysfsDriver.new(null)
		
	var term_scene: PackedScene = load("res://Applications/Terminal/src/terminal_scene.tscn")
	var terminal: Terminal = term_scene.instantiate()
	add_child_autofree(terminal)
	terminal.virtual_path_manager._sysfs_driver = VirtualSysfsDriver.new(null)
	
	dev_cmd.execute(terminal, ["list"])
	var output_text: String = str(terminal.command_output_container.get_child(terminal.command_output_container.get_child_count() - 1).text)
	assert_true(output_text.contains("Errore: Hardware Bus non disponibile o nave non inizializzata"))
	
	if tdm:
		tdm.sysfs_driver = old_driver

func test_cat_and_echo_redirection_sysfs() -> void:
	var cat_cmd: TerminalCommand = load("res://Applications/Terminal/commands/cat_command.gd").new()
	var echo_cmd: TerminalCommand = load("res://Applications/Terminal/commands/echo_command.gd").new()
	
	var term_scene: PackedScene = load("res://Applications/Terminal/src/terminal_scene.tscn")
	var terminal: Terminal = term_scene.instantiate()
	add_child_autofree(terminal)
	terminal.virtual_path_manager._sysfs_driver = sysfs
	
	# Test echo con redirezione su power_target: echo 1.25 > /sys/rooms/engine_room/reactor_01/power_target
	echo_cmd.execute(terminal, ["1.25", ">", "/sys/rooms/engine_room/reactor_01/power_target"])
	assert_almost_eq(reactor.power_target, 1.25, 0.01, "Echo con redirezione deve aggiornare il registro hardware")
	
	# Test cat del valore aggiornato
	cat_cmd.execute(terminal, ["/sys/rooms/engine_room/reactor_01/power_target"])
	var cat_output: String = str(terminal.command_output_container.get_child(terminal.command_output_container.get_child_count() - 1).text)
	assert_almost_eq(float(cat_output), 1.25, 0.01)
