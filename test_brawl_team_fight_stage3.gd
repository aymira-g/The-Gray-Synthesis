extends SceneTree

const ArenaScene = preload("res://scenes/BrawlArena3D.tscn")
const HeroScript = preload("res://scripts/BrawlHero3D.gd")
const CombatantScript = preload("res://scripts/BrawlCombatant3D.gd")

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("==================================================================")
	print("--- STARTING BRAWL TEAM FIGHT STAGE 3 VERIFICATION ---")
	print("==================================================================")

	var stats := {"passed": 0, "failed": 0}
	var assert_test = func(condition: bool, test_name: String) -> void:
		if condition:
			stats["passed"] += 1
			print("  [PASS] ", test_name)
		else:
			stats["failed"] += 1
			print("  [FAIL] *** ", test_name, " ***")

	var arena := ArenaScene.instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await process_frame

	var blue_heroes: Array[Node] = []
	var red_heroes: Array[Node] = []
	for unit in arena.get_tree().get_nodes_in_group("brawl_units"):
		if String(unit.get("unit_type")) != "hero":
			continue
		if String(unit.get("team_id")) == "blue":
			blue_heroes.append(unit)
		else:
			red_heroes.append(unit)
	assert_test.call(blue_heroes.size() == 5, "Blue team has the player plus four lane bots")
	assert_test.call(red_heroes.size() == 5, "Red team has five enemy lane bots")
	assert_test.call(arena.player.hero_id == "garrick_cole", "Player uses the Garrick frontline kit")
	assert_test.call(arena.ability_status_label.text.contains("Q Cleave") and arena.ability_status_label.text.contains("E Fortify") and arena.ability_status_label.text.contains("R Slam"), "HUD lists the player kit abilities and cooldowns")
	assert_test.call(arena.player.select_hero("nyx_calder") and arena.player.hero_name == "Nyx Calder", "Player can select the Nyx ranger kit")
	assert_test.call(arena.ability_status_label.text.contains("Nyx Calder") and arena.ability_status_label.text.contains("Longshot"), "HUD updates ability names when the player switches kits")
	arena.player.select_hero("garrick_cole")

	var kit_ids := {}
	for hero in blue_heroes + red_heroes:
		kit_ids[String(hero.get("hero_id"))] = true
	assert_test.call(kit_ids.has("garrick_cole") and kit_ids.has("nyx_calder") and kit_ids.has("mira_solis") and kit_ids.has("aris_thorne"), "Five-hero teams use all four roster kits")
	for hero in blue_heroes + red_heroes:
		if hero != arena.player:
			assert_test.call(hero.get("is_bot") == true, "%s is controlled by lane AI" % hero.name)

	var garrick_target := _spawn_test_combatant(arena, "GarrickAbilityTarget", "red", Vector3(-21.0, 0.0, 2.0))
	var health_before: float = garrick_target.get("current_health")
	assert_test.call(arena.player.use_ability("Q"), "Garrick Q cleave activates")
	assert_test.call(garrick_target.get("current_health") < health_before, "Garrick Q damages nearby enemies")
	var player_health_before: float = arena.player.get("current_health")
	arena.player.use_ability("E")
	arena.player.take_damage(100.0)
	assert_test.call(player_health_before - float(arena.player.get("current_health")) < 100.0, "Garrick E reduces incoming damage")

	var garrick_ultimate_target := _spawn_test_combatant(arena, "GarrickUltimateTarget", "red", Vector3(-18.0, 0.0, 2.0))
	health_before = garrick_ultimate_target.get("current_health")
	assert_test.call(arena.player.use_ability("R"), "Garrick R slam activates")
	assert_test.call(garrick_ultimate_target.get("current_health") < health_before, "Garrick R hits enemies in its area")

	var nyx := _spawn_test_hero(arena, "NyxAbilityTester", "nyx_calder", "blue", Vector3(-4.0, 0.0, -4.0))
	var nyx_target := _spawn_test_combatant(arena, "NyxAbilityTarget", "red", Vector3(5.0, 0.0, -4.0))
	health_before = nyx_target.get("current_health")
	assert_test.call(nyx.use_ability("Q"), "Nyx Q ranged shot activates")
	assert_test.call(nyx_target.get("current_health") < health_before, "Nyx Q reaches a distant target")
	var nyx_position: Vector3 = nyx.global_position
	assert_test.call(nyx.use_ability("E") and nyx.global_position != nyx_position, "Nyx E performs an evasive dash")
	var volley_target := _spawn_test_combatant(arena, "NyxVolleyTarget", "red", Vector3(2.0, 0.0, -2.0))
	health_before = volley_target.get("current_health")
	assert_test.call(nyx.use_ability("R"), "Nyx R volley activates")
	assert_test.call(volley_target.get("current_health") < health_before, "Nyx R damages multiple enemies in range")

	var mira := _spawn_test_hero(arena, "MiraAbilityTester", "mira_solis", "blue", Vector3(0.0, 0.0, 4.0))
	var mira_target := _spawn_test_combatant(arena, "MiraAbilityTarget", "red", Vector3(3.0, 0.0, 4.0))
	health_before = mira_target.get("current_health")
	assert_test.call(mira.use_ability("Q"), "Mira Q pressure blast activates")
	assert_test.call(mira_target.get("current_health") < health_before and mira_target.get("slowed_remaining") > 0.0, "Mira Q damages and slows enemies")
	assert_test.call(mira.use_ability("E") and mira_target.get("slowed_remaining") > 0.0, "Mira E applies a wider ground slow")
	assert_test.call(mira.use_ability("R") and mira_target.get("current_health") < health_before, "Mira R tidal burst damages enemies in a wide area")

	var aris := _spawn_test_hero(arena, "ArisAbilityTester", "aris_thorne", "blue", Vector3(0.0, 0.0, -8.0))
	var wounded_ally := _spawn_test_combatant(arena, "ArisWoundedAlly", "blue", Vector3(1.0, 0.0, -8.0))
	wounded_ally.set("unit_type", "hero")
	wounded_ally.set("max_health", 600.0)
	wounded_ally.set("current_health", 600.0)
	wounded_ally.take_damage(500.0)
	var ally_health_before: float = wounded_ally.get("current_health")
	assert_test.call(aris.use_ability("Q"), "Aris Q healing spray activates")
	assert_test.call(wounded_ally.get("current_health") > ally_health_before, "Aris Q heals nearby allies")
	var aris_stun_target := _spawn_test_combatant(arena, "ArisStunTarget", "red", Vector3(2.0, 0.0, -8.0))
	assert_test.call(aris.use_ability("E") and aris_stun_target.get("stunned_remaining") > 0.0, "Aris E stuns a nearby enemy")
	wounded_ally.take_damage(100.0)
	ally_health_before = wounded_ally.get("current_health")
	assert_test.call(aris.use_ability("R"), "Aris R team-wide recovery activates")
	assert_test.call(wounded_ally.get("current_health") > ally_health_before, "Aris R heals allies across a larger radius")

	var blue_bot: Node = blue_heroes[1]
	var lane_enemy := _spawn_test_combatant(arena, "BotBrainTarget", "red", Vector3(4.0, 0.0, 0.0))
	blue_bot.global_position = Vector3(0.0, 0.0, 0.0)
	blue_bot.set("current_health", blue_bot.get("max_health"))
	blue_bot._run_bot_brain()
	assert_test.call(blue_bot.get("_brain_target") != null and String(blue_bot.get("_brain_target").get("team_id")) == "red", "Lane bot acquires nearby enemy units")
	blue_bot.set("current_health", float(blue_bot.get("max_health")) * 0.2)
	blue_bot._run_bot_brain()
	blue_bot._bot_move()
	assert_test.call(blue_bot.get("_brain_target") == null and blue_bot.velocity.x < 0.0, "Low-health blue bot retreats toward its base")

	print("==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if current_scene != null:
		current_scene.queue_free()
	quit(0 if stats["failed"] == 0 else 1)

func _spawn_test_hero(parent: Node, node_name: String, hero_id: String, team_id: String, position: Vector3) -> Node:
	var hero := CharacterBody3D.new()
	hero.name = node_name
	hero.set_script(HeroScript)
	hero.set("hero_id", hero_id)
	hero.set("team_id", team_id)
	hero.position = position
	parent.add_child(hero)
	return hero

func _spawn_test_combatant(parent: Node, node_name: String, team_id: String, position: Vector3) -> Node:
	var combatant := CharacterBody3D.new()
	combatant.name = node_name
	combatant.set_script(CombatantScript)
	combatant.set("team_id", team_id)
	combatant.set("unit_type", "hero")
	combatant.position = position
	parent.add_child(combatant)
	return combatant
