extends SceneTree

class Preview extends Node2D:
	var painter = preload("res://scripts/procedural_world.gd").new()
	var frames := 0
	var started := 0
	var draw_usec := 0
	func _ready() -> void:
		started = Time.get_ticks_usec()
	func _process(_delta: float) -> void:
		frames += 1
		queue_redraw()
	func _draw() -> void:
		var draw_started := Time.get_ticks_usec()
		draw_rect(Rect2(0, 0, 1280, 800), Color("df4094"))
		for region in range(3):
			var rect := Rect2(20, 6 + region * 264, 1240, 250)
			painter.paint(self, null, region, rect, frames / 60.0, 1700.0, true, false)
			for x in range(0, 1281, 8):
				var height: float = painter.ground_height(region, rect, x, 1700.0, false)
				assert(absf(height - (rect.end.y - 92)) <= 7.6, "Surface exceeds contact budget")
				var next: float = painter.ground_height(region, rect, x + 1, 1700.0, false)
				assert(absf(height - next) < 0.25, "Non-continuous walk surface")
		draw_usec += Time.get_ticks_usec() - draw_started

func _initialize() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)
	var preview := Preview.new()
	root.add_child(preview)
	_run(preview)

func _run(preview: Preview) -> void:
	for i in range(24):
		await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png("res://.godot/procedural-world-review.png")
	assert(not picture.is_empty())
	for y in [0, 260, 525, 799]:
		for x in range(5, 1280, 32):
			assert(picture.get_pixel(x, y).is_equal_approx(Color("df4094")), "World paint escaped supplied rect vertically")
	for y in range(0, 800, 16):
		assert(picture.get_pixel(5, y).is_equal_approx(Color("df4094")), "World paint escaped supplied rect horizontally")
	assert(preview.painter._terrain_meshes.size() == 3, "Retained mesh per viewport")
	print("PROCEDURAL WORLD PASS: three regions, continuous shared ground, clipping, retained meshes. Frame average %.2f ms" % ((Time.get_ticks_usec() - preview.started) / 1000.0 / preview.frames))
	print("Three-world script paint CPU: %.2f ms" % (preview.draw_usec / 1000.0 / preview.frames))
	quit()
