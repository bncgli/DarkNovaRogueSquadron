# TASK: Sviluppo Modulo "Commercio, Logistica Cargo ed Economia a FLUX" (`Economy/FluxCargo`)

## 1. Obiettivo e Panoramica
Sviluppare il sistema economico **Freemium-punk a FLUX, Gestione Stiva Cargo e Rete Dati S-Net** per *Dark Nova: Rogue Squadron*.
Il sistema gestisce l'inventario cargo della corvetta (celle energetiche, leghe, minerali, contrabbando), il rating finanziario continuo **FLUX** (credit score dinamico che determina tariffe, abbonamenti e rischio di sequestro/impound della nave) e il trasporto fisico di snapshot della rete **S-Net** con intercettazione hacker.

---

## 2. Standard Architetturali e Flusso Git
1. **Flusso Git (Obbligatorio)**:
   - Creare ed eseguire il checkout sul branch dedicato partendo da `main`: `git checkout -b feature/FluxEconomyCargo main`.
   - Sviluppare il codice, gestori, interfacce UI e test esclusivamente all'interno di tale branch.
   - Al termine dello sviluppo e dopo aver validato con successo i test:
     1. Eseguire il commit di tutte le modifiche: `git add .` e `git commit -m "feat(economy): implementa rating FLUX, gestione stiva cargo e snapshot S-Net"`.
     2. Passare al branch `main`: `git checkout main`.
     3. Eseguire il merge del branch completato: `git merge feature/FluxEconomyCargo`.
2. **Posizione File**:
   - `Economy/cargo_manager.gd` (Gestore stiva cargo e trasferimento merci)
   - `Economy/flux_economy_manager.gd` (Autoload / Rating FLUX, canoni e microtransazioni)
   - `Applications/CargoBay/cargo_bay_app.tscn` e `.gd` (Interfaccia UI gestione stiva)
   - `tests/test_flux_economy_cargo.gd` (Suite di test headless)

---

## 3. Specifiche Tecniche e Funzionali
1. **Gestione della Stiva (`Cargo Bay`)**:
   - Capacità volumetrica e di massa (es. 2000 kg totali).
   - Tipologie merci: minerali, leghe raffinate, munizioni, celle energetiche, dischi snapshot S-Net, contrabbando sigillato.
   - Trasferimento bidirezionale tra stiva nave, *Service Drone* e magazzini stazione.
2. **Economia a FLUX e Rating Creditizio**:
   - Valutazione continua basata su volume, puntualità e regolarità transazioni.
   - **Rating A/S**: sconti portuali, priorità forniture, contratti prestigiosi.
   - **Rating D/F (Insolvente)**: disattivazione remota di feature OS, sovraccosti, taglie di debito e minaccia sequestro (Impound / Game Over).
3. **Snapshot Rete S-Net e Meccanica Hacker**:
   - Array fisici di dischi dati trasportati da cargo corrieri per superare i vincoli no-FTL.
   - L'Hacker può violare le barriere ICE degli hard disk per sottrarre snapshot finanziari e listini segreti.

---

## 4. Criteri di Accettazione, Test e Chiusura Task
1. **Suite di Test Headless**: Creare ed eseguire `tests/test_flux_economy_cargo.gd` per verificare:
   - Calcolo corretto del peso/spazio occupato nella stiva e blocco sovraccarico.
   - Aggiornamento dinamico del punteggio FLUX ed emissione eventi di penalità in stato di insolvenza.
   - Trasferimento di risorse tra nave e drone o stazione.
2. **Chiusura Git**:
   - [ ] Test headless superati con esito positivo.
   - [ ] Commit di tutte le modifiche su branch `feature/FluxEconomyCargo`.
   - [ ] Checkout su `main` e merge completato del branch.
