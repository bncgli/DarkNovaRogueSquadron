# Terminal System

The Terminal is a core application that provides a CLI interface to the virtual file system and various game systems.

## Structure
- **Applications/Terminal/commands/**: Contains individual command implementations (e.g., `ls`, `cd`, `cat`, `mkdir`, `pod`, `worm`, `decript`, `dataread`).
- **Applications/Terminal/src/script_classes/**: Core logic for parsing input, managing command history, and interacting with the virtual path manager.
- **TerminalDriveManager (Autoload)**: Manages the actual data and hierarchy of the virtual file system.

## Command Implementation
All terminal commands inherit from `terminal_command.gd`. They typically override the `execute` method and optionally `handle_interactive_input` for multi-step interactive commands (such as `worm` and `decript`). When `terminal.active_interactive_command` is set, user inputs are routed directly to the active command.

## Virtual File System
The Terminal uses a virtual file system that is separate from the real host file system, managed by `TerminalDriveManager` and `virtual_path_manager.gd`.
