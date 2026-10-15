extends SceneTree
## Run with --path . --script tests/creature_motion_smoke.gd.
## Uses real CanvasItem draw commands and exports a gallery to user://.
class Gallery extends Node2D:
	var rig = preload("res://scripts/creature_motion.gd").new()
	var ids: Array[String] = ["ember", "moss", "luna", "tide", "crag", "cloud", "thornbud", "pebblebug", "reefclaw", "tidejelly", "runewisp", "shardguard", "rootelder", "abyssmaw", "moonwarden"]
	var sheets: Array[Texture2D] = []
	var frame := 0
	var draw_cost_usec := 0
	var first_pixels := PackedByteArray()
	var blink_gallery := false
	var blink_sweep := false
	var states_sweep := false
	var upright_gallery := false
	func _ready() -> void:
		blink_gallery = "--blink" in OS.get_cmdline_user_args()
		blink_sweep = "--blink-sweep" in OS.get_cmdline_user_args()
		states_sweep = "--states" in OS.get_cmdline_user_args()
		upright_gallery = "--upright" in OS.get_cmdline_user_args()
		sheets = [load("res://assets/creatures-taskmon.png"), load("res://assets/enemies.png")]
		for phase in range(62):
			assert(is_zero_approx(rig.foot_offset(float(phase) / 100.0, 0.03, 0.04).y), "Planted feet must stay at floor")
		assert(rig.foot_offset(0.8, 0.03, 0.04).y < -0.03, "Swing must clear the floor")
		for width in [64.0, 128.0, 192.0]:
			var rate := 1.2
			var stride: float = rig.stride_for_ground_speed(15.36, rate, width)
			var from: Vector2 = rig.foot_offset(0.15, stride, 0.02)
			var to: Vector2 = rig.foot_offset(0.15 + 0.01 * rate, stride, 0.02)
			assert(absf((to.x - from.x) * width / 0.01 + 15.36) < 0.001, "Planted foot must match terrain velocity at every render scale")
		for id in ids:
			assert(rig.animation_metadata(id).states.size() == 9, "Every species must expose the complete state vocabulary")
			for state in rig.STATES:
				var sample = rig.sample_animation(id, 1.13, state, 0.16, 1.0, true)
				assert(is_finite(sample.action) and sample.alpha >= 0.0 and sample.alpha <= 1.0)
			assert(rig.sample_animation(id, 1.0, "appear", 0.0).alpha == 0.0)
			assert(rig.sample_animation(id, 1.0, "death", 1.0).alpha == 0.0)
		assert(not rig.sample_animation("ember", 1.0, "locomotion").walk, "A seated fox must never be used as a walking cycle")
		assert(rig.sample_animation("ember", 1.0, "locomotion", 0.0, 0.0, true).walk, "Approved upright art unlocks the walking rig")
		assert(rig.upright_profile("ember").feet.size() == 4, "Standing fox requires four anatomical supports")
		assert(rig.upright_profile("ember").phases.size() == 4)
		assert(rig.instance_variation(12345) != rig.instance_variation(98765), "Each exemplar needs an independent motion phase")
	func _process(_delta: float) -> void:
		frame += 1
		queue_redraw()
		if frame == 3:
			await RenderingServer.frame_post_draw
			first_pixels = get_viewport().get_texture().get_image().get_data()
		if frame == 32:
			await RenderingServer.frame_post_draw
			var screenshot := get_viewport().get_texture().get_image()
			if not blink_sweep and not states_sweep:
				assert(first_pixels == screenshot.get_data(), "Reused dynamic buffers must preserve UVs and vertex layout")
			var path := "user://creature-blink-gallery.png" if blink_gallery else "user://creature-motion-gallery.png"
			assert(screenshot.save_png(path) == OK)
			print("CREATURE_MOTION_OK all 15 rigs + grounded stance + rendered gallery: ", ProjectSettings.globalize_path(path))
			print("Rig gallery average CPU draw cost (15 creatures): ", float(draw_cost_usec) / maxf(frame, 1) / 1000.0, " ms")
			get_tree().quit()
	func _draw() -> void:
		var started := Time.get_ticks_usec()
		rig.begin_frame()
		draw_rect(Rect2(0, 0, 1280, 800), Color("13202b"))
		for i in range(ids.size()):
			var is_enemy := i >= 6
			var sheet: Texture2D = sheets[1 if is_enemy else 0]
			var cell := sheet.get_size() / Vector2(3, 3 if is_enemy else 2)
			var index := i - 6 if is_enemy else i
			var region := Rect2i(Vector2(index % 3, index / 3) * cell, cell)
			if is_enemy:
				var boundaries := [0, int(sheet.get_height() / 3.0), int(sheet.get_height() * 0.6395), sheet.get_height()]
				var row := int(index / 3)
				region.position.y = boundaries[row]
				region.size.y = boundaries[row + 1] - boundaries[row]
			var used := sheet.get_image().get_region(region).get_used_rect()
			region = Rect2i(region.position + used.position, used.size)
			if upright_gallery and ids[i] == "ember":
				var poses = preload("res://scripts/creature_pose_player.gd").new()
				poses.prepare()
				sheet = poses.sheet
				region = Rect2i(poses.regions[0])
			var origin := Vector2(128 + (i % 5) * 256, 215 + int(i / 5) * 260)
			draw_set_transform(origin)
			draw_line(Vector2(-110, 0), Vector2(110, 0), Color("89a574"), 2)
			var dimensions := Vector2(region.size) / maxf(region.size.x, region.size.y) * 190.0
			var animation := {"state": "blink", "age": 0.085} if blink_gallery else {}
			if blink_sweep:
				animation = {"state": "blink", "age": float(frame % 32) / 32.0 * 0.17}
			if states_sweep:
				animation = {"state": rig.STATES[(int(frame / 3) + i) % rig.STATES.size()], "age": float(frame % 3 + 1) * 0.13}
			if upright_gallery and ids[i] == "ember":
				animation.upright = true
				animation.seed = 12345.0
			rig.paint(self, sheet, Rect2(region), Rect2(Vector2(-dimensions.x / 2, -dimensions.y), dimensions), ids[i], 1.13, true, false, Color.WHITE, 0.0, animation)
			draw_string(ThemeDB.fallback_font, Vector2(-70, 24), ids[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
		draw_set_transform(Vector2.ZERO)
		draw_cost_usec += Time.get_ticks_usec() - started

func _initialize() -> void:
	root.size = Vector2i(1280, 800)
	root.add_child.call_deferred(Gallery.new())
