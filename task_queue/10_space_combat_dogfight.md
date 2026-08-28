# TASK: Sviluppo Modulo "Combattimenti Spaziali, Dogfight e Guerra Tattica Asimmetrica" (`Combat/DogfightTactics`)

## 1. Obiettivo e Panoramica
Sviluppare il sistema di **Combattimento Spaziale Asimmetrico, IA Nemica e Danni Sistemici Localizzati** per *Dark Nova: Rogue Squadron*.
Il modulo gestisce gli ingaggi tattici contro caccia pirata, droni ostili e corvette di pattuglia, integrando la cooperazione asimmetrica tra Pilota (manovre evasive), Soldato (armi e Point-Defense), Ingegnere (bilanciamento scudi a 4 quadranti e gestione danni) e Hacker (guerra elettronica, jamming e iniezioni exploit).

---

## 2. Standard Architetturali e Flusso Git
1. **Flusso Git (Obbligatorio)**:
   - Creare ed eseguire il checkout sul branch dedicato partendo da `main`: `git checkout -b feature/CombatDogfightTactics main`.
   - Sviluppare il codice, IA nemica, gestori di danno e test esclusivamente all'interno di tale branch.
   - Al termine dello sviluppo e dopo aver validato con successo i test:
     1. Eseguire il commit di tutte le modifiche: `git add .` e `git commit -m "feat(combat): implementa combattimento spaziale, IA nemica e danni sistemici"`.
     2. Passare al branch `main`: `git checkout main`.
     3. Eseguire il merge del branch completato: `git merge feature/CombatDogfightTactics`.
2. **Posizione File**:
   - `Outside/Combat/enemy_ship_ai.gd` (IA per caccia pirata e corvette nemiche)
   - `Outside/Combat/combat_director.gd` (Regia degli incontri ostili e spawn ondate)
   - `Outside/Combat/systemic_damage_handler.gd` (Gestione impatti fisici e danni sistemici localizzati)
   - `tests/test_combat_dogfight.gd` (Suite di test headless)

---

## 3. Specifiche Tecniche e Flusso di Combattimento
1. **IA Nemica e Manovre di Ingaggio**:
   - Comportamenti: pattugliamento, inseguimento a sciame (caccia leggeri), bombardamento con siluri e ritirata tattica.
2. **Danni Sistemici Localizzati & Livelli di Allarme**:
   - I proiettili/missili che penetrano gli scudi (`ShieldMatrix`) impattano lo scafo generando guasti specifici: breccia scafo (`dmg_breach`), cortocircuiti elettrici (`PowerGrid`), avaria sensori o focolai d'incendio (`LifeSupport`).
   - Trigger degli stati di allarme diegetici su GodotOS:
     - **Allarme Giallo**: Avaria grave a un sottosistema primario o scudi esauriti su un quadrante.
     - **Allarme Rosso**: Breccia critica, disattivazione reattore o distruzione imminente.
3. **Guerra Elettronica Offensiva / Difensiva**:
   - Possibilità per l'Hacker di disturbare il puntamento nemico tramite jammer (*Comms*) o iniettare firmware exploit per disattivare i motori bersaglio.

---

## 4. Criteri di Accettazione, Test e Chiusura Task
1. **Suite di Test Headless**: Creare ed eseguire `tests/test_combat_dogfight.gd` per verificare:
   - Comportamento ad albero decisionale/state-machine dell'IA nemica in combattimento.
   - Propagazione dei danni localizzati dallo scafo ai rispettivi sottosistemi di bordo.
   - Trigger e propagazione degli stati di Allarme Giallo/Rosso in rete.
2. **Chiusura Git**:
   - [ ] Test headless superati con esito positivo.
   - [ ] Commit di tutte le modifiche su branch `feature/CombatDogfightTactics`.
   - [ ] Checkout su `main` e merge completato del branch.
