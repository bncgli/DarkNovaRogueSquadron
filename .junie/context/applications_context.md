### Applications Context Index

This directory contains the suite of applications for the GodotOS interface, representing the ship's operative consoles.

| File/Directory | Purpose | Critical Dependencies |
|----------------|---------|-----------------------|
| `Lobby/` | Matchmaking, ship/sector setup, and role selection. | `NetworkManager`, `StarSystemGridManager` |
| `FlightControl/` | Pilot interface for navigation, thrusters, and warp. | `spaceship.gd`, `StarSystemGridManager` |
| `PowerGrid/` | Engineer interface for room-based power distribution and grid balancing. | `ship_blueprint.gd` (Centralized room-based logic) |
| `ShieldMatrix/` | Deflector shield modulation and frequency management. | `spaceship.gd` |
| `Comms/` | Radio communications and frequency tuning. | `NetworkManager` |
| `DuctDrone/` | Internal repair drone control. | `ship_blueprint.gd` |
| `ServiceDrone/` | External EVA and mining drone control. | `ServiceDroneEntity` |
| `CargoBay/` | Inventory management, refining, and cargo storage. | `CargoManager`, `FluxEconomyManager` |
| `Diagnostics/` | Subsystem health and hull integrity monitoring. | `spaceship.gd` |
| `Sensors/` | Radar and spectrometry tracking. | `spaceship.gd` |
| `LifeSupport/` | O2/CO2, temperature, and biosensor management. | `spaceship.gd` |
| `Logbook/` | Mission logs and historical communications. | N/A |
| `StationHub/` | Station services (repairs, trading, missions). | `DockingManager`, `FluxEconomyManager` |
| `Terminal/` | Command line interface with GDScript shell commands. | `TerminalDriveManager`, `ShipDriveManager` |
| `Cams/` | Internal and external camera feed management. | N/A |
| `SystemMap/` | Solar system map and local navigation. | `StarSystemGridManager` |
| `FluxWallet/` | Economic status, Flux monitoring, and modifiers log. | `ship_blueprint.gd` |

#### Technical Notes
- Most applications are structured with a `.tscn` for the UI, a `.gd` for logic, and a `.tres` for application metadata in GodotOS.
- Application resources are stored in `res://Applications/` and can be installed into the ship's blueprint using the **Software Manager** (unified single-line layout for programs and passwords) in `ShipSublayerEditor`.
- The installation process automatically configures required `Ship Drive` files and passwords based on the `AppResource` definition.
- They communicate with the ship's backend through Autoloads or by directly referencing the `spaceship.gd` entity when present in the 3D scene.
