extends "res://scripts/world_painter.gd"
## TaskMon's continuous, deterministic 2D landscape. No panorama textures.
## Geometry is generated in world coordinates; every parallax layer has its own
## camera coefficient. The walkable surface and visual terrain share one sampler.

const BIOMES = [
	[Color("142d49"), Color("6eb7a2"), Color("e2d69b"), Color("356779"), Color("226d65"), Color("36936d"), Color("1e403e"), Color("7cbd78"), Color("ffda83")],
	[Color("1c466e"), Color("75d4cf"), Color("f6d59b"), Color("4188a1"), Color("359da2"), Color("62b8a4"), Color("2b555c"), Color("dcc58b"), Color("b9fff0")],
	[Color("191e48"), Color("8e80b9"), Color("d6b8e5"), Color("514d85"), Color("665c97"), Color("857da2"), Color("353653"), Color("a1a0ba"), Color("c9e5ff")],
]

var _noises: Array[FastNoiseLite] = []
var _terrain_meshes: Dictionary = {}
var _crown_shapes: Dictionary = {}

func _noise_for(region: int) -> FastNoiseLite:
	if _noises.is_empty():
		for i in range(3):
			var noise := FastNoiseLite.new()
			noise.seed = 7319 + i * 9349
			noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			noise.frequency = 0.0035
			noise.fractal_octaves = 3
			_noises.append(noise)
	return _noises[clampi(region, 0, 2)]

func ground_height(region: int, rect: Rect2, x: float, distance: float, compact: bool = false) -> float:
	var world_x := x - rect.position.x + distance * 0.64
	var wave := _noise_for(region).get_noise_1d(world_x) * 6.0 + sin(world_x * 0.008 + region) * 1.5
	return rect.end.y - (56.0 if compact else 92.0) + wave

func paint(canvas: CanvasItem, _atlas: Texture2D, region: int, rect: Rect2, time: float, distance: float, _moving: bool, compact: bool, _single: bool = false) -> void:
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	var biome := clampi(region, 0, 2)
	var colors: Array = BIOMES[biome]
	var scale := clampf(rect.size.y / 480.0, 0.55, 1.35)
	_sky_gradient(canvas, rect, colors)
	_atmosphere(canvas, rect, biome, time, distance, scale)
	for layer in range(3):
		_ridge(canvas, rect, biome, distance, layer, colors)
	_distant_landmarks(canvas, rect, biome, distance, scale)
	_rear_garden(canvas, rect, biome, time, distance, scale, compact)
	_surface(canvas, rect, biome, distance, compact, colors)
	_ground_details(canvas, rect, biome, time, distance, scale, compact)
	_air(canvas, rect, biome, time, distance, scale)

func _sky_gradient(canvas: CanvasItem, rect: Rect2, colors: Array) -> void:
	# Continuous vertex-color gradient, not an enlarged low-resolution bitmap.
	canvas.draw_primitive(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end]), PackedColorArray([colors[0], colors[0], colors[2]]), PackedVector2Array())
	canvas.draw_primitive(PackedVector2Array([rect.position, rect.end, Vector2(rect.position.x, rect.end.y)]), PackedColorArray([colors[0], colors[2], colors[2]]), PackedVector2Array())

func _atmosphere(canvas: CanvasItem, rect: Rect2, biome: int, time: float, distance: float, scale: float) -> void:
	var colors: Array = BIOMES[biome]
	var light := Vector2(rect.position.x + rect.size.x * 0.77 - fposmod(distance * 0.006, 40.0), rect.position.y + rect.size.y * 0.20)
	var sun: Color = colors[2].lightened(0.15) if biome == 1 else colors[8]
	for ring in range(5, 0, -1):
		_disk(canvas, rect, light, (23.0 + ring * 11.0) * scale, Color(sun, 0.016), 40)
	_disk(canvas, rect, light, 22 * scale, Color(sun, 0.9), 40)
	if biome == 2:
		_disk(canvas, rect, light + Vector2(8, -4) * scale, 20 * scale, Color(colors[0], 0.93), 40)
		for i in range(38):
			var star := Vector2(rect.position.x + fposmod(_random(i, 8) * rect.size.x - distance * 0.008, rect.size.x), rect.position.y + _random(i, 9) * rect.size.y * 0.46)
			_disk(canvas, rect, star, 0.6 + _random(i, 3), Color(colors[8], 0.25 + 0.3 * sin(time * 0.3 + i)), 6)
	# Wispy elliptical clouds give the sky a soft silhouette rather than flat bands.
	for i in range(8):
		var x := rect.position.x + fposmod(i * 293.0 - distance * 0.025 + time * 1.2, rect.size.x + 280) - 140
		var y := rect.position.y + rect.size.y * (0.13 + _random(i, biome) * 0.30)
		for wisp in range(3):
			_oval(canvas, rect, Vector2(x + wisp * 38 * scale, y + wisp * 3 * scale), Vector2(80, 5 + wisp * 2) * scale, Color(colors[2], 0.045))
	if biome == 0:
		# Sun shafts occupy background only, leaving creatures readable.
		for i in range(3):
			var x := light.x - i * 180 * scale
			_poly(canvas, rect, PackedVector2Array([Vector2(x, rect.position.y), Vector2(x + 18 * scale, rect.position.y), Vector2(x - 100 * scale, rect.end.y), Vector2(x - 205 * scale, rect.end.y)]), Color("ead79c", 0.025))

func _ridge(canvas: CanvasItem, rect: Rect2, biome: int, distance: float, layer: int, colors: Array) -> void:
	var points := PackedVector2Array([Vector2(rect.position.x, rect.end.y)])
	var coefficient := 0.035 + layer * 0.065
	var baseline := rect.position.y + rect.size.y * (0.43 + layer * 0.13)
	var noise := _noise_for(biome)
	for i in range(int(ceil(rect.size.x / 14.0)) + 1):
		var x := minf(rect.end.x, rect.position.x + i * 14.0)
		var world_x := x - rect.position.x + distance * coefficient
		var ridge := noise.get_noise_2d(world_x * (1.0 + layer * 0.2), layer * 973.0)
		var shape := ridge * rect.size.y * (0.26 - layer * 0.045)
		points.append(Vector2(x, baseline + shape))
	points.append(rect.end)
	_poly(canvas, rect, points, colors[3 + layer])
	# Atmospheric mist along each valley separates planes in depth.
	_oval(canvas, rect, Vector2(rect.get_center().x, baseline + rect.size.y * 0.13), Vector2(rect.size.x * 0.72, rect.size.y * 0.035), Color(colors[2], 0.065))

func _distant_landmarks(canvas: CanvasItem, rect: Rect2, biome: int, distance: float, scale: float) -> void:
	var colors: Array = BIOMES[biome]
	var travel := distance * 0.12
	var chunk := 270.0 * scale
	var first := int(floor(travel / chunk)) - 1
	var count := int(ceil(rect.size.x / chunk)) + 3
	for i in range(first, first + count):
		var x := rect.position.x + i * chunk - travel + _random(i, 21) * chunk * 0.38
		var y := rect.position.y + rect.size.y * (0.64 + _random(i, 22) * 0.10)
		var s := scale * (0.65 + _random(i, 23) * 0.6)
		match biome:
			0:
				_tree(canvas, rect, Vector2(x, y), s * 0.95, i, colors[3].darkened(0.15), colors[4], 0.0)
			1:
				# Sea stacks with broad eroded crowns and illuminated faces.
				var height := (75 + _random(i, 24) * 65) * s
				_rock(canvas, rect, Vector2(x, y), Vector2(58 * s, height), colors[3], i)
				_oval(canvas, rect, Vector2(x, y + 8 * s), Vector2(76, 4) * s, Color(colors[8], 0.16))
				for j in range(3):
					_line(canvas, rect, Vector2(x - 30 * s, y + (10 + j * 7) * s), Vector2(x + (35 + j * 8) * s, y + (10 + j * 7) * s), Color(colors[8], 0.09), 1.0)
			2:
				_arch(canvas, rect, Vector2(x, y), s, colors[3].lightened(0.08), i)
	if biome == 1:
		var sea_top := rect.position.y + rect.size.y * 0.70
		for i in range(27):
			var y := sea_top + i * 2.3 * scale
			var x := rect.position.x + fposmod(i * 97.3 - distance * 0.17, rect.size.x)
			_line(canvas, rect, Vector2(x, y), Vector2(x + (15 + i % 5 * 12) * scale, y), Color(colors[8], 0.12), 1.0)

func _rear_garden(canvas: CanvasItem, rect: Rect2, biome: int, time: float, distance: float, scale: float, compact: bool) -> void:
	var colors: Array = BIOMES[biome]
	var travel := distance * 0.39
	var spacing := 145.0 * scale
	var first := int(floor(travel / spacing)) - 1
	for i in range(first, first + int(ceil(rect.size.x / spacing)) + 3):
		var x := rect.position.x + i * spacing - travel + _random(i, 71) * spacing * 0.50
		var y := ground_height(biome, rect, x, distance, compact) - (16 + _random(i, 72) * 18) * scale
		var s := scale * (0.60 + _random(i, 73) * 0.7)
		match biome:
			0:
				if posmod(i, 4) != 1:
					_tree(canvas, rect, Vector2(x, y), s, i, colors[6], colors[4], time)
				else:
					_rock(canvas, rect, Vector2(x, y), Vector2(37, 33) * s, colors[6], i)
					_lantern(canvas, rect, Vector2(x + 28 * s, y), s, time + i, colors[8])
			1:
				_rock(canvas, rect, Vector2(x, y), Vector2(35, 22 + _random(i, 74) * 25) * s, colors[4].darkened(0.19), i)
				if posmod(i, 3) == 0:
					_crystal_cluster(canvas, rect, Vector2(x + 14 * s, y - 10 * s), s * 0.8, colors[8])
				_reeds(canvas, rect, Vector2(x - 30 * s, y + 2), s, time + i, colors[5])
			2:
				if posmod(i, 3) == 0:
					_arch(canvas, rect, Vector2(x, y), s * 0.80, colors[5].darkened(0.22), i)
				else:
					_rock(canvas, rect, Vector2(x, y), Vector2(37, 26) * s, colors[6], i)
					_crystal_cluster(canvas, rect, Vector2(x, y - 13 * s), s, colors[8])

func _surface(canvas: CanvasItem, rect: Rect2, biome: int, distance: float, compact: bool, colors: Array) -> void:
	# Retain resources for the entire frame: CanvasItem stores their RIDs until
	# rendering. A local temporary Mesh would be freed before the queued draw.
	var key := "%s/%s/%s/%s" % [biome, rect.position, rect.size, compact]
	if not _terrain_meshes.has(key):
		_terrain_meshes[key] = ArrayMesh.new()
	var mesh: ArrayMesh = _terrain_meshes[key]
	mesh.clear_surfaces()
	var vertices := PackedVector3Array()
	var vertex_colors := PackedColorArray()
	var step := 8.0
	var segments := int(ceil(rect.size.x / step))
	for i in range(segments):
		var x0 := rect.position.x + i * step
		var x1 := minf(rect.end.x, x0 + step)
		var y0 := clampf(ground_height(biome, rect, x0, distance, compact), rect.position.y, rect.end.y)
		var y1 := clampf(ground_height(biome, rect, x1, distance, compact), rect.position.y, rect.end.y)
		var depths := [0.0, 7.0, 22.0, rect.size.y]
		for band in range(3):
			var a := Vector3(x0, minf(y0 + depths[band], rect.end.y), 0)
			var b := Vector3(x1, minf(y1 + depths[band], rect.end.y), 0)
			var c := Vector3(x1, minf(y1 + depths[band + 1], rect.end.y), 0)
			var d := Vector3(x0, minf(y0 + depths[band + 1], rect.end.y), 0)
			var shade := _noise_for(biome).get_noise_1d(x0 + distance * 0.64) * 0.05
			var top: Color = colors[7].lightened(shade) if band == 0 else colors[6].lightened(0.13 if band == 1 else 0.02)
			var bottom: Color = colors[7].darkened(0.23) if band == 0 else colors[6].darkened(0.10 if band == 1 else 0.42)
			if biome == 0 and band == 1:
				top = top.lerp(Color("866b47"), 0.34)
				bottom = bottom.lerp(Color("594c3a"), 0.24)
			vertices.append_array(PackedVector3Array([a, b, c, a, c, d]))
			vertex_colors.append_array(PackedColorArray([top, top, bottom, top, bottom, bottom]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = vertex_colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	canvas.draw_mesh(mesh, null)
	# Fine luminous rim follows exactly the same contact function as actors.
	for i in range(segments):
		var x := rect.position.x + i * step
		var next := minf(rect.end.x, x + step)
		_line(canvas, rect, Vector2(x, ground_height(biome, rect, x, distance, compact)), Vector2(next, ground_height(biome, rect, next, distance, compact)), Color(colors[7].lightened(0.25), 0.65), 1.4)

func _ground_details(canvas: CanvasItem, rect: Rect2, biome: int, time: float, distance: float, scale: float, compact: bool) -> void:
	var colors: Array = BIOMES[biome]
	var travel := distance * 0.64
	var spacing := 23.0 * scale
	var first := int(floor(travel / spacing)) - 1
	for i in range(first, first + int(ceil(rect.size.x / spacing)) + 3):
		var x := rect.position.x + i * spacing - travel + _random(i, 91) * 15 * scale
		var surface := ground_height(biome, rect, x, distance, compact)
		var y := surface + 15 * scale + _random(i, 92) * (rect.end.y - surface - 24 * scale)
		_oval(canvas, rect, Vector2(x, y), Vector2(3 + _random(i, 94) * 8, 1.2 + _random(i, 95) * 2) * scale, Color(colors[7], 0.13))
		# Buried bedrock, short fissures and warm soil strata add tangible depth.
		if posmod(i, 5) == 0:
			var stone := Vector2(x, surface + (23 + _random(i, 93) * 26) * scale)
			_rock(canvas, rect, stone, Vector2(12 + _random(i, 97) * 9, 6) * scale, colors[6].lightened(0.16), i)
		if posmod(i, 4) == 0:
			var seam := Vector2(x, surface + 15 * scale)
			_line(canvas, rect, seam, seam + Vector2(12, 2) * scale, Color(colors[0], 0.30), scale)
			_line(canvas, rect, seam + Vector2(12, 2) * scale, seam + Vector2(20, 0) * scale, Color(colors[0], 0.24), scale)
		if posmod(i, 3) == 0:
			_line(canvas, rect, Vector2(x, y + 4 * scale), Vector2(x + 6 * scale, y + 5 * scale), Color(colors[0], 0.22), 1.0)
		if biome == 0:
			var wind := sin(time * 1.6 + i * 1.7) * 1.7
			for blade in range(3):
				var root := Vector2(x + blade * 3 * scale, surface + 4 * scale)
				_line(canvas, rect, root, root + Vector2(-3 + blade * 2 + wind, -4 - _random(i + blade, 96) * 9) * scale, colors[7].lightened(blade * 0.04), 1.4 * scale)
			if posmod(i, 6) == 0:
				for flower in range(3):
					var center := Vector2(x + flower * 5 * scale, surface - (7 + flower % 2 * 5) * scale)
					_line(canvas, rect, center, Vector2(center.x - 1, surface + 1), colors[7], scale)
					var bloom := Color("efc075") if posmod(i, 12) == 0 else Color("d5a4df")
					for petal in range(4):
						_disk(canvas, rect, center + Vector2.from_angle(petal * TAU / 4.0) * 1.5 * scale, 1.1 * scale, bloom, 6)
					_disk(canvas, rect, center, 0.8 * scale, colors[8], 6)
			if posmod(i, 13) == 0:
				_leaf_contour(canvas, rect, Vector2(x, surface + 3 * scale), Vector2(11, 6) * scale, colors[5].darkened(0.1), i)
		elif biome == 1:
			if posmod(i, 7) == 0:
				_rock(canvas, rect, Vector2(x, surface + 4 * scale), Vector2(8, 5) * scale, colors[7].lightened(0.13), i)
			_line(canvas, rect, Vector2(x, surface + 9 * scale), Vector2(x + 11 * scale, surface + 9 * scale), Color(colors[8], 0.2), 1.0)
		else:
			if posmod(i, 9) == 0:
				_crystal_cluster(canvas, rect, Vector2(x, surface + 5 * scale), scale * 0.22, colors[8])
			elif posmod(i, 5) == 0:
				_poly(canvas, rect, PackedVector2Array([Vector2(x, surface + 8), Vector2(x + 20 * scale, surface + 6), Vector2(x + 25 * scale, surface + 11), Vector2(x + 4, surface + 14)]), Color(colors[7], 0.38))

func _tree(canvas: CanvasItem, rect: Rect2, base: Vector2, scale: float, seed_id: int, bark: Color, leaf: Color, time: float) -> void:
	var height := (86 + _random(seed_id, 31) * 55) * scale
	if not rect.intersects(Rect2(base - Vector2(83 * scale, height + 43 * scale), Vector2(166 * scale, height + 50 * scale))):
		return
	var lean := (_random(seed_id, 32) - 0.5) * 13 * scale
	var top := base + Vector2(lean, -height)
	var wood := bark.lerp(Color("6b694d"), 0.28)
	_oval(canvas, rect, base + Vector2(2, 2), Vector2(25, 4) * scale, Color("102d34", 0.28))
	_poly(canvas, rect, PackedVector2Array([base + Vector2(-14, 2) * scale, base + Vector2(-7, -height * 0.24), base + Vector2(-4, -height * 0.64), top + Vector2(3, 0), base + Vector2(9, -height * 0.56), base + Vector2(8, -height * 0.19), base + Vector2(16, 2) * scale]), wood)
	_poly(canvas, rect, PackedVector2Array([base + Vector2(0, -2), base + Vector2(-1, -height * 0.38), top + Vector2(2, 3), base + Vector2(6, -height * 0.39), base + Vector2(8, -3)]), wood.lightened(0.12))
	for root in range(3):
		var side := -1.0 if root % 2 == 0 else 1.0
		var start := base + Vector2(side * 4, -9) * scale
		var joint := base + Vector2(side * (12 + root * 3), -2) * scale
		var tip := base + Vector2(side * (22 + root * 5), 2) * scale
		_poly(canvas, rect, PackedVector2Array([start, joint, tip, joint + Vector2(0, 3) * scale, base + Vector2(0, 2)]), wood)
		_line(canvas, rect, start + Vector2(1, 1), joint, wood.lightened(0.14), maxf(0.7, scale))
	for mark in range(3):
		var p := base + Vector2(0, -height * (0.14 + mark * 0.14))
		_line(canvas, rect, p, p + Vector2(-2, -7) * scale, wood.darkened(0.3), maxf(0.7, scale))
	for branch in range(4):
		var side := -1.0 if branch % 2 == 0 else 1.0
		var joint := base + Vector2(lean * 0.4, -height * (0.45 + branch * 0.095))
		var crown := joint + Vector2(side * (22 + _random(seed_id + branch, 34) * 18) * scale, -height * 0.22)
		_poly(canvas, rect, PackedVector2Array([joint + Vector2(-3, 2) * scale, joint + Vector2(1, -5) * scale, crown + Vector2(1, -2) * scale, crown + Vector2(1, 2) * scale]), wood)
		var sway := sin(time * 0.7 + seed_id + branch) * 1.5 * scale
		_foliage(canvas, rect, crown + Vector2(sway, -7 * scale), Vector2(36, 23) * scale, leaf.darkened(0.09 * (branch % 2)), seed_id + branch)
	_foliage(canvas, rect, top + Vector2(0, -3 * scale), Vector2(36, 29) * scale, leaf.lightened(0.06), seed_id + 11)
	# Delicate hanging vines break the trimmed silhouette at selected crowns.
	if posmod(seed_id, 3) == 0:
		var hanging := top + Vector2(-23, 7) * scale
		_line(canvas, rect, hanging, hanging + Vector2(1, 22) * scale, leaf.darkened(0.15), scale)
		_line(canvas, rect, hanging + Vector2(1, 22) * scale, hanging + Vector2(6, 27) * scale, leaf.darkened(0.15), scale)

func _foliage(canvas: CanvasItem, rect: Rect2, center: Vector2, radius: Vector2, color: Color, seed_id: int) -> void:
	var bounds := Rect2(center - radius * 1.2, radius * 2.4)
	if not rect.intersects(bounds):
		return
	_leaf_contour(canvas, rect, center + Vector2(0, 1), radius * 1.06, color.darkened(0.30), seed_id)
	_leaf_contour(canvas, rect, center, radius, color, seed_id)
	_leaf_contour(canvas, rect, center + Vector2(-radius.x * 0.13, -radius.y * 0.24), radius * Vector2(0.84, 0.70), color.lightened(0.14), seed_id + 7)
	_leaf_contour(canvas, rect, center + Vector2(-radius.x * 0.23, -radius.y * 0.42), radius * Vector2(0.52, 0.30), color.lightened(0.25), seed_id + 12)
	for i in range(5):
		var p := center + radius * Vector2((_random(seed_id + i, 118) - 0.5) * 1.6, (_random(seed_id + i, 119) - 0.5) * 1.1)
		var direction := Vector2(2.6, -1.4) * radius.x / 34.0
		_line(canvas, rect, p, p + direction, Color(color.lightened(0.4), 0.60), maxf(0.6, radius.x / 35.0))

func _leaf_contour(canvas: CanvasItem, rect: Rect2, center: Vector2, radius: Vector2, color: Color, seed_id: int) -> void:
	var key := posmod(seed_id, 32)
	if not _crown_shapes.has(key):
		var contour := PackedVector2Array()
		for i in range(48):
			var angle := i * TAU / 48.0
			var relief := 0.92 + sin(angle * 9 + key * 1.7) * 0.07 + sin(angle * 5 + key) * 0.055 + _random(i, key) * 0.04
			contour.append(Vector2.from_angle(angle) * relief)
		_crown_shapes[key] = contour
	var points: PackedVector2Array = _crown_shapes[key]
	if rect.encloses(Rect2(center - radius * 1.12, radius * 2.24)):
		canvas.draw_set_transform(center, 0.0, radius)
		canvas.draw_colored_polygon(points, color)
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		var transformed := PackedVector2Array()
		for point in points:
			transformed.append(center + point * radius)
		_poly(canvas, rect, transformed, color)

func _rock(canvas: CanvasItem, rect: Rect2, base: Vector2, size: Vector2, color: Color, seed_id: int) -> void:
	if not rect.intersects(Rect2(base - Vector2(size.x * 0.65, size.y), Vector2(size.x * 1.3, size.y + 1))):
		return
	var ridge := base + Vector2(size.x * (-0.2 + _random(seed_id, 42) * 0.3), -size.y)
	var crown_left := ridge + Vector2(-size.x * 0.19, size.y * 0.08)
	var crown_right := ridge + Vector2(size.x * 0.24, size.y * 0.03)
	var left := base + Vector2(-size.x * 0.5, -size.y * 0.64)
	var right := base + Vector2(size.x * 0.5, -size.y * 0.46)
	var foot_left := base + Vector2(-size.x * 0.60, 0)
	var foot_right := base + Vector2(size.x * 0.58, 0)
	_poly(canvas, rect, PackedVector2Array([foot_left, left, crown_left, ridge, crown_right, right, foot_right]), color)
	_poly(canvas, rect, PackedVector2Array([left, crown_left, ridge, crown_right, right, base + Vector2(size.x * 0.1, -size.y * 0.41)]), color.lightened(0.12))
	_poly(canvas, rect, PackedVector2Array([crown_right, right, foot_right, base + Vector2(size.x * 0.1, -size.y * 0.41)]), color.darkened(0.14))
	_line(canvas, rect, crown_left + Vector2(0, 1), crown_right + Vector2(0, 1), Color(color.lightened(0.25), 0.6), 1.0)
	for i in range(3):
		var y := base.y - size.y * (0.16 + i * 0.17)
		_line(canvas, rect, Vector2(base.x - size.x * 0.36, y), Vector2(base.x + size.x * 0.05, y - 1), Color(color.darkened(0.2), 0.5), 1.0)

func _arch(canvas: CanvasItem, rect: Rect2, base: Vector2, scale: float, color: Color, seed_id: int) -> void:
	# Radial masonry arch: a true opening reveals the generated landscape.
	var center := base + Vector2(0, -70 * scale)
	for side in [-1, 1]:
		for course in range(5):
			if posmod(seed_id, 4) == 1 and side == 1 and course > 2:
				continue
			var x: float = base.x + side * 33 * scale
			var y := base.y - (course + 1) * 14 * scale
			_box(canvas, rect, Rect2(x - 9 * scale, y, 18 * scale, 13 * scale), color.lightened(_random(seed_id + course + side, 51) * 0.08))
			_line(canvas, rect, Vector2(x - 8 * scale, y + 1), Vector2(x + 6 * scale, y + 1), color.lightened(0.18), scale)
	for stone in range(11):
		if posmod(seed_id, 4) == 1 and stone > 6:
			continue
		if posmod(seed_id, 4) == 2 and stone > 3 and stone < 8:
			continue
		var a := PI + stone * PI / 11.0
		var b := PI + (stone + 0.91) * PI / 11.0
		_poly(canvas, rect, PackedVector2Array([center + Vector2(cos(a), sin(a)) * 25 * scale, center + Vector2(cos(a), sin(a)) * 43 * scale, center + Vector2(cos(b), sin(b)) * 43 * scale, center + Vector2(cos(b), sin(b)) * 25 * scale]), color.lightened(0.06 * (stone % 3)))
	for rune in range(3):
		var p := base + Vector2(-33, -24 - rune * 14) * scale
		_line(canvas, rect, p, p + Vector2(3, -4) * scale, Color("bcd9f4", 0.5), scale)

func _crystal_cluster(canvas: CanvasItem, rect: Rect2, base: Vector2, scale: float, color: Color) -> void:
	for i in range(3):
		var p := base + Vector2((i - 1) * 10, -i % 2 * 3) * scale
		var h := (23 + (i % 2) * 15) * scale
		var tip := p + Vector2(2 * scale, -h)
		_poly(canvas, rect, PackedVector2Array([p + Vector2(-5, 0) * scale, p + Vector2(-7 * scale, -h * 0.60), tip, p + Vector2(7 * scale, -h * 0.52), p + Vector2(5, 0) * scale]), color.darkened(0.25))
		_poly(canvas, rect, PackedVector2Array([p, p + Vector2(-7 * scale, -h * 0.60), tip, p + Vector2(1, -2) * scale]), color)
		_line(canvas, rect, tip, p + Vector2(1, -2) * scale, color.lightened(0.4), maxf(0.6, scale))

func _lantern(canvas: CanvasItem, rect: Rect2, base: Vector2, scale: float, time: float, color: Color) -> void:
	var light := base + Vector2(0, -39) * scale
	_line(canvas, rect, base, light + Vector2(-5, -16) * scale, Color("293f3b"), 3 * scale)
	_line(canvas, rect, light + Vector2(-5, -16) * scale, light + Vector2(8, -16) * scale, Color("293f3b"), 2 * scale)
	for i in range(3, 0, -1):
		_disk(canvas, rect, light + Vector2(8, -7) * scale, (7 + i * 5) * scale, Color(color, 0.035 + sin(time) * 0.009), 16)
	_poly(canvas, rect, PackedVector2Array([light + Vector2(3, -13) * scale, light + Vector2(13, -13) * scale, light + Vector2(12, -2) * scale, light + Vector2(5, -2) * scale]), color)
	_line(canvas, rect, light + Vector2(2, -14) * scale, light + Vector2(14, -14) * scale, Color("504b3a"), 2 * scale)

func _reeds(canvas: CanvasItem, rect: Rect2, base: Vector2, scale: float, time: float, color: Color) -> void:
	for i in range(5):
		var tip := base + Vector2((i - 2) * 6 + sin(time * 0.9 + i) * 2, -12 - i % 3 * 7) * scale
		_line(canvas, rect, base + Vector2(i * 2, 0), tip, color, 1.5 * scale)
		_oval(canvas, rect, tip, Vector2(2, 4) * scale, color.lightened(0.22))

func _air(canvas: CanvasItem, rect: Rect2, biome: int, time: float, distance: float, scale: float) -> void:
	var colors: Array = BIOMES[biome]
	for i in range(17):
		var x := rect.position.x + fposmod(i * 137.3 + time * (2.0 + i % 3) - distance * 0.27, rect.size.x)
		var y := rect.position.y + rect.size.y * (0.32 + _random(i, 99) * 0.48) + sin(time * 0.7 + i) * 7 * scale
		var alpha := 0.18 + (sin(time * 1.2 + i * 3) + 1) * 0.15
		_disk(canvas, rect, Vector2(x, y), 1.0 * scale, Color(colors[8], alpha), 8)
		if biome == 0 and i % 4 == 0:
			_disk(canvas, rect, Vector2(x, y), 4 * scale, Color(colors[8], alpha * 0.08), 10)

func _oval(canvas: CanvasItem, rect: Rect2, center: Vector2, radius: Vector2, color: Color) -> void:
	if center.x + radius.x < rect.position.x or center.x - radius.x > rect.end.x or center.y + radius.y < rect.position.y or center.y - radius.y > rect.end.y:
		return
	if rect.encloses(Rect2(center - radius, radius * 2.0)):
		# Circle AA fringes are transformed too: avoid a unit-radius AA border
		# becoming a 40px glow that could escape the supplied clipping rectangle.
		canvas.draw_set_transform(center, 0.0, radius / 20.0)
		canvas.draw_circle(Vector2.ZERO, 20.0, color, true, -1.0, false)
		canvas.draw_set_transform(Vector2.ZERO)
		return
	var points := PackedVector2Array()
	for i in range(20):
		var angle := i * TAU / 20.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	_poly(canvas, rect, points, color)

func _disk(canvas: CanvasItem, rect: Rect2, center: Vector2, radius: float, color: Color, segments: int = 20) -> void:
	var bounds := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2)
	if rect.encloses(bounds):
		canvas.draw_circle(center, radius, color, true, -1.0, true)
	elif rect.intersects(bounds):
		var points := PackedVector2Array()
		for i in range(segments):
			points.append(center + Vector2.from_angle(i * TAU / segments) * radius)
		_poly(canvas, rect, points, color)

func _random(index: int, salt: int) -> float:
	# Integer hashing avoids global RNG state and supports negative world chunks.
	var value := (index * 374761393 + salt * 668265263) & 0x7fffffff
	value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
	return float(value & 65535) / 65535.0

func _poly(canvas: CanvasItem, clip: Rect2, points: PackedVector2Array, color: Color) -> void:
	# Fully contained contours take Godot's native polygon path in one batch.
	# Only edge-crossing geometry needs the parent's robust polygon clipping.
	# Avoid thousands of per-triangle script calls for every tree canopy.
	var contained := true
	for point in points:
		if point.x < clip.position.x or point.x > clip.end.x or point.y < clip.position.y or point.y > clip.end.y:
			contained = false
			break
	if contained:
		canvas.draw_colored_polygon(points, color)
	else:
		super._poly(canvas, clip, points, color)

func _line(canvas: CanvasItem, clip: Rect2, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var inside := clip.grow(-width * 0.5)
	if inside.has_point(a) and inside.has_point(b):
		canvas.draw_line(a, b, color, width, true)
	else:
		super._line(canvas, clip, a, b, color, width)
