extends SceneTree
## Rendering fixtures only. Economy and real HTTP flows are covered by ui_smoke/server tests.
class RenderClient extends "res://scripts/main.gd":
	func _api(_path: String, _data: Dictionary, _context: String) -> void:
		pass
	func _save_settings() -> void:
		pass
	func _session_section() -> String:
		return "isolated_render_fixture"

var game: Control
var failures = 0
var directory = "C:/Users/Alienware/AppData/Local/Brumora/taskmon-captures"

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1

func capture(name: String) -> void:
	game.queue_redraw()
	await create_timer(0.08).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(directory)
	check(root.get_texture().get_image().save_png(directory.path_join(name + ".png")) == OK, name)

func creature(id: String, index: int) -> Dictionary:
	var spec = game.by_id[id]
	var values = spec.base.duplicate(true)
	return {"id": "fixture_" + str(index), "species": id, "level": 5, "xp": 55, "next_xp": 200, "rarity": "rare", "shiny": false, "iv": {"hp":8,"attack":8,"defense":8,"speed":8}, "stats": values, "gear_score": 180, "upgrade": 1, "upgrade_cost": {"gold":45,"level":3,"seconds":240,"materials":{"essence":3,"fibre":5}}}

func fighter(c: Dictionary, side: String) -> Dictionary:
	return {"id":c.id,"species":c.species,"name":game.by_id[c.species].name,"level":int(c.level),"stats":c.stats.duplicate(true),"hp":c.stats.hp,"shield":0,"cooldown":0,"shiny":false,"side":side}

func _run() -> void:
	game = RenderClient.new()
	root.add_child(game)
	await create_timer(0.5).timeout
	game.token = ""
	game.pending_requests.clear()
	game.sound_enabled = false
	game.banner_time = 0
	game.route_auto = false
	game.compact_auto = false
	game.auto_battle = false
	check(game.action_regions.get("ember", []).size() == 4, "raposa tem quatro poses de ataque distintas")
	check(game.sprite_regions.size() == 15, "atlas e recortes de todas as 15 espécies")
	for id in game.by_id:
		check(game.sprite_regions.has(id) and game.sprite_regions[id].size.x > 10 and game.sprite_regions[id].size.y > 10, "sprite " + id)
		for kind in ["attack", "skill", "impact"]:
			check(ResourceLoader.exists("res://assets/audio/" + id + "_" + kind + ".wav"), "som " + id + " " + kind)
	game.player = {"id":"fixture","name":"Explorador","gold":245,"region":0,"unlocked":2,"team":[],"collection":[],"expedition":null,"battle":null,"rating":1120,"wins":6,"losses":2,"bosses":[0],"log":[],"gear_score":540,"next_tick":12,"distance":1800,"inventory":{"essence":14,"fibre":23,"pearl":5,"shard":3},"pending_loot":{"core":2},"inventory_capacity":4,"inventory_cost":60,"achievements":[{"name":"Primeiro passo","description":"Vença um encontro PvE","progress":1,"target":1,"unlocked":true}],"materials_catalogue":JSON.parse_string(FileAccess.get_file_as_string("res://assets/materials.json"))}
	var all: Array = []
	for i in range(6):
		all.append(creature(game.catalogue.species[i].id, i))
	game.player.collection = all
	if "--atlas-only" in OS.get_cmdline_user_args():
		game.player.team = [all[0].id, all[1].id, all[2].id]
		game._build_ui()
		game._maps_dialog()
		await capture("taskmon-atlas-hd")
		game.queue_free()
		await process_frame
		print("Atlas review finished, failures=" + str(failures))
		quit(1 if failures else 0)
		return
	for biome in range(3):
		game.player.region = biome
		game.selected_region = biome
		game.player.team = [all[0].id,all[1].id,all[2].id] if biome == 0 else [all[3].id,all[4].id,all[5].id]
		game._build_ui()
		await capture("taskmon-world-" + str(biome))
		await create_timer(0.8).timeout
		await capture("taskmon-idle-" + str(biome))
		game.player.expedition = {"ticks": 0}
		game._build_ui()
		await create_timer(0.35).timeout
		await capture("taskmon-walking-" + str(biome))
		await create_timer(0.22).timeout
		await capture("taskmon-walking-step-" + str(biome))
		await create_timer(0.18).timeout
		print("REVIEW_RUNTIME biome=", biome, " walking fps=", Performance.get_monitor(Performance.TIME_FPS), " process_ms=", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		game.player.expedition = null
		game._build_ui()
		await create_timer(0.90).timeout
		await capture("taskmon-rest-after-walk-" + str(biome))
	var twin = all[1].duplicate(true)
	twin.id = "fixture_moss_independent"
	game.player.collection.append(twin)
	game.player.region = 0
	game.selected_region = 0
	game.player.team = [all[0].id, all[1].id, twin.id]
	game.player.expedition = {"ticks": 0}
	game._build_ui()
	var first_seed = float(absi(str(all[1].id).hash()) % 65521)
	var second_seed = float(absi(str(twin.id).hash()) % 65521)
	check(absf(game.creature_motion.instance_variation(first_seed) - game.creature_motion.instance_variation(second_seed)) > 0.001, "duas criaturas da mesma espécie têm fases próprias por exemplar")
	for speed in [0.5, 1.0, 2.0]:
		game.world_speed_multiplier = speed
		var distance_before = game.route_distance
		var clock_before = game.walk_clock
		await create_timer(0.5).timeout
		check(absf((game.route_distance - distance_before) - (game.walk_clock - clock_before) * 24.0) < 0.01, "mapa e passada sincronizados em velocidade " + str(speed))
		await capture("taskmon-speed-" + str(speed).replace(".", "_") + "-twins")
	game.world_speed_multiplier = 1.0
	game.player.expedition = null
	game.player.collection.erase(twin)
	game.player.team = [all[3].id, all[4].id, all[5].id]
	game._build_ui()
	game.player.gold = 245.125
	game.gain_events = [{"kind": "gold", "value": 0.125, "started": game.elapsed}, {"kind": "xp", "value": 3, "started": game.elapsed}]
	check(game._coins(0.125) == "0,125" and game._coins(245.125) == "245,125", "ganhos decimais mantêm três casas úteis")
	await capture("taskmon-decimal-gains")
	game._inventory_dialog()
	await capture("taskmon-inventory-populated")
	game._maps_dialog()
	await capture("taskmon-atlas-hd")
	game._profile_dialog()
	await capture("taskmon-profile-complete")
	game._collection_dialog(0)
	await capture("taskmon-collection-cards")
	game._creature_dialog(all[0].id)
	await capture("taskmon-creature-upgrade")
	game.modal.hide()
	game.modal.queue_free()
	game.menu_chrome.build_expedition_summary(game, {"id":"review_summary","outcome":"victory","region":0,"duration_seconds":125,"battles":3,"kills":5,"rewards":{"gold":12.375,"xp":17,"items":{"essence":4,"fibre":3}}})
	await capture("taskmon-expedition-summary")
	game.modal.hide()
	game.modal.queue_free()
	for biome in range(3):
		game.player.region = biome
		var enemy_ids = [["thornbud","pebblebug","rootelder"],["reefclaw","tidejelly","abyssmaw"],["runewisp","shardguard","moonwarden"]][biome]
		var enemies: Array = []
		for i in range(3):
			enemies.append(fighter(creature(enemy_ids[i],i+10),"enemy"))
		var allies: Array = []
		for i in range(3):
			allies.append(fighter(all[i+biome],"ally"))
		var battle = {"id":"review_battle_" + str(biome),"region":biome,"kind":"boss","round":1,"allies":allies,"enemies":enemies,"result":null,"rated":false,"messages":[],"events":[]}
		game.player.battle = battle
		game.encounter_director.begin_battle(str(battle.id), game.elapsed, {"restored":true,"round":1})
		game.player.team = [all[biome].id,all[biome+1].id,all[biome+2].id]
		game._build_ui()
		if biome == 0:
			await capture("taskmon-battle-entry")
		await create_timer(0.95).timeout
		await capture("taskmon-boss-" + str(biome))
		await create_timer(0.18).timeout
		print("REVIEW_RUNTIME biome=", biome, " battle fps=", Performance.get_monitor(Performance.TIME_FPS), " process_ms=", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		var previous = battle.duplicate(true)
		battle.events = [{"actor":allies[0].id,"target":enemies[0].id,"species":allies[0].species,"kind":"attack","value":28,"skill":true},{"actor":allies[1].id,"target":allies[1].id,"species":allies[1].species,"kind":"shield","value":24,"skill":true},{"actor":allies[2].id,"target":allies[0].id,"species":allies[2].species,"kind":"heal","value":18,"skill":true}]
		game._animate_round(previous,battle)
		await create_timer(0.3).timeout
		await capture("taskmon-projectile-"+str(biome))
		await create_timer(0.55).timeout
		await capture("taskmon-impact-"+str(biome))
		await create_timer(0.4).timeout
		await capture("taskmon-shield-"+str(biome))
		await create_timer(0.7).timeout
		await capture("taskmon-heal-"+str(biome))
		await create_timer(1).timeout
	print("Visual review finished, failures=" + str(failures))
	quit(1 if failures else 0)
