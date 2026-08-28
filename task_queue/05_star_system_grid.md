# TASK: Sviluppo Modulo "Architettura del Sistema Stellare e Griglia Spaziale" (`Outside/StarSystemGrid`)

## 1. Obiettivo e Panoramica
Sviluppare il sistema logico e grafico di **Griglia Spaziale a Settori** per *Dark Nova: Rogue Squadron*.
L'intero sistema stellare è strutturato in una griglia 3D/2D discreta di coordinate di settore (es. `SEC-04-12`), dove ogni cella contiene macro-entità (corpi celesti, campi di asteroidi, stazioni, relitti, pattuglie). Il modulo gestisce l'illuminazione dinamica della stella primaria, coni d'ombra planetari, rendering skybox diegetico scalare e distanze in assenza di motori FTL.

---

## 2. Standard Architetturali e Flusso Git
1. **Flusso Git (Obbligatorio)**:
   - Creare ed eseguire il checkout sul branch dedicato partendo da `main`: `git checkout -b feature/StarSystemGrid main`.
   - Sviluppare il codice, risorse e test esclusivamente all'interno di tale branch.
   - Al termine dello sviluppo e dopo aver validato con successo i test:
     1. Eseguire il commit di tutte le modifiche: `git add .` e `git commit -m "feat(grid): implementa griglia spaziale a settori e skybox diegetico"`.
     2. Passare al branch `main`: `git checkout main`.
     3. Eseguire il merge del branch completato: `git merge feature/StarSystemGrid`.
2. **Posizione File**:
   - `Outside/StarSystemGrid/star_system_grid_manager.gd` (Autoload / Manager di settore)
   - `Outside/StarSystemGrid/sector_data.gd` (Risorsa dati settore)
   - `Outside/Skybox/dynamic_space_skybox.gd` (Gestore proiezione skybox e illuminazione stellare)
   - `tests/test_star_system_grid.gd` (Suite di test headless)

---

## 3. Specifiche Tecniche e Funzionali
1. **Modello a Griglia e Coordinate**:
   - Rappresentazione a coordinate discrete indicizzate (`sector_x`, `sector_y`, `sector_z` o formato `SEC-XX-YY`).
   - Caricamento dinamico / generazione procedurale dei contenuti del settore corrente in `SpaceWorldManager`.
2. **Illuminazione Dinamica & Occlusione Planetaria**:
   - Vettore di illuminazione direzionale calcolato dalla stella primaria rispetto al settore corrente.
   - Calcolo delle zone d'ombra/eclissi dietro pianeti massicci (riduzione visibilità e blackout pannelli solari).
3. **Distanze di Render e Skybox Diegetico**:
   - Raggio scalare di proiezione sullo skybox:
     - Stella Primaria: visibile fino a 30+ caselle.
     - Giganti Gassosi / Pianeti: visibili entro 10-15 caselle.
     - Stazioni / Fasce Asteroidi: visibili entro 2-4 caselle prima dell'ingresso nel settore.
4. **Vincolo No-FTL**:
   - Il mondo di gioco è interamente contenuto all'interno di un singolo sistema stellare denso senza viaggi istantanei FTL.

---

## 4. Integrazione con i Sottosistemi Esistenti
- `SpaceWorldManager`: Caricamento macro-entità del settore attivo.
- `Sensors` & `FlightControl`: Calcolo vettori di rotta e distanze cinematiche tra settori.

---

## 5. Criteri di Accettazione, Test e Chiusura Task
1. **Suite di Test Headless**: Creare ed eseguire `tests/test_star_system_grid.gd` per verificare:
   - Calcolo corretto delle coordinate di settore e transizioni tra caselle adiacenti.
   - Calcolo dell'occlusione e coni d'ombra planetari.
   - Visibilità scalare delle entità sullo skybox in base alla distanza di griglia.
2. **Chiusura Git**:
   - [ ] Test headless superati con esito positivo.
   - [ ] Commit di tutte le modifiche su branch `feature/StarSystemGrid`.
   - [ ] Checkout su `main` e merge completato del branch.
