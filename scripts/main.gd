extends Control

const BG = Color("0d1422")
const PANEL = Color("152133")
const PANEL_LIGHT = Color("1d2e43")
const INK = Color("edf2ed")
const MUTED = Color("94a9bb")
const MINT = Color("83dfba")
const GOLD = Color("f2cd85")
const LILAC = Color("c5a5ef")
const RED = Color("ef8e8b")
const CATALOGUE_PATH = "res://assets/species.json"
const SETTINGS_PATH = "user://connection.cfg"

var catalogue: Dictionary = {}
var by_id: Dictionary = {}
var player: Dictionary = {}
var leaderboard: Dictionary = {}
var server_url = "http://127.0.0.1:8787"
var token = ""
var connected = false
var busy = false
var auto_battle = false
var compact = false
var selected_region = 0
var elapsed = 0.0
var poll_elapsed = 0.0
var draw_elapsed = 0.0
var banner = "Iniciando conexão com o servidor local…"
var banner_time = 0.0
var request_context = ""
var creature_atlas: Texture2D
var terrain_atlas: Texture2D
var prop_atlas: Texture2D
var backdrop: Texture2D
var font: Font
var title_font: Font
var detailed_atlas: Texture2D
var world_atlas: Texture2D
var regional_worlds: Array = []
var enemy_atlas: Texture2D
var world_painter = preload("res://scripts/world_painter.gd").new()
var effects_painter = preload("res://scripts/combat_effects.gd").new()
var menu_chrome = preload("res://scripts/menu_chrome.gd").new()
var route_distance = 0.0
var compact_auto = true
var route_auto = true
var wave_elapsed = 0.0
var combat_sequence: Array = []
var unit_positions: Dictionary = {}
var unit_muzzles: Dictionary = {}
var pending_requests: Array = []
var ui: Control
var http: HTTPRequest
var name_input: LineEdit
var settings: ConfigFile
var last_signature = ""
var sound_enabled = true
var sound_channels: Array = []
var sound_channel_index = 0
var sound_player: AudioStreamPlayer
var battle_fx: Dictionary = {}
var displayed_hp: Dictionary = {}
var trailing_hp: Dictionary = {}
var unit_birth: Dictionary = {}
var unit_death: Dictionary = {}
var icons: Dictionary = {}
var sprite_regions: Dictionary = {}
var action_atlases: Dictionary = {}
var action_regions: Dictionary = {}
var action_catalogue: Dictionary = {}
var creature_motion = preload("res://scripts/creature_motion.gd").new()
var pose_player = preload("res://scripts/creature_pose_player.gd").new()
var camera_zoom = 0.90
var battle_blend = 0.0
var encounter_director = preload("res://scripts/encounter_director.gd").new()
var enemy_step_speed = 0.0
var discovery_meter = 0.0
var discovery_sample_time = 0.0
var discovery_expedition = ""
var gain_events: Array = []
var pending_expedition_summary: Dictionary = {}
@export_range(8.0, 64.0, 1.0) var travel_speed = 24.0
@export_range(0.25, 3.0, 0.05) var world_speed_multiplier = 1.0
var walk_clock = 0.0
var animation_until = 0.0
var visual_hp: Dictionary = {}
var server_now = 0.0
var upgrade_flare = -20.0
var modal: AcceptDialog
var modal_kind = ""
var detail_id = ""
var map_data: Dictionary = {}

func _ready() -> void:
	font = load("res://assets/fonts/TaskMon-Interface.ttf")
	font.allow_system_fallback = false
	title_font = load("res://assets/fonts/CinzelDecorative.ttf")
	title_font.allow_system_fallback = false
	var game_theme = Theme.new()
	game_theme.default_font = font
	game_theme.default_font_size = 17
	var window_skin = _style(Color("102332"), GOLD, 3)
	window_skin.expand_margin_top = 32
	game_theme.set_stylebox("embedded_border", "Window", window_skin)
	game_theme.set_color("title_color", "Window", GOLD)
	game_theme.set_font("title_font", "Window", title_font)
	for control_class in ["Button", "Label", "LineEdit", "TooltipLabel", "RichTextLabel"]:
		game_theme.set_font("font", control_class, font)
	game_theme.set_font_size("font_size", "TooltipLabel", 14)
	game_theme.set_stylebox("panel", "TooltipPanel", _style(Color("102332"), Color("68736c"), 6))
	theme = game_theme
	get_window().theme = game_theme
	Engine.max_fps = 60
	get_window().gui_embed_subwindows = true
	creature_atlas = load("res://assets/creatures.png")
	terrain_atlas = load("res://assets/terrain.png")
	prop_atlas = load("res://assets/props.png")
	backdrop = load("res://docs/art-direction.png")
	if ResourceLoader.exists("res://assets/creatures-detailed.png"):
		detailed_atlas = load("res://assets/creatures-detailed.png")
	if ResourceLoader.exists("res://assets/worlds.png"):
		world_atlas = load("res://assets/worlds.png")
	if ResourceLoader.exists("res://assets/enemies.png"):
		enemy_atlas = load("res://assets/enemies.png")
	if ResourceLoader.exists("res://assets/creatures-taskmon.png"):
		detailed_atlas = load("res://assets/creatures-taskmon.png")
	for icon_id in ["heart", "sword", "shield", "boot", "bag", "expand", "compact", "pause", "play", "settings", "sound", "book", "star", "spark", "leaf", "orb", "crystal", "core", "close", "upgrade", "auto", "trophy", "coin", "xp", "eye"]:
		icons[icon_id] = load("res://assets/icons/" + icon_id + ".svg")
	for region_key in ["forest", "coast", "ruins"]:
		var path = "res://assets/world-" + region_key + ".png"
		regional_worlds.append(load(path) if ResourceLoader.exists(path) else null)
	map_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps.json"))
	catalogue = JSON.parse_string(FileAccess.get_file_as_string(CATALOGUE_PATH))
	for item in catalogue.species:
		by_id[item.id] = item
	var enemy_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/enemies.json"))
	for item in enemy_data.species:
		by_id[item.id] = item
	_cache_sprite_regions()
	_cache_action_poses()
	pose_player.prepare()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	settings = ConfigFile.new()
	settings.load(SETTINGS_PATH)
	server_url = settings.get_value("connection", "url", server_url)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--server="):
			server_url = arg.trim_prefix("--server=").trim_suffix("/")
	token = settings.get_value(_session_section(), "token", "")
	ui = Control.new()
	ui.name = "Interface"
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	http = HTTPRequest.new()
	http.timeout = 6.0
	http.request_completed.connect(_request_completed)
	add_child(http)
	sound_player = AudioStreamPlayer.new()
	sound_player.volume_db = -16
	add_child(sound_player)
	for i in range(12):
		var channel = AudioStreamPlayer.new()
		channel.volume_db = -14
		add_child(channel)
		sound_channels.append(channel)
	_build_ui()
	if token.is_empty():
		_api("/health", {}, "health")
	else:
		_api("/api/state", {}, "state")
	set_process(true)

func _session_section() -> String:
	return "session_" + server_url.sha256_text().left(12)

func _exit_tree() -> void:
	# Explicitly retire active voices before the audio server tears down playback.
	if is_instance_valid(sound_player):
		sound_player.stop()
		sound_player.stream = null
	for channel in sound_channels:
		if is_instance_valid(channel):
			channel.stop()
			channel.stream = null

func _save_settings() -> void:
	settings.set_value("connection", "url", server_url)
	settings.set_value(_session_section(), "token", token)
	if not player.is_empty() and not token.is_empty():
		var profiles = settings.get_value(_session_section(), "profiles", {})
		profiles[player.id] = {"name": player.name, "token": token}
		settings.set_value(_session_section(), "profiles", profiles)
	settings.save(SETTINGS_PATH)

func _process(delta: float) -> void:
	elapsed += delta
	var in_combat = player.get("battle") != null
	var phase_before = encounter_director.phase
	var clock_before = encounter_director.locomotion_clock
	var offset_before = encounter_director.enemy_world_offset
	var menus_open = is_instance_valid(modal) and modal.visible
	encounter_director.journey_active = player.get("expedition") != null and not menus_open
	encounter_director.update(delta, 0.0 if menus_open else world_speed_multiplier * travel_speed / 24.0, in_combat and player.battle.get("result") != null)
	enemy_step_speed = (offset_before - encounter_director.enemy_world_offset) / maxf(0.001, delta)
	route_distance += encounter_director.consume_travel_distance()
	walk_clock += encounter_director.locomotion_clock - clock_before
	battle_blend = encounter_director.camera_blend
	camera_zoom = lerpf(0.90, 1.10, battle_blend)
	world_painter.camera_zoom = camera_zoom
	if phase_before != encounter_director.phase and not player.is_empty():
		_build_ui()
	server_now += delta
	_update_timer_labels()
	poll_elapsed += delta
	draw_elapsed += delta
	wave_elapsed += delta
	var exploring = not player.is_empty() and player.get("expedition") != null
	if exploring and player.get("battle") == null and (not is_instance_valid(modal) or not modal.visible):
		route_distance += delta * travel_speed * world_speed_multiplier
	if exploring:
		var partial = clampf((20.0 - float(player.get("next_tick", 20)) + elapsed - discovery_sample_time) / 20.0, 0, 1)
		var meter_target = float(player.expedition.get("ticks", 0)) / 3.0 + partial / 3.0
		discovery_meter = lerpf(discovery_meter, maxf(discovery_meter, meter_target), 1.0 - exp(-delta * 8.0))
	_update_world_inspect()
	if not pending_expedition_summary.is_empty() and elapsed >= animation_until + 0.25 and (not is_instance_valid(modal) or not modal.visible):
		var report = pending_expedition_summary
		pending_expedition_summary = {}
		if compact:
			_toggle_compact()
		if player.get("battle") != null and player.battle.get("result") != null:
			_action("close_battle")
		menu_chrome.build_expedition_summary(self, report)
		modal_kind = "expedition_summary"
	banner_time = maxf(0, banner_time - delta)
	var interval = 0.5 if get_window().mode == Window.MODE_MINIMIZED else 1.0 / 60.0
	if draw_elapsed >= interval:
		draw_elapsed = 0
		queue_redraw()
	if player.get("battle") != null:
		for side in ["allies", "enemies"]:
			for unit in player.battle[side]:
				displayed_hp[unit.id] = lerpf(float(displayed_hp.get(unit.id, unit.hp)), float(visual_hp.get(unit.id, unit.hp)) if elapsed < animation_until else float(unit.hp), 1.0 - exp(-delta * 10.0))
				trailing_hp[unit.id] = lerpf(float(trailing_hp.get(unit.id, unit.hp)), float(displayed_hp[unit.id]), 1.0 - exp(-delta * 2.2))
				if float(displayed_hp[unit.id]) < 0.6 and not unit_death.has(unit.id):
					unit_death[unit.id] = elapsed
	for event in combat_sequence:
		if not event.get("sounded", false) and elapsed >= float(event.started) + 0.27:
			event.sounded = true
			if event.get("sound_owner", true):
				_play_creature_sound(event.species, "skill" if event.get("skill", false) else "attack")
		if not event.get("applied", false) and elapsed >= float(event.started) + (0.81 if event.kind == "attack" else 0.55):
			event.applied = true
			if event.kind == "attack":
				_play_creature_sound(event.species, "impact")
			var current_hp = float(visual_hp.get(event.target, 0))
			if event.kind == "attack":
				visual_hp[event.target] = maxf(0, current_hp - float(event.value))
			elif event.kind == "heal":
				visual_hp[event.target] = current_hp + float(event.value)
	_update_combat_controls()
	if busy:
		return
	if not pending_requests.is_empty():
		var next = pending_requests.pop_front()
		_api(next.path, next.data, next.context)
		return
	if ((compact and compact_auto) or (not compact and route_auto)) and exploring and (not is_instance_valid(modal) or not modal.visible):
		var active = player.get("battle")
		if active == null and wave_elapsed > (3.0 if compact else 8.0):
			wave_elapsed = 0
			auto_battle = true
			_action("battle", {"kind": "wild"})
			return
		if active != null and active.get("result") != null and wave_elapsed > 2.0 and elapsed >= animation_until + 0.8:
			wave_elapsed = 0
			_action("close_battle")
			return
	if auto_battle and not player.is_empty() and player.get("battle") != null:
		if player.battle.get("result") != null:
			auto_battle = false
		elif poll_elapsed >= 1.35 and elapsed >= animation_until and not _presentation_locked():
			poll_elapsed = 0
			_action("turn", {"command": "auto"})
			return
	if not token.is_empty() and poll_elapsed >= 2.5:
		poll_elapsed = 0
		_api("/api/state", {}, "state")

func _api(path: String, data: Dictionary, context: String) -> void:
	if busy:
		if context != "state" and pending_requests.size() < 4:
			pending_requests.append({"path": path, "data": data.duplicate(true), "context": context})
		return
	busy = true
	request_context = context
	var headers = PackedStringArray(["Content-Type: application/json"])
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	var method = HTTPClient.METHOD_GET
	var payload = ""
	if not data.is_empty():
		method = HTTPClient.METHOD_POST
		payload = JSON.stringify(data)
		headers.append("Idempotency-Key: " + Crypto.new().generate_random_bytes(16).hex_encode())
	var err = http.request(server_url + path, headers, method, payload)
	if err != OK:
		busy = false
		_notice("Não foi possível conectar. Abra Iniciar-Brumora.bat ou configure o servidor.")

func _request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if result != HTTPRequest.RESULT_SUCCESS or body.is_empty():
		connected = false
		_notice("Servidor indisponível. Abra o inicializador; o progresso fica salvo no servidor.")
		queue_redraw()
		return
	var parser = JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		connected = false
		_notice("O endereço não respondeu como um servidor TaskMon.")
		return
	var response = parser.data
	connected = true
	if response_code >= 400:
		_notice(str(response.get("error", "Falha na solicitação.")))
		if response_code == 401:
			token = ""
			player = {}
			auto_battle = false
			_build_ui()
		return
	if response.has("token"):
		token = response.token
	if response.has("player"):
		var previous_gold = float(player.get("gold", -1))
		var previous_id = str(player.get("id", ""))
		var previous_distance = float(player.get("distance", 0))
		var previous_summary_id = str(player.get("last_expedition_summary", {}).get("id", "")) if player.get("last_expedition_summary") != null else ""
		var previous_battle = player.get("battle")
		var previous_round = int(player.get("battle", {}).get("round", -1)) if player.get("battle") != null else -1
		var before_inventory = str(player.get("inventory", {})) + str(player.get("pending_loot", {})) + str(player.get("inventory_capacity", 4))
		var before_upgrades = str(player.get("collection", []))
		var old_collection: Array = player.get("collection", []).duplicate(true)
		player = response.player
		discovery_sample_time = elapsed
		var journey_id = str(player.expedition.get("id", "")) if player.get("expedition") != null else ""
		if journey_id != discovery_expedition:
			discovery_expedition = journey_id
			discovery_meter = float(player.expedition.get("ticks", 0)) / 3.0 if player.get("expedition") != null else 0.0
		var report = player.get("last_expedition_summary")
		if report != null and str(report.get("id", "")) != previous_summary_id and previous_id == str(player.id):
			pending_expedition_summary = report.duplicate(true)
			auto_battle = false
		if str(player.id) == previous_id and previous_gold >= 0 and float(player.gold) - previous_gold >= 0.0005:
			gain_events.append({"kind": "gold", "value": snappedf(float(player.gold) - previous_gold, 0.001), "started": elapsed + (maxf(0, animation_until - elapsed) if player.get("battle") != null else 0)})
		if player.get("battle") != null and player.battle.get("result") != null and previous_battle != null and previous_battle.get("result") == null:
			var earned = int(player.battle.get("rewards", {}).get("xp", 0))
			if earned > 0:
				gain_events.append({"kind": "xp", "value": earned, "started": elapsed + maxf(1.5, player.battle.get("events", []).size())})
		if gain_events.size() > 8:
			gain_events.pop_front()
		if player.get("battle") != null and (previous_battle == null or str(previous_battle.get("id", "")) != str(player.battle.get("id", ""))):
			encounter_director.begin_battle(str(player.battle.get("id", "legacy_" + str(player.id))), elapsed, {"journey_active": player.get("expedition") != null, "round": int(player.battle.round), "finished": player.battle.get("result") != null, "restored": previous_id.is_empty()})
			animation_until = elapsed + 0.85
			combat_sequence.clear()
			visual_hp.clear()
			displayed_hp.clear()
			unit_birth.clear()
			unit_death.clear()
			trailing_hp.clear()
			for side in ["allies", "enemies"]:
				for i in range(player.battle[side].size()):
					unit_birth[player.battle[side][i].id] = elapsed - 1.0 if side == "allies" or player.battle.kind == "wild" else elapsed + i * 0.12
					visual_hp[player.battle[side][i].id] = float(player.battle[side][i].hp)
					if int(player.battle[side][i].hp) <= 0:
						unit_death[player.battle[side][i].id] = elapsed - 2.0
		server_now = float(player.get("server_time", 0)) / 1000.0
		for c in player.collection:
			for old_c in old_collection:
				if c.id == old_c.id and int(c.get("upgrade", 0)) > int(old_c.get("upgrade", 0)):
					upgrade_flare = elapsed
					_notice(by_id[c.species].name + " aprimorado!")
					_play_sound("win")
		if is_instance_valid(modal) and modal.visible:
			var changed = before_inventory != str(player.get("inventory", {})) + str(player.get("pending_loot", {})) + str(player.get("inventory_capacity", 4)) or before_upgrades != str(player.collection)
			if changed:
				call_deferred("_refresh_modal")
		if str(player.id) != previous_id:
			route_distance = float(player.get("distance", 0))
			selected_region = int(player.region)
		else:
			route_distance += maxf(0, float(player.get("distance", 0)) - previous_distance)
		if previous_battle != null and previous_battle.get("result") == null and player.get("battle") != null and player.battle.get("result") != null:
			wave_elapsed = 0
		if player.get("battle") != null and previous_battle != null and int(player.battle.round) > previous_round:
			_animate_round(previous_battle, player.battle)
			if player.battle.get("result") != null and previous_battle.get("result") == null:
				for gain in gain_events:
					if float(gain.started) >= elapsed - 0.01:
						gain.started = animation_until
		elif player.get("battle") == null:
			if previous_battle != null:
				encounter_director.end_battle(elapsed)
			animation_until = 0
			battle_fx.clear()
			visual_hp.clear()
			displayed_hp.clear()
			combat_sequence.clear()
			unit_positions.clear()
		if request_context == "register":
			_save_settings()
		if player.get("battle") != null and int(player.battle.round) > previous_round and previous_round >= 0:
			pass
		if request_context == "register":
			selected_region = int(player.region)
			_notice("Sua caravana está pronta. Parta em expedição!")
		var signature = str(player.team) + str(player.collection.size()) + str(player.get("battle")) + str(player.gold) + str(player.region) + str(player.get("expedition") != null) + str(player.get("inventory", {})) + str(player.collection)
		if signature != last_signature:
			last_signature = signature
			_build_ui()
	if request_context == "health":
		banner = "Servidor local conectado. Escolha seu companheiro inicial."
		for arg in OS.get_cmdline_user_args():
			if arg == "--demo":
				_register("ember", "Viajante Demo")
	if request_context == "leaderboard":
		leaderboard = response
		_show_leaderboard()
	queue_redraw()

func _notice(message: String) -> void:
	banner = message
	banner_time = 10
	queue_redraw()

func _register(starter: String, chosen_name: String = "") -> void:
	var profile_name = chosen_name
	if profile_name.is_empty() and is_instance_valid(name_input):
		profile_name = name_input.text.strip_edges()
	if profile_name.length() < 2:
		_notice("Digite seu nome de viajante (2 a 20 caracteres).")
		return
	_api("/api/register", {"name": profile_name, "starter": starter}, "register")

func _action(op: String, args: Dictionary = {}) -> void:
	if op == "turn" and _presentation_locked():
		return
	if op in ["turn", "close_battle", "retreat"] and elapsed < animation_until:
		return
	if op == "turn" and args.get("command", "auto") != "auto":
		auto_battle = false
	if op == "route":
		route_auto = true
		auto_battle = true
		wave_elapsed = 0
	var data = {"op": op}
	data.merge(args)
	_api("/api/action", data, "action")

func _style(color: Color, border_color: Color = Color.TRANSPARENT, radius: int = 12) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(2 if border_color.a > 0 else 0)
	style.set_corner_radius_all(mini(radius, 8))
	style.shadow_color = Color(0.01, 0.02, 0.04, 0.65)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _button(text: String, rect: Rect2, callback: Callable, primary: bool = false, tip: String = "", icon_id: String = "") -> Button:
	var button = Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if text.is_empty() else HORIZONTAL_ALIGNMENT_LEFT
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.position = rect.position
	button.size = rect.size
	if player.get("battle") != null and rect.position.y >= 700:
		button.visible = not _presentation_locked()
	_decorate_button(button, primary)
	if icons.has(icon_id):
		button.icon = icons[icon_id]
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", mini(22, maxi(12, int(minf(rect.size.x, rect.size.y)) - 12)))
	button.tooltip_text = tip
	if player.get("battle") != null and callback.get_method() == "_action":
		button.add_to_group("combat_commands")
		button.disabled = busy or elapsed < animation_until
	button.pressed.connect(callback)
	ui.add_child(button)
	return button

func _build_ui() -> void:
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	if compact and not player.is_empty():
		_button("", Rect2(1216, 12, 48, 44), _toggle_compact, true, "Expandir · Esc", "expand")
		_button("", Rect2(16, 185, 48, 44), _pause_or_explore, false, "Pausar / explorar", "pause" if player.expedition != null else "play")
		_button("", Rect2(76, 185, 48, 44), _toggle_compact_auto, compact_auto, "Combate automático", "auto")
		_button("", Rect2(136, 185, 48, 44), _inventory_dialog, false, "Inventário", "bag")
		return
	_button("", Rect2(1210, 22, 48, 42), _connection_dialog, false, "Perfis e conexão", "settings")
	if player.is_empty():
		name_input = LineEdit.new()
		name_input.position = Vector2(450, 211)
		name_input.size = Vector2(380, 44)
		name_input.placeholder_text = "Nome do explorador"
		name_input.max_length = 20
		name_input.add_theme_stylebox_override("normal", _style(Color("0d202c"), GOLD, 3))
		ui.add_child(name_input)
		for i in range(3):
			_button("Escolher", Rect2(165 + i * 338, 644, 274, 42), _register.bind(catalogue.species[i].id), true, "", "spark")
		return
	_button("", Rect2(1152, 22, 48, 42), _toggle_compact, false, "Rodapé · Esc para voltar", "compact")
	_button("", Rect2(1094, 22, 48, 42), _inventory_dialog, false, "Inventário", "bag")
	_button("", Rect2(1036, 22, 48, 42), _profile_dialog, false, "Perfil e conquistas", "trophy")
	var battle = player.get("battle")
	if battle != null and encounter_director.phase != &"approach":
		if battle.get("result") != null:
			var resume = _button("", Rect2(604, 708, 72, 56), _action.bind("close_battle"), true, "Continuar exploração", "play")
			resume.name = "ContinueBattle"
		else:
			_button("", Rect2(428, 708, 72, 56), _action.bind("turn", {"command": "attack"}), false, "Atacar", "sword")
			_button("", Rect2(516, 708, 72, 56), _action.bind("turn", {"command": "skill"}), true, "Habilidade", "spark")
			_button("", Rect2(604, 708, 72, 56), _action.bind("turn", {"command": "guard"}), false, "Defender", "shield")
			_button("", Rect2(692, 708, 72, 56), _toggle_auto, auto_battle, "Combate automático", "auto")
			if not battle.get("rated", false):
				_button("", Rect2(780, 708, 72, 56), _action.bind("retreat"), false, "Recuar", "close")
		return
	_button("Explorar", Rect2(28, 208, 154, 44), _action.bind("route", {"region": selected_region}), true, "Partir no mapa selecionado", "play")
	_button("Batalha", Rect2(28, 264, 154, 44), _action.bind("battle", {"kind": "wild"}), false, "Materiais e XP", "sword")
	_button("Chefe", Rect2(28, 320, 154, 44), _action.bind("battle", {"kind": "boss"}), false, "Núcleos e novas regiões", "core")
	_button("Mapas", Rect2(28, 376, 154, 44), _maps_dialog, false, "Rotas, dificuldade e poder recomendado", "book")
	_button("Arena", Rect2(28, 450, 154, 44), _api.bind("/api/leaderboard", {}, "leaderboard"), false, "Defesas assíncronas", "trophy")
	_button("Auto", Rect2(1090, 171, 140, 42), _toggle_route_auto, route_auto, "Batalhas automáticas com o jogo aberto", "auto")
	_button("Treino", Rect2(28, 506, 154, 40), _action.bind("battle", {"kind": "training"}), false, "Treino sem recompensas", "shield")
	_button("", Rect2(28, 618, 68, 54), _collection_dialog.bind(0), false, "Coleção", "star")
	_button("", Rect2(112, 618, 68, 54), _inventory_dialog, false, "Inventário", "bag")
	_button("", Rect2(28, 720, 44, 42), _toggle_sound, sound_enabled, "Som", "sound")
	_button("", Rect2(82, 720, 44, 42), _journal_dialog, false, "Diário", "book")
	_button("", Rect2(136, 720, 44, 42), _pause_or_explore, false, "Pausar / explorar", "pause" if player.expedition != null else "play")
	for i in range(3):
		var x = 212 + i * 348
		var region = catalogue.regions[i]
		var button = _button(region.name if i <= int(player.unlocked) else "Rota selada", Rect2(x, 100, 332, 40), _select_region.bind(i), i == selected_region)
		button.disabled = i > int(player.unlocked)
		if player.expedition != null:
			if i < player.team.size():
				var eye = _button("", Rect2(0, 0, 28, 28), _creature_dialog.bind(player.team[i]), false, "Ver criatura", "eye")
				eye.add_to_group("world_inspect")
				eye.set_meta("member", i)
			continue
		var slot = _button("", Rect2(x, 568, 332, 188), _creature_dialog.bind(player.team[i]) if i < player.team.size() else _collection_dialog.bind(i), false, "Abrir criatura" if i < player.team.size() else "Adicionar companheiro")
		slot.name = "TeamSlot" + str(i)
		slot.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		slot.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		for state in ["hover", "pressed", "focus"]:
			var highlight = _style(Color(0.35, 0.5, 0.6, 0.10 if state == "hover" else 0.16), Color(GOLD, 0.6), 8)
			highlight.set_border_width_all(1)
			highlight.shadow_size = 0
			slot.add_theme_stylebox_override(state, highlight)

func _select_region(index: int) -> void:
	selected_region = index
	_build_ui()
	queue_redraw()

func _update_combat_controls() -> void:
	var locked = busy or elapsed < animation_until or _presentation_locked()
	for command in get_tree().get_nodes_in_group("combat_commands"):
		if is_instance_valid(command):
			command.disabled = locked

func _presentation_locked() -> bool:
	return encounter_director.phase in [&"approach", &"engage", &"disengage"]

func _update_world_inspect() -> void:
	for eye in get_tree().get_nodes_in_group("world_inspect"):
		var index = int(eye.get_meta("member", 0))
		if index >= player.get("team", []).size():
			continue
		var member = _creature(player.team[index])
		eye.visible = int(member.get("current_hp", 1)) > 0
		var foot_x = 299.6 + index * 156.0
		var creature_scale = lerpf(4.05, 4.6, smoothstep(0, 1, battle_blend))
		eye.position = Vector2(foot_x + 50, _ground_at(foot_x) - creature_scale * 32 - 53)

func _pause_or_explore() -> void:
	if player.expedition != null:
		_action("pause")
	else:
		_action("route", {"region": selected_region})

func _toggle_auto() -> void:
	auto_battle = not auto_battle
	poll_elapsed = 0.85
	_build_ui()

func _toggle_compact() -> void:
	compact = not compact
	if compact and compact_auto:
		auto_battle = true
		wave_elapsed = 0
	var window = get_window()
	window.always_on_top = compact
	window.borderless = compact
	if compact:
		window.min_size = Vector2i(800, 180)
		window.content_scale_size = Vector2i(1280, 250)
		window.size = Vector2i(1100, 215)
		var screen = DisplayServer.screen_get_usable_rect()
		window.position = Vector2i(screen.position.x + (screen.size.x - window.size.x) / 2, screen.end.y - window.size.y - 8)
	else:
		window.min_size = Vector2i(960, 600)
		window.content_scale_size = Vector2i(1280, 800)
		window.size = Vector2i(1280, 800)
		window.move_to_center()
	_build_ui()
	queue_redraw()

func _toggle_compact_auto() -> void:
	compact_auto = not compact_auto
	auto_battle = compact_auto
	_build_ui()

func _gui_input(event: InputEvent) -> void:
	if compact and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and event.position.y < 65:
		get_window().position += Vector2i(event.relative)

func _creature(id: String) -> Dictionary:
	for c in player.get("collection", []):
		if c.id == id:
			return c
	return {}

func _text(text: String, pos: Vector2, size_px: int = 16, color: Color = INK, max_width: float = -1) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, size_px, color)

func _coins(value: float) -> String:
	var formatted = "%.3f" % value
	while formatted.ends_with("0"):
		formatted = formatted.left(-1)
	return formatted.trim_suffix(".").replace(".", ",")

func _draw_gains() -> void:
	var row = 0
	for gain in gain_events:
		var age = elapsed - float(gain.started)
		if age < 0 or age > 3.2:
			continue
		menu_chrome.paint_reward_feedback(self, font, icons, Vector2(812 + row * 104, 48), float(gain.value), gain.kind, age, 3.2)
		row += 1

func _title(text: String, pos: Vector2, size_px: int = 30, color: Color = GOLD) -> void:
	draw_string(title_font, pos + Vector2(1, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(Color("101a25"), color.a))
	draw_string(title_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func _ornate(rect: Rect2, color: Color = Color(0.04, 0.10, 0.14, 0.92), accent: Color = Color("9e875e")) -> void:
	_panel(rect, color, accent, 3)
	draw_rect(Rect2(rect.position + Vector2(4, 4), rect.size - Vector2(8, 8)), Color(accent, 0.3), false, 1)
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		draw_circle(corner, 3, accent)

func _wrapped(text: String, rect: Rect2, size_px: int = 15, color: Color = MUTED) -> void:
	var line = ""
	var y = rect.position.y + size_px
	for word in text.split(" "):
		var candidate = line + (" " if not line.is_empty() else "") + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > rect.size.x and not line.is_empty():
			_text(line, Vector2(rect.position.x, y), size_px, color)
			y += size_px + 5
			line = word
		else:
			line = candidate
		if y > rect.end.y:
			return
	_text(line, Vector2(rect.position.x, y), size_px, color)

func _panel(rect: Rect2, color: Color = PANEL, border: Color = Color.TRANSPARENT, radius: int = 16) -> void:
	draw_style_box(_style(color, border, radius), rect)

func _bar(rect: Rect2, ratio: float, color: Color) -> void:
	_panel(rect, Color("0c1523"), Color.TRANSPARENT, 4)
	if ratio > 0:
		_panel(Rect2(rect.position, Vector2(maxf(3, rect.size.x * clampf(ratio, 0, 1)), rect.size.y)), color, Color.TRANSPARENT, 4)

func _sprite(id: String, pos: Vector2, scale_px: float = 3, shiny: bool = false, frozen: bool = false, flip: bool = false, flash: float = 0.0, action_pose: float = 0.0, locomotion: bool = false, opacity: float = 1.0, action_frame: int = -1, animation: Dictionary = {}) -> void:
	if not animation.has("key"):
		animation.key = id + str(pos.round())
	var spec = by_id.get(id, catalogue.species[0])
	var sheet = enemy_atlas if spec.get("sprite_atlas", "") == "enemy" else detailed_atlas
	if sheet == null or not sprite_regions.has(id):
		return
	var source: Rect2 = sprite_regions[id]
	var extent = scale_px * 32.0
	var ratio = source.size / maxf(source.size.x, source.size.y)
	var dimensions = Vector2(extent * ratio.x, extent * ratio.y)
	if id == "ember" and not frozen and action_frame < 0:
		var key = str(animation.get("key", id + str(roundi(pos.x))))
		var pose = pose_player.sample(key, elapsed, locomotion, animation.get("combat", false))
		if (locomotion and pose >= 1 and pose <= 8) or pose == 10:
			pose = 0
		if animation.get("state", "") == "hurt" and float(animation.get("age", 1)) < 0.30:
			pose = 11
		if pose >= 0:
			sheet = pose_player.sheet
			source = pose_player.regions[pose]
			dimensions = pose_player.pose_size(pose, extent, ratio.y)
			if pose == 0:
				dimensions.y *= 1.0 + sin(elapsed * 2.4) * 0.004
			frozen = true
			# Drawn foot placements carry the stride; avoid a second IK cycle.
			if pose == 0:
				animation.upright = true
				animation.eyes = creature_motion.upright_eyes(id)
				animation.drawn_walk_cycle = false
				frozen = false
	if action_frame >= 0 and action_atlases.has(id):
		sheet = action_atlases[id]
		source = action_regions[id][clampi(action_frame, 0, 3)]
		dimensions = _action_pose_size(id, action_frame, extent)
		frozen = true
		action_pose = 0.0
	var foot = pos + Vector2(extent * 0.5, extent)
	draw_set_transform(foot)
	var target = Rect2(Vector2(-dimensions.x / 2, -dimensions.y), dimensions)
	if flip:
		target.position.x += dimensions.x
		target.size.x = -dimensions.x
	var tint = Color("fff0c7") if shiny else Color.WHITE
	tint = tint.lerp(Color(2, 1.6, 1.6), clampf(flash, 0, 1))
	tint.a = opacity
	_draw_creature_mesh(sheet, source, target, id, frozen, tint, action_pose, locomotion, animation)
	draw_set_transform(Vector2.ZERO)
	if shiny and opacity > 0.8:
		_icon("spark", pos + Vector2(extent - 14, 0), 18)

func _prop(index: int, pos: Vector2, scale_px: float = 2) -> void:
	draw_texture_rect_region(prop_atlas, Rect2(pos, Vector2(32, 48) * scale_px), Rect2(index * 32, 0, 32, 48))

func _draw() -> void:
	creature_motion.begin_frame()
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	if compact and not player.is_empty():
		_draw_compact()
		return
	if player.is_empty():
		_draw_onboarding()
		return
	_draw_world(_world_rect())
	_panel(Rect2(0, 0, 1280, 80), Color("0a1520"), Color("675a42"))
	_title("TaskMon", Vector2(26, 47), 30)
	_text("CRÔNICAS DA CARAVANA", Vector2(29, 67), 11, MUTED)
	var player_name=str(player.name)
	while font.get_string_size(player_name,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x>125 and player_name.length()>1:
		player_name=player_name.left(player_name.length()-2)+"…"
	_text(player_name,Vector2(302,46),17)
	_draw_gear_badge(Vector2(447, 21), int(player.get("gear_score", 0)))
	_icon("coin", Vector2(634, 27), 26)
	_text(_coins(float(player.gold)), Vector2(670, 47), 23, GOLD)
	_draw_gains()
	if player.get("battle") != null:
		_draw_battle(player.battle)
		_draw_banner()
		return
	_draw_sidebar()
	_draw_caravan()
	if player.expedition != null:
		_draw_banner()
		return
	for i in range(3):
		_draw_card(i)
	_text("EQUIPE", Vector2(214, 554), 16, GOLD)
	_draw_banner()
	if elapsed - upgrade_flare < 2.5:
		for i in range(24):
			var a = float(i) * TAU / 24.0
			var t = elapsed - upgrade_flare
			draw_circle(Vector2(736, 640) + Vector2.from_angle(a) * (30 + t * 150), 3, Color(GOLD, maxf(0, 1-t/2.5)))

func _draw_onboarding() -> void:
	_draw_world(Rect2(0, 0, 1280, 800))
	draw_rect(Rect2(0, 0, 1280, 800), Color(0.03, 0.07, 0.12, 0.42))
	_title("TaskMon", Vector2(430, 100), 54, Color("f2ddae"))
	_text("CRÔNICAS DA CARAVANA", Vector2(494, 135), 17, GOLD)
	_text("Escolha quem dará o primeiro passo ao seu lado.", Vector2(367, 179), 23)
	for i in range(3):
		var s = catalogue.species[i]
		var x = 147 + i * 338
		var color = Color(s.color)
		var center = Vector2(x + 155, 407)
		for ring in range(4):
			draw_circle(center, 93 - ring * 13, Color(color, 0.025 + ring * 0.012))
		draw_arc(center + Vector2(0, 41), 84, 0, PI, 32, Color(color, 0.65), 2, true)
		_sprite(s.id, Vector2(x + 52, 301), 6.4)
		_ornate(Rect2(x + 2, 508, 306, 128), Color(0.04, 0.10, 0.14, 0.91), Color(color, 0.7))
		_text(s.name, Vector2(x + 20, 539), 29, color)
		_icon(_role_icon(s.role), Vector2(x + 20, 546), 20)
		_text(_role_name(s.role) + " · " + s.element, Vector2(x + 49, 564), 17, INK)
		_draw_stats(s.base, Vector2(x + 20, 574), 67, 17)
		_text(s.skill.name, Vector2(x + 20, 621), 15, color)
	_text("Cada jornada é diferente. Seus companheiros também serão.", Vector2(355, 718), 19, Color("dfd9c5"))
	_text(banner, Vector2(170, 763), 16, MINT if connected else GOLD, 945)

func _draw_sidebar() -> void:
	_ornate(Rect2(14, 163, 180, 396), Color(0.025, 0.06, 0.09, 0.94))
	_text("JORNADA", Vector2(48, 191), 17, GOLD)
	draw_line(Vector2(30, 435), Vector2(176, 435), Color(GOLD, 0.3))
	_ornate(Rect2(14, 574, 180, 199), Color(0.025, 0.06, 0.09, 0.96))
	_text("COLEÇÃO", Vector2(55, 599), 14, MINT)

func _draw_world(rect: Rect2) -> void:
	var region = int(player.get("region", 0))
	var exploring = player.get("expedition") != null and (player.get("battle") == null or encounter_director.phase == &"approach") and (not is_instance_valid(modal) or not modal.visible)
	var single = regional_worlds.size() > region and regional_worlds[region] != null
	world_painter.paint(self, regional_worlds[region] if single else world_atlas, region, rect, elapsed, route_distance, exploring, compact, single)

func _ground_at(x: float) -> float:
	var world_rect = _world_rect()
	if world_painter.has_method("ground_height"):
		return world_painter.ground_height(int(player.get("region", 0)), world_rect, x, route_distance, compact)
	return world_rect.end.y - (56 if compact else 92)

func _world_rect() -> Rect2:
	if compact:
		return Rect2(0, 0, 1280, 250)
	var height = lerpf(720, 484, smoothstep(0, 1, battle_blend)) if player.get("expedition") != null else 484.0
	return Rect2(0, 80, 1280, height)


func _draw_location() -> void:
	var region = catalogue.regions[int(player.region)]
	# Unboxed location lettering: offset ink keeps it readable over the panorama.
	draw_string_outline(title_font, Vector2(244, 187), region.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color("12202b"))
	draw_string(title_font, Vector2(244, 185), region.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, GOLD)
	draw_rect(Rect2(244, 195, 42, 3), GOLD)
	draw_rect(Rect2(288, 196, 122, 1), Color(GOLD, 0.6))
	var waypoint = map_data.regions[int(player.region)].waypoints[0]
	for candidate in map_data.regions[int(player.region)].waypoints:
		if fposmod(route_distance, float(map_data.regions[int(player.region)].travel_length)) >= float(candidate.distance):
			waypoint = candidate
	draw_string_outline(font, Vector2(244, 218), waypoint.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 5, Color("12202b"))
	_text(waypoint.name, Vector2(244, 218), 14, INK)

func _draw_caravan() -> void:
	_draw_location()
	for i in range(player.team.size()):
		var c = _creature(player.team[i])
		var x = 226.0 + i * 156.0
		var ground = _ground_at(x + 73.6)
		var travel_scale = lerpf(4.05, 4.6, smoothstep(0, 1, battle_blend))
		var walking = player.expedition != null and (not is_instance_valid(modal) or not modal.visible)
		if int(c.get("current_hp", c.stats.hp)) <= 0:
			continue
		_shadow(Vector2(x + 73.6, ground), 44, 8)
		_sprite(c.species, Vector2(x + 73.6 - travel_scale * 16, ground - travel_scale * 32), travel_scale, c.shiny, false, false, 0.0, 0.0, walking, 1.0, -1, {"key": c.id, "state": "locomotion" if walking else "idle"})
		if player.expedition != null:
			var unit = {"id": c.id, "name": by_id[c.species].name, "level": c.level, "stats": c.stats, "hp": c.get("current_hp", c.stats.hp), "shield": 0}
			_paint_unit_hud(unit, Vector2(x + 73.6, ground), travel_scale * 32, false, false, 1.0, float(unit.hp))
	_draw_journey_progress()

func _draw_journey_progress() -> void:
	var ticks = int(player.expedition.ticks) if player.expedition != null else 0
	menu_chrome.paint_exploration_progress(self,font,icons,Rect2(226,_world_rect().end.y-76,1004,42),ticks,float(player.get("next_tick",20)),int(player.get("distance",0)),player.expedition!=null, fposmod(discovery_meter, 1.0))

func _draw_battle(battle: Dictionary) -> void:
	_draw_location()
	if encounter_director.phase == &"approach":
		_draw_sidebar()
		_draw_journey_progress()
	unit_positions.clear()
	for side in ["allies", "enemies"]:
		for i in range(battle[side].size()):
			var unit = battle[side][i]
			# Reserve the first 200 ms to rise before moving the formation.
			var unit_scale = lerpf(4.05, 4.6, battle_blend)
			var first_enemy = 299.6 + maxf(0, battle.allies.size() - 1) * 156.0 + 260.0
			var foot_x = 299.6 + i * 156.0 if side == "allies" else first_enemy + i * 156.0 + encounter_director.enemy_world_offset
			_paint_fighter(unit, Vector2(foot_x - unit_scale * 16, _ground_at(foot_x) - unit_scale * 32), side == "enemies", unit_scale, false)
	if encounter_director.show_vs:
		var center_x = 299.6 + maxf(0, battle.allies.size() - 1) * 156.0 + 130.0
		var alpha = sin(encounter_director.vs_progress * PI)
		_title("VS", Vector2(center_x - 28, _ground_at(center_x) - 140), 42, Color(GOLD, alpha))
	_draw_combat_choreography(false)
	if battle_blend < 0.95:
		return
	_ornate(Rect2(28, 557, 1224, 132), Color(0.025, 0.05, 0.08, 0.98))
	if battle.get("result") != null and elapsed >= animation_until:
		_title("Vitória" if battle.result == "win" else "Reagrupar", Vector2(49, 596), 28, MINT if battle.result == "win" else RED)
		var rewards = battle.get("rewards", {})
		_text("+" + _coins(float(rewards.get("gold", 0))) + " moedas   +" + str(int(rewards.get("xp", 0))) + " XP", Vector2(50, 626), 18, GOLD)
		var x = 390
		for id in rewards.get("items", {}):
			var material = _material(id)
			_icon(material.get("icon", "spark"), Vector2(x, 580), 32, Color(material.get("color", "ffffff")))
			_text("+" + str(int(rewards.items[id])), Vector2(x + 42, 605), 22, INK)
			_text(material.get("name", id), Vector2(x, 636), 14, MUTED)
			x += 180
		if not player.get("pending_loot", {}).is_empty():
			_text("Mochila cheia · excedentes guardados no inventário", Vector2(50, 666), 15, LILAC)
	else:
		for i in range(battle.allies.size()):
			var unit = battle.allies[i]
			var x = 50 + i * 396
			_icon("spark", Vector2(x, 580), 24)
			_text(unit.name, Vector2(x + 35, 600), 20, MINT)
			_text(by_id[unit.species].skill.name, Vector2(x, 627), 17, INK)
			_text("Pronta" if int(unit.cooldown) == 0 else "Recarga · " + str(int(unit.cooldown)), Vector2(x, 654), 14, GOLD if int(unit.cooldown) == 0 else MUTED)
	if not battle.messages.is_empty():
		_text(str(battle.messages[-1]), Vector2(46, 793), 14, MUTED, 1180)

func _paint_fighter(unit: Dictionary, pos: Vector2, enemy: bool, sprite_scale: float, small: bool) -> void:
	var extent = 32 * sprite_scale
	var center = pos + Vector2(extent * 0.5, extent * 0.52)
	unit_positions[unit.id] = center
	var muzzle_height = -0.05 if unit.species in ["ember", "moss", "tide", "reefclaw", "abyssmaw"] else -0.17
	unit_muzzles[unit.id] = center + Vector2(extent * (-0.31 if enemy else 0.31), extent * muzzle_height)
	var offset = Vector2.ZERO
	var flash = 0.0
	var action_pose = 0.0
	var action_frame = -1
	var approaching = encounter_director.phase == &"approach"
	var animation = {"key": unit.id, "state": "locomotion" if approaching else "stand", "combat": true, "upright": true, "age": 0.0, "walk_clock": not enemy}
	animation.ground_speed = 15.36 * world_speed_multiplier * travel_speed / 24.0 - enemy_step_speed if enemy else 15.36
	for event in combat_sequence:
		var age = elapsed - float(event.started)
		if age < 0 or age > 1.5:
			continue
		if event.actor == unit.id:
			animation.state = "cast" if event.get("skill", false) or event.kind in ["heal", "shield", "guard"] else "attack"
			animation.age = age
			if event.kind == "attack" and action_atlases.has(unit.species):
				action_frame = 1 if age >= 0.27 and age < 0.60 else 2 if age >= 0.60 and age < 0.95 else -1
			if age < 0.2:
				action_pose = -sin(age / 0.2 * PI) * 0.6
			else:
				action_pose = sin(clampf((age - 0.2) / 0.6, 0, 1) * PI)
			if event.kind == "attack":
				offset.x += sin(clampf(age / 0.6, 0, 1) * PI) * (12 if small else 22) * (-1 if enemy else 1)
				# Grounded weight transfer instead of lifting the entire creature.
				action_pose *= 1.1
		if event.target == unit.id and event.kind == "attack" and age > 0.81:
			animation.state = "hurt"
			animation.age = age - 0.81
			var hurt = age - 0.81
			flash = maxf(0, 1 - hurt / 0.16)
			var recoil = sin(clampf(hurt / 0.38, 0, 1) * PI) * exp(-hurt * 4)
			offset.x += recoil * (8 if small else 18) * (1 if enemy else -1)
			action_pose -= recoil * 0.65
	var facing_left = by_id[unit.species].get("sprite_atlas", "") == "enemy"
	var visible_hp = float(displayed_hp.get(unit.id, unit.hp))
	var arrival = clampf((elapsed - float(unit_birth.get(unit.id, elapsed - 1))) / 0.6, 0, 1)
	var death_age = elapsed - float(unit_death.get(unit.id, elapsed + 1))
	var opacity = smoothstep(0, 1, arrival) * (1.0 - clampf(death_age / 0.7, 0, 1))
	var foot = pos + Vector2(extent * 0.5, extent)
	if opacity < 0.002:
		return
	_shadow(foot + Vector2(offset.x, 0), extent * 0.34 * opacity, (5 if small else 9) * opacity)
	if arrival < 1.0:
		_draw_manifestation(foot, arrival, extent, enemy)
	if death_age >= 0:
		for i in range(10):
			var phase = float(i) / 10.0
			var motes = foot + Vector2(sin(phase * TAU + death_age * 2) * extent * 0.35, -extent * phase - death_age * 38)
			draw_circle(motes, 1.5 + phase, Color(LILAC if enemy else MINT, opacity * 0.7), true, -1, true)
	_sprite(unit.species, pos + offset + Vector2(0, (1.0 - arrival) * 8 - maxf(0, death_age) * 9), sprite_scale, unit.shiny, visible_hp <= 0, enemy != facing_left, flash, action_pose, approaching, opacity, action_frame, animation)
	unit_muzzles[unit.id] += offset
	if action_frame >= 0 and action_atlases.has(unit.species):
		var pose_size = _action_pose_size(unit.species, action_frame, extent)
		var muzzle_uv = action_catalogue[unit.species].muzzles[action_frame]
		unit_muzzles[unit.id] = foot + offset + Vector2((float(muzzle_uv[0]) - 0.5) * pose_size.x * (-1 if enemy else 1), (float(muzzle_uv[1]) - 1.0) * pose_size.y)
	_paint_unit_hud(unit, foot, extent, enemy, small, opacity, visible_hp)
	if int(unit.shield) > 0:
		var ward = PackedVector2Array()
		for j in range(13):
			var a = PI * 0.12 + float(j) / 12.0 * PI * 0.76
			ward.append((foot + Vector2(cos(a) * extent * 0.48, -sin(a) * extent * 1.02)).snapped(Vector2(2, 2)))
		draw_polyline(ward, Color(0.6, 0.83, 1.0, opacity * 0.32), 2, false)

func _paint_unit_hud(unit: Dictionary, foot: Vector2, extent: float, enemy: bool, small: bool, opacity: float, hp: float) -> void:
	var width = 96.0 if small else 148.0
	var anchor = foot + Vector2(-width * 0.5, -extent - (25 if small else 36))
	var title = str(unit.name) + "  lvl " + str(int(unit.get("level", 1)))
	var point_size = 12 if small else 16
	var title_width = width if enemy else width - 25
	# Keep name and level together, reserving the inspection eye only for allies.
	while point_size > (10 if small else 12) and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x > title_width:
		point_size -= 1
	draw_string_outline(font, anchor, title, HORIZONTAL_ALIGNMENT_LEFT, title_width, point_size, 4, Color(0.025, 0.04, 0.06, opacity))
	_text(title, anchor, point_size, Color(RED if enemy else GOLD, opacity), title_width)
	var rect = Rect2(anchor + Vector2(0, 10), Vector2(width, 7))
	var ratio = hp / maxf(1, float(unit.stats.hp))
	var trail = float(trailing_hp.get(unit.id, hp)) / maxf(1, float(unit.stats.hp))
	_pixel_hp(rect, ratio, trail, RED if enemy else MINT, opacity)
	if not small:
		var counter = str(maxi(0, roundi(hp))) + " / " + str(int(unit.stats.hp))
		draw_string_outline(font, anchor + Vector2(1, 31), counter, HORIZONTAL_ALIGNMENT_LEFT, width, 11, 3, Color(0.025,0.04,0.06,opacity))
		_text(counter, anchor + Vector2(1,31), 11, Color(INK,opacity))
	if int(unit.get("shield", 0)) > 0:
		_bar(Rect2(anchor + Vector2(0, 20), Vector2(width, 2)), float(unit.shield) / maxf(1,float(unit.stats.hp)*0.6), Color("9dccfa"))

func _draw_manifestation(foot: Vector2, progress: float, extent: float, enemy: bool) -> void:
	var tint = LILAC if enemy else MINT
	var fade = sin(progress * PI) * 0.6
	var oval = PackedVector2Array()
	for j in range(33):
		var angle = float(j) / 32 * TAU
		oval.append(foot + Vector2(cos(angle) * extent * 0.4, sin(angle) * extent * 0.075) * (0.4 + progress * 0.6))
	draw_polyline(oval, Color(tint, fade), 2, true)
	for j in range(7):
		var phase = float(j) / 7
		var p = foot + Vector2(sin(phase * 13) * extent * 0.32, -progress * extent * (0.3 + phase * 0.7))
		draw_circle(p, 1.6, Color(tint, fade), true, -1, true)

func _draw_combat_choreography(small: bool) -> void:
	for event in combat_sequence:
		var age = elapsed - float(event.started)
		if age < 0 or age > 1.9:
			continue
		if not unit_positions.has(event.actor) or not unit_positions.has(event.target):
			continue
		var origin: Vector2 = unit_muzzles.get(event.actor, unit_positions[event.actor]) if event.kind == "attack" else unit_positions[event.actor]
		var target: Vector2 = unit_positions[event.target]
		var kind = "shield" if event.kind == "guard" else event.kind
		if age >= 0.27:
			if not event.has("launch_origin"):
				event.launch_origin = origin
				event.launch_target = target
			origin = event.launch_origin
			target = event.launch_target
		if event.get("skill", false) and age < 0.4:
			var tint = Color(by_id[event.species].get("color", "b9d7f0"))
			var cast_radius = (18 + age * 100) * (0.5 if small else 1.0)
			draw_arc(origin, cast_radius, elapsed * 2, elapsed * 2 + TAU * 0.8, 32, Color(tint, (0.4-age)*2), 2, true)
		var seed = float(absi(str(event.actor).hash()) % 65521)
		effects_painter.paint(self, event.species, origin, target, age, kind, (0.65 if small else 1.15) * (1.35 if event.get("skill", false) else 1.0), event.get("skill", false), seed)
		if int(event.value) > 0 and age >= (0.81 if kind == "attack" else 0.55):
			var color = RED if kind == "attack" else MINT if kind == "heal" else Color("9dccfa")
			effects_painter.paint_damage(self, font, ("-" if kind == "attack" else "+") + str(int(event.value)), target + Vector2(0, -38), age - (0.81 if kind == "attack" else 0.55), color, event.get("critical", false), 18 if small else 26, seed)


func _draw_card(index: int) -> void:
	var x = 212 + index * 348
	var card = Rect2(x, 568, 332, 188)
	_panel(card, Color("0c1b27"), Color("526164"), 8)
	if index >= player.team.size():
		_icon("star", Vector2(x + 149, 620), 34, MUTED)
		_text("Companheiro", Vector2(x + 108, 680), 16, MUTED)
		return
	var c = _creature(player.team[index])
	var spec = by_id[c.species]
	var tint = Color(spec.color)
	_panel(Rect2(x + 14, 584, 110, 140), Color(tint, 0.065), Color(tint, 0.22), 8)
	_sprite(c.species, Vector2(x + 17, 590), 3.25, c.shiny, false)
	_text(spec.name, Vector2(x + 139, 607), 21, tint)
	var name_width = font.get_string_size(spec.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
	_text("lvl " + str(int(c.level)), Vector2(x + 151 + name_width, 607), 14, GOLD)
	_icon(_role_icon(spec.role), Vector2(x + 140, 623), 16)
	_text(_role_name(spec.role), Vector2(x + 165, 637), 14, INK)
	_bar(Rect2(x + 140, 689, 173, 5), float(c.xp) / maxf(1, float(c.next_xp)), LILAC)
	_text(str(int(c.xp)) + " / " + str(int(c.next_xp)) + " XP", Vector2(x + 140, 716), 12, MUTED)
	if c.get("upgrade_job") != null:
		_icon("upgrade", Vector2(x + 288, 578), 16, MINT)

func _rarity(id: String) -> Dictionary:
	for r in catalogue.rarities:
		if r.id == id:
			return r
	return catalogue.rarities[0]

func _draw_banner() -> void:
	if banner_time > 0:
		_ornate(Rect2(350, 170 if player.get("battle") != null else 225, 840, 32), Color(0.025, 0.06, 0.09, 0.94))
		_text(banner, Vector2(362, 192 if player.get("battle") != null else 247), 14, GOLD, 814)

func _draw_compact() -> void:
	_draw_world(Rect2(0, 0, 1280, 250))
	_ornate(Rect2(12, 12, 300, 60), Color(0.025, 0.05, 0.08, 0.92))
	_text("TaskMon", Vector2(28, 38), 22, GOLD)
	_text(str(int(player.get("gear_score", 0))) + " GS · " + _coins(float(player.gold)), Vector2(28, 60), 15, MINT)
	var battle = player.get("battle")
	if battle != null:
		unit_positions.clear()
		for side in ["allies", "enemies"]:
			for i in range(battle[side].size()):
				var x = (355 if side == "allies" else 842) + i * 108
				_paint_fighter(battle[side][i], Vector2(x, _ground_at(x + 44.8) - 89.6), side == "enemies", 2.8, true)
		_draw_combat_choreography(true)
	else:
		for i in range(player.team.size()):
			var c = _creature(player.team[i])
			var x = 562 + i * 158
			var ground = _ground_at(x + 48)
			_shadow(Vector2(x + 48, ground), 35, 6)
			_sprite(c.species, Vector2(x, ground - 96), 3.0, c.shiny, false, false, 0.0, 0.0, player.expedition != null)
	_text(catalogue.regions[int(player.region)].name, Vector2(350, 39), 18, GOLD)
	if battle != null:
		_text("Vitória" if battle.get("result") == "win" else "Combate", Vector2(350, 62), 14, MINT)

func _dialog(title: String, dimensions: Vector2i = Vector2i(720, 500)) -> AcceptDialog:
	if is_instance_valid(modal):
		modal.hide()
		modal.queue_free()
	var dialog = AcceptDialog.new()
	dialog.theme = theme
	dialog.title = title
	dialog.min_size = dimensions
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	dialog.add_theme_stylebox_override("panel", _style(Color("102332"), Color("9e875e"), 3))
	dialog.add_theme_font_override("title_font", title_font)
	dialog.add_theme_font_size_override("title_font_size", 22)
	dialog.ok_button_text = "Fechar"
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	modal = dialog
	modal_kind = ""
	menu_chrome.decorate_dialog(dialog,title,font,title_font,icons.close,_region_texture(int(player.get("region",0))))
	return dialog

func _content(dialog: AcceptDialog) -> VBoxContainer:
	return menu_chrome.content(dialog)

func _label(text: String, parent: Node, size_px: int = 15, color: Color = INK) -> Label:
	var label = Label.new()
	label.add_theme_font_override("font", font)
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _collection_dialog(slot: int) -> void:
	var dialog = _dialog("Companheiros · formação " + str(slot + 1), Vector2i(1060, 690))
	var box = _content(dialog)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	for c in player.collection:
		var spec = by_id[c.species]
		var tile = _tile(grid, Color(_rarity(c.rarity).color))
		tile.custom_minimum_size.x = 305
		_image_control(_portrait(c.species), Vector2(240, 126), tile)
		_label(spec.name + "  +" + str(int(c.get("upgrade", 0))), tile, 23, Color(spec.color))
		_role_controls(spec, tile)
		_label("Nv." + str(int(c.level)) + "  ·  " + str(int(c.get("gear_score", 0))) + " GS  ·  " + _rarity(c.rarity).name, tile, 16, GOLD)
		_stats_controls(c.stats, tile)
		_modal_button("Equipar" if not c.id in player.team else "Na equipe", tile, _choose_creature.bind(c.id, slot, dialog), not c.id in player.team)
		_modal_button("Detalhes", tile, _creature_dialog.bind(c.id), false, "upgrade")
	dialog.popup_centered(Vector2i(1060, 690))

func _choose_creature(id: String, slot: int, dialog: AcceptDialog) -> void:
	if player.get("battle") != null:
		_notice("Troque sua equipe depois da batalha.")
		return
	var team: Array = player.team.duplicate()
	if id in team:
		var old = team.find(id)
		if slot < team.size():
			var replacement = team[slot]
			team[slot] = id
			team[old] = replacement
	else:
		if slot < team.size():
			team[slot] = id
		else:
			team.append(id)
	dialog.queue_free()
	_action("team", {"ids": team})

func _journal_dialog() -> void:
	var dialog = _dialog("Diário de viagem", Vector2i(780, 530))
	var box = _content(dialog)
	for line in player.log:
		_label("• " + str(line), box)
	if player.get("battle") != null:
		_label("BATALHA ATUAL", box, 18, GOLD)
		for line in player.battle.messages:
			_label(str(line), box, 14, MUTED)
	dialog.popup_centered(Vector2i(780, 530))

func _help_dialog() -> void:
	var dialog = _dialog("Guia da caravana", Vector2i(790, 540))
	var box = _content(dialog)
	_label("1. Escolha uma rota e parta. Inimigos abatidos concedem moedas, XP e materiais. A viagem aberta também permite descobertas de criaturas.", box)
	_label("2. Combine atacante + tanque + suporte. O tanque atrai parte dos ataques; o suporte cura o aliado mais ferido. Habilidades têm recarga.", box)
	_label("3. Em PvE, cada clique resolve um turno da equipe. Atacar poupa habilidades; Habilidade usa poderes disponíveis; Proteger gera escudos. Auto decide sozinho.", box)
	_label("4. Vença chefes para abrir regiões. A vida permanece entre encontros; uma derrota total encerra a jornada. Aprimore com materiais de abates: atributos, passiva e ativa. O tempo cresce a cada grau.", box)
	_label("5. Arena: desafie a defesa de outra conta. Poder normalizado no nível 5, sem bônus de raridade ou individuais. Treino PvP não vale pontos.", box)
	_label("6. Progresso AFK exige o jogo aberto. Ao fechar, a expedição para de gerar recursos. Aprimoramentos já iniciados continuam contando seu prazo.", box)
	_label("Para testar dois jogadores: crie outra caravana em Conexão e alterne entre as caravanas salvas. Desafie a primeira equipe na Arena. Amigos Steam e duelos ao vivo ficam para uma próxima versão.", box, 14, MUTED)
	dialog.popup_centered(Vector2i(790, 540))

func _show_leaderboard() -> void:
	var dialog = _dialog("Arena • liga local e Hall da Fama", Vector2i(800, 570))
	var box = _content(dialog)
	_label("Desafios assíncronos: você enfrenta a defesa automática. Mesma criatura, mesmo poder base. Duelo não exige outro jogador conectado.", box, 14, MUTED)
	for entry in leaderboard.get("players", []):
		var row = HBoxContainer.new()
		box.add_child(row)
		_label(str(int(entry.rank)) + ". " + entry.name + "  ·  " + str(int(entry.rating)) + " pts  ·  " + str(int(entry.wins)) + "V / " + str(int(entry.losses)) + "D", row)
		if entry.id != player.id:
			var button = Button.new()
			button.text = "Desafiar"
			button.pressed.connect(_challenge.bind(entry.id, dialog))
			row.add_child(button)
	_label("HALL DA FAMA — EXPLORADORES", box, 19, GOLD)
	if leaderboard.get("hall", []).is_empty():
		_label("Os primeiros vencedores de chefes aparecerão aqui.", box, 14, MUTED)
	for entry in leaderboard.get("hall", []):
		_label(entry.name + " — " + str(int(entry.bosses)) + "/3 chefes", box)
	_label("Liga de protótipo local. Temporadas, moderação e proteção avançada contra contas de abuso ficam para a versão online.", box, 13, MUTED)
	dialog.popup_centered(Vector2i(800, 570))

func _challenge(id: String, dialog: AcceptDialog) -> void:
	dialog.queue_free()
	_action("duel", {"opponent": id})

func _connection_dialog() -> void:
	var dialog = _dialog("Conexão e caravanas", Vector2i(720, 460))
	var box = _content(dialog)
	_label("Servidor local padrão: http://127.0.0.1:8787. Para hospedagem futura, use HTTPS.", box, 14)
	var input = LineEdit.new()
	input.text = server_url
	box.add_child(input)
	var connect_button = Button.new()
	connect_button.text = "Salvar e reconectar"
	connect_button.pressed.connect(_change_server.bind(input, dialog, false))
	box.add_child(connect_button)
	var fresh = Button.new()
	fresh.text = "Criar outra caravana neste servidor"
	fresh.pressed.connect(_change_server.bind(input, dialog, true))
	box.add_child(fresh)
	_label("CARAVANAS SALVAS NESTE COMPUTADOR", box, 14, MINT)
	var profiles = settings.get_value(_session_section(), "profiles", {})
	for id in profiles:
		var profile_button = Button.new()
		profile_button.text = profiles[id].name + "  #" + str(id).left(6)
		profile_button.pressed.connect(_switch_profile.bind(profiles[id].token, dialog))
		box.add_child(profile_button)
	_label("Contas locais usam uma chave salva neste computador. Não compartilhe connection.cfg. O banco fica na pasta server/data.", box, 12, MUTED)
	dialog.popup_centered(Vector2i(720, 460))

func _switch_profile(saved_token: String, dialog: AcceptDialog) -> void:
	if busy:
		_notice("Aguarde a solicitação atual.")
		return
	token = saved_token
	player = {}
	auto_battle = false
	last_signature = ""
	_save_settings()
	dialog.queue_free()
	_build_ui()
	_api("/api/state", {}, "state")

func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	_build_ui()

func _play_sound(kind: String) -> void:
	if sound_enabled:
		sound_player.stream = load("res://assets/" + kind + ".wav")
		sound_player.play()

func _animate_round(previous: Dictionary, current: Dictionary) -> void:
	combat_sequence.clear()
	visual_hp.clear()
	for side in ["allies", "enemies"]:
		for unit in previous[side]:
			visual_hp[unit.id] = float(unit.hp)
			displayed_hp[unit.id] = float(unit.hp)
	var sequence_index = 0
	var last_actor = ""
	for event in current.get("events", []):
		var visual = event.duplicate()
		var same_actor = str(event.actor) == last_actor
		visual.started = elapsed + (sequence_index - 1 if same_actor else sequence_index) * 1.0
		visual.sound_owner = not same_actor
		visual.applied = false
		combat_sequence.append(visual)
		if not same_actor:
			sequence_index += 1
		last_actor = str(event.actor)
	animation_until = elapsed + maxf(1.9, (sequence_index - 1) * 1.0 + 1.9)

func _change_server(input: LineEdit, dialog: AcceptDialog, fresh: bool) -> void:
	if busy:
		_notice("Aguarde a solicitação atual e tente novamente.")
		return
	var target = input.text.strip_edges().trim_suffix("/")
	if not (target.begins_with("https://") or target.begins_with("http://127.0.0.1:") or target.begins_with("http://localhost:")):
		_notice("Use HTTPS ou HTTP no servidor local (127.0.0.1/localhost).")
		return
	server_url = target
	token = "" if fresh else settings.get_value(_session_section(), "token", "")
	player = {}
	auto_battle = false
	compact = false
	get_window().always_on_top = false
	get_window().borderless = false
	get_window().content_scale_size = Vector2i(1280, 800)
	get_window().size = Vector2i(1280, 800)
	last_signature = ""
	_save_settings()
	dialog.queue_free()
	_build_ui()
	_api("/health" if token.is_empty() else "/api/state", {}, "health" if token.is_empty() else "state")

func _decorate_button(button: Button, primary: bool = false) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.clip_contents = false
	# Keep identical inner bounds across focus, hover and pressed states.
	button.add_theme_constant_override("align_to_largest_stylebox", 0)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if button.text.is_empty() else HORIZONTAL_ALIGNMENT_LEFT
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("h_separation", 0 if button.text.is_empty() else 8)
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_pressed_color", Color("fff1cb"))
	button.add_theme_color_override("font_disabled_color", Color("72818c"))
	var normal_skin = _button_skin(primary)
	if button.text.is_empty():
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			normal_skin.set_content_margin(side, 4)
	button.add_theme_stylebox_override("normal", normal_skin)
	for state in ["hover", "pressed", "disabled", "focus"]:
		var state_skin = _button_skin(primary or state == "focus")
		if button.text.is_empty():
			for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
				state_skin.set_content_margin(side, 4)
		state_skin.modulate_color = Color(1.2, 1.17, 1.08) if state == "hover" else Color(0.72, 0.83, 0.89) if state == "pressed" else Color(0.47, 0.5, 0.53) if state == "disabled" else Color.WHITE
		button.add_theme_stylebox_override(state, state_skin)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_entered.connect(_button_feedback.bind(button, Color(1.06, 1.06, 1.04), 0.12))
	button.mouse_exited.connect(_button_feedback.bind(button, Color.WHITE, 0.16))
	button.button_down.connect(_button_feedback.bind(button, Color(0.85, 0.91, 0.94), 0.06))
	button.button_up.connect(_button_feedback.bind(button, Color.WHITE, 0.12))

func _button_feedback(button: Button, tint: Color, duration: float) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	var previous = button.get_meta("feedback_tween") if button.has_meta("feedback_tween") else null
	if previous != null and previous.is_valid():
		previous.kill()
	var feedback = button.create_tween()
	feedback.tween_property(button, "modulate", tint, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	button.set_meta("feedback_tween", feedback)

func _button_skin(primary: bool) -> StyleBoxTexture:
	var skin = StyleBoxTexture.new()
	skin.texture = load("res://assets/ui/button-gold.svg" if primary else "res://assets/ui/button-blue.svg")
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		skin.set_texture_margin(side, 12)
		skin.set_content_margin(side, 10 if side < 2 else 5)
	return skin

func _pixel_hp(rect: Rect2, ratio: float, trail: float, tint: Color, opacity: float) -> void:
	var r = Rect2(rect.position.round(), rect.size.round())
	# Two orthogonal rectangles form clipped, two-pixel corners with no smoothing.
	draw_rect(Rect2(r.position + Vector2(-2, -4), r.size + Vector2(4, 8)), Color("09131f", opacity))
	draw_rect(Rect2(r.position + Vector2(-4, -2), r.size + Vector2(8, 4)), Color("09131f", opacity))
	draw_rect(Rect2(r.position + Vector2(-2, -2), r.size + Vector2(4, 4)), Color("697d83", opacity))
	draw_rect(r, Color("172331", opacity))
	var width = floorf(r.size.x * clampf(ratio, 0, 1) / 2) * 2
	var damage_width = floorf(r.size.x * clampf(trail, 0, 1) / 2) * 2
	draw_rect(Rect2(r.position, Vector2(damage_width, r.size.y)), Color(GOLD, opacity * 0.8))
	if width > 0:
		draw_rect(Rect2(r.position, Vector2(width, r.size.y)), Color(tint.darkened(0.28), opacity))
		draw_rect(Rect2(r.position, Vector2(width, maxf(2, r.size.y - 3))), Color(tint, opacity))
		draw_rect(Rect2(r.position, Vector2(width, 2)), Color(tint.lightened(0.4), opacity))
	for i in range(1, 5):
		var x = r.position.x + floorf(r.size.x * i / 5.0)
		draw_rect(Rect2(x, r.position.y + r.size.y - 3, 1, 3), Color("09131f", opacity * 0.65))

func _draw_gear_badge(pos: Vector2, score: int) -> void:
	menu_chrome.paint_gear_score(self, font, pos, score)

func _icon(id: String, pos: Vector2, extent: float = 22, tint: Color = Color.WHITE) -> void:
	if icons.has(id):
		draw_texture_rect(icons[id], Rect2(pos, Vector2.ONE * extent), false, tint)

func _role_icon(role: String) -> String:
	return "shield" if role == "Tanque" else "heart" if role == "Suporte" else "sword"

func _role_name(role: String) -> String:
	return "Tank" if role == "Tanque" else role

func _draw_stats(values: Dictionary, pos: Vector2, spacing: float = 55, font_size: int = 16) -> void:
	var keys = ["hp", "attack", "defense", "speed"]
	var symbols = ["heart", "sword", "shield", "boot"]
	for i in range(4):
		_icon(symbols[i], pos + Vector2(i * spacing, 0), 15)
		_text(str(int(values.get(keys[i], 0))), pos + Vector2(i * spacing + 18, 14), font_size, INK)

func _shadow(pos: Vector2, width: float, height: float) -> void:
	for i in range(3):
		draw_set_transform(pos, 0, Vector2(width * (1.0 - i * 0.18), height * (1.0 - i * 0.16)))
		draw_circle(Vector2.ZERO, 1, Color(0.01, 0.015, 0.025, 0.15))
		draw_set_transform(Vector2.ZERO)

func _cache_sprite_regions() -> void:
	for id in by_id:
		var spec = by_id[id]
		var enemy = spec.get("sprite_atlas", "") == "enemy"
		var sheet = enemy_atlas if enemy else detailed_atlas
		if sheet == null:
			continue
		var index = int(spec.sprite)
		var cell = sheet.get_size() / Vector2(3, 3 if enemy else 2)
		var source = Rect2i(Vector2(index % 3, index / 3) * cell, cell)
		# The original atlas has a few Marulito pixels inside Pedrume's cell.
		# Trim only the empty left gutter; retain every crystal and body pixel.
		if id == "crag":
			source.position.x += 56
			source.size.x -= 56
		if enemy:
			var boundaries = [0, int(sheet.get_height() / 3.0), int(sheet.get_height() * 0.6395), sheet.get_height()]
			var row = int(index / 3)
			source.position.y = boundaries[row]
			source.size.y = boundaries[row + 1] - boundaries[row]
		var image = sheet.get_image().get_region(source)
		var used = image.get_used_rect()
		if used.size.x > 0:
			source = Rect2i(source.position + used.position, used.size)
		sprite_regions[id] = source

func _portrait(id: String) -> AtlasTexture:
	var portrait = AtlasTexture.new()
	portrait.atlas = enemy_atlas if by_id[id].get("sprite_atlas", "") == "enemy" else detailed_atlas
	portrait.set_meta("creature_id", id)
	portrait.region = sprite_regions.get(id, Rect2(0, 0, 32, 32))
	return portrait

func _duration(seconds: float) -> String:
	var total = maxi(0, ceili(seconds))
	return str(int(total / 60)) + ":" + str(total % 60).pad_zeros(2)

func _update_timer_labels() -> void:
	for label in get_tree().get_nodes_in_group("upgrade_timers"):
		label.text = "Aprimorando · " + _duration(float(label.get_meta("deadline")) / 1000.0 - server_now)
		var total = float(label.get_meta("duration", 60.0))
		var progress = label.get_meta("progress", null)
		if is_instance_valid(progress):
			progress.value = clampf(1.0 - (float(label.get_meta("deadline")) / 1000.0 - server_now) / total, 0, 1) * 100

func _material(id: String) -> Dictionary:
	for item in player.get("materials_catalogue", []):
		if item.id == id:
			return item
	return {}

func _modal_button(text: String, parent: Node, callback: Callable, primary: bool = false, icon_id: String = "") -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(42 if text.is_empty() else 0, 42)
	_decorate_button(button, primary)
	if icons.has(icon_id):
		button.icon = icons[icon_id]
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 22)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _image_control(texture: Texture2D, extent: Vector2, parent: Node) -> TextureRect:
	var image = TextureRect.new()
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image.clip_contents = false
	if texture != null and texture.has_meta("creature_id"):
		image.set_script(preload("res://scripts/portrait_motion.gd"))
		image.set("species_id", str(texture.get_meta("creature_id")))
	image.texture = texture
	image.custom_minimum_size = extent
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _stats_controls(values: Dictionary, parent: Node) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var keys = ["hp", "attack", "defense", "speed"]
	var names = ["Vida", "Ataque", "Defesa", "Velocidade"]
	var symbols = ["heart", "sword", "shield", "boot"]
	for i in range(4):
		var image = _image_control(icons[symbols[i]], Vector2(20, 22), row)
		image.mouse_filter = Control.MOUSE_FILTER_STOP
		image.tooltip_text = names[i]
		_label(str(int(values.get(keys[i], 0))), row, 16)

func _role_controls(spec: Dictionary, parent: Node) -> void:
	var row = HBoxContainer.new()
	parent.add_child(row)
	_image_control(icons[_role_icon(spec.role)], Vector2(22, 22), row)
	_label(_role_name(spec.role) + " · " + spec.element, row, 17, Color(spec.color))

func _tile(parent: Node, tint: Color = GOLD) -> VBoxContainer:
	var panel = PanelContainer.new()
	var surface = _style(Color(0.025, 0.055, 0.085, 0.95), Color(tint, 0.6), 8)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		surface.set_content_margin(side, 0)
	panel.add_theme_stylebox_override("panel", surface)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	return box

func _refresh_modal() -> void:
	if not is_instance_valid(modal) or not modal.visible:
		return
	var kind = modal_kind
	modal.hide()
	modal.queue_free()
	match kind:
		"inventory": _inventory_dialog()
		"creature": _creature_dialog(detail_id)
		"profile": _profile_dialog()

func _inventory_dialog() -> void:
	menu_chrome.build_inventory(self)

func _creature_dialog(id: String) -> void:
	menu_chrome.build_creature_card(self,id)

func _profile_dialog() -> void:
	var dialog = _dialog("Perfil do explorador", Vector2i(920, 680))
	modal_kind = "profile"
	var box = _content(dialog)
	var hero = _tile(box, GOLD)
	_label(player.name, hero, 34, GOLD)
	_label(str(int(player.get("gear_score", 0))) + "  GEAR SCORE", hero, 36, MINT)
	_label("Poder da equipe equipada · atributos + aprimoramentos", hero, 14, MUTED)
	_label(str(player.collection.size()) + " criaturas   ·   " + str(int(player.get("distance", 0))) + " m   ·   " + str(int(player.get("encounters", 0))) + " vitórias PvE", hero, 18)
	_label("Liga " + str(int(player.rating)) + "   ·   " + str(int(player.wins)) + " V / " + str(int(player.losses)) + " D   ·   " + str(player.bosses.size()) + "/3 chefes", hero, 18, LILAC)
	var team = HBoxContainer.new()
	box.add_child(team)
	for id in player.team:
		var c = _creature(id)
		var tile = _tile(team, Color(by_id[c.species].color))
		_image_control(_portrait(c.species), Vector2(140, 100), tile)
		_label(by_id[c.species].name, tile, 18)
		_label(str(int(c.get("gear_score", 0))) + " GS", tile, 20, GOLD)
	_label("CONQUISTAS", box, 22, GOLD)
	for achievement in player.get("achievements", []):
		var row = HBoxContainer.new()
		box.add_child(row)
		_image_control(icons["trophy"], Vector2(28, 28), row).modulate = Color.WHITE if achievement.unlocked else Color(0.4, 0.4, 0.5)
		_label(achievement.name + " · " + achievement.description, row, 17, GOLD if achievement.unlocked else MUTED)
		_label(str(int(achievement.progress)) + "/" + str(int(achievement.target)), row, 16, MINT)
	dialog.popup_centered(Vector2i(920, 680))

func _maps_dialog() -> void:
	var dialog = _dialog("Atlas de expedições", Vector2i(1040, 620))
	var box = _content(dialog)
	_label("Poder da equipe · " + str(int(player.get("gear_score", 0))) + " GS", box, 22, GOLD)
	var grid = HBoxContainer.new()
	grid.add_theme_constant_override("separation", 14)
	box.add_child(grid)
	for i in range(3):
		var region = catalogue.regions[i]
		var tile = _tile(grid, Color(region.color))
		tile.add_theme_constant_override("separation", 8)
		tile.custom_minimum_size.x = 272
		var preview = AtlasTexture.new()
		preview = _region_texture(i)
		_image_control(preview, Vector2(250, 112), tile).stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var region_title = _label(region.name, tile, 22, Color(region.color))
		region_title.custom_minimum_size.y = 48
		var stars = HBoxContainer.new()
		tile.add_child(stars)
		for j in range(3):
			_image_control(icons["star"], Vector2(24, 24), stars).modulate = Color.WHITE if j < int(region.stars) else Color(0.3, 0.3, 0.3)
		_label(str(int(region.recommended_gs)) + " GS recomendado", tile, 18, MINT if int(player.get("gear_score", 0)) >= int(region.recommended_gs) else GOLD)
		_label("Chefe · " + str(int(region.boss_gs)) + " GS", tile, 16, RED)
		var description = _label(map_data.regions[i].theme, tile, 16, MUTED)
		description.custom_minimum_size.y = 48
		_label("MATERIAIS", tile, 14, GOLD)
		_label(["Fibra ancestral", "Pérola de maré", "Fragmento lunar"][i], tile, 17, INK)
		var spacer = Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile.add_child(spacer)
		var select = _modal_button("Explorar" if i <= int(player.unlocked) else "Selada", tile, _start_map.bind(i, dialog), true, "play")
		select.disabled = i > int(player.unlocked) or player.get("battle") != null
		select.tooltip_text = "Vença o chefe anterior para liberar esta rota. GS recomendado; a composição também importa."
	dialog.popup_centered(Vector2i(1040, 620))

func _start_map(region: int, dialog: AcceptDialog) -> void:
	selected_region = region
	dialog.queue_free()
	_action("route", {"region": region})

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if compact:
			_toggle_compact()
		elif is_instance_valid(modal) and modal.visible:
			modal.hide()
			modal.queue_free()

func _draw_creature_mesh(sheet: Texture2D, source: Rect2, target: Rect2, id: String, frozen: bool, tint: Color, action_pose: float = 0.0, locomotion: bool = false, animation: Dictionary = {}) -> void:
	var key = str(animation.get("key", id + str(target.position)))
	animation.seed = float(absi(key.hash()) % 65521)
	if not animation.has("ground_speed"):
		# walk_clock already integrates the shared speed multiplier. The stride
		# uses its reference speed to avoid applying acceleration twice.
		animation.ground_speed = 24.0 * 0.64
	var motion_time = walk_clock if locomotion and (not animation.get("combat", false) or animation.get("walk_clock", false)) else elapsed
	creature_motion.paint(self, sheet, source, target, id, motion_time, locomotion, frozen, tint, action_pose, animation)

func _play_creature_sound(id: String, kind: String) -> void:
	if not sound_enabled or sound_channels.is_empty():
		return
	var path = "res://assets/audio/" + id + "_" + kind + ".wav"
	if ResourceLoader.exists(path):
		var channel = sound_channels[sound_channel_index % sound_channels.size()]
		sound_channel_index += 1
		channel.stream = load(path)
		channel.play()

func _region_texture(index: int) -> AtlasTexture:
	var result = AtlasTexture.new()
	if regional_worlds.size() > index and regional_worlds[index] != null:
		result.atlas = regional_worlds[index]
		result.region = Rect2(Vector2.ZERO, result.atlas.get_size())
	else:
		result.atlas = world_atlas
		result.region = Rect2(0, index * world_atlas.get_height() / 3.0, world_atlas.get_width(), world_atlas.get_height() / 3.0)
	return result

func _toggle_route_auto() -> void:
	route_auto = not route_auto
	auto_battle = route_auto
	wave_elapsed = 0
	_build_ui()

func _cache_action_poses() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/creature_animations.json"))
	if not data is Dictionary:
		return
	action_catalogue = data
	for id in data:
		var spec = data[id]
		var sheet: Texture2D = load(spec.texture)
		if sheet == null:
			continue
		action_atlases[id] = sheet
		action_regions[id] = []
		var cell = sheet.get_size() / Vector2(int(spec.columns), int(spec.rows))
		var image = sheet.get_image()
		for i in range(spec.frames.size()):
			var region = Rect2i(Vector2(i % int(spec.columns), i / int(spec.columns)) * cell, cell)
			var used = image.get_region(region).get_used_rect()
			action_regions[id].append(Rect2(region.position + used.position, used.size))

func _action_pose_size(id: String, frame: int, extent: float) -> Vector2:
	var base: Rect2 = sprite_regions[id]
	var reference: Rect2 = action_regions[id][int(action_catalogue[id].reference_frame)]
	var source: Rect2 = action_regions[id][clampi(frame, 0, 3)]
	var height = extent * base.size.y / maxf(base.size.x, base.size.y)
	return source.size * height / maxf(1.0, reference.size.y)
