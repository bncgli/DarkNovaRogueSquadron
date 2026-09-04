# TASK-034: Duct Drone Fire Hazard, Sealed Room Barriers, Blueprint Spawn & Light Defaults

## Descrizione
Risoluzione e potenziamento delle meccaniche del `DuctDrone`: introduzione del nuovo tipo di danno da Incendio (`FIRE`), gestione delle barriere generate dalle stanze sigillate dal Supporto Vitale (il robottino non può entrare né uscire da una stanza con paratie stagne chiuse), correzione definitiva dello spawn iniziale vincolato alle coordinate di `ShipBlueprint` e avvio con luce spenta di default.

## Obiettivi
- Introdurre il tipo di danno Incendio (`FIRE` / `dmg_fire`) nel sistema di condotti e stanze, visualizzabile sul radar del drone e gestibile dal Life Support / drone.
- Implementare il blocco di transito delle stanze sigillate: se una stanza è sigillata (`is_sealed == true`), il duct drone non può oltrepassare le sue porte/perimetro (impossibile entrare dall'esterno o uscire dall'interno).
- Correggere il bug dello spawn del drone che si posizionava nel ponte di comando anziché nella posizione esatta definita nella `ShipBlueprint` (`drone_spawn_pos` e `drone_spawn_heading`).
- Impostare lo stato predefinito delle luci del drone su Spento (`lights_enabled = false`) all'avvio.

## Criteri di Accettazione
- [x] **Nuovo Tipo Danno Incendio (FIRE)**:
  - [x] Il sistema danni riconosce `FIRE` / `dmg_fire` con icona/animazione diegetica sul canvas e impatto termico sul compartimento.
- [x] **Barriere Stanze Sigillate**:
  - [x] Quando una stanza viene sigillata da `LifeSupportApp`, il contorno della stanza funge da collider invalicabile per il drone (nessun passaggio consentito attraverso condotti/porte della stanza bloccata).
  - [x] Se il drone si trova all'interno di una stanza al momento del sigillo, resta confinato all'interno fino al dissigillo.
- [x] **Spawn Corretto da Blueprint**:
  - [x] All'apertura dell'app, `drone_pos` e `drone_heading` vengono letti rigorosamente da `ShipBlueprint.drone_spawn_pos` e `ShipBlueprint.drone_spawn_heading`, senza fallback forzati a `(300, 80)` (ponte di comando).
- [x] **Luce Spenta di Default**:
  - [x] All'avvio dell'applicazione `lights_enabled` è `false` e il pulsante `%BtnLightsToggle` riflette lo stato spento senza consumo batteria passivo delle luci.

## Dettagli Tecnici
- **File coinvolti**:
  - `Applications/DuctDrone/duct_drone_app.gd`:
    - Metodo `_ready()` e `_init_drone_state()`: correzione inizializzazione coordinate da `ShipBlueprint`.
    - Variabile `lights_enabled`: impostazione predefinita su `false`.
    - Metodo `_can_move_to(target_pos: Vector2)` / `_resolve_collision(new_pos: Vector2)`: verifica intersezioni con i confini delle stanze aventi `is_sealed == true`.
    - Gestione riparazione/segnalazione danni da `FIRE`.
  - `Applications/DuctDrone/duct_map_canvas.gd`:
    - Rendering visivo delle fiamme e delle paratie stagne chiuse (bordo rosso/griglia di blocco).
  - `Outside/ShipSublayer/ship_blueprint.gd` & `Outside/ShipSublayer/ShipDamageData.gd`:
    - Costante o enum per il danno `DAMAGE_TYPE_FIRE`.

## Step by Step Implementation
1. **Correzione Default Luce e Variabili in `Applications/DuctDrone/duct_drone_app.gd`**:
   - Alla linea ~92, modificare:
     ```gdscript
     var lights_enabled: bool = false
     ```
   - In `_setup_ui_signals()` o `_update_telemetry_ui()`, sincronizzare il testo/stato di `%BtnLightsToggle` affinché mostri `LUCI: OFF`.
2. **Correzione Inizializzazione Coordinate Spawn da Blueprint in `Applications/DuctDrone/duct_drone_app.gd`**:
   - Nella funzione `_init_drone_state()` (linee ~280-310) e in `_ready()`:
     - Rimuovere l'assegnazione hardcoded `drone_pos = Vector2(300, 80)`.
     - Inserire il caricamento rigoroso:
       ```gdscript
       var bp := SpaceWorldManager.get_ship_blueprint() if SpaceWorldManager else null
       if bp:
           drone_pos = bp.get_drone_spawn_pos()
           drone_heading = bp.drone_spawn_heading
       else:
           drone_pos = Vector2(150, 150) # Neutro di emergenza
           drone_heading = -PI * 0.5
       ```
3. **Integrazione Tipo Danno Incendio in `Applications/DuctDrone/duct_drone_app.gd`**:
   - Nei metodi di parsing e categorizzazione danni (`_refresh_damages_list()`, `_get_damage_color()`):
     - Riconoscere il tipo `FIRE` / `dmg_fire`.
     - Assegnare colore arancio/fuoco acceso (`Color(1.0, 0.4, 0.1)`) e label "INCENDIO ATTIVO".
     - Se il drone dispone di kit estintore, consentire azione riparazione per soffocare il focolaio.
4. **Logica di Collisione per Stanze Sigillate in `Applications/DuctDrone/duct_drone_app.gd`**:
   - Nel metodo di controllo collisioni `_can_move_to(target_pos: Vector2) -> bool`:
     - Recuperare la lista delle stanze sigillate da `SpaceWorldManager` o dall'istanza `LifeSupportApp`.
     - Per ogni stanza con `is_sealed == true`:
       - Verificare se la posizione corrente del drone `drone_pos` è all'interno della stanza `r.rect.has_point(drone_pos)`:
         - Se il drone è **all'interno**: `target_pos` non può uscire da `r.rect` (se `!r.rect.has_point(target_pos)`, movimento bloccato).
         - Se il drone è **all'esterno**: `target_pos` non può entrare in `r.rect` (se `r.rect.has_point(target_pos)`, movimento bloccato).
5. **Aggiornamento Grafico Canvas in `Applications/DuctDrone/duct_map_canvas.gd`**:
   - Nella funzione `_draw()`:
     - Disegnare le stanze con `is_sealed == true` con un perimetro a tratteggio rosso spesso (segnaletica di pericolo/blocco stagna).
     - Disegnare le aree con danni da incendio con cerchi/particelle pulsanti color arancio fuoco.
