extends SceneTree
## Deterministic crop regression: no rendered assets or account state required.

class Preview extends Node2D:
	var painter = preload("res://scripts/world_painter.gd").new()
	var atlas: Texture2D
	var biome := 0
	func _draw() -> void:
		painter.paint(self, atlas, biome, Rect2(0, 0, 1280, 484), 4.0, 640.0, true, false, true)

func _initialize() -> void:
	var painter = preload("res://scripts/world_painter.gd").new()
	for single in [false, true]:
		var texture := Vector2(4096, 3072) if not single else Vector2(1536, 1024)
		var row_height := texture.y if single else texture.y / 3.0
		for viewport in [Vector2(1280, 484), Vector2(1280, 250), Vector2(960, 600)]:
			for region in range(3):
				var backdrop_height: float = row_height * painter.BACKDROP_FRACTIONS[region]
				for zoom in [0.5, 0.9, 1.0, 1.1, 2.0]:
					painter.camera_zoom = zoom
					var row_y: float = 0.0 if single else region * row_height
					var bounds := Rect2(0, row_y, texture.x, backdrop_height)
					for travel in [-100000.0, -1.0, 0.0, 1.0, 5000.0, 100000.0]:
						var crop: Rect2 = painter._panorama_source(texture, region, viewport, travel, single)
						assert(crop.has_area())
						assert(bounds.grow(0.001).encloses(crop), "Crop sampled original painted floor or escaped biome")
						assert(crop.end.y <= row_y + backdrop_height + 0.001, "A second painted floor became visible")
						assert(absf(crop.size.x / crop.size.y - viewport.x / viewport.y) < 0.0001, "Illustration aspect distorted")
						assert(absf(crop.get_center().y - (row_y + backdrop_height * 0.5)) < 0.001, "Background-only vertical framing moved")
						var next: Rect2 = painter._panorama_source(texture, region, viewport, travel + 0.01, single)
						assert(absf(next.position.x - crop.position.x) <= 0.002, "Pan jumped at wrap/reversal")
				painter.camera_zoom = 0.9
				var wide: Rect2 = painter._panorama_source(texture, region, viewport, 0, single)
				painter.camera_zoom = 1.1
				var close: Rect2 = painter._panorama_source(texture, region, viewport, 0, single)
				assert(wide.size.x > close.size.x * 1.15, "Exploration and combat framing indistinguishable")
				assert(absf(wide.get_center().x - texture.x * 0.5) < 0.001)
				assert(absf(close.get_center().x - texture.x * 0.5) < 0.001)
	print("WORLD CAMERA PASS: 540 background-only bounded/aspect-preserving crops; original painted floors never sampled at zoom 0.5–2.0")
	if "--render-review" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		call_deferred("_render_review")
	else:
		quit()

func _render_review() -> void:
	root.min_size = Vector2i(1280, 484)
	root.content_scale_size = Vector2i(1280, 484)
	root.size = Vector2i(1280, 484)
	var preview := Preview.new()
	preview.painter.camera_zoom = 0.9
	root.add_child(preview)
	for biome in range(3):
		var key: String = ["forest", "coast", "ruins"][biome]
		preview.biome = biome
		preview.atlas = load("res://assets/world-" + key + ".png")
		preview.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://.godot/world-single-floor-" + key + ".png") == OK)
		print("NATIVE REVIEW: ", key, ", zoom0.9, one ground strip")
	preview.queue_free()
	await process_frame
	quit()
