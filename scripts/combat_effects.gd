extends RefCounted
## Deterministic, allocation-light combat choreography. Call only from CanvasItem._draw().
## Coordinates belong to the caller; power scales artwork, never gameplay damage.

const OUTLINE := Color("111a30")
const LIGHT := Color("fff2cf")
var _damage_font: Font = preload("res://assets/fonts/PixelifySans.ttf")
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

func paint(canvas: CanvasItem, species_id: String, origin: Vector2, target: Vector2, age: float, event_kind: String, power: float = 1.0, empowered: bool = false, instance_seed: float = 0.0) -> void:
	if age < 0.0 or age > 1.5:
		return
	var profile: Array = PROFILES.get(species_id, PROFILES["cloud"])
	var kind: String = str(profile[0])
	var primary := Color(str(profile[1]))
	var secondary := Color(str(profile[2]))
	var variant := instance_variation(instance_seed)
	var scale := clampf(power, 0.3, 2.0)
	var t := clampf(age / 1.5, 0.0, 1.0)
	var alpha := clampf((1.0 - t) * 4.0, 0.0, 1.0)
	primary.a = alpha
	secondary.a = alpha * 0.8
	match event_kind:
		"heal":
			_support_trail(canvas, origin, target, t, scale, primary, secondary, variant)
			_heal(canvas, target, t, scale, primary, secondary, kind == "moon", variant)
		"shield":
			_support_trail(canvas, origin, target, t, scale, primary, secondary, variant)
			_shield(canvas, target, t, scale, primary, secondary, kind, variant)
		"hit":
			_impact(canvas, target, t, scale, primary, secondary, kind, 8, (target - origin).normalized(), variant)
		"attack":
			_attack(canvas, origin, target, t, scale, primary, secondary, kind, variant)
			if empowered:
				_skill_signature(canvas, target, t, scale, primary, secondary, kind, variant)

func instance_variation(seed: float, channel: float = 0.0) -> float:
	return fposmod(sin(fposmod(seed, 65521.0) * 0.01731 + channel * 1.7131) * 43758.5453, 1.0)

func paint_damage(canvas: CanvasItem, font: Font, text: String, pos: Vector2, age: float, color: Color, crit: bool = false, font_size: int = 26, instance_seed: float = 0.0) -> void:
	if age < 0.0 or age > 1.05 or text.is_empty():
		return
	var typeface := font if font != null else _damage_font
	var pop := 1.0
	if age < 0.10:
		pop = lerpf(0.68, 1.20, 1.0 - pow(1.0 - age / 0.10, 3.0))
	elif age < 0.23:
		pop = lerpf(1.20, 1.0, smoothstep(0.0, 1.0, (age - 0.10) / 0.13))
	var size := maxi(10, roundi(font_size * pop * (1.18 if crit else 1.0)))
	var fade := 1.0 - smoothstep(0.62, 1.05, age)
	var drift := (instance_variation(instance_seed, 2.0) - 0.5) * 15.0
	var anchor := pos + Vector2(drift * age, -age * 31.0 - sin(clampf(age / 0.23, 0.0, 1.0) * PI) * 4.0)
	var width := typeface.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var baseline := (anchor - Vector2(width * 0.5, 0)).round()
	var ink := Color("ffdc87") if crit else color
	ink.a *= fade
	var shadow := Color(0.025, 0.035, 0.075, ink.a * 0.90)
	canvas.draw_string(typeface, baseline + Vector2(2, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, shadow)
	canvas.draw_string_outline(typeface, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5 if crit else 4, Color(OUTLINE, ink.a))
	canvas.draw_string(typeface, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
	# A bright upper rim is a restrained fantasy highlight, without labels or
	# an opaque plate over the creature. Critical hits add one short star accent.
	if crit and age < 0.28:
		var strength := sin(clampf(age / 0.28, 0.0, 1.0) * PI)
		_star(canvas, anchor + Vector2(-width * 0.5 - 9, -size * 0.35), 4.0 + strength * 2.0, Color(LIGHT, ink.a * strength))

func _skill_signature(c: CanvasItem, target: Vector2, t: float, s: float, p: Color, q: Color, kind: String, variant: float = 0.0) -> void:
	if t < 0.54:
		return
	var release := (t - 0.54) / 0.46
	var fade := sin(release * PI)
	if kind in ["flame", "roots", "crystal", "runes"]:
		for i in range(5):
			var spread := float(i - 2) * (11.0 + variant * 4.0) * s
			var height := sin(clampf(release * 1.8 - absf(float(i - 2)) * 0.12, 0.0, 1.0) * PI) * (45.0 - absf(float(i - 2)) * 8.0) * s
			if height > 0.3:
				var base := target + Vector2(spread, 25.0 * s)
				var top := base - Vector2(0.0, height)
				c.draw_line(base, top, Color(q, fade * 0.35), 7.0 * s, true)
				c.draw_line(base, top, Color(p, fade), 2.5 * s, true)
	else:
		for i in range(3):
			var radius := (17.0 + release * 37.0 + i * 9.0) * s
			var turn := release * 3.0 + float(i) * TAU / 3.0 + variant * TAU
			c.draw_arc(target, radius, turn, turn + 1.7, 24, Color(p if i == 0 else q, fade * 0.65), (2.5 - release) * s, true)

func _attack(c: CanvasItem, a: Vector2, b: Vector2, t: float, s: float, p: Color, q: Color, kind: String, variant: float = 0.0) -> void:
	var flight := clampf((t - 0.18) / 0.36, 0.0, 1.0)
	var impact := maxf(0.0, (t - 0.54) / 0.46)
	var direction := (b - a).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	var normal := Vector2(-direction.y, direction.x)
	var head := a.lerp(b, _smooth(flight))
	_muzzle_release(c, a, direction, t, s, p, q, kind, variant)
	var lift := sin(flight * PI) * s
	var arc_height := 52.0 + variant * 24.0
	head += normal * lift * (variant - 0.5) * 12.0
	if kind in ["flame", "leaf", "thorn", "moon", "dust"]:
		head += Vector2.UP * lift * arc_height
	if flight > 0.0 and flight < 1.0:
		for i in range(12):
			var behind := maxf(0.0, flight - float(i) * 0.014)
			var trail := a.lerp(b, _smooth(behind))
			trail += normal * sin(behind * PI) * (variant - 0.5) * 12.0 * s
			if kind in ["flame", "leaf", "thorn", "moon", "dust"]:
				trail += Vector2.UP * sin(behind * PI) * arc_height * s
			var size := (4.5 - float(i) * 0.25) * s
			var tint := q.lerp(p, 1.0 - float(i) / 12.0)
			tint.a *= 1.0 - float(i) / 13.0
			_cluster(c, trail, size, tint)
		match kind:
			"flame":
				c.draw_circle(head, 9.0 * s, Color(q, q.a * 0.12), true, -1, true)
				c.draw_circle(head, 7.0 * s, p, true, -1, true)
				c.draw_circle(head + direction * 1.5 * s, 3.6 * s, Color(LIGHT, p.a), true, -1, true)
				for j in range(3):
					var ember := head - direction * (6.0 + j * 4.5) * s + normal * sin(t * 38.0 + j + variant * TAU) * 2.0 * s
					c.draw_circle(ember, (2.7 - j * 0.7) * s, Color(q, q.a * (0.7 - j * 0.15)), true, -1, true)
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
					c.draw_arc(head, (8.0 + j * 5.0) * s, t * 12.0 + j * 2.0 + variant * TAU, t * 12.0 + j * 2.0 + variant * TAU + 3.5, 16, p, 2.0 * s, true)
			"bolt", "runes":
				var line := PackedVector2Array()
				for j in range(7):
					line.append(head - direction * float(j) * 7.0 * s + normal * sin(float(j) * 2.2 + variant * TAU) * 8.0 * s)
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
	if t >= 0.54:
		_impact(c, b, impact, s * (1.25 if kind in ["roots", "abyss", "runes"] else 1.0), p, q, kind, 10, direction, variant)

func _impact(c: CanvasItem, pos: Vector2, t: float, s: float, p: Color, q: Color, kind: String, count: int, direction: Vector2 = Vector2.RIGHT, variant: float = 0.0) -> void:
	if t < 0.0 or t > 1.0:
		return
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	var normal := direction.orthogonal()
	var fade := (1.0 - t) * p.a
	p.a = fade
	q.a = fade * 0.65
	var burst := 5.0 + sqrt(t) * 34.0
	if t < 0.40:
		var arc := direction.angle() - PI * 0.5
		c.draw_arc(pos + direction * 2.0 * s, burst * s, arc, arc + PI, 16, Color(q, fade * 0.45), maxf(1.0, (2.0 - t * 3.0) * s), false)
	for i in range(count):
		var spread := (float(i) / maxf(1.0, count - 1.0) - 0.5) * 3.0
		var jitter := sin(float(i) * 2.399 + variant * TAU) * 0.22
		var angle := direction.angle() + spread + jitter
		var radial := Vector2.from_angle(angle)
		var point := _pixel(pos + radial * burst * (0.7 + fposmod(float(i) * 0.618 + variant, 0.4)) * s + Vector2.DOWN * t * t * 17.0 * s)
		if kind in ["leaf", "thorn", "roots", "crystal", "runes"]:
			_diamond(c, point, Vector2(6, 3) * s * (1.0 - t * 0.6), p, angle)
		else:
			var tint := p if i % 2 == 0 else q
			var side := maxf(1.0, roundf((3.0 - t * 2.0) * s))
			c.draw_rect(Rect2(point, Vector2(side * 2.0, side)), Color(OUTLINE, tint.a * 0.7))
			c.draw_rect(Rect2(point - Vector2(side * 0.25, side * 0.25), Vector2.ONE * side), tint)
	if t < 0.20:
		var sharp := pow(1.0 - t / 0.20, 1.5)
		_diamond(c, pos, Vector2(13.0, 2.4) * s * sharp, Color(LIGHT, fade * 0.9), direction.angle() + 0.25)
		_diamond(c, pos - direction * 2.0 * s, Vector2(8.0, 1.8) * s * sharp, Color(p, fade), normal.angle() - 0.25)

func _heal(c: CanvasItem, pos: Vector2, t: float, s: float, p: Color, q: Color, moon: bool, variant: float = 0.0) -> void:
	# Two airy currents lift restoration through the body, leaving the face clear.
	var envelope := smoothstep(0.04, 0.20, t) * (1.0 - smoothstep(0.70, 1.0, t))
	if envelope <= 0.002:
		return
	for strand in range(2):
		var line := PackedVector2Array()
		for j in range(16):
			var rise := float(j) / 15.0
			var angle := rise * 4.8 - t * 5.0 + strand * PI + variant * TAU
			line.append(_pixel(pos + Vector2(sin(angle) * (22.0 + rise * 5.0), 39.0 - rise * 91.0) * s))
		c.draw_polyline(line, Color(q, envelope * 0.22), maxf(1.0, s), false)
	for i in range(12):
		var phase := fposmod(t * 1.25 + float(i) * 0.137 + variant * 0.45, 1.0)
		var strand := PI if i % 2 else 0.0
		var angle := phase * 4.8 - t * 5.0 + strand + variant * TAU
		var point := _pixel(pos + Vector2(sin(angle) * (22.0 + phase * 5.0), 39.0 - phase * 91.0) * s)
		var fade := sin(phase * PI) * envelope
		var tint := Color(p, fade * 0.85)
		if i % 3 == 0:
			# Tiny petals, never a repeating field of plus signs.
			_pixel_leaf(c, point, 2.4 * s, tint, i % 2 == 0)
		else:
			var side := maxf(1.0, roundf((1.2 + phase * 0.8) * s))
			c.draw_rect(Rect2(point, Vector2.ONE * side), Color(LIGHT if i % 2 else p, fade))
	_ellipse_trace(c, pos + Vector2(0, 41.0 * s), Vector2(32.0, 5.0) * s, Color(q, envelope * 0.45), maxf(1.0, s), 0.0, TAU)
	# One restorative glyph above the silhouette gives an unmistakable signal.
	var emblem := _pixel(pos + Vector2(0, -54.0 - t * 5.0) * s)
	var ink := Color(p, envelope * 0.85)
	if moon:
		_ellipse_trace(c, emblem, Vector2(7, 8) * s, ink, maxf(1.0, 2.0 * s), 0.6, 5.1)
	else:
		_pixel_leaf(c, emblem + Vector2(-2 * s, 0), 5.0 * s, ink, true)
		_pixel_leaf(c, emblem + Vector2(3 * s, -3 * s), 3.4 * s, Color(q, envelope), false)

func _shield(c: CanvasItem, pos: Vector2, t: float, s: float, p: Color, q: Color, kind: String, variant: float = 0.0) -> void:
	# A full-height ward grows from the feet, then breaks into small edge motes.
	# Broken stepped outlines read as pixel light, not a solid UI hexagon.
	var appear := smoothstep(0.02, 0.26, t)
	var vanish := smoothstep(0.68, 1.0, t)
	var envelope := appear * (1.0 - vanish)
	if envelope < 0.002:
		return
	var radius := Vector2(43.0, 50.0) * s * (0.91 + appear * 0.09)
	var segments := 28
	var reveal := appear * segments
	for i in range(segments):
		if float(i) > reveal:
			continue
		var phase := float(i) / segments
		# Dissolution rolls upward from the feet, with stable per-segment timing.
		var edge_fade := 1.0 - smoothstep(0.68 + phase * 0.12, 0.90 + phase * 0.10, t)
		var angle_a := PI * 0.5 + phase * TAU
		var angle_b := PI * 0.5 + float(i + 1) / segments * TAU
		var a := _pixel(pos + Vector2(cos(angle_a), sin(angle_a)) * radius)
		var b := _pixel(pos + Vector2(cos(angle_b), sin(angle_b)) * radius)
		var tint := p if (i + int(variant * 17.0)) % 5 in [0, 1] else q
		c.draw_line(a, b, Color(tint, envelope * edge_fade * 0.85), maxf(1.0, roundf(2.0 * s)), false)
		if i % 7 == 2 and t < 0.73:
			var inner_a := _pixel(pos + (a - pos) * 0.94)
			var inner_b := _pixel(pos + (b - pos) * 0.94)
			c.draw_line(inner_a, inner_b, Color(LIGHT, envelope * 0.6), maxf(1.0, s), false)
		if vanish > 0.0 and i % 3 == 0:
			var escape := vanish * 13.0 * s
			var mote := _pixel(a + Vector2(cos(angle_a), -1.0) * escape)
			c.draw_rect(Rect2(mote, Vector2.ONE * maxf(1.0, 1.5 * s)), Color(p, (1.0 - vanish) * 0.8))
	# The activation travels up the ward in one restrained sweep.
	if t < 0.43:
		var sweep := clampf((t - 0.08) / 0.35, 0.0, 1.0)
		var height := lerpf(radius.y, -radius.y, sweep)
		var half_width := sqrt(maxf(0.0, 1.0 - pow(height / maxf(radius.y, 0.01), 2))) * radius.x
		var left := _pixel(pos + Vector2(-half_width, height))
		var right := _pixel(pos + Vector2(half_width, height))
		c.draw_line(left, right, Color(p, sin(sweep * PI) * 0.23), maxf(1.0, s), false)
	_ellipse_trace(c, pos + Vector2(0, radius.y - 3 * s), Vector2(radius.x * 0.84, 5.0 * s), Color(q, envelope * 0.5), maxf(1.0, s), 0.0, TAU)
	# Species accents stay on the edge, preserving the canonical silhouette.
	if kind in ["leaf", "thorn", "roots", "crystal", "runes"]:
		for side in [-1.0, 1.0]:
			var accent := _pixel(pos + Vector2(side * radius.x, 0))
			_pixel_leaf(c, accent, 4.0 * s, Color(p, envelope * 0.85), kind in ["leaf", "thorn", "roots"])

func _pixel(point: Vector2) -> Vector2:
	return (point / 2.0).round() * 2.0

func _pixel_leaf(c: CanvasItem, pos: Vector2, radius: float, tint: Color, lean_right: bool) -> void:
	if tint.a < 0.005 or radius < 0.4:
		return
	var direction := 1.0 if lean_right else -1.0
	var step := maxf(1.0, roundf(radius * 0.38))
	c.draw_rect(Rect2(_pixel(pos - Vector2(step, step)), Vector2(step * 2, step * 2)), tint)
	c.draw_rect(Rect2(_pixel(pos + Vector2(direction * step, -step * 2)), Vector2(step, step * 2)), tint)
	c.draw_rect(Rect2(_pixel(pos - Vector2(direction * step * 2, 0)), Vector2(step, step)), Color(LIGHT, tint.a * 0.6))

func _ellipse_trace(c: CanvasItem, center: Vector2, radius: Vector2, tint: Color, width: float, start: float, end: float) -> void:
	var points := PackedVector2Array()
	for i in range(25):
		var angle := lerpf(start, end, float(i) / 24.0)
		var point := _pixel(center + Vector2(cos(angle), sin(angle)) * radius)
		if points.is_empty() or points[-1] != point:
			points.append(point)
	if points.size() > 1:
		c.draw_polyline(points, tint, width, false)

func _cluster(c: CanvasItem, pos: Vector2, radius: float, tint: Color) -> void:
	var r := maxf(0.7, radius * 0.65)
	c.draw_circle(pos, r * 2.0, Color(tint, tint.a * 0.07), true, -1, true)
	c.draw_circle(pos, r, Color(tint, tint.a * 0.75), true, -1, true)
	c.draw_circle(pos, r * 0.38, Color(LIGHT, tint.a), true, -1, true)

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

func _muzzle_release(c: CanvasItem, origin: Vector2, direction: Vector2, t: float, s: float, p: Color, q: Color, kind: String, variant: float = 0.0) -> void:
	if t < 0.18:
		var charge := t / 0.18
		for i in range(5):
			var angle := float(i) * TAU / 5.0 + t * 7.0 + variant * TAU
			var pos := origin + Vector2.from_angle(angle) * (1.0-charge) * 17.0 * s
			c.draw_circle(pos, (1.0 + charge) * s, Color(q, charge * 0.75), true, -1, true)
		c.draw_circle(origin, (2.0 + charge * 4.0) * s, Color(p, charge * 0.8), true, -1, true)
	elif t < 0.28:
		var release := (t - 0.18) / 0.10
		var normal := direction.orthogonal()
		for i in range(5):
			var spread := float(i - 2) * 0.28
			var ray := direction.rotated(spread)
			var start := origin + ray * 4 * s
			var end := origin + ray * (10 + release * 19) * s
			c.draw_line(start, end, Color(p, (1-release) * 0.65), (2-release) * s, true)

func _support_trail(c: CanvasItem, origin: Vector2, target: Vector2, t: float, s: float, p: Color, q: Color, variant: float = 0.0) -> void:
	if origin.distance_squared_to(target) < 100.0 or t < 0.08 or t > 0.68:
		return
	var forward := clampf((t - 0.08) / 0.40, 0, 1)
	for i in range(15):
		var phase := clampf(forward - i * 0.025, 0, 1)
		if phase < 0.01 or phase > 0.99:
			continue
		var pos := origin.lerp(target, _smooth(phase)) + Vector2.UP * sin(phase * PI) * 50 * s
		pos += Vector2(0, sin(phase * 18 + i + variant * TAU) * 3 * s)
		var fade := (1.0 - float(i) / 16.0) * minf(1.0, (0.68-t)*6)
		var side := maxf(1.0, roundf((2.5 - i * 0.09) * s))
		c.draw_rect(Rect2(_pixel(pos), Vector2.ONE * side), Color(p if i % 2 == 0 else q, maxf(0, fade)))
