extends SceneTree

const GuideClass = preload("res://scripts/FirstMatchGuide3D.gd")
const TEST_PROGRESS_PATH := "user://first_match_guide_test.cfg"
const SKIP_PROGRESS_PATH := "user://first_match_guide_skip_test.cfg"

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	await process_frame
	var stats := {"passed": 0, "failed": 0}
	_remove_test_file(TEST_PROGRESS_PATH)
	_remove_test_file(SKIP_PROGRESS_PATH)

	var guide = GuideClass.new()
	guide.progress_file_path = TEST_PROGRESS_PATH
	root.add_child(guide)
	_assert(not guide.guide_completed, "First-run guide starts incomplete", stats)

	guide.begin_first_match(Vector3.ZERO)
	_assert(guide.visible and guide.current_step == 0, "Guide starts at Open Town with movement tip", stats)
	guide.notify_player_position(Vector3(1.9, 0.0, 0.0))
	_assert(guide.current_step == 0, "Small movement does not skip the first instruction", stats)
	guide.notify_player_position(Vector3(2.0, 0.0, 0.0))
	_assert(guide.current_step == 1, "Moving two world units advances to station channeling tip", stats)

	guide.notify_task_completed()
	_assert(guide.current_step == 2, "Completing a task advances to the journal tip", stats)
	guide.notify_journal_opened()
	_assert(guide.current_step == 3, "Opening the journal advances to the First Council tip", stats)
	guide.reach_first_council()
	_assert(guide.guide_completed and not guide.first_run_active, "First Council completes the first-run guide", stats)
	_assert(FileAccess.file_exists(ProjectSettings.globalize_path(TEST_PROGRESS_PATH)), "Guide completion is persisted", stats)

	var restored_guide = GuideClass.new()
	restored_guide.progress_file_path = TEST_PROGRESS_PATH
	root.add_child(restored_guide)
	_assert(restored_guide.guide_completed, "Saved completion is restored on the next launch", stats)
	restored_guide.begin_first_match(Vector3.ZERO)
	_assert(not restored_guide.visible, "Completed guide does not auto-play again", stats)

	restored_guide.replay_guide()
	_assert(restored_guide.visible and restored_guide.replay_active and restored_guide.current_step == 0, "Replay starts the optional guide without clearing progress", stats)
	for expected_step in range(1, 4):
		restored_guide._on_primary_pressed()
		_assert(restored_guide.current_step == expected_step, "Replay advances to guide step %d" % (expected_step + 1), stats)
	restored_guide._on_primary_pressed()
	_assert(not restored_guide.visible and restored_guide.guide_completed, "Replay closes without changing completion", stats)

	var skipped_guide = GuideClass.new()
	skipped_guide.progress_file_path = SKIP_PROGRESS_PATH
	root.add_child(skipped_guide)
	skipped_guide.begin_first_match(Vector3.ZERO)
	skipped_guide.skip_guide()
	var restored_skip = GuideClass.new()
	restored_skip.progress_file_path = SKIP_PROGRESS_PATH
	root.add_child(restored_skip)
	_assert(restored_skip.guide_completed, "Skipping is remembered across launches", stats)

	_remove_test_file(TEST_PROGRESS_PATH)
	_remove_test_file(SKIP_PROGRESS_PATH)
	print("RESULTS: %d PASSED, %d FAILED" % [stats["passed"], stats["failed"]])
	quit(0 if stats["failed"] == 0 else 1)

func _assert(condition: bool, description: String, stats: Dictionary) -> void:
	if condition:
		stats["passed"] += 1
		print("[PASS] ", description)
	else:
		stats["failed"] += 1
		print("[FAIL] ", description)

func _remove_test_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		var error := DirAccess.remove_absolute(absolute_path)
		if error != OK:
			push_error("Could not remove onboarding test progress '%s': %s" % [absolute_path, error_string(error)])
