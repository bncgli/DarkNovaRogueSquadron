# Scenario Operativo di Sessione e Piano di Sviluppo Funzionalità Mancanti
# Dark Nova: Rogue Squadron / GodotOS

> **Scopo del Documento**: 
> Questo documento formalizza l'esperienza di gioco (User Journey & Game Session Loop) per una tipica partita cooperativa/solo in *Dark Nova: Rogue Squadron*, ne analizza l'architettura sistemica in termini di resa operativa e cooperativa, mappa le funzionalità già presenti nel codebase rispetto a quelle assenti e definisce il piano di sviluppo (Roadmap & Action Items) per implementare tutto ciò che manca.

---

## 1. Narrazione Dettagliata della Sessione di Gioco (Game Session Loop)

### Fase 1: Boot, Personalizzazione e Configurazione Periferiche
1. **Accesso all'OS**: Ciascun giocatore avvia il gioco. Viene caricato l'ambiente desktop diegetico **GodotOS** (con barra delle applicazioni, orologio di sistema, tray delle notifiche e icone dei file locali).
2. **Impostazioni e Controlli**: I giocatori possono aprire la finestra **Settings**:
   - Personalizzazione grafica e interfaccia (risoluzione, scaling UI, sfondo desktop, colori).
   - **Mappatura comandi e controller/joystick**: assegnazione degli assi analogici, calibrazione delle deadzone, supporto a cloche/HOTAS e binding di tastiera/mouse sia per il pilotaggio che per il puntamento manuale delle torrette.

### Fase 2: Lobby, Generazione Procedurale e Selezione Nave/Sistema
1. **Lobby & Matchmaking**: Ciascun giocatore apre l'applicazione **Lobby**, che offre tre scelte operative:
   - **Gioca in Solo**: sessione offline in cui il giocatore assume tutti i ruoli simultaneamente con privilegi di Capitano.
   - **Host Partita**: creazione della sessione server-authoritative di plancia.
   - **Join Partita**: connessione come membro dell'equipaggio alla nave dell'Host via IP/LAN.
2. **Scelta Risorse Nave e Sistema**:
   - In modalità Solo o Host, il giocatore sceglie la **Nave** (`ShipBlueprint`) e il **Sistema Stellare** (`StarSystemData`).
   - Entrambe le risorse possono essere create o generate proceduralmente in precedenza tramite le applicazioni dedicate:
     - **Ship Builder**: progettazione del telaio, compartimentazione stanze, posizionamento componenti energetici e installazione software iniziale.
     - **System Discover**: applicazione/modulo per la generazione procedurale di sistemi stellari completi (pianeti, fasce di asteroidi, stazioni orbitali, quadranti di relitti e zone di pericolo).
3. **Assegnazione Ruoli & Pod Connection**:
   - I membri dell'equipaggio selezionano il proprio ruolo (*Capitano*, *Pilota*, *Soldato/Cannoniere*, *Ingegnere*, *Hacker*, *Stagista*).
   - All'avvio della missione dall'Host, i giocatori "entrano" nei loro rispettivi pod: l'interfaccia si sincronizza con la nave, montando su GodotOS lo **Ship Drive** e sbloccando le applicazioni installate sulla corvetta secondo la matrice dei permessi RBAC.

### Fase 3: Stazione Spaziale di Partenza & Condizione Economica "Freemium Debt"
1. **Posizione Iniziale**: La nave inizia la sessione **attraccata a una Stazione Spaziale** (senza rischio immediato di deriva o scontro nel vuoto).
2. **Stato del Wallet**:
   - Saldo disponibile nel **Flux Wallet**: `300 FLUX`.
   - Modificatore passivo di debito bloccato: `-700 FLUX` contrassegnato come `"Ship Rent Service"`.
   - La pressione economica che racconta ai giocatori il fatto che non possiedono niente, tutto è in prestito e tutto è un prestito.
3. **Operazioni su StationHub**: Tramite l'applicazione **StationHub**, l'equipaggio accede ai servizi portuali:
   - **App Store / Software Repository**: acquisto, installazione e disinstallazione dei programmi e driver di bordo direttamente sulla blueprint della nave attiva.
   - **Il Bar / Taverna**: raccolta di voci e *rumors* da commercianti e fuorilegge locali (rivelazione di coordinate occulte di relitti, navi fantasma o convogli vulnerabili).
   - **Il Fixer**: bacheca contratti per accettare o consegnare missioni (Bounty, Trasporto merci, Esplorazione cartografica, Scorta, Recupero/Retrieval).
   - **Mercante & Borsa Merci**: compravendita di beni di consumo e materie prime con rating dinamico di acquisto/vendita (economia stile X4 basata su domanda e offerta dei diversi quadranti).
   - **Cantiere & Manutenzione**: rifornimento proiettili, materiali di riparazione, riparazione brecce nello scafo e cambio fluidi del reattore.
   - **Salpare**: si chiude lo stationhub e la nave non è più attraccata alla stazione spaziale.

### Fase 4: Preparazione Rotta e Spedizione al Relitto
1. **Acquisto Merci & Contratti**:
   - L'equipaggio acquista stock di risorse a basso prezzo dal mercante, pianificando di rivenderle con margine di profitto presso una seconda stazione del sistema.
   - Il Capitano accetta una missione di **Bounty** dal Fixer per eliminare un bersaglio ostile noto.
   - Al Bar, un rumor segnala la presenza di un **relitto inesplorato** nel quadrante orbitale di un pianeta specifico (`Pianeta XYZ`). Le coordinate vengono annotate e trasmesse alla `System Map` (notando che i POI del quadrante non si trovano su un piano piatto ad altezza zero, ma possiedono quote ed elevazioni verticali tridimensionali variabili).
2. **Disattracco & Decollo**:
   - Connessione a Flight Control, disimpegno dagli attracchi magnetici della stazione e allineamento vettoriale verso il quadrante del pianeta.
3. **Transito: Salto Hyperdrive o Navigazione Continua a Velocità di Crociera**:
   - L'equipaggio dispone di due opzioni di navigazione per raggiungere la destinazione:
     - **Salto Hyperdrive (Viaggio Rapido)**: calcolo del vettore di salto su `System Map`, aggancio della rotta su `Flight Control` e attivazione dell'iperguida per transitare istantaneamente nel quadrante designato a consumo di celle energetiche.
     - **Velocità di Crociera Continua (Cruise Speed & Caricamento Dinamico dei Quadranti)**: se il pilota imposta la velocità di crociera sub-luce per risparmiare energia, pattugliare lo spazio intermedio o esplorare senza interruzioni, la nave naviga attraversando direttamente i quadranti. Il motore gestisce lo streaming in modo trasparente e continuo: quando la nave si avvicina al bordo del quadrante attivo, il sistema rileva la traiettoria vettoriale e inizia a caricare dinamicamente in background il quadrante adiacente. Al varcare della soglia, la transizione avviene senza schermate di caricamento né stacchi netti (universo *seamless*).

### Fase 5: Scavenging sul Relitto & Minaccia Sciacalli
1. **Esplorazione del Quadrante Relitto**:
   - All'uscita dal salto, l'area è costellata di detriti metallici, rottami e frammenti fluttuanti.
   - **Disposizione Volumetrica 3D**: i punti di interesse (il relitto principale, i cluster di rottami, le boe e i container dispersi) non sono allineati a un piano bidimensionale convenzionale ad altezza $Y = 0$, ma presentano quote ed elevazioni variabili lungo tutto l'asse verticale $Y$, richiedendo all'equipaggio di orientarsi e manovrare nello spazio tridimensionale reale.
   - Il Soldato/Tattico impiega i **Sensori** (con visualizzazione volumetrica/sferica che tiene conto della quota polare ed elevazione) e i filtri ottici **LIDAR / Termico** delle telecamere esterne per filtrare i falsi positivi a diverse altezze e triangolare la massa del relitto principale.
2. **Impiego del Service Drone (Scavenging)**:
   - Una volta stabilizzata la corvetta a distanza di sicurezza, viene lanciato il **Drone di Servizio** nello spazio esterno.
   - Il pilota del drone naviga verso il relitto, aggancia i container pressurizzati o i rottami di valore con il braccio manipolatore e li trasporta nella stiva cargo della nave.
3. **Sorveglianza Anti-Sciacallo**:
   - Mentre il drone è impegnato nel recupero, gli altri membri dell'equipaggio tengono i radar sotto sweep continuo e monitorano lo spazio profondo: la presenza di sciacalli (*scavenger* pirata attratti dal relitto o dalla nave ferma) costituisce una minaccia costante di imboscata.

### Fase 6: Caccia alla Bounty, Guerra Elettronica e Balistica Newtoniana
1. **Salto nel Quadrante Bersaglio**:
   - Caricato il loot, la nave effettua un secondo salto iperspaziale verso le coordinate del bersaglio della taglia.
2. **Avvicinamento Furtivo & Lancio Sonde**:
   - L'equipaggio evita di avvicinarsi a motori spiegati. Le navi nemiche possono nascondersi nei coni d'ombra radar proiettati dai corpi celesti o satelliti.
   - Il Tattico lancia sonde telemetriche (**Probe**) verso le zone cieche per illuminare lo scenario e rivelare la formazione nemica senza tradire la posizione della corvetta.
3. **Sabotaggio Informatico (Cyberwarfare)**:
   - L'Hacker orienta l'antenna direzionale dell'applicazione **Comms**, aggancia la frequenza radio nemica e stabilisce il link al drive avversario.
   - Tramite **Hack Exploits**, inietta virus (es. popup spam, loop giroscopici, disattivazione camme) o altera illegalmente i parametri dei file `.dat` nemici (es. riducendo l'efficienza dei motori o la dissipazione termica).
4. **Combattimento a Fuoco con Fisica Balistica Newtoniana**:
   - La nave nemica risponde al fuoco e inizia lo scontro armato.
   - **Vettorialità Reale dei Proiettili Hard Sci-Fi**:
     - Ai proiettili fisici (mitragliatrici pesanti Gatling, cannoni cinetici) viene sommato il vettore velocità istantaneo della corvetta:
       $$\vec{v}_{proiettile\_globale} = \vec{v}_{nave} + \vec{v}_{sparo\_relativo}$$
     - Se la nave fa fuoco procedendo verso il bersaglio, la velocità relativa di impatto aumenta, massimizzando il danno cinetico trasferito.
     - Se spara in ritirata (direzione opposta al moto), il proiettile perde velocità effettiva nello spazio assoluto, riducendo l'energia all'impatto.
     - All'impatto, la cinematica del bersaglio conta allo stesso modo: una nave nemica che accelera contro il proiettile subisce un danno moltiplicato dall'energia d'impatto relativa; una nave in fuga concorde attutisce il danno.

### Fase 7: Gestione Interna Danni, Minacce Cyber e Sopravvivenza
1. **Danni Strutturali & Segnalazioni**:
   - I proiettili nemici che superano la matrice di scudi colpiscono lo scafo. I guasti compaiono in tempo reale sui registri di **Diagnostics**.
   - I giocatori percepiscono i danni esclusivamente tramite **feedback diegetici**: boati d'impatto, sibili di decompressione per brecce aperte nello scafo, scariche da cortocircuiti e fiamme nei compartimenti.
2. **Intervento dell'Ingegnere (Duct Drone)**:
   - L'Ingegnere decolla con il **Duct Drone** all'interno della rete dei condotti tecnici della nave.
   - Naviga verso i punti di avaria per estinguere incendi, riparare giunzioni elettriche e sigillare falle per arrestare la fuga di atmosfera.
3. **Fluttuazione Parametri Vitali nei Pod**:
   - I guasti impattano il **Life Support** (caduta di pressione, gelo nel vuoto, fumo tossico o picchi di G durante manovre brusche).
   - I parametri vitali dei membri dell'equipaggio in **PodInfo** oscillano; se le avarie non vengono risolte tempestivamente, i giocatori subiscono blackout, asfissia o la morte nel pod.
4. **Contrattacco Cyber Nemico**:
   - I pirati tentano a loro volta attacchi hacker alla corvetta dei giocatori.
   - L'Hacker deve monitorare costantemente il file system dello Ship Drive: individuare file exploit malevoli iniettati dal nemico e cancellarli rapidamente prima che causino danni irreversibili ai sistemi o letali sovraccarichi energetici.

### Fase 8: Scavenging Post-Combat, Rientro e Chiusura del Ciclo
1. **Recupero Relitti Nemici**:
   - Distrutta la nave nemica, l'equipaggio impiega nuovamente il Drone di Servizio per recuperare moduli, armi e materiali dai resti fumanti del bersaglio.
2. **Attracco Automatico a StationHub**:
   - La nave fa rotta verso la stazione spaziale più vicina.
   - In prossimità della stazione, il pilota invia la richiesta di attracco tramite **Comms / StationHub** e la procedura automatica aggancia la corvetta al pontile.
3. **Chiusura delle Transazioni Economiche**:
   - Vendita dello stock di merci acquistato nella prima stazione (incasso della plusvalenza).
   - Vendita dei materiali recuperati con lo scavenging dal relitto orbitale e dai detriti della battaglia.
   - Incasso della ricompensa per la taglia completata presso il Fixer.
   - Pagamento della quota di noleggio e riparazione completa dello scafo al cantiere navale.
4. **Riavvio del Ciclo**:
   - Con i fondi accumulati e il debito saldato, l'equipaggio è pronto per una nuova pianificazione, acquisto di nuovi moduli software e rotta verso nuove missioni.

---

## 2. Valutazione Funzionale del Loop (Analisi del Valore di Gioco)

L'architettura di questo gameplay loop presenta un profilo di efficacia eccezionale per i seguenti fattori sistemici:

1. **Massimizzazione dell'Utilità dei Ruoli (Nessun Tempo Morto, Massima Agency)**:
   - In molti giochi cooperativi spaziali alcuni ruoli soffrono di passività nei momenti non di combattimento. In questo scenario, ogni fase assegna a ciascun giocatore un compito critico:
     - Nella fase di viaggio/esplorazione: Pilota naviga, Tattico usa i sensori per mappare i rottami, Hacker intercetta frequenze e rumors, Ingegnere controlla consumi e batterie.
     - Nella fase relitto: l'operatore del Service Drone recupera il carico mentre gli altri scansionano in allerta anti-sciacalli.
     - In combattimento: Tattico/Soldato gestisce la torretta balistica, Ingegnere pilota il Duct Drone per riparare falle e incendi, Hacker duella in tempo reale contro gli exploit nemici, Pilota manovra per massimizzare la velocità relativa dei proiettili.
   - Il rendimento complessivo dell'esperienza per ora di gioco risulta massimizzato per tutti i partecipanti.

2. **Tensione Economica come Motore di Scelte Pragmatiche**:
   - La condizione iniziale con debito passivo di noleggio (`-700 FLUX`) e liquidità limitata (`300 FLUX`) elimina la noia della partenza comoda: costringe il gruppo a prendere decisioni razionali, soppesare rischi e ricompense, ottimizzare la stiva e non sprecare carburante o munizioni.

3. **Integrazione Meccanica Diegetica (Zero Astrazione)**:
   - Il fatto che i danni si sentano solo con suoni interni, sbalzi atmosferici e telemetrie, unito alla necessità fisica di eliminare file `.dat` e pilotare droni nei condotti, crea una sinergia totale tra interfaccia diegetica (GodotOS) e simulazione 3D esterna.

4. **Balistica Vettoriale come Moltiplicatore di Tattica**:
   - La somma della velocità della nave a quella dei proiettili trasforma il posizionamento e il moto da semplice manovra evasiva a componente primaria della letalità dell'arma. Il Pilota e il Cannoniere devono sincronizzare manovra e tiro in modo organico.

5. **Doppia Modalità di Navigazione (Hyperdrive Tattico vs Crociera Continua Seamless)**:
   - Offrire sia il salto iperspaziale rapido sia la velocità di crociera continua con streaming dinamico dei quadranti adiacenti azzera i confini artificiali del mondo: i giocatori possono decidere liberamente se bruciare celle di salto o pattugliare lo spazio inter-quadrante senza subire schermate di caricamento o freeze della simulazione.

6. **Spazio Volumetrico Reale e Dislivelli Verticali (POI ad Altezze Variabili)**:
   - Eliminare l'appiattimento dei punti d'interesse su un piano fittizio a quota zero ($Y = 0$) trasforma l'esplorazione e il combattimento in un'esperienza tridimensionale autentica. Le entità (stazioni, relitti, campi detriti, bersagli di taglie) possono trovarsi a quote positive o negative considerevoli rispetto all'eclittica, costringendo il pilota a sfruttare a pieno beccheggio e traslazioni verticali, e spingendo il tattico a leggere radar sferici a $360^\circ$ per individuare minacce che provengono da sopra o da sotto.

---

## 3. Matrice di Allineamento del Codebase (Cosa c'è vs Cosa manca)

| Area Funzionale | Componenti Esistenti nel Repository | Cosa Manca / Da Implementare | Stato Attuale |
| :--- | :--- | :--- | :---: |
| **OS & Settings** | Tab `Controlli & Periferiche` in `Settings Window` (`InputSettingsTab`), calibrazione assi, deadzone/sensibilità joypad, visualizzazione assi live, remapping azioni e persistenza su `user://input_config.json`. | Validato con suite automatizzata GUT (`tests/gut/test_phase_a_controls_economy_docking.gd`). | **Completato** |
| **Lobby & Inizializzazione** | Conio iniziale di 300 FLUX e modificatore passivo vincolato di -700 FLUX ("Ship Rent Service") in `ShipBlueprint` e `FluxWallet`; estinzione quote noleggio in `StationHub`; spawn iniziale attraccato alla Baia 0 della stazione primaria con blocco propulsori e sblocco su `request_undock()` in `SpaceWorldManager`. | Validato con suite automatizzata GUT (`tests/gut/test_phase_a_controls_economy_docking.gd`). | **Completato** |
| **Procedural Generation** | Generatore astronomico modulare deterministico da seed `StarSystemGenerator`, applicazione diegetica `SystemDiscoverApp` con canvas orbitale e altimetrico, 4 archetipi galattici, distribuzione volumetrica 3D ($Y \neq 0$) e selezione istantanea da Lobby. | Validato con suite automatizzata GUT (`tests/gut/test_phase_b_system_discover.gd`). | **Completato** |
| **Station Services (StationHub)** | Struttura a 5 Tab (Market, Contratti, Software, Cantiere, Taverna), coordinatore contratti autonomo `MissionManagerSingleton` con claim collettivo, archetipi economici stazione stile X4 (spread bid/ask) e dicerie della taverna con waypoint 3D volumetrici. | Validato con suite automatizzata GUT (`tests/gut/test_phase_c_station_hub_services.gd`). | **Completato** |
| **Navigazione & Streaming Quadranti** | `StarSystemGridManager` (coordinate `Vector3i`, calcolo distanze, cache `SectorData`), `SpaceWorldManager.load_sector_zone()`, trigger di prossimità ai bordi a velocità di crociera, pre-caricamento asincrono `preload_adjacent_sector_async()`, crossing seamless con floating origin shift. | Validato con suite automatizzata GUT (`tests/gut/test_phase_d_debris_scavenging_streaming.gd`). | **Completato** |
| **Sensori, LIDAR & Sonde** | Raggio 1km, radar volumetrico sferico 3D con indicazione quota altimetrica relativa, ping energetico in `SensorsApp`, filtri Cams (Normal/Thermal/Lidar), spettrometria e coordinate 3D dei container cargo. | Integrazione completa dei container fluttuanti nel catalogo sensori. | **Completato** |
| **Service Drone (Esterno)** | Scena 3D del drone, collisioni fisiche, controlli di volo e rotazione, harpoon magnetico fisico per traino container cargo (`latch_cargo`, `unlatch_cargo`), consumo energetico modulato dalla massa rimorchiata e portello cargo nave. | Validato con suite automatizzata GUT (`tests/gut/test_phase_d_debris_scavenging_streaming.gd`). | **Completato** |
| **Balistica Newtoniana Torretta** | Profili balistici munizioni in `SpaceWorldManager`, somma vettoriale galileiana $\vec{v}_{proj} = \vec{v}_{ship} + (\hat{d}_{aim} \times v_{muzzle})$, collision sweep continuo anti-tunneling, danno cinetico scalato in base a $\vec{v}_{rel}$, Lead Indicator relativo in `WeaponsApp` e telemetria d'impatto su `WeaponsTrajectoryHUD`. | Testata e validata con suite GUT (`tests/gut/test_ballistics_newtonian.gd`). | **Completato** |
| **Combattimento Cyber (Hackwarfare)** | Routine di guerra elettronica in `CombatDirector`, iniezione remota sentinelle malware `.dat` nello Ship Drive, anomalie diegetiche (deriva RCS, glitch visivo cams, sovraccarico reattore), neutralizzazione con disinfezione file e detonazione da timeout su `SystemicDamageHandler`. | Validato con suite automatizzata GUT (`tests/gut/test_phase_f_cyber_warfare_sensory_damage.gd`). | **Completato** |
| **Danni & Riparazioni Interne** | `DiagnosticsApp`, `LifeSupportApp`, `DuctDrone`, feedback acustici diegetici ovattati/interni (boati impatto, breccia depressurizzazione, incendio condotti), scuotimento schermo desktop con falloff quadratico e reazioni vitali biometriche nei pod (`PodInfoApp`). | Validato con suite automatizzata GUT (`tests/gut/test_phase_f_cyber_warfare_sensory_damage.gd`). | **Completato** |
| **Economia & Loop Ricorsivo** | Distinzione esplicita merci ordinarie vs bottino scavenging (`is_scavenged`), liquidazione rapida in un clic nel Tab Market, riscossione collettiva contratti nel Tab Fixer, versamento discrezionale canone noleggio nel Tab Cantiere e persistenza `ShipBlueprint` su disco utente (`user://blueprints/active_corvette_session.tres`). | Validato con suite automatizzata GUT (`tests/gut/test_phase_g_debriefing_persistence_loop.gd`). | **Completato** |

---

## 4. Piano di Sviluppo Dettagliato (Roadmap & Action Plan)

### Fase A: Fondamenta Controlli, Economia e Partenza Stazione [COMPLETATA]

#### Task A1: Tab Controlli e Joystick in `Settings Window` [COMPLETATO]
- **Obiettivo**: Permettere a ogni giocatore di calibrare e rimappare comandi tastiera, mouse e controller/joystick prima di entrare in partita.
- **Implementazione Eseguita**:
  - Creato `Scenes/Window/Settings Window/input_settings_tab.gd` integrato in `settings_window.tscn` sotto la scheda `Controlli & Periferiche`.
  - Rilevamento joypad con `Input.get_connected_joypads()` e monitoraggio assi in tempo reale.
  - Rimappatura interattiva azioni di volo e armeria, calibrazione deadzone ($0.05 - 0.35$) e sensibilità ($0.5x - 3.0x$) con persistenza su `user://input_config.json`.

#### Task A2: Spawn Iniziale Attraccato & Condizione Economica Debito [COMPLETATO]
- **Obiettivo**: Far iniziare ogni sessione con la nave attraccata alla stazione e bilancio iniziale configurato a `300 FLUX` disponibili e `-700 FLUX` di debito noleggio.
- **Implementazione Eseguita**:
  - In `ShipBlueprint` conio impostato a `flux = 300` e modificatore passivo vincolato da `-700 FLUX` ("Ship Rent Service", "Canone noleggio scafo"), visualizzato in `FluxWallet` con badge `[BLOCKED]` e saldo netto contabile.
  - Interfaccia di ripianamento rate o saldo noleggio integrata nel Tab Cantiere di `StationHub`.
  - In `SpaceWorldManager`, spawn iniziale ancorato alla Baia 0 di `primary_station_instance` con stato `is_docked = true` e blocco propulsori fino alla richiesta di `request_undock()`.
  - Suite automatizzata di test GUT in `tests/gut/test_phase_a_controls_economy_docking.gd` (4/4 superati).

---

### Fase B: Generazione Procedurale Sistemi & Applicazione "System Discover" [COMPLETATA]

#### Task B1: Modulo e Applicazione `System Discover` [COMPLETATO]
- **Obiettivo**: Offrire uno strumento procedurale diegetico per generare rapidamente sistemi stellari randomici (`StarSystemData`) pronti per essere giocati o caricati nella Lobby.
- **Implementazione Eseguita**:
  - Creato `Outside/StarSystemGrid/star_system_generator.gd` con 4 archetipi galattici bilanciati (`STANDARD_BALANCED`, `MINING_FRONTIER`, `CORE_HIGH_TECH`, `MILITARY_ANOMALY`), distribuzione orbitale deterministica da seed e garanzia della stazione di partenza.
  - Creata `Applications/SystemDiscover/system_discover_app.gd` e `.tscn` con controlli seed/archetipi, canvas olografico orbitale interattivo con indicatori altimetrici $\Delta z$, esportazione su disco (`user://systems/` e `res://CustomSystems/`) e auto-integrazione in `LobbyApp`.
  - Simulazione volumetrica reale 3D: tutte le entità generate possiedono quote variabili ($Y \in [-1200, +1200]\,\text{m}$), sincronizzate sui sensori e navigazione.
  - Validato con suite automatizzata GUT (`tests/gut/test_phase_b_system_discover.gd`: 6/6 superati).

---

### Fase C: Servizi Portuali Avanzati su StationHub [COMPLETATA]

#### Task C1: Bacheca Contratti & Fixer Dinamico [COMPLETATO]
- **Obiettivo**: Trasformare il Tab Contratti di `StationHub` in una vera bacheca contratti collegata a eventi e POI della simulazione.
- **Implementazione Eseguita**:
  - Creato `Economy/mission_manager.gd` (`MissionManagerSingleton`) coordinando il ciclo vitale dei contratti procedurali (Bounty, Transport, Retrieval, Patrol) e l'accredito dei premi in Crediti e FLUX.
  - Collegati i segnali di distruzione navi pirata in `CombatDirector` e di attracco in `DockingManager` alla risoluzione automatica delle missioni.
  - Implementata la riscossione con un clic sia per singolo contratto sia collettiva ("Riscuoti Tutti i Contratti") con sincronizzazione in `LogbookApp`.

#### Task C2: Il Bar della Stazione e Generazione Rumors [COMPLETATO]
- **Obiettivo**: Rendere il Tab Taverna un aggregatore di informazioni esplorative con impatto reale sullo spazio 3D.
- **Implementazione Eseguita**:
  - Le dicerie raccolte al bancone della stazione generano punti di interesse temporanei o permanenti (relitti, giacimenti, nascondigli) comprensivi di offset altimetrico volumetrico $Y \neq 0$.
  - Il pulsante diegetico "Trascrivi Coordinate nei Sensori & Mappa" inietta il Waypoint su `SpaceWorldManager`, rendendolo visibile su Mappa Stellare, Sensori e Navigazione.

#### Task C3: Borsa Merci Dinamica Stile X4 [COMPLETATO]
- **Obiettivo**: Offrire differenziali di prezzo di acquisto/vendita tra stazioni e settori.
- **Implementazione Eseguita**:
  - Definiti in `Outside/Stations/space_station_entity.gd` 4 archetipi economici (`MINING_OUTPOST`, `INDUSTRIAL_REFINERY`, `HIGH_TECH_HUB`, `AGRICULTURAL_DEPOT`) con modificatori di categoria e margini di spread bid/ask per garantire opportunità di commercio inter-settoriale senza loop speculativi locali.
  - Validato con suite automatizzata GUT (`tests/gut/test_phase_c_station_hub_services.gd`: 5/5 superati).

---

### Fase D: Esplorazione, Relitti e Scavenging con Service Drone [COMPLETATA]

#### Task D1: Generazione Debris Field & Relitto Orbitale [COMPLETATO]
- **Obiettivo**: Popolare i quadranti designati con campi di detriti fluttuanti, rottami e relitti scansionabili distribuiti a quote ed elevazioni 3D variabili sull'asse Y.
- **Implementazione Eseguita**:
  - Creata l'entità fisica 3D `CargoContainerEntity` (`Outside/Mining/cargo_container_entity.gd`) con massa, volume, collision box, firma per LIDAR e spettrometria per `SensorsApp`.
  - In `SpaceWorldManager`, implementati `spawn_debris_field()` e popolamento automatico di relitti primari e 4+ container a quote tridimensionali variabili ($Y \in [-1200, +1200]\,\text{m}$) nei settori relitto.
  - In `CombatDirector`, implementata la routine di allerta e imboscata periodica degli sciacalli pirata (`process_scavenger_threat()` e `trigger_scavenger_ambush()`).

#### Task D2: Meccanica di Scavenging per il Service Drone [COMPLETATO]
- **Obiettivo**: Permettere al Drone di Servizio di prelevare materiali e container dal relitto e stivarli nella nave madre.
- **Implementazione Eseguita**:
  - In `ServiceDroneEntity`, implementato lo strumento `"magnet"` con raggio di $18.0\,\text{m}$, vincolo harpoon (`latch_cargo`, `unlatch_cargo`), rimorchio fluido con smorzamento lerp, inerzia maggiorata e incremento consumo batteria proporzionale alla massa rimorchiata.
  - Sulla corvetta (`Spaceship.gd`), creato il portello cargo (`CargoHatchArea3D`) che rileva i container consegnati, li stiva direttamente in `CargoManager`, rilascia l'harpoon del drone e distrugge l'entità 3D nello spazio con notifica diegetica.

#### Task D3: Caricamento Dinamico e Streaming Asincrono dei Quadranti a Velocità di Crociera [COMPLETATO]
- **Obiettivo**: Consentire alla nave di transitare continuativamente attraverso i confini dei quadranti navigando a velocità di crociera sub-luce, caricando dinamicamente e in background il quadrante adiacente per un'esperienza seamless priva di schermate di caricamento.
- **Implementazione Eseguita**:
  - In `StarSystemGridManager`, implementato `check_sector_boundary_proximity()` con rilevamento della distanza dai 6 piani del settore e soglia di allerta ($15.000\,\text{km}$).
  - Implementato il pre-caricamento asincrono `preload_adjacent_sector_async()` del settore adiacente prima del valico.
  - Al varcare del confine, esecuzione del crossing seamless con floating origin shift che riallinea le coordinate al margine opposto preservando orientamento, velocità lineare e angolare.
  - Suite automatizzata di test GUT in `tests/gut/test_phase_d_debris_scavenging_streaming.gd` (6/6 superati).

---

### Fase E: Fisica Balistica Newtoniana & Combattimento Hard Sci-Fi [COMPLETATA]

#### Task E1: Somma Vettoriale della Nave ai Proiettili Torretta [COMPLETATO]
- **Obiettivo**: Rispettare rigorosamente la relatività galileiana applicando la cinematica newtoniana a proiettili di mitragliatrici pesanti e cannoni.
- **Implementazione Eseguita**:
  - In `SpaceWorldManager.request_fire_weapon()` e `spawn_ballistic_projectile()`:
    - Tabella profili balistici munizioni `BALLISTIC_PROFILES` (`HEAVY_MG`, `HEAVY_CANNON`, `MISSILE`, `PROBE`, `TORPEDO`, `KINETIC`).
    - Estrazione della velocità istantanea corvetta `get_spaceship_velocity()` e somma vettoriale:
      $$\vec{v}_{proj} = \vec{v}_{ship} + (\hat{d}_{aim} \times v_{muzzle})$$
    - Buffer di simulazione `active_ballistic_projectiles` con aggiornamento frame per frame e sweep continuo di collisione anti-tunneling (`check_segment_sphere_collision`).
    - Allineamento del fuoco nemico in `CombatDirector` con vettori galileiani e calcolo d'impatto.

#### Task E2: Calcolo del Danno Cinetico Relativo all'Impatto & Telemetria HUD [COMPLETATO]
- **Obiettivo**: Scalare il danno inflitto in base all'energia cinetica relativa all'impatto e aggiornare il mirino predittivo.
- **Implementazione Eseguita**:
  - Risoluzione collisioni in `SpaceWorldManager`: calcolo di $\vec{v}_{rel} = \vec{v}_{proj} - \vec{v}_{target}$ e moltiplicatore:
    $$\text{danno\_effettivo} = \text{danno\_base} \times \text{clampf}\left(\frac{|\vec{v}_{rel}|}{v_{muzzle}}, 0.25, 2.5\right)$$
  - Ricalcolo predittivo in `WeaponsApp` sul vettore di chiusura relativo $(\vec{v}_{target} - \vec{v}_{ship})$: Lead Indicator privo di derive spurie.
  - Telemetria diegetica in `WeaponsTrajectoryHUD` con indicazione dinamica di $\Delta v$ e `IMP. PWR: %`.
  - Suite automatizzata di test GUT in `tests/gut/test_ballistics_newtonian.gd` (5/5 passati con successo).

---

### Fase F: Guerra Elettronica, Contrattacco Hacker & Feedback Diegetici [COMPLETATA]

#### Task F1: Contrattacco Hacker Nemico e File Exploit Malevoli [COMPLETATO]
- **Obiettivo**: Creare la minaccia attiva di sabotaggio nemico a cui l'Hacker di bordo deve rispondere diegeticamente.
- **Implementazione Eseguita**:
  - In `CombatDirector`, implementata la routine di guerra elettronica ostile con timer probabilistico durante il combattimento.
  - Iniezione da parte dei caccia nemici di file sentinella `.dat` malevoli (`PROPULSION_WORM`, `BLIND_EYE`, `REACTOR_OVERLOAD`) nelle directory protette dello Ship Drive via `ShipDriveManager.inject_intrusion_file()`.
  - Generazione di anomalie sistemiche in tempo reale (deriva erratica attuatori RCS su `Spaceship.gd`, static glitch e offuscamento mirino telecamere su `CameraFeedWindow`, sovraccarico del regolatore di potenza in `PowerGridApp`).
  - Monitoraggio e notifica in `DiagnosticsApp` con conto alla rovescia di allarme; rimozione/disinfezione immediata tramite cancellazione del file da parte dell'Hacker (`sdm.item_deleted`), oppure detonazione critica con danni a scafo e moduli su `SystemicDamageHandler` allo scadere del timeout.

#### Task F2: Feedback Sensoriali Interni & Fluttuazioni Vitali [COMPLETATO]
- **Obiettivo**: Riconnettere i danni esterni a effetti sensoriali claustrofobici all'interno dei pod.
- **Implementazione Eseguita**:
  - Sintetizzati in `PodInfoApp` generatori audio procedurali diegetici a bassa frequenza per boati di scafo ovattati, decompressioni per brecce e sfrigolii di incendi da cortocircuito.
  - Applicato camera shake desktop smorzato con decadimento quadratico calibrato sul danno subito.
  - Sincronizzate le fluttuazioni biometriche e la frequenza cardiaca (da 72 a 160 BPM) con allarmi di stress e rantoli se la nave subisce brecce non riparate.
  - Validato con suite automatizzata GUT (`tests/gut/test_phase_f_cyber_warfare_sensory_damage.gd`: 8/8 superati).

---

### Fase G: Chiusura del Ciclo, Debriefing e Rientro Persistente [COMPLETATA]

#### Task G1: Flusso Completo di Fine Missione, Debriefing e Salvataggio [COMPLETATO]
- **Obiettivo**: Riconciliare in modo modulare i profitti di fine missione nei rispettivi uffici di StationHub e salvare stabilmente lo stato della corvetta.
- **Implementazione Eseguita**:
  - In `CargoManagerSingleton`, aggiunta identificazione e tracciamento esplicito del bottino di scavenging (`is_scavenged = true` o categorie `SCAVENGED`, `WRECK_COMPONENT`, `SALVAGE`), calcolo del valore e metodo di liquidazione in blocco `liquidate_scavenged_items()`.
  - In `StationHubApp` Tab 1 (Logistica & Cargo Market), differenziazione diegetica delle merci ordinarie dal bottino recuperato nello spazio e pulsante rapido "⚡ Vendi Tutto il Bottino Scavenging" per la conversione immediata in Crediti e FLUX.
  - In `StationHubApp` Tab 2 (Bacheca Contratti), conteggio dei contratti completati non riscossi e pulsante "💰 Riscuoti Tutti i Contratti" con accredito unificato e notifica diegetica.
  - In `StationHubApp` Tab 4 (Cantiere), gestione trasparente del debito residuo del canone noleggio scafo con pagamento discrezionale manuale a quote o estinzione completa.
  - In `ShipBlueprint`, implementato `save_blueprint_state(file_path)` con salvataggio persistente su directory utente (`user://blueprints/active_corvette_session.tres`) collegato automaticamente al termine delle transazioni di rientro o tramite pulsante dedicato.
  - Validato con suite automatizzata GUT (`tests/gut/test_phase_g_debriefing_persistence_loop.gd`).

---

## 5. Sintesi Operativa

Questo flusso rappresenta la piena maturazione di *Dark Nova: Rogue Squadron* come simulatore cooperativo asimmetrico:
1. **La tecnologia di base è pronta e solida**: l'architettura a finestre di GodotOS, i protocolli RBAC, la gestione dei droni (Duct e Service), i sottosistemi di potenza, supporto vitale e telecomunicazioni costituiscono già un'infrastruttura d'avanguardia.
2. **I pezzi mancanti completano la catena di valore**: l'introduzione della balistica newtoniana vettoriale, dell'app procedurale System Discover, del ciclo di contratti e scavenging 3D e della cyber-difesa attiva trasforma il progetto da sandbox tecnico a esperienza di gioco ricca di tensione, strategia e rendimento cooperativo continuo.
