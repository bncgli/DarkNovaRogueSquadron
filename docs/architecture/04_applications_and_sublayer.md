# 04. Architettura Applicazioni GodotOS, ShipHAL OS e Sublayer Hardware

In **Dark Nova: Rogue Squadron**, le applicazioni eseguite sul desktop virtuale (GodotOS) non sono semplici widget grafici isolati, ma interfacce diegetiche che comunicano con l'hardware della nave attraverso un vero e proprio sistema operativo di bordo: **`ShipHAL` (Hardware Abstraction Layer & Ship OS Kernel)**.

Tutti i dispositivi fisici definiti nello `ShipBlueprint` sono entità simulate indipendenti registrate su **`ShipHardwareBus`**, ciascuna dotata di registri I/O, calcolo energetico/termico continuo e logica di degradazione autonoma su deficit di alimentazione o brownout.

---

## 🖥️ Grafo Architetturale Software <-> ShipHAL OS <-> Hardware Bus <-> Entità Fisiche

```mermaid
graph TD
    classDef appNode fill:#1e293b,stroke:#38bdf8,stroke-width:2px,color:#fff;
    classDef osNode fill:#1e293b,stroke:#ec4899,stroke-width:2px,color:#fff;
    classDef busNode fill:#1e293b,stroke:#10b981,stroke-width:2px,color:#fff;
    classDef compNode fill:#1e293b,stroke:#f59e0b,stroke-width:2px,color:#fff;
    classDef hardNode fill:#1e293b,stroke:#8b5cf6,stroke-width:2px,color:#fff;

    subgraph SOFTWARE_LAYER [Software di Bordo - GodotOS & CLI Terminal]
        FlightApp[FlightControl App]:::appNode
        PowerApp[PowerGrid App]:::appNode
        ShieldApp[ShieldMatrix App]:::appNode
        DuctApp[DuctDrone App]:::appNode
        ServApp[ServiceDrone App]:::appNode
        LifeApp[LifeSupport App]:::appNode
        DiagApp[Diagnostics App]:::appNode
        SensApp[Sensors App]:::appNode
        WeapApp[Weapons App]:::appNode
        CargoApp[CargoBay App]:::appNode
        HackApp[HackExploits App]:::appNode
        CamsApp[Cams App]:::appNode
        TermApp[Terminal CLI Commands]:::appNode
    end

    subgraph OS_KERNEL [ShipHAL - Ship Operating System Kernel]
        HAL_Power[Power Subsystem]:::osNode
        HAL_Prop[Propulsion Subsystem]:::osNode
        HAL_Nav[Navigation Subsystem]:::osNode
        HAL_Sens[Sensors Subsystem]:::osNode
        HAL_Comms[Comms Subsystem]:::osNode
        HAL_Def[Defense Subsystem]:::osNode
        HAL_Life[LifeSupport Subsystem]:::osNode
        HAL_Cargo[Logistics & Cargo Subsystem]:::osNode
        HAL_Cyber[Cyber Warfare Subsystem]:::osNode
        HAL_Opt[Optics Subsystem]:::osNode
    end

    subgraph BUS_INFRASTRUCTURE [Infrastruttura di Rete & Potenza]
        HWBUS[ShipHardwareBus: Bilanciamento O(N) e Caching Telemetria]:::busNode
    end

    subgraph PHYSICAL_COMPONENTS [Hardware Simulato - 19 Dispositivi Canonici]
        CoreReactor[ReactorComponent: core_reactor]:::compNode
        Battery01[BatteryComponent: battery_01]:::compNode
        Cooling01[CoolingComponent: cooling_01]:::compNode
        EngineMain[ThrusterComponent: engine_main]:::compNode
        RcsThrusters[ThrusterComponent: rcs_pitch_l / r]:::compNode
        HelmComp[HelmControlComponent: helm_control]:::compNode
        NavComp[NavComputerComponent: nav_computer]:::compNode
        SensMatrix[SensorsMatrixComponent: sensors_matrix]:::compNode
        AntennaComp[AntennaArrayComponent: antenna_array]:::compNode
        ArmoryComp[ArmoryDefenseComponent: armory_defense]:::compNode
        ShieldBalancers[ShieldBalancerComponent: arm_sx/dx_balancer]:::compNode
        LifeSuppComp[LifeSupportComponent: scrubber / heater / serra]:::compNode
        CargoComp[CargoHandlingComponent: cargo_handling]:::compNode
        DroneStations[DroneStationComponent & RechargeDock]:::compNode
        ServerRackComp[ServerRackComponent: server_rack]:::compNode
        CamArrayComp[CamArrayComponent: cam_array]:::compNode
    end

    subgraph WORLD_3D [Mondo 3D & Attuatori Fisici]
        Spaceship3D[Spaceship 3D Rigidbody]:::hardNode
        CruiseController[CruiseDriveController: 160 m/s]:::hardNode
        DeflectorShields[Scudi Deflettori 4 Quadranti]:::hardNode
        BallisticWeapons[Armi Balistiche & Torrette]:::hardNode
        Drones3D[Droni EVA e Condotti]:::hardNode
    end

    %% Software -> OS
    PowerApp <--> HAL_Power
    FlightApp <--> HAL_Prop
    FlightApp & TermApp <--> HAL_Nav
    SensApp & TermApp <--> HAL_Sens
    CommsApp & TermApp <--> HAL_Comms
    ShieldApp & WeapApp <--> HAL_Def
    LifeApp <--> HAL_Life
    CargoApp & ServApp & DuctApp <--> HAL_Cargo
    HackApp <--> HAL_Cyber
    CamsApp <--> HAL_Opt
    DiagApp & TermApp <--> OS_KERNEL

    %% OS -> HardwareBus
    OS_KERNEL <--> HWBUS

    %% HardwareBus -> Physical Components
    HWBUS <--> CoreReactor & Battery01 & Cooling01
    HWBUS <--> EngineMain & RcsThrusters & HelmComp & NavComp
    HWBUS <--> SensMatrix & AntennaComp & ArmoryComp & ShieldBalancers
    HWBUS <--> LifeSuppComp & CargoComp & DroneStations & ServerRackComp & CamArrayComp

    %% Physical Components -> World 3D
    EngineMain & RcsThrusters --> Spaceship3D & CruiseController
    ShieldBalancers --> DeflectorShields
    ArmoryComp --> BallisticWeapons
    DroneStations --> Drones3D
```

---

## ⚙️ Sottosistemi Tipizzati di ShipHAL (Ship OS)

`ShipHAL` incapsula l'accesso diretto ai registri hardware ed espone classi di servizio fortemente tipizzate:

1. **`hal.power` (PowerSubsystem)**:
   - Monitoraggio telemetrico della rete (`generated_mw`, `demanded_mw`, `power_ratio`, `is_blackout`).
   - Controllo modulazione del reattore a fusione tokamak e attivazione dell'autobilanciamento.
   - Apertura/chiusura breaker delle stanze per prevenire blackout o isolare guasti.

2. **`hal.propulsion` (PropulsionSubsystem)**:
   - Coordinamento spinta combinata, controllo timone WASD/QE e moltiplicatore di velocità (`speed_limiter`).
   - Gestione stabilizzazione inerziale e disingaggio di sicurezza del Cruise Drive in caso di deficit energetico.

3. **`hal.navigation` (NavigationSubsystem)**:
   - Elaborazione rotta verso coordinate di settore, stima distanza ed ETA.
   - Soluzione vettoriale per il salto Hyperdrive e proiezioni dei coni d'ombra gravitazionali.

4. **`hal.sensors` (SensorsSubsystem)**:
   - Feed contatti radar tracciati dal phased array a 360°.
   - Impulso ad alta energia Ping Attivo (120 MW) e controllo velocità di scansione.

5. **`hal.comms` (CommsSubsystem)**:
   - Orientamento azimutale dell'antenna parabolica e scansione automatica delle frequenze.
   - Sintonizzazione frequenze radio subspazio e stabilizzazione data link EW.

6. **`hal.defense` (DefenseSubsystem)**:
   - Modulazione e rigenerazione bolla scudi a 4 quadranti (Prua, Poppa, Babordo, Tribordo).
   - Ricarica condensatori laser e autorizzazione scarica delle torrette.
   - Scarico termico di emergenza (Emergency Venting).

7. **`hal.life_support` (LifeSupportSubsystem)**:
   - Monitoraggio e rigenerazione atmosfera (O2, CO2, integrità filtri scrubber).
   - Termoregolazione della cabina verso la temperatura obiettivo (21°C).

8. **`hal.logistics` / `hal.cargo` (LogisticsSubsystem)**:
   - Serrande dei portelloni di carico e bloccaggio magnetico container.
   - Stazioni di ricarica induttiva per drone condotti e drone EVA esterno.

9. **`hal.cyber` (CyberSubsystem)**:
   - Stato e integrità del firewall di bordo.
   - Esecuzione exploit contro target drive remoti e operazioni crittografiche sicure su ship drive locale.

10. **`hal.optics` (OpticsSubsystem)**:
    - Selezione e routing dei 6 canali video CCTV perimetrali.
    - Accensione selettiva dei fari di illuminazione scafo.

---

## 🛡️ Matrice Ruoli RBAC (Role-Based Access Control)

Le applicazioni rispettano i ruoli dell'equipaggio gestiti da `ShipSoftwareManager`:

| Applicazione / Strumento | Capitano | Pilota | Ingegnere | Soldato | Hacker | Factotum |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| `FlightControl` | 👁️ Sola lettura | ✅ Controllo Totale | ❌ | ❌ | ⚠️ Override Shell | ✅ Pieno Controllo |
| `PowerGrid` | 👁️ Sola lettura | ❌ | ✅ Controllo Totale | ❌ | ⚠️ Deviazione Rete | ✅ Pieno Controllo |
| `ShieldMatrix` | 👁️ Sola lettura | ❌ | ✅ Calibrazione | ✅ Modulazione Angoli | ⚠️ Spoofing Frequenze | ✅ Pieno Controllo |
| `Weapons` | ✅ Autorizzazione | ❌ | ❌ | ✅ Controllo Torrette | ⚠️ Lock Puntamento | ✅ Pieno Controllo |
| `Sensors` | ✅ Monitoraggio | 👁️ Coordinate | ❌ | 👁️ Target IFF | ⚠️ Intercettazione | ✅ Pieno Controllo |
| `Comms` | ✅ Canale Ufficiale | 👁️ Frequenze Volo | ❌ | ❌ | ✅ Decodifica Criptata | ✅ Pieno Controllo |
| `LifeSupport` | ✅ Monitoraggio | ❌ | ✅ Regolazione Valvole | ❌ | ⚠️ Controllo Atmosfera | ✅ Pieno Controllo |
| `CargoBay` | ✅ Gestione Merci | ❌ | ❌ | ❌ | ⚠️ Falsificazione Bolle | ✅ Pieno Controllo |
| `ServiceDrone` / `DuctDrone` | ❌ | ⚠️ Manovra | ✅ Riparazioni | ⚠️ Saldatura Laser | ⚠️ Hacking Subroutine | ✅ Pieno Controllo |
| `HackExploits` | ❌ | ❌ | ❌ | ❌ | ✅ Suite Completa | ✅ Pieno Controllo |
| `Cams` | ✅ Monitoraggio | 👁️ Prua/Poppa | 👁️ Sala Motori | 👁️ Vano Armi | ⚠️ Blind Eye | ✅ Pieno Controllo |
| `Diagnostics` | ✅ Stato Generale | ✅ Allarmi Volo | ✅ Dettaglio Bus | ✅ Mappa Danni | ✅ Dump Registri | ✅ Pieno Controllo |
| `Terminal` (CLI) | ✅ Comandi Base | ✅ `flight`, `nav` | ✅ `dev` | ✅ `weapons` | ✅ `comms`, `sysfs` | ✅ Tutti i comandi |

---

## 📄 Modello Dati e Serializzazione

I file di configurazione (.dat) risiedono in `Ship Drive/Programs/[NomeApp]/` e consentono la calibrazione diegetica dei parametri di runtime.
I blueprint navali e le stanze utilizzano il modello unificato a classi `Resource` (`ShipBlueprint`, `ShipRoomData`, `ShipDeviceData`), garantendo tipizzazione statica, serializzazione pulita in `.tres` e ispezione completa tramite l'editor di sublayer in Godot.
