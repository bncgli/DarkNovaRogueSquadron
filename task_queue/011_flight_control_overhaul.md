# TASK-023: Flight Control System & Cruise Propulsion Overhaul

## Descrizione
Rifacimento dei controlli di velocità, gestione dell'inerzia della nave, rimozione comandi obsoleti e correzione completa dei sistemi di propulsione di crociera e allineamento/attivazione dell'Hyperdrive.

## Obiettivi
- Sostituire il pulsante di selezione velocità ciclica con tasti dedicati `R` (incremento moltiplicatore fino a 2.0x) e `F` (decremento moltiplicatore fino a 0.5x).
- Rimuovere il pulsante "Reset Position" sia dall'interfaccia che dalla logica applicativa.
- Convertire il pulsante "Spegni Motori" nel controllo diegetico "Toggle Inerzia" (smorzamento inerziale attivo di default).
- Risolvere i problemi della propulsione di crociera (lettura potenza MW da `ShipBlueprint`, rotazione effettiva della nave per allineamento Hyperdrive, esecuzione transito di settore con attivazione Hyperdrive).

## Criteri di Accettazione
- [x] **Regolazione Dinamica Velocità (Tasti R / F)**:
  - [x] Rimozione del pulsante `SpeedModeButton` dall'interfaccia.
  - [x] Pressione del tasto `R`: Incrementa il moltiplicatore di velocità `_speed_multiplier` con un incremento graduale (es. +0.1x o +0.25x) fino a un massimo di `2.0x`.
  - [x] Pressione del tasto `F`: Decrementa il moltiplicatore di velocità fino a un minimo di `0.5x`.
  - [x] La UI di telemetria deve mostrare il moltiplicatore attuale in tempo reale.
- [x] **Rimozione Reset Position**:
  - [x] Il pulsante `ResetButton` è rimosso da `flight_control_app.tscn` e le relative funzioni dismesse da `flight_control_app.gd`.
- [x] **Toggle Inerzia (Inertia Dampening)**:
  - [x] Sostituzione del pulsante `StopButton` con il pulsante `InertiaToggleButton` (stato visivo On/Off).
  - [x] Con Inerzia ON (default): il rilascio dei comandi applica la decelerazione standard fermando la nave.
  - [x] Con Inerzia OFF: la nave conserva la velocità lineare e la direzione vettoriale senza decelerazione passiva (deriva newtoniana).
- [x] **Propulsione di Crociera & Ship Blueprint Power**:
  - [x] La potenza per le bobine di crociera (`cruise_coils_power_mw`) viene letta dinamicamente dai generatori/stanze attive di categoria `propulsion` e `reactor` definite in `ShipBlueprint` (e sincronizzate con `PowerGridApp`).
- [x] **Allineamento Vettore Hyperdrive**:
  - [x] La pressione di "Allinea Vettore Hyperdrive" (`align_to_hyperdrive_vector`) ruota fisicamente il nodo `Spaceship` (yaw/pitch) verso la direzione calcolata della rotta del settore target in `StarSystemGridManager`.
- [x] **Attivazione Hyperdrive**:
  - [x] La pressione di "Attiva Hyperdrive" (`engage_hyperdrive`) esegue la transizione di settore (`StarSystemGridManager.engage_hyperdrive_transit`), aggiornando le coordinate del settore corrente, rigenerando l'ambiente in `SpaceWorldManager` e svuotando la rotta attiva con relativo feedback sonoro/visivo.

## Dettagli Tecnici
- **File coinvolti**:
  - `Applications/FlightControl/flight_control_app.tscn`: Riorganizzazione pulsanti inferiori (rimozione `ResetButton`, `SpeedModeButton`, inserimento `InertiaToggleButton`).
  - `Applications/FlightControl/flight_control_app.gd`:
    - Gestione input tastiera `KEY_R` e `KEY_F` in `_input(event)`.
    - Variabile `_speed_multiplier` delimitata nel range `[0.5, 2.0]`.
    - Variabile `is_inertia_enabled: bool = true` e relative chiamate a `SpaceWorldManager` / `Spaceship`.
    - Metodo `align_to_hyperdrive_vector()` (linee 650-672): orientamento del `basis` / `rotation` della nave.
    - Metodo `engage_hyperdrive()` (linee 674-696): chiamata a `StarSystemGridManager.engage_hyperdrive_transit(target_coords)`.
  - `Outside/ShipSystems/cruise_drive_controller.gd`: Collegamento della potenza richiesta ai dati effettivi di `ShipBlueprint`.
  - `Outside/spaceship.gd`: Supporto per il flag di smorzamento inerziale (`inertia_dampening_active`).

## Step by Step Implementation
1. **Aggiornamento Layout UI in `Applications/FlightControl/flight_control_app.tscn`**:
   - Rimuovere il nodo `%ResetButton`.
   - Rimuovere il nodo `%SpeedModeButton`.
   - Rinominare `%StopButton` in `%InertiaToggleButton` (o aggiornare il testo in "INERZIA: ON" con colore verde).
2. **Logica Velocità e Inerzia in `Applications/FlightControl/flight_control_app.gd`**:
   - Rimuovere i riferimenti a `reset_button` e `speed_mode_button`.
   - Nel metodo `_input(event)` (o `_unhandled_input`):
     - Catturare la pressione di `KEY_R`: `_speed_multiplier = clampf(_speed_multiplier + 0.1, 0.5, 2.0)`.
     - Catturare la pressione di `KEY_F`: `_speed_multiplier = clampf(_speed_multiplier - 0.1, 0.5, 2.0)`.
     - Aggiornare il display di velocità/moltiplicatore nella telemetria HUD.
   - Aggiungere variabile `var is_inertia_enabled: bool = true`.
   - Connettere `%InertiaToggleButton.pressed` a `_on_inertia_toggle_pressed()`, che inverte lo stato, aggiorna il testo ("INERZIA: ON" / "INERZIA: OFF") e notifica `SpaceWorldManager` / `Spaceship`.
3. **Modifica Fisica Navale in `Outside/spaceship.gd`**:
   - Aggiungere variabile esportata o flag `var inertia_dampening: bool = true`.
   - In `_physics_process(delta)`: Se `input_linear == Vector3.ZERO`, applicare la decelerazione/attrito lineare solo se `inertia_dampening == true`. Se `false`, la velocità `linear_velocity` non viene azzerata né decelerata.
4. **Integrazione Potenza Crociera da `ShipBlueprint` in `Outside/ShipSystems/cruise_drive_controller.gd`**:
   - Nel metodo `check_power_state()` o all'aggiornamento di rete:
     - Recuperare la `ShipBlueprint` corrente da `SpaceWorldManager.get_ship_blueprint()`.
     - Calcolare la potenza totale erogata dalle stanze attive associate alla propulsione (`propulsion` e `reactor`).
     - Assegnare tale valore a `cruise_coils_power_mw` tramite `set_cruise_coils_power()`.
5. **Correzione Rotazione Allineamento Hyperdrive in `Applications/FlightControl/flight_control_app.gd`**:
   - In `align_to_hyperdrive_vector()`:
     - Calcolare la direzione 3D desiderata partendo da `active_hyperdrive_route["course_vector"]`.
     - Ottenere il riferimento al nodo `Spaceship` da `SpaceWorldManager.get_spaceship()`.
     - Ruotare l'astronave impostando il `global_transform.basis` tramite `Basis.looking_at(course_dir, Vector3.UP)` o calcolando gli angoli di yaw/pitch necessari, azzerando le velocità angolari parassite.
6. **Esecuzione Transito Hyperdrive in `Applications/FlightControl/flight_control_app.gd` & `Outside/StarSystemGrid/StarSystemGridManager.gd`**:
   - In `engage_hyperdrive()`:
     - Verificare che la rotta sia valida e allineata (`is_hyperdrive_aligned()`).
     - Invocare `StarSystemGridManager.engage_hyperdrive_transit(target_coords)`.
     - Riposizionare l'astronave alle coordinate del nuovo settore in `SpaceWorldManager`, emettere notifiche diegetiche e svuotare la rotta di navigazione attiva.
