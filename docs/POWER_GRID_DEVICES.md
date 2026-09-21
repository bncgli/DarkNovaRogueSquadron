# Specifiche Dispositivi di Bordo & Impatto Disattivazione Power Grid
# Dark Nova: Rogue Squadron

> **Scopo del Documento**:
> Questo documento definisce la lista ufficiale di tutti i **dispositivi (devices)** installati o installabili a bordo della nave (`ShipBlueprint` / `RoomDatabase`), dettagliando per ciascuno:
> 1. La sua **funzionalità** primaria a bordo;
> 2. Le **azioni operative** che permette di compiere all'equipaggio e ai sistemi di bordo;
> 3. L'elenco completo di **funzionalità, azioni e sistemi che ne risentono** (degrado, blocco o spegnimento) quando il dispositivo viene disattivato o perde alimentazione tramite **Power Grid**.
>
> Il file è strutturato per consentire la revisione e l'aggiornamento diretto da parte del designer prima di procedere con l'implementazione del gameplay.

---

## 1. Matrice Rapida Dispositivi & Sintesi Impatto Energetico

| ID Dispositivo | Nome rappresentativo | Classe Componente | Sottosistema HAL | Stanza / Settore | Categoria | Potenza Nominale | Effetto Critico se OFF |
|---|---|---|---|---|---|---|---|
| `core_reactor` | Reattore Tokamak Primario | `ReactorComponent` | `power` | `reattore_fusione` / `reactor` | `reactor` | **+500 / +1000 MW** | Blackout generale nave se batterie esaurite; blocco Cruise e Hyperdrive |
| `engine_main` | Propulsore a Scarica Ionica | `ThrusterComponent` | `propulsion` | `sala_motori` / `engine` | `propulsion` | **-50..-80 MW** | Perdita spinta longitudinale; disingaggio Cruise Drive; blocco Hyperdrive |
| `rcs_pitch_l` / `r` | Attuatori RCS Babordo / Tribordo | `ThrusterComponent` | `propulsion` | `rcs_left`, `rcs_right` | `propulsion` | **-15 MW cad.** | Perdita rotazione (Pitch/Yaw/Roll) e stabilizzazione; deriva permanente |
| `helm_control` | Consolle Pilotaggio e Plancia | `HelmControlComponent` | `propulsion` | `ponte_comando` / `bridge` | `command` | **-15 MW** | Comandi pilota scollegati dall'HAL; blocco input manuali WASD/QE/Spazio |
| `nav_computer` | Elaboratore Rotte & Salto | `NavComputerComponent` | `navigation` | `ponte_comando` / `bridge` | `command` | **-10 MW** | Impossibile calcolare rotte planetarie; spegnimento vettori salto e waypoint |
| `sensors_matrix` | Matrice Sensori Phased Array | `SensorsMatrixComponent` | `sensors` | `matrice_sensori` / `sensors` | `sensors` | **-25..-120 MW** | Radar cieco (0 blip); blocco ping attivo 2km; perdita tracking armi |
| `antenna_array` | Antenna Transceiver Sub-Spazio | `AntennaArrayComponent` | `comms` | `comunicazioni` / `comms` | `comms` | **-15..-65 MW** | Blocco richieste attracco stazioni; waterfall muta; nessun link EW |
| `armory_defense` | Alimentazione Armeria & Torrette | `ArmoryDefenseComponent` | `defense` | `armamenti` / `armory` | `tactical` | **-30..-250 MW** | Laser scarichi; servomeccanismi torretta bloccati; stop lancio missili |
| `arm_sx/dx_balancer` | Bilanciatori Scudi Deflettori | `ShieldBalancerComponent` | `defense` | `armatura_adattiva` / `14..15` | `defense` | **-10..-90 MW** | Collasso rigenerazione scudi; rapido decadimento a 0 HP; stop deflettori |
| `scrubber` | Filtro CO2 Primario (Scrubber) | `LifeSupportComponent` | `life_support` | `supporto_vitale` / `11` | `life_support` | **-10 MW** | Tossicità e accumulo rapido CO2; caduta purezza O2; asfissia equipaggio |
| `heater` | Caldaia Termoregolatrice | `LifeSupportComponent` | `life_support` | `supporto_vitale` / `11` | `life_support` | **-10 MW** | Temperatura cabina sotto zero; ipotermia; congelamento condotti e merci |
| `serra_idroponica` | Serra Idroponica O2/Biologica | `LifeSupportComponent` | `life_support` | `supporto_vitale` / `11` | `life_support` | **-15 MW** | Perdita rigenerazione continua biologica O2; deperimento delle colture |
| `cargo_handling` | Manipolatore Stiva & Portelloni | `CargoHandlingComponent` | `cargo` | `baia_carico` / `cargo` | `cargo` | **-10 MW** | Portelloni stiva bloccati; impossibile espellere o stivare; stop raffinatore |
| `dronestation` | Baia Ricarica Drone EVA Esterno | `DroneStationComponent` | `cargo` / `service` | `pod_drone` / `13` | `service` | **-10..-30 MW** | Drone EVA non si ricarica ad attracco; rischio perdita alla deriva |
| `recharge_dock` | Dock Ricarica Drone Condotti | `RechargeDockComponent` | `cargo` / `service` | `cargo` / `engineering` | `engineering` | **-10 MW** | Drone condotti non si ricarica nella culla; stop riparazioni interne |
| `server_rack` | Server Cyber-Guerra / Mainframe | `ServerRackComponent` | `cyber` | `mainframe` | `cyber` | **-10..-30 MW** | Blocco exploit offensivi; caduta firewall; comandi shell crypto disabilitati |
| `cooling_01` | Radiatore Criogenico | `CoolingComponent` | `power` | `engine_room` / `motori` | `engineering` | **-20 MW** | Accumulo termico; surriscaldamento esponenziale e scram forzato |
| `battery_01` | Banco Batterie d'Emergenza | `BatteryComponent` | `power` | `engine_room` / `reattore` | `engineering` | **Buffer 500 MJ** | Assenza riserva tampone; blackout istantaneo su sbalzi di carico |
| `cam_array` | Array Telecamere Esterne & Fari | `CamArrayComponent` | `optics` | `bridge` / Scafo | `sensors` | **-5..-15 MW** | Schermi Cams su 'NO SIGNAL'; spegnimento fari esterni; perdita visuale |

---

## 2. Schede Dettagliate per Dispositivo

---

### 2.1 Reattore a Fusione Tokamak Primario
- **ID Dispositivo**: `core_reactor` (o `reactor_01`)
- **Stanza / Settore**: `engine_room`
- **Categoria Power Grid**: `reactor`
- **Potenza Erogata**: `+500.0 MW` nominali (fino a `+1000.0 MW` su modelli pesanti)
- **Funzionalità (Scopo a bordo)**:
  - Cuore energetico principale della nave stellare.
  - Genera l'energia elettrica a fusione magnetica distribuita attraverso la rete di condotti (`Power Grid`) a tutti i sottosistemi di bordo.
  - Sostiene il fabbisogno ad alta tensione dei motori a ioni, degli scudi deflettori, dei condensatori d'armamento e dei sistemi di supporto vitale.
- **Azioni che può fare**:
  - Erogazione continua e bilanciamento della potenza erogata.
  - Modulazione output percentuale da terminale `/sys/rooms/reactor/power_target` o cursore `PowerGridApp`.
  - Assorbimento del picco transitorio di `160 MW` richiesto per il warmup del Cruise Drive.
  - Procedura di Scram / Spegnimento di emergenza e isolamento del nocciolo plasma.
- **Funzionalità & Azioni che ne risentono se DISATTIVATO da Power Grid**:
  - **Blackout Totale / Transito a Batterie**: L'intera nave perde la sorgente principale di energia. Se il banco batterie (`battery_01`) non è carico o attivo, l'intera nave entra in blackout immediato.
  - **Arresto Cruise Drive e Hyperdrive**: Impossibile avviare la sequenza di warmup del Cruise Drive (richiede 160 MW garantiti per 4s) o caricare l'Iperdrive.

---

### 2.2 Propulsore Principale a Scarica Ionica
- **ID Dispositivo**: `engine_main` (o `thruster_01`, `thruster_02`)
- **Stanza / Settore**: `sala_motori` / `engine` (o `engine_room`)
- **Categoria Power Grid**: `propulsion`
- **Potenza Assorbita**: `-50.0 MW` a `-80.0 MW` base (fino a `-120.0 MW` a massima spinta)
- **Funzionalità (Scopo a bordo)**:
  - Genera la spinta longitudinale primaria lungo l'asse della nave (asse Z: avanti/indietro).
  - Determina la velocità sub-luce ordinaria e consente l'attivazione della propulsione di crociera (Cruise Drive a 160 m/s).
- **Azioni che può fare**:
  - Accelerazione lineare in avanti (tasto `W`) e retromarcia (tasto `S`).
  - Regolazione fine del speed limiter (tasti `R` per incrementare, `F` per ridurre).
  - Ingaggio Cruise Drive (`CruiseToggleButton`) per accelerare a x8.0 della velocità massima.
  - Erogazione spinta di inserimento nel corridoio Hyperdrive.
- **Funzionalità & Azioni che ne risentono se DISATTIVATO da Power Grid**:
  - **Blocco Tasti WASD di Traslazione**: I comandi `W`, `S`, `R`, `F` in `FlightControlApp` cessano di generare spinta.
  - **Disattivazione Immediata Cruise Drive**: Se il Cruise Drive è in corso, si disinnesta all'istante con errore `CRUISE DISENGAGED: PROPULSION POWER LOSS`.
  - **Blocco Salto Iperspaziale**: Il salto con l'Hyperdrive non può essere effettuato per assenza del vettore di spinta vettoriale necessario.
  - **Deriva Inerziale Incontrollata**: Senza propulsore principale, la nave mantiene la velocità residua per inerzia e non può frenare l'avanzamento longitudinale.
  - **Badge FlightControl**: Il badge dei propulsori passa su `OFFLINE - NO POWER`.
- **Comandi terminale**:
  - **cruise_mode start/stop**: attiva e disattiva il Cruise Drive.
  - **toggle_inertia on/off**: attiva e disattiva l'inerzia.
  - **set_speed x**: Imposta lo speed limiter della nave a `x` va da 0.1 a 2.0.
  - **forward x** move the ship forward by `x` m/s (clamp to max_speed).
  - **backward x** move the ship backward by `x` m/s (clamp to max_speed).

---

### 2.3 Attuatori RCS Babordo e Tribordo
- **ID Dispositivo**: `rcs_pitch_l` (Babordo), `rcs_pitch_r` (Tribordo)
- **Stanza / Settore**: `rcs_left`, `rcs_right`
- **Categoria Power Grid**: `propulsion`
- **Potenza Assorbita**: `-15.0 MW` ciascuno (totale `-30.0 MW`)
- **Funzionalità (Scopo a bordo)**:
  - Sistema di manovra a reazione vettoriale (Reaction Control System) per il controllo dei 3 assi di rotazione e delle traslazioni ortogonali.
  - Gestione della stabilizzazione automatica (smorzamento inerziale / Inertia Damping).
- **Azioni che può fare**:
  - Rotazione di Beccheggio/Pitch (frecce `Su`/`Giù`), Imbardata/Yaw (frecce `Sinistra`/`Destra`) e Rollio/Roll (tasti `Q`/`E`).
  - Traslazione laterale (tasti `A`/`D`) e traslazione verticale (tasto `Spazio` quota, `Ctrl` discesa).
  - Stabilizzazione d'inerzia automatica (`Inertia Toggle`).
  - Allineamento automatico al vettore Hyperdrive (`align_to_hyperdrive_vector`).
- **Funzionalità & Azioni che ne risentono se DISATTIVATI da Power Grid**:
  - **Perdita Totale Orientamento 3D**: La nave non risponde più ai comandi di rotazione (Q/E, frecce) e traslazione laterale (A/D, Spazio/Ctrl).
  - **Asimmetria se disattivato un solo lato**: Se viene spento solo Babordo o Tribordo, la nave subisce torsioni involontarie durante qualsiasi manovra e può ruotare solo verso un lato.
  - **Deriva Angolare Permanente**: Se colpita da proiettili, onde d'urto o impatti con asteroidi, la nave continua a piroettare nello spazio senza poter frenare la rotazione.
  - **Blocco Sequenza Salto Hyperdrive**: Impossibile orientare la prua verso il vettore di salto entro i 3.0° di tolleranza richiesti.
- **Comandi terminale**:
  - **set_speed x**: Imposta lo speed limiter della nave a `x` va da 0.1 a 2.0.
  - **rotate x y z**: Rotazione della nave attorno agli assi X, Y, Z.
  - **rotate_to x y z**: Orienta la nave verso il vettore specificato.
  - **slide x y**: Traslazione laterale della nave lungo gli assi X e Y in m/s.

---

### 2.4 Consolle di Pilotaggio e Plancia Comando
- **ID Dispositivo**: `helm_control` (o `pod_piloti`)
- **Stanza / Settore**: `ponte_comando` / `bridge`
- **Categoria Power Grid**: `command`
- **Potenza Assorbita**: `-15.0 MW`
- **Funzionalità (Scopo a bordo)**:
  - Hub diegetico di controllo tra la postazione fisica del Pilota e l'Hardware Abstraction Layer (`ShipHAL`).
  - Riceve gli input da tastiera, mouse e gamepad e li converte in istruzioni di manovra per i controller dei motori.
- **Azioni che può fare**:
  - Abilitazione/disabilitazione del controllo manuale del volo (`can_control_flight`).
  - Inoltro degli input di timone e manetta ai propulsori e agli attuatori RCS.
  - Commutazione modalità di navigazione (Inerziale On/Off, Cruise Drive, Allineamento automatico).
- **Funzionalità & Azioni che ne risentono se DISATTIVATO da Power Grid**:
  - **Controlli Volo Disconnessi**: In `FlightControlApp`, `can_control_flight` diventa `false`. Tutti i comandi del pilota vengono ignorati.
  - **Overlay di Sistema**: La finestra di pilotaggio mostra l'avviso di assenza connessione/alimentazione consolle (`COMMAND CONSOLE UNPOWERED`).
  - **Impossibile Disattivare/Attivare Inerzia**: I toggle di plancia non rispondono.

---

### 2.5 Elaboratore Rotte e Calcolo Salto
- **ID Dispositivo**: `nav_computer`
- **Stanza / Settore**: `ponte_comando` / `bridge`
- **Categoria Power Grid**: `command`
- **Potenza Assorbita**: `-10.0 MW`
- **Funzionalità (Scopo a bordo)**:
  - Computer dedicato al calcolo delle traiettorie orbitali nel sistema stellare e delle coordinate per il salto iperuranico.
  - Elabora la previsione dei coni d'ombra planetari rispetto alla stella centrale per la protezione dalle tempeste solari.
- **Azioni che può fare**:
  - Calcolo rotta interplanetaria su `SystemMapApp` (sequenza 3-5 secondi).
  - Determinazione del vettore di salto e rotta Hyperdrive per `FlightControlApp`.
  - Calcolo e visualizzazione dei cerchi di intercettazione orbitale e coni d'ombra planetari.
  - Generazione dei Waypoint di missione visibili sull'HUD e sul radar sensori.
- **Funzionalità & Azioni che ne risentono se DISATTIVATO da Power Grid**:
  - **Blocco Calcolo Rotta**: Il pulsante "Calcola Rotta" in `SystemMapApp` fallisce con errore `NAV COMPUTER OFFLINE`.
  - **Scomparsa Coni d'Ombra**: I coni di protezione solare proiettati dai corpi celesti scompaiono dalla mappa.
  - **Scomparsa Waypoint Navigazione**: I marcatori dei waypoint sull'HUD del pilota e sul radar si spengono.
  - **Blocco Iperdrive**: Il salto iperuranico non può essere ingaggiato mancando i dati vettoriali di destinazione.
- **Comandi terminale**:
  - **position**: restituisce la posizione attuale della nave nel quadrante corrente.
  - **calculate x y**: Calcola la rotta diretta verso il quadrante (x,y).

---

### 2.6 Matrice Sensori Phased Array
- **ID Dispositivo**: `sensors_matrix` (o `array_sensori`)
- **Stanza / Settore**: `matrice_sensori` / `sensors`
- **Categoria Power Grid**: `sensors`
- **Potenza Assorbita**: `-25.0 MW` base (fino a `-40.0 MW` in sweep, `-120.0 MW` per Ping attivo)
- **Funzionalità (Scopo a bordo)**:
  - Scansione volumetrica 3D dello spazio circostante la corvetta.
  - Tracciamento passivo delle emissioni radar, termiche e gravitazionali.
  - Rilevamento di navi nemiche, relitti, asteroidi e pericoli ambientali.
- **Azioni che può fare**:
  - Sweep radar passivo a 360° con raggio di `1000 m` (1 km).
  - Emissione di Ping Attivo ad alta frequenza con portata estesa a `2000 m` (2 km).
  - Ricezione del feed telemetrico dalle Sonde (Probe) lanciate nello spazio.
  - Fornitura della lista bersagli tracciati con distanza, orientamento ed elevazione per `WeaponsApp`.
  - Monitoraggio anticipato dei fronti di tempesta solare (CME) o impulsi ionici (EMP).
- **Funzionalità & Azioni che ne risentono se DISATTIVATO da Power Grid**:
  - **Cecità Radar Totale**: Lo schermo di `SensorsApp` diventa nero (`STATO RADAR: OFFLINE - RETE ELETTRICA`). Tutti i blip dei contatti spariscono.
  - **Blocco Ping Attivo**: L'azione di ping omnidirezionale è disabilitata (`can_consume_power(120 MW) = false`).
  - **Impossibilità di Aggancio Bersagli Armi**: In `WeaponsApp` scompare la lista bersagli; l'aggancio missilistico (`Missile Lock`) non può essere agganciato.
  - **Perdita Rilevamento Sonda**: Il radar secondario della sonda telemetrica non può trasmettere i contatti a bordo.
  - **Nessun Allarme Tempeste Spaziali**: Nessun preavviso per pericoli dinamici di settore; la nave entra in aree di tempesta senza telemetria di avviso.
- **Comandi terminale**:
  - **swipe on/off**: Attiva e disattiva la rotazione dell'antenna.
  - **get_targets**: Restituisce la lista di tutto quello che è visibile nello scanner
  - **get_probe_targets <probe id>**: Restituisce la lista di tutti i bersagli visibili dalla sonda telemetrica.

---

### 2.7 Antenna Tranceiver e Array Comunicazioni Sub-Spazio
- **ID Dispositivo**: `antenna_array` (o `matrice_comunicazione`)
- **Stanza / Settore**: `comunicazioni` / `comms`
- **Categoria Power Grid**: `comms`
- **Potenza Assorbita**: `-15.0 MW` base (fino a `-50.0 MW` in trasmissione, `-65.0 MW` con rotazione attiva)
- **Funzionalità (Scopo a bordo)**:
  - Antenna parabolica/phased array orientabile per comunicazioni radio a lungo raggio e banda ultralarga.
  - Ricezione frequenze di settore, canali criptati, corrieri dati S-Net (1920 MHz) e segnali di soccorso relitti.
  - Aggancio di fasci dati stabili per guerra elettronica (EW Link).
- **Azioni che può fare**:
  - Rotazione orientata dell'antenna (0-360°) manuale o in scansione continua.
  - Sintonizzazione frequenze radio/sub-spazio e aggancio automatico su segnali con SNR favorevole.
  - Invio e ricezione richieste di attracco (Docking Request) alle stazioni spaziali.
  - Stabilizzazione del fascio dati "CONNECT" per montare il `Target Drive` remoto sul desktop di GodotOS.
- **Funzionalità & Azioni che ne risentono se DISATTIVATO da Power Grid**:
  - **Muto Radio Totale**: Lo spettrogramma e la waterfall di `CommsApp` si azzerano; nessun segnale audio o testo può essere captato.
  - **Blocco Totale Applicazione HackExploits**: Senza segnale EW attivo, non è possibile montare l'unità disco bersaglio `Target Drive`. Tutti gli exploit (`spammer`, `blind_eye`, `8loops`, `gout`, `dump_vault`) risultano inutilizzabili.
  - **Nessuna Intercettazione S-Net o Relitti**: Impossibile captare corrieri dati o localizzare relitti spaziali tramite frequenza SOS.
- **Comandi terminale**:
  - **rotate x**: Rotazione orientata dell'antenna (0-360°) manuale o in scansione continua.
  - **scan on/off**: Attiva e disattiva la scansione automatica dell'antenna.
  - **get_frequency**: Restituisce la lista di tutte le frequenze visibili dallo scanner
  - **lock_frequency <frequency>**: Blocca la frequenza specificata per la scansione automatica.
  - **listen_frequency <frequency>**: Trascrive i messaggi della frequenza specificata rimane in lettura fino a che non viene bloccata premendo q. i messaggi ricevuti arrivano in tempi diversi stile radio
---

### 2.8 Sistemi Alimentazione Armeria e Torrette
- **ID Dispositivo**: `armory_defense` (o `gestore_torrette`)
- **Stanza / Settore**: `armamenti` / `armory`
- **Categoria Power Grid**: `weapons` (o `tactical`)
- **Potenza Assorbita**: `-30.0 MW` base (fino a `-250.0 MW` durante la ricarica delle armi)
- **Funzionalità (Scopo a bordo)**:
  - Banco di potenza dedicato al funzionamento della torretta esterna della corvetta.
  - Alimenta il servomeccanismo giroscopico di puntamento, i solenoidi di sparo balistico e i condensatori laser.
  - Il sistema di torrette automatico che viene chiamato ShieldMatrix
- **Azioni che può fare**:
  - Puntamento fluido della torretta con cattura del cursore mouse (tasto `Spazio`).
  - Sparo cannone rotante balistico (`Heavy MG`) e cannone pesante cinetico (`Heavy Cannon`).
  - Ricarica e sparo del proiettore laser a scarica continua (`Laser Burst`).
  - Lancio missili a guida radar e rilascio sonde telemetriche (`Probe`).
  - Azionamento della procedura di sfiato termico d'emergenza (`Emergency Venting`).
- **Funzionalità & Azioni che ne risentono se DISATTIVATO da Power Grid**:
  - **Blocco Ricarica Laser**: I condensatori del laser non ricevono energia; la carica laser si blocca o decade a zero.
  - **Blocco Torretta**: I servomotori di orientamento perdono alimentazione e la torretta si blocca sul punto morto o risponde con estrema lentezza.
  - **Mancata Alimentazione Munizioni**: Gli attuatori pneumatici/elettrici dei nastri balistici non funzionano; sparo disabilitato.
  - **Blocco Lancio Missili e Sonde**: I tubi di lancio non ricevono il segnale elettrico di consenso al rilascio.
  - **Badge WeaponsApp**: Mostra `⚠️ PWR: 0 MW (OFFLINE)` con blocco dei pulsanti di ingaggio.

---

### 2.9 Orchestratori Servo Motori e Scudi Difensivi
- **ID Dispositivo**: `arm_sx_balancer`, `arm_dx_balancer` (o `sistema_difesa`)
- **Stanza / Settore**: `armatura_adattiva` / `room_14`, `room_15`
- **Categoria Power Grid**: `defense`
- **Potenza Assorbita**: `-10.0 MW` ciascuno a riposo (totale `-90.0 MW` base di rete, fino a `-120.0 MW` in boost)
- **Funzionalità (Scopo a bordo)**:
  - Generano la bolla deflettrice energetica a 4 quadranti (Prua, Poppa, Babordo, Tribordo).
  - Alimentano i sistemi difensivi direzionali (torrette Gatling automatiche anti-siluro e lanciatori Flak Angel-Hair).
- **Azioni che può fare**:
  - Rigenerazione continua dei 4 settori scudo (`15 HP/s` per settore proporzionale al bilanciamento).
  - Ribilanciamento dell'energia sui quadranti tramite Vector Pad in `ShieldMatrixApp`.
  - Attivazione dell'`Emergency Boost` per ripristino istantaneo di `+75 HP` sul settore critico.
  - Sincronizzazione di fase delle frequenze deflettrici (Harmonic Sync).
  - Intercettazione automatica dei missili nemici tramite Gatling e nubi di schegge Flak.
- **Funzionalità & Azioni che ne risentono se DISATTIVATI da Power Grid**:
  - **Collasso Immediato Scudi Deflettori**: La ricarica scudi si arresta; i settori attivi decadono rapidamente per dissipazione passiva (`-25 HP/s`) fino all'azzeramento.
  - **Esposizione Totale dello Scafo**: I proiettili cinetici e i laser colpiscono direttamente l'armatura metallica, provocando brecce, incendi e danni interni ai componenti.
  - **Sistemi Difensivi Direzionali Spenti**: I Gatling di punto e i dispenser Flak rimangono inerti; missili e siluri colpiscono senza contrasto.
  - **Emergency Boost Inutilizzabile**: Il comando di emergenza viene rifiutato per mancanza di alimentazione di rete.
  - **Nessuna Difesa da Radiazioni / Tempeste Solari**: La corvetta non può deflettere la componente particellare delle tempeste solari (CME), subendo danni critici a tutti i circuiti e ai pod.

---

### 2.10 Filtro CO2 Primario / Purificatore Aria
- **ID Dispositivo**: `scrubber` (o `purificatore`)
- **Stanza / Settore**: `supporto_vitale_min`, `supporto_vitale_adv` / `room_11`
- **Categoria Power Grid**: `life_support`
- **Potenza Assorbita**: `-10.0 MW`
- **Funzionalità (Scopo a bordo)**:
  - Reattore chimico rigenerativo per l'assorbimento continuo della CO2 esalata dall'equipaggio e il ricircolo di O2 nell'atmosfera interna delle stanze.
- **Azioni che può fare**:
  - Mantenimento del tasso di CO2 a livelli fisiologici ideali (`0.04%`).
  - Mantenimento del tasso di O2 a livelli standard (`21.0%`).
  - Sovralimentazione selettiva del flusso d'ossigeno in stanze decompresse o sigillate.
  - Iniezione gas inerte per soffocare incendi di bordo tramite `LifeSupportApp`.
- **Funzionalità & Azioni che ne risentono se DISATTIVATO da Power Grid**:
  - **Innalzamento Letale della CO2**: La concentrazione di anidride carbonica sale rapidamente oltre le soglie tossiche (`>1.0%`, fino a `>3.0%`).
  - **Caduta Inesorabile dell'O2**: L'ossigeno libero scende progressivamente sotto il 18% fino a livelli di anossia.
  - **Asfissia e Rantoli in PodInfo**: I membri dell'equipaggio iniziano ad accusare affanno, colpi di tosse udibili, visione periferica oscurata (blackout) e decesso in pochi minuti.
  - **Blocco Sistemi Antincendio a Gas Inerte**: Impossibile pressurizzare le valvole di iniezione gas estinguente nelle stanze in fiamme.

---

### 2.11 Caldaia e Termoregolatore Nave
- **ID Dispositivo**: `heater` (o `caldaia`)
- **Stanza / Settore**: `supporto_vitale_min`, `supporto_vitale_adv` / `room_11`
- **Categoria Power Grid**: `life_support`
- **Potenza Assorbita**: `-10.0 MW`
- **Funzionalità (Scopo a bordo)**:
  - Pompa di calore e scambiatore termico per mantenere la temperatura ambiente interna a `21.0°C`, isolando la cabina dal gelo cosmico dello spazio (`~0 K`).
- **Azioni che può fare**:
  - Regolazione automatica della temperatura di comfort (18-22°C) in tutte le stanze pressurizzate.
  - Riscaldamento rapido di ambienti dopo la chiusura di brecce nello scafo.
  - Protezione termica attiva per tubazioni idrauliche, serbatoi e condotti di servizio.
- **Funzionalità & Azioni che ne risentono se DISATTIVATA da Power Grid**:
  - **Congelamento Rapido Ambienti**: La temperatura interna cala progressivamente verso valori negativi (-10°C, -30°C, fino al congelamento completo).
  - **Ipotermia Equipaggio in PodInfo**: L'equipaggio subisce brividi, battito cardiaco rallentato (bradicardia), tremori violenti, perdita di reattività ai comandi e morte per congelamento.
  - **Ghiaccio nei Condotti**: I condotti di ventilazione del Duct Drone si congelano, riducendo la velocità del drone e bloccando i sensori di fumo.
  - **Deterioramento Carico Stiva**: Le merci liquide e biologiche immagazzinate si congelano e vanno distrutte.

---

### 2.12 Serra Idroponica di Bordo
- **ID Dispositivo**: `serra_idroponica`
- **Stanza / Settore**: `supporto_vitale_adv`
- **Categoria Power Grid**: `life_support`
- **Potenza Assorbita**: `-15.0 MW`
- **Funzionalità (Scopo a bordo)**:
  - Impianto botanico idroponico avanzato per la produzione biologica di ossigeno e razioni fresche durante le missioni a lungo raggio.
- **Azioni che può fare**:
  - Generazione biologica autonoma di ossigeno rinnovabile.
  - Produzione continuativa di scorte alimentari per l'equipaggio.
  - Riciclo e purificazione naturale delle acque grigie di bordo.
- **Funzionalità & Azioni che ne risentono se DISATTIVATA da Power Grid**:
  - **Morte delle Colture Idroponiche**: Lo spegnimento delle lampade UV e delle pompe nutritive uccide le piante entro breve tempo.
  - **Perdita della Riserva Rinnovabile di O2**: La nave dipende unicamente dai filtri chimici dello scrubber; consumate le cartucce, non c'è possibilità di rigenerare aria fresca.
  - **Perdita Valore Economico**: Il valore di mercato delle merci agricole e delle razioni a bordo viene azzerato.

---

### 2.14 Manipolatore e Sistemi di Stiva Merci
- **ID Dispositivo**: `cargo_handling`
- **Stanza / Settore**: `baia_carico` / `cargo`
- **Categoria Power Grid**: `cargo`
- **Potenza Assorbita**: `-10.0 MW`
- **Funzionalità (Scopo a bordo)**:
  - Servomeccanismi elettro-meccanici per l'apertura dei portelloni di carico, il bloccaggio magnetico dei container e la movimentazione carichi pesanti.
  - Impianto di raffinazione per sciogliere blocchi di ghiaccio frantumati e trasferirli al Life Support.
- **Azioni che può fare**:
  - Apertura e chiusura portelloni stiva cargo per carico/scarico nello spazio o in hangar.
  - Espulsione d'emergenza merci (`Eject Cargo`) da `CargoBayApp`.
  - Blocco magnetico inerziale dei container durante manovre ad alto G (evita sfondamenti interni).
  - Raffinazione e fusione dei nodi di ghiaccio (`MineralDepositEntity`) in acqua potabile e O2.
- **Funzionalità & Azioni che ne risentono se DISATTIVATO da Power Grid**:
  - **Portelloni Bloccati**: Impossibile aprire i portelloni esterni per caricare nodi minerali dal Service Drone o espellere merci pericolose/in fiamme.
  - **Rischio Sfondamento da Carico Svincolato**: Durante frenate violente (Proximity Drop a -5.8G), i container non magnetizzati si muovono causando danni strutturali alla stanza cargo.
  - **Blocco Raffinazione Risorse**: Il ghiaccio minerario non può essere fuso e purificato per rifornire le riserve vitali della nave.
  - **Deperimento Merci Termosensibili**: Il vano stiva perde isolamento termico rovinando beni deperibili.

---

### 2.15 Baia Ricarica e Manutenzione Drone di Servizio (EVA)
- **ID Dispositivo**: `dronestation` (o `baia_ricarica_drone`)
- **Stanza / Settore**: `pod_drone` / `room_13` (o adiacente alla stiva)
- **Categoria Power Grid**: `service`
- **Potenza Assorbita**: `-10.0 MW` a riposo (fino a `-30.0 MW` durante la ricarica rapida)
- **Funzionalità (Scopo a bordo)**:
  - Culla di aggancio, ricarica a induzione ad alta tensione e manutenzione per il drone di servizio esterno (`ServiceDrone`).
- **Azioni che può fare**:
  - Ricarica della batteria del Service Drone quando attraccato alla culla.
  - Rifornimento propellente RCS del drone esterno.
  - Riarmo e calibrazione degli utensili (saldatrice per falle, laser da taglio, elettromagnete).
  - Meccanismo di rilascio e procedura di attracco guidato automatico (`Auto-Dock`).
- **Funzionalità & Azioni che ne risentono se DISATTIVATA da Power Grid**:
  - **Blocco Ricarica Drone EVA**: Se il drone rientra, la sua batteria non si ricarica.
  - **Perdita Drone nello Spazio**: Se il drone esaurisce la batteria all'esterno senza che la baia possa riaccenderlo o guidarlo, rimane alla deriva permanente nello spazio profondo.
  - **Impossibile Riparare Falle Scafo Esterne**: La corvetta perde la capacità di inviare il drone all'esterno per saldare brecce allo scafo, costringendo a evacuare o sigillare le stanze danneggiate.
  - **Blocco Mining e Recupero Relitti**: Impossibile eseguire estrazione mineraria sugli asteroidi o recuperare i container `DataVault`.

---

### 2.16 Nodo Ricarica e Connessione Duct Drone (Interno)
- **ID Dispositivo**: `recharge_dock` (stanza definita da `recharge_room_id`, default: `cargo`)
- **Stanza / Settore**: `cargo` / `engineering`
- **Categoria Power Grid**: `engineering` (o `service`)
- **Potenza Assorbita**: `-10.0 MW`
- **Funzionalità (Scopo a bordo)**:
  - Connettore magnetico a contatto per la ricarica rapida e il bootstrap del drone per la manutenzione dei condotti interni (`DuctDrone`).
- **Azioni che può fare**:
  - Ricarica automatica batteria del Duct Drone a contatto (`+8.0% / sec`).
  - Annullamento dello stato di recupero d'emergenza (`is_in_emergency_recovery = false`).
  - Sincronizzazione dati telemetrici danni strutturali con `DiagnosticsApp`.
- **Funzionalità & Azioni che ne risentono se DISATTIVATO da Power Grid**:
  - **Il Duct Drone non si Ricarica**: Rientrando nella stanza designata, il drone non riceve energia e la batteria rimane invariata.
  - **Blocco Riparazioni Interne**: Se la batteria del drone si azzera, l'unità non può ripartire; i cortocircuiti, gli incendi e le falle nei condotti rimangono non riparabili.
  - **Fallimento Auto-Recupero 60s**: La subroutine di ripristino di emergenza dopo 60 secondi non è in grado di ricaricare il drone al 25%, lasciandolo inerte.

---

### 2.17 Server Centrale Cyber-Guerra / Mainframe
- **ID Dispositivo**: `server_rack` (o `mainframe`)
- **Stanza / Settore**: `mainframe`
- **Categoria Power Grid**: `cyber` (o `mainframe`)
- **Potenza Assorbita**: `-10.0 MW` base (fino a `-30.0 MW` durante l'elaborazione exploit)
- **Funzionalità (Scopo a bordo)**:
  - Coprocessore quantistico e memoria centrale per la suite di cyber-warfare, i firewall della corvetta e i servizi crittografici avanzati del sistema operativo GodotOS.
- **Azioni che può fare**:
  - Esecuzione degli exploit offensivi contro navi bersaglio in `HackExploitsApp` (`spammer`, `blind_eye`, `8loops`, `gout`, `dump_vault`).
  - Protezione attiva contro intrusioni informatiche nemiche e infezioni worm.
  - Elaborazione ad alta velocità per i comandi terminale dedicati: `worm` (violazione password), `decript` (decifratura chiavi .DAT) e `datread`.
  - Gestione della gerarchia virtuale `/sys` per la diagnostica a basso livello dei registri hardware.
- **Funzionalità & Azioni che ne risentono se DISATTIVATO da Power Grid**:
  - **Blocco Completo HackExploits**: L'applicazione `HackExploits` non può avviare alcun sottoprogramma di intrusione.
  - **Caduta Firewall di Bordo**: La nave diventa totalmente vulnerabile agli hacker nemici (gli exploit nemici penetrano istantaneamente nei sistemi della corvetta).
  - **Comandi Terminale Crittografici Offline**: I tool CLI `worm` e `decript` restituiscono errore di mancata risposta del coprocessore crittografico.
  - **Degrado Diagnostics e Logs**: Il logbook e l'analisi avanzata della memoria interna in `DiagnosticsApp` risultano inaccessibili o non aggiornati.

---

### 2.18 Radiatore Criogenico di Raffreddamento
- **ID Dispositivo**: `cooling_01`
- **Stanza / Settore**: `engine_room` / `sala_motori`
- **Categoria Power Grid**: `engineering`
- **Potenza Assorbita**: `-20.0 MW`
- **Funzionalità (Scopo a bordo)**:
  - Scambiatore termico criogenico a circuito chiuso per dissipare il calore generato dal reattore, dai propulsori a ioni e dai banchi laser dell'armeria.
- **Azioni che può fare**:
  - Dissipazione continua di calore termico (capacità nominale `60.0 kW/s`).
  - Raffreddamento rapido post-Proximity Drop (+60°C di picco termico).
  - Mantenimento della temperatura del reattore al di sotto della soglia critica (250°C).
- **Funzionalità & Azioni che ne risentono se DISATTIVATO da Power Grid**:
  - **Surriscaldamento Esponenziale**: Il calore generato da reattore e motori non viene espulso nello spazio.
  - **Spegnimento d'Emergenza Reattore (Scram)**: Raggiunti i 250°C, il reattore si spegne automaticamente per prevenire la fusione del nocciolo (Meltdown), lasciando la nave al buio.
  - **Blocco Riavvio Cruise Drive**: Il cooldown termico dei propulsori non scende, bloccando il riavvio della propulsione di crociera.

---

### 2.19 Banco Batterie di Riserva ed Emergenza
- **ID Dispositivo**: `battery_01`
- **Stanza / Settore**: `engine_room` / `reattore_fusione`
- **Categoria Power Grid**: `engineering`
- **Capacità / Potenza**: `500.0 MJ` capacità / erogazione fino a `500.0 MW`
- **Funzionalità (Scopo a bordo)**:
  - Accumulatore elettrochimico al grafene ad alta densità per assorbire i transitori di carico della rete e fornire alimentazione tampone in caso di avaria o disattivazione del reattore.
- **Azioni che può fare**:
  - Erogazione immediata di potenza sostitutiva quando la richiesta eccede la generazione del reattore.
  - Alimentazione d'emergenza dei sistemi vitali minimi durante il blackout del reattore primario.
  - Stabilizzazione di tensione evitando lo scatto intempestivo dei breaker di stanza.
- **Funzionalità & Azioni che ne risentono se DISATTIVATO da Power Grid**:
  - **Perdita Totale Buffer Energetico**: Qualsiasi accensione di sistemi esosi (Laser, Ping radar, Warmup cruise) causa un calo di tensione immediato con disattivazione dei sistemi sensibili.
  - **Spegnimento Improvviso a Freddo (Cold Shutdown)**: Se il reattore viene spento o danneggiato, la nave non ha secondi di autonomia per completare manovre d'emergenza o sigillare le paratie.

---

### 2.20 Array Telecamere Esterne e Fari Scafo
- **ID Dispositivo**: `cam_array` (`CAM 01 Prua`, `CAM 02 Poppa`, `CAM 03 Babordo`, `CAM 04 Tribordo`, `CAM 05 Dorsale`, `CAM 06 Ventrale`)
- **Stanza / Settore**: Esterno Scafo (6 prospettive ortogonali)
- **Categoria Power Grid**: `sensors` (o `service`)
- **Potenza Assorbita**: `-5.0 MW` base (fino a `-15.0 MW` con tutti i fari accesi)
- **Funzionalità (Scopo a bordo)**:
  - Sensori ottici perimetrali che forniscono feed visivo in tempo reale attorno alla corvetta in 3D.
  - Fari proiettori ad alta intensità per illuminare il buio dello spazio profondo, asteroidi e relitti.
  - Filtri multispettrali avanzati (Normale, Termico per scie di calore, Lidar per scansione superfici).
- **Azioni che può fare**:
  - Visualizzazione visiva diretta di avvicinamento a stazioni, campi di asteroidi e navi in `CamsApp`.
  - Attivazione/disattivazione fari anteriori/perimetrali per facilitare manovre notturne o in ombra planetaria.
  - Attivazione shader Termico (tracciamento vettori di fuga e firme IR) e Lidar (rilievo volumetrico ostacoli).
- **Funzionalità & Azioni che ne risentono se DISATTIVATO da Power Grid**:
  - **Perdita Segnale Video su Tutte le Cam**: I 6 canali video in `CamsApp` mostrano disturbo statico con testo `NO CARRIER / SIGNAL LOST`.
  - **Spegnimento Fari Esterni**: La zona circostante lo scafo precipita nell'oscurità totale durante l'attraversamento di coni d'ombra planetari o settori bui.
  - **Perdita Tracciamento Ottico/Lidar**: Impossibile verificare visivamente l'integrità esterna dello scafo, la presenza di fori di breccia o individuare ingressi hangar.

---

## 3. Note e Spunti per il Designer (Prossimi Passi di Sviluppo)

1. **Granularità Controllo PowerGrid (Stanza vs Singolo Device)**:
   - Attualmente `PowerGridApp` controlla l'on/off a livello di **stanza** (`ShipRoomData`), spegnendo tutti i device contenuti in essa.
   - *Domanda di espansione*: Vuoi mantenere il controllo per intera stanza (es. spegnere "Supporto vitale minimale" spegne sia purificatore che caldaia), oppure abilitare l'espansione ad albero per consentire all'Ingegnere di spegnere singoli device all'interno della stanza (es. tenere accesa la caldaia ma spegnere temporaneamente il purificatore)?
2. **Priorità di Protezione Breaker (Priority Tiers)**:
   - Se la richiesta di potenza supera l'erogazione del reattore, quali categorie devono staccarsi per prime in automatico? (es. Livello 1: Ricarica Laser e Scudi; Livello 2: Confort e Mainframe; Livello 3: Sensori e Motori; Livello 4 - Mai: Supporto Vitale minimo).
3. **Integrazione con la Gerarchia OS `/sys`**:
   - Ogni device spento da PowerGrid rifletterà il proprio stato nel registro `/sys/rooms/[room_id]/[device_id]/status` impostandolo su `OFFLINE`, permettendo all'equipaggio di verificare e automatizzare la gestione energetica anche tramite script CLI nel Terminale.
