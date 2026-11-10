# Downhill Herd - current local handoff

The playable third iteration is documented in [downhill_v3.md](downhill_v3.md), including its bounded plan, all eleven acceptance exercises, exact tuning, changed files, captures and honest verification limitations. [downhill_v2.md](downhill_v2.md) preserves the earlier verified base and its history.

Worktree: `C:/Users/alvar/Desktop/SheepGame-downhill`, branch `feature/downhill-herd-v3`. Changes remain local and uncommitted. Original SheepGame and shared Classic files are unchanged by v3.

Launch this worktree's `project.godot` in Godot 4.7. The ordinary 3D menu offers Downhill Herd, Classic Puzzle and Quit. Downhill loads `scenes/downhill/downhill_level_01.tscn`; Classic starts original level 1. Automated drivers exist only under tests.

WASD moves relative to the camera, Shift sprints, E/left click barks, Space jumps. Short RMB click toggles Herd + dog / Dog follow; drag orbits, wheel zooms, C resets, Esc pauses, R retries from pause/results. Lower-right Pause/Restart and modal Resume/Restart/Main Menu remain available.

Normal sheep/dog walk is 7 m/s; dog sprint is 14. Pads boost 1.6x for two seconds; sheep target/absolute caps remain 12.6/13. Rear fear remains finite and capped at two stacks. Animal boost trails, dog wind, waddle, radial impact hops, contact barrel rolls/sparkles and the grounded barn are mode-local. The HUD safely adapts the Classic packed UI, stars and controls hint without editing those originals.

Parent independently verified all fifteen strict suites outside the worker sandbox: exit 0, no engine/script diagnostics. Editor import, rendered feature/UI/Classic regression, sequential 35/100 full-course drivers, menu boot and a complete 3,600-frame normal scene run also passed. Parent added RED/GREEN regressions for smooth bark-hop interpolation and read-only presentation after sheep delivery. One nonblocking limitation remains: forcibly ending a run during an MP3 cue can report two audio reference leaks at process shutdown; complete-course shutdown is clean. See the authoritative final parent section in v3 for evidence and limits.
