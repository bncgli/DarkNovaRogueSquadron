# TASK-033: LifeSupport Telemetry Expansion: Pressure, Temperature & Fire/Breach Dynamics

## Descrizione
Estensione del modello simulativo e telemetrico di `LifeSupportApp`. Oltre ai livelli di Ossigeno (O2) e allarmi incendio, l'applicazione deve monitorare la pressione barometrica (kPa) e la temperatura (°C) di ogni singolo compartimento della nave. Viene introdotta l'interazione diretta con le brecce strutturali (che causano decompressione immediata), con i cortocircuiti degli apparati elettrici (che possono disattivare la caldaia/riscaldamento di compartimento) e con gli incendi che provocano ustioni e decesso dell'equipaggio in caso di mancata estinzione o paratie non sigillate. Una stanza priva di pressione (vuoto spaziale) non trattiene calore e azzera automaticamente la temperatura verso lo zero.

## Obiettivi
- Monitorare costantemente per ogni compartimento: Livello O2 (%), Pressione atmosferica (kPa), Temperatura (°C) e Allarmi Incendio/Fumo/Breccia/Corto.
- Integrare gli effetti delle brecce strutturali: rapida perdita di pressione fino a 0 kPa.
- Implementare la legge fisica diegetica: una stanza decompressa (pressione = 0 kPa) dissipa istantaneamente il calore e fa crollare la temperatura a zero (0.0 °C / vuoto spaziale).
- Gestire i cortocircuiti dei dispositivi: un guasto elettrico nella stanza o nel generatore termico spegne la caldaia, portando a raffreddamento progressivo del compartimento.
- Simulare il pericolo termico degli incendi: temperature elevate (>350°C) e fumo tossico che infliggono danni letali all'equipaggio presente.

## Criteri di Accettazione
- [x] **Monitoraggio a 4 Parametri per Stanza**:
  - [x] La UI di ogni scheda stanza in `room_atmo_card.tscn` visualizza O2 (%), Pressione (kPa), Temperatura (°C) e Stato Caldaia/Termoregolazione.
- [x] **Dinamica Brecce e Decompressione**:
  - [x] Se in una stanza è presente una breccia (`has_breach == true` o danno strutturale da DuctDrone), la pressione scende a 0 kPa a una velocità proporzionale alla dimensione della falla.
- [x] **Azzeramento Temperatura nel Vuoto**:
  - [x] Non appena la pressione di una stanza scende sotto la soglia critica (es. < 1.0 kPa), la temperatura della stanza decade rapidamente e incondizionatamente verso 0.0 °C / zero assoluto, indipendentemente dal riscaldatore.
- [x] **Disattivazione Caldaia da Cortocircuito**:
  - [x] Se un dispositivo elettrico/cablaggio nella stanza va in corto circuito (`has_short_circuit == true`), l'impianto termico locale si spegne e la temperatura cala gradualmente verso la temperatura ambiente esterna.
- [x] **Incendi e Danni Termici Equipaggio**:
  - [x] La presenza di fuoco eleva la temperatura a picchi critici; se l'equipaggio/personaggio si trova nella stanza in fiamme o adiacente non sigillata, riceve danni continui da calore e asfissia comunicati a `PodInfo`.

## Dettagli Tecnici
- **File coinvolti**:
  - `Applications/LifeSupport/life_support_app.gd`:
    - Aggiornamento stato dizionario stanza `rooms_state[r_id]`: campi `pressure_kpa`, `temperature_c`, `o2_pct`, `co2_pct`, `is_fire_active`, `has_breach`, `has_short_circuit`, `heater_online`.
    - Metodo `_simulate_atmosphere_step(delta: float)`: implementazione formule fisiche per decadimento termico nel vuoto e spegnimento caldaia da guasti.
  - `Applications/LifeSupport/Components/room_atmo_card.tscn` & `room_atmo_card.gd`:
    - Layout a 4 barre/valori con codifica colore diegetica (Blu freddo/vuoto, Verde ottimale, Giallo allerta, Rosso fuoco/critico).
  - `Outside/space_world_manager.gd` & `Outside/Managers/ShipDamageManager.gd`:
    - Propagazione real-time dei danni da breccia, cortocircuito e fuoco tra i moduli di bordo.

## Step by Step Implementation
1. **Aggiornamento Struttura Dati Stanza in `Applications/LifeSupport/life_support_app.gd`**:
   - Nella funzione `_init_rooms_state()` (linee 267-284), assicurare per ogni stanza i seguenti campi predefiniti:
     ```gdscript
     "pressure_kpa": 101.3,
     "temperature_c": 21.5,
     "o2_pct": 21.0,
     "co2_pct": 0.04,
     "has_breach": false,
     "has_short_circuit": false,
     "heater_online": true,
     "is_fire_active": false,
     "is_sealed": false
     ```
2. **Modifica Simulazione Atmosferica in `_simulate_atmosphere_step(delta: float)` in `Applications/LifeSupport/life_support_app.gd`**:
   - Nelle linee 316-392:
     - Calcolo stato brecce e corti: interrogare i danni attivi da `SpaceWorldManager.get_damage_zones()`. Se il danno è di tipo `dmg_short` o `ELECTRICAL`, impostare `state["has_short_circuit"] = true`, altrimenti `false`.
     - Calcolo stato caldaia: `state["heater_online"] = not state["has_short_circuit"] and is_power_supplied_to_room(r_id)`.
     - **Regola Vuoto/Pressione**: Se `state["has_breach"]` o `state["is_venting"]`:
       - `state["pressure_kpa"] = move_toward(state["pressure_kpa"], 0.0, delta * 25.0)`
       - `state["o2_pct"] = move_toward(state["o2_pct"], 0.0, delta * 15.0)`
     - **Regola Temperatura nel Vuoto**: Se `state["pressure_kpa"] <= 1.0`:
       - `state["temperature_c"] = move_toward(state["temperature_c"], 0.0, delta * 30.0)` (nel vuoto non c'è mantenimento termico).
     - **Regola Riscaldamento Normale vs Caldaia Spenta**:
       - Se `state["pressure_kpa"] > 1.0` e non c'è fuoco:
         - Se `state["heater_online"]`: `state["temperature_c"] = move_toward(state["temperature_c"], 21.5, delta * 1.5)`
         - Se `not state["heater_online"]`: `state["temperature_c"] = move_toward(state["temperature_c"], 0.0, delta * 0.8)` (raffreddamento progressivo).
     - **Regola Incendio**: Se `state["is_fire_active"]`:
       - `state["temperature_c"] = move_toward(state["temperature_c"], 420.0, delta * 35.0)`
       - `state["o2_pct"] = move_toward(state["o2_pct"], 0.0, delta * 4.0)`
3. **Aggiornamento Widget Scheda Stanza in `room_atmo_card.gd`**:
   - Nel metodo `update_telemetry(data: Dictionary)`:
     - Aggiornare etichetta e barra della pressione: evidenziare in rosso se < 50.0 kPa (Decompressione).
     - Aggiornare etichetta e barra della temperatura: evidenziare in ciano freddo se < 10.0 °C, verde a 18-24 °C, rosso caldo se > 40.0 °C.
     - Mostrare badge allarme "🔥 INCENDIO", "⚡ CORTO CALDAIA", "🚨 BRECCIA" in base ai flag booleani.
4. **Propagazione Dati Fisiologici verso `PodInfoApp`**:
   - Esporre metodo pubblico in `LifeSupportApp`: `get_room_atmo_state(room_id: String) -> Dictionary` e segnale `atmosphere_anomaly_detected(room_id, anomaly_type)`.
