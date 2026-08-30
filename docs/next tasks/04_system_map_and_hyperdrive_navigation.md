# TASK: Applicazione System Map e Integrazione Rotte Hyperdrive con Flight Control

## 1. Obiettivo e Panoramica
Sviluppare l'applicazione diegetica **"System Map"** (`Applications/SystemMap`) e integrarla con il sistema di navigazione di **Flight Control** (`Applications/FlightControl`):
1. Fornire una mappa olografica/schematica 2D-3D dell'intero sistema stellare suddiviso in sezioni/settori di griglia.
2. Consentire all'equipaggio (Pilota, Capitano, Hacker) di tracciare rotte di navigazione e calcolare traiettorie di viaggio intersettoriale.
3. Trasmettere il vettore di navigazione calcolato all'applicazione **Flight Control**, permettendo al Pilota di agganciare il vettore e attivare la modalità **Hyperdrive / Velocità di Crociera** per il transito verso il settore di destinazione.

---

## 2. Riferimenti al Documento di Design (DARK_NOVA_FEATURES_DESIGN.md)
- **Sezione 2 (Diagramma Flusso Utente - Fase 5a)**: *5a. System Map & Hyperdrive*.
- **Sezione 2.4 (Fase 4 - Pianificazione Rotta e Hyperdrive - Fase 5a)**:
  > - **Pianificazione Rotta e Hyperdrive**: I giocatori possono utilizzare l'applicazione **"System Map"** per consultare la griglia del sistema e progettare la traiettoria di viaggio dell'**Hyperdrive** tra le sezioni/settori.
  > - Una volta calcolata e impostata la rotta sulla System Map, l'applicazione **Flight Control** del Pilota aggancia il vettore e avvia l'**Hyperdrive** per eseguire il transito verso la destinazione.

---

## 3. Specifiche Tecniche e Funzionali

### 3.1 Applicazione System Map (`Applications/SystemMap`)
1. **Interfaccia Grafica (`system_map_app.tscn`, `720x520`)**:
   - Vista a griglia 2D interattiva dei settori con pan, zoom e visualizzazione delle coordinate (`SEC-XX-YY`).
   - Icone per stella primaria, pianeti, stazioni spaziali, campi di asteroidi e relitti noti.
   - Posizione attuale della nave evidenziata con vettore di prua.
2. **Strumento di Tracciamento Rotte**:
   - Selezione del settore di destinazione tramite click/tap sulla griglia.
   - Calcolo automatico di: distanza in settori, tempo stimato di transito (ETA), consumo energetico/carburante stimato.
   - Pulsante **"Invia Rotta a Flight Control"**: emette il segnale globale / di sistema `route_plotted(target_sector_coords, course_vector)`.

### 3.2 Integrazione con Flight Control (`Applications/FlightControl`)
1. **Aggancio Vettore (Vector Lock)**:
   - All'interno di *Flight Control*, se è presente una rotta calcolata dalla System Map, si attiva l'indicatore di allineamento prua e il pulsante **"Allinea a Vettore Hyperdrive"**.
2. **Attivazione Hyperdrive / Cruise Drive**:
   - Una volta allineata la nave e soddisfatte le condizioni di quiete/energia, il Pilota attiva l'ingaggio Hyperdrive.
   - Avvio della transizione e propagazione a `SpaceWorldManager` per il transito al settore target.

---

## 4. Standard Architetturali e Flusso Git
1. **Branch Git**:
   - `git checkout -b applications/SystemMap main`
2. **File Coinvolti**:
   - `Applications/SystemMap/system_map_app.tscn`
   - `Applications/SystemMap/system_map_app.gd`
   - `Applications/SystemMap/system_map_app.tres`
   - `Applications/FlightControl/flight_control_app.gd`
   - `Outside/StarSystemGrid/star_system_grid_manager.gd`
   - `tests/test_system_map_hyperdrive.gd`

---

## 5. Criteri di Accettazione e Test Headless
1. **Suite di Test (`tests/test_system_map_hyperdrive.gd`)**:
   - Verifica caricamento griglia e settori da `StarSystemData` su System Map.
   - Verifica calcolo rotta e invio segnale di rotta verso Flight Control.
   - Verifica aggancio vettore in Flight Control e transizione di settore con Hyperdrive.
2. **Chiusura Git**:
   - [ ] Test headless superati con successo.
   - [ ] Commit con messaggio: `feat(nav): implement System Map app and Hyperdrive trajectory locking in Flight Control`.
   - [ ] Merge su `main`.
