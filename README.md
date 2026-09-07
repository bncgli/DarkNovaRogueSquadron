# Dark Nova: Rogue Squadron

*Un simulatore cooperativo asimmetrico di una corvetta stellare, interamente pilotato attraverso il sistema operativo di bordo diegetico "GodotOS".*

## Cos'è il gioco

**Dark Nova: Rogue Squadron** mette l'equipaggio (da 1 a più giocatori, in LAN o in Solo Mode) al comando di una corvetta spaziale di frontiera. Non si controlla un avatar in prima/terza persona: tutta l'esperienza di gioco avviene attraverso le finestre, i terminali e i file di configurazione `.dat` del computer di bordo **GodotOS**, un desktop diegetico multi-finestra ispirato ai sistemi operativi reali (taskbar, menu Start, gestione finestre, editor di testo, file manager, ecc.).

Ogni membro dell'equipaggio può assumere un ruolo operativo diverso — **Capitano**, **Pilota**, **Soldato**, **Ingegnere**, **Hacker** o **Stagista** — con accesso alle applicazioni di bordo pertinenti al proprio incarico (pilotaggio, armi, scudi, energia, sensori, comunicazioni...). In **Solo Mode** un singolo giocatore ottiene il controllo completo di tutti i sistemi della nave.

## Come avviarlo

1. **Requisiti**: [Godot Engine 4.7](https://godotengine.org/download) (il progetto usa il renderer *Forward Plus*).
2. Clona o scarica questo repository.
3. Apri Godot Engine, seleziona "Importa" e scegli il file `project.godot` nella cartella del progetto.
4. Avvia il progetto (F5): la scena principale è `Scenes/Main/MainScene.tscn`.
5. Dalla schermata di **Lobby & Matchmaking** scegli se giocare in **Solo Mode**, ospitare una partita (**Host**) oppure unirti a una nave già in ascolto sulla rete locale (**Join**), quindi seleziona il tuo ruolo e premi "Avvia Missione" quando l'equipaggio è pronto.

## Panoramica delle funzionalità

### Il desktop GodotOS (`Scenes/`)
Gestione finestre flottanti ridimensionabili, taskbar, menu Start, notifiche di sistema, copia-incolla, gestione hotkey e drive virtuali (`Ship Drive` condiviso e `Terminal Drive` locale) su cui vivono i file di configurazione `.dat` delle applicazioni di bordo. La taskbar ospita anche il widget diegetico **PodInfo**, sempre attivo (non è un'app apribile/chiudibile): mostra in tempo reale Ossigeno, Temperatura, Pressione e G-Force della plancia, gestisce il microfono virtuale spazializzato per i suoni di bordo ed applica gli effetti fisiologici critici (Blackout/Redout/GameOver).

### Applicazioni della nave (`Applications/`)
Le applicazioni realmente operative a bordo della corvetta includono, tra le altre:

- **Flight Control** — pilotaggio manuale della nave con controlli RCS a 6 gradi di libertà, modalità di Crociera (Cruise Drive) e allineamento/attivazione dell'Hyperdrive verso una rotta calcolata su System Map.
- **Weapons** — puntamento della torretta (mouse o slider), quattro sistemi d'arma selezionabili (mitragliatrice pesante, cannone a impulsi, missili a ricerca, sonde), lock bersaglio con calcolo dell'anticipo di tiro e Point-Defense automatico.
- **Shield Matrix** — bilanciamento energetico dei 4 quadranti scudo (Prua/Poppa/Babordo/Tribordo) e gestione dei dispositivi di difesa direzionale (torrette Gatling e lanciatori Flack) contro proiettili e missili in arrivo.
- **Power Grid** — distribuzione dell'energia dei reattori verso le utenze di bordo (motori, sensori, scudi, supporto vitale).
- **Sensors** — radar tattico con sweep passivo e ping attivo, occlusione realistica della linea di vista, lock bersaglio e trasmissione waypoint a Flight Control e Weapons.
- **Comms** — antenna direzionale orientabile, sintonizzazione di frequenze radio subspaziali, richiesta di attracco alle stazioni spaziali e intrusione EW sul drive remoto di un bersaglio agganciato.
- **Cams** — sorveglianza video esterna a 360° tramite le telecamere di scafo.
- **Duct Drone** e **Service Drone** — droni teleguidati per ispezioni/riparazioni nei condotti interni e per operazioni extra-veicolari (EVA) esterne allo scafo.
- **Life Support** — monitoraggio e controllo dei parametri vitali (ossigeno, pressione, temperatura, incendi) per ogni compartimento.
- **Diagnostics** — scansione di sicurezza dei drive virtuali e diagnostica dei sistemi di bordo.
- **Cargo Bay** — inventario della stiva con limiti di massa/volume, dettagli del carico ed espulsione (jettison).
- **Flux Wallet** — stato economico della nave e modificatori dell'indice **FLUX**.
- **System Map** e **Station Hub** — mappa del sistema stellare per la pianificazione delle rotte e servizi diegetici delle stazioni orbitali (attracco, commercio, contratti).
- **Terminal** — riga di comando diegetica UNIX-like con comandi come `ls`, `cd`, `pwd`, `cat`, `mkdir`, `touch`, `date`, `echo`, oltre a comandi specifici della progressione hacker (`worm`, `decript`, `dataread`).
- **Games** — una selezione di mini-giochi giocabili direttamente dal desktop: **Godotris** (Tetris-like), **Pong**, **Snake** e **Super Bit Boy**.

### Simulazione esterna (`Outside/`)
Simulazione 3D dello spazio circostante la nave (`SpaceWorldManager`, `space_scene`, `spaceship`, asteroidi) e la griglia del sistema stellare (`StarSystemGrid`) che alimentano radar, telecamere, mining e navigazione.

## Controlli principali

**Pilotaggio (Flight Control):**
| Comando | Azione |
| :--- | :--- |
| `W` / `A` / `S` / `D` | Traslazione orizzontale/longitudinale (RCS) |
| `Spazio` / `Ctrl` | Salita / discesa verticale |
| `Q` / `E` | Rollio |
| Frecce direzionali | Beccheggio / imbardata |
| `R` / `F` | Aumenta / riduce il moltiplicatore di velocità |

**Torretta armi (Weapons):**
| Comando | Azione |
| :--- | :--- |
| `Spazio` | Cattura/rilascia il puntatore mouse sulla torretta |
| `Esc` | Rilascia il puntatore mouse |
| `1`-`4` | Seleziona il sistema d'arma (MG pesante, Cannone, Missili, Sonda) |
| Click sinistro | Fuoco (con puntatore catturato) |

**Scorciatoie generali del desktop GodotOS** (configurabili in `project.godot`): `Ctrl+S` salva, `F2` rinomina, `Ctrl+Shift+F` apri nel file manager, `Ctrl+=`/`Ctrl+-` zoom, `Alt+Invio`/`F11` schermo intero, `Ctrl+Shift+Canc` chiudi tutte le finestre.

## Requisiti tecnici

- **Motore**: Godot Engine 4.7 (Forward Plus).
- **Versione progetto**: v1.2.0 (vedi `project.godot`).
- **Licenza**: [GNU Affero General Public License v3.0](LICENSE).

## Documentazione per sviluppatori

Chi desidera contribuire allo sviluppo può consultare:
- [`docs/DARK_NOVA_FEATURES_DESIGN.md`](docs/DARK_NOVA_FEATURES_DESIGN.md) — documento di design, flusso utente e catalogo delle applicazioni.
- [`docs/APP_ARCHITECTURE_STANDARD.md`](docs/APP_ARCHITECTURE_STANDARD.md) — standard architetturale per le applicazioni di bordo.
- [`TODO.md`](TODO.md) e [`CHANGELOG.md`](CHANGELOG.md) — stato di avanzamento e cronologia delle modifiche.

## Crediti

Il progetto nasce come derivazione di **GodotOS**, il desktop diegetico originale creato da [popcar2](https://github.com/popcar2/GodotOS):

* [Sfondo predefinito](https://unsplash.com/photos/snow-capped-mountain-at-night-3s85IxVDyXE) di Haseeb Jamil.
* Icone varie da [game-icons](https://game-icons.net/).
* Icone cartelle da [flaticon](https://www.flaticon.com/).
* Sfondi aggiuntivi di [lydex256](https://github.com/lydex256).
* "Godotris" di [MrakDun-desu](https://github.com/MrakDun-desu).
* "Snake" di [jean-philippe-martin](https://github.com/jean-philippe-martin).
* "Terminal" di [o-GUTS](https://github.com/o-GUTS).

---

**Nota**: Dark Nova: Rogue Squadron non è un vero sistema operativo, ma un'applicazione con un'interfaccia diegetica che ne simula uno. Il progetto non è affiliato agli sviluppatori di Godot Engine o alla Godot Foundation.
