# LANTERNFALL — Phase plan

Godot 4.7 (standard build), GDScript only, no plugins. Desktop (Ubuntu x86_64), keyboard + mouse or gamepad.

Every phase ends with `tools/check_all.gd` at zero errors, all tests passing (`tools/ci.sh`),
an entry in `PROGRESS.md` and a git commit named "Phase N: …".

1. **Foundations** — project setup, simulation/presentation split, signal bus, input (keyboard, mouse, gamepad, buffering, aim), player movement, dash, a test room, camera.
2. **Combat core** — all 5 weapons with frame data, Specials, dash-attacks, the Sigil, crits, the hit pipeline, and the full game-feel juice (hit-stop, shake, flash, knockback, wall slams, particles, decals, damage numbers, slow motion).
3. **Damage clarity** — player hurt pipeline, telegraph system, colour language, HP bar with chip damage, directional arcs, hitbox dot, off-screen arrows, low-HP state, death recap.
4. **Depths 1–2 content** — 16 enemies with roles, spawn portals, waves, elite modifiers; Ashenhart and Velloran plus their guardians.
5. **Rooms** — rooms and doors, all room types, shops, springs, ordeals, depth progression and scaling.
6. **Lights** — all 8 patron Lights, all boons and duos, rarities, boon-choice screen, synergy callouts, Overdrive meter, perfect dash, counters, finishers.
7. **Depths 3–4 content** — enemies, hazards, guardians, the Engine Tyrant, the Pale Regent; the full run plus the ending.
8. **The Wick** — hub, meta unlocks, Keepsakes, Deepening, Vows, weapon mastery, bestiary, story, achievements, Daily Descent, Kindling Heat, run summary.
9. **Polish** — full UI pass, procedural SFX and layered music, settings with rebinding and accessibility, save/load with mid-run resume.
10. **Ship** — debug menu, headless bot, balancing pass from bot data, screenshots, Linux export, README.
