$tests = @(
    "test_hero_draft_lobby_matchmaking.gd",
    "test_mode_selection_and_brawl_stage1.gd",
    "test_hero_roster_and_abilities.gd",
    "test_audio_mixer_and_settings.gd",
    "test_restrained_effects.gd",
    "test_lighting_and_sector_identity.gd",
    "test_character_readability_and_poses.gd",
    "test_first_council_motion_ballot.gd",
    "test_archive_dilemma_modal.gd",
    "test_playtest_tuning_panel.gd",
    "test_option3_journal_and_minimap.gd",
    "test_option4_bot_deception.gd",
    "test_bot_personalities_and_memory.gd",
    "test_end_to_end_match_polish.gd",
    "test_full_3d_phase3.gd",
    "test_camera_dynamics_and_zoom.gd",
    "test_sound_and_audio_atmosphere.gd",
    "test_visual_and_atmospheric_polish.gd",
    "test_player_indicators_and_controls.gd",
    "test_player_cosmetics.gd",
    "test_first_match_guide.gd",
    "test_full_3d_phase2.gd",
    "test_full_3d_phase1.gd",
    "test_slice_3d_integration.gd",
    "test_milestone_7_verification.gd",
    "test_milestone_6_verification.gd",
    "test_court_3d_prototype.gd",
    "test_smoke_main3d_run.gd"
)

$passedSuites = 0
$failedSuites = 0
$totalPassedChecks = 0

foreach ($t in $tests) {
    Write-Host "--------------------------------------------------"
    Write-Host ("Running: " + $t)
    $output = & ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s $t 2>&1
    $exitCode = $LASTEXITCODE
    $match = [regex]::Match($output, 'RESULTS:\s*(\d+)\s*PASSED,\s*(\d+)\s*FAILED')
    if ($exitCode -eq 0) {
        $passedSuites++
        if ($match.Success) {
            $p = [int]$match.Groups[1].Value
            $f = [int]$match.Groups[2].Value
            $totalPassedChecks += $p
            Write-Host ("[PASS] $t -> $p passed, $f failed")
        } else {
            Write-Host ("[PASS] $t -> completed cleanly (exit 0)")
        }
    } else {
        $failedSuites++
        Write-Host ("[FAIL] $t -> FAILED with exit code $exitCode")
        Write-Host $output
    }
}

Write-Host "=================================================="
Write-Host "REGRESSION RUN SUMMARY:"
Write-Host "Total Suites Passed: $passedSuites / $($tests.Count)"
Write-Host "Total Numbered Checks Passed: $totalPassedChecks"
Write-Host "=================================================="
