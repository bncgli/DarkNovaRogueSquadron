### Infrastructure Context Index

Project metadata, documentation, and external tools.

| Directory | Purpose | Key Files |
|-----------|---------|-----------|
| `addons/` | Godot editor plugins for custom workflows. | `ship_sublayer_editor` (Software Manager, Password centralization, Flux/Spawn support), `star_system_editor` |
| `docs/` | Technical documentation and architectural designs. | `APP_ARCHITECTURE_STANDARD.md`, `architecture/` |
| `tests/` | Test suites for project features. | N/A |
| `Art/` | Graphical assets, textures, and UI elements. | `Godot Logo.png`, `icon.svg` |
| `Default Files/` | Default virtual files for the OS interface. | N/A |

#### Technical Notes
- `addons/` contains tools specifically built to help designers create ship layouts and star systems within the Godot editor.
- `ship_sublayer_editor` includes a **Software Manager** for installing `.tres` applications and centralizing password management; the UI now uses a unified single-line layout for apps and passwords to improve information density.
- `docs/architecture/` contains the primary source of truth for the system design.
