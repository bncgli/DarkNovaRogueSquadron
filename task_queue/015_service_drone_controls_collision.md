# TASK-027: Service Drone 3D Collision Physics & Rotation Controls

## Descrizione
Implementazione della fisica delle collisioni 3D per il drone di servizio EVA (`ServiceDroneEntity`) e introduzione del controllo di rotazione da tastiera tramite tasti freccia (pitch e yaw), allineando il modello di pilotaggio a quello di `FlightControl`.

## Obiettivi
- Dotare il drone di servizio di un collider 3D solido e logica di collisione per interagire fisicamente con lo scafo della nave, asteroidi, relitti e stazioni.
- Aggiungere il controllo di rotazione su se stesso nell'app `ServiceDrone` mappato sui tasti freccia (Freccia Su/Giù per Pitch, Freccia Sinistra/Destra per Yaw).

## Criteri di Accettazione
- [x] **Collider e Fisica 3D**:
  - [x] `ServiceDroneEntity` include un `CollisionShape3D` con opportuno shape volumetrico (es. `BoxShape3D` compatibile con il modello di dimensioni 0.7m x 0.35m x 0.9m).
  - [x] Il movimento del drone utilizza `CharacterBody3D` o `move_and_collide` / `move_and_slide`, impedendo la compenetrazione di pareti della nave, rocce e strutture spaziali esterne.
- [x] **Controlli di Rotazione con Tasti Freccia**:
  - [x] `KEY_LEFT` (Freccia Sinistra): Ruota il drone verso sinistra (Yaw antiorario).
  - [x] `KEY_RIGHT` (Freccia Destra): Ruota il drone verso destra (Yaw orario).
  - [x] `KEY_UP` (Freccia Su): Inclina il muso del drone verso l'alto (Pitch positivo).
  - [x] `KEY_DOWN` (Freccia Giù): Inclina il muso del drone verso il basso (Pitch negativo).
  - [x] La rotazione deve essere fluida con accelerazione e smorzamento angolare diegetico.

## Dettagli Tecnici
- **File coinvolti**:
  - `Outside/ServiceDrone/service_drone_entity.tscn`: Conversione radice a `CharacterBody3D` (o aggiunta di `CollisionShape3D` e maschere di collisione).
  - `Outside/ServiceDrone/service_drone_entity.gd`:
    - Integrazione di `current_angular_velocity` e applicazione delle rotazioni su base locale (`rotate_object_local`).
    - Gestione del movimento fisico tramite `move_and_slide()` o test di collisione lineare.
  - `Applications/ServiceDrone/service_drone_app.gd`:
    - Metodo `_input(event: InputEvent)` (linee 175-223): aggiunta dei casi per `KEY_UP`, `KEY_DOWN`, `KEY_LEFT`, `KEY_RIGHT` nel mapping di `_manual_angular_input`.

## Step by Step Implementation
1. **Configurazione Collider e Scena in `Outside/ServiceDrone/service_drone_entity.tscn`**:
   - Modificare il nodo radice in `CharacterBody3D` (oppure `RigidBody3D`/`AnimatableBody3D`).
   - Aggiungere un nodo figlio `CollisionShape3D` denominato `CollisionShape3D`.
   - Assegnare una risorsa `BoxShape3D` con estensione proporzionata al `BodyMesh` (`size = Vector3(0.7, 0.35, 0.9)`).
   - Impostare `collision_layer` e `collision_mask` per intercettare gli strati fisici dello scafo nave, asteroidi e strutture.
2. **Logica di Rotazione e Movimento Fisico in `Outside/ServiceDrone/service_drone_entity.gd`**:
   - In `_physics_process(delta: float)`:
     - Applicare la spinta angolare: `current_angular_velocity.y = lerpf(current_angular_velocity.y, input_rot.y * max_rot_speed, angular_accel * delta)`.
     - `current_angular_velocity.x = lerpf(current_angular_velocity.x, input_rot.x * max_rot_speed, angular_accel * delta)`.
     - Applicare le rotazioni relative: `rotate_object_local(Vector3.UP, current_angular_velocity.y * delta)` e `rotate_object_local(Vector3.RIGHT, current_angular_velocity.x * delta)`.
     - Per il movimento lineare: calcolare `velocity = current_linear_velocity` e invocare `move_and_slide()` per gestire rimbalzi e arresti contro ostacoli solidi.
3. **Mappatura Tasti Freccia in `Applications/ServiceDrone/service_drone_app.gd`**:
   - Nella funzione `_input(event: InputEvent)` (linee 180-222):
     - Aggiungere i match per:
       - `KEY_UP`: `_manual_angular_input.x = 1.0 if pressed else 0.0; handled = true`
       - `KEY_DOWN`: `_manual_angular_input.x = -1.0 if pressed else 0.0; handled = true`
       - `KEY_LEFT`: `_manual_angular_input.y = 1.0 if pressed else 0.0; handled = true`
       - `KEY_RIGHT`: `_manual_angular_input.y = -1.0 if pressed else 0.0; handled = true`
     - All'avvenuta modifica, chiamare `_send_thruster_inputs()` per trasmettere i vettori aggiornati all'entità 3D.
