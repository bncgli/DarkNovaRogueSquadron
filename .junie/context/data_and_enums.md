# Scattered Enums and Static Data

## Key Enums

| Enum Name | File | Description |
|-----------|------|-------------|
| `file_type_enum` | `Scenes/Desktop/desktop_folder.gd` | Defines if an OS item is a FOLDER, TEXT_FILE, or IMAGE. |
| `StateEnum` | `Scenes/Autoloads/CopyPaste Manager/copy_paste_manager.gd` | COPY or CUT state. |
| `DockingState` | `Outside/Stations/docking_manager.gd` | States of the ship docking process (UNDOCKED, CLEARANCE_REQUESTED, etc.). |
| `AIState` | `Outside/Combat/enemy_ship_ai.gd` | States for enemy AI (PATROL, SWARM_CHASE). |
| `ShipType` | `Outside/Combat/enemy_ship_ai.gd` | Types of enemy ships. |
| `AlarmLevel` | `Outside/Combat/systemic_damage_handler.gd` | Ship alert levels (NORMAL, YELLOW_ALERT, etc.). |
| `State` | `Outside/ShipSystems/cruise_drive_controller.gd` | Cruise drive states (IDLE, WARMUP, etc.). |
| `DisplayMode` | `Applications/Sensors/Components/radar_display.gd` | Radar display modes (POLAR_2D, CARTESIAN_GRID). |
| `WeaponGroup` | `Applications/Weapons/weapons_app.gd` | Categories of weapons (LASER, TORPEDO). |
| `Quadrant` | `Applications/ShieldMatrix/shield_matrix_app.gd` | Ship quadrants for shielding (FORE, AFT, etc.). |

## Static Data / Templates

### Ship Blueprints (`ShipBlueprint.gd`)
- `SHIP_CLASSES`: ["Corvette", "Frigate", "Destroyer", "Cruiser", "Freighter", "Science Vessel", "Scout", "Carrier", "Station"]
- `DEVICE_CATEGORIES`: ["command", "propulsion", "life_support", "engineering", "tactical", "sensors", "comms", "mainframe", "defense", "cargo", "service", "utility"]

### Item Templates (`CargoManager.gd`)
Contains a dictionary `item_templates` with predefined cargo items:
- `minerals_titanium`: Raw titanium.
- `alloys_durasteel`: High density alloys.
- `ammo_railgun`: Projectiles for heavy turrets.
- `energy_cell`: Plasma cells for power.
- `snet_snapshot_alpha`: Physical S-Net storage disk.
- `contraband_synth_narcotics`: Illegal cargo.

### Economy Constants (`FluxEconomyManager.gd`)
- `INSOLVENCY_FEATURES`: List of features disabled when FLUX rating is low.
- `subscriptions`: List of recurring costs (S-Net bandwidth, Port license, Insurance).

### Mining Resource Types (`MiningManager.gd`)
Contains `MINERAL_TYPES` dictionary:
- `heavy_metals`: Raw heavy metals.
- `rare_alloys`: Complex alloys.
- `crystals`: Galactic quartz.
- `water_ice`: Mineral water ice.
- `durasteel_ore`: Raw durasteel.

### Ship Metadata (`SpaceWorldManager.gd`)
- `CAMERAS_METADATA`: Configuration for the 6 ship cameras (Front, Rear, Left, Right, Top, Bottom).
- `DUCT_ROOMS`: Rectangles and properties defining the ship's internal rooms for the duct drone.

### OS Constants
- `DefaultValues.gd` handles wallpaper paths and UI scale.
