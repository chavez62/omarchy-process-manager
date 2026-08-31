# Omarchy Process Manager

A native, theme-aware process manager for the Omarchy Quattro bar. Inspect live CPU and memory use, search and sort processes, and safely control processes owned by your user without leaving the shell.

## Features

- Live interval CPU and resident-memory usage
- Search by process name, command, or PID
- Sort by CPU, memory, name, or PID
- Pause (`SIGSTOP`) and resume (`SIGCONT`)
- Graceful termination (`SIGTERM`)
- Two-click hard-kill confirmation (`SIGKILL`)
- Lower process priority by increasing its nice value
- PID start-time checks before every action to prevent acting on a reused PID
- Protection for the Omarchy/Quickshell host process
- Polling only while the panel is open

Only processes owned by the current user are shown or controlled. The plugin never uses `sudo`, `pkexec`, network access, telemetry, or external services.

## Requirements

- Omarchy 4 (Quattro)
- Python 3, included with Omarchy
- Linux `/proc`

## Install

```sh
omarchy plugin add https://github.com/chavez62/omarchy-process-manager.git --enable
```

The widget is placed in the right section by default. Move it explicitly with:

```sh
omarchy bar move io.github.chavez62.process-manager --section right
```

## Use

Click the chip icon to open the panel. Select a process, then use the action buttons:

- Pause/resume changes the process execution state.
- Terminate asks the process to exit cleanly.
- Kill sends `SIGKILL` and requires a second click within 3.5 seconds.
- The minus control increases the nice value, lowering CPU scheduling priority; Apply commits it.

The plugin intentionally does not request permission to raise process priority or control another user's processes.

## Safety model

Actions are executed by the bundled `processctl` helper. Before signaling a process it verifies:

1. the PID is still owned by the current user;
2. the PID still has the same kernel start time shown in the panel;
3. the target is not PID 1, the helper, its parent, `omarchy-shell`, or Quickshell.

Third-party Omarchy plugins run unsandboxed with your user permissions. Review the source before installing.

## Development

```sh
omarchy plugin validate .
python3 -m unittest discover -s tests -v
```

When `qmllint` is installed:

```sh
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml ProcessService.qml
```

## Remove

```sh
omarchy plugin remove io.github.chavez62.process-manager
```

No persistent configuration is created. A small CPU-sampling state file in `$XDG_RUNTIME_DIR` is automatically discarded at logout.

## License

MIT
