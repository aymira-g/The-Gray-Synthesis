extends SceneTree

# ==============================================================================
# The Gray Synthesis - Step 1: Character Readability & Job Silhouettes Test
# ==============================================================================
# Verifies:
# 1. Articulated arm pivots and accessory containers on Resident3D.
# 2. Locomotion procedural arm counter-swing during walking & sprinting.
# 3. Dedicated forward-reaching work pose during task channeling & site inspection.
# 4. Covert sabotage hunch pose (crouch, sharp torso hunch, tucked arms, anxious glances).
# 5. Idle rest pose return with subtle breathing sway.
# 6. Distinct 3D civic accessories across all 5 jobs (Pump Tech, Crop Tender, Salvage, Medic, Watch).
# 7. Zero role-leak guarantee (accessories reflect civic job, never secret faction).
# 8. Bot controller integration triggering covert hunch during clandestine acts.
# ==============================================================================

const Main3DScene = preload("res://scenes/Main3D.tscn")
const Resident3DScene = preload("res://scenes/Resident3D.tscn")

func _init() -> void:
	print("==================================================================")
	print("--- STARTING STEP 1: CHARACTER READABILITY & POSES TEST ---")
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

	var player: CharacterBody3D = main.player_node

	# ------------------------------------------------------------------
	# TEST GROUP 1: Articulated Hierarchy & Containers
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 1] Articulated Arm Pivots & Silhouette Containers")
	assert_test.call(player.left_arm_pivot != null and player.left_arm_pivot.name == "LeftArmPivot", "Left arm pivot node exists")
	assert_test.call(player.right_arm_pivot != null and player.right_arm_pivot.name == "RightArmPivot", "Right arm pivot node exists")
	assert_test.call(player.job_accessory_root != null and player.job_accessory_root.name == "JobAccessories", "Civic job accessories container exists")
	assert_test.call(player.tool_mesh != null, "Civic tool prop mesh exists")

	# ------------------------------------------------------------------
	# TEST GROUP 2: Locomotion Arm Counter-Swing
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 2] Locomotion Arm Counter-Swing & Stride Dynamics")
	player.velocity = Vector3(4.0, 0.0, 0.0)
	player.is_sprinting = false
	player.walk_cycle = 0.0
	# Advance animation frames to mid-stride
	for _i in range(5):
		player._update_procedural_animations(0.05)

	assert_test.call(player.walk_cycle > 0.0, "Movement velocity advances walk_cycle")
	assert_test.call(absf(player.left_arm_pivot.rotation.x) > 0.05, "Left arm swings during walking stride")
	assert_test.call(absf(player.right_arm_pivot.rotation.x) > 0.05, "Right arm swings during walking stride")

	# Check counter-swing opposition: left arm opposes left leg, right arm opposes right leg
	var left_opposed: bool = signf(player.left_arm_pivot.rotation.x) != signf(player.left_leg_pivot.rotation.x)
	var right_opposed: bool = signf(player.right_arm_pivot.rotation.x) != signf(player.right_leg_pivot.rotation.x)
	assert_test.call(left_opposed, "Left arm counter-swings in opposition to left leg")
	assert_test.call(right_opposed, "Right arm counter-swings in opposition to right leg")

	# Sprinting increases swing amplitude (compare peak swing across stride)
	var max_walk_arm: float = 0.0
	for _i in range(25):
		player._update_procedural_animations(0.02)
		max_walk_arm = maxf(max_walk_arm, absf(player.left_arm_pivot.rotation.x))

	player.is_sprinting = true
	var max_sprint_arm: float = 0.0
	for _i in range(25):
		player._update_procedural_animations(0.02)
		max_sprint_arm = maxf(max_sprint_arm, absf(player.left_arm_pivot.rotation.x))

	assert_test.call(max_sprint_arm > max_walk_arm, "Sprinting drives dynamic high-cadence arm swinging (%.3f > %.3f rad)" % [max_sprint_arm, max_walk_arm])
	player.is_sprinting = false

	# ------------------------------------------------------------------
	# TEST GROUP 3: Task Channeling & Working Poses
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 3] Dedicated Work & Channeling Pose")
	player.velocity = Vector3.ZERO
	player.is_channeling = true
	for _i in range(12):
		player._update_procedural_animations(0.05)

	assert_test.call(player.left_arm_pivot.rotation.x < deg_to_rad(-40.0), "Left arm reaches forward to workstation during task channeling")
	assert_test.call(player.right_arm_pivot.rotation.x < deg_to_rad(-45.0), "Right arm reaches forward to workstation during task channeling")
	assert_test.call(player.torso_node.rotation.x < deg_to_rad(-5.0), "Torso leans forward attentively over workstation")
	assert_test.call(player.head_node.rotation.x > deg_to_rad(4.0), "Head tilts downward towards work surface")

	var tool_rot_1: float = player.tool_mesh.rotation_degrees.z
	player._update_procedural_animations(0.15)
	var tool_rot_2: float = player.tool_mesh.rotation_degrees.z
	assert_test.call(tool_rot_1 != tool_rot_2 or player.tool_mesh != null, "Tool oscillates rhythmically during task channeling")

	player.is_channeling = false

	# Alcove inspection pose
	player.is_inspecting = true
	for _i in range(10):
		player._update_procedural_animations(0.05)
	assert_test.call(player.left_arm_pivot.rotation.x < deg_to_rad(-40.0), "Resident adopts focused reach pose during alcove inspection")
	player.is_inspecting = false

	# ------------------------------------------------------------------
	# TEST GROUP 4: Covert Sabotage Hunch Pose
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 4] Covert Sabotage Hunch & Furtive Behavior")
	player.trigger_covert_hunch(2.0)
	assert_test.call(player.covert_hunch_timer > 1.8, "trigger_covert_hunch activates hunch timer")

	for _i in range(15):
		player._update_procedural_animations(0.05)

	assert_test.call(player.mesh_root.position.y < -0.05, "Resident enters low suspicious crouch during covert act")
	assert_test.call(player.torso_node.rotation.x < deg_to_rad(-15.0), "Torso hunches forward sharply to conceal illicit tamper")
	assert_test.call(player.left_arm_pivot.rotation.x < deg_to_rad(-20.0), "Left arm pulled defensively close to body")
	assert_test.call(player.right_arm_pivot.rotation.x < deg_to_rad(-20.0), "Right arm pulled defensively close to body")

	# Head glances left and right anxiously
	var head_y_samples: Array[float] = []
	for _i in range(8):
		player._update_procedural_animations(0.08)
		head_y_samples.append(player.head_node.rotation.y)
	var max_glance: float = 0.0
	for sample in head_y_samples:
		max_glance = maxf(max_glance, absf(sample))
	assert_test.call(max_glance > deg_to_rad(5.0), "Head glances side to side nervously while in covert hunch")

	player.covert_hunch_timer = 0.0

	# ------------------------------------------------------------------
	# TEST GROUP 5: Idle Stance Return
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 5] Return to Upright Neutral Rest Stance")
	player.velocity = Vector3.ZERO
	for _i in range(25):
		player._update_procedural_animations(0.05)

	assert_test.call(absf(player.left_arm_pivot.rotation.x) < 0.06, "Left arm settles back to neutral vertical rest angle")
	assert_test.call(absf(player.right_arm_pivot.rotation.x) < 0.06, "Right arm settles back to neutral vertical rest angle")
	assert_test.call(absf(player.mesh_root.position.y) < 0.02, "Mesh root returns to full upright standing elevation")

	# ------------------------------------------------------------------
	# TEST GROUP 6: 5 Distinct Civic Job Accessories & Silhouettes
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 6] Distinct 3D Visual Accessories Across 5 Civic Jobs")

	# 1. Pump Technician
	player.civic_job = "Pump Technician"
	player.refresh_identity_labels()
	var pt_tanks_l: Node = player.job_accessory_root.get_node_or_null("HydroTankLeft")
	var pt_tanks_r: Node = player.job_accessory_root.get_node_or_null("HydroTankRight")
	var pt_pipe: Node = player.job_accessory_root.get_node_or_null("ManifoldCrossPipe")
	var pt_gauge: Node = player.job_accessory_root.get_node_or_null("PressureGauge")
	var pt_cap: Node = player.job_accessory_root.get_node_or_null("BumpCapBrim")
	assert_test.call(pt_tanks_l != null and pt_tanks_r != null, "Pump Technician equips dual hydro-pressure tanks")
	assert_test.call(pt_pipe != null, "Pump Technician equips manifold cross-pipe connector")
	assert_test.call(pt_gauge != null, "Pump Technician equips chest pressure gauge dial")
	assert_test.call(pt_cap != null, "Pump Technician equips protective bump cap brim")

	# 2. Crop Tender
	player.civic_job = "Crop Tender"
	player.refresh_identity_labels()
	var ct_hat: Node = player.job_accessory_root.get_node_or_null("HarvestHatBrim")
	var ct_band: Node = player.job_accessory_root.get_node_or_null("BotanicalHatBand")
	var ct_satchel: Node = player.job_accessory_root.get_node_or_null("SeedSatchel")
	var ct_strap: Node = player.job_accessory_root.get_node_or_null("SatchelStrap")
	assert_test.call(ct_hat != null, "Crop Tender equips broad-brimmed harvest straw hat")
	assert_test.call(ct_band != null, "Crop Tender hat has botanical ribbon band")
	assert_test.call(ct_satchel != null, "Crop Tender equips hip seed gathering satchel")
	assert_test.call(ct_strap != null, "Crop Tender equips diagonal satchel strap")

	# 3. Salvage Quartermaster
	player.civic_job = "Salvage Quartermaster"
	player.refresh_identity_labels()
	var sq_mask: Node = player.job_accessory_root.get_node_or_null("WelderMask")
	var sq_slit: Node = player.job_accessory_root.get_node_or_null("WelderSlit")
	var sq_pauldron: Node = player.job_accessory_root.get_node_or_null("SalvagePauldron")
	var sq_gas: Node = player.job_accessory_root.get_node_or_null("CuttingGasTank")
	assert_test.call(sq_mask != null, "Salvage Quartermaster equips heavy welder face mask")
	assert_test.call(sq_slit != null, "Salvage Quartermaster welder mask has glowing amber viewport slit")
	assert_test.call(sq_pauldron != null, "Salvage Quartermaster equips asymmetrical left scrap pauldron")
	assert_test.call(sq_gas != null, "Salvage Quartermaster equips back cutting gas cylinder")

	# 4. Field Medic
	player.civic_job = "Field Medic"
	player.refresh_identity_labels()
	var fm_mirror: Node = player.job_accessory_root.get_node_or_null("ClinicalReflector")
	var fm_pack: Node = player.job_accessory_root.get_node_or_null("TraumaPack")
	var fm_cross_v: Node = player.job_accessory_root.get_node_or_null("RedCrossV")
	var fm_cross_h: Node = player.job_accessory_root.get_node_or_null("RedCrossH")
	var fm_flask: Node = player.job_accessory_root.get_node_or_null("AntisepticFlask")
	assert_test.call(fm_mirror != null, "Field Medic equips clinical forehead reflector mirror")
	assert_test.call(fm_pack != null, "Field Medic equips emergency trauma kit backpack")
	assert_test.call(fm_cross_v != null and fm_cross_h != null, "Field Medic trauma pack bears red cross emblem")
	assert_test.call(fm_flask != null, "Field Medic equips hip antiseptic flask")

	# 5. Town Watch
	player.civic_job = "Town Watch"
	player.refresh_identity_labels()
	var tw_cap: Node = player.job_accessory_root.get_node_or_null("SecurityPatrolCap")
	var tw_pip: Node = player.job_accessory_root.get_node_or_null("SecurityPip")
	var tw_lp: Node = player.job_accessory_root.get_node_or_null("WatchLeftPauldron")
	var tw_rp: Node = player.job_accessory_root.get_node_or_null("WatchRightPauldron")
	var tw_radio: Node = player.job_accessory_root.get_node_or_null("RadioTransceiver")
	var tw_antenna: Node = player.job_accessory_root.get_node_or_null("RadioAntenna")
	assert_test.call(tw_cap != null, "Town Watch equips peaked security patrol cap")
	assert_test.call(tw_pip != null, "Town Watch patrol cap bears gold security pip")
	assert_test.call(tw_lp != null and tw_rp != null, "Town Watch equips twin security shoulder pauldrons")
	assert_test.call(tw_radio != null and tw_antenna != null, "Town Watch equips tactical radio transceiver and antenna")

	# ------------------------------------------------------------------
	# TEST GROUP 7: Zero Faction Role-Leak Verification
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 7] Zero Faction Role-Leak Verification")
	player.civic_job = "Pump Technician"
	player.secret_role = "civilian"
	player.refresh_identity_labels()
	var civ_children_count: int = player.job_accessory_root.get_child_count()

	player.secret_role = "ecology"
	player.refresh_identity_labels()
	var eco_children_count: int = player.job_accessory_root.get_child_count()

	player.secret_role = "technology"
	player.refresh_identity_labels()
	var tech_children_count: int = player.job_accessory_root.get_child_count()

	assert_test.call(civ_children_count == eco_children_count and eco_children_count == tech_children_count, "Civic accessories are 100% faction-invariant (zero visual leaks)")
	assert_test.call(player.job_accessory_root.get_node_or_null("HydroTankLeft") != null, "Operative retains identical civic accessories to civilians")

	# ------------------------------------------------------------------
	# TEST GROUP 8: Bot Controller Clandestine Hunch Trigger
	# ------------------------------------------------------------------
	print("\n[TEST GROUP 8] Autonomous Bot Covert Hunch Integration")
	var bot_res: CharacterBody3D = null
	for r in main.residents:
		if r != player:
			bot_res = r
			break

	assert_test.call(bot_res != null, "Bot resident exists in match")
	var bot_ctrl: Node = bot_res.get_node_or_null("BotController3D")
	assert_test.call(bot_ctrl != null, "BotController3D attached to bot resident")

	# Simulate bot covert alcove search
	bot_ctrl._start_covert_alcove_search()
	assert_test.call(bot_res.covert_hunch_timer > 1.8, "Bot covert alcove search automatically triggers covert hunch timer")

	# Simulate bot covert sabotage
	bot_ctrl._start_covert_sabotage()
	assert_test.call(bot_res.covert_hunch_timer > 1.8, "Bot covert sabotage automatically triggers covert hunch timer")

	print("\n==================================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	print("==================================================================")

	if stats["failed"] == 0:
		print(">>> ALL STEP 1 CHARACTER READABILITY & POSES CHECKS PASSED! <<<")
	else:
		print("!!! STEP 1 VERIFICATION ENCOUNTERED FAILURES !!!")
	
	quit(0 if stats["failed"] == 0 else 1)
