# System Relationships

## OS & Applications
- **Desktop/MainScene**: The shell that hosts all `FakeWindow` instances.
- **Applications**: Communicate with the core via Autoloads (e.g., `SpaceWorldManager` for Cams, `CargoManager` for CargoBay).
- **Terminal**: Acts as a command-line interface to interact with almost every system.

## Gameplay & Economy
- **Mining**: Produces minerals which are added to `CargoManager`.
- **CargoManager**: Used by `StationHub` and `CargoBay` app to manage inventory.
- **FluxEconomyManager**: Affects prices in `StationHub` based on FLUX rating.
- **S-Net Disks**: Found as cargo, can be hacked via `FluxEconomyManager` for rewards.

## Outside & Internal
- **SpaceWorldManager**: The bridge between the 3D world (`Outside`) and the OS UI.
- **ShipSublayer**: Defines the internal layout of the ship, used by the Duct Drone.
- **Duct Drone**: A sub-system controlled via `DuctDroneApp`, used to repair damages tracked by `SpaceWorldManager`.
- **Combat**: `CombatDirector` and `EnemyShipAI` interact with the player's spaceship in 3D.

## Autoload Interactions
- `FluxEconomyManager` can disable OS features (managed in `DefaultValues` or specific apps) if the player is insolvent.
- `SpaceWorldManager` emits signals that apps like `CamsApp` and `SensorsApp` listen to.
