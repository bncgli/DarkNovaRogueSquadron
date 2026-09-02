# Scattered Enums and Static Data

## Centralized Enums (GlobalValues.gd)

Tutti i principali enum globali sono ora centralizzati in `Scenes/Autoloads/GlobalValues/global_values.gd`. È mandatorio utilizzare questi riferimenti invece di ridefinirli localmente.

| Enum Name | Description |
|-----------|-------------|
| `GlobalValues.AlarmLevel` | Ship alert levels (NORMAL, YELLOW_ALERT, RED_ALERT). |
| `GlobalValues.Quadrant` | Ship quadrants for shielding and damage (FORE, AFT, PORT, STARBOARD). |
| `GlobalValues.ShipClass` | Classification of vessels (CORVETTE, FRIGATE, etc.). |
| `GlobalValues.DeviceCategory` | Categories for electrical devices (COMMAND, PROPULSION, etc.). |
| `GlobalValues.FileType` | OS item types (FOLDER, TEXT_FILE, IMAGE). |

## Centralized Metadata (RoomDatabase.gd)

I metadati precedentemente sparsi nei manager sono stati spostati nel `RoomDatabase`.

| Metadata | Description |
|----------|-------------|
| `RoomDatabase.CAMERS_METADATA` | Configuration for the 6 ship cameras. |
| `RoomDatabase.DUCT_ROOMS` | Standard room definitions and properties. |

## Scattered Enums (Pending Centralization)

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

### Ship Metadata (RoomDatabase.gd)
- `CAMERAS_METADATA`: Configuration for the 6 ship cameras (Front, Rear, Left, Right, Top, Bottom).
- `DUCT_ROOMS`: Rectangles and properties defining the ship's internal rooms for the duct drone.

### OS Constants
- `DefaultValues.gd` handles wallpaper paths and UI scale.
