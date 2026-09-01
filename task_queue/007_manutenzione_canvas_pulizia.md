# TASK-017: Manutenzione Canvas e Pulizia

## Descrizione
Attivit? di pulizia del codice e aggiornamento dei componenti di visualizzazione per rimuovere ogni traccia del vecchio sistema a snodi e cablaggi.

## Obiettivi
- Ottimizzare il rendering delle blueprint.
- Rimuovere codice morto per migliorare la manutenibilit?.

## Criteri di Accettazione
- [ ] `ShipBlueprintCanvas.gd`:
    - [ ] Rimozione completa del codice di disegno per `junctions` e `conduits`.
    - [ ] Aggiornamento visualizzazione dei `devices` (ora sono icone o indicatori dentro l'area della stanza).
- [ ] Global Clean-up:
    - [ ] Ricerca e rimozione di riferimenti a "junction", "conduit", "wire", "connection" nella logica elettrica obsoleta.
    - [ ] Eliminazione di script o scene non pi? utilizzati (es. `junction.tscn`, `conduit.gd` se indipendenti).

## Dettagli Tecnici
- Assicurarsi che la rimozione non causi errori di reference in altre parti del sistema (es. salvataggi vecchi).
- Il rendering delle stanze deve ora includere un feedback visivo se la stanza ? Alimentata (`is_on`) o meno.

## Step by Step Implementation
1. Aggiornare `ShipBlueprintCanvas` per riflettere la nuova struttura.
2. Eseguire un grep globale per identificare codice morto legato ai vecchi layer.
3. Rimuovere i file fisici obsoleti dal filesystem.
4. Verificare l'integrit? del progetto tramite i test esistenti.
