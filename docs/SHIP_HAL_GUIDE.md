# Specifiche Architetturali e Guida Operativa: ShipHAL (Ship Hardware Abstraction Layer)
**Dark Nova: Rogue Squadron — Kernel OS e Astrazione Hardware Navale**

---

### Indice dei Contenuti
1. [Visione Generale e Ruolo del Kernel](#1-visione-generale-e-ruolo-del-kernel)
2. [Principi Architetturali ed Efficienza Sistemica](#2-principi-architetturali-ed-efficienza-sistemica)
3. [Mappatura, Risoluzione Dispositivi e Aliasing](#3-mappatura-risoluzione-dispositivi-e-aliasing)
4. [Syscall Atomiche e Controllo Basso Livello](#4-syscall-atomiche-e-controllo-basso-livello)
5. [I 10 Sottosistemi Tipizzati di Dominio](#5-i-10-sottosistemi-tipizzati-di-dominio)
   - 5.1 [PowerSubsystem (`power`)](#51-powersubsystem-power)
   - 5.2 [PropulsionSubsystem (`propulsion`)](#52-propulsionsubsystem-propulsion)
   - 5.3 [NavigationSubsystem (`navigation`)](#53-navigationsubsystem-navigation)
   - 5.4 [SensorsSubsystem (`sensors`)](#54-sensorssubsystem-sensors)
   - 5.5 [CommsSubsystem (`comms`)](#55-commssubsystem-comms)
   - 5.6 [DefenseSubsystem (`defense`)](#56-defensesubsystem-defense)
   - 5.7 [LifeSupportSubsystem (`life_support`)](#57-lifesupportsubsystem-life_support)
   - 5.8 [LogisticsSubsystem (`logistics` / `cargo`)](#58-logisticssubsystem-logistics--cargo)
   - 5.9 [CyberSubsystem (`cyber`)](#59-cybersubsystem-cyber)
   - 5.10 [OpticsSubsystem (`optics`)](#510-opticssubsystem-optics)
6. [Bus Segnali ed Eventi Reattivi](#6-bus-segnali-ed-eventi-reattivi)
7. [Matrice di Interazione con i Componenti del Progetto](#7-matrice-di-interazione-con-i-componenti-del-progetto)
   - 7.1 [Integrazione con `ShipHardwareBus` e Componenti Fisici](#71-integrazione-con-shiphardwarebus-e-componenti-fisici)
   - 7.2 [Integrazione con la Simulazione Nave (`Spaceship` & `SpaceWorldManager`)](#72-integrazione-con-la-simulazione-nave-spaceship--spaceworldmanager)
   - 7.3 [Integrazione con le Applicazioni Desktop GodotOS](#73-integrazione-con-le-applicazioni-desktop-godotos)
   - 7.4 [Integrazione con la Suite CLI del Terminale e Virtual Sysfs](#74-integrazione-con-la-suite-cli-del-terminale-e-virtual-sysfs)
8. [Gestione dei Guasti, Ridondanza e Resilienza](#8-gestione-dei-guasti-ridondanza-e-resilienza)

---

### 1. Visione Generale e Ruolo del Kernel

La classe `ShipHAL` (`Outside/ShipSystems/HAL/ship_hal.gd`) opera come il **Kernel del Sistema Operativo di bordo** della nave stellare in *Dark Nova: Rogue Squadron*. 

La sua finalità primaria è massimizzare l'efficienza funzionale, la stabilità operativa e la tempestività decisionale dell'equipaggio, interponendosi tra due livelli strutturalmente eterogenei:
1. **Hardware Fisico Simulato**: I nodi componenti situati nelle varie stanze della nave (`ShipPhysicalComponent` derivati come reattori, propulsori, antenne, scudi, batterie), coordinati da `ShipHardwareBus`.
2. **Software Applicativo di Bordo**: L'interfaccia grafica utente (**GodotOS** desktop suite), i sottocomandi shell interattivi del **Terminale** navale e il filesystem virtuale `/sys/`.

Senza un'astrazione centralizzata, ogni applicazione software dovrebbe interrogare direttamente l'albero di scena fisico, gestendo registri eterogenei, race conditions e stati di disconnessione o danneggiamento con enorme spreco di risorse computazionali. `ShipHAL` normalizza e arbitra l'accesso alle risorse vitali (energia elettrica MW, capacità termica, spinta, dati telemetrici), garantendo che l'utilità complessiva della nave sia preservata anche durante guasti sistemici o blackout.

```
+-----------------------------------------------------------------------+
|                       APPLICAZIONI SOFTWARE                           |
|  [PowerGrid] [FlightControl] [Sensors] [Comms] [Weapons] [Terminal]   |
+-----------------------------------------------------------------------+
                                   ▲
                                   │ Chiamate di dominio / Segnali Push
                                   ▼
+-----------------------------------------------------------------------+
|                    ShipHAL (Ship Operating System)                    |
|  - 10 Sottosistemi Tipizzati (Power, Propulsion, Comms, Defense...)   |
|  - Kernel Syscalls, Normalizzazione Aliasing & Contratti Forwarded    |
|  - Arbitraggio Potenza Transitoria & Calcolo Integrità Sistemica     |
+-----------------------------------------------------------------------+
                                   ▲
                                   │ Telemetria hardware / Comandi bus
                                   ▼
+-----------------------------------------------------------------------+
|                   ShipHardwareBus & Physical Layer                    |
|  - Reactor, Batteries, Thrusters, Sensors, Antennas, Life Support...  |
+-----------------------------------------------------------------------+
```

---

### 2. Principi Architetturali ed Efficienza Sistemica

1. **Architettura Event-Driven (Push vs Polling)**:  
   Il kernel evita rigorosamente il polling ad alto costo in `_process` per il layer applicativo. I cambiamenti di stato generati dall'hardware (`ShipHardwareBus`) vengono catturati da `ShipHAL` e ritrasmessi istantaneamente tramite segnali tipizzati (`power_telemetry_updated`, `propulsion_profile_changed`, `defense_shields_updated`). Questo azzera i consumi di cicli CPU a riposo per le GUI.
2. **Arbitraggio Centralizzato delle Risorse Scarse**:  
   L'energia elettrica e la tolleranza termica sono risorse finite. Tramite la syscall `request_power_allocation()`, `ShipHAL` verifica lo stato della rete (evitando sovraccarichi con `power_ratio < 0.8` o condizioni di blackout) prima di consentire assorbimenti impulsivi da parte di armamenti ad alta energia o scansioni radar attive.
3. **Isolamento e Tolleranza ai Guasti (Graceful Degradation)**:  
   Se un componente fisico viene distrutto o disattivato (es. `nav_computer` o `helm_control`), `ShipHAL` non va in crash e non restituisce puntatori nulli alle GUI: degrada in modo controllato i sottosistemi esponendo codici di errore standard (`NAV_COMPUTER_OFFLINE`, efficienza propulsiva ridotta a 0.0, disattivazione controllata dei controlli di volo).

---

### 3. Mappatura, Risoluzione Dispositivi e Aliasing

Per garantire la massima flessibilità sia verso il codice legacy che verso i comandi CLI impartiti dall'utente sul terminale, `ShipHAL` incapsula tre dizionari costanti di traduzione:

- **`ROOM_ALIASES`**: Consente di riferirsi alle stanze usando sia la nomenclatura tecnica inglese che i termini operativi italiani (es. `"engine_room"` $\leftrightarrow$ `"sala_motori"`, `"bridge"` $\leftrightarrow$ `"ponte_comando"`, `"armory"` $\leftrightarrow$ `"armamenti"`, `"room_11"` $\leftrightarrow$ `"supporto_vitale_adv"`).
- **`DEVICE_ALIASES`**: Risolve gli identificatori dei dispositivi su eventuali alias storici o gruppi fisici (es. `"engine_main"` include `"thruster_01"`, `"thruster_02"`, `"engine_left"`; `"armory_defense"` include `"weapon_array"`, `"gestore_torrette"`).
- **`DEVICE_DEFAULT_ROOMS`**: Mappa la stanza predefinita in cui risiede ciascuna classe di apparato hardware (es. `"core_reactor"` $\rightarrow$ `"reactor"`, `"helm_control"` $\rightarrow$ `"bridge"`, `"antenna_array"` $\rightarrow$ `"comms"`).

#### Pipeline di Risoluzione Hardware (`find_component_for_device`):
Quando un'applicazione richiede l'accesso a un `device_id`:
1. Viene effettuato un lookup diretto su `ShipHardwareBus.has_component(device_id)`.
2. Se non presente, si scorrono gli alias registrati in `DEVICE_ALIASES`.
3. Se ancora non trovato, cerca il primo componente presente nella stanza corrispondente agli alias.
4. Se il bus non è agganciato o il componente fisico non è ancora istanziato, vengono consultate le definizioni fallback del `ShipBlueprint` tramite `_check_fallback_device_online()`.

---

### 4. Syscall Atomiche e Controllo Basso Livello

`ShipHAL` espone un set di chiamate di sistema (Syscall) per il controllo granulare dell'hardware:

- **`request_power_allocation(device_id: String, amount_mw: float) -> bool`**:  
  Determina se la griglia energetica può sostenere un picco transitorio di assorbimento senza innescare blackout sistemici. Ritorna `true` se il bilancio netto è sufficiente o se il rapporto potenza generata/richiesta è almeno dell'80%.
- **`execute_hardware_action(subsystem_name: String, action: String, params: Dictionary) -> Dictionary`**:  
  Punto di ingresso standardizzato per l'invio di azioni hardware atomiche provenienti da comandi CLI o script automatizzati:
  - `"propulsion"`: `"throttle"`, `"speed_limit"`, `"toggle_inertia"`, `"cruise"`.
  - `"navigation"`: `"calculate"`.
  - `"sensors"`: `"ping"`, `"sweep"`.
  - `"comms"`: `"rotate"`, `"lock"`, `"ew_link"`.
  - `"defense"`: `"fire"`, `"boost"`, `"vent"`.
  - `"life_support"`: `"temperature"`.
  - `"cargo"` / `"logistics"`: `"doors"`.
  - `"cyber"`: `"exploit"`.
  - `"optics"`: `"channel"`, `"floodlights"`.
- **`query_subsystem_health(subsystem_name: String) -> Dictionary`**:  
  Scansiona tutti i componenti appartenenti alla categoria indicata, calcolando la salute percentuale media, il power ratio medio e determinando lo stato consolidato (`ONLINE`, `DEGRADED`, `OFFLINE`).
- **`toggle_room_power(room_id: String, online: bool) -> void`**:  
  Interruttore breaker di compartimento. Spegne o alimenta simultaneamente tutti i dispositivi della stanza e aggiorna lo stato reattivo del `ShipBlueprint`.
- **`toggle_device_power(device_id: String, online: bool) -> bool`**:  
  Comanda l'accensione/spegnimento controllato del singolo apparato fisico.
- **`get_device_status(device_id: String) -> Dictionary`**:  
  Raccoglie una scheda telemetrica unificata (nome, stanza, stato alimentazione, salute %, assorbimento attuale, erogazione, categoria).
- **`reboot_device(device_id: String) -> bool`**:  
  Invia un comando di riavvio controllato via bus hardware.
- **`repair_device(device_id: String, amount: float = 100.0) -> bool`**:  
  Esegue la riparazione o manutenzione fisica del componente ripristinando la percentuale di integrità strutturale.

---

### 5. I 10 Sottosistemi Tipizzati di Dominio

All'inizializzazione (`_init_subsystems()`), `ShipHAL` istanzia dieci oggetti `RefCounted` dedicati, accessibili come proprietà pubbliche del kernel:

#### 5.1 PowerSubsystem (`power`)
Sovraintende alla generazione, accumulo e distribuzione dei MegaWatt della nave.
- `get_balance() -> Dictionary`: Ritorna potenza generata (`generated_mw`), assorbimento complessivo (`demanded_mw`), bilancio netto (`net_balance_mw`), rapporto di alimentazione (`power_ratio`), flag di blackout e carica attuale/massima delle batterie (`battery_charge_mj`).
- `set_reactor_target(target: float) -> bool`: Regola il registro di modulazione del carico del reattore a fusione principale.
- `autobalance() -> void`: Algoritmo di auto-ottimizzazione. Calcola il fabbisogno energetico totale dei carichi attivi e imposta il reattore con un margine di sicurezza ottimale (+15%), evitando sia il sottodimensionamento (blackout) che il sovraccarico termico da iper-generazione.
- `is_blackout() -> bool`: Verifica immediata dell'assenza di alimentazione della rete.
- `toggle_room(room_id: String, online: bool) -> void`: Chiusura o apertura dei breaker di linea della stanza.

#### 5.2 PropulsionSubsystem (`propulsion`)
Gestisce la mobilità vettoriale e i vincoli di pilotaggio.
- `get_status() -> Dictionary`: Ritorna lo stato combinato tra propulsori e computer di bordo del ponte comando (`can_control`, `available_thrust`, `max_thrust`, `efficiency`, `inertia_damping`, `speed_limiter`, `cruise_drive_enabled`).
- `can_control_flight() -> bool`: Verifica restrittiva: ritorna `true` **solo se** la console di pilotaggio (`helm_control`) è online, alimentata, e i motori principali sono alimentati e privi di guasti bloccanti.
- `apply_thrust(throttle: float) -> void`: Invia il segnale di spinta vettoriale (0.0 - 1.0) a tutti i `ThrusterComponent` di tipo primario registrati.
- `set_speed_limiter(val: float) -> bool`: Imposta il tetto di velocità massima ammessa dai computer di bordo (da 0.1 a 2.0).
- `toggle_inertia(enabled: bool) -> bool`: Abilita o disabilita gli stabilizzatori inerziali (RCS automatici per contrastare il drift newtoniano).
- `toggle_cruise(start: bool) -> bool`: Innesca o interrompe il Cruise Drive per viaggi sub-luce ad alta velocità.

#### 5.3 NavigationSubsystem (`navigation`)
Elabora le rotte e i salti tra quadranti e coordinate celesti.
- `get_status() -> Dictionary`: Telemetria del computer di navigazione (`nav_computer`), stato di calcolo rotta, coni d'ombra gravitazionale e waypoint attivi.
- `calculate_route(dest: Vector2) -> Dictionary`: Calcola distanza euclidea ed ETA in secondi verso le coordinate di destinazione. Se il computer di bordo è offline o guasto, rigetta la richiesta con errore formattato.
- `get_hyperdrive_solution() -> Dictionary`: Verifica la disponibilità del vettore di salto iperspaziale.

#### 5.4 SensorsSubsystem (`sensors`)
Monitora lo spazio circostante mediante scansioni radar attive e passive.
- `get_status() -> Dictionary`: Raggio radar passivo (nominale 1000m), raggio ping attivo (2000m), bersagli tracciati e disponibilità dello sweep continuo.
- `get_contacts() -> Array[Dictionary]`: Ritorna l'elenco dei contatti rilevati (navi, detriti, asteroidi, sonde).
- `trigger_active_ping() -> Array`: Attiva una scarica ad alta intensità della matrice sensori (richiede potenza impulsiva) per scoprire contatti occultati oltre la portata standard.
- `toggle_sweep(enabled: bool) -> bool`: Attiva la rotazione motorizzata dell'array sensori.

#### 5.5 CommsSubsystem (`comms`)
Gestisce l'antenna a guadagno orientabile, lo spettro radio e i ponti di guerra elettronica.
- `get_status() -> Dictionary`: Azimut attuale dell'antenna (0 - 360°), frequenza agganciata (`locked_freq`), stato scansione automatica e connessione EW cyber attiva.
- `rotate_antenna(degrees: float) -> bool`: Modifica l'angolo di puntamento verso stazioni o bersagli.
- `toggle_scan(enabled: bool) -> bool`: Avvia la scansione dello spettro di frequenza sub-spaziale.
- `lock_frequency(freq: float) -> bool`: Sintonizza e aggancia una specifica frequenza portante.
- `establish_ew_link(target_id: String) -> bool`: Stabilisce una connessione di guerra elettronica (EW) per trasmettere payload informatici verso un vascello nemico.
- `disconnect_ew_link() -> void`: Interrompe l'aggancio cyber.
- `get_visible_frequencies() -> Array[float]`: Elenca le frequenze rilevate nello spettro locale (es. 1420 MHz, 1920 MHz, 433 MHz).

#### 5.6 DefenseSubsystem (`defense`)
Coordina lo scudo energetico deflettore e gli accumulatori d'arma.
- `get_status() -> Dictionary`: Integrità dei 4 quadranti di scudo (`front`, `rear`, `left`, `right`), distribuzione vettoriale dell'energia, stato del boost di emergenza e carica dei condensatori laser.
- `set_shield_distribution(dist: Vector2) -> bool`: Regola i bilanciatori di scudo direzionando l'energia protettiva verso i settori esposti (prua, poppa, fiancata sinistra, fiancata destra).
- `activate_shield_boost(quadrant: String) -> bool`: Sovralimenta temporaneamente il quadrante specificato sacrificando riserve ausiliarie (soggetto a cooldown).
- `request_weapon_discharge(weapon_type: String) -> bool`: Richiede l'innesco dei condensatori e lo sparo delle torrette dell'armeria.
- `trigger_emergency_venting() -> bool`: Espelle istantaneamente calore accumulato dai banchi laser per prevenire il meltdown dell'armeria.

#### 5.7 LifeSupportSubsystem (`life_support`)
Regola i parametri biologici dell'atmosfera interna e il comfort dei compartimenti.
- `get_status() -> Dictionary`: Concentrazione O2 (%), accumulo CO2 (%), temperatura cabina (°C) e stato generale dei filtri scrubber.
- `set_target_temp(target: float) -> bool`: Imposta il termostato di bordo verso il riscaldatore/climatizzatore principale.
- `replace_filters() -> bool`: Resetta l'efficienza dei purificatori d'aria chimici per il riciclo della CO2.

#### 5.8 LogisticsSubsystem (`logistics` / `cargo`)
Sovraintende alle stive di carico, alle morse magnetiche e alle flotte di droni ausiliari.
*(Esposto sia come `hal.logistics` sia tramite l'alias retrocompatibile `hal.cargo`).*
- `get_status() -> Dictionary`: Stato portelloni stiva, morse magnetiche ancorate, raffinazione minerali in corso, percentuale di ricarica droni e drone EVA agganciato al pod.
- `toggle_cargo_doors(open: bool) -> bool`: Apertura o chiusura pressurizzata dei portelloni di carico.
- `toggle_magnetic_clamps(clamped: bool) -> bool`: Attivazione/disattivazione morse magnetiche per il blocco del carico inerte.
- `charge_duct_drone(current_battery: float, delta: float) -> float`: Ricarica a induzione della batteria del drone da condotta (`DuctDrone`) quando si trova nel dock della stiva.
- `dock_eva_drone() -> bool` & `launch_eva_drone() -> bool`: Comandi di rientro e rilascio del drone esterno per riparazioni EVA.

#### 5.9 CyberSubsystem (`cyber`)
Amministra il mainframe della nave, il firewall reattivo e i vettori di intrusione.
- `get_status() -> Dictionary`: Integrità del firewall di bordo (%), stato di attivazione, carico CPU del server rack, exploit attivo in esecuzione e disponibilità del coprocessore crittografico.
- `start_exploit(name: String) -> bool`: Carica ed esegue un payload malevolo contro un bersaglio connesso via link EW.
- `cancel_exploit() -> void`: Interrompe immediatamente il thread di attacco in corso.
- `execute_crypto_op(op: String) -> bool`: Esegue operazioni di decifrazione, hashing o cifratura sui file di sistema protetti.

#### 5.10 OpticsSubsystem (`optics`)
Comanda il circuito visivo esterno e l'illuminazione perimetrale.
- `get_status() -> Dictionary`: Canale video attualmente attivo (1-6), nome telecamera, stato del segnale feed e maschera bitwise dei proiettori scafo accesi.
- `set_active_channel(ch: int) -> bool`: Commuta il flusso video verso la telecamera perimetrale selezionata (Prua, Poppa, Babordo, Tribordo, Dorso, Ventre).
- `toggle_floodlight(ch: int, on: bool) -> bool`: Accende/spegne il faro ausiliario associato alla singola telecamera.
- `toggle_all_floodlights(on: bool) -> bool`: Comando master per l'illuminazione esterna totale dello scafo.

---

### 6. Bus Segnali ed Eventi Reattivi

Tutti gli eventi critici rilevati a livello fisico vengono propagati alle applicazioni connesse mediante segnali Godot tipizzati:

| Segnale | Parametri Emessi | Finalità e Riceventi Principali |
|---|---|---|
| `propulsion_profile_changed` | `(eff: float, max_th: float, avail_th: float)` | Notifica variazioni di spinta utile a `FlightControlApp` e comandi `flight`. |
| `flight_controls_state_changed` | `(can_control: bool)` | Blocca o sblocca la barra di controllo e la manetta su GUI e terminale. |
| `power_telemetry_updated` | `(gen_mw: float, dem_mw: float, ratio: float, blackout: bool)` | Aggiorna grafici e allarmi in `PowerGridApp` e cruscotto generale. |
| `thermal_telemetry_updated` | `(total_heat: float, avg_temp: float)` | Monitoraggio termico scafo e rischio surriscaldamento. |
| `hardware_integrity_changed` | `(dev_id: String, health: float, status: String)` | Aggiorna lo stato diagnostico in `DiagnosticsApp` e sysfs. |
| `system_alert_emitted` | `(alert_type: String, message: String)` | Notifiche push di emergenza per l'equipaggio. |
| `life_support_updated` | `(o2: float, co2: float, cabin_temp: float)` | Dati telemetrici per `LifeSupportApp`. |
| `navigation_route_updated` | `(dest: Vector2, dist: float, eta: float)` | Sincronizzazione rotta con la mappa stellare e comandi `nav`. |
| `sensor_sweep_updated` | `(targets: Array)` | Invio lista bersagli rilevati a `SensorsApp`. |
| `comms_state_updated` | `(freq: float, ew_connected: bool)` | Stato frequenza sintonizzata e link EW verso `CommsApp` e `HackExploitsApp`. |
| `defense_shields_updated` | `(front: float, rear: float, left: float, right: float)` | Quadranti scudi per `ShieldMatrixApp` e indicatori HUD. |
| `cyber_firewall_updated` | `(integrity: float, active: bool)` | Salute del firewall per `HackExploitsApp`. |
| `optics_feed_updated` | `(channel: int, status: String)` | Aggiornamento canali per `CamsApp`. |
| `device_lifecycle_changed` | `(device_id: String, action: String)` | Rileva apparati registrati o rimossi a caldo su `ShipHardwareBus`. |

---

### 7. Matrice di Interazione con i Componenti del Progetto

```mermaid
graph LR
    subgraph HARDWARE_LAYER [Livello Hardware Fisico]
        BUS[ShipHardwareBus]
        COMP[20+ ShipPhysicalComponents]
        BUS --- COMP
    end

    subgraph KERNEL [Operating System Kernel]
        HAL[ShipHAL]
    end

    subgraph SYSTEM_MANAGERS [Manager Globali]
        SWM[SpaceWorldManager]
        SHIP[Spaceship RigidBody3D]
        BLUEPRINT[ShipBlueprint]
    end

    subgraph GUI_APPS [GodotOS Desktop Apps]
        APP_PWR[PowerGridApp]
        APP_FLT[FlightControlApp]
        APP_SNS[SensorsApp]
        APP_CMS[CommsApp]
        APP_WPN[WeaponsApp & ShieldMatrixApp]
        APP_LS[LifeSupportApp]
        APP_CRG[CargoBayApp]
        APP_DIA[DiagnosticsApp]
        APP_CYB[HackExploitsApp]
        APP_CAM[CamsApp]
    end

    subgraph CLI_LAYER [Terminale & Virtual Sysfs]
        CMD_FLT[flight_command]
        CMD_NAV[nav_command]
        CMD_SNS[sensors_command]
        CMD_CMS[comms_command]
        CMD_DEV[dev_command]
        SYSFS[VirtualSysfsDriver]
    end

    HARDWARE_LAYER <-->|Eventi Bus / Registri| HAL
    HAL <-->|Sincronizzazione Breaker & Stato| BLUEPRINT
    SWM -->|get_ship_hal() Provider| HAL
    HAL <-->|Telemetria Propulsione & Spinta| SHIP

    HAL -->|Segnali Reattivi| GUI_APPS
    GUI_APPS -->|Syscall di Dominio| HAL

    HAL -->|Stato Hardware & Syscall| CLI_LAYER
    SYSFS -->|Lettura/Scrittura Registri| HARDWARE_LAYER
```

#### 7.1 Integrazione con `ShipHardwareBus` e Componenti Fisici
- `ShipHardwareBus` gestisce la simulazione dei circuiti e la lista delle istanze fisiche concrete (`ReactorComponent`, `BatteryComponent`, `ThrusterComponent`, `HelmControlComponent`, `NavComputerComponent`, `SensorsMatrixComponent`, `AntennaArrayComponent`, `ArmoryDefenseComponent`, `ShieldBalancerComponent`, `LifeSupportComponent`, `CargoHandlingComponent`, `RechargeDockComponent`, `DroneStationComponent`, `ServerRackComponent`, `CamArrayComponent`, `CoolingComponent`).
- All'avvio, `ShipHAL` ascolta i segnali del bus (`device_registered`, `telemetry_received`, `power_grid_balanced`, `thermal_grid_updated`, `blackout_state_changed`).
- In risposta, invoca `_refresh_all_domains()` ed emette i rispettivi segnali riepilogativi verso il software.

#### 7.2 Integrazione con la Simulazione Nave (`Spaceship` & `SpaceWorldManager`)
- In `Outside/spaceship.gd`, la fisica newtoniana del `RigidBody3D` interroga continuamente `hal.propulsion.can_control_flight()`, `hal.get_propulsion_efficiency()` e `hal.get_total_available_thrust()` per calcolare l'effettiva forza di spinta e la reattività dei propulsori di manovra (RCS).
- `SpaceWorldManager` agisce come fornitore globale singleton di `ShipHAL` tramite `SpaceWorldManager.get_ship_hal()`, garantendo istanza unica e persistente tra i caricamenti di scena.

#### 7.3 Integrazione con le Applicazioni Desktop GodotOS
Tutte le finestre applicative si collegano a `ShipHAL` per visualizzare lo stato e inoltrare comandi:
- **`PowerGridApp`**: Mostra la telemetria MW, comanda i breaker per stanza con `hal.toggle_room_power()`, invoca `hal.power.autobalance()` e modula il reattore.
- **`FlightControlApp`**: Riceve `propulsion_profile_changed`, mostra il badge dell'efficienza motori, disabilita l'interfaccia se `can_control` è falso, attiva cruise mode o damping.
- **`SensorsApp`**: Esegue scansioni attive tramite `hal.sensors.trigger_active_ping()` e riceve l'array dei contatti con `sensor_sweep_updated`.
- **`CommsApp`**: Orienta l'antenna con `hal.comms.rotate_antenna()`, aggancia le frequenze e attiva il ponte EW verso vascelli target.
- **`WeaponsApp` & `ShieldMatrixApp`**: Ripartiscono l'energia degli scudi sui 4 quadranti con `hal.defense.set_shield_distribution()`, eseguono il boost d'emergenza e ordinano il fuoco laser.
- **`LifeSupportApp`**: Regola il target termico di cabina e comanda la sostituzione filtri chimici.
- **`CargoBayApp`**: Comanda l'apertura portelloni, le morse di sicurezza e gestisce la ricarica/lancio dei droni.
- **`DiagnosticsApp`**: Calcola l'indice di salute nave aggregato con `hal.get_overall_system_integrity()`, visualizza la lista dei componenti danneggiati con `hal.get_damaged_components()` ed esegue reboot o riparazioni mirate.
- **`HackExploitsApp`**: Interagisce con `hal.cyber` per lanciare o annullare script malevoli sul bersaglio collegato via EW.
- **`CamsApp`**: Commuta il canale video attivo tra le 6 telecamere e accende i fari dello scafo.

#### 7.4 Integrazione con la Suite CLI del Terminale e Virtual Sysfs
- I comandi shell (`flight`, `nav`, `sensors`, `comms`, `dev`) istanziano chiamate verso `hal.execute_hardware_action()` o direttamente sui sottosistemi di dominio.
- Il comando `dev` interroga l'integrità del bus (`dev bus`, `dev list`, `dev status <id>`) e permette l'accensione/spegnimento (`dev online <id> <1|0>`).
- Il driver `VirtualSysfsDriver` consente la manipolazione di registri hardware direttamente da percorsi virtuali `/sys/rooms/<stanza>/<device>/<registro>`, sincronizzandosi in tempo reale con i sottosistemi di `ShipHAL`.

---

### 8. Gestione dei Guasti, Ridondanza e Resilienza

Per assicurare la massima utilità operativa in situazioni critiche (combattimento, impatti di asteroidi, guasti sistemici), `ShipHAL` adotta strategie avanzate di resilienza:

1. **Gestione del Blackout Totale**:  
   Se il generatore va offline e le batterie si esauriscono (`is_blackout == true`), `ShipHAL` inibisce istantaneamente ogni richiesta di consumo energetico (`request_power_allocation` ritorna `false`), blocca i comandi di propulsione (`can_control_flight == false`) ed emette il segnale reattivo `power_telemetry_updated` con `ratio = 0.0` e `blackout = true`, provocando l'oscuramento coordinato delle relative interfacce utente.
2. **Degrado Parziale dell'Hardware**:  
   Se un propulsore subisce un danno strutturale del 50%, `ShipHAL` non interrompe il volo: ricalcola la spinta disponibile (`available_thrust`) e l'efficienza proporzionale, aggiornando la nave e la GUI con l'avviso di efficienza ridotta senza causare errori a runtime.
3. **Modalità Standalone e Blueprint Fallback**:  
   Qualora `ShipHAL` venga eseguito senza un'istanza attiva di `ShipHardwareBus` (es. in scenari di test isolati o prima del caricamento della simulazione 3D), i metodi del kernel ripiegano su valori di sicurezza nominali (100% salute, dati telemetrici sintetici coerenti) e interrogano direttamente le proprietà statiche di `ShipBlueprint`, impedendo crash da dereferenziazione di puntatori nulli.
4. **Verificabilità e Manutenibilità**:  
   Il comportamento atomico del kernel e di tutti i suoi 10 sottosistemi è interamente coperto dalla suite di test automatici GUT (`tests/gut/test_ship_hal_os_kernel.gd` e `tests/gut/test_hal_applications_flow.gd`), garantendo che qualsiasi modifica futura rispetti i contratti di integrazione stabiliti.
