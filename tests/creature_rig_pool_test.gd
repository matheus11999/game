extends SceneTree
const Pool = preload('res://scripts/creature_rig_pool.gd')
class Painter extends Node2D:
 var pool
 var requests: Array = []
 var results: Array = []
 func _draw():
  results.clear()
  for request in requests:
   results.append(pool.paint(self, request.key, request.id, request.rect, request.animation))

var checks = 0
var failures = 0
func check(condition: bool, label: String) -> void:
 checks += 1
 if not condition:
  push_error('POOL FAIL: '+label)
  failures += 1
func _initialize(): call_deferred('run')
func redraw(painter: Painter) -> void:
 painter.queue_redraw()
 await process_frame
 await process_frame
func request(key: String, id: String = 'ember', rect: Rect2 = Rect2(130,150,220,240), animation: Dictionary = {}) -> Dictionary:
 return {'key':key,'id':id,'rect':rect,'animation':animation}
func run():
 var painter = Painter.new()
 painter.pool = Pool.new()
 root.add_child(painter)
 var pool = painter.pool
 check(pool.available('ember'), 'fox available')
 check(not pool.available('missing'), 'missing species fallback')
 pool.begin_frame(.05, false)
 painter.requests = [request('fox-A','ember',Rect2(130,150,220,240),{'state':'locomotion','seed':14.0})]
 await redraw(painter)
 var fox = pool.actors['fox-A']
 check(fox.rendered, 'paused first frame scheduled')
 check(is_zero_approx(fox.rig.clock), 'paused creation does not advance')
 check(fox.rig.skeleton.get_bone_count()==11, 'native skeleton')
 check(fox.viewport.transparent_bg, 'transparent viewport')
 if DisplayServer.get_name() != 'headless':
  await RenderingServer.frame_post_draw
  check(fox.viewport.get_texture().get_image().get_used_rect().has_area(), 'paused first texture visible')
 pool.begin_frame(.05)
 var motion = {'state':'attack','age':.2,'seed':14.0,'ground_speed':20.0}
 painter.requests = [request('fox-A','ember',Rect2(130,150,220,240),motion),request('fox-A','ember',Rect2(130,150,220,240),motion)]
 await redraw(painter)
 check(pool.actors.size()==1, 'duplicate draws share actor')
 check(pool.actors['fox-A'].rig==fox.rig, 'stable identity')
 check(is_equal_approx(fox.rig.clock,.05), 'one advance per frame')
 check(is_equal_approx(fox.rig.state_age,.25), 'duplicate draw preserves event age')
 var bounds_array = pool._catalog.ember.get('render_bounds',[-250,-360,500,360])
 var bounds = Rect2(bounds_array[0],bounds_array[1],bounds_array[2],bounds_array[3])
 check(is_equal_approx(fox.rig.speed,20.0*bounds.size.y/240.0), 'world velocity converted to local scale')
 check(is_equal_approx(fox.rig.speed_factor,20.0/15.36), 'single speed factor')
 check(fox.rig.position.y <= fox.viewport.size.y, 'ground origin inside viewport')
 var padded_bounds = Rect2(-250,-360,500,375)
 var draw_rect = pool._draw_target(padded_bounds,Rect2(130,150,220,240))
 check(is_equal_approx(draw_rect.position.y-padded_bounds.position.y*240.0/375.0,390.0), 'padded bounds preserve ground origin')
 var flipped_rect = pool._draw_target(padded_bounds,Rect2(540,150,-220,240))
 check(flipped_rect.size.x < 0.0, 'negative width mirrors draw target')
 check(is_equal_approx(flipped_rect.position.x+absf(flipped_rect.size.x)*.5,430.0), 'mirrored center retained')
 pool.begin_frame(.05, false)
 painter.requests = [request('fox-A','ember',Rect2(130,150,220,240),{'state':'cast','age':9.0})]
 await redraw(painter)
 check(is_equal_approx(fox.rig.clock,.05), 'paused clock frozen')
 check(is_equal_approx(fox.rig.state_age,.25), 'paused external age frozen')
 check(fox.rig.state=='attack', 'paused pose retained')
 pool.begin_frame(.05)
 painter.requests = [request('fox-A','ember',Rect2(130,150,220,240),{'state':'appear','age':0.0,'external_alpha':true}),request('fox-B','ember',Rect2(540,150,-220,240),{'state':'locomotion','seed':233.0})]
 await redraw(painter)
 check(pool.actors.size()==2, 'two fox actors')
 check(is_equal_approx(fox.rig.modulate.a,1.0), 'external appearance alpha is not applied twice')
 check(pool.actors['fox-B'].rig!=fox.rig, 'independent skeletons')
 check(pool.actors['fox-B'].rig.speed<0.0, 'mirrored actor converts ground velocity into its local direction')
 check(not is_equal_approx(pool.actors['fox-B'].rig.seed,fox.rig.seed), 'independent seeds')
 pool.begin_frame(.05)
 painter.requests = [request('fox-B','ember',Rect2(540,150,-220,240),{'state':'locomotion','ground_speed':-15.36})]
 await redraw(painter)
 check(pool.actors['fox-B'].rig.speed>0.0, 'negative world speed and mirror cancel')
 check(is_equal_approx(pool.actors['fox-B'].rig.speed_factor,1.0), 'negative speed preserves cadence magnitude')
 pool.begin_frame(.05)
 painter.requests = [request('empty','ember',Rect2(0,0,0,240)),request('missing','not-present')]
 await redraw(painter)
 check(painter.results==[false,false], 'invalid paints fallback')
 check(pool.actors.size()==2, 'invalid targets allocate nothing')
 pool.begin_frame(.05)
 painter.requests = [request('fox-A','moss')]
 await redraw(painter)
 check(pool.actors['fox-A'].id=='moss', 'species replacement')
 check(not is_instance_valid(fox.viewport), 'old viewport freed')
 var replaced_viewport = pool.actors['fox-A'].viewport
 replaced_viewport.queue_free()
 await process_frame
 painter.requests = [request('fox-A','ember')]
 await redraw(painter)
 check(is_instance_valid(pool.actors['fox-A'].viewport), 'freed viewport recreated')
 painter.requests.clear()
 for i in range(121): pool.begin_frame(.016)
 await process_frame
 check(pool.actors.is_empty(), 'unused actors pruned')
 pool.begin_frame(.016)
 # Test the native mirror geometry at 1:1 pixels. Fractional downsampling
 # of the detailed face introduces direction-dependent GPU sampling noise.
 var mirror_motion = {'state':'idle','seed':17.0}
 painter.requests = [request('final-fox','ember',Rect2(200,100,200,bounds.size.y),mirror_motion),request('mirror-fox','ember',Rect2(1080,100,-200,bounds.size.y),mirror_motion)]
 await redraw(painter)
 if DisplayServer.get_name() != 'headless':
  await RenderingServer.frame_post_draw
  var capture = root.get_texture().get_image()
  capture.save_png('user://native-rig-pool.png')
  var differences = 0
  var visible = 0
  for y in range(100,100+int(bounds.size.y)+20):
   for x in range(0,600):
    var left = capture.get_pixel(x,y)
    var right = capture.get_pixel(1279-x,y)
    if maxf(left.r,maxf(left.g,left.b))>.2: visible += 1
    if absf(left.r-right.r)+absf(left.g-right.g)+absf(left.b-right.b)>.15: differences += 1
  check(visible>1000, 'both fox renders have visible area')
  check(differences<visible*.05, 'negative width renders a mirrored fox without disappearing')
 var final_viewport = pool.actors['final-fox'].viewport
 pool.dispose()
 painter.requests.clear()
 painter.queue_free()
 await process_frame
 check(pool.actors.is_empty(), 'dispose clears references')
 check(not is_instance_valid(final_viewport), 'dispose frees viewport')
 pool.dispose()
 print('NATIVE_POOL_%s %d checks, %d failures: pause, clocks, identity, scaling, pruning, disposal'%['PASS' if failures==0 else 'FAIL',checks,failures])
 quit(1 if failures else 0)
