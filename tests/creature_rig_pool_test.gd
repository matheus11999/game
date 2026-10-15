extends SceneTree
const Pool=preload('res://scripts/creature_rig_pool.gd')
class Painter extends Node2D:
 var pool
 var frame=0
 func _process(delta):
  frame+=1
  pool.begin_frame(delta,true)
  queue_redraw()
 func _draw():
  pool.paint(self,'fox-A','ember',Rect2(130,150,220,240),{'state':'locomotion','seed':14.0})
  pool.paint(self,'fox-B','ember',Rect2(540,150,-220,240),{'state':'idle','seed':233.0})
func _initialize(): call_deferred('run')
func run():
 var painter=Painter.new()
 painter.pool=Pool.new()
 root.add_child(painter)
 for i in range(40): await process_frame
 assert(painter.pool.actors.size()==2)
 for entry in painter.pool.actors.values():
  assert(entry.rig.skeleton.get_bone_count()==11)
  assert(entry.viewport.transparent_bg)
 if DisplayServer.get_name()!='headless':
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png('user://native-rig-pool.png')
 print('NATIVE_POOL_PASS 2 actors, unique rigs, transparent viewports')
 painter.set_process(false)
 painter.pool.dispose()
 await process_frame
 painter.queue_free()
 await process_frame
 quit()
