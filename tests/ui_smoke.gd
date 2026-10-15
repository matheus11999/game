extends SceneTree

var game: Control
var failures = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _wait_request() -> void:
	var deadline = Time.get_ticks_msec() + 10000
	while (game.busy or not game.pending_requests.is_empty()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	_check(not game.busy and game.pending_requests.is_empty(), "solicitação concluída")

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var directory = OS.get_environment("BRUMORA_CAPTURE_DIR")
	if directory.is_empty():
		directory = ProjectSettings.globalize_path("user://test-captures")
	DirAccess.make_dir_recursive_absolute(directory)
	var result = image.save_png(directory.path_join(name + ".png"))
	_check(result == OK, "captura " + name)

func _run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await _wait_request()
	_check(game.connected, "Godot conectado ao servidor local")
	game.player = {}
	game.token = ""
	game._build_ui()
	game.queue_redraw()
	await _capture("brumora-starters")
	game._register("moss", "Teste Interface")
	await _wait_request()
	_check(not game.player.is_empty(), "escolha de criatura inicial")
	if game.player.is_empty():
		quit(1)
		return
	_check(game.player.collection[0].species == "moss", "espécie e atributos recebidos")
	game._action("route", {"region": 0})
	await _wait_request()
	_check(game.player.expedition != null, "expedição iniciada")
	await _capture("brumora-expedition")
	game._action("battle", {"kind": "wild"})
	await _wait_request()
	_check(game.player.battle != null, "encontro PvE iniciado")
	_check(game.by_id[game.player.battle.enemies[0].species].get("sprite_atlas") == "enemy", "inimigo próprio com atlas detalhado")
	game._action("turn", {"command": "skill"})
	await _wait_request()
	_check(int(game.player.battle.round) == 1, "intervenção manual e habilidade")
	_check(not game.combat_sequence.is_empty(), "eventos acionam efeitos por criatura")
	await _capture("brumora-battle")
	var rounds = 0
	while game.player.battle.result == null and rounds < 60:
		game._action("turn", {"command": "auto"})
		await _wait_request()
		rounds += 1
	_check(game.player.battle.result != null, "batalha concluída")
	game._action("close_battle")
	await _wait_request()
	_check(game.player.battle == null, "retorno à exploração")
	game._collection_dialog(0)
	await process_frame
	for child in game.get_children():
		if child is AcceptDialog:
			child.hide()
			child.queue_free()
	await process_frame
	game._help_dialog()
	await process_frame
	for child in game.get_children():
		if child is AcceptDialog:
			child.hide()
			child.queue_free()
	await process_frame
	game._api("/api/state", {}, "state")
	game._api("/api/leaderboard", {}, "leaderboard")
	await _wait_request()
	_check(not game.leaderboard.get("players", []).is_empty(), "clique no ranking enfileirado durante consulta automática")
	for child in game.get_children():
		if child is AcceptDialog:
			child.hide()
			child.queue_free()
	await process_frame
	game._toggle_compact()
	await process_frame
	_check(game.compact, "modo rodapé ativado")
	var encounters_before = int(game.player.get("encounters", 0))
	var distance_before = int(game.player.get("distance", 0))
	var deadline = Time.get_ticks_msec() + 65000
	while int(game.player.get("encounters", 0)) <= encounters_before and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	_check(int(game.player.get("encounters", 0)) > encounters_before, "rodapé inicia e vence batalha automaticamente")
	_check(int(game.player.get("distance", 0)) > distance_before, "vitória avança a caravana no servidor")
	await _capture("brumora-taskbar")
	deadline = Time.get_ticks_msec() + 6000
	while game.player.get("battle") != null and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	_check(game.player.get("battle") == null, "rodapé encerra resultado e retoma viagem")
	game.compact_auto = false
	game.auto_battle = false
	game._toggle_compact()
	_check(not game.compact, "modo normal restaurado")
	print("UI smoke finished, failures=" + str(failures))
	quit(1 if failures else 0)
