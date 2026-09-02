---
sessionId: session-260901-174741-fkyv
---

# Requirements

### Overview & Goals
L'obiettivo di questo intervento è consolidare i risultati del recente refactoring descritti in `docs/analisi_e_refactoring.md` all'interno della documentazione ufficiale del progetto e del contesto per l'agente AI. Questo garantirà che ogni nuova funzionalità o modifica futura segua i nuovi standard di qualità, manutenibilità e scalabilità.

### Scope
- **In Scope**:
    - Aggiornamento di `docs/APP_ARCHITECTURE_STANDARD.md` con le nuove regole mandatorie.
    - Allineamento del contesto Junie (`.junie/context/*.md`) allo stato post-refactoring.
    - Documentazione dell'attività in `docs/task_log.md`.
- **Out of Scope**:
    - Modifiche al codice sorgente (il refactoring è già stato completato).
    - Creazione di nuova documentazione non strettamente legata ai punti menzionati nel file di analisi.

# Technical Design

### Current Implementation
Il progetto ha recentemente subito un profondo refactoring che ha introdotto:
- **`BaseApp.gd`**: Una classe base per tutte le applicazioni GodotOS.
- **Centralizzazione**: Spostamento di enum globali in `GlobalValues.gd` e metadati in `RoomDatabase.gd`.
- **Modularizzazione Manager**: Suddivisione di `SpaceWorldManager` e `NetworkManager` in componenti specializzati (es. `DuctDroneManager`, `CrewManager`).
- **Risorse Tipizzate**: Transizione da `Dictionary` a `Resource` per strutture dati complesse.
- **Addon UI**: Migrazione degli strumenti editor verso una struttura basata su scene `.tscn`.

### Proposed Changes

#### 1. Documentazione Sviluppo (`docs/APP_ARCHITECTURE_STANDARD.md`)
Verranno aggiunte le seguenti direttive mandatorie:
- **Ereditarietà Mandatoria**: Ogni nuova app DEVE ereditare da `BaseApp` (`class_name BaseApp`).
- **Single Responsibility Principle (SRP)**: I nuovi manager devono essere componenti atomici e non script monolitici.
- **Utilizzo di Enum Centralizzati**: Divieto di duplicazione di enum come `Quadrant` o `AlarmLevel`; utilizzo obbligatorio di `GlobalValues`.
- **Tipizzazione Dati**: Obbligo di utilizzo di `Array[ResourceType]` invece di `Array[Dictionary]` per le risorse esportate.
- **UI Addon**: Obbligo di utilizzo di scene `.tscn` per le interfacce degli addon editor.

#### 2. Allineamento Contesto AI (`.junie/context/`)
Aggiornamento dei file di contesto per riflettere la nuova architettura:
- **`data_and_enums.md`**: Aggiornamento puntatori alle nuove posizioni centralizzate.
- **`global_context.md`**: Aggiornamento elenco Autoload e descrizione sub-manager.
- **`applications_context.md`**: Inclusione di `BaseApp` nelle note tecniche.

#### 3. Registro Attività (`docs/task_log.md`)
Aggiunta di un'entry per tracciare questa attività di consolidamento documentale.

### File Structure
- `docs/APP_ARCHITECTURE_STANDARD.md` (Modified)
- `.junie/context/data_and_enums.md` (Modified)
- `.junie/context/global_context.md` (Modified)
- `.junie/context/applications_context.md` (Modified)
- `docs/task_log.md` (Modified)

# Delivery Steps

### ✓ Step 1: Aggiornamento Documentazione Standard Architetturale
Aggiornamento del file `docs/APP_ARCHITECTURE_STANDARD.md` con le nuove direttive.

- Aggiunta della sezione "Linee Guida Post-Refactoring" con i principi mandatori (BaseApp, SRP Managers, Centralizzazione, Risorse Tipizzate).
- Aggiornamento del template dello script GDScript per ereditare da `BaseApp`.
- Inserimento di regole specifiche per lo sviluppo di UI di Addon basate su scene `.tscn`.

### ✓ Step 2: Aggiornamento Contesto per Agenti AI (.junie)
Sincronizzazione dei file di contesto Junie per riflettere lo stato attuale del progetto.

- Aggiornamento di `.junie/context/data_and_enums.md` con le nuove posizioni di enum e metadati.
- Aggiornamento di `.junie/context/global_context.md` con la descrizione della suddivisione dei manager.
- Aggiornamento di `.junie/context/applications_context.md` per includere `BaseApp`.

### ✓ Step 3: Aggiornamento Task Log e Chiusura Task
Documentazione del completamento dell'integrazione delle direttive.

- Aggiunta di un nuovo task nel file `docs/task_log.md` che descrive l'integrazione delle linee guida di refactoring nelle direttive di sviluppo.