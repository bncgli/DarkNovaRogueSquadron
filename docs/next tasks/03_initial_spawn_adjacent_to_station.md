# TASK: Posizionamento Iniziale della Nave Adiacente a Stazione Spaziale e Bivio Operativo

## 1. Obiettivo e Panoramica
Configurare la logica di inizializzazione e generazione del mondo di gioco all'interno di `SpaceWorldManager` e `StarSystemGridManager` affinché:
1. All'avvio della sessione di gioco, la corvetta venga posizionata in un settore spaziale immediatamente **adiacente ad una stazione spaziale orbitale**.
2. Venga presentato chiaramente all'equipaggio il **bivio operativo iniziale**:
   - Avvicinarsi ed eseguire l'attracco alla stazione spaziale adiacente (per accedere a commercio, missioni, acquisto programmi e riparazioni).
   - Oppure pianificare la rotta e viaggiare verso altri settori del sistema stellare (navigazione di crociera / Hyperdrive).

---

## 2. Riferimenti al Documento di Design (DARK_NOVA_FEATURES_DESIGN.md)
- **Sezione 2 (Diagramma Flusso Utente - Fase 4)**: *Posizionamento Iniziale & Scelta Rotta*.
- **Sezione 2.4 (Fase 4 - Posizionamento Iniziale, Navigazione e Stazione Spaziale)**:
  > - **Posizionamento Iniziale**: La nave parte e viene posizionata in una sezione/settore spaziale immediatamente **adiacente ad una stazione spaziale**.
  > - **Bivio Operativo dell'Equipaggio**: I giocatori possono decidere di dirigersi verso la stazione spaziale oppure partire verso altre sezioni del sistema stellare.

---

## 3. Specifiche Tecniche e Funzionali

### 3.1 Logica di Spawning e Posizionamento (`SpaceWorldManager` / `StarSystemGridManager`)
1. **Identificazione Stazione di Partenza**:
   - All'interno del `StarSystemData` attivo, individuare la stazione spaziale primaria/di partenza (es. `Stazione Orbitale Alpha`).
   - Determinare le coordinate di griglia del settore della stazione (`sector_coords_station`).
2. **Calcolo Settore Adiacente di Spawning**:
   - Posizionare la nave in un settore adiacente libero (distanza 1 casella di griglia, es. offset $+1$ su asse X o Y) o nell'area di avvicinamento perimetrale della stazione (es. a 1000–2500 metri dallo scalo portuale).
   - Orientare la nave verso il vettore della stazione, con telemetria visibile su *Flight Control*, *Sensors* e *Cams*.
3. **Notifica di Inizio Missione & Waypoint**:
   - Generare automaticamente un waypoint e segnale IFF identificativo per la stazione vicina sui radar/sensori.
   - Mostrare notifica diegetica di sistema: *"Posizionamento completato: Stazione Spaziale rilevata nel settore adiacente"*.

---

## 4. Standard Architetturali e Flusso Git
1. **Branch Git**:
   - `git checkout -b feature/InitialSpawnStationSector main`
2. **File Coinvolti**:
   - `Outside/SpaceWorld/space_world_manager.gd`
   - `Outside/StarSystemGrid/star_system_grid_manager.gd`
   - `Outside/StarSystemGrid/star_system_data.gd`
   - `Outside/Stations/station_manager.gd` (o equivalente)
   - `tests/test_initial_spawn_adjacent_station.gd`

---

## 5. Criteri di Accettazione e Test Headless
1. **Suite di Test (`tests/test_initial_spawn_adjacent_station.gd`)**:
   - Verifica che all'avvio della partita la posizione iniziale della nave sia calcolata adiacente a una stazione spaziale definita nel `StarSystemData`.
   - Verifica che la stazione spaziale sia rilevabile come bersaglio/contatto su sensori e radar.
   - Verifica che la distanza tra nave e stazione consenta sia l'immediato avvicinamento per docking sia la rotta di fuga verso altri quadranti.
2. **Chiusura Git**:
   - [ ] Test headless superati con successo.
   - [ ] Commit con messaggio: `feat(world): configure initial ship spawn adjacent to orbital space station`.
   - [ ] Merge su `main`.
