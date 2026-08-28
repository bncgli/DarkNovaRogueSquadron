#!/usr/bin/env python3
"""
Script di automazione per eseguire sequenzialmente i task di sviluppo tramite Claude Code CLI.
Ogni task viene eseguito in un processo separato per garantire il reset completo del contesto (azzeramento memoria conversazione).
"""

import sys
import subprocess
from pathlib import Path

def main():
    # Cerca la cartella dei task (supporta sia task_queue che tasks_queue)
    queue_dir = Path("task_queue")
    if not queue_dir.exists() and Path("tasks_queue").exists():
        queue_dir = Path("tasks_queue")
    
    if not queue_dir.exists():
        print(f"[ERRORE] Cartella '{queue_dir}' non trovata!", file=sys.stderr)
        sys.exit(1)

    tasks = sorted(queue_dir.glob("*.md"))
    
    if not tasks:
        print(f"[ATTENZIONE] Nessun file .md trovato in '{queue_dir}'.")
        return

    print(f"=== Trovati {len(tasks)} task da eseguire con Claude Code ===")
    
    for idx, task in enumerate(tasks, 1):
        print(f"\n[{idx}/{len(tasks)}] ========================================")
        print(f"Avvio esecuzione task: {task.name}...")
        print("==================================================")
        
        prompt = task.read_text(encoding="utf-8")
        
        # Invocazione di Claude Code CLI
        # -p / --print esegue il prompt fornito in modalità non-interattiva
        # --dangerously-skip-permissions consente l'esecuzione autonoma dei tool senza richiedere conferme manuali
        cmd = [
            "claude",
            "-p", prompt,
            "--dangerously-skip-permissions"
        ]
        
        try:
            result = subprocess.run(cmd, check=True)
            print(f"\n[OK] Task completato con successo: {task.name}")
        except subprocess.CalledProcessError as e:
            print(f"\n[ERRORE] Il task '{task.name}' è fallito con codice di uscita {e.returncode}.", file=sys.stderr)
            scelta = input("Vuoi continuare con il prossimo task? [s/N]: ").strip().lower()
            if scelta != 's':
                print("Interruzione esecuzione pipeline.")
                sys.exit(e.returncode)
        except FileNotFoundError:
            print("\n[ERRORE] Il comando 'claude' non è stato trovato nel PATH di sistema.", file=sys.stderr)
            print("Assicurati di aver installato Claude Code CLI (`npm install -g @anthropic-ai/claude-code`).")
            sys.exit(1)

    print("\n=== Tutti i task della coda sono stati completati! ===")

if __name__ == "__main__":
    main()
