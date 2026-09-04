# TASK-035: Sensors Radar Realism: Obstacle Shadows, 1km Sweep, Probe Feeds & Energy-Gated Ping

## Descrizione
Ricalibrazione realistica e diegetica dell'applicazione `SensorsApp`. Lo scanner primario della nave passa da una portata irreale di 50 km a un raggio operativo ravvicinato di 1 km. Viene introdotto il sistema di ombreggiamento degli ostacoli fisici (Line of Sight): corpi densi e asteroidi proiettano zone d'ombra retrostanti che nascondono i contatti al radar. Lo scanner opera come un radar diegetico puro (visualizza la presenza di echi fisici senza classificazione automatica magica). Vengono rimossi gli elenchi a tendina con i bersagli per favorire l'interazione diretta a schermo. Il lancio di una sonda telemetrica (Probe) estende la copertura proiettando il feed radar secondario della sonda direttamente sul display. L'impulso Ping attivo (portata 2 km) richiede e consuma energia reale dalla rete di bordo.

## Obiettivi
- Ridurre la portata massima della scansione radar standard della nave a 1 km (1000 metri).
- Implementare l'algoritmo di occlusione/ombra da ostacoli (Line of Sight 2D/3D): corpi celesti e asteroidi oscurano gli oggetti posizionati dietro di essi rispetto all'emettitore.
- Rimuovere la classificazione istantanea magica dei contatti: il radar restituisce blip ed echi di massa anonimi.
- Rimuovere le liste a tendina dei bersagli (`%TargetOption` / `%OptionFilter`) dall'interfaccia, puntando sull'interazione tattica sul display.
- Integrare il feed radar della sonda telemetrica lanciata nello spazio: visualizzare l'area scansionata dalla sonda sul display della mappa tattica.
- Limitare l'impulso Ping attivo (fino a 2 km) al soddisfacimento del fabbisogno energetico di bordo (`PowerGrid`).

## Criteri di Accettazione
- [ ] **Portata Radar 1 KM**:
  - [ ] Il raggio di scansione passivo e standard è calibrato a 1000.0 m (1 km).
- [ ] **Ombre Radar e Occlusione Ostacoli**:
  - [ ] Gli asteroidi e le strutture massive intermedie bloccano la linea di vista; qualsiasi entità posizionata nel cono d'ombra dietro l'ostacolo non viene disegnata sul radar.
- [ ] **Radar Puro Senza Metadati Cheat**:
  - [ ] I contatti appaiono come blip generici senza rivelare identità o fazione pregressa finché non vengono analizzati da vicino o da una sonda.
- [ ] **Rimozione Dropdown Bersagli**:
  - [ ] I menu a tendina `%TargetOption` e le etichette di spettrometria non diegetiche sono rimosse dalla UI.
- [ ] **Visualizzazione Radar Sonda (Probe)**:
  - [ ] Al rilascio di una Probe, sul radar compare un cerchio di scansione secondario attorno alla posizione della sonda, rivelando contatti nascosti o distanti.
- [ ] **Ping a 2 KM Vincolato all'Energia**:
  - [ ] L'impulso Ping raggiunge 2000m ma può essere emesso solo se c'è energia sufficiente nel condensatore/rete. In caso contrario il comando fallisce con allarme sonoro/visivo.

## Dettagli Tecnici
- **File coinvolti**:
  - `Applications/Sensors/sensors_app.tscn`: Rimozione dropdown a tendina, aggiornamento controlli portata e indicatore feed sonda.
  - `Applications/Sensors/sensors_app.gd`:
    - Costante portata: `const MAX_STANDARD_RANGE: float = 1000.0`, `const ACTIVE_PING_RANGE: float = 2000.0`.
    - Metodo `_refresh_entities()`: filtraggio contatti tramite calcolo raggio di occlusione/intersezione con gli asteroidi.
    - Metodo `_on_active_ping_pressed()`: verifica `PowerGridManager.has_available_power(ACTIVE_PING_POWER_MW)` prima dell'emissione.
  - `Applications/Sensors/Components/radar_display.gd`:
    - Disegno dei coni d'ombra degli asteroidi e rendering del campo visivo concentrico della sonda (Probe).
  - `Outside/space_world_manager.gd`: Registrazione e sincronizzazione stato delle sonde telemetriche in volo.

## Step by Step Implementation
1. **Pulizia Layout UI in `Applications/Sensors/sensors_app.tscn`**:
   - Rimuovere il nodo `%TargetOption` e il pannello delle informazioni spettrometriche testuali non diegetiche.
   - Sostituire `%OptionRange` con indicatore fisso o pulsanti rapidi (1 KM Standard / 2 KM Ping).
2. **Aggiornamento Portata e Parametri in `Applications/Sensors/sensors_app.gd`**:
   - Nelle costanti e in `_ready()`:
     ```gdscript
     const RADAR_STANDARD_RANGE: float = 1000.0 # 1 km
     const PING_MAX_RANGE: float = 2000.0 # 2 km
     ```
   - In `_init_ui_elements()`: impostare la scala del `radar_display.max_range = RADAR_STANDARD_RANGE`.
3. **Algoritmo Line of Sight & Ombra Ostacoli in `Applications/Sensors/sensors_app.gd`**:
   - In `_refresh_entities()`:
     - Ottenere tutti gli asteroidi e ostacoli solidi dall'ambiente.
     - Per ciascun contatto rilevato:
       - Eseguire test di occlusione vettoriale: calcolare il segmento tra la posizione della nave e la posizione del contatto.
       - Se il segmento interseca il cerchio/sfera di ingombro di un asteroide intermedio, marcare il contatto come `is_occluded = true`.
       - Escludere i contatti occlusi dalla lista visibile sul display primario della nave.
4. **Integrazione Feed Radar Probe in `Applications/Sensors/sensors_app.gd` & `radar_display.gd`**:
   - In `_process(delta)`:
     - Verificare se esiste una sonda attiva lanciata da Weapons: `var probe = SpaceWorldManager.get_active_probe()`.
     - Se presente, passare la posizione relativa della sonda e il suo raggio di scansione (1000m) a `radar_display.probe_data`.
     - I contatti all'interno del raggio della sonda vengono rivelati anche se si trovano in zone d'ombra rispetto alla nave madre.
5. **Verifica Energetica per Ping 2 KM in `Applications/Sensors/sensors_app.gd`**:
   - Nella funzione `_on_btn_active_ping_pressed()`:
     - Verificare la potenza disponibile: `var has_power = SpaceWorldManager.can_consume_power(ACTIVE_PING_POWER_MW)`.
     - Se `not has_power`: emettere notifica/allarme "⚠️ ENERGIA INSUFFICIENTE PER IMPULSO PING (RICHIESTI 120 MW)" e interrompere.
     - Se autorizzato: consumare energia, avviare animazione ping fino a 2000m e rivelare temporaneamente la topologia dell'area.
