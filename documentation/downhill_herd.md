# Downhill Herd — local playable vertical slice

## Delivery and launch

- Worktree: `C:/Users/alvar/Desktop/SheepGame-downhill`
- Branch: `feature/downhill-herd`
- Base: `origin/Matteo`, `cd0e09e2c8daf0ae9215288fbe1bddf6f8d9e038`, fetched before work.
- `Player` has a newer commit timestamp but lacks the integrated flock/game code; it was not merged.
- Work remains local: no push, merge, or pull request. The original SheepGame checkout stays on `Player` with its two supplied markdown files untouched.
- Required engine: **Godot 4.7 stable**, verified `4.7.stable.official.5b4e0cb0f`.

Open this worktree's `project.godot` with Godot 4.7 and run. The existing 3D menu offers **Downhill Herd**, **Classic Puzzle**, and Quit. Classic starts the original level 1; Downhill starts `res://scenes/downhill/downhill_level_01.tscn`.

Installed-engine command on this machine:

```powershell
$godot = 'C:/Users/alvar/Desktop/SheepGame/.local/Godot-4.7/Godot_v4.7-stable_win64_console.exe'
& $godot --path 'C:/Users/alvar/Desktop/SheepGame-downhill'
```

**Controls:** WASD camera-relative movement; Shift sprint; E or left mouse bark (hold to repeat after cooldown); Space jump; Esc pause/resume; R retry from pause/results. Pause/results also have Retry and Back to Menu buttons. Two-second countdown; falling rescues the dog at a rock-safe checkpoint without changing sheep or score.

**Play hint:** after the central rock, sprint onto the flock's outer world-+X flank (screen-left) before the right-side rock at z=220, and bark inward. Barking while inside the flock can send sheep toward both cliffs.

## Design and reuse

One fixed, hand-authored 300 m route, 24 m wide, descending five degrees along world +Z. Teaching rock at z=76, central splitting rock at z=145, offset hazards at z=220/239, and a broad barn entrance near z=300. Track construction is deterministic; no procedural routes, per-frame rebakes, shops, upgrades or online systems.

Reused: packed-data `BoidSystem`, MultiMesh `BoidPresenter`, flock/cruise/emitter/obstacle influences, spawn API, pen entrance/storage, sheep gait shader, original dog, sheep and barn assets. Sheep are not individual physics-body nodes. Added: a downhill profile/velocity-target influence, analytical slope ground, dog/bark/controller/camera/HUD scripts, scene, tests and portable sheep mesh.

Only the shared simulation change is two additive stable-handle companion signals alongside the unchanged Classic penned/died signal signatures. Gameplay callbacks read stores and queue `request_state`; they never mutate store arrays or remove sheep synchronously. Scores resolve only on committed identified events and use actual spawned handles. `Saved + Lost + Remaining == Initial` holds after every tested tick, including swap removals and duplicate/stale requests.

Solid rocks retain baked avoidance/collision. Downhill disables world-bound clamping and uses analytical void detection rather than heightfield void-walls; sheep can really cross x=±12 and die. Split/rejoin is physical flock motion, never a teleport. Connected-component notices run at 4 Hz with 0.75-second debounce. Unlimited barn storage keeps delivered sheep at their entry positions. Countdown, all-saved/all-lost/mixed, first-arrival grace, hard timeout, pause, results freeze, retry and scene cleanup are covered.

The perspective camera blends flock/dog 65%/35%, looks ahead, damps exponentially, bounds zoom with a 90th-percentile extent and checks terrain/solid occlusion. Exceptional offscreen sheep have directional HUD counts. The dog’s old puzzle camera and proximity emitter are not instantiated in this mode; Q/E rotation cannot conflict with bark.

### Tuning

| Knob | Final value | Location |
|---|---:|---|
| Initial population | 35; Inspector 1..100 | `scripts/downhill/downhill_level_controller.gd` |
| Sheep cruise / dog walk / sprint | 5 / 5 / 10 m/s | downhill profile/drive and dog `WALK_SPEED` |
| Sheep speed cap / acceleration | 6.2 / 16 | `assets/boids_resources/downhill_sheep_behaviour.tres` |
| Simulation / player physics | 30 / 60 Hz | existing system / engine default |
| Drive response / lane gain / lateral cap | 1.6 / **0.04** / 0.6 | `flocking/influence/boid_influence_downhill.gd` |
| Flock perception / separation | 8 / 1.15 m | downhill profile |
| Central rock radius | 4.3 m | `scripts/downhill/downhill_track.gd`, `ROCKS` |
| Bark radius / strength | 7 m / 30 | `scripts/downhill/downhill_bark.gd` |
| Pulse / cooldown | 0.3 / 0.7 s | bark script |
| Camera FOV / lookahead | 62 degrees / 10 m | `scripts/downhill/downhill_camera.gd` |
| Camera distance / elevation ratio | 27..44 m / 1.15 | camera script |
| Countdown / goal grace / hard deadline | 2 / 6 / 95 s | controller exports |
| Stars | 60 / 80 / 95% delivered | controller `stars()` |

Independent gameplay review caught excessive automatic centering: initial lane gain 0.08 saved 35/35 with no input. A failing guidance test was added, then gain reduced to 0.04. Final seeded no-input run saves **28/35**, while inward flank barking saves **35/35** in the guidance fixture and the real moving-dog rendered driver. The fixture positions the emitter to isolate steering; the rendered driver uses actual CharacterBody movement and never overrides sheep transforms/velocities.

## Import and Classic compatibility

Removed the absent/untracked MCP toolkit autoload, used explicit Global/audio-layout resource paths, and removed the menu's eager level PackedScene reference to break a menu→level→Classic-UI→menu load cycle. Classic still accepts its existing explicit `target_level` override.

Blender import is disabled for portable launch. `assets/meshes/sheep_portable.tres` preserves the original edited sheep mesh's geometry, dimensions and UVs, exported with the already-installed Blender 4.5 and extracted through Godot GLTFDocument. White/orange Classic visual resources now reference it; materials, tint, gait and Classic behavior resources are unchanged. Source assets were retained; no global engine/editor settings or credentials were changed.

**Classic regression:** levels 1–4 load and spawn consistent real flocks, retain world bounds and orthographic cameras, and both actual menu buttons navigate correctly. Rendered Classic/menu regression also passes on the default D3D12 Forward+ renderer. Original Classic player/camera/level/scoring scripts are unmodified.

The original standalone `scenes/main.tscn` remains intact as requested; it has a preexisting undefined `CapsuleShape3D_tbgi4` override. Unrelated `minimal_level.tscn` references missing `scripts/results_screen.gd`. These prototypes are outside normal menu flow and are not claimed as working. Small optional populations can naturally choose one central-rock path: the final 20-sheep no-input run did so. Default 35 and stress 50/100 runs demonstrate both streams and physical rejoining; no artificial group assignment was added just to force the 20-sheep case.

## Automated verification

```powershell
# Discovers the installed sibling engine, GODOT environment variable or PATH.
powershell -NoProfile -ExecutionPolicy Bypass -File tests/downhill/run_tests.ps1
# Or pass -Godot <Godot-4.7-executable> and -OutputDirectory <log-directory>.
```

The runner fails on nonzero exit **or engine/script error output**, not merely exit code. It does not override APPDATA/LOCALAPPDATA. On this machine its logs go to `C:/Users/alvar/AppData/Local/hermes/cache/scratch/downhill-tests/`. Individual suites can be run cross-platform with `godot --headless --path . --script res://tests/downhill/<name>_test.gd`.

Seven suites pass:

- **movement:** real no-input forward ticks at configured 5 m/s; both flank barks deflect away within 0.333 s.
- **lifecycle:** all saved/lost, mixed duplicate deaths and slot swaps, stable survivor identities, goal dedup, hard timeout, invariant every tick, results freeze.
- **edge:** rim crossing, exactly one death/removal, harmless duplicate stale requests; solid-rock baking retained.
- **course:** default physical left/right split, rejoin, no rock penetration, complete population resolution. No-input results below.
- **timing:** real countdown release, first-delivery straggler grace, actual sloping CharacterBody travel 5.0013/10.0017 m over one second (commanded speeds exactly 5/10), fall rescue and rock-safe checkpoint.
- **regression:** Classic 1–4, actual mode buttons, pause/resume, retry from pause/fresh score, old emitter/audio/scene release, menu exit, visible bark and scheduled sound.
- **guidance:** doing nothing is not automatically perfect; correctly timed bark improves survival and can earn three stars.

| No-input course population | Saved / lost | Simulated seconds | Result |
|---:|---|---:|---|
| 20 | 15 / 5 | 58.80 | Completes safely through one rock route; no penetration |
| 35 | 28 / 7 | 59.10 | Both streams, split/rejoin, no penetration |
| 50 | 39 / 11 | 59.30 | Both streams, split/rejoin, no penetration |
| 100 | 63 / 37 | 59.60 | Both streams, split/rejoin, no penetration |

### Recorded RED → GREEN checkpoints

- Missing downhill profile: exit 1 → real movement/flank-bark suite exit 0.
- Missing playable lifecycle: exit 1 → lifecycle suite exit 0.
- Rock-adjacent rescue: `TIMING failures=1` → `TIMING failures=0` after safe-position search.
- Meaningful guidance: `GUIDANCE failures=2` (automatic perfect score/no improvement) → `GUIDANCE failures=0`, no-input 28/35 vs guided 35/35, after lane tuning. Parent logs: `downhill-guidance-red.log` and `downhill-tests/downhill-guidance.log` in scratch.

These are actual observed checkpoints, not a claim that every later test assertion was independently written and failed first.

Parent independently reran all suites outside the worker sandbox. Editor `--headless --editor --import --quit` passes with **no errors/warnings**; `git diff --check` passes. Earlier worker-only certificate-store diagnostics were sandbox-related and are absent in final parent runs. No generated `.godot/`, imported-cache churn, screenshots, logs, executables or export intermediates are part of the source change.

## Rendered verification and performance

```powershell
$env:DOWNHILL_OUTPUT_DIR = 'C:/Users/alvar/AppData/Local/hermes/cache/scratch'
& $godot --path . --audio-driver Dummy --log-file "$env:DOWNHILL_OUTPUT_DIR/downhill-profile.log" `
  --script res://tests/downhill/playtest.gd -- 35
# Use 100 for stress. Omit rendering-method override: this profiles default Forward+.
& $godot --path . --audio-driver Dummy --script res://tests/downhill/fall_demo.gd
& $godot --path . --audio-driver Dummy --script res://tests/downhill/regression_test.gd
```

Final measurements: **D3D12 Forward+**, 1280×720, normal VSync, Intel i7-13700H, RTX 4060 Laptop GPU, 15.7 GiB system RAM, Godot 4.7/Jolt. Full-course wall-clock samples exclude the first three running seconds. FPS is measured from actual frame-loop intervals; 1% low is reciprocal mean of the slowest 1% intervals. Screenshot readbacks remain included. Single-machine single-run results, not guarantees or lower-end hardware claims.

| Sheep | Real-dog saved/lost | Mean FPS | 1% low FPS | p99 / worst frame ms | Average draw calls | Boid tick mean / max ms |
|---:|---|---:|---:|---|---:|---|
| 35 | **35 / 0**, 59.00 s | **163.50** | 47.73 | 9.53 / 61.60 | 72.1 | 0.294 / 0.564 |
| 100 | **93 / 7**, 59.70 s | **163.39** | 45.39 | 9.93 / 58.98 | 72.2 | 0.864 / 1.244 |

Each driver run physically split/rejoined and needed zero dog rescues. Sampled camera coverage: dog and live flock within viewport at **100%** of 219/222 quarter-second samples respectively. Screenshot inspection confirms visible streams around the central rock, flank bark ring, readable HUD/results and unobstructed normal framing. This measures geometric screen inclusion, not visibility through occluders or a guarantee for every arbitrary player route. Average FPS exceeds the targets, but isolated ~60 ms stalls and low 1% figures mean **no claim of a stutter-free locked 60 FPS**. Screenshot overhead is included; the precise stall cause was not isolated.

Rendered fall proof passes: `deaths=1 saved=0 lost=1 remaining=0 store=0`, with before/after images. Native background keyboard checks also verified Esc pause and R retry. All rendered runs exited 0 with no engine/script errors.

Final logs: `downhill-final-forward35.log`, `downhill-final-forward100.log`, `downhill-final-fall.log`, `downhill-final-rendered-regression.log` in scratch. Images: `downhill-35-{start,split,bark,results}.png`, analogous 100-sheep images, `downhill-fall-{before,after}.png`, `downhill-menu.png`, `downhill-classic.png`. `DOWNHILL_OUTPUT_DIR` controls captures; otherwise they use the game's user-data capture directory.

## Review and limitations

Implementation used one Codex **gpt-6.1-sol / medium** writer. Free OpenCode **glm-5.3-flash-free** supplied base-risk review and final independent review; no blocking findings in its completed verdict. The orchestrator independently ran engine/tests/rendered checks and corrected difficulty plus test-path portability. The first final-review call timed out; resuming it produced the verdict, rather than treating a timeout as approval.

Remaining: one MVP course with simple geometry; optional 20-sheep population may take only one central path; further difficulty/art polish, real-speaker bark listening, long restart soak and lower-end hardware testing are not completed. Bark playback/VFX are exercised, but automated Dummy-audio runs do not establish subjective sound quality. Two old standalone prototype scenes remain broken as above. No publication, global installations, settings/auth changes or commits to original branches.
