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

## Colour language (phase 3) — used everywhere, defined once in `game_feel.tres` (`colors`, `colors_cb`)
| Colour | Meaning | Examples |
| --- | --- | --- |
| **Red / orange** | It will hurt you | every telegraph fill/edge, enemy projectiles (red body, bright cream core, near-black outline), enemy floor hazards, the HP bar, hurt edge-flash and damage arc, hurt numbers, off-screen threat arrows |
| **White, gold, patron colours** | It is yours | swing trails, knives/arrows/halo, Sigil ring, starfall, fissures, crits (gold), hitbox dot, i-frame shield outline, Overdrive, status-coloured infusion sparks |
| **Purple** | Boss | boss/guardian HP bar and name, attack-callout and phase banners, a purple rim on boss telegraphs (the fill stays red), boss off-screen arrows |
| **Cyan** | Pickup or heal | halo around every pickup (gold coins, Embers, HP orbs, reward orb), heal numbers and heal fill (green-cyan) |
- Player projectiles are never red; enemy projectiles are never white/gold.
- Telegraphs: the shape fills from its outer edge inward over the windup; the edge turns white for the final `flash_window` (0.12 s) — that white flash is the **counter window**; at impact the whole shape flashes white for 0.14 s. Floor hazards pulse twice before they become active.
- The colour-blind palette (`colors_cb`) swaps red→orange-amber and heal-green→teal, keeping danger/pickup contrast; shapes and outlines carry the meaning too, never colour alone.
- Damage arcs always point at the *attacker*, not at the impact centre of an area attack.
- Perfect dash: starting a dash while inside an attack that lands within 0.15 s (or while an enemy projectile would reach the hitbox within 0.15 s).
- Off-screen arrows are shown for every living enemy (half-transparent while still in a spawn portal) and for enemy projectiles on a course to pass near Wren; pulse rate scales from 1.5 Hz (far) to 9 Hz (near).

## Enemies (phase 4)
- **Every attack is a telegraph.** Contact damage only exists during telegraphed charges (the charge line is shown first). Small rushers (Grubs, Void Imps) bite with a short telegraphed lunge instead of touch damage.
- Lunges deal their damage at the telegraph's impact (the shape is exactly the hit area); long charges (Bramblehorn, Thornback, Ashenhart) instead deal contact damage while travelling along the line that was shown, so the player can still step out after the charge begins.
- The 170-unit minimum applies to every portal spawn (waves and summons): a spawn point closer than that is pushed out along the player→point direction. Split children (Slurry, Brood elites) emerge from the parent's corpse without a portal — they are not new arrivals.
- Bosses cannot be frozen, countered or executed; guardians freeze for half as long and are rooted for half as long.
- Tidecleric heal beams are teal-green (enemy support, not a threat to you) — not red, and distinct from the bright cyan pickup halo.
- Twinned Scribes' tether is a cycle: rest (faint line) → 0.6 s flickering warning (the telegraph) → 2 s burning beam.
- Glimmerjelly mines are floor hazards: they pulse while arming, then any player *or enemy* stepping close starts a 0.5 s blast telegraph that damages everyone inside.
- Elite "Hasted" speeds movement and shortens cooldowns but never shortens telegraph windups below the minimums.
- Velloran's Mirror Copies are optional enemies (the room clears without them) that cast twice and fade.
- Scripts launched with `-s` can't statically reference classes that use autoloads, so tools and tests load their logic at runtime with `load()`.

## Rooms and runs (phase 5)
- Each depth has 6 rooms (combat → choice → choice → guardian → choice → boss), 24 rooms per full run; with ~45–75 s per room this lands in the 20–35 minute target.
- Doors stand inside the top edge of the room; after a clear the camera eases out to show the whole room and lit doors get gold edge arrows when off-screen.
- Room generation uses a hash of (run seed, room index, depth, step, salt), so door options, waves, shop stock and reward choices are reproducible for a seed (and for the Daily Descent) regardless of how long the player spent in earlier rooms.
- The simulation pauses while a choice overlay (boon, forge, shop, ordeal) is open.
- Ordeals: **Altar** trades 15 % max HP for an Epic boon; **Gauntlet** is a 4-wave elite fight for a Legendary-chance boon plus 120 gold; **Wager** stakes 60 gold — clear taking less than 20 damage to win double and the reward, otherwise both are lost.
- After a boss: +30 % heal, then the next depth's doors. After the fourth boss the run is won.
- Every depth has its own periodic floor hazard in combat rooms past the first (Ember Vents, Brine Pools, Piston Spikes, Void Rifts) that always warns for 0.7 s (two pulses) before it hurts.
- Autosave happens on entering each room (and on quitting mid-room); "Continue" restarts the saved room from its beginning with the saved build.

## Lights and boons (phase 6)
- Boon content is data (`data/boons.tres`): infusion boons set a slot's element; every other effect is a `mods` list applied through `Stats.apply_mod` ("+key", "-key", "*key", "f:flag"), and the unique mechanics read those flags in `sim/boon_fx.gd`.
- Rarity names are Common / Rare / Epic / Legendary (×1.0 / 1.35 / 1.75 / 2.2). Legendary-*slot* boons always arrive at Legendary rarity with fixed values; duos at least Epic.
- Rarity roll per card: 2.5 % Legendary, 8 % Epic, 24 % Rare; elite/guardian rooms set a Rare floor, the Fate Die raises the floor by one, the Altar gives Epic, the Gauntlet Legendary.
- A duo can replace one card (35 % when eligible). It needs the Concord unlock and at least one boon from each of its two Lights.
- Before/after numbers are computed by rebuilding the stats with the candidate boon and listing up to three changed values (plus element changes per slot).
- Inputs pressed during hit-stop are written into the input buffer (they used to be lost — found by the Overdrive test).
- Labels only wrap when given a width (`UI.para`); full-rect overlays use `set_anchors_and_offsets_preset` (a bare anchor preset left them at zero size under a CanvasLayer).
- Godot's generated `*.uid` files are committed, as Godot recommends.

## Depths 3–4 (phase 7)
- The spec's depth 3 list names nine creatures; the Pylon is the Coil Sentry's summon, so each depth still has 8 encounter enemies (plus summons: Grub, Slurrylet, Pylon, Void Portal, Void Imp).
- Gyrosaw: its first heading is telegraphed by a line; while spinning it is invulnerable, has a red spinning-danger ring and deals contact damage, then stops and glows (vulnerable) for 1.6 s.
- Sparkmites latch only if their telegraphed latch line hits; each clinging mite slows Wren by 12 % and stings every 1.2 s; any dash (or invulnerability) throws them all off.
- Mirror Knight / Eclipsed Knight guards are telegraphed by a pulsing white ring; hitting them during it is reflected as 60 % of their damage ("REFLECTED").
- The Pale Regent is pale by design; she still reads as a boss through the purple crown/aura, purple HP bar and red eyes.
- The Engine Tyrant's phase-2 change is OVERHEAT: four lasers instead of two, more mortars/vents/saws and a new Meltdown ring attack.
- The Riveters guardian always spawns as a linked pair; the room clears when both are dead.

## The Wick and meta progression (phase 8)
- The Wick is a menu hub (with Ossa, Wren and Quill around the hearth) rather than a walkable room: every feature is one or two presses away with keyboard or gamepad, and a run starts in well under two seconds.
- Flow after a run: death recap (Descend again focused) → Return to the Wick → run summary → the Wick. A win shows the ending, then the summary.
- Embers earned = picked-up Embers + 3 per depth reached + 15 for a win, × (1 + 20 % per Deepening tier + 10 % per Heat point), + kept Vows.
- Vows: two are enforced (No Springs, Elites Everywhere — paid if the run clears depth 1), six are checked at the end of the run. Up to three per run; the Daily Descent ignores Vows, Keepsakes and Heat so its scores are comparable.
- Weapon mastery XP: 1 per kill, 5 per elite, 15 per guardian, 30 per boss. Level 0 has the first weapon forge; levels 1 and 3 unlock the second and third; levels 2, 4, 5 are cosmetic glows.
- The Kindling Heat unlocks with the first win; six stackable modifiers (1–3 points each).
- Daily Descent seed and weapon are derived from the local date (`YYYY-MM-DD`); the top 10 local scores per day are kept. Score = 100/room + 5/kill + 500/boss + 2000 for a win − 0.1/second.
- The bestiary records a creature when it first appears, counts kills and deaths to it, and reveals its tip after 3 kills or a death to it.
- Achievements that can happen mid-run are checked on every room clear and pop as toasts immediately; the rest are checked at the end of the run.
