extends SceneTree

const Main3DScene = preload("res://scenes/Main3D.tscn")
const BotControllerClass = preload("res://scripts/ResidentBotController3D.gd")
const TEMPERAMENTS: Array[String] = ["DUTIFUL", "INVESTIGATOR", "OPPORTUNIST", "BOLD"]

func _init() -> void:
	var stats: Dictionary = {"passed": 0, "failed": 0}
	var main: Node3D = Main3DScene.instantiate()
	main.bot_seed = 90421
	root.add_child(main)
	main._ready()

	var gm: Node = main.game_manager
	var bot_controllers: Array = main.bot_controllers
	var profiles: Array[String] = []
	for bot in bot_controllers:
		profiles.append(String(bot.temperament))
		_assert_test(TEMPERAMENTS.has(bot.temperament), "Bot receives a valid role-neutral temperament", stats)

	var distinct_profiles: Dictionary = {}
	for profile in profiles:
		distinct_profiles[profile] = true
	_assert_test(distinct_profiles.size() > 1, "Roster includes varied temperaments", stats)

	for index in range(bot_controllers.size()):
		bot_controllers[index].set_bot_seed(90421 + int(bot_controllers[index].resident.resident_id))
		_assert_test(bot_controllers[index].temperament == profiles[index], "Profile assignment reproduces from a fixed seed", stats)

	var civilian_bot: Node = null
	var operative_bot: Node = null
	var operative_partner: Node = null
	for resident in main.residents:
		if resident.is_player:
			continue
		if resident.secret_role == "civilian" and civilian_bot == null:
			civilian_bot = resident
		elif resident.secret_role == "ecology" or resident.secret_role == "technology":
			if operative_bot == null:
				operative_bot = resident
			elif resident.secret_role == operative_bot.secret_role:
				operative_partner = resident

	var civilian_controller: Node = civilian_bot.bot_controller
	var operative_controller: Node = operative_bot.bot_controller
	operative_controller.refresh_personal_memory()
	var known_partner_names: Array = operative_controller.personal_memory.get("known_partners", [])
	_assert_test(known_partner_names.has(operative_partner.resident_name), "Operative memory includes its known faction partners", stats)
	civilian_bot.bot_controller.set_bot_seed(777)
	operative_controller.set_bot_seed(777)
	_assert_test(civilian_bot.bot_controller.temperament == operative_controller.temperament, "Same seed assigns the same temperament regardless of secret role", stats)
	var own_id: int = int(civilian_bot.resident_id)
	var other_id: int = int(main.residents[0].resident_id)
	gm._add_private_evidence(own_id, "observed_fact", "MEMORY_OWN_PRIVATE", "Town Square", "04:10", "Observed Resident 1")
	gm._add_private_evidence(other_id, "observed_fact", "MEMORY_OTHER_PRIVATE", "Pump", "04:12", "Observed Resident 2")
	gm.tabled_evidence.append({
		"id": "public-memory-test",
		"tier": "observed_fact",
		"text": "MEMORY_PUBLIC_RECORD",
		"subject": "Resident 3",
		"region": "Pump & Generator Station",
		"owner_id": other_id,
		"tabled": true
	})
	var memory: Dictionary = civilian_controller.refresh_personal_memory()
	_assert_test(_memory_has_text(memory.get("private_evidence", []), "MEMORY_OWN_PRIVATE"), "Bot memory includes its own private evidence", stats)
	_assert_test(not _memory_has_text(memory.get("private_evidence", []), "MEMORY_OTHER_PRIVATE"), "Bot memory excludes another resident's private evidence", stats)
	_assert_test(_memory_has_text(memory.get("public_evidence", []), "MEMORY_PUBLIC_RECORD"), "Bot memory includes explicitly tabled public evidence", stats)

	gm.water = 30.0
	gm.stability = 80.0
	gm.scrap = 6
	var inspection_routine: Array = [{"type": "inspect", "pos": Vector3.ZERO, "label": "Routine inspection"}]
	var selected_by_profile: Dictionary = {}
	for profile in TEMPERAMENTS:
		civilian_controller.set_bot_seed(2525)
		civilian_controller.temperament = profile
		civilian_controller.routine_step = 1
		selected_by_profile[profile] = civilian_controller._choose_profile_chore(inspection_routine, civilian_bot.position)
	_assert_test(selected_by_profile["DUTIFUL"].get("id", "") == "pump", "Dutiful profile redirects to urgent water crisis task", stats)
	_assert_test(selected_by_profile["INVESTIGATOR"].get("type", "") == "inspect", "Investigator profile chooses an inspection route", stats)
	var investigator_region: String = main.town_map.get_region_name_at_3d(selected_by_profile["INVESTIGATOR"].get("pos", Vector3.ZERO))
	_assert_test(civilian_controller._memory_region_affinity(investigator_region) > 0.0, "Investigator favors a region linked to its own evidence", stats)
	_assert_test(selected_by_profile["OPPORTUNIST"].get("type", "") == "pad", "Opportunist profile pivots to a scored task pad", stats)
	_assert_test(selected_by_profile["BOLD"].get("type", "") == "pad", "Bold profile selects a less predictable task pad", stats)
	civilian_controller.temperament = "INVESTIGATOR"
	civilian_controller.routine_step = 0
	var routine_pad: Dictionary = {"type": "pad", "id": "greenhouse", "action": "Tending crops"}
	_assert_test(civilian_controller._choose_profile_chore([routine_pad], civilian_bot.position) == routine_pad, "Investigator alternates profile detours with civic routine tasks", stats)
	var all_task_pads: Array[Dictionary] = civilian_controller._get_available_task_pads()
	var jam_test_pad: Dictionary = main.town_map.get_pad_by_id("pump")
	var saved_jam: float = float(jam_test_pad.get("jammed_timer", 0.0))
	jam_test_pad["jammed_timer"] = 5.0
	var pads_while_jammed: Array[Dictionary] = civilian_controller._get_available_task_pads()
	_assert_test(not _pads_include(pads_while_jammed, "pump"), "Bot excludes signal-jammed pads from available chores", stats)
	jam_test_pad["jammed_timer"] = saved_jam
	_assert_test(_pads_include(all_task_pads, "pump"), "Unjammed pump remains eligible for bot chores", stats)
	var pad_chore: Dictionary = civilian_controller._make_pad_chore({"id": "pump", "name": "Pump\n[JAMMED]", "base_title": "Pump"})
	_assert_test(not String(pad_chore.get("action", "")).contains("\n"), "Bot action label uses a single-line task title", stats)
	civilian_controller.set_bot_seed(1024)
	civilian_controller.temperament = "BOLD"
	var bold_pause: float = civilian_controller._next_pause_duration()
	var bold_covert_delay: float = civilian_controller._covert_cooldown_range("initial")
	civilian_controller.set_bot_seed(1024)
	civilian_controller.temperament = "DUTIFUL"
	var dutiful_pause: float = civilian_controller._next_pause_duration()
	var dutiful_covert_delay: float = civilian_controller._covert_cooldown_range("initial")
	_assert_test(bold_pause < dutiful_pause, "Bold profile has a measurably faster pause cadence than Dutiful", stats)
	_assert_test(bold_covert_delay < dutiful_covert_delay, "Bold profile takes covert opportunities sooner than Dutiful", stats)

	var vote_one: Dictionary = gm.evaluate_civilian_bot_vote(civilian_bot, civilian_controller.bot_rng)
	civilian_controller.set_bot_seed(54321)
	var seeded_vote_one: Dictionary = gm.evaluate_civilian_bot_vote(civilian_bot, civilian_controller.bot_rng)
	civilian_controller.set_bot_seed(54321)
	var seeded_vote_two: Dictionary = gm.evaluate_civilian_bot_vote(civilian_bot, civilian_controller.bot_rng)
	_assert_test(seeded_vote_one.get("vote") == seeded_vote_two.get("vote"), "Court vote repeats with the same bot seed", stats)
	_assert_test(vote_one.has("vote"), "Court vote remains available with a bot-specific random source", stats)
	var reason_source: String = gm._get_vote_reason_source(vote_one.get("reason", ""))
	_assert_test(reason_source != "", "Court reasoning assigns a readable source label", stats)
	var pod_reason: String = gm._summarize_podium_reason(vote_one.get("reason", ""))
	_assert_test(String(pod_reason).contains("—") or String(pod_reason).contains("RESOURCE") or String(pod_reason).contains("PRIVATE"), "Court podium summary preserves a readable source label and trimmed rationale", stats)
	var suspicion_snapshot: Dictionary = civilian_controller.refresh_personal_memory()
	_assert_test(String(suspicion_snapshot.get("suspicion_summary", "")).length() > 0, "Bot suspicion summary remains present after memory refresh", stats)
	_assert_test(suspicion_snapshot.has("rumor_network"), "Bot memory tracks a rumor network separate from private evidence", stats)
	_assert_test(suspicion_snapshot.has("trust_scores"), "Bot memory tracks a trust score map separate from raw suspicion", stats)
	_assert_test(String(suspicion_snapshot.get("social_summary", "")).length() > 0, "Bot social summary remains readable without revealing hidden roles", stats)
	_assert_test(suspicion_snapshot.has("suspicion_drift"), "Bot social memory tracks suspicion drift over time to support readable trust flow", stats)
	civilian_controller.personal_memory["trust_scores"] = {"Resident X": -0.9, "Resident Y": 0.85}
	civilian_controller.personal_memory["rumor_network"] = {"Resident X": 1.5, "Resident Y": 0.1}
	var social_pads: Array[Dictionary] = [
		{"id": "greenhouse", "position": Vector3.ZERO, "active_user": {"resident_name": "Resident X"}},
		{"id": "clinic", "position": Vector3(12.0, 0.0, 0.0), "active_user": {"resident_name": "Resident Y"}}
	]
	var trust_choice: Dictionary = civilian_controller._choose_best_pad(social_pads, Vector3.ZERO, false)
	_assert_test(String(trust_choice.get("id", "")) == "clinic", "Low social trust and rumor churn discourage a bot from selecting a distrusted resident's pad", stats)

	gm.water = 50.0
	gm.stability = 50.0
	gm.scrap = 6
	gm.tabled_evidence.clear()
	gm.alibi_conflicts.clear()
	gm.court_ballot_records.clear()
	civilian_bot.civic_job = "Field Medic"
	gm.evidence_journals[own_id] = {"observed": [], "traces": []}
	var baseline_rng := RandomNumberGenerator.new()
	baseline_rng.seed = 111
	var no_clue_vote: Dictionary = gm.evaluate_civilian_bot_vote(civilian_bot, baseline_rng)
	civilian_controller.personal_memory["trust_scores"] = {
		"Townmate One": 1.0,
		"Townmate Two": 1.0,
		"Townmate Three": 1.0
	}
	gm.court_ballot_records.append({"name": "Townmate One", "resident_id": 901, "vote": "Ecology"})
	gm.court_ballot_records.append({"name": "Townmate Two", "resident_id": 902, "vote": "Ecology"})
	gm.court_ballot_records.append({"name": "Townmate Three", "resident_id": 903, "vote": "Ecology"})
	civilian_controller.temperament = "DUTIFUL"
	var dutiful_court_influence: Dictionary = gm._get_public_court_influence(civilian_bot)
	civilian_controller.temperament = "OPPORTUNIST"
	var opportunist_court_influence: Dictionary = gm._get_public_court_influence(civilian_bot)
	civilian_controller.temperament = "INVESTIGATOR"
	var investigator_court_influence: Dictionary = gm._get_public_court_influence(civilian_bot)
	civilian_controller.temperament = "BOLD"
	var bold_court_influence: Dictionary = gm._get_public_court_influence(civilian_bot)
	_assert_test(float(dutiful_court_influence.get("ecology", 0.0)) > float(opportunist_court_influence.get("ecology", 0.0)) and float(opportunist_court_influence.get("ecology", 0.0)) > float(investigator_court_influence.get("ecology", 0.0)) and float(investigator_court_influence.get("ecology", 0.0)) > float(bold_court_influence.get("ecology", 0.0)), "Public Court consensus influences each temperament at a bounded, distinct strength", stats)
	civilian_controller.personal_memory["trust_scores"] = {"Townmate One": -1.0, "Townmate Two": -1.0, "Townmate Three": -1.0}
	var distrusted_court_influence: Dictionary = gm._get_public_court_influence(civilian_bot)
	_assert_test(float(distrusted_court_influence.get("ecology", 0.0)) < float(dutiful_court_influence.get("ecology", 0.0)), "Bots give less weight to earlier ballots from residents they distrust", stats)
	gm.court_ballot_records.append({"name": civilian_bot.resident_name, "resident_id": int(civilian_bot.resident_id), "vote": "Technology"})
	var influence_with_own_ballot: Dictionary = gm._get_public_court_influence(civilian_bot)
	_assert_test(is_equal_approx(float(influence_with_own_ballot.get("ecology", 0.0)), float(distrusted_court_influence.get("ecology", 0.0))) and is_equal_approx(float(influence_with_own_ballot.get("technology", 0.0)), float(distrusted_court_influence.get("technology", 0.0))), "A bot's own ballot is excluded from Court social influence", stats)
	gm.court_ballot_records.pop_back()
	civilian_controller.personal_memory["trust_scores"] = {
		"Townmate One": 1.0,
		"Townmate Two": 1.0,
		"Townmate Three": 1.0
	}
	civilian_controller.temperament = "DUTIFUL"
	var consensus_rng := RandomNumberGenerator.new()
	consensus_rng.seed = 111
	var consensus_vote: Dictionary = gm.evaluate_civilian_bot_vote(civilian_bot, consensus_rng)
	_assert_test(consensus_vote.get("vote") == "Ecology" and String(consensus_vote.get("reason", "")).contains("Earlier public Court votes"), "Later voters can be swayed by earlier public ballots and explain that influence", stats)
	_assert_test(gm._get_vote_reason_source(consensus_vote.get("reason", "")) == "COURT CONSENSUS", "Court consensus testimony receives a distinct podium source label", stats)
	gm.court_ballot_records.clear()
	gm.evidence_journals[other_id] = {
		"observed": [{"id": "foreign-ideology", "tier": "observed_fact", "text": "Resident witnessed an Old-World frequency action.", "subject": "Resident X"}],
		"traces": []
	}
	var foreign_rng := RandomNumberGenerator.new()
	foreign_rng.seed = 111
	var foreign_clue_vote: Dictionary = gm.evaluate_civilian_bot_vote(civilian_bot, foreign_rng)
	_assert_test(foreign_clue_vote == no_clue_vote, "A foreign private ideological clue does not alter this bot's vote or testimony", stats)

	gm.evidence_journals[own_id] = {
		"observed": [{"id": "unverified-claim", "tier": "unverified_claim", "text": "Resident X tuned the Old-World frequency.", "subject": "Resident X"}],
		"traces": []
	}
	var claim_rng := RandomNumberGenerator.new()
	claim_rng.seed = 111
	var claim_only_vote: Dictionary = gm.evaluate_civilian_bot_vote(civilian_bot, claim_rng)
	_assert_test(claim_only_vote == no_clue_vote, "Unverified claims contribute neither faction score nor testimony", stats)

	gm.evidence_journals[own_id] = {
		"observed": [{"id": "private-ideology", "tier": "observed_fact", "text": "Resident X tuned the Old-World frequency.", "subject": "Resident X"}],
		"traces": []
	}
	var ideology_rng := RandomNumberGenerator.new()
	ideology_rng.seed = 111
	var private_ideology_vote: Dictionary = gm.evaluate_civilian_bot_vote(civilian_bot, ideology_rng)
	_assert_test(private_ideology_vote.get("vote") == "Technology" and String(private_ideology_vote.get("reason", "")).contains("Old-World"), "A bot's own ideological observation supports a matching Technology vote and reason", stats)
	gm.water = 49.0
	gm.evidence_journals[own_id] = {
		"observed": [
			{"id": "private-ideology-one", "tier": "observed_fact", "text": "Resident X tuned the Old-World frequency.", "subject": "Resident X"},
			{"id": "private-ideology-two", "tier": "observed_fact", "text": "Resident Y tuned the Old-World frequency.", "subject": "Resident Y"}
		],
		"traces": []
	}
	var flipped_vote_rng := RandomNumberGenerator.new()
	flipped_vote_rng.seed = 111
	var flipped_vote: Dictionary = gm.evaluate_civilian_bot_vote(civilian_bot, flipped_vote_rng)
	_assert_test(flipped_vote.get("vote") == "Technology" and String(flipped_vote.get("reason", "")).contains("Old-World") and not String(flipped_vote.get("reason", "")).contains("Water reserves"), "When evidence overturns the resource lean, testimony supports the actual winning vote", stats)
	gm.water = 50.0
	gm.alibi_conflicts.append({"resident": "Resident X", "claim": "Greenhouse", "seen": "Town Square"})
	var corroborated_rng := RandomNumberGenerator.new()
	corroborated_rng.seed = 111
	var corroborated_vote: Dictionary = gm.evaluate_civilian_bot_vote(civilian_bot, corroborated_rng)
	_assert_test(corroborated_vote.get("vote") == "Technology" and String(corroborated_vote.get("reason", "")).contains("alibi"), "A public alibi conflict corroborates only an ideological clue naming that resident", stats)
	gm.evidence_journals[own_id] = {"observed": [], "traces": []}
	var conflict_only_rng := RandomNumberGenerator.new()
	conflict_only_rng.seed = 111
	var conflict_only_vote: Dictionary = gm.evaluate_civilian_bot_vote(civilian_bot, conflict_only_rng)
	_assert_test(conflict_only_vote == no_clue_vote, "An alibi conflict alone does not create faction bias", stats)
	gm.alibi_conflicts.clear()

	gm.evidence_journals[own_id] = {
		"observed": [{"id": "pump-tampering", "tier": "observed_fact", "text": "Resident X was caught tampering at the pump.", "subject": "Resident X", "region": "Pump & Generator Station"}],
		"traces": []
	}
	var pump_rng := RandomNumberGenerator.new()
	pump_rng.seed = 111
	var pump_vote: Dictionary = gm.evaluate_civilian_bot_vote(civilian_bot, pump_rng)
	_assert_test(pump_vote.get("vote") == "Ecology" and String(pump_vote.get("reason", "")).contains("Pump"), "Personally witnessed infrastructure tampering informs the matching sector-protective vote", stats)
	var fact_score: float = gm._get_sector_disruption_score({"tier": "observed_fact", "text": "caught tampering"})
	var trace_score: float = gm._get_sector_disruption_score({"tier": "verified_trace", "text": "caught tampering"})
	_assert_test(fact_score > trace_score and trace_score > 0.0, "A witnessed fact carries more disruption weight than a trace", stats)
	gm.evidence_journals[own_id] = {
		"observed": [],
		"traces": [{"id": "pump-trace", "tier": "verified_trace", "text": "A trace of tampering at the pump.", "subject": "Resident X", "region": "Pump & Generator Station"}]
	}
	var trace_rng := RandomNumberGenerator.new()
	trace_rng.seed = 111
	var trace_vote: Dictionary = gm.evaluate_civilian_bot_vote(civilian_bot, trace_rng)
	_assert_test(trace_vote.get("vote") == "Ecology" and String(trace_vote.get("reason", "")).contains("verified trace"), "Bot testimony distinguishes a verified trace from direct witnessing", stats)
	gm.evidence_journals[own_id] = {"observed": [], "traces": []}
	gm.tabled_evidence.append({
		"id": "rumor-net",
		"tier": "observed_fact",
		"text": "Resident X was caught tampering at the pump.",
		"subject": "Resident X",
		"region": "Pump & Generator Station"
	})
	gm.alibi_conflicts.clear()
	gm.alibi_conflicts.append({"resident": "Resident X", "claim": "Greenhouse", "seen": "Town Square"})
	var rumor_memory: Dictionary = civilian_controller.refresh_personal_memory()
	_assert_test(float(rumor_memory.get("trust_scores", {}).get("Resident X", 0.0)) < 0.0, "Public contradictions and tampering reduce the bot's trust in a resident in its rumor network", stats)
	_assert_test(rumor_memory.get("rumor_network", {}).has("Resident X"), "Rumor graph records public social friction for named residents without exposing hidden roles", stats)
	gm.tabled_evidence.clear()
	gm.alibi_conflicts.clear()
	gm.evidence_journals[own_id] = {"observed": [], "traces": []}
	gm.tabled_evidence.append({		"id": "public-ideology",
		"tier": "observed_fact",
		"text": "Resident Y tuned the Old-World frequency.",
		"subject": "Resident Y",
		"region": "Town Square"
	})
	var public_rng := RandomNumberGenerator.new()
	public_rng.seed = 111
	var public_vote: Dictionary = gm.evaluate_civilian_bot_vote(civilian_bot, public_rng)
	_assert_test(public_vote.get("vote") == "Technology" and String(public_vote.get("reason", "")).contains("Council-tabled"), "Explicitly public ideological evidence informs every voter's Technology reasoning", stats)
	gm.tabled_evidence.clear()

	civilian_controller.temperament = "BOLD"
	var bold_court_delay: float = gm.get_civilian_bot_deliberation_delay(civilian_bot)
	civilian_controller.temperament = "OPPORTUNIST"
	var opportunist_court_delay: float = gm.get_civilian_bot_deliberation_delay(civilian_bot)
	civilian_controller.temperament = "DUTIFUL"
	var dutiful_court_delay: float = gm.get_civilian_bot_deliberation_delay(civilian_bot)
	civilian_controller.temperament = "INVESTIGATOR"
	var investigator_court_delay: float = gm.get_civilian_bot_deliberation_delay(civilian_bot)
	_assert_test(bold_court_delay < opportunist_court_delay and opportunist_court_delay < dutiful_court_delay and dutiful_court_delay < investigator_court_delay, "Court deliberation time varies by temperament in the intended order", stats)
	_assert_test(investigator_court_delay <= gm.court_turn_duration - 0.5, "Slowest temperament deliberates before the Court timeout", stats)

	var operative_id: int = int(operative_bot.resident_id)
	gm.evidence_journals[operative_id] = {"observed": [], "traces": []}
	var protected_text: String = "Observed %s tampering at the pump." % operative_partner.resident_name
	var safe_text: String = "Observed %s at the greenhouse." % civilian_bot.resident_name
	gm._add_private_evidence(operative_id, "observed_fact", protected_text, "Pump", "04:20", operative_partner.resident_name)
	gm._add_private_evidence(operative_id, "observed_fact", safe_text, "Greenhouse", "04:21", civilian_bot.resident_name)
	gm.prepare_first_council(main.residents, main.town_map)
	_assert_test(not _table_has_text(gm.tabled_evidence, protected_text), "Operative withholds a clue identifying a known faction partner", stats)
	_assert_test(_table_has_text(gm.tabled_evidence, safe_text), "Operative still tables unrelated useful evidence", stats)
	_assert_test(_event_has_text(gm.recent_events, "AI residents shared evidence"), "Council log uses a concise AI evidence summary", stats)
	_assert_test(not _event_has_text(gm.recent_events, "You tabled"), "Automated bot tabling is not logged as the player's action", stats)

	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	root.remove_child(main)
	main.free()
	quit(0 if stats["failed"] == 0 else 1)

func _assert_test(condition: bool, description: String, stats: Dictionary) -> void:
	if condition:
		stats["passed"] += 1
		print("[PASS] ", description)
	else:
		stats["failed"] += 1
		printerr("[FAIL] ", description)

func _memory_has_text(entries: Array, target: String) -> bool:
	for entry in entries:
		if String(entry.get("text", "")) == target:
			return true
	return false

func _table_has_text(entries: Array, target: String) -> bool:
	for entry in entries:
		if String(entry.get("text", "")) == target:
			return true
	return false

func _event_has_text(entries: Array, target: String) -> bool:
	for entry in entries:
		if String(entry.get("text", "")).contains(target):
			return true
	return false

func _pads_include(pads: Array[Dictionary], target_id: String) -> bool:
	for pad in pads:
		if String(pad.get("id", "")) == target_id:
			return true
	return false
