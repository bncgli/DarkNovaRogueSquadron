# TASK-040: GodotOS Notification Queue Stacking & Hardware Peripheral Detection

## Descrizione
Ottimizzazione del sistema di notifiche e gestione periferiche di GodotOS. Risoluzione del problema del sovrapposizionamento simultaneo delle notifiche di sistema: le notifiche generate in rapida successione devono essere impilate verticalmente in modo ordinato senza coprirsi a vicenda. Integrazione dell'ascolto hardware delle periferiche: rilevamento automatico della connessione e disconnessione di dispositivi di input (gamepad, joystick, controller) con generazione di una notifica diegetica che specifica il nome e il tipo di periferica connessa.

## Obiettivi
- Ristrutturare il layout di `NotificationManager` per supportare un contenitore dinamico verticale (`VBoxContainer` con ancoraggio inferiore destro), garantendo che notifiche multiple generate nello stesso istante o in rapida sequenza vengano ordinate e separate nello spazio.
- Rimuovere l'animazione con coordinate $Y$ assolute hardcoded che causava la sovrapposizione visiva delle notifiche concorrenti.
- Implementare l'ascolto dei segnali di connessione periferiche di input del motore Godot (`Input.joy_connection_changed`).
- Generare notifiche diegetiche informative quando un controller o joystick viene collegato o scollegato (es. *"🎮 Controller Rilevato: Xbox Wireless Controller [Porta #0]"*).

## Criteri di Accettazione
- [ ] **Impilamento Verticale Ordinato delle Notifiche**:
  - [ ] Generando 5 notifiche consecutive in contemporanea, ciascuna notifica occupa uno slot separato senza coprire il testo delle altre.
- [ ] **Dissolvenza e Riordino Dinamico**:
  - [ ] Quando una notifica scade ed esegue il fade out / `queue_free()`, le altre notifiche nello stack scalano fluidamente verso il basso o verso la loro posizione ordinata.
- [ ] **Riconoscimento Connessione Gamepad/Controller**:
  - [ ] Al collegamento di un controller, compare una notifica verde con icona/tag `[CONTROLLER CONNESSO]` riportante il modello del dispositivo.
- [ ] **Riconoscimento Disconnessione Periferica**:
  - [ ] Alla disconnessione del controller, compare una notifica di avviso giallo/arancio con l'indice della porta disconnessa.

## Dettagli Tecnici
- **File coinvolti**:
  - `Scenes/Autoloads/Notification Manager/notification_manager.tscn`: Sostituzione con nodo `VBoxContainer` ancorato in basso a destra con `mouse_filter = MOUSE_FILTER_IGNORE`.
  - `Scenes/Autoloads/Notification Manager/notification_manager.gd`:
    - Connessione a `Input.joy_connection_changed`.
    - Metodo `_on_joy_connection_changed(device_id: int, connected: bool)`.
    - Gestione istanziazione notifiche all'interno del `VBoxContainer`.
  - `Scenes/Autoloads/Notification Manager/notification.tscn` & `notification.gd`:
    - Adattamento dimensioni e transizioni di fade-in/fade-out compatibili con il container.

## Step by Step Implementation
1. **Riorganizzazione Strutturale di `Scenes/Autoloads/Notification Manager/notification_manager.tscn`**:
   - Inserire un nodo `NotificationContainer (VBoxContainer)` figlio del singleton.
   - Configurare le ancore: `Anchor Right = 1.0`, `Anchor Bottom = 1.0`, `Offset Left = -350`, `Offset Top = -400`, `Offset Right = -15`, `Offset Bottom = -15`.
   - Impostare `alignment = BoxContainer.ALIGNMENT_END` e `grow_vertical = Control.GROW_VERTICAL_BEGIN`.
2. **Aggiornamento di `Scenes/Autoloads/Notification Manager/notification.gd`**:
   - Rimuovere la transizione hardcoded `tween.tween_property(self, "position:y", position.y - 75, 3)` dalle linee 17-21.
   - Sostituire con transizione di trasparenza e scala o slide orizzontale:
     ```gdscript
     modulate.a = 0.0
     var tween := create_tween()
     tween.tween_property(self, "modulate:a", 1.0, 0.25)
     await get_tree().create_timer(3.5).timeout
     var fade := create_tween()
     await fade.tween_property(self, "modulate:a", 0.0, 0.5).finished
     queue_free()
     ```
3. **Integrazione Rilevamento Periferiche in `Scenes/Autoloads/Notification Manager/notification_manager.gd`**:
   - Nel metodo `_ready()` o `_enter_tree()`:
     ```gdscript
     Input.joy_connection_changed.connect(_on_joy_connection_changed)
     ```
   - Implementare il callback:
     ```gdscript
     func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
         if connected:
             var joy_name := Input.get_joy_name(device_id)
             var msg := "[color=33ff88]🎮 Periferica Connessa: %s [Slot #%d][/color]" % [joy_name, device_id]
             spawn_notification(msg)
         else:
             var msg := "[color=ffaa33]⚠️ Periferica Scollegata: Slot #%d[/color]" % [device_id]
             spawn_notification(msg)
     ```
4. **Istanziamento Notifiche nel Container in `Scenes/Autoloads/Notification Manager/notification_manager.gd`**:
   - In `_spawn_notification_internal(text: String)`:
     - Istanziare la notifica e aggiungerla come figlia di `%NotificationContainer`.
     - Impostare il testo RichText con supporto BBCode.
