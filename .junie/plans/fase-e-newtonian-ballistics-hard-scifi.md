---
sessionId: session-260915-141146-3p3m
---

# Requirements

### Overview & Goals
In accordo con la decisione di design consolidata in `DESIGN_DECISIONS_PENDING.md` (Punto 6) e con le preferenze architetturali dell'utente (**Riscrittura Flux Economy** e modello a **Baratto Titoli Debito**), questo piano operativo definisce la riscrittura integrale del motore economico di *Dark Nova: Rogue Squadron*.

Nel contesto satirico e distopico **Freemium-punk** dell'ambientazione:
1. **Eliminazione Radicale della Valuta Fiat Standard**: Non esistono "Crediti" generici (CR) o monete cartacee statiche. L'intera economia opera tramite il **FLUX**, concepito come liquidità di conio e indice dinamico di rating.
2. **Baratto di Debiti e Crediti Corporativi**: Le transazioni si svolgono come uno scambio di rate e titoli di debito/credito circolanti (analogia: *"scambiarsi le rate della macchina venduta per pagare le rate di una moto"*). Comprare forniture, navi o servizi implica cedere titoli di credito attivi, versare FLUX liquido o accollarsi quote/tranche di debito passivo verso le stazioni o corporazioni locali.
3. **Rating Creditizio Dinamico e Rischio Sequestro**: Il rating FLUX della nave (S, A, B, C, D, F) riflette il rapporto tra liquidità e debito complessivo e la regolarità delle transazioni, determinando agevolazioni commerciali o sovraccosti da rischio insolvenza e blocco delle licenze software.
4. **Armonizzazione Sistemica**: `FluxEconomyManager`, `StationHubApp`, `MissionManagerSingleton`, `CargoManager` e `FluxWallet` operano all'unisono basandosi sulla fonte di verità dello scafo (`ShipBlueprint` e `ShipFluxModifier`).

### Scope
- **In Scope**:
  - Riscrittura completa di `Economy/flux_economy_manager.gd`: rimozione della proprietà legacy `credits` e di tutte le API basate su crediti; introduzione della gestione di titoli di debito (`DEBT`) e titoli di credito (`CREDIT_TITLE`) rappresentati tramite `ShipFluxModifier`.
  - Calcolo contabile del saldo netto:
    $$\text{Net FLUX} = \text{Liquid FLUX} + \sum \text{Modifier Values}$$
  - Metodi transazionali per il baratto:
    - `pay_with_flux(amount: int, allow_debt_issuance: bool, creditor: String)`
    - `transact_barter(required_cost: int, offered_liquid: int, transferred_titles: Array, accepted_debts: Array)`
    - `receive_flux_reward(liquid_amount: int, debt_relief_target: String)`
    - `repay_debt_tranche(debt_owner: String, amount: int)`
  - Adeguamento di `Applications/StationHub/station_hub_app.gd`: sostituzione dell'indicatore `Crediti: %d CR` con la telemetria diegetica di FLUX Netto, Liquido e Debito; adeguamento degli acquisti/vendite nel Cargo Market, delle riparazioni al Cantiere e del saldo rate al modello a baratto titoli e FLUX.
  - Adeguamento di `Economy/mission_manager.gd`: riconversione dei compensi dei contratti in FLUX liquido, sgravio di rate di debito pregresse e titoli di credito corporativi commerciabili.
  - Adeguamento di `Economy/cargo_manager.gd`: valutazione del valore merci (`unit_base_value`) e del bottino in unità di valore FLUX.
  - Aggiornamento di `Applications/FluxWallet/flux_wallet.gd`: supporto completo all'elenco espanso dei titoli di credito e debito corporativi con opzioni di trasferimento e cessione.
  - Creazione della suite di test GUT `tests/gut/test_flux_economy_barter_system.gd` e allineamento dei test preesistenti.
- **Out of Scope**:
  - Aste multiplayer in tempo reale tra giocatori su diversi server (verranno affrontate con l'integrazione lobby avanzata).
  - Mercati neri fisici clandestini con contrabbando fuorilegge all'interno delle stazioni (Fase futura).

### User Stories
- **Come Equipaggio**, voglio poter fare rifornimento, riparare lo scafo o acquistare merci anche a corto di FLUX liquido, accollandomi una tranche di debito verso la corporazione portuale o cedendo un titolo di credito guadagnato in precedenza.
- **Come Commerciante**, voglio vendere le merci della stiva o i minerali estratti per ripianare direttamente le rate di debito che gravano sul noleggio della nave ("Ship Rent Service") oppure per ottenere conio FLUX spendibile.
- **Come Cacciatore di Taglie**, voglio che i contratti del Fixer mi ricompensino con un mix di liquidità immediata e sgravi di debito corporativo, aumentando il rating creditizio della corvetta.
- **Come Capitano alla plancia FluxWallet**, voglio monitorare con precisione la composizione del portafoglio titoli (debiti passivi vs crediti attivi) e il credit score per prevenire l'impound della nave.

### Functional Requirements
- **FR-FLUX1 (Rimozione Totale Crediti Legacy)**: Nessun componente dell'economia deve fare affidamento su valuta fiat generica (`credits: int`). `FluxEconomyManager` diventa l'autorità unica per la contabilità FLUX liquida e dei titoli.
- **FR-FLUX2 (Gestione Titoli e Modificatori Scafo)**: I titoli di debito (es. `-700 FLUX` per Ship Rent Service, `-150 FLUX` per anticipo riparazioni) e i titoli di credito (es. `+200 FLUX` buono corporativo minerario) sono memorizzati come `ShipFluxModifier` e sincronizzati con `ShipBlueprint`.
- **FR-FLUX3 (Baratto e Transazioni Flessibili)**: Nei servizi di stazione (`StationHub`), se il costo $C$ supera il FLUX liquido disponibile $L$, il giocatore autorizzato (RBAC) può:
  - Salpare o procedere indebitandosi con emissione automatica di un nuovo `ShipFluxModifier` passivo (fino al tetto massimo di debito consentito dal rating creditizio).
  - Cedere uno o più titoli di credito attivi in portafoglio per coprire la differenza.
- **FR-FLUX4 (Liquidazione Bottino e Rimborso Debiti)**: La vendita rapida del carico e del bottino di scavenging permette di scegliere se ricevere conio liquido o applicare l'intero importo ad abbattere prioritariamente il debito di noleggio scafo o debiti ad alto tasso di penalità.
- **FR-FLUX5 (Contratti Fixer a Ricompensa Mista)**: I contratti di `MissionManager` generano ricompense strutturate in `reward_liquid_flux` e `reward_debt_relief` (con applicazione automatica alla fazione/corporazione creditrice o rilascio di un titolo di credito negoziabile).
- **FR-FLUX6 (Rating Dinamico e Penalità Insolvenza)**: Il credit score FLUX oscilla da 0 a 1000:
  - *Rating S (≥900)* / *A (≥750)*: sconti portuali (-20%, -10%), spread favorevole di baratto, sblocco contratti di prestigio.
  - *Rating B (≥600)* / *C (≥450)*: condizioni standard.
  - *Rating D (≥300)* / *F (<300)*: sovraccosti di rischio (+15%, +35%), rifiuto di apertura nuove linee di debito, disattivazione remota licenze software e avvio timer di sequestro forzato (Impound).

### Non-Functional Requirements
- **Integrità Contabile**: Nessuna operazione di baratto o transazione può produrre valori `NaN`, corrompere la consistenza di `ShipBlueprint.flux_modifiers` o disallineare lo stato su disco rispetto alla memoria.
- **Retrocompatibilità di Segnali**: Aggiornare i segnali economici (`flux_balance_changed`, `debt_tranche_added`, `debt_tranche_repaid`, `rating_changed`) garantendo al contempo bridge di compatibilità per eventuali listener legacy.

# Technical Design

### Current Implementation
- **`Economy/flux_economy_manager.gd`**:
  - Contiene ancora residui della vecchia logica basata su `credits: int = 5000`, `credits_changed(new_credits, delta)` e abbonamenti a tempo legati a crediti standard.
  - Possiede già il calcolo del `flux_score` (0-1000), le lettere di rating (S, A, B, C, D, F) e il timer di rischio impound.
- **`Outside/ShipSublayer/ShipFluxModifier.gd`**:
  - Risorsa `@tool` esportabile con `value: int`, `owner: String`, `reason: String`, `to_dict()` e `from_dict()`.
- **`Outside/ShipSublayer/ship_blueprint.gd`**:
  - Gestisce `flux: int` (300 di default), `flux_modifiers: Array[ShipFluxModifier]` (con -700 per Ship Rent Service), `get_rent_debt()` e `repay_rent_debt()`.
- **`Applications/StationHub/station_hub_app.gd`**:
  - Contiene gli helper `_get_credits()`, `_spend_credits()`, `_add_credits()` che leggono e scrivono su `flux_mgr.credits`.
  - La UI mostra un label per crediti (`%CreditsLabel`) e uno per FLUX (`%FluxRatingLabel`).
- **`Economy/mission_manager.gd`**:
  - Ogni contratto definisce `reward_credits` e `reward_flux`. All'incasso, accredita crediti su `FluxEconomyManager`.

### Key Decisions
1. **Unificazione della Fonte di Verità Economica**:
   - *Scelta*: `FluxEconomyManager` diventa il proxy contabile centrale che legge e scrive direttamente sul saldo `flux` e sull'array `flux_modifiers` della `ShipBlueprint` attiva.
   - *Motivazione*: Elimina ogni duplicazione o disallineamento: il wallet, i salvataggi blueprint, i terminali portuali e i contratti condividono esattamente la stessa istanza e gli stessi titoli.
2. **Modello Dati a Baratto Titoli (Debt & Credit Tranches)**:
   - *Scelta*: Trattare ogni voce contabile passiva o attiva non liquida come istanza di `ShipFluxModifier`.
   - *Motivazione*: Pienamente allineato con la visione dell'utente: non un'astratta cifra numerica, ma un portafoglio di obbligazioni, rate di noleggio e buoni commerciali emessi da corporazioni reali dell'ambientazione (*"Aegis Port Authority"*, *"Titan Mining Consortium"*, *"Ship Rent Service"*).
3. **Flessibilità di Pagamento con Emissione Debito Condizionata dal Rating**:
   - *Scelta*: Consentire alle navi con rating $\ge \text{C}$ di indebitarsi al momento dell'acquisto emettendo un nuovo titolo passivo se non dispongono di FLUX liquido sufficiente. Impedire l'apertura di nuovo debito per rating D ed F (richiesta liquidità integrale o vendita merci prima dell'acquisto).
   - *Motivazione*: Crea una dinamica di gameplay satirico Freemium-punk in cui il rating creditizio influenza concretamente la libertà operativa dell'equipaggio.
4. **Liquidazione Intelligente del Bottino e Contratti Misti**:
   - *Scelta*: Alla vendita del carico o incasso contratti, permettere l'allocazione diretta verso il rimborso delle rate attive (riducendo il debito) o l'incasso in conio liquido.
   - *Motivazione*: Supporta la decisione dell'utente sul pagamento discrezionale del debito di noleggio e incentiva la gestione finanziaria strategica.

### Architecture Diagram

```mermaid
graph TD
    subgraph Core Economic State
        Blueprint[ShipBlueprint<br/>flux: int & flux_modifiers]
        Mods[ShipFluxModifier List<br/>-700 Rent | +200 Titoli Credito | -150 Rate]
        Blueprint --- Mods
    end

    subgraph FluxEconomyManager Singleton
        FEM[FluxEconomyManager]
        FEM -->|sync balance & modifiers| Blueprint
        ScoreCalc[Calculate FLUX Rating & Score<br/>Liquid vs Debt Ratio + Volume]
        ImpoundLogic[Impound Risk & Remote Feature Lockout]
        BarterEngine[Barter Engine<br/>Liquid Flux + Debt Issuance / Credit Exchange]
        FEM --> ScoreCalc
        FEM --> ImpoundLogic
        FEM --> BarterEngine
    end

    subgraph Consumers & UI
        Hub[StationHubApp<br/>Market Trade | Yard Repairs | Debt Repay]
        Wallet[FluxWalletApp<br/>Display Net Balance & Tranche Portfolio]
        Missions[MissionManagerSingleton<br/>Bounties & Contracts Payout]
        Cargo[CargoManagerSingleton<br/>Valuation in FLUX Units]
    end

    Hub -->|barter transactions| FEM
    Wallet -->|telemetry & repay| FEM
    Missions -->|liquid reward & debt relief| FEM
    Cargo -->|item values in FLUX| Hub
```

### Proposed Changes

#### 1. Ristrutturazione di `Economy/flux_economy_manager.gd`
- Rimuovere la variabile `credits: int` e il segnale `credits_changed`.
- Aggiungere proprietà e segnali:
  - `signal flux_balance_changed(net_flux: int, liquid_flux: int, total_debt: int)`
  - `signal debt_tranche_added(modifier: ShipFluxModifier)`
  - `signal debt_tranche_settled(owner: String, amount: int)`
  - `signal barter_transaction_completed(summary: Dictionary)`
- Implementare i metodi principali:
  - `get_liquid_flux() -> int`: legge `blueprint.flux`.
  - `get_total_debt() -> int`: somma i modificatori negativi in `blueprint.flux_modifiers`.
  - `get_total_credit_titles() -> int`: somma i modificatori positivi.
  - `get_net_flux() -> int`: calcola $\text{liquid} + \text{modificatori}$.
  - `can_afford(cost: int, allow_debt: bool = false) -> bool`: verifica se la nave può sostenere la spesa.
  - `spend_liquid_flux(amount: int) -> bool`: detrae FLUX liquido.
  - `add_liquid_flux(amount: int) -> void`: incrementa FLUX liquido.
  - `issue_debt_tranche(owner: String, reason: String, amount: int) -> ShipFluxModifier`: crea e registra una nuova rata passiva.
  - `repay_debt(owner: String, amount: int) -> int`: rimborsa una tranche passiva usando FLUX liquido.
  - `barter_transaction(cost: int, offered_liquid: int, transferred_titles: Array, issue_debt_if_needed: bool, creditor: String) -> Dictionary`: risolve uno scambio complesso multi-tranche.
  - Ricalcolo dinamico di `flux_score` basato sul rapporto $\frac{\text{Liquid}}{\text{Debt} + 1}$ e sulla tempestività dei rimborsi.

#### 2. Riconversione di `Applications/StationHub/station_hub_app.gd`
- Sostituire `%CreditsLabel` con telemetria integrata FLUX: `"FLUX Netto: %d [Liq: %d | Deb: -%d]"`.
- Rimuovere `_get_credits()`, `_spend_credits()`, `_add_credits()`, sostituendoli con chiamate dirette a `FluxEconomyManager`.
- Aggiornare i flussi:
  - **Cantiere Navale**: riparazione scafo (es. 250 FLUX), naniti e batterie pagabili in FLUX o con accollo rateale (`"Aegis Shipyard Repairs"`).
  - **Cargo Market**: compravendita merci regolata in FLUX. Se il compratore non ha abbastanza conio, può ricorrere a debito commerciale autorizzato.
  - **Liquidazione Bottino**: pulsante `"⚡ Vendi Bottino Scavenging"` accredita FLUX liquido o decurta il canone noleggio scafo con opzione di scelta.
  - **Bacheca Contratti**: incasso delle taglie con accredito FLUX e sgravio rateale.

#### 3. Riconversione di `Economy/mission_manager.gd`
- Ridenominare le ricompense dei contratti da `reward_credits` a `reward_liquid_flux: int` e aggiungere `reward_debt_relief: int` e `creditor_relief_target: String`.
- All'atto del claim (`claim_contract`), chiamare `FluxEconomyManager.receive_contract_reward(contract)`.

#### 4. Integrazione con `Economy/cargo_manager.gd`
- Uniformare la nomenclatura di `unit_base_value` come valore intrinseco in FLUX, eliminando ogni testo o log diegetico che faccia riferimento a "Crediti" o "CR".

#### 5. Aggiornamento di `Applications/FluxWallet/flux_wallet.gd`
- Mostrare la visualizzazione analitica delle tranche corporative possedute (con badge distintivi per debiti verso Ship Rent Service, cantieri, o titoli di credito cedibili).

### File Structure
- **Modificati**:
  - `Economy/flux_economy_manager.gd`: riscrittura completa, eliminazione crediti fiat, gestione del baratto di titoli e rating.
  - `Applications/StationHub/station_hub_app.gd`: interfaccia e transazioni interamente convertite a FLUX e baratto rate.
  - `Economy/mission_manager.gd`: contratti e ricompense allineati al modello FLUX e sgravio debiti.
  - `Economy/cargo_manager.gd`: quotazioni e stime stiva in unità FLUX.
  - `Applications/FluxWallet/flux_wallet.gd`: supporto all'elenco espanso delle tranche di debito/credito corporativo.
  - `docs/GAME_SESSION_SCENARIO_AND_ROADMAP.md`: tracciamento del nuovo pilastro economico completato.
- **Creati**:
  - `tests/gut/test_flux_economy_barter_system.gd`: suite automatizzata GUT per la validazione della riscrittura economica a baratto debiti/crediti.

### Risks
- **Rischio Regressione Test Preesistenti che invocavano `flux_mgr.credits`**: Alcuni test storici leggevano o modificavano `flux_mgr.credits`.
  - *Mitigazione*: Implementare proprietà o setter/getter di transizione su `FluxEconomyManager` con warning diegetico, oppure aggiornare i test di test suite storiche per testare direttamente i metodi FLUX nativi.
- **Rischio Overflow di Debito (Ciclo di Default Permanente)**: I giocatori potrebbero accumulare debiti senza poter salpare o attraccare.
  - *Mitigazione*: I contratti del Fixer e le missioni di soccorso/scavenging rimangono sempre accessibili indipendentemente dal rating, consentendo sempre all'equipaggio abile di ripianare i debiti e risalire il rating.

# Testing

### Validation Approach
La riscrittura della Flux Economy viene convalidata tramite una nuova suite automatizzata Godot GUT (`tests/gut/test_flux_economy_barter_system.gd`), accompagnata dall'esecuzione in headless mode di tutte le suite di regressione del progetto.

### Key Scenarios

#### Scenario 1: Modello a Saldo Netto e Tranche di Debito
- **Setup**: Nave con 300 FLUX liquidi e modificatore di partenza -700 FLUX per "Ship Rent Service".
- **Esito Atteso**:
  - `get_liquid_flux()` restituisce `300`.
  - `get_total_debt()` restituisce `700`.
  - `get_net_flux()` restituisce `-400`.
  - Il rating creditizio calcola la fascia proporzionata alla solvibilità.

#### Scenario 2: Transazione con Baratto ed Emissione Nuovo Debito
- **Setup**: Corvetta con 100 FLUX liquidi e rating B che intende acquistare una fornitura dal cantiere del costo di 250 FLUX.
- **Azione**: Invocazione di `barter_transaction` con FLUX parziale e accollo del residuo (150 FLUX) a debito verso la corporazione portuale.
- **Esito Atteso**:
  - Il FLUX liquido scende a 0.
  - Viene emesso un nuovo `ShipFluxModifier` passivo di valore `-150` intestato alla stazione.
  - `get_total_debt()` sale di 150.
  - La transazione va a buon fine e la merce/servizio viene erogata.

#### Scenario 3: Rimborso Debito tramite Liquidazione Bottino
- **Setup**: Nave con debito residuo di 700 FLUX. La stiva contiene minerali e bottino di relitto per un controvalore di 400 FLUX.
- **Azione**: Liquidazione del bottino con destinazione rimborso debito in `StationHub`.
- **Esito Atteso**:
  - Il debito di noleggio scende da 700 a 300 FLUX.
  - Il saldo netto sale di 400.
  - Il rating FLUX riceve un bonus per puntualità e riduzione dell'indebitamento.

#### Scenario 4: Riscossione Contratti Fixer e Sgravio Rateale
- **Setup**: Contratto completato con ricompensa di 500 FLUX liquidi e 300 FLUX di sgravio debito.
- **Azione**: Chiamata di `claim_contract`.
- **Esito Atteso**:
  - Il FLUX liquido aumenta di 500.
  - Le rate di debito attive vengono ridotte di 300.
  - Nessuna presenza di campi monetari obsoleti "CR".

### Edge Cases
- **Tentativo di Indebitamento con Rating F**: La transazione a debito deve essere respinta se la corvetta si trova in stato insolvente (`is_insolvent() == true`).
- **Pagamento Superiore al Debito Residuo**: Se si rimborsa più del debito residuo di una tranche, l'eccedenza non va persa ma viene restituita in conio liquido.
- **Rimozione Titoli a Saldo Zero**: I modificatori che raggiungono valore 0 vengono rimossi automaticamente dall'array per evitare frammentazione della memoria.

### Test Changes
- **Nuovo File**: `tests/gut/test_flux_economy_barter_system.gd` contenente:
  - `test_net_flux_and_debt_tranches_accounting()`
  - `test_barter_purchase_with_debt_issuance()`
  - `test_debt_relief_from_salvage_liquidation()`
  - `test_fixer_contract_flux_and_debt_relief_payout()`
  - `test_insolvency_blocks_new_debt_and_triggers_impound_risk()`

# Delivery Steps

### ✓ Step 1: Ristrutturazione FluxEconomyManager e Modello a Titoli di Debito/Credito
Riscrivere completamente `Economy/flux_economy_manager.gd` eliminando la valuta fiat standard (`credits`), calcolando il saldo netto contabile (`Net FLUX = Liquid + Titoli`), sincronizzandosi con `ShipBlueprint` e `ShipFluxModifier`, e introducendo i metodi transazionali per il baratto (`pay_with_flux`, `transact_barter`, `issue_debt_tranche`, `repay_debt`).

### ✓ Step 2: Adeguamento di StationHub con Baratto Titoli e Ripianamento Rate
Riconvertire `Applications/StationHub/station_hub_app.gd` sostituendo i riferimenti a crediti e CR con telemetria diegetica FLUX (netto, liquido, debito), e adeguando il Cantiere Navale, il Cargo Market e la liquidazione del bottino al modello a baratto titoli e FLUX.

### ✓ Step 3: Allineamento Contratti Fixer e Borsa Merci in Unità FLUX
Aggiornare `Economy/mission_manager.gd` e `Economy/cargo_manager.gd` per operare interamente in unità FLUX, con contratti a ricompensa mista (FLUX liquido + sgravio rateale) e valorizzazione del carico stiva in FLUX.

### ✓ Step 4: Aggiornamento FluxWallet e Suite di Validazione GUT
Aggiornare `Applications/FluxWallet/flux_wallet.gd` con la visualizzazione avanzata delle tranche di debito/credito corporativo e creare la suite di test GUT `tests/gut/test_flux_economy_barter_system.gd` per verificare la contabilità, il baratto titoli e il rating di solvibilità.