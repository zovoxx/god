class_name Weapons
extends RefCounted
## Weapon registry.

const IDS := ["fangs", "pike", "anvil", "bow", "halo"]

static func make(id: String) -> WeaponBase:
	match id:
		"pike": return WPike.new()
		"anvil": return WAnvil.new()
		"bow": return WBow.new()
		"halo": return WHalo.new()
	return WFangs.new()
