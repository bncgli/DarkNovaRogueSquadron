### Gameplay Context Index

Contains specialized gameplay mechanics logic.

| File | Purpose | Critical Dependencies |
|------|---------|-----------------------|
| `Mining/mining_manager.gd` | Manages mining sessions and resource drops. | `CargoManager`, `SpaceWorldManager` |
| `res://Outside/ShipSublayer/ship_blueprint.gd` | Core ship data structure (Rooms, Energy, Ducts). | `RoomDatabase` |

#### Ship Systems Refactoring
- **Energy Centralization**: Power is now managed per room, simplifying the previous conduit/junction system.
- **Ship Blueprint**: Acts as the single source of truth for the ship's physical and functional layout.

#### Technical Notes
- The mining system interfaces with the 3D world (`Outside/Mining`) to spawn mineral deposits and handle extraction lasers.
