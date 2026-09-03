# TASK-022: GodotOS Window Management & Z-Order Fixes

## Descrizione
Risoluzione di problematiche relative alla gestione del rendering, focus e trasparenza delle finestre diegetiche del sistema operativo GodotOS (`FakeWindow`).

## Obiettivi
- Evitare che la barra del titolo delle finestre sottostanti rimanga visibile sopra le finestre in primo piano.
- Consentire la messa a fuoco (foreground/focus) delle finestre cliccando su qualsiasi punto della loro superficie (inclusi i contenuti interni).
- Eliminare l'effetto di semi-trasparenza applicato alle finestre quando perdono il focus (background).

## Criteri di Accettazione
- [x] **Fix Z-Order Titoli**: La barra del titolo (`Top Bar`) e il testo del titolo (`Title Text`) non devono mai scavalcare il rendering di finestre posizionate a un livello z superiore o successivo nell'albero dei nodi.
- [x] **Selezione Finestra su Intera Superficie**: Cliccando (click sinistro o destro) in un punto qualsiasi della finestra o dei suoi container interni (non solo sulla `Top Bar`), la finestra passa immediatamente in primo piano (`select_window(true)`), riordinando l'albero dei nodi.
- [x] **Opacità Finestre in Background**: Quando una finestra passa in secondo piano (`deselect_window()`), la sua trasparenza (`modulate.a`) deve rimanere opaca al 100% (`1.0`) invece di scendere a `0.75`.

## Dettagli Tecnici
- **File coinvolti**:
  - `Scenes/Window/Window.tscn`: La `Top Bar` presenta attualmente una proprietà `z_index = 2` che forza il motore 2D di Godot a renderizzare la barra sopra tutte le finestre con z_index 0 o 1, ignorando l'ordine dell'albero dei nodi.
  - `Scenes/Window/window.gd`:
    - Metodo `deselect_window()` (linee ~302-315): Contiene un tween che abbassa `modulate:a` a `0.75`.
    - Metodo `select_window()` (linee ~280-301): Contiene tween di ripristino opacità.
    - Metodo `_gui_input(event)` (linee ~66-69): Intercetta gli eventi mouse solo se il nodo `Window` riceve l'input, ma i nodi figli (come `ApplicationContents` o widget UI) consumano l'input mouse se `mouse_filter` è `STOP`. È opportuno gestire l'evento a livello di `_input` o intercettare l'interazione per chiamare `select_window(true)` quando il click avviene all'interno del rettangolo globale della finestra non ancora selezionata.

## Step by Step Implementation
1. **Correzione Z-Index in `Scenes/Window/Window.tscn`**:
   - Aprire `Scenes/Window/Window.tscn`.
   - Nel nodo `Top Bar` (linea 59-60), rimuovere la proprietà `z_index = 2` (o impostarla a `0`), in modo che il canvas item rispetti il naturale z-index della finestra genitore e l'ordinamento gerarchico dei figli del desktop (`move_child`).
2. **Rimozione Semi-trasparenza in `Scenes/Window/window.gd`**:
   - Nel metodo `deselect_window()` (linee 309-315):
     - Rimuovere o commentare la riga `tween.tween_property(self, "modulate:a", 0.75, 0.25)`.
     - Mantenere le transizioni del testo del titolo (`modulate` a `Color.WHITE`) e del `shadow_size` a `0`.
   - Nel metodo `select_window()` (linee 293-295):
     - Rimuovere la logica che porta `modulate:a` a `1.0` se non necessaria, garantendo che l'opacità rimanga invariata.
3. **Gestione Focus Cliccando su Tutta la Superficie in `Scenes/Window/window.gd`**:
   - Modificare la gestione degli input per intercettare i click anche quando avvengono sui nodi figli:
     - Implementare/estendere `_input(event: InputEvent)` o `_unhandled_input(event: InputEvent)` in `Scenes/Window/window.gd`.
     - Se `event` è `InputEventMouseButton`, `event.is_pressed()` con `button_index` 1 o 2:
       - Verificare se `!is_external` e `!is_selected` e `!is_minimized` e `visible`.
       - Controllare se `get_global_rect().has_point(event.global_position)`.
       - Se il click cade all'interno del rettangolo della finestra, verificare se non ci sono finestre figlie con indice gerarchico superiore che contengono lo stesso punto. In alternativa, gestire l'evento chiamando `select_window(true)` per portare la finestra in foreground.
