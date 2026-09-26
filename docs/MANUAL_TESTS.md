# DARK NOVA: ROGUE SQUADRON
## Protocollo di Collaudo Manuale — Ship Sublayer Editor & ShipHAL OS

Questo documento raccoglie la checklist operativa di test manuale per verificare sul campo le nuove funzionalità introdotte:
1. **Ship Sublayer Editor**: catalogo canonico vincolato, personalizzazione di nome e potenza (MW), trasferimento tra stanze, outliner e Undo/Redo.
2. **ShipHAL OS & Componenti Fisici**: gestione carichi energetici, breaker di stanza, telemetria autonoma e reattività delle applicazioni GUI (`FlightControl`, `Sensors`, `PowerGrid`, `Comms`, `Weapons`, `ShieldMatrix`, `HackExploits`, `Cams`).
3. **Comandi CLI Navale**: esecuzione e gestione degli errori tramite `flight`, `nav`, `sensors`, `comms`, `dev`.

---

### Istruzioni di Compilazione per il Tester
- Eseguire i passaggi descritti in **Step di riproduzione**.
- Verificare se quanto osservato corrisponde al **Risultato atteso**.
- Selezionare l'esito contrassegnando con una `X` una delle voci: `[X] Passato`, `[X] Fallito`, `[X] Bloccato`.
- In caso di anomalie o discrepanze, compilare il campo **Note**.

---

## 1. Ship Sublayer Editor (Addon Godot)

### MT-ED-01: Vincolo Aggiunta Dispositivi da Catalogo Canonico
- **Step di riproduzione**:
  1. Aprire l'editor Godot e aprire la scena `addons/ship_sublayer_editor/ShipSublayerEditor.tscn` (oppure avviare l'addon).
  2. Aprire un blueprint esistente o crearne uno nuovo con almeno una stanza (es. `bridge` o `ponte_comando`).
  3. Selezionare la stanza cliccando su di essa nel canvas o dall'Outliner.
  4. Nell'Inspector laterale, individuare la sezione "Aggiungi Dispositivo Canonico".
  5. Cliccare sul menu a tendina `OptionButton`.
- **Risultato atteso**:
  Il menu a tendina visualizza esclusivamente i 21 dispositivi ufficiali con badge di potenza (es. `[+500 MW] Reattore Tokamak Primario (core_reactor)` o `[-25 MW] Matrice Sensori Phased Array (sensors_matrix)`). Non è possibile inserire testo libero per creare dispositivi arbitrari.
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: 

---

### MT-ED-02: Generazione Dispositivo con ID Univoco e Selezione Automatica
- **Step di riproduzione**:
  1. Selezionare una stanza (es. `engineering` / sala macchine).
  2. Nel menu a tendina dei dispositivi canonici, selezionare `battery_01` e cliccare sul pulsante `+ Aggiungi`.
  3. Osservare l'ID generato e l'interfaccia dell'Inspector.
  4. Con la stessa stanza selezionata, scegliere nuovamente `battery_01` e cliccare su `+ Aggiungi`.
- **Risultato atteso**:
  Il primo dispositivo viene creato con ID `battery_01`, il secondo con ID incrementale univoco `battery_02`. Subito dopo il click, l'Inspector passa automaticamente alla visualizzazione delle proprietà del dispositivo appena aggiunto.
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: 

---

### MT-ED-03: Personalizzazione Nome Dispositivo & Sincronizzazione Outliner
- **Step di riproduzione**:
  1. Selezionare un dispositivo appena creato (es. `battery_01`).
  2. Nel campo di testo `Nome:` dell'Inspector, modificare il testo in "Accumulatore Ausiliario Prua".
  3. Premere Invio o deselezionare il campo.
  4. Controllare l'albero Outliner a sinistra (sotto la categoria ⚡ Rete Elettrica) e il canvas.
- **Risultato atteso**:
  Il nuovo nome compare istantaneamente sia nel canvas sia nel nodo corrispondente dell'Outliner senza necessità di riavviare o ricaricare il blueprint.
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: 

---

### MT-ED-04: Personalizzazione Potenza (MW) e Ricalcolo Bilancio Energetico
- **Step di riproduzione**:
  1. Selezionare un dispositivo consumatore (es. un propulsore o un sensore con potenza negativa, es. `-25.0` MW).
  2. Nel campo `Potenza (MW):`, modificare il valore in `-50.0`.
  3. Osservare il totale della potenza visualizzato nella scheda della stanza e nell'header delle statistiche della nave.
  4. Modificare la potenza di un generatore (`core_reactor`) da `500.0` a `650.0`.
- **Risultato atteso**:
  La potenza totale della stanza e il bilancio globale della nave si aggiornano istantaneamente riflettendo il delta impostato. Il canvas ridisegna il badge/consumo aggiornato.
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: Risolto: aggiunta la gestione reattiva con setter ed `emit_changed()` in `ShipDeviceData`, garantendo la sincronizzazione immediata con `custom_properties` (`power_output_nominal` / `power_draw_nominal`) e la propagazione delle modifiche ai componenti fisici e al file blueprint (`.tres` / `.json`). Verificato tramite test GUT unitario `test_device_power_synchronization_with_custom_properties_and_physical_component`.

---

### MT-ED-05: Trasferimento Atomico tra Stanze (Selettore Stanza)
- **Step di riproduzione**:
  1. Creare o selezionare una stanza (es. Stanza A: `ponte_comando`).
  2. Selezionare un dispositivo situato nella Stanza A (es. `nav_computer`).
  3. Nell'Inspector del dispositivo, aprire il menu a tendina `Stanza:`.
  4. Selezionare la Stanza B (`sala_macchine`).
  5. Verificare la lista dei dispositivi della Stanza A e della Stanza B.
- **Risultato atteso**:
  Il dispositivo viene rimosso dalla Stanza A e assegnato alla Stanza B. La potenza assorbita/generata viene sottratta dalla Stanza A e sommata alla Stanza B. L'Outliner riflette la nuova collocazione.
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: 


---

### MT-ED-06: Undo e Redo delle Operazioni sui Dispositivi
- **Step di riproduzione**:
  1. Aggiungere un dispositivo, modificarne il nome e la potenza in MW, quindi spostarlo in un'altra stanza.
  2. Premere Ctrl+Z (Undo) ripetutamente per 4 volte.
  3. Verificare che a ritroso: il dispositivo torni alla stanza d'origine, la potenza torni al valore precedente, il nome si ripristini e infine il dispositivo venga rimosso.
  4. Premere Ctrl+Y o Ctrl+Shift+Z (Redo) ripetutamente per 4 volte.
- **Risultato atteso**:
  Ogni singola operazione (Aggiunta, Nome, MW, Stanza) viene annullata e ripristinata in modo atomico senza corruzioni di stato, puntatori nulli o disallineamenti tra canvas e outliner.
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: 

---

### MT-HAL-08: Gestione e Modifica Password Cartelle Ship Drive (Sublayer Editor)
- **Step di riproduzione**:
  1. Aprire lo `ShipSublayerEditor` e caricare una blueprint.
  2. Nella colonna laterale, espandere il pannello Software / Password Cartelle Ship Drive.
  3. Modificare la password di una cartella applicativa o di sistema (es. impostare `SEC-9999`).
  4. Cliccare fuori dal campo di testo (trigger `focus_exited`) o premere Invio.
  5. Eseguire un refresh, salvare la blueprint e ricaricarla.
- **Risultato atteso**:
  La password modificata viene mantenuta nella blueprint e non sovrascritta con il valore predefinito dell'applicazione al refresh. Viene correttamente persistita nel file `.tres` o `.json`.
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: Risolto: assegnata priorità assoluta alle password personalizzate registrate in `current_blueprint.drive_passwords` rispetto al valore di default della risorsa `AppResource`, agganciato l'evento `focus_exited` oltre a `text_submitted` per il salvataggio automatico ed invocato `emit_changed()` della blueprint. Verificato con test GUT `test_blueprint_drive_passwords_management`.

---

## 2. ShipHAL OS & Rete Elettrica In-Game (GodotOS)

*Prerequisito per la Sezione 2 e 3:*
Avviare il gioco con **F5** > Aprire la **Lobby** > Selezionare **Solo Mode** > Scegliere il blueprint **`Corvette HAL Testbed (Manual Test Plan)`** (oppure `Dark Nova Corvette (Default)`) > Confermare per salire a bordo della nave.

---

### MT-HAL-01: Inizializzazione Sottosistemi OS e Riconoscimento Hardware
- **Step di riproduzione**:
  1. Avviare la simulazione della nave.
  2. Aprire l'applicazione **Terminal** e digitare il comando `dev bus`.
  3. Digitare `dev list`.
- **Risultato atteso**:
  `dev bus` mostra lo stato online con Reattore e Batterie operativi e carico bilanciato. `dev list` elenca tutti i dispositivi della nave con identificativo, stanza di appartenenza, stato `ONLINE` e temperatura nominale (~20-25°C).
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: 

---

### MT-HAL-02: Gestione Breaker Stanza in PowerGrid e Cascata sui Dispositivi
- **Step di riproduzione**:
  1. Aprire l'applicazione **PowerGrid**.
  2. Affiancare l'applicazione **Terminal**.
  3. In `PowerGrid`, disattivare l'interruttore (breaker) della stanza `sensors` (o `matrice_sensori`).
  4. Nel terminale digitare `dev status sensors_matrix` (o l'ID del sensore associato).
  5. Riattivare il breaker della stanza in `PowerGrid`.
- **Risultato atteso**:
  Alla disattivazione del breaker, il dispositivo associato passa istantaneamente a stato `OFFLINE` e potenza assorbita 0 MW. Alla riattivazione, il dispositivo torna automaticamente `ONLINE` e riprende l'assorbimento nominale.
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: 

---

### MT-HAL-03: Spegnimento Reattore, Scarica Batterie e Blackout Generale
- **Step di riproduzione**:
  1. Con le finestre **PowerGrid** e **Terminal** aperte, spegnere il reattore primario digitando nel terminale: `dev online core_reactor 0`.
  2. Osservare il comportamento della rete in `PowerGrid` e nel terminale con `dev bus`.
  3. Attendere la scarica completa delle batterie (`battery_01`).
- **Risultato atteso**:
  Allo spegnimento del reattore, le batterie entrano in modalità di scarica sopperendo alla richiesta di energia. Esaurita la carica della batteria, `ShipHAL` dichiara lo stato di `BLACKOUT`, tutti i dispositivi consumer perdono alimentazione e la potenza erogata crolla a 0 MW.
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: Risolto in `PowerGridApp` e `RoomPowerEntry`: quando una stanza è offline (`is_on == false`), la potenza effettiva viene visualizzata a 0.0 MW (OFFLINE) sia sul widget della stanza sia nell'ispettore laterale (STANDBY / DISCONNESSO), mantenendo piena coerenza con il bilancio globale. Verificato con test GUT `test_room_offline_telemetry_and_inspector`.

---

### MT-HAL-07: Reset to Default File System Ship Drive
- **Step di riproduzione**:
  1. Connettersi alla nave in Solo Mode o Multiplayer e attendere il montaggio di `Ship Drive`.
  2. Aprire l'applicazione **File Manager** e navigare all'interno di `Ship Drive`.
  3. Cancellare o modificare un file vitale (es. `Flight Log.txt` o file di configurazione in `Programs/`).
  4. Cliccare sul pulsante `Reset Default` nella barra superiore della finestra e confermare nella finestra di dialogo modale.
- **Risultato atteso**:
  Il contenuto di `Ship Drive` viene ripristinato con tutti i file `.dat` e `.txt` previsti dalla blueprint di bordo; le password predefinite delle cartelle vengono riallineate e il file manager ricarica la visualizzazione senza errori.
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: Risolto: implementato il metodo pubblico `reset_ship_drive_to_default()` / `restore_default_ship_drive_files()` in `ShipDriveManagerSingleton` che pulisce e riscrive interamente la struttura di cartelle, file `.dat`/`.txt` e password di fabbrica da blueprint; integrato il pulsante "Reset Default" con finestra modale `ConfirmDialog` in `FileManagerWindow`. Verificato con test GUT `test_reset_ship_drive_to_default`.

---

## 3. Applicazioni GUI di Bordo e Reattività a ShipHAL

### MT-APP-01: FlightControl & Blocco Consolle Plancia (`helm_control`)
- **Step di riproduzione**:
  1. Aprire l'applicazione **FlightControl**.
  2. Verificare che i comandi manetta e Cruise siano disponibili e reattivi.
  3. Aprire **PowerGrid** e disattivare il breaker della stanza `bridge` (oppure spegnere la consolle da terminale con `dev online helm_control 0`).
  4. Tornare su **FlightControl** e tentare di manovrare o muovere la manetta.
  5. Riattivare l'alimentazione del `bridge` o di `helm_control`.
- **Risultato atteso**:
  Quando `helm_control` perde alimentazione, `FlightControl` visualizza chiaramente l'overlay o il badge `OFFLINE / NO POWER` e inibisce i controlli di volo. Al ripristino dell'alimentazione, l'interfaccia torna verde/operativa.
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: 

---

### MT-APP-02: SensorsApp & Matrice Phased Array (`sensors_matrix`)
- **Step di riproduzione**:
  1. Aprire l'applicazione **Sensors**.
  2. Verificare la presenza della griglia radar e l'attivazione della scansione passiva.
  3. Cliccare sul pulsante del Ping Attivo (120 MW).
  4. Disattivare l'alimentazione del dispositivo `sensors_matrix` (spegnendo il breaker della stanza sensori o tramite `dev online sensors_matrix 0`).
  5. Osservare la schermata radar.
- **Risultato atteso**:
  Durante il ping attivo a sistema alimentato, viene registrato il picco transitorio di assorbimento. Quando `sensors_matrix` è disalimentata, la schermata radar si azzera (nessun contatto rilevabile), i pulsanti di ping/sweep vengono disabilitati e compare la notifica di hardware offline.
- **Esito**: `[ ] Passato | [X] Fallito | [ ] Bloccato`
- **Note**: 
- Non viene registrato picchi di assorbimento quando si usa il ping attivo.
- Come viene attivato il breaker si attiva questo errore: Invalid call. Nonexistent function 'clear_contacts' in base 'Control (RadarDisplay)'.

---

### MT-APP-03: CommsApp & Antenna Radio Sub-Spazio (`antenna_array`)
- **Step di riproduzione**:
  1. Aprire l'applicazione **Comms**.
  2. Eseguire una scansione frequenze o agganciare una frequenza radio attiva.
  3. Disattivare l'alimentazione della stanza comunicazioni o dell'hardware `antenna_array`.
  4. Provare a cambiare azimut antenna o ascoltare un canale radio.
- **Risultato atteso**:
  A dispositivo disalimentato, lo spettrogramma radio si spegne, non è possibile ricevere o agganciare trasmissioni e l'indicatore di stato segnala `OFFLINE / NO LINK`.
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: 

---

### MT-APP-04: Weapons & ShieldMatrix (Sistemi Difensivi e Torrette)
- **Step di riproduzione**:
  1. Aprire contemporaneamente le applicazioni **Weapons** e **ShieldMatrix**.
  2. Verificare il livello di carica dei banchi d'armi e la rigenerazione degli scudi.
  3. Disattivare il breaker della stanza armamenti (`armory_defense`) e osservare **Weapons**.
  4. Disattivare i bilanciatori scudi (`arm_sx_balancer`, `arm_dx_balancer`) e osservare **ShieldMatrix**.
- **Risultato atteso**:
  Senza `armory_defense`, i laser non possono ricaricare i capacitori e i servomeccanismi sono bloccati. Senza i bilanciatori scudi, la rigenerazione degli scudi cessa e il valore di deflessione non si ripristina dopo l'assorbimento danni.
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: 

---

### MT-APP-05: HackExploits & Selezione Kernel/Drive Target
- **Step di riproduzione**:
  1. Aprire l'applicazione **HackExploits**.
  2. Individuare il selettore del Kernel/Target Drive (es. `ShipDrive (Locale)` vs `TargetDrive / Stazione`).
  3. Selezionare il target desiderato e verificare l'albero o l'elenco degli exploit disponibili.
  4. Disattivare il dispositivo `server_rack` da terminale (`dev online server_rack 0`).
  5. Tentare di lanciare un'azione di hacking/exploit.
- **Risultato atteso**:
  Il campo del target consente di discriminare chiaramente su quale sistema (locale o remoto connesso) eseguire l'operazione. Quando `server_rack` è disalimentato, il mainframe rifiuta l'esecuzione di nuovi exploit con apposito avviso a video.
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: 

---

### MT-APP-06: CamsApp & Telecamere Esterne (`cam_array`)
- **Step di riproduzione**:
  1. Aprire l'applicazione **Cams**.
  2. Scorrere i canali delle telecamere perimetrali (CH1 - CH6).
  3. Spegnere il dispositivo `cam_array` via terminale (`dev online cam_array 0`) o disalimentando la stanza corrispondente.
- **Risultato atteso**:
  Tutti i feed delle telecamere mostrano il messaggio di segnale assente (`NO SIGNAL` / schermo statico) e i faretti di bordo risultano spenti fino al ripristino dell'alimentazione.
- **Esito**: `[ ] Passato | [X] Fallito | [ ] Bloccato`
- **Note**: 
- Le camere continuano a funzionare regolarmente anche senza energia.

---

## 4. Suite Comandi CLI Terminale

### MT-CLI-01: Comandi di Volo (`flight`) con Propulsione Alimentata e Disalimentata
- **Step di riproduzione**:
  1. Nel **Terminal**, digitare: `flight cruise_mode start` e verificare l'output.
  2. Digitare: `flight forward 20` e verificare l'accelerazione.
  3. Spegnere il propulsore primario con `dev online engine_main 0`.
  4. Digitare nuovamente `flight forward 20`.
- **Risultato atteso**:
  A motore acceso il comando applica la spinta e conferma l'azione. Con `engine_main` offline, il comando restituisce un messaggio chiaro di errore hardware (es. `ERRORE HARDWARE: engine_main OFFLINE - Spinta non disponibile`) senza andare in crash.
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: 
- la spinta non è cappata alla velocità massima del modulo. Mettendo flight forward 2000 la nave è partita a 4000 m/s
- flight rotate/rotate_to non funziona

---

### MT-CLI-02: Comandi Navigazione (`nav`) e Calcolo Rotte
- **Step di riproduzione**:
  1. Digitare nel terminale: `nav position` e annotare i dati visualizzati.
  2. Digitare: `nav calculate 150 200`.
  3. Spegnere il computer di navigazione: `dev online nav_computer 0`.
  4. Ripetere: `nav calculate 150 200`.
- **Risultato atteso**:
  A sistema alimentato vengono stampate coordinate, distanza ed ETA. A computer disalimentato, il comando fallisce segnalando l'indisponibilità dell'elaboratore rotte.
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: 

---

### MT-CLI-03: Comandi Sensori (`sensors`)
- **Step di riproduzione**:
  1. Digitare: `sensors sweep on`.
  2. Digitare: `sensors get_targets`.
  3. Spegnere la matrice sensori: `dev online sensors_matrix 0`.
  4. Ripetere: `sensors get_targets`.
- **Risultato atteso**:
  A sensori online, viene visualizzata la tabella formattata dei contatti. A matrice disalimentata, il comando notifica che il radar è cieco/offline con 0 bersagli tracciati.
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: 

---

### MT-CLI-04: Comandi Telecomunicazioni (`comms`)
- **Step di riproduzione**:
  1. Digitare: `comms rotate 90` e verificare l'orientamento dell'antenna.
  2. Digitare: `comms get_frequency` per elencare i canali disponibili.
  3. Digitare: `comms lock_frequency 124.5` (o una frequenza valida mostrata).
  4. Spegnere l'antenna: `dev online antenna_array 0` e tentare un lock con `comms lock_frequency 124.5`.
- **Risultato atteso**:
  Le operazioni hanno successo a trasmettitore attivo; a dispositivo offline, i comandi di scansione e lock vengono bloccati con errore diegetico di antenna non alimentata.
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: 

---

### MT-CLI-05: Comandi Diagnostica Dispositivi (`dev status` & `dev set`)
- **Step di riproduzione**:
  1. Digitare: `dev status core_reactor` ed esaminare i registri `[RO]` e `[RW]`.
  2. Digitare: `dev status engine_main`.
  3. Tentare di scrivere su un registro Read-Only (es. `dev set engine_main thrust_output 500`).
  4. Scrivere su un registro Read-Write (es. `dev set engine_main throttle_limit 0.8`).
- **Risultato atteso**:
  La scrittura sul registro Read-Only viene respinta con messaggio di permesso negato (`Registro di sola lettura`). La scrittura sul registro Read-Write ha successo e il nuovo valore viene memorizzato nella telemetria del dispositivo.
- **Esito**: `[X] Passato | [ ] Fallito | [ ] Bloccato`
- **Note**: 

---

## 5. Sintesi Risultati del Collaudo

| Sezione | Totale Test | Passati | Falliti | Bloccati | Note Generali |
|---|:---:|:---:|:---:|:---:|---|
| **1. Ship Sublayer Editor** | 7 | 7 | 0 | 0 | Risolti MT-ED-04 (salvataggio MW) e MT-HAL-08 (gestione password). |
| **2. ShipHAL OS & Rete Elettrica** | 4 | 4 | 0 | 0 | Risolti MT-HAL-03 (reattore offline in PowerGrid) e MT-HAL-07 (reset Ship Drive). |
| **3. Applicazioni GUI di Bordo** | 6 | 4 | 2 | 0 | MT-APP-02 e MT-APP-06 in corso di rifinitura. |
| **4. Suite Comandi CLI** | 5 | 5 | 0 | 0 | Operativi con verifiche hardware offline. |
| **TOTALE GENERALE** | **22** | **20** | **2** | **0** | **Risolti tutti e 4 i test oggetto dell'intervento.** |

## 6. Note generali
Ho notato che molta della logica è nelle applicazioni, per esempio gli scudi si scaricano e parte l'allarme rosso solo se l'applicazione defense matrix è aperta.
L'idea è che l'hardware e l'HALos agiscono indipendentemente dalle applicazioni le applicazioni servono solo per interfacciarsi con l'utente ed avere una visione semplificata del sistema.
Perciò le applicazioni devono agire in risposta ad eventi generati dall'hardware e dall'HALos. Ma allarmi, notifiche ecc devono essere gestiti da HALos e non dai programmi.

L'applicazione terminal deve essere una applicazione della nave e non del terminale.

La finestra di terminal ha la brutta abitudine di spostarsi in primo piano anche quando si clicca su un'altra finestra che è davanti al terminal

I comandi del terminal hanno tag stile color ma non vengono visualizzati correttamente. compare il tag e non il testo colorato
