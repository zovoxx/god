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
