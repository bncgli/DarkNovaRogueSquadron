# TASK-032: ShieldMatrix Split UI & Directional Point-Defense Systems

## Descrizione
Riprogettazione e ricostruzione integrale dell'applicazione `ShieldMatrixApp`. L'interfaccia viene riorganizzata in due sezioni principali (sinistra e destra): a sinistra è collocato l'ologramma della nave con i 4 settori difensivi (Frontale, Laterale Sinistro / Babordo, Laterale Destro / Tribordo, Posteriore / Poppa); a destra è presente il pannello di gestione dinamica dei dispositivi di difesa di prossimità (Gatling Automatiche e Lanciatori Flack "Angel Hair"), con assegnazione selettiva della direzione di copertura e contrasto a specifiche minacce balistiche o missilistiche.

## Obiettivi
- Riorganizzare il layout di `ShieldMatrix` in una vista bipartita (Split View Sinistra / Destra).
- Mostrare a sinistra l'ologramma della corvetta con i 4 settori e i relativi archi/vettori di stato protettivo.
- Implementare a destra una lista dinamica ed estensibile di dispositivi difensivi installati:
  1. **Gatling Automatica (Point Defense Gun)**: distruzione cinetica a distanza di missili, razzi, mine spaziali e micro-asteroidi in avvicinamento nel settore assegnato.
  2. **Lanciatori Flack**: detonazione di contromisure a dispersione ("nuvola angel hair" / chaff) per accecare e deviare la guida di missili a testata autocercante / tracciamento radar.
- Consentire al giocatore di riassegnare in tempo reale il settore di copertura per ogni dispositivo (ciascun dispositivo protegge un solo settore alla volta).
- Predisporre l'architettura per l'aggiunta dinamica di futuri moduli di difesa (es. laser point-defense, generatori EMP di settore).

## Criteri di Accettazione
- [x] **Interfaccia Split a 2 Sezioni**:
  - [x] Sezione Sinistra: Visualizzatore olografico interattivo con nave centrale e indicatori dei 4 settori (Prua, Babordo, Tribordo, Poppa) e rispettivi carichi/dispositivi assegnati.
  - [x] Sezione Destra: Lista dinamica di schede/slot dei dispositivi di difesa attivi con controlli di assegnazione settore, stato munizioni e modalità operativa.
- [x] **Gestione Dinamica Dispositivi di Difesa**:
  - [x] Supporto a lista dati dinamica (Resource/Array) per i dispositivi montati.
  - [x] Possibilità per ogni dispositivo di selezionare il quadrante protetto tramite dropdown o click sui settori dell'ologramma.
- [x] **Comportamento Specifico dei Dispositivi**:
  - [x] **Gatling Automatica**: Intercetta e neutralizza minacce cinetiche (missili, razzi, mine, asteroidi) provenienti dal settore difeso.
  - [x] **Flack Launcher**: Emette la nube angel hair nel settore selezionato, azzerando l'aggancio dei missili a ricerca in arrivo.
- [x] **Vincolo Direzionale Monosettore**:
  - [x] Ogni singolo dispositivo difensivo può proteggere unicamente la direzione a cui è assegnato, lasciando scoperti gli altri settori se non presidiati da ulteriori apparati.

## Dettagli Tecnici
- **File coinvolti**:
  - `Applications/ShieldMatrix/shield_matrix_app.tscn`: Ricostruzione layout con `HSplitContainer` / `HBoxContainer`, pannello sinistro per ologramma e pannello destro con `VBoxContainer` a schede dinamiche (`DefenseDeviceCard`).
  - `Applications/ShieldMatrix/shield_matrix_app.gd`:
    - Ristrutturazione logica: array `defense_devices: Array[Dictionary]` (o `Array[DefenseDeviceData]`).
    - Metodi di gestione assegnazione: `assign_device_sector(device_id: String, sector_enum: int)`.
    - Metodo `_process_active_defenses(delta: float)`: verifica minacce in arrivo da `SpaceWorldManager.get_incoming_projectiles()`.
  - `Applications/ShieldMatrix/shield_matrix_hologram.gd`:
    - Aggiornamento disegno: visualizzazione delle icone/archi dei dispositivi attivi sul settore corrispondente (simboli per Gatling e Flack sui 4 lati).
  - `Outside/Combat/combat_director.gd` & `Outside/space_world_manager.gd`:
    - Filtraggio delle intercettazioni difensive in base all'angolo di ingresso del proiettile vs settore coperto dai dispositivi attivi della nave.

## Step by Step Implementation
1. **Ristrutturazione Layout UI in `Applications/ShieldMatrix/shield_matrix_app.tscn`**:
   - Creare un contenitore principale orizzontale (`HSplitContainer` o `HBoxContainer`).
   - Posizionare a sinistra il container ologramma contenente `%HologramCanvas` e indicatori di integrità dei 4 quadranti.
   - Posizionare a destra `%DefenseDevicesPanel` con `%DevicesScrollContainer` e `%DevicesListContainer` (VBoxContainer) per contenere le schede dei dispositivi.
2. **Definizione Struttura Dati Dispositivi in `Applications/ShieldMatrix/shield_matrix_app.gd`**:
   - Inserire l'enum dei settori: `enum DefenseSector { FORE = 0, PORT = 1, STARBOARD = 2, AFT = 3 }`.
   - Definire l'array dinamico `defense_devices: Array[Dictionary]`:
     - `{ "id": "gatling_1", "name": "Gatling Difesa Auto-1", "type": "GATLING", "sector": DefenseSector.FORE, "ammo": 800, "status": "READY", "cooldown": 0.0 }`
     - `{ "id": "flack_1", "name": "Lanciatore Flack Angel-Hair", "type": "FLACK", "sector": DefenseSector.AFT, "ammo": 16, "status": "READY", "cooldown": 0.0 }`
   - Creare funzione `register_defense_device(device_data: Dictionary) -> void` per consentire aggiunte dinamiche a runtime da blueprint o espansioni.
3. **Creazione Componente Scheda Dispositivo `defense_device_card.tscn` / `.gd`**:
   - Creare il widget per la lista destra: mostra nome dispositivo, tipo con icona dedicata, stato munizioni, barra cooldown e `OptionButton` per scegliere il settore (`Prua`, `Babordo`, `Tribordo`, `Poppa`).
   - Connettere il segnale di cambio settore a `ShieldMatrixApp._on_device_sector_changed(device_id, new_sector)`.
4. **Aggiornamento Rendering Olografico in `Applications/ShieldMatrix/shield_matrix_hologram.gd`**:
   - In `_draw()`:
     - Per ciascuno dei 4 archi di settore, scorrere i dispositivi assegnati a quel settore.
     - Disegnare marcatori diegetici specifici all'esterno dell'arco: icona proiettile/torretta per Gatling, icona nuvola/particellare per Flack.
5. **Logica di Intercettazione Automatica in `Applications/ShieldMatrix/shield_matrix_app.gd`**:
   - In `_process(delta: float)`:
     - Recuperare proiettili ostili in rotta di collisione da `SpaceWorldManager`.
     - Determinare il settore di provenienza dell'attacco (calcolo angolo relativo alla prua nave: -45°..+45° Fore, 45°..135° Starboard, 135°..-135° Aft, -135°..-45° Port).
     - Se il settore ha una **Gatling** attiva e il proiettile è missilistico/cinetico/asteroide: ingaggiare e distruggere a distanza decrementando munizioni.
     - Se il settore ha un modulo **Flack** e il proiettile è un missile a ricerca: innescare detonazione della cortina angel hair e deviare la rotta del missile.
