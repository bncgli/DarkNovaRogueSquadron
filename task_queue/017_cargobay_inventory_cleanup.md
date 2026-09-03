# TASK-029: CargoBay Application Simplification & Inventory Cleanup

## Descrizione
Semplificazione radicale dell'applicazione `CargoBay`, rimuovendo tutte le funzionalità accessorie (trasferimenti logistici, rating/canoni FLUX e violazione ICE Snapshot S-Net) per trasformarla in una vista di inventario stiva pura, pulita ed efficiente.

## Obiettivi
- Rimuovere le schede e funzionalità superflue:
  - Tab Trasferimenti (logistica carichi nave/drone/stazione).
  - Tab Rating FLUX & Canoni (credit score, debiti, abbonamenti).
  - Tab Array Snapshot S-Net & ICE Hack (violazione e analisi dischi cifrati).
- Riorganizzare l'interfaccia come inventario stiva a schermo singolo (lista oggetti, dettagli elemento, barre di carico massa/volume ed espulsione carico).

## Criteri di Accettazione
- [x] **Interfaccia Inventario Pura**:
  - [x] Eliminazione del `TabContainer` o mantenimento esclusivo della vista inventario stiva.
  - [x] Visualizzazione chiara degli oggetti immagazzinati nella stiva (`ItemList` / griglia).
  - [x] Visualizzazione di massa totale occupata rispetto alla capacità (`MassProgressBar`), volume (`VolProgressBar`) e numero di slot.
  - [x] Riquadro dettagli dell'oggetto selezionato (nome, tipo, quantità, peso unitario/totale, descrizione).
  - [x] Funzionalità di espulsione carico ("Espelli Stiva" / `BtnJettison`).
- [x] **Pulizia Codice & Logica**:
  - [x] Rimozione di tutti i listener, riferimenti UI, metodi e variabili collegati a S-Net hack, canoni FLUX e sottomenu di trasferimento merci da `cargo_bay_app.gd`.

## Dettagli Tecnici
- **File coinvolti**:
  - `Applications/CargoBay/cargo_bay_app.tscn`: Rimozione delle schede 2 (Trasferimenti), 3 (Rating FLUX), 4 (S-Net ICE Hack) e semplificazione del layout a schermata singola.
  - `Applications/CargoBay/cargo_bay_app.gd`: Rimozione metodi `_setup_transfer_tab`, `_setup_flux_tab`, `_setup_snet_tab`, `_on_hack_ice_pressed`, `_on_pay_sub_pressed` e snellimento su `CargoManagerSingleton`.

## Step by Step Implementation
1. **Ristrutturazione UI in `Applications/CargoBay/cargo_bay_app.tscn`**:
   - Aprire la scena `cargo_bay_app.tscn`.
   - Rimuovere i nodi del `TabContainer`:
     - Tab `Trasferimenti` (e figli: `%TargetOptionBtn`, `%DirectionOptionBtn`, `%TransferItemList`, `%TransferSpinbox`, `%BtnExecuteTransfer`).
     - Tab `Rating FLUX & Canoni` (e figli: `%FluxScoreBar`, `%SubscriptionsItemList`, `%BtnPaySub`, `%BtnPayAllDebt`).
     - Tab `Array Snapshot S-Net & ICE Hack` (e figli: `%SnetDiskList`, `%BtnHackIce`, `%IntelOutputBox`).
   - Mantenere e centrare la vista Inventario (`%MassProgressBar`, `%VolProgressBar`, `%CargoItemList`, `%ItemDetailsLabel`, `%BtnJettison`).
2. **Pulizia Codice in `Applications/CargoBay/cargo_bay_app.gd`**:
   - Rimuovere gli `@onready` relativi ai nodi eliminati (linee ~29-54).
   - Rimuovere le variabili di stato legate a hacking e sottoscrizioni (linee ~57-62).
   - In `_ready()` e `_refresh_all_views()`: mantenere unicamente `_refresh_cargo_inventory()` e i controlli di connessione stiva.
   - Eliminare tutte le funzioni non pertinenti:
     - Logica hacking ICE (`_on_hack_ice_pressed`, ecc.).
     - Logica pagamento debiti e rating FLUX (`_on_pay_sub_pressed`, `_on_pay_all_debt_pressed`, ecc.).
     - Logica trasferimenti cargo (`_on_execute_transfer_pressed`, ecc.).
   - Mantenere la logica diegetica di selezione oggetto (`_on_cargo_item_selected`) e di scarico/espulsione stiva (`_on_jettison_pressed`).
