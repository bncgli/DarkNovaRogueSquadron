# Documento di Design di Gioco, Flusso Utente e Feature Suite (GDD / FDD)
# Dark Nova: Rogue Squadron / GodotOS

> **Scopo del Documento**:
> Questo documento definisce l'esperienza di gioco complessiva di *Dark Nova: Rogue Squadron*, descrivendo in dettaglio:
> 1. **Il Flusso Lato Utente (User Journey)**: cosa succede dall'avvio del gioco, quali finestre si aprono, come interagiscono i giocatori e la gestione del desktop multi-finestra.
> 2. **Le Applicazioni Proprietarie Esistenti e la Matrice dei Ruoli (RBAC)**: funzionamento dettagliato di ogni applicazione sviluppata e responsabilità di ogni ruolo.
> 3. **Le Nuove Feature da Creare (Roadmap)**: specifiche complete, flusso d'uso, finestre, configurazioni `.dat` e integrazione sublayer per tutte le prossime applicazioni pianificate.

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
 │ 1. BOOT & AVVIO GODOTOS                                                │
 │    - Schermata di Boot Splash Dark Nova                                │
 │    - Caricamento Desktop GodotOS con Taskbar e Start Menu              │
 └───────────────────────────────────┬────────────────────────────────────┘
                                     │
                                     ▼
 ┌────────────────────────────────────────────────────────────────────────┐
 │ 2. FASE LOBBY & PREPARAZIONE                                           │
 │    - Il giocatore apre la finestra "Lobby & Matchmaking"               │
 │    - Modalità Solo Mode vs Host Multiplayer LAN/P2P vs Join Client     │
 │    - Selezione e sincronizzazione del Ruolo (Capitano, Pilota, ecc.)   │
 │    - Configurazione file locali su Terminal Drive (se necessario)      │
 └───────────────────────────────────┬────────────────────────────────────┘
                                     │
                                     ▼ (Host/Solo preme "Avvia Missione")
 ┌────────────────────────────────────────────────────────────────────────┐
 │ 3. DECOLLO & SBLOCCO SISTEMI NAVE                                      │
 │    - NetworkManager & SpaceWorldManager attivano la simulazione 3D     │
 │    - Notifica desktop: "Decollo completato - Sistemi Nave Operativi"   │
 │    - Le app della nave rimuovono l'overlay "Sistemi Offline"           │
 │    - I giocatori aprono le proprie applicazioni di specializzazione    │
 └───────────────────────────────────┬────────────────────────────────────┘
                                     │
                                     ▼
 ┌────────────────────────────────────────────────────────────────────────┐
 │ 4. GAMEPLAY LOOP OPERATIVO (CO-OP ASIMMETRICO)                         │
 │    - Pilota: Controlla la nave per evitare pericoli e collisioni       │
 │    - Soldato: Usa le armi per abbattere i nemici                       │
 │    - Ingegnere: Gestisce l'energia e le riparazioni                    │
 │    - Hacker: Gestisce il terminale e electronic warfare                │
 └───────────────────────────────────┬────────────────────────────────────┘
                                     │
                                     ▼ (Eventi Imprevisti / Emergenze)
 ┌────────────────────────────────────────────────────────────────────────┐
 │ 5. GESTIONE EMERGENZE & GUASTI A BORDO                                 │
 │    - Rilevamento guasto / allarme sonoro / notifica OS                 │
 │    - Apertura finestre di diagnostica e cooperazione incrociata        │
 │    - Drone naviga nei condotti -> Ingegnere isola il settore elettrico │
 └───────────────────────────────────┬────────────────────────────────────┘
                                     │
                                     ▼
 ┌────────────────────────────────────────────────────────────────────────┐
 │ 6. CONCLUSIONE MISSIONE / FINE SESSIONE                                │
 │    - Il gioco è un sandbox: salvataggio persistente e debriefing      │
 │    - Chiusura/Blocco automatico finestre nave con overlay Disconnesso  │
 │    - Schermata di debriefing e statistiche sessione in Lobby           │
 └────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Fase 1: Boot e Desktop
1. **Avvio**: L'utente avvia l'eseguibile di gioco.
2. Viene visualizzata una schermata di caricamento/boot splash a tema aerospaziale.
3. Si carica l'ambiente desktop **GodotOS** con sfondo spaziale, barra delle applicazioni (Taskbar) in basso, orologio di sistema, tray notifiche e icone sul desktop.

### 2.2 Fase 2: Apertura Lobby e Scelta del Ruolo
1. All'avvio del desktop, la finestra **Lobby & Matchmaking** si apre al centro dello schermo (oppure può essere richiamata dal menu Start o dall'icona sul desktop).
2. **Scelte possibili per l'utente**:
   - **Gioca da Solo (Solo Mode)**: Il giocatore avvia la sessione offline e ottiene i permessi di tutti i ruoli simultaneamente.
   - **Crea Stanza (Host Server)**: Il giocatore funge da host server-authoritative, imposta il nome della stanza e la porta di rete.
   - **Unisciti (Join Client)**: Il giocatore inserisce l'indirizzo IP dell'host e si connette alla stanza.
3. **Selezione del Ruolo**:
   - Nella lista equipaggio, ogni giocatore sceglie il proprio ruolo tra quelli disponibili: *Capitano*, *Pilota*, *Soldato*, *Ingegnere*, *Hacker*, *Factotum*, ecc.
   - La chat integrata nella finestra di Lobby permette di coordinare i ruoli prima del lancio.
4. **Comportamento delle applicazioni prima del decollo e gestione dinamica del menu Start**:
   - Le applicazioni operative della nave (*Flight Control*, *Cams*, *Power Grid*, *Duct Drone*, ecc.) sono definite direttamente all'interno della risorsa `ShipBlueprint` della nave (Sublayer 6: *Mainframe Installed Apps*).
   - Prima dell'avvio della missione (in stato Offline o Lobby), le applicazioni della nave **non compaiono nel menu Start**, eliminando aperture accidentali e il problema dei blocchi con overlay *"connettiti ad una nave"*.
   - Le sole app sempre presenti sono le utility locali del terminale (es. *Lobby*, *Terminale*, *File Manager*, *Text Editor*, *Giochi*).
5. **Comportamento delle applicazioni in base al ruolo al decollo (Filtro Ruoli RBAC)**:
   - Al decollo (`start_mission()`), il menu Start di GodotOS legge dinamicamente dalla `ShipBlueprint` attiva e popola le sole applicazioni autorizzate per il ruolo ricoperto dal giocatore locale:
     - **Pilota**: visualizza *Flight Control* e *Cams*.
     - **Ingegnere**: visualizza *Power Grid* e *Duct Drone*.
     - **Tattico / Soldato**: visualizza *Cams* e *Weapons*.
     - **Hacker**: visualizza *Duct Drone* e strumenti di cyber warfare.
     - **Capitano / Factotum / Solo Mode**: visualizza l'intera suite delle applicazioni installate a bordo senza restrizioni.
   - In caso di cambio ruolo a runtime o fine missione, il menu Start si aggiorna o ripulisce istantaneamente.

### 2.3 Fase 3: Transizione e Decollo ("Start Mission")
1. Quando tutti i membri sono pronti, l'Host o il giocatore Solo preme **"Avvia Missione"**.
2. **Cosa succede a livello di sistema**:
   - L'evento globale `mission_started` viene propagato a tutte le macchine connesse.
   - L'autoload `SpaceWorldManager` inizializza l'universo 3D, posiziona la corvetta stellare (`Spaceship`), genera il campo di asteroidi e attiva le 6 telecamere perimetrali CCTV.
   - Viene emessa una notifica sonora e visiva sul desktop di tutti i client.
   - Tutte le finestre delle applicazioni della nave aperte rimuovono istantaneamente l'overlay di blocco e diventano interattive.

### 2.4 Fase 4: Loop di Gioco Operativo e Organizzazione Desktop
Ogni membro dell'equipaggio organizza il proprio desktop in base alle proprie mansioni:

- **Postazione Pilota**:
  - Apre **Flight Control**: controlla il throttle di spinta lineare, orienta i vettori di beccheggio/imbardata/rollio (RCS) per navigare nel campo asteroidi ed evitare collisioni.
  - Apre **Cams CCTV Array**: disporre sullo schermo fino a 6 feed delle telecamere (Frontale, Posteriore, Sinistra, Destra, Superiore, Inferiore).
- **Postazione Soldato**:
  - Apre **Cams CCTV Array**: disporre sullo schermo fino a 6 feed delle telecamere (Frontale, Posteriore, Sinistra, Destra, Superiore, Inferiore).
  - Apre **Weapons**: Prepara gli armamenti di attacco e difesa. 
- **Postazione Ingegnere**:
  - Apre **Power Grid**: monitora il grafico di assorbimento MW e i generatori. Se il Pilota richiede massima spinta, l'Ingegnere convoglia potenza ai motori spegnendo utenze non essenziali; se c'è un'avaria, commuta gli snodi elettrici per isolare i cortocircuiti.
  - Apre **Duct Drone**: decolla dalla baia droni e pilota il micro-drone all'interno dei condotti di ventilazione e manutenzione della nave, guidato dalla mappa 2D generata dalla `ShipBlueprint`. Raggiunge i punti di danno per eseguire le riparazioni.
- **Postazione Hacker**:
  - Apre **Terminale / Prompt dei comandi**: esegue script clandestini per manipolare i file `.dat`, bypassare crittografie e connettersi a stazioni o navi nemiche per estrarre crediti e dati sensibili.
  - Apre **Duct Drone**: esplora furtivamente i condotti di navi nemiche o settori isolati per effettuare scansioni clandestine e ricognizioni.
  - Apre **ICE & Firewall / Diagnostics**: gestisce barriere crittografiche difensive per neutralizzare virus, malware e intrusioni nemiche.
- **Postazione Capitano o Factotum**:
  - Apre una vista d'insieme: telemetria motori, telecamere principali, stato rete elettrica, chat ordini e logbook. Sovraintende alle decisioni strategiche e può intervenire con comandi di override d'emergenza su qualsiasi sottosistema.

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
| **Weapons (Roadmap)** | `Ship Drive/Programs/Weapons/` | `WEAP-7815` | `weapons_config.dat`, `ammo_tuning.dat` |
| **Sensors (Roadmap)** | `Ship Drive/Programs/Sensors/` | `SENS-7815` | `sensors_config.dat`, `radar_tuning.dat` |
| **Shield Matrix (Roadmap)** | `Ship Drive/Programs/ShieldMatrix/` | `SHLD-7815` | `shields_config.dat`, `deflector_tuning.dat` |
| **Comms & EW (Roadmap)** | `Ship Drive/Programs/Comms/` | `COMM-7815` | `comms_config.dat`, `crypto_tuning.dat` |
| **Life Support (Roadmap)** | `Ship Drive/Programs/LifeSupport/` | `LIFE-7815` | `life_support_config.dat`, `atmo_tuning.dat` |
| **Logbook (Roadmap)** | `Ship Drive/Programs/Logbook/` | `LOGS-7815` | `logbook_config.dat`, `journal_tuning.dat` |
| **Diagnostics (Roadmap)** | `Ship Drive/Programs/Diagnostics/` | `DIAG-7815` | `diagnostics_config.dat`, `security_tuning.dat` |
| **Master Superuser** | *Root Drive & System Folders* | `ROOT-7815` | *Bypass universale per test suites e console* |

---

### 2.7 Fase 6: Fine Missione e Debriefing
1. Al completamento degli obiettivi o alla distruzione della nave, viene invocato `end_mission()`.
2. Le app della nave ripristinano l'overlay `SISTEMI NAVE OFFLINE`.
3. La finestra di Lobby mostra il riepilogo della missione (tempo trascorso, danni subiti, riparazioni eseguite) e permette di rilanciare una nuova missione o riassegnare i ruoli.

---

## 3. Matrice dei Ruoli (RBAC - Role-Based Access Control)

La tabella seguente specifica l'accesso e i permessi di controllo per ciascun ruolo all'interno delle applicazioni di bordo (operative e pianificate):

| Ruolo | Flight Control | Cams CCTV | Power Grid | Duct Drone | Weapons | Sensors | Shield Matrix | Comms & EW | Life Support | Logbook | Diagnostics | File Protetti .dat | Comandi Terminale |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Capitano** | Controllo + Override | Controllo + Zoom | Controllo + Override | Controllo + Override | Controllo + Override | Controllo + Target Lock | Controllo + Override | Controllo + Comms | Controllo + Override | Controllo + Modifica Log | Controllo + Override | Accesso Master | Tutti i Comandi |
| **Factotum** | Controllo + Override | Controllo + Zoom | Controllo + Override | Controllo + Override | Controllo + Override | Controllo + Target Lock | Controllo + Override | Controllo + Comms | Controllo + Override | Controllo + Modifica Log | Controllo + Override | Accesso Master | Tutti i Comandi |
| **Pilota** | **Controllo Completo** | Sola Visualizzazione | Sola Visualizzazione | Sola Visualizzazione | Sola Visualizzazione | Telemetria / Waypoint | Sola Visualizzazione | Sola Visualizzazione | Sola Visualizzazione | Lettura / Note | Sola Visualizzazione | Tuning Motori | Navigazione / Rotte |
| **Soldato** | Sola Visualizzazione | **Controllo Completo** | Sola Visualizzazione | Sola Visualizzazione | **Controllo Completo** | **Controllo Target / Radar** | Sola Visualizzazione | Sola Visualizzazione | Sola Visualizzazione | Lettura / Note | Sola Visualizzazione | Tuning Ottiche & Armi | Puntamento & Difesa |
| **Ingegnere** | Sola Visualizzazione | Sola Visualizzazione | **Controllo Completo** | **Controllo (Riparazioni)** | Sola Visualizzazione | Sola Visualizzazione | **Controllo Completo** | Sola Visualizzazione | **Controllo Completo** | Lettura / Note | **Controllo Diagnostica** | Tuning Reattore, Griglia & Scudi | Energia & Supporto Vitale |
| **Hacker** | Sola Visualizzazione | Sola Visualizzazione | Sola Visualizzazione | **Controllo (Infiltrazione)** | Sola Visualizzazione | **Controllo Scanner / EW** | Sola Visualizzazione | **Controllo EW & Hackwarfare** | Sola Visualizzazione | Lettura / Note | **Controllo Cyber Sec & ICE** | Exploit Clandestini .dat | Cracking, Jamming & Scripting |
| **Solo Mode (Offline)** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Controllo Totale** | **Tutti i Comandi** |

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

---

## 5. Roadmap e Nuove Feature da Creare

Di seguito vengono definite le specifiche dettagliate per le nuove applicazioni proprietarie della nave da sviluppare nelle prossime milestone, coerentemente con i ruoli RBAC, il tema sandbox Freemium-punk / Firefly e la suite di configurazione `.dat`.

```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│                         ROADMAP NUOVE APPLICAZIONI NAVE                          │
├──────────────────────────────┬───────────────────────────────────────────────────┤
│ Applicazione Pianificata     │ Ruolo Principale / Scopo Operativo                │
├──────────────────────────────┼───────────────────────────────────────────────────┤
│ 1. Tactical Weapons System   │ Soldato / Torrette Laser, Lanciasiluri e PDG      │
│ 2. Long-Range Sensor Array   │ Soldato / Hacker / Radar 50km e Spettrometria     │
│ 3. Shield Matrix & Deflectors│ Ingegnere / Scudi 4 Quadranti & Ricarica Rapida   │
│ 4. Comms & Electronic War    │ Hacker / Capitano / EW Jamming, SOS & Decodifica  │
│ 5. Life Support & Atmosphere │ Ingegnere / O2, CO2, Paratie e Antincendio        │
│ 6. Mission Logbook & Sandbox │ Capitano / Tutti i Ruoli / Contratti & Black Box  │
│ 7. System Diagnostics & ICE  │ Hacker / Ingegnere / Malware, Antivirus & Reset   │
└──────────────────────────────┴───────────────────────────────────────────────────┘
```
NOTA: Il concetto di freemium-punk verrà impostato in seguito
---

### 5.1 Nuova Feature 1: Tactical Weapons & Point Defense (`Applications/Weapons`)
- **Descrizione**: Pannello diegetico di gestione, puntamento e ingaggio dei sistemi d'arma di bordo (Torrette Laser binate, Lanciasiluri a guida termica e torrette automatiche Point Defense Gatling - PDG - per intercettare asteroidi e missili nemici). 
- **Flusso Utente e Finestre**:
  - **Finestra Principale (`weapons_app.tscn`, `720x520`)**:
    - Selettore gruppi d'arma (*Torrette Laser*, *Siluri Pesanti*, *PDG Difesa di Prossimità*).
    - Radar di puntamento con acquisizione bersagli (Target Lock) e calcolo anticipo di tiro (Lead Indicator).
    - Indicatori di stato munizioni, surriscaldamento canne e stato condensatori di carica.
    - Pulsanti per fuoco manuale, abilitazione fuoco difensivo automatico PDG e scarico termico d'emergenza.
    - Finestra della telecamera che indica a cosa sta puntando la torretta.
    - Finestra di puntamento manuale
- **Ruolo Assegnato**: **Soldato** (Controllo completo su fuoco, lock e gestione munizioni; Capitano/Factotum hanno override; Pilota e Ingegnere possono solo visualizzare lo stato di carica/munizioni).
- **Integrazione con i Sublayer e la Rete Elettrica**:
  - **Sublayer 3 (Rete Elettrica)**: Le torrette laser e i caricatori siluri assorbono picchi di potenza elevati (fino a 250 MW). Se l'Ingegnere taglia potenza all'Armeria (`armory_defense`), la velocità di ricarica si azzera o le torrette vanno offline.
  - **Sublayer 4 (Danni)**: Impatti all'armeria o alle torrette provocano inceppamenti, dispersione di fuoco o surriscaldamento critico.
  - **Sublayer 5 & Cams**: Puntamento sincronizzato con i canali visivi delle telecamere esterne CCTV.
- **Configurazione `.DAT` e Meccanica Hackwarfare**:
  - **Percorso Cartella Protetta**: `Ship Drive/Programs/Weapons/` (Password debug: `WEAP-7815`).
  - **File di Configurazione Attivi**:
    - `weapons_config.dat`: parametri operativi (`max_range=4500.0`, `fire_rate=1.8`, `cooling_rate=0.75`, `auto_pdg_enabled=true`).
    - `ammo_tuning.dat`: balistica e tracking (`torpedo_velocity=85.0`, `auto_lead_tracking=true`, `overclock_damage_mult=1.0`).
  - **Manomissione Firmware Clandestina**: L'Hacker può eseguire exploit sui file `.dat` delle armi per sbloccare la cadenza di tiro e il danno oltre i limiti di fabbrica (overclock illegale), al prezzo di un incremento drastico del calore generato e del rischio di detonazione interna del siluro.

---

### 5.2 Nuova Feature 2: Long-Range Sensor Array & Tactical Map (`Applications/Sensors`)
- **Descrizione**: Sistema di scansione e telemetria subspaziale a lungo raggio per mappare corpi celesti, campi di asteroidi, stazioni orbitali, navi nemiche e relitti derelitti fino a 50 km di distanza.
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
- **Configurazione `.DAT` e Meccanica Hackwarfare**:
  - **Percorso Cartella Protetta**: `Ship Drive/Programs/Sensors/` (Password debug: `SENS-7815`).
  - **File di Configurazione Attivi**:
    - `sensors_config.dat`: frequenza e sensibilità (`sweep_frequency_hz=12.0`, `active_ping_radius=50000.0`, `noise_filter=0.92`).
    - `radar_tuning.dat`: calibrazione filtri e IFF (`spectrum_sensitivity=1.0`, `iff_auto_tag=true`, `stealth_detection_threshold=0.35`).
  - **Manomissione Firmware Clandestina**: Modificare clandestinamente `radar_tuning.dat` consente di abbattere i filtri di rumore per rilevare vascelli stealth o relitti mimetizzati, ma rende i sensori estremamente vulnerabili al jamming da parte di stazioni pirata.

---

### 5.3 Nuova Feature 3: Shield Matrix & Hull Deflectors (`Applications/ShieldMatrix`) [SVILUPPATA]
- **Stato di Sviluppo**: **Completata e Integrata** (conforme ad `APP_ARCHITECTURE_STANDARD.md`, registrata in `ShipBlueprint` con suite di test headless `tests/test_shield_matrix.tscn`).
- **Descrizione**: Gestione e distribuzione dinamica della barriera deflettente energetica della nave, suddivisa in 4 quadranti indipendenti (**Prua**, **Poppa**, **Babordo**, **Tribordo**).
- **Flusso Utente e Finestre**:
  - **Finestra Principale (`shield_matrix_app.tscn`, `620x460`)**:
    - Visualizzatore olografico della corvetta con rendering wireframe, archi scudo dinamici e barre di integrità e stato energetico per ciascuno dei 4 quadranti.
    - Pad direzionale / Vector Slider 2D e cursori ratio individuali per sbilanciare e concentrare l'energia difensiva verso la direzione d'impatto con normalizzazione automatica (somma 100%).
    - Pulsante "Ricarica Rapida d'Emergenza": convoglia un boost immediato di ripristino scudi al costo di un picco di assorbimento da 80-120 MW dalla rete elettrica con cooldown attivo.
    - Interruttore di sincronizzazione frequenza di fase (deflection harmonics a 440.0 Hz).
    - Pulsante "🔄 Ricarica .DAT" per hot-reloading manuale e visualizzazione dello stato firmware.
- **Ruolo Assegnato**: **Ingegnere** (Controllo totale sul bilanciamento e sulla ricarica; Capitano in override; Pilota e Soldato in sola visualizzazione telemetrica).
- **Integrazione con i Sublayer**:
  - **Sublayer 3 (Rete Elettrica)**: L'emettitore scudi (`shields_deflector`) è un'utenza primaria ad alto consumo continuo. La perdita di potenza causa il decadimento rapido della matrice.
  - **Sublayer 4 (Danni)**: Danni all'emettitore o agli anelli di collimazione riducono la capacità massima del quadrante interessato e degradano la tenuta.
  - **Sublayer 5 (Drive Files)**: Cartella protetta `Ship Drive/Programs/ShieldMatrix/` (Password debug: `SHLD-7815`).
  - **Sublayer 6 (Mainframe Apps)**: Registrata in `ShipBlueprint` con visibilità nel menu Start per Ingegnere, Capitano e Factotum.
- **Configurazione `.DAT` e Meccanica Hackwarfare**:
  - **Percorso Cartella Protetta**: `Ship Drive/Programs/ShieldMatrix/` (Password debug: `SHLD-7815`).
  - **File di Configurazione Attivi**:
    - `shields_config.dat`: capacità e rigenerazione (`max_capacity_per_quadrant=250.0`, `recharge_rate_per_sec=15.0`, `overload_limit=1.3`).
    - `deflector_tuning.dat`: matrice armonica (`harmonic_frequency=440.0`, `emergency_boost_multiplier=2.5`, `overclock_absorption=1.0`).
  - **Manomissione Firmware Clandestina**: Un firmware exploit su `deflector_tuning.dat` può incrementare l'assorbimento d'urto fino al 150%, ma se la frequenza armonica collassa durante un impatto energetico, provoca un arco voltaico che danneggia direttamente il generatore nel Sublayer 3.

---

### 5.4 Nuova Feature 4: Communications, Electronic Warfare & Hackwarfare (`Applications/Comms`)
- **Descrizione**: Suite integrata per comunicazioni subspaziali radio, ricezione di richieste di soccorso (SOS) da relitti o colonie, contromisure di guerra elettronica (Electronic Warfare - Jamming) e strumenti di intrusione/decodifica crittografica (Hackwarfare).
- **Flusso Utente e Finestre**:
  - **Finestra Principale (`comms_app.tscn`, `680x480`)**:
    - Sintonizzatore frequenze radio RF/subspaziali con visualizzatore a cascata di spettro (Waterfall Display) per intercettare trasmissioni nascoste.
    - Modulo **Guerra Elettronica (Jamming & Spoofing)**: emissione di segnali di disturbo per accecare i radar di navi nemiche, deviare missili a guida radar e falsificare i transponder IFF della corvetta.
    - Modulo **Hackwarfare & Cifrari**: mini-gioco diegetico a riga di comando o a blocchi per la decodifica di pacchetti crittografati recuperati da droni o sonde spaziali, utile per estrarre password di cartelle protette (`.dat`) su navi nemiche e stazioni abbandonate.
    - Registro messaggi in arrivo e ordini della corporazione.
- **Ruolo Assegnato**: **Hacker** (Gestione offensiva EW, decodifica e hacking remoto) e **Capitano** (Comunicazioni diplomatiche, gestione canali ufficiali e patti di non aggressione).
- **Integrazione con i Sublayer**:
  - **Sublayer 3 (Rete Elettrica)**: L'antenna e i trasmettitori EW (`comms_ew`) richiedono energia modulabile in base alla potenza di disturbo erogata (da 50 a 180 MW).
  - **Sublayer 5 (Ship Drive)**: Il modulo di decodifica salva direttamente i file e le password recuperate nello storage virtuale della nave per consentire all'equipaggio di consultarle.
- **Configurazione `.DAT` e Meccanica Hackwarfare**:
  - **Percorso Cartella Protetta**: `Ship Drive/Programs/Comms/` (Password debug: `COMM-7815`).
  - **File di Configurazione Attivi**:
    - `comms_config.dat`: larghezza di banda e segnale (`bandwidth_hz=1420.0`, `decryption_speed_multiplier=1.0`, `subspace_relay_active=true`).
    - `crypto_tuning.dat`: contromisure e jamming (`jamming_power_mw=120.0`, `signal_noise_ratio=0.85`, `spoofing_signature=CORVETTE_CIVILIAN`).
  - **Manomissione Firmware Clandestina**: L'Hacker può modificare `crypto_tuning.dat` per potenziare il raggio di jamming oltre le specifiche legali, consentendo di mandare in blackout i sistemi di comunicazione di un'intera stazione commerciale pirata.

---

### 5.5 Nuova Feature 5: Life Support & Atmosphere Control (`Applications/LifeSupport`)
- **Descrizione**: Monitoraggio telemetrico e controllo attivo dei parametri vitali (percentuale di O2, accumulo di CO2, pressione barometrica, temperatura e presenza di focolai d'incendio) per ciascuna stanza e compartimento della nave.
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
- **Configurazione `.DAT` e Meccanica Hackwarfare**:
  - **Percorso Cartella Protetta**: `Ship Drive/Programs/LifeSupport/` (Password debug: `LIFE-7815`).
  - **File di Configurazione Attivi**:
    - `life_support_config.dat`: tassi di ricircolo (`o2_generation_rate=1.2`, `seal_door_speed=0.5`, `auto_fire_suppress=false`).
    - `atmo_tuning.dat`: soglie e pressioni (`decompression_rate=1.8`, `fire_suppression_co2_level=0.45`, `scrubber_efficiency=0.98`).
  - **Manomissione Firmware Clandestina**: Manomettere `life_support_config.dat` permette di tagliare l'alimentazione del supporto vitale nei settori non presidiati per deviare energia supplementare ai motori o agli scudi (tattica disperata di sopravvivenza).

---

### 5.6 Nuova Feature 6: Mission Logbook & Tactical Objectives (`Applications/Logbook`)
- **Descrizione**: Registro di bordo ufficiale, diario delle operazioni di volo, monitoraggio dei contratti sandbox per "continuare a volare" (es. trasporto merci di contrabbando, riparazione relitti, estrazione minerali rari) e archivio note personali dell'equipaggio.
- **Flusso Utente e Finestre**:
  - **Finestra Principale (`logbook_app.tscn`, `560x420`)**:
    - **Scheda Contratti & Obiettivi**: lista delle missioni attive con tracker di avanzamento, ricompense in crediti e penalità di ritardo.
    - **Scheda Scatola Nera (Event Log)**: storico telemetrico generato automaticamente dal sistema operativo (es. "[14:22] Impatto meteorite a prua", "[14:23] Allarme incendio Sala Motori", "[14:25] Frequenza jamming nemica rilevata").
    - **Scheda Diario Personale / Note di Plancia**: editor testuale diegetico per annotare coordinate di relitti scoperti, codici di decodifica o istruzioni operative, con possibilità di salvare su `Ship Drive` (condiviso) o `Terminal Drive` (locale/privato).
- **Ruolo Assegnato**: **Tutti i Ruoli** (Il Capitano ha i permessi di spuntare o riassegnare i contratti; tutti i membri dell'equipaggio possono leggere e inserire annotazioni di registro).
- **Integrazione con i Sublayer e la Sessione**:
  - Sincronizzato con il loop di gioco persistente: i contratti completati alimentano il fondo cassa comune della nave per acquisto ricambi, munizioni e carburante.
- **Configurazione `.DAT` e Meccanica Hackwarfare**:
  - **Percorso Cartella Protetta**: `Ship Drive/Programs/Logbook/` (Password debug: `LOGS-7815`).
  - **File di Configurazione Attivi**:
    - `logbook_config.dat`: impostazioni registro (`auto_log_events=true`, `max_history_entries=200`, `log_telemetry_errors=true`).
    - `journal_tuning.dat`: sincronizzazione drive (`sync_to_ship_drive=true`, `timestamp_format=STAR_DATE`, `cloud_backup=false`).
  - **Manomissione Firmware Clandestina**: L'Hacker può falsificare le registrazioni della scatola nera su `logbook_config.dat` per cancellare le prove di contrabbando o manomissioni illegali prima di attraccare a una stazione governativa.

---

### 5.7 Nuova Feature 7: System Diagnostics, Cyber Security & ICE Defense (`Applications/Diagnostics`)
- **Descrizione**: Centro di sicurezza informatica e manutenzione logica di bordo per eseguire scansioni d'integrità dei drive, ripulire infezioni da malware/trojan contratti scaricando dati da relitti infetti, gestire contromisure ICE (Intrusion Countermeasure Electronics) e ripristinare configurazioni `.dat` danneggiate.
- **Flusso Utente e Finestre**:
  - **Finestra Principale (`diagnostics_app.tscn`, `640x450`)**:
    - **Scanner Integrità Drive**: avvio scansione rapida o profonda su `Ship Drive` e `Terminal Drive` con barra di scansione diegetica e lista delle minacce rilevate (es. "Crypto-Miner clandestino", "Worm corporativo", "Firmware .DAT corrotto").
    - **Pannello ICE & Firewall**: gestione nodi difensivi per bloccare intrusioni nemiche in tempo reale durante i combattimenti informatici (Hackwarfare).
    - **Pulsante "Factory Reset Firmware"**: ripristina istantaneamente i file di configurazione `.dat` di un sottosistema ai valori di fabbrica standard, ripulendo overclock instabili o corruzioni logiche.
- **Ruolo Assegnato**: **Hacker** / **Ingegnere** (Pieno controllo; Capitano in override).
- **Integrazione con i Sublayer**:
  - Monitora lo stato di integrità di Sublayer 5 (Drive Files) e Sublayer 6 (Applicazioni Mainframe).
  - Connesso a `FolderPasswordManager` e `ShipDriveManager` per rilevare violazioni di cartelle protette o iniezioni anomale di file eseguibili.
- **Configurazione `.DAT` e Meccanica Hackwarfare**:
  - **Percorso Cartella Protetta**: `Ship Drive/Programs/Diagnostics/` (Password debug: `DIAG-7815`).
  - **File di Configurazione Attivi**:
    - `diagnostics_config.dat`: parametri scanner (`scan_depth=DEEP`, `auto_quarantine_malware=true`, `alert_sound=true`).
    - `security_tuning.dat`: barriere ICE (`ice_firewall_strength=100.0`, `factory_reset_delay_sec=3.0`, `tamper_detection_level=HIGH`).
  - **Manomissione Firmware Clandestina**: Modificando `security_tuning.dat`, un Hacker esperto può disattivare il controllo di integrità interno (tamper detection) per consentire all'equipaggio di installare overclock estremi sui motori o sulle armi senza far scattare gli allarmi di sistema del mainframe.

---

## 6. Schema Architetturale di Riferimento per Nuove App

Ogni nuova applicazione pianificata nella Roadmap deve rispettare rigorosamente il modello architetturale definito in [`docs/APP_ARCHITECTURE_STANDARD.md`](APP_ARCHITECTURE_STANDARD.md):

```text
Applications/NomeApplicazione/
├── nome_app.tscn           # Scena UI (Control) con %DisconnectedOverlay
├── nome_app.gd             # Controller con parsing .DAT, hot-reloading e RBAC
├── Componenti/             # Sotto-scene, widget modulari o finestre figlie
└── tests/test_nome_app.gd  # Test headless per verificare overlay offline/online, RBAC e .DAT
```

### Regole Vincolanti per lo Sviluppo:
1. **Branch Dedicato**: Creare e utilizzare sempre il branch `applications/[NomeApp]` prima di apportare modifiche (es. `applications/Weapons`).
2. **Ciclo di Vita e Overlay Offline**: Tutte le applicazioni della nave devono includere il nodo `%DisconnectedOverlay` ed essere disabilitate prima del decollo (`not SpaceWorldManager.is_ship_connected()`).
3. **Cartella Protetta e File `.dat`**:
   - Salvataggio in `Ship Drive/Programs/[NomeApp]/` con password predefinita dal Cheat-Sheet Master (Sezione 2.6).
   - Utilizzo del metodo standard `_parse_dat_file()` per il parsing INI con type-casting.
   - Iscrizione al segnale `ShipDriveManager.file_written` per supportare l'**Hot-Reloading** immediato dei parametri a runtime.
4. **Adattamento Dimensionale**: Impostare `custom_minimum_size` calibrata senza sbordamenti oltre i confini della finestra, con layout reattivo (`Anchors` e `Containers`).
5. **Integrazione con `ShipBlueprint` (Sublayer 6)**:
   - Registrazione dell'applicazione nel catalogo `installed_apps` della blueprint con ID, titolo, icona e array dei ruoli autorizzati (`roles`).
   - Popolamento dinamico nel menu Start di GodotOS all'evento `start_mission()`, visualizzando solo le app consentite per il ruolo del giocatore locale.
6. **Protezione Diegetica e Hackwarfare**:
   - I file `.dat` non sono leggibili né modificabili via `cat` o text editor standard (blocco per file binari/protetti).
   - Qualsiasi modifica clandestina deve avvenire tramite le meccaniche dedicate dell'Hacker o del modulo Diagnostics.
7. **Suite di Test Headless**:
   - Creazione del test in `tests/test_[nome_app].gd` che verifichi:
     - Overlay visibile in stato disconnesso / offline.
     - Sblocco e reattività in stato connesso (`start_mission()`).
     - Rispetto dei permessi RBAC (azioni consentite per il ruolo assegnato e bloccate/in sola lettura per gli altri).
     - Caricamento e aggiornamento dei parametri `.dat`.

---

## 7. Conclusioni e Riepilogo

Il presente documento fornisce la visione completa, organica e integrata di *Dark Nova: Rogue Squadron*. 

Attraverso la combinazione dell'atmosfera di frontiera in stile *Firefly*, della satira *Freemium-punk*, dell'interfaccia diegetica a finestre su **GodotOS** e della rigida matrice di cooperazione asimmetrica tra i 6 ruoli dell'equipaggio (**Capitano**, **Pilota**, **Soldato**, **Ingegnere**, **Hacker**, **Factotum**), il gioco garantisce un gameplay sandbox dinamico, teso e profondo.

L'ecosistema complessivo delle 11 applicazioni della corvetta (4 esistenti + 7 pianificate nella roadmap), alimentato dai 6 sottolivelli della `ShipBlueprint` e protetto dall'architettura firmware `.dat` con meccaniche di Hackwarfare, pone le basi per un'esperienza cooperativa solida, scalabile e rigorosamente conforme agli standard tecnici di progetto.
