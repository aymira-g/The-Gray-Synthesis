extends SceneTree

# ==============================================================================
# The Gray Synthesis - Step 3: Restrained Atmospheric Effects Test Suite
# ==============================================================================
# Verifies:
# 1. Subtle Pump Steam (Reservoir condensation vapor, low-density CPUParticles3D).
# 2. Greenhouse Spores (Bioluminescent agricultural drifting motes under canopy).
# 3. Generator Turbine Sparks (Occasional micro electric arcs around copper induction coil).
# 4. Task Channeling Progress Ring (Clean 3D ground ring tracking task % and alcove inspection).
# 5. Non-Interference Guardrails (Zero physics collision clutter or navigation disruption).
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")
const Resident3DScene = preload("res://scenes/Resident3D.tscn")

func _init() -> void:
	print("==================================================================")
	print("--- STARTING STEP 3: RESTRAINED ATMOSPHERIC EFFECTS TEST ---")
	print("==================================================================")

	var stats := {"passed": 0, "failed": 0}

	var assert_test = func(condition: bool, test_name: String) -> void:
		if condition:
			stats["passed"] += 1
			print("  [PASS] ", test_name)
		else:
			stats["failed"] += 1
			print("  [FAIL] *** ", test_name, " ***")

	var main: Node3D = Main3DScene.instantiate()
	root.add_child(main)
	main._ready()

	var map: Node3D = main.town_map
	var player: CharacterBody3D = main.player_node

	# ------------------------------------------------------------------
	# TEST GROUP 1: Subtle Pump Station Steam Vent
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 1] Subtle Pump Station Steam Vent")
	var ps_decor: Node = map.get_node_or_null("SectorDecorations/PumpStationDecor")
	assert_test.call(ps_decor != null, "PumpStationDecor container exists")

	var steam: CPUParticles3D = ps_decor.get_node_or_null("PumpStationSteam")
	assert_test.call(steam != null, "PumpStationSteam CPUParticles3D node exists")
	assert_test.call(steam.amount <= 32 and steam.amount >= 8, "Restrained steam density (<= 32 particles to avoid map clutter)")
	assert_test.call(steam.gravity.y > 0.0, "Steam particles display buoyant upward vertical rise")
	assert_test.call(steam.position.distance_to(Vector3(-14.0, 0.6, 26.0)) < 1.0, "Steam is localized directly at water reservoir overflow valve")

	var s_mesh: SphereMesh = steam.mesh as SphereMesh
	assert_test.call(s_mesh != null and s_mesh.material != null, "Steam uses soft spherical particle mesh")
	var s_mat: StandardMaterial3D = s_mesh.material as StandardMaterial3D
	assert_test.call(s_mat != null and s_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Steam material features soft alpha transparency")

	# ------------------------------------------------------------------
	# TEST GROUP 2: Greenhouse Bioluminescent Spores
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] Greenhouse Bioluminescent Spores")
	var gh_decor: Node = map.get_node_or_null("SectorDecorations/GreenhouseDecor")
	assert_test.call(gh_decor != null, "GreenhouseDecor container exists")

	var spores: CPUParticles3D = gh_decor.get_node_or_null("GreenhouseSpores")
	assert_test.call(spores != null, "GreenhouseSpores CPUParticles3D node exists")
	assert_test.call(spores.amount <= 32 and spores.amount >= 12, "Restrained spore density (<= 32 particles)")
	assert_test.call(absf(spores.gravity.y) <= 0.05, "Spores have near-weightless ambient drifting dynamics")
	assert_test.call(spores.position.x < -10.0 and spores.position.z < -15.0, "Spores distributed within greenhouse crop canopy")

	var sp_mesh: SphereMesh = spores.mesh as SphereMesh
	assert_test.call(sp_mesh != null and sp_mesh.material != null, "Spores use delicate particle motes")
	var sp_mat: StandardMaterial3D = sp_mesh.material as StandardMaterial3D
	assert_test.call(sp_mat != null and sp_mat.emission_enabled == true, "Spores feature bioluminescent emission")

	# ------------------------------------------------------------------
	# TEST GROUP 3: Generator Turbine Induction Sparks
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] Generator Turbine Induction Sparks")
	var turbine: Node = ps_decor.get_node_or_null("GeneratorTurbine")
	assert_test.call(turbine != null, "GeneratorTurbine node exists")

	var sparks: CPUParticles3D = turbine.get_node_or_null("TurbineSparks")
	assert_test.call(sparks != null, "TurbineSparks CPUParticles3D node exists on generator turbine")
	assert_test.call(sparks.amount <= 16, "Restrained spark burst count (<= 16 particles)")
	assert_test.call(sparks.explosiveness >= 0.60, "High explosiveness (>= 0.60) simulating intermittent electrical discharge")
	assert_test.call(sparks.emission_shape == CPUParticles3D.EMISSION_SHAPE_RING, "Sparks radiate from ring shape around induction coils")

	var spark_mesh: BoxMesh = sparks.mesh as BoxMesh
	assert_test.call(spark_mesh != null and spark_mesh.material != null, "Sparks use sharp micro-arc mesh")
	var spark_mat: StandardMaterial3D = spark_mesh.material as StandardMaterial3D
	assert_test.call(spark_mat != null and spark_mat.emission_enabled == true and spark_mat.emission_energy_multiplier >= 2.0, "Sparks feature high-intensity electric emission")

	# ------------------------------------------------------------------
	# TEST GROUP 4: 3D Task Channeling Progress Ring
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] 3D Task Channeling & Inspection Progress Ring")
	main.game_manager.set_phase(main.game_manager.Phase.OPEN_TOWN)

	assert_test.call(player.channel_progress_ring != null, "Resident has ChannelProgressRing node")
	assert_test.call(player.channel_progress_ring.visible == false, "ChannelProgressRing hidden while resident is idle")

	# Test 1: Channeling Pad Progress Ring
	var pump_pad: Dictionary = map.get_pad_by_id("pump")
	assert_test.call(not pump_pad.is_empty(), "Pump task station found")

	player.position = pump_pad["position"] + Vector3(0.5, 0.0, 0.5)
	player.active_pad = pump_pad
	player.is_channeling = true
	player.channel_progress = 0.0

	# Process frame
	player._physics_process(0.1)

	assert_test.call(player.channel_progress_ring.visible == true, "ChannelProgressRing appears during active task channeling")
	assert_test.call(player.channel_progress_ring.position.y <= 0.08, "Progress ring rendered flush at floor level")
	var initial_scale: Vector3 = player.channel_progress_ring.scale

	# Advance channeling to 80%
	var req_dur: float = 2.0 * player.task_channel_scale
	player.channel_progress = req_dur * 0.8
	player._physics_process(0.1)

	var mid_scale: Vector3 = player.channel_progress_ring.scale
	assert_test.call(mid_scale.x > initial_scale.x, "Progress ring scale expands dynamically with task progress (%.2f > %.2f)" % [mid_scale.x, initial_scale.x])
	assert_test.call(player.channel_ring_mat.emission_energy_multiplier > 1.5, "Ring emission intensity brightens as task nears completion")

	# Cancel channeling
	player.cancel_channeling()
	assert_test.call(player.channel_progress_ring.visible == false, "Progress ring hides immediately when channeling is canceled")

	# Test 2: Bedrock Alcove Inspection Progress Ring
	player.is_inspecting = true
	player.inspection_timer = 2.0
	player._physics_process(0.1)

	assert_test.call(player.channel_progress_ring.visible == true, "ChannelProgressRing appears during secluded alcove inspection")
	player.cancel_inspection()
	assert_test.call(player.channel_progress_ring.visible == false, "Progress ring hides immediately when inspection is canceled")

	# ------------------------------------------------------------------
	# TEST GROUP 5: Non-Interference & Clutter Guardrails
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 5] Collision & Clutter Guardrails")
	# Verify that no particle node or visual ring contains physics collision shapes
	assert_test.call(steam.get_node_or_null("CollisionShape3D") == null, "Steam particles have zero collision shapes")
	assert_test.call(spores.get_node_or_null("CollisionShape3D") == null, "Greenhouse spores have zero collision shapes")
	assert_test.call(sparks.get_node_or_null("CollisionShape3D") == null, "Turbine sparks have zero collision shapes")
	assert_test.call(player.channel_progress_ring.get_node_or_null("CollisionShape3D") == null, "Progress ring has zero collision shapes")

	# Obstacle count remains strictly locked at 5
	assert_test.call(map.obstacle_aabbs.size() == 5, "Static obstacle count strictly preserved at 5 (no pathfinding interference)")

	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")

	if stats["failed"] == 0:
		print(">>> ALL STEP 3 RESTRAINED ATMOSPHERIC EFFECTS CHECKS PASSED! <<<")
	else:
		print("!!! STEP 3 VERIFICATION ENCOUNTERED FAILURES !!!")

	quit(0 if stats["failed"] == 0 else 1)
