extends SceneTree
## Fox regression: signed stance displacement plus painted far-foot contact.
## Run with real GL for the alpha checks; --headless verifies kinematics only.
const Rig = preload('res://scripts/creature_rig.gd')
func _initialize(): call_deferred('run')
func run():
 var rig = Rig.new()
 root.add_child(rig)
 rig.configure('ember',load('res://assets/rigs/ember-parts.png'))
 assert(is_equal_approx(float(rig.metadata.cadence),.9))
 var bounds_height=float(rig.metadata.get('render_bounds',[-250,-360,500,360])[3])
 var max_error = 0.0
 for direction in [-1.0,1.0]:
  for multiplier in [.5,1.0,2.0]:
   rig.phase=0.0
   rig.walk_blend=1.0
   var velocity=15.36*direction*multiplier
   rig.set_motion({'state':'locomotion','seed':0,'ground_speed':velocity,'ground_speed_local':velocity*bounds_height/132.0,'speed_factor':multiplier})
   var previous=[]
   var previous_targets=[]
   var error_sum=0.0
   var expected_sum=0.0
   for frame in range(480):
    rig.advance(1.0/240.0)
    var positions=rig.foot_positions()
    for leg in range(4):
     var target: Vector2=rig.support_targets[leg]
     var ground_y=float(rig.metadata.feet[leg][1])
     if previous.size()==4 and is_equal_approx(target.y,ground_y) and is_equal_approx(previous_targets[leg].y,ground_y) and (previous_targets[leg].x-target.x)*direction>0.0:
      var displacement=(previous[leg].x-positions[leg].x)*132.0/bounds_height
      var expected=velocity/240.0
      error_sum+=absf(displacement-expected)
      expected_sum+=absf(expected)
    previous=positions
    previous_targets=[]
    for leg in range(4): previous_targets.append(rig.support_targets[leg])
   var error=error_sum/maxf(.001,expected_sum)
   max_error=maxf(max_error,error)
   assert(expected_sum>1.0,'No support samples for signed direction')
   assert(error<.02,'Signed stance displacement deviated >2%')
 print('FOX_SIGNED_STANCE_PASS max_relative_error=',max_error)
 rig.queue_free()
 await process_frame
 if DisplayServer.get_name()=='headless':
  print('FOX_PAINTED_CONTACT_SKIP requires real renderer')
  quit()
  return
 var viewport=SubViewport.new()
 viewport.size=Vector2i(600,600)
 viewport.transparent_bg=true
 root.add_child(viewport)
 rig=Rig.new()
 viewport.add_child(rig)
 rig.position=Vector2(300,570)
 rig.configure('ember',load('res://assets/rigs/ember-parts.png'))
 rig.walk_blend=1.0
 rig.set_motion({'state':'locomotion','seed':0,'ground_speed_local':15.36*bounds_height/132.0})
 var worst_gap=0.0
 for name in ['far_front','far_rear']:
  var leg=2 if name=='far_front' else 3
  for key in rig.parts: rig.parts[key].node.visible=key==name
  for frame in range(24):
   rig.phase=float(frame)/24.0*TAU
   rig.advance(0.0)
   viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
   await process_frame
   await RenderingServer.frame_post_draw
   var picture=viewport.get_texture().get_image()
   var bottom=-1
   for y in range(530,590):
    for x in range(170,430):
     if picture.get_pixel(x,y).a>.5: bottom=maxi(bottom,y)
   assert(bottom>=0,'Painted foot missing from capture')
   var gap=absf(float(bottom)-(570.0+rig.support_targets[leg].y))*132.0/bounds_height
   worst_gap=maxf(worst_gap,gap)
   assert(gap<1.8,'Far painted foot detached >1.8px at132px draw height')
 print('FOX_PAINTED_CONTACT_PASS 24phases each; max_gap_at132px=',worst_gap)
 viewport.queue_free()
 await process_frame
 quit()
