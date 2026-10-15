extends "res://tests/visual_review.gd"
## Presentation fixture: no account, network or saved settings are modified.
func _run() -> void:
 game=RenderClient.new()
 root.add_child(game)
 game.sound_enabled=false
 game.token=""
 game.auto_battle=false
 game.route_auto=false
 game.compact_auto=false
 game.banner_time=0
 await process_frame
 game.player={"id":"encounter-fixture","name":"Explorador","gold":31.625,"region":0,"unlocked":2,"team":[],"collection":[],"expedition":null,"battle":null,"rating":1000,"wins":0,"losses":0,"bosses":[],"log":[],"gear_score":236,"next_tick":12,"distance":840,"inventory":{},"pending_loot":{},"inventory_capacity":4}
 var roster: Array=[]
 for i in range(3): roster.append(creature(["ember","moss","luna"][i],i))
 game.player.collection=roster
 game.player.team=[roster[0].id,roster[1].id,roster[2].id]
 for biome in range(3):
  game.encounter_director.reset(game.elapsed)
  game.player.region=biome
  game.selected_region=biome
  game.player.battle=null
  game.player.expedition={"id":"journey_"+str(biome),"ticks":0}
  game._build_ui()
  await create_timer(0.08).timeout
  check(is_equal_approx(game._world_rect().size.y,720.0),"exploração amplia 720 px, bioma "+str(biome))
  await capture("taskmon-encounter-travel-"+str(biome))
  var allies: Array=[]
  var enemies: Array=[]
  for i in range(3):
   allies.append(fighter(roster[i],"ally"))
   enemies.append(fighter(creature([["thornbud","pebblebug","rootelder"],["reefclaw","tidejelly","abyssmaw"],["runewisp","shardguard","moonwarden"]][biome][i],i+10),"enemy"))
  var battle={"id":"visual_"+str(biome),"region":biome,"kind":"wild","round":0,"allies":allies,"enemies":enemies,"result":null,"messages":[],"events":[]}
  game.player.battle=battle
  game.encounter_director.begin_battle(battle.id,game.elapsed,{"journey_active":true,"round":0})
  game._build_ui()
  await create_timer(0.4).timeout
  check(game.encounter_director.phase==&"approach" and game.battle_blend==0 and game._presentation_locked(),"aproximação precede zoom e bloqueia comandos, bioma "+str(biome))
  await capture("taskmon-encounter-approach-"+str(biome))
  await create_timer(1.8).timeout
  check(game.encounter_director.phase==&"engage" and game.encounter_director.show_vs,"VS aparece depois da aproximação, bioma "+str(biome))
  await capture("taskmon-encounter-engage-"+str(biome))
  await create_timer(0.95).timeout
  check(game.encounter_director.can_act and is_equal_approx(game.battle_blend,1.0),"combate pronto após zoom, bioma "+str(biome))
  await capture("taskmon-encounter-combat-"+str(biome))
  var gap=game.unit_positions[enemies[1].id].x-game.unit_positions[enemies[0].id].x
  check(gap>=156.0,"barras HP inimigas de 148 px têm 8 px de intervalo, bioma "+str(biome))
  game.player.battle=null
  game.encounter_director.end_battle(game.elapsed)
  await create_timer(0.35).timeout
  check(game.battle_blend>0 and game.battle_blend<1,"zoom out intermediário suave, bioma "+str(biome))
  await capture("taskmon-encounter-disengage-"+str(biome))
  await create_timer(0.6).timeout
  check(game.encounter_director.phase==&"travel" and game.battle_blend==0,"exploração restaura câmera, bioma "+str(biome))
  await capture("taskmon-encounter-return-"+str(biome))
 print("Encounter visual integration: failures=",failures)
 game.queue_free()
 await process_frame
 quit(1 if failures else 0)
