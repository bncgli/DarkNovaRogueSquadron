# TASK: Sviluppo Modulo "Velocità di Crociera (Cruise Mode / Sub-FTL)" (`Outside/ShipSystems/CruiseDrive`)

## 1. Obiettivo e Panoramica
Sviluppare il sistema di propulsione e navigazione interplanetaria ad alta velocità **Cruise Mode (Velocità di Crociera sub-FTL)** per *Dark Nova: Rogue Squadron*.
La modalità consente alla corvetta di coprire grandi distanze tra settori amplificando esponenzialmente la spinta lineare con rotta vincolata, richiedendo una sequenza coordinata di warmup tra Pilota e Ingegnere e implementando il disingaggio forzato d'emergenza (Proximity Drop).

---

## 2. Standard Architetturali e Git
1. **Branch Git**: Creare ed eseguire il checkout sul branch `feature/CruiseDrive`.
2. **Posizione File**:
   - `Outside/ShipSystems/cruise_drive_controller.gd` (Logica di accelerazione, cooldown e warmup)
   - `Applications/FlightControl/Componenti/cruise_control_panel.tscn` e `.gd` (Widget UI in Flight Control)
   - `tests/test_cruise_drive.gd` (Suite di test headless)

---

## 3. Specifiche Tecniche e Flusso Operativo
1. **Procedura di Ingaggio (Warmup Sequenziale)**:
   - **Fase 1: Stato di Quiete**: Velocità relativa della nave < 5 m/s per almeno $N$ secondi.
   - **Fase 2: Allineamento Vettoriale**: Allineamento della prua verso il vettore di destinazione (tolleranza < 3°).
   - **Fase 3: Picco Energetico Reattore**: L'Ingegnere convoglia un picco di 160 MW via `PowerGrid` verso il sottosistema `cruise_coils`.
   - **Fase 4: Boost Esponenziale**: Attivazione spinta di crociera lineare con blocco del controllo RCS manuale.
2. **Sistemi di Sicurezza e Disingaggio d'Emergenza (Proximity Drop)**:
   - Sensori di prossimità intercettano masse critiche (asteroidi, stazioni, navi ostili).
   - Drop immediato a velocità ordinaria con surriscaldamento temporaneo dei propulsori e allarme in plancia.
3. **Integrazione UI**:
   - Barra di stato di carica in *Flight Control* e notifica coordinate in *Sensors*.

---

## 4. Configurazione `.DAT`
- **File**: `Ship Drive/Programs/FlightControls/thrusters_tuning.dat`
- **Parametri**: `cruise_multiplier=8.0`, `warmup_time_sec=4.0`, `proximity_drop_distance=250.0`, `heat_penalty=45.0`.

---

## 5. Criteri di Accettazione e Test Headless
Creare `tests/test_cruise_drive.gd` per verificare:
- Blocco dell'ingaggio se la nave è in movimento o disallineata.
- Requisito di potenza energetica da `PowerGrid`.
- Transizione corretta e moltiplicatore di velocità in Cruise Mode.
- Trigger del Proximity Drop in presenza di ostacoli lungo la traiettoria.
