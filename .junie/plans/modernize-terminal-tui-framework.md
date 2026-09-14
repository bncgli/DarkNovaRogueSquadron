---
sessionId: session-260912-101850-1g7a
---

# Requirements

### Overview & Goals
L'obiettivo è modernizzare il Terminale Shell diegetico di GodotOS (`Applications/Terminal/terminal_app.tres` e `terminal_scene.tscn`), trasformandolo da semplice console basata su stringhe statiche a un ambiente shell UNIX evoluto e interattivo.
Il sistema includerà:
1. **Riconoscimento comandi con Regex**: supporto a sintassi avanzata, flag, argomenti quotati e pattern matching tramite espressioni regolari.
2. **Autocompletamento con Tab**: completamento contestuale di comandi e percorsi di file/cartelle, con calcolo del prefisso comune e visualizzazione formattata delle ambiguità.
3. **Navigazione Cronologia con tasti freccia**: scorrimento fluido con Freccia Su e Freccia Giù, con preservazione della bozza in fase di digitazione.
4. **Framework TUI (Terminal User Interface) con supporto Mouse**: architettura ibrida (stream inline + overlay) per creare interfacce grafiche terminal-style (simili a quella di Junie) con pulsanti, card informative, menu a opzioni e interazioni cliccabili tramite mouse.
5. **Predisposizione integrazione applicazioni esterne**: architettura comandi aperta ed estendibile per invocare in futuro comandi e funzionalità di altre app installate nel sistema.
6. **Istanze Multiple del Terminale**: capacità di aprire più finestre contemporaneamente con titoli dinamici numerati e indicazione della cartella attiva, oltre alla creazione di nuove finestre tramite comando CLI `terminal`.

---

### Scope
- **In Scope**:
  - Refactoring del parser `terminal_input_parser.gd` con motore `RegEx`.
  - Meccanismo di registrazione comandi basato su regex in `terminal_command.gd` e `terminal_command_manager.gd`.
  - Gestione del tasto TAB per l'autocompletamento di comandi e percorsi (file/cartelle), con logica di disambiguazione.
  - Risoluzione dei bug di navigazione cronologia su UP/DOWN in `terminal_script.gd` e `terminal_input_history_manager.gd`.
  - Framework TUI modulare (`terminal_ui_widget.gd`, `terminal_ui_button.gd`, `terminal_ui_options.gd`, `terminal_ui_card.gd`, `terminal_ui_overlay.gd`) integrato in `terminal_scene.tscn`.
  - Aggiornamento di comandi standard (es. `ls`) con elementi TUI cliccabili tramite mouse.
  - Nuovo comando integrato `terminal` per aprire nuove istanze della shell.
  - Gestione di istanze multiple con identificatore numerico progressivo e percorso corrente nel titolo della finestra.
  - Test suite GUT aggiornata ed estesa.
- **Out of Scope**:
  - Implementazione completa delle API applicative di terze parti (come specificato nel prompt: "lasciamolo per dopo"); viene unicamente predisposto l'aggancio architetturale.
  - Modifica grafica invasiva al window manager generale di GodotOS estranea al terminale.

---

### User Stories
- **Come utente della shell**, voglio poter usare espressioni regolari, flag (`--flag`) e argomenti con spazi racchiusi tra virgolette, così che i comandi possano accettare parametri complessi in modo naturale.
- **Come utente della shell**, voglio premere TAB per completare rapidamente comandi e nomi di file, e vedere immediatamente la lista delle possibilità se il prefisso è ambiguo.
- **Come utente della shell**, voglio premere Freccia Su e Freccia Giù per richiamare i comandi passati senza perdere il testo che stavo digitando se decido di tornare all'inizio.
- **Come utente/giocatore**, voglio interagire con il terminale anche tramite mouse cliccando su file, pulsanti e menu interattivi in stile "Junie" (TUI diegetica).
- **Come sviluppatore di mod o future app**, voglio un framework modulare TUI per creare facilmente nuove schermate e componenti interattivi all'interno della shell.
- **Come utente multitasking**, voglio poter aprire più finestre di terminale contemporaneamente (anche digitando `terminal`), riconoscendole facilmente grazie ai titoli dinamici.

---

### Functional Requirements
1. **Regex Command Tokenizer & Dispatcher**:
   - `TerminalInputParser` deve tokenizzare stringhe supportando apici/virgolette singole e doppie, flag e concatenazione con `&&`.
   - `TerminalCommand` deve supportare pattern regex tramite proprietà dedicate (`regex_pattern` o `regex`).
   - `TerminalCommandManager` deve validare prima la corrispondenza esatta (`call_name`) e poi valutare i comandi con pattern regex, passando l'oggetto `RegExMatch` con i named groups al metodo `execute()`.
2. **Tab Autocomplete & Ambiguity Handler**:
   - Intercettazione di `KEY_TAB` nella `LineEdit` impedendo la perdita del focus UI (`accept_event()`).
   - Se il cursore si trova sul primo token: completamento dei comandi registrati.
   - Se il cursore si trova sugli argomenti: completamento di cartelle e file in base al percorso virtuale corrente.
   - In caso di corrispondenza univoca: completamento inline con aggiunta di spazio o `/`.
   - In caso di ambiguità: calcolo del Longest Common Prefix (LCP), inserimento del prefisso comune nel campo input, e stampa nell'output della lista dei candidati senza resettare la riga di comando.
3. **History Navigation**:
   - Gestione degli eventi `KEY_UP` e `KEY_DOWN` (o `ui_up`/`ui_down`).
   - Salvataggio della bozza temporanea corrente prima di scorrere all'indietro nella cronologia, con ripristino automatico tornando alla fine.
   - Spostamento automatico del cursore (caret) alla fine del testo caricato.
   - Prevenzione dell'inserimento di comandi vuoti o duplicati consecutivi nella cronologia.
4. **Terminal UI (TUI) Framework**:
   - Architettura ibrida: componenti inline (figli di `%Terminal Output`) ed eventuale layer overlay (`%TUI Overlay Host`) per schermate a vista intera.
   - Tutti i widget devono derivare da una classe base `TerminalUIWidget` (`Control`) condividendo palette (verde fosforo `matrix_green`, ciano), font monospazio `Inconsolata-Regular.ttf` e bordi diegetici.
   - Supporto ad eventi mouse: hover con cambio colore, click con emissione di segnali o dispatch di comandi della shell.
   - Componenti base: `TerminalUIButton` (pulsante d'azione cliccabile), `TerminalUIOptions` (elenco opzioni a scelta singola/multipla stile Junie), `TerminalUICard` (box informativo ASCII con titolo e corpo).
5. **Multiple Instances Management**:
   - Registrazione di un contatore globale o identificatore d'istanza per le sessioni aperte di terminale.
   - Aggiornamento del titolo in `FakeWindow` (es. `Terminale Shell UNIX [1] - /systems`).
   - Comando built-in `terminal` (alias `term`) per instanziare una nuova finestra terminale tramite `TerminalSoftwareManager.launch_app("terminal")`.

---

### Non-Functional Requirements
- **Prestazioni**: Tokenizzazione regex e autocompletamento istantanei senza cali di framerate (< 5ms per operazione).
- **Consistenza Estetica**: Mantenimento fedele dell'aspetto diegetico sci-fi / UNIX del gioco.
- **Retrocompatibilità**: Nessuna rottura per i comandi attuali (`worm`, `decript`, `dataread`, `ls`, `cd`, `cat`, `help`, `echo`, ecc.) e i test GUT esistenti.

# Technical Design

### Current Implementation
Il terminale è strutturato nei seguenti file principali:
- `Applications/Terminal/src/terminal_script.gd`: script controller principale associato alla scena `terminal_scene.tscn`. Gestisce la `LineEdit` (`command_line`), il container dei messaggi (`output_container`), e le chiamate ai manager.
- `Applications/Terminal/src/terminal_command_manager.gd`: carica e indicizza i comandi derivati da `TerminalCommand` presenti in `Applications/Terminal/commands/`. Attualmente esegue solo il matching esatto tramite chiave dizionario `call_name`.
- `Applications/Terminal/src/terminal_input_parser.gd`: suddivide l'input su `&&` e su spazi con `split(" ", false)`, senza supporto a stringhe quotate o espressioni regolari.
- `Applications/Terminal/src/terminal_input_history_manager.gd`: memorizza lo storico dei comandi. Attualmente usa azioni `ui_text_caret_up` / `down` che soffrono di problemi di input e non salvano la bozza di testo non inviata.
- `Scenes/Autoloads/SoftwareManager/terminal_software_manager.gd`: singleton che istanzia l'applicazione tramite `launch_app("terminal")` racchiudendola in un'istanza di `FakeWindow`.

---

### Key Decisions
1. **Architettura TUI Ibrida (Stream Inline + Overlay)**:
   - I widget interattivi possono essere inseriti sia come nodi all'interno del flusso di output verticale del terminale (ideale per opzioni tipo prompt di Junie o elenchi file cliccabili), sia in un container overlay trasparente per viste a tutto schermo interattive.
2. **Motore Regex Ibrido (Tokenizzazione Globale + Command Regex Dispatch)**:
   - Il parser utilizza `RegEx` per tokenizzare parametri complessi, stringhe con virgolette e flag.
   - I singoli comandi possono dichiarare una regex (`regex_pattern: RegEx`). Il `TerminalCommandManager` controlla prima il nome esatto e, in caso di mancata corrispondenza, testa i pattern registrati passando il `RegExMatch` con i gruppi di cattura.
3. **Titoli Dinamici Numerati per Istanze Multiple**:
   - Viene mantenuto un contatore progressivo delle istanze aperte. All'avvio e ad ogni cambio di cartella (`cd`), il terminale aggiorna il titolo della propria `FakeWindow` (es. `Terminale Shell UNIX #1 - ~/<path>`).
   - Viene fornito il comando `terminal` per aprire comodamente ulteriori finestre shell.
4. **Modulo Autocomplete Dedicato**:
   - La logica di completamento è isolata in `Applications/Terminal/src/terminal_autocomplete.gd`, mantenendo snello `terminal_script.gd`.

---

### Architecture Diagram
```mermaid
graph TD
    User([User Input: Keyboard / Mouse]) --> CommandLine[LineEdit / GUI Input]
    User --> MouseTUI[Mouse Clicks on TUI Widgets]
    
    subgraph Terminal Core
        CommandLine -->|Tab Pressed| AutoComplete[TerminalAutoComplete]
        CommandLine -->|Up / Down| HistoryMgr[TerminalInputHistoryManager]
        CommandLine -->|Enter Pressed| InputParser[TerminalInputParser (RegEx)]
        
        InputParser --> CommandMgr[TerminalCommandManager]
        CommandMgr -->|Exact or RegEx Match| CmdInstance[TerminalCommand Instance]
        
        CmdInstance -->|Output Lines / Widgets| OutputContainer[%Terminal Output VBox]
        CmdInstance -->|Full TUI Mode| OverlayHost[%TUI Overlay Host]
    end
    
    subgraph TUI Framework
        OutputContainer --> TUIWidget[TerminalUIWidget]
        TUIWidget --> TUIButton[TerminalUIButton]
        TUIWidget --> TUIOptions[TerminalUIOptions]
        TUIWidget --> TUICard[TerminalUICard]
        MouseTUI --> TUIButton
        MouseTUI --> TUIOptions
    end
    
    subgraph Window & Multi-Instance
        CmdInstance -->|Command 'terminal'| SoftMgr[TerminalSoftwareManager]
        SoftMgr -->|Instantiate| NewWindow[FakeWindow #N]
        NewWindow --> TerminalCore
    end
```

---

### Components & Technical Specifications

#### 1. Regex Input Parser (`terminal_input_parser.gd`)
- Implementa un'espressione regolare per il tokenizing:
  `r'("([^"\\]*(\\.[^"\\]*)*)"|\'([^\'\\]*(\\.[^\'\\]*)*)\'|(\S+))'`
- Estrae comandi concatenati (`&&`) preservando le stringhe quotate.
- Produce `TerminalParserOutput` arricchito con token normalizzati e supporto a named flags (`--key=value`, `-f`).

#### 2. Regex Command System (`terminal_command.gd` & `terminal_command_manager.gd`)
- In `TerminalCommand`:
  - `var regex_pattern: String = ""` (o `var regex: RegEx = null`)
  - `func matches_input(token: String) -> RegExMatch`
  - `func execute_regex(terminal: Node, match: RegExMatch, raw_args: PackedStringArray) -> void`
- In `TerminalCommandManager`:
  - `_commands: Dictionary` per match esatto `call_name`.
  - `_regex_commands: Array[TerminalCommand]` per match su pattern regex.
  - Metodo `find_command(command_str: String) -> Dictionary` che restituisce `{ "command": cmd, "regex_match": match }`.

#### 3. Autocompletion Engine (`terminal_autocomplete.gd`)
- Supporta due modalità in base alla posizione del cursore:
  - **Command Mode**: interroga `command_manager.get_all_command_names()`.
  - **Path Mode**: analizza il token parziale relativo a percorsi (es. `cd Sys`, `cat term`), risolvendo cartelle e file tramite `virtual_path_manager`.
- Calcola il Longest Common Prefix (LCP) tra i candidati.
- Se esistono più candidati (ambiguità), restituisce la lista formattata a colonne o a elenco per la stampa su terminale.

#### 4. History Navigation (`terminal_input_history_manager.gd`)
- Mantiene:
  - `history: Array[String]`
  - `history_index: int`
  - `current_draft: String`: testo digitato prima di iniziare a scorrere lo storico.
- In `terminal_script.gd`, aggancio pulito su `_gui_input`:
  - `KEY_UP`: se `history_index == history.size()`, salva `current_draft = command_line.text`. Decrementa indice e carica comando.
  - `KEY_DOWN`: incrementa indice; se raggiunge la fine, ricarica `current_draft`.

#### 5. TUI Component Framework (`Applications/Terminal/tui/`)
- `terminal_ui_widget.gd` (Control base):
  - Stile unificato GodotOS: font `Inconsolata`, colori `Color("39ff14")` (matrix green), `Color("00e5ff")` (cyan).
  - Gestione stato `mouse_hover` e `focused`.
- `terminal_ui_button.gd`:
  - Etichetta con parentesi quadre diegetiche `[ Esegui ]`.
  - Al passaggio del mouse si illumina; al click emette `clicked` o invia un comando direttamente alla shell.
- `terminal_ui_options.gd`:
  - Rendering di una lista di opzioni (stile Junie choices).
  - Ogni opzione è selezionabile con click del mouse o tramite numero/tasto di scelta rapida.
- `terminal_ui_card.gd`:
  - Riquadro con bordo ASCII o flat border con titolo, separator e area contenuto.
- Integrazione in `terminal_script.gd`:
  - `push_widget_to_output(widget: Control) -> void`
  - `set_tui_overlay_active(active: bool, overlay_content: Control = null) -> void`
- Integrazione in comandi:
  - Aggiornamento di `ls` per renderizzare elementi cliccabili con il mouse (clic su cartella -> esegue `cd <cartella>`, clic su file -> esegue `cat <file>`).

#### 6. Multi-Instance & CLI Spawn (`terminal_app_command.gd`)
- Variabile statica o contatore in `terminal_script.gd`:
  - `static var instance_counter: int = 0`
  - `var instance_id: int = 0`
- Metodo `update_window_title()`:
  - Cerca il nodo genitore `FakeWindow`.
  - Imposta il titolo: `"Terminale Shell UNIX #%d - %s" % [instance_id, current_virtual_path]`.
- Nuovo comando CLI `terminal`:
  - `call_name = "terminal"`
  - Esegue: `TerminalSoftwareManager.launch_app("terminal")`.

---

### File Structure
```
Applications/Terminal/
├── commands/
│   ├── terminal_command.gd               # Modificato: supporto regex e flags
│   ├── ls_command.gd                     # Modificato: supporto widget cliccabili
│   ├── terminal_app_command.gd           # NUOVO: comando CLI per aprire nuove istanze
│   └── ... (altri comandi esistenti)
├── src/
│   ├── terminal_script.gd                # Modificato: TUI host, titoli dinamici, hook Tab/History
│   ├── terminal_command_manager.gd       # Modificato: regex matcher & dispatcher
│   ├── terminal_input_parser.gd          # Modificato: tokenizer regex
│   ├── terminal_input_history_manager.gd # Modificato: gestione draft e arrow keys
│   ├── terminal_autocomplete.gd          # NUOVO: motore di autocompletamento
│   └── terminal_scene.tscn               # Modificato: aggiunta overlay host container
├── tui/                                  # NUOVA CARTELLA: Framework TUI diegetico
│   ├── terminal_ui_widget.gd             # Base class per widget TUI
│   ├── terminal_ui_button.gd             # Pulsante cliccabile terminal-style
│   ├── terminal_ui_options.gd            # Selezione opzioni interattive (stile Junie)
│   ├── terminal_ui_card.gd               # Riquadro contenitore con bordi diegetici
│   └── terminal_ui_overlay.gd            # Host per TUI a schermo intero
└── terminal_app.tres                     # Invariato (risorsa applicazione)
```

---

### Risks & Mitigations
- **Rischio: Godot LineEdit intercetta TAB per il cambio di focus della UI.**
  - *Mitigazione*: Gestire `KEY_TAB` direttamente nell'evento `_gui_input(event)` di `command_line` chiamando immediatamente `accept_event()` per consumare l'evento prima che il sistema di focus interno di Godot lo elabori.
- **Rischio: Caratteri speciali nei nomi dei file (spazi o simboli) durante l'autocompletamento.**
  - *Mitigazione*: L'autocompletamento aggiunge automaticamente virgolette di chiusura se il token conteneva virgolette aperte o esegue l'escape degli spazi.
- **Rischio: Sovraccarico della cronologia o perdita del testo non ancora inviato.**
  - *Mitigazione*: Implementazione del buffer `current_draft` che preserva il testo digitato fino a quando non viene effettivamente eseguito un comando con Invio.

# Testing

### Validation Approach
La validazione delle nuove funzionalità avverrà tramite una combinazione di test automatizzati con GUT (Godot Unit Testing framework già presente nel progetto) e verifiche sull'interfaccia terminale.

---

### Key Scenarios

#### 1. Regex Parsing & Command Execution
- Esecuzione comandi standard con argomenti con spazi racchiusi tra virgolette:
  `cat "nome file con spazi.txt"`
  *Verifica*: il parser estrae un solo argomento posizionale invece di dividerlo su ciascun spazio.
- Esecuzione comandi con pattern regex personalizzati e flag:
  *Verifica*: i gruppi di cattura regex vengono passati correttamente al comando e i flag interpretati fedelmente.
- Concatenazione comandi con `&&`:
  `cd systems && ls`
  *Verifica*: entrambi i comandi vengono eseguiti in sequenza.

#### 2. Autocompletamento (Tasto TAB)
- **Comando univoco**: digitando `wor` + TAB -> il testo si completa automaticamente in `worm `.
- **Comando ambiguo**: digitando `d` + TAB -> mostra la lista di ambiguità (`dataread`, `decript`), completa fino al prefisso comune (`d`), e ristampa la riga di input inalterata con il cursore posizionato alla fine.
- **Percorso cartella univoco**: digitando `cd Shi` + TAB -> si completa in `cd "Ship Drive/"`.
- **File ambiguo**: digitando `cat ter` + TAB -> stampa i file candidati (`terminal_config.dat`, ecc.) mantenendo intatta la bozza digitata.

#### 3. Cronologia Comandi (Freccia SU e Freccia GIÙ)
- Digitando `comando_di_prova` senza premere Invio, premendo poi Freccia SU per scorrere i comandi precedenti, e successivamente Freccia GIÙ fino alla fine:
  *Verifica*: il testo `comando_di_prova` viene ripristinato esattamente come prima.
- Invio di comandi consecutivi identici:
  *Verifica*: non vengono salvati duplicati adiacenti nella cronologia.

#### 4. Framework TUI e Input Mouse
- Esecuzione di `ls` in una cartella:
  *Verifica*: le cartelle e i file vengono generati come widget `TerminalUIWidget`.
  *Verifica click mouse*: cliccando con il tasto sinistro su una cartella visualizzata, viene automaticamente eseguito `cd <cartella>` e la visualizzazione si aggiorna.
- Rendering del componente `TerminalUIOptions` (stile opzioni Junie):
  *Verifica*: passaggio del mouse evidenzia l'opzione; il click del mouse seleziona l'opzione ed emette il segnale corrispondente.
- Overlay TUI:
  *Verifica*: attivazione e disattivazione corretta dell'overlay senza sovrapposizioni errate con la riga di comando.

#### 5. Istanze Multiple e Comando 'terminal'
- Esecuzione del comando `terminal` o `term` all'interno della shell:
  *Verifica*: viene istanziata una nuova finestra terminale indipendente.
- Verifica titoli finestre:
  *Verifica*: la prima istanza mostra `#1`, la seconda mostra `#2`, e la navigazione in una cartella aggiorna il titolo con il percorso corrente.
- Test di non-interferenza:
  *Verifica*: cambiare directory o cronologia nella finestra #1 non modifica la directory o cronologia della finestra #2.

---

### Regression Testing
- Esecuzione completa della suite GUT per i comandi speciali:
  `tests/gut/test_terminal_commands_worm_decript_dataread_node.gd`
- Esecuzione della suite per il Terminal Drive:
  `tests/gut/test_terminal_drive_node.gd`
  *Verifica*: 100% dei test esistenti continuano a passare con successo.

# Delivery Steps

### ✓ Step 1: Implement Regex Command Tokenizer and Pattern Dispatcher
Aggiornare il parsing e la gestione dei comandi del terminale per supportare espressioni regolari e pattern avanzati.

- Aggiornare `terminal_input_parser.gd` con un tokenizer basato su `RegEx` capace di gestire correttamente stringhe con virgolette (`"percorso con spazi"`), argomenti posizionali e flag/opzioni (`--flag`, `-f`, `--key=value`).
- Estendere `terminal_command.gd` per consentire la definizione opzionale di pattern regex (`regex_pattern: String` o `regex: RegEx`) e il passaggio dei risultati del match (`RegExMatch`) al metodo `execute()`.
- Modificare `terminal_command_manager.gd` per eseguire il dispatch prioritario sul `call_name` esatto e, in alternativa, sui comandi registrati con pattern regex, estraendo i gruppi con nome e argomenti.
- Preservare la retrocompatibilità totale con i comandi esistenti (`ls`, `cd`, `cat`, `worm`, `decript`, `dataread`).

### ✓ Step 2: Implement Tab Autocomplete and UP/DOWN History Navigation
Aggiungere il completamento automatico intelligente con il tasto TAB e correggere la navigazione nella cronologia comandi.

- Creare un modulo dedicato `terminal_autocomplete.gd` per calcolare i suggerimenti su comandi disponibili e su file/cartelle (tramite `virtual_path_manager` e `TerminalDriveManager`).
- Implementare l'algoritmo di completamento su TAB: completamento automatico se univoco, calcolo del Longest Common Prefix (LCP) in caso di ambiguità parziale, e stampa formattata della lista di ambiguità nell'output del terminale senza cancellare l'input in corso.
- Intercettare `KEY_TAB` in `terminal_script.gd` (`_gui_input` della LineEdit) per prevenire lo switch di focus GUI predefinito di Godot (`accept_event()`).
- Riscrivere la logica in `terminal_input_history_manager.gd` e `terminal_script.gd` per gestire correttamente i tasti freccia SU e GIÙ (`KEY_UP`, `KEY_DOWN`, `ui_up`, `ui_down`), memorizzando la bozza digitata non ancora inviata e ripristinandola quando si scorre di nuovo verso il basso.
- Evitare duplicati consecutivi nella cronologia comandi e posizionare il cursore (caret) alla fine della riga dopo la navigazione.

### ✓ Step 3: Build Modular Terminal TUI Framework with Mouse Input
Progettare e realizzare un framework modulare per interfacce terminal-style (TUI) interattive con supporto al mouse (stile Junie).

- Creare la classe base `terminal_ui_widget.gd` che estende `Control` e definisce lo stile retro/diegetico (font monospazio Inconsolata, palette verde matrice/cyan, bordi ASCII/flat, stati hover e focus).
- Sviluppare componenti widget inline:
  - `terminal_ui_button.gd`: pulsanti cliccabili con mouse, stati hover/press e callback ad azioni terminale.
  - `terminal_ui_options.gd`: gruppi di opzioni a selezione singola o multipla (stile prompt Junie) con click del mouse o shortcut numeriche/letterali.
  - `terminal_ui_card.gd`: riquadri incorniciati per mostrare contenuti strutturati, tabelle o dettagli file.
- Sviluppare `terminal_ui_overlay.gd` in `terminal_scene.tscn` per ospitare viste TUI complesse a schermo intero (come visualizzatori interattivi o dashboard) mantenendo il supporto al mouse.
- Aggiornare `terminal_script.gd` con metodi helper (`push_widget_to_output()`, `open_tui_overlay()`, `close_tui_overlay()`) per consentire a qualunque comando presente o futuro di generare interfacce TUI.
- Dimostrare il framework integrando elementi cliccabili nel comando `ls` (cliccando su una cartella esegue `cd`, cliccando su un file esegue `cat`) e un comando demo/prompt interattivo.

### ✓ Step 4: Support Multiple Terminal Instances with Dynamic Titles
Permettere l'apertura e l'esecuzione simultanea di più istanze indipendenti del terminale.

- Introdurre un contatore di istanze e un generatore di ID univoci nel ciclo di vita di `terminal_script.gd`.
- Aggiornare dinamicamente il titolo della finestra contenitrice (`FakeWindow`) per distinguere le istanze aperte (es. `Terminale Shell UNIX #1 - ~/<path>`).
- Implementare il comando CLI `terminal` (`terminal_app_command.gd`) che invoca `TerminalSoftwareManager.launch_app("terminal")`, permettendo di aprire una nuova istanza direttamente da riga di comando o con argomenti opzionali (es. percorso iniziale).
- Verificare che ogni istanza mantenga il proprio stato isolato (`VirtualPathManager`, cronologia locale, overlay TUI e comandi attivi) senza interferenze tra finestre parallele.

### ✓ Step 5: Validate Regression Tests and Add New Unit Tests
Eseguire i test di regressione esistenti e aggiungere test specifici per regex, autocompletamento, cronologia e componenti TUI.

- Verificare che i test esistenti (`test_terminal_commands_worm_decript_dataread_node.gd`, `test_terminal_drive_node.gd`) continuino a passare senza errori.
- Creare un nuovo test GUT per verificare il riconoscimento regex dei comandi, il parsing di stringhe complesse e l'estrazione dei gruppi.
- Aggiungere test per il calcolo dell'autocompletamento (univoco vs lista di ambiguità) e la navigazione della cronologia con persistenza della bozza.
- Verificare la corretta instanziazione e gestione degli eventi mouse per i componenti del framework TUI.