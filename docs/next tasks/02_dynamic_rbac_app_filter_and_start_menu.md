# TASK: Caricamento Dinamico Programmi per Ruolo (Filtro RBAC) e Gestione Menu Start

## 1. Obiettivo e Panoramica
Implementare e consolidare il sistema diegetico di **Role-Based Access Control (RBAC)** per il caricamento delle applicazioni sulla corvetta stellare e la gestione dinamica del menu Start di GodotOS:
1. Durante la fase di Lobby/Offline, le applicazioni operative della nave non devono comparire nel menu Start.
2. All'avvio della partita (`start_mission()`), il menu Start e il desktop devono popolare solo ed esclusivamente i programmi autorizzati per il ruolo ricoperto dal giocatore locale, leggendo le app installate dalla `ShipBlueprint` attiva.
3. Rimuovere tempestivamente l'overlay `DisconnectedOverlay` ("Sistemi Offline") dalle applicazioni autorizzate all'avvio missione.
4. Ripristinare o pulire le applicazioni al termine della missione (`end_mission()`) o in caso di cambio ruolo a runtime.

---

## 2. Riferimenti al Documento di Design (DARK_NOVA_FEATURES_DESIGN.md)
- **Sezione 2 (Diagramma Flusso Utente - Fase 3)**: *Avvio Partita & Caricamento Programmi sulla Nave*.
- **Sezione 2.3 (Fase 3 - Avvio Partita e Caricamento Programmi)**:
  - **Pilota**: *Flight Control*, *Cams*, *System Map*.
  - **Ingegnere**: *Power Grid*, *Duct Drone*, *Life Support*, *Shield Matrix*.
  - **Soldato / Tattico**: *Cams*, *Weapons*, *Sensors*.
  - **Hacker**: *Duct Drone*, *Comms & EW*, *Diagnostics*, strumenti di cyber warfare.
  - **Capitano / Factotum / Solo Mode**: suite completa di tutti i programmi installati a bordo.
- **Sezione 3**: *Matrice dei Ruoli (RBAC - Role-Based Access Control)*.

---

## 3. Specifiche Tecniche e Funzionali

### 3.1 Gestione Menu Start e Taskbar (`Scenes/Desktop`, `Scenes/Taskbar`)
1. **Stato Lobby / Offline**:
   - Nel menu Start compaiono unicamente le utility locali del computer di bordo (es. *Lobby*, *Terminale*, *File Manager*, *Text Editor*, *Giochi*).
   - Nessuna applicazione dipendente da `SpaceWorldManager` o dalla nave (`ShipAppResource`) è visibile o avviabile prima del decollo.
2. **Evento Decollo (`start_mission()`)**:
   - `ShipSoftwareManager` / `GlobalValues` riceve l'evento di inizio missione e il ruolo del giocatore locale (`current_role`).
   - Il menu Start filtra l'array `installed_apps` di `ShipBlueprint` confrontando i ruoli consentiti (`allowed_roles` della risorsa `ShipAppResource`) con il ruolo del giocatore.
   - Popolamento dinamico delle sole voci di menu e icone pertinenti.
3. **Gestione Overlay Offline**:
   - All'avvio della missione, tutte le finestre delle app nave aperte ricevono la notifica di connessione e nascondono il nodo `%DisconnectedOverlay`.
4. **Fine Missione / Cambio Ruolo**:
   - All'invocazione di `end_mission()`, le finestre aperte mostrano nuovamente l'overlay "Sistemi Offline" e il menu Start rimuove le scorciatoie della nave.

---

## 4. Standard Architetturali e Flusso Git
1. **Branch Git**:
   - `git checkout -b feature/DynamicRBACStartMenu main`
2. **File Coinvolti**:
   - `Scenes/Desktop/` / `Scenes/Taskbar/` / Start Menu scripts
   - `Scenes/Autoloads/SoftwareManager/ship_software_manager.gd`
   - `Outside/ShipSublayer/ship_blueprint.gd`
   - `Outside/SpaceWorld/space_world_manager.gd`
   - `tests/test_rbac_start_menu_filter.gd`

---

## 5. Criteri di Accettazione e Test Headless
1. **Suite di Test (`tests/test_rbac_start_menu_filter.gd`)**:
   - Test stato Offline: verifica che nessuna app nave sia presente nel menu Start.
   - Test per ciascun ruolo all'avvio missione:
     - Pilota visualizza solo `Flight Control`, `Cams`, `System Map`.
     - Ingegnere visualizza solo `Power Grid`, `Duct Drone`, `Life Support`, `Shield Matrix`.
     - Soldato visualizza solo `Cams`, `Weapons`, `Sensors`.
     - Hacker visualizza solo `Duct Drone`, `Comms`, `Diagnostics`.
     - Capitano/Solo Mode visualizza tutte le app disponibili.
   - Test transizione fine missione (`end_mission()`): riattivazione overlay disconnesso e svuotamento menu Start.
2. **Chiusura Git**:
   - [ ] Test headless superati con successo.
   - [ ] Commit con messaggio: `feat(rbac): dynamic role-based app filtering and start menu management`.
   - [ ] Merge su `main`.
