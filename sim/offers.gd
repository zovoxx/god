class_name Offers
extends RefCounted
## Reward choices and shop stock. Offers are plain data: options carry an `actions` list that
## Offers.do_action applies, so the UI, the bot and saves all treat them the same way.

static func make(kind: String, title: String, subtitle: String, color: String, options: Array, rerollable: bool = false) -> Dictionary:
	return {"kind": kind, "title": title, "subtitle": subtitle, "color": color, "options": options, "rerollable": rerollable}

static func opt(id: String, name: String, desc: String, tag: String, rarity: int, color: String, icon: String, actions: Array, extra: Dictionary = {}) -> Dictionary:
	var o := {"id": id, "name": name, "desc": desc, "tag": tag, "rarity": rarity, "color": color, "icon": icon, "actions": actions}
	for k in extra.keys():
		o[k] = extra[k]
	return o

## the reward offer for a room plan
static func for_reward(sim, plan: Dictionary) -> Dictionary:
	var run: RunState = sim.run
	match String(plan.get("reward", "none")):
		"boon": return Boons.offer(sim, String(plan.get("patron", "")), int(plan.get("rarity", 0)))
		"forge": return forge(sim)
		"kindle": return kindle(sim)
		"heart": return heart(sim)
		"gold": return gold(sim)
	return {}

static func forge(sim) -> Dictionary:
	var run: RunState = sim.run
	var rng := Rooms.room_rng(run, 31)
	var T: Tuning = sim.T
	var mastery: int = run.forge_unlocks
	var own: Array = T.weapons[run.weapon].forges
	var pool: Array = []
	for i in own.size():
		var fid: String = own[i]
		if i < mastery and int(run.forges.get(fid, 0)) < int(T.forges[fid].max):
			pool.append(fid)
	for fid in T.forges.keys():
		if String(T.forges[fid].weapon) == "" and int(run.forges.get(fid, 0)) < int(T.forges[fid].max):
			pool.append(fid)
	var options: Array = []
	while options.size() < 3 and not pool.is_empty():
		var k := rng.randi_range(0, pool.size() - 1)
		var fid2: String = pool[k]
		pool.remove_at(k)
		var F: Dictionary = T.forges[fid2]
		var lv := int(run.forges.get(fid2, 0))
		var weapon_specific := String(F.weapon) != ""
		options.append(opt(fid2, String(F.name), String(F.desc), "FORGE · %d → %d" % [lv, lv + 1], 2 if weapon_specific else 1, "#ffb84a", "w_" + run.weapon if weapon_specific else "i_slot_attack",
			[{"type": "forge", "id": fid2}], {"before": "Level %d" % lv, "after": "Level %d" % (lv + 1)}))
	if options.is_empty():
		return heart(sim)
	return make("forge", "The Forge-Spark", "Your %s remembers how it was made." % T.weapons[run.weapon].name, "#ffb84a", options, true)

static func kindle(sim) -> Dictionary:
	var run: RunState = sim.run
	var rng := Rooms.room_rng(run, 32)
	var owned: Array = run.boons.filter(func(b): return int(b.get("level", 1)) < 6)
	if owned.is_empty():
		return heart(sim)
	var options: Array = []
	owned = owned.duplicate()
	while options.size() < 3 and not owned.is_empty():
		var k := rng.randi_range(0, owned.size() - 1)
		var b: Dictionary = owned[k]
		owned.remove_at(k)
		var d := Boons.def(b.id)
		var lv := int(b.get("level", 1))
		options.append(opt(b.id, "%s → Lv %d" % [d.get("name", b.id), lv + 1], Boons.describe(b.id, int(b.rarity), lv + 1), "KINDLE · " + Boons.RARITY_NAMES[int(b.rarity)], int(b.rarity), Boons.hex_of(b.id), "i_slot_" + Boons.slot_of(b.id),
			[{"type": "kindle", "id": b.id}], {"before": Boons.describe(b.id, int(b.rarity), lv), "after": Boons.describe(b.id, int(b.rarity), lv + 1)}))
	return make("kindle", "Kindling", "Feed a light you already carry.", "#ffd27a", options, true)

static func heart(sim) -> Dictionary:
	var p: SimPlayer = sim.player
	var half = round(p.max_hp * 0.5)
	return make("heart", "Heartwood", "Something warm grows here.", "#ff5d7a", [
		opt("vital", "Vitality", "+18 max health and heal 18.", "HEART", 1, "#ff5d7a", "i_heart", [{"type": "max_hp", "amount": 18.0}, {"type": "heal", "amount": 18.0}],
			{"before": "%d max HP" % p.max_hp, "after": "%d max HP" % (p.max_hp + 18)}),
		opt("mend", "Mend", "Heal %d health (50%%)." % half, "HEART", 0, "#5dff9a", "i_heal", [{"type": "heal", "amount": half}],
			{"before": "%d HP" % p.hp, "after": "%d HP" % minf(p.max_hp, p.hp + half)}),
		opt("sap", "Ember Sap", "+8 max health, heal 20% and +25 gold.", "HEART", 0, "#ffd27a", "i_heart", [{"type": "max_hp", "amount": 8.0}, {"type": "heal", "amount": round(p.max_hp * 0.2)}, {"type": "gold", "amount": 25}]),
	])

static func gold(sim) -> Dictionary:
	var run: RunState = sim.run
	var sc := 1.0 + (run.depth - 1) * 0.35
	return make("gold", "A Moth-Merchant's Purse", "Coins hum when you hold them.", "#ffd166", [
		opt("purse", "Full Purse", "+%d gold." % round(70 * sc), "GOLD", 0, "#ffd166", "i_gold", [{"type": "gold", "amount": round(70 * sc)}]),
		opt("tithe", "Tithe", "+%d gold and heal 15." % round(40 * sc), "GOLD", 0, "#ffd166", "i_gold", [{"type": "gold", "amount": round(40 * sc)}, {"type": "heal", "amount": 15.0}]),
		opt("gamble", "Coin Flip", "50%%: +%d gold. 50%%: +%d." % [round(150 * sc), round(10 * sc)], "GAMBLE", 2, "#c07bff", "i_gold", [{"type": "gamble", "win": round(150 * sc), "lose": round(10 * sc)}]),
	])

# ───────── shop ─────────

static func price(sim, base_key: String) -> int:
	var E: Dictionary = sim.T.economy
	return int(round(float(E.shop_prices[base_key]) * (1.0 + float(E.shop_price_depth_mul) * (sim.run.depth - 1))))

static func shop_stock(sim) -> Array:
	var run: RunState = sim.run
	var rng := Rooms.room_rng(run, 40)
	var items: Array = []
	var p: SimPlayer = sim.player
	# two boons from different Lights
	var used: Array = []
	for i in 2:
		var pat: String = Rooms._pick_patron(rng, run, used)
		used.append(pat)
		var bo := Boons.offer(sim, pat, 0, 1, rng)
		if not bo.is_empty() and not bo.options.is_empty():
			var o: Dictionary = bo.options[0].duplicate(true)
			o.price = price(sim, "boon")
			items.append(o)
	items.append(opt("heal", "Ember Broth", "Heal 30 health.", "HEAL", 0, "#5dff9a", "i_heal", [{"type": "heal", "amount": 30.0}], {"price": price(sim, "heal")}))
	items.append(opt("heart", "Heartwood Seed", "+15 max health.", "HEART", 1, "#ff5d7a", "i_heart", [{"type": "max_hp", "amount": 15.0}, {"type": "heal", "amount": 15.0}], {"price": price(sim, "heart")}))
	var fo := forge(sim)
	if fo.kind == "forge":
		var f0: Dictionary = fo.options[0].duplicate(true)
		f0.price = price(sim, "forge")
		items.append(f0)
	items.append(opt("reroll", "Moth Wing", "+1 reroll.", "REROLL", 0, "#d8c8ff", "i_reroll", [{"type": "reroll", "amount": 1}], {"price": price(sim, "reroll")}))
	items.append(opt("fate", "Fate Die", "+1 Fate Die: reroll a choice with +1 rarity.", "FATE", 2, "#c07bff", "i_die", [{"type": "fate", "amount": 1}], {"price": price(sim, "fate_die")}))
	for it in items:
		it["sold"] = false
	return items

# ───────── ordeals ─────────

static func ordeal_prompt(sim, plan: Dictionary) -> Dictionary:
	var O: Dictionary = sim.T.rooms.ordeals
	var id: String = plan.get("ordeal", "altar")
	var info: Dictionary = O[id]
	var desc := ""
	match id:
		"altar": desc = String(info.desc) % int(round(sim.run.max_hp() * float(info.hp_cost_frac)))
		"gauntlet": desc = String(info.desc) % int(info.gold)
		"wager": desc = String(info.desc) % [int(info.stake), int(info.max_damage)]
	return make("ordeal", String(info.name), desc, "#c07bff", [
		opt("accept", "Accept", desc, "ORDEAL", 2, "#c07bff", "i_slot_legendary", [{"type": "ordeal_accept", "ordeal": id}]),
		opt("decline", "Walk away", "Leave the ordeal untouched.", "", 0, "#a89cb4", "i_slot_passive", [{"type": "ordeal_decline"}]),
	])

# ───────── applying ─────────

static func do_action(sim, a: Dictionary) -> void:
	var run: RunState = sim.run
	match String(a.type):
		"boon":
			Boons.grant(sim, String(a.id), int(a.get("rarity", 0)))
		"forge":
			run.forges[a.id] = int(run.forges.get(a.id, 0)) + 1
			run.recompute(sim)
		"kindle":
			var b = run.boon(String(a.id))
			if b != null:
				b.level = int(b.get("level", 1)) + 1
				run.recompute(sim)
		"max_hp":
			run.max_hp_base += float(a.amount)
			run.recompute(sim)
		"heal":
			Combat.heal_player(sim, float(a.amount), "reward")
		"gold":
			run.add_gold(int(a.amount))
		"gamble":
			run.add_gold(int(a.win) if sim.rng.randf() < 0.5 else int(a.lose))
		"reroll":
			run.rerolls += int(a.amount)
		"fate":
			run.fate_dice += int(a.amount)
		"embers":
			run.embers += int(a.amount)
