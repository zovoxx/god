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

## Phase 3 — Damage clarity
- Telegraph system (`sim/telegraph.gd`): circle, cone, line and ring shapes plus non-damaging projectile aim lines, minimum windups (0.35 s enemies / 0.5 s bosses) enforced centrally, attacker glow, counter window, perfect-dash detection, impact flash. Rendering in `render/tele_draw.gd` (fills from the outside in, white flash, purple boss rim). Enemy floor hazards pulse twice before activating.
- Hurt pipeline: 70 ms hit-stop, knockback, 0.8 s i-frames with sprite flicker and shield outline, red damage number with the source's icon, damage log, dodge/barrier, Death Defiance hook, death slow-mo.
- HUD (`ui/hud.gd`): HP bar with chip damage (`ui/hp_chip.gd`, white chip holds 0.5 s then drains; heals fill green), numeric HP, barrier segment, Death Defiance lanterns with a shatter, dash pips, Special/Sigil rings, Overdrive meter, gold/Embers, streak tier with timer, boon strip, boss bar, callout/phase banners, red edge flash, directional damage arcs, low-HP heartbeat vignette, off-screen threat arrows that pulse faster with proximity.
- World overlays: small HP bars once damaged, elite icon rows, status icons with stack counts, cracking armor pips, finisher glow, hitbox dot whenever danger is near.
- Pause screen (last 10 hits + boons with descriptions) and death recap card (killer sprite/name, killing attack, last 5 hits, enemy-specific tip, build, Embers, next-unlock bar, "Descend again" focused).
- Shared UI theme + builders (`ui/ui.gd`) with visible focus for keyboard/gamepad.
- Sparring Effigy training enemy that cycles all telegraph shapes.
- Tests: hurt i-frames/hit-stop/knockback, damage log, hitbox size, chip timing, minimum windups, inside/outside hits, perfect-dash window (and an early dash not counting), spawn portals harmless+invulnerable, spawn distance ≥ 170, counters, finishers, projectile vs small hitbox.
