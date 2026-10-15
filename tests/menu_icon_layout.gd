extends SceneTree
class IconClient extends "res://scripts/main.gd":
 func _api(_path: String,_data: Dictionary,_context: String) -> void:
  pass
 func _save_settings() -> void:
  pass
var game: Control
var failures=0
var checks=0
func _initialize(): call_deferred("run")
func check(value: bool,message: String):
 checks+=1
 if not value:
  failures+=1
  push_error(message)
func run():
 game=IconClient.new()
 root.add_child(game)
 game.set_process(false)
 game.token=""
 for child in game.ui.get_children(): child.queue_free()
 await process_frame
 var index=0
 for id in game.icons:
  for side in [28,36,44]:
   var x=32+index%8*152
   var y=80+index/8*190+(side-28)*4
   var button=game._button("",Rect2(x,y,side,side),func():pass,false,id,id)
   button.name=id+str(side)
   check(button.icon_alignment==HORIZONTAL_ALIGNMENT_CENTER and button.vertical_icon_alignment==VERTICAL_ALIGNMENT_CENTER,"centralizado "+button.name)
   for state in ["normal","hover","pressed","disabled","focus"]:
    var skin=button.get_theme_stylebox(state)
    var inner=button.size-Vector2(skin.get_content_margin(SIDE_LEFT)+skin.get_content_margin(SIDE_RIGHT),skin.get_content_margin(SIDE_TOP)+skin.get_content_margin(SIDE_BOTTOM))
    check(inner.x>=button.get_theme_constant("icon_max_width") and inner.y>=button.get_theme_constant("icon_max_width"),"espaÃ§o seguro "+button.name+" "+state)
  index+=1
 await create_timer(0.1).timeout
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.godot/menu-icon-layout.png")
 var dialog=game._dialog("Ícones · teste de margens",Vector2i(480,230))
 var box=game._content(dialog)
 var text_button=game._modal_button("Aprimorar",box,func():pass,true,"upgrade")
 var icon_button=game._modal_button("",box,func():pass,false,"bag")
 dialog.popup_centered()
 await process_frame
 await process_frame
 var close: Button=dialog.get_meta("chrome_root").get_node("CloseMenu")
 check(close.size==Vector2(36,36),"fechar preserva alvo36px")
 for button in [close,text_button,icon_button]:
  for state in ["normal","hover","pressed","disabled","focus"]:
   var skin=button.get_theme_stylebox(state)
   var inset=Vector2(skin.get_content_margin(SIDE_LEFT)+skin.get_content_margin(SIDE_RIGHT),skin.get_content_margin(SIDE_TOP)+skin.get_content_margin(SIDE_BOTTOM))
   check(button.size.y-inset.y>=button.get_theme_constant("icon_max_width"),"modal sem corte vertical: "+button.name+" "+state)
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.godot/menu-icon-dialog.png")
 print("Menu icon layout: ",checks," checks, ",failures," failures")
 game.queue_free()
 await process_frame
 quit(1 if failures else 0)
