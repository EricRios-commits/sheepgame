# Downhill Challenge v4

Worker implementation baseline: c3b5b42. The historical worker evidence below is followed by the authoritative parent integration and verification report.

1. Add failing release regressions for captured input, Puzzle-first menu, and scoped music; implement and verify.
2. Add HUD/layout/split-transition regressions; simplify presentation and render both resolutions.
3. Add fall lifecycle/transform regressions; implement bounded cosmetic ghosts independent of live boids.
4. Update intentional v3 expectations; run strict suites, fresh import, conflict scan, and Classic capacity/scene chains.
5. Render evidence and sequential 35/100 moving-dog courses; review changes and record exact results and limitations.

Verification results and final controls are recorded below as work completes.

## Delivered behavior

The worker produced local v4 changes on `feature/downhill-herd-v4`, initially at `c3b5b42`. The parent subsequently integrated newer main commits and independently verified the combined tree; see the final report below. The original checkout, authentication/configuration and remote branches were not modified by this iteration.

1. Dog-only camera is the default. Captured no-button mouse-look wraps yaw through 360 degrees; pitch remains 0.4–0.95 radians. Wheel zoom is 12–32 m. RMB **press** switches once. Camera-relative movement remains intact. Obstruction correction shortens the lens ray and also checks its damped position; a tall-blocker RED regression caught the old vertical-only correction. Esc releases/pauses; explicit Resume recaptures. Results/menu/scene exit release. Focus-out pauses/releases and focus-in stays paused until explicit resume.
2. Puzzle Game is first and focused, Downhill Challenge second, Quit third. Actual routed Enter opens Puzzle. Existing title flock and Classic level 1→2→3→4→menu chain remain intact; no preload cycle added.
3. One owned `AudioStreamPlayer` reuses `geoffharvey-fun-on-the-farm-377651.mp3` at -20 dB. It stops inherited Global BGM, plays from countdown, pauses/resumes, loops on completion, stops/nulls its stream at results and exit, and is freed/replaced on retry/menu. Classic music code is untouched. Dummy-backend playback and object lifetimes are asserted; no human audition claim.
4. Gameplay shows Saved, existing saved progress/stars, a camera→dog or camera→dog+sheep geometry icon, and lower-right controls. Old status/course/offscreen counters are hidden and their status computation removed. Split detection retains its 0.5 s debounce; a joined→split edge shows `HERD SPLIT!` for 1.25 s with a short pulse/fade. Continuing split cannot retrigger; rejoin rearms it. Boost/hoop audio/effects do not add event text. Results keep statistics and modal controls.
5. One row beside the keys: `Bark: LMB | Sprint: Shift | Switch view: RMB | Wheel: Zoom`. Font is 18 px at 1280 and 15 px at 960; WASD/jump geometry is reused at 0.62 scale with a lower safe margin. E remains an unadvertised alternate bark; C resets the camera without being advertised.
6. Real sheep are removed/scored by the existing lifecycle. The identified death signal snapshots stable handle, species, physical heading/terrain pose, real mesh scale, airborne height/bounce/spin **before store compaction**. One 100-instance cosmetic batch tumbles about local length Z with heading-aware left/right sign, outward translation and downward acceleration for 0.7 s; alpha fades over the last 0.25 s. It has no collisions, steering, scoring, or saving. Results preserve the last farewell; pause freezes it; expiry and scene exit release it.
7. Main's orange guided state and transitions remain asserted. Classic's real flock reserves all 20 pen spots, walks through the center/spot phases, rejects an extra sheep at the full gate during actual simulation, preserves invariants, and swings both authored doors in opposite directions. Existing gameplay caps, baseline dynamics, and active-guidance advantage remain covered.

## Verification and reproduction

Godot: `C:/Users/alvar/Desktop/SheepGame/.local/Godot-4.7/Godot_v4.7-stable_win64_console.exe`.
Scratch evidence root: `C:/Users/alvar/AppData/Local/hermes/cache/scratch`.

The strict runner now computes its count from 18 suite names (the original 15 plus `release`, `farewell`, `classic_pen`). Camera/interface/release/farewell run in a real rendered window because headless Godot does not provide real capture or GPU instance-transform readback.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/downhill/run_tests.ps1 -OutputDirectory C:/Users/alvar/AppData/Local/hermes/cache/scratch/downhill-v4-worker-tests
```

Strict runner **is not green in this sandbox**: it exits 1 immediately on `Failed to read the root certificate store`, preserved in `downhill-v4-strict-runner.log`. No diagnostics were filtered or suppressed. Parent must rerun outside this sandbox.

Every suite was also executed directly with `--audio-driver Dummy --rendering-method gl_compatibility --log-file <scratch>/downhill-v4-acceptance-NAME.log --add-dir <scratch> --path . --script res://tests/downhill/NAME_test.gd`, adding `--headless` except for the four windowed suites. All 18 reported `failures=0` and exit 0. These are assertion results, not a claim of diagnostic-free engine shutdown. The windowed suites additionally route real viewport mouse clicks through Resume, results Retry, and paused Main Menu, and verify replacement/lifetime/cursor state; the final standalone release log is `downhill-v4-routing-final.log`.

Fresh `--headless --editor --import --path . --log-file <scratch>/downhill-v4-import-final.log --add-dir <scratch> --quit` completed filesystem/class registration with exit 0 and no script parse/compile errors. It reports sandbox-denied Godot editor data/config/cache/user directories, certificate-store access, help-cache and settings writes. This is **not** a clean editor-import claim.

`git diff --check` passes; conflict-marker scan finds none. Git only warns that two edited CRLF files will normalize to LF. No package installations or downloads were used.

Short synchronous fixtures can still report two ObjectDB instances / one resource at shutdown (the known MP3 playback teardown limitation is not claimed fixed). Early farewell readback fixtures also exposed OpenGL texture teardown warnings when freeing uploaded batches before a draw; allowing the actual GPU frame to complete before fixture destruction removed those warnings in the final farewell runs. Complete moving-dog courses and capture runs had no resource/texture teardown warnings, while still reporting sandbox certificate/cache errors.

## Rendered evidence

All files below are under the scratch evidence root, saved successfully and visually inspected:

- `downhill-v4-puzzle-first-menu.png`: real title-screen flock and Puzzle-first order.
- `downhill-v4-dog-hud-1280.png`, `downhill-v4-dog-hud-960.png`: ordinary live player scene after default countdown, no dog driver or camera override.
- `downhill-v4-herd-icon-960.png`: distinct herd+dog mode pictogram and framing.
- `downhill-v4-split-alert.png`: brief split alert (deterministic group-transition fixture).
- `downhill-v4-tumble-left.png`, `downhill-v4-tumble-right.png`: opposite-rim real death/removal, outward local-Z tumble at 0.25 s; dedicated camera shots keep the cosmetic visible.
- `downhill-v4-ui-1280.png`, `downhill-v4-ui-960.png`: real routed GUI pause/resume checks at both resolutions.
- `downhill-v4-35-*.png`, `downhill-v4-100-*.png`: sequential full-course start/pad/airborne/hoop/split/bark/results evidence.

Capture reproduction: run `tests/downhill/release_capture.gd` windowed with the same renderer/audio/path/log/add-dir arguments and `DOWNHILL_OUTPUT_DIR` set to scratch. Full courses use `tests/downhill/playtest.gd -- 35`, then `-- 100`; this driver exists only under tests. Normal project launch remains the manual title screen/game.

Final-source sequential course observations: Windows Compatibility/OpenGL, 1280×720, Dummy audio; i7-13700H / RTX 4060 Laptop GPU. No simultaneous GPU profilers. Figures include capture/readback stalls and are observations on this machine, not hardware guarantees or headless FPS.

| Sheep | Saved / lost | Simulated run | Sampled FPS | 1% low FPS | p99 ms | Max ms | Draw calls avg |
|---|---|---|---|---|---|---|---|
| 35 | 31 / 4 | 39.57 s | 159.23 | 32.42 | 7.33 | 663.78 | 175.5 |
| 100 | 67 / 33 | 39.77 s | 159.04 | 30.63 | 8.66 | 670.92 | 176.1 |

Both reach both split streams and reunion with zero dog rescues and dog visible in 100% of 143 camera samples. Dog-only mode intentionally does not promise flock inclusion; observed flock inclusion (97.83% / 96.14%) is informational. Worker logs: `downhill-v4-final-course35.log`, `downhill-v4-final-course100.log`. Ordinary main-scene boot without a test script also exited 0 in the worker sandbox (`downhill-v4-normal-menu.log`, `--quit-after 180`); this historical exit status does not establish diagnostic-free audio shutdown.

## Final parent integration and verification — November 10, 2026

Integrated actual `origin/main` through **`2c66d2d5ccde996c0120a4a931cf58e177fb5171`**, including `a80f7b9` title music/UI/credits/atlas corrections and `2c66d2d` star-sound counter fix. Integration HEAD is `6993978`; v4 implementation remains local/uncommitted. No v4 push or PR was made. The title flock, upstream pen capacity/door/storage behavior and main's real orange guided state are preserved. Relative to main, shared boid-system changes remain only the five identity-preserving lifecycle signal lines; neighbour queries and separation/alignment/cohesion math are unchanged.

Parent regressions caught and fixed:

- Main's zero-star results logic hid the mode-specific loss heading; the Downhill adapter explicitly restores it when its modal is visible.
- Title music now retains upstream playback but releases only its own stream on scene exit. The real Quit action stops playback and gives the audio mixer 0.1 seconds to release references before shutdown. An actual-button regression reproduced the leak before the fix; five consecutive Forward+ runs were clean afterward.
- Fast manual-simulation fixtures no longer start MP3 playback unless `fixture_audio` explicitly opts in. The audio integration suite opts in; normal gameplay remains audible. The Classic pen fixture releases autoload SFX players before teardown instead of misreporting accelerated-fixture playback as a game leak.

Final commands, run outside the worker sandbox:

```text
python C:/Users/alvar/AppData/Local/hermes/cache/scratch/downhill-v4-parent-verify.py headless
python C:/Users/alvar/AppData/Local/hermes/cache/scratch/downhill-v4-parent-verify.py rendered release farewell classic_pen interface regression camera
```

Results:

- Fresh editor import, **all 19 strict suites**, and `git diff --check`: passed, no engine warnings/errors in the final strict logs. The added nineteenth suite exercises the real title Quit button with live music.
- Forward+/D3D12 rendered release, farewell, Classic pen, interface at 1280×720 and 960×540, Classic level/menu regression and camera suites: all passed without warnings/errors.
- Sequential full moving-dog courses: 35 sheep saved/lost **31/4**, 100 sheep **67/33**; both split/reunite and exercise pads, ramps and hoops with zero dog rescues. Parent sampled FPS **162.74/163.43**, respectively, at 1280×720 on RTX 4060 Laptop GPU; p99 **7.30/8.62 ms**, max **79.55/81.06 ms**, including capture work. These are local measurements, not performance guarantees.
- Final release capture regenerated all seven screenshot artifacts successfully with no warnings/errors. Menu, HUD, camera indicators, split flash and left/right tumbling evidence were inspected.
- A separate **60-second live scene without a dog driver or manual simulation override** reached results at 39.6 seconds (20 saved/15 lost), returned through the real menu transition, verified the old music player was freed, then quit through the title button: exit 0, no warnings/errors. Evidence: `downhill-v4-parent-live-lifecycle.log` and `downhill-v4-parent-final-lifecycle-results.json` in scratch.
- Ordinary real title boot and actual Quit: clean. Latest-main ancestry and conflict-marker checks passed; original `SheepGame` checkout remains untouched apart from the user's two existing untracked brief files.

### Remaining release limitations

- **Forced engine termination while MP3 playback is active still reports shutdown resource warnings.** The deliberately abrupt `--quit-after 3600` direct-scene run exited 0 but reported four ObjectDB instances/two resources; the earlier forced title quit reported two instances/one resource. This is not counted as a clean verification. Normal menu transitions, results/retry and the real Quit path pass; use the actual Quit button rather than forced termination for clean audio shutdown. Window-manager force-close/Stop behavior is not claimed fixed.
- Audio was exercised with Godot's Dummy backend; human listening and subjective mouse/game-feel approval remain manual checks.

Launch: open `C:/Users/alvar/Desktop/SheepGame-downhill/project.godot`, press **F5**, then choose **Downhill Challenge**. Puzzle Game remains the first/default choice.

## Canonical branch publication

At the user's request, this iteration is committed and published under the canonical `feature/downhill-herd` name, superseding the local v4 name and published v3 branch. It includes main through `576281f` (master audio bus lowered by 12 dB). Earlier local/uncommitted statements above describe the pre-publication stage.

Pre-publication verification: fresh editor import and all 19 strict suites passed on rerun, with no warnings/errors in that completed run. The first attempt failed the real-GUI retry lifetime assertion; this intermittent test failure is recorded rather than treated as consistently green. No gameplay changes were made to hide it. The forced-termination audio limitation above still applies.
