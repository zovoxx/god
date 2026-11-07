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

## Phase 4 — Depths 1–2: enemies, elites, guardians, bosses
- 16 enemies with distinct roles and brains (`sim/ai/depth1.gd`, `sim/ai/depth2.gd`) plus summons (Grub, Slurrylet): Cinderling (rusher lunge), Bramblehorn (charger, wall stun), Spitbloom (lobber), Ashwisp (orbiting swarm), Burrowmaw (burrower), Kindlepod (bomber, chain blast), Thorn Warden (front shield), Grubmother (summoner); Inkshade (teleport ink gate + slash), Lanternist (tracking beam blocked by pillars), Twinned Scribe (tether pair with revive), Tidecleric (heal channel, interruptible), Hookjaw (hook pull + bite, dash breaks it), Slurry (hop splash, splits), Echo (dodger), Glimmerjelly (mines).
- 10 combinable elite modifiers (`sim/elites.gd`) with HP/damage scaling, icons and death effects.
- Boss/guardian framework (`sim/ai/boss.gd`): weighted attacks gated by phase/range/cooldown, callout banners, invulnerable phase roar that clears bullets.
- Guardians Thornback, Bloom Mother, The Librarian, Deepmaw; bosses Ashenhart (Cinder Charge, Antler Sweep, Firefall, Flame Ring, Kindle Brood, Ember Spiral) and Velloran (Quill Storm, Seeking Pages, Drowning Tide, Ink Snipe, Blink, Mirror Copies), each with a phase-2 change.
- Encounter planner with role templates, novelty weighting, Deepening gating, elite promotion; wave runner (next wave at 34 % or 13 s).
- Spawn portals drawn as swirls (purple for bosses), burrow mounds, hop arcs, lob arcs, tether/heal/sniper beams, explosions.
- Procedural sprites for all 18 depth 1–2 enemies, 4 guardians and 2 bosses.
- Tests: roster sizes, brain/sprite/tip coverage, every enemy telegraphs and resolves attacks in a soak, bosses cycle ≥3 named attacks in 30 s and change phase invulnerably, 6+ attacks per boss, each elite modifier and all pair combinations, volatile/brood/blinking/vampiric effects, wave determinism per seed, Deepening gating, waves run to a clear.

## Phase 5 — Rooms, doors, room types and depth progression
- `RunState` (build, currencies, position, modifiers, statistics; JSON round-trip), `Rooms` (deterministic door generation with depth/step rules, vows, recovery before bosses; 8 pillar layouts weighted per depth; depth hazards), `RoomFlow` (enter → waves/shop/spring/ordeal → clear slow-mo → magnet → reward orb → choice → doors lit one by one → next room; guardians, bosses, depth changes, victory, death, abandon).
- `Offers`: forge, kindling, heartwood and gold choices with before/after values; shop stock (2 boons, heal, max HP, forge, reroll, Fate Die) with depth-scaled prices; ordeal prompts (Altar, Gauntlet, Wager); rerolls and Fate Dice.
- Presentation: door arches on the top wall showing room type + reward icon + label, spring fountain, altar, fade transitions, depth title banners, camera framing for doors, door arrows; choice overlay with flip-in cards; shop overlay; title screen; victory screen; run save/continue; death recap after a run.
- `tools/screenshots.gd` (+ `tools/shots_impl.gd`) with scenarios; `tools/fix_inference.py` dev helper.
- Tests: deterministic doors per seed, door rules per step, No Springs vow, depth progression and HP/damage scaling, first room → doors, walking through a door, forge choice, rerolls, shop buying/prices, spring heal, Altar/Gauntlet/Wager outcomes and declining, guardian/boss rooms, hazards warn first, run JSON round-trip, and a scripted play-through of depths 1–2 defeating both bosses.

## Phase 6 — The Lights: boons, duos, choice screen, synergies
- `data/boons.tres`: 8 patrons (colour, title, theme, 3 greetings) with 11 boons each (attack, special, dash, cast, revenge, passives, legendary) = 88, plus 18 duo boons.
- `sim/boons.gd`: rarity/level values, descriptions, slot replacement, passive/legendary/duo requirements, weighted deterministic offers with rarity floors, Concord duos, granting, exact before/after previews.
- `sim/boon_fx.gd`: every unique mechanic — fire trails and fields, frost novas, Absolute Zero, Steam Burst, storm clouds, Thunderhead, Plasma/Static Frost, wall-slam duos, Riptide, Maelstrom Heart, radiance marks, Glare, Morning Star, Eclipse, Hex burst/spread, Siphon, Black Sun, Black Static, Drowned Curse, wind blades, cyclones/Maelstrom, Bleed bursts, Bloodletting, Thousand Thorns, Wildthorn, Blood Moon, Thousand Cuts, all six revenge boons, Updraft — with "+COMBO" synergy callouts.
- Patron portraits; boon choice cards with rarity frames/glow, flip-in with rarity sounds, before/after numbers, CONCORD banner, reroll and Fate Die.
- Overdrive (per-weapon empowered Specials), perfect dash, counters and finishers were built in phases 2–3 and are now fed by boons and tested here.
- Tests: content counts (88 + 18), every patron has every slot + colour + greetings + portrait, all texts fill their values, rarity/level scaling, fixed values, every boon changes stats, infusions, slot replacement, passive/legendary rules, every duo requirement, offer rules + rarity floor + determinism, Burn cap/DoT, Chill → Freeze → Shatter, Hex spread, Bleed burst, Mark crits, Jolt chains, freeze+lightning synergy, a combat soak with every boon granted, Overdrive fill and empowered special, input buffered through hit-stop.

## Phase 7 — Depths 3–4, the Engine Tyrant, the Pale Regent, the full run
- 16 more enemies (`sim/ai/depth3.gd`, `sim/ai/depth4.gd`): Rivet Hound (ring then pounce), Coil Sentry + Pylons (lightning fences), Ironclad (armor, Hammerfall), Forge Mortar (sequenced shells), Bellwether (speed/defence aura), Gyrosaw (invulnerable bouncing spin), Slagcrawler (slag trail), Sparkmite (latching swarm); Voidcaller + Void Portals + Void Imps, Mirror Knight (reflecting guard + 3-slash combo), Gravewell Seer (pull well), Prism (sweeping beam arc), Wraith Lancer (three telegraphed dash lines), Aegis Herald (bubble shields), Hexer (footstep curses), Null Shard (gapped bullet rings).
- Guardians The Riveters (twin pair with a live fence), The Foreman (armored), The Eclipsed Knight, The Void Matron; bosses The Engine Tyrant (Sweeping Lasers, Furnace Mortars, Saw Launch, Piston Wall, Release the Hounds, Steam Vents, Meltdown) and The Pale Regent (Crescent Volley, Starfall, Gravity, Mirror Dash, Time Sigil, Summon Knights, Eclipse Spiral) with phase-2 changes.
- Projectile wall bounce, player slows (Time Sigil, latches), Bellwether buff; drawing of fences, lasers, beams, gravity wells, auras, bubbles, spin rings.
- Sprites for all 19 new enemies, 4 guardians and 2 bosses.
- Tests now cover all four depths (rosters, brains/sprites/tips, attack soak, boss phases and ≥6 attacks), depth 3–4 specials (spin invulnerability, reflect, armor stun, Bellwether aura, Sparkmite shake-off), and a scripted **full run to victory** (24 rooms, all four bosses).

## Phase 8 — The Wick and the loop
- `sim/meta.gd`: 23 unlocks (4 weapons, 4 Lights, Concord, 2 hearts, Second Wick, Moth Wings, Fate Die, Moth Purse, 6 Keepsakes, Deepening I–II), run options from the Wick, end-of-run settlement (Embers with Deepening/Heat bonuses, Vows, boss kills, totals, mastery XP, bestiary, personal bests, Daily scores, Heat unlock), 28-line story told one line per run end, ending text.
- `sim/achievements.gd`: 30 achievements with toast pop-ups (`ui/toasts.gd`).
- `ui/wick.gd`: hub with Descend (Vows → weapon select), Daily Descent (seed, weapon, local best table), the Wick tree, Keepsakes, Kindling Heat, Weapon Mastery (XP bars + forge unlocks), Bestiary, Achievements, Story log, Settings.
- `ui/run_summary.gd`: time, depth, rooms, kills, damage dealt, damage taken per source (bars), best hit, highest streak, perfect dashes/counters/finishers, Embers, Vows kept, mastery gain, boons, achievements, personal-best comparisons.
- Death recap now carries the next-unlock progress bar and the new story line.
- Tests: purchases + requirements, unlocks shaping run options, keepsakes, mastery → forges, Ember maths, Vows, Heat, story, achievements, Daily seed/weapon/score, bestiary, personal bests, meta JSON round trip.

## Phase 9 — UI pass, audio, settings, saves
- `audio/synth.gd` + `audio/audio.gd`: 67 procedural SFX (hits, crits, kills, every weapon, dash, perfect, clang, finisher, freeze/shatter, telegraph rising cues, impacts, explosions, beams, portals, mines, roars, room clear arpeggio, doors, rarity-specific card reveals up to a legendary chorus, Concord, UI sounds, achievement, heartbeat, warm chime, stinger), file overrides, voice pool, layered reactive music per depth, low-HP muffling.
- `ui/settings_screen.gd`: Master/Music/SFX volumes; screen shake, hit-stop, flash and damage-number sliders; damage numbers on/off; reduce flashing; colour-blind palette; aim mode; graphics preset; fullscreen; full keyboard and gamepad rebinding with reset. Reachable from the title, the Wick and the pause menu.
- UI pass: one shared theme everywhere, focus-following scroll lists, wrapped paragraphs, fixed overlay sizing, polygon fixes (no more triangulation errors).
- Saves: meta, settings, and mid-run resume ("Continue descent" / `--continue`).
- Tests: every SFX renders, music layers loop in sync, audio API is safe headless, rebinding and binding persistence, default controls, settings round trip, colour-blind palette swap, feel sliders, mid-run resume restores room, build, gold and weapon.

## Phase 10 — Debug menu, bot, balance, screenshots, export, README
- F1 debug menu (`ui/debug_menu.gd`): jump to any depth/room type, spawn any enemy with any elite modifiers, guardians and bosses, grant boons and weapons, god mode, one-hit kills, freeze AI, overlays for hitboxes, AI states and telegraph shapes, plus heal/gold/Embers/Overdrive helpers.
- Headless bot (`bot/bot_brain.gd`, `bot/bot_runner.gd`, `tools/run_bot.sh`): plays full runs, reports crashes, soft-locks, room times, damage per source, killers and win rate, writes a JSON report, exits 1 on any crash or soft-lock.
- Balance pass from bot data (see DECISIONS.md) and two bugs it found (Thorn Warden corner soft-lock, guardian stuck invulnerable).
- Screenshots (`tools/screenshots.gd` under xvfb): doors, boss telegraph, death recap, boon choice, the Wick, settings, debug menu, depth 3 and depth 4 boss fights — saved in `screenshots/`.
- Linux export preset (`export_presets.cfg`) → `build/linux/lanternfall.x86_64` with the `.pck` embedded; command-line flags `--new-run`, `--continue`, `--daily`, `--weapon=<id>`, `--depth=<n>`.
- README with run instructions, controls, debug keys, phase summary, simplifications, known issues, asset replacement and the verification results.
- Final: check_all 0 errors, 115 tests passing, bot 20/20 runs without crashes or soft-locks (16 wins).
