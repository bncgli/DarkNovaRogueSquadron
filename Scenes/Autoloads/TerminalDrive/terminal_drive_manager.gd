class_name TerminalDriveManagerSingleton
extends Node

## Singleton / Manager per la gestione dell'unità "Terminal Drive" sul Desktop di GodotOS.
## Contiene le impostazioni, documentazione, alias e configurazioni del terminale.
## A differenza di "Ship Drive", questa cartella è strettamente locale e non necessita
## di sincronizzazione multiplayer tra i giocatori.
## Viene caricata di default sul Desktop all'avvio del programma.

signal terminal_drive_loaded()

const TERMINAL_DRIVE_NAME := "Terminal Drive"
const TERMINAL_DRIVE_ROOT_DIR := "user://files/Terminal Drive"

var is_drive_loaded: bool = false

func _ready() -> void:
	ensure_drive_exists()

## Verifica o crea la cartella Terminal Drive e i file di configurazione di default
func ensure_drive_exists() -> void:
	if not DirAccess.dir_exists_absolute("user://files"):
		DirAccess.make_dir_recursive_absolute("user://files")
	
	if not DirAccess.dir_exists_absolute(TERMINAL_DRIVE_ROOT_DIR):
		DirAccess.make_dir_recursive_absolute(TERMINAL_DRIVE_ROOT_DIR)
	
	_populate_default_terminal_drive_files()
	is_drive_loaded = true
	terminal_drive_loaded.emit()

func _populate_default_terminal_drive_files() -> void:
	var settings_path := "%s/Terminal Settings.txt" % TERMINAL_DRIVE_ROOT_DIR
	if not FileAccess.file_exists(settings_path):
		_write_file_content("Terminal Drive/Terminal Settings.txt", """=== DARK NOVA - TERMINAL CONFIGURATION ===
# Impostazioni di visualizzazione terminale
PROMPT_STYLE=folder_arrow
FONT_SIZE=14
THEME_ACCENT=matrix_green
AUTO_SCROLL=true

# Comportamento della shell
HISTORY_MAX_ENTRIES=100
AUTO_FOCUS=true
SHOW_WELCOME_BANNER=true

# Informazioni di sistema
TERMINAL_ID=DN-TERM-01
OS_NAME=GodotOS
VERSION=1.2.0
SECURITY_LEVEL=OPERATIONAL
DRIVE_MOUNT=LOCAL
""")

	var commands_path := "%s/Commands Reference.txt" % TERMINAL_DRIVE_ROOT_DIR
	if not FileAccess.file_exists(commands_path):
		_write_file_content("Terminal Drive/Commands Reference.txt", "=== GUIDA COMANDI TERMINALE ===\n\nCOMANDI DISPONIBILI:\n----------------------------------------------------------------------\n  help [comando]     Mostra la lista dei comandi o i dettagli di un comando.\n  ls [percorso]      Elenca file e cartelle nella directory corrente o nel percorso specificato.\n  cd <percorso>      Cambia la cartella di lavoro corrente (supporta '..', '/', o percorsi relativi).\n  pwd                Visualizza il percorso virtuale corrente.\n  cat <file>         Mostra a schermo il contenuto di un file di testo.\n  touch <file>       Crea un nuovo file vuoto nella directory indicata.\n  mkdir <cartella>   Crea una nuova cartella nel percorso indicato.\n  echo <testo>       Stampa il testo specificato sul terminale.\n  clear              Pulisce l'output della schermata del terminale.\n  date               Mostra data e ora correnti di sistema.\n\nUNITA' DI SISTEMA:\n----------------------------------------------------------------------\n  - Terminal Drive : Impostazioni e configurazioni locali della shell.\n  - Ship Drive     : File di bordo condivisi in rete (attivo quando connessi).\n")

	var env_path := "%s/Environment.txt" % TERMINAL_DRIVE_ROOT_DIR
	if not FileAccess.file_exists(env_path):
		_write_file_content("Terminal Drive/Environment.txt", """# Profilo Ambiente Shell Locale
USER=Operator
HOSTNAME=DarkNova-Console
SHELL=/bin/godotos-sh
TERMINAL_DRIVE=user://files/Terminal Drive
NETWORK_SYNC=DISABLED
LOCALE=it_IT.UTF-8
""")

	var aliases_path := "%s/Aliases.txt" % TERMINAL_DRIVE_ROOT_DIR
	if not FileAccess.file_exists(aliases_path):
		_write_file_content("Terminal Drive/Aliases.txt", """# Alias personalizzati per sessioni di lavoro
# Sintassi: alias=comando
cls=clear
dir=ls
sysinfo=cat Environment.txt
config=cat "Terminal Settings.txt"
manual=cat "Commands Reference.txt"
""")

	var term_dat_path := "%s/systems/terminal_config.dat" % TERMINAL_DRIVE_ROOT_DIR
	if not FileAccess.file_exists(term_dat_path):
		_write_file_content("Terminal Drive/systems/terminal_config.dat", """# GODOTOS TERMINAL RUNTIME CONFIGURATION
# WARNING: TERMINAL CORE FIRMWARE FILE - DIRECT EDITING RESTRICTED
[TERMINAL]
terminal_id=DN-TERM-01
shell=/bin/godotos-sh
prompt_style=folder_arrow
font_size=14
theme_accent=matrix_green
auto_scroll=true
auto_focus=true
show_welcome_banner=true
history_max_entries=100
security_level=OPERATIONAL
""")

	var os_dat_path := "%s/systems/godotos_core.dat" % TERMINAL_DRIVE_ROOT_DIR
	if not FileAccess.file_exists(os_dat_path):
		_write_file_content("Terminal Drive/systems/godotos_core.dat", """# GODOTOS CORE SYSTEM CONFIGURATION
# WARNING: SYSTEM KERNEL FIRMWARE - DIEGETIC OS CONFIGURATION
[OS_CORE]
os_name=GodotOS
version=1.2.0
build=2026.08
kernel=GodotOS-Kernel-v4.7
architecture=x86_64_diegetic
security_level=OPERATIONAL
locale=it_IT.UTF-8
drive_mount=LOCAL
desktop_mode=MULTI_WINDOW
window_manager=GODOTOS_WM
vram_allocation_mb=512
swap_enabled=true
max_open_windows=16

[SYSTEM_DRIVES]
terminal_drive_mounted=true
ship_drive_sync=NETWORK_SYNC
network_sync=DISABLED
""")

	var desktop_dat_path := "%s/systems/desktop_config.dat" % TERMINAL_DRIVE_ROOT_DIR
	if not FileAccess.file_exists(desktop_dat_path):
		_write_file_content("Terminal Drive/systems/desktop_config.dat", """# GODOTOS DESKTOP & DISPLAY RUNTIME MATRIX
[DESKTOP]
wallpaper=default
theme=matrix_green
taskbar_position=BOTTOM
animations_enabled=true
notification_sound=true
clock_format=24H
resolution_scaling=1.0
""")

	var fpm := get_node_or_null("/root/FolderPasswordManager")
	if fpm:
		fpm.set_password("Terminal Drive/systems", "ROOT-7815")
		
	var tsm := get_node_or_null("/root/TerminalSoftwareManager")
	if tsm and tsm.has_method("populate_all_terminal_drive_apps"):
		tsm.populate_all_terminal_drive_apps()

func _write_file_content(rel_path: String, content: String) -> void:
	var abs_path := "user://files/%s" % rel_path
	var base_dir := abs_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)
	var file := FileAccess.open(abs_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()

## Verifica se un percorso appartiene a Terminal Drive
func is_path_in_terminal_drive(path: String) -> bool:
	var clean := path.replace("\\", "/").strip_edges().trim_prefix("/").trim_suffix("/")
	return clean == TERMINAL_DRIVE_NAME or clean.begins_with(TERMINAL_DRIVE_NAME + "/")

## Recupera una configurazione chiave=valore da Terminal Settings.txt
func get_setting(key: String, default_val: String = "") -> String:
	var path := "%s/Terminal Settings.txt" % TERMINAL_DRIVE_ROOT_DIR
	if not FileAccess.file_exists(path):
		return default_val
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return default_val
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("#") or line.begins_with(";") or line.begins_with("=") or line.is_empty():
			continue
		var parts := line.split("=", true, 1)
		if parts.size() == 2 and parts[0].strip_edges() == key:
			file.close()
			return parts[1].strip_edges()
	file.close()
	return default_val
