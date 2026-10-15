extends SceneTree
## A locomoting/combat actor must never select the seated canonical artwork.
func _initialize() -> void:
	var player = preload("res://scripts/creature_pose_player.gd").new()
	player.prepare()
	assert(player.sheet != null and player.regions.size() == 12)
	var sheet_bounds := Rect2(Vector2.ZERO, player.sheet.get_size())
	for rect: Rect2 in player.regions:
		assert(rect.has_area() and sheet_bounds.encloses(rect), "Every posture must have visible pixels inside the sheet")
	assert(player.sample("traveller", 10.0, false, false) == -1, "Settled rest may use seated artwork")
	assert(player.sample("traveller", 11.0, true, false) >= 0, "Walking must first leave the seated artwork")
	var gait_frames: Dictionary = {}
	for tick in range(1, 200):
		var frame: int = player.sample("traveller", 11.0 + float(tick) / 60.0, true, false)
		assert(frame >= 0 and frame < player.regions.size(), "No walking frame may be a seated or invalid source")
		if tick > 12:
			gait_frames[frame] = true
	assert(not gait_frames.is_empty(), "Walking requires an upright pose source")
	for frame in gait_frames:
		assert(int(frame) <= 8, "Walking must not select sitting, blink or hurt art")
	assert(player.sample("traveller", 15.0, false, false) >= 0, "Stopping settles upright feet before sitting")
	assert(player.sample("traveller", 15.4, false, false) >= 0, "Sitting cannot happen during settling")
	assert(player.sample("traveller", 15.9, false, false) == -1, "Settled actor may return to seated idle")
	assert(player.sample("traveller", 16.0, false, true) >= 0, "Entering combat from rest must select standing art")
	var saw_blink := false
	for tick in range(1, 400):
		var frame: int = player.sample("traveller", 16.0 + float(tick) / 60.0, false, true)
		assert(frame >= 0, "Combat must never return to seated idle")
		if frame == 10:
			saw_blink = true
	assert(saw_blink, "Standing idle in combat must retain the authored blink")
	# Independent actor keys cannot reset another member's posture transition.
	assert(player.sample("resting_member", 23.0, false, false) == -1)
	assert(player.sample("traveller", 23.0, true, true) >= 0)
	print("POSE PLAYER PASS: 12 valid alpha-trimmed poses; upright locomotion source; rest/stand/walk/stop/combat/blink; no seated locomotion; independent actors")
	quit()
