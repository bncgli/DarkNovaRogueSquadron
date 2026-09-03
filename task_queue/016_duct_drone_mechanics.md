# TASK-028: Duct Drone Blueprint Alignment, Radar Key & Emergency Recovery

## Descrizione
Allineamento del Duct Drone ai parametri definiti nella `ShipBlueprint` (posizione di spawn e stanza di ricarica), riassegnazione del tasto radar a `R`, rimozione del pulsante manuale di reset e introduzione del timer di recupero automatico a batteria esaurita.

## Obiettivi
- Inizializzare la posizione e l'orientamento di spawn del drone leggendoli direttamente da `ShipBlueprint.drone_spawn_pos` e `ShipBlueprint.drone_spawn_heading`.
- Vincolare la ricarica della batteria alla presenza del drone all'interno del rettangolo della stanza `ShipBlueprint.recharge_room_id`.
- Assegnare il tasto rapido da tastiera `R` all'impulso radar / scansione.
- Rimuovere il pulsante "Ritorno alla Base" (`BtnReset`) dall'interfaccia dell'applicazione.
- Implementare un timer di sicurezza di 60 secondi quando la batteria si azzera fuori dalla stanza di ricarica, con teletrasporto automatico alla base allo scadere.

## Criteri di Accettazione
- [x] **Spawn da ShipBlueprint**:
  - [x] All'apertura dell'app o al caricamento della nave, la posizione iniziale `drone_pos` e l'angolo `drone_heading` corrispondono ai valori impostati nella blueprint della nave attiva.
- [x] **Ricarica nella Stanza Designata**:
  - [x] La batteria del robottino si ricarica esclusivamente quando `drone_pos` si trova all'interno della stanza specificata da `recharge_room_id`. Al di fuori di essa, nessuna ricarica passiva deve verificarsi.
- [x] **Mappatura Tasto Radar 'R'**:
  - [x] La pressione del tasto `R` (KEY_R) aziona l'impulso radar (`_on_scan_pulse_pressed()`) emettendo l'onda di scansione per rilevare anomalie e danni.
- [x] **Rimozione Pulsante Reset**:
  - [x] Il pulsante `BtnReset` è rimosso dal layout visivo di `duct_drone_app.tscn` e non più collegato a scorciatoie di reset manuale.
- [x] **Timer Recupero Batteria Esaurita (1 Minuto)**:
  - [x] Se `drone_battery <= 0.0` e il drone non è nella stanza di ricarica:
    - I comandi di movimento vengono bloccati.
    - Si avvia un countdown diegetico di 60 secondi mostrato nell'HUD ("RECUPERO EMERGENZA IN: XX s").
    - Allo scadere del minuto, il drone viene riportato automaticamente alla posizione di spawn nella stanza di ricarica con ripristino graduale della carica.

## Dettagli Tecnici
- **File coinvolti**:
  - `Applications/DuctDrone/duct_drone_app.tscn`: Rimozione nodo `%BtnReset`.
  - `Applications/DuctDrone/duct_drone_app.gd`:
    - Metodo `_ready()` / `_init_drone_state()`: lettura parametri da `SpaceWorldManager.get_ship_blueprint()`.
    - Metodo `_input(event)`: rimappatura di `KEY_R` per invocare `_on_scan_pulse_pressed()`.
    - Metodo `_process(delta)`: verifica contenimento `recharge_room.rect.has_point(drone_pos)` per la ricarica.
    - Logica timer emergenza `emergency_recovery_timer: float` (60.0s) gestito nel frame loop o con `Timer`.
  - `Outside/Managers/DuctDroneManager.gd` & `Outside/space_world_manager.gd`: Sincronizzazione dello stato di spawn e ricarica con la blueprint.

## Step by Step Implementation
1. **Rimozione Pulsante Reset in `Applications/DuctDrone/duct_drone_app.tscn`**:
   - Rimuovere il nodo `%BtnReset` dal contenitore dei pulsanti.
2. **Lettura Spawn e Orientamento da Blueprint in `Applications/DuctDrone/duct_drone_app.gd`**:
   - Nel metodo `_ready()` e nelle funzioni di reset/inizializzazione:
     - Recuperare la blueprint corrente: `var bp := SpaceWorldManager.get_ship_blueprint() if SpaceWorldManager else null`.
     - Se `bp`: impostare `drone_pos = bp.get_drone_spawn_pos()` e `drone_heading = bp.drone_spawn_heading`.
3. **Logica di Ricarica Stanza in `Applications/DuctDrone/duct_drone_app.gd`**:
   - Sostituire il controllo `drone_pos.distance_to(initial_drone_pos) < 30.0` (linea ~968) con:
     - Recuperare la stanza di ricarica: `var recharge_room = bp.get_room_by_id(bp.recharge_room_id)` se valida.
     - Verificare `if recharge_room and recharge_room.rect.has_point(drone_pos): drone_battery = minf(100.0, drone_battery + 8.0 * delta)`.
4. **Mappatura Tasto 'R' al Radar in `Applications/DuctDrone/duct_drone_app.gd`**:
   - Nella funzione `_input(event: InputEvent)` (linee ~630-633):
     - Rimuovere la chiamata a `_on_reset_pressed()`.
     - Impostare: `if event.pressed and (event.keycode == KEY_R or event.physical_keycode == KEY_R): _on_scan_pulse_pressed(); get_viewport().set_input_as_handled()`.
5. **Implementazione Timer Recupero Emergenza in `Applications/DuctDrone/duct_drone_app.gd`**:
   - Aggiungere variabili `var emergency_recovery_time_left: float = 0.0` e `var is_in_emergency_recovery: bool = false`.
   - In `_process(delta: float)`:
     - Se `drone_battery <= 0.0` e non si è nella stanza di ricarica:
       - Se `!is_in_emergency_recovery`: attivare `is_in_emergency_recovery = true`, `emergency_recovery_time_left = 60.0`.
       - Decrementare `emergency_recovery_time_left -= delta`.
       - Aggiornare label HUD con il conto alla rovescia.
       - Quando `emergency_recovery_time_left <= 0.0`:
         - Riportare `drone_pos = bp.get_drone_spawn_pos()`, `drone_battery = 25.0`, `is_in_emergency_recovery = false`.
         - Notificare l'avvenuto recupero diegetico.
     - Se la batteria viene ricaricata o il drone entra nella stanza, resettare `is_in_emergency_recovery = false`.
