extends RefCounted
## Native regional renderer. All coordinates are clipped to the supplied world rect.
## distance is world travel in pixels; time drives ambient detail independently.
## The caller freezes distance during battle (moving=false also freezes route drift).

var ground_texture: Texture2D
var camera_zoom := 1.0
# Reserve illustration margins so exploration at 0.90 can show more scenery
# while battle at 1.10 approaches smoothly without stretching its aspect.
const PANORAMA_OVERSCAN := 1.12
# Canonical illustrations contain a painted foreground floor around source
# y=670–710 / 1024. It must NEVER be sampled as background: the scrolling
# ground strip below is the sole walkable plane. Fractions leave a safe margin
# above that floor, including at the widest exploration zoom.
const BACKDROP_FRACTIONS := [0.61, 0.60, 0.61]

const PALETTES = [
	[Color("111e30"), Color("2b5361"), Color("83dfba"), Color("f2cd85")],
	[Color("111b35"), Color("315c75"), Color("78ced5"), Color("c5a5ef")],
	[Color("17172e"), Color("454568"), Color("c5a5ef"), Color("f2cd85")],
]

func paint(canvas: CanvasItem, atlas: Texture2D, region: int, rect: Rect2, time: float, distance: float, moving: bool, compact: bool, single: bool = false) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if ground_texture == null and ResourceLoader.exists("res://assets/ground-taskmon.png"):
		ground_texture = load("res://assets/ground-taskmon.png")
	var biome := clampi(region, 0, 2)
	var colors: Array = PALETTES[biome]
	var scale := clampf(rect.size.y / 390.0, 0.6, 1.5)
	# Travel remains authoritative to the caller; no clock-derived movement when stopped.
	var travel := distance
	var ambient := time
	canvas.draw_rect(rect, colors[0])
	_draw_sky(canvas, rect, biome, ambient, travel, scale)
	if atlas != null:
		_draw_panorama(canvas, atlas, biome, rect, travel, single, compact)
	else:
		_draw_distant_ridges(canvas, rect, biome, travel, scale)
	# Sparse independent distant mist ribbons help separate the baked panorama layers.
	for index in range(4):
		var ribbon_x := rect.position.x + fposmod(float(index) * 389.0 + ambient * 1.5 - travel * 0.025, rect.size.x + 210.0) - 105.0
		var ribbon_y := rect.position.y + rect.size.y * (0.26 + index * 0.105)
		_poly(canvas, rect, PackedVector2Array([
			Vector2(ribbon_x - 100, ribbon_y + 4 * scale), Vector2(ribbon_x - 42, ribbon_y),
			Vector2(ribbon_x + 56, ribbon_y + scale), Vector2(ribbon_x + 100, ribbon_y + 5 * scale)
		]), Color(colors[2], 0.06))
	_draw_ground(canvas, rect, biome, travel, scale, compact)
	_draw_motes(canvas, rect, biome, ambient, travel, scale)
	# A hairline horizon frame defines the world, without dashboard panels.
	_line(canvas, rect, rect.position, Vector2(rect.end.x, rect.position.y), Color(colors[2], 0.18), 1.0)
	if moving:
		_draw_route_glints(canvas, rect, biome, travel, scale)

func _draw_panorama(canvas: CanvasItem, atlas: Texture2D, biome: int, rect: Rect2, travel: float, single: bool = false, compact: bool = false) -> void:
	# Frame the painting above the walkable plane rather than hiding its lower
	# quarter behind terrain. This preserves the coastal sea and distant vistas.
	# A small overlap behind the strip prevents a seam at the contact edge.
	var backdrop := Rect2(rect.position, Vector2(rect.size.x, maxf(1.0, rect.size.y - (56.0 if compact else 92.0) + 4.0)))
	var source := _panorama_source(atlas.get_size(), biome, backdrop.size, travel, single)
	if not source.has_area():
		return
	canvas.draw_texture_rect_region(atlas, backdrop, source, Color.WHITE, false, true)

func _panorama_source(texture_size: Vector2, biome: int, viewport_size: Vector2, travel: float, single: bool = false) -> Rect2:
	var row_height := texture_size.y if single else texture_size.y / 3.0
	if row_height <= 0.0 or texture_size.x <= 0.0 or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var aspect := viewport_size.x / viewport_size.y
	var backdrop_height: float = row_height * BACKDROP_FRACTIONS[clampi(biome, 0, 2)]
	var max_width := minf(texture_size.x, backdrop_height * aspect)
	var source_width := minf(max_width, max_width / PANORAMA_OVERSCAN / clampf(camera_zoom, 0.5, 2.0))
	var source_height := source_width / aspect
	var row_y: float = (0.0 if single else clampi(biome, 0, 2) * row_height) + (backdrop_height - source_height) * 0.5
	# Reflect within available crop margins instead of wrapping unrelated ends
	# of a painted scene together. Smoothstep makes reversals gently decelerate.
	var span := maxf(0.0, texture_size.x - source_width)
	var source_x := 0.0
	if span > 0.001:
		var phase := pingpong(travel * 0.07 + span * 0.5, span) / span
		source_x = span * smoothstep(0.0, 1.0, phase)
	return Rect2(source_x, row_y, source_width, source_height)

func _draw_sky(canvas: CanvasItem, rect: Rect2, biome: int, time: float, travel: float, scale: float) -> void:
	var colors: Array = PALETTES[biome]
	for i in range(24):
		var sx := rect.position.x + fposmod(i * 157.0 + 38.0 - travel * 0.012, rect.size.x)
		var sy := rect.position.y + (12.0 + fposmod(i * 37.0, rect.size.y * 0.42))
		var alpha := 0.18 + 0.22 * (0.5 + 0.5 * sin(time * 0.6 + i))
		_box(canvas, rect, Rect2(sx, sy, 2 * scale, scale), Color(colors[3], alpha))
	# Angular cloud ribbons: deliberately not large circular ornaments.
	for i in range(6):
		var x := rect.position.x + fposmod(i * 267.0 + time * 2.0 - travel * 0.02, rect.size.x + 160.0) - 80.0
		var y := rect.position.y + rect.size.y * (0.085 + 0.043 * (i % 3))
		_poly(canvas, rect, PackedVector2Array([Vector2(x-54,y+8), Vector2(x-30,y+4), Vector2(x-12,y+4), Vector2(x,y), Vector2(x+22,y), Vector2(x+37,y+5), Vector2(x+65,y+8)]), Color(colors[1], 0.22))

func _draw_distant_ridges(canvas: CanvasItem, rect: Rect2, biome: int, travel: float, _scale: float) -> void:
	var colors: Array = PALETTES[biome]
	for layer in range(3):
		var points := PackedVector2Array([Vector2(rect.position.x, rect.end.y)])
		for i in range(20):
			var x := rect.position.x + rect.size.x * float(i) / 19.0
			var y := rect.position.y + rect.size.y * (0.43 + layer * 0.14 + sin(i * 1.7 + travel * 0.0004) * 0.075)
			points.append(Vector2(x, y))
		points.append(rect.end)
		_poly(canvas, rect, points, Color(colors[1], 0.32 + layer * 0.12))

func _draw_ground(canvas: CanvasItem, rect: Rect2, biome: int, travel: float, scale: float, compact: bool) -> void:
	var contact := rect.end.y - (56.0 if compact else 92.0)
	if ground_texture != null:
		var row_height := float(ground_texture.get_height()) / 3.0
		var tex_height := row_height * 0.78
		var target_height := (125.0 if not compact else 80.0) * clampf(camera_zoom, 0.5, 2.0)
		# Even a very wide camera must keep terrain down to the viewport bottom;
		# shrinking the whole strip must not reveal background beneath the floor.
		target_height = maxf(target_height, (rect.end.y - contact) / 0.91)
		var tile_width := ground_texture.get_width() * target_height / tex_height
		var phase := fposmod(travel * 0.64, tile_width)
		var x := rect.position.x - phase
		while x < rect.end.x:
			var destination := Rect2(x, contact - target_height * 0.09, tile_width, target_height)
			var source := Rect2(0, biome * row_height + row_height * 0.22, ground_texture.get_width(), tex_height)
			var clipped := destination.intersection(rect)
			if clipped.has_area():
				var uv := Rect2(source.position + (clipped.position - destination.position) / destination.size * source.size, clipped.size / destination.size * source.size)
				canvas.draw_texture_rect_region(ground_texture, clipped, uv)
			x += tile_width
		return

	var colors: Array = PALETTES[biome]
	var ground := rect.end.y - (56.0 if compact else 92.0)
	_poly(canvas, rect, PackedVector2Array([Vector2(rect.position.x, ground + 3), Vector2(rect.position.x + rect.size.x * 0.25, ground), Vector2(rect.position.x + rect.size.x * 0.6, ground + 5), Vector2(rect.end.x, ground + 1), rect.end, Vector2(rect.position.x, rect.end.y)]), Color(colors[0], 0.48))
	for i in range(21):
		var x := rect.position.x + fposmod(i * 97.0 - travel * 0.62, rect.size.x + 100.0) - 50.0
		var y := ground + fposmod(i * 7.0, 12.0) * scale
		match biome:
			0:
				for stem in range(3):
					var base := Vector2(x + stem * 5 * scale, y + 10 * scale)
					var top := base + Vector2((-5 + stem * 3) * scale, (-11 - stem * 3) * scale)
					_line(canvas, rect, base, top, Color(colors[2], 0.46), maxf(1, 2 * scale))
				if i % 3 == 0:
					_box(canvas, rect, Rect2(x + 5 * scale, y - 5 * scale, 3 * scale, 3 * scale), Color(colors[3], 0.8))
			1:
				_line(canvas, rect, Vector2(x,y), Vector2(x+25*scale,y), Color(colors[2],0.4), scale)
				_line(canvas, rect, Vector2(x+9*scale,y+3*scale), Vector2(x+36*scale,y+3*scale), Color(colors[3],0.22), scale)
				if i % 4 == 0:
					_crystal(canvas, rect, Vector2(x,y+8*scale), 13*scale, Color(colors[3],0.5))
			2:
				if i % 2 == 0:
					_crystal(canvas, rect, Vector2(x,y+9*scale), (12 + i%3*4)*scale, Color(colors[2],0.54))
				else:
					_poly(canvas, rect, PackedVector2Array([Vector2(x,y),Vector2(x+17*scale,y-4*scale),Vector2(x+26*scale,y+3*scale),Vector2(x+22*scale,y+9*scale),Vector2(x,y+9*scale)]),Color(colors[1],0.7))


func _crystal(canvas: CanvasItem, rect: Rect2, base: Vector2, height: float, color: Color) -> void:
	var tip := base + Vector2(2,-height)
	_poly(canvas, rect, PackedVector2Array([base+Vector2(-5,0),base+Vector2(-6,-height*0.6),tip,base+Vector2(7,-height*0.55),base+Vector2(5,0)]),color)
	_line(canvas, rect, tip, base+Vector2(0,-2),Color("e5d8fb",0.55),1)

func _draw_motes(canvas: CanvasItem, rect: Rect2, biome: int, time: float, travel: float, scale: float) -> void:
	var colors: Array = PALETTES[biome]
	for i in range(16):
		var x := rect.position.x + fposmod(i * 127.0 + time * (3.0 + i%3) - travel * 0.09, rect.size.x)
		var y := rect.position.y + rect.size.y * (0.24 + fposmod(i * 0.137, 0.6)) + sin(time * 0.7 + i) * 8 * scale
		var alpha := 0.18 + 0.32 * (0.5 + 0.5 * sin(time * 1.3 + i * 2.0))
		_box(canvas, rect, Rect2(x, y, 2*scale, 2*scale), Color(colors[3 if biome == 0 else 2], alpha))

func _draw_route_glints(canvas: CanvasItem, rect: Rect2, biome: int, travel: float, scale: float) -> void:
	var colors: Array = PALETTES[biome]
	for i in range(8):
		var x := rect.position.x + fposmod(i*191.0-travel*0.45,rect.size.x)
		var y := rect.end.y - (34+i%3*3)*scale
		_line(canvas,rect,Vector2(x,y),Vector2(x+8*scale,y),Color(colors[3],0.15),scale)

func _box(canvas: CanvasItem, clip: Rect2, box: Rect2, color: Color) -> void:
	var visible := clip.intersection(box)
	if visible.size.x > 0 and visible.size.y > 0:
		canvas.draw_rect(visible, color)

func _line(canvas: CanvasItem, clip: Rect2, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	# Line segment rendered as a clipped polygon, including stroke thickness.
	if a.distance_squared_to(b) < 0.01:
		return
	var normal := (b-a).normalized().orthogonal() * maxf(0.5, width*0.5)
	_poly(canvas,clip,PackedVector2Array([a+normal,b+normal,b-normal,a-normal]),color)

func _poly(canvas: CanvasItem, clip: Rect2, input: PackedVector2Array, color: Color) -> void:
	var points := input
	for edge in range(4):
		if points.size() < 3:
			return
		var output := PackedVector2Array()
		var previous := points[points.size()-1]
		for current in points:
			var current_inside := _inside(current,clip,edge)
			var previous_inside := _inside(previous,clip,edge)
			if current_inside != previous_inside:
				output.append(_intersect(previous,current,clip,edge))
			if current_inside:
				output.append(current)
			previous = current
		points = output
	# Clipping at a corner can produce duplicate intersections or a zero-area
	# stroke. Remove those before submitting geometry to the render server.
	var clean := PackedVector2Array()
	for point in points:
		if clean.is_empty() or clean[clean.size()-1].distance_squared_to(point) > 0.000001:
			clean.append(point)
	if clean.size() > 1 and clean[0].distance_squared_to(clean[clean.size()-1]) <= 0.000001:
		clean.remove_at(clean.size()-1)
	var changed := true
	while changed and clean.size() >= 3:
		changed = false
		for index in range(clean.size()):
			var a := clean[(index+clean.size()-1)%clean.size()]
			var b := clean[index]
			var c := clean[(index+1)%clean.size()]
			if absf((b-a).cross(c-b)) <= 0.0001:
				clean.remove_at(index)
				changed = true
				break
	if clean.size() < 3:
		return
	var twice_area := 0.0
	var origin := clean[0]
	for index in range(clean.size()):
		twice_area += (clean[index]-origin).cross(clean[(index+1)%clean.size()]-origin)
	if absf(twice_area) < 0.01:
		return
	# Preflight handles any numerically unstable or non-simple contour without
	# sending invalid polygon data to the renderer. Draw explicit valid triangles.
	var indices := Geometry2D.triangulate_polygon(clean)
	for index in range(0, indices.size(), 3):
		var a := clean[indices[index]]
		var b := clean[indices[index+1]]
		var c := clean[indices[index+2]]
		if absf((b-a).cross(c-a)) > 0.0001:
			canvas.draw_primitive(PackedVector2Array([a,b,c]), PackedColorArray([color]), PackedVector2Array())

func _inside(point: Vector2, clip: Rect2, edge: int) -> bool:
	match edge:
		0: return point.x >= clip.position.x
		1: return point.x <= clip.end.x
		2: return point.y >= clip.position.y
		_: return point.y <= clip.end.y

func _intersect(a: Vector2, b: Vector2, clip: Rect2, edge: int) -> Vector2:
	if edge < 2:
		var x := clip.position.x if edge == 0 else clip.end.x
		return Vector2(x, a.y+(b.y-a.y)*(x-a.x)/(b.x-a.x))
	var y := clip.position.y if edge == 2 else clip.end.y
	return Vector2(a.x+(b.x-a.x)*(y-a.y)/(b.y-a.y),y)
