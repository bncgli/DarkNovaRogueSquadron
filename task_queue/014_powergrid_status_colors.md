# TASK-026: PowerGrid Status Colors for Producing and Consuming Rooms

## Descrizione
Standardizzazione cromatica e diegetica degli indicatori di potenza nell'applicazione `PowerGrid`, evidenziando in modo inequivocabile le stanze consumatrici in rosso e mantenendo le stanze produttrici in verde.

## Obiettivi
- Aggiornare i componenti UI delle singole stanze (`RoomPowerEntry`) per evidenziare visivamente il consumo energetico in rosso vivo.
- Mantenere e uniformare la colorazione verde per le stanze e i moduli che generano energia.
- Assicurare coerenza visiva anche nell'ispettore di stanza e nel riepilogo generale dei carichi di bordo.

## Criteri di Accettazione
- [x] **Stanze Consumatrici in Rosso**:
  - [x] Tutte le stanze con bilancio energetico negativo (`power_mw < 0`) devono mostrare il testo del valore in MW, i badge e gli indicatori di carico in colore **rosso** chiaro/evidente (es. `Color(1.0, 0.25, 0.25)` / `#ff4040`).
- [x] **Stanze Produttrici in Verde**:
  - [x] Tutte le stanze con bilancio energetico positivo (`power_mw > 0`, es. Sala Reattore, Generatore Ausiliario) devono mostrare il valore in MW e gli indicatori in colore **verde** brillante (es. `Color(0.2, 1.0, 0.4)` / `#33ff66`).
- [x] **Stanze Neutre / Spente**:
  - [x] Stanze con consumo pari a 0 MW o disattivate devono presentare un colore neutro grigio / smorzato (`Color(0.65, 0.65, 0.65)`).

## Dettagli Tecnici
- **File coinvolti**:
  - `Applications/PowerGrid/Components/room_power_entry.gd`:
    - Metodo `update_power(power_mw: float)` (linee 29-42): modifica della logica di colorazione `power_status_label.modulate` e styling della barra/badge.
  - `Applications/PowerGrid/Components/room_power_entry.tscn`: Configurazione stili del componente se applicabile.
  - `Applications/PowerGrid/power_grid_app.gd`: Aggiornamento della formattazione nell'ispettore (`_update_inspector`) e nei log di diagnostica.

## Step by Step Implementation
1. **Aggiornamento Cromie in `Applications/PowerGrid/Components/room_power_entry.gd`**:
   - Nella funzione `update_power(power_mw: float)` (linee 29-42):
     - Modificare il ramo `elif power_mw < 0:` per impostare `power_status_label.modulate = Color(1.0, 0.25, 0.25, 1.0)` (rosso).
     - Modificare il ramo `if power_mw > 0:` per impostare `power_status_label.modulate = Color(0.2, 1.0, 0.4, 1.0)` (verde).
     - Impostare `power_status_label.modulate = Color(0.65, 0.65, 0.65, 1.0)` quando `power_mw == 0.0`.
   - Opzionalmente, aggiornare `power_bar` (`theme_override_styles/fill`) o un badge identificativo con il colore corrispondente (rosso per carico, verde per generazione).
2. **Aggiornamento Ispettore in `Applications/PowerGrid/power_grid_app.gd`**:
   - Nella funzione `_update_inspector()`:
     - Verificare se il consumo mostrato è negativo o positivo e applicare i medesimi colori BBCode `[color=#ff4040]` per i consumi e `[color=#33ff66]` per la produzione energetica.
