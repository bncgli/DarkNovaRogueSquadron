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
| **OS & Settings** | GodotOS Desktop, notifiche periferica (`NotificationManager`), scaling e display in `Settings Window`. | Tab comandi/controller in `Settings Window`: remapping assi analogici, deadzone joystick/cloche, mapping tastiera/mouse. | **Parziale** |
| **Lobby & Inizializzazione** | `LobbyApp`, selezione Solo/Host/Join, sincronizzazione ruoli RBAC, caricamento custom `ShipBlueprint`. | Generazione rapida/procedurale o selezione integrata da `SystemDiscover` e spawn obbligatorio attraccato alla stazione con debito iniziale preimpostato (`-700 FLUX`). | **Parziale** |
| **Procedural Generation** | `ShipBuilder` (generazione stanze e telai), `StarSystemEditor` (editor manuale di sistemi stellari). | Applicazione **System Discover** (o generatore procedurale per creare randomicamente sistemi completi con stazioni, pianeti e settori di pericolo). | **Mancante** |
| **Station Services (StationHub)** | Struttura a 5 Tab (Market, Contratti, Software, Cantiere, Taverna), API attracco `DockingManager`. | Generazione contratti procedurali (Bounty, Retrieval, Scorta) collegati al mondo; Bar con rumors attivi che generano POI nel mondo 3D; Logica economica dinamica stile X4 basata su domanda/offerta tra mercati diversi. | **Parziale** |
| **Navigazione & Streaming Quadranti** | `StarSystemGridManager` (coordinate `Vector3i`, calcolo distanze, cache `SectorData`), `SpaceWorldManager.load_sector_zone()`. | Rilevamento prossimità bordo quadrante in volo a velocità di crociera, pre-caricamento asincrono (`load_threaded_request`) del quadrante adiacente, origin shifting e scaricamento dinamico del settore alle spalle; posizionamento volumetrico dei POI a quote $Y$ variabili (dislivelli verticali tridimensionali). | **Mancante** |
| **Sensori, LIDAR & Sonde** | Raggio 1km, coni d'ombra radar (LOS), ping energetico in `SensorsApp`, filtri Cams (Normal/Thermal/Lidar), lancio `Probe`. | Spawn relitti con detriti sparsi nei quadranti a quote/altezze variabili; radar volumetrico sferico 3D con indicazione quota altimetrica relativa; integrazione di detriti e relitti rilevabili dallo shader lidar/termico e spettrometria sensori. | **Parziale** |
| **Service Drone (Esterno)** | Scena 3D del drone, collisioni fisiche, controlli di volo e rotazione, alimentazione da Sublayer. | Meccanica attiva di **Scavenging** 3D: raggio traente o manipolatore per agganciare container/rottami e trasferirli nella stiva `CargoBay`. | **Parziale** |
| **Balistica Newtoniana Torretta** | Torretta Weapons con cattura mouse (`KEY_SPACE`), classi munizioni 1..4, HUD lead indicator. | **Somma vettoriale della nave**: aggiungere $\vec{v}_{ship}$ alla velocità del proiettile al momento dello sparo e calcolo del danno scalato su velocità relativa d'impatto con il bersaglio. | **Mancante** |
| **Combattimento Cyber (Hackwarfare)** | `HackExploitsApp`, montaggio Target Drive, exploit (spammer, blind_eye, 8loops, gout), comandi terminale `worm`/`decript`/`datread`. | Logica di AI nemica che contrattacca iniettando file malevoli nello Ship Drive del giocatore; meccanica diegetica per cui l'Hacker deve localizzare ed eliminare il file malevolo prima del timeout. | **Mancante** |
| **Danni & Riparazioni Interne** | `DiagnosticsApp`, `LifeSupportApp` (P, T, O2, G), incendi, brecce, `DuctDrone` con estintore e saldatore, effetti sensoriali `PodInfo`. | Feedback sonori diegetici sincronizzati con `ship_damage_taken` (boato impatto, decompressivo, scariche elettriche nei pod). | **Parziale** |
| **Economia & Loop Ricorsivo** | `FluxWalletApp`, gestione stiva `CargoBayApp`. | Riscrittura/consolidamento di `FluxEconomyManager` per gestire debiti e crediti (baratto rate/quote) anziché crediti flat; ciclo completo di incasso taglia dal Fixer. | **Parziale** |

---

## 4. Piano di Sviluppo Dettagliato (Roadmap & Action Plan)

### Fase A: Fondamenta Controlli, Economia e Partenza Stazione (Priorità Alta)

#### Task A1: Tab Controlli e Joystick in `Settings Window`
- **Obiettivo**: Permettere a ogni giocatore di calibrare e rimappare comandi tastiera, mouse e controller/joystick prima di entrare in partita.
- **Implementazione**:
  - Estendere `Scenes/Window/Settings Window/settings_window.tscn` aggiungendo un tab o sottomenu `Controlli & Periferiche`.
  - Lettura delle periferiche attive tramite `Input.get_connected_joypads()`.
  - Assegnazione assi per volo/torretta (Pitch, Yaw, Roll, Throttle) e regolazione della sensibilità/deadzone con persistenza su file di configurazione utente locale (`user://input_config.json`).

#### Task A2: Spawn Iniziale Attraccato & Condizione Economica Debito
- **Obiettivo**: Far iniziare ogni sessione con la nave attraccata alla stazione e bilancio iniziale configurato a `300 FLUX` disponibili e `-700 FLUX` di debito noleggio.
- **Implementazione**:
  - Modificare l'inizializzazione partita in `SpaceWorldManager` e `LobbyApp`: all'avvio sessione la nave è posizionata a zero metri dal docking bay della stazione del settore di partenza con stato `is_docked = true`.
  - Inizializzare `ShipBlueprint` con `flux = 300` e un modificatore attivo `{"id": "ship_rent", "name": "Ship Rent Service", "amount": -700, "locked": true}`.
  - Aggiornare `FluxWallet` e `StationHub` per mostrare correttamente la passività e richiedere il ripianamento del canone di noleggio.

---

### Fase B: Generazione Procedurale Sistemi & Applicazione "System Discover" (Priorità Alta)

#### Task B1: Modulo e Applicazione `System Discover`
- **Obiettivo**: Offrire uno strumento procedurale diegetico per generare rapidamente sistemi stellari randomici (`StarSystemData`) pronti per essere giocati o caricati nella Lobby.
- **Implementazione**:
  - Creare `Applications/SystemDiscover/system_discover_app.gd` e `.tscn` (registrata in GodotOS).
  - Algoritmo di generazione procedurale:
    - Stella centrale (tipo spettrale, classe di calore e radiazione).
    - Da 3 a 8 pianeti con orbite proporzionali e parametri atmosferici/risorse.
    - Fasce di asteroidi con densità e composizione minerale variabile.
    - Da 1 a 3 stazioni spaziali (commerciali, industriali o avamposti fuorilegge).
    - Quadranti speciali: zone di relitti (*debris fields*), nubi di gas e settori caldi di taglie (*bounty hunting zones*).
    - **Distribuzione Volumetrica 3D dei POI (Quote/Altezze Variabili su Asse Y)**: assegnazione a tutte le entità e punti di interesse di coordinate spaziali $Vector3(x, y, z)$ con quote ed elevazioni variabili ($Y \in [-H, +H]$ rispetto all'eclittica o al piano equatoriale del settore), superando qualsiasi vincolo di altezza fissa a zero ($Y \neq 0$).
  - Funzione di esportazione/salvataggio come risorsa `StarSystemData` caricabile direttamente nella Lobby prima del lancio.

---

### Fase C: Servizi Portuali Avanzati su StationHub (Priorità Media)

#### Task C1: Bacheca Contratti & Fixer Dinamico
- **Obiettivo**: Trasformare il Tab Contratti di `StationHub` in una vera bacheca contratti collegata a eventi e POI della simulazione.
- **Implementazione**:
  - Generatore di contratti legati al sistema corrente:
    - Missioni di **Bounty**: bersaglio pirata spawnato in un quadrante specifico a quota/altezza 3D variabile (coordinate volumetriche trasmesse al Logbook).
    - Missioni di **Trasporto**: consegna pacchi cargo a un'altra stazione con scadenza a tempo.
    - Missioni di **Retrieval**: recupero di una scatola nera o risorsa speciale da un relitto posizionato a coordinate spaziali tridimensionali.
  - Aggancio al completamento della missione con incasso del premio in FLUX e notifica di debriefing.

#### Task C2: Il Bar della Stazione e Generazione Rumors
- **Obiettivo**: Rendere il Tab Taverna un aggregatore di informazioni esplorative con impatto reale sullo spazio 3D.
- **Implementazione**:
  - I rumors acquistabili o ascoltati generano punti di interesse temporanei o stabili (`Debris Field`, `Wreck Site`) nel quadrante indicato, comprensivi di offset altimetrico sull'asse Y.
  - Pulsante "Invia a Mappa Stellare" che crea un Waypoint automatico diegetico leggibile da `System Map` e `Flight Control`.

#### Task C3: Borsa Merci Dinamica Stile X4
- **Obiettivo**: Offrire differenziali di prezzo di acquisto/vendita tra stazioni e settori.
- **Implementazione**:
  - Ogni stazione possiede profili di consumo e produzione diversi (es. Stazione Mineraria: minerali economici, cibo/elettronica costosi; Avamposto Tecnologico: chip economici, metalli grezzi ad alto valore).
  - La compravendita di merci aggiorna la stiva di `CargoBay` e modifica il rating FLUX del mercato locale.

---

### Fase D: Esplorazione, Relitti e Scavenging con Service Drone (Priorità Alta)

#### Task D1: Generazione Debris Field & Relitto Orbitale
- **Obiettivo**: Popolare i quadranti designati con campi di detriti fluttuanti, rottami e relitti scansionabili distribuiti a quote ed elevazioni 3D variabili sull'asse Y.
- **Implementazione**:
  - In `SpaceWorldManager`, creazione di nodi `WreckSite` composti da una carcassa principale e detriti fisici minori, posizionati nello spazio a coordinate $Vector3(x, y, z)$ con quote verticali variabili rispetto all'origine del quadrante (evitando l'appiattimento a $Y = 0$).
  - Firma spettrometrica e radar per i Sensori (inclusa la marcatura di elevazione/quota azimutale e polare) e risposta ai filtri LIDAR e Termico delle telecamere esterne per identificare il nucleo recuperabile tra i rottami inerti a qualsiasi dislivello di quota.
  - Meccanica di allerta: timer o probabilità di spawn di navi ostili ("Sciacalli") che possono sopraggiungere da quote superiori o inferiori attratti dall'attività di recupero della corvetta.

#### Task D2: Meccanica di Scavenging per il Service Drone
- **Obiettivo**: Permettere al Drone di Servizio di prelevare materiali e container dal relitto e stivarli nella nave madre.
- **Implementazione**:
  - Aggiungere al `ServiceDrone` un raggio o morsa manipolatrice (`Manipulator / Tractor Beam`) azionabile dal pilota del drone quando entro 5 metri da un container/componente del relitto.
  - Il drone trasporta l'oggetto fino al portello di carico della corvetta.
  - All'aggancio al portello, l'oggetto viene rimosso dallo spazio 3D e aggiunto all'inventario di `CargoBay` con notifica audio e telemetrica.

#### Task D3: Caricamento Dinamico e Streaming Asincrono dei Quadranti a Velocità di Crociera
- **Obiettivo**: Consentire alla nave di transitare continuativamente attraverso i confini dei quadranti navigando a velocità di crociera sub-luce, caricando dinamicamente e in background il quadrante adiacente quando ci si avvicina al bordo per un'esperienza seamless priva di schermate di caricamento.
- **Implementazione**:
  - **Proximity Trigger di Confine Quadrante**:
    - Monitoraggio continuo della posizione 3D della nave all'interno del volume del settore attivo (`SECTOR_SIZE_KM` in `StarSystemGridManager` / `SpaceWorldManager`).
    - Calcolo della distanza dai 6 piani di confine del quadrante: quando la distanza scende sotto la soglia di guardia (es. 15-20% del raggio del settore o margine dinamico basato sul tempo all'attraversamento $t = \frac{dist}{|\vec{v}_{ship}|}$), viene identificato il quadrante adiacente verso cui punta il vettore di moto: $\vec{C}_{target} = \vec{C}_{curr} + \vec{d}_{boundary}$.
  - **Threaded / Asynchronous Pre-loading**:
    - Avvio del caricamento in background dei dati del settore (`SectorData`), skybox occlusion, entità celesti, stazioni o relitti del quadrante bersaglio tramite `ResourceLoader.load_threaded_request()` o thread separato, azzerando lag spike e freeze della simulazione.
  - **Seamless Crossing & Floating Origin Shift**:
    - Al varcare fisico della soglia del quadrante, il settore di destinazione viene promosso a settore attivo (`current_sector_data`), le sue entità fisiche vengono attivate nell'albero di scena e viene applicato un origin shift o riallineamento delle coordinate per preservare la precisione floating-point dei calcoli fisici di Godot.
  - **Unloading e Gestione Memoria del Settore Superato**:
    - Quando la nave si allontana dal confine oltre la zona di buffer, le entità fisiche 3D pesanti del settore precedente vengono scaricate dalla memoria o riciclate tramite pooling, preservando nella cache solo i metadati leggeri per i sensori a lungo raggio.
  - **Integrazione con la Plancia (Flight Control & System Map)**:
    - Supporto in `Flight Control` per la modalità di accelerazione a crociera continua (*Cruise Speed Throttle*).
    - Aggiornamento in tempo reale e continuo della traiettoria di volo lungo la griglia vettoriale della `System Map` e sui radar di `SensorsApp`.

---

### Fase E: Fisica Balistica Newtoniana & Combattimento Hard Sci-Fi (Priorità Massima)

#### Task E1: Somma Vettoriale della Nave ai Proiettili Torretta
- **Obiettivo**: Rispettare rigorosamente la relatività galileiana applicando la cinematica newtoniana a proiettili di mitragliatrici pesanti e cannoni.
- **Implementazione**:
  - In `SpaceWorldManager.request_fire_weapon()` e nello spawn dei proiettili fisici:
    - Ricavare il vettore velocità lineare istantaneo della corvetta: $\vec{v}_{ship} = \text{ship.linear\_velocity}$.
    - Ricavare il vettore direzione di mira della torretta $\hat{d}_{aim}$ e la velocità propria del proiettile $v_{muzzle}$.
    - Calcolare la velocità iniziale assoluta del proiettile:
      $$\vec{v}_{proj} = \vec{v}_{ship} + (\hat{d}_{aim} \times v_{muzzle})$$
    - Assegnare $\vec{v}_{proj}$ alla simulazione fisica del proiettile nello spazio 3D.
  - Se $\vec{v}_{ship}$ è concordante con $\hat{d}_{aim}$, la gittata e la velocità d'impatto aumentano; se discorde, diminuiscono.

#### Task E2: Calcolo del Danno Cinetico Relativo all'Impatto
- **Obiettivo**: Scalare il danno inflitto in base all'energia cinetica relativa all'impatto.
- **Implementazione**:
  - Al momento della collisione del proiettile contro il bersaglio (nave nemica o nave giocatore), calcolare la velocità relativa di collisione:
    $$\vec{v}_{rel} = \vec{v}_{proj} - \vec{v}_{target}$$
  - Moltiplicatore di danno cinetico:
    $$\text{danno\_effettivo} = \text{danno\_base} \times \left(\frac{|\vec{v}_{rel}|}{v_{muzzle}}\right)$$
  - Un bersaglio che accelera frontalmente verso il colpo riceve danno maggiorato; un bersaglio in fuga nella stessa direzione subisce un danno ridotto o attutito.

---

### Fase F: Guerra Elettronica, Contrattacco Hacker & Feedback Diegetici (Priorità Alta)

#### Task F1: Contrattacco Hacker Nemico e File Exploit Malevoli
- **Obiettivo**: Creare la minaccia attiva di sabotaggio nemico a cui l'Hacker di bordo deve rispondere diegeticamente.
- **Implementazione**:
  - Quando si è a portata di combattimento con navi nemiche ostili provviste di EW, un timer probabilistico avvia un attacco informatico sulla nave dei giocatori.
  - Viene iniettato un file `.dat` sentinella malevolo nella cartella protetta di un'app a bordo (es. `Ship Drive/Programs/FlightControls/worm_exploit.dat` o `PowerGrid/overload_virus.dat`).
  - L'exploit provoca anomalie in tempo reale (spostamento motori, distorsione telecamere, allarmi acustici).
  - L'Hacker riceve un allarme di intrusione e deve navigare nel file system, individuare il file infetto ed eliminarlo rapidamente prima dello scadere del timeout di sicurezza per neutralizzare la minaccia.

#### Task F2: Feedback Sensoriali Interni & Fluttuazioni Vitali
- **Obiettivo**: Riconnettere i danni esterni a effetti sensoriali claustrofobici all'interno dei pod.
- **Implementazione**:
  - Al segnale `ship_damage_taken`:
    - Riproduzione suoni 3D ovattati/interni: boato d'impatto metallico, allarme depressurizzazione per breccia, ronzio di scariche elettriche per corti circuiti, sibilo di fiamma per incendi.
    - Scuotimento dello schermo (camera shake leggero del desktop) proporzionale alla violenza del colpo.
    - Sincronizzazione immediata con `LifeSupport` e `PodInfo`: fumo tossico o calo di ossigeno aumentano il battito cardiaco dei giocatori, provocando distorsioni visive e rantoli se non risolti dall'Ingegnere con il Duct Drone.

---

### Fase G: Chiusura del Ciclo e Debriefing (Priorità Media)

#### Task G1: Flusso Completo di Fine Missione e Rientro
- **Obiettivo**: Automatizzare la vendita di bottino e riscossione taglie all'attracco, con salvataggio dello stato persistente della nave.
- **Implementazione**:
  - Aggancio di StationHub con le entità recuperate in `CargoBay`: visualizzazione separata delle merci commerciali standard e del "Loot di Scavenging" (rottami rari, moduli nemici, chip cifrati).
  - Riscossione immediata della taglia con azzeramento del contratto attivo nel Logbook e accredito dei FLUX nel wallet di bordo.
  - Verifica automatica del saldo per la detrazione della quota di noleggio nave (`Ship Rent Service`), aggiornando il debito residuo e salvando la `ShipBlueprint` con le nuove risorse accumulate per la sessione successiva.

---

## 5. Sintesi Operativa

Questo flusso rappresenta la piena maturazione di *Dark Nova: Rogue Squadron* come simulatore cooperativo asimmetrico:
1. **La tecnologia di base è pronta e solida**: l'architettura a finestre di GodotOS, i protocolli RBAC, la gestione dei droni (Duct e Service), i sottosistemi di potenza, supporto vitale e telecomunicazioni costituiscono già un'infrastruttura d'avanguardia.
2. **I pezzi mancanti completano la catena di valore**: l'introduzione della balistica newtoniana vettoriale, dell'app procedurale System Discover, del ciclo di contratti e scavenging 3D e della cyber-difesa attiva trasforma il progetto da sandbox tecnico a esperienza di gioco ricca di tensione, strategia e rendimento cooperativo continuo.
