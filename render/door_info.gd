class_name DoorInfo
extends RefCounted
## What a door shows in advance: room type icon, reward icon, label and colour.

static func info(plan: Dictionary) -> Dictionary:
	var t: String = plan.get("type", "combat")
	var reward: String = plan.get("reward", "none")
	var out := {"type_icon": "i_combat", "reward_icon": "", "label": "", "color": Color("#e8e0d0"), "sub": ""}
	match t:
		"boss":
			out.type_icon = "i_boss"
			out.label = "BOSS"
			out.color = Cfg.col("boss")
			out.sub = Rooms.depth_name(int(plan.depth))
		"guardian":
			out.type_icon = "i_guardian"
			out.label = "GUARDIAN"
			out.color = Cfg.col("boss")
		"shop":
			out.type_icon = "i_shop"
			out.label = "SHOP"
			out.color = Color("#ffd166")
		"spring":
			out.type_icon = "i_spring"
			out.label = "SPRING"
			out.color = Cfg.col("pickup")
		"ordeal":
			out.type_icon = "i_ordeal"
			out.label = String(Cfg.T.rooms.ordeals[plan.get("ordeal", "altar")].name).to_upper()
			out.color = Color("#c07bff")
		"elite":
			out.type_icon = "i_elite"
			out.label = "ELITE"
			out.color = Color("#ffd166")
	if reward != "none" and t != "shop" and t != "spring":
		match reward:
			"boon":
				var pat: String = plan.get("patron", "")
				out.reward_icon = "p_" + pat
				var pd := Boons.patron(pat)
				if out.label == "":
					out.label = String(pd.get("name", "BOON")).to_upper()
				else:
					out.sub = String(pd.get("name", ""))
				if t == "combat":
					out.color = Color.html(String(pd.get("color", "#ffffff")))
			"forge":
				out.reward_icon = "i_forge"
				if out.label == "": out.label = "FORGE"
			"kindle":
				out.reward_icon = "i_kindle"
				if out.label == "": out.label = "KINDLING"
			"heart":
				out.reward_icon = "i_heart"
				if out.label == "": out.label = "HEARTWOOD"
			"gold":
				out.reward_icon = "i_gold"
				if out.label == "": out.label = "GOLD"
	return out
