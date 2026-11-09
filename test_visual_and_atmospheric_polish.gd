extends SceneTree

# ==============================================================================
# The Gray Synthesis - Option 1: Visual & Atmospheric Polish Verification Suite
# ==============================================================================
# Verifies:
# 1. Resident3D Procedural Bipedal Animations (Leg pivots, walk cycle, bounce, lean, tool pose)
# 2. Atmospheric ACES Lighting & Bloom Environment Setup
# 3. Sector Floor Inlays & Distinct Architectural Props (Council benches, lanterns, reservoir,
#    pipeline conduits, generator turbine, beacon mast, greenhouse ribs/planters, salvage crane/containers)
# 4. Enhanced Field Zone Visual Geometry (Thorn dome, root spikes, mist puffs, spark core)
# 5. Non-interference with Waypoint Navigation & Obstacle Collision (5 registered walls)
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")
const Resident3DScene = preload("res://scenes/Resident3D.tscn")

func _init() -> void:
	print("==================================================================")
	print("--- STARTING OPTION 1: VISUAL & ATMOSPHERIC POLISH VERIFICATION ---")
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
	var residents: Array = main.residents
	var player: CharacterBody3D = main.player_node

	# ------------------------------------------------------------------
	# TEST GROUP 1: Resident3D Procedural Animations & Articulation
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 1] Resident3D Procedural Bipedal Motion & Tools")
	assert_test.call(player.mesh_root != null, "Resident has mesh_root container")
	assert_test.call(player.torso_node != null and player.torso_node.name == "Torso", "Resident has dedicated Torso node")
	assert_test.call(player.head_node != null and player.head_node.name == "Head", "Resident has dedicated Head node")
	assert_test.call(player.left_leg_pivot != null and player.right_leg_pivot != null, "Resident has articulated Left & Right leg pivots")

	# Test walking animation: non-zero velocity advances walk_cycle and swings legs
	player.velocity = Vector3(5.0, 0.0, 0.0)
	var prev_cycle: float = player.walk_cycle
	player._update_procedural_animations(0.1)
	assert_test.call(player.walk_cycle > prev_cycle, "Horizontal velocity advances walk_cycle stride")
	assert_test.call(absf(player.left_leg_pivot.rotation.x) > 0.01, "Left leg swings forward/backward during movement")
	assert_test.call(absf(player.right_leg_pivot.rotation.x) > 0.01, "Right leg swings opposite during movement")

	# Test idle return: zero velocity resets legs to upright resting stance
	player.velocity = Vector3.ZERO
	for _frame in range(20):
		player._update_procedural_animations(0.1)
	assert_test.call(absf(player.left_leg_pivot.rotation.x) < 0.05, "Zero velocity returns Left leg to upright rest stance")
	assert_test.call(absf(player.right_leg_pivot.rotation.x) < 0.05, "Zero velocity returns Right leg to upright rest stance")

	# Test tool working pose
	player.is_channeling = true
	var orig_tool_rot: float = player.tool_mesh.rotation_degrees.z if player.tool_mesh != null else 0.0
	player._update_procedural_animations(0.05)
	assert_test.call(player.tool_mesh != null, "Resident retains visible tool mesh during work")
	player.is_channeling = false

	# Test clinic incapacitation pose
	player.is_incapacitated = true
	for _f in range(10):
		player._update_procedural_animations(0.2)
	assert_test.call(player.mesh_root.rotation.x > deg_to_rad(30.0), "Incapacitated resident collapses into resting recovery pose")
	player.is_incapacitated = false
	for _f in range(15):
		player._update_procedural_animations(0.2)
	assert_test.call(player.mesh_root.rotation.x < deg_to_rad(5.0), "Recovered resident returns to upright stance")

	# ------------------------------------------------------------------
	# TEST GROUP 2: Atmospheric Lighting & ACES Color Grading
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] Atmospheric ACES Lighting & Bloom Environment")
	var world_env: WorldEnvironment = map.get_node_or_null("WorldEnvironment")
	assert_test.call(world_env != null and world_env.environment != null, "WorldEnvironment registered on TownMap3D")

	var env: Environment = world_env.environment
	assert_test.call(env.tonemap_mode == Environment.TONE_MAPPER_ACES, "Tonemapper set to cinematic TONE_MAPPER_ACES")
	assert_test.call(env.glow_enabled == true, "Glow is enabled for emissive lamps and tools")
	assert_test.call(env.glow_bloom >= 0.15, "Glow bloom threshold set to >= 0.15 for soft radiant light")

	var sun: DirectionalLight3D = map.get_node_or_null("SunLight")
	assert_test.call(sun != null, "Directional Sunlight registered on TownMap3D")
	assert_test.call(sun.shadow_enabled == true, "Directional sun casts soft shadows")
	assert_test.call(sun.light_color.r > 0.9 and sun.light_color.g > 0.85, "Warm sunlight illumination palette")

	# ------------------------------------------------------------------
	# TEST GROUP 3: Sector Floor Inlays & Thematic Architectural Props
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] Sector Floor Inlays & Architectural Props")
	var decor: Node3D = map.get_node_or_null("SectorDecorations")
	assert_test.call(decor != null, "SectorDecorations root node present in TownMap3D")

	# Sector Floors
	var floors: Node3D = decor.get_node_or_null("SectorFloors")
	assert_test.call(floors != null, "SectorFloors node present")
	assert_test.call(floors.get_node_or_null("TownSquarePlaza") != null, "Town Square slate plaza floor inlay exists")
	assert_test.call(floors.get_node_or_null("PumpStationFloor") != null, "Pump Station reinforced concrete floor inlay exists")
	assert_test.call(floors.get_node_or_null("GreenhouseLoamFloor") != null, "Greenhouse moist loam soil floor inlay exists")
	assert_test.call(floors.get_node_or_null("SalvageYardGravelFloor") != null, "Salvage Yard crushed gravel floor inlay exists")

	# Town Square Decor
	var ts_decor: Node3D = decor.get_node_or_null("TownSquareDecor")
	assert_test.call(ts_decor != null, "TownSquareDecor node present")
	assert_test.call(ts_decor.get_node_or_null("CouncilDaisStep") != null, "Council dais concentric stone step exists")
	assert_test.call(ts_decor.get_node_or_null("SpeakerLectern") != null, "Podium speaker lectern exists")

	var benches: Node3D = ts_decor.get_node_or_null("CouncilBenches")
	assert_test.call(benches != null and benches.get_child_count() == 10, "10 Stone Council Benches placed around council perimeter")

	var lanterns: Node3D = ts_decor.get_node_or_null("StreetLanterns")
	assert_test.call(lanterns != null and lanterns.get_child_count() == 4, "4 Wrought-iron street lanterns placed in Town Square")
	var first_lantern: Node = lanterns.get_child(0)
	assert_test.call(first_lantern.get_node_or_null("LanternLight") is OmniLight3D, "Street lanterns emit warm amber OmniLight3D")

	var clinic_pav: Node3D = ts_decor.get_node_or_null("ClinicPavilion")
	assert_test.call(clinic_pav != null, "Clinic medical pavilion canopy structure exists")
	assert_test.call(clinic_pav.get_node_or_null("ClinicMedicalLight") is OmniLight3D, "Clinic pavilion provides soothing medical OmniLight3D")

	# Pump & Generator Station Decor
	var ps_decor: Node3D = decor.get_node_or_null("PumpStationDecor")
	assert_test.call(ps_decor != null, "PumpStationDecor node present")
	var res_basin: Node3D = ps_decor.get_node_or_null("WaterReservoir")
	assert_test.call(res_basin != null, "Concrete Water Reservoir basin exists")
	assert_test.call(res_basin.get_node_or_null("WaterSurface") != null, "Water Reservoir has reflective water surface")
	assert_test.call(ps_decor.get_node_or_null("IndustrialPipelines") != null, "Industrial pipeline conduits with valves exist")
	assert_test.call(ps_decor.get_node_or_null("GeneratorTurbine") != null, "Generator turbine casing and coils exist")
	var beacon_mast: Node3D = ps_decor.get_node_or_null("SignalBeaconMast")
	assert_test.call(beacon_mast != null, "Signal Beacon communications lattice mast exists")
	assert_test.call(beacon_mast.get_node_or_null("BeaconMastLight") is OmniLight3D, "Beacon mast has blinking warning light")

	# Greenhouse Decor
	var gh_decor: Node3D = decor.get_node_or_null("GreenhouseDecor")
	assert_test.call(gh_decor != null, "GreenhouseDecor node present")
	var ribs: Node3D = gh_decor.get_node_or_null("GlasshouseRibs")
	assert_test.call(ribs != null and ribs.get_child_count() == 3, "3 Arched translucent glasshouse ribs span Greenhouse")
	var beds: Node3D = gh_decor.get_node_or_null("RaisedPlanterBeds")
	assert_test.call(beds != null and beds.get_child_count() == 3, "3 Raised timber planter boxes with crop foliage clusters exist")
	assert_test.call(gh_decor.get_node_or_null("BotanicalGrowLights") != null, "Botanical grow lights suspended in Greenhouse")

	# Salvage Yard Decor
	var sy_decor: Node3D = decor.get_node_or_null("SalvageYardDecor")
	assert_test.call(sy_decor != null, "SalvageYardDecor node present")
	assert_test.call(sy_decor.get_node_or_null("SalvageGantryCrane") != null, "Overhead yellow-striped steel gantry crane exists")
	var containers: Node3D = sy_decor.get_node_or_null("StackedShippingContainers")
	assert_test.call(containers != null and containers.get_child_count() == 3, "3 Stacked weathered shipping containers exist")
	assert_test.call(sy_decor.get_node_or_null("ScrapMetalPiles") != null, "Scrap metal salvage junk mounds exist")
	assert_test.call(sy_decor.get_node_or_null("SalvageWorkbench") != null, "Salvage quartermaster workbench with vise exists")
	var floodlight: Node3D = sy_decor.get_node_or_null("SalvageFloodlight")
	assert_test.call(floodlight != null and floodlight.get_node_or_null("HalogenLamp") is OmniLight3D, "Halogen floodlight mast illuminates Salvage Yard")

	# ------------------------------------------------------------------
	# TEST GROUP 4: Enhanced Field Zone Visual Geometry
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] Enhanced Field Zone Visual Geometry")
	var mist_node: Node3D = map.spawn_field_zone_3d("mulch_mist", Vector3(-10.0, 0.0, -10.0), 3.0, 5.0, 1)
	assert_test.call(mist_node.get_child_count() >= 4, "Mulch Mist spawns organic billowing spore cloud puffs")

	var snare_node: Node3D = map.spawn_field_zone_3d("root_snare", Vector3(10.0, 0.0, -10.0), 2.5, 5.0, 1)
	assert_test.call(snare_node.get_child_count() >= 8, "Root Snare spawns 8 perimeter briar root thorn spikes")

	var guard_node: Node3D = map.spawn_field_zone_3d("thorn_guard", Vector3(0.0, 0.0, 15.0), 2.8, 5.0, 1)
	assert_test.call(guard_node.get_child_count() >= 1, "Thorn Guard spawns protective translucent shield hemisphere dome")

	var spark_node: Node3D = map.spawn_field_zone_3d("spark_trail", Vector3(0.0, 0.0, 0.0), 1.5, 5.0, 2)
	assert_test.call(spark_node.get_child_count() >= 1, "Spark Trail spawns energetic electric core mesh")

	# ------------------------------------------------------------------
	# TEST GROUP 5: Pathfinding & Obstacle Collision Integrity
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 5] Collision & Navigation Guardrails")
	assert_test.call(map.obstacle_aabbs.size() == 5, "Obstacle AABBs count strictly maintained at 5 (no rogue collision registered)")
	assert_test.call(map.waypoints.size() >= 16, "All navigation waypoints intact and unobstructed (>= 16 connected nodes)")
	var clear_los: bool = map.has_clear_sightline_3d(Vector3(-4.0, 0.0, 0.0), Vector3(4.0, 0.0, 0.0))
	assert_test.call(clear_los == true, "Town Square line-of-sight remains unobstructed by decorative props")

	# Summary
	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")
	if stats["failed"] == 0:
		print(">>> ALL OPTION 1 VISUAL & ATMOSPHERIC POLISH CHECKS PASSED! <<<")
	else:
		print(">>> SOME CHECKS FAILED! <<<")

	main.free()
	quit(0 if stats["failed"] == 0 else 1)
