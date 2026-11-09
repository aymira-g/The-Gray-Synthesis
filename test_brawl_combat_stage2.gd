extends SceneTree

const ArenaScene = preload("res://scenes/BrawlArena3D.tscn")
const CombatantScript = preload("res://scripts/BrawlCombatant3D.gd")
const MinionScript = preload("res://scripts/BrawlMinion3D.gd")

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("==================================================================")
	print("--- STARTING BRAWL COMBAT STAGE 2 VERIFICATION ---")
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

	assert_test.call(arena.player.get("current_health") == arena.player.get("max_health") and arena.player.get("current_mana") == arena.player.get("max_mana"), "Player spawns with full health and mana")
	assert_test.call(arena.player_health_bar != null and arena.player_mana_bar != null, "HUD displays player health and mana bars")
	assert_test.call(arena.get_tree().get_nodes_in_group("brawl_units").size() >= 9, "Initial waves spawn three minions for both teams")

	var red_minion: Node3D
	for unit in arena.get_tree().get_nodes_in_group("brawl_units"):
		if String(unit.get("unit_type")) == "minion" and String(unit.get("team_id")) == "red":
			red_minion = unit
			break
	assert_test.call(red_minion != null, "Enemy minion is registered as a combat target")
	if red_minion != null:
		red_minion.global_position = arena.player.global_position + Vector3(2.5, 0.0, 0.0)
		var before_attack: float = red_minion.get("current_health")
		assert_test.call(arena.player.attack_nearest_enemy(), "Player basic attack hits an enemy in range")
		assert_test.call(red_minion.get("current_health") < before_attack, "Basic attack applies damage")
		assert_test.call(arena.get_tree().get_nodes_in_group("brawl_damage_numbers").size() > 0, "Damage creates a floating damage number")
		assert_test.call(not arena.player.attack_nearest_enemy(), "Attack cooldown prevents an immediate second hit")
		arena.player.take_damage(35.0, red_minion)
		assert_test.call(arena.player_health_bar.value < 100.0, "Player health HUD updates when damage is received")

	var blue_minion: Node3D
	for unit in arena.get_tree().get_nodes_in_group("brawl_units"):
		if String(unit.get("unit_type")) == "minion" and String(unit.get("team_id")) == "blue":
			blue_minion = unit
			break
	assert_test.call(blue_minion != null and not arena.player.try_basic_attack(blue_minion), "Player basic attack cannot hit an ally")

	if blue_minion != null and red_minion != null:
		blue_minion.global_position = Vector3(0.0, 0.0, 0.0)
		red_minion.global_position = Vector3(1.4, 0.0, 0.0)
		var before_minion_attack: float = red_minion.get("current_health")
		blue_minion._physics_process(0.1)
		assert_test.call(red_minion.get("current_health") < before_minion_attack, "Minions engage and damage nearby enemies")

	var red_turret: Node3D = arena.get_node("Arena/RedTurret")
	assert_test.call(red_turret.get("max_health") > 0.0 and red_turret.get("health_bar_fill") != null, "Turrets have health and a visible health bar")
	if blue_minion != null:
		blue_minion.global_position = red_turret.global_position + Vector3(-5.0, 0.0, 2.0)
		red_turret.set("attack_cooldown_remaining", 0.0)
		assert_test.call(red_turret.select_target() == blue_minion, "Turret prioritizes enemy minions")
		var before_turret_attack: float = blue_minion.get("current_health")
		assert_test.call(red_turret.fire_at(blue_minion), "Turret can fire at an enemy in range")
		assert_test.call(blue_minion.get("current_health") < before_turret_attack, "Turret attack applies damage")

	var enemy_hero := CharacterBody3D.new()
	enemy_hero.name = "TurretAggroTestHero"
	enemy_hero.set_script(CombatantScript)
	enemy_hero.set("team_id", "blue")
	enemy_hero.set("unit_type", "hero")
	enemy_hero.position = red_turret.global_position + Vector3(-3.0, 0.0, -2.0)
	arena.add_child(enemy_hero)
	var defended_hero := CharacterBody3D.new()
	defended_hero.name = "TurretDefendedTestHero"
	defended_hero.set_script(CombatantScript)
	defended_hero.set("team_id", "red")
	defended_hero.set("unit_type", "hero")
	defended_hero.position = enemy_hero.position + Vector3(1.0, 0.0, 0.0)
	arena.add_child(defended_hero)
	await process_frame
	assert_test.call(red_turret.select_target() == blue_minion, "Turret keeps minions as its default target over heroes")
	enemy_hero.try_basic_attack(defended_hero)
	assert_test.call(red_turret.select_target() == enemy_hero, "Turret retaliates against a hero who attacks within range")
	enemy_hero.queue_free()
	defended_hero.queue_free()

	var wave_before: int = arena.get("_wave_number")
	arena.set("_wave_timer", 0.0)
	arena._process(0.1)
	assert_test.call(arena.get("_wave_number") == wave_before + 1, "Minion waves spawn automatically on the interval")
	assert_test.call(arena.wave_status_label.text.contains("Wave %d" % (wave_before + 1)), "HUD reports the current wave")

	arena.player.set("current_mana", 80.0)
	arena.player._process(2.0)
	assert_test.call(arena.player.get("current_mana") > 80.0, "Player mana regenerates over time")
	assert_test.call(arena.player_mana_bar.value > 80.0, "Mana HUD updates with regeneration")

	print("==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if current_scene != null:
		current_scene.queue_free()
	quit(0 if stats["failed"] == 0 else 1)
