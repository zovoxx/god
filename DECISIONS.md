# Decisions made without asking

Each entry: what was decided and why.

## Engine & project
- **Godot 4.7.2-stable** (latest stable 4.x at build time), installed to `~/.local/bin/godot`, templates to `~/.local/share/godot/export_templates/4.7.2.stable/`.
- **Forward+ with a "low" preset**: `quality/driver/low_end`, no MSAA/SSAA, no glow (no WorldEnvironment is ever created), tiny shadow atlas. `fallback_to_opengl3=true` so the game still starts on machines (and CI/xvfb) without Vulkan — Godot switches to the Compatibility renderer automatically there.
- Base resolution 1920×1080, `canvas_items` stretch, `expand` aspect. Window opens at 1600×900 so it fits laptop screens; F11 toggles fullscreen (saved in settings).
- **Fixed 60 Hz simulation** in `_physics_process`; rendering interpolates positions between the last two sim steps. FPS capped at 144 with V-Sync on, so 60 Hz and 144 Hz monitors both run smoothly.
- Hit-stop and slow motion are implemented *inside the simulation* (the world does not advance during hit-stop) so the bot and tests see exactly what a player sees.

## Architecture
- `sim/` holds the whole game simulation as plain `RefCounted` objects (no Nodes). It never reads `Input` and never draws. It talks to the outside only through `bus.fire(name, data)` (the `Bus` autoload in the game, `null` in tests/bot).
- Presentation (`render/`, `ui/`, `audio/`) reads sim state read-only every frame and reacts to bus events.
- Input arrives as an `InputFrame` per step (move, aim, aim point, edge presses). The bot synthesises the same frames.
- **Balance numbers live in `data/tuning.tres`, feel numbers in `data/game_feel.tres`, boon content in `data/boons.tres`.** Their scripts (`config/*.gd`) only declare Dictionary sections without defaults, so the `.tres` files are the single source of truth. Enemy AI step timings that are not balance-relevant (e.g. "turn rate while tracking") may live next to the AI code.
- Scripts started with `-s` (tests, tools) cannot reference autoloads by identifier at compile time; they fetch them with `root.get_node("Cfg")`. Every other script uses autoload names normally.
- New `class_name` scripts need a filesystem scan before `-s` scripts can see them, so `tools/ci.sh` runs `--import` first.
- `tools/check_all.gd` uses Godot's `Logger` API (`OS.add_logger`) to count every engine/script error raised while loading all files.

## Input
- Bindings are created in code (`autoload/controls.gd`) instead of in `project.godot`, which keeps defaults readable and makes rebinding/resetting trivial.
- Aim mode "auto" switches to whichever device was used last (mouse motion/click → mouse aim; any pad input → stick aim). Settings can force mouse, stick or pure auto-aim.
- Mouse aim snaps softly to an enemy within 14° of the cursor direction; stick aim does the same around the stick direction and falls back to the auto-aim cone (65°, plus anything within 90 units) in the movement direction when the right stick is idle.
- The 150 ms input buffer applies to attack, special, dash and Sigil. Dash can cancel attack *recovery* (not windup/active). An attack within 0.18 s of a dash ending becomes the weapon's dash-attack.

## Combat (phase 2)
- Combo chaining: the next combo step can start once `chain_at` (35–40 %) of the current recovery has elapsed; holding attack auto-repeats (except the bow, where holding charges a power shot).
- Hits only stagger an enemy that is *not* mid-attack (no active telegraph) and whose hit power is ≥ 0.18. Interrupting an attack needs a **counter** (hit during the white flash) or breaking armor. This keeps fast weapons from perma-stunning everything while making counters meaningful.
- `request_hitstop` keeps a rolling 1-second log; total hit-stop in any second is capped at `budget_per_second` (0.32 s) and a new stop can't start within 30 ms of the last one ending.
- Hit sparks are white/gold (crit gold) so red/orange stays reserved for threats; enemies only shed their own body colour as shards when they die.
- **Pickups always carry a cyan halo** (the pickup colour), whatever their core: gold coins, Embers, HP orbs, the reward orb.
- Halo: one chakram in flight at a time (two with Twin Halos); attack input is ignored until it returns.
- Weapon forges: exactly 3 per weapon (the spec), plus 5 generic forges shared by all weapons.
