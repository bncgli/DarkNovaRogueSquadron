### Dark Nova Rogue Squadron - Global Context

#### Project Information
- **Name:** Dark Nova Rogue Squadron
- **Description:** A fake operating system interface, created by popcar2 for fun!
- **Version:** 1.2.0
- **Main Scene:** `res://Scenes/Main/MainScene.tscn`
- **Godot Version Features:** 4.7, GL Compatibility

#### Autoloads (Singletons)
| Name | Path | Description |
|------|------|-------------|
| HotkeyManager | `res://Scenes/Autoloads/Hotkey Manager/hotkey_manager.tscn` | Manages global hotkeys. |
| ContextMenu | `res://Scenes/Autoloads/Context Menu/context_menu.tscn` | Handles right-click context menus. |
| NotificationManager | `res://Scenes/Autoloads/Notification Manager/notification_manager.tscn` | Manages system notifications. |
| CopyPasteManager | `res://Scenes/Autoloads/CopyPaste Manager/copy_paste_manager.tscn` | Handles global copy-paste operations. |
| GlobalValues | `res://Scenes/Autoloads/GlobalValues/global_values.tscn` | Stores global state and configuration. |
| DefaultValues | `res://Scenes/Autoloads/Default Values/default_values.tscn` | Stores default configuration values. |
| NetworkManager | `res://Scenes/Networking/network_manager.tscn` | Manages networking capabilities. |
| SpaceWorldManager | `res://Outside/space_world_manager.gd` | Manages the 3D space world environment. |
| StarSystemGridManager | `res://Outside/StarSystemGrid/star_system_grid_manager.gd` | Manages the star system grid. |
| ShipDriveManager | `res://Scenes/Autoloads/ShipDrive/ship_drive_manager.gd` | Manages ship movement and drive systems. |
| TerminalDriveManager | `res://Scenes/Autoloads/TerminalDrive/terminal_drive_manager.gd` | Manages terminal-related drive operations. |
| FolderPasswordManager | `res://Scenes/Autoloads/FolderPasswordManager/folder_password_manager.gd` | Manages passwords for folders. |
| ShipSoftwareManager | `res://Scenes/Autoloads/SoftwareManager/ship_software_manager.gd` | Manages software installed on the ship. |
| TerminalSoftwareManager | `res://Scenes/Autoloads/SoftwareManager/terminal_software_manager.gd` | Manages software on the terminal. |
| CargoManager | `res://Economy/cargo_manager.gd` | Manages cargo and inventory. |
| FluxEconomyManager | `res://Economy/flux_economy_manager.gd` | Manages the game economy (Flux). |

#### Key Directories
| Path | Purpose |
|------|---------|
| `res://Applications/` | Repository of application resources (`.tres`, `.tscn`, `.gd`). |
| `res://Outside/` | Ship blueprint, star system data, and 3D world logic. |
| `res://Scenes/` | Core OS UI components, autoloads, and networking. |

#### Critical Dependencies
- The game uses a custom user directory: `GodotOS`.
- Rendering Method: `gl_compatibility`.
