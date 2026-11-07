# Progress

## Phase 1 — Foundations
- Project (`project.godot`), autoloads: `Bus` (signal bus), `Cfg` (tuning/feel resources), `Assets` (central sprite map with SubViewport baking + PNG override), `Audio` (stub), `App` (settings, args, meta).
- `data/tuning.tres` and `data/game_feel.tres` with all numbers for player, dash, input, aim, cast, weapons and feel.
- Simulation core `sim/sim.gd` (fixed step, hit-stop budget, slow motion, arena collision with walls/pillars, queries), `SimPlayer` + `PlayerCtl` (acceleration movement, dash with i-frames/charges/cooldown/exit slide, 150 ms buffering, mouse/stick/auto aim with snap), `InputFrame`.
- Presentation: `GameView` (device → InputFrame, 60 Hz stepping, interpolation), `WorldView` (floor, y-sorted sprites with hit-flash shader, layers), procedural floor per depth, follow camera with lookahead, trauma shake, kick spring and zoom punch.
- Procedural Wren + weapon sprites baked at startup.
- `tools/check_all.gd` (Logger-based, catches parse errors), `tests/run_tests.gd` + `tests/test_player.gd` (dash i-frames, distance, charges/cooldown, buffer window, acceleration, walls), `tools/ci.sh`.
