# Task 001: ShipBlueprint Flux & Modifiers

## Descrizione
Estendere la risorsa `ShipBlueprint` per memorizzare i dati economici specifici della nave. La risorsa deve tenere traccia del valore attuale di `flux` e di una lista di modificatori che ne giustificano il valore o le variazioni.

## File Coinvolti
- `Outside/ShipSublayer/ship_blueprint.gd`

## Dettagli Implementativi
- Aggiungere una variabile esportata `flux` di tipo `int` con valore predefinito 100 (se non gi? presente o se da rifinire).
- Aggiungere una variabile esportata `flux_modifiers` di tipo `Array[Dictionary]`.
- Ogni elemento dell'array `flux_modifiers` deve essere un dizionario con la seguente struttura:
  - `value`: il valore numerico del modificatore (positivo o negativo).
  - `owner`: stringa indicante chi ha emesso il modificatore (es. "Friendly Spaceship dealer").
  - `reason`: stringa indicante la causale (es. "Propriet? nave").
- Prendere come riferimento `Economy/flux_economy_manager.gd` per la coerenza con il sistema economico globale, pur mantenendo questa implementazione specifica per la blueprint della nave.

## Criteri di Accettazione
- [ ] La risorsa `ShipBlueprint` contiene i campi `flux` e `flux_modifiers`.
- [ ] I campi sono correttamente esportati e visibili nell'Inspector di Godot.
- [ ] Il valore di default di `flux` ? 100.
- [ ] La modifica dei valori tramite Inspector viene salvata correttamente nella risorsa.
