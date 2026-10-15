extends SceneTree
## Regression: a basic attack must contain an independently rendered projectile,
## with visible pixels between actor and target, not just actor translation.
class Gallery extends Control:
	var painter = preload("res://scripts/combat_effects.gd").new()
	var age = -1.0
	var only_species = ""
	var font: Font = load("res://assets/fonts/Inter.ttf")
	var species = ["ember", "moss", "luna", "tide", "crag", "cloud"]
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("111d2b"))
		draw_string(font, Vector2(30, 32), "ATAQUE BÁSICO", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("e7c58a"))
		draw_string(font, Vector2(680, 32), "HABILIDADE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("e7c58a"))
		for i in range(6):
			var y = 108.0 + i * 96
			draw_string(font, Vector2(24, y), species[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("b7c9d9"))
			draw_line(Vector2(95, y+12), Vector2(590,y+12), Color("263c4b"), 1)
			draw_line(Vector2(730, y+12), Vector2(1220,y+12), Color("263c4b"), 1)
			if not only_species.is_empty() and only_species != species[i]:
				continue
			painter.paint(self, species[i], Vector2(110,y), Vector2(570,y), age, "attack", 1.35, false)
			var kind = "shield" if species[i] in ["moss", "crag"] else "heal" if species[i] in ["luna", "cloud"] else "attack"
			painter.paint(self, species[i], Vector2(745,y), Vector2(1190,y), age, kind, 1.9, true)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var gallery = Gallery.new()
	root.add_child(gallery)
	await process_frame
	await RenderingServer.frame_post_draw
	var baseline = root.get_texture().get_image()
	gallery.age = 0.54
	gallery.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	var failures = 0
	for i in range(6):
		gallery.only_species = gallery.species[i]
		gallery.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		frame = root.get_texture().get_image()
		var changed = 0
		for x in range(230, 450, 2):
			for y in range(10+i*96, 115+i*96, 2):
				var diff = frame.get_pixel(x,y) - baseline.get_pixel(x,y)
				if absf(diff.r) + absf(diff.g) + absf(diff.b) > 0.12:
					changed += 1
		print("PROJECTILE ", gallery.species[i], " changed_pixels=", changed)
		if changed < 5:
			failures += 1
	gallery.only_species = ""
	gallery.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	frame = root.get_texture().get_image()
	var destination = "C:/Users/Alienware/AppData/Local/Brumora/taskmon-captures/taskmon-projectiles-proof.png"
	frame.save_png(destination)
	print("PROJECTILE_SMOKE failures=", failures)
	quit(1 if failures else 0)
