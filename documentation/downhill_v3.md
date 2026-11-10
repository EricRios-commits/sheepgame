# Downhill Herd v3

Sole writer; preserved the supplied dirty v2 base. Implementation-stage constraints and results below are historical; publication integration is recorded here.

## Publication integration

At the user's request, committed the complete v2/v3 source as `473d934` on `feature/downhill-herd-v3` and integrated `origin/Matteo` at `5f25ed9`. Resolved title-screen conflicts by preserving both mode buttons, upstream's on-demand Classic scene loading, and its new title-screen flock. Incoming Classic level fixes, remappable inputs, guided-white-sheep behaviour and wrong-barn UI are retained.

Mixed-species Classic levels exposed an upstream missing `guided` behaviour for orange sheep. The global vocabulary includes white sheep's new state, so the behaviour table warns even though orange sheep previously fell back to idle. Added an explicit orange `guided` entry referencing exactly the existing idle influences/speed, without adding transitions or changing flocking calculations. A regression failed before this resource fix and passed afterward.

Post-integration verification: editor import and all fifteen strict suites pass with exit 0 and no engine/script diagnostics; default Forward+ Classic/menu regression, two-resolution interface test and ordinary title-screen boot also pass without diagnostics. No PR or merge into the upstream Matteo/main branch is requested. Earlier no-commit/local-only statements describe development before publication authorization.

## Bounded work plan

1. Run the strict baseline; add and execute RED geometry/boost assertions, then fix arrows, boost response and barn grounding.
2. Execute RED contact/roll assertions; implement an interpolated barrel roll, bounded animal effects and radial soundwave impact hops.
3. Execute RED interface assertions; add dog animation, event-driven wind, camera gestures and a safe Classic UI adapter.
4. Run all original suites plus focused regressions; correct failures without weakening course, guidance, lifecycle or Classic assertions.
5. Inspect rendered feature and finish captures, verify GUI at two resolutions, run sequential default Forward+ 35/100 drivers, import the editor and report environmental limitations.

## Play and exact tuning

Launch the ordinary project menu and choose **Downhill Herd**. Main scene and manual flow are unchanged; drivers live only under `tests/downhill`.

WASD follows the current camera; Shift sprints; E or an unhandled left click barks; Space jumps. A short right click (at most 350 ms, accumulated movement at most 6 px) switches **Herd + dog / Dog follow**. Right drag orbits after 6 px. Wheel zoom and C reset retain their old behavior. Esc pauses; R retries from pause/results. Pause/Restart buttons sit at lower right, with Resume/Restart/Main Menu in the modal. GUI mouse events do not bark or toggle the camera.

- Normal sheep/dog walk remains 7 m/s; dog sprint remains 14 m/s. Pad multiplier is **1.6 for 2 seconds**: normal boosted sheep target 11.2, dog walk/sprint 11.2/22.4. Forward boost response is 8/s, while lateral steering retains 1.6/s. A real normal sheep exceeds 9.8 m/s within 0.5 seconds. Sheep combined target/absolute speed caps remain 12.6/13, below unboosted dog sprint.
- Rear fear remains at most two stacks, 1.5x/1.75x, expiring after 3 seconds. Lateral barks do not add rear fear. Bark range increases from 9 to 10 m; cooldown/pulse remain 0.7/0.3 seconds. The early offset rock moves from x=-4 to x=-7 to retain physical two-stream traversal under the stronger boost. Other rock radii/positions are unchanged.
- Dog gait reuses the Classic parabolic formula: 0.25-second alternating hops at walk, height 0.2, side sway 0.12, local-Z roll 13 degrees; cadence scales with speed, capped at 2.5x. A yaw pivot contains the cosmetic model. Successful bark adds a bounded 0.18 m / 0.3-second visual hop; rejected cooldown input adds none.
- Sheep hop once when the expanding radial soundwave reaches them, including lateral targets. Radius is evaluated at the final pulse tick too. Per-pulse handles prevent repeated impacts; out-of-range sheep do not hop. Bounce is 0.28 m / 0.4 seconds and composes with launch/spin presentation. Physics XZ and packed store arrays are untouched.
- Hoops require an airborne state and a swept forward circular passage. The leading extent comes from the actual portable sheep mesh bounds projected along heading, rather than waiting for the center plane. Local +Z is its length axis. Roll duration is at most 0.45 seconds and shortened against remaining authored airtime. Rotation is around the mesh AABB center, with sampled corner clearance and 0.2 m shader-motion margin. The original interpolated launch endpoints and no-double-lip-height behavior remain.
- One 384-instance MultiMesh holds cyan animal boost wakes and contact sparkles. At most 128 sparkle records, 16 per accepted aggregate burst, 0.06-second burst cooldown, 0.45-second lifetime. Wakes follow only boosted stable handles. One CanvasItem draws peripheral dog boost streaks; unrelated speed cannot trigger them. Both effects freeze during pause, expire, clear on results and are freed on retry/menu.
- Barn grounding uses nested transformed mesh bounds, a 3x3 footprint terrain sample, foundation and sampled approach. Its imported reflected basis is preserved while scaling, and its doorway faces uphill. The finish-angle image shows the entire upright roof, doorway and base above the approach.
- The HUD instantiates `scenes/ui.tscn` and replaces its script with a mode-only UI subclass before tree entry. It reuses Classic gameplay stars, hollow/filled results scenes, callbacks/layout and a subclass of `controls_hint.gd`. Original files/assets are unchanged. Saved percentage drives the stars; a separate 6 px bar shows course progress. Results textures use mode-local expansion/64 px sizing to fit the modal. Finish Attempt/Next Level are hidden, with inert override callbacks. The two camera modes damp smoothly and retain collision checks; dog-only target/distance ignore distant sheep.

## Acceptance evidence

All evidence is under `C:/Users/alvar/AppData/Local/hermes/cache/scratch`, primarily `downhill-v3-worker-tests`. Logs/captures use the `downhill-v3` prefix unless produced by the unchanged strict runner's historical file naming.

| Requirement | Actual exercise |
|---|---|
| 1 Arrow direction | `polish`: all 24 transformed stripe arms assert inner tip Z > outer tip Z; rendered pad capture. |
| 2 Punchy boosts, normal/fear caps | `polish` ticks actual sheep acceleration and dog speeds; original `effects`, `movement`, `timing` retain exact caps, expiry and 7/14 travel checks. |
| 3 Grounded barn | `polish` transforms nested mesh bounds and samples footprint corners; inspected `downhill-v3-finish-barn.png`. |
| 4 Animal pad feedback | `contact` checks actual trail instance uploads, expiry, pause and bounded pool; inspected pad/wind and full-course captures. |
| 5 Dog gait | `contact` checks model apex, alternating sway, local roll and idle/airborne settling; rendered dog waddle/bark fixture. |
| 6 First-contact barrel roll | `contact` checks pre-center onset, airborne gate, fast sweeps, misses, deduplication/later hoops, unchanged local Z axis and every rotated AABB corner against ground. Original `airborne` and `presentation` exercise natural ramps and actual uploaded/render-server poses. Natural rendered capture confirms leading entry before center z=110. |
| 7 Dog wind | `interface` checks event timer, unrelated speed rejection, paused phase and results clearing; inspected peripheral streak geometry. |
| 8 Camera modes | `interface` executes short click, drag, long hold, damped transition, pause/results gating and distant extra-spawn independence; `camera` retains actual wheel/C/orbit-relative D movement and terrain collision probes. |
| 9 Classic UI reuse | `interface` routes real viewport mouse events through GUI at 1280x720 and 960x540, verifies pause/no bark, RMB no toggle, button bounds, slim bars and result star bounds. `regression` executes lower-right retry, Classic results restart/menu callbacks, old-effect cleanup, title menu and Classic levels 1-4. |
| 10 Hoop sparkles | `contact` checks real instance count/lifetime/pause/pool/clear; natural hoop capture shows gold burst at contact. |
| 11 Bark hops | `contact` checks successful/rejected dog hop, no early sheep hop, lateral radial impact, once-per-pulse ledger, out-of-range miss and settling; rendered bark impact fixture. Rear fear remains independently covered by `effects`. |

Retained RED logs: `downhill-v3-red-geometry.log` (26 genuine assertion failures: 24 reversed arms, weak tuning and acceleration), `downhill-v3-red-contact.log` (4), `downhill-v3-red-interface.log` (3), `downhill-v3-red-slimbars.log` (2), `downhill-v3-red-results-layout.log` (2). Parse/API failures encountered while implementing were corrected and rerun; they are not represented as acceptance proof.

The fifteen direct headless suites are movement, lifecycle, edge, course, timing, regression, guidance, effects, airborne, camera, scenery, presentation, polish, contact and interface. Final logs are `downhill-v3-worker-tests/downhill-v3-final-<suite>.log`; each completed with `failures=0`, process exit 0. These are assertion results, **not a clean strict-runner pass**: the sandbox emits a certificate-store engine error in every process.

`run_tests.ps1` still rejects ERROR/SCRIPT ERROR/FAIL and nonzero exits; it adds the three new suites and `--add-dir` without suppressing diagnostics. The requested strict command was executed before and after implementation and exited 1 at `Failed to read the root certificate store`. It needs an independent outside-sandbox rerun. Editor `--headless --editor --import --quit` completed exit 0, registered/imported scripts, but reported denied editor data/config/cache paths and consequent settings-save errors. No global settings were changed to hide these errors.

Rendered default D3D12 Forward+ runs of contact, airborne, camera, presentation, regression, interface and the feature capture fixture completed with zero assertion failures. The last interface run additionally proves 280x6 / 280x12 bars and result-star fit. The normal title boot completed exit 0. Rendered logs retain `Can't create shader cache folder` and the certificate error; no script errors in final successful runs. Screenshots were opened and inspected, including both pause resolutions, pad/wind/waddle, natural hoop roll/sparkles, barn finish angle and results. A real delivery fixture captures correctly contained filled-star results; zero-save results exercise hollow stars.

## Full-course rendered drivers

Sequential 1280x720 default Forward+ on RTX 4060 Laptop GPU / i7-13700H, no sheep transform/simulation overrides, no simultaneous GPU profilers. The driver moves a real CharacterBody dog; its strategy is not optimal. Frame intervals exclude the first three running seconds and include screenshot readbacks.

| Sheep | Saved / lost | Sim s | Mean FPS | 1% low FPS | p99 / worst ms | Mean draw calls | Tick mean / max ms |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 35 | 31 / 4 | 39.57 | 163.86 | 59.48 | 8.58 / 80.26 | 182.1 | 0.546 / 1.360 |
| 100 | 67 / 33 | 39.77 | 163.73 | 55.89 | 9.62 / 82.46 | 183.0 | 1.345 / 3.320 |

35 events: pads 98, launches 65, hoop pairs 43. 100 events: pads 258, launches 166, hoop pairs 105. Both runs reported left/right streams, split/reunion, zero dog rescues and screenshot-save errors=0. Camera inclusion: dog 100% for both; mean live flock 99.26% / 99.43%. Logs `downhill-v3-forward35.log` / `downhill-v3-forward100.log`; captures `downhill-v3-{35,100}-{start,pad,ramp-airborne,hoop-spin,split,bark,results}.png`. Final UI bar/texture-size refinements were verified separately afterward; these measurements precede those tiny HUD refinements, not a new benchmark of them.

No-input/guided fixture retains strict advantage and three-star threshold: **20/35 versus 34/35**, zero rock penetration and actual split/rejoin. This emitter fixture isolates steering; it is distinct from the rendered real-dog driver above. Exact physical dog travel measured 7.0005 / 14.0016 m per second.

## Changed source relative to supplied v2

Modified mode scripts: `downhill_bark`, `downhill_camera`, `downhill_dog`, `downhill_hud`, `downhill_level_controller`, `downhill_motion`, `downhill_presenter`, `downhill_rules`, `downhill_scenery`, `downhill_track`; mode-only `flocking/influence/boid_influence_downhill.gd`.

New mode scripts: `downhill_effects.gd`, `downhill_wind.gd`, `downhill_ui_adapter.gd`, `downhill_controls_hint.gd`, with Godot-generated UID sidecars.

New tests: `polish_test.gd`, `contact_test.gd`, `interface_test.gd`, `feature_capture.gd` plus UIDs. Existing tests changed: airborne (later synthetic passage now explicitly airborne, capture prefix); camera (actual RMB press preceding drag); guidance (loss diagnostics); playtest (v3 prefix); regression (effects cleanup and actual adapter callbacks); scenery (capture prefix); strict runner (three new suites and scratch access). No original assertion was weakened. Documentation: this file and the current handoff pointer. A zip comparison list is retained in `downhill-v3-changed-from-v2.txt`; existing v2 dirty files outside this list remain preserved.

## Reproduce and limitations

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/downhill/run_tests.ps1 -OutputDirectory C:/Users/alvar/AppData/Local/hermes/cache/scratch/downhill-v3-worker-tests
$env:DOWNHILL_OUTPUT_DIR='C:/Users/alvar/AppData/Local/hermes/cache/scratch/downhill-v3-worker-tests'
$godot='C:/Users/alvar/Desktop/SheepGame/.local/Godot-4.7/Godot_v4.7-stable_win64_console.exe'
& $godot --path . --audio-driver Dummy --log-file C:/Users/alvar/AppData/Local/hermes/cache/scratch/downhill-v3-features-rerun.log --add-dir C:/Users/alvar/AppData/Local/hermes/cache/scratch --script res://tests/downhill/feature_capture.gd
# Substitute interface_test.gd for the two-resolution GUI exercise.
# Run playtest.gd -- 35, then only after exit run playtest.gd -- 100.
```

Human speaker audition and subjective mouse/keyboard feel remain unverified; Dummy audio/rendered automation is not such a claim. No lower-end hardware or long-session soak claim. Screen inclusion is not occlusion testing. Engine certificate/cache/editor-directory errors require parent verification outside the sandbox. The strict runner was never relaxed. No commits or original SheepGame changes.

## Final independent parent verification (authoritative)

The worker limitations above are historical: **parent editor import and all fifteen strict suites passed outside the sandbox with exit 0 and no engine/script diagnostics**. Logs: scratch `downhill-v3-parent-import.log`, `downhill-v3-parent-strict.log`, and `downhill-v3-parent-tests/`. Strict verdicts were programmatically counted and checked: fifteen distinct suite names, each `failures=0`. Original Classic source, UI scenes/assets and shared flock core/presenter remain unchanged by this iteration. Original checkout still has only its two supplied markdown files untracked.

Parent review found that bounce presentation was stepping at tick frequency and that its getter recreated cleaned stable-handle state while rendering saved sheep. A new regression in `presentation_test.gd` produced three genuine RED failures (`downhill-v3-parent-bounce-red.log`). The fix interpolates previous/current bounce heights and makes presentation/boost reads non-allocating. All strict suites passed again; rendered presentation also passed. No gameplay velocity or guidance assertions were relaxed.

Independent final rendered contact, airborne, presentation, interface, Classic regression and camera suites exited 0 without diagnostics. The GUI suite exercised 1280x720 and 960x540. `feature_capture.gd` was rerun outside sandbox and its pad/wind/waddle, bark-impact-hop, natural hoop roll/sparkles, grounded-barn and filled-star-results captures were inspected. Parent captures are directly under scratch with `downhill-v3-` prefixes. Ordinary menu boot passed; normal manual-control scene ran for 3,600 frames at a 60 FPS cap and shut down cleanly.

Final sequential default D3D12 Forward+ profiles, 1280x720 on the same RTX 4060 Laptop GPU, retaining screenshot readback stalls:

| Sheep | Saved/lost | Sim seconds | Mean FPS | 1% low FPS | p99/worst ms | Mean draw calls | Tick mean/max ms |
|---:|---|---:|---:|---:|---|---:|---|
| 35 | 31 / 4 | 39.57 | 163.81 | 61.62 | 7.46 / 77.89 | 182.1 | 0.473 / 0.767 |
| 100 | 67 / 33 | 39.77 | 162.75 | 41.34 | 8.96 / 80.15 | 183.0 | 1.266 / 1.778 |

Both runs split/rejoined through both physical streams, with no dog rescues. Events pad/launch/hoop: 98/65/43 and 258/166/105. Dog screen inclusion 100%; mean flock inclusion 99.26%/99.47%. These are imperfect automated real-dog runs, not human scores or occlusion-free framing claims.

**Remaining nonblocking shutdown diagnostic:** forcibly terminating the normal scene at 900 frames can report two leaked audio objects and one resource in use. Verbose reproduction isolated `AudioStreamMP3` (`audio/sfx/star/star_2.mp3`) and `AudioStreamPlaybackMP3` during the active hoop cue, not sheep/effect nodes. One verbose repeat was clean, subsequent normal/verbose repeats reproduced it. The 3,600-frame complete run and normal menu/test shutdowns are clean. Do not claim every forced mid-play exit is diagnostic-free; no speculative audio-engine workaround was applied. Human speaker audition/subjective feel and lower-end/soak checks remain outstanding.

Evidence aggregation: `downhill-v3-parent-verification-summary.json`; rendered logs `downhill-v3-parent-{contact,airborne,presentation,interface,regression,camera,profile35,profile100,menu,manual-complete}.log`; forced-shutdown verbose logs retain the diagnostic. Scope comparison against preserved v2: `downhill-v3-parent-scope.json`; v2 source backup: `downhill-v2-before-v3.zip`. No commit, push, merge or PR.
