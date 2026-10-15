extends SceneTree
## Offline decision test: runs the real client loop without sockets, textures,
## database writes or connection.cfg changes. Server remains authority for all
## battle results; this verifies only when the client requests an encounter.

class JourneyClient extends "res://scripts/main.gd":
	var requests: Array = []
	func _ready() -> void:
		set_process(false)
	func _draw() -> void:
		pass
	func _update_timer_labels() -> void:
		pass
	func _build_ui() -> void:
		pass
	func _api(path: String, data: Dictionary, context: String) -> void:
		requests.append({"path": path, "data": data.duplicate(true), "context": context})

var failures := 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var client := JourneyClient.new()
	root.add_child(client)
	client.player = {"expedition": {"ticks": 0}, "battle": null, "collection": []}
	_check(client.route_auto, "jornada normal inicia com encontros automáticos ativos")
	client._process(8.5)
	_check(client.requests.size() == 1 and client.requests[0].data.get("op") == "battle" and client.requests[0].data.get("kind") == "wild", "exploração solicita encontro em até 8.5 segundos")
	client.requests.clear()
	client.player.battle = {"id": "test-battle", "round": 0, "allies": [], "enemies": [], "result": null}
	client.auto_battle = true
	client.animation_until = client.elapsed + 2.0
	client.poll_elapsed = 2.0
	client._process(0.1)
	_check(client.requests.is_empty(), "não avança turno durante animação")
	client.animation_until = 0
	client._process(0.1)
	_check(client.requests.size() == 1 and client.requests[0].data.get("op") == "turn" and client.requests[0].data.get("command") == "auto", "encontro usa turno automático calculado pelo servidor")
	client.requests.clear()
	client.player.battle.result = "win"
	client.wave_elapsed = 3.0
	client._process(0.1)
	_check(client.requests.size() == 1 and client.requests[0].data.get("op") == "close_battle", "jornada fecha resultado e pode continuar")
	client.requests.clear()
	client.player.battle = null
	client._pause_or_explore()
	_check(client.requests.size() == 1 and client.requests[0].data.get("op") == "pause", "pausa explícita é enviada ao servidor")
	client.requests.clear()
	client.player.expedition = null
	client.wave_elapsed = 20
	client._process(10.0)
	_check(client.requests.is_empty(), "jornada pausada não cria encontros")
	client.player.expedition = {"ticks": 0}
	client.busy = true
	client.wave_elapsed = 20
	client._process(10.0)
	_check(client.requests.is_empty(), "não duplica encontro enquanto existe solicitação pendente")
	client.queue_free()
	print("Exploration auto decision failures: ", failures)
	quit(1 if failures else 0)
