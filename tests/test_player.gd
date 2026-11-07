extends TestBase

func test_dash_iframes() -> void:
	var s := make_sim()
	s.step(press("dash"), 1.0 / 60.0)
	check(s.player.state == SimPlayer.St.DASH, "dash starts on press")
	check(s.player.is_invuln(), "dash grants i-frames")
	var iframes: float = T.dash.iframes
	steps(s, int(ceil(iframes * 60.0)) + 1)
	check(not s.player.is_invuln(), "i-frames end after %ss" % iframes)

func test_dash_distance() -> void:
	var s := make_sim()
	var start := s.player.pos
	var f := press("dash")
	f.move = Vector2.RIGHT
	s.step(f, 1.0 / 60.0)
	steps(s, int(ceil(float(T.dash.duration) * 60.0)))
	var moved := s.player.pos.x - start.x
	check(moved >= float(T.dash.distance) * 0.9, "dash travels ~distance (moved %.1f)" % moved)

func test_dash_charges_and_cooldown() -> void:
	var s := make_sim()
	s.step(press("dash"), 1.0 / 60.0)
	check(s.player.dash_charges == 0, "one charge used")
	steps(s, 9)
	s.step(press("dash"), 1.0 / 60.0)  # ~170 ms into the cooldown: too early to be buffered
	check(s.player.state != SimPlayer.St.DASH, "cannot dash with no charge")
	steps(s, int(float(T.dash.cooldown) * 60.0) + 2)
	check(s.player.dash_charges == 1, "charge recharges after cooldown")

func test_input_buffer_window() -> void:
	# a dash pressed slightly before a charge is available still fires (150 ms buffer)
	var s := make_sim()
	s.step(press("dash"), 1.0 / 60.0)
	var cd: float = s.dash_cooldown()
	var frames_until_ready := int(ceil(cd * 60.0))
	steps(s, frames_until_ready - 6)  # ~100 ms early
	s.step(press("dash"), 1.0 / 60.0)
	var dashed := false
	for i in 12:
		s.step(InputFrame.new(), 1.0 / 60.0)
		if s.player.state == SimPlayer.St.DASH and s.time - s.player.dash_started_at < 0.05:
			dashed = true
	check(dashed, "buffered dash fires when the charge returns")
	# a press older than the buffer is dropped
	var s2 := make_sim()
	s2.step(press("dash"), 1.0 / 60.0)
	steps(s2, frames_until_ready - 14)  # ~230 ms early
	s2.step(press("dash"), 1.0 / 60.0)
	var dashed2 := false
	for i in 20:
		s2.step(InputFrame.new(), 1.0 / 60.0)
		if s2.player.state == SimPlayer.St.DASH and s2.player.dash_started_at > 0.3:
			dashed2 = true
	check(not dashed2, "stale press (> buffer) is dropped")

func test_movement_acceleration() -> void:
	var s := make_sim()
	var f := InputFrame.new()
	f.move = Vector2.RIGHT
	steps(s, 12, f)
	near(s.player.vel.length(), s.move_speed(), 1.0, "reaches max speed within 0.2 s")
	steps(s, 10, InputFrame.new())
	near(s.player.vel.length(), 0.0, 1.0, "stops quickly when released")

func test_walls_block() -> void:
	var s := make_sim()
	var f := InputFrame.new()
	f.move = Vector2.LEFT
	steps(s, 240, f)
	check(s.player.pos.x >= s.arena.rect.position.x + s.player.radius - 0.01, "player stays inside the arena")
