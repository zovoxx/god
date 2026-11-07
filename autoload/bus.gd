extends Node
## Signal bus: the only channel from the simulation to presentation (FX, audio, UI).
## The simulation calls `fire(name, data)`; it emits the generic `event` signal and the
## specific named signal when one is declared below. The headless bot runs with no listeners.

signal event(name: StringName, d: Dictionary)

# --- room / flow ---
signal run_started(d: Dictionary)
signal run_ended(d: Dictionary)
signal room_entered(d: Dictionary)
signal room_cleared(d: Dictionary)
signal wave_started(d: Dictionary)
signal doors_opened(d: Dictionary)
signal offer_opened(d: Dictionary)
signal offer_closed(d: Dictionary)
signal reward_ready(d: Dictionary)
# --- combat ---
signal enemy_spawning(d: Dictionary)
signal enemy_spawned(d: Dictionary)
signal enemy_hit(d: Dictionary)
signal enemy_killed(d: Dictionary)
signal enemy_countered(d: Dictionary)
signal finisher(d: Dictionary)
signal wall_slam(d: Dictionary)
signal synergy(d: Dictionary)
signal telegraph_started(d: Dictionary)
signal telegraph_impact(d: Dictionary)
signal boss_callout(d: Dictionary)
signal boss_phase(d: Dictionary)
# --- player ---
signal player_attack(d: Dictionary)
signal player_dash(d: Dictionary)
signal perfect_dash(d: Dictionary)
signal player_hurt(d: Dictionary)
signal player_healed(d: Dictionary)
signal player_defied(d: Dictionary)
signal player_died(d: Dictionary)
signal low_hp_changed(d: Dictionary)
signal overdrive_full(d: Dictionary)
signal streak_tier(d: Dictionary)
# --- meta / ui ---
signal achievement(d: Dictionary)
signal toast(d: Dictionary)
signal settings_changed(d: Dictionary)

var _count := 0

func fire(name: StringName, d: Dictionary = {}) -> void:
	_count += 1
	event.emit(name, d)
	if has_user_signal(name) or has_signal(name):
		emit_signal(name, d)

func events_fired() -> int:
	return _count
