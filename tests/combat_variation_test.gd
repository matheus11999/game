extends SceneTree
## Same species/time, different actor seeds: patterns must remain individualized.
class Board extends Node2D:
	var effects = preload("res://scripts/combat_effects.gd").new()
	var species := ["ember", "moss", "luna", "tide", "crag", "cloud", "thornbud", "pebblebug", "reefclaw", "tidejelly", "runewisp", "shardguard", "rootelder", "abyssmaw", "moonwarden"]
	var frame := 0
	var font: Font = preload("res://assets/fonts/PixelifySans.ttf")
	func _ready() -> void:
		assert(effects.instance_variation(12345) == effects.instance_variation(12345))
		assert(absf(effects.instance_variation(12345) - effects.instance_variation(98765)) > 0.01)
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 800), Color("15202c"))
		for i in range(species.size()):
			var y := 35.0 + i * 47.0
			for column in range(2):
				var shift := Vector2(column * 640, y)
				effects.paint(self, species[i], shift + Vector2(70, 0), shift + Vector2(560, 0), 0.54, "attack", 0.65, false, 12345.0 if column == 0 else 98765.0)
		effects.paint(self, "ember", Vector2(100, 730), Vector2(215, 730), 0.08, "hit", 1.4, false, 12345)
		effects.paint(self, "ember", Vector2(740, 730), Vector2(855, 730), 0.08, "hit", 1.4, false, 98765)
		effects.paint_damage(self, null, "28", Vector2(370, 761), 0.10, Color("ffa981"), false)
		effects.paint_damage(self, null, "42!", Vector2(1010, 761), 0.10, Color("ffa981"), true)
	func _process(_delta: float) -> void:
		frame += 1
		queue_redraw()
		if frame != 3:
			return
		await RenderingServer.frame_post_draw
		var screenshot := get_viewport().get_texture().get_image()
		for i in range(species.size()):
			var changes := 0
			for y in range(maxi(0, int(35 + i * 47 - 42)), int(35 + i * 47 + 12)):
				for x in range(260, 385):
					var left := screenshot.get_pixel(x, y)
					var right := screenshot.get_pixel(x + 640, y)
					if absf(left.r - right.r) + absf(left.g - right.g) + absf(left.b - right.b) > 0.05:
						changes += 1
			assert(changes > 5, "Identical species effects require actor-specific trajectories: " + species[i])
		var path := "user://combat-instance-variation.png"
		assert(screenshot.save_png(path) == OK)
		print("COMBAT VARIATION PASS: all 15 species distinguish actor seeds; directional hit; outlined fantasy damage/critical. ", ProjectSettings.globalize_path(path))
		get_tree().quit()

func _initialize() -> void:
	root.size = Vector2i(1280, 800)
	root.add_child.call_deferred(Board.new())
