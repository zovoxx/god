class_name SimPlayer
extends SimBody
## Wren. Movement, dash (i-frames, charges), input buffering and the action state machine.
## Weapon-specific behaviour lives in sim/weapons/*.gd; this script owns timing rules that
## are shared by all weapons (buffer, dash-cancel of recovery, dash-attack window).

enum St { FREE, ATTACK, DASH, SPECIAL, CAST, DEAD }

var state := St.FREE
var hp := 60.0
var max_hp := 60.0
var barrier := 0.0
var hit_radius := 8.0
var aim_dir := Vector2.RIGHT
var aim_target = null            # SimEnemy or null
var move_dir := Vector2.ZERO

# dash
var dash_charges := 1
var dash_max := 1
var dash_cd := 0.0
var dash_t := 0.0
var dash_dir := Vector2.RIGHT
var dash_speed := 0.0
var dash_iframes := 0.0
var dash_started_at := -99.0
var dash_ended_at := -99.0
var dash_hit := {}               # enemy ids touched by this dash (dash-through boons)
var dash_from := Vector2.ZERO

# hurt
var hurt_iframes := 0.0
var hurt_lock := 0.0
var invuln_t := 0.0              # generic invulnerability (defiance, transitions)

# attack (shared bookkeeping, weapons fill it)
var atk_step := 0
var atk_phase := 0               # 0 windup, 1 active, 2 recovery
var atk_t := 0.0
var atk := {}                    # current frame data
var atk_hits := {}               # enemy id -> true for this swing
var atk_is_dash := false
var atk_dir := Vector2.RIGHT
var atk_cur := 0
var combo_timer := 0.0
var queued_attack := false

# special / cast
var special_cd := 0.0
var special_t := 0.0
var special_charge := 0.0
var cast_charges := 2
var cast_max := 2
var cast_recharge := 0.0
var cast_t := 0.0

# feel / meta
var overdrive := 0.0
var overdrive_ready := false
var overdrive_idle := 0.0
var guaranteed_crit := 0
var squash := 0.0
var wstate := {}                 # free-form per-weapon state

var buf := {"attack": -99.0, "special": -99.0, "dash": -99.0, "cast": -99.0}

func setup(T: Tuning) -> void:
	radius = T.player.radius
	hit_radius = T.player.hit_radius
	max_hp = T.player.max_hp
	hp = max_hp
	dash_max = T.dash.charges
	dash_charges = dash_max
	cast_max = T.cast.charges
	cast_charges = cast_max

func is_invuln() -> bool:
	return dash_iframes > 0.0 or hurt_iframes > 0.0 or invuln_t > 0.0 or state == St.DEAD

func dash_origin() -> Vector2:
	return dash_from

func is_dashing() -> bool:
	return state == St.DASH

func press(action: String, now: float) -> void:
	buf[action] = now

func buffered(action: String, now: float, window: float) -> bool:
	return now - float(buf[action]) <= window

func consume(action: String) -> void:
	buf[action] = -99.0
