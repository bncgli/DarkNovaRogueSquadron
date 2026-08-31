# TASK-012: Standardizzazione Stanze Editor

## Descrizione
Standardizzare la creazione delle stanze nel `ship_sublayer_editor`. Attualmente in `addons/ship_sublayer_editor/ship_blueprint_canvas.gd` la funzione `_finish_add_room` crea stanze generiche. L'obiettivo e' creare un Autoload (es. `RoomDatabase.gd`) che contenga una lista di stanze di default con dimensioni minime e dispositivi gia' assegnati.

## Requisiti
L'editor deve permettere di scegliere da questa lista invece di inserire a mano. Le dimensioni fornite sono minime.

Lista delle stanze da includere:
1. **Ponte di comando**: pod piloti, 30x30
2. **Supporto vitale minimale**: purificatore, caldaia, 60x60
3. **Supporto vitale avanzato**: purificatore, caldaia, serra idroponica, 100x100
4. **Mainframe**: mainframe, 30x30
5. **Sistemi di comunicazione**: matrice di comunicazione, 60x60
6. **Reattore a fusione**: reattore, 200x200
7. **Baia di carico**: nessuno, 150x150
8. **Sala motori**: reattore 1 e reattore 2, 100x100
9. **Pod drone di servizio**: baia di ricarica drone, 60x60
10. **Matrice sensori**: Array di sensori, 60x60
11. **Armatura adattiva**: sistema di difesa, 30x30
12. **Armamenti**: Gestore torrette, 80x80

## Criteri di Accettazione
- [ ] Creazione dell'Autoload `RoomDatabase.gd` con la lista delle stanze definita sopra.
- [ ] Implementazione della logica di selezione della stanza nell'editor prima del piazzamento.
- [ ] La funzione `_finish_add_room` in `ship_blueprint_canvas.gd` deve utilizzare i dati della stanza selezionata.
- [ ] I dispositivi associati alla stanza devono essere aggiunti automaticamente alla creazione.
- [ ] Rispetto delle dimensioni minime durante la creazione.

## TODO / Note per Sviluppi Futuri
1. **Aggiornamento Costi**: I costi di costruzione verranno aggiornati in una fase successiva.
2. **Validazione Posizionamento**: Assicurarsi che i dispositivi non si sovrappongano o escano dai bordi della stanza se possibile.

## Dettagli Tecnici
- Autoload: `RoomDatabase.gd`
- Script principale da modificare: `addons/ship_sublayer_editor/ship_blueprint_canvas.gd`
- Formato dati: Dizionario o Risorsa custom per definire le proprieta' delle stanze.
