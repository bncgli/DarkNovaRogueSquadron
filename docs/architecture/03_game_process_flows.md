# 03. Flussi di Processo e Ciclo di Vita del Gioco

Questo documento descrive i principali **flussi di processo sequenziali e logici** di **Dark Nova: Rogue Squadron**, illustrando come gli eventi viaggiano attraverso la rete, la GUI di GodotOS e la simulazione spaziale 3D.

---

## 🚀 Flusso 1: Boot Splash, OS Init e Caricamento Desktop

```mermaid
sequenceDiagram
    autonumber
    actor Player as Giocatore
    participant Main as MainScene (main.gd)
    participant Boot as BootSplash
    participant GV as GlobalValues
    participant Desktop as Desktop / Taskbar
    participant WinMgr as WindowManager

    Player->>Main: Avvio Gioco (Godot Engine)
    Main->>Boot: Inizializza animazione splash
    Main->>GV: Carica impostazioni utente e risoluzione
    Boot-->>Main: Segnale splash_finished
    Main->>Desktop: Istanzia Desktop diegetico GodotOS
    Desktop->>Desktop: Carica Taskbar, Orologio, Start Menu
    Desktop->>WinMgr: Inizializza gestore finestre flottanti
    Desktop->>Player: Desktop pronto (Icona Lobby & Terminal visibili)
```

---

## 👥 Flusso 2: Lobby, Matchmaking, Selezione Ruoli (RBAC) e Avvio Partita

```mermaid
sequenceDiagram
    autonumber
    actor Host as Host (Capitano)
    actor Client as Peer (Client)
    participant Lobby as LobbyApp
    participant NM as NetworkManager
    participant SSM as ShipSoftwareManager
    participant SWM as SpaceWorldManager
    participant SSGM as StarSystemGridManager

    Host->>Lobby: Crea Stanza (Host Mode)
    Client->>Lobby: Unisciti a IP/Porta
    Lobby->>NM: create_client()
    NM-->>Host: RPC: peer_connected(client_id)
    Host->>Lobby: Seleziona ShipBlueprint & SectorData custom
    Client->>Lobby: Seleziona Ruolo (es. Ingegnere / Pilota)
    Lobby->>NM: RPC: sync_player_role(peer_id, role)
    NM-->>Host: Aggiorna Matrice Ruoli
    NM-->>Client: Aggiorna Matrice Ruoli
    
    Host->>Lobby: Clicca "AVVIA MISSIONE"
    Lobby->>NM: RPC: start_game_session()
    NM->>SSGM: Inizializza Settore & Griglia
    NM->>SWM: spawn_ship(blueprint)
    NM->>SSM: filter_apps_for_role(peer_id)
    SSM-->>Client: Installa App autorizzate sul Desktop
    SSM-->>Host: Installa App autorizzate sul Desktop
    SWM-->>Host: Rimuove overlay "Sistemi Offline"
    SWM-->>Client: Rimuove overlay "Sistemi Offline"
```

---

## 🧭 Flusso 3: Ciclo di Navigazione, Settori e Griglia Stellare (`StarSystemGrid`)

```mermaid
flowchart TD
    classDef step fill:#1e293b,stroke:#38bdf8,stroke-width:2px,color:#fff;
    classDef decision fill:#334155,stroke:#f59e0b,stroke-width:2px,color:#fff;
    classDef action fill:#0f172a,stroke:#10b981,stroke-width:2px,color:#fff;

    Start([Inizio Settore]):::step --> DetectCoord[FlightControl legge coordinate attuali da SSGM]:::step
    DetectCoord --> PilotAction{Azione Pilota}:::decision
    
    PilotAction -->|Volo Sub-Luce| Cruise[Attivazione CruiseDriveController]:::action
    Cruise --> MoveShip[Spaceship applica forze fisiche 3D]:::step
    MoveShip --> BoundsCheck{Raggiunto bordo settore?}:::decision
    BoundsCheck -->|No| MoveShip
    BoundsCheck -->|Sì| TriggerSubwarp[Transizione automatica a coordinate contigue]:::action

    PilotAction -->|Salto Iperspazio| TargetSelect[Selezione Settore Mappa in StarSystemGrid]:::step
    TargetSelect --> EngCheck{Energia & Warp Drive OK?}:::decision
    EngCheck -->|No| WarpError[Allarme: Sovraccarico o Energia insufficiente]:::step
    EngCheck -->|Sì| WarpCharge[Caricamento Motore a Curvatura]:::action
    WarpCharge --> Jump[Esecuzione Salto Iperspazio]:::action
    Jump --> DespawnOld[SWM: Despawn entità vecchio settore]:::step
    DespawnOld --> SpawnNew[SWM: Spawn stazioni, asteroidi e nemici nuovo settore]:::step
    SpawnNew --> FinalSector([Arrivo nel Nuovo Settore]):::step
```

---

## ⚔️ Flusso 4: Combattimento, Danno Sistemico e IA Nemica

```mermaid
sequenceDiagram
    autonumber
    participant AI as EnemyShipAI
    participant CD as CombatDirector
    participant Ship as Spaceship 3D
    participant Sublayer as SystemicDamageHandler / Sublayer
    participant Power as PowerGrid / Diagnostics
    participant Cams as CamsApp / Allarmi

    AI->>CD: Target acquisito (Nave Giocatore a raggio tiro)
    AI->>Ship: Fuoco Laser / Lancio Siluro
    Ship->>Ship: Calcolo impatto su Scudi Deflettori
    alt Scudi Attivi e Carichi
        Ship->>Ship: Assorbimento scudo (-energia scudo)
    else Scudi Scarichi o Penetrati
        Ship->>Sublayer: Calcolo punto di impatto su griglia sublayer
        Sublayer->>Sublayer: Danno a componente specifico (es. Reattore, Condotto O2)
        Sublayer->>Power: Notifica guasto hardware / black-out linea
        Sublayer->>Cams: Trigger allarme visivo & spia fumo
        Sublayer->>DiagnosticsApp: Aggiorna mappa integrità componenti
    end
```

---

## ⛏️ Flusso 5: Ciclo Minerario, Derelitti ed Economia Flux

```mermaid
flowchart LR
    classDef entity fill:#1e293b,stroke:#a855f7,stroke-width:2px,color:#fff;
    classDef process fill:#0f172a,stroke:#3b82f6,stroke-width:2px,color:#fff;
    classDef store fill:#1e293b,stroke:#ec4899,stroke-width:2px,color:#fff;

    Sensor[SensorsApp: Scan Settore]:::process --> Deposit[Giacimento Minerale / Relitto]:::entity
    Deposit --> DroneEVA[ServiceDrone: Lancio e Manovra EVA]:::process
    DroneEVA --> Extract[Laser di Taglio & Raccolta Frammenti]:::process
    Extract --> CargoTrans[Trasferimento Stiva: CargoManager]:::store
    CargoTrans --> Refinery[CargoBay: Raffinazione Grezzo -> Lingotti]:::process
    Refinery --> Station[Attracco a Stazione: StationHub]:::entity
    Station --> Sell[Vendita Merci: FluxEconomyManager]:::process
    Sell --> Gain[Guadagno Crediti Flux per l'Equipaggio]:::store
```

---

## ⚓ Flusso 6: Attracco e Hub Stazione Spaziale

```mermaid
sequenceDiagram
    autonumber
    actor Pilot as Pilota
    participant Flight as FlightControl
    participant DockMgr as DockingManager
    participant Station as SpaceStationEntity
    participant Hub as StationHubApp
    participant Econ as FluxEconomyManager / CargoManager

    Pilot->>Flight: Avvicinamento all'Hangar Stazione (< raggio attracco)
    DockMgr->>Station: Verifica permessi attracco & allineamento
    Station-->>DockMgr: Autorizzazione concessa
    DockMgr->>Flight: Aggancio magnetico & Spegnimento motori
    DockMgr->>Hub: Apertura automatica StationHub su GodotOS
    Hub->>Econ: Recupera listino prezzi stazione e contratti
    Hub-->>Pilot: Mostra opzioni: Riparazione Scafo, Ricarica Reattore, Compravendita Merci, Contratti
```
