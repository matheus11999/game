extends SceneTree
const Rig = preload('res://scripts/creature_rig.gd')
func _initialize(): call_deferred('run')
func run():
 var ids=[]
 for path in ['res://assets/rigs/rig-metadata.json','res://assets/rigs/rig-species.json','res://assets/rigs/rig-enemies.json']:
  var data=JSON.parse_string(FileAccess.get_file_as_string(path))
  for id in data:
   if data[id] is Dictionary: ids.append(id)
 for id in ids:
  var rig=Rig.new()
  root.add_child(rig)
  rig.configure(id,load('res://assets/rigs/%s-parts.png'%id))
  for state in ['idle','locomotion','attack','cast','hurt','appear','death','blink']:
   rig.set_motion({'state':state,'seed':float(ids.find(id)*131)})
   for i in range(60):
    rig.advance(1.0/60.0)
    for bone in rig.bones.values(): assert(is_finite(bone.rotation))
   if state=='death': assert(rig.modulate.a==0.0)
   if state=='appear': assert(rig.modulate.a==1.0)
  rig.set_motion({'state':'idle'})
  rig.set_motion({'state':'blink'})
  rig.advance(.04)
  assert(rig._head_frame==3)
  rig.set_motion({'state':'cast'})
  rig.advance(.01)
  assert(rig._head_frame==10)
  rig.set_motion({'state':'hurt'})
  rig.advance(.01)
  assert(rig._head_frame==11)
  rig.queue_free()
  await process_frame
 print('NATIVE_STATES_PASS ',ids.size(),' species,8 states,cast/hurt authored heads,appear/death alpha')
 quit()
