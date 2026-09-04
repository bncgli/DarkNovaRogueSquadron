# TASK-039: PodInfo Vitals Engine, Spatial Bridge Microphone & Physiological Crew States

## Descrizione
Ristrutturazione dell'applicazione `PodInfo` per monitorare i 4 parametri vitali fondamentali dell'equipaggio (Ossigeno %, Temperatura °C, Pressione barometrica kPa, Accelerazione gravitazionale G), calcolati in tempo reale dai sistemi di bordo (`LifeSupportApp`, `FlightControl` e dinamica nave). Implementazione del sistema di simulazione audio diegetico ("Microfono Virtuale in Plancia"): un ricevitore acustico posizionato nel ponte di comando che propaga i rumori della nave (impatti balistici, scariche di cortocircuito nei compartimenti, ronzio servomotori del Duct Drone nei condotti adiacenti) con volume e attenuazione spaziale proporzionale alla distanza. Gestione completa degli effetti sensoriali/fisiologici del personaggio (rantoli/boccheggio per asfissia, colpi/urla per ustione, battito denti per ipotermia, blackout/redout a schermo e collasso vitale con GameOver).

## Obiettivi
- Monitorare costantemente la fisiologia dell'equipaggio su 4 indicatori vitali collegati alla simulazione:
  1. **Ossigeno (O2)**
  2. **Temperatura (°C)**
  3. **Pressione (kPa)**
  4. **Accelerazione G**
- Implementare il modulo audio diegetico a microfono virtuale fisso nella sala comando:
  - Generare suoni direzionali per gli eventi di bordo: impatti e penetrazioni scafo, scariche elettriche di corti circuiti, passaggio del Duct Drone nei condotti vicini.
  - Applicare attenuazione esponenziale e filtro passa-basso diegetico in base alla distanza dell'evento dalla sala comandi.
- Implementare la macchina a stati fisiologici con feedback sonori del personaggio ed effetti a schermo:
  - **Ossigeno basso / zero**: il personaggio rantola e boccheggia $\rightarrow$ oscuramento progressivo schermo (Blackout) $\rightarrow$ decesso e GameOver.
  - **Temperatura alta (>45°C)**: respiro affannoso $\rightarrow$ agitazione/scalpiccio $\rightarrow$ urla strazianti $\rightarrow$ morte per ustione e GameOver.
  - **Temperatura bassa (<10°C)**: battito di denti $\rightarrow$ torpore $\rightarrow$ Blackout e GameOver.
  - **G alti positivi (>5G)**: Blackout visivo totale $\rightarrow$ arresto cardiaco e GameOver.
  - **G negativi (<-2G)**: Redout visivo totale (schermo velato di rosso sangue) $\rightarrow$ rottura vascolare, urla e GameOver.

## Criteri di Accettazione
- [x] **Lettura Reale dei 4 Parametri Vitali**:
  - [x] Nessuna oscillazione causale dummy slegata dalla nave: i valori rispecchiano le condizioni fisiche della sala comando e le accelerazioni di manovra.
- [x] **Microfono Virtuale & Audio Spazializzato**:
  - [x] Gli eventi distanti dalla plancia (es. corti in sala motori o urti a poppa) sono riprodotti ovattati e con volume ridotto; gli eventi vicini sono nitidi e ad alto volume.
  - [x] Il movimento del Duct Drone nei pressi della sala comandi emette il ronzio meccanico proporzionale alla vicinanza.
- [x] **Effetti di Fuori Scala Parametri**:
  - [x] Asfissia: Audio respiro rantolante, fade a nero progressivo, GameOver al 100% di danno asfissia.
  - [x] Ipertermia/Incendio: Ansito $\rightarrow$ rantolo $\rightarrow$ urla $\rightarrow$ GameOver da fuoco.
  - [x] Ipotermia: Suono battito denti $\rightarrow$ assideramento $\rightarrow$ GameOver.
  - [x] Forza G estrema: Overlay Blackout (nero) o Redout (rosso vivo) con modulazione alpha legata all'accelerazione $G_z$.

## Dettagli Tecnici
- **File coinvolti**:
  - `Applications/PodInfo/pod_info_app.tscn`: Display parametri vitali, indicatori di allarme fisiologico e player audio FX.
  - `Applications/PodInfo/pod_info_app.gd`:
    - Ristrutturazione logica: ricezione stato da `LifeSupportApp` e `cruise_drive_controller.gd`.
    - Gestione player sonori `AudioStreamPlayer` / `AudioStreamPlayer2D` per rumori ambientali, impatti, corti, drone e voce del personaggio.
  - `Scenes/Desktop/` o overlay globale: Shader/CanvasLayer per filtri Blackout e Redout a schermo intero.
  - `Outside/space_world_manager.gd`: Bus eventi fisici di bordo (`damage_occurred`, `drone_moved`, `g_force_updated`).

## Step by Step Implementation
1. **Collegamento Parametri Vitali Reali in `Applications/PodInfo/pod_info_app.gd`**:
   - In `_simulate_vital_signs(delta: float)` (linee 55-75):
     - Rimuovere le oscillazioni casuali `randf_range`.
     - Recuperare le condizioni della stanza di comando: `var atmo = SpaceWorldManager.get_bridge_atmo_state()`.
     - Impostare `oxygen_value = atmo.o2_pct`, `temp_value = atmo.temperature_c`, `pressure_value = atmo.pressure_kpa`.
     - Recuperare l'accelerazione $G$ da `SpaceWorldManager.get_ship_g_force()`.
2. **Implementazione Microfono Virtuale in Plancia in `Applications/PodInfo/pod_info_app.gd`**:
   - Connettere i segnali globali degli eventi di bordo da `SpaceWorldManager`:
     - `ship_damage_taken(pos: Vector2, type: String)`
     - `electrical_short_sparked(pos: Vector2)`
     - `duct_drone_position_updated(pos: Vector2)`
   - Metodo `_play_spatial_ship_sound(event_pos: Vector2, sfx_stream: AudioStream, base_vol: float = 0.0)`:
     - Calcolare la distanza $d = \text{bridge\_pos.distance\_to}(event\_pos)$.
     - Calcolare attenuazione $A = 1.0 / (1.0 + 0.01 \cdot d)$ e impostare il volume in dB: $\text{vol\_db} = \text{base\_vol} + 20.0 \cdot \log_{10}(A)$.
     - Se $d > 150.0$: applicare filtro diegetico Low-Pass a 800 Hz (suono ovattato attraverso le paratie).
3. **Macchina a Stati Fisiologica in `Applications/PodInfo/pod_info_app.gd`**:
   - In `_process(delta: float)`:
     - **Stato Asfissia** (`oxygen_value < 12.0` o `pressure_value < 20.0`):
       - Riprodurre audio rantolo/soffocamento con frequenza crescente.
       - Aumentare intensità `blackout_intensity += delta * 0.15`.
       - Se `blackout_intensity >= 1.0`: innescare `_trigger_game_over("DECESSO PER ASFISSIA")`.
     - **Stato Ipertermia** (`temp_value > 45.0`):
       - Riprodurre ansito affannoso; se `> 65.0` riprodurre urla disperate di bruciatura.
       - Se `temp_value > 80.0`: innescare `_trigger_game_over("DECESSO PER COMBUSTIONE TERMICA")`.
     - **Stato Ipotermia** (`temp_value < 10.0`):
       - Riprodurre loop battito di denti; aumentare `blackout_intensity`.
       - Se `temp_value <= 0.0`: innescare `_trigger_game_over("DECESSO PER IPOTERMIA")`.
4. **Gestione Effetti G-Force (Blackout & Redout) in `Applications/PodInfo/pod_info_app.gd`**:
   - Se `g_force_value > 4.5`:
     - `blackout_intensity = clampf((g_force_value - 4.5) / 2.5, 0.0, 1.0)`
     - Aggiornare overlay oscuramento schermo. Se `g_force_value > 7.0` per più di 3 secondi $\rightarrow$ GameOver.
   - Se `g_force_value < -1.5`:
     - `redout_intensity = clampf((-g_force_value - 1.5) / 2.0, 0.0, 1.0)`
     - Aggiornare overlay rosso sangue a schermo. Se `g_force_value < -3.5` per più di 2 secondi $\rightarrow$ GameOver.
5. **Creazione / Aggiornamento Overlay Schermo Blackout/Redout**:
   - Aggiungere un nodo `ColorRect` a schermo intero nel Desktop o CanvasLayer principale collegato alle proprietà `blackout_intensity` (Colore Nero, alpha) e `redout_intensity` (Colore Rosso puro, alpha).
