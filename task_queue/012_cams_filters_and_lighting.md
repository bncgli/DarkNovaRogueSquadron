# TASK-024: Cams Feed Filters, Headlights & Dynamic Skybox Fix

## Descrizione
Risoluzione del rendering dei corpi celesti nello skybox dinamico 3D e ristrutturazione completa dei filtri ottici delle telecamere esterne (`CameraFeedWindow`), limitandoli a Normale (con comando fari), Termico (con rilevamento scie termiche) e Lidar (con matrice di punti e profondità).

## Obiettivi
- Ripristinare la corretta visualizzazione e proiezione visiva dei macro-corpi celesti nello skybox 3D (`DynamicSpaceSkybox`).
- Ridurre e standardizzare i filtri video delle telecamere a tre modalità esclusive:
  1. **Normale**: Feed a colori naturali con pulsante dedicato per accendere/spegnere i fari esterni.
  2. **Termico**: Shader di post-processing che evidenzia gradienti termici e scie dei propulsori di navi ed entità.
  3. **Lidar**: Shader a scansione vettoriale/punti di contatto raycast che evidenzia geometrie e ostacoli.

## Criteri di Accettazione
- [x] **Skybox Dinamico & Corpi Celesti**:
  - [x] Gli impostori dei corpi celesti in `DynamicSpaceSkybox` devono essere renderizzati visivamente (tramite `MeshInstance3D` o `Sprite3D` con shader emissivi/billboard) e proiettati correttamente sulla sfera celeste a distanza diegetica.
  - [x] Il contenitore dello skybox segue la posizione della telecamera attiva nello spazio 3D senza clipping.
- [x] **Filtro Normale & Controllo Fari**:
  - [x] Modalità predefinita standard a colori.
  - [x] Aggiunta del pulsante "Fari: ON/OFF" (`BtnHeadlightsToggle`) nell'interfaccia HUD di `CameraFeedWindow`.
  - [x] Il pulsante pilota le sorgenti luminose esterne (`SpotLight3D`) montate in prossimità della telecamera o sulla prua/scafo dell'astronave.
- [x] **Filtro Termico**:
  - [x] Shader `thermal_filter.gdshader` applicato al canvas del feed.
  - [x] Rilevamento visivo ad alto contrasto per propulsori, motori a reazione, scie termiche e generatori caldi in tonalità termiche (nero-viola-arancio-bianco).
- [x] **Filtro Lidar**:
  - [x] Shader `lidar_filter.gdshader` che simula la scansione topografica (sweep beam, coordinate di profondità, pattern a reticolo di punti/mesh su superfici rilevate).
- [x] **Rimozione Filtri Obsoleti**:
  - [x] Eliminazione di tutti i filtri precedenti non conformi (es. Night Vision generico, HUD Cyan).

## Dettagli Tecnici
- **File coinvolti**:
  - `Outside/Skybox/dynamic_space_skybox.gd`: Correzione di `_create_celestial_impostor_node(info)` per istanziare mesh e materiali visibili anziché semplici `Marker3D` vuoti.
  - `Applications/Cams/CameraFeed/camera_feed_window.tscn`: Aggiunta pulsante fari nell'header/footer dei controlli feed e configurazione dei `ShaderMaterial` su `FilterColorRect`.
  - `Applications/Cams/CameraFeed/camera_feed_window.gd`:
    - Ristrutturazione di `_filter_mode` (0: Normale, 1: Termico, 2: Lidar).
    - Metodo `_on_headlights_toggled()`.
    - Metodo `_apply_filter_mode()`.
  - `Outside/Managers/CameraFeedManager.gd` o `Outside/space_world_manager.gd`: Supporto per l'attivazione dei fari telecamera.

## Step by Step Implementation
1. **Riparazione Impostori Corpi Celesti in `Outside/Skybox/dynamic_space_skybox.gd`**:
   - Nella funzione `_create_celestial_impostor_node(info: Dictionary)` (linee 147-154):
     - Sostituire l'istanza di `Marker3D` con un `MeshInstance3D` (es. `SphereMesh` o `QuadMesh` billboard).
     - Creare e assegnare uno `StandardMaterial3D` o `ShaderMaterial` con `shading_mode = SHADING_MODE_UNSHADED`, `albedo_color` impostato in base alla tipologia di corpo celeste (es. stella giallo/arancio brillante, gigante gassoso, pianeta roccioso) ed emissione attiva.
     - Impostare `position` su `info["projected_pos"]` e scalare opportunamente il nodo.
2. **Creazione Shader per Filtro Termico e Lidar**:
   - Creare `Applications/Cams/CameraFeed/Shaders/thermal.gdshader` con gradiente termico e campionamento dei canali luminosi.
   - Creare `Applications/Cams/CameraFeed/Shaders/lidar.gdshader` che sfrutta la `DEPTH_TEXTURE` del viewport e una griglia modulare a punti/linee di scansione raycast verde/ciano diegetico.
3. **Aggiornamento UI in `Applications/Cams/CameraFeed/camera_feed_window.tscn`**:
   - Inserire un nuovo `Button` `%BtnHeadlights` nella barra dei controlli della telecamera.
   - Aggiornare `FilterCycleBtn` per alternare ciclicamente solo le tre modalità: "Normale", "Termico", "Lidar".
4. **Logica Filtri e Fari in `Applications/Cams/CameraFeed/camera_feed_window.gd`**:
   - Modificare `_filter_mode`:
     - `0`: Normale -> `filter_rect.visible = false`.
     - `1`: Termico -> `filter_rect.visible = true`, assegna lo shader termico.
     - `2`: Lidar -> `filter_rect.visible = true`, assegna lo shader lidar.
   - Connettere `%BtnHeadlights.pressed` alla funzione `_on_headlights_toggled()`:
     - Inviare la richiesta a `SpaceWorldManager` / `CameraFeedManager` per attivare o spegnere lo spot luminoso associato alla telecamera `camera_id`.
     - Aggiornare l'aspetto visivo del pulsante fari (stato attivo/inattivo).
