# LANTERNFALL

*Wren, the last Kindler, descends four depths to take back a stolen sun.*

A 2D top-down action roguelike built in **Godot 4.7 (standard build, GDScript only, no plugins)** for Ubuntu x86_64, played with keyboard + mouse or a gamepad. It is a Godot rebuild of the web game Lanternfall: 5 weapons, 8 patron Lights with 88 boons and 18 duo boons, 32 enemies across 4 depths, 10 combinable elite modifiers, 8 guardians and 4 multi-phase bosses, the Wick hub with permanent unlocks, Vows, mastery, a bestiary, a story, 30 achievements, a Daily Descent and the Kindling Heat.

All art and sound is generated in code; drop in your own files to replace any of it (see the end of this file).

---

## Running the game

### From the editor (or the Godot binary)

Install Godot 4.7.x (standard build). Then, from the project folder, either open it in the editor:

```bash
godot --path . --editor
```

…and press **F5**, or run it directly:

```bash
godot --path .
```

Command-line flags (put them after `--` when running through `godot`):

```bash
godot --path . -- --new-run --weapon=pike
```

```bash
godot --path . -- --continue
```

```bash
godot --path . -- --daily
```

```bash
godot --path . -- --new-run --depth=3
```

| Flag | Effect |
| --- | --- |
| `--new-run` | skip the menus and start a run |
| `--continue` | resume the saved run in progress |
| `--daily` | start today's Daily Descent |
| `--weapon=<id>` | `fangs`, `pike`, `anvil`, `bow` or `halo` (must be unlocked) |
| `--depth=<n>` | start the run at depth 1–4 |

### From the exported binary (Ubuntu)

The Linux build is a single file with the `.pck` embedded:

```bash
./build/linux/lanternfall.x86_64
```

The same flags work directly:

```bash
./build/linux/lanternfall.x86_64 --new-run --weapon=bow
```

To rebuild it (needs the 4.7 export templates):

```bash
godot --headless --path . --export-release "Linux" build/linux/lanternfall.x86_64
```

### Tests, checks, bot and screenshots

```bash
tools/ci.sh
```

runs `tools/check_all.gd` (loads every script, scene, shader and resource; zero errors required) and `tests/run_tests.gd` (prints PASS/FAIL, exits 1 on any failure). They can also be run on their own:

```bash
godot --headless --path . -s tools/check_all.gd
```

```bash
godot --headless --path . -s tests/run_tests.gd
```

The headless bot plays full runs and reports crashes, soft-locks, room times, damage sources and win rate (exit code 1 on a crash or soft-lock):

```bash
godot --headless --path . -- --bot --runs=20 --weapon=all
```

Add `--fresh` to play with a brand-new save instead of a fully unlocked Wick. Screenshots of the boon choice, a boss telegraph, the death recap, the Wick and more:

```bash
xvfb-run -a -s "-screen 0 1920x1080x24" godot --audio-driver Dummy --path . -s tools/screenshots.gd
```

(they land in `screenshots/`).

---

## Controls

| Action | Keyboard + mouse | Gamepad |
| --- | --- | --- |
| Move | W A S D (or arrow keys) | Left stick (or D-pad) |
| Aim | Mouse cursor (soft snap to nearby enemies) | Right stick; idle stick = smart auto-aim in the move direction |
| Attack (hold to keep attacking; hold to charge with the bow) | Left click / J | A / RT |
| Special | Right click / K | X / LB |
| Dash (i-frames; cancels attack recovery) | Space / Shift | B / RB |
| Sigil (2 charges, delayed rooting blast) | Q / E | Y / LT |
| Pause (damage log + boons) | Esc | Start |
| Fullscreen | F11 | — |
| Menus | Arrow keys / Tab, Enter, Esc | D-pad / left stick, A, B |

Everything is rebindable in **Settings → Controls** (keyboard and gamepad separately). Aim mode can be forced to mouse, right stick or pure auto-aim.

### Debug keys

| Key | Effect |
| --- | --- |
| **F1** | Debug menu (pauses the run): jump to any depth and room type; spawn any enemy with any elite modifiers, any guardian or boss; grant any boon or weapon; god mode; one-hit kills; freeze AI; overlays for hitboxes, AI states and telegraph shapes; kill all, heal, gold, Embers, Overdrive |
| **1–5** | In the Training grounds (title menu): swap weapon |

---

## How the code is organised

- `sim/` — the whole game simulation as plain objects (rooms, combat, enemies, boons, run and meta state). It never reads input and never draws; it talks to the outside only through `bus.fire()` (the `Bus` autoload). This is what lets the headless bot and the tests play the real game.
- `render/` — presentation: world view, camera, FX, telegraph drawing, the central asset map `render/assets.gd` and the procedural art in `render/art/`.
- `ui/` — HUD and every screen, built on one shared Theme (`ui/ui.gd`).
- `audio/` — procedural SFX and layered music.
- `data/tuning.tres` (balance), `data/game_feel.tres` (juice and readability), `data/boons.tres` (Lights and boons) — every number lives here.
- `bot/`, `tests/`, `tools/`.
- `PHASES.md` (the plan), `DECISIONS.md` (every choice made without asking, including the colour language), `PROGRESS.md` (what each phase delivered).

---

## What each phase delivered

1. **Foundations** — project, autoloads, signal bus, tuning resources, fixed 60 Hz simulation with interpolation, input (keyboard/mouse/gamepad, 150 ms buffer, mouse snap, stick aim, auto-aim cone), movement, dash, camera with lookahead/shake/kick/zoom punch, training room.
2. **Combat** — the five weapons with frame data, combos, Specials, dash-attacks, three forges each and Overdrive-empowered Specials; the Sigil; crits, armor, shields, knockback, wall slams, hitstun; hit-stop with a per-second budget; slow motion; particles, decals, trails, merging damage numbers, callouts.
3. **Damage clarity** — the telegraph system (fills outside-in, white impact flash, counter window, minimum windups), colour language, chip-damage HP bar, damage arcs, edge flash, hitbox dot, i-frame shield, off-screen arrows, low-HP state, enemy HP bars/status icons/elite icons/armor pips, pause damage log, death recap.
4. **Depths 1–2** — 16 enemies, summons, spawn portals, role-based waves, 10 elite modifiers, Ashenhart, Velloran and four guardians.
5. **Rooms** — door generation with rewards shown in advance, combat/elite/guardian/shop/spring/ordeal/boss rooms, reward choices, rerolls, Fate Die, depth hazards, scaling, autosave.
6. **Lights** — 8 patrons, 88 boons + 18 duos, rarities, stacking rules, Concord, the boon-choice screen with before/after numbers, every unique boon mechanic, synergy callouts.
7. **Depths 3–4** — 16 more enemies, four more guardians, the Engine Tyrant and the Pale Regent, the full run and the ending.
8. **The Wick** — unlocks, Keepsakes, Deepening, Vows, weapon mastery, bestiary, story, 30 achievements, Daily Descent, Kindling Heat, run summary.
9. **Polish** — procedural SFX and reactive layered music, settings with rebinding and accessibility options, mid-run resume, UI pass.
10. **Ship** — debug menu, headless bot, balance pass from bot data, screenshots, Linux export, this README.

## What was simplified, and why

- **The Wick is a menu hub**, not a walkable room — every feature stays one or two presses away with any device, and "Descend again" from the recap starts a new run in well under two seconds.
- **Placeholder art** is vector-style shapes baked into textures at startup; animation is squash-and-stretch, flips, rotation and FX rather than frame animation.
- **Procedural audio** is deliberately simple (a handful of oscillators and noise with envelopes); music is four short synchronised loops per depth.
- **Enemy pathing** is steering with pillar avoidance, not a navmesh — the arenas are open rooms with a few round pillars.
- **Mid-run resume** restarts the room you were in (with your build, gold and HP as you entered it) rather than restoring the exact moment.
- **Boss "copies"/"reflections"** are separate, optional, short-lived enemies.
- The bot plays with a fully unlocked Wick by default so every system gets exercised; `--fresh` measures a brand-new save.

## Known issues

- Under software rendering (no Vulkan, e.g. inside CI/xvfb) Godot falls back to the Compatibility renderer automatically and prints a Vulkan warning at startup; this is harmless.
- Very wide or very tall windows show more of the floor than the 16:9 layout was tuned for; HUD anchors adapt, but the camera framing of doors assumes roughly 16:9.
- Enemy steering can occasionally press an enemy against a pillar for a moment; it frees itself when the player moves.
- The bot sometimes needs a "navigation assist" to walk into a door behind a pillar (counted in its report; it never happens to a human player because doors are walked into manually).
- Godot reports leaked objects/resources at exit when the headless tools quit; these are shutdown messages, not gameplay errors.

## Replacing sprites and sounds

**Sprites.** Every sprite is requested by id from the asset map `res://render/assets.gd`. Put a PNG at:

```
res://sprites/<id>.png
```

and it replaces the procedural sprite (scaled to the same on-screen height; transparency is respected; the white hit-flash shader still works). Ids are the names passed to `A.reg(...)` in `render/art/*.gd`: for example `wren`, `w_fangs`, `w_pike`, `w_anvil`, `w_bow`, `w_halo`, `knife`, `arrow`, enemy ids such as `cinderling`, `hookjaw`, `ironclad`, `mirrorknight`, guardians such as `mini_thornback`, `mini_riveter`, bosses `boss_stag`, `boss_archivist`, `boss_engine`, `boss_regent`, patron portraits `p_ember` … `p_thorn`, and icons such as `i_lantern`, `i_heart`, `i_forge`, `i_elite_hasted`, `i_st_burn`. Calling `Assets.dump("user://sprites")` from the debugger writes every baked sprite out as a PNG to start from.

**Sounds.** Every sound is requested by id. Put a file at:

```
res://audio/<id>.ogg
```

or `res://audio/<id>.wav` and it overrides the generated sound. Ids are the keys of `Synth.sfx_recipes()` in `audio/synth.gd`, for example `hit`, `hit_crit`, `kill`, `swing_fangs`, `dash`, `perfect`, `clang`, `finisher`, `hurt`, `heal`, `heartbeat`, `defied`, `tele`, `tele_boss`, `explosion`, `roar`, `room_clear`, `card_legendary`, `concord`, `ui_select`, `stinger`.

Files added in the editor are imported automatically; for the exported build, re-export after adding files.

---

## Latest verification results

**Headless bot, 20 runs, all five weapons, fully unlocked Wick** (`godot --headless --path . -- --bot --runs=20 --weapon=all`):

- 20 runs, **0 crashes, 0 soft-locks**, 0 navigation assists — exit code 0.
- 16 wins (80 %); 19 of 20 runs reached the Starless Crown. Per weapon: Fangs 3/4, Moonreach 2/4, Anvilheart 3/4, Vesper Bow 4/4, Sunwheel Halo 4/4.
- Average room time 22.9 s for the bot (≈ 8–10 minutes per full run; a human player, who cannot read every telegraph perfectly, takes roughly two to three times as long).
- Deaths: The Void Matron (Void Well) ×2, The Pale Regent (Mirror Dash), The Engine Tyrant (Furnace Mortar). Most damage taken: The Engine Tyrant, Mirror Knight, Prism, The Pale Regent, Slagcrawler.
- With a brand-new save (`--fresh`, Kestrel Fangs only, 4 Lights, no hearts) the bot won 4 of 10 runs before the final balance pass.

**Exported binary under xvfb for 10 seconds** (`timeout 10 xvfb-run -a ./build/linux/lanternfall.x86_64 --new-run`): starts a run and keeps running until the timeout with **0 script errors**. The only engine messages are the Vulkan → OpenGL fallback and V-Sync notice that any GPU-less virtual display produces. The exported binary also plays a full headless bot run (`./build/linux/lanternfall.x86_64 --headless --bot --runs=1`).

**Checks:** `tools/check_all.gd` loads 119 files with 0 errors; `tests/run_tests.gd` runs 115 tests, all passing.
