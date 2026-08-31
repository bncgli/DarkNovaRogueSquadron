### Economy Context Index

Handles the economic logic, Flux currency, and cargo management.

| File | Purpose | Critical Dependencies |
|------|---------|-----------------------|
| `cargo_manager.gd` | Autoload managing cargo capacity, mineral refining, and inventory. | `FluxEconomyManager` |
| `flux_economy_manager.gd` | Autoload managing Flux credits, transactions, and bounties. | `CargoManager` |

#### Technical Notes
- Both managers are registered as Autoloads (`CargoManager` and `FluxEconomyManager`).
- They handle the persistence and synchronization of player assets across the game.
