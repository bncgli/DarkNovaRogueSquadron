# TASK-038: Terminal Commands Suite: 'worm', 'decript' & 'dataread'

## Descrizione
Estensione delle capacità operative dell'applicazione `Terminal` con l'introduzione di tre nuovi comandi da riga di comando per l'hacking diegetico e la manipolazione dei file protetti: `worm <nome_cartella>` (minigioco logico stile Mastermind per indovinare la password della cartella), `decript <file.dat>` (minigioco interattivo di sostituzione cifraria basato sulla frase testuale diegetica "the quick brown fox jumps over the lazy dog" per rivelare la chiave crittografica del file), e `dataread <file.dat>` (lettore e visualizzatore per aprire, consultare e modificare i file di configurazione binari/protetti `.dat` nell'Editor di Testo).

## Obiettivi
- Creare il comando `worm <cartella>`: avvia un minigioco stile Mastermind nel terminale, dove il giocatore formula tentativi per indovinare la sequenza di caratteri della password della cartella specificata, ricevendo indizi sul numero di caratteri esatti e posizionati correttamente.
- Creare il comando `decript <file.dat>`: cifra la frase standard *"the quick brown fox jumps over the lazy dog"* con la chiave di decriptazione (`decryption_key`) del file `.dat`; consentire al giocatore di immettere tentativi di caratteri della chiave, svelando progressivamente il testo in chiaro fino alla decodifica completa.
- Creare il comando `dataread <file.dat>`: apre il file `.dat` specificato direttamente nell'applicazione `Text Editor` di GodotOS, bypassando la schermata di blocco per i file protetti e consentendo la modifica diegetica dei parametri di configurazione.

## Criteri di Accettazione
- [x] **Comando Terminale `worm`**:
  - [x] Sintassi: `worm <nome_cartella>` (o percorso relativo).
  - [x] Recupera la password reale protetta da `FolderPasswordManager`.
  - [x] Gestisce turni di tentativi interattivi mostrando feedback visivo diegetico (es. `[MATCH: 2 ESATTI, 1 FUORI POSTO]`).
  - [x] Al completamento con successo, la password della cartella viene sbloccata/rivelata.
- [x] **Comando Terminale `decript`**:
  - [x] Sintassi: `decript <file.dat>`.
  - [x] Visualizza la frase *"the quick brown fox jumps over the lazy dog"* criptata con la chiave del file.
  - [x] Inserendo i caratteri corretti della chiave, la stringa si decifra progressivamente a schermo fino alla soluzione.
- [x] **Comando Terminale `dataread`**:
  - [x] Sintassi: `dataread <chiave> <file.dat>`.
  - [x] Verifica l'esistenza del file `.dat` e lo apre nel `Text Editor` con permessi di visualizzazione e scrittura abilitati.

## Dettagli Tecnici
- **File coinvolti**:
  - `Applications/Terminal/commands/worm_command.gd`: Nuovo script che estende `TerminalCommand`.
  - `Applications/Terminal/commands/decript_command.gd`: Nuovo script che estende `TerminalCommand`.
  - `Applications/Terminal/commands/dataread_command.gd`: Nuovo script che estende `TerminalCommand`.
  - `Applications/Terminal/src/terminal_script.gd`: Supporto per stati interattivi multi-step da riga di comando (comandi con input in loop continuo come `worm` e `decript`).
  - `Scenes/Window/Text Editor/text_editor.gd`: Metodo `open_dat_file(path: String)` per consentire la lettura autorizzata da `dataread`.
  - `Scenes/Autoloads/FolderPasswordManager/folder_password_manager.gd`: Metodi di consultazione e validazione per `worm`.

## Step by Step Implementation
1. **Implementazione di `Applications/Terminal/commands/worm_command.gd`**:
   - Creare la classe derivata da `TerminalCommand`:
     ```gdscript
     extends TerminalCommand
     func _init() -> void: call_name = "worm"
     ```
   - In `execute(terminal: Terminal, args: Array[String])`:
     - Validare gli argomenti: `args.size() == 1` (nome della cartella).
     - Recuperare la password della cartella da `FolderPasswordManager.get_password(target_folder)`.
     - Inizializzare la sessione Mastermind: memorizzare la lunghezza della password, i tentativi rimasti (es. 6) e passare il controllo a una modalità di input interattivo su `terminal`.
     - Ad ogni tentativo dell'utente:
       - Calcolare quanti caratteri coincidono nella posizione esatta (`bulls`) e quanti sono presenti ma in posizione errata (`cows`).
       - Stampare: `TENTATIVO [N/6]: "%s" -> ESATTI: %d | DISLOCATI: %d`
       - Se la password è indovinata: stampare `[ACCESSO CONFERMATO] Password cartella violata con successo: %s` e sbloccare la cartella.
2. **Implementazione di `Applications/Terminal/commands/decript_command.gd`**:
   - Creare la classe derivata da `TerminalCommand`:
     ```gdscript
     extends TerminalCommand
     func _init() -> void: call_name = "decript"
     ```
   - In `execute(terminal: Terminal, args: Array[String])`:
     - Validare che il file esista e termini per `.dat`.
     - Leggere `decryption_key` dal file `.dat` (es. tramite `BaseApp._parse_dat_file`).
     - Creare la mappatura di cifratura monoalfabetica applicata alla frase *"the quick brown fox jumps over the lazy dog"*.
     - Mostrare il testo oscurato (es. `xli uymgo fvsar jsb nyqtw sziv xli pedc hsk`).
     - Ad ogni carattere di chiave indovinato dal giocatore, sostituire i glifi cifrati con le lettere in chiaro corrispondenti.
     - Quando l'intera chiave è scoperta, stampare `[CHIAVE DECRIPTAZIONE IDENTIFICATA: %s]` e salvarla nel drive/log.
3. **Implementazione di `Applications/Terminal/commands/dataread_command.gd`**:
   - Creare la classe derivata da `TerminalCommand`:
     ```gdscript
     extends TerminalCommand
     func _init() -> void: call_name = "dataread"
     ```
   - In `execute(terminal: Terminal, args: Array[String])`:
     - Validare l'argomento `args[0]` verificando sia la chiave di decriptazione del file dat all'argomento 1.
     - Validare l'argomento `args[1]` verificando che termini con `.dat`.
     - Risolvere il path assoluto tramite `terminal.virtual_path_manager.get_path()`.
     - Inviare l'evento al desktop o istanziare la finestra `Text Editor` invocando `text_editor.open_dat_file(full_path)`.
     - Notificare a video: `Apertura file protetto '%s' nel lettore di sistema...`
4. **Adattamento `Scenes/Window/Text Editor/text_editor.gd`**:
   - Aggiungere variabile `var allow_dat_editing: bool = false`.
   - Modificare `populate_text(path: String)`:
     - Se `path.ends_with(".dat")`:
       - Se `allow_dat_editing`: leggere il contenuto grezzo testuale/chiavi-valori e permettere l'editing/salvataggio standard (`editable = true`).
       - Altrimenti: mantenere il blocco con messaggio di errore informativo che suggerisce l'uso del comando `dataread`.
5. **Supporto Sessioni Interattive in `Applications/Terminal/src/terminal_script.gd`**:
   - Aggiungere `var active_interactive_command: TerminalCommand = null` per reindirizzare le righe digitate dall'utente direttamente al comando in esecuzione senza interpretarle come nuovi comandi shell.
