### Gameplay Context Index

Contains specialized gameplay mechanics logic.

| File | Purpose | Critical Dependencies |
|------|---------|-----------------------|
| `Mining/mining_manager.gd` | Manages mining sessions and resource drops. | `CargoManager`, `SpaceWorldManager` |

#### Technical Notes
- The mining system interfaces with the 3D world (`Outside/Mining`) to spawn mineral deposits and handle extraction lasers.
