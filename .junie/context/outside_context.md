### Outside Context Index

Handles the 3D space simulation, entities, and ship physical subsystems.

| File/Directory | Purpose | Critical Dependencies |
|----------------|---------|-----------------------|
| `space_world_manager.gd` | Autoload orchestrating the 3D world and entity spawning. | `space_scene.tscn`, `spaceship.tscn` |
| `space_scene.tscn` | The main 3D scene for space gameplay. | `SpaceWorldManager` |
| `spaceship.gd` | 3D physical controller for the player's ship. | `CruiseDriveController`, `ShipBlueprint` |
| `Combat/` | AI, combat director, and systemic damage handling. | `systemic_damage_handler.gd`, `enemy_ship_ai.gd` |
| `Mining/` | 3D entities for mineral deposits and derelict ships. | `mineral_deposit_entity.tscn` |
| `ServiceDrone/` | 3D entity for the external service drone. | N/A |
| `ShipSublayer/` | Ship architecture blueprints, room-based energy system, and maintenance ducts. | `ship_blueprint.gd` (Refactored to centralize energy in rooms, removing junctions/conduits) |
| `ShipSystems/` | 3D flight controllers (CruiseDrive, RCS, Warp). | N/A |
| `Skybox/` | Dynamic space skybox shaders and rendering. | N/A |
| `StarSystemGrid/` | Galactic map, sector data, and warping logic. | `star_system_grid_manager.gd` |
| `Stations/` | 3D space station entities and docking management. | `docking_manager.gd`, `space_station_entity.tscn` |
| `asteroid.tscn` | Physical asteroid objects. | N/A |

#### Technical Notes
- The `Outside` module represents the "real world" simulation that the OS applications interact with.
- `SpaceWorldManager` is the primary entry point for managing life-cycle of 3D objects.
- **Resource Refactoring**: Ship and system data (Rooms, Ducts, Damages, Celestial Bodies) are now strictly typed via `Resource` classes instead of `Dictionary` objects, improving sync reliability between the 3D simulation and OS applications.
