class_name TaskMonCreatureRigPool
extends RefCounted
const Rig = preload('res://scripts/creature_rig.gd')
var actors: Dictionary = {}
var tick = 0
var delta = 1.0/60.0
var _catalog: Dictionary = {}
var _enabled = true
func _init() -> void:
 for path in ['res://assets/rigs/rig-metadata.json','res://assets/rigs/rig-species.json','res://assets/rigs/rig-enemies.json']:
  if FileAccess.file_exists(path):
   var data = JSON.parse_string(FileAccess.get_file_as_string(path))
   if data is Dictionary: _catalog.merge(data,true)
func begin_frame(frame_delta: float = 1.0/60.0, enabled: bool = true) -> void:
 tick += 1
 _enabled = enabled
 delta = clampf(frame_delta,0.0,.1) if enabled else 0.0
 for key in actors.keys():
  var item: Dictionary = actors[key]
  if not is_instance_valid(item.viewport):
   actors.erase(key)
  elif tick-int(item.used)>120:
   item.viewport.queue_free()
   actors.erase(key)
  else:
   item.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
func available(id: String) -> bool:
 return _catalog.has(id) and ResourceLoader.exists('res://assets/rigs/%s-parts.png'%id)
func source_faces_left(id: String) -> bool:
 return bool(_catalog.get(id,{}).get('faces_left',false))
func paint(owner: CanvasItem, actor_key: String, id: String, target: Rect2, animation: Dictionary, tint: Color = Color.WHITE) -> bool:
 if not available(id) or absf(target.size.x) < .001 or absf(target.size.y) < .001: return false
 if actors.has(actor_key) and not is_instance_valid(actors[actor_key].viewport):
  actors.erase(actor_key)
 var config: Dictionary = _catalog[id]
 var bounds = Rect2(-250,-360,500,360)
 if config.has('render_bounds'):
  var b = config.render_bounds
  bounds = Rect2(float(b[0]),float(b[1]),float(b[2]),float(b[3]))
 if actors.has(actor_key) and str(actors[actor_key].id) != id:
  actors[actor_key].viewport.queue_free()
  actors.erase(actor_key)
 if not actors.has(actor_key):
  var viewport = SubViewport.new()
  viewport.name = 'Rig_'+actor_key.validate_node_name()
  viewport.size = Vector2i(maxi(512,int(ceil(maxf(absf(bounds.position.x),absf(bounds.end.x))*2.0+24))),maxi(512,int(ceil(bounds.size.y+48))))
  viewport.transparent_bg = true
  viewport.disable_3d = true
  viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
  owner.add_child(viewport)
  var rig = Rig.new()
  viewport.add_child(rig)
  rig.position = Vector2(viewport.size.x*.5,viewport.size.y-24-maxf(0.0,bounds.end.y))
  rig.configure(id,load('res://assets/rigs/%s-parts.png'%id),_catalog[id])
  actors[actor_key] = {'viewport':viewport,'rig':rig,'used':tick,'advanced':-1,'id':id,'rendered':false}
 var item: Dictionary = actors[actor_key]
 var local_animation = animation.duplicate()
 var world_velocity = float(animation.get('ground_speed',15.36))
 local_animation.ground_speed_local = world_velocity*bounds.size.y/maxf(1.0,absf(target.size.y))*signf(target.size.x)
 local_animation.speed_factor = float(animation.get('speed_factor',absf(world_velocity)/15.36))
 item.used = tick
 # A redraw can paint the same actor more than once. Apply externally supplied
 # ages only once too, otherwise the second draw rewinds the first advance.
 if int(item.advanced) != tick and (_enabled or not item.rendered):
  item.rig.set_motion(local_animation)
  item.rig.advance(delta)
  if bool(animation.get('external_alpha',false)): item.rig.modulate.a = 1.0
  item.advanced = tick
 # New actors need one render even when paused; otherwise their texture stays
 # transparent until animation resumes. Existing actors retain their last pose.
 if _enabled or not item.rendered:
  item.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
  item.rendered = true
 # Crop emptiness using the per-actor origin; larger wings retain their margins.
 var source = Rect2(item.rig.position+bounds.position,bounds.size)
 var draw_target = _draw_target(bounds,target)
 owner.draw_texture_rect_region(item.viewport.get_texture(),draw_target,source,tint)
 return true
func _draw_target(bounds: Rect2, target: Rect2) -> Rect2:
 var scale_factor = target.size.y/bounds.size.y
 var width = bounds.size.x*scale_factor*signf(target.size.x)
 # Godot flips a negative-width texture at its left edge; it does not move
 # that edge to rect.end.x. Center using the absolute width in both directions.
 # render_bounds may include padding below local y=0. Keep the rig's ground
 # origin on target.end.y instead of aligning the bottom of that padding.
 return Rect2(Vector2(target.position.x+target.size.x*.5-absf(width)*.5,target.position.y+bounds.end.y*scale_factor),Vector2(width,target.size.y))
func dispose() -> void:
 for item in actors.values():
  if is_instance_valid(item.viewport): item.viewport.queue_free()
 actors.clear()
