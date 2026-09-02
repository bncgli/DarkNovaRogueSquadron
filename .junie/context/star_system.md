# Star System & Grid

The game takes place in the **Dark Nova Helios System**, managed by `StarSystemGridManager`.

## Grid Mechanics
- **Sector Size**: 100,000 km per side.
- **Coordinates**: Vector3i (X, Y, Z).
- **Navigation**:
  - **Cruise**: Sub-light travel within or between adjacent sectors. Standard speed is 500 km/s.
  - **Hyperdrive**: Fast transit between distant sectors. ETA is roughly 4.5s per sector.

## Celestial Bodies
The system contains several predefined bodies:
- **Helios Nova (STAR)**: The central star. Provides solar energy.
- **Vulcanus (PLANET)**: Rocky volcanic planet.
- **Terra Nova Prime (PLANET)**: Habitable planet.
- **Selene Secundus (MOON)**: Mining moon of Terra Nova.
- **Valkyrie (STATION)**: Primary orbital hub and starting point.
- **Kronos Titan (GAS GIANT)**: Giant with hydrogen rings.
- **Aetheris (GAS GIANT)**: Ice giant.

## Visibility & Environmental Effects
- **Visibility Ranges**: Different ranges for different types of bodies (e.g., Stars are visible from 40 sectors, Stations from 4).
- **Occlusion & Blackout**: Planets can block sunlight, causing solar panels to lose efficiency and affecting ambient lighting.

## Data Structures (Resource-based)
- `StarSystemData`: Main resource containing the system configuration.
- `SectorData`: Resource defining a specific sector's properties and hazards.
- `CelestialBodyData`: Resource defining planets, stars, and stations.
- `EnvironmentalHazardData`: Resource for hazards like asteroid belts or radiation zones.
