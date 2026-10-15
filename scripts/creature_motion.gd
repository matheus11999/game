extends RefCounted
## Anatomical, atlas-preserving 2D skinning. Coordinates are normalized within
## the alpha-trimmed source. The caller owns translation along the ground.

const COLUMNS := 16
const ROWS := 18
var _frame_meshes: Array[ArrayMesh] = []
var _mesh_cursor := 0
var _templates: Dictionary = {}
var _skins: Dictionary = {}
var _profiles: Dictionary = {}
var _eyelids: Dictionary = {}
var _filtered_textures: Dictionary = {}
var _upright_profiles: Dictionary = {}
var _ember_parts: Dictionary = {}
var _ember_textures: Dictionary = {}

func upright_profile(id: String) -> Dictionary:
	if id != "ember":
		return profile(id)
	if _upright_profiles.has(id):
		return _upright_profiles[id]
	var rig := profile(id).duplicate(true)
	rig.merge({"rate": 0.90, "lift": 0.012, "hips": [Vector2(0.42, 0.71), Vector2(0.48, 0.74), Vector2(0.67, 0.70), Vector2(0.79, 0.69)], "feet": [Vector2(0.286, 0.943), Vector2(0.486, 0.917), Vector2(0.735, 0.943), Vector2(0.902, 0.914)], "phases": [0.0, 0.5, 0.75, 0.25], "radius": 0.085, "head": Vector2(0.79, 0.45), "tail_pivot": Vector2(0.43, 0.64), "tail_floor": 0.68, "ear_pivot": Vector2(0.74, 0.34)}, true)
	_upright_profiles[id] = rig
	return rig

func instance_variation(seed: float, channel: float = 0.0) -> float:
	return fposmod(sin(fposmod(seed, 65521.0) * 0.01731 + channel * 1.7131) * 43758.5453, 1.0)

func upright_eyes(id: String) -> Array:
	if id != "ember":
		return []
	# Anchors calibrated for alpha-trimmed first cell of ember-locomotion-v2.
	return [{"center": Vector2(0.772, 0.473), "radius": Vector2(0.050, 0.044), "sample": Vector2(0.78, 0.38)}, {"center": Vector2(0.923, 0.460), "radius": Vector2(0.025, 0.037), "sample": Vector2(0.78, 0.38)}]

func _render_texture(sheet: Texture2D) -> CanvasTexture:
	var key := sheet.get_instance_id()
	if _filtered_textures.has(key):
		return _filtered_textures[key]
	var texture := CanvasTexture.new()
	texture.diffuse_texture = sheet
	var image := sheet.get_image()
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if image != null and image.has_mipmaps() else CanvasItem.TEXTURE_FILTER_LINEAR
	_filtered_textures[key] = texture
	return texture

const SPECIES := ["ember", "moss", "luna", "tide", "crag", "cloud", "thornbud", "pebblebug", "reefclaw", "tidejelly", "runewisp", "shardguard", "rootelder", "abyssmaw", "moonwarden"]
const STATES := ["idle", "stand", "locomotion", "attack", "cast", "hurt", "blink", "appear", "death"]

## Explicit production metadata: a static seated painting is not a walk cycle.
## The caller must select a standing pose before requesting locomotion/combat.
func animation_metadata(id: String) -> Dictionary:
	return {"species": id, "states": STATES.duplicate(), "locomotion": "flight" if is_flying(id) else ("slither" if id == "abyssmaw" else "walk"), "seated_idle": id == "ember", "requires_upright_pose": id == "ember", "technique": "anatomical_rig", "drawn_walk_cycle": false, "durations": {"stand": 0.32, "attack": 0.90, "cast": 1.20, "hurt": 0.42, "blink": 0.17, "appear": 0.55, "death": 0.70}}

## Deterministic samples, independent of FPS and rendering frequency. age is
## elapsed time since the authoritative visual event, never server simulation.
func sample_animation(id: String, time: float, state: String = "idle", age: float = 0.0, seed: float = 0.0, upright: bool = false) -> Dictionary:
	if not state in STATES:
		state = "idle"
	var metadata := animation_metadata(id)
	var duration := float(metadata.durations.get(state, 1.0))
	var progress := clampf(age / duration, 0.0, 1.0)
	var pose := 0.0
	var offset := Vector2.ZERO
	var tilt := 0.0
	var alpha := 1.0
	var hurt := 0.0
	var casting := 0.0
	match state:
		"stand":
			# Art selection performs the posture change. No scaling a seated torso
			# into invented legs; this only settles the selected standing pose.
			offset.y = -sin(progress * PI) * 0.008
		"attack":
			if progress < 0.28:
				pose = -sin(progress / 0.28 * PI * 0.5) * 0.32
			elif progress < 0.56:
				pose = lerpf(-0.32, 1.0, smoothstep(0.0, 1.0, (progress - 0.28) / 0.28))
			else:
				pose = 1.0 - smoothstep(0.0, 1.0, (progress - 0.56) / 0.44)
			tilt = -pose * 0.025
		"cast":
			casting = sin(progress * PI)
			pose = casting * 0.4
			offset.y = -casting * (0.018 if is_flying(id) else 0.002)
		"hurt":
			hurt = sin(progress * PI) * (1.0 - progress)
			pose = -hurt * 0.70
			offset.x = -hurt * 0.020
			tilt = hurt * 0.035
		"appear":
			alpha = smoothstep(0.0, 0.75, progress)
			offset.y = -pow(1.0 - progress, 2.0) * (0.07 if is_flying(id) else 0.028)
		"death":
			alpha = 1.0 - smoothstep(0.15, 1.0, progress)
			offset.y = -progress * progress * 0.035
			tilt = progress * 0.09
	# Incommensurate timing prevents an entire team blinking in unison. A long
	# dwell and a 170 ms closed/open arc feels organic without random frame state.
	var interval := 3.7 + fposmod(seed * 0.731, 1.7)
	var blink_age := fposmod(time + seed * 1.371, interval)
	var closure := sin(PI * blink_age / 0.17) if blink_age < 0.17 else 0.0
	if state == "blink":
		closure = sin(progress * PI)
	if state in ["hurt", "death"]:
		closure = maxf(closure, hurt * 0.70 if state == "hurt" else progress)
	var can_walk := not bool(metadata.requires_upright_pose) or upright
	return {"state": state, "progress": progress, "seed": seed, "action": pose, "offset": offset, "tilt": tilt, "alpha": alpha, "hurt": hurt, "cast": casting, "blink": clampf(closure, 0.0, 1.0), "walk": state == "locomotion" and can_walk, "upright": upright, "pose_required": "upright" if not can_walk and state in ["locomotion", "attack", "cast"] else ""}

func begin_frame() -> void:
	# Retain RID resources across frames, with one dynamic buffer per draw slot.
	# Reuse avoids rebuilding GPU topology/UV buffers at every 60 Hz repaint.
	_mesh_cursor = 0

func is_flying(id: String) -> bool:
	return id in ["luna", "cloud", "tidejelly", "runewisp", "moonwarden"]

func profile(id: String) -> Dictionary:
	if _profiles.has(id):
		return _profiles[id]
	var rig := {"rate": 1.25, "stride": 0.023, "lift": 0.026, "hips": [Vector2(0.30, 0.75), Vector2(0.70, 0.75)], "feet": [Vector2(0.29, 0.97), Vector2(0.74, 0.97)], "radius": 0.18, "head": Vector2(0.57, 0.35)}
	match id:
		"ember":
			rig.merge({"rate": 1.65, "hips": [Vector2(0.46, 0.78), Vector2(0.75, 0.74)], "feet": [Vector2(0.48, 0.98), Vector2(0.81, 0.98)], "radius": 0.12, "head": Vector2(0.70, 0.42)}, true)
		"moss":
			rig.merge({"rate": 0.86, "stride": 0.018, "lift": 0.018, "hips": [Vector2(0.16, 0.81), Vector2(0.63, 0.81), Vector2(0.84, 0.80)], "feet": [Vector2(0.15, 0.96), Vector2(0.62, 0.98), Vector2(0.89, 0.97)], "radius": 0.14, "head": Vector2(0.82, 0.56)}, true)
		"tide":
			rig.merge({"rate": 1.38, "hips": [Vector2(0.36, 0.78), Vector2(0.61, 0.77), Vector2(0.78, 0.77)], "feet": [Vector2(0.35, 0.96), Vector2(0.59, 0.98), Vector2(0.82, 0.96)], "radius": 0.115, "head": Vector2(0.68, 0.46)}, true)
		"crag", "shardguard":
			rig.merge({"rate": 0.80, "stride": 0.02, "lift": 0.032, "hips": [Vector2(0.36, 0.78), Vector2(0.65, 0.78)], "feet": [Vector2(0.35, 0.98), Vector2(0.67, 0.98)], "radius": 0.16}, true)
		"thornbud":
			rig.merge({"rate": 1.6, "hips": [Vector2(0.39, 0.79), Vector2(0.62, 0.79)], "feet": [Vector2(0.33, 0.97), Vector2(0.71, 0.97)]}, true)
		"pebblebug":
			rig.merge({"rate": 1.15, "lift": 0.02, "hips": [Vector2(0.23, 0.77), Vector2(0.52, 0.77), Vector2(0.78, 0.74)], "feet": [Vector2(0.16, 0.96), Vector2(0.50, 0.97), Vector2(0.87, 0.95)], "radius": 0.12, "head": Vector2(0.25, 0.52)}, true)
		"reefclaw":
			rig.merge({"rate": 1.5, "stride": 0.027, "hips": [Vector2(0.32, 0.77), Vector2(0.71, 0.77)], "feet": [Vector2(0.29, 0.97), Vector2(0.82, 0.97)], "radius": 0.14}, true)
		"rootelder":
			rig.merge({"rate": 0.62, "lift": 0.02, "stride": 0.014, "hips": [Vector2(0.35, 0.80), Vector2(0.68, 0.80)], "feet": [Vector2(0.32, 0.98), Vector2(0.73, 0.98)]}, true)
		"abyssmaw":
			rig.merge({"rate": 0.85, "stride": 0.01, "lift": 0.008, "hips": [Vector2(0.36, 0.82), Vector2(0.71, 0.82)], "feet": [Vector2(0.33, 0.98), Vector2(0.78, 0.98)], "head": Vector2(0.30, 0.28)}, true)
	_profiles[id] = rig
	return rig

func _skin(template: Dictionary, id: String, rig: Dictionary) -> Dictionary:
	var key := id + str(template.points.size()) + str(rig)
	if _skins.has(key):
		return _skins[key]
	var limbs: Array = []
	var body_weights := PackedVector2Array()
	for point: Vector2 in template.points:
		var weights: Array[Vector4] = []
		for i in range(rig.feet.size()):
			var hip: Vector2 = rig.hips[i]
			var foot: Vector2 = rig.feet[i]
			var weight := _falloff(absf(point.x - lerpf(hip.x, foot.x, clampf((point.y - hip.y) / maxf(foot.y - hip.y, 0.01), 0.0, 1.0))), float(rig.radius) * 0.42, float(rig.radius)) * smoothstep(hip.y - 0.06, hip.y + 0.08, point.y)
			if weight > 0.001:
				var length := hip.distance_to(foot)
				var knee := _knee(hip, foot, length * 0.57, length * 0.57, -1.0 if i % 2 == 0 else 1.0)
				weights.append(Vector4(i, weight, smoothstep(knee.y - 0.04, knee.y + 0.08, point.y), smoothstep(0.92, 0.98, point.y)))
		limbs.append(weights)
		body_weights.append(Vector2(_falloff(point.distance_to(Vector2(0.56, 0.66)), 0.10, 0.34), _falloff(point.distance_to(rig.head), 0.15, 0.27) * _falloff(point.y, 0.66, 0.78)))
	var result := {"limbs": limbs, "body": body_weights}
	_skins[key] = result
	return result

func _template(sheet: Texture2D, source: Rect2) -> Dictionary:
	var key := str(sheet.get_instance_id()) + str(source)
	if _templates.has(key):
		return _templates[key]
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in range(ROWS + 1):
		for col in range(COLUMNS + 1):
			var p := Vector2(float(col) / COLUMNS, float(row) / ROWS)
			points.append(p)
			uv.append((source.position + p * source.size) / sheet.get_size())
	for row in range(ROWS):
		for col in range(COLUMNS):
			var a := row * (COLUMNS + 1) + col
			indices.append_array(PackedInt32Array([a, a + 1, a + COLUMNS + 1, a + 1, a + COLUMNS + 2, a + COLUMNS + 1]))
	# Alpha-trimmed atlases can contain isolated sparks or export speckles below
	# the actual feet. Detect the final solid silhouette row instead of using an
	# almost-transparent pixel as the grounding plane.
	var image := sheet.get_image()
	var contact := 1.0
	var bounds := Rect2i(source)
	for y in range(bounds.end.y - 1, bounds.position.y + int(bounds.size.y * 0.72), -1):
		var solid := 0
		for x in range(bounds.position.x, bounds.end.x, 2):
			if image.get_pixel(x, y).a >= 0.72:
				solid += 1
		if solid >= maxi(3, int(bounds.size.x * 0.032)):
			contact = float(y + 1 - bounds.position.y) / float(bounds.size.y)
			break
	var result := {"points": points, "uv": uv, "indices": indices, "contact": contact}
	_templates[key] = result
	return result

func _falloff(value: float, inner: float, outer: float) -> float:
	return 1.0 - smoothstep(inner, outer, value)

func _around(point: Vector2, pivot: Vector2, angle: float) -> Vector2:
	return pivot + (point - pivot).rotated(angle)

## Toe path: 62% planted stance, 38% smooth lifted return. Unlike a sinusoid,
## the foot moves backwards at constant speed during contact with the floor.
func foot_offset(cycle: float, stride: float, lift: float) -> Vector2:
	var phase := fposmod(cycle, 1.0)
	if phase < 0.62:
		return Vector2(lerpf(stride, -stride, phase / 0.62), 0.0)
	var swing := (phase - 0.62) / 0.38
	return Vector2(lerpf(-stride, stride, smoothstep(0.0, 1.0, swing)), -sin(PI * swing) * lift)

func stride_for_ground_speed(speed_px: float, cycles_per_second: float, width_px: float) -> float:
	# Match planted-foot velocity to the scrolling ground. A fixed normalized
	# stride makes large and small creatures skate at different world speeds.
	return clampf(speed_px * 0.62 / (2.0 * maxf(cycles_per_second, 0.1) * maxf(width_px, 1.0)), -0.065, 0.065)

## Source-space partitions for the first upright fox frame. Each painted pixel
## belongs to one leg, never to a blend of four nearby skeletons.
func ember_leg_masks() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for polygon in [
		[Vector2(72,238),Vector2(135,238),Vector2(135,330),Vector2(72,330)],
		[Vector2(135,247),Vector2(193,247),Vector2(193,330),Vector2(135,330)],
		[Vector2(193,238),Vector2(247,238),Vector2(247,330),Vector2(193,330)],
		[Vector2(247,238),Vector2(315,238),Vector2(315,330),Vector2(247,330)]]:
		var points := PackedVector2Array()
		for point: Vector2 in polygon:
			points.append(point / Vector2(325,315))
		result.append(points)
	return result

func ember_rigid_pose(time: float, walking: bool, width_px: float, seed: float, speed_px: float = 15.36, body_shift: Vector2 = Vector2.ZERO) -> Array:
	var hips := [Vector2(109,248),Vector2(154,252),Vector2(207,248),Vector2(250,249)]
	var knees := [Vector2(91,273),Vector2(151,275),Vector2(203,271),Vector2(248,272)]
	var feet := [Vector2(102,292),Vector2(178,291),Vector2(225,298),Vector2(272,295)]
	var phases := [0.0,0.5,0.75,0.25]
	var cycle := (time + instance_variation(seed) * 8.0) * 0.90
	var stride := stride_for_ground_speed(speed_px, 0.90, width_px)
	var result: Array = []
	for i in range(4):
		var hip: Vector2 = hips[i] / Vector2(325,315)
		var knee: Vector2 = knees[i] / Vector2(325,315)
		var toe: Vector2 = feet[i] / Vector2(325,315)
		var offset := foot_offset(cycle + float(phases[i]), stride, 0.012) if walking else Vector2.ZERO
		var moved_hip := hip + body_shift
		var moved_toe := toe + offset
		var upper := hip.distance_to(knee)
		var lower := knee.distance_to(toe)
		var bend := 1.0 if (knee-hip).cross(toe-knee) > 0.0 else -1.0
		# _knee's perpendicular convention is opposite the triangle cross sign.
		var moved_knee := _knee(moved_hip,moved_toe,upper,lower,-bend)
		var a := (moved_knee-moved_hip).angle()-(knee-hip).angle()
		var b := (moved_toe-moved_knee).angle()-(toe-knee).angle()
		result.append({"upper":Transform2D(a,moved_hip-hip.rotated(a)),"lower":Transform2D(b,moved_knee-knee.rotated(b)),"foot":Transform2D(0.0,offset),"knee_y":knee.y,"toe_y":toe.y-0.020,"hip":hip,"toe":toe})
	return result

func _ember_partition() -> Dictionary:
	if not _ember_parts.is_empty():
		return _ember_parts
	var masks := ember_leg_masks()
	var bounds := PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
	var body: Array[PackedVector2Array] = [bounds]
	var legs: Array = []
	var used: Array[PackedVector2Array] = []
	for mask: PackedVector2Array in masks:
		var disjoint: Array[PackedVector2Array] = [mask]
		for earlier: PackedVector2Array in used:
			var remaining: Array[PackedVector2Array] = []
			for piece: PackedVector2Array in disjoint:
				remaining.append_array(Geometry2D.clip_polygons(piece,earlier))
			disjoint = remaining
		legs.append(disjoint)
		used.append(mask)
		var remaining_body: Array[PackedVector2Array] = []
		var body_cut:=mask.duplicate()
		for index in range(body_cut.size()):
			if body_cut[index].y<0.90:
				body_cut[index].y+=8.0/315.0
		for piece: PackedVector2Array in body:
			remaining_body.append_array(Geometry2D.clip_polygons(piece,body_cut))
		body = remaining_body
	_ember_parts = {"body":body,"legs":legs}
	return _ember_parts

func _ember_cutout_textures(sheet:Texture2D,source:Rect2) -> Array[Texture2D]:
	var key:=str(sheet.get_instance_id())+str(source)
	if _ember_textures.has(key):
		return _ember_textures[key]
	var body:=sheet.get_image().get_region(Rect2i(source))
	var limbs:Array[Image]=[]
	for i in range(4):
		limbs.append(Image.create(body.get_width(),body.get_height(),false,Image.FORMAT_RGBA8))
	# The cream/orange fur belongs to the torso even when it overlaps a leg's
	# rectangular domain. Material-aware cutouts avoid moving little chest
	# fragments with the shin and leave no painted stationary paw underneath.
	for y in range(238,mini(315,body.get_height())):
		for x in range(72,mini(315,body.get_width())):
			var limb:=0 if x<135 else 1 if x<193 else 2 if x<247 else 3
			if limb==1 and y<247:
				continue
			var color:=body.get_pixel(x,y)
			if color.a<0.002 or color.r>0.82 or color.g>0.56 or color.b>0.65:
				continue
			limbs[limb].set_pixel(x,y,color)
			body.set_pixel(x,y,Color.TRANSPARENT)
	var result:Array[Texture2D]=[ImageTexture.create_from_image(body)]
	for limb:Image in limbs:
		result.append(ImageTexture.create_from_image(limb))
	_ember_textures[key]=result
	return result

func _draw_rigid_polygon(canvas: CanvasItem,sheet:Texture2D,source:Rect2,target:Rect2,polygon:PackedVector2Array,transform:Transform2D,tint:Color,key:String,contact:float,state_offset:Vector2,state_tilt:float) -> void:
	if polygon.size()<3:
		return
	var indices := Geometry2D.triangulate_polygon(polygon)
	if indices.is_empty():
		return
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for point:Vector2 in polygon:
		var p := transform * point
		p.y += 1.0-contact
		p = _around(p,Vector2(0.5,1.0),state_tilt)+state_offset
		var pixel := target.position+p*target.size
		vertices.append(Vector3(pixel.x,pixel.y,0))
		uvs.append((source.position+point*source.size)/sheet.get_size())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:ArrayMesh
	if _mesh_cursor<_frame_meshes.size():
		mesh=_frame_meshes[_mesh_cursor]
	else:
		mesh=ArrayMesh.new()
		_frame_meshes.append(mesh)
	var mesh_key:=str(sheet.get_instance_id())+str(source)+key+str(polygon)
	if mesh.get_meta("source_key","")!=mesh_key:
		mesh.clear_surfaces()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
		mesh.set_meta("source_key",mesh_key)
	else:
		mesh.surface_update_vertex_region(0,0,vertices.to_byte_array())
	_mesh_cursor+=1
	canvas.draw_mesh(mesh,_render_texture(sheet),Transform2D.IDENTITY,tint)

func _paint_ember_rigid(canvas:CanvasItem,sheet:Texture2D,source:Rect2,target:Rect2,time:float,walking:bool,tint:Color,action:float,sampled:Dictionary,animation:Dictionary) -> void:
	var seed:=float(animation.get("seed",1.0))
	var body_shift:=Vector2(action*0.022,absf(action)*0.009+(0.012 if walking else 0.0))
	var poses:=ember_rigid_pose(time,walking,absf(target.size.x),seed,float(animation.get("ground_speed",15.36)),body_shift)
	var parts:=_ember_partition()
	var textures:=_ember_cutout_textures(sheet,source)
	var cutout_source:=Rect2(Vector2.ZERO,source.size)
	var contact:float=_template(sheet,source).contact
	var offset:Vector2=sampled.offset
	var tilt:float=sampled.tilt
	# Every segment is a rigid island. Small overlap is confined to the same
	# limb's knee/toe seams; unrelated legs never share weights or vertices.
	for i in range(4):
		if int(animation.get("debug_limb",-1))>=0 and int(animation.debug_limb)!=i:
			continue
		var pose:Dictionary=poses[i]
		var bands:=[Rect2(0,0,1,float(pose.knee_y)+0.004),Rect2(0,float(pose.knee_y)-0.004,1,float(pose.toe_y)-float(pose.knee_y)+0.008),Rect2(0,float(pose.toe_y)-0.004,1,1)]
		var transforms:=[pose.upper,pose.lower,pose.foot]
		for piece:PackedVector2Array in parts.legs[i]:
			for band in range(3):
				if int(animation.get("debug_segment",-1))>=0 and int(animation.debug_segment)!=band:
					continue
				var r:Rect2=bands[band]
				var box:=PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
				for cut:PackedVector2Array in Geometry2D.intersect_polygons(piece,box):
					_draw_rigid_polygon(canvas,textures[i+1],cutout_source,target,cut,transforms[band],tint,"fox_"+str(i)+"_"+str(band),contact,offset,tilt)
	if int(animation.get("debug_limb",-1))<0:
		var polygon:=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
		_draw_rigid_polygon(canvas,textures[0],cutout_source,target,polygon,Transform2D(0,body_shift),tint,"fox_body",contact,offset,tilt)
	if float(sampled.blink)>0.08 and bool(animation.get("blink_enabled",true)):
		_draw_eyelids(canvas,sheet,source,target,"ember",float(sampled.blink),body_shift,Transform2D.IDENTITY,false,contact,offset,tilt,tint,animation.get("eyes",upright_eyes("ember")))

## Two-bone solve in normalized sprite space. A stable bend direction avoids
## knee snapping; legs never scale to fake a step.
func _knee(hip: Vector2, toe: Vector2, upper: float, lower: float, bend: float) -> Vector2:
	var delta := toe - hip
	var distance := clampf(delta.length(), 0.001, upper + lower - 0.0001)
	var direction := delta.normalized()
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, upper * upper - along * along))
	return hip + direction * along + Vector2(-direction.y, direction.x) * height * bend

func paint(canvas: CanvasItem, sheet: Texture2D, source: Rect2, target: Rect2, id: String, time: float, walking: bool, frozen: bool, tint: Color, action_pose: float = 0.0, animation: Dictionary = {}) -> void:
	if sheet == null or source.size.x <= 0.0 or source.size.y <= 0.0:
		return
	var render_texture := _render_texture(sheet)
	if frozen:
		canvas.draw_texture_rect_region(render_texture, target, source, tint)
		return
	var state := str(animation.get("state", "locomotion" if walking else "idle"))
	if walking and state in ["idle", "stand"]:
		state = "locomotion"
	var sampled := animation if animation.has("progress") else sample_animation(id, time, state, float(animation.get("age", 0.0)), float(animation.get("seed", SPECIES.find(id) + 1)), bool(animation.get("upright", false)))
	walking = bool(sampled.walk) and not bool(animation.get("drawn_walk_cycle", false))
	# Stand/walk artwork is selected by the caller; a seated idle is never
	# deformed into a fake walk just because the actor's world x is changing.
	if absf(action_pose) < 0.001:
		action_pose = float(sampled.action)
	tint.a *= float(sampled.alpha)
	if tint.a <= 0.001:
		return
	if id=="ember" and bool(animation.get("upright",false)) and sheet.resource_path=="res://assets/animations/ember-locomotion-v2.png" and source.position.y<341.0:
		_paint_ember_rigid(canvas,sheet,source,target,time,walking,tint,action_pose,sampled,animation)
		return
	var rig := upright_profile(id) if bool(animation.get("upright", false)) else profile(id)
	if animation.has("anatomy") and animation.anatomy is Dictionary:
		rig = rig.duplicate(true)
		rig.merge(animation.anatomy, true)
	var instance_seed := float(animation.get("seed", SPECIES.find(id) + 1))
	var local_time := time + instance_variation(instance_seed, 0.0) * 8.0
	var phase := local_time * float(rig.rate)
	var breath := sin(local_time * 2.4) * 0.0015
	var flying := is_flying(id)
	var body_shift := Vector2(action_pose * 0.022, absf(action_pose) * 0.009)
	if flying:
		body_shift.y += -0.045 + sin(local_time * 2.8) * 0.008
	elif walking:
		body_shift.y -= (1.0 - cos(phase * TAU * 2.0)) * 0.0018
	var hips: Array = rig.hips
	var feet: Array = rig.feet
	var stride := stride_for_ground_speed(float(animation.get("ground_speed", 15.36)), float(rig.rate), absf(target.size.x)) if walking else float(rig.stride)
	var offsets: Array[Vector2] = []
	var knees: Array[Vector2] = []
	var rest_knees: Array[Vector2] = []
	var uppers: Array[Transform2D] = []
	var lowers: Array[Transform2D] = []
	for i in range(feet.size()):
		var foot_phase := float(rig.get("phases", [])[i]) if rig.has("phases") else (0.5 if i % 2 else 0.0)
		var offset := foot_offset(phase + foot_phase, stride, float(rig.lift)) if walking and not flying else Vector2.ZERO
		offsets.append(offset)
		var length: float = hips[i].distance_to(feet[i])
		var bend := -1.0 if i % 2 == 0 else 1.0
		rest_knees.append(_knee(hips[i], feet[i], length * 0.57, length * 0.57, bend))
		knees.append(_knee(hips[i] + body_shift, feet[i] + offset, length * 0.57, length * 0.57, bend))
		var upper_angle: float = (knees[i] - hips[i] - body_shift).angle() - (rest_knees[i] - hips[i]).angle()
		var lower_angle: float = (feet[i] + offset - knees[i]).angle() - (feet[i] - rest_knees[i]).angle()
		uppers.append(Transform2D(upper_angle, hips[i] + body_shift - Vector2(hips[i]).rotated(upper_angle)))
		lowers.append(Transform2D(lower_angle, knees[i] - rest_knees[i].rotated(lower_angle)))
	var template := _template(sheet, source)
	var skin_data := _skin(template, id, rig)
	var vertices := PackedVector3Array()
	var point_index := -1
	var head: Vector2 = rig.head
	var head_pivot := head + Vector2(0, 0.15)
	var head_transform := Transform2D(-action_pose * 0.055, head_pivot - head_pivot.rotated(-action_pose * 0.055))
	var state_offset: Vector2 = sampled.offset
	var state_tilt: float = sampled.tilt
	for original: Vector2 in template.points:
		point_index += 1
		var p := original
		# Torso translates coherently. Very small chest respiration, zero facial
		# scaling: no full-body jelly deformation and no moving planted toes.
		var chest: float = skin_data.body[point_index].x
		p += body_shift + Vector2(0.0, -breath * chest)
		if flying:
			p = _flight_pose(p, original, id, local_time, action_pose)
		else:
			var face_weight: float = skin_data.body[point_index].y
			if face_weight > 0.001 and absf(action_pose) > 0.001:
				p = p.lerp(head_transform * p, face_weight)
			var weight_sum := 0.0
			var skin := Vector2.ZERO
			for weights: Vector4 in skin_data.limbs[point_index]:
				var i := int(weights.x)
				var weight := weights.y
				var upper_point := uppers[i] * original
				var lower_point := lowers[i] * original
				var articulated := upper_point.lerp(lower_point, weights.z)
				# Last few pixels share the toe transform and remain level in stance.
				articulated = articulated.lerp(original + offsets[i], weights.w)
				skin += (articulated - p) * weight
				weight_sum += weight
			p += skin / maxf(1.0, weight_sum)
			p = _secondary_pose(p, original, id, local_time, walking, action_pose, rig)
			# Translate the solid contact row onto the floor. Clamping coarse
			# bottom vertices compresses transparent padding and leaves the actual
			# opaque paws suspended a few pixels above the plane.
			p.y += 1.0 - float(template.contact)
		p = _around(p, Vector2(0.5, 1.0), state_tilt) + state_offset
		var pixel := target.position + p * target.size
		vertices.append(Vector3(pixel.x, pixel.y, 0.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = template.uv
	arrays[Mesh.ARRAY_INDEX] = template.indices
	var mesh: ArrayMesh
	var mesh_key := str(sheet.get_instance_id()) + str(source)
	if _mesh_cursor < _frame_meshes.size():
		mesh = _frame_meshes[_mesh_cursor]
	else:
		mesh = ArrayMesh.new()
		_frame_meshes.append(mesh)
	if mesh.get_meta("source_key", "") != mesh_key:
		mesh.clear_surfaces()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
		mesh.set_meta("source_key", mesh_key)
	else:
		mesh.surface_update_vertex_region(0, 0, vertices.to_byte_array())
	_mesh_cursor += 1
	canvas.draw_mesh(mesh, render_texture, Transform2D.IDENTITY, tint)
	if float(sampled.blink) > 0.025 and bool(animation.get("blink_enabled", true)):
		var eyes: Array = animation.get("eyes", [])
		if eyes.is_empty() and id == "ember" and sheet.resource_path == "res://assets/animations/ember-locomotion-v2.png" and source.position.y < 341.0:
			eyes = upright_eyes(id)
		_draw_eyelids(canvas, sheet, source, target, id, float(sampled.blink), body_shift, head_transform, flying, float(template.contact), state_offset, state_tilt, tint, eyes)

func _eye_definitions(id: String) -> Array:
	# Canonical atlas pixel coordinates, before alpha trimming. Entries are
	# Vector4(center_x, center_y, radius_x, radius_y), not generic face bands.
	match id:
		"ember": return [Vector4(365, 249, 23, 25), Vector4(431, 247, 9, 16)]
		"moss": return [Vector4(941, 294, 19, 20)]
		"luna": return [Vector4(1304, 223, 19, 20), Vector4(1375, 226, 17, 20)]
		"tide": return [Vector4(344, 746, 24, 25), Vector4(475, 737, 16, 20)]
		"crag": return [Vector4(812.5, 726, 12, 23), Vector4(882, 720, 13, 23)]
		"cloud": return [Vector4(1317, 697, 20, 24), Vector4(1392, 699, 16, 21)]
		"thornbud": return [Vector4(170, 282, 9, 17), Vector4(212, 279, 13, 20)]
		"pebblebug": return [Vector4(501, 279, 7, 16), Vector4(557, 280, 17, 23)]
		"reefclaw": return [Vector4(977, 181, 15, 25), Vector4(1033, 179, 15, 25)]
		"tidejelly": return [Vector4(121, 566, 14, 20), Vector4(175, 559, 16, 21)]
		"runewisp": return [Vector4(578, 608, 10, 15), Vector4(614, 601, 13, 20)]
		"shardguard": return [Vector4(982, 635, 10, 17), Vector4(1029, 630, 13, 17)]
		"rootelder": return [Vector4(122, 967, 6, 10), Vector4(169, 957, 10, 12)]
		"abyssmaw": return [Vector4(482.5, 947, 6.5, 6)]
		"moonwarden": return [Vector4(974, 995, 8, 15), Vector4(1022, 990, 15, 19)]
	return []

func _eye_skin_sample(id: String, fallback: Vector2) -> Vector2:
	# Verified patches of the same facial material, away from pupils, gills,
	# antlers and glows. One shared swatch makes both eyelids visually consistent.
	match id:
		"tide": return Vector2(400, 700)
		"crag": return Vector2(844, 735)
		"thornbud": return Vector2(206, 304)
		"pebblebug": return Vector2(534, 314)
		"reefclaw": return Vector2(965, 184)
		"tidejelly": return Vector2(164, 584)
		"runewisp": return Vector2(592, 610)
		"shardguard": return Vector2(1007, 642)
		"rootelder": return Vector2(147, 965)
		"abyssmaw": return Vector2(489, 946)
		"moonwarden": return Vector2(1000, 1012)
	return fallback

func _eye_data(sheet: Texture2D, source: Rect2, id: String, custom: Array) -> Array:
	var key := str(sheet.get_instance_id()) + str(source) + id + str(custom)
	if _eyelids.has(key):
		return _eyelids[key]
	var eyes: Array = []
	var image := sheet.get_image()
	var definitions := _eye_definitions(id)
	if not custom.is_empty():
		definitions = custom
	elif not sheet.resource_path in ["res://assets/creatures-taskmon.png", "res://assets/enemies.png"]:
		# New artwork needs its own verified eye anchors. Never reuse the old
		# seated face's coordinates on an upright/new animation frame.
		return []
	for definition in definitions:
		var center: Vector2
		var radius: Vector2
		var skin: Color
		if definition is Dictionary:
			center = definition.center
			radius = definition.radius
			var pixel := source.position + Vector2(definition.get("sample", center - Vector2(0, radius.y * 1.45))) * source.size
			skin = definition.get("skin", image.get_pixelv(Vector2i(pixel).clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)))
		else:
			var entry: Vector4 = definition
			center = (Vector2(entry.x, entry.y) - source.position) / source.size
			radius = Vector2(entry.z, entry.w) / source.size
			var pixel := Vector2i(_eye_skin_sample(id, Vector2(entry.x, entry.y - entry.w * 1.45))).clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
			skin = image.get_pixelv(pixel)
		if skin.a < 0.85 or not Rect2(0, 0, 1, 1).has_point(center):
			continue
		eyes.append({"center": center, "radius": radius, "skin": skin})
	_eyelids[key] = eyes
	return eyes

func _eyelid_point(point: Vector2, target: Rect2, body: Vector2, head: Transform2D, flying: bool, contact: float, offset: Vector2, tilt: float) -> Vector2:
	var p := point + body
	if not flying:
		p = head * p
		p.y += 1.0 - contact
	p = _around(p, Vector2(0.5, 1.0), tilt) + offset
	return target.position + p * target.size

func _draw_eyelids(canvas: CanvasItem, sheet: Texture2D, source: Rect2, target: Rect2, id: String, closure: float, body: Vector2, head: Transform2D, flying: bool, contact: float, offset: Vector2, tilt: float, tint: Color, custom: Array) -> void:
	if closure < 0.08:
		return
	for eye: Dictionary in _eye_data(sheet, source, id, custom):
		var center: Vector2 = eye.center
		var radius: Vector2 = eye.radius
		# Two clipped oval caps close over the iris, retaining the species' own
		# sampled eyelid color. Their boundaries meet only when fully closed.
		for side in [-1.0, 1.0]:
			var polygon := PackedVector2Array()
			var intersection := asin(clampf(1.0 - closure, 0.0, 1.0))
			for step in range(13):
				var angle := lerpf(intersection, PI - intersection, float(step) / 12.0)
				var point := center + Vector2(cos(angle) * radius.x, side * sin(angle) * radius.y)
				polygon.append(_eyelid_point(point, target, body, head, flying, contact, offset, tilt))
			# A convex ellipse cap has no duplicated edge vertices or crossed
			# strips at partial closure. Tiny sprites can still collapse below
			# subpixel precision; do not submit a degenerate polygon to Godot.
			if Geometry2D.triangulate_polygon(polygon).size() >= 3:
				canvas.draw_colored_polygon(polygon, Color(eye.skin) * tint)
		if closure > 0.85:
			var line := PackedVector2Array()
			for step in range(7):
				var x := lerpf(-0.90, 0.90, float(step) / 6.0)
				var point := center + Vector2(x * radius.x, sin((x + 1.0) * PI * 0.5) * radius.y * 0.08)
				line.append(_eyelid_point(point, target, body, head, flying, contact, offset, tilt))
			var contour: Color = Color(eye.skin).darkened(0.65) * tint
			contour.a *= smoothstep(0.85, 1.0, closure)
			canvas.draw_polyline(line, contour, maxf(1.0, absf(target.size.y) * 0.003), true)

func _secondary_pose(p: Vector2, uv: Vector2, id: String, time: float, walking: bool, action: float, rig: Dictionary = {}) -> Vector2:
	if id == "ember":
		# Tail is left of the pelvis, not the fox's torso. Rotate around its base.
		var tail := _falloff(uv.x, 0.26, 0.43) * smoothstep(0.18, 0.38, uv.y) * _falloff(uv.y, 0.83, 0.98)
		if rig.has("tail_floor"):
			tail *= _falloff(uv.y, float(rig.tail_floor) - 0.10, float(rig.tail_floor))
		if tail > 0.001:
			p = p.lerp(_around(p, rig.get("tail_pivot", Vector2(0.42, 0.81)), sin(time * 2.2) * 0.028 - action * 0.04), tail)
		# Ear tips respond after the body, face and eyes retain their shape.
		var ears := _falloff(uv.y, 0.17, 0.36) * smoothstep(0.38, 0.50, uv.x)
		if ears > 0.001:
			p = p.lerp(_around(p, rig.get("ear_pivot", Vector2(0.64, 0.35)), sin(time * 2.2 - 0.5) * 0.012), ears)
	elif id == "tide":
		var tail := _falloff(uv.x, 0.16, 0.35) * smoothstep(0.56, 0.70, uv.y)
		if tail > 0.001:
			p = p.lerp(_around(p, Vector2(0.36, 0.79), sin(time * 2.5) * 0.025), tail)
	elif id in ["crag", "shardguard", "thornbud", "rootelder", "reefclaw"]:
		var arm := smoothstep(0.15, 0.30, absf(uv.x - 0.5)) * smoothstep(0.40, 0.57, uv.y) * _falloff(uv.y, 0.78, 0.91)
		if arm < 0.001:
			return p
		var pivot := Vector2(0.28 if uv.x < 0.5 else 0.73, 0.56)
		var sign_x := -1.0 if uv.x < 0.5 else 1.0
		var sway := sin(time * (3.0 if walking else 1.8)) * 0.018
		p = p.lerp(_around(p, pivot, sign_x * (sway + action * 0.11)), arm)
	elif id == "abyssmaw":
		var crest := _falloff(uv.y, 0.20, 0.38)
		p.x += sin(time * 2.1) * crest * 0.003
	return p

func _flight_pose(p: Vector2, uv: Vector2, id: String, time: float, action: float) -> Vector2:
	if id in ["luna", "cloud", "moonwarden"]:
		var center := 0.57 if id == "luna" else 0.62
		var wing_weight := smoothstep(0.10, 0.30, absf(uv.x - center))
		if id == "cloud":
			wing_weight *= smoothstep(0.40, 0.60, uv.y) * _falloff(uv.y, 0.85, 0.98)
		elif id == "moonwarden":
			wing_weight *= _falloff(uv.y, 0.68, 0.90)
		if wing_weight < 0.001:
			return p
		var side := -1.0 if uv.x < center else 1.0
		var flap := sin(time * (8.5 if id == "luna" else 5.7))
		var pivot := Vector2(center + side * 0.10, 0.47 if id == "luna" else 0.61)
		# Pivot articulation maintains the painted wing's shape; amplitude avoids
		# pretending a frontal atlas can show an unavailable side/back wing pose.
		p = p.lerp(_around(p, pivot, side * (flap * 0.095 + action * 0.08)), wing_weight)
	elif id == "tidejelly":
		var tentacles := smoothstep(0.44, 0.68, uv.y)
		p.x += sin(time * 2.8 + uv.y * 4.0) * tentacles * 0.012
	elif id == "runewisp":
		var wisps := smoothstep(0.60, 0.88, uv.y)
		p.x += sin(time * 2.6 + uv.y * 5.0) * wisps * 0.009
	return p
