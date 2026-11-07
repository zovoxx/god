class_name RoomFlow
extends RefCounted
## The run's room-to-room flow inside the simulation, so the UI and the headless bot drive
## exactly the same logic: enter → (combat waves | shop | spring | ordeal prompt) → clear →
## slow-mo last kill → everything flies to you → reward orb → choice → doors light up one by
## one → walk into a door → next room. Bosses end a depth; the fourth boss ends the run.

enum S { ENTER, COMBAT, CLEAR, REWARD, OFFER, DOORS, SHOP, SPRING, ORDEAL, EXIT, DEAD, WON }

var sim: Sim
var run: RunState
var state := S.ENTER
var t := 0.0
var waves: Encounters.Runner
var offer := {}
var shop: Array = []
var doors: Array = []            # [{plan, pos}]
var doors_lit := 0
var hazard_spots: Array = []
var room_t := 0.0
var room_dmg := 0.0
var spring_used := false
var ordeal_active := ""
var exit_door := -1
var reward_pending := {}
var boss_ref: SimEnemy = null
var cleared_once := false

func _init(s: Sim, r: RunState) -> void:
	sim = s
	run = r
	sim.run = r
	sim.flow = self
	waves = Encounters.Runner.new()

# ───────── queries used by combat ─────────

func combat_live() -> bool:
	return state in [S.COMBAT, S.CLEAR, S.REWARD, S.DOORS, S.SPRING, S.SHOP, S.OFFER, S.ORDEAL]

func streak_paused() -> bool:
	return state != S.COMBAT

func handles_death() -> bool:
	return true

func is_choice_open() -> bool:
	return state == S.OFFER or state == S.SHOP or state == S.ORDEAL

# ───────── entering rooms ─────────

func start_run() -> void:
	run.plan = Rooms.first_room(run)
	sim.equip_weapon(run.weapon, run.forges)
	run.recompute(sim)
	sim.player.hp = minf(run.hp, sim.player.max_hp)
	sim.fire(&"run_started", {"weapon": run.weapon, "seed": run.seed, "daily": run.daily})
	enter(run.plan)

## resume: re-enter the saved room plan with the saved run state
func resume_run() -> void:
	sim.equip_weapon(run.weapon, run.forges)
	run.recompute(sim)
	sim.player.hp = clampf(run.hp, 1.0, sim.player.max_hp)
	enter(run.plan, true)

func enter(plan: Dictionary, resumed: bool = false) -> void:
	run.plan = plan
	run.depth = int(plan.depth)
	run.step = int(plan.step)
	var arena := Rooms.make_arena(plan)
	sim.set_arena(arena.rect, arena.pillars, arena.style)
	sim.arena["hazards"] = arena.hazards
	hazard_spots = arena.hazards.duplicate(true)
	for h in hazard_spots:
		h["t"] = float(h.phase) * float(sim.T.rooms.hazard_cycle)
	sim.enemies.clear()
	sim.projectiles.clear()
	sim.hazards.clear()
	sim.telegraphs.clear()
	sim.pickups.clear()
	var p: SimPlayer = sim.player
	p.pos = Rooms.entry_point(arena)
	p.prev = p.pos
	p.vel = Vector2.ZERO
	p.kvel = Vector2.ZERO
	p.state = SimPlayer.St.FREE
	p.invuln_t = 0.6
	p.dash_charges = p.dash_max
	p.cast_charges = p.cast_max
	p.wstate["out"] = 0
	offer = {}
	shop = []
	doors = []
	doors_lit = 0
	room_t = 0.0
	room_dmg = 0.0
	spring_used = false
	ordeal_active = ""
	exit_door = -1
	boss_ref = null
	cleared_once = false
	reward_pending = {}
	state = S.ENTER
	t = 0.0
	if run.depth == 1 and run.step == 0 and run.room_index == 0 and not run.has_meta("started"):
		run.set_meta("started", true)
	sim.fire(&"room_entered", {"plan": plan, "depth": run.depth, "step": run.step, "index": run.room_index, "name": Rooms.depth_name(run.depth), "resumed": resumed, "seed": int(plan.get("seed", 0))})
	sim.fire(&"autosave", {"run": run.to_dict()})

func _begin_content() -> void:
	var plan: Dictionary = run.plan
	match String(plan.type):
		"combat", "elite":
			_start_waves(String(plan.type))
		"guardian":
			var g: String = plan.get("kind", Cfg.T.rooms.guardians[str(run.depth)][0])
			boss_ref = Enemies.spawn(sim, g, Vector2(0, sim.arena.rect.position.y + 220.0), run.depth)
			sim.fire(&"banner", {"text": boss_ref.name.to_upper(), "sub": "Guardian of " + Rooms.depth_name(run.depth), "col": Cfg.col("boss"), "life": 2.0, "big": true})
			waves.start([], run.depth, 0.0)
			state = S.COMBAT
		"boss":
			var b: String = plan.get("kind", Cfg.T.rooms.bosses[str(run.depth)])
			boss_ref = Enemies.spawn(sim, b, Vector2(0, sim.arena.rect.position.y + 240.0), run.depth)
			sim.fire(&"banner", {"text": boss_ref.name.to_upper(), "sub": Rooms.depth_name(run.depth), "col": Cfg.col("boss"), "life": 2.6, "big": true})
			sim.fire(&"boss_intro", {"kind": b, "name": boss_ref.name})
			waves.start([], run.depth, 0.0)
			state = S.COMBAT
		"shop":
			run.shops_this_depth += 1
			shop = Offers.shop_stock(sim)
			state = S.SHOP
			sim.fire(&"offer_opened", {"kind": "shop"})
		"spring":
			state = S.SPRING
			_open_doors()
		"ordeal":
			offer = Offers.ordeal_prompt(sim, plan)
			state = S.ORDEAL
			sim.fire(&"offer_opened", {"kind": "ordeal", "offer": offer})

func _start_waves(type: String) -> void:
	var rng := Rooms.room_rng(run, 3)
	var extra := 1 if run.has_vow("elites") else 0
	if run.has_heat("swarming"):
		extra += 1
	var plan := Encounters.plan(sim.T, rng, run.depth, run.step, type, run.deepening, extra)
	waves.start(plan, run.depth, float(sim.T.pacing.first_wave_delay))
	state = S.COMBAT

# ───────── per step ─────────

func update(dt: float) -> void:
	t += dt
	run.time += dt
	run.hp = sim.player.hp
	match state:
		S.ENTER:
			if t >= 0.35:
				_begin_content()
		S.COMBAT:
			room_t += dt
			waves.update(sim, dt)
			_update_room_hazards(dt)
			if waves.done and sim.living_enemies() == 0 and (boss_ref == null or not boss_ref.alive):
				_on_clear()
		S.CLEAR:
			if t >= float(sim.F.slowmo.last_kill_duration) + float(sim.T.pacing.reward_magnet_delay):
				_spawn_reward()
		S.REWARD:
			# safety: if the orb somehow can't reach the player, open the offer anyway
			if t > 3.0 and not reward_pending.is_empty():
				_open_reward()
		S.SPRING:
			if not spring_used and sim.player.pos.distance_to(Vector2.ZERO) < 80.0:
				_use_spring()
			_update_doors(dt)
		S.DOORS:
			_update_doors(dt)
		S.EXIT:
			if t >= 0.3:
				_go_through(exit_door)

func _update_room_hazards(dt: float) -> void:
	var R: Dictionary = sim.T.rooms
	var cycle: float = R.hazard_cycle
	var names: Dictionary = R.hazard_names
	for h in hazard_spots:
		h.t = float(h.t) + dt
		if float(h.t) >= cycle:
			h.t = 0.0
			var hz := Hazards.enemy_field(sim, null, h.pos, float(h.radius), float(sim.F.telegraph.hazard_warn_time), float(R.hazard_active), float(R.hazard_dmg) * float(sim.T.scaling.dmg_by_depth[run.depth - 1]), String(names[h.kind]), String(h.kind))
			hz.name = String(names[h.kind])
			hz.art = "hazard"
			hz.tick = 0.5

func _on_clear() -> void:
	if cleared_once:
		return
	cleared_once = true
	state = S.CLEAR
	t = 0.0
	run.rooms_cleared += 1
	run.room_times.append(room_t)
	var plan: Dictionary = run.plan
	var is_boss: bool = plan.type == "boss"
	var SM: Dictionary = sim.F.slowmo
	if is_boss:
		sim.slowmo(float(SM.boss_kill_scale), float(SM.boss_kill_duration))
	else:
		sim.slowmo(float(SM.last_kill_scale), float(SM.last_kill_duration))
	# hazards and leftover bullets fade away
	for pr in sim.projectiles:
		if pr.team == 1:
			pr.alive = false
	for h in sim.hazards:
		if h.team == 1:
			h.alive = false
	for tt in sim.telegraphs:
		Tele.cancel(sim, tt)
	# embers for the room
	var E: Dictionary = sim.T.economy
	var em := int(E.embers_per_room)
	if plan.type == "guardian":
		em += int(E.embers_per_guardian)
	elif is_boss:
		em += int(E.embers_per_boss)
	var pos := sim.player.pos + Vector2(0, -60)
	for i in em:
		Pickups.spawn(sim, "ember", pos + Vector2(sim.rng.randf_range(-40, 40), sim.rng.randf_range(-30, 30)), 1.0)
	Pickups.magnet_all(sim)
	if sim.stats.heal_on_room_clear > 0.0:
		Combat.heal_player(sim, sim.stats.heal_on_room_clear, "room")
	if ordeal_active == "wager":
		var W: Dictionary = sim.T.rooms.ordeals.wager
		if room_dmg < float(W.max_damage):
			run.add_gold(int(W.stake) * 2)
			sim.fire(&"banner", {"text": "WAGER WON", "sub": "+%d gold" % (int(W.stake) * 2), "col": Color("#ffd166"), "life": 1.8, "big": false})
		else:
			plan["reward"] = "none"
			sim.fire(&"banner", {"text": "WAGER LOST", "sub": "", "col": Color("#ff8a6a"), "life": 1.8, "big": false})
	elif ordeal_active == "gauntlet":
		run.add_gold(int(sim.T.rooms.ordeals.gauntlet.gold))
	sim.fire(&"room_cleared", {"boss": is_boss, "guardian": plan.type == "guardian", "pos": sim.player.pos, "text": "DEPTH CONQUERED" if is_boss else "CLEARED", "time": room_t})

func _spawn_reward() -> void:
	var plan: Dictionary = run.plan
	state = S.REWARD
	t = 0.0
	if plan.type == "boss":
		Combat.heal_player(sim, sim.player.max_hp * 0.3, "boss")
		if run.depth >= Rooms.DEPTH_COUNT:
			_win()
			return
	var r: String = plan.get("reward", "none")
	if r == "none" or r == "":
		_open_doors()
		return
	reward_pending = plan
	var pk := Pickups.spawn(sim, "reward", sim.player.pos + Vector2(0, -120), 0.0, {"reward": r, "patron": plan.get("patron", "")})
	pk.magnet = true
	sim.fire(&"reward_ready", {"reward": r, "patron": plan.get("patron", "")})

func on_reward_collected(_pk) -> void:
	if state == S.REWARD:
		_open_reward()

func _open_reward() -> void:
	var plan := reward_pending
	reward_pending = {}
	offer = Offers.for_reward(sim, plan)
	if offer.is_empty() or offer.get("options", []).is_empty():
		_open_doors()
		return
	state = S.OFFER
	sim.fire(&"offer_opened", {"kind": offer.kind, "offer": offer})

# ───────── choices ─────────

## picks an option of the open offer (boon/forge/heart/gold/ordeal)
func choose(i: int) -> bool:
	if state == S.ORDEAL:
		return _choose_ordeal(i)
	if state != S.OFFER or offer.is_empty():
		return false
	var opts: Array = offer.options
	if i < 0 or i >= opts.size():
		return false
	for a in opts[i].actions:
		Offers.do_action(sim, a)
	sim.fire(&"offer_closed", {"kind": offer.kind, "picked": opts[i].id})
	offer = {}
	_open_doors()
	return true

func can_reroll() -> bool:
	return state == S.OFFER and offer.get("rerollable", false) and run.rerolls > 0

func reroll(fate: bool = false) -> bool:
	if state != S.OFFER or not offer.get("rerollable", false):
		return false
	if fate:
		if run.fate_dice <= 0:
			return false
		run.fate_dice -= 1
	else:
		if run.rerolls <= 0:
			return false
		run.rerolls -= 1
	run.set_meta("reroll_salt", int(run.get_meta("reroll_salt", 0)) + 1)
	var plan := run.plan.duplicate()
	if fate:
		plan["rarity"] = int(plan.get("rarity", 0)) + int(sim.T.economy.fate_die_rarity_bonus)
	offer = Offers.for_reward(sim, plan) if offer.kind != "boon" else Boons.offer(sim, String(offer.get("patron", plan.get("patron", ""))), int(plan.get("rarity", 0)), 3, Rooms.room_rng(run, 900 + int(run.get_meta("reroll_salt", 0))))
	sim.fire(&"offer_opened", {"kind": offer.kind, "offer": offer, "reroll": true})
	return true

func _choose_ordeal(i: int) -> bool:
	var id: String = run.plan.get("ordeal", "altar")
	var O: Dictionary = sim.T.rooms.ordeals
	sim.fire(&"offer_closed", {"kind": "ordeal", "picked": "accept" if i == 0 else "decline"})
	offer = {}
	if i != 0:
		_open_doors()
		return true
	match id:
		"altar":
			var cost = round(run.max_hp() * float(O.altar.hp_cost_frac))
			run.max_hp_base -= cost
			run.recompute(sim)
			var plan: Dictionary = run.plan.duplicate()
			plan["rarity"] = 2
			plan["reward"] = "boon"
			reward_pending = plan
			_open_reward()
		"gauntlet":
			ordeal_active = "gauntlet"
			run.plan["rarity"] = 3
			_start_waves("gauntlet")
		"wager":
			var stake: int = mini(run.gold, int(O.wager.stake))
			run.gold -= stake
			ordeal_active = "wager"
			_start_waves("combat")
	return true

## shop: buy item i if affordable
func buy(i: int) -> bool:
	if state != S.SHOP or i < 0 or i >= shop.size():
		return false
	var it: Dictionary = shop[i]
	if it.sold or run.gold < int(it.price):
		return false
	run.gold -= int(it.price)
	it.sold = true
	for a in it.actions:
		Offers.do_action(sim, a)
	sim.fire(&"shop_bought", {"id": it.id, "price": it.price})
	return true

func leave_shop() -> void:
	if state != S.SHOP:
		return
	sim.fire(&"offer_closed", {"kind": "shop"})
	_open_doors()

func _use_spring() -> void:
	spring_used = true
	run.springs_used += 1
	Combat.heal_player(sim, sim.player.max_hp * float(sim.T.rooms.spring_heal_frac), "spring")
	sim.fire(&"spring_used", {"pos": Vector2.ZERO})

# ───────── doors ─────────

func _open_doors() -> void:
	run.doors = Rooms.next_doors(run)
	doors.clear()
	var pos := Rooms.door_positions(sim.arena, run.doors.size())
	for i in run.doors.size():
		doors.append({"plan": run.doors[i], "pos": pos[i]})
	doors_lit = 0
	if state != S.SPRING:
		state = S.DOORS
	t = 0.0
	sim.fire(&"doors_opened", {"count": doors.size()})

func _update_doors(dt: float) -> void:
	var interval: float = sim.T.pacing.door_light_interval
	var lit := mini(doors.size(), int(t / interval) + 1)
	if lit > doors_lit:
		doors_lit = lit
		sim.fire(&"door_lit", {"index": lit - 1, "count": doors.size()})
	if doors_lit < doors.size():
		return
	for i in doors.size():
		if sim.player.pos.distance_to(doors[i].pos) < 46.0:
			enter_door(i)
			return

func enter_door(i: int) -> bool:
	if i < 0 or i >= doors.size():
		return false
	if state != S.DOORS and state != S.SPRING:
		return false
	exit_door = i
	state = S.EXIT
	t = 0.0
	sim.fire(&"door_entered", {"index": i, "plan": doors[i].plan})
	return true

func _go_through(i: int) -> void:
	var plan: Dictionary = doors[i].plan
	run.room_index += 1
	if int(plan.depth) != run.depth:
		run.shops_this_depth = 0
		sim.fire(&"depth_changed", {"depth": int(plan.depth), "name": Rooms.depth_name(int(plan.depth))})
	enter(plan)

# ───────── end of run ─────────

func on_enemy_killed(e: SimEnemy) -> void:
	pass

func on_player_died(entry: Dictionary) -> void:
	state = S.DEAD
	run.dead = true
	run.hp = 0.0
	run.killer = entry
	sim.fire(&"run_ended", {"won": false, "run": run.to_dict(), "killer": entry})

func _win() -> void:
	state = S.WON
	run.won = true
	sim.fire(&"run_ended", {"won": true, "run": run.to_dict()})

func abandon() -> void:
	if state == S.DEAD or state == S.WON:
		return
	state = S.DEAD
	run.dead = true
	sim.player.state = SimPlayer.St.DEAD
	sim.fire(&"run_ended", {"won": false, "abandoned": true, "run": run.to_dict(), "killer": {"source": "Abandoned", "attack": "", "dmg": 0, "art": "wren", "kind": ""}})

func on_hurt(d: float) -> void:
	room_dmg += d
