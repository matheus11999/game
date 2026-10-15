extends SceneTree
const Rig = preload('res://scripts/creature_rig.gd')
var checks = 0
var failures = 0
var rig
func check(condition: bool, label: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error('POSTURE FAIL: '+label)
func _initialize(): call_deferred('run')
func step(seconds: float) -> void:
 for i in range(int(round(seconds*120.0))): rig.advance(1.0/120.0)
func supports(label: String) -> void:
 var feet = rig.foot_positions()
 for i in range(4):
  check(feet[i].distance_to(rig.support_targets[i])<.2,label+' foot %d support'%i)
func capture(label: String) -> void:
 if DisplayServer.get_name() == 'headless': return
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png('user://fox-posture-'+label+'.png')
func run():
 rig = Rig.new()
 root.add_child(rig)
 rig.position = Vector2(640,650)
 rig.scale = Vector2(1.5,1.5)
 rig.configure('ember',load('res://assets/rigs/ember-parts.png'))
 rig.set_motion({'state':'idle','seed':14.0})
 rig.advance(0.0)
 var standing_body: Vector2 = rig.bones.body.position
 check(is_zero_approx(rig.sit_blend),'starts standing')
 rig.set_motion({'state':'sit','seed':14.0})
 step(.8)
 check(is_equal_approx(rig.sit_blend,1.0),'explicit sit completes')
 check(rig.bones.body.position.y>standing_body.y+30.0,'haunches lower visibly')
 check(is_zero_approx(rig.walk_blend),'seated gait stopped')
 supports('sitting')
 await capture('sit')
 rig.set_motion({'state':'locomotion','ground_speed':30.0})
 check(rig.state=='rise','locomotion first requests rise')
 step(.275)
 check(rig.sit_blend>.25 and rig.sit_blend<.75,'half rise has intermediate pose')
 check(is_zero_approx(rig.walk_blend),'half rise cannot walk')
 supports('half-rise')
 await capture('half-rise')
 # Repeated renderer commands must not restart the transition.
 for i in range(36):
  rig.set_motion({'state':'locomotion','ground_speed':30.0})
  rig.advance(1.0/120.0)
 check(is_zero_approx(rig.sit_blend),'repeated locomotion finishes rising')
 check(rig.state=='locomotion','movement resumes after fully standing')
 await capture('stand')
 step(.4)
 check(rig.walk_blend>.95,'standing resumes full walking')
 supports('walking')
 await capture('walk')
 rig.set_motion({'state':'idle'})
 step(5.0)
 check(is_zero_approx(rig.sit_blend),'ordinary idle never automatically sits')
 rig.set_motion({'state':'idle','allow_sit':true})
 step(4.8)
 check(is_zero_approx(rig.sit_blend),'unapproved seated art cannot auto-sit in production')
 # The following checks exercise the opt-in contract using isolated fixture
 # metadata, without claiming that the current art is visually approved.
 rig.metadata = rig.metadata.duplicate(true)
 rig.metadata.seated_pose_approved = true
 rig.set_motion({'state':'idle','allow_sit':true})
 step(4.8)
 check(rig.sit_blend>.99,'opt-in idle settles into sit')
 rig.set_motion({'state':'idle','allow_sit':false})
 check(rig.state=='rise','leaving safe idle rises')
 step(.6)
 check(rig.state=='idle' and is_zero_approx(rig.sit_blend),'returns to standing idle')
 rig.set_motion({'state':'sit'})
 step(.8)
 rig.set_motion({'state':'attack'})
 check(rig.state=='rise','ordinary attack rises first')
 step(.6)
 check(rig.state=='attack' and rig.state_age<.1,'attack age begins after rise')
 rig.set_motion({'state':'sit'})
 step(.8)
 rig.set_motion({'state':'attack','combat':true,'age':.27})
 rig.advance(0.0)
 check(rig.state=='attack' and is_zero_approx(rig.sit_blend),'restored combat immediately stands')
 check(is_equal_approx(rig.state_age,.27),'restored impact age preserved')
 print('FOX_POSTURE_%s %d checks, %d failures'%['PASS' if failures==0 else 'FAIL',checks,failures])
 rig.queue_free()
 await process_frame
 quit(1 if failures else 0)
