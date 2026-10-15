class_name TaskMonCreatureRigPool
extends RefCounted
const Rig = preload('res://scripts/creature_rig.gd')
var actors: Dictionary = {}
var tick = 0
var delta = 1.0/60.0
var _catalog: Dictionary = {}
func _init() -> void:
 for path in ['res://assets/rigs/rig-metadata.json','res://assets/rigs/rig-species.json','res://assets/rigs/rig-enemies.json']:
  if FileAccess.file_exists(path):
   var data = JSON.parse_string(FileAccess.get_file_as_string(path))
   if data is Dictionary: _catalog.merge(data,true)
func begin_frame(frame_delta: float = 1.0/60.0, enabled: bool = true) -> void:
 tick += 1
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
func paint(owner: CanvasItem, actor_key: String, id: String, target: Rect2, animation: Dictionary, tint: Color = Color.WHITE) -> bool:
 if not available(id): return false
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
  actors[actor_key] = {'viewport':viewport,'rig':rig,'used':tick,'advanced':-1,'id':id}
 var item: Dictionary = actors[actor_key]
 var local_animation = animation.duplicate()
 var world_velocity = absf(float(animation.get('ground_speed',15.36)))
 local_animation.ground_speed_local = world_velocity*bounds.size.y/maxf(1.0,absf(target.size.y))
 local_animation.speed_factor = float(animation.get('speed_factor',world_velocity/15.36))
 item.used = tick
 item.rig.set_motion(local_animation)
 if int(item.advanced) != tick:
  item.rig.advance(delta)
  item.advanced = tick
 item.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if delta>0.0 else SubViewport.UPDATE_DISABLED
 # Crop emptiness using the per-actor origin; larger wings retain their margins.
 var source = Rect2(item.rig.position+bounds.position,bounds.size)
 var width = target.size.y*bounds.size.x/bounds.size.y*signf(target.size.x)
 var draw_target = Rect2(Vector2(target.position.x+target.size.x*.5-width*.5,target.end.y-target.size.y),Vector2(width,target.size.y))
 owner.draw_texture_rect_region(item.viewport.get_texture(),draw_target,source,tint)
 return true
func dispose() -> void:
 for item in actors.values():
  if is_instance_valid(item.viewport): item.viewport.queue_free()
 actors.clear()
