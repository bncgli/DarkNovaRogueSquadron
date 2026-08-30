# Documento di Design di Gioco, Flusso Utente e Feature Suite (GDD / FDD)
# Dark Nova: Rogue Squadron / GodotOS

> **Scopo del Documento**:
> Questo documento definisce l'esperienza di gioco complessiva di *Dark Nova: Rogue Squadron*, descrivendo in dettaglio:
> 1. **Il Flusso Lato Utente (User Journey)**: cosa succede dall'avvio del gioco, quali finestre si aprono, come interagiscono i giocatori e la gestione del desktop multi-finestra.
> 2. **Le Applicazioni Proprietarie Esistenti e la Matrice dei Ruoli (RBAC)**: funzionamento dettagliato di ogni applicazione sviluppata e responsabilità di ogni ruolo.
> 3. **Meccaniche di Settore (Sviluppate)**: descrizione delle meccaniche di navigazione interplanetaria, economia a FLUX e gameplay di settore già implementate.
> 4. **Le Nuove Feature da Creare (Roadmap)**: specifiche per le prossime espansioni e moduli pianificati.

---

## 1. Visione di Gioco ed Esperienza Utente

### 1.1 High Concept
*Dark Nova: Rogue Squadron* è un simulatore cooperativo asimmetrico e server-authoritative di gestione di una nave stellare. L'intera interfaccia di gioco è diegetica ed è rappresentata dal sistema operativo di bordo **GodotOS**. I giocatori non controllano un avatar 3D in prima persona, ma operano come ufficiali di plancia attraverso le finestre, i terminali, i file di configurazione `.dat` e i monitor telemetrici del proprio computer di bordo.
Il gioco unisce un'atmosfera ispirata alla serie *Firefly* (stile coloni spaziali e frontiera derelitta) a un tema satirico in stile Freemium-punk. Il gioco è un sandbox in cui i giocatori cooperano con il solo scopo di "continuare a volare" ed evitare la bancarotta o l'annientamento.

### 1.2 Filosofia dell'Interfaccia Multi-Finestra
- **Desktop Operativo Unificato**: Ogni sistema della nave (motori, telecamere, reattore, droni, sensori) è una finestra flottante ridimensionabile e riposizionabile.
- **Interdipendenza Assoluta**: Nessun giocatore può vincere da solo in multiplayer. Il Pilota ha bisogno dell'energia distribuita dall'Ingegnere, la nave deve essere protetta e difesa dal Soldato, mentre l'Hacker contrasta le minacce informatiche e manomette i sistemi nemici.
- **Tensione Diegetica**: Durante le emergenze (asteroidi, incendi nei condotti, falle nello scafo, sovraccarico reattore, attacco da parte di altre navi), i giocatori aprono e organizzano rapidamente molteplici finestre e comunicano via chat integrata o voce.

---

## 2. Flusso Lato Utente (User Flow & Step-by-Step Experience)

Di seguito viene illustrato il percorso completo dell'utente dall'avvio dell'applicazione fino alla conclusione di una missione.

```text
 ┌────────────────────────────────────────────────────────────────────────┐
 │ 1. BOOT & ACCESSO ALL'OS (GODOTOS)                                     │
 │    - Schermata di Boot Splash Dark Nova                                │
 │    - Caricamento Desktop GodotOS con Taskbar e Start Menu              │
 └───────────────────────────────────┬────────────────────────────────────┘
                                     │
                                     ▼
 ┌────────────────────────────────────────────────────────────────────────┐
 │ 2. FASE LOBBY, MATCHMAKING & CONFIGURAZIONE RISORSE CUSTOM             │
 │    - Il giocatore accede alla Lobby (Solo Mode vs Host vs Join Nave)   │
 │    - L'Host può caricare una risorsa Nave e una risorsa Sistema        │
 │      Stellare per avviare una nave custom in un setting custom         │
 │    - Selezione e sincronizzazione del Ruolo (Capitano, Pilota, ecc.)   │
 └───────────────────────────────────┬────────────────────────────────────┘
                                     │
                                     ▼ (Host/Solo avvia la partita)
 ┌────────────────────────────────────────────────────────────────────────┐
 │ 3. AVVIO PARTITA & CARICAMENTO PROGRAMMI SULLA NAVE                    │
 │    - NetworkManager & SpaceWorldManager inizializzano la simulazione   │
 │    - I programmi/applicazioni vengono caricati sulla nave in base ai   │
 │      ruoli assegnati a ciascun giocatore (Filtro Ruoli RBAC)           │
 │    - Rimozione overlay "Sistemi Offline" e notifica di decollo         │
 └───────────────────────────────────┬────────────────────────────────────┘
                                     │
                                     ▼
 ┌────────────────────────────────────────────────────────────────────────┐
 │ 4. POSIZIONAMENTO INIZIALE & SCELTA ROTTA                              │
 │    - La nave parte in una sezione/settore adiacente a una stazione     │
 │    - Scelta: raggiungere la Stazione Spaziale o viaggiare nel sistema  │
 └─────────────────┬───────────────────────────────────┬──────────────────┘
                   │                                   │
                   ▼ (Attracco a Stazione)             ▼ (Navigazione & Iperspazio)
 ┌───────────────────────────────────┐   ┌────────────────────────────────┐
 │ 5b. SERVIZI STAZIONE SPAZIALE     │   │ 5a. SYSTEM MAP & HYPERDRIVE    │
 │  - Commercio merci e logistica    │   │  - Uso di "System Map" per     │
 │  - Stipula di nuove missioni      │   │    pianificare la traiettoria  │
 │  - Acquisto nuovi programmi/app   │   │  - Flight Control attiva       │
 │  - Riparazioni e rifornimenti     │   │    l'Hyperdrive lungo la rotta │
 └─────────────────┬─────────────────┘   └────────────────┬───────────────┘
                   │                                      │
                   └───────────────────┬──────────────────┘
                                       │
                                       ▼
 ┌────────────────────────────────────────────────────────────────────────┐
 │ 6. GAMEPLAY LOOP OPERATIVO & GESTIONE EMERGENZE                        │
 │    - Cooperazione asimmetrica multiruolo in volo e combattimento       │
 │    - Gestione avarie, intrusioni informatiche e guasti a bordo         │
 └───────────────────────────────────┬────────────────────────────────────┘
                                     │
                                     ▼
 ┌────────────────────────────────────────────────────────────────────────┐
 │ 7. CONCLUSIONE MISSIONE / FINE SESSIONE                                │
 │    - Il gioco è un sandbox: salvataggio persistente e debriefing       │
 │    - Chiusura/Blocco automatico finestre nave con overlay Disconnesso  │
 │    - Schermata di debriefing e statistiche sessione in Lobby           │
 └────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Fase 1: Boot e Accesso all'OS
1. **Avvio**: I giocatori avviano il gioco ed eseguono l'accesso al sistema operativo diegetico **GodotOS**.
2. Viene visualizzata la sequenza di caricamento/boot splash a tema aerospaziale.
3. Si carica l'ambiente desktop **GodotOS** con sfondo spaziale, barra delle applicazioni (Taskbar) in basso, orologio di sistema, tray notifiche e icone sul desktop.

### 2.2 Fase 2: Accesso alla Lobby e Configurazione Nave/Sistema
1. All'avvio del desktop, il giocatore accede alla finestra **Lobby & Matchmaking** (aperta in automatico o richiamata dal menu Start / desktop).
2. **Modalità di avvio partita**:
   - **Gioca da Solo (Solo Mode)**: Il giocatore avvia la sessione offline e ottiene i permessi di tutti i ruoli simultaneamente.
   - **Modalità Host**: Il giocatore crea la stanza server-authoritative e ospita la partita.
   - **Unisciti a una Nave (Join Client)**: Il giocatore si unisce alla nave inserendo l'IP dell'host o selezionando la sessione.
3. **Caricamento Risorse Custom (Host)**:
   - L'host ha la facoltà di caricare una specifica **risorsa nave** (`ShipBlueprint`) e una **risorsa sistema stellare** (`StarSystemData`) per avviare una nave custom all'interno di un setting/sistema stellare custom.
4. **Selezione del Ruolo**:
   - Nella lista equipaggio, ciascun giocatore seleziona il proprio ruolo operativo (*Capitano*, *Pilota*, *Soldato*, *Ingegnere*, *Hacker*, *Factotum*).
   - La chat integrata di lobby consente la coordinazione dell'equipaggio prima della partenza.
5. **Comportamento delle applicazioni prima dell'avvio**:
   - Le applicazioni operative della nave non compaiono nel menu Start durante la fase di lobby, prevenendo aperture premature o errori; restano disponibili solo le utility di sistema locali.

### 2.3 Fase 3: Avvio Partita e Caricamento Programmi
1. L'Host (o il giocatore in Solo Mode) preme **"Avvia Missione"** per far partire la partita.
2. **Inizializzazione e Caricamento Programmi per Ruolo**:
   - L'evento globale di avvio viene propagato a tutti i client connessi.
   - `SpaceWorldManager` e il sottosistema di rete generano e attivano l'ambiente 3D del settore spaziale.
   - Ciascun giocatore carica i propri programmi/applicazioni sulla nave in base al proprio ruolo assegnato (Filtro Ruoli RBAC derivato dalla `ShipBlueprint`):
     - **Pilota**: *Flight Control*, *Cams*, *System Map* (visualizzazione rotta).
     - **Ingegnere**: *Power Grid*, *Duct Drone*, *Life Support*, *Shield Matrix*.
     - **Soldato / Tattico**: *Cams*, *Weapons*, *Sensors*.
     - **Hacker**: *Duct Drone*, *Comms & EW*, *Diagnostics*, strumenti di cyber warfare.
     - **Capitano / Factotum / Solo Mode**: suite completa di tutti i programmi installati a bordo.
   - Le finestre dei programmi rimuovono l'overlay *"Sistemi Offline"* e diventano pienamente operative con notifica di decollo completato.

### 2.4 Fase 4: Posizionamento Iniziale, Navigazione e Stazione Spaziale
1. **Posizionamento Iniziale**:
   - La nave parte e viene posizionata in una sezione/settore spaziale immediatamente **adiacente ad una stazione spaziale**.
2. **Bivio Operativo dell'Equipaggio**:
   - I giocatori possono decidere di dirigersi verso la stazione spaziale oppure partire verso altre sezioni del sistema stellare.
3. **Pianificazione Rotta e Hyperdrive (Fase 5a)**:
   - I giocatori possono utilizzare l'applicazione **"System Map"** per consultare la griglia del sistema e progettare la traiettoria di viaggio dell'**Hyperdrive** tra le sezioni/settori.
   - Una volta calcolata e impostata la rotta sulla System Map, l'applicazione **Flight Control** del Pilota aggancia il vettore e avvia l'**Hyperdrive** per eseguire il transito verso la destinazione.
4. **Accesso alla Stazione Spaziale (Fase 5b)**:
   - Se l'equipaggio decide di attraccare alla stazione spaziale adiacente (tramite procedura guidata su *Comms* o avvicinamento), i giocatori accedono ai servizi della stazione via GodotOS per:
     - **Commerciare merci e materiali** (compravendita, gestione stiva cargo e transazioni FLUX).
     - **Trovare e accettare nuove missioni/contratti** (sincronizzati con l'app *Logbook*).
     - **Acquistare nuovi programmi**, driver firmware e upgrade software per la nave.
     - **Eseguire riparazioni dello scafo**, manutenzione e rifornimento risorse.

### 2.5 Fase 5: Gestione dei File di Configurazione (.DAT), Sicurezza e Manomissione "Illegale" (Hackwarfare)
1. **Natura dei file `.dat` e Blocco Legale**:
   - I file `.dat` sono file di configurazione binari/protetti di basso livello (firmware di bordo) che alimentano direttamente i parametri fisici e telemetrici della corvetta stellare.
   - **Regola di Design**: **I file `.dat` NON possono essere modificati tramite vie ordinarie o canali "legali" all'interno del gioco**. I lettori di testo standard (`cat`, text editor standard) ne impediscono la lettura e l'alterazione diretta.
   - Qualsiasi modifica, overclock o alterazione dei valori `.dat` costituisce un'azione di **manomissione illegale / firmware exploit** all'interno dell'universo di gioco.
2. **Collegamento con la Meccanica di Hackwarfare**:
   - La manipolazione, forzatura e iniezione di codice nei file `.dat` è un pilastro centrale del modulo **Hackwarfare (Cyber Warfare & Electronic Warfare)**, che introdurrà specifici strumenti di cracking diegetici, bypass di cifratura, sniffing di pacchetti e contromisure firewall.
3. **Hot-Reloading a Runtime**:
   - Quando una modifica illegale (o un override autorizzato) viene sincronizzata su `Ship Drive`, il sottosistema esegue l'**Hot-Reloading** immediato, applicando i nuovi parametri operativi alla fisica della nave in tempo reale.

---

### 2.6 Cheat-Sheet Master: Password dei Programmi per Debug e Sviluppo
Ad uso esclusivo dello sviluppatore per attività di debug, test e override rapido delle cartelle protette in `Ship Drive/Programs/`:

| Applicazione / Modulo | Percorso Cartella Protetta | Password di Debug | File di Configurazione Attivi |
| :--- | :--- | :---: | :--- |
| **Flight Control** | `Ship Drive/Programs/FlightControls/` | `FLIGHT-7815` | `flight_config.dat`, `thrusters_tuning.dat` |
| **Cams CCTV Array** | `Ship Drive/Programs/Cams/` | `CAMS-7815` | `cams_config.dat`, `optics_tuning.dat` |
| **Duct Drone** | `Ship Drive/Programs/DuctDrone/` | `DRONE-7815` | `duct_drone_config.dat`, `drone_tuning.dat` |
| **Power Grid** | `Ship Drive/Programs/PowerGrid/` | `GRID-7815` | `power_grid_config.dat`, `grid_tuning.dat` |
| **Weapons** | `Ship Drive/Programs/Weapons/` | `WEAP-7815` | `weapons_config.dat`, `ammo_tuning.dat` |
| **Shield Matrix** | `Ship Drive/Programs/ShieldMatrix/` | `SHLD-7815` | `shields_config.dat`, `deflector_tuning.dat` |
| **Comms & EW** | `Ship Drive/Programs/Comms/` | `COMM-7815` | `comms_config.dat`, `crypto_tuning.dat` |
| **System Diagnostics** | `Ship Drive/Programs/Diagnostics/` | `DIAG-7815` | `diagnostics_config.dat`, `security_tuning.dat` |
| **Sensors (Roadmap)** | `Ship Drive/Programs/Sensors/` | `SENS-7815` | `sensors_config.dat`, `radar_tuning.dat` |
| **Life Support (Roadmap)** | `Ship Drive/Programs/LifeSupport/` | `LIFE-7815` | `life_support_config.dat`, `atmo_tuning.dat` |
| **Logbook (Roadmap)** | `Ship Drive/Programs/Logbook/` | `LOGS-7815` | `logbook_config.dat`, `journal_tuning.dat` |
| **Service Drone (Roadmap)** | `Ship Drive/Programs/ServiceDrone/` | `SERV-7815` | `service_drone_config.dat`, `manipulator_tuning.dat` |
| **Master Superuser** | *Root Drive & System Folders* | `ROOT-7815` | *Bypass universale per test suites e console* |

---

### 2.7 Fase 6: Fine Missione e Debriefing
1. Al completamento degli obiettivi o alla distruzione della nave, viene invocato `end_mission()`.
2. Le app della nave ripristinano l'overlay `SISTEMI NAVE OFFLINE`.
3. La finestra di Lobby mostra il riepilogo della missione (tempo trascorso, danni subiti, riparazioni eseguite) e permette di rilanciare una nuova missione o riassegnare i ruoli.

---

## 3. Matrice dei Ruoli (RBAC - Role-Based Access Control)

La tabella seguente specifica l'accesso e i permessi di controllo per ciascun ruolo all'interno delle applicazioni di bordo (operative e pianificate):

| Ruolo | Flight Control | Cams CCTV | Power Grid | Duct Drone | Service Drone | Weapons | Sensors | Shield Matrix | Comms & EW | Life Support | Logbook | Diagnostics | File Protetti .dat | Comandi Terminale |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Capitano** | Controllo + Override | Controllo + Zoom | Controllo + Override | Controllo + Override | Controllo + Override | Controllo + Override | Controllo + Target Lock | Controllo + Override | Controllo + Comms | Controllo + Override | Controllo + Modifica Log | Controllo + Override | Accesso Master | Tutti i Comandi |
| **Factotum** | Controllo + Override | Controllo + Zoom | Controllo + Override | Controllo + Override | Controllo + Override | Controllo + Override | Controllo + Target Lock | Controllo + Override | Controllo + Comms | Controllo + Override | Controllo + Modifica Log | Controllo + Override | Accesso Master | Tutti i Comandi |
| **Pilota** | **Controllo Completo** | Sola Visualizzazione | Sola Visualizzazione | Sola Visualizzazione | Sola Visualizzazione | Sola Visualizzazione | Telemetria / Waypoint | Sola Visualizzazione | Sola Visualizzazione | Sola Visualizzazione | Lettura / Note | Sola Visualizzazione | Tuning Motori | Navigazione / Rotte |
| **Soldato** | Sola Visualizzazione | **Controllo Completo** | Sola Visualizzazione | Sola Visualizzazione | Sola Visualizzazione | **Controllo Completo** | **Controllo Target / Radar** | Sola Visualizzazione | Sola Visualizzazione | Sola Visualizzazione | Lettura / Note | Sola Visualizzazione | Tuning Ottiche & Armi | Puntamento & Difesa |
| **Ingegnere** | Sola Visualizzazione | Sola Visualizzazione | **Controllo Completo** | **Controllo (Riparazioni)** | **Controllo (Riparazioni/Recupero)** | Sola Visualizzazione | Sola Visualizzazione | **Controllo Completo** | Sola Visualizzazione | **Controllo Completo** | Lettura / Note | **Controllo Diagnostica** | Tuning Reattore, Griglia & Scudi | Energia & Supporto Vitale |
| **Hacker** | Sola Visualizzazione | Sola Visualizzazione | Sola Visualizzazione | **Controllo (Infiltrazione)** | **Controllo (Recupero/Sabotaggio)** | Sola Visualizzazione | **Controllo Scanner / EW** | Sola Visualizzazione | **Controllo EW & Hackwarfare** | Sola Visualizzazione | Lettura / Note | **Controllo Cyber Sec & ICE** | Exploit Clandestini .dat | Cracking, Jamming & Scripting |
| **Solo Mode (Offline)** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Tutti i Comandi** |

---

## 4. Catalogo delle Applicazioni Proprietarie Esistenti

### 4.1 Lobby & Matchmaking (`Applications/Lobby`)
- **Scopo**: Gestione connessione LAN/P2P, creazione lobby, selezione ruoli, chat di plancia e avvio/termine missione.
- **Finestra**: `lobby_app.tscn` (Dimensioni: Finestra massimizzata).
- **Flusso Utente**:
  1. Si apre all'avvio del gioco.
  2. L'utente sceglie se giocare da solo o connettersi ad altri peer.
  3. Sceglie il proprio ruolo da un menu a tendina.
  4. L'host preme "Avvia Missione" quando l'equipaggio è pronto.
- **Architettura**: Connesso a `NetworkManager`. Sincronizza lo stato dei giocatori e lo stato `is_mission_active`.

### 4.2 Flight Control (`Applications/FlightControl`)
- **Scopo**: Pilotaggio e controllo della traiettoria fisica della corvetta spaziale in ambiente 3D.
- **Finestra**: `flight_control_app.tscn` (Dimensioni: `650x480`).
- **Flusso Utente**:
  1. Il Pilota apre l'app dal menu Start o Taskbar.
  2. Monitora telemetria (velocità lineare in m/s, rotazione angolare, assetto giroscopico).
  3. Usa lo slider di spinta (Throttle) e i controlli vettoriali RCS per manovrare.
  4. In caso di emergenza, preme il pulsante rosso "Arresto d'Emergenza" (Full Stop).
- **Integrazione .DAT**: Cartella protetta `Ship Drive/Programs/FlightControls/`, file `flight_config.dat` e `thrusters_tuning.dat` (Password debug: `FLIGHT-7815`).

### 4.3 Cams CCTV Array (`Applications/Cams`)
- **Scopo**: Sorveglianza visiva perimetrale a 360° della nave tramite 6 telecamere esterne montate sullo scafo.
- **Finestre**: 
  - Pannello di Controllo Principale: `cams_app.tscn` (Dimensioni: `600x420`).
  - Finestre Feed Telecamera: `camera_feed_window.tscn` (Dimensioni: `360x270`, fino a 6 istanze contemporanee).
- **Flusso Utente**:
  1. Il Soldato (o Tattico) apre l'app Cams.
  2. Può attivare i singoli canali (`Frontale`, `Posteriore`, `Sinistra`, `Destra`, `Superiore`, `Inferiore`) o premere **"Apri Tutte"**.
  3. Ciascun feed si apre in una finestra indipendente con rendering 3D in tempo reale via `SubViewport`.
  4. All'interno di ogni feed, può regolare lo zoom (In/Out), attivare filtri ottici o premere **"Reset Ottiche"** sul pannello master.
- **Integrazione .DAT**: Cartella protetta `Ship Drive/Programs/Cams/`, file `cams_config.dat` e `optics_tuning.dat` (Password debug: `CAMS-7815`).

### 4.4 Power Grid (`Applications/PowerGrid`)
- **Scopo**: Monitoraggio e ripartizione dinamica della potenza elettrica (MW) generata dai reattori verso le utenze di bordo.
- **Finestra**: `power_grid_app.tscn` (Dimensioni: `800x550`).
- **Flusso Utente**:
  1. L'Ingegnere visualizza la mappa schematica 2D generata dalla `ShipBlueprint` con generatori, snodi e dispositivi.
  2. Attiva o disattiva l'alimentazione verso motori, sensori, baia droni, scudi o supporto vitale.
  3. Commuta gli snodi elettrici per bypassare linee danneggiate o prevenire blackout da sovraccarico.
- **Integrazione .DAT**: Cartella protetta `Ship Drive/Programs/PowerGrid/`, file `power_grid_config.dat` e `grid_tuning.dat` (Password debug: `GRID-7815`).

### 4.5 Duct Drone (`Applications/DuctDrone`)
- **Scopo**: Ispezione e manutenzione interna nei condotti tecnici e compartimenti della nave tramite micro-drone teleguidato.
- **Finestra**: `duct_drone_app.tscn` (Dimensioni: `700x500`).
- **Flusso Utente**:
  1. L'Ingegnere o l'Hacker apre l'app e avvia il drone dalla baia di lancio.
  2. Pilota il drone con i controlli direzionali all'interno dei condotti tecnici visualizzati sulla mappa della blueprint.
  3. Rileva ostruzioni, cortocircuiti e falle strutturali segnalati con icone d'allarme.
  4. Esegue scansioni e riparazioni in loco consumando energia della batteria del drone.
- **Integrazione .DAT**: Cartella protetta `Ship Drive/Programs/DuctDrone/`, file `duct_drone_config.dat` e `drone_tuning.dat` (Password debug: `DRONE-7815`).

### 4.6 Terminale Diegetico UNIX (`Applications/Terminal`)
- **Scopo**: Interfaccia a riga di comando per operazioni avanzate, navigazione drive virtuali e diagnostica rapida.
- **Finestra**: `terminal_scene.tscn`.
- **Caratteristiche di Sicurezza**:
  - Supporta comandi standard (`ls`, `cd`, `pwd`, `cat`, `help`, `clear`).
  - Protezione diegetica dei file `.dat`: il comando `cat` rifiuta la lettura grezza dei file di configurazione per preservare l'integrità del sistema.

### 4.7 Tactical Weapons & Point Defense (`Applications/Weapons`)
- **Scopo**: Gestione, puntamento e ingaggio dei sistemi d'arma di bordo (Torrette Laser binate, Siluri e PDG).
- **Finestra**: `weapons_app.tscn` (Dimensioni: `720x520`).
- **Ruolo**: **Soldato** (Override: Capitano/Factotum).
- **Integrazione .DAT**: Cartella protetta `Ship Drive/Programs/Weapons/`, file `weapons_config.dat` e `ammo_tuning.dat` (Password debug: `WEAP-7815`).

### 4.8 Shield Matrix & Hull Deflectors (`Applications/ShieldMatrix`)
- **Scopo**: Gestione, distribuzione e bilanciamento della barriera deflettente energetica a 4 quadranti (Prua, Poppa, Babordo, Tribordo).
- **Finestra**: `shield_matrix_app.tscn` (Dimensioni: `620x460`).
- **Flusso Utente**:
  1. L'Ingegnere apre l'app dal menu Start o Taskbar.
  2. Monitora lo stato energetico e l'integrità dei 4 quadranti attraverso il visualizzatore olografico e le barre telemetriche.
  3. Utilizza gli slider dedicati o il Vector Pad 2D per sbilanciare la protezione verso la direzione dei pericoli/impatti.
  4. In caso di emergenza, attiva la **Ricarica Rapida d'Emergenza** per un boost istantaneo di energia deflettente al costo di un picco di assorbimento (120 MW).
  5. Sincronizza le armoniche di fase (440.0 Hz) per massimizzare stabilità ed efficienza di assorbimento.
- **Ruolo**: **Ingegnere** (Override: Capitano/Factotum; Solo Mode: controllo totale).
- **Integrazione .DAT**: Cartella protetta `Ship Drive/Programs/ShieldMatrix/`, file `shields_config.dat` e `deflector_tuning.dat` (Password debug: `SHLD-7815`).

### 4.9 Communications, Electronic Warfare & Hackwarfare (`Applications/Comms`)
- **Scopo**: Suite integrata per comunicazioni subspaziali radio, ricezione di richieste di soccorso (SOS) da relitti o colonie, contromisure di guerra elettronica (Electronic Warfare - Jamming & Spoofing IFF) e strumenti di intrusione/decodifica crittografica (Hackwarfare).
- **Finestra**: `comms_app.tscn` (Dimensioni: `680x480`).
- **Flusso Utente**:
  1. L'Hacker o il Capitano apre l'app dal menu Start o Taskbar.
  2. Utilizza il sintonizzatore di frequenze RF e il visualizzatore Waterfall Display procedurale per agganciare le portanti attive (es. SOS Emergenza a 850.5 MHz, Relay Subspaziale a 1420.0 MHz, Canale Pirata a 2185.2 MHz).
  3. Preme "Registra Trascrizione" per trascrivere i messaggi nel registro di bordo diegetico.
  4. Attiva l'emettitore Jammer modulando la potenza da 50 a 180 MW per disturbare i radar nemici e deviare missili guidati, o seleziona una firma transponder per lo Spoofing IFF (`CORVETTE_CIVILIAN`, `CARGO_HAULER_MINING`, `DERELICT_DEBRIS`, `MILITARY_ESCORT`).
  5. Nel modulo Hackwarfare, seleziona pacchetti crittografati recuperati da sonde o relitti, avvia la decodifica in tempo reale ed esporta le chiavi/password estratte direttamente su `Ship Drive` (`intercepted_crypto_key.txt`).
- **Ruolo**: **Hacker** / **Capitano** (Override: Factotum; Solo Mode: controllo totale).
- **Integrazione .DAT**: Cartella protetta `Ship Drive/Programs/Comms/`, file `comms_config.dat` e `crypto_tuning.dat` (Password debug: `COMM-7815`).

### 4.10 System Diagnostics, Cyber Security & ICE Defense (`Applications/Diagnostics`)
- **Scopo**: Centro di sicurezza informatica, diagnostica d'integrità dei drive virtuali, scansione e bonifica da minacce malware/trojan, gestione nodi barriera ICE (Intrusion Countermeasure Electronics) e ripristino di fabbrica dei firmware `.dat`.
- **Finestra**: `diagnostics_app.tscn` (Dimensioni: `640x450`).
- **Flusso Utente**:
  1. L'Hacker o l'Ingegnere apre l'app dal menu Start o Taskbar.
  2. Nello **Scanner Minacce & Drive**, seleziona l'unità target (`Ship Drive`, `Terminal Drive` o `Tutti i Drive`) e la modalità (`Rapida` o `Profonda`), quindi preme "Avvia Scansione".
  3. Visualizza l'indice di integrità complessivo e la lista dettagliata delle minacce/anomalie rilevate, procedendo alla bonifica manuale con "Purga Minacce" (o auto-quarantena automatica).
  4. Nel pannello **Barriera ICE & Difesa**, monitora l'integrità dello scudo informatico (HP) e lo stato dei nodi sottosistema (`Avionica`, `Reattore`, `Comms`, `Armi`, `Mainframe`). Durante attacchi o intrusioni cyber, rinforza la barriera (+25% HP) o esegue il flush cache del firewall.
  5. Nel modulo **Reset Firmware .DAT**, seleziona un sottosistema alterato da overclock instabili o corruzioni e avvia il "Factory Reset Firmware", ripristinando istantaneamente i parametri `.dat` ai valori di fabbrica certificati con propagazione hot-reload in tempo reale.
- **Ruolo**: **Hacker** / **Ingegnere** (Override: Capitano/Factotum; Solo Mode: controllo totale).
- **Integrazione .DAT**: Cartella protetta `Ship Drive/Programs/Diagnostics/`, file `diagnostics_config.dat` e `security_tuning.dat` (Password debug: `DIAG-7815`).

### 4.11 Long-Range Sensor Array & Tactical Map (`Applications/Sensors`)
- **Scopo**: Sistema di scansione e telemetria subspaziale a lungo raggio per mappare corpi celesti, campi di asteroidi, stazioni orbitali, navi nemiche e relitti derelitti fino a 50 km di distanza.
- **Flusso Utente e Finestre**:
  - **Finestra Principale (`sensors_app.tscn`, `750x550`)**:
    - Radar tattico 2D/3D circolare con zoom multilivello e filtri selettivi (Massa, Segnature Elettromagnetiche, Segnali IFF Amico/Nemico).
    - Modalità di scansione: **"Scansione Passiva"** (invisibile ai nemici, basso assorbimento energetico) e **"Ping Attivo"** (massima portata e risoluzione istantanea, ma rivela la posizione della nave a tutti i vascelli nel settore).
    - Modulo di analisi spettrometrica per scansionare la composizione minerale degli asteroidi o i moduli ancora integri nei relitti da saccheggiare.
    - Pulsante "Invia Coordinate": trasmette i waypoint dei bersagli rilevati direttamente al *Flight Control* del Pilota e all'app *Weapons* del Soldato.
- **Ruolo Assegnato**: **Soldato** / **Hacker** (Pieno controllo dello sweep, analisi e marcatura bersagli; gli altri membri dell'equipaggio ricevono i contatti marcati).
- **Integrazione con i Sublayer e la Simulazione 3D**:
  - Interagisce direttamente con `SpaceWorldManager` per interrogare le entità 3D presenti nello spazio di gioco.
  - **Sublayer 3 (Rete Elettrica)**: Collegato al nodo avionica e radar (`sensors_radar`, assorbimento 120 MW).
  - **Sublayer 4 (Danni)**: Guasti all'array generano "segnali fantasma" (radar ghosts) o zone d'ombra cieche nella mappa.
- **Integrazione .DAT**: Cartella protetta `Ship Drive/Programs/Sensors/`, file `sensors_config.dat` e `radar_tuning.dat` (Password debug: `SENS-7815`).

### 4.12 Life Support & Atmosphere Control (`Applications/LifeSupport`)
- **Scopo**: Monitoraggio telemetrico e controllo attivo dei parametri vitali (percentuale di O2, accumulo di CO2, pressione barometrica, temperatura e presenza di focolai d'incendio) per ciascuna stanza e compartimento della nave.
- **Flusso Utente e Finestre**:
  - **Finestra Principale (`life_support_app.tscn`, `700x500`)**:
    - Mappa atmosferica e termica 2D in tempo reale derivata dal Sublayer 1 di `ShipBlueprint`, con colorazione semaforica per compartimento (Verde = Pressione e O2 ottimali, Giallo = Calo di pressione o saturazione CO2, Rosso = Vuoto assoluto, Incendio o Atmosfera Tossica).
    - Pannello di controllo paratie stagne: pulsanti per isolare ermeticamente singole stanze o corridoi in caso di depressurizzazione rapida.
    - Pulsante "Soppressione Incendio a Gas Inerte": inietta azoto e gas estinguente nella stanza selezionata per spegnere fiamme originate da cortocircuiti, esaurendo temporaneamente l'ossigeno locale.
    - Slider di regolazione miscela O2/N2 e potenza degli scrubber di filtraggio.
- **Ruolo Assegnato**: **Ingegnere** (Controllo operativo su paratie, estintori e scrubber; Capitano in override).
- **Integrazione con i Sublayer**:
  - **Sublayer 1 (Stanze)**: Corrispondenza diretta 1:1 con i poligoni delle stanze (`rooms`) per il calcolo volumetrico dell'aria.
  - **Sublayer 2 (Condotti)**: Se un condotto tecnico subisce ostruzioni o fiamme, il fumo si diffonde attraverso la rete di condotti verso le stanze adiacenti.
  - **Sublayer 4 (Danni)**: Quando un meteorite o un missile causa una falla nello scafo (`dmg_breach`), la stanza perde atmosfera progressivamente. L'Ingegnere deve sigillare la paratia stagna mentre invia il *Duct Drone* a saldare la breccia.
- **Integrazione .DAT**: Cartella protetta `Ship Drive/Programs/LifeSupport/`, file `life_support_config.dat` e `atmo_tuning.dat` (Password debug: `LIFE-7815`).

### 4.13 Mission Logbook & Tactical Objectives (`Applications/Logbook`)
- **Scopo**: Registro di bordo ufficiale, diario delle operazioni di volo, monitoraggio dei contratti sandbox per "continuare a volare" (es. trasporto merci di contrabbando, riparazione relitti, estrazione minerali rari) e archivio note personali dell'equipaggio.
- **Flusso Utente e Finestre**:
  - **Finestra Principale (`logbook_app.tscn`, `560x420`)**:
    - **Scheda Contratti & Obiettivi**: lista delle missioni attive con tracker di avanzamento, ricompense in crediti e penalità di ritardo.
    - **Scheda Scatola Nera (Event Log)**: storico telemetrico generato automaticamente dal sistema operativo (es. "[14:22] Impatto meteorite a prua", "[14:23] Allarme incendio Sala Motori", "[14:25] Frequenza jamming nemica rilevata").
    - **Scheda Diario Personale / Note di Plancia**: editor testuale diegetico per annotare coordinate di relitti scoperti, codici di decodifica o istruzioni operative, con possibilità di salvare su `Ship Drive` (condiviso) o `Terminal Drive` (locale/privato).
- **Ruolo Assegnato**: **Tutti i Ruoli** (Il Capitano ha i permessi di spuntare o riassegnare i contratti; tutti i membri dell'equipaggio possono leggere e inserire annotazioni di registro).
- **Integrazione con i Sublayer e la Sessione**:
  - Sincronizzato con il loop di gioco persistente: i contratti completati alimentano il fondo cassa comune della nave per acquisto ricambi, munizioni e carburante.
- **Integrazione .DAT**: Cartella protetta `Ship Drive/Programs/Logbook/`, file `logbook_config.dat` e `journal_tuning.dat` (Password debug: `LOGS-7815`).

### 4.14 External Service Drone & EVA Operations (`Applications/ServiceDrone`)
- **Scopo**: Drone di servizio teleguidato per operazioni extra-veicolari (EVA), ispezioni e riparazioni strutturali esterne dello scafo, saldatura di falle nello spazio profondo, raccolta cargo/detriti spaziali e manomissione o taglio di componenti da relitti e navi disabilitate.
- **Flusso Utente e Finestre**:
  - **Finestra Principale (`service_drone_app.tscn`, `720x520`)**:
    - Feed video frontale diegetico in tempo reale ad alta risoluzione (telecamera montata sul muso del drone via `SubViewport` 3D).
    - Pannello di pilotaggio con controlli e telemetria analoghi a *Flight Control* (vettori di spinta RCS 6-DOF, slider del throttle lineare, bussola spaziale di rotta e indicatore distanza relativa dalla corvetta madre).
    - Braccio manipolatore polivalente multifunzione con selettore modalità:
      - **Modalità Riparazione Scafo / Saldatura**: ripristina l'integrità dei punti di impatto esterni e salda falle strutturali (`dmg_breach`), consumando naniti di riparazione o energia della batteria.
      - **Modalità Taglio Laser / Danneggiamento**: incide paratie esterne di relitti per sbloccare l'accesso o disabilitare selettivamente moduli esterni ostili (antenne, sensori, propulsori di manovra).
      - **Modalità Fascio Magnetico / Raccolta Cargo (Harpoon)**: aggancia container fluttuanti, minerali estratti da asteroidi e rottami preziosi, stivandoli nel vano cargo integrato del drone (capacità: 4 slot / 500 kg).
    - Pulsante "Attracco / Rientro Baia (Auto-Dock)": guida autonoma di rientro verso la baia di lancio della corvetta. All'attracco, le risorse e il cargo raccolti nella stiva del drone vengono trasferiti automaticamente e istantaneamente nella stiva principale della nave (`Cargo Bay`).
- **Ruolo Assegnato**: **Ingegnere** / **Hacker** (Ingegnere per riparazioni strutturali e recupero risorse; Hacker per sabotaggio moduli esterni e hacking ravvicinato; Capitano/Factotum in override).
- **Integrazione con i Sublayer e la Simulazione 3D**:
  - **Simulazione 3D (`SpaceWorldManager`)**: Istanzia l'entità fisica 3D del service drone nello spazio attorno alla corvetta, con raggio operativo limitato dal segnale radio della baia (max 1500 m prima del disingaggio telemetrico).
  - **Sublayer 3 (Rete Elettrica)**: La baia droni esterna (`service_bay`) assorbe 80 MW in standby e 140 MW in fase di ricarica rapida della batteria del drone.
  - **Sublayer 4 (Danni)**: Ripara direttamente le coordinate dei danni allo scafo esterno registrati dal sistema di diagnostica (`dmg_breach` e usura scafo).
- **Integrazione .DAT**: Cartella protetta `Ship Drive/Programs/ServiceDrone/`, file `service_drone_config.dat` e `manipulator_tuning.dat` (Password debug: `SERV-7815`).

---

## 5. Roadmap e Nuove Feature da Creare

Di seguito vengono definite le specifiche per le future espansioni di *Dark Nova: Rogue Squadron*.

### 5.1 Roadmap nuove applicazioni

Tutte le applicazioni principali della corvetta sono state completate. Ulteriori moduli di espansione verranno pianificati in base ai feedback del gameplay sandbox.

NOTA: Il concetto di freemium-punk verrà impostato in seguito

---

## 6. Meccaniche di Settore e Navigazione Spaziale (Sviluppate)

Le seguenti meccaniche definiscono l'ambiente di gioco e le modalità di interazione con il sistema stellare.

### 6.1 Mappa del Sistema Stellare e Gameplay di Settore

```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│                     MAPPA SISTEMA STELLARE & MECCANICHE SETTORE                  │
├──────────────────────────────┬───────────────────────────────────────────────────┤
│ Feature                      │ Descrizione e Scopo Operativo                     │
├──────────────────────────────┼───────────────────────────────────────────────────┤
│ 1. Architettura Griglia      │ Coordinate spaziali a celle, skybox e illuminazione│
│ 2. Propulsione di Crociera   │ Navigazione interplanetaria sub-FTL vettorizzata  │
│ 3. Stazioni Orbitali & Dock  │ Interfaccia di docking via Comms e servizi porto  │
│ 4. Economia a FLUX & Cargo   │ Gestione stiva, rating FLUX e corrieri dati S-Net │
│ 5. Mining & Scavenging       │ Estrazione asteroidi e recupero relitti derelitti │
│ 6. Dogfight & Ingaggi Tattici│ Combattimento asimmetrico e guerra elettronica    │
└──────────────────────────────┴───────────────────────────────────────────────────┘
```

---

#### 6.1.1 Architettura del Sistema Stellare e Griglia Spaziale
- **Modello a Griglia e Coordinate di Settore**:
  - L'intero sistema solare è strutturato come una griglia 3D/2D discreta di coordinate di settore (celle spaziali indicizzate, es. `SEC-04-12`).
  - Ciascuna casella della griglia non rappresenta un singolo punto geometrico, ma un'intera macro-area di simulazione (scena 3D attiva generata da `SpaceWorldManager`), popolata da corpi celesti, campi di detriti, fasce di asteroidi, stazioni orbitali, navi mercantili o vascelli pirata.
  - La griglia costituisce il layer logico utilizzato dal computer di bordo per calcolare in tempo reale vettori di navigazione, consumi propellente, distanze cinematiche e rendering diegetico dei corpi celesti sullo skymap/skybox.
- **Illuminazione Dinamica e Occlusione Planetaria**:
  - L'illuminazione direzionale del settore viene calcolata dinamicamente in base alla distanza e all'angolo relativo della stella primaria (o delle stelle binarie) rispetto alla posizione della nave nella griglia.
  - Pianeti massicci, lune e megalopoli spaziali generano realistici coni d'ombra e zone di eclissi/occlusione in cui la visibilità ottica perimetrale cala drasticamente e l'assorbimento fotovoltaico o dei collettori di radiazione si azzera, costringendo l'equipaggio ad affidarsi interamente ai fari di bordo e ai sensori termici.
- **Distanza di Render e Skybox Diegetico**:
  - Ogni macro-entità del sistema possiede un raggio di visibilità scalare misurato in caselle di griglia:
    - *Stella Primaria*: visibile fino a 30+ caselle di distanza.
    - *Giganti Gassosi / Pianeti Maggiori*: visibili entro un raggio di 10-15 caselle.
    - *Stazioni Spaziali / Fasce di Asteroidi*: visibili entro 2-4 caselle prima dell'ingresso nel settore di rendering dettagliato in locale.
  - Gli oggetti astronomici distanti vengono proiettati dinamicamente sullo skybox della scena 3D come indicatori ottici e telemetrici per il Pilota (*Flight Control*), le telecamere esterne (*Cams*) e la mappa tattica (*Sensors*).
- **Vincolo Tecnologico Diegetico (No-FTL)**:
  - L'ambientazione è rigorosamente priva di motori FTL (Faster-Than-Light / Iperspazio convenzionale). L'esperienza è interamente circoscritta all'interno di un singolo, denso sistema stellare colonizzato, caratterizzato da forti contrasti tra potenti corporazioni centrali, stazioni orbitali sovraffollate e colonie minerarie di frontiera derelitte.

---

#### 6.1.2 Modalità Velocità di Crociera (Cruise Mode / Sub-FTL)
- **Meccanica di Propulsione Accelerata**:
  - Per coprire le immense distanze interplanetarie tra le caselle del sistema senza viaggi istantanei, la corvetta impiega la modalità **Velocità di Crociera (Cruise Drive)**.
  - In assetto ordinario la nave opera a velocità manovriera ($V$) con pieno controllo manuale dei vettori RCS (beccheggio, imbardata, rollio).
  - In modalità Crociera la spinta propulsiva viene amplificata a valori esponenziali ($V^2$ o boost moltiplicativo), mentre il controllo del timone manuale viene temporaneamente bloccato: la rotta viene vincolata dal computer di navigazione in linea retta verso il settore o quadrante di destinazione selezionato.
- **Procedura di Ingaggio e Warmup del Reattore**:
  - L'attivazione della velocità di crociera non è istantanea, ma richiede una sequenza coordinata:
    1. **Stato di Quiete**: La nave deve mantenere una velocità relativa quasi nulla e azzerare le manovre brusche per $N$ secondi.
    2. **Allineamento Vettoriale**: Il Pilota orienta la prua verso il vettore del settore bersaglio indicato dai *Sensors*.
    3. **Warmup & Distribuzione Energetica**: L'Ingegnere convoglia un picco di potenza ausiliaria dai generatori (*Power Grid*) per alimentare le bobine di spinta.
    4. **Difesa & Copertura**: In situazioni di combattimento, Soldato e Hacker devono fornire copertura difensiva (chaff, flare e jamming contromisure) per impedire a proiettili o missili nemici di interrompere la sequenza di carica.
- **Sistemi di Sicurezza e Disingaggio d'Emergenza (Proximity Drop)**:
  - Se la traiettoria di crociera intercetta la massa critica di un asteroide gigante, una stazione, un relitto o una nave ostile (o in presenza di un'allerta collisione imminente), l'avionica di bordo esegue automaticamente un **Emergency Drop**.
  - Il disingaggio brusco riporta istantaneamente la nave a velocità ordinaria, provocando un temporaneo surriscaldamento dei propulsori e lasciando la corvetta vulnerabile per alcuni secondi.
- **Flusso Operativo UI**:
  - La rotta di crociera viene impostata attraverso le finestre *Sensors / Flight Control*: si seleziona la coordinata di destinazione sulla mappa di sistema, si calcola il vettore di rotta e si avvia la sequenza di spinta coordinata tra Pilota e Ingegnere.

---

#### 6.1.3 Stazioni Spaziali, Docking e Servizi Portuali
- **Protocollo di Attracco Diegetico (Docking Protocol)**:
  - In prossimità di una stazione spaziale orbitale, l'equipaggio non controlla un avatar fisico a piedi, ma interagisce unicamente attraverso i protocolli e le comunicazioni diegetiche del sistema operativo **GodotOS**.
  - La sequenza di attracco si avvia tramite l'applicazione *Comms & EW*: l'Hacker o il Capitano aggancia la frequenza del controllo traffico portuale, invia la firma transponder IFF e riceve l'assegnazione dello slot di docking o del braccio magnetico.
  - Il Pilota allinea la corvetta entro i coni telemetrici di cattura per completare la procedura di aggancio.
- **Servizi e Hub di Stazione su GodotOS**:
  - A docking completato, su GodotOS si rendono accessibili finestre e pannelli di servizio proprietari forniti dal porto (in stile *Sid Meier's Pirates!* spaziale):
    - **Cantiere Navale & Officina Riparazioni**: ripristino dell'integrità strutturale dello scafo, manutenzione e spurgo dei condotti tecnici, ricarica delle batterie e approvvigionamento di naniti e ricambi per l'Ingegnere.
    - **Mercato Software & Repository Firmware**: compravendita di nuovi programmi diegetici, driver di periferica, script di automazione per il terminale e patch firmware legali o clandestine per l'Hacker e il Capitano.
    - **Bacheca Contratti & Ufficio Taglie**: consultazione e stipula di contratti corporativi, incarichi di scorta, bonifica relitti, tratte mercantili o contrabbando illegale, sincronizzati con l'app *Logbook*.
    - **Taverna Spaziale & Intercettazione Frequenze**: ascolto di trasmissioni radio locali, intercettazione di rumors su carichi preziosi in transito e coordinate di relitti abbandonati ricchi di risorse.
- **Restrizione Mobilità Diegetica**:
  - Nessuna transizione a piedi o ambiente 3D in prima persona per gli interni di stazione: tutta l'interazione resta ancorata alle applicazioni del desktop di bordo, preservando l'identità diegetica pura del gioco.

---

#### 6.1.4 Commercio, Logistica Cargo ed Economia a "FLUX"
- **Gestione della Stiva (Cargo Bay & Material Flow)**:
  - Interfaccia per il trasferimento merci bidirezionale tra i magazzini di stazione (o le stive di navi abbordate/amiche) e i compartimenti di carico della nave.
  - Catalogazione merci diversificata: celle energetiche, minerali grezzi, leghe raffinate, ricambi per condotti, munizioni per torrette balistiche, pacchetti software e merci di contrabbando sotto sigillo.
- **La Rete Dati S-Net (System Network) e i Corrieri Fisici**:
  - Nell'universo di gioco, a causa delle immense distanze astronomiche e dell'assenza di comunicazioni FTL istantanee ad alta banda, la rete dati interplanetaria **S-Net (System Network)** non è sincronizzata in tempo reale tra pianeti e stazioni distanti.
  - Le informazioni, i notiziari, le banche dati economiche e i listini prezzi viaggiano attraverso navi cargo dedicate che trasportano array fisici di hard disk contenenti snapshot aggiornati della S-Net di ciascun settore.
  - L'Hacker può intercettare o connettersi ai terminali dati di queste navi corriere per estrarre informazioni riservate, coordinate segrete e dati finanziari, affrontando le barriere ICE e i nodi firewall integrati nell'hard disk.
- **Il Sistema Economico dei "FLUX" (Freemium-punk)**:
  - Nel contesto satirico Freemium-punk non esiste una moneta cartacea fissa: l'unità e indice economico universale è il **FLUX**.
  - Il FLUX è un indice dinamico di rating finanziario e liquidità di flusso (simile a un credit score continuo), calcolato sulla base del volume, della frequenza e della regolarità delle transazioni in entrata e in uscita associate all'identità della nave.
  - Carburante, rifornimenti, riparazioni e persino licenze software dei sistemi operativi di bordo operano tramite canoni di abbonamento, microtransazioni di sistema e royalty settoriali.
- **Impatti del Rating FLUX**:
    - *FLUX Elevato (Rating A/S)*: garantisce tariffe agevolate di porto, priorità di fornitura energetica nei settori corporativi e sblocco di contratti commerciali prestigiosi.
    - *FLUX Negativo o Insolvente (Rating D/F)*: comporta disattivazione remota di feature software da parte delle corporazioni fornitrici, sovraccosti sui servizi portuali, emissione di taglie da parte dei creditori fino all'**impound (sequestro della nave)** con conseguente fallimento della sessione (Game Over).

---

#### 6.1.5 Mining ed Estrazione Risorse (Asteroidi & Scavenging)
- **Estrazione Mineraria su Asteroidi (Deep Core Mining)**:
  - Scansione preliminare geologica dei campi di asteroidi tramite *Sensors* (analisi spettrometrica per identificare vene di metalli pesanti, leghe rare, cristalli energetici e ghiaccio d'acqua per il supporto vitale).
  - Frantumazione calibrata dei massi rocciosi tramite i laser minerari o torrette controllate dal Soldato (*Weapons*), mentre il Pilota mantiene un hovering ravvicinato stabile per evitare collisioni da rinculo o frammentazione.
  - Recupero dei frammenti minerali fluttuanti tramite il fascio magnetico del *Service Drone* e stivaggio istantaneo nella stiva cargo della nave.
- **Scavenging e Spoglio di Relitti Spaziali (Derelict Salvage)**:
  - Esplorazione e spoglio di vascelli distrutti, stazioni abbandonate e detriti bellici nello spazio profondo.
  - L'Hacker neutralizza i sistemi di sicurezza automatizzati, bypassa le serrature elettroniche e abbatte i nodi ICE residui della carcassa per sbloccare i portelloni di carico.
  - L'Ingegnere (o l'Hacker) pilota il *Service Drone* all'esterno o il *Duct Drone* all'interno dei compartimenti pressurizzati del relitto per tagliare piastre corazzate, estrarre moduli avionici integri e recuperare black box con crediti o chiavi crittografiche.

---

#### 6.1.6 Combattimenti Spaziali, Dogfight e Guerra Tattica Asimmetrica
- **Cooperazione Multiruolo in Combattimento**:
  - Gli ingaggi a fuoco contro caccia pirata, droni da ricognizione corporativi o incrociatori di pattuglia richiedono la sinergia assoluta di tutti i membri dell'equipaggio:
    - **Pilota**: esegue manovre evasive, controlla la spinta lineare per mantenere la distanza ottimale di tiro e allinea la corvetta per garantire l'arco di tiro ottimale delle torrette dorsali e ventrali.
    - **Soldato**: gestisce il raffreddamento e la cadenza di fuoco delle torrette laser e balistiche (*Weapons*), calcola il punto di anticipo balistico e attiva le mitragliatrici Point-Defense (PDG) contro sciami di missili in arrivo.
    - **Ingegnere**: bilancia la distribution energetica dei 4 quadranti deflettenti (*Shield Matrix*), gestisce i picchi di assorbimento del generatore (*Power Grid*) e interviene tempestivamente sulle falle strutturali e sugli incendi con *Life Support*, *Duct Drone* e *Service Drone*.
    - **Hacker**: conduce operazioni di guerra elettronica offensive e difensive (*Comms & EW*, *Diagnostics*), manomette a distanza i motori o il puntamento radar nemico con iniezioni di exploit firmware, e contrasta i virus o attacchi ICE lanciati contro i drive virtuali della corvetta.
- **Integrazione Danni Sistemici e Stati di Allarme**:
  - I colpi subiti non riducono una semplice barra di vita astratta, ma generano danni fisici localizzati ai componenti della nave: falle strutturali (`dmg_breach`), cortocircuiti nei condotti elettrici, guasti all'array radar, avarie ai giroscopi RCS e perdite progressive di atmosfera.
  - Troppi danni accumulati possono determinare lo spegnimento a cascata dei sistemi ausiliari, il collasso del reattore principale o la distruzione dell'unità.
  - Un indicatore diegetico di **Emergenza** viene mostrato su tutti i display di bordo:
    - *Allarme Giallo (Avaria Grave)*: integrità scafo compromessa o disattivazione di un sottosistema primario.
    - *Allarme Rosso (Pericolo Distruzione Imminente / Breccia Critica)*: fallimento catastrofico dei sistemi con conto alla rovescia per l'evacuazione o la perdita totale della corvetta.

---

## 7. Schema Architetturale di Riferimento per Nuove App
Ogni nuova applicazione pianificata nella Roadmap deve rispettare rigorosamente il modello architetturale definito in [`docs/APP_ARCHITECTURE_STANDARD.md`](APP_ARCHITECTURE_STANDARD.md):

```text
Applications/NomeApplicazione/
├── nome_app.tscn           # Scena UI (Control) con %DisconnectedOverlay
├── nome_app.gd             # Controller con parsing .DAT, hot-reloading e RBAC
├── nome_app.tres           # Risorsa ShipAppResource o TerminalAppResource
├── Componenti/             # Sotto-scene, widget modulari o finestre figlie
└── tests/test_nome_app.gd  # Test headless per verificare overlay offline/online, risorsa .tres, RBAC e .DAT
```

### Regole Vincolanti per lo Sviluppo:
1. **Branch Dedicato**: Creare e utilizzare sempre il branch `applications/[NomeApp]` prima di apportare modifiche (es. `applications/Weapons`).
2. **Definizione Risorsa `.tres`**: Creare la risorsa esportabile (`ShipAppResource` per app di bordo o `TerminalAppResource` per app locali) impostando ID, metadati, percorsi scene, dimensioni finestra, assorbimento energetico e array dei ruoli RBAC.
3. **Ciclo di Vita e Overlay Offline**: Tutte le applicazioni della nave devono includere il nodo `%DisconnectedOverlay` ed essere disabilitate prima del decollo (`not SpaceWorldManager.is_ship_connected()`).
4. **Cartella Protetta e File `.dat`**:
   - Salvataggio in `Ship Drive/Programs/[NomeApp]/` con password predefinita dal Cheat-Sheet Master (Sezione 2.6).
   - I file `.dat` e le password di default sono definiti nella proprietà `default_files` e `default_password` della risorsa e popolati automaticamente da `ShipSoftwareManager`.
   - Utilizzo del metodo standard `_parse_dat_file()` per il parsing INI con type-casting.
   - Iscrizione al segnale `ShipDriveManager.file_modified` per supportare l'**Hot-Reloading** immediato dei parametri a runtime.
5. **Adattamento Dimensionale**: Impostare `custom_minimum_size` calibrata senza sbordamenti oltre i confini della finestra, con layout reattivo (`Anchors` e `Containers`).
6. **Integrazione con `ShipSoftwareManager` e `ShipBlueprint` (Sublayer 6)**:
   - Registrazione della risorsa nel catalogo `ShipSoftwareManager` e nell'array `installed_apps` di `ShipBlueprint`.
   - Popolamento dinamico nel menu Start di GodotOS all'evento `start_mission()`, visualizzando solo le app consentite per il ruolo del giocatore locale.
7. **Protezione Diegetica e Hackwarfare**:
   - I file `.dat` non sono leggibili né modificabili via `cat` o text editor standard (blocco per file binari/protetti).
   - Qualsiasi modifica clandestina deve avvenire tramite le meccaniche dedicate dell'Hacker o del modulo Diagnostics.
8. **Suite di Test Headless**:
   - Creazione del test in `tests/test_[nome_app].gd` che verifichi:
     - Overlay visibile in stato disconnesso / offline.
     - Sblocco e reattività in stato connesso (`start_mission()`).
     - Rispetto dei permessi RBAC (azioni consentite per il ruolo assegnato e bloccate/in sola lettura per gli altri).
     - Caricamento e aggiornamento dei parametri `.dat`.
     - Integrazione con la risorsa `.tres` e il relativo Software Manager.

---

## 8. Conclusioni e Riepilogo

Il presente documento fornisce la visione completa, organica e integrata di *Dark Nova: Rogue Squadron*. 

Attraverso la combinazione dell'atmosfera di frontiera in stile *Firefly*, della satira *Freemium-punk*, dell'interfaccia diegetica a finestre su **GodotOS** e della rigida matrice di cooperazione asimmetrica tra i 6 ruoli dell'equipaggio (**Capitano**, **Pilota**, **Soldato**, **Ingegnere**, **Hacker**, **Factotum**), il gioco garantisce un gameplay sandbox dinamico, teso e profondo.

L'ecosistema complessivo delle 14 applicazioni della corvetta (tutte sviluppate), alimentato dai 6 sottolivelli della `ShipBlueprint` e protetto dall'architettura firmware `.dat` con meccaniche di Hackwarfare, pone le basi per un'esperienza cooperativa solida, scalabile e rigorosamente conforme agli standard tecnici di progetto.
