# TASK-014: Refactor di ShipBlueprint e Struttura Dati

## Descrizione
Refactoring completo della risorsa `ShipBlueprint` per centralizzare la gestione dei dispositivi all'interno delle stanze e rimuovere i layer obsoleti di snodi e cablaggi.

## Obiettivi
- Ristrutturare la gerarchia dei dati per favorire una gestione per stanze.
- Semplificare il sistema elettrico rimuovendo la necessit? di tracciamento manuale di snodi e cavi.
- Aggiungere il supporto per il riferimento alla mesh 3D della nave.

## Criteri di Accettazione
- [ ] Modifica di `device.gd` (o risorsa equivalente) per includere solo: `id`, `name`, `description`, `category`, `power_mw`.
- [ ] Modifica di `room_data.gd` (o struttura interna alla blueprint):
    - [ ] Aggiunta array `devices`.
    - [ ] Aggiunta variabile `power_mw` (somma algebrica dei device contenuti).
    - [ ] Aggiunta variabile `is_on` (bool).
    - [ ] Rimozione `category` dalla stanza.
- [ ] Rimozione completa dei layer `junctions` e `conduits` dalla risorsa `ShipBlueprint`.
- [ ] Aggiunta del campo `ship_mesh_path` (String, export FILE) alla blueprint.
- [ ] Aggiornamento dei metodi di inizializzazione e serializzazione per supportare la nuova struttura.

## Dettagli Tecnici
- **Power Calculation**: Il `power_mw` della stanza deve essere aggiornato ogni volta che un device viene aggiunto o rimosso.
- **Power Logic**: Un valore `power_mw` positivo nel device indica un generatore, negativo indica un consumatore.
- **Legacy Cleanup**: Assicurarsi che il caricamento di vecchie blueprint non rompa il sistema (prevedere una migrazione o dichiarare il breaking change).

## Step by Step Implementation
1. Modificare le classi/risorse base dei Device e delle Stanze.
2. Aggiornare la classe `ShipBlueprint` per riflettere i cambiamenti (rimozione layer, aggiunta mesh path).
3. Implementare la logica di calcolo automatico del wattaggio nella stanza.
4. Verificare che i dati vengano salvati e caricati correttamente in formato .tres.
