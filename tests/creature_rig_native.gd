extends SceneTree
const Rig = preload('res://scripts/creature_rig.gd')
const Pool = preload('res://scripts/creature_rig_pool.gd')
func _initialize(): call_deferred('run')
func run():
 var configs = JSON.parse_string(FileAccess.get_file_as_string('res://assets/rigs/rig-metadata.json'))
 for path in ['res://assets/rigs/rig-species.json','res://assets/rigs/rig-enemies.json']:
  if FileAccess.file_exists(path): configs.merge(JSON.parse_string(FileAccess.get_file_as_string(path)),true)
 var ids = ['ember','moss','luna','tide','crag','cloud','thornbud']
 if '--all' in OS.get_cmdline_user_args():
  ids=[]
  for id in configs:
   if configs[id] is Dictionary: ids.append(id)
 var rigs=[]
 var index=0
 for id in ids:
  if not configs.has(id): continue
  var rig=Rig.new()
  root.add_child(rig)
  rig.position=Vector2(160+(index%4)*310,180+(index/4)*200) if ids.size()>7 else Vector2(160+(index%4)*310,365+(index/4)*380)
  rig.scale=Vector2.ONE*(.38 if ids.size()>7 else .58)
  rig.configure(id,load('res://assets/rigs/%s-parts.png'%id),configs[id])
  rig.set_motion({'state':'locomotion','seed':float(index*133)})
  rigs.append(rig)
  index+=1
 for i in range(90):
  for rig in rigs: rig.advance(1.0/60.0)
  await process_frame
 if DisplayServer.get_name() != 'headless':
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png('user://native-rig-gallery.png')
  print('RIG_CAPTURE ',OS.get_user_data_dir()+'/native-rig-gallery.png')
 for rig in rigs:
  assert(rig.skeleton.get_bone_count()==11)
  for bone in rig.bones.values(): assert(is_finite(bone.rotation))
 print('NATIVE_RIG_PASS ',rigs.size(),' species, 90 frames, 11 native bones each')
 quit()
