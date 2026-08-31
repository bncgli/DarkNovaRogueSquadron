### Scenes Context Index

GodotOS system components and UI infrastructure.

| File/Directory | Purpose | Critical Dependencies |
|----------------|---------|-----------------------|
| `Main/` | Game entry point (`MainScene.tscn`) and boot splash. | `GlobalValues`, `DefaultValues` |
| `Desktop/` | Desktop surface, wallpaper, and icon management. | `Taskbar`, `WindowManager` |
| `Taskbar/` | App bar, start menu, and system clock. | `WindowManager` |
| `Window/` | Floating window system, drag & drop, and file manager. | `WindowManager` |
| `Networking/` | NetworkManager for multiplayer and sync. | `SpaceWorldManager`, `StarSystemGridManager` |
| `Autoloads/` | System-wide singletons (Hotkey, ContextMenu, etc.). | See `global_context.md` |
| `Containers/` | Reusable UI container components. | N/A |
| `Misc/` | Miscellaneous UI elements and helper scripts. | N/A |

#### Technical Notes
- `MainScene.tscn` initializes the OS environment.
- The windowing system is a custom implementation for GodotOS to simulate a desktop environment.
