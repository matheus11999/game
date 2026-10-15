extends SceneTree
## Native production renderer + disposable QA account. Never loads/saves a session.
class QaClient extends "res://scripts/main.gd":
 func _session_section() -> String: return 'isolated_native_rig_qa_no_saved_session'
 func _save_settings() -> void: pass
 func _api(path:String,data:Dictionary,context:String) -> void:
  server_url='http://127.0.0.1:18787'
  super._api(path,data,context)
var game: Control
var failures=0
var key=''
var directory=''
func _initialize(): call_deferred('_run')
func check(condition:bool,label:String):
 if condition: print('PASS ',label)
 else:
  failures+=1
  push_error('FAIL '+label)
func wait_request():
 var deadline=Time.get_ticks_msec()+20000
 while (game.busy or not game.pending_requests.is_empty() or game.elapsed<game.animation_until or game._presentation_locked()) and Time.get_ticks_msec()<deadline:
  await create_timer(.05).timeout
 check(not game.busy and game.pending_requests.is_empty(),'QA request completed')
func frames(count=3,delta=1.0/60.0):
 for i in range(count):
  game._process(delta)
  game.queue_redraw()
  await process_frame
  if DisplayServer.get_name()!='headless': await RenderingServer.frame_post_draw
func capture(label:String):
 if DisplayServer.get_name()=='headless': return
 await frames()
 check(root.get_texture().get_image().save_png(directory.path_join(label+'.png'))==OK,'capture '+label)
func _run():
 directory=OS.get_environment('BRUMORA_CAPTURE_DIR')
 if directory.is_empty(): directory=ProjectSettings.globalize_path('user://rig-integration')
 DirAccess.make_dir_recursive_absolute(directory)
 game=QaClient.new()
 root.add_child(game)
 await wait_request()
 check(game.connected,'QA API18787 connected')
 if not game.connected:
  quit(1)
  return
 game._register('ember','QA Rig '+str(Time.get_ticks_msec()))
 await wait_request()
 if game.player.is_empty():
  check(false,'isolated registration')
  quit(1)
  return
 var id=str(game.player.team[0])
 key='world:'+id
 game._action('route',{'region':0})
 game.route_auto=false
 game.auto_battle=false
 game.compact_auto=false
 await wait_request()
 game.set_process(false)
 await frames(6)
 check(game.native_rigs_enabled and game.creature_rigs.actors.has(key),'production world actor uses native rig')
 if not game.creature_rigs.actors.has(key):
  quit(1)
  return
 var rig=game.creature_rigs.actors[key].rig
 var instance=rig.get_instance_id()
 check(rig.skeleton is Skeleton2D and rig.skeleton.get_bone_count()==11,'real production Skeleton2D11bones')
 for multiplier in [.5,1.0,2.0]:
  game.world_speed_multiplier=multiplier
  await frames(6)
  check(is_equal_approx(rig.speed_factor,multiplier),'speed factor applied once '+str(multiplier))
  var extent=lerpf(4.05,4.6,smoothstep(0.0,1.0,game.battle_blend))*32.0
  var bounds_height=float(rig.metadata.get('render_bounds',[-250,-360,500,360])[3])
  var expected=game.travel_speed*multiplier*.64*bounds_height/extent
  check(absf(rig.speed-expected)<.001,'local ground speed converted once '+str(multiplier))
  var phase=rig.phase
  await frames(1)
  check(absf(rig.phase-phase-TAU*.9*multiplier/60.0)<.0001,'0.90Hz cadence scales once '+str(multiplier))
 game.world_speed_multiplier=1.0
 for i in range(6):
  await frames(8)
  await capture('walk-%02d'%i)
 game._inventory_dialog()
 await frames(70)
 check(rig.state=='idle' and rig.walk_blend<.001,'menu stops locomotion; idle breathing remains active')
 var idle_clock=rig.clock
 await frames(3)
 check(rig.clock>idle_clock,'idle remains animated')
 game.modal.hide()
 game.modal.queue_free()
 game.hide()
 var paused_clock=rig.clock
 await frames(4)
 check(is_equal_approx(rig.clock,paused_clock),'hidden production control freezes pooled clock')
 game.show()
 await frames(3)
 check(rig.clock>paused_clock,'visible production control resumes rig')
 var original_mode=root.mode
 root.mode=Window.MODE_MINIMIZED
 await create_timer(.1).timeout
 if root.mode==Window.MODE_MINIMIZED:
  var minimized_clock=rig.clock
  for i in range(4):
   game._process(1.0/60.0)
   game.queue_redraw()
   await process_frame
  check(is_equal_approx(rig.clock,minimized_clock),'minimized window freezes pooled clock')
 else: print('SKIP minimization: window system did not enter minimized mode')
 root.mode=original_mode
 await frames(3)
 game.set_process(true)
 game._action('battle',{'kind':'wild'})
 await wait_request()
 game.set_process(false)
 await frames(4)
 check(game.player.battle!=null,'real QA battle started')
 check(game.creature_rigs.actors[key].rig.get_instance_id()==instance,'world actor identity persists into combat')
 await capture('battle')
 game._toggle_compact()
 await frames(4)
 check(game.creature_rigs.actors[key].rig.get_instance_id()==instance,'world actor identity persists in compact mode')
 await capture('battle-compact')
 game._toggle_compact()
 var birth_backup=game.unit_birth.duplicate()
 var death_backup=game.unit_death.duplicate()
 game.combat_sequence.clear()
 game.unit_birth[id]=game.elapsed-.15
 await frames(1)
 check(rig.state=='appear','production fighter routes appearance state')
 game.unit_birth[id]=game.elapsed-5.0
 var opponent=game.player.battle.enemies[0]
 for state in ['cast','hurt']:
  game.combat_sequence=[{'actor':id if state=='cast' else opponent.id,'target':id,'species':'ember' if state=='cast' else opponent.species,'kind':'guard' if state=='cast' else 'attack','skill':state=='cast','started':game.elapsed-(.2 if state=='cast' else .95),'value':0,'applied':true,'sounded':true}]
  await frames(1)
  check(rig.state==state,'production fighter routes '+state+' state')
  await capture('state-'+state)
 game.combat_sequence.clear()
 game.unit_death[id]=game.elapsed-.2
 await frames(1)
 check(rig.state=='death','production fighter routes death state')
 await capture('state-death')
 game.unit_birth=birth_backup
 game.unit_death=death_backup
 check(game.native_rig_fallbacks.is_empty(),'zero static native-rig fallbacks')
 print('RIG_PRODUCTION_INTEGRATION failures=',failures,' captures=',directory)
 game.queue_free()
 await process_frame
 quit(1 if failures else 0)
