extends SceneTree
const Rig = preload('res://scripts/creature_rig.gd')
func _initialize(): call_deferred('run')
func run():
 if DisplayServer.get_name()=='headless':
  print('NATIVE_LIMB_AREA_SKIP needs GL renderer')
  quit()
  return
 var viewport=SubViewport.new()
 viewport.size=Vector2i(512,512)
 viewport.transparent_bg=true
 root.add_child(viewport)
 var rig=Rig.new()
 viewport.add_child(rig)
 rig.position=Vector2(256,490)
 rig.configure('ember',load('res://assets/rigs/ember-parts.png'))
 rig.set_motion({'state':'locomotion','seed':0.0,'ground_speed':15.36,'ground_speed_local':15.36*360.0/132.0,'speed_factor':1.0})
 var worst=0.0
 for selected in ['upper0','lower0','upper1','lower1']:
  for name in rig.parts: rig.parts[name].node.visible = name==selected
  var smallest=999999
  var largest=0
  for phase in range(24):
   rig.phase=phase/24.0*TAU
   rig.walk_blend=1.0
   rig.advance(0.0)
   viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
   await process_frame
   await RenderingServer.frame_post_draw
   var data=viewport.get_texture().get_image().get_data()
   var area=0
   for i in range(3,data.size(),4):
    if data[i]>127: area+=1
   smallest=mini(smallest,area)
   largest=maxi(largest,area)
  var variation=float(largest)/maxf(1.0,smallest)-1.0
  worst=maxf(worst,variation)
  print('LIMB_AREA ',selected,' min=',smallest,' max=',largest,' variation=',variation)
  assert(variation<.15,'Authored limb inflated >15%')
 print('NATIVE_LIMB_AREA_PASS 24phases each, max variation ',worst)
 viewport.queue_free()
 await process_frame
 quit()
