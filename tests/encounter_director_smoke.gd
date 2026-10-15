extends SceneTree

const Director = preload("res://scripts/encounter_director.gd")
var checks := 0

func _check(condition: bool, message: String) -> void:
	checks += 1
	assert(condition, message)
	print("PASS: " + message)

func _simulate(fps: int, seconds: float, speed: float = 1.0):
	var director = Director.new()
	director.begin_battle("field", 0, {"journey_active": true})
	var remaining := seconds
	while remaining > 0.00000001:
		var step := minf(remaining, 1.0 / fps)
		director.update(step, speed)
		remaining -= step
	return director

func _initialize() -> void:
	var d = Director.new()
	_check(d.phase == &"travel" and not d.can_act and not d.show_vs, "estado inicial é viagem sem HUD de combate")
	_check(not d.begin_battle("", 0), "ID vazio não cria encontro")
	d.begin_battle("first", 10, {"journey_active": true})
	_check(d.phase == &"approach" and d.walking and d.camera_blend == 0.0, "inimigo aparece no campo antes do zoom")
	_check(d.enemy_world_offset == 80.0 and not d.can_act and not d.can_autoclose and not d.show_vs, "prévia aparece 80px adiante e bloqueia turnos/VS")
	d.update(1.1)
	_check(is_equal_approx(d.approach_progress, 0.5) and is_equal_approx(d.enemy_world_offset, 40), "aproximação e posição do inimigo progridem suavemente")
	_check(is_equal_approx(d.distance_delta, Director.APPROACH_DISTANCE * 0.5) and is_equal_approx(d.locomotion_clock, 1.1), "deslocamento de cenário mantém 24 unidades/s e relógio dos passos")
	_check(is_equal_approx(d.consume_travel_distance(), Director.APPROACH_DISTANCE * 0.5) and d.consume_travel_distance() == 0, "deslocamento extra é consumido uma vez")
	_check(not d.begin_battle("first", 99) and is_equal_approx(d.approach_progress, 0.5), "poll repetido não reinicia aproximação")
	d.update(1.1)
	_check(d.phase == &"engage" and d.show_vs and not d.walking and not d.can_act, "VS começa após chegar ao inimigo")
	d.update(0.35)
	_check(d.camera_blend > 0 and d.camera_blend < 1 and d.show_vs and not d.can_act, "câmera aproxima durante VS sem liberar ataque")
	d.update(0.36)
	_check(not d.show_vs and d.phase == &"engage" and not d.can_act, "VS dura 0.7s; controle aguarda câmera assentar")
	d.update(0.24)
	_check(d.phase == &"combat" and d.can_act and is_equal_approx(d.camera_blend, 1), "ataques liberados somente depois do enquadramento final")
	d.update(0.1, 1, true)
	_check(not d.can_act and d.can_autoclose and not d.show_vs, "resultado permite fechamento e não permite novo ataque")
	d.end_battle(14)
	_check(d.phase == &"disengage" and d.walking and not d.can_act, "continuar inicia recuo suave e retoma passos")
	d.update(0.425)
	_check(is_equal_approx(d.camera_blend, 0.5), "zoom de saída tem interpolação suave")
	d.update(0.425)
	_check(d.phase == &"travel" and d.camera_blend == 0 and d.walking, "retoma o mesmo campo sem troca de cena")

	for seconds in [0.5, 1.1, 2.2, 2.55, 2.91, 3.15, 4.0]:
		var low = _simulate(5, seconds)
		for fps in [30, 60, 144]:
			var high = _simulate(fps, seconds)
			_check(low.phase == high.phase and absf(low.approach_progress - high.approach_progress) < 0.00001 and absf(low.camera_blend - high.camera_blend) < 0.00001 and absf(low.travel_distance_extra - high.travel_distance_extra) < 0.0001 and low.can_act == high.can_act, "independente de FPS: 5 versus %s, t=%.2f" % [fps, seconds])
	var slow = _simulate(60, 2.2, 0.5)
	var fast = _simulate(60, 1.1, 2.0)
	_check(is_equal_approx(slow.approach_progress, 0.5) and fast.phase == &"engage", "velocidade ajusta aproximação sem acelerar duração do VS")
	var frozen = Director.new()
	frozen.begin_battle("paused", 0, {"journey_active": true})
	frozen.update(10, 0)
	_check(frozen.approach_progress == 0 and frozen.travel_distance_extra == 0 and not frozen.walking, "velocidade zero congela aproximação e passos")
	var outside = Director.new()
	outside.begin_battle("manual", 0, {"journey_active": false})
	outside.update(10)
	_check(outside.phase == &"combat" and outside.travel_distance_extra == 0, "combate fora da jornada não adiciona distância da rota")
	var giant = _simulate(1, 10)
	_check(is_equal_approx(giant.travel_distance_extra, Director.APPROACH_DISTANCE) and giant.phase == &"combat", "delta grande não perde fases nem excede distância de aproximação")
	var restored = Director.new()
	restored.begin_battle("saved-result", 50, {"restored": true, "finished": true, "round": 7, "journey_active": true})
	_check(restored.phase == &"combat" and restored.can_autoclose and not restored.show_vs and restored.travel_distance_extra == 0, "resultado restaurado não reproduz caminhada nem VS")
	var interrupted = Director.new()
	interrupted.begin_battle("mid-round", 0, {"round": 2})
	_check(interrupted.can_act and interrupted.camera_blend == 1 and not interrupted.show_vs, "reconexão no turno ativo retoma diretamente o combate")
	interrupted.reset()
	interrupted.begin_battle("instant-result", 0)
	interrupted.update(0, 1, true)
	_check(interrupted.can_autoclose and not interrupted.show_vs and interrupted.distance_delta == 0, "resultado recebido antes do primeiro frame também não repete apresentação")
	print("ENCOUNTER DIRECTOR PASS: %s checks" % checks)
	quit()
