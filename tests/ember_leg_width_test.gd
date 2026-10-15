extends SceneTree
## Full-cycle rendered alpha regression. Paw islands must retain painted width.
class View extends Node2D:
	var rig = preload("res://scripts/creature_motion.gd").new()
	var sheet:Texture2D=preload("res://assets/animations/ember-locomotion-v2.png")
	var source:=Rect2(33,25,325,315)
	var sample_time:=0.0
	var walking:=false
	var gallery:=false
	var debug_segment:=2
	func _draw() -> void:
		rig.begin_frame()
		if gallery:
			draw_rect(Rect2(0,0,1280,800),Color("202f3b"))
			for i in range(6):
				var foot:=Vector2(205+(i%3)*405,355+int(i/3)*370)
				draw_set_transform(foot)
				draw_line(Vector2(-170,0),Vector2(170,0),Color("86ab80"),1)
				rig.paint(self,sheet,source,Rect2(-162.5,-315,325,315),"ember",float(i)/5.0/0.90,true,false,Color.WHITE,0.0,{"upright":true,"seed":0.0,"state":"locomotion","blink_enabled":false})
			draw_set_transform(Vector2.ZERO)
			return
		for leg in range(4):
			draw_set_transform(Vector2(160+leg*320,400))
			rig.paint(self,sheet,source,Rect2(-162.5,-315,325,315),"ember",sample_time,walking,false,Color.WHITE,0.0,{"upright":true,"seed":0.0,"state":"locomotion" if walking else "idle","blink_enabled":false,"debug_limb":leg,"debug_segment":debug_segment})
		draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
	root.transparent_bg=true
	call_deferred("run")

func render(view:View) -> Image:
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func widths(picture:Image) -> Array[int]:
	var result:Array[int]=[]
	for leg in range(4):
		result.append(picture.get_region(Rect2i(leg*320,0,320,500)).get_used_rect().size.x)
	return result

func run() -> void:
	var view:=View.new()
	root.add_child(view)
	var neutral:=widths(await render(view))
	var maximum:=neutral.duplicate()
	var minimum:=neutral.duplicate()
	for leg in range(4):
		assert(neutral[leg]>4,"Each isolated paw needs a measurable alpha extent")
	view.walking=true
	for step in range(72):
		view.sample_time=float(step)/72.0/0.90
		var frame:=widths(await render(view))
		var poses:Array=view.rig.ember_rigid_pose(view.sample_time,true,325,0.0)
		for leg in range(4):
			maximum[leg]=maxi(maximum[leg],frame[leg])
			minimum[leg]=mini(minimum[leg],frame[leg])
			assert(float(frame[leg])/neutral[leg]<=1.15,"Paw alpha width exceeded 15%: leg "+str(leg))
			for part in ["upper","lower","foot"]:
				var transform:Transform2D=poses[leg][part]
				assert(absf(transform.x.length()-1.0)<0.0001 and absf(transform.y.length()-1.0)<0.0001 and absf(transform.determinant()-1.0)<0.0001,"Rigid limb segment must never change width/area")
	for segment in [0,1]:
		view.debug_segment=segment
		view.walking=false
		var leg_neutral:=widths(await render(view))
		var leg_maximum:=leg_neutral.duplicate()
		view.walking=true
		for step in range(72):
			view.sample_time=float(step)/72.0/0.90
			var extent:=widths(await render(view))
			for leg in range(4):
				leg_maximum[leg]=maxi(leg_maximum[leg],extent[leg])
				assert(float(extent[leg])/maxi(leg_neutral[leg],1)<=1.15,"Leg segment alpha width exceeded 15%: segment "+str(segment)+" leg "+str(leg))
		print("EMBER SEGMENT ",segment," neutral=",leg_neutral," max=",leg_maximum)
	view.gallery=true
	var gallery:Image=await render(view)
	var path:="user://ember-rigid-leg-cycle.png"
	assert(gallery.save_png(path)==OK)
	print("EMBER LEG WIDTH PASS: 72 phases, neutral=",neutral," min=",minimum," max=",maximum,"; every segment preserves width/area; alpha paw growth <=15%. ",ProjectSettings.globalize_path(path))
	quit()
