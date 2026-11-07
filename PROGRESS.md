# Progress

## Phase 1 — Foundations
- Project (`project.godot`), autoloads: `Bus` (signal bus), `Cfg` (tuning/feel resources), `Assets` (central sprite map with SubViewport baking + PNG override), `Audio` (stub), `App` (settings, args, meta).
- `data/tuning.tres` and `data/game_feel.tres` with all numbers for player, dash, input, aim, cast, weapons and feel.
- Simulation core `sim/sim.gd` (fixed step, hit-stop budget, slow motion, arena collision with walls/pillars, queries), `SimPlayer` + `PlayerCtl` (acceleration movement, dash with i-frames/charges/cooldown/exit slide, 150 ms buffering, mouse/stick/auto aim with snap), `InputFrame`.
- Presentation: `GameView` (device → InputFrame, 60 Hz stepping, interpolation), `WorldView` (floor, y-sorted sprites with hit-flash shader, layers), procedural floor per depth, follow camera with lookahead, trauma shake, kick spring and zoom punch.
- Procedural Wren + weapon sprites baked at startup.
- `tools/check_all.gd` (Logger-based, catches parse errors), `tests/run_tests.gd` + `tests/test_player.gd` (dash i-frames, distance, charges/cooldown, buffer window, acceleration, walls), `tools/ci.sh`.

## Phase 2 — Combat core and juice
- Hit pipeline `sim/combat.gd`: damage multipliers, crits, shields, armor (armor break), knockback by mass, hitstun, counters, finishers, kills, drops, wall slams, kill streaks, Overdrive meter, Sigil, defiance/death.
- Weapons (`sim/weapons/`): shared melee combo state machine from frame data + Kestrel Fangs (backstab, knife fan), Moonreach (tip crits, channelled whirl), Anvilheart (armor break, charged fissure), Vesper Bow (quick shots, volleys, charged/perfect release, starfall), Sunwheel Halo (out-and-back chakram, apex grind, orbit). Each has a dash-attack, 3 forges and an Overdrive-empowered Special.
- Projectiles, floor hazards (player blasts/fields/lines, enemy fields with warning pulses), pickups with room-clear magnet, status effect base (Burn, Chill/Freeze, Hex, Bleed, Mark, Jolt).
- FX (`render/fx_view.gd`): packed particle system (sparks, shards, embers, smoke), fading floor decals, swing trails, dash ghosts, lightning, rings, merging damage numbers (pop-in, crit shake, status orange), callouts, camera trauma/kick per hit; FX run at 12 % during hit-stop.
- Training room with dummies (keys 1–5 swap weapons).
- Tests: frame data presence, combo timing and reset, 4-step chaining, dash-cancel of recovery, dash-attack window, every weapon's attack and special damage, hit-stop budget/scaling/freeze, crit math, knockback + wall slam, Sigil blast/root/recharge, bow perfect release, halo return, streak tiers, slow-mo easing.
