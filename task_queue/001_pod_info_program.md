# TASK-007: Sviluppo Programma Terminale PodInfo

## Descrizione
Sviluppare un programma per terminale chiamato `PodInfo`. L'applicazione deve monitorare i parametri vitali del personaggio e gestire i sistemi audio ambientali della nave.

## Requisiti
Il programma deve mostrare i seguenti valori vitali dell'utente:
- **Frequenza cardiaca**
- **Ossigeno**
- **Temperatura**
- **Qualità dell'aria**
- **G della nave**

## Criteri di Accettazione
- [ ] Creazione dell'applicazione `PodInfo` (scena e script).
- [ ] Registrazione del comando nel `TerminalSoftwareManager`.
- [ ] Interfaccia terminale funzionante con visualizzazione dei 5 parametri richiesti.
- [ ] Predisposizione della logica per la gestione dei suoni in background.

## TODO / Note per Sviluppi Futuri
1. **Effetti G-force**: In base al movimento di pitch della nave, il personaggio deve subire red-out o black-out (schermo rosso/nero graduale). Se l'effetto è sostenuto, il personaggio muore.
2. **Gestione rumori interni**: Il programma `pod` deve gestire i suoni ambientali della nave in background.
3. **Audio immersivo**: Implementare un listener 2D stereo direzionale nella plancia che riproduca rumori legati a danni al blueprint della nave, guasti o altri eventi specifici.

## Dettagli Tecnici
- L'applicazione deve seguire gli standard in `docs/APP_ARCHITECTURE_STANDARD.md`.
- Il comando da terminale dovrebbe essere `pod`.
