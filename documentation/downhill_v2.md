# Downhill Herd v2

Local, uncommitted implementation on `feature/downhill-herd-v2`, based on `29ccc7d7df6de5944ec2b1d38972b8124b61c7c3`. One writer, no nested agents, installs, downloads, configuration/auth changes, commits, pushes or PRs. Original checkout untouched.

## Play

Run this worktree in Godot 4.7 and choose Downhill Herd in the existing menu, or run `res://scenes/downhill/downhill_level_01.tscn`. Classic still starts its original level 1.

WASD moves relative to the actual perspective camera; Shift sprints; E/left click barks; Space jumps. Right mouse drag orbits, wheel zooms, C resets the view. Esc pauses/resumes; R retries from pause/results. Retry and Back to Menu buttons remain available. Two-second countdown, dog rescue, stable sheep outcomes, stars, bounded arrival grace and hard timeout remain functional.

Sprint to the outer right flank after the central split and bark inward before the offset rock at z=220. A rear bark hurries only sheep ahead and within range. The automatic rendered driver is an imperfect real CharacterBody player, not an optimal strategy or a human playtest.

## Rules and motion

`scripts/downhill/downhill_rules.gd` centralizes mode tuning: width 36 m, cruise and dog walk 7 m/s, dog sprint exactly 14 m/s. Rear-bark fear requires `relative_z > abs(relative_x)` within bark radius. First and second stacks target 1.5x/1.75x cruise; further barks refresh a three-second expiry without adding stacks. Sideways barks retain emitter flee steering. Bark radius/strength are retuned to 9 m/40 for the wider course.

Four cyan chevron pad areas give a 1.3x boost for two seconds on entry. Per-handle pad membership debounces sheep; dog membership debounces dog boosts and preserves walk:sprint 1:2 (9.1/18.2 boosted). Combined sheep targets cap at 12.6; the downhill behavior caps actual horizontal speed at 13, below unboosted sprint 14. Dynamic downhill target steering replaces the contradictory fixed Cruise influence; rock, emitter and flock steering remain active. No global time scaling or Classic profile changes.

`downhill_motion.gd` owns fear, pad, arc, spin and per-hoop hit state by generation-bearing stable handle. Gameplay callbacks never write store arrays. Death and pen commits erase state; penned sheep remaining in the shared active storage prefix are explicitly excluded. Retry creates a fresh service. Tests caught and fixed this distinction rather than assuming every saved sheep was frozen by the shared system.

Ramps at z=98..104 and 258..264 are 12 m wide with a 1.8 m launch lip. Sheep follow a finite continuous vertical arc `max(0, 1.8 + 5t - 6t²)` above sampled terrain after the lip. Their XZ simulation, obstacle avoidance and grouping stay packed. Hoops at z=110/270 test swept forward 3D plane crossings and a circular 2.6 m radius, using the same world-position function as the presenter. A per-handle/per-hoop ledger awards once, permits later hoops and starts a full 0.8-second somersault. Off-height and outside-radius crossings miss.

`downhill_presenter.gd` calls the shared presenter then adds mode-only vertical offsets and rotates the actual STRIDE20 transform basis. It disables engine physics interpolation on every actual MultiMeshInstance3D batch; the shared presenter still performs its own interpolation. No shared presenter rewrite or per-sheep physics nodes. Rendered tests read the resulting RenderingServer-backed MultiMesh transform; headless tests inspect the upload buffer because dummy-renderer transform getters return identity.

## Course and presentation

The analytic ground samples a five-degree descent with longitudinal undulation, lateral unevenness and varying bank. A one-meter triangle mesh and matching dog trimesh collision sample that function; separate collidable ramp wedges preserve real launch lips. Collision probes agree within 2 cm at opposite sides and both ramps. The 18 m half-width is shared by terrain, validity, rim markers, rescue bounds, bake bounds and finish mouth. Rim posts are visual markings, never walls. Decorative cliffs/mountains/trees have no ground collision beyond the rim.

The center rock grows from radius 4.3 to 6 m for real two-stream traversal. Offset hazards and stronger bark preserve a meaningful survival difference. Split/rejoin notices use connected components with a 0.5 s debounce, shortened for faster travel. Actual left/right trajectories and collision clearance are tested independently of HUD notices.

Terrain has a softly worn center, green shoulders, vertical cliff faces, seeded rim grass/pebbles, replaceable low-poly pine canopy placeholders outside the lanes, and broad parallax mountain geometry. Repeated details are MultiMeshes generated once. A texture-free sky shader combines distant ridges and two inexpensive noise octaves for drifting clouds, with warm sun, ambient sky color and distance fog. The camera mostly looks downhill, so sky/cloud coverage varies with orbit. This remains a stylized procedural course, not final environment art.

The camera starts at distance 18 m and about 13 m elevation relative to focus, FOV 70; extent-based framing can extend to 36 m. Orbit is bounded to ±0.8 rad yaw and 0.4..0.95 rad pitch, user zoom 12..32 m, C resets. Focus and position damp smoothly; terrain/solid ray checks exclude the dog RID. The forward view shows upcoming course hazards beyond two seconds of cruise. No motion blur or dynamic FOV changes. Sky built-ins were checked against the [official Godot sky shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/sky_shader.html).

Mode-owned audio reuses `star_1/2/3.mp3` for pads/hoops/results and `universfield-sheep-bleat-122256.mp3` for bark response, alongside the existing synthesized bark. A 0.4-second shared feedback cooldown avoids 35 simultaneous voices; feedback uses a pausable player at -15 dB. Fast manual simulation fixtures suppress feedback playback, while rendered tests exercise it. No Classic AudioManager mutation or new BGM. Dummy playback is not a human sound audition.

## Verification and evidence

Engine: sibling `C:/Users/alvar/Desktop/SheepGame/.local/Godot-4.7/Godot_v4.7-stable_win64_console.exe`, Godot 4.7 stable. All logs/captures are in `C:/Users/alvar/AppData/Local/hermes/cache/scratch/`, prefixed `downhill-v2-`, except reused fall capture names `downhill-fall-{before,after}.png`.

Actual RED: `downhill-v2-red-effects-engine.log` reports missing stable-handle service; `downhill-v2-red-airborne-engine.log` reports missing continuous launch/swept-hoop service. Both exited 1 before implementation. Later checks caught reversed terrain collision winding (dog fell through), a headless dummy-transform getter limitation, and penned-state recreation; all received real GREEN reruns. Initial commands without a writable log path crashed during engine startup; explicit scratch `--log-file` resolved that startup problem.

Run the strict suite:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/downhill/run_tests.ps1
```

The final runner includes twelve suites and rejects engine/script error output. **Parent independently reran it outside the worker sandbox: all twelve passed, exit 0.** Earlier worker-only certificate-store/shader-cache diagnostics did not recur. Final parent evidence and tuning below supersede the historical worker measurements in this document.

```powershell
$godot = 'C:/Users/alvar/Desktop/SheepGame/.local/Godot-4.7/Godot_v4.7-stable_win64_console.exe'
$out = 'C:/Users/alvar/AppData/Local/hermes/cache/scratch'
& $godot --headless --rendering-method gl_compatibility --audio-driver Dummy --path . `
  --log-file "$out/downhill-v2-effects-engine.log" --script res://tests/downhill/effects_test.gd
# Substitute movement/lifecycle/edge/course/timing/regression/guidance/airborne/camera.
$env:DOWNHILL_OUTPUT_DIR = $out
& $godot --path . --audio-driver Dummy --log-file "$out/downhill-v2-forward35.log" `
  --script res://tests/downhill/playtest.gd -- 35
# Run 100 only after 35 exits. No renderer override: default D3D12 Forward+.
& $godot --path . --audio-driver Dummy --log-file "$out/downhill-v2-direct.log" `
  res://scenes/downhill/downhill_level_01.tscn --quit-after 3600
```

Ten assertion suites: movement; lifecycle; new-rim edge/death identity; physical course split/rejoin and no rock penetration; real dog timing/ramp/jump/rescue; Classic 1–4/menu/pause/retry; meaningful guidance; fear/pad effects; 3D airborne/pose/hoop lifecycle; camera input/collision. Each final suite reports `failures=0`. Actual dog horizontal travel is 7.0005/14.0016 m over one second. Edge crossing dies once at x=18.377, removes the stable handle, cannot later save. Default no-input course saves 20/35 versus guided fixture 34/35 (three stars), with unchanged strict improvement/three-star assertions. Guided fixture positions an emitter; rendered driver separately moves the real dog without sheep transform/velocity edits.

Rendered `camera`, `airborne`, and `regression` suites also report zero failures on default Forward+. `downhill-v2-pose-rendered.png` shows the airborne rotated sheep; the test also compares actual rendering-server transforms. Normal direct-scene run has no MultiMesh interpolation warnings. Rendered rim demo confirms exactly one death/loss/removal with no saved sheep. No sound-listening claim.

## Rendered measurements

Sequential runs, 1280×720, default D3D12 Forward+, normal VSync, RTX 4060 Laptop GPU, i7-13700H. Actual frame intervals exclude the first three running seconds, retain screenshot readbacks; 1% low is reciprocal mean of slowest 1% intervals. Headless execution is not used for FPS claims. The simple driver can lose sheep and is not an optimal-score test.

| Sheep | Saved/lost | Sim seconds | Mean FPS | 1% low FPS | p99/worst frame ms | Avg draw calls | Tick mean/max ms |
|---:|---|---:|---:|---:|---|---:|---|
| 35 | 30 / 5 | 40.70 | 163.71 | 56.14 | 7.74 / 82.49 | 126.0 | 0.537 / 1.225 |
| 100 | 79 / 21 | 42.37 | 163.59 | 53.82 | 8.93 / 86.13 | 126.3 | 1.277 / 2.516 |

Both runs report physical left/right streams, split/rejoin, zero dog rescues and zero screenshot save errors. 35-sheep events: 96 pad entries, 63 launches, 38 hoop passages; 100-sheep events: 263 entries, 169 launches, 76 passages. Passages count sheep/hoop pairs, not unique sheep. Camera screen inclusion uses actual airborne world positions: dog 100% for both; mean live flock 99.85% across 148 samples / 99.21% across 154 samples. Runtime logs contain only the two restricted-environment diagnostics above; no script errors, interpolation warnings or leaked-resource shutdown errors in these profiles. A final local correction prevents double-counting the ramp lip height on the first interpolated airborne frame; dedicated headless and rendered pose tests were rerun afterward, rather than representing these profiles as a new benchmark of that tiny interpolation correction. The strict runner was actually invoked and exited 1 at the certificate-store diagnostic; it was not relaxed to turn this green.

Captures: `downhill-v2-{35,100}-{start,pad,ramp-airborne,hoop-spin,split,bark,results}.png`. The driver waits for a nonzero airborne spin angle before taking its final hoop-spin capture. Frame-based camera coverage measures screen inclusion, not visibility through rocks or guaranteed framing for arbitrary play. The 90th-percentile adaptive extent intentionally permits exceptional stragglers; HUD offscreen counts remain available.

## Remaining review scope

Human speaker audition and mouse/keyboard usability remain unverified. Rendered tests exercise input events and actual collision/pose, but are not a human usability session. Procedural pines and mountains are replaceable art, one authored route remains, and full long-session restart soak/lower-end hardware testing is outstanding. Isolated long frames mean this is not a stutter-free locked-60 claim. No generated caches, logs, screenshots, binaries or imported asset churn belong in the local diff.

## Final parent review and verification (authoritative)

- Added a continuous seeded FastNoiseLite valley beyond the cliff strips, with no collider or flock-ground coverage. Falling remains fatal. Trees now sit against sampled valley height.
- Camera default/reset pitch is 0.46 radians, rather than the earlier 0.63; sky fog influence is 0.15. Three-octave clouds and a cheap realtime cubemap branch make the procedural backdrop readable in the default view. Earlier approximate camera elevation and two-octave descriptions above refer to the worker version.
- Grounded the countdown dog spawn. Interpolated physical height endpoints and full-turn somersault angles in the mode presenter instead of stepping them at simulation frequency; shared presenter/core unchanged.
- Added RED/GREEN scenery and presentation suites. Strict runner now passes twelve suites: original ten plus deterministic/noncollidable scenery and interpolated launch/spin presentation.
- Independent default-Forward+ camera, airborne, presentation, scenery and Classic 1–4 regression runs exited 0 without warnings/errors. Rendered fall demo: exactly one death/loss/removal, no save. Normal direct scene: 3,600 frames at a 60 FPS cap, exit 0 without diagnostics. Rendered sky horizontal variation measured 0.1725.
- Bounded independent OpenCode review (`opencode/glm-5.3-flash-free`) returned no blocking findings. Changed-source secret/unsafe-execution pattern scan found no hits; `git diff --check` passed.
- Final editor import and ordinary menu boot both exited 0 without warnings/errors; all twelve strict suites passed again afterward. New script/shader `.uid` sidecars were generated by Godot import and retained as source resource identifiers. Original checkout remains on Player with only its two supplied markdown files untracked.

Final sequential 1280×720 D3D12 Forward+ profiles on the same RTX 4060 Laptop GPU, retaining screenshot readback stalls:

| Sheep | Saved/lost | Sim seconds | Mean FPS | 1% low FPS | p99/worst ms | Mean draw calls | Tick mean/max ms |
|---:|---|---:|---:|---:|---|---:|---|
| 35 | 30 / 5 | 40.70 | 163.18 | 46.62 | 7.34 / 78.64 | 134.5 | 0.447 / 1.103 |
| 100 | 79 / 21 | 42.37 | 162.85 | 44.11 | 8.73 / 84.20 | 134.2 | 1.229 / 1.795 |

Both runs physically split/rejoined, with zero dog rescues. Pad/launch/hoop counts: 96/63/39 for 35 sheep and 262/168/76 for 100. Dog screen inclusion 100%; mean live-flock screen inclusion 99.53%/98.53%. Screen inclusion does not establish occlusion-free visibility. Real dog driver is not an optimal-score or human playtest.

Authoritative logs under scratch: `downhill-v2-parent-{profile35,profile100,camera,airborne,presentation,scenery,regression,fall,normal-direct}.log`; aggregation `downhill-v2-parent-rendered-results.json`; strict suites under `downhill-v2-parent-tests/`. Final captures retain `downhill-v2-{35,100}-*.png` names and `downhill-v2-scenery-proof.png`. Changes remain local and uncommitted; no push/merge/PR.
