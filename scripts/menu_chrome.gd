extends RefCounted
## Shared hand-composed surfaces for every game menu. No gameplay authority.
const INK = Color("edf2ed")
const MUTED = Color("9cabb6")
const GOLD = Color("e4c68c")
const MINT = Color("91d8bd")
const LILAC = Color("cab5e9")
const RED = Color("e59b98")
var _ui_art: Dictionary = {}

class GearBadge extends Control:
	var display_font: Font
	var score: int
	var art: Texture2D=load("res://assets/ui/gear-leaf.svg")
	func _ready() -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_texture_rect(art,Rect2(0,0,164,54),false)
		if display_font!=null:
			draw_string(display_font,Vector2(59,17),"GEAR SCORE",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("b0bb98"))
			draw_string(display_font,Vector2(59,39),str(score),HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("f0d795"))

class MenuBackdrop extends Control:
	var illustration: Texture2D
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		resized.connect(queue_redraw)
	func _draw() -> void:
		draw_style_box(_surface(Color("0b1b22"), Color("879074"), 12), Rect2(Vector2.ZERO, size))
		if illustration != null and size.x > 0:
			var source_size = illustration.get_size()
			var height = minf(source_size.y, source_size.x * size.y / size.x)
			draw_texture_rect_region(illustration, Rect2(2, 58, size.x-4, size.y-60), Rect2(0, (source_size.y-height)*0.5, source_size.x, height), Color(0.30, 0.36, 0.44, 0.22))
		# Four restrained horizontal values imitate dark lacquer, without noise.
		for band in range(4):
			var y = 58.0 + (size.y-60) * float(band) / 4.0
			draw_rect(Rect2(2,y,size.x-4,(size.y-60)/4.0),Color(0.02,0.04,0.065,0.12+band*0.045))
		draw_line(Vector2(20,57),Vector2(size.x-20,57),Color("8b805f",0.5),1,true)
		draw_line(Vector2(20,58),Vector2(size.x-20,58),Color(0,0,0,0.6),1,true)
		_foliage(self,Vector2(15,12),Vector2(1,1),0.7)
		_foliage(self,Vector2(15,size.y-13),Vector2(1,-1),0.45)
		_foliage(self,Vector2(size.x-15,size.y-13),Vector2(-1,-1),0.45)
	static func _foliage(c: CanvasItem, origin: Vector2, mirror: Vector2, opacity: float) -> void:
		var branch=PackedVector2Array()
		for point in [Vector2.ZERO,Vector2(8,8),Vector2(14,20),Vector2(17,34)]:
			branch.append(origin+point*mirror)
		c.draw_polyline(branch,Color("c0b883",opacity),1,true)
		for i in range(3):
			var stem=Vector2(5+i*5,6+i*9)
			var side=1.0 if i%2==0 else -1.0
			var leaf=PackedVector2Array()
			for point in [Vector2.ZERO,Vector2(side*3,-5),Vector2(side*10,-8),Vector2(side*10,-2),Vector2(side*5,2)]:
				leaf.append(origin+(stem+point)*mirror)
			c.draw_colored_polygon(leaf,Color("8ca788",opacity*0.72))
			c.draw_polyline(PackedVector2Array([leaf[0],leaf[2]]),Color("e0c890",opacity*0.65),1,true)
	static func _surface(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
		var result=StyleBoxFlat.new()
		result.bg_color=fill
		result.border_color=border
		result.set_border_width_all(1)
		result.set_corner_radius_all(radius)
		return result

func _surface(fill: Color, border: Color = Color.TRANSPARENT, radius: int = 8) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color=fill
	style.border_color=border
	style.set_border_width_all(1 if border.a>0 else 0)
	style.set_corner_radius_all(radius)
	style.content_margin_left=12
	style.content_margin_right=12
	style.content_margin_top=10
	style.content_margin_bottom=10
	return style

func decorate_dialog(dialog: AcceptDialog, title: String, font: Font, title_font: Font, close_icon: Texture2D, illustration: Texture2D = null) -> void:
	dialog.borderless=true
	dialog.title=""
	dialog.get_ok_button().hide()
	var empty_panel = StyleBoxEmpty.new()
	dialog.add_theme_stylebox_override("panel",empty_panel)
	var chrome_root = Control.new()
	chrome_root.name = "MenuChrome"
	chrome_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.add_child(chrome_root)
	dialog.set_meta("chrome_root",chrome_root)
	var backdrop=MenuBackdrop.new()
	backdrop.illustration=illustration
	chrome_root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrome_root.move_child(backdrop,0)
	var header=Label.new()
	header.text=title
	header.add_theme_font_override("font",title_font)
	header.add_theme_font_size_override("font_size",21)
	header.add_theme_color_override("font_color",GOLD)
	header.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	header.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	header.mouse_filter=Control.MOUSE_FILTER_IGNORE
	header.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	chrome_root.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left=58
	header.offset_right=-58
	header.offset_top=5
	header.offset_bottom=54
	var close=Button.new()
	close.name="CloseMenu"
	close.icon=close_icon
	close.tooltip_text="Fechar · Esc"
	close.alignment=HORIZONTAL_ALIGNMENT_CENTER
	close.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	close.vertical_icon_alignment=VERTICAL_ALIGNMENT_CENTER
	close.expand_icon=true
	close.clip_contents=false
	close.add_theme_constant_override("align_to_largest_stylebox",0)
	close.add_theme_constant_override("icon_max_width",26)
	close.add_theme_constant_override("h_separation",0)
	close.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	close.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus"]:
		var fill=Color("253943") if state=="hover" else Color("152831") if state=="pressed" else Color(0,0,0,0)
		var close_style = _surface(fill,Color(GOLD,0.45) if state in ["hover","focus"] else Color.TRANSPARENT,8)
		for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
			close_style.set_content_margin(side,5)
		close.add_theme_stylebox_override(state,close_style)
	close.pressed.connect(func(): dialog.hide(); dialog.queue_free())
	chrome_root.add_child(close)
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left=-48
	close.offset_right=-12
	close.offset_top=10
	close.offset_bottom=46

func content(dialog: AcceptDialog) -> VBoxContainer:
	var margin=MarginContainer.new()
	var root: Control=dialog.get_meta("chrome_root") if dialog.has_meta("chrome_root") else dialog
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_left=22
	margin.offset_right=-22
	margin.offset_top=72
	margin.offset_bottom=-20
	var scroll=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var box=VBoxContainer.new()
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",12)
	scroll.add_child(box)
	return box

func _text(game: Control, text: String, parent: Node, px: int=14, tint: Color=INK, centered: bool=false) -> Label:
	var label=game._label(text,parent,px,tint)
	if centered:
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	return label

func _row(parent: Node, centered: bool=false, gap: int=8) -> HBoxContainer:
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",gap)
	if centered:
		row.alignment=BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	return row

func _icon(game: Control, icon: String, parent: Node, side: float=20, tint: Color=GOLD, tip: String="") -> TextureRect:
	var texture=game.icons.get(icon)
	if texture==null and ResourceLoader.exists("res://assets/icons/"+icon+".svg"):
		texture=load("res://assets/icons/"+icon+".svg")
	var image=game._image_control(texture,Vector2(side,side),parent)
	image.modulate=tint
	image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	image.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	if not tip.is_empty():
		image.mouse_filter=Control.MOUSE_FILTER_STOP
		image.tooltip_text=tip
	return image

func _group(parent: Node, tint: Color=Color("45565b")) -> VBoxContainer:
	var panel=PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",_surface(Color(0.035,0.075,0.105,0.94),tint))
	parent.add_child(panel)
	var box=VBoxContainer.new()
	box.add_theme_constant_override("separation",6)
	panel.add_child(box)
	return box

func build_creature_card(game: Control, id: String) -> void:
	var creature: Dictionary=game._creature(id)
	if creature.is_empty():
		return
	var spec: Dictionary=game.by_id[creature.species]
	var tint=Color(spec.color)
	var rank=int(creature.get("upgrade",0))
	game.detail_id=id
	var dialog: AcceptDialog=game._dialog(spec.name+"   lvl "+str(int(creature.level)),Vector2i(552,650))
	game.modal_kind="creature"
	var box: VBoxContainer=game._content(dialog)
	box.add_theme_constant_override("separation",8)
	# One art composition: illustration, creature, botanical frame and floating stats.
	var hero=Control.new()
	hero.custom_minimum_size=Vector2(0,250)
	hero.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_child(hero)
	var background=TextureRect.new()
	background.texture=game._region_texture(int(game.player.get("region",0)))
	background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate=Color(0.5,0.58,0.58,0.62)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hero.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.offset_left=10
	background.offset_top=9
	background.offset_right=-10
	background.offset_bottom=-12
	var portrait=game._image_control(game._portrait(creature.species),Vector2(180,180),hero)
	portrait.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.anchor_left=0.5
	portrait.anchor_right=0.5
	portrait.offset_left=-90
	portrait.offset_right=90
	portrait.offset_top=4
	portrait.offset_bottom=184
	var ornament=TextureRect.new()
	ornament.texture=load("res://assets/ui/hero-leaf.svg")
	ornament.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	ornament.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ornament.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	hero.add_child(ornament)
	ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stats=HBoxContainer.new()
	stats.add_theme_constant_override("separation",7)
	hero.add_child(stats)
	stats.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	stats.offset_left=14
	stats.offset_right=-14
	stats.offset_top=-57
	stats.offset_bottom=-12
	var stat_names=["Vida","Ataque","Defesa","Velocidade"]
	var stat_keys=["hp","attack","defense","speed"]
	var stat_icons=["heart","sword","shield","boot"]
	for i in range(4):
		var tile=PanelContainer.new()
		tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var skin=StyleBoxTexture.new()
		skin.texture=load("res://assets/ui/stat-leaf.svg")
		for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
			skin.set_texture_margin(side,12)
			skin.set_content_margin(side,8 if side<2 else 4)
		tile.add_theme_stylebox_override("panel",skin)
		tile.tooltip_text=stat_names[i]
		stats.add_child(tile)
		var cell=_row(tile,true,6)
		_icon(game,stat_icons[i],cell,20,GOLD,stat_names[i])
		var value=_text(game,str(int(creature.stats.get(stat_keys[i],0))),cell,17)
		value.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
		value.autowrap_mode=TextServer.AUTOWRAP_OFF
	var identity=_row(box,false,10)
	var role_column=VBoxContainer.new()
	role_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	identity.add_child(role_column)
	var category=_row(role_column,false,7)
	_icon(game,game._role_icon(spec.role),category,20,tint)
	_text(game,game._role_name(spec.role),category,17,tint)
	_text(game,game._rarity(creature.rarity).name+" · Grau +"+str(rank),role_column,12,MUTED)
	var badge=GearBadge.new()
	badge.display_font=game.font
	badge.score=int(creature.get("gear_score",0))
	badge.custom_minimum_size=Vector2(164,54)
	identity.add_child(badge)
	var xp=ProgressBar.new()
	xp.value=float(creature.xp)/maxf(1,float(creature.next_xp))*100
	xp.show_percentage=false
	xp.custom_minimum_size.y=5
	var xp_bg = _surface(Color("08131d"),Color.TRANSPARENT,2)
	var xp_fill = _surface(LILAC,Color.TRANSPARENT,2)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
		xp_bg.set_content_margin(side,0)
		xp_fill.set_content_margin(side,0)
	xp.add_theme_stylebox_override("background",xp_bg)
	xp.add_theme_stylebox_override("fill",xp_fill)
	box.add_child(xp)
	_text(game,str(int(creature.xp))+" / "+str(int(creature.next_xp))+" XP",box,11,MUTED,true)
	var details=HBoxContainer.new()
	details.add_theme_constant_override("separation",10)
	box.add_child(details)
	var skills=_group(details,Color("63785e"))
	var passive: Dictionary=spec.get("passive",{})
	var passive_row=_row(skills)
	_icon(game,"leaf",passive_row,17,LILAC)
	_text(game,passive.get("name","Vigor")+" · Passiva",passive_row,14,LILAC)
	_text(game,passive.get("description","")+" "+str(roundi((float(passive.get("power",0))+rank*0.01)*100))+"%",skills,13,INK)
	var active_row=_row(skills)
	_icon(game,"spark",active_row,17,MINT)
	_text(game,spec.skill.name+" · Ativa",active_row,14,MINT)
	_text(game,spec.skill.description+" ×"+str(snappedf(float(spec.skill.power)*(1+rank*0.03),0.01))+" · "+str(int(spec.skill.cooldown))+" turnos",skills,13,INK)
	if creature.get("upgrade_job")!=null:
		var timer=_text(game,"",box,18,MINT,true)
		timer.add_to_group("upgrade_timers")
		timer.set_meta("deadline",creature.upgrade_job.ready_at)
		timer.set_meta("duration",(float(creature.upgrade_job.ready_at)-float(creature.upgrade_job.started_at))/1000.0)
		var progress=ProgressBar.new()
		progress.show_percentage=false
		progress.custom_minimum_size.y=6
		box.add_child(progress)
		timer.set_meta("progress",progress)
	elif rank>=10:
		_text(game,"Aprimoramento máximo",box,18,GOLD,true)
	else:
		var cost: Dictionary=creature.upgrade_cost
		var upgrade=_group(details,Color(GOLD,0.5))
		_text(game,"Grau +"+str(rank+1)+" · "+game._duration(float(cost.seconds)),upgrade,15,GOLD)
		var costs=_row(upgrade,false,10)
		var ready=float(game.player.gold)>=float(cost.gold) and int(creature.level)>=int(cost.level) and game.player.get("battle")==null
		for material in cost.materials:
			var have=int(game.player.get("inventory",{}).get(material,0))
			var need=int(cost.materials[material])
			_icon(game,game._material(material).get("icon","spark"),costs,20,GOLD,game._material(material).get("name",material))
			_text(game,str(have)+"/"+str(need),costs,13,MINT if have>=need else RED)
			ready=ready and have>=need
		_text(game,game._coins(float(cost.gold))+" moedas · Nv. "+str(int(cost.level)),upgrade,12,MUTED)
		var button: Button=game._modal_button("Aprimorar",upgrade,game._action.bind("upgrade",{"id":id}),true,"upgrade")
		button.disabled=not ready
		button.tooltip_text="+4% atributos · +1 ponto na passiva · +3% poder da ativa"
	var swap: Button=game._modal_button("Trocar companheiro",box,game._collection_dialog.bind(maxi(0,game.player.team.find(id))),false,"star")
	swap.custom_minimum_size.y=34
	game._update_timer_labels()
	dialog.popup_centered(Vector2i(552,650))
func _art(name: String) -> Texture2D:
	if not _ui_art.has(name):
		var texture=CanvasTexture.new()
		texture.diffuse_texture=load("res://assets/ui/"+name)
		texture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		_ui_art[name]=texture
	return _ui_art[name]

func paint_gear_score(canvas: CanvasItem, font: Font, pos: Vector2, score: int) -> void:
	canvas.draw_texture_rect(_art("gear-leaf.svg"),Rect2(pos,Vector2(164,54)),false)
	canvas.draw_string(font,pos+Vector2(59,17),"GEAR SCORE",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("b0bb98"))
	canvas.draw_string(font,pos+Vector2(59,39),str(score),HORIZONTAL_ALIGNMENT_LEFT,-1,23,GOLD)

func paint_exploration_progress(canvas: CanvasItem, font: Font, icons: Dictionary, rect: Rect2, ticks: int, next_tick: float, distance: int, active: bool, continuous_progress: float=-1.0) -> void:
	canvas.draw_style_box(_surface(Color(0.025,0.08,0.085,0.9),Color("708269"),8),rect)
	var y=rect.get_center().y
	if icons.has("leaf"):
		canvas.draw_texture_rect(icons.leaf,Rect2(rect.position.x+15,y-10,20,20),false,GOLD)
	canvas.draw_string(font,Vector2(rect.position.x+46,y+4),"Descoberta",HORIZONTAL_ALIGNMENT_LEFT,-1,13,INK)
	var track=Rect2(rect.position.x+150,y-12,rect.size.x-420,24)
	canvas.draw_texture_rect(_art("progress-vine.svg"),track,false)
	var progress=clampf(continuous_progress,0,1) if continuous_progress>=0 else clampf((float(ticks%3)+clampf(20.0-next_tick,0,20)/20.0)/3.0,0,1) if active else 0.0
	var fill=Rect2(track.position+Vector2(16,6),Vector2(track.size.x-32,12))
	if progress>0:
		var source=Rect2(0,0,600*progress,16)
		canvas.draw_texture_rect_region(_art("progress-satin.svg"),Rect2(fill.position,Vector2(fill.size.x*progress,fill.size.y)),source)
	if icons.has("boot"):
		canvas.draw_texture_rect(icons.boot,Rect2(rect.end.x-225,y-8,16,16),false,GOLD)
	canvas.draw_string(font,Vector2(rect.end.x-200,y+4),str(distance)+" m",HORIZONTAL_ALIGNMENT_LEFT,110,13,GOLD)
	var state_tint=MINT if active else MUTED
	canvas.draw_circle(Vector2(rect.end.x-96,y),3,state_tint,true,-1,true)
	canvas.draw_string(font,Vector2(rect.end.x-84,y+4),"Em rota" if active else "Pausa",HORIZONTAL_ALIGNMENT_LEFT,75,12,state_tint)

func _leaf_skin(path: String="stat-leaf.svg", inset: int=12) -> StyleBoxTexture:
	var skin=StyleBoxTexture.new()
	skin.texture=load("res://assets/ui/"+path)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
		skin.set_texture_margin(side,inset)
		skin.set_content_margin(side,16 if side<2 else 11)
	return skin

func _leaf_group(parent: Node) -> VBoxContainer:
	var panel=PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	panel.add_theme_stylebox_override("panel",_leaf_skin())
	parent.add_child(panel)
	var box=VBoxContainer.new()
	box.add_theme_constant_override("separation",6)
	panel.add_child(box)
	return box

func build_inventory(game: Control) -> void:
	var capacity=int(game.player.get("inventory_capacity",4))
	var pending: Dictionary=game.player.get("pending_loot",{})
	var height=mini(740,170+ceili(float(capacity)/6.0)*100+(120 if not pending.is_empty() else 0))
	var dialog: AcceptDialog=game._dialog("Inventário",Vector2i(680,height))
	game.modal_kind="inventory"
	var box: VBoxContainer=game._content(dialog)
	var top=_row(box)
	_text(game,str(game.player.get("inventory",{}).size())+" / "+str(capacity)+" espaços",top,18,GOLD)
	var price=float(game.player.get("inventory_cost",60))
	var expand: Button=game._modal_button("+2 · "+game._coins(price),top,game._action.bind("inventory_expand"),true,"coin")
	expand.disabled=capacity>=20 or game.player.get("battle")!=null or float(game.player.gold)<price
	expand.tooltip_text="Expandir mochila com moedas"
	var centered=_row(box,true)
	var grid=GridContainer.new()
	grid.columns=mini(6,capacity)
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	centered.add_child(grid)
	var keys: Array=game.player.get("inventory",{}).keys()
	for i in range(capacity):
		var slot=PanelContainer.new()
		slot.custom_minimum_size=Vector2(90,90)
		var skin=_surface(Color("0e202a"),Color("526663"),8)
		for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
			skin.set_content_margin(side,8)
		slot.add_theme_stylebox_override("panel",skin)
		grid.add_child(slot)
		var stack=VBoxContainer.new()
		stack.add_theme_constant_override("separation",6)
		slot.add_child(stack)
		if i<keys.size():
			var id=keys[i]
			var item: Dictionary=game._material(id)
			_icon(game,item.get("icon","spark"),stack,36,Color(item.get("color","e4c68c")))
			_text(game,"× "+str(int(game.player.inventory[id])),stack,16,INK,true)
			slot.tooltip_text=item.get("name",id)+" · "+item.get("source","")
		else:
			_icon(game,"bag",stack,36,Color(1,1,1,0.13))
			slot.tooltip_text="Espaço livre"
	if not pending.is_empty():
		var rescue=_group(box,Color("5b5870"))
		var title=_row(rescue)
		_icon(game,"bag",title,18,LILAC)
		_text(game,"Baú de resgate",title,15,LILAC)
		var items=_row(rescue,false,10)
		for id in pending:
			var material: Dictionary=game._material(id)
			_icon(game,material.get("icon","spark"),items,20,Color(material.get("color","e4c68c")),material.get("name",id))
			_text(game,"× "+str(int(pending[id])),items,14,INK)
		game._modal_button("Resgatar",rescue,game._action.bind("claim_loot"),false,"bag")
	dialog.popup_centered(Vector2i(680,height))

## summary schema is server-derived; this view never computes rewards.
func build_expedition_summary(game: Control, summary: Dictionary) -> void:
	var result=str(summary.get("outcome",summary.get("reason","complete")))
	var wiped=result in ["wipe","defeat","team_wipe"]
	var region=clampi(int(summary.get("region",game.player.get("region",0))),0,2)
	var reward: Dictionary=summary.get("rewards",summary)
	var gold=float(reward.get("gold",summary.get("gold",0)))
	var experience=int(reward.get("xp",summary.get("xp",0)))
	var items: Dictionary=reward.get("items",summary.get("items",{}))
	var duration=float(summary.get("duration_seconds",summary.get("elapsed_seconds",0)))
	if duration<=0 and summary.has("started_at") and summary.has("ended_at"):
		duration=(float(summary.ended_at)-float(summary.started_at))/1000.0
	var battles=int(summary.get("battles",summary.get("encounters",0)))
	var kills=int(summary.get("kills",summary.get("defeated",0)))
	var title="Caravana de volta" if wiped else "Jornada concluída"
	var dialog: AcceptDialog=game._dialog(title,Vector2i(650,606 if items.size()>0 else 526))
	game.modal_kind="expedition_summary"
	var box: VBoxContainer=game._content(dialog)
	box.add_theme_constant_override("separation",10)
	var hero=PanelContainer.new()
	hero.add_theme_stylebox_override("panel",_leaf_skin("hero-leaf.svg",28))
	box.add_child(hero)
	var picture=TextureRect.new()
	picture.texture=game._region_texture(region)
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.custom_minimum_size=Vector2(580,116)
	picture.modulate=Color(0.66,0.72,0.76,0.85)
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	picture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	hero.add_child(picture)
	var region_title=_text(game,game.catalogue.regions[region].name,box,21,GOLD,true)
	region_title.add_theme_font_override("font",game.title_font)
	_text(game,"Sua equipe precisa reagrupar. Os ganhos estão guardados." if wiped else "Rota explorada. Cada passo fortalece a caravana.",box,13,MUTED,true)
	var metrics=_row(box,false,12)
	for metric in [["boot",game._duration(duration),"TEMPO"],["sword",str(kills),"ABATES"],["shield",str(battles),"BATALHAS"]]:
		var cell=_leaf_group(metrics)
		cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var heading=_row(cell,true)
		_icon(game,str(metric[0]),heading,18,MINT)
		var value=_text(game,str(metric[1]),heading,19,INK)
		value.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
		value.autowrap_mode=TextServer.AUTOWRAP_OFF
		_text(game,str(metric[2]),cell,10,MUTED,true)
	var earnings=_row(box,true,18)
	for gain in [["coin",game._coins(gold),GOLD],["xp",str(experience),LILAC]]:
		var earned=_leaf_group(earnings)
		var line=_row(earned,true,10)
		_icon(game,str(gain[0]),line,34,Color.WHITE)
		var amount=_text(game,"+"+str(gain[1]),line,25,gain[2])
		amount.autowrap_mode=TextServer.AUTOWRAP_OFF
		amount.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	if not items.is_empty():
		var loot=_leaf_group(box)
		var loot_row=_row(loot,true,15)
		for id in items:
			var material: Dictionary=game._material(id)
			var item=_row(loot_row,false,5)
			_icon(game,material.get("icon","spark"),item,24,Color(material.get("color","e4c68c")),material.get("name",id))
			var count=_text(game,"×"+str(int(items[id])),item,16,INK)
			count.autowrap_mode=TextServer.AUTOWRAP_OFF
	var close: Button=game._modal_button("Reagrupar" if wiped else "Continuar",box,dialog.queue_free,true,"play")
	close.custom_minimum_size.y=42
	dialog.popup_centered(Vector2i(650,606 if items.size()>0 else 526))

## One shared icon vocabulary for transient world/HUD gains. origin is the
## center-left of the feedback; age drives only presentation, never rewards.
func paint_reward_feedback(canvas: CanvasItem, font: Font, icons: Dictionary, origin: Vector2, value: float, kind: String, age: float, duration: float=1.8) -> void:
	if age<0 or age>duration or is_zero_approx(value):
		return
	var progress=clampf(age/duration,0,1)
	var opacity=smoothstep(0,0.08,progress)*(1.0-smoothstep(0.58,1.0,progress))
	var position=origin+Vector2(0,-smoothstep(0,1,progress)*30)
	var tint=GOLD if kind=="gold" else LILAC
	var icon_id="coin" if kind=="gold" else "xp"
	var texture: Texture2D=icons.get(icon_id)
	if texture==null:
		texture=load("res://assets/icons/"+icon_id+".svg")
	var amount = "%.3f" % value
	while amount.ends_with("0"):
		amount = amount.left(-1)
	var text="+"+amount.trim_suffix(".").replace(".",",") if kind=="gold" else "+"+str(int(value))
	var width=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x+48
	canvas.draw_style_box(_surface(Color(0.025,0.075,0.09,opacity*0.9),Color(tint,opacity*0.35),7),Rect2(position-Vector2(6,17),Vector2(width,34)))
	canvas.draw_texture_rect(texture,Rect2(position-Vector2(0,13),Vector2(26,26)),false,Color(1,1,1,opacity))
	canvas.draw_string(font,position+Vector2(34,6),text,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(tint,opacity))
