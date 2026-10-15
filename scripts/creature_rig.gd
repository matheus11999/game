class_name TaskMonCreatureRig
extends Node2D
## Authored, overlapping artwork. No extraction of limbs from a full-body sprite.
const METADATA_PATH = 'res://assets/rigs/rig-metadata.json'
static var _region_cache: Dictionary = {}
var skeleton: Skeleton2D
var bones: Dictionary = {}
var parts: Dictionary = {}
var rest_points: Dictionary = {}
var metadata: Dictionary = {}
var species_id = ''
var phase = 0.0
var clock = 0.0
var walk_blend = 0.0
var state = 'idle'
var state_age = 0.0
var seed = 0.0
var speed = 15.36
var speed_factor = 1.0
var action = 0.0
var _sheet: Texture2D
var _image: Image
var _head_regions: Dictionary = {}
var _head_frame = -1
var support_targets: Dictionary = {}
var _previous_state = 'idle'
# Posture is separate from the gait: a seated fox must finish rising before
# any foot starts a walking cycle. Other species keep their existing anatomy.
var sit_blend = 0.0
var _sit_progress = 0.0
var _sit_target = 0.0
var _posture_resume_state = 'idle'
var _allow_sit = false
var _auto_sitting = false
var _idle_age = 0.0

func configure(id: String, texture: Texture2D, config: Dictionary = {}) -> void:
 species_id = id
 _sheet = texture
 _image = texture.get_image()
 metadata = config
 if metadata.is_empty():
  var file = FileAccess.open(METADATA_PATH, FileAccess.READ)
  var catalog = JSON.parse_string(file.get_as_text()) if file else {}
  for path in ['res://assets/rigs/rig-species.json','res://assets/rigs/rig-enemies.json']:
   if FileAccess.file_exists(path): catalog.merge(JSON.parse_string(FileAccess.get_file_as_string(path)),true)
  metadata = catalog.get(id, catalog.get('ember', {}))
 skeleton = Skeleton2D.new()
 skeleton.name = 'Skeleton2D'
 add_child(skeleton)
 _bone('body', '', Vector2(0,-150))
 _bone('head', 'body', _v(metadata.head_pivot))
 _bone('tail', 'body', _v(metadata.tail_pivot))
 for index in range(4):
  var hip = _v(metadata.hips[index])
  var foot = _v(metadata.feet[index])
  var knee_offset = float(metadata.get('knee_offsets',[-7, -26 if id == 'ember' else 10, -7, -26 if id == 'ember' else 10])[index])
  var knee = hip.lerp(foot,0.52) + Vector2(knee_offset,0)
  _bone('upper%d'%index,'body',hip)
  _bone('lower%d'%index,'upper%d'%index,knee)
 # Back-to-front ordering, independent chains prevent cross-limb influence.
 _part('far_rear',9,_limb_rect(3,true),'upper3','lower3',-4)
 _part('far_front',8,_limb_rect(2,true),'upper2','lower2',-3)
 _part('tail',2,_rect(metadata.tail),'tail','',-2)
 _part('torso',0,_rect(metadata.body),'body','',0)
 for index in range(2):
  var hip = _v(metadata.hips[index])
  var knee: Vector2 = rest_points['lower%d'%index]
  var us = _v(metadata.upper_size[index])
  var ls = _v(metadata.lower_size[index])
  _part('upper%d'%index,4 if index == 0 else 6,Rect2(hip-Vector2(us.x*.5,8),us),'upper%d'%index,'lower%d'%index,-1)
  var foot = _v(metadata.feet[index])
  var contact_x = float(metadata.get('lower_contact_x',[0.69,0.80] if id == 'ember' else [0.55,0.55])[index])
  var lower_rect = Rect2(Vector2(foot.x-ls.x*contact_x,knee.y-18),Vector2(ls.x,foot.y-knee.y+18))
  if id != 'ember': lower_rect = Rect2(knee-Vector2(ls.x*.48,10),ls)
  _part('lower%d'%index,5 if index == 0 else 7,lower_rect,'lower%d'%index,'',-2)
 _part('head',1,_rect(metadata.head),'head','',3)
 for hidden in metadata.get('hidden_parts',[]):
  if parts.has(hidden): parts[hidden].node.visible = false
 for frame in [1,3,10,11]:
  _head_regions[frame] = _region(frame)
 # Rest transforms must be explicit for code-built skeletons.
 for bone in bones.values():
  bone.rest = bone.transform
 texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _v(value) -> Vector2:
 return Vector2(float(value[0]),float(value[1]))
func _rect(value) -> Rect2:
 return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))
func _bone(key: String, parent_key: String, point: Vector2) -> void:
 var bone = Bone2D.new()
 bone.name = key
 bone.set_autocalculate_length_and_angle(false)
 bone.length = 50.0
 var parent: Node2D = skeleton if parent_key.is_empty() else bones[parent_key]
 parent.add_child(bone)
 bone.position = point if parent_key.is_empty() else point-rest_points[parent_key]
 bones[key] = bone
 rest_points[key] = point
func _region(index: int) -> Rect2:
 var cache_key = '%s:%s:%d:%d'%[_sheet.resource_path,species_id,index,metadata.hash()]
 if _region_cache.has(cache_key): return _region_cache[cache_key]
 var cell = Vector2(_image.get_width()/4.0,_image.get_height()/3.0)
 var rect = Rect2i(int((index%4)*cell.x),int((index/4)*cell.y),int(cell.x),int(cell.y))
 if metadata.has('row_edges'):
  var edges = metadata.row_edges
  var row = index/4
  rect.position.y = int(edges[row])
  rect.size.y = int(edges[row+1])-rect.position.y
 if metadata.has('source_rects') and metadata.source_rects.has(str(index)):
  rect = Rect2i(_rect(metadata.source_rects[str(index)]))
 var bounds = Rect2i()
 var first = true
 for y in range(rect.position.y,rect.end.y):
  for x in range(rect.position.x,rect.end.x):
   if _image.get_pixel(x,y).a > 0.12:
    if first:
     bounds = Rect2i(x,y,1,1)
     first = false
    else:
     bounds = bounds.expand(Vector2i(x,y))
 var result = Rect2(bounds.grow(2).intersection(rect))
 _region_cache[cache_key] = result
 return result
func _limb_rect(index: int, far: bool) -> Rect2:
 var hip = _v(metadata.hips[index])
 var size = _v(metadata.far_size[index-2]) if far else Vector2(40,120)
 return Rect2(hip-Vector2(size.x*.5,6),size)
func _part(key: String, frame: int, destination: Rect2, primary: String, secondary: String, layer: int) -> void:
 var poly = Polygon2D.new()
 poly.name = key
 poly.texture = _sheet
 poly.z_index = layer
 add_child(poly)
 poly.skeleton = poly.get_path_to(skeleton)
 var region = _region(frame)
 var vertices = PackedVector2Array()
 var uv = PackedVector2Array()
 var weights = PackedFloat32Array()
 var secondary_weights = PackedFloat32Array()
 var triangles: Array[PackedInt32Array] = []
 const COLS = 5
 const ROWS = 8
 for y in range(ROWS+1):
  for x in range(COLS+1):
   var t = Vector2(x/float(COLS),y/float(ROWS))
   vertices.append(destination.position+t*destination.size)
   uv.append(region.position+t*region.size)
   var influence = 0.0
   if not secondary.is_empty():
    # Blend only at this part's own adjacent joint, never another limb.
    var joint_y: float = rest_points[secondary].y
    influence = smoothstep(joint_y-10.0,joint_y+12.0,vertices[-1].y)*0.65
   weights.append(1.0-influence)
   secondary_weights.append(influence)
 for y in range(ROWS):
  for x in range(COLS):
   var a = y*(COLS+1)+x
   triangles.append(PackedInt32Array([a,a+1,a+COLS+1]))
   triangles.append(PackedInt32Array([a+1,a+COLS+2,a+COLS+1]))
 poly.polygon = vertices
 poly.polygons = triangles
 poly.uv = uv
 poly.add_bone(poly.get_path_to(bones[primary]),weights)
 if not secondary.is_empty():
  poly.add_bone(poly.get_path_to(bones[secondary]),secondary_weights)
 parts[key] = {'node':poly,'destination':destination,'region':region}

func set_motion(animation: Dictionary) -> void:
 var next = str(animation.get('state','idle'))
 # Current standing torso can crouch safely but does not yet form a natural
 # seated haunch. Explicit sit/rise are available for art review; automatic
 # production sitting requires the species' seated artwork to be approved.
 _allow_sit = bool(animation.get('allow_sit',false)) and bool(metadata.get('seated_pose_approved',false))
 if species_id == 'ember':
  # Restored combat has no approach interval: authoritative impacts must not
  # be delayed by a cosmetic posture. Normal encounters rise during approach.
  if bool(animation.get('combat',false)) and next != 'locomotion':
   _sit_progress = 0.0
   sit_blend = 0.0
   _auto_sitting = false
   _allow_sit = false
  if next != 'idle': _idle_age = 0.0
  if next == 'idle' and _auto_sitting and _allow_sit: next = 'sit'
  elif next != 'sit': _auto_sitting = false
  if next == 'sit':
   _sit_target = 1.0
  else:
   _sit_target = 0.0
   if next == 'rise': next = 'idle'
   if _sit_progress > 0.0 and next != 'death':
    _posture_resume_state = next
    next = 'rise'
 if next != state:
  _previous_state = state
  state = next
  state_age = 0.0
 seed = float(animation.get('seed',seed))
 var world_speed = float(animation.get('ground_speed',15.36))
 speed = float(animation.get('ground_speed_local',world_speed))
 speed_factor = maxf(0.01,float(animation.get('speed_factor',absf(world_speed)/15.36)))
 action = float(animation.get('action',0.0))
 if state == 'rise': return # event ages start after the posture transition
 if animation.has('age'): state_age = maxf(0.0,float(animation.age))
 elif animation.has('progress') and state in ['attack','cast','hurt','appear','death']:
  state_age = clampf(float(animation.progress),0.0,1.0)*(.65 if state == 'death' else .55)
func advance(delta: float) -> void:
 clock += delta
 state_age += delta
 if species_id == 'ember':
  if state == 'idle' and _allow_sit:
   _idle_age += delta
   if _idle_age >= float(metadata.get('sit_idle_delay',4.0)):
    _auto_sitting = true
    _sit_target = 1.0
    state = 'sit'
    state_age = 0.0
  var duration = float(metadata.get('sit_duration',.70) if _sit_target > _sit_progress else metadata.get('rise_duration',.55))
  _sit_progress = move_toward(_sit_progress,_sit_target,delta/maxf(.1,duration))
  sit_blend = smoothstep(0.0,1.0,_sit_progress)
  if state == 'rise' and is_zero_approx(_sit_progress):
   state = _posture_resume_state
   state_age = 0.0
 var moving = state == 'locomotion' and is_zero_approx(_sit_progress)
 walk_blend = move_toward(walk_blend,1.0 if moving else 0.0,delta*5.0)
 var cadence: float = float(metadata.get('cadence',0.9))
 phase += delta*cadence*speed_factor*TAU
 var idle = sin(clock*1.7+seed*.37)
 var archetype: String = str(metadata.get('archetype','quadruped'))
 var body: Bone2D = bones.body
 body.position = rest_points.body + Vector2(0,idle*.7*(1.0-walk_blend)-absf(sin(phase))*1.2*walk_blend)
 body.rotation = sin(clock*1.1+seed)*.004
 if species_id == 'ember':
  body.position += Vector2(-12.0,36.0)*sit_blend
  body.rotation -= .19*sit_blend
 var attack = 0.0
 if state == 'attack':
  if state_age < .16: attack = -sin(state_age/.16*PI*.5)*.32
  elif state_age < .30: attack = lerpf(-.32,1.0,smoothstep(0.0,1.0,(state_age-.16)/.14))
  else: attack = 1.0-smoothstep(.30,.65,state_age)
 elif state == 'cast': attack = sin(clampf(state_age/.9,0.0,1.0)*PI)*.65
 body.position.x += attack*7.0
 body.rotation += attack*.035
 if state == 'hurt':
  var recoil = sin(clampf(state_age/.4,0.0,1.0)*PI)*exp(-state_age*3.0)
  body.position.x -= recoil*6.0
  body.rotation -= recoil*.035
 elif state == 'death':
  var collapse = smoothstep(0.0,.65,state_age)
  body.position.y += collapse*8.0
  body.rotation += collapse*.16
 if archetype in ['flyer','floater']: body.position.y += sin(clock*2.4+seed)*3.5-8.0
 for index in range(4):
  var foot = _v(metadata.feet[index])
  var leg_phase = fposmod(phase + [0.0,PI,PI*.85,PI*1.85][index]+seed*.017,TAU)/TAU
  # Sign follows relative ground motion; approaching actors can walk against
  # camera travel, while cadence remains a positive frequency.
  var stride = speed/maxf(.01,cadence*speed_factor)*.64
  var offset_x: float
  var lift = 0.0
  if leg_phase < .64:
   offset_x = lerpf(stride*.5,-stride*.5,leg_phase/.64)
  else:
   var swing = (leg_phase-.64)/.36
   offset_x = lerpf(-stride*.5,stride*.5,smoothstep(0.0,1.0,swing))
   lift = sin(swing*PI)*5.0
  foot += Vector2(offset_x*walk_blend,-lift*walk_blend)
  if species_id == 'ember':
   # Forefeet stay planted; folded hind feet tuck toward the haunches. These
   # are articulated poses from the same authored parts, not seated PNGs.
   if index % 2 == 1: foot.x += 24.0*sit_blend
  support_targets[index] = foot
  if archetype in ['flyer','floater','serpent'] or (archetype == 'biped' and index % 2 == 0):
   bones['upper%d'%index].rotation = sin(clock*2.2+seed+index)*.04 + attack*.18
   bones['lower%d'%index].rotation = sin(clock*2.2+seed+index+.5)*.03
  else:
   _solve_leg(index,foot)
 var head: Bone2D = bones.head
 head.rotation = idle*.008-attack*.075+.14*sit_blend
 var tail: Bone2D = bones.tail
 tail.rotation = sin(clock*2.1+seed*.6)*.028 + sin(phase)*.012*walk_blend-.12*sit_blend
 if archetype == 'flyer':
  var flap = sin(clock*5.5+seed*.37)
  tail.rotation = flap*.17
  bones.upper2.rotation = -flap*.17
  bones.lower2.rotation = flap*.045
 var blink_cycle = fposmod(clock+seed*.113,4.7)
 var head_frame = 3 if blink_cycle < .12 else 1
 if state == 'blink': head_frame = 3 if state_age < .17 else 1
 if state == 'cast': head_frame = 10
 if state == 'hurt': head_frame = 11
 _swap_head(head_frame)
 modulate.a = clampf(state_age/.4,0.0,1.0) if state == 'appear' else (1.0-clampf(state_age/.65,0.0,1.0) if state == 'death' else 1.0)
 if state == 'hurt':
  modulate = Color(1.0,1.0-.3*exp(-state_age*9),1.0-.3*exp(-state_age*9),modulate.a)
 else:
  modulate = Color(1,1,1,modulate.a)
func _solve_leg(index: int, foot: Vector2) -> void:
 var upper: Bone2D = bones['upper%d'%index]
 var lower: Bone2D = bones['lower%d'%index]
 var hip = to_local(upper.global_position)
 var rest_hip: Vector2 = rest_points['upper%d'%index]
 var rest_knee: Vector2 = rest_points['lower%d'%index]
 var rest_foot = _v(metadata.feet[index])
 var l1 = rest_hip.distance_to(rest_knee)
 var l2 = rest_knee.distance_to(rest_foot)
 var delta = foot-hip
 var distance = clampf(delta.length(),absf(l1-l2)+.1,l1+l2-.1)
 var bend = acos(clampf((l1*l1+distance*distance-l2*l2)/(2.0*l1*distance),-1,1))
 var direction = delta.angle()
 var angle = direction + bend*(1.0 if index%2 else -1.0)
 var knee = hip+Vector2.from_angle(angle)*l1
 var original_upper = (rest_knee-rest_hip).angle()
 upper.rotation = angle-original_upper-bones.body.rotation
 var lower_angle = (foot-knee).angle()-(rest_foot-rest_knee).angle()
 lower.rotation = lower_angle-upper.global_rotation
func _swap_head(frame: int) -> void:
 if frame == _head_frame: return
 _head_frame = frame
 var part: Dictionary = parts.head
 var region: Rect2 = _head_regions[frame]
 var original: Rect2 = part.region
 var poly: Polygon2D = part.node
 var uv = poly.uv
 for index in range(uv.size()):
  var normalized = (uv[index]-original.position)/original.size
  uv[index] = region.position+normalized*region.size
 poly.uv = uv
 part.region = region
func foot_positions() -> Array[Vector2]:
 var result: Array[Vector2] = []
 for index in range(4):
  var lower: Bone2D = bones['lower%d'%index]
  var local_endpoint = _v(metadata.feet[index])-rest_points['lower%d'%index]
  result.append(to_local(lower.to_global(local_endpoint)))
 return result
