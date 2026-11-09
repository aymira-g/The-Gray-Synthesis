extends RefCounted

const MOVE_SPEED: float = 235.0
const CHANNEL_DURATION: float = 2.5
const PAD_COOLDOWN: float = 14.0
const PAD_INTERACT_RADIUS: float = 68.0
const SHOVE_COOLDOWN: float = 5.0
const SHOVE_RADIUS: float = 85.0
const SHOVE_STAMINA_DAMAGE: float = 35.0
const MAX_STAMINA: float = 100.0
const STAMINA_REGEN_RATE: float = 4.0
const RESPAWN_DURATION: float = 8.0
const SEPARATION_RADIUS: float = 42.0
const WITNESS_RADIUS: float = 260.0

const EVIDENCE_FACT: String = "observed_fact"
const EVIDENCE_TRACE: String = "verified_trace"
const EVIDENCE_CLAIM: String = "unverified_claim"
const EVIDENCE_TIER_LABELS: Dictionary = {
	EVIDENCE_FACT: "[OBSERVED FACT]",
	EVIDENCE_TRACE: "[VERIFIED TRACE]",
	EVIDENCE_CLAIM: "[UNVERIFIED CLAIM]"
}

const OBJECTIVE_CHANNEL_DURATION: float = 4.0
const ARCHIVE_CHANNEL_DURATION: float = 2.5

const FINALE_ROUTE_NONE: String = "none"
const FINALE_ROUTE_CONFRONTATION: String = "confrontation"
const FINALE_ROUTE_PEACE: String = "peace"

const STRATEGIC_CHOICE_NONE: String = "none"
const STRATEGIC_CHOICE_CONFRONTATION: String = "confrontation"
const STRATEGIC_CHOICE_PEACE: String = "peace"

const CHARTER_POWER_LOW: String = "low"
const CHARTER_POWER_HIGH: String = "high"
const CHARTER_LAND_RESTRICTED: String = "restricted"
const CHARTER_LAND_OPEN: String = "open"
const CHARTER_MED_SCHEDULED: String = "scheduled"
const CHARTER_MED_AUTOMATED: String = "automated"

const HOLDOUT_DURATION_LOW_POWER: float = 90.0
const HOLDOUT_DURATION_HIGH_POWER: float = 60.0
const HOLDOUT_HAZARD_CLEAR_DURATION: float = 2.0
const HOLDOUT_HAZARD_CLEAR_RESTRICTED_ECO: float = 1.3
const TUG_OF_WAR_CHANNEL_DELTA: float = 10.0

const HOLDOUT_HAZARD_SPAWNS: Array[Dictionary] = [
	{
		"id": "blight_plot_a",
		"kind": "blight",
		"label": "Blight Flare Bed Alpha",
		"pos": Vector2(-780, -320),
		"region": "Greenhouse & Fields"
	},
	{
		"id": "blight_plot_b",
		"kind": "blight",
		"label": "Blight Flare Bed Beta",
		"pos": Vector2(-620, -320),
		"region": "Greenhouse & Fields"
	},
	{
		"id": "steam_valve_a",
		"kind": "steam",
		"label": "Overpressure Steam Valve A",
		"pos": Vector2(-320, 680),
		"region": "Pump & Generator Station"
	},
	{
		"id": "steam_valve_b",
		"kind": "steam",
		"label": "Overpressure Steam Valve B",
		"pos": Vector2(120, 720),
		"region": "Pump & Generator Station"
	}
]

const ARCHIVE_CHOICE_NONE: String = "none"
const ARCHIVE_CHOICE_LOYAL: String = "loyal"
const ARCHIVE_CHOICE_WHISTLEBLOWER: String = "whistleblower"
const ARCHIVE_CHOICE_ENTRUST_ECO: String = "entrust_eco"
const ARCHIVE_CHOICE_ENTRUST_TECH: String = "entrust_tech"
const ARCHIVE_CHOICE_RESERVE_CW: String = "reserve_cw"

const ARCHIVE_CACHE_SPAWNS: Array[Dictionary] = [
	{
		"id": "north_pass",
		"name": "North Pass Crevice",
		"pos": Vector2(0, -680),
		"region": "Town Corridors",
		"waypoint": "north_pass"
	},
	{
		"id": "salvage_alcove",
		"name": "Salvage Yard Gantry Alcove",
		"pos": Vector2(1050, -380),
		"region": "Salvage Yard",
		"waypoint": "sy_deep"
	},
	{
		"id": "pump_basin",
		"name": "Pump Station Aquifer Basin",
		"pos": Vector2(-500, 740),
		"region": "Pump & Generator Station",
		"waypoint": "pump_west"
	},
	{
		"id": "council_niche",
		"name": "Council Ring Old Archive Niche",
		"pos": Vector2(-340, 40),
		"region": "Town Square / Common Works",
		"waypoint": "hub_nw"
	}
]

const COUNCIL_MOTIONS: Array[Dictionary] = [
	{"id": 1, "name": "Station Watch Beacons", "short": "Beacons observe Pump + Greenhouse during Escalation."},
	{"id": 2, "name": "Emergency Scrap Subsidy", "short": "+3 Town Scrap immediately."},
	{"id": 3, "name": "Crop Blight Remediation", "short": "-25% Stability drain during Escalation."}
]

const CIVIC_JOB_NAMES: Array[String] = [
	"Pump Technician",
	"Crop Tender",
	"Salvage Quartermaster",
	"Field Medic",
	"Town Watch"
]

const CIVIC_KIT_INFO: Dictionary = {
	"Pump Technician": {
		"ability_name": "Field Calibrator",
		"cooldown": 14.0,
		"short_desc": "-6s pad cooldown OR +40% work speed (4s)",
		"full_desc": "Reduces a cooling-down/jammed station pad within 140px by 6.0s (or grants +40% work speed for 4.0s if no pad needs calibration)."
	},
	"Crop Tender": {
		"ability_name": "Mulch Mist",
		"cooldown": 15.0,
		"short_desc": "95px ring (+8 Stamina/s for 5s)",
		"full_desc": "Drops a 95px soothing pollen ring on the floor for 5.0s that restores +8 Stamina/sec to residents inside."
	},
	"Salvage Quartermaster": {
		"ability_name": "Haul Rig Sprint",
		"cooldown": 12.0,
		"short_desc": "+45% Move Speed for 3.5s",
		"full_desc": "Grants +45% movement speed (340 px/s) for 3.5s to rotate across town corridors or escape clashes."
	},
	"Field Medic": {
		"ability_name": "First Aid Patch",
		"cooldown": 14.0,
		"short_desc": "+35 Stamina (Self + Nearest Ally)",
		"full_desc": "Instantly restores +35 Stamina to yourself and the single nearest other resident within 110px."
	},
	"Town Watch": {
		"ability_name": "Brace & Lantern",
		"cooldown": 15.0,
		"short_desc": "4.5s Shove/Shock Shield",
		"full_desc": "Grants a Watch Shield for 4.5s that blocks the next incoming Civic Shove or Shock Tool stamina hit and knockback."
	}
}

const ECOLOGY_KITS: Array[String] = ["tracker", "grower", "warden"]
const TECHNOLOGY_KITS: Array[String] = ["runner", "mechanic", "saboteur"]

const OPERATIVE_KIT_INFO: Dictionary = {
	"tracker": {
		"kit_title": "Tracker",
		"ability_name": "Scent Trail",
		"faction": "ecology",
		"cooldown": 16.0,
		"short_desc": "320px Snapshot Scan (5s private view)",
		"full_desc": "One-shot 320px snapshot scan (visible only to you for 5.0s): reveals the last resident who used each scanned station pad and places a snapshot heading arrow on nearby residents."
	},
	"grower": {
		"kit_title": "Grower",
		"ability_name": "Root Snare",
		"faction": "ecology",
		"cooldown": 18.0,
		"short_desc": "105px Briar Patch (-45% speed, 6s)",
		"full_desc": "Spawns a 105px Briar Patch zone on the floor for 6.0s that slows other residents crossing it by -45% move speed."
	},
	"warden": {
		"kit_title": "Warden",
		"ability_name": "Thorn Guard",
		"faction": "ecology",
		"cooldown": 18.0,
		"short_desc": "90px Pad/Self Canopy (Uninterruptible, 6s)",
		"full_desc": "Places a 90px Thorn Canopy over the nearest station pad (or self) for 6.0s: occupants cannot be interrupted by Civic Shove and reflect 20 Stamina damage to shovers."
	},
	"runner": {
		"kit_title": "Runner",
		"ability_name": "Exosuit Burst",
		"faction": "technology",
		"cooldown": 14.0,
		"short_desc": "160px Dash + 2.5s Speed (Leaves Spark Trail)",
		"full_desc": "Performs an instant 160px directional dash + 35% move speed for 2.5s, leaving a visible electric spark trail on the floor for 4.0s."
	},
	"mechanic": {
		"kit_title": "Mechanic",
		"ability_name": "Overclock Rig",
		"faction": "technology",
		"cooldown": 18.0,
		"short_desc": "Reset Pad Cooldown + 50% Output Boost",
		"full_desc": "Instantly clears a nearby station pad cooldown (0.0s) and supercharges the pad so its next completion yields +50% output."
	},
	"saboteur": {
		"kit_title": "Saboteur",
		"ability_name": "Shock Tool",
		"faction": "technology",
		"cooldown": 18.0,
		"short_desc": "Jam Pad 8s + Interrupt & -25 Stam to Target",
		"full_desc": "Arc-pulses the nearest station pad within 130px (or nearest resident within 100px), interrupting work, locking the pad for 8.0s (JAMMED), and dealing 25 Stamina damage to the target resident."
	},
	"none": {
		"kit_title": "Civilian Voter",
		"ability_name": "No Faction Kit",
		"faction": "civilian",
		"cooldown": 0.0,
		"short_desc": "Rely on Civic Kit [F] & Court Vote",
		"full_desc": "Civilians have no covert faction kit. Use your Public Civic Ability [F], observe disturbances, and cast your decisive vote at Civilian Court."
	}
}

# ==============================================================================
# 10-Hero Roster (1 Unique Active [F] + 1 Unique Passive Trait per Hero)
# ==============================================================================
const HERO_ROSTER: Array[Dictionary] = [
	{
		"hero_id": "kaelen_vance",
		"name": "Kaelen Vance",
		"title": "Chief Hydro-Engineer",
		"civic_job": "Pump Technician",
		"variant": 0,
		"active_id": "field_calibrator",
		"active_name": "Field Calibrator",
		"active_cd": 14.0,
		"active_short": "-6s pad CD OR +40% work speed (4s)",
		"active_desc": "Reduces a nearby cooling-down/jammed pad timer by 6.0s, or grants +40% work speed for 4.0s.",
		"passive_id": "hydro_mastery",
		"passive_name": "Hydro-Mastery",
		"passive_desc": "Channels Pump & Generator stations +20% faster.",
		"torso_color": Color(0.24, 0.45, 0.62),
		"accent_color": Color(0.35, 0.82, 1.0),
		"lore": "Designed the colony's primary aquifer manifolds before the collapse."
	},
	{
		"hero_id": "soren_moss",
		"name": "Soren Moss",
		"title": "Mycology Botanist",
		"civic_job": "Crop Tender",
		"variant": 0,
		"active_id": "mulch_mist",
		"active_name": "Mulch Mist",
		"active_cd": 15.0,
		"active_short": "4m Spore Ring (+8 Stamina/s for 5s)",
		"active_desc": "Drops a 4m soothing spore ring on the floor for 5.0s that restores +8 Stamina/s to anyone inside.",
		"passive_id": "deep_roots",
		"passive_name": "Deep Roots",
		"passive_desc": "Regenerates +2.5 extra Stamina/s while inside the Greenhouse sector.",
		"torso_color": Color(0.30, 0.50, 0.34),
		"accent_color": Color(0.48, 0.90, 0.55),
		"lore": "Cultivates drought-resistant spore strains that keep the greenhouse alive."
	},
	{
		"hero_id": "garrick_cole",
		"name": "Garrick Cole",
		"title": "Heavy Rig Welder",
		"civic_job": "Salvage Quartermaster",
		"variant": 0,
		"active_id": "haul_rig_sprint",
		"active_name": "Haul Rig Sprint",
		"active_cd": 12.0,
		"active_short": "+45% Move Speed for 3.5s",
		"active_desc": "Ignites exorig thrusters for +45% movement speed for 3.5s.",
		"passive_id": "heavy_frame",
		"passive_name": "Heavy Frame",
		"passive_desc": "+25 Max Stamina (125 total) and 20% knockback resistance against Civic Shoves.",
		"torso_color": Color(0.54, 0.40, 0.28),
		"accent_color": Color(0.96, 0.68, 0.30),
		"lore": "Hauls structural girders from the deep slag pits with an old loader frame."
	},
	{
		"hero_id": "aris_thorne",
		"name": "Dr. Aris Thorne",
		"title": "Chief Triage Surgeon",
		"civic_job": "Field Medic",
		"variant": 0,
		"active_id": "first_aid_patch",
		"active_name": "First Aid Patch",
		"active_cd": 14.0,
		"active_short": "+35 Stamina (Self + Nearest Ally)",
		"active_desc": "Instantly restores +35 Stamina to self and the nearest resident within 4m.",
		"passive_id": "triage_veteran",
		"passive_name": "Triage Veteran",
		"passive_desc": "Recovers from Clinic exhaustion 2.5s faster (5.5s) and +30% faster low-stamina regen.",
		"torso_color": Color(0.64, 0.72, 0.78),
		"accent_color": Color(0.38, 0.92, 0.85),
		"lore": "Runs the Town Square trauma tent with rationed pre-collapse supplies."
	},
	{
		"hero_id": "bram_sterling",
		"name": "Bram Sterling",
		"title": "Perimeter Warden",
		"civic_job": "Town Watch",
		"variant": 0,
		"active_id": "brace_and_lantern",
		"active_name": "Brace & Lantern",
		"active_cd": 15.0,
		"active_short": "4.5s Shove/Shock Shield",
		"active_desc": "Grants a Watch Shield for 4.5s that blocks the next incoming Civic Shove or Shock Tool hit.",
		"passive_id": "sentinels_reach",
		"passive_name": "Sentinel's Reach",
		"passive_desc": "Civic Shove cooldown reduced by 1.5s and deals +10 bonus Stamina damage.",
		"torso_color": Color(0.34, 0.38, 0.48),
		"accent_color": Color(0.92, 0.80, 0.40),
		"lore": "Keeps order on the town walkways when resource shortages fray tempers."
	},
	{
		"hero_id": "mira_solis",
		"name": "Mira Solis",
		"title": "Aquifer Diver",
		"civic_job": "Pump Technician",
		"variant": 1,
		"active_id": "pressure_surge",
		"active_name": "Pressure Surge",
		"active_cd": 15.0,
		"active_short": "+20 Stam, +30% Spd (3.5s) & Hydro Push",
		"active_desc": "Releases a hydro-burst restoring +20 Stamina, granting +30% move speed (3.5s), and pushing back nearby crowd.",
		"passive_id": "crisis_responder",
		"passive_name": "Crisis Responder",
		"passive_desc": "+15% movement speed whenever Town Water reserves drop below 50%.",
		"torso_color": Color(0.20, 0.52, 0.56),
		"accent_color": Color(0.96, 0.88, 0.32),
		"lore": "Dives into flooded intake shafts to clear silt blockages by hand."
	},
	{
		"hero_id": "linnea_reed",
		"name": "Linnea Reed",
		"title": "Seedbank Curator",
		"civic_job": "Crop Tender",
		"variant": 1,
		"active_id": "blight_cleanse",
		"active_name": "Blight Cleanse",
		"active_cd": 16.0,
		"active_short": "Purify Jammed Pad/Snare + 25 Stamina",
		"active_desc": "Purifies the nearest jammed pad or snare zone within 5m and restores +25 Stamina to self.",
		"passive_id": "seedbank_curator",
		"passive_name": "Seedbank Curator",
		"passive_desc": "Completing Greenhouse Crop tasks restores +2% bonus Town Stability.",
		"torso_color": Color(0.42, 0.56, 0.38),
		"accent_color": Color(0.72, 0.96, 0.55),
		"lore": "Guards the last heirloom grain vaults beneath the hydroponic beds."
	},
	{
		"hero_id": "vespera_crane",
		"name": "Vespera Crane",
		"title": "Scrap Logistics Specialist",
		"civic_job": "Salvage Quartermaster",
		"variant": 1,
		"active_id": "scrap_overdrive",
		"active_name": "Scrap Overdrive",
		"active_cd": 16.0,
		"active_short": "+40% Work Spd & +20% Move Spd (5s)",
		"active_desc": "Tunes her salvage rig for 5.0s, granting +40% task channel speed and +20% movement speed.",
		"passive_id": "scavengers_eye",
		"passive_name": "Scavenger's Eye",
		"passive_desc": "Completing Salvage tasks extracts +1 bonus Town Scrap.",
		"torso_color": Color(0.58, 0.30, 0.26),
		"accent_color": Color(1.0, 0.58, 0.28),
		"lore": "Can spot intact copper windings buried three feet deep in oxidized slag."
	},
	{
		"hero_id": "clara_vale",
		"name": "Clara Vale",
		"title": "Bio-Chemist Apothecary",
		"civic_job": "Field Medic",
		"variant": 1,
		"active_id": "adrenaline_tonic",
		"active_name": "Adrenaline Tonic",
		"active_cd": 15.0,
		"active_short": "+25 Stam, +25% Spd & Zero Sprint Drain (3.5s)",
		"active_desc": "Administers a stimulant burst restoring +25 Stamina and granting +25% speed with zero sprint drain for 3.5s.",
		"passive_id": "apothecarys_aura",
		"passive_name": "Apothecary's Aura",
		"passive_desc": "Nearby residents within 4m regenerate +2.0 extra Stamina/s.",
		"torso_color": Color(0.24, 0.48, 0.46),
		"accent_color": Color(0.62, 0.98, 0.78),
		"lore": "Synthesizes restorative tonics from filtered greenhouse condensates."
	},
	{
		"hero_id": "nyx_calder",
		"name": "Nyx Calder",
		"title": "Signal & Recon Officer",
		"civic_job": "Town Watch",
		"variant": 1,
		"active_id": "recon_pulse",
		"active_name": "Recon Pulse",
		"active_cd": 16.0,
		"active_short": "10m Radar Ping + 20% Move Speed (3.5s)",
		"active_desc": "Emits a 10m acoustic radar ping revealing nearby pad states & residents, plus +20% move speed for 3.5s.",
		"passive_id": "forensic_eye",
		"passive_name": "Forensic Eye",
		"passive_desc": "Inspects secluded Bedrock Alcoves and station pads +30% faster.",
		"torso_color": Color(0.28, 0.30, 0.38),
		"accent_color": Color(0.58, 0.78, 1.0),
		"lore": "Monitors acoustic sensors along the perimeter wall and bedrock crevices."
	}
]

static func get_hero_by_id(h_id: String) -> Dictionary:
	for h in HERO_ROSTER:
		if String(h.get("hero_id", "")) == h_id:
			return h
	return HERO_ROSTER[0]

static func get_hero_by_index(idx: int) -> Dictionary:
	if HERO_ROSTER.is_empty():
		return {}
	var safe_idx: int = posmod(idx, HERO_ROSTER.size())
	return HERO_ROSTER[safe_idx]

