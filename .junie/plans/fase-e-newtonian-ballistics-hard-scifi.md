---
sessionId: session-260915-141146-3p3m
---

# Requirements

### Overview & Goals
In accordo con la visione delineata in `docs/GAME_SESSION_SCENARIO_AND_ROADMAP.md` e con le preferenze espresse dall'utente, questo piano sviluppa il blocco a **priorità massima** della roadmap: **Fase E (Fisica Balistica Newtoniana & Combattimento Hard Sci-Fi)**.

L'obiettivo è trasformare il combattimento spaziale di *Dark Nova Rogue Squadron* in una simulazione hard sci-fi autentica basata sul principio di relatività galileiana:
1. I proiettili fisici non viaggiano a velocità assoluta slegata dalla nave, ma ereditano per intero il vettore di moto dell'astronave da cui vengono sparati ($\vec{v}_{proj} = \vec{v}_{ship} + \hat{d}_{aim} \times v_{muzzle}$).
2. Il danno da impatto cinetico scala in tempo reale in funzione della velocità relativa di collisione col bersaglio: un colpo frontale contro un bersaglio in avvicinamento infligge danni devastanti per via dell'alta energia cinetica relativa, mentre colpire un bersaglio in fuga nella stessa direzione attutisce il danno.
3. Il Lead Indicator (mirino predittivo) e l'HUD di telemetria dell'applicazione `Weapons` tengono conto della velocità relativa $\vec{v}_{target} - \vec{v}_{ship}$, offrendo al soldato/artigliere dati affidabili di ingaggio e stima del moltiplicatore di impatto.

### Scope
- **In Scope**:
  - Modello cinematico galileiano centralizzato in `SpaceWorldManager` per tutti i proiettili fisici (mitragliatrice pesante, cannoni, torpedini).
  - Tracciamento della velocità lineare della nave (`Spaceship.linear_velocity`) e delle navi nemiche (`EnemyShipAI.velocity`).
  - Calcolo del danno cinetico d'impatto scalato: $\text{danno\_effettivo} = \text{danno\_base} \times \frac{|\vec{v}_{rel}|}{v_{muzzle}}$ per colpi inferti e subiti.
  - Correzione del calcolo del punto di lead in `WeaponsApp` sul vettore di chiusura relativo $(\vec{v}_{target} - \vec{v}_{ship})$.
  - Telemetria diegetica del fattore di impatto stimato e della velocità di chiusura in `WeaponsTrajectoryHUD`.
  - Suite di collaudo automatizzata in `tests/gut/test_ballistics_newtonian.gd`.
- **Out of Scope (fasi successive della roadmap)**:
  - Generazione procedurale di sistemi stellari e applicazione `System Discover` (Fase B).
  - Contratti della stazione e borsa merci X4 in `StationHub` (Fase C).
  - Meccanica di scavenging con braccio manipolatore per il `ServiceDrone` (Fase D).
  - Contrattacchi cyber dell'IA nemica tramite iniezione file (Fase F).

### User Stories
- **Come Soldato / Cannoniere alla plancia Weapons**, voglio che i miei colpi tengano conto del vettore di navigazione della nave madre, in modo da coordinarmi col Pilota per effettuare passaggi di tiro ad alta velocità ed infliggere il massimo danno cinetico all'impatto.
- **Come Cannoniere**, voglio che il mirino di anticipo (Lead Indicator) calcoli esattamente la deviazione basandosi sulla velocità relativa tra la mia nave e il bersaglio, così da non sbagliare il tiro mentre manovriamo.
- **Come Pilota**, voglio che le mie manovre evasive (es. accelerare via dal caccia ostile che mi insegue) riducano l'energia d'impatto e il danno dei colpi nemici che colpiscono la poppa.

### Functional Requirements
- **FR-E1 (Somma Vettoriale al Lancio)**: Al momento dello sparo in `request_fire_weapon()`, il proiettile deve ricevere una velocità iniziale $\vec{v}_{proj} = \vec{v}_{ship} + (\hat{d}_{aim} \times v_{muzzle})$. Se la torretta spara in avanti mentre la nave viaggia a $20\,\text{m/s}$ e la volata è $100\,\text{m/s}$, il proiettile deve viaggiare a $120\,\text{m/s}$. Se spara all'indietro, viaggia a $80\,\text{m/s}$.
- **FR-E2 (Tracciamento e Collisione Proiettili)**: `SpaceWorldManager` aggiorna in tempo reale la posizione dei proiettili attivi e calcola l'intersezione con il raggio di collisione delle entità bersaglio (`EnemyShipAI`).
- **FR-E3 (Danno Cinetico Scalato)**: All'impatto contro un'entità (o contro la corvetta per proiettili nemici), il danno base viene moltiplicato per $\frac{|\vec{v}_{rel}|}{v_{muzzle}}$, con un clamp di sicurezza per il gameplay ($[0.25, 2.5]$).
- **FR-E4 (Lead Indicator Dinamico)**: Il calcolo dell'anticipo in `WeaponsApp` deve usare il vettore di velocità relativa del bersaglio rispetto alla corvetta $(\vec{v}_{target} - \vec{v}_{ship})$ moltiplicato per il tempo stimato di intercettazione.
- **FR-E5 (HUD Telemetria Balistica)**: `WeaponsTrajectoryHUD` deve visualizzare la velocità di chiusura ($\Delta v$) e la percentuale di impatto attesa (es. `IMP. PWR: 120%`).

### Non-Functional Requirements
- **Zero Overhead Fisico Eccessivo**: La simulazione centralizzata vettoriale evita l'allocazione pesante di dozzine di nodi fisici complessi per colpi a raffica, preservando 60+ FPS anche con raffiche sostenute.
- **Precisione Numerica**: Tutti i calcoli balistici utilizzano la precisione floating point nativa di Godot 4.x in coordinate vettoriali 3D cartesiane.

# Technical Design

### Current Implementation
- **Astronave Giocatore (`Outside/spaceship.gd`)**:
  - Estende `RigidBody3D`. Espone `linear_velocity: Vector3` calcolato dalla simulazione fisica di Godot, oltre a `linear_input` e controlli di manovra.
- **IA Nemica (`Outside/Combat/enemy_ship_ai.gd`)**:
  - Estende `CharacterBody3D` / `Node3D`. Espone `velocity: Vector3` calcolato a ogni frame durante il pattern di volo (`SWARM_CHASE`, `EVASIVE_STRAFE`, `TORPEDO_BOMBING`). Espone `take_damage(amount, is_emp)`.
- **Coordinatore Spazio & Armi (`Outside/space_world_manager.gd`)**:
  - Dispone del metodo `request_fire_weapon(weapon_type, target_id, manual_aim_dir)`. Attualmente emette il segnale `weapon_fired`, ma non istanzia proiettili fisici per il giocatore né calcola la somma vettoriale newtoniana.
  - Per i nemici dispone di `spawn_incoming_projectile()`, memorizzando proiettili in un array `incoming_projectiles` con posizione e velocità fissa.
- **Plancia Armeria (`Applications/Weapons/weapons_app.gd` & `WeaponsTrajectoryHUD`)**:
  - Calcola l'anticipo `lead_world_pos = t_pos + t_vel * flight_time` ignorando la velocità propria della nave madre (`Spaceship.linear_velocity`), rendendo il mirino impreciso durante traslazioni o manovre a velocità sostenuta.

### Key Decisions
1. **Simulatore Vettoriale Centralizzato in `SpaceWorldManager`**:
   - *Scelta*: Gestire l'array di proiettili e la cinematica newtoniana all'interno di `SpaceWorldManager` (struttura analoga e unificata a `incoming_projectiles`).
   - *Motivazione*: Massime prestazioni computazionali, assenza di leak di nodi 3D, perfetta sincronizzazione con lo stato globale di rete e con le query dei sistemi di bordo (`ShieldMatrix`, `SensorsApp`, `WeaponsApp`).
2. **Normalizzazione del Fattore Cinetico con Clamp Sicuro**:
   - *Scelta*: Fattore cinetico $K = \text{clampf}\left(\frac{|\vec{v}_{rel}|}{v_{muzzle}}, 0.25, 2.5\right)$.
   - *Motivazione*: Impedisce sia danni nulli/negativi in condizioni estreme (se il bersaglio vola via velocissimo, il proiettile fa comunque almeno il 25% del danno nominale), sia picchi incontrollati di one-shot in caso di impatti supersonici accidentali.
3. **Calcolo Relativo Galileiano del Lead Indicator**:
   - *Scelta*: Calcolare il tempo di volo e l'anticipo considerando $\vec{v}_{closing} = (\vec{v}_{ship} + \hat{d}_{aim} \times v_{muzzle}) - \vec{v}_{target}$.
   - *Motivazione*: Il reticolo predittivo rimane stabile e perfettamente allineato indipendentemente dalla velocità e direzione di crociera della nave del giocatore.

### Proposed Changes

#### 1. Estensione di `Outside/space_world_manager.gd`
- Aggiunta tabella profili balistici delle munizioni:
  ```gdscript
  const BALLISTIC_PROFILES := {
      "HEAVY_MG": {"muzzle_speed": 180.0, "base_damage": 12.0, "radius": 2.5, "lifetime": 3.0, "is_kinetic": true},
      "HEAVY_CANNON": {"muzzle_speed": 120.0, "base_damage": 65.0, "radius": 3.5, "lifetime": 4.0, "is_kinetic": true},
      "MISSILE": {"muzzle_speed": 75.0, "base_damage": 140.0, "radius": 4.0, "lifetime": 6.0, "is_kinetic": false},
      "PROBE": {"muzzle_speed": 35.0, "base_damage": 0.0, "radius": 2.0, "lifetime": 15.0, "is_kinetic": false}
  }
  ```
- Struttura `active_ballistic_projectiles: Array[Dictionary]`:
  - Traccia ogni proiettile: `id`, `weapon_type`, `position`, `velocity`, `muzzle_speed`, `base_damage`, `is_kinetic`, `source ("PLAYER" / "ENEMY")`, `target_id`, `lifetime`.
- Aggiornamento in `_process` / `_physics_process`:
  - `proj.position += proj.velocity * delta`
  - Controllo collisioni verso `CombatDirector.active_enemies` (per colpi player) e verso la corvetta giocatore (per colpi nemici).
  - All'impatto:
    $$\vec{v}_{rel} = \vec{v}_{proj} - \vec{v}_{target}$$
    $$\text{dmg} = \text{base\_damage} \times (\text{clampf}(|\vec{v}_{rel}| / v_{muzzle}, 0.25, 2.5) \text{ if is\_kinetic else } 1.0)$$
    Chiamata diretta di applicazione danno su bersaglio (`take_damage`).

#### 2. Integrazione con `Applications/Weapons/weapons_app.gd`
- Recupero della velocità corvetta: `var ship_vel: Vector3 = SpaceWorldManager.get_spaceship_velocity()`.
- Ricalcolo predittivo:
  ```gdscript
  var rel_target_vel: Vector3 = target_vel - ship_vel
  var flight_time: float = target_dist / muzzle_speed
  var lead_world_pos: Vector3 = target_pos + rel_target_vel * flight_time
  ```
- Calcolo telemetrico della velocità di chiusura e percentuale di impatto attesa trasmessa a `WeaponsTrajectoryHUD`.

#### 3. Estensione di `Applications/Weapons/weapons_trajectory_hud.gd`
- Aggiunta indicatore telemetrico:
  - `closing_speed: float` ($\text{m/s}$)
  - `expected_kinetic_pct: float` (es. `115%`)
  - Rendering diegetico nel box bersaglio o nell'angolo dell'HUD mirino: `IMP. PWR: 115% (Δv: +24 m/s)`.

### Architecture Diagram

```mermaid
graph TD
    Spaceship[Spaceship RigidBody3D<br/>linear_velocity] -->|v_ship| SWM[SpaceWorldManager]
    WeaponsApp[WeaponsApp<br/>manual_aim_dir & ammo_type] -->|request_fire_weapon| SWM
    
    subgraph Ballistic Simulation in SWM
        CalcInit[v_proj = v_ship + d_aim * v_muzzle]
        SimLoop[Step position += v_proj * delta]
        SweepCheck[Check collision radius]
        CalcDamage[v_rel = v_proj - v_target<br/>damage = base * |v_rel| / v_muzzle]
        
        CalcInit --> SimLoop
        SimLoop --> SweepCheck
        SweepCheck --> CalcDamage
    end
    
    CalcDamage -->|take_damage| Enemy[EnemyShipAI<br/>velocity]
    CalcDamage -->|process_hit| PlayerDmg[SystemicDamageHandler]
    
    SWM -->|closing_speed & ship_vel| WeaponsApp
    WeaponsApp -->|rel_lead & kinetic_pct| HUD[WeaponsTrajectoryHUD]
```

### File Structure
- **Modificati**:
  - `Outside/space_world_manager.gd`: spawn proiettili newtoniani, aggiornamento vettoriale, calcolo danno relativo, getter velocità nave.
  - `Applications/Weapons/weapons_app.gd`: lead indicator con velocità relativa $(\vec{v}_{target} - \vec{v}_{ship})$ e telemetria balistica.
  - `Applications/Weapons/weapons_trajectory_hud.gd`: visualizzazione diegetica della velocità di chiusura e del fattore di impatto stimato.
  - `Outside/Combat/combat_director.gd`: allineamento del fuoco nemico con velocità del tiratore e passaggio a `SpaceWorldManager`.
- **Creati**:
  - `tests/gut/test_ballistics_newtonian.gd`: suite completa di test GUT per balistica vettoriale e danno cinetico.

### Risks
- **Rischio Tunneling su Proiettili Veloci**: A framerate bassi, un proiettile ad alta velocità potrebbe oltrepassare il bersaglio tra due frame.
  - *Mitigazione*: Controllo della collisione tramite segment-sweep (da `prev_position` a `new_position`) calcolando la distanza minima dal segmento al centro del bersaglio rispetto al raggio di collisione.
- **Disallineamento Segnali Rete / Solo**: La corvetta o i caccia potrebbero subire correzioni di posizione istantanee.
  - *Mitigazione*: La cinematica è risolta a livello autoritativo sull'host/solo all'interno di `SpaceWorldManager`, con posizioni sincronizzate via telemetria standard.

# Testing

### Validation Approach
La validazione del sistema balistico newtoniano e del danno cinetico relativo viene condotta tramite suite automatizzata in Godot con il framework GUT (`tests/gut/test_ballistics_newtonian.gd`), supportata da test di integrazione visiva tra `WeaponsApp` e `WeaponsTrajectoryHUD`.

### Key Scenarios

#### Scenario 1: Addizione Vettoriale di Volata (Relatività Galileiana)
- **Setup**: Nave posizionata a $(0, 0, 0)$ con velocità lineare $\vec{v}_{ship} = (0, 0, -20)$ (moto in avanti verso $-Z$).
- **Azione**:
  1. Fuoco in avanti ($\hat{d}_{aim} = (0, 0, -1)$ con munizione a velocità $100\,\text{m/s}$).
  2. Fuoco all'indietro ($\hat{d}_{aim} = (0, 0, 1)$).
  3. Fuoco laterale verso destra ($\hat{d}_{aim} = (1, 0, 0)$).
- **Esito Atteso**:
  1. Velocità proiettile frontale $= (0, 0, -120)$ ($|\vec{v}_{proj}| = 120\,\text{m/s}$).
  2. Velocità proiettile posteriore $= (0, 0, 80)$ ($|\vec{v}_{proj}| = 80\,\text{m/s}$).
  3. Velocità proiettile laterale $= (100, 0, -20)$ ($|\vec{v}_{proj}| = \sqrt{100^2 + 20^2} \approx 101.98\,\text{m/s}$).

#### Scenario 2: Danno Cinetico Relativo all'Impatto (Head-On vs Tail-Chase)
- **Setup**: Bersaglio `EnemyShipAI` con 100 HP di scafo, munizione con danno base 50 e velocità di volata $100\,\text{m/s}$. Proiettile sparato a $100\,\text{m/s}$ verso $-Z$.
- **Test 2A (Head-On / Frontale)**:
  - Bersaglio vola incontro al proiettile a $\vec{v}_{target} = (0, 0, 50)$ (verso $+Z$).
  - Velocità relativa: $\vec{v}_{rel} = (0, 0, -100) - (0, 0, 50) = (0, 0, -150) \implies |\vec{v}_{rel}| = 150\,\text{m/s}$.
  - Moltiplicatore cinetico: $150 / 100 = 1.5$.
  - Danno applicato $= 50 \times 1.5 = 75.0$.
- **Test 2B (Tail-Chase / Bersaglio in fuga)**:
  - Bersaglio fugge nella stessa direzione a $\vec{v}_{target} = (0, 0, -50)$ (verso $-Z$).
  - Velocità relativa: $\vec{v}_{rel} = (0, 0, -100) - (0, 0, -50) = (0, 0, -50) \implies |\vec{v}_{rel}| = 50\,\text{m/s}$.
  - Moltiplicatore cinetico: $50 / 100 = 0.5$.
  - Danno applicato $= 50 \times 0.5 = 25.0$.

#### Scenario 3: Precisione del Lead Indicator Relativo
- **Setup**: Bersaglio a 100m di distanza in moto a $(10, 0, 0)$. Nave madre che trasla lateralmente a $(10, 0, 0)$.
- **Esito Atteso**: Poiché bersaglio e corvetta volano alla stessa velocità nella stessa direzione, il moto relativo laterale è $0$. Il Lead Indicator predittivo calcolato su $(\vec{v}_{target} - \vec{v}_{ship})$ deve coincidere con il centro del bersaglio (nessun offset laterale fasullo).

### Edge Cases
- **Velocità Bersaglio Pari o Superiore al Proiettile in Fuga**: Il clamp minimo a $0.25$ assicura che il colpo non infligga $0$ o danno negativo.
- **Spari a Nave Ferma**: A $\vec{v}_{ship} = (0, 0, 0)$, la velocità del proiettile e il danno contro un bersaglio statico coincidono esattamente con i valori nominali ($v_{muzzle}$ e danno base).
- **Proiettili Non Cinetici (Es. EMP / Sonde / Siluri Energetici)**: Il flag `is_kinetic: false` disattiva la moltiplicazione cinetica per preservare il comportamento standard di testate o sonde esplosive.

### Test Changes
- **Nuovo File**: `tests/gut/test_ballistics_newtonian.gd` contenente:
  - `test_galilean_velocity_addition()`
  - `test_relative_kinetic_damage_head_on_vs_tail_chase()`
  - `test_enemy_incoming_projectile_relative_damage()`
  - `test_weapons_lead_indicator_relative_velocity()`
  - `test_ballistic_projectile_segment_sweep_collision()`

# Delivery Steps

### ✓ Step 1: Cinematica Vettoriale Galileiana e Spawn Proiettili in SpaceWorldManager
I proiettili fisici sparati dalla nave giocatrice e dalle navi nemiche ereditano fedelmente il vettore velocità del rispettivo vettore di lancio secondo la relatività galileiana.
- Definire in `SpaceWorldManager` i profili balistici delle munizioni (velocità di volata $v_{muzzle}$, raggio di collisione, ciclo di vita massimo) per mitragliatrice pesante, cannone e siluri.
- Estendere `request_fire_weapon()` in `Outside/space_world_manager.gd` per estrarre la velocità lineare istantanea della corvetta (`Spaceship.linear_velocity`) e sommarla vettorialmente al vettore di volata: $\vec{v}_{proj} = \vec{v}_{ship} + (\hat{d}_{aim} \times v_{muzzle})$.
- Implementare il buffer di simulazione dei proiettili attivi con aggiornamento della traiettoria frame per frame e rimozione temporale o fuori portata.
- Integrare la medesima cinematica newtoniana nel generatore di proiettili nemici di `CombatDirector` e `EnemyShipAI`.

### ✓ Step 2: Calcolo del Danno Cinetico Relativo all'Impatto
I danni inferti dalle collisioni balistiche scalano proporzionalmente in base alla velocità relativa reale tra il proiettile e il bersaglio al momento dell'impatto.
- Implementare in `SpaceWorldManager` il rilevamento delle collisioni tra proiettili attivi e i bersagli ostili (`CombatDirector.active_enemies`) tramite sweep vettoriale continuo.
- Calcolare il vettore velocità relativo d'impatto $\vec{v}_{rel} = \vec{v}_{proj} - \vec{v}_{target}$ e ricavare il moltiplicatore cinetico: $\text{mult} = \text{clampf}(|\vec{v}_{rel}| / v_{muzzle}, 0.25, 2.5)$.
- Applicare il danno scalato a `EnemyShipAI.take_damage()` con notifica telemetrica dell'impatto e del moltiplicatore cinetico applicato.
- Estendere la risoluzione dei colpi nemici su `SystemicDamageHandler` applicando il medesimo moltiplicatore $\vec{v}_{rel} = \vec{v}_{enemy\_proj} - \vec{v}_{player}$.

### ✓ Step 3: Lead Indicator Relativo e Telemetria Cinetica in WeaponsApp & HUD
Il reticolo predittivo del mirino e l'HUD riflettono accuratamente la velocità di chiusura relativa della nave madre e del bersaglio con indicatori diegetici di potenza d'impatto.
- Aggiornare in `Applications/Weapons/weapons_app.gd` l'algoritmo di calcolo del punto di anticipo (Lead Indicator) sostituendo il moto assoluto con il moto relativo: $\vec{v}_{rel\_target} = \vec{v}_{target} - \vec{v}_{ship}$.
- Trasmettere al componente `WeaponsTrajectoryHUD` la velocità di chiusura telemetrica $\Delta v$ e il fattore di impatto stimato (es. `IMP. PWR: 135%` in avvicinamento frontale vs `65%` in fuga).
- Visualizzare sull'HUD del mirino il marker di anticipo calibrato e il feedback visivo al momento dell'impatto critico ad alta velocità cinetica.

### ✓ Step 4: Suite di Test GUT e Validazione del Dogfight Hard Sci-Fi
Tutti i comportamenti balistici newtoniani e di scala del danno sono verificati e protetti da regressioni tramite suite automatizzata GUT.
- Creare la suite di test GUT `tests/gut/test_ballistics_newtonian.gd` che verifica:
  - Addizione vettoriale $\vec{v}_{proj} = \vec{v}_{ship} + \hat{d}_{aim} \times v_{muzzle}$ sia in volo concorde sia discorde.
  - Variazione del danno inferto a un caccia nemico che accelera frontalmente (danno maggiorato) rispetto a uno in allontanamento (danno attutito).
  - Impatto newtoniano dei colpi nemici sulla corvetta giocatrice in funzione della manovra evasiva.
  - Accuratezza del Lead Indicator in presenza di moto traslatorio e rollio della corvetta.
- Verificare l'esecuzione pulita e senza errori dei test con Godot in modalità headless.