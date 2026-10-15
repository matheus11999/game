extends RefCounted
## Deterministic, allocation-light combat choreography. Call only from CanvasItem._draw().
## Coordinates belong to the caller; power scales artwork, never gameplay damage.

const OUTLINE := Color("111a30")
const LIGHT := Color("fff2cf")
const PROFILES := {
	"ember": ["flame", "ffb34f", "f26b45"],
	"moss": ["leaf", "a0df90", "439e83"],
	"luna": ["moon", "e5d4ff", "a696e9"],
	"tide": ["wave", "94f0e6", "439dc6"],
	"crag": ["crystal", "d6c1fa", "9a80c6"],
	"cloud": ["wind", "f8edc9", "81c9c9"],
	"thornbud": ["thorn", "bed77b", "65975d"],
	"pebblebug": ["dust", "ddc698", "998e91"],
	"reefclaw": ["fang", "87e2d2", "488aaf"],
	"tidejelly": ["pulse", "b4eeec", "86a1e5"],
	"runewisp": ["bolt", "d7b6fa", "926ce0"],
	"shardguard": ["crystal", "dae3f9", "8aa3da"],
	"rootelder": ["roots", "d5cd8c", "668d66"],
	"abyssmaw": ["abyss", "97dcd9", "5672a7"],
	"moonwarden": ["runes", "f2dfaa", "a99ae7"]
}

func paint(canvas: CanvasItem, species_id: String, origin: Vector2, target: Vector2, age: float, event_kind: String, power: float = 1.0) -> void:
	if age < 0.0 or age > 1.1:
		return
	var profile: Array = PROFILES.get(species_id, PROFILES["cloud"])
	var kind: String = str(profile[0])
	var primary := Color(str(profile[1]))
	var secondary := Color(str(profile[2]))
	var scale := clampf(power, 0.3, 2.0)
	var t := clampf(age / 1.1, 0.0, 1.0)
	var alpha := clampf((1.0 - t) * 4.0, 0.0, 1.0)
	primary.a = alpha
	secondary.a = alpha * 0.8
	match event_kind:
		"heal":
			_heal(canvas, target, t, scale, primary, secondary, kind == "moon")
		"shield":
			_shield(canvas, target, t, scale, primary, secondary, kind)
		"hit":
			_impact(canvas, target, t, scale, primary, secondary, kind, 8)
		"attack":
			_attack(canvas, origin, target, t, scale, primary, secondary, kind)

func _attack(c: CanvasItem, a: Vector2, b: Vector2, t: float, s: float, p: Color, q: Color, kind: String) -> void:
	var flight := clampf(t / 0.48, 0.0, 1.0)
	var impact := maxf(0.0, (t - 0.42) / 0.58)
	var direction := (b - a).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	var normal := Vector2(-direction.y, direction.x)
	var head := a.lerp(b, _smooth(flight))
	var lift := sin(flight * PI) * s
	if kind in ["flame", "leaf", "thorn", "moon", "dust"]:
		head += Vector2.UP * lift * 32.0
	if flight < 1.0:
		for i in range(7):
			var behind := maxf(0.0, flight - float(i) * 0.028)
			var trail := a.lerp(b, _smooth(behind))
			if kind in ["flame", "leaf", "thorn", "moon", "dust"]:
				trail += Vector2.UP * sin(behind * PI) * 32.0 * s
			var size := (7.0 - float(i) * 0.65) * s
			var tint := q.lerp(p, 1.0 - float(i) / 7.0)
			tint.a *= 1.0 - float(i) / 8.0
			_cluster(c, trail, size, tint)
		match kind:
			"flame":
				_diamond(c, head, Vector2(10, 16) * s, p)
				_diamond(c, head - direction * 7.0 * s, Vector2(5, 8) * s, LIGHT * Color(1, 1, 1, p.a))
			"leaf", "thorn":
				for j in range(3):
					var point := head + normal * float(j - 1) * 10.0 * s
					_diamond(c, point, Vector2(12, 4) * s, p, direction.angle() - 0.5 + float(j) * 0.5)
			"moon":
				_ring(c, head, 13.0 * s, p, 2.0 * s)
				_star(c, head, 9.0 * s, p)
			"wave", "abyss", "fang":
				for j in range(3):
					c.draw_arc(head - direction * float(j) * 7.0 * s, (12.0 + j * 4.0) * s, direction.angle() - 1.3, direction.angle() + 1.3, 12, p if j == 0 else q, 3.0 * s, true)
				if kind == "fang":
					_diamond(c, head + normal * 8.0 * s, Vector2(11, 3) * s, LIGHT, direction.angle())
			"crystal":
				_diamond(c, head, Vector2(14, 7) * s, p, direction.angle())
				c.draw_line(head - direction * 8.0 * s, head + direction * 8.0 * s, LIGHT, s)
			"wind", "pulse":
				for j in range(3):
					c.draw_arc(head, (8.0 + j * 5.0) * s, t * 12.0 + j * 2.0, t * 12.0 + j * 2.0 + 3.5, 16, p, 2.0 * s, true)
			"bolt", "runes":
				var line := PackedVector2Array()
				for j in range(7):
					line.append(head - direction * float(j) * 7.0 * s + normal * sin(float(j) * 2.2) * 8.0 * s)
				c.draw_polyline(line, q, 6.0 * s, true)
				c.draw_polyline(line, p, 2.0 * s, true)
				_star(c, head, 10.0 * s, p)
			"roots":
				for j in range(3):
					var bend := normal * float(j - 1) * 12.0 * s
					c.draw_polyline(PackedVector2Array([head - direction * 22.0 * s, head - direction * 10.0 * s + bend, head]), q, 4.0 * s, true)
				_diamond(c, head, Vector2(12, 4) * s, p, direction.angle())
			_:
				_cluster(c, head, 10.0 * s, p)
	if t >= 0.42:
		_impact(c, b, impact, s * (1.25 if kind in ["roots", "abyss", "runes"] else 1.0), p, q, kind, 10)

func _impact(c: CanvasItem, pos: Vector2, t: float, s: float, p: Color, q: Color, kind: String, count: int) -> void:
	var fade := (1.0 - t) * p.a
	p.a = fade
	q.a = fade * 0.65
	var burst := 8.0 + sqrt(t) * 38.0
	if t < 0.5:
		_ring(c, pos, burst * s, q, (3.0 - t * 4.0) * s)
	for i in range(count):
		var angle := float(i) * TAU / float(count) + 0.23
		var radial := Vector2.from_angle(angle)
		var point := pos + radial * burst * s + Vector2.DOWN * t * t * 17.0 * s
		if kind in ["leaf", "thorn", "roots", "crystal", "runes"]:
			_diamond(c, point, Vector2(6, 3) * s * (1.0 - t * 0.6), p, angle)
		else:
			_cluster(c, point, (4.0 - t * 2.5) * s, p if i % 2 == 0 else q)
	if t < 0.28:
		_star(c, pos, (1.0 - t / 0.28) * 18.0 * s, Color(1.0, 0.95, 0.8, fade))

func _heal(c: CanvasItem, pos: Vector2, t: float, s: float, p: Color, q: Color, moon: bool) -> void:
	for i in range(8):
		var phase := fmod(t + float(i) / 8.0, 1.0)
		var angle := float(i) * 2.4 + t * 3.0
		var point := pos + Vector2(sin(angle) * 24.0 * s, (16.0 - phase * 66.0) * s)
		var tint := p
		tint.a *= sin(phase * PI)
		if moon:
			_star(c, point, 4.0 * s, tint)
		else:
			var radius := 4.0 * s
			c.draw_line(point - Vector2(radius, 0), point + Vector2(radius, 0), tint, 2.0 * s)
			c.draw_line(point - Vector2(0, radius), point + Vector2(0, radius), tint, 2.0 * s)
	var ring := 25.0 * s * (0.8 + sin(t * PI) * 0.3)
	c.draw_arc(pos + Vector2.DOWN * 18.0 * s, ring, 0, TAU, 32, q, 2.0 * s, true)
	if moon:
		c.draw_arc(pos + Vector2.UP * 23.0 * s, 13.0 * s, 0.6, 5.1, 20, p, 3.0 * s, true)

func _shield(c: CanvasItem, pos: Vector2, t: float, s: float, p: Color, q: Color, kind: String) -> void:
	var appear := _smooth(minf(1.0, t / 0.18))
	var radius := (27.0 + sin(t * PI) * 5.0) * s * appear
	# The first frame has zero area; subpixel polygons cannot triangulate reliably.
	if radius < 0.5 or p.a <= 0.002:
		return
	var polygon := PackedVector2Array()
	for i in range(6):
		polygon.append(pos + Vector2.from_angle(-PI / 2.0 + float(i) * TAU / 6.0) * radius)
	var fill := q
	fill.a *= 0.12
	c.draw_colored_polygon(polygon, fill)
	polygon.append(polygon[0])
	c.draw_polyline(polygon, q, 5.0 * s, true)
	c.draw_polyline(polygon, p, 2.0 * s, true)
	for i in range(6):
		var point := polygon[i]
		if kind in ["leaf", "thorn", "roots"]:
			_diamond(c, point, Vector2(7, 3) * s * appear, p, float(i) * PI / 3.0)
		elif kind in ["crystal", "runes"]:
			_diamond(c, point, Vector2(4, 8) * s * appear, p)
		else:
			_cluster(c, point, 3.0 * s, p)
	_star(c, pos, 8.0 * s * appear, p)

func _cluster(c: CanvasItem, pos: Vector2, radius: float, tint: Color) -> void:
	var r := maxf(1.0, radius)
	c.draw_rect(Rect2((pos - Vector2(r, r * 0.5)).round(), Vector2(r * 2, r).round()), tint)
	c.draw_rect(Rect2((pos - Vector2(r * 0.5, r)).round(), Vector2(r, r * 2).round()), tint)

func _diamond(c: CanvasItem, pos: Vector2, size: Vector2, tint: Color, angle: float = 0.0) -> void:
	# Fade-in/out can collapse both triangles to identical points. Skip invisible
	# geometry rather than passing zero/subpixel area to the renderer.
	if not pos.is_finite() or not size.is_finite() or not is_finite(angle):
		return
	if minf(size.x, size.y) < 0.25 or tint.a <= 0.002:
		return
	var vertices := PackedVector2Array()
	var border := PackedVector2Array()
	for point in [Vector2(-size.x, 0), Vector2(0, -size.y), Vector2(size.x, 0), Vector2(0, size.y)]:
		vertices.append(pos + point.rotated(angle))
		border.append(pos + (point * 1.18).rotated(angle))
	var ink := OUTLINE
	ink.a = tint.a * 0.75
	c.draw_colored_polygon(border, ink)
	c.draw_colored_polygon(vertices, tint)

func _star(c: CanvasItem, pos: Vector2, radius: float, tint: Color) -> void:
	_diamond(c, pos, Vector2(radius * 0.35, radius), tint)
	_diamond(c, pos, Vector2(radius, radius * 0.35), tint)

func _ring(c: CanvasItem, pos: Vector2, radius: float, tint: Color, width: float) -> void:
	c.draw_arc(pos, maxf(1.0, radius), 0, TAU, 24, tint, maxf(1.0, width), true)

func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
