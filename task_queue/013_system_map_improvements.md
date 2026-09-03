# TASK-025: System Map Zoom, Dynamic Route Plotting & Planetary Shadows

## Descrizione
Potenziamento dell'applicazione `SystemMap` (Mappa del Sistema Stellare) con estensione dei livelli di zoom, sequenza di calcolo asincrona della rotta con feedback diegetico e rendering 2D delle zone d'ombra proiettate dai corpi celesti.

## Obiettivi
- Aumentare la capacità di zoom sulla mappa 2D per consentire una visione ravvicinata dettagliata dei settori.
- Introdurre un tempo di elaborazione di 3-5 secondi per il calcolo della rotta di transito con messaggi di stato in tempo reale (es. scansione corpi neri, check traiettoria, calcolo perturbazioni).
- Visualizzare sulla griglia le zone d'ombra (coni di occultamento solare) generate dai pianeti e lune rispetto alla stella del sistema.

## Criteri di Accettazione
- [x] **Zoom Esteso**:
  - [x] Incremento del limite `MAX_ZOOM` da `2.5` a un valore di almeno `6.0` (o `8.0`).
  - [x] Supporto a ingrandimenti progressivi sia tramite pulsanti (`BtnZoomIn` / `BtnZoomOut`) che rotellina del mouse (`MOUSE_BUTTON_WHEEL_UP` / `DOWN`).
- [x] **Calcolo Rotta con Feedback Differito (3-5s)**:
  - [x] Alla pressione di "Calcola Rotta" (`BtnPlotRoute`), il calcolo non deve essere istantaneo ma richiedere un intervallo random o configurabile di 3-5 secondi.
  - [x] Durante il calcolo, i controlli di invio rotta sono temporaneamente disabilitati con indicatore di caricamento.
  - [x] Visualizzazione di messaggi di feedback sequenziali nell'header o nel box informativo:
    - *"Scansione emissioni corpi neri..."*
    - *"Analisi interferenze gravitazionali e traiettoria..."*
    - *"Calcolo vettore rotta e corridoio iperdrive..."*
    - *"Rotta calcolata con successo."*
- [x] **Visualizzazione Zone d'Ombra Planetarie**:
  - [x] Identificazione della posizione della stella centrale del sistema.
  - [x] Per ciascun pianeta, luna o gigante gassoso, proiezione del cono d'ombra opposto alla stella nel canvas di disegno (`_on_grid_display_draw`).
  - [x] Rappresentazione grafica delle zone d'ombra tramite poligoni semi-trasparenti sfumati (`draw_polygon` / `draw_colored_polygon`).

## Dettagli Tecnici
- **File coinvolti**:
  - `Applications/SystemMap/system_map_app.gd`:
    - Costante `MAX_ZOOM = 6.0` (linea 47).
    - Metodo `_on_plot_route_pressed()` (linee 286-293) convertito in sequenza asincrona con `Tween` o `get_tree().create_timer()`.
    - Metodo `_on_grid_display_draw()` (linee 440-576): calcolo vettoriale e rendering delle zone d'ombra.
  - `Applications/SystemMap/system_map_app.tscn`: Eventuale aggiunta di una barra di progresso calcolo o label di feedback superiore dedicata.

## Step by Step Implementation
1. **Estensione Livelli di Zoom in `Applications/SystemMap/system_map_app.gd`**:
   - Modificare la costante `MAX_ZOOM` a `6.0` (linea 47).
   - In `_on_grid_display_gui_input(event)`: Aggiungere il supporto allo zoom tramite rotellina del mouse (`MOUSE_BUTTON_WHEEL_UP` e `MOUSE_BUTTON_WHEEL_DOWN`) centrato sul cursore del mouse.
2. **Sequenza Asincrona di Calcolo Rotta in `Applications/SystemMap/system_map_app.gd`**:
   - Creare una variabile di stato `var is_plotting_route: bool = false`.
   - Modificare `_on_plot_route_pressed()`:
     - Impostare `is_plotting_route = true`.
     - Disabilitare i pulsanti `btn_plot_route` e `btn_send_route`.
     - Creare una sequenza asincrona con step di aggiornamento testo (durata totale ~3.5 - 4.5 secondi):
       - Step 1 (t=0.0s): `sector_info_text.text = "[color=#ffaa00]Scansione corpi neri e parametri gravitazionali...[/color]"`
       - Step 2 (t=1.2s): `sector_info_text.text = "[color=#ffaa00]Check traiettoria ed interferenze orbitali...[/color]"`
       - Step 3 (t=2.6s): `sector_info_text.text = "[color=#ffaa00]Calcolo vettore e corridoio iperdrive...[/color]"`
       - Step 4 (t=3.8s): Chiamare `_calculate_route_to_selected()`, riabilitare `btn_plot_route` e `btn_send_route`, `is_plotting_route = false`, e aggiornare i dettagli di rotta completata.
3. **Calcolo e Rendering Zone d'Ombra Planetarie in `Applications/SystemMap/system_map_app.gd`**:
   - Nella funzione `_on_grid_display_draw()`:
     - Individuare le coordinate a schermo della stella principale (`STAR`).
     - Per ciascun corpo celeste planetario (`PLANET`, `GAS_GIANT`, `MOON`):
       - Calcolare il vettore direzione dalla stella al pianeta `dir_from_star = (b_pos - star_pos).normalized()`.
       - Calcolare la normale perpendicolare `perp = Vector2(-dir_from_star.y, dir_from_star.x)`.
       - Definire i vertici del trapezio d'ombra proiettato dietro al pianeta (raggio iniziale = `icon_radius`, estensione posteriore fino a bordo settore o diversi raggi planetari).
       - Disegnare il cono d'ombra tramite `canvas.draw_polygon(shadow_points, [Color(0.0, 0.0, 0.0, 0.45)])`.
