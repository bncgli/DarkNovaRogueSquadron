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

## Resource-based Data Structures

Il progetto utilizza ora classi basate su `Resource` invece di `Dictionary` per le strutture dati principali, migliorando la tipizzazione e l'integrazione con l'ispettore di Godot.

| Class Name | Path | Description |
|------------|------|-------------|
| `ShipRoomData` | `Outside/ShipSublayer/ShipRoomData.gd` | Dati geometrici e logici di una stanza della nave. |
| `ShipDuctData` | `Outside/ShipSublayer/ShipDuctData.gd` | Definizione dei condotti di manutenzione. |
| `ShipDeviceData` | `Outside/ShipSublayer/ShipDeviceData.gd` | Dati di un dispositivo elettrico/logico. |
| `ShipDamageData` | `Outside/ShipSublayer/ShipDamageData.gd` | Definizione di una zona di danno strutturale. |
| `ShipFluxModifier` | `Outside/ShipSublayer/ShipFluxModifier.gd` | Modificatore economico applicato alla nave. |
| `ShipAppMetadata` | `Outside/ShipSublayer/ShipAppMetadata.gd` | Metadati per le applicazioni installate nel mainframe. |
| `ShipDriveFile` | `Outside/ShipSublayer/ShipDriveFile.gd` | Definizione di un file nel file system della nave. |
| `CameraMetadata` | `Outside/ShipSublayer/CameraMetadata.gd` | Metadati per le telecamere della nave. |
| `DuctRoomData` | `Outside/ShipSublayer/DuctRoomData.gd` | Dati semplificati delle stanze per la navigazione dei droni. |
| `CelestialBodyData` | `Outside/StarSystemGrid/CelestialBodyData.gd` | Dati di un corpo celeste (pianeti, stazioni). |
| `SectorData` | `Outside/StarSystemGrid/sector_data.gd` | Definizione di un settore nella griglia di sistema. |
| `EnvironmentalHazardData` | `Outside/StarSystemGrid/EnvironmentalHazardData.gd` | Pericoli ambientali nel settore. |
| `CargoItemData` | `Economy/CargoItemData.gd` | Dati di un item nell'inventario cargo. |
| `ShipDamageRuntimeState` | `Outside/ShipSublayer/ShipDamageRuntimeState.gd` | Stato di runtime dei danni. |

## Centralized Metadata (RoomDatabase.gd)

I metadati sono ora gestiti tramite array di oggetti Resource tipizzati.

| Metadata | Description |
|----------|-------------|
| `RoomDatabase.CAMERAS_METADATA` | Array di `CameraMetadata` per le 6 telecamere della nave. |
| `RoomDatabase.DUCT_ROOMS` | Array di `DuctRoomData` che definisce le stanze navigabili. |

## Scattered Enums (Pending Centralization)

## Static Data / Templates

### Ship Blueprints (`ShipBlueprint.gd`)
- `SHIP_CLASSES`: ["Corvette", "Frigate", "Destroyer", "Cruiser", "Freighter", "Science Vessel", "Scout", "Carrier", "Station"]
- `DEVICE_CATEGORIES`: ["command", "propulsion", "life_support", "engineering", "tactical", "sensors", "comms", "mainframe", "defense", "cargo", "service", "utility"]

### Item Templates (`CargoManager.gd`)
L'inventario (`cargo_items`) è un `Array[CargoItemData]`. I template rimangono definiti come `Dictionary` in `item_templates`, ma vengono convertiti in `CargoItemData` all'aggiunta nell'inventario.

- `minerals_titanium`: Titanio Grezzo.
- `alloys_durasteel`: Leghe Raffinate Durasteel.
- `ammo_railgun`: Munizioni Sabot Railgun.
- `energy_cell`: Celle Energetiche al Plasma.
- `snet_snapshot_alpha`: Array Snapshot Rete S-Net (fisico).
- `contraband_synth_narcotics`: Narcotici Sintetici Sigillati (Illegali).

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

### OS Constants
- `DefaultValues.gd` handles wallpaper paths and UI scale.
