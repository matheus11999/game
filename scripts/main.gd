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
var enemy_atlas: Texture2D
var world_painter = preload("res://scripts/world_painter.gd").new()
var effects_painter = preload("res://scripts/combat_effects.gd").new()
var route_distance = 0.0
var compact_auto = true
var wave_elapsed = 0.0
var combat_sequence: Array = []
var unit_positions: Dictionary = {}
var pending_requests: Array = []
var ui: Control
var http: HTTPRequest
var name_input: LineEdit
var settings: ConfigFile
var last_signature = ""
var sound_enabled = true
var sound_player: AudioStreamPlayer
var battle_fx: Dictionary = {}
var displayed_hp: Dictionary = {}

func _ready() -> void:
	font = load("res://assets/fonts/PixelifySans.ttf")
	title_font = load("res://assets/fonts/CinzelDecorative.ttf")
	var game_theme = Theme.new()
	game_theme.default_font = font
	game_theme.default_font_size = 17
	theme = game_theme
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
	catalogue = JSON.parse_string(FileAccess.get_file_as_string(CATALOGUE_PATH))
	for item in catalogue.species:
		by_id[item.id] = item
	var enemy_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/enemies.json"))
	for item in enemy_data.species:
		by_id[item.id] = item
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
	http = HTTPRequest.new()
	http.timeout = 6.0
	http.request_completed.connect(_request_completed)
	add_child(http)
	sound_player = AudioStreamPlayer.new()
	sound_player.volume_db = -16
	add_child(sound_player)
	_build_ui()
	if token.is_empty():
		_api("/health", {}, "health")
	else:
		_api("/api/state", {}, "state")
	set_process(true)

func _session_section() -> String:
	return "session_" + server_url.sha256_text().left(12)

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
	poll_elapsed += delta
	draw_elapsed += delta
	wave_elapsed += delta
	var exploring = not player.is_empty() and player.get("expedition") != null
	if exploring and player.get("battle") == null:
		route_distance += delta * 24.0
	banner_time = maxf(0, banner_time - delta)
	var interval = 0.5 if get_window().mode == Window.MODE_MINIMIZED else 1.0 / 60.0
	if draw_elapsed >= interval:
		draw_elapsed = 0
		queue_redraw()
	if player.get("battle") != null:
		for side in ["allies", "enemies"]:
			for unit in player.battle[side]:
				displayed_hp[unit.id] = lerpf(float(displayed_hp.get(unit.id, unit.hp)), float(unit.hp), 1.0 - exp(-delta * 10.0))
	if busy:
		return
	if not pending_requests.is_empty():
		var next = pending_requests.pop_front()
		_api(next.path, next.data, next.context)
		return
	if compact and compact_auto and exploring:
		var active = player.get("battle")
		if active == null and wave_elapsed > 3.0:
			wave_elapsed = 0
			auto_battle = true
			_action("battle", {"kind": "wild"})
			return
		if active != null and active.get("result") != null and wave_elapsed > 2.0:
			wave_elapsed = 0
			_action("close_battle")
			return
	if auto_battle and not player.is_empty() and player.get("battle") != null:
		if player.battle.get("result") != null:
			auto_battle = false
		elif poll_elapsed >= 1.35:
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
		_notice("O endereço não respondeu como um servidor Brumora.")
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
		var previous_id = str(player.get("id", ""))
		var previous_distance = float(player.get("distance", 0))
		var previous_battle = player.get("battle")
		var previous_round = int(player.get("battle", {}).get("round", -1)) if player.get("battle") != null else -1
		player = response.player
		if str(player.id) != previous_id:
			route_distance = float(player.get("distance", 0))
			selected_region = int(player.region)
		else:
			route_distance += maxf(0, float(player.get("distance", 0)) - previous_distance)
		if previous_battle != null and previous_battle.get("result") == null and player.get("battle") != null and player.battle.get("result") != null:
			wave_elapsed = 0
		if player.get("battle") != null and previous_battle != null and int(player.battle.round) > previous_round:
			_animate_round(previous_battle, player.battle)
		elif player.get("battle") == null:
			battle_fx.clear()
			displayed_hp.clear()
			combat_sequence.clear()
			unit_positions.clear()
		if request_context == "register":
			_save_settings()
		if player.get("battle") != null and int(player.battle.round) > previous_round and previous_round >= 0:
			_play_sound("win" if player.battle.get("result") == "win" else "turn")
		if request_context == "register":
			selected_region = int(player.region)
			_notice("Sua caravana está pronta. Parta em expedição!")
		var signature = str(player.team) + str(player.collection.size()) + str(player.get("battle")) + str(player.gold) + str(player.region) + str(player.get("expedition") != null)
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
	var data = {"op": op}
	data.merge(args)
	_api("/api/action", data, "action")

func _style(color: Color, border_color: Color = Color.TRANSPARENT, radius: int = 12) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(1 if border_color.a > 0 else 0)
	style.set_corner_radius_all(mini(radius, 4))
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style

func _button(text: String, rect: Rect2, callback: Callable, primary: bool = false, tip: String = "") -> Button:
	var button = Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", BG if primary else INK)
	button.add_theme_color_override("font_hover_color", BG if primary else INK)
	button.add_theme_color_override("font_pressed_color", BG if primary else INK)
	button.add_theme_stylebox_override("normal", _style(Color("c39b60") if primary else Color("172c35"), Color("f2d69b") if primary else Color("536568"), 3))
	button.add_theme_stylebox_override("hover", _style(Color("edc987") if primary else Color("2d464b"), GOLD, 3))
	button.add_theme_stylebox_override("pressed", _style(Color("9b7848") if primary else Color("20363c"), GOLD, 3))
	button.add_theme_stylebox_override("disabled", _style(PANEL_LIGHT))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, MINT))
	button.tooltip_text = tip
	button.pressed.connect(callback)
	ui.add_child(button)
	return button

func _build_ui() -> void:
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	if not compact:
		_button("Caravanas", Rect2(1112, 26, 140, 38), _connection_dialog)
	if player.is_empty():
		name_input = LineEdit.new()
		name_input.position = Vector2(450, 211)
		name_input.size = Vector2(380, 44)
		name_input.placeholder_text = "Seu nome de viajante"
		name_input.max_length = 20
		name_input.add_theme_stylebox_override("normal", _style(Color(0.05, 0.12, 0.16, 0.9), Color("b29465"), 3))
		name_input.add_theme_font_size_override("font_size", 18)
		name_input.add_theme_color_override("font_color", INK)
		ui.add_child(name_input)
		for i in range(3):
			var id = catalogue.species[i].id
			_button("Escolher " + catalogue.species[i].name, Rect2(165 + i * 338, 624, 274, 46), _register.bind(id), true)
		return
	if compact:
		_button("Expandir", Rect2(1100, 20, 150, 38), _toggle_compact)
		_button("Pausar" if player.expedition != null else "Explorar", Rect2(20, 183, 155, 38), _pause_or_explore, true)
		_button("Auto batalhas " + ("ON" if compact_auto else "OFF"), Rect2(187, 183, 206, 38), _toggle_compact_auto)
		_button("Assumir", Rect2(404, 183, 130, 38), _toggle_compact)
		return
	_button("Modo rodapé", Rect2(947, 26, 152, 38), _toggle_compact, false, "Janela compacta e sempre visível. Pode ser movida; não altera a barra do sistema.")
	for i in range(3):
		var region = catalogue.regions[i]
		var label = region.name if i <= int(player.unlocked) else "Bloqueada • chefe anterior"
		var button = _button(label, Rect2(308 + i * 306, 104, 294, 36), _select_region.bind(i), i == selected_region)
		button.disabled = i > int(player.unlocked)
	_button("Partir em expedição", Rect2(28, 201, 218, 42), _action.bind("route", {"region": selected_region}), true, "Recompensas a cada 20s; uma criatura a cada 60s. Até 8h AFK.")
	_button("Encontro PvE", Rect2(28, 252, 218, 40), _action.bind("battle", {"kind": "wild"}))
	_button("Desafiar o chefe", Rect2(28, 301, 218, 40), _action.bind("battle", {"kind": "boss"}), false, "Use uma equipe completa. Vencer desbloqueia a próxima região.")
	_button("Arena / ranking", Rect2(28, 452, 218, 40), _api.bind("/api/leaderboard", {}, "leaderboard"))
	_button("Treino PvP", Rect2(28, 501, 218, 40), _action.bind("battle", {"kind": "training"}), false, "Simulação com poder normalizado. Não altera a liga.")
	_button("Pausar AFK" if player.expedition != null else "Exploração AFK", Rect2(28, 350, 218, 36), _pause_or_explore)
	var battle = player.get("battle")
	if battle != null:
		if battle.get("result") != null:
			_button("Voltar à caravana", Rect2(900, 482, 324, 40), _action.bind("close_battle"), true)
		else:
			_button("Atacar", Rect2(283, 482, 165, 40), _action.bind("turn", {"command": "attack"}))
			_button("Habilidade", Rect2(460, 482, 165, 40), _action.bind("turn", {"command": "skill"}), true)
			_button("Proteger", Rect2(637, 482, 165, 40), _action.bind("turn", {"command": "guard"}))
			_button("Auto: " + ("ligado" if auto_battle else "desligado"), Rect2(814, 482, 190, 40), _toggle_auto)
			if not battle.get("rated", false):
				_button("Recuar", Rect2(1016, 482, 208, 40), _action.bind("retreat"))
	else:
		_button("Intervir na rota", Rect2(1008, 482, 216, 40), _action.bind("battle", {"kind": "wild"}), true)
	for i in range(3):
		var x = 276 + i * 322
		_button("Trocar" if i < player.team.size() else "Adicionar", Rect2(x + 14, 692, 130, 30), _collection_dialog.bind(i))
		if i < player.team.size():
			var c = _creature(player.team[i])
			_button("Treinar • " + str(int(c.level) * 15), Rect2(x + 156, 692, 130, 30), _action.bind("train", {"id": c.id}), false, "Compra o próximo nível com moedas do jogo; limite 20.")
	_button("Coleção • " + str(player.collection.size()), Rect2(276, 742, 177, 36), _collection_dialog.bind(0))
	_button("Diário", Rect2(465, 742, 177, 36), _journal_dialog)
	_button("Como jogar", Rect2(654, 742, 154, 36), _help_dialog)
	_button("Som " + ("on" if sound_enabled else "off"), Rect2(820, 742, 95, 36), _toggle_sound)

func _select_region(index: int) -> void:
	selected_region = index
	_build_ui()
	queue_redraw()

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

func _title(text: String, pos: Vector2, size_px: int = 30, color: Color = GOLD) -> void:
	draw_string(title_font, pos + Vector2(1, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color("101a25"))
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

func _sprite(id: String, pos: Vector2, scale_px: float = 3, shiny: bool = false, frozen: bool = false, flip: bool = false, flash: float = 0.0) -> void:
	var s = by_id.get(id, catalogue.species[0])
	var frame = 0 if frozen else int(elapsed * 8) % 4
	var bob = 0.0 if frozen else sin(elapsed * 3 + int(s.sprite)) * 2
	var target = Rect2(pos + Vector2(0, bob), Vector2(32, 32) * scale_px)
	if flip:
		target.position.x += target.size.x
		target.size.x = -target.size.x
	var color = Color("fff1cb") if shiny else Color.WHITE
	color = color.lerp(Color(1.8, 1.3, 1.3), flash)
	var is_enemy = s.get("sprite_atlas", "") == "enemy"
	var sheet = enemy_atlas if is_enemy else detailed_atlas
	if sheet != null:
		var index = int(s.sprite)
		var cell = sheet.get_size() / Vector2(3, 3 if is_enemy else 2)
		var source = Rect2(Vector2(index % 3, index / 3) * cell, cell)
		if is_enemy:
			var row = int(index / 3)
			var boundaries = [0.0, sheet.get_height() / 3.0, sheet.get_height() * 0.6395, float(sheet.get_height())]
			source.position.y = boundaries[row]
			source.size.y = boundaries[row + 1] - boundaries[row]
		var breathing = 0.0 if frozen else sin(elapsed * 2.8 + index) * 0.018
		var width = 32 * scale_px * (1 + breathing)
		var height = 32 * scale_px * (1 - breathing)
		var center = pos + Vector2(16, 16) * scale_px + Vector2(0, bob)
		draw_set_transform(center, 0.0 if frozen else sin(elapsed * 2 + index) * 0.02)
		var local = Rect2(Vector2(-width / 2, -height / 2), Vector2(width, height))
		if flip:
			local.position.x += width
			local.size.x = -width
		draw_texture_rect_region(sheet, local, source, color)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect_region(creature_atlas, target, Rect2(int(s.sprite) * 32, frame * 32, 32, 32), color)
	if shiny:
		_text("✦", pos + Vector2(26 * scale_px, 0), 20, GOLD)

func _prop(index: int, pos: Vector2, scale_px: float = 2) -> void:
	draw_texture_rect_region(prop_atlas, Rect2(pos, Vector2(32, 48) * scale_px), Rect2(index * 32, 0, 32, 48))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	if compact and not player.is_empty():
		_draw_compact()
		return
	if player.is_empty():
		_draw_onboarding()
		return
	_draw_world(Rect2(0, 80, 1280, 485))
	for i in range(16):
		draw_rect(Rect2(0, 520 + i * 18, 1280, 18), Color(0.035, 0.065, 0.10, minf(1, 0.3 + i * 0.08)))
	draw_rect(Rect2(0, 0, 1280, 89), Color(0.035, 0.07, 0.10, 0.95))
	draw_line(Vector2(0, 88), Vector2(1280, 88), Color("927b52"), 1)
	_title("BRUMORA", Vector2(28, 51), 30)
	_text("Crônicas de uma pequena caravana", Vector2(30, 75), 14, MUTED)
	_text(str(player.name), Vector2(349, 44), 22, INK)
	_text("◆ " + str(int(player.gold)) + " moedas", Vector2(636, 45), 21, GOLD)
	_text("EXPEDIÇÃO" if player.expedition != null else "ACAMPAMENTO", Vector2(349, 67), 12, MINT)
	_draw_sidebar()
	var battle = player.get("battle")
	if battle != null:
		_draw_battle(battle)
	else:
		_draw_caravan()
	_text("◆  SUA CARAVANA  ◆", Vector2(278, 557), 18, GOLD)
	_text("Ataque, proteção e cuidado em equilíbrio.", Vector2(509, 557), 15, MUTED)
	for i in range(3):
		_draw_card(i)
	if not player.log.is_empty():
		_text(str(player.log[0]), Vector2(931, 766), 13, MUTED, 312)
	_draw_banner()

func _draw_onboarding() -> void:
	_draw_world(Rect2(0, 0, 1280, 800))
	draw_rect(Rect2(0, 0, 1280, 800), Color(0.03, 0.07, 0.12, 0.42))
	_title("BRUMORA", Vector2(430, 100), 54, Color("f2ddae"))
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
		_ornate(Rect2(x + 2, 508, 306, 112), Color(0.04, 0.10, 0.14, 0.91), Color(color, 0.7))
		_text(s.name, Vector2(x + 20, 539), 29, color)
		_text(s.role + "  /  " + s.element, Vector2(x + 20, 564), 17, INK)
		_text("VID " + str(int(s.base.hp)) + "   ATQ " + str(int(s.base.attack)) + "   DEF " + str(int(s.base.defense)), Vector2(x + 20, 586), 16, MUTED)
		_text(s.skill.name, Vector2(x + 20, 608), 15, color)
	_text("Cada jornada é diferente. Seus companheiros também serão.", Vector2(355, 718), 19, Color("dfd9c5"))
	_text(banner, Vector2(170, 763), 16, MINT if connected else GOLD, 945)

func _draw_sidebar() -> void:
	_ornate(Rect2(16, 161, 242, 237))
	_text("◆ EXPEDIÇÃO ◆", Vector2(40, 188), 18, GOLD)
	_ornate(Rect2(16, 411, 242, 151))
	_text("◆ DUELOS ◆", Vector2(69, 439), 18, LILAC)
	_ornate(Rect2(16, 579, 242, 199))
	_text("DIÁRIO DA CARAVANA", Vector2(32, 608), 18, GOLD)
	_text("Liga: " + str(int(player.rating)) + " pontos", Vector2(32, 635), 17, LILAC)
	_text("Chefes: " + str(player.bosses.size()) + "/3", Vector2(32, 661), 16, MINT)
	if not player.log.is_empty():
		_wrapped(str(player.log[0]), Rect2(32, 677, 210, 88), 15)

func _draw_world(rect: Rect2) -> void:
	var region = int(player.get("region", 0))
	var exploring = player.get("expedition") != null and player.get("battle") == null
	world_painter.paint(self, world_atlas, region, rect, elapsed, route_distance, exploring, compact)


func _draw_caravan() -> void:
	_text(catalogue.regions[int(player.region)].name, Vector2(320, 180), 27, GOLD)
	_text("A caravana segue seu caminho…" if player.expedition != null else "Seus companheiros descansam.", Vector2(321, 207), 19, INK)
	for i in range(player.team.size()):
		var c = _creature(player.team[i])
		var x = 472 + i * 185
		draw_set_transform(Vector2(x + 75, 479), 0, Vector2(46, 7))
		draw_circle(Vector2.ZERO, 1, Color(0.02, 0.04, 0.07, 0.42))
		draw_set_transform(Vector2.ZERO)
		_sprite(c.species, Vector2(x, 335), 4.7, c.shiny)
	var ticks = int(player.expedition.ticks) if player.expedition != null else 0
	var remainder = clampf(20.0 - float(player.get("next_tick", 20)), 0, 20)
	_text("PRÓXIMA DESCOBERTA", Vector2(303, 487), 14, MINT)
	_bar(Rect2(303, 500, 468, 7), (float(ticks % 3) + remainder / 20.0) / 3.0 if player.expedition != null else 0.0, MINT)
	_text("Até 8h AFK • intervenção opcional", Vector2(303, 527), 14, INK)


func _draw_battle(battle: Dictionary) -> void:
	_ornate(Rect2(280, 160, 958, 58), Color(0.04, 0.08, 0.13, 0.92))
	var title = "CHEFE: " + catalogue.regions[int(battle.region)].boss if battle.kind == "boss" else "DUELO NORMALIZADO" if battle.kind in ["duel", "training"] else "ENCONTRO NA ROTA"
	_text(title, Vector2(299, 194), 21, GOLD)
	_text("TURNO " + str(int(battle.round)), Vector2(1100, 194), 15, MUTED)
	unit_positions.clear()
	for side in ["allies", "enemies"]:
		for i in range(battle[side].size()):
			var unit = battle[side][i]
			var x = (315 if side == "allies" else 819) + i * 135
			_paint_fighter(unit, Vector2(x, 345), side == "enemies", 4.0, false)
	_title("VS", Vector2(725, 354), 25)
	_draw_combat_choreography(false)
	if battle.get("result") != null:
		_text("VITÓRIA!" if battle.result == "win" else "A CARAVANA RECUOU", Vector2(294, 510), 26, MINT if battle.result == "win" else GOLD)
	if not battle.messages.is_empty():
		_text(str(battle.messages[-1]), Vector2(297, 535), 14, INK, 917)

func _paint_fighter(unit: Dictionary, pos: Vector2, enemy: bool, sprite_scale: float, small: bool) -> void:
	var extent = 32 * sprite_scale
	var center = pos + Vector2(extent * 0.5, extent * 0.55)
	unit_positions[unit.id] = center
	var effect = battle_fx.get(unit.id, {})
	var age = elapsed - float(effect.get("started", -10))
	var offset = Vector2.ZERO
	var flash = 0.0
	if age >= 0 and age < 0.6:
		if effect.get("attack", false):
			offset.x += sin(clampf(age / 0.55, 0, 1) * PI) * (16 if small else 27) * (-1 if enemy else 1)
		if effect.get("damage", 0) > 0:
			offset.x += sin(age * 65) * (3 if small else 6) * (1 - age / 0.6)
			flash = maxf(0, 1 - age / 0.3)
	draw_set_transform(pos + Vector2(extent * 0.5, extent - 8), 0, Vector2(extent * 0.31, 5 if small else 7))
	draw_circle(Vector2.ZERO, 1, Color(0.02, 0.04, 0.07, 0.4))
	draw_set_transform(Vector2.ZERO)
	var source_facing_left = by_id[unit.species].get("sprite_atlas", "") == "enemy"
	var flip_sprite = enemy != source_facing_left
	_sprite(unit.species, pos + offset, sprite_scale if unit.hp > 0 else sprite_scale * 0.82, unit.shiny, unit.hp <= 0, flip_sprite, flash)
	_text(unit.name, pos + Vector2(0, -7), 12 if small else 15, INK if unit.hp > 0 else MUTED, extent + 2)
	_bar(Rect2(pos + Vector2(5, extent - 1), Vector2(extent - 10, 5 if small else 7)), float(displayed_hp.get(unit.id, unit.hp)) / float(unit.stats.hp), RED if enemy else MINT)
	if not small:
		_text(str(int(unit.hp)) + "/" + str(int(unit.stats.hp)), pos + Vector2(7, extent - 7), 13, INK)
	if unit.shield > 0:
		draw_arc(center, extent * 0.38 + sin(elapsed * 3) * 2, PI, TAU, 28, Color(0.5, 0.8, 1.0, 0.65), 2, true)

func _draw_combat_choreography(small: bool) -> void:
	for event in combat_sequence:
		var age = elapsed - float(event.started)
		if age < 0 or age > 1.1:
			continue
		if not unit_positions.has(event.actor) or not unit_positions.has(event.target):
			continue
		var origin: Vector2 = unit_positions[event.actor]
		var target: Vector2 = unit_positions[event.target]
		var kind = "shield" if event.kind == "guard" else event.kind
		effects_painter.paint(self, event.species, origin, target, age, kind, 0.55 if small else 1.0)
		if int(event.value) > 0:
			var color = RED if kind == "attack" else MINT if kind == "heal" else Color("9dccfa")
			color.a = minf(1, (1.1 - age) * 3)
			_text(("-" if kind == "attack" else "+") + str(int(event.value)), target + Vector2(7, -28 - age * 30), 15 if small else 22, color)


func _draw_card(index: int) -> void:
	var x = 276 + index * 322
	_ornate(Rect2(x, 577, 306, 152), Color(0.05, 0.10, 0.14, 0.93), Color("796c50"))
	if index >= player.team.size():
		_text("◇", Vector2(x + 31, 636), 35, GOLD)
		_wrapped("Um lugar para seu próximo companheiro", Rect2(x + 93, 597, 190, 61), 18)
		return
	var c = _creature(player.team[index])
	var s = by_id[c.species]
	var rarity = _rarity(c.rarity)
	_sprite(c.species, Vector2(x + 2, 585), 3.0, c.shiny)
	_text(s.name + " · " + str(int(c.level)), Vector2(x + 101, 607), 21, Color(s.color))
	_text(s.role + " • " + rarity.name, Vector2(x + 101, 629), 14, Color(rarity.color))
	_text("VID " + str(int(c.stats.hp)) + "  ATQ " + str(int(c.stats.attack)) + "  DEF " + str(int(c.stats.defense)), Vector2(x + 101, 650), 12, MUTED)
	_text(s.skill.name, Vector2(x + 101, 670), 14, INK)
	_bar(Rect2(x + 16, 681, 274, 4), float(c.xp) / maxf(1, float(c.next_xp)), LILAC)


func _rarity(id: String) -> Dictionary:
	for r in catalogue.rarities:
		if r.id == id:
			return r
	return catalogue.rarities[0]

func _draw_banner() -> void:
	if banner_time > 0:
		_ornate(Rect2(319, 229, 912, 29), Color(0.05, 0.12, 0.16, 0.94))
		_text(banner, Vector2(330, 249), 14, GOLD, 886)

func _draw_compact() -> void:
	_draw_world(Rect2(0, 0, 1280, 250))
	_ornate(Rect2(14, 12, 591, 57), Color(0.04, 0.08, 0.13, 0.88))
	_text("BRUMORA / " + str(player.name), Vector2(30, 36), 19, GOLD)
	_text("◆ " + str(int(player.gold)) + " moedas • " + catalogue.regions[int(player.region)].name, Vector2(30, 58), 14, MINT)
	var battle = player.get("battle")
	if battle != null:
		unit_positions.clear()
		for side in ["allies", "enemies"]:
			for i in range(battle[side].size()):
				var unit = battle[side][i]
				_paint_fighter(unit, Vector2((382 if side == "allies" else 843) + i * 108, 91), side == "enemies", 2.8, true)
		_draw_combat_choreography(true)
		_text("VITÓRIA — AVANÇANDO!" if battle.get("result") == "win" else "REAGRUPANDO…" if battle.get("result") == "loss" else "TURNO " + str(int(battle.round)), Vector2(650, 50), 18, GOLD)
	else:
		for i in range(player.team.size()):
			var c = _creature(player.team[i])
			_sprite(c.species, Vector2(667 + i * 144, 88), 3.0, c.shiny)
		_text("CARAVANA EM MOVIMENTO" if player.expedition != null else "CARAVANA EM REPOUSO", Vector2(650, 47), 16, GOLD)
	_text("Arraste o topo para mover • " + str(int(player.get("distance", 0))) + "m conquistados", Vector2(558, 211), 14, INK)


func _dialog(title: String, dimensions: Vector2i = Vector2i(720, 500)) -> AcceptDialog:
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.min_size = dimensions
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	dialog.add_theme_stylebox_override("panel", _style(PANEL, Color("3b5365")))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	return dialog

func _content(dialog: AcceptDialog) -> VBoxContainer:
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 20
	margin.offset_top = 20
	margin.offset_right = -20
	margin.offset_bottom = -60
	dialog.add_child(margin)
	var scroll = ScrollContainer.new()
	margin.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	return box

func _label(text: String, parent: Node, size_px: int = 15, color: Color = INK) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _collection_dialog(slot: int) -> void:
	var dialog = _dialog("Coleção — escolher para o espaço " + str(slot + 1), Vector2i(850, 610))
	var box = _content(dialog)
	_label("Cada exemplar tem atributos individuais de 0–15. ✦ Luminoso é uma aparência cosmética. Limite: 80 criaturas.", box, 14, MUTED)
	for c in player.collection:
		var s = by_id[c.species]
		var r = _rarity(c.rarity)
		var button = Button.new()
		button.text = s.name + (" ✦" if c.shiny else "") + "  |  " + r.name + "  |  Nível " + str(int(c.level)) + "\nVID " + str(int(c.stats.hp)) + "  ATQ " + str(int(c.stats.attack)) + "  DEF " + str(int(c.stats.defense)) + "  VEL " + str(int(c.stats.speed)) + "\nIndividuais: " + str(int(c.iv.hp)) + " / " + str(int(c.iv.attack)) + " / " + str(int(c.iv.defense)) + " / " + str(int(c.iv.speed)) + "  •  " + s.skill.name
		var atlas = AtlasTexture.new()
		atlas.atlas = detailed_atlas if detailed_atlas != null else creature_atlas
		if detailed_atlas != null:
			var cell = detailed_atlas.get_size() / Vector2(3, 2)
			atlas.region = Rect2(Vector2(int(s.sprite) % 3, int(s.sprite) / 3) * cell, cell)
		else:
			atlas.region = Rect2(int(s.sprite) * 32, 0, 32, 32)
		button.icon = atlas
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 64)
		button.custom_minimum_size = Vector2(760, 88)
		button.add_theme_stylebox_override("normal", _style(PANEL_LIGHT))
		button.add_theme_stylebox_override("hover", _style(Color("2d4356"), Color(r.color)))
		button.add_theme_color_override("font_color", INK)
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_choose_creature.bind(c.id, slot, dialog))
		box.add_child(button)
	dialog.popup_centered(Vector2i(850, 610))

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
	_label("1. Escolha uma rota e parta. A cada 20s: moedas e XP. A cada 60s: uma criatura; vagas da equipe são preenchidas automaticamente.", box)
	_label("2. Combine atacante + tanque + suporte. O tanque atrai parte dos ataques; o suporte cura o aliado mais ferido. Habilidades têm recarga.", box)
	_label("3. Em PvE, cada clique resolve um turno da equipe. Atacar poupa habilidades; Habilidade usa poderes disponíveis; Proteger gera escudos. Auto decide sozinho.", box)
	_label("4. Vença os chefes para abrir regiões mais difíceis. Treinar compra um nível com moedas do jogo. Não existem pagamentos neste MVP.", box)
	_label("5. Arena: desafie a defesa de outra conta. Poder normalizado no nível 5, sem bônus de raridade ou individuais. Treino PvP não vale pontos.", box)
	_label("6. Feche o jogo e retorne: até 8h de recompensas calculadas pelo servidor. O servidor local deve manter o mesmo banco de dados; o relógio é o do servidor.", box)
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
		_label("✦ " + entry.name + " — " + str(int(entry.bosses)) + "/3 chefes", box)
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
	var sequence_index = 0
	for event in current.get("events", []):
		var visual = event.duplicate()
		visual.started = elapsed + sequence_index * 0.055
		combat_sequence.append(visual)
		sequence_index += 1
	for side in ["allies", "enemies"]:
		for unit in current[side]:
			var old = {}
			for candidate in previous[side]:
				if candidate.id == unit.id:
					old = candidate
			if old.is_empty():
				continue
			var attack = false
			for message in current.messages:
				if str(message).begins_with(unit.name) and ("→" in str(message)):
					attack = true
			battle_fx[unit.id] = {"started": elapsed, "attack": attack, "damage": maxf(0, float(old.hp) - float(unit.hp)), "heal": maxf(0, float(unit.hp) - float(old.hp)), "shield": maxf(0, float(unit.shield) - float(old.shield))}
			displayed_hp[unit.id] = float(old.hp)

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
