extends RefCounted
## Drawn posture overrides. A seated illustration is never used for locomotion.
var sheet: Texture2D
var regions: Array[Rect2] = []
var actors: Dictionary = {}

func prepare() -> void:
	if sheet != null:
		return
	sheet = load("res://assets/animations/ember-locomotion-v2.png")
	var pixels = sheet.get_image()
	var cell = Vector2i(pixels.get_width() / 4, pixels.get_height() / 3)
	for i in range(12):
		var rect = Rect2i(Vector2i(i % 4, i / 4) * cell, cell)
		var used = pixels.get_region(rect).get_used_rect()
		regions.append(Rect2(rect.position + used.position, used.size))

func sample(key: String, now: float, walking: bool, combat: bool) -> int:
	var active = walking or combat
	if not actors.has(key):
		actors[key] = {"active": active, "changed": now - 1.0}
	var actor: Dictionary = actors[key]
	if bool(actor.active) != active:
		actor.active = active
		actor.changed = now
	var age = now - float(actor.changed)
	if active:
		if age < 0.20:
			return 9 # Stand up before taking the first step.
		if walking:
			return 1 + int((now - float(actor.changed) - 0.20) * 12.0) % 8
		return 10 if fposmod(now + float(key.hash() % 31) * 0.1, 4.3) > 4.14 else 0
	if age < 0.55:
		return 0 # Settle the feet before lowering the hindquarters.
	if age < 0.78:
		return 9
	return -1 # Canonical seated idle is allowed only after stopping.

func pose_size(frame: int, extent: float, base_height_ratio: float) -> Vector2:
	return regions[frame].size * (extent * base_height_ratio / maxf(1, regions[0].size.y))
