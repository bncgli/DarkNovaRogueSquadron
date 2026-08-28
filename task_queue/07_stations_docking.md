# TASK: Sviluppo Modulo "Stazioni Spaziali, Docking e Servizi Portuali" (`SpaceWorld/StationsDocking`)

## 1. Obiettivo e Panoramica
Sviluppare il sistema diegetico di **Stazioni Spaziali, Protocollo di Docking e Hub Servizi Portuali** su GodotOS per *Dark Nova: Rogue Squadron*.
L'equipaggio attracca alle stazioni tramite protocollo radio in *Comms & EW* e manovre di precisione in *Flight Control*. A docking completato, GodotOS sblocca applicazioni di servizio portuale (Cantiere Riparazioni, Mercato Software/Firmware, Bacheca Contratti, Taverna Spaziale per rumors/coordinate) senza transizioni 3D in prima persona.

---

## 2. Standard Architetturali e Git
1. **Branch Git**: Creare ed eseguire il checkout sul branch `feature/StationsDocking`.
2. **Posizione File**:
   - `Outside/Stations/space_station_entity.tscn` e `.gd` (Entità 3D stazione orbitale)
   - `Outside/Stations/docking_manager.gd` (Gestione procedura di aggancio e permessi)
   - `Applications/StationHub/station_hub_app.tscn` e `.gd` (Interfaccia desktop servizi porto)
   - `tests/test_stations_docking.gd` (Suite di test headless)

---

## 3. Specifiche Tecniche e Flusso Operativo
1. **Protocollo di Docking Diegetico**:
   - Aggancio radio via *Comms*: trasmissione identità IFF e richiesta autorizzazione attracco.
   - Allineamento nei coni telemetrici di cattura (guida *Flight Control* entro tolleranza e raggio magnetico).
2. **Hub Servizi di Stazione su GodotOS**:
   - **Cantiere Navale & Riparazioni**: Riparazione scafo, manutenzione condotti, ricarica batterie e acquisto naniti/ricambi.
   - **Mercato Software & Repository Firmware**: Compravendita programmi diegetici, script terminale e driver.
   - **Bacheca Contratti & Ufficio Taglie**: Consultazione e accettazione contratti mercantili o taglie sincronizzate con *Logbook*.
   - **Taverna Spaziale & Intercettazione Frequenze**: Ascolto gossip radio e coordinate di relitti con risorse.
3. **Restrizione Diegetica Pura**:
   - Tutta l'interazione con la stazione avviene unicamente tramite finestre del computer di bordo GodotOS.

---

## 4. Criteri di Accettazione e Test Headless
Creare `tests/test_stations_docking.gd` per verificare:
- Flusso di richiesta e concessione slot di docking tramite messaggistica radio.
- Verifica vincoli cinematici di cattura magnetica e blocco nave in stato docked.
- Apertura e popolamento corretto dell'app `StationHub` con i servizi attivi.
