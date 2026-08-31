# Task 002: App Flux Wallet

## Descrizione
Creare una nuova applicazione di sistema denominata `FluxWallet` che consenta all'equipaggio di visualizzare lo stato economico della nave (Flux) e lo storico dei modificatori attivi.

## File Coinvolti
- `Applications/FluxWallet/flux_wallet.tscn`
- `Applications/FluxWallet/flux_wallet.gd`
- `Applications/FluxWallet/flux_wallet.tres`
- `Gameplay/ShipSoftwareManager.gd` (registrazione)
- `Gameplay/TerminalSoftwareManager.gd` (registrazione)

## Dettagli Implementativi
- Seguire lo standard definito in `docs/APP_ARCHITECTURE_STANDARD.md`.
- L'interfaccia deve mostrare in evidenza in alto il valore corrente di `flux` (recuperato dalla `ShipBlueprint` attiva).
- Sotto il valore principale, mostrare una tabella con 3 colonne:
  - **Modificatore**: il valore numerico. Deve essere colorato di **verde** se positivo e di **rosso** se negativo.
  - **Proprietario**: il debitore/creditore.
  - **Causale**: la descrizione del motivo.
- Esempio riga: `-80, Friendly Spaceship dealer, Propriet? nave`.
- L'applicazione deve essere registrata nei Software Manager per apparire nel menu Start di GodotOS.

## Criteri di Accettazione
- [ ] L'app `FluxWallet` si apre correttamente dal menu Start.
- [ ] L'app visualizza il valore corretto di flux della nave.
- [ ] La lista dei modificatori ? visualizzata correttamente in formato tabella.
- [ ] La colorazione dei valori (verde/rosso) rispetta i requisiti.
- [ ] L'app segue il ciclo di vita delle applicazioni di sistema di GodotOS.
