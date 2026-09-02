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
- **Ereditarietà Mandatoria**: Tutte le applicazioni DEVONO ereditare da `BaseApp.gd` per la gestione standard di finestre, configurazione `.dat` e overlay di missione.
- **Struttura Risorse**: Strutturate con una scena UI (`.tscn`), un controller (`.gd`) che estende `BaseApp`, e una risorsa metadati (`AppResource.tres`).
- **Integrazione Software Manager**: Le risorse `AppResource` sono gestite dai Software Manager per l'installazione su `ShipBlueprint` o `Terminal Drive`.
- **Configurazione Runtime**: L'utilizzo dei file `.dat` è automatizzato tramite gli helper di `BaseApp` (`_apply_configuration`).
- **Filtro RBAC**: Lo Start Menu filtra automaticamente le app installate in base al ruolo del giocatore tramite `SpaceWorldManager.get_installed_apps_for_role()`.
