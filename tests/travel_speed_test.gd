extends SceneTree
## Pure reference-clock regression: acceleration must not be applied twice.
var failures = 0

func _initialize() -> void:
	var motion = preload("res://scripts/creature_motion.gd").new()
	for multiplier in [0.5, 1.0, 2.0, 3.0]:
		for width in [96.0, 144.0, 192.0]:
			var cadence = 0.9
			var stride = motion.stride_for_ground_speed(15.36, cadence, width)
			var dt = 0.0001
			var a = motion.foot_offset(0.2, stride, 0.012).x * width
			var b = motion.foot_offset(0.2 + dt * multiplier * cadence, stride, 0.012).x * width
			var foot_speed = -(b - a) / dt
			var map_speed = 24.0 * multiplier * 0.64
			if absf(foot_speed - map_speed) > 0.03:
				failures += 1
	print("TRAVEL SPEED: 12 scale/speed pairs; foot and ground synchronized; failures=", failures)
	quit(1 if failures else 0)
