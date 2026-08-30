# TASK: Configurazione e Sincronizzazione Risorse Custom nella Lobby (`ShipBlueprint` e `StarSystemData`)

## 1. Obiettivo e Panoramica
Implementare all'interno dell'applicazione **Lobby & Matchmaking** (`Applications/Lobby`) e del sottosistema di networking (`NetworkManager` / `SpaceWorldManager`) la facoltà per l'Host (e in Solo Mode) di selezionare e caricare:
1. Una specifica risorsa di definizione della nave (**`ShipBlueprint`**).
2. Una specifica risorsa di definizione del sistema stellare (**`StarSystemData`**).

I dati delle risorse selezionate devono essere sincronizzati con tutti i client connessi prima dell'avvio della partita (`start_mission()`), in modo che l'istanza di gioco carichi la corvetta custom e l'ambiente spaziale configurato.

---

## 2. Riferimenti al Documento di Design (DARK_NOVA_FEATURES_DESIGN.md)
- **Sezione 2 (Diagramma Flusso Utente - Fase 2)**: *Fase Lobby, Matchmaking & Configurazione Risorse Custom*.
- **Sezione 2.2 (Fase 2 - Accesso alla Lobby e Configurazione Nave/Sistema)**:
  > L'Host ha la facoltà di caricare una specifica **risorsa nave** (`ShipBlueprint`) e una **risorsa sistema stellare** (`StarSystemData`) per avviare una nave custom all'interno di un setting/sistema stellare custom.

---

## 3. Specifiche Tecniche e Funzionali

### 3.1 Interfaccia UI Lobby (`lobby_app.tscn` / `lobby_app.gd`)
1. **Selettore Risorsa Nave (`ShipBlueprint`)**:
   - Menu dropdown (`OptionButton`) o pulsante di selezione file (`FileDialog` filtrato su `*.tres`) visibile/abilitato per l'Host e in Solo Mode.
   - Lista predefinita delle blueprint disponibili nel progetto (es. `CorvetteDefault.tres`, blueprint custom).
   - Visualizzazione anteprima/metadati: Nome della nave, classe, numero di stanze/condotti, programmi installati.
2. **Selettore Risorsa Sistema Stellare (`StarSystemData`)**:
   - Menu dropdown (`OptionButton`) o file picker per selezionare il sistema stellare (es. `StarSystemDefault.tres`, sistemi custom).
   - Visualizzazione anteprima: Nome del sistema, coordinate stella primaria, numero di settori/stazioni.
3. **Visibilità e Permessi**:
   - I client connessi visualizzano in sola lettura il nome della nave e del sistema stellare selezionati dall'Host (sincronizzati via RPC/NetworkManager).

### 3.2 Sincronizzazione Networking (`NetworkManager` / `SpaceWorldManager`)
1. **Sincronizzazione Parametri di Sessione**:
   - Quando l'Host cambia blueprint o sistema stellare, invia un messaggio RPC (o segnale di rete) a tutti i peer con i percorsi/dati delle risorse.
2. **Inizializzazione Partita**:
   - All'invocazione di `start_mission()`, `SpaceWorldManager` istanzia il mondo di gioco utilizzando il `StarSystemData` sincronizzato e carica sulla nave il `ShipBlueprint` selezionato.
   - I client ricevono e applicano le stesse risorse per la simulazione e il rendering locale.

---

## 4. Standard Architetturali e Flusso Git
1. **Branch Git**:
   - `git checkout -b feature/LobbyCustomResources main`
2. **File Coinvolti**:
   - `Applications/Lobby/lobby_app.tscn`
   - `Applications/Lobby/lobby_app.gd`
   - `Scenes/Networking/network_manager.gd` (se presente o autoload equivalente)
   - `Outside/SpaceWorld/space_world_manager.gd` / `Outside/StarSystemGrid/`
   - `tests/test_lobby_custom_resources.gd`

---

## 5. Criteri di Accettazione e Test Headless
1. **Suite di Test (`tests/test_lobby_custom_resources.gd`)**:
   - Verifica che l'Host possa impostare e modificare `ShipBlueprint` e `StarSystemData`.
   - Verifica che i client non possano modificare le risorse ma ricevano gli aggiornamenti sincronizzati.
   - Verifica che all'avvio della missione `SpaceWorldManager` riceva correttamente le risorse impostate.
2. **Chiusura Git**:
   - [ ] Test headless superati con successo.
   - [ ] Commit con messaggio convenzionale: `feat(lobby): implement custom ship and star system resource selection and sync`.
   - [ ] Merge su `main`.
