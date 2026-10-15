extends SceneTree
class Board extends Node2D:
	var sheet: Texture2D = preload("res://assets/enemies.png")
	var frames := 0
	func _process(_dt: float) -> void:
		frames += 1
		queue_redraw()
		if frames == 3:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("user://creature-eye-calibration.png")
			get_tree().quit()
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 1280), Color("202838"))
		if "--bottom" in OS.get_cmdline_user_args():
			draw_set_transform(Vector2(0, -730))
		draw_texture(sheet, Vector2.ZERO)
		for x in range(0, 1254, 50):
			draw_line(Vector2(x, 0), Vector2(x, 1254), Color(1, 0.8, 0.1, 0.30))
			for y in range(50, 1254, 100):
				draw_string(ThemeDB.fallback_font, Vector2(x + 2, y - 2), str(x) + "," + str(y), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.YELLOW)
		for y in range(0, 1254, 50):
			draw_line(Vector2(0, y), Vector2(1254, y), Color(1, 0.8, 0.1, 0.30))
func _initialize() -> void:
	root.size = Vector2i(1280, 1280)
	root.add_child.call_deferred(Board.new())
