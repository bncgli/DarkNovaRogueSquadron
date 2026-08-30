# TASK: Flusso Integrato Servizi Stazione Spaziale (Commercio, Contratti, Upgrade e Riparazioni)

## 1. Obiettivo e Panoramica
Sviluppare e integrare il flusso diegetico completo di attracco e fruizione dei **Servizi della Stazione Spaziale** (`Applications/StationHub` e app correlate) su **GodotOS**:
1. Gestire la procedura di attracco guidato alla stazione spaziale adiacente (richiesta e autorizzazione tramite *Comms & EW* / avvicinamento).
2. Fornire l'interfaccia multi-servizio di porto:
   - **Commercio merci e logistica**: compravendita materiali, gestione stiva cargo e transazioni FLUX.
   - **Stipula di nuove missioni/contratti**: sincronizzazione con l'applicazione *Logbook*.
   - **Acquisto nuovi programmi e upgrade software**: firmware driver e applicazioni installabili su `Ship Drive`.
   - **Riparazioni e rifornimenti**: ripristino dell'integrità strutturale scafo, manutenzione condotti e ricarica risorse/batterie.

---

## 2. Riferimenti al Documento di Design (DARK_NOVA_FEATURES_DESIGN.md)
- **Sezione 2 (Diagramma Flusso Utente - Fase 5b)**: *5b. Servizi Stazione Spaziale*.
- **Sezione 2.4 (Fase 4 - Accesso alla Stazione Spaziale - Fase 5b)**:
  > - **Commerciare merci e materiali** (compravendita, gestione stiva cargo e transazioni FLUX).
  > - **Trovare e accettare nuove missioni/contratti** (sincronizzati con l'app *Logbook*).
  > - **Acquistare nuovi programmi**, driver firmware e upgrade software per la nave.
  > - **Eseguire riparazioni dello scafo**, manutenzione e rifornimento risorse.

---

## 3. Specifiche Tecniche e Funzionali

### 3.1 Procedura di Docking e Attivazione Servizi
1. **Richiesta Docking via Comms**:
   - Quando la corvetta si trova nell'area della stazione adiacente, `comms_app.gd` consente di selezionare la frequenza del controllo portuale e richiedere l'attracco.
   - Ad aggancio completato (`is_docked = true`), viene notificata l'apertura o disponibilità dei servizi di stazione su GodotOS.
2. **Interfaccia Station Hub (`station_hub_app.tscn`, `780x560`)**:
   - **Tab 1: Logistica & Cargo Market**: interfaccia bidirezionale di compravendita merci tra stiva della nave (`Applications/CargoBay`) e mercato locale a valuta/rating FLUX.
   - **Tab 2: Bacheca Contratti**: elenco missioni disponibili con ricompense in crediti/FLUX; all'accettazione, la missione viene iniettata automaticamente in `Logbook` (`Applications/Logbook`).
   - **Tab 3: Software & Firmware Repository**: catalogo di nuovi moduli/programmi diegetici acquistabili e scaricabili direttamente in `Ship Drive/Programs/`.
   - **Tab 4: Cantiere e Riparazioni**: pulsanti per la riparazione istantanea delle brecce nello scafo (`dmg_breach`), ripristino integrità strutturale e rifornimento naniti/energia.

### 3.2 Sincronizzazione con i Sottosistemi di Bordo
1. **Integrazione `CargoBay` & `Economy`**:
   - Aggiornamento pesi e volumi stiva nave.
   - Incremento/decremento indice rating FLUX.
2. **Integrazione `Logbook`**:
   - Aggiornamento istantaneo della lista contratti attivi con tracker obiettivi.
3. **Integrazione `Diagnostics` & `ShipBlueprint`**:
   - Azzeramento allarmi danni scafo a riparazione effettuata.

---

## 4. Standard Architetturali e Flusso Git
1. **Branch Git**:
   - `git checkout -b applications/StationServicesHub main`
2. **File Coinvolti**:
   - `Applications/StationHub/station_hub_app.tscn`
   - `Applications/StationHub/station_hub_app.gd`
   - `Applications/StationHub/station_hub_app.tres`
   - `Applications/Comms/comms_app.gd`
   - `Applications/Logbook/logbook_app.gd`
   - `Applications/CargoBay/cargo_bay_app.gd`
   - `Outside/Stations/station_manager.gd`
   - `tests/test_station_services_hub.gd`

---

## 5. Criteri di Accettazione e Test Headless
1. **Suite di Test (`tests/test_station_services_hub.gd`)**:
   - Test procedura di docking/undocking ed emissione stato `is_docked`.
   - Test compravendita merci con trasferimento stiva e saldo FLUX.
   - Test accettazione contratto con sincronizzazione su `Logbook`.
   - Test acquisto software con scrittura file su `Ship Drive/Programs/`.
   - Test riparazione scafo con azzeramento brecce/danni.
2. **Chiusura Git**:
   - [ ] Test headless superati con successo.
   - [ ] Commit con messaggio: `feat(station): implement full station services hub flow and subsystem integrations`.
   - [ ] Merge su `main`.
