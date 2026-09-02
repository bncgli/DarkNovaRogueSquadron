# Dark Nova Rogue Squadron - Project Overview

## Core Concept
Dark Nova Rogue Squadron is a Godot-based game that simulates a fake operating system (GodotOS) interface where the player manages a spaceship, its systems, economy, and missions.

## Main Directories
- **Applications/**: Various "apps" within the fake OS (Terminal, Cams, FlightControl, PowerGrid, etc.).
- **Economy/**: Management of cargo, credits (FLUX), and subscriptions.
- **Gameplay/**: Specific gameplay modules like Mining.
- **Games/**: Minigames accessible within the OS (e.g., Godotris).
- **Outside/**: The 3D space environment, ship systems, combat, and stations.
- **Scenes/**: Core UI scenes, desktop, windows, and Autoloads.
- **addons/**: Custom Godot editor plugins (Ship Sublayer Editor, Star System Editor).

## Key Systems
- **OS Layer**: Handles windows, desktop, hotkeys, and application lifecycle.
- **Ship Layer (Outside)**: Handles 3D movement, combat, docking, and physical ship state.
- **Economy Layer**: Handles FLUX rating, debts, cargo logistics, and S-Net hacking.
- **Sublayer (Duct Drone)**: Internal maintenance and repair system within the ship's ducts.
- **Data Model**: Uses a Resource-based architecture for core systems (ShipBlueprint, StarSystemData, Cargo), ensuring consistency across all game layers and facilitating editor integration.

