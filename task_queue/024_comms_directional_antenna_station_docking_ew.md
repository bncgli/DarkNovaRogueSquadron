# TASK-036: Comms Overhaul: Directional Antenna, Station Interaction & EW Drive Connection

## Descrizione
Ristrutturazione dell'applicazione `CommsApp`. Rimozione dei vecchi moduli di jamming globale e decriptazione passiva. L'interfaccia inferiore viene suddivisa in 2 settori dedicati: a sinistra il controllo dell'antenna radio direzionale (rotazione manuale o rotazione automatica con ricezione a corto raggio sgranata, e funzione di Lock su frequenza per inseguimento continuo); a destra il modulo interattivo di gestione delle frequenze agganciate, con menu di opzioni contestuali per stazioni spaziali (richiesta attracco, commercio, comunicazioni) e pulsante "Connect" per accedere all'Electronic Warfare / Drive della nave bersaglio se il segnale radio è sufficientemente potente e stabile.

## Obiettivi
- Rimuovere i controlli obsoleti di Jamming e Decripting cifrari dall'applicazione Comms.
- Dividere la metà inferiore della finestra in due settori funzionali distinti:
  1. **Settore Sinistro**: Antenna Direzionale (manopola azimutale manuale 0-360°, modalità auto-rotazione, tracking lock su frequenza).
  2. **Settore Destro**: Pannello di Ricezione & Interazione Frequenza (dialoghi/menu stazioni e link EW).
- Implementare il comportamento dell'antenna direzionale:
  - **Puntamento Manuale**: ricezione mirata ad alto guadagno e precisione nella direzione puntata.
  - **Rotazione Automatica**: l'antenna ruota continuamente a 360°, ma riceve solo segnali molto vicini e con rumore/bassa precisione.
  - **Frequency Lock**: l'antenna corregge automaticamente il proprio orientamento per mantenere agganciata la trasmissione selezionata mentre le navi manovrano.
- Integrare il menu interattivo quando si sintonizza una Stazione Spaziale (pulsanti "Richiedi Attracco", "Frequenza Emergenza", "Canale Mercantile").
- Introdurre il test di potenza segnale per la connessione EW: se la frequenza di una nave selezionata è sufficientemente forte e vicina, abilitare il tasto "Connect" per agganciare il Drive remoto tramite il modulo Hack Exploits.

## Criteri di Accettazione
- [ ] **Rimozione Jamming & Vecchio Decripting**:
  - [ ] Nessun residuo visivo o logico dei moduli Jammer e Decryption progress bar in `comms_app.tscn`/`.gd`.
- [ ] **Suddivisione Inferiore in 2 Settori**:
  - [ ] Sinistra: Controlli Antenna Direzionale (Azimut, Auto-Rotate, Frequency Lock).
  - [ ] Destra: Pannello Info Frequenza, Menu Stazione & EW Connect.
- [ ] **Meccanica Antenna Direzionale & Modalità Operative**:
  - [ ] In modalità manuale, solo i segnali compresi nel cono angolare (es. ±25°) dell'antenna sono visibili/udibili con chiarezza.
  - [ ] In auto-rotazione, l'antenna ruota autonomamente a velocità costante; il raggio di intercettazione è ridotto del 70% e presenta rumore di fondo.
  - [ ] Con Frequency Lock attivo, l'antenna ruota autonomamente per inseguire la direzione relativa del bersaglio in tempo reale.
- [ ] **Menu Interazione Stazioni Spaziali**:
  - [ ] Alla sintonizzazione con una stazione compare il menu dedicato per richiedere l'autorizzazione all'attracco (`StationHub`).
- [ ] **Abilitazione Connessione Drive EW su Segnale Potente**:
  - [ ] Il pulsante "Connect" si attiva solo quando la potenza del segnale della nave bersaglio supera la soglia di stabilità per l'intrusione informatica.

## Dettagli Tecnici
- **File coinvolti**:
  - `Applications/Comms/comms_app.tscn`: Riorganizzazione della metà inferiore in 2 pannelli (`DirectionalAntennaPanel` a sinistra e `FrequencyActionPanel` a destra); rimozione vecchi controlli.
  - `Applications/Comms/comms_app.gd`:
    - Variabili: `antenna_azimuth: float`, `is_auto_rotating: bool`, `is_freq_locked: bool`, `locked_signal_id: String`.
    - Metodo `_process(delta: float)`: aggiornamento rotazione antenna e calcolo potenza segnale direzionale: $P = P_0 \cdot \cos(\Delta \theta) / d^2$.
    - Metodo `_on_connect_drive_pressed()`: passaggio coordinate/connessione alla nuova suite Hack Exploits.
  - `Applications/StationHub/station_hub_app.gd` & `Outside/space_world_manager.gd`: Sincronizzazione segnali di attracco e ricezione stazioni.

## Step by Step Implementation
1. **Ristrutturazione UI in `Applications/Comms/comms_app.tscn`**:
   - Rimuovere nodi Jammer (`%JammerSwitch`, `%JammerPowerSlider`, `%JammerModeOption`, `%SpoofSignatureOption`) e Decryption (`%CipherPackageOption`, `%DecryptionProgressBar`, `%ExtractedKeyEdit`, `%BtnStartDecrypt`).
   - Creare `%BottomSplit (HBoxContainer)`:
     - `%AntennaSector (PanelContainer)`: Bussola/manopola azimutale antenna (`%AntennaHeadingSlider` o dial), pulsante `%BtnAutoRotate` (toggle), pulsante `%BtnFreqLock` (toggle) e label `%AntennaStatusLabel`.
     - `%SignalInteractionSector (PanelContainer)`: Etichetta segnale, pulsante `%BtnRequestDocking` (per stazioni), pulsanti opzioni contatto radio e pulsante `%BtnConnectDrive` ("🔗 CONNETTI A DRIVE BERSAGLIO").
2. **Implementazione Logica Antenna in `Applications/Comms/comms_app.gd`**:
   - Aggiungere variabili di stato:
     ```gdscript
     var antenna_azimuth_deg: float = 0.0 # 0..360 gradi
     var is_auto_rotating: bool = false
     var auto_rotate_speed: float = 45.0 # gradi/sec
     var is_frequency_locked: bool = false
     var locked_signal_id: String = ""
     ```
3. **Calcolo Ricezione Segnali in `_process(delta: float)` in `Applications/Comms/comms_app.gd`**:
   - Se `is_auto_rotating` e non `is_frequency_locked`:
     - `antenna_azimuth_deg = fmod(antenna_azimuth_deg + auto_rotate_speed * delta, 360.0)`
   - Se `is_frequency_locked` e `locked_signal_id != ""`:
     - Recuperare il bearing del trasmettitore da `SpaceWorldManager`: orientare gradualmente `antenna_azimuth_deg` verso il target bearing.
   - Per ciascun segnale radio:
     - Calcolare differenza angolare $\Delta \theta$ tra l'antenna e la direzione della sorgente.
     - Se `is_auto_rotating`: ricezione limitata a segnali molto vicini (< 800m) e con rapporto segnale/rumore degradato.
     - Se manuale/focalizzata: potenza piena se $|\Delta \theta| < 25^\circ$.
4. **Integrazione Menu Stazione Spaziale in `Applications/Comms/comms_app.gd`**:
   - Alla selezione di una frequenza di tipo `STATION`:
     - Mostrare `%BtnRequestDocking` e le opzioni di contatto della stazione.
     - Alla pressione di `%BtnRequestDocking`: emettere segnale `docking_clearance_requested(station_id)`.
5. **Logica di Abilitazione "Connect" per Hack Exploits in `Applications/Comms/comms_app.gd`**:
   - Per le frequenze di navi bersaglio (`SHIP` / `CORVETTE` / `DERELICT`):
     - Calcolare la stabilità della connessione radio: `var is_stable = signal_strength >= 0.75 and target_distance < 1200.0`.
     - Abilitare `%BtnConnectDrive.disabled = not is_stable`.
     - Al click di `%BtnConnectDrive`: lanciare o focalizzare il nuovo programma `HackExploitsApp` montando il drive della nave nemica sul Desktop.
