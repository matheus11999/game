extends RefCounted
## Presentation only: the server already owns battle creation, HP and rewards.
## The field remains visible while the team approaches a visible opponent.
## No Node, timers, global clock or network dependencies: update() is deterministic.

const APPROACH_DURATION := 2.2
const ENGAGE_DURATION := 0.95
const VS_DURATION := 0.70
const DISENGAGE_DURATION := 0.85
# Match ordinary world travel (24 units/s), keeping map speed and stride phase
# identical when a server-created encounter begins its visible approach.
const APPROACH_DISTANCE := 24.0 * APPROACH_DURATION
const PREVIEW_OFFSET := 80.0

var phase: StringName = &"travel"
var battle_id := ""
var journey_active := false
var approach_progress := 0.0
var camera_blend := 0.0
var can_act := false
var can_autoclose := false
var show_vs := false
var vs_progress := 0.0
var enemy_world_offset := PREVIEW_OFFSET
var walking := false
var locomotion_clock := 0.0
# distance_delta is this update's approach displacement. The accumulated value
# is an alternative convenience API; consume it once, never add both to travel.
var distance_delta := 0.0
var travel_distance_extra := 0.0
var battle_finished := false
var phase_started_at := 0.0
var battle_started_at := 0.0
var _clock := 0.0
var _phase_elapsed := 0.0
var _disengage_from := 0.0
var _speed := 1.0

func begin_battle(id: String, now: float, options: Dictionary = {}) -> bool:
	if id.is_empty():
		return false
	if id == battle_id and phase in [&"approach", &"engage", &"combat"]:
		if bool(options.get("finished", false)):
			_mark_finished()
		return false
	battle_id = id
	_clock = now
	battle_started_at = now
	phase_started_at = now
	_phase_elapsed = 0.0
	distance_delta = 0.0
	journey_active = bool(options.get("journey_active", journey_active))
	battle_finished = bool(options.get("finished", false))
	var resume := bool(options.get("restored", false)) or int(options.get("round", 0)) > 0 or battle_finished
	phase = &"combat" if resume else &"approach"
	approach_progress = 1.0 if resume else 0.0
	camera_blend = 1.0 if resume else 0.0
	enemy_world_offset = 0.0 if resume else PREVIEW_OFFSET
	_refresh()
	return true

func update(delta: float, travel_speed_factor: float = 1.0, finished: bool = false) -> void:
	distance_delta = 0.0
	if not is_finite(delta) or delta <= 0.0:
		if finished:
			_mark_finished()
		_refresh()
		return
	_speed = maxf(0.0, travel_speed_factor) if is_finite(travel_speed_factor) else 0.0
	_clock += delta
	if finished and not battle_id.is_empty():
		_mark_finished()
	var remaining := delta
	# At most four finite phases can be crossed; a 5 FPS update and a 144 FPS
	# update therefore produce the same progression, displacement and VS timing.
	for _transition in range(5):
		if remaining <= 0.0000001:
			break
		match phase:
			&"travel":
				if journey_active:
					locomotion_clock += remaining * _speed
				break
			&"approach":
				if _speed <= 0.000001:
					break
				var step := minf(remaining, maxf(0.0, APPROACH_DURATION - _phase_elapsed) / _speed)
				var before := approach_progress
				_phase_elapsed = minf(APPROACH_DURATION, _phase_elapsed + step * _speed)
				approach_progress = _phase_elapsed / APPROACH_DURATION
				locomotion_clock += step * _speed
				if journey_active:
					var displacement := (approach_progress - before) * APPROACH_DISTANCE
					distance_delta += displacement
					travel_distance_extra += displacement
				enemy_world_offset = PREVIEW_OFFSET * (1.0 - _ease(approach_progress))
				remaining = maxf(0.0, remaining - step)
				if _phase_elapsed >= APPROACH_DURATION - 0.000001:
					approach_progress = 1.0
					enemy_world_offset = 0.0
					_enter(&"engage", remaining)
				else:
					break
			&"engage":
				var step := minf(remaining, maxf(0.0, ENGAGE_DURATION - _phase_elapsed))
				_phase_elapsed = minf(ENGAGE_DURATION, _phase_elapsed + step)
				camera_blend = _ease(_phase_elapsed / ENGAGE_DURATION)
				remaining = maxf(0.0, remaining - step)
				if _phase_elapsed >= ENGAGE_DURATION - 0.000001:
					camera_blend = 1.0
					_enter(&"combat", remaining)
				else:
					break
			&"combat":
				break
			&"disengage":
				var step := minf(remaining, maxf(0.0, DISENGAGE_DURATION - _phase_elapsed))
				_phase_elapsed = minf(DISENGAGE_DURATION, _phase_elapsed + step)
				camera_blend = _disengage_from * (1.0 - _ease(_phase_elapsed / DISENGAGE_DURATION))
				if journey_active:
					locomotion_clock += step * _speed
				remaining = maxf(0.0, remaining - step)
				if _phase_elapsed >= DISENGAGE_DURATION - 0.000001:
					camera_blend = 0.0
					approach_progress = 0.0
					enemy_world_offset = PREVIEW_OFFSET
					_enter(&"travel", remaining)
				else:
					break
	_refresh()

func end_battle(now: float) -> void:
	if battle_id.is_empty() or phase in [&"travel", &"disengage"]:
		return
	_clock = now
	_disengage_from = camera_blend
	battle_id = ""
	battle_finished = false
	_phase_elapsed = 0.0
	phase_started_at = now
	phase = &"disengage"
	_refresh()

func consume_travel_distance() -> float:
	var result := travel_distance_extra
	travel_distance_extra = 0.0
	return result

func reset(now: float = 0.0) -> void:
	phase = &"travel"
	battle_id = ""
	battle_finished = false
	journey_active = false
	approach_progress = 0.0
	camera_blend = 0.0
	enemy_world_offset = PREVIEW_OFFSET
	locomotion_clock = 0.0
	distance_delta = 0.0
	travel_distance_extra = 0.0
	_clock = now
	phase_started_at = now
	_phase_elapsed = 0.0
	_refresh()

func _enter(next: StringName, remaining: float) -> void:
	phase = next
	_phase_elapsed = 0.0
	phase_started_at = _clock - remaining

func _mark_finished() -> void:
	battle_finished = true
	if not battle_id.is_empty() and phase in [&"approach", &"engage"]:
		# Restored completed battles are immediately actionable results. They must
		# never replay approach/VS or add visual travel to a finished encounter.
		phase = &"combat"
		_phase_elapsed = 0.0
		approach_progress = 1.0
		camera_blend = 1.0
		enemy_world_offset = 0.0

func _refresh() -> void:
	show_vs = phase == &"engage" and _phase_elapsed < VS_DURATION
	vs_progress = clampf(_phase_elapsed / VS_DURATION, 0.0, 1.0) if phase == &"engage" else 0.0
	can_act = phase == &"combat" and not battle_finished and not battle_id.is_empty()
	can_autoclose = phase == &"combat" and battle_finished and not battle_id.is_empty()
	walking = _speed > 0.0 and (phase == &"approach" or (journey_active and phase in [&"travel", &"disengage"]))

func _ease(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
