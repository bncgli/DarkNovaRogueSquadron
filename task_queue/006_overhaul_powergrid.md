# TASK-016: Overhaul Applicazione PowerGrid

## Descrizione
Rifacimento completo dell'applicazione `PowerGrid` per gestire l'energia a livello di stanza invece che a livello di snodi elettrici.

## Obiettivi
- Semplificare il controllo energetico per il giocatore.
- Introdurre conseguenze sistemiche basate sullo stato energetico delle stanze.
- Implementare un sistema di bilanciamento del carico energetico.

## Criteri di Accettazione
- [ ] Nuova Interfaccia: Sostituire la mappa 2D con una `ItemList` o `VBoxContainer` di stanze.
- [ ] Controllo per Stanza: Mostrare nome stanza, consumo/produzione (`power_mw`) e uno switch On/Off.
- [ ] Logica di Bilanciamento:
    - [ ] Il wattaggio totale disponibile deve riflettere la somma dei generatori attivi meno i consumatori attivi.
    - [ ] Spegnere stanze non essenziali deve rendere disponibile energia per sistemi critici (es. Iperdrive).
- [ ] Effetti di Sistema: Implementare listener o check periodici che attivano/disattivano funzionalit? della nave in base alle categorie dei device attivi:
    - **defence**: Scudi, contromisure.
    - **mainframe**: Funzionamento programmi avanzati.
    - **comms**: Comunicazioni a lungo raggio.
    - **tactical**: Armamenti.
    - **propulsion**: Motori e Iperdrive.
    - **service**: drone di servizio.
    - **sensors**: Radar, scansione.
    - **life_support**: Consumo ossigeno (se OFF, timer di emergenza, l'ossigeno di podinfo inizia a scendere. se arriva a zero il personaggio muore).
    - **command**: non succede niente.
    - **engineering**: Il duct drone non ricarica più.
    - **cargo**: Controllo temperatura/sicurezza stiva, oggetti o persone nella stiva possono congelarsi o decomprimere e rovinarsi.

## Dettagli Tecnici
- L'app deve interrogare la `ShipBlueprint` corrente e mappare i dispositivi attivi per categoria.
- Utilizzare segnali per notificare agli altri sistemi della nave (es. `LifeSupportManager`) quando una categoria perde alimentazione.

## Step by Step Implementation
1. Creare il nuovo layout UI per `PowerGrid`.
2. Implementare il data binding tra la UI e le stanze della `ShipBlueprint`.
3. Scrivere la logica di calcolo del bilancio energetico globale.
4. Creare il sistema di "Tag/Categorie" per mappare gli effetti sistemici.
5. Integrare gli effetti con i sistemi esistenti (Gameplay).
