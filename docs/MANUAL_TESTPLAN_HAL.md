# DARK NOVA: ROGUE SQUADRON
## Manual Test Plan — Hardware Abstraction Layer (HAL) & Power Grid Devices
**Questionario di Collaudo Operativo e Validazione Manuale In-Game**  
*File di Lavoro per il Tester / Pilota di Collaudo*

---

### Indice Generale
1. [Istruzioni Operative & Setup dell'Ambiente di Collaudo](#1-istruzioni-operative--setup-dellambiente-di-collaudo)
   - 1.1 [Configurazione dell'Ambiente di Esecuzione](#11-configurazione-dellambiente-di-esecuzione)
   - 1.2 [Disposizione Finestre e Monitoraggio Reattivo](#12-disposizione-finestre-e-monitoraggio-reattivo)
   - 1.3 [Cheat Sheet Comandi CLI del Terminale (`flight`, `nav`, `sensors`, `comms`, `dev`)](#13-cheat-sheet-comandi-cli-del-terminale-flight-nav-sensors-comms-dev)
   - 1.4 [Come Compilare il Questionario di Collaudo](#14-come-compilare-il-questionario-di-collaudo)
2. [Cruscotto Riassuntivo di Avanzamento](#2-cruscotto-riassuntivo-di-avanzamento)
3. [Schede di Collaudo Operativo Dettagliate](#3-schede-di-collaudo-operativo-dettagliate)
   - 3.1 [Dominio Inizializzazione & Lifecycle (INIT)](#31-dominio-inizializzazione--lifecycle-init)
   - 3.2 [Dominio Propulsione & Flight Control (PROP & FLIGHT)](#32-dominio-propulsione--flight-control-prop--flight)
   - 3.3 [Dominio Energia & Rete Elettrica (PWR & GRID)](#33-dominio-energia--rete-elettrica-pwr--grid)
   - 3.4 [Dominio Termica & Raffreddamento (THRM)](#34-dominio-termica--raffreddamento-thrm)
   - 3.5 [Dominio Sensori & Radar Spaziale (SENS)](#35-dominio-sensori--radar-spaziale-sens)
   - 3.6 [Dominio Telecomunicazioni & Guerra Elettronica (COMMS)](#36-dominio-telecomunicazioni--guerra-elettronica-comms)
   - 3.7 [Dominio Sistemi Difensivi & Armeria (WEAP & SHIELD)](#37-dominio-sistemi-difensivi--armeria-weap--shield)
   - 3.8 [Dominio Supporto Vitale & Sistemi Ausiliari (LS & CARGO)](#38-dominio-supporto-vitale--sistemi-ausiliari-ls--cargo)
   - 3.9 [Dominio Suite CLI Navale Terminale (CLI)](#39-dominio-suite-cli-navale-terminale-cli)
   - 3.10 [Dominio Resilienza & Scenari Limite (EDGE)](#310-dominio-resilienza--scenari-limite-edge)
4. [Protocollo di Triage & Segnalazione Bug](#4-protocollo-di-triage--segnalazione-bug)

---

## 1. Istruzioni Operative & Setup dell'Ambiente di Collaudo

### 1.1 Configurazione dell'Ambiente di Esecuzione
1. **Avvio del Progetto**:
   - Avviare il gioco direttamente dall'editor Godot premendo **F5** (oppure lanciando l'eseguibile standalone).
   - All'avvio dell'ambiente desktop **GodotOS**, aprire l'applicazione **Lobby** (icona sul desktop o menu Start).
   - Selezionare **Solo Mode**.
   - Nel selettore del Blueprint della Nave, scegliere:  
     👉 **`Corvette HAL Testbed (Manual Test Plan)`** (oppure `Dark Nova Corvette (Default)`).  
     *(Il testbed contiene i dispositivi e le stanze configurati per i test: `core_reactor`, `engine_main`, `rcs_pitch_l`, `rcs_pitch_r`, `helm_control`, `nav_computer`, `sensors_matrix`, `antenna_array`, `armory_defense`, `arm_sx_balancer`, `arm_dx_balancer`, `scrubber`, `heater`, `cargo_handling`, `cooling_01`, `battery_01`).*
   - Cliccare su **Conferma / Connetti Pod** per avviare la simulazione della nave.

2. **Accesso alle Applicazioni di Bordo**:
   - Aprire dal desktop le finestre applicative necessarie per il monitoraggio visivo e operativo:
     - **Terminal**: riga di comando per i sottocomandi operativi (`flight`, `nav`, `sensors`, `comms`) e diagnostici (`dev`).
     - **PowerGrid**: gestione interruttori stanza (breaker), controllo del carico reattore e autobilanciamento.
     - **FlightControl**: manetta, indicatore propulsori, cruise drive e comandi di volo manuali (WASD/QE).
     - **Sensors**: display radar 3D, scansione attiva a 120 MW e contatti rilevati.
     - **Comms**: spettrogramma frequenze radio, azimut antenna, docking con stazioni e link EW per `HackExploits`.
     - **Weapons & ShieldMatrix**: carica laser, orientamento torretta, integrità scudi e scarica a -25 HP/s.
     - **LifeSupport & CargoBay**: concentrazione O2/CO2, riscaldamento cabina e blocco portelloni stiva.

### 1.2 Disposizione Finestre e Monitoraggio Reattivo
L'Hardware Abstraction Layer propaga gli eventi in tempo reale tramite segnali reattivi senza polling:
- Si consiglia di affiancare il **Terminal** sulla metà sinistra dello schermo.
- Posizionare sul lato destro l'applicazione GUI sotto test (es. `FlightControl` durante i comandi di spinta, `PowerGrid` durante i test sui breaker, `Sensors` durante la scansione radar).
- Quando si disattiva una stanza in `PowerGrid` o si invia un comando CLI, osservare come le GUI collegate si aggiornino **immediatamente** senza ritardi o freeze dell'interfaccia.

### 1.3 Cheat Sheet Comandi CLI del Terminale (`flight`, `nav`, `sensors`, `comms`, `dev`)

#### Comandi di Volo (`flight`)
- `flight cruise_mode <start|stop>`: attiva o interrompe il Cruise Drive.
- `flight toggle_inertia <on|off>`: attiva o disattiva la stabilizzazione inerziale automatica.
- `flight set_speed <x>`: imposta il moltiplicatore di velocità limite tra 0.1 e 2.0.
- `flight forward <x>`: applica spinta lineare in avanti di `<x>` m/s.
- `flight backward <x>`: applica spinta lineare in retromarcia di `<x>` m/s.
- `flight rotate <x> <y> <z>`: applica rotazione attorno agli assi Pitch (X), Yaw (Y), Roll (Z).
- `flight rotate_to <x> <y> <z>`: orienta la prua verso il vettore indicato.
- `flight slide <x> <y>`: esegue una traslazione ortogonale laterale/verticale.

#### Comandi Navigazione (`nav`)
- `nav position`: mostra il quadrante, le coordinate globali e il settore attuale.
- `nav calculate <x> <y>`: calcola rotta, distanza stimata ed ETA per il quadrante specificato.

#### Comandi Sensori & Radar (`sensors`)
- `sensors swipe <on|off>` (o `sensors sweep <on|off>`): avvia o arresta la rotazione continua dell'antenna scanner.
- `sensors get_targets`: stampa la tabella formattata con tutti i contatti rilevati (ID, tipo, coordinate, distanza).
- `sensors get_probe_targets <probe_id>`: visualizza i contatti tracciati dal feed della sonda specificata.

#### Comandi Telecomunicazioni Radio (`comms`)
- `comms rotate <deg>`: orienta l'antenna radio sull'azimut specificato (0 - 360°).
- `comms scan <on|off>`: avvia o interrompe la scansione automatica delle frequenze.
- `comms get_frequency`: elenca i canali radio visibili nello spettro sub-spazio.
- `comms lock_frequency <freq>`: sintonizza e aggancia l'antenna sulla frequenza indicata.
- `comms listen_frequency <freq>`: **Modalità Streaming Radio Interattiva**. Stampa i messaggi radio periodici in tempo reale stile comunicazioni di settore. Premere `q` o digitare `exit` per terminare e tornare al prompt.

#### Diagnostica Basso Livello & Sysfs (`dev` & `sysfs`)
- `dev bus`: riepilogo generale dello stato dell'Hardware Bus e dei parametri complessivi nave.
- `dev list`: elenco completo dei dispositivi fisici con Device ID, stanza, stato (`ONLINE`/`OFFLINE`), integrità e temperatura.
- `dev status <device_id>`: scheda telemetrica del singolo dispositivo con registri hardware `[RO]` e `[RW]`.
- `dev get <device_id> <reg>` / `dev set <device_id> <reg> <val>`: lettura e scrittura su registri `[RW]`.
- `dev online <device_id> <1|0>`: accensione o spegnimento controllato a livello di singolo hardware.
- `cat /sys/rooms/<stanza>/<device>/<registro>`: lettura trasparente nel filesystem virtuale sysfs.
- `echo <valore> > /sys/rooms/<stanza>/<device>/<registro>`: scrittura diretta tramite sysfs.

### 1.4 Come Compilare il Questionario di Collaudo
1. Eseguire ciascun test case seguendo fedelmente i **Passi Operativi** indicati.
2. Contrassegnare l'esito della verifica sostituendo lo spazio con una `X`:
   - `[X] PASS`: Il comportamento osservato a video corrisponde esattamente al Risultato Atteso.
   - `[X] FAIL`: Si è verificato un errore, una visualizzazione errata, o la GUI non ha reagito all'azione.
   - `[X] BLOCKED`: Il test non può essere eseguito a causa di un crash, blocco della UI o malfunzionamento a monte.
3. Nel campo **Note / Anomalie Riscontrate**, annotare impressioni, messaggi d'errore o comportamenti anomali.
4. Aggiornare la colonna *Esito* nel **Cruscotto Riassuntivo**.

---

## 2. Cruscotto Riassuntivo di Avanzamento

| ID Test | Ambito / Dominio | Titolo Sintetico | Esito | Note Sintetiche |
|---|---|---|:---:|---|
| TC-HAL-INIT-01 | Lifecycle | Binding Automatico e Inizializzazione Bus (20 Devices) | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-INIT-02 | Lifecycle | Resilienza Nave Disconnessa (Bus Nullo) | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-PROP-01 | Propulsione | Spinta Nominale e Telemetria Propulsori | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-PROP-02 | Propulsione | Spegnimento `engine_main` e Blocco Tasti WASD/Cruise | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-PROP-03 | Propulsione | Spegnimento RCS (`rcs_pitch_l`/`r`) e Perdita Manovra 3D | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-PROP-04 | Propulsione | Spegnimento `helm_control` e Blocco Consolle Pilota | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-PWR-01 | Energia | Telemetria Rete Elettrica e Rapporto di Carico Nominale | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-PWR-02 | Energia | Variazione Erogazione Reattore (`power_target`) da CLI | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-PWR-03 | Energia | Cascata Breaker Stanza -> Dispositivi Hardware (`toggle_room_power`) | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-PWR-04 | Energia | Bilanciamento Automatico Rete (`autobalance`) | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-THRM-01 | Termica | Dissipazione Termica Nominale Radiatore Criogenico (`cooling_01`) | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-THRM-02 | Termica | Scram Termico di Sicurezza Reattore a 250°C | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-SENS-01 | Sensori | Scansione Radar Passiva e Tracciamento Bersagli | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-SENS-02 | Sensori | Spegnimento `sensors_matrix` e Cecità Radar Diegetica | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-COMMS-01 | Comms | Azimut Antenna, Scansione e Sintonizzazione Canali | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-COMMS-02 | Comms | Spegnimento `antenna_array` e Muto Radio / Blocco EW | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-COMMS-03 | Comms | Streaming Radio Interattivo (`comms listen_frequency`) | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-WEAP-01 | Armamenti | Spegnimento Armeria (`armory_defense`) e Blocco Torretta | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-SHIELD-01 | Difesa | Spegnimento Bilanciatori Scudi e Scarica Rapida (-25 HP/s) | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-LS-01 | Supporto Vitale | Monitoraggio Telemetria Atmosferica Nominale | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-LS-02 | Supporto Vitale | Spegnimento `scrubber`/`heater` e Allarmi Ipossia/Gelo | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-CARGO-01 | Stiva Merci | Spegnimento `cargo_handling` e Blocco Portelloni Stiva | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-CLI-01 | Suite CLI | Comandi Manovra e Spinta (`flight forward`, `set_speed`) | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-CLI-02 | Suite CLI | Comandi Navigazione e Rotte (`nav position`, `calculate`) | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-CLI-03 | Suite CLI | Comandi Radar Scanner (`sensors swipe`, `get_targets`) | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-CLI-04 | Suite CLI | Pre-Flight Check Hardware nei Comandi CLI (Rifiuto Esecuzione) | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-CLI-05 | Suite CLI | Ispezione e Modifica Registri Hardware (`dev` & `sysfs`) | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-EDGE-01 | Resilienza | Blackout Totale Nave e Intervento Batterie d'Emergenza | `[ ] PASS / [ ] FAIL` | |
| TC-HAL-EDGE-02 | Resilienza | Cambio Blueprint da Lobby e Riconnessione Hot-Swap | `[ ] PASS / [ ] FAIL` | |

---

## 3. Schede di Collaudo Operativo Dettagliate

### 3.1 Dominio Inizializzazione & Lifecycle (INIT)

#### TC-HAL-INIT-01: Binding Automatico e Inizializzazione Bus (20 Devices)
- **Prerequisiti**: Gioco avviato, nave inizializzata tramite `Lobby` (`Solo Mode`, blueprint `Corvette HAL Testbed`).
- **Passi Operativi**:
  1. Aprire l'applicazione `Terminal`.
  2. Digitare: `dev bus`.
  3. Digitare: `dev list`.
  4. Aprire le applicazioni `PowerGrid`, `FlightControl`, `Sensors` e `Comms`.
- **Risultato Atteso**:
  - `dev bus` conferma `"Hardware Bus: ATTIVO"` e `"HAL Controller: CONNESSO E SINCRONIZZATO"`.
  - `dev list` mostra i componenti registrati nel bus (`reactor_01`, `thruster_01`, `thruster_02`, `cooling_01`, `battery_01`, `life_support_01`, ecc.) in stato `ONLINE`.
  - Le applicazioni caricano i rispettivi parametri operativi senza errori in console né overlay di errore.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

#### TC-HAL-INIT-02: Resilienza Nave Disconnessa (Bus Nullo)
- **Prerequisiti**: Gioco appena avviato sul Desktop GodotOS, **PRIMA** di aprire `Lobby` e connettersi alla nave.
- **Passi Operativi**:
  1. Aprire direttamente `Terminal` dal desktop.
  2. Digitare: `dev list`.
  3. Digitare: `flight set_speed 1.0`.
  4. Aprire le finestre `FlightControl` e `PowerGrid`.
- **Risultato Atteso**:
  - Nessun crash dell'eseguibile o eccezione runtime `Invalid get index`.
  - Il Terminale stampa un avviso informativo diegetico indicando che la nave non è connessa.
  - Le applicazioni mostrano l'overlay di disconnessione o valori nominali di sicurezza senza bloccare l'interfaccia.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

### 3.2 Dominio Propulsione & Flight Control (PROP & FLIGHT)

#### TC-HAL-PROP-01: Spinta Nominale e Telemetria Propulsori
- **Prerequisiti**: Nave attiva con reattore e motori operativi. Finestre `FlightControl` e `Terminal` aperte e affiancate.
- **Passi Operativi**:
  1. In `FlightControl`, verificare il badge propulsori (`thrusters_badge`).
  2. Nel `Terminal`, digitare: `dev status thruster_01` e `dev status thruster_02`.
  3. Premere e mantenere premuto il tasto di avanzamento `W`.
  4. Verificare l'erogazione di spinta e la variazione di velocità orizzontale/longitudinale.
- **Risultato Atteso**:
  - Il badge mostra `"PROPULSORI PRONTI (80 kN)"` (o `"PROPULSORI PRONTI (500 kN)"` a seconda del blueprint) con modulate verde (`#66ff99`).
  - Premendo `W`, la nave accelera lungo l'asse longitudinale (-Z).
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

#### TC-HAL-PROP-02: Spegnimento `engine_main` e Blocco Tasti WASD/Cruise
- **Prerequisiti**: Finestre `PowerGrid`, `FlightControl` e `Terminal` aperte e affiancate.
- **Passi Operativi**:
  1. In `FlightControl`, attivare la modalità Cruise Drive cliccando sul pulsante **Cruise** (la nave accelera a 160 m/s).
  2. In `PowerGrid`, spegnere la stanza **Sala Macchine & Propulsione** (`engine_room` / `sala_motori`) abbassando l'interruttore breaker.
  3. Osservare immediatamente `FlightControl`.
  4. Provare a premere i tasti di avanzamento `W`, `S` e i tasti regolazione velocità `R`, `F`.
  5. Nel `Terminal`, verificare lo stato con: `dev status engine_main` (o `dev list`).
  6. In `PowerGrid`, riaccendere la stanza dei motori.
- **Risultato Atteso**:
  - Al passo 2-3: Il Cruise Drive si disinnesta all'istante con errore `"CRUISE DISENGAGED: PROPULSION POWER LOSS"`.
  - Il badge in `FlightControl` diventa rosso con testo `"OFFLINE - NO POWER"`.
  - Al passo 4: La nave non genera alcuna spinta longitudinale; i tasti W, S, R, F non applicano accelerazione.
  - Al passo 5: Il dispositivo `engine_main` risulta `is_online: false`, `is_powered: false`.
  - Al passo 6: Il badge torna verde e la piena manovrabilità longitudinale viene ripristinata.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

#### TC-HAL-PROP-03: Spegnimento RCS (`rcs_pitch_l`/`r`) e Perdita Manovra 3D
- **Prerequisiti**: Finestre `PowerGrid` e `FlightControl` aperte e affiancate. Nave in assetto stabile.
- **Passi Operativi**:
  1. In `PowerGrid`, disattivare la stanza `rcs_left` (lasciando `rcs_right` acceso).
  2. In `FlightControl`, provare a ruotare la nave con `Q` ed `E` e traslare lateralmente con `A` e `D`.
  3. In `PowerGrid`, disattivare anche `rcs_right`.
  4. Provare a ruotare la nave sui 3 assi (frecce direzionali e tasti Q/E) e variare quota (`Spazio` / `Ctrl`).
  5. Riaccendere entrambi i breaker RCS in `PowerGrid`.
- **Risultato Atteso**:
  - Al passo 2: Rotazione e traslazione laterale risultano asimmetriche (la nave perde la capacità di ruotare o traslare verso un lato).
  - Al passo 4: Con entrambi gli RCS spenti, la rotazione 3D e la traslazione laterale/verticale sono completamente bloccate (`rot_vec = Vector3.ZERO`).
  - Al passo 5: La completa manovrabilità angolare e il controllo inerziale vengono ripristinati.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

#### TC-HAL-PROP-04: Spegnimento `helm_control` e Blocco Consolle Pilota
- **Prerequisiti**: Finestre `PowerGrid` e `FlightControl` aperte e affiancate.
- **Passi Operativi**:
  1. In `PowerGrid`, disattivare la stanza del **Ponte di Comando** (`bridge` / `ponte_comando`).
  2. Osservare l'interfaccia di `FlightControl`.
  3. Provare ad agire su qualsiasi comando di pilotaggio (WASD, QE, pulsante Cruise, pulsante Inerzia).
  4. Riattivare la stanza `bridge` in `PowerGrid`.
- **Risultato Atteso**:
  - Al passo 1-2: Il badge di `FlightControl` diventa rosso acceso con la dicitura:  
    `"COMMAND CONSOLE UNPOWERED"`.
  - La barra di riepilogo notifica: `"Consolle di comando non alimentata (helm_control offline). Comandi pilota disconnessi."`.
  - Al passo 3: Tutti gli input di pilotaggio sono completamente ignorati (`can_control_flight = false`).
  - Al passo 4: L'overlay scompare e i controlli tornano operativi.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

### 3.3 Dominio Energia & Rete Elettrica (PWR & GRID)

#### TC-HAL-PWR-01: Telemetria Rete Elettrica e Rapporto di Carico Nominale
- **Prerequisiti**: Nave attiva con reattore funzionante (`Corvette HAL Testbed`).
- **Passi Operativi**:
  1. Aprire l'applicazione `PowerGrid`.
  2. Nel `Terminal`, digitare: `dev status core_reactor` (o `dev status reactor_01`).
  3. Confrontare il valore di erogazione MW mostrato nel Terminale con la **Potenza Totale Generata** nell'intestazione di `PowerGrid`.
  4. Verificare che il rapporto energetico (power ratio) sia >= 1.0 (barra verde).
- **Risultato Atteso**:
  - La potenza erogata nominale è coerente (es. 1000.0 MW).
  - Il consumo complessivo riflette la somma delle stanze attive.
  - Nessun allarme di blackout o deficit energetico attivo in condizioni nominali.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

#### TC-HAL-PWR-02: Variazione Erogazione Reattore (`power_target`) da CLI
- **Prerequisiti**: Finestre `PowerGrid` e `Terminal` aperte e affiancate.
- **Passi Operativi**:
  1. Nel `Terminal`, impostare il target di potenza del reattore al 50%:  
     `dev set core_reactor power_target 0.50`  
     *(oppure `dev set reactor_01 power_target 0.50`)*.
  2. Osservare l'indicatore della potenza generata in `PowerGrid`.
  3. Nel `Terminal`, verificare con: `dev get core_reactor power_target`.
  4. Riportare il target al 100%:  
     `dev set core_reactor power_target 1.0`
- **Risultato Atteso**:
  - Al passo 1-2: La generazione in `PowerGrid` scende a circa la metà della potenza nominale (~500 MW).
  - Il comando `dev get` restituisce esattamente `0.5`.
  - Al ripristino, la potenza generata risale a 1000 MW.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

#### TC-HAL-PWR-03: Cascata Breaker Stanza -> Dispositivi Hardware (`toggle_room_power`)
- **Prerequisiti**: Finestre `PowerGrid` e `Terminal` aperte e affiancate.
- **Passi Operativi**:
  1. In `PowerGrid`, individuare la stanza **Matrice Sensori** (`matrice_sensori` / `sensors`) e disattivarla tramite interruttore breaker.
  2. Nel `Terminal`, digitare: `dev status sensors_matrix`.
  3. In `PowerGrid`, disattivare la stanza **Comunicazioni** (`comunicazioni` / `comms`).
  4. Nel `Terminal`, digitare: `dev status antenna_array`.
  5. In `PowerGrid`, riaccendere entrambe le stanze.
- **Risultato Atteso**:
  - Al passo 2: Il dispositivo `sensors_matrix` passa a `is_online: false`, `is_powered: false`, status `OFFLINE`.
  - Al passo 4: Il dispositivo `antenna_array` passa a `is_online: false`, `is_powered: false`, status `OFFLINE`.
  - Al passo 5: Entrambi i dispositivi tornano `is_online: true`, `is_powered: true`, status `ONLINE`.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

#### TC-HAL-PWR-04: Bilanciamento Automatico Rete (`autobalance`)
- **Prerequisiti**: Finestre `PowerGrid` e `Terminal` aperte e affiancate.
- **Passi Operativi**:
  1. Nel `Terminal`, ridurre il reattore a un livello di erogazione insufficiente:  
     `dev set core_reactor power_target 0.15`
  2. In `PowerGrid`, osservare l'insorgere del deficit energetico (barra rossa o indicatore < 1.0).
  3. In `PowerGrid`, cliccare sul pulsante **Autobilanciamento Rete** (`BtnAutobalance`).
  4. Nel `Terminal`, leggere il nuovo valore con:  
     `dev get core_reactor power_target`
- **Risultato Atteso**:
  - Il bilanciamento automatico ricalcola il fabbisogno energetico complessivo applicando un margine di riserva (+15%).
  - Il target sale a un valore sufficiente a coprire i carichi attivi.
  - La rete torna in pareggio positivo con rapporto di alimentazione >= 1.0.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

### 3.4 Dominio Termica & Raffreddamento (THRM)

#### TC-HAL-THRM-01: Dissipazione Termica Nominale Radiatore Criogenico (`cooling_01`)
- **Prerequisiti**: Nave attiva con reattore in funzione.
- **Passi Operativi**:
  1. Nel `Terminal`, digitare: `dev bus`.
  2. Verificare i valori di calore totale e temperatura media.
  3. Digitare: `dev status cooling_01`.
- **Risultato Atteso**:
  - `cooling_01` è in stato `ONLINE` con potenza dissipativa attiva.
  - La temperatura media si mantiene stabile nell'intervallo nominale (20°C - 45°C).
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

#### TC-HAL-THRM-02: Scram Termico di Sicurezza Reattore a 250°C
- **Prerequisiti**: Finestre `PowerGrid` e `Terminal` aperte e affiancate.
- **Passi Operativi**:
  1. Nel `Terminal`, spegnere il radiatore criogenico per arrestare la dissipazione termica:  
     `dev online cooling_01 0`
  2. Monitorare la telemetria termica con `dev status core_reactor` (o `dev status reactor_01`).
  3. Se la temperatura non sale abbastanza in fretta per via dei carichi bassi, osservare il comportamento al raggiungimento della soglia critica di 250.0°C.
  4. Verificare lo stato del reattore quando `heat_current >= heat_max` (250°C).
- **Risultato Atteso**:
  - Al raggiungimento dei 250°C, scatta istantaneamente lo **SCRAM Termico di Sicurezza**:
    - Il reattore passa allo stato `SCRAM`.
    - La potenza generata crolla a `0.0 MW`.
    - Viene emesso l'allarme diegetico: `"SCRAM TERMICO ATTIVATO: Temperatura nocciolo >= 250.0 C! Reattore disconnesso per prevenire meltdown."`.
  - In `PowerGrid` si registra la perdita immediata della generazione reattore.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

### 3.5 Dominio Sensori & Radar Spaziale (SENS)

#### TC-HAL-SENS-01: Scansione Radar Passiva e Tracciamento Bersagli
- **Prerequisiti**: Nave attiva nello spazio, stanza `matrice_sensori` alimentata.
- **Passi Operativi**:
  1. Aprire l'applicazione `Sensors`.
  2. Verificare la rotazione dell'antenna radar e l'aggiornamento dei contatti nel raggio di 1000 m.
  3. Cliccare sul pulsante **Ping Attivo (120 MW)** (se presente).
- **Risultato Atteso**:
  - Lo schermo radar visualizza la griglia circolare attiva, il fascio di scansione rotante e i contatti tracciati.
  - Il ping attivo estende la portata della scansione a 2000 m assorbendo il picco energetico temporaneo.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

#### TC-HAL-SENS-02: Spegnimento `sensors_matrix` e Cecità Radar Diegetica
- **Prerequisiti**: Finestre `PowerGrid` e `Sensors` aperte e affiancate.
- **Passi Operativi**:
  1. In `PowerGrid`, disattivare la stanza **Matrice Sensori** (`matrice_sensori` / `sensors`).
  2. Osservare immediatamente lo schermo di `Sensors`.
  3. Provare a inviare il ping attivo a 120 MW.
  4. Aprire l'applicazione `Weapons` e verificare l'elenco bersagli agganciabili.
  5. Riaccendere `matrice_sensori` in `PowerGrid`.
- **Risultato Atteso**:
  - Al passo 1-2: Lo schermo radar si oscura con overlay:  
    `"STATO RADAR: OFFLINE (RETE ELETTRICA)"`.
  - Tutti i blip dei contatti spariscono; la lista bersagli si svuota.
  - Al passo 3: Il ping attivo è inibito e rifiuta l'erogazione di energia.
  - Al passo 4: In `Weapons`, l'aggancio missilistico (`Missile Lock`) non può essere effettuato per assenza di dati radar.
  - Al passo 5: Il radar si riattiva e torna a tracciare i contatti.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

### 3.6 Dominio Telecomunicazioni & Guerra Elettronica (COMMS)

#### TC-HAL-COMMS-01: Azimut Antenna, Scansione e Sintonizzazione Canali
- **Prerequisiti**: Stanza `comunicazioni` alimentata. Finestra `Comms` aperta.
- **Passi Operativi**:
  1. In `Comms`, osservare lo spettrogramma / waterfall delle frequenze radio.
  2. Ruotare la parabola orientando l'azimut (es. 180°).
  3. Selezionare una frequenza attiva nello spettro e tentare l'aggancio del segnale.
- **Risultato Atteso**:
  - La waterfall visualizza le onde e il rumore di fondo con eventuali picchi di segnale.
  - La rotazione dell'antenna aggiorna il puntamento dell'azimut.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

#### TC-HAL-COMMS-02: Spegnimento `antenna_array` e Muto Radio / Blocco EW
- **Prerequisiti**: Finestre `PowerGrid`, `Comms` e `HackExploits` aperte.
- **Passi Operativi**:
  1. In `PowerGrid`, spegnere la stanza **Comunicazioni** (`comunicazioni` / `comms`).
  2. Osservare `CommsApp`.
  3. Aprire l'applicazione `HackExploits`.
  4. Provare ad agganciare un bersaglio EW o montare il `Target Drive`.
  5. Riaccendere la stanza `comunicazioni` in `PowerGrid`.
- **Risultato Atteso**:
  - Al passo 1-2: In `Comms`, lo spettrogramma si azzera (`SEGNALE ASSENTE`), il ricevitore audio ammutolisce e le richieste di attracco alle stazioni vengono bloccate.
  - Al passo 3-4: `HackExploits` non riesce a stabilire il fascio EW; il `Target Drive` remoto non può essere montato sul filesystem.
  - Al passo 5: Il segnale radio e il link EW vengono ripristinati.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

#### TC-HAL-COMMS-03: Streaming Radio Interattivo (`comms listen_frequency`)
- **Prerequisiti**: Finestra `Terminal` aperta in primo piano. Stanza `comms` alimentata.
- **Passi Operativi**:
  1. Nel `Terminal`, avviare l'ascolto radio interattivo su frequenza standard:  
     `comms listen_frequency 1420.0`
  2. Osservare i messaggi stampati nel terminale a intervalli regolari (es. ogni pochi secondi).
  3. Digitare un comando qualsiasi mentre lo streaming è attivo (es. `help` o testo casuale) e verificare la continuazione dello stream.
  4. Premere il tasto `q` (oppure digitare `exit`) e premere Invio.
  5. Verificare il ritorno al prompt normale del terminale digitando `dev bus`.
- **Risultato Atteso**:
  - Al passo 1: Il terminale stampa l'avviso di aggancio e sincronizzazione del flusso:  
    `"Sintonizzazione su 1420.0 MHz in corso..."` e attiva la modalità interattiva.
  - Al passo 2: Vengono stampati pacchetti radio diegetici in tempo reale stile comunicazioni di settore.
  - Al passo 4: Premendo `q` o digitando `exit`, l'ascolto si arresta con messaggio di disconnessione e il controllo torna al prompt senza blocchi.
  - Al passo 5: I comandi ordinari del terminale funzionano regolarmente.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

### 3.7 Dominio Sistemi Difensivi & Armeria (WEAP & SHIELD)

#### TC-HAL-WEAP-01: Spegnimento Armeria (`armory_defense`) e Blocco Torretta
- **Prerequisiti**: Finestre `PowerGrid` e `Weapons` aperte e affiancate.
- **Passi Operativi**:
  1. In `PowerGrid`, spegnere la stanza **Armeria & Sistemi Difensivi** (`armamenti` / `armory`).
  2. In `Weapons`, osservare i condensatori dei laser e i tubi missili.
  3. Provare a orientare la torretta esterna o a fare fuoco con i laser primari.
  4. Riaccendere `armamenti` in `PowerGrid`.
- **Risultato Atteso**:
  - Al passo 1-2: I condensatori laser interrompono la carica; i servomotori della torretta si bloccano in posizione fissa.
  - Al passo 3: I comandi di fuoco e lancio missili vengono inibiti per mancanza di consenso energetico.
  - Al passo 4: La ricarica dei condensatori riprende e le armi tornano operative.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

#### TC-HAL-SHIELD-01: Spegnimento Bilanciatori Scudi e Scarica Rapida (-25 HP/s)
- **Prerequisiti**: Finestre `PowerGrid` e `ShieldMatrix` aperte e affiancate. Scudi carichi al 100%.
- **Passi Operativi**:
  1. In `PowerGrid`, disattivare le stanze dei bilanciatori scudi (`armatura_adattiva_sx` / `armatura_adattiva_dx` o `room_14` / `room_15`).
  2. Osservare immediatamente gli indicatori HP degli scudi in `ShieldMatrix`.
  3. Verificare lo stato delle torrette automatiche difensive PDG e Flak.
  4. Riaccendere i bilanciatori scudi in `PowerGrid`.
- **Risultato Atteso**:
  - Al passo 1-2: L'energia degli scudi inizia a dissiparsi passivamente a una velocità costante di circa **-25 HP/s** fino a raggiungere 0 HP.
  - Al passo 3: I sistemi difensivi ravvicinati Point Defense (PDG) e Flak si spengono.
  - Al passo 4: La dissipazione si arresta e inizia il ciclo di ricarica deflettori.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

### 3.8 Dominio Supporto Vitale & Sistemi Ausiliari (LS & CARGO)

#### TC-HAL-LS-01: Monitoraggio Telemetria Atmosferica Nominale
- **Prerequisiti**: Finestra `LifeSupport` aperta. Stanza `supporto_vitale_min` alimentata.
- **Passi Operativi**:
  1. In `LifeSupport`, osservare i valori di concentrazione O2, CO2 e temperatura cabina.
  2. Nel `Terminal`, verificare i valori corrispondenti con: `dev status life_support_01` (o `dev bus`).
- **Risultato Atteso**:
  - O2 si attesta sopra il 95%, CO2 sotto lo 0.05%, temperatura ambiente attorno a 21.0°C.
  - Nessun allarme ipossia o tossicità attivo.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

#### TC-HAL-LS-02: Spegnimento `scrubber`/`heater` e Allarmi Ipossia/Gelo
- **Prerequisiti**: Finestre `PowerGrid` e `LifeSupport` aperte e affiancate.
- **Passi Operativi**:
  1. In `PowerGrid`, spegnere la stanza **Supporto Vitale** (`supporto_vitale_min` / `room_11`).
  2. Osservare la telemetria in `LifeSupport` nell'arco di 30-60 secondi.
  3. Verificare l'andamento della CO2, dell'O2 e della temperatura cabina.
  4. Riaccendere la stanza `supporto_vitale_min`.
- **Risultato Atteso**:
  - Con lo scrubber spento: la concentrazione di CO2 sale progressivamente e l'O2 diminuisce, facendo scattare allarmi di rischio tossicità/asfissia.
  - Con la caldaia spenta: la temperatura cabina crolla verso lo zero termico.
  - Al ripristino dell'alimentazione: i filtri riprendono la depurazione e la temperatura torna a salire verso i 21°C.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

#### TC-HAL-CARGO-01: Spegnimento `cargo_handling` e Blocco Portelloni Stiva
- **Prerequisiti**: Finestre `PowerGrid` e `CargoBay` aperte e affiancate.
- **Passi Operativi**:
  1. In `PowerGrid`, spegnere la stanza **Baia di Carico** (`baia_carico` / `cargo`).
  2. In `CargoBay`, provare ad aprire i portelloni della stiva o avviare l'espulsione (jettison) merci.
  3. Provare ad avviare la fusione/raffinazione dei minerali di ghiaccio.
  4. Riaccendere `baia_carico` in `PowerGrid`.
- **Risultato Atteso**:
  - Al passo 1-2: I portelloni risultano bloccati (`CARGO HANDLING UNPOWERED`); l'espulsione merci è inibita.
  - Al passo 3: Il riscaldatore di fusione ghiaccio non riceve alimentazione.
  - Al passo 4: I comandi della stiva tornano operativi.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

### 3.9 Dominio Suite CLI Navale Terminale (CLI)

#### TC-HAL-CLI-01: Comandi Manovra e Spinta (`flight forward`, `set_speed`)
- **Prerequisiti**: Finestra `Terminal` aperta in primo piano. Nave alimentata.
- **Passi Operativi**:
  1. Digitare: `flight set_speed 1.5`
  2. Digitare: `flight forward 20`
  3. Digitare: `flight slide 5 0`
  4. Digitare: `flight rotate 10 0 0`
  5. Digitare: `flight toggle_inertia on`
  6. Digitare: `flight cruise_mode start` e poi `flight cruise_mode stop`
- **Risultato Atteso**:
  - Ciascun comando restituisce una risposta di conferma dell'azione eseguita senza errori di sintassi.
  - La velocità limite viene aggiornata a 1.5x.
  - La nave riceve gli impulsi di spinta e manovra richiesti.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

#### TC-HAL-CLI-02: Comandi Navigazione e Rotte (`nav position`, `calculate`)
- **Prerequisiti**: Finestra `Terminal` aperta in primo piano. Nave alimentata.
- **Passi Operativi**:
  1. Digitare: `nav position`
  2. Verificare l'output con quadrante, coordinate e settore.
  3. Digitare: `nav calculate 12 8`
  4. Digitare con parametri non validi (es. `nav calculate abc def`) per verificare la robustezza.
- **Risultato Atteso**:
  - `nav position` stampa le coordinate attuali ricavate da `StarSystemGridManager`.
  - `nav calculate` calcola e visualizza la distanza in unità spaziali, il vettore di avvicinamento e l'ETA stimato.
  - Con parametri non validi, stampa un chiaro messaggio di errore di formato senza crash.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

#### TC-HAL-CLI-03: Comandi Radar Scanner (`sensors swipe`, `get_targets`)
- **Prerequisiti**: Finestra `Terminal` aperta. Matrice sensori alimentata.
- **Passi Operativi**:
  1. Digitare: `sensors swipe on` (oppure `sensors sweep on`)
  2. Digitare: `sensors get_targets`
  3. Digitare: `sensors swipe off`
- **Risultato Atteso**:
  - `sensors swipe on` conferma l'avvio della scansione continua dell'antenna scanner.
  - `sensors get_targets` stampa la tabella ASCII formattata con l'elenco dei contatti nel raggio radar (ID, tipo bersaglio, coordinate, distanza in metri).
  - `sensors swipe off` arresta la rotazione continua.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

#### TC-HAL-CLI-04: Pre-Flight Check Hardware nei Comandi CLI (Rifiuto Esecuzione)
- **Prerequisiti**: Finestre `PowerGrid` e `Terminal` aperte e affiancate.
- **Passi Operativi**:
  1. In `PowerGrid`, spegnere la stanza **Sala Macchine & Propulsione** (`engine_room` / `sala_motori`).
  2. Nel `Terminal`, provare a eseguire: `flight forward 15`
  3. In `PowerGrid`, spegnere la stanza **Ponte di Comando** (`bridge` / `ponte_comando`).
  4. Nel `Terminal`, provare a eseguire: `nav calculate 5 5`
  5. In `PowerGrid`, spegnere la stanza **Matrice Sensori** (`matrice_sensori` / `sensors`).
  6. Nel `Terminal`, provare a eseguire: `sensors get_targets`
  7. In `PowerGrid`, spegnere la stanza **Comunicazioni** (`comunicazioni` / `comms`).
  8. Nel `Terminal`, provare a eseguire: `comms get_frequency` o `comms listen_frequency 1420`
  9. Riaccendere tutte le stanze in `PowerGrid`.
- **Risultato Atteso**:
  - Tutti i comandi vengono **rifiutati** prima dell'esecuzione.
  - Il Terminale stampa l'errore hardware specifico indicando il dispositivo mancante e la stanza di appartenenza:
    - Passo 2: `[ERRORE HARDWARE] Dispositivo 'engine_main' (sala_motori) non alimentato o offline.`
    - Passo 4: `[ERRORE HARDWARE] Dispositivo 'nav_computer' (ponte_comando) non alimentato o offline.`
    - Passo 6: `[ERRORE HARDWARE] Dispositivo 'sensors_matrix' (matrice_sensori) non alimentato o offline.`
    - Passo 8: `[ERRORE HARDWARE] Dispositivo 'antenna_array' (comunicazioni) non alimentato o offline.`
  - Al ripristino (passo 9), tutti i comandi tornano a rispondere normalmente.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

#### TC-HAL-CLI-05: Ispezione e Modifica Registri Hardware (`dev` & `sysfs`)
- **Prerequisiti**: Finestra `Terminal` aperta in primo piano.
- **Passi Operativi**:
  1. Digitare: `dev help`
  2. Digitare: `dev list`
  3. Digitare: `dev status core_reactor` e verificare la colonna dei permessi `[RO]` / `[RW]`.
  4. Digitare: `cat /sys/rooms/engine_room/reactor_01/status` (o percorso stanza corrispondente).
  5. Spegnere e riaccendere un dispositivo via `dev online`:  
     `dev online cooling_01 0`  
     `dev online cooling_01 1`
- **Risultato Atteso**:
  - La guida comandi elenca tutti i sottocomandi di `dev`.
  - La scheda diagnostica distingue chiaramente i registri in sola lettura da quelli scrivibili.
  - Il driver virtuale sysfs e il comando `dev online` aggiornano istantaneamente lo stato del componente.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

### 3.10 Dominio Resilienza & Scenari Limite (EDGE)

#### TC-HAL-EDGE-01: Blackout Totale Nave e Intervento Batterie d'Emergenza
- **Prerequisiti**: Finestre `PowerGrid` e `Terminal` aperte e affiancate.
- **Passi Operativi**:
  1. Nel `Terminal`, disattivare il reattore primario:  
     `dev online core_reactor 0` (oppure `dev online reactor_01 0`).
  2. Osservare il comportamento della rete elettrica in `PowerGrid`.
  3. Se il banco batterie (`battery_01`) è attivo, verificare la transizione dell'alimentazione sulle riserve tampone (scarica MJ).
  4. Spegnere anche il banco batterie (`dev online battery_01 0`).
  5. Osservare l'allarme di Blackout Totale Fisico a video.
  6. Riattivare il reattore (`dev online core_reactor 1`) e ripristinare la rete.
- **Risultato Atteso**:
  - Al passo 1-2: La nave passa in alimentazione di emergenza su batteria; i carichi essenziali rimangono alimentati temporaneamente.
  - Al passo 4-5: Con batterie esaurite o spente, scatta il **Blackout Fisico**: tutti i dispositivi si spengono simultaneamente, le applicazioni segnalano la perdita totale di potenza e i comandi CLI vengono bloccati.
  - Al passo 6: La riaccensione del reattore ripristina la rete e i sistemi riprendono il funzionamento nominale.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

#### TC-HAL-EDGE-02: Cambio Blueprint da Lobby e Riconnessione Hot-Swap
- **Prerequisiti**: Sessione in corso su `Corvette HAL Testbed`.
- **Passi Operativi**:
  1. Aprire l'applicazione `Lobby`.
  2. Nel selettore Blueprint, passare a `Dark Nova Corvette (Default)`.
  3. Cliccare su **Conferma / Connetti Pod**.
  4. Nel `Terminal`, digitare: `dev bus` e poi `dev list`.
  5. Aprire `FlightControl` e verificare la nuova spinta visualizzata.
- **Risultato Atteso**:
  - L'HAL si scollega in modo pulito dal bus precedente e si connette al nuovo bus della nave.
  - Nessun segnale duplicato in console, nessun memory leak o crash.
  - Il Terminale e le app mostrano la configurazione hardware del nuovo blueprint selezionato.
- [ ] PASS  - [ ] FAIL  - [ ] BLOCKED  
**Note / Anomalie Riscontrate**:

---

## 4. Protocollo di Triage & Segnalazione Bug

Qualora un test case produca un esito `[X] FAIL` o `[X] BLOCKED`:
1. **Identificazione del Layer Responsabile**:
   - **Comando CLI Subsystem (`flight`, `nav`, `sensors`, `comms`)**: Se un sottocomando fallisce nel parsing, genera errori di battitura o non blocca l'hardware unpowered, verificare la classe del comando in `Applications/Terminal/commands/<nome>_command.gd`.
   - **Comando Radio Interattivo**: Se `comms listen_frequency` non produce messaggi o non esce con il tasto `q`, verificare l'implementazione del metodo `handle_interactive_input()` e `terminal.active_interactive_command`.
   - **Cascata PowerGrid -> Device**: Se l'interruttore in `PowerGridApp` viene spento ma il dispositivo in `dev list` o `ship_hal.is_device_online()` resta `ONLINE`, verificare la mappa degli alias in `ship_hal.gd` e la chiamata `toggle_room_power()`.
   - **Mancata Reazione Applicazione GUI**: Se il componente è offline ma la schermata continua a permettere manovre o visualizzare dati, verificare le connessioni ai segnali o le chiamate di controllo hardware in `*App.gd`.
2. **Tracciamento dell'Anomalia**:
   - Annotare i passi esatti e il comportamento anomalo riscontrato nel campo **Note / Anomalie Riscontrate** della relativa scheda di collaudo.
   - Aprire la segnalazione di bug specificando l'ID del test (es. `[HAL-BUG] TC-HAL-CLI-04: Rifiuto comando non scattato per nav calculate con nav_computer spento`).
