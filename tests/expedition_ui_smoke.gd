extends SceneTree
## Full client + isolated QA API. This subclass never reads a real session token
## and never writes connection.cfg. Every HTTP request is forced to port 18787.

class QaClient extends "res://scripts/main.gd":
	func _session_section() -> String:
		return "isolated_expedition_ui_smoke_no_saved_session"
	func _save_settings() -> void:
		pass
	func _api(path: String, data: Dictionary, context: String) -> void:
		server_url = "http://127.0.0.1:18787"
		super._api(path, data, context)

var game: Control
var failures := 0
var started := 0

func _initialize() -> void:
	started = Time.get_ticks_msec()
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _wait_request() -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while (game.busy or not game.pending_requests.is_empty() or game.elapsed < game.animation_until or game._presentation_locked()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	var ready: bool = not game.busy and game.pending_requests.is_empty() and game.elapsed >= game.animation_until and not game._presentation_locked()
	_check(ready, "HTTP e animações concluíram")
	return ready

func _action(op: String, args: Dictionary = {}) -> bool:
	game._action(op, args)
	# The production journey defaults to autoplay; this test controls the timing
	# through real commands so automatic waves cannot race the assertions.
	game.route_auto = false
	game.compact_auto = false
	game.auto_battle = false
	return await _wait_request()

func _finish() -> void:
	print("EXPEDITION UI SMOKE: failures=%s, elapsed=%.2fs, endedUTC=%s" % [failures, (Time.get_ticks_msec() - started) / 1000.0, Time.get_datetime_string_from_system(true, true)])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _collect_reward(total: Dictionary, reward: Dictionary) -> void:
	total.gold = roundi(float(total.gold) * 1000 + float(reward.gold) * 1000) / 1000.0
	total.kills += reward.get("defeated", []).size()
	total.battles += 1
	for id in reward.items:
		total.items[id] = int(total.items.get(id, 0)) + int(reward.items[id])
	for id in reward.xp_by_creature:
		total.xp_by_creature[id] = int(total.xp_by_creature.get(id, 0)) + int(reward.xp_by_creature[id])

func _same_items(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.size() != expected.size():
		return false
	for id in expected:
		if not actual.has(id) or int(actual[id]) != int(expected[id]):
			return false
	return true

func _run() -> void:
	game = QaClient.new()
	root.add_child(game)
	await _wait_request()
	_check(game.connected and game.server_url == "http://127.0.0.1:18787", "cliente usa exclusivamente servidor QA 18787")
	if not game.connected:
		await _finish()
		return
	_check(game._coins(0.001) == "0,001", "formatação preserva milésimo de moeda")
	_check(game._coins(0.22) == "0,22" and game._coins(12.0) == "12", "moedas removem zeros supérfluos")
	for icon in ["coin", "xp", "eye"]:
		_check(ResourceLoader.exists("res://assets/icons/" + icon + ".svg"), "asset canônico disponível: " + icon)
		_check(game.icons.has(icon), "ícone carregado pelo cliente: " + icon)
	game._register("ember", "QA Jornada")
	await _wait_request()
	_check(not game.player.is_empty(), "registro isolado com Fagulim")
	if game.player.is_empty():
		await _finish()
		return
	var creature_id: String = game.player.team[0]
	await _action("route", {"region": 0})
	_check(game.player.expedition != null, "expedição iniciada")
	await _action("battle", {"kind": "wild"})
	_check(game.player.battle != null, "primeiro encontro iniciado")
	if game.player.battle == null:
		await _finish()
		return
	var turns := 0
	while game.player.battle.result == null and turns < 60:
		# Basic attacks allow defending enemies time to attack after their shield.
		await _action("turn", {"command": "attack"})
		turns += 1
	_check(game.player.battle.result == "win", "equipe conclui encontro inicial")
	if game.player.battle.result != "win":
		await _finish()
		return
	var hp: float = game.player.battle.allies[0].hp
	var maximum: float = game.player.battle.allies[0].stats.hp
	var reward: Dictionary = {"gold": 0.0, "items": {}, "xp_by_creature": {}, "kills": 0, "battles": 0}
	_collect_reward(reward, game.player.battle.rewards)
	# A critical opening can legitimately win without taking damage. Continue the
	# real journey rather than treating a perfect victory as a persistence bug.
	var perfect_wins := 0
	while hp >= maximum and perfect_wins < 3:
		await _action("close_battle")
		await _action("battle", {"kind": "wild"})
		turns = 0
		while game.player.battle.result == null and turns < 60:
			await _action("turn", {"command": "attack"})
			turns += 1
		_collect_reward(reward, game.player.battle.rewards)
		hp = float(game.player.battle.allies[0].hp)
		maximum = float(game.player.battle.allies[0].stats.hp)
		perfect_wins += 1
	_check(hp > 0 and hp < maximum, "jornada causou desgaste real antes de verificar continuidade")
	_check(game.player.expedition.has("hp"), "servidor QA executa persistência HP atualizada")
	if not game.player.expedition.has("hp"):
		await _finish()
		return
	_check(float(game.player.expedition.hp[creature_id]) == hp, "HP da jornada acompanha resultado autoritativo")
	_check(float(game.player.battle.rewards.gold) > 0 and float(game.player.battle.rewards.gold) < 1 and int(game.player.battle.rewards.xp) > 0, "abate concede moedas fracionárias e XP")
	_check(game.gain_events.any(func(g): return g.kind == "gold") and game.gain_events.any(func(g): return g.kind == "xp"), "cliente registra feedback de moeda e XP")
	await _action("close_battle")
	await _action("battle", {"kind": "wild"})
	_check(game.player.battle != null and float(game.player.battle.allies[0].hp) == hp, "próximo encontro preserva HP sem cura automática")
	await _action("pause")
	_check(game.player.expedition == null and game.player.battle == null, "retorno encerra rota e encontro")
	var summary: Dictionary = game.player.get("last_expedition_summary", {})
	_check(not summary.is_empty(), "servidor retorna resumo persistido")
	if not summary.is_empty():
		_check(summary.outcome == "returned" and int(summary.kills) == int(reward.kills) and int(summary.battles) == int(reward.battles) + 1, "resumo registra retorno, abates e todos encontros")
		_check(is_equal_approx(float(summary.gold), float(reward.gold)), "moedas do resumo correspondem ao ganho real")
		_check(_same_items(summary.items, reward.items), "materiais do resumo correspondem aos drops reais")
		_check(int(summary.xp_by_creature.get(creature_id, 0)) == int(reward.xp_by_creature.get(creature_id, 0)), "resumo preserva XP real por exemplar")
	var modal_deadline := Time.get_ticks_msec() + 8000
	while game.modal_kind != "expedition_summary" and Time.get_ticks_msec() < modal_deadline:
		await create_timer(0.05).timeout
	_check(game.modal_kind == "expedition_summary" and is_instance_valid(game.modal) and game.modal.visible, "UI abre resumo contextual da expedição")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_check(image.save_png("res://.godot/expedition-ui-smoke.png") == OK, "captura real do resumo")
	await _finish()
