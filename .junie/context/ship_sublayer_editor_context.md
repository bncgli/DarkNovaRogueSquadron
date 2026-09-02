### Ship Sublayer Editor Context Index

Custom Godot editor plugin and standalone tool for managing ship blueprints (`ShipBlueprint`).

| File | Purpose | Key Responsibilities |
|------|---------|----------------------|
| `ship_sublayer_editor.gd` | Main editor logic and UI. | UI construction, Software Manager, Room selection, Blueprint I/O. |
| `ship_blueprint_canvas.gd` | 2D Canvas for visual editing. | Rendering ship rooms, maintenance ducts, devices, and handling mouse input. |
| `ship_sublayer_editor_plugin.gd` | Godot Editor Plugin wrapper. | Integration with the Godot editor interface. |

#### Structural Changes (Refactoring)
- **Room-Based Energy**: Power is now managed at the room level. Each room tracks its own consumption and state (`is_on`).
- **Junctions & Conduits Removed**: The complex network of power lines and junctions has been removed in favor of a centralized room-based system.
- **Maintenance Ducts**: Still present for drone navigation but decoupled from the power grid.

#### Software Manager (Integrated in Editor)
- **Purpose**: Manages installed applications and drive passwords within a `ShipBlueprint`.
- **UI Layout**: Unified single-line row per item.
  - **Programs**: Displays app title with an icon (📦), a direct password field, and an uninstall button.
  - **Passwords**: Displays system/drive passwords (🔑) with a direct edit field.
- **Benefits**: Improved information density and accessibility by keeping app association and credentials in one row.
- **Persistence**: Changes are saved directly to the `ShipBlueprint` resource and support the editor's Undo/Redo stack.

#### Technical Details
- **Location**: `addons/ship_sublayer_editor/`
- **Dependency**: Uses `ShipBlueprint` (res://Outside/ShipSublayer/ship_blueprint.gd).
- **Auto-linking**: Automatically identifies passwords related to applications based on `drive_folder` or matching IDs.
- **Resource Management**: The editor now handles `ShipRoomData`, `ShipDuctData`, and `ShipDeviceData` resources natively, utilizing Godot's built-in Resource inspector features for editing properties.
