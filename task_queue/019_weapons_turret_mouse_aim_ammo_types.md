# TASK-031: Weapons Turret Overhaul, Mouse Aiming & Ammo Types

## Descrizione
Ristrutturazione completa dell'applicazione `WeaponsApp` per trasformarla in una torretta d'ingaggio tattico reattiva, controllabile direttamente tramite movimento del mouse (con cattura/rilascio del puntatore su tasto Spazio), supporto a 4 classi di munizioni intercambiabili tramite tasti numerici (Mitragliatrice pesante, Cannone pesante, Missili a ricerca con lock, Sonde telemetriche) e HUD diegetico con calcolo delle traiettorie e lead indicator di puntamento.

## Obiettivi
- Convertire il controllo della torretta da slider manuali a tracciamento fluido tramite mouse (yaw e pitch).
- Implementare la cattura del puntatore del mouse nella finestra dell'applicazione premendo il tasto `Space` (Spazio).
- Mappare i tasti numerici (`1`, `2`, `3`, `4`) per la commutazione istantanea tra i tipi di proiettili/munizioni:
  1. **Mitragliatrice Pesante**: cadenza rapida, danno medio continuo, surriscaldamento moderato.
  2. **Cannone Pesante**: cadenza lenta, danno elevato per colpo, alto impatto e rinculo termico.
  3. **Missili**: richiedono aggancio bersaglio (puntamento continuo per X secondi o lock da radar/sensori).
  4. **Probe (Sonda)**: lancio sonda telemetrica per trasmissione dati a Sensors e Mappa Tattica.
- Disegnare nell'HUD della telecamera della torretta una UI con indicatore di traiettoria e lead marker (punto di anticipo ottimale per colpire il bersaglio in movimento).

## Criteri di Accettazione
- [x] **Controllo Telecamera Torretta via Mouse**:
  - [x] Il movimento del mouse modifica in tempo reale `manual_aim.x` (yaw: -45°..+45° o 360° torretta) e `manual_aim.y` (pitch: -30°..+60°), ruotando fluidamente la telecamera 3D associata al viewport.
- [x] **Cattura Mouse con Spazio**:
  - [x] La pressione del tasto `KEY_SPACE` all'interno della finestra commuta lo stato di cattura mouse (`Input.MOUSE_MODE_CAPTURED` vs `Input.MOUSE_MODE_VISIBLE`).
  - [x] La pressione di `Escape` o la deselezione della finestra rilascia automaticamente il puntatore.
- [x] **Selettore Munizioni 1/2/3/4**:
  - [x] Tasto `1`: Seleziona Mitragliatrice Pesante (alta frequenza di fuoco, consumo munizioni continuo, danno medio).
  - [x] Tasto `2`: Seleziona Cannone Pesante (colpi singoli potenti, cooldown prolungato, danno critico).
  - [x] Tasto `3`: Seleziona Missili (richiede puntamento sul target per 2.0s o lock radar attivo prima del lancio guidato).
  - [x] Tasto `4`: Seleziona Sonda (Probe) (rilascia sonda attiva per l'array sensori).
- [x] **HUD Traiettoria & Indicatore di Puntamento (Lead Indicator)**:
  - [x] L'HUD sovrapposto alla telecamera mostra il reticolo di mira centrale e un marker predittivo calcolato in base a distanza e velocità del bersaglio targettizzato.

## Dettagli Tecnici
- **File coinvolti**:
  - `Applications/Weapons/weapons_app.tscn`: Riorganizzazione viewport torretta, aggiunta overlay HUD traiettoria, indicatori munizioni 1/2/3/4 e stato mouse capture.
  - `Applications/Weapons/weapons_app.gd`:
    - `enum AmmoType { HEAVY_MG = 1, HEAVY_CANNON = 2, MISSILE = 3, PROBE = 4 }`
    - Metodo `_input(event: InputEvent)`: gestione `InputEventMouseMotion`, `KEY_SPACE`, `KEY_1`..`KEY_4`, `MOUSE_BUTTON_LEFT` per fuoco continuo o singolo.
    - Logica di lock missile: accumulatore tempo `missile_lock_timer: float` quando il reticolo è allineato entro un cono angolare dal bersaglio.
    - Metodo `_draw_trajectory_hud()` / calcolo `lead_position`.
  - `Applications/Weapons/weapons_radar_canvas.gd`: Aggiornamento sincronizzazione bersagli e lock.
  - `Outside/space_world_manager.gd`: Registrazione proiettili mitragliatrice, cannoni pesanti, missili e spawn sonda probe.

## Step by Step Implementation
1. **Aggiornamento Tipi Munizioni e Variabili in `Applications/Weapons/weapons_app.gd`**:
   - Nelle linee 16-20, sostituire l'enum `WeaponGroup` con `enum AmmoType { HEAVY_MG = 1, HEAVY_CANNON = 2, MISSILE = 3, PROBE = 4 }`.
   - Aggiungere le variabili di stato:
     - `var is_mouse_captured: bool = false`
     - `var mouse_sensitivity: float = 0.15`
     - `var missile_lock_time_required: float = 2.0`
     - `var missile_current_aim_time: float = 0.0`
     - `var is_missile_locked: bool = false`
2. **Gestione Cattura Mouse e Input da Tastiera in `Applications/Weapons/weapons_app.gd`**:
   - Nella funzione `_input(event: InputEvent)`:
     - Se `event is InputEventKey and event.pressed and not event.echo`:
       - Se `event.keycode == KEY_SPACE`: commutare `is_mouse_captured = not is_mouse_captured`; impostare `Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if is_mouse_captured else Input.MOUSE_MODE_VISIBLE`.
       - Se `event.keycode == KEY_1`: chiamare `_select_ammo_type(AmmoType.HEAVY_MG)`.
       - Se `event.keycode == KEY_2`: chiamare `_select_ammo_type(AmmoType.HEAVY_CANNON)`.
       - Se `event.keycode == KEY_3`: chiamare `_select_ammo_type(AmmoType.MISSILE)`.
       - Se `event.keycode == KEY_4`: chiamare `_select_ammo_type(AmmoType.PROBE)`.
     - Se `is_mouse_captured and event is InputEventMouseMotion`:
       - Aggiornare `manual_aim.x = clampf(manual_aim.x - event.relative.x * mouse_sensitivity, -60.0, 60.0)`.
       - Aggiornare `manual_aim.y = clampf(manual_aim.y - event.relative.y * mouse_sensitivity, -35.0, 45.0)`.
       - Invocare `_update_turret_camera_feed()`.
3. **Logica di Lock Missile e Traiettoria in `_process(delta: float)` in `Applications/Weapons/weapons_app.gd`**:
   - In `_process(delta: float)`:
     - Se `active_ammo_type == AmmoType.MISSILE`:
       - Verificare se il mirino `manual_aim` punta verso un bersaglio rilevato entro un delta angolare di 5.0°.
       - Se allineato o se `is_target_locked` da radar: incrementare `missile_current_aim_time += delta`.
       - Se `missile_current_aim_time >= missile_lock_time_required`: `is_missile_locked = true`.
       - Altrimenti se disallineato e senza lock radar: resettare `missile_current_aim_time = maxf(0.0, missile_current_aim_time - delta * 2.0)`, `is_missile_locked = false`.
4. **Comportamento di Fuoco Differenziato in `_on_fire_button_pressed()` in `Applications/Weapons/weapons_app.gd`**:
   - Riorganizzare il matching del fuoco:
     - `AmmoType.HEAVY_MG`: cooldown 0.08s, consumo munizioni 1 colpo, incremento calore +0.8%, trigger `SpaceWorldManager.request_fire_weapon("HEAVY_MG", ...)`.
     - `AmmoType.HEAVY_CANNON`: cooldown 1.4s, incremento calore +18.0%, trigger `SpaceWorldManager.request_fire_weapon("HEAVY_CANNON", ...)`.
     - `AmmoType.MISSILE`: verificare `if not is_missile_locked: return (avvisa HUD 'LOCK IN CORSO...')`; consumo 1 missile, trigger `SpaceWorldManager.request_fire_weapon("HOMING_MISSILE", selected_target_id, ...)`.
     - `AmmoType.PROBE`: verificare disponibilità sonde stiva/sistema; trigger spawn sonda telemetrica nello spazio verso la direzione `aim_dir`.
5. **Rendering HUD Traiettoria e Lead Indicator in `Applications/Weapons/weapons_app.gd`**:
   - Creare un nodo `TrajectoryHUD (Control)` sopra la telecamera torretta con script dedicato o funzione `_draw()` in un canvas sovrapposto.
   - Calcolare il punto di anticipo (Lead Indicator): data la velocità del proiettile dell'arma attiva e il vettore velocità del bersaglio targettizzato, calcolare la posizione prospettica 2D nel mirino e disegnare cerchio predittivo diegetico con linea di mira.
