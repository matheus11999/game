extends SceneTree
const Rig = preload('res://scripts/creature_rig.gd')
func _initialize(): call_deferred('run')
func run():
 var worst_drift = 0.0
 var worst_ratio = 0.0
 for height in [132.0,240.0]:
  for multiplier in [.5,1.0,2.0]:
   var rig=Rig.new()
   root.add_child(rig)
   rig.configure('ember',load('res://assets/rigs/ember-parts.png'))
   var scale_factor=height/360.0
   rig.set_motion({'state':'locomotion','seed':0,'ground_speed':15.36*multiplier,'ground_speed_local':15.36*multiplier/scale_factor,'speed_factor':multiplier})
   rig.walk_blend=1.0
   var previous=[]
   var previous_targets=[]
   var error_sum=0.0
   var expected_sum=0.0
   for i in range(480):
    rig.advance(1.0/240.0)
    var actual=rig.foot_positions()
    for leg in range(4):
     var target: Vector2 = rig.support_targets[leg]
     worst_drift=maxf(worst_drift,actual[leg].distance_to(target)*scale_factor)
     assert(absf(rig.bones['lower%d'%leg].transform.determinant()-1.0)<.001)
     if previous.size()==4 and target.y==float(rig.metadata.feet[leg][1]) and previous_targets[leg].y==target.y and target.x<previous_targets[leg].x:
      var expected=15.36*multiplier/240.0
      var traveled=(previous[leg].x-actual[leg].x)*scale_factor
      error_sum+=absf(traveled-expected)
      expected_sum+=expected
    previous=actual
    previous_targets=[]
    for leg in range(4): previous_targets.append(rig.support_targets[leg])
   var ratio=error_sum/maxf(.001,expected_sum)
   worst_ratio=maxf(worst_ratio,ratio)
   print('WORLD_CONTACT height=',height,' speed=',multiplier,' relative_error=',ratio)
   assert(ratio<.12,'Stance-world displacement differs by >12%')
   rig.queue_free()
   await process_frame
 print('NATIVE_KINEMATICS_PASS world heights132/240 speed0.5/1/2; max support drift %.3fpx; max stance movement error %.2f%%'%[worst_drift,worst_ratio*100.0])
 quit()
