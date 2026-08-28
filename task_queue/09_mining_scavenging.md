# TASK: Sviluppo Modulo "Mining ed Estrazione Risorse (Asteroidi & Scavenging)" (`Gameplay/MiningScavenging`)

## 1. Obiettivo e Panoramica
Sviluppare il ciclo di gameplay diegetico di **Mining su Asteroidi (Deep Core Mining)** e **Scavenging di Relitti Derelitti** per *Dark Nova: Rogue Squadron*.
La meccanica coinvolge la scansione geologica via *Sensors*, la frantumazione calibrata tramite torrette controllate dal Soldato (*Weapons*), l'hovering del Pilota per evitare frammenti e il recupero dei minerali e moduli avionici tramite *Service Drone* / *Duct Drone* con bypass ICE dell'Hacker.

---

## 2. Standard Architetturali e Flusso Git
1. **Flusso Git (Obbligatorio)**:
   - Creare ed eseguire il checkout sul branch dedicato partendo da `main`: `git checkout -b feature/MiningScavenging main`.
   - Sviluppare il codice, entità, logiche di gioco e test esclusivamente all'interno di tale branch.
   - Al termine dello sviluppo e dopo aver validato con successo i test:
     1. Eseguire il commit di tutte le modifiche: `git add .` e `git commit -m "feat(mining): implementa estrazione mineraria asteroidi e scavenging relitti"`.
     2. Passare al branch `main`: `git checkout main`.
     3. Eseguire il merge del branch completato: `git merge feature/MiningScavenging`.
2. **Posizione File**:
   - `Outside/Mining/mineral_deposit_entity.tscn` e `.gd` (Frammenti e nodi minerali fluttuanti)
   - `Outside/Mining/derelict_ship_entity.tscn` e `.gd` (Relitti esplorabili e scassinabili)
   - `Gameplay/Mining/mining_manager.gd` (Gestione logica frantumazione e spawn risorse)
   - `tests/test_mining_scavenging.gd` (Suite di test headless)

---

## 3. Specifiche Tecniche e Flusso Operativo
1. **Estrazione Mineraria su Asteroidi**:
   - Analisi spettrometrica preliminare su *Sensors* per identificare vene di valore (metalli pesanti, leghe rare, cristalli, ghiaccio d'acqua per Life Support).
   - Frantumazione progressiva: danni laser o cinetici applicati agli asteroidi rilasciano $N$ frammenti minerari fisici.
   - Cattura tramite harpoon/fascio magnetico del *Service Drone* e stivaggio istantaneo nella `Cargo Bay`.
2. **Scavenging e Spoglio di Relitti Derelitti**:
   - Relitti spaziali protetti da serrature elettroniche e residui ICE (scassinabili dall'Hacker).
   - Taglio laser delle paratie esterne tramite *Service Drone* o infiltrazione condotti interni con *Duct Drone*.
   - Recupero moduli integri, registri scatola nera e crediti/FLUX.

---

## 4. Criteri di Accettazione, Test e Chiusura Task
1. **Suite di Test Headless**: Creare ed eseguire `tests/test_mining_scavenging.gd` per verificare:
   - Danneggiamento e generazione procedurale di frammenti minerari dagli asteroidi.
   - Riconoscimento del tipo di risorsa estratta e inserimento corretto in stiva.
   - Meccanica di violazione serrature/ICE sui relitti e raccolta moduli.
2. **Chiusura Git**:
   - [ ] Test headless superati con esito positivo.
   - [ ] Commit di tutte le modifiche su branch `feature/MiningScavenging`.
   - [ ] Checkout su `main` e merge completato del branch.
