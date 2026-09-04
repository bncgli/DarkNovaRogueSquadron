class_name RemoteDriveManagerSingleton
extends Node

## Singleton / Autoload per la gestione dell'unità remota "Target Drive" sul Desktop di GodotOS.
## Gestisce il montaggio/smontaggio diegetico delle cartelle della nave bersaglio,
## la creazione dei firmware .dat remoti, l'iniezione degli exploit e il monitoraggio dei file sentinella (.pid / .sys).

signal target_drive_mounted(target_ship_id: String)
signal target_drive_unmounted()
signal exploit_executed(exploit_type: String, target_ship_id: String)
signal exploit_terminated(exploit_type: String, target_ship_id: String)
signal spammer_popup_triggered(message: String, title: String)
signal drive_updated()

const TARGET_DRIVE_NAME := "Target Drive"
const TARGET_DRIVE_ROOT_DIR := "user://files/Target Drive"

const SPAMMER_SENTINEL := "System/spammer.pid"
const BLIND_EYE_SENTINEL := "Cams/blind_eye.pid"
const EIGHT_LOOPS_SENTINEL := "FlightControl/8loops.sys"
const GOUT_SENTINEL := "FlightControl/gout.pid"
const GOUT_FALLBACK_SENTINEL := "System/gout.pid"

var is_target_drive_mounted: bool = false
var current_target_ship_id: String = ""
var current_target_ship_name: String = ""

var active_exploits: Dictionary = {
	"spammer": false,
	"blind_eye": false,
	"8loops": false,
	"gout": false
}

var _poll_timer: float = 0.0
var _spammer_spawn_timer: float = 0.0
var _blind_eye_timer: float = 0.0

const SPAM_ADS: Array[Dictionary] = [
	{
		"title": "⚡ PROMO QUANTUM DRIVE ⚡",
		"message": "AGGIORNA SUBITO IL TUO REATTORE CON UNO SCONTO DEL 50%! ACQUISTA SU DARKOVERLAY.NET!",
		"accent": "ff0055"
	},
	{
		"title": "🛡️ SCUDI DEFLETTORI ULTRA 🛡️",
		"message": "I TUOI SCUDI FANNO ACQUA? PASSA A MATRICE HYPER-SHIELD V9! CLICCA QUI PER ATTIVARE IL TRIAL!",
		"accent": "ffaa00"
	},
	{
		"title": "🚀 SILURI AL PLASMA 2x1 🚀",
		"message": "OFFERTA IMPERDIBILE DEI CANTIERI PIRATA: COMPRA 1 SILURO E NE RICEVI 2! CONSEGNA IMMEDIATA IN WARP!",
		"accent": "00ffff"
	},
	{
		"title": "⚠️ ATTENZIONE: VIRUS RILEVATO ⚠️",
		"message": "IL TUO SISTEMA OPERATIVO HA 999 ERRORI CRITICI! SCARICA L'ANTIVIRUS PIRATA GRATUITO ADESSO!",
		"accent": "ff2222"
	},
	{
		"title": "💎 FLUX COINS GRATIS 💎",
		"message": "CONGRATULAZIONI! SEI IL VISITATORE NUMERO 1.000.000 DEL SETTORE! RISCATTA 500.000 FLUX ADESSO!",
		"accent": "39ff14"
	}
]

func _ready() -> void:
	# All'avvio puliamo eventuali residui di Target Drive non smontati correttamente
	if DirAccess.dir_exists_absolute(TARGET_DRIVE_ROOT_DIR):
		_delete_dir_recursive(TARGET_DRIVE_ROOT_DIR)

func _process(delta: float) -> void:
	if not is_target_drive_mounted:
		return
	
	_poll_timer += delta
	if _poll_timer >= 0.25:
		_poll_timer = 0.0
		_check_sentinel_files()
	
	# Gestione attiva degli effetti temporali degli exploit
	if active_exploits.get("spammer", false):
		_spammer_spawn_timer -= delta
		if _spammer_spawn_timer <= 0.0:
			_spammer_spawn_timer = 2.5
			_trigger_spam_ad()
	
	if active_exploits.get("blind_eye", false):
		_blind_eye_timer -= delta
		if _blind_eye_timer <= 0.0:
			_blind_eye_timer = 1.0
			_enforce_camera_blackout()

## Monta l'unità Target Drive popolandola con le sottocartelle e i firmware diegetici
func mount_target_drive(target_ship_id: String, target_name: String = "Nave Bersaglio", custom_passwords: Dictionary = {}, _custom_files: Array = []) -> void:
	if is_target_drive_mounted and current_target_ship_id != target_ship_id:
		unmount_target_drive()
	
	is_target_drive_mounted = true
	current_target_ship_id = target_ship_id
	current_target_ship_name = target_name
	
	# 1. Creazione cartella principale
	if not DirAccess.dir_exists_absolute(TARGET_DRIVE_ROOT_DIR):
		DirAccess.make_dir_recursive_absolute(TARGET_DRIVE_ROOT_DIR)
	
	# 2. Creazione sottocartelle diegetiche
	var subfolders: Array[String] = [
		"FlightControl",
		"Cams",
		"System",
		"LifeSupport",
		"Weapons"
	]
	
	for subf in subfolders:
		var full_sub_path := "%s/%s" % [TARGET_DRIVE_ROOT_DIR, subf]
		if not DirAccess.dir_exists_absolute(full_sub_path):
			DirAccess.make_dir_recursive_absolute(full_sub_path)
	
	# 3. Popolamento file .dat diegetici
	_populate_target_drive_files(target_ship_id, target_name)
	
	# 4. Configurazione password delle cartelle in FolderPasswordManager
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	if fpm:
		var default_pw := {
			"Target Drive/FlightControl": "FC-HOSTILE-99",
			"Target Drive/Cams": "CAMS-HOSTILE-44",
			"Target Drive/System": "SYS-HOSTILE-11",
			"Target Drive/LifeSupport": "LIFE-HOSTILE-55",
			"Target Drive/Weapons": "WEAP-HOSTILE-77"
		}
		
		# Applica custom_passwords se presenti
		for k in custom_passwords:
			var norm_k: String = str(k)
			if not norm_k.begins_with("Target Drive/"):
				norm_k = "Target Drive/" + norm_k
			default_pw[norm_k] = str(custom_passwords[k])
		
		for folder_path in default_pw:
			fpm.set_password(folder_path, default_pw[folder_path])
	
	_refresh_desktop()
	
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("⚡ Target Drive montato per %s." % target_name)
	
	target_drive_mounted.emit(target_ship_id)
	drive_updated.emit()

## Smonta l'unità remota, interrompe gli exploit ed elimina file e password temporanei
func unmount_target_drive() -> void:
	if not is_target_drive_mounted and not DirAccess.dir_exists_absolute(TARGET_DRIVE_ROOT_DIR):
		return
	
	# Termina tutti gli exploit attivi
	for exploit_key in active_exploits.keys():
		if active_exploits[exploit_key]:
			terminate_exploit(exploit_key, false)
	
	is_target_drive_mounted = false
	current_target_ship_id = ""
	current_target_ship_name = ""
	
	# Chiudi finestre associate a Target Drive
	_close_target_drive_windows()
	
	# Rimuovi file su disco
	if DirAccess.dir_exists_absolute(TARGET_DRIVE_ROOT_DIR):
		_delete_dir_recursive(TARGET_DRIVE_ROOT_DIR)
	
	# Pulisci password
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	if fpm:
		fpm.delete_path(TARGET_DRIVE_NAME)
	
	_refresh_desktop()
	
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("Target Drive smontato dal Desktop.")
	
	target_drive_unmounted.emit()
	drive_updated.emit()

func _populate_target_drive_files(ship_id: String, ship_name: String) -> void:
	# FlightControl .dat files
	_write_target_file("FlightControl/flight_config.dat", """# TARGET FLIGHT COMPUTER FIRMWARE
[FLIGHT_CONTROL]
app_name=FlightControl
version=1.0.4
status=OPERATIONAL
decryption_key=FLGT-SEC-9921
max_speed=40.0
max_angular_velocity=2.5
g_limiter=true
damping_factor=0.95
auto_heading=true
""")

	_write_target_file("FlightControl/thrusters_tuning.dat", """# TARGET PROPULSION & THRUSTER CALIBRATION
[THRUSTERS]
cruise_multiplier=8.0
decryption_key=THRU-KEY-3310
warmup_time_sec=4.0
maneuver_mode=STANDARD
rcs_burn_rate=1.2
overclock_thrust=1.0
""")

	_write_target_file("FlightControl/Nav_Route.txt", """=== ROTTA DI VOLO BERSAGLIO ===
DESTINAZIONE: Settore Clandestino 9
PATTUGLIAMENTO: Stazione Mineraria Theta
ORDINI: Intercettare e neutralizzare qualsiasi sonda ostile.
""")

	# Cams .dat files
	_write_target_file("Cams/cams_config.dat", """# TARGET OPTICS & CCTV FIRMWARE
[CAMS]
app_name=Cams
version=1.2.0
status=OPERATIONAL
decryption_key=CAMS-SEC-4412
feed_active=true
channels=6
resolution=1080p
stream_bitrate_mbps=15.0
""")

	_write_target_file("Cams/optics_tuning.dat", """# TARGET SENSORS OPTICS TUNING MATRIX
[OPTICS]
decryption_key=OPTC-KEY-8820
night_vision=true
thermal_enabled=true
lidar_enabled=true
filter_mask=STANDARD
gain=1.0
""")

	# System .dat files
	_write_target_file("System/system_config.dat", """# TARGET CORE SYSTEM CONFIGURATION
[SYSTEM]
target_id=%s
target_name=%s
os_version=GodotOS-4.7-Hostile
decryption_key=SYST-KEY-1104
security_level=RESTRICTED
popup_filter=ENABLED
kernel_integrity=100.0
active_threads=12
""" % [ship_id, ship_name])

	_write_target_file("System/Security_Notice.txt", """=== AVVISO DI SICUREZZA MAINFRAME ===
ACCESSO RISERVATO AGLI UFFICIALI DI BORDO.
OGNI TENTATIVO DI INTRUSIONE RADIO EW SARA' REGISTRATO E REPRESSO.
FILE SENTINELLA ATTIVI SUL KERNEL.
""")

	# LifeSupport .dat files
	_write_target_file("LifeSupport/life_support.dat", """# TARGET LIFE SUPPORT & CABIN ENVIRONMENT
[LIFE_SUPPORT]
o2_level=98.5
co2_ppm=420.0
gravity_gen=1.0
decryption_key=LIFE-SEC-5501
temp_celsius=21.5
pressure_kpa=101.3
""")

	# Weapons .dat files
	_write_target_file("Weapons/weapons_config.dat", """# TARGET TACTICAL WEAPONS FIRMWARE
[WEAPONS]
active_turrets=2
laser_draw_mw=180.0
decryption_key=WEAP-KEY-7733
torpedoes_loaded=8
pdg_auto_intercept=true
""")

## Esegue l'attivazione di uno dei 4 exploit depositando il file sentinella
func execute_exploit(exploit_type: String) -> bool:
	if not is_target_drive_mounted:
		return false
	
	active_exploits[exploit_type] = true
	var pid_id := randi_range(1000, 9999)
	var timestamp := Time.get_datetime_string_from_system()
	
	match exploit_type:
		"spammer":
			var content := "# SPAMMER INTRUSION PID FILE\nPID=%d\nEXPLOIT=SPAMMER\nSTATUS=ACTIVE\nTARGET=%s\nSTARTED_AT=%s\nPOPUP_RATE=2.5s\n" % [pid_id, current_target_ship_id, timestamp]
			_write_target_file(SPAMMER_SENTINEL, content)
			_spammer_spawn_timer = 0.5
			_apply_spammer_effect_to_target(true)
		
		"blind_eye":
			var content := "# BLIND_EYE INTRUSION PID FILE\nPID=%d\nEXPLOIT=BLIND_EYE\nSTATUS=ACTIVE\nTARGET=%s\nSTARTED_AT=%s\nCAMS_SHUTDOWN=FORCED\n" % [pid_id, current_target_ship_id, timestamp]
			_write_target_file(BLIND_EYE_SENTINEL, content)
			_blind_eye_timer = 0.0
			_apply_blind_eye_effect_to_target(true)
		
		"8loops":
			var content := "# 8LOOPS FLIGHT OVERRIDE SYS FILE\nPID=%d\nEXPLOIT=8LOOPS\nSTATUS=ACTIVE\nTARGET=%s\nSTARTED_AT=%s\nMANEUVER=FIGURE_8_HIGH_G\nOVERRIDE=CRUISE_PROPULSION\n" % [pid_id, current_target_ship_id, timestamp]
			_write_target_file(EIGHT_LOOPS_SENTINEL, content)
			_apply_8loops_effect_to_target(true)
		
		"gout":
			var content := "# GOUT ANGULAR VELOCITY OVERRIDE PID FILE\nPID=%d\nEXPLOIT=GOUT\nSTATUS=ACTIVE\nTARGET=%s\nSTARTED_AT=%s\nANGULAR_LIMITERS=DISABLED\nG_FORCE_UNCLAMPED=TRUE\n" % [pid_id, current_target_ship_id, timestamp]
			_write_target_file(GOUT_SENTINEL, content)
			_apply_gout_effect_to_target(true)
		
		_:
			return false
	
	exploit_executed.emit(exploit_type, current_target_ship_id)
	drive_updated.emit()
	return true

## Termina l'exploit ripristinando il normale comportamento del sistema bersaglio
func terminate_exploit(exploit_type: String, remove_file: bool = true) -> void:
	if not active_exploits.has(exploit_type):
		return
	
	active_exploits[exploit_type] = false
	
	if remove_file:
		var s_path := get_sentinel_path(exploit_type)
		if not s_path.is_empty():
			var abs_p := "%s/%s" % [TARGET_DRIVE_ROOT_DIR, s_path]
			if FileAccess.file_exists(abs_p):
				DirAccess.remove_absolute(abs_p)
	
	match exploit_type:
		"spammer":
			_apply_spammer_effect_to_target(false)
		"blind_eye":
			_apply_blind_eye_effect_to_target(false)
		"8loops":
			_apply_8loops_effect_to_target(false)
		"gout":
			_apply_gout_effect_to_target(false)
	
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("Exploit '%s' terminato su %s." % [exploit_type.to_upper(), current_target_ship_name])
	
	exploit_terminated.emit(exploit_type, current_target_ship_id)
	drive_updated.emit()

func is_exploit_active(exploit_type: String) -> bool:
	return active_exploits.get(exploit_type, false)

func get_active_exploits() -> Dictionary:
	return active_exploits.duplicate()

func get_sentinel_path(exploit_type: String) -> String:
	match exploit_type:
		"spammer": return SPAMMER_SENTINEL
		"blind_eye": return BLIND_EYE_SENTINEL
		"8loops": return EIGHT_LOOPS_SENTINEL
		"gout": return GOUT_SENTINEL
		_: return ""

func is_sentinel_file_present(exploit_type: String) -> bool:
	var s_path := get_sentinel_path(exploit_type)
	if s_path.is_empty():
		return false
	var abs_path := "%s/%s" % [TARGET_DRIVE_ROOT_DIR, s_path]
	if FileAccess.file_exists(abs_path):
		return true
	if exploit_type == "gout":
		var fallback_abs := "%s/%s" % [TARGET_DRIVE_ROOT_DIR, GOUT_FALLBACK_SENTINEL]
		return FileAccess.file_exists(fallback_abs)
	return false

func _check_sentinel_files() -> void:
	for exploit_type in active_exploits.keys():
		if active_exploits[exploit_type]:
			if not is_sentinel_file_present(exploit_type):
				# Il file è stato cancellato: termina immediatamente l'attacco
				terminate_exploit(exploit_type, false)

func _trigger_spam_ad() -> void:
	var ad: Dictionary = SPAM_ADS.pick_random()
	var ad_title: String = ad.get("title", "SPAM")
	var ad_msg: String = ad.get("message", "Promo")
	
	spammer_popup_triggered.emit(ad_msg, ad_title)
	
	# Spawna la finestra popup su GodotOS
	_spawn_spam_popup_window(ad_title, ad_msg, str(ad.get("accent", "ff0055")))

func _spawn_spam_popup_window(title: String, msg: String, color_hex: String) -> void:
	var popup_scene_path := "res://Applications/HackExploits/spam_popup_window.tscn"
	if ResourceLoader.exists(popup_scene_path):
		var scene: PackedScene = load(popup_scene_path)
		if scene:
			var popup: Node = scene.instantiate()
			if popup.has_method("setup_spam"):
				popup.setup_spam(title, msg, color_hex)
			var root_scene := get_tree().current_scene
			if root_scene == null:
				root_scene = get_tree().root
			root_scene.add_child(popup)
			return
	
	# Fallback a notifica di sistema
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("[color=#%s][b]%s[/b][/color]\n%s" % [color_hex, title, msg])

func _enforce_camera_blackout() -> void:
	# Chiude tutte le telecamere aperte dell'astronave bersaglio o della simulazione
	var cf_mgr := get_node_or_null("/root/SpaceWorldManager/CameraFeedManager")
	if not cf_mgr:
		var swm := get_node_or_null("/root/SpaceWorldManager")
		if swm and "camera_manager" in swm and swm.camera_manager:
			cf_mgr = swm.camera_manager
	
	if cf_mgr and "active_camera_windows" in cf_mgr:
		var cam_wins: Dictionary = cf_mgr.active_camera_windows
		for cam_id in cam_wins.keys():
			var win: FakeWindow = cam_wins.get(cam_id) as FakeWindow
			if win and is_instance_valid(win):
				win._on_close_button_pressed()

	for win in get_tree().get_nodes_in_group("camera_feed_window"):
		if win and is_instance_valid(win) and win.has_method("_on_close_button_pressed"):
			win._on_close_button_pressed()

func _apply_spammer_effect_to_target(active: bool) -> void:
	var enemy := _find_target_enemy()
	if enemy and enemy.has_method("apply_spammer_exploit"):
		enemy.apply_spammer_exploit(active)

func _apply_blind_eye_effect_to_target(active: bool) -> void:
	if active:
		_enforce_camera_blackout()
	var enemy := _find_target_enemy()
	if enemy and enemy.has_method("apply_blind_eye_exploit"):
		enemy.apply_blind_eye_exploit(active)

func _apply_8loops_effect_to_target(active: bool) -> void:
	var enemy := _find_target_enemy()
	if enemy and enemy.has_method("apply_8loops_exploit"):
		enemy.apply_8loops_exploit(active)
	
	var cruise := get_node_or_null("/root/CruiseDriveController")
	if cruise and cruise.has_method("apply_8loops_exploit"):
		cruise.apply_8loops_exploit(active)

func _apply_gout_effect_to_target(active: bool) -> void:
	var enemy := _find_target_enemy()
	if enemy and enemy.has_method("apply_gout_exploit"):
		enemy.apply_gout_exploit(active)
	
	var cruise := get_node_or_null("/root/CruiseDriveController")
	if cruise and cruise.has_method("apply_gout_exploit"):
		cruise.apply_gout_exploit(active)

func _find_target_enemy() -> EnemyShipAI:
	if current_target_ship_id.is_empty():
		return null
	
	for enemy in get_tree().get_nodes_in_group("enemy_ships"):
		if enemy is EnemyShipAI and enemy.ship_id == current_target_ship_id:
			return enemy
	
	# Ricerca generica in scene tree
	var combat_dir := get_node_or_null("/root/CombatDirector")
	if combat_dir and "active_enemies" in combat_dir:
		for e in combat_dir.active_enemies:
			if is_instance_valid(e) and e.ship_id == current_target_ship_id:
				return e
	return null

func _write_target_file(rel_path: String, content: String) -> void:
	var abs_path := "%s/%s" % [TARGET_DRIVE_ROOT_DIR, rel_path]
	var base_dir := abs_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f:
		f.store_string(content)
		f.close()

func _delete_dir_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var item := dir.get_next()
		while not item.is_empty():
			if item != "." and item != "..":
				var full_p := "%s/%s" % [path, item]
				if dir.current_is_dir():
					_delete_dir_recursive(full_p)
				else:
					DirAccess.remove_absolute(full_p)
			item = dir.get_next()
		dir.list_dir_end()
		DirAccess.remove_absolute(path)

func _close_target_drive_windows() -> void:
	if not is_inside_tree():
		return
	for fm in get_tree().get_nodes_in_group("file_manager_window"):
		if is_instance_valid(fm):
			var p: String = str(fm.get("file_path"))
			if p == TARGET_DRIVE_NAME or p.begins_with(TARGET_DRIVE_NAME + "/") or p.begins_with(TARGET_DRIVE_ROOT_DIR):
				if fm.has_method("close_window"):
					fm.close_window()

func _refresh_desktop() -> void:
	if not is_inside_tree():
		return
	var desktop: DesktopFileManager = get_tree().get_first_node_in_group("desktop_file_manager") as DesktopFileManager
	if desktop and is_instance_valid(desktop):
		desktop.populate_file_manager()
