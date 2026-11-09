# Downhill Herd implementation

Base: `origin/Matteo`, `cd0e09e2c8daf0ae9215288fbe1bddf6f8d9e038`.
Local branch: `feature/downhill-herd`. Local-only delivery; no remote changes.

1. Inspect the shared simulation and write/run movement and flank-bark tests (RED), then add the dedicated profile and drive (GREEN).
2. Build the slope, physical obstacles, dog/bark, MultiMesh flock and follow camera.
3. Write/run lifecycle tests (RED), implement stable-handle loss/delivery accounting and round completion (GREEN).
4. Add countdown, HUD, pause/results/retry/menu and minimal import reproducibility fixes.
5. Run engine import, real simulation integration and Classic/menu regressions; tune physical split/rejoin and record evidence and profiling limitations.

All five steps completed. Movement/lifecycle/rescue/guidance RED and GREEN outputs,
seven passing headless suites, 20/35/50/100 physical course runs, rendered
35/100 Forward+ profiling, visible edge-loss proof, default-renderer regression,
Classic levels 1–4 evidence, independent review, import fixes and remaining
limitations are recorded in `downhill_herd.md`. Parent difficulty review reduced
automatic lane centering so correct barking improves survival rather than
merely disturbing an already-perfect automatic run.
