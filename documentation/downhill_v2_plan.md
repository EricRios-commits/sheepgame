# Downhill v2 implementation plan

1. Read mode, simulation, presenter and regression fixtures; establish RED speed/effects and airborne tests.
2. Implement shared rules and stable-handle fear, pads, launch arcs, swept hoops and spin presentation.
3. Build sampled collision terrain, ramps, readable course features and seeded mountain scenery; integrate scoped audio.
4. Add bounded close chase orbit/zoom/reset and camera-relative driver/HUD controls.
5. Retune and run lifecycle, edge, split, guidance, Classic and new v2 suites; fix actual failures.
6. Run normal scene and sequential rendered 35/100 drivers; inspect captures and document measured results and gaps.

All edits local and uncommitted. One writer. Verification evidence and final tuning go in downhill_v2.md.

Completed: all six steps plus parent camera/valley/fog and height/spin interpolation polish. Actual RED failures preceded fixes. Parent strict runner passes all twelve suites outside sandbox; default-renderer camera/airborne/presentation/scenery/Classic tests, fall demo, sequential 35/100 profiles and normal direct-scene run pass without diagnostics. Captures inspected and independent OpenCode review reports no blocking findings. Human audio/usability audition and lower-end/long-session checks remain explicit limitations in downhill_v2.md. Local and uncommitted; no push/merge.
