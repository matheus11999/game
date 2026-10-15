extends SceneTree

class QaClient extends "res://scripts/main.gd":
	func _session_section() -> String:
		return "isolated_ui_smoke_no_saved_session"
	func _save_settings() -> void:
		pass
	func _api(path: String, data: Dictionary, context: String) -> void:
		server_url = "http://127.0.0.1:18787"
		super._api(path, data, context)

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
	while (game.busy or not game.pending_requests.is_empty() or game.elapsed < game.animation_until or game._presentation_locked()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	_check(not game.busy and game.pending_requests.is_empty() and game.elapsed >= game.animation_until and not game._presentation_locked(), "solicitação concluída")

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
	game = QaClient.new()
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
	_check(int(game.player.get("gear_score", 0)) > 0, "gear score calculado pelo servidor")
	game._inventory_dialog()
	await _capture("taskmon-inventory")
	_check(game.modal_kind == "inventory", "inventário com quatro espaços")
	game._profile_dialog()
	await _capture("taskmon-profile")
	game._maps_dialog()
	await _capture("taskmon-maps")
	game._creature_dialog(game.player.team[0])
	await _capture("taskmon-creature")
	game.modal.hide()
	game.modal.queue_free()
	game._action("route", {"region": 0})
	await _wait_request()
	_check(game.player.expedition != null, "expedição iniciada")
	await _capture("brumora-expedition")
	# Keep this phase manual: route auto is exercised separately below.
	game.auto_battle = false
	game._action("battle", {"kind": "wild"})
	await _wait_request()
	_check(game.player.battle != null, "encontro PvE iniciado")
	_check(game.by_id[game.player.battle.enemies[0].species].get("sprite_atlas") == "enemy", "inimigo próprio com atlas detalhado")
	await _capture("taskmon-arena")
	_check(not game.ui.get_children().any(func(c): return c is Button and c.text == "Explorar"), "combate tem interface própria")
	var births_before_turn = game.unit_birth.duplicate()
	game._action("turn", {"command": "skill"})
	await _wait_request()
	_check(game.unit_birth == births_before_turn, "novo turno não repete animação de aparição")
	_check(int(game.player.battle.round) == 1, "intervenção manual e habilidade")
	_check(not game.combat_sequence.is_empty(), "eventos acionam efeitos por criatura")
	await _capture("brumora-battle")
	var rounds = 0
	while game.player.battle.result == null and rounds < 60:
		game._action("turn", {"command": "auto"})
		await _wait_request()
		rounds += 1
	_check(game.player.battle.result != null, "batalha concluída")
	var first_health = {}
	for ally in game.player.battle.allies:
		first_health[ally.id] = int(ally.hp)
	await _capture("taskmon-loot")
	_check(not game.player.inventory.is_empty(), "vitória entrega materiais")
	# Re-enter a persisted result as happens after starting from the editor.
	# The result must remain actionable even without an in-memory prior turn.
	var completed_battle_id = str(game.player.battle.id)
	game.player = {}
	game.last_signature = ""
	game._api("/api/state", {}, "state")
	await _wait_request()
	_check(game.player.get("battle") != null and str(game.player.battle.id) == completed_battle_id and game.player.battle.result != null, "reconexão restaura resultado de batalha persistido")
	var continue_button: Button = null
	for child in game.ui.get_children():
		if child is Button and (child.name == "ContinueBattle" or child.tooltip_text == "Continuar exploração" or child.text == "Continuar"):
			continue_button = child
			break
	_check(is_instance_valid(continue_button), "resultado restaurado possui botão Continuar")
	if is_instance_valid(continue_button):
		_check(not continue_button.disabled, "Continuar habilitado após animação")
		continue_button.pressed.emit()
	await _wait_request()
	_check(game.player.battle == null, "clique real em Continuar retorna à exploração")
	for id in first_health:
		_check(int(game.player.expedition.hp.get(id, -1)) == first_health[id], "HP da equipe persiste após o encontro")
	game._inventory_dialog()
	await _capture("taskmon-inventory-loot")
	game._creature_dialog(game.player.team[0])
	game._action("upgrade", {"id": game.player.team[0]})
	await _wait_request()
	_check(game.player.collection[0].get("upgrade_job") != null, "aprimoramento temporizado iniciado com materiais de batalha")
	await _capture("taskmon-upgrade-timer")
	game.modal.hide()
	game.modal.queue_free()
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
	while int(game.player.get("encounters", 0)) <= encounters_before and game.player.expedition != null and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	var survived = int(game.player.get("encounters", 0)) > encounters_before
	_check(survived or game.player.get("last_expedition_summary", {}).get("outcome", "") == "defeat", "rodapé resolve encontro ou retorna após derrota real")
	if survived:
		_check(int(game.player.get("distance", 0)) > distance_before, "vitória avança a caravana no servidor")
	await _capture("brumora-taskbar")
	deadline = Time.get_ticks_msec() + 6000
	while game.player.get("battle") != null and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	_check(game.player.get("battle") == null, "rodapé encerra o resultado")
	game.compact_auto = false
	game.auto_battle = false
	game.route_auto = false
	# Challenge an actual boss with the remaining starter HP. No fixture rewards,
	# fake outcomes or HP resets: the server must end this expedition on a wipe.
	if game.player.expedition != null:
		game._action("battle", {"kind": "boss"})
		await _wait_request()
		var boss_rounds = 0
		# This verifies an actual wipe, not the tank autopilot endurance strategy.
		# Basic attacks leave the starter exposed; no fabricated HP or rewards.
		while game.player.get("battle") != null and game.player.battle.result == null and boss_rounds < 60:
			game._action("turn", {"command": "attack"})
			await _wait_request()
			boss_rounds += 1
	deadline = Time.get_ticks_msec() + 6000
	while (game.player.expedition != null or game.modal_kind != "expedition_summary" or game.compact) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	_check(game.player.expedition == null, "derrota total encerra expedição sem curar a equipe")
	var report = game.player.get("last_expedition_summary", {})
	_check(report.get("outcome", "") == "defeat" and int(report.get("battles", 0)) >= 2 and int(report.get("kills", 0)) > 0, "resumo autoritativo registra batalhas e abates anteriores")
	_check(game.modal_kind == "expedition_summary" and is_instance_valid(game.modal) and game.modal.visible, "retorno abre resumo da expedição")
	_check(not game.compact, "derrota no rodapé expande o resumo")
	await _capture("taskmon-expedition-wipe")
	var escape = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._unhandled_key_input(escape)
	_check(not game.compact, "Escape restaura modo normal")
	var upgrade_deadline = Time.get_ticks_msec() + 75000
	while game.player.collection[0].get("upgrade_job") != null and Time.get_ticks_msec() < upgrade_deadline:
		await create_timer(0.2).timeout
	_check(int(game.player.collection[0].get("upgrade", 0)) == 1, "aprimoramento conclui após prazo do servidor")
	game._creature_dialog(game.player.team[0])
	await _capture("taskmon-upgrade-complete")
	if is_instance_valid(game.modal):
		game.modal.hide()
		game.modal.queue_free()
	game.queue_free()
	await process_frame
	await process_frame
	# Headless frames can run faster than the audio mixer's teardown period.
	await create_timer(0.1).timeout
	print("UI smoke finished, failures=" + str(failures))
	quit(1 if failures else 0)
