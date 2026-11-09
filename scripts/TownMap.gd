class_name TownMap
extends Node2D

const C = preload("res://scripts/GameConstants.gd")

const PAD_COOLDOWN: float = C.PAD_COOLDOWN
const PAD_INTERACT_RADIUS: float = C.PAD_INTERACT_RADIUS

var game_manager: Node
var all_residents: Array = []
var anim_time: float = 0.0

# 4 named regions
var regions: Array[Dictionary] = [
	{
		"id": "town_square",
		"name": "Town Square / Common Works",
		"subtitle": "Central Hub • Council Ring & Shared Facility",
		"rect": Rect2(-440, -300, 880, 600),
		"floor_color": Color(0.16, 0.18, 0.21, 1.0),
		"border_color": Color(0.52, 0.58, 0.68, 1.0)
	},
	{
		"id": "greenhouse",
		"name": "Greenhouse & Fields",
		"subtitle": "North-West • Crop Beds (+Town Stability)",
		"rect": Rect2(-1120, -820, 620, 560),
		"floor_color": Color(0.11, 0.20, 0.15, 1.0),
		"border_color": Color(0.36, 0.78, 0.48, 1.0)
	},
	{
		"id": "salvage_yard",
		"name": "Salvage Yard",
		"subtitle": "North-East • Scrap Stacks (+Town Scrap)",
		"rect": Rect2(500, -820, 620, 560),
		"floor_color": Color(0.21, 0.16, 0.12, 1.0),
		"border_color": Color(0.88, 0.62, 0.32, 1.0)
	},
	{
		"id": "pump_station",
		"name": "Pump & Generator Station",
		"subtitle": "South • Water Turbines (+Water) & Buried Generator",
		"rect": Rect2(-620, 360, 1240, 460),
		"floor_color": Color(0.11, 0.17, 0.23, 1.0),
		"border_color": Color(0.36, 0.72, 0.96, 1.0)
	}
]

# 8 task pads (2 per region)
var task_pads: Array[Dictionary] = []

# Active field zones ("mulch_mist", "root_snare", "thorn_guard", "spark_trail", "disturbance_ring")
var active_zones: Array[Dictionary] = []

# Private snapshot markers for Tracker's Scent Trail (only populated when local player casts Scent Trail)
var private_scent_markers: Array[Dictionary] = []
var inspection_rings: Array[Dictionary] = []

# Waypoint graph for clean bot routing through wide corridors
var waypoints: Dictionary = {
	"hub_center": { "pos": Vector2(0, 60), "links": ["hub_nw", "hub_ne", "hub_south", "cw_west", "cw_east", "cw_struct", "cache_council"] },
	"cw_west": { "pos": Vector2(-190, -70), "links": ["hub_center", "hub_nw", "cw_struct"] },
	"cw_east": { "pos": Vector2(190, -70), "links": ["hub_center", "hub_ne", "cw_struct"] },
	"cw_struct": { "pos": Vector2(0, 10), "links": ["hub_center", "cw_west", "cw_east"] },
	"hub_nw": { "pos": Vector2(-420, -240), "links": ["hub_center", "cw_west", "gh_entry", "west_road", "cache_council"] },
	"hub_ne": { "pos": Vector2(420, -240), "links": ["hub_center", "cw_east", "sy_entry", "east_road"] },
	"hub_south": { "pos": Vector2(0, 310), "links": ["hub_center", "pump_entry", "west_road", "east_road"] },
	"gh_entry": { "pos": Vector2(-640, -400), "links": ["hub_nw", "gh_deep", "north_pass"] },
	"gh_deep": { "pos": Vector2(-920, -620), "links": ["gh_entry", "north_pass"] },
	"north_pass": { "pos": Vector2(0, -540), "links": ["gh_entry", "gh_deep", "sy_entry", "sy_deep", "cache_north_pass"] },
	"cache_north_pass": { "pos": Vector2(0, -680), "links": ["north_pass"] },
	"sy_entry": { "pos": Vector2(640, -400), "links": ["hub_ne", "sy_deep", "north_pass"] },
	"sy_deep": { "pos": Vector2(920, -620), "links": ["sy_entry", "north_pass", "cache_salvage"] },
	"cache_salvage": { "pos": Vector2(1050, -380), "links": ["sy_deep", "sy_entry"] },
	"west_road": { "pos": Vector2(-600, 120), "links": ["hub_nw", "hub_south", "pump_west"] },
	"east_road": { "pos": Vector2(600, 120), "links": ["hub_ne", "hub_south", "pump_east"] },
	"pump_entry": { "pos": Vector2(0, 470), "links": ["hub_south", "pump_west", "pump_east"] },
	"pump_west": { "pos": Vector2(-460, 490), "links": ["pump_entry", "west_road", "cache_pump"] },
	"cache_pump": { "pos": Vector2(-500, 740), "links": ["pump_west"] },
	"pump_east": { "pos": Vector2(520, 470), "links": ["pump_entry", "east_road"] },
	"cache_council": { "pos": Vector2(-340, 40), "links": ["hub_nw", "hub_center"] }
}

var wall_rects: Array[Rect2] = []
var hazard_pads: Dictionary = {}

func _ready() -> void:
	_init_task_pads()
	_build_walls()

func _init_task_pads() -> void:
	task_pads = [
		{
			"id": "cw_pad_eco",
			"label": "CW: Ecological Stabilization",
			"effect_tag": "+10% ECO (-1 Water)",
			"task_type": "cw_eco",
			"region": "Town Square / Common Works",
			"pos": Vector2(-190, -80),
			"console_offset": Vector2(56, 0),
			"waypoint": "cw_west",
			"color": Color(0.38, 0.88, 0.50),
			"cooldown": 0.0,
			"jammed_timer": 0.0,
			"overclocked": false,
			"channel_duration": 3.0,
			"last_user_name": "None",
			"last_use_time": -1.0,
			"active_user": null,
			"reserved_by": null
		},
		{
			"id": "cw_pad_tech",
			"label": "CW: Engineering Components",
			"effect_tag": "+10% TECH (-1 Scrap)",
			"task_type": "cw_tech",
			"region": "Town Square / Common Works",
			"pos": Vector2(190, -80),
			"console_offset": Vector2(-56, 0),
			"waypoint": "cw_east",
			"color": Color(0.95, 0.68, 0.32),
			"cooldown": 0.0,
			"jammed_timer": 0.0,
			"overclocked": false,
			"channel_duration": 3.0,
			"last_user_name": "None",
			"last_use_time": -1.0,
			"active_user": null,
			"reserved_by": null
		},
		{
			"id": "cw_pad_struct",
			"label": "CW: Structural Assembly",
			"effect_tag": "+10% STRUCT (-25 Stam)",
			"task_type": "cw_struct",
			"region": "Town Square / Common Works",
			"pos": Vector2(0, 10),
			"console_offset": Vector2(0, -36),
			"waypoint": "cw_struct",
			"color": Color(0.76, 0.62, 0.98),
			"cooldown": 0.0,
			"jammed_timer": 0.0,
			"overclocked": false,
			"channel_duration": 3.0,
			"last_user_name": "None",
			"last_use_time": -1.0,
			"active_user": null,
			"reserved_by": null
		},
		{
			"id": "cw_ratify_eco",
			"label": "Eco Charter Terminal",
			"effect_tag": "RATIFY CHARTER (Eco)",
			"task_type": "ratify_eco",
			"region": "Town Square / Common Works",
			"pos": Vector2(-95, -18),
			"console_offset": Vector2(-36, 0),
			"waypoint": "cw_west",
			"color": Color(0.38, 0.88, 0.50),
			"cooldown": 0.0,
			"jammed_timer": 0.0,
			"overclocked": false,
			"channel_duration": 3.0,
			"last_user_name": "None",
			"last_use_time": -1.0,
			"active_user": null,
			"reserved_by": null
		},
		{
			"id": "cw_ratify_tech",
			"label": "Tech Charter Terminal",
			"effect_tag": "RATIFY CHARTER (Tech)",
			"task_type": "ratify_tech",
			"region": "Town Square / Common Works",
			"pos": Vector2(95, -18),
			"console_offset": Vector2(36, 0),
			"waypoint": "cw_east",
			"color": Color(0.95, 0.68, 0.32),
			"cooldown": 0.0,
			"jammed_timer": 0.0,
			"overclocked": false,
			"channel_duration": 3.0,
			"last_user_name": "None",
			"last_use_time": -1.0,
			"active_user": null,
			"reserved_by": null
		},
		{
			"id": "obj_generator",
			"label": "Buried Generator Hatch",
			"effect_tag": "ALIGN GENERATOR",
			"task_type": "generator_objective",
			"region": "Pump & Generator Station",
			"pos": Vector2(325, 480),
			"console_offset": Vector2(0, 45),
			"waypoint": "pump_east",
			"color": Color(0.92, 0.48, 0.40),
			"cooldown": 0.0,
			"jammed_timer": 0.0,
			"overclocked": false,
			"channel_duration": 4.0,
			"last_user_name": "None",
			"last_use_time": -1.0,
			"active_user": null,
			"reserved_by": null
		},
		{
			"id": "obj_beacon",
			"label": "Emergency Beacon",
			"effect_tag": "TUNE FREQUENCY",
			"task_type": "beacon_objective",
			"region": "Salvage Yard",
			"pos": Vector2(850, -420),
			"console_offset": Vector2(0, -45),
			"waypoint": "sy_entry",
			"color": Color(0.48, 0.82, 0.98),
			"cooldown": 0.0,
			"jammed_timer": 0.0,
			"overclocked": false,
			"channel_duration": 4.0,
			"last_user_name": "None",
			"last_use_time": -1.0,
			"active_user": null,
			"reserved_by": null
		},
		{
			"id": "gh_pad_1",
			"label": "Tend Crops (North Bed)",
			"effect_tag": "+7 STABILITY",
			"task_type": "greenhouse",
			"region": "Greenhouse & Fields",
			"pos": Vector2(-930, -650),
			"console_offset": Vector2(0, -54),
			"waypoint": "gh_deep",
			"color": Color(0.38, 0.88, 0.50),
			"cooldown": 0.0,
			"jammed_timer": 0.0,
			"overclocked": false,
			"last_user_name": "None",
			"last_use_time": -1.0,
			"active_user": null,
			"reserved_by": null
		},
		{
			"id": "gh_pad_2",
			"label": "Tend Crops (South Bed)",
			"effect_tag": "+7 STABILITY",
			"task_type": "greenhouse",
			"region": "Greenhouse & Fields",
			"pos": Vector2(-680, -450),
			"console_offset": Vector2(0, -54),
			"waypoint": "gh_entry",
			"color": Color(0.38, 0.88, 0.50),
			"cooldown": 0.0,
			"jammed_timer": 0.0,
			"overclocked": false,
			"last_user_name": "None",
			"last_use_time": -1.0,
			"active_user": null,
			"reserved_by": null
		},
		{
			"id": "sy_pad_1",
			"label": "Gather Scrap (West Bay)",
			"effect_tag": "+2 SCRAP",
			"task_type": "salvage",
			"region": "Salvage Yard",
			"pos": Vector2(680, -450),
			"console_offset": Vector2(0, -54),
			"waypoint": "sy_entry",
			"color": Color(0.95, 0.68, 0.32),
			"cooldown": 0.0,
			"jammed_timer": 0.0,
			"overclocked": false,
			"last_user_name": "None",
			"last_use_time": -1.0,
			"active_user": null,
			"reserved_by": null
		},
		{
			"id": "sy_pad_2",
			"label": "Gather Scrap (East Bay)",
			"effect_tag": "+2 SCRAP",
			"task_type": "salvage",
			"region": "Salvage Yard",
			"pos": Vector2(930, -650),
			"console_offset": Vector2(0, -54),
			"waypoint": "sy_deep",
			"color": Color(0.95, 0.68, 0.32),
			"cooldown": 0.0,
			"jammed_timer": 0.0,
			"overclocked": false,
			"last_user_name": "None",
			"last_use_time": -1.0,
			"active_user": null,
			"reserved_by": null
		},
		{
			"id": "pump_pad_1",
			"label": "Repair Pump (Main Turbine)",
			"effect_tag": "+8 WATER",
			"task_type": "pump",
			"region": "Pump & Generator Station",
			"pos": Vector2(-360, 600),
			"console_offset": Vector2(0, 56),
			"waypoint": "pump_west",
			"color": Color(0.34, 0.78, 0.98),
			"cooldown": 0.0,
			"jammed_timer": 0.0,
			"overclocked": false,
			"last_user_name": "None",
			"last_use_time": -1.0,
			"active_user": null,
			"reserved_by": null
		},
		{
			"id": "pump_pad_2",
			"label": "Repair Pump (Aux Intake)",
			"effect_tag": "+8 WATER",
			"task_type": "pump",
			"region": "Pump & Generator Station",
			"pos": Vector2(-80, 620),
			"console_offset": Vector2(0, 56),
			"waypoint": "pump_entry",
			"color": Color(0.34, 0.78, 0.98),
			"cooldown": 0.0,
			"jammed_timer": 0.0,
			"overclocked": false,
			"last_user_name": "None",
			"last_use_time": -1.0,
			"active_user": null,
			"reserved_by": null
		}
	]
	for pad in task_pads:
		pad["last_action"] = ""
		pad["last_action_clock"] = ""

func reset_pads() -> void:
	for pad in task_pads:
		pad["cooldown"] = 0.0
		pad["jammed_timer"] = 0.0
		pad["overclocked"] = false
		pad["last_user_name"] = "None"
		pad["last_use_time"] = -1.0
		pad["last_action"] = ""
		pad["last_action_clock"] = ""
		pad["active_user"] = null
		pad["reserved_by"] = null
	hazard_pads.clear()
	active_zones.clear()
	private_scent_markers.clear()
	inspection_rings.clear()
	queue_redraw()

func _build_walls() -> void:
	wall_rects = [
		# Outer perimeter walls
		Rect2(-1200, -900, 2400, 44),
		Rect2(-1200, 856, 2400, 44),
		Rect2(-1200, -900, 44, 1800),
		Rect2(1156, -900, 44, 1800),

		# North-center divider blocks (leaving wide 220px North Pass corridor)
		Rect2(-460, -856, 320, 210),
		Rect2(140, -856, 320, 210),

		# Divider walls between outer wings and Town Square (leaving >200px wide gates)
		Rect2(-880, -220, 200, 36),
		Rect2(680, -220, 200, 36),

		# South station divider blocks (leaving wide West, Center, and East gates)
		Rect2(-1156, 320, 390, 38),
		Rect2(-440, 320, 280, 38),
		Rect2(160, 320, 280, 38),
		Rect2(766, 320, 390, 38),

		# Central Common Works core structure (solid centerpiece between the two CW pads)
		Rect2(-85, -145, 170, 110),

		# Buried Generator Hatch landmark housing (South-East of Pump Station)
		Rect2(250, 540, 150, 110)
	]

	var static_body := StaticBody2D.new()
	static_body.name = "TownWalls"
	static_body.collision_layer = 1
	static_body.collision_mask = 0
	add_child(static_body)

	for rect in wall_rects:
		var shape_node := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape_node.shape = box
		shape_node.position = rect.position + rect.size * 0.5
		static_body.add_child(shape_node)

func _process(delta: float) -> void:
	anim_time += delta
	for pad in task_pads:
		if pad["cooldown"] > 0.0:
			pad["cooldown"] = maxf(0.0, pad["cooldown"] - delta)
		if pad["jammed_timer"] > 0.0:
			pad["jammed_timer"] = maxf(0.0, pad["jammed_timer"] - delta)

	for hid in hazard_pads.keys():
		var hpad: Dictionary = hazard_pads[hid]
		if hpad["cooldown"] > 0.0:
			hpad["cooldown"] = maxf(0.0, hpad["cooldown"] - delta)

	for i in range(active_zones.size() - 1, -1, -1):
		active_zones[i]["time_left"] -= delta
		if active_zones[i]["time_left"] <= 0.0:
			active_zones.remove_at(i)

	for j in range(private_scent_markers.size() - 1, -1, -1):
		private_scent_markers[j]["time_left"] -= delta
		if private_scent_markers[j]["time_left"] <= 0.0:
			private_scent_markers.remove_at(j)
	for k in range(inspection_rings.size() - 1, -1, -1):
		inspection_rings[k]["time_left"] -= delta
		if inspection_rings[k]["time_left"] <= 0.0:
			inspection_rings.remove_at(k)

	queue_redraw()

func has_clear_sightline(a: Vector2, b: Vector2) -> bool:
	for rect in wall_rects:
		if rect.has_point(a) or rect.has_point(b):
			return false
		var tl := rect.position
		var tr := Vector2(rect.end.x, rect.position.y)
		var br := rect.end
		var bl := Vector2(rect.position.x, rect.end.y)
		if Geometry2D.segment_intersects_segment(a, b, tl, tr) != null:
			return false
		if Geometry2D.segment_intersects_segment(a, b, tr, br) != null:
			return false
		if Geometry2D.segment_intersects_segment(a, b, br, bl) != null:
			return false
		if Geometry2D.segment_intersects_segment(a, b, bl, tl) != null:
			return false
	return true

func spawn_field_zone(zone_type: String, pos: Vector2, radius: float, duration: float, owner_id: int, extra_text: String = "", start_pos: Vector2 = Vector2.ZERO) -> void:
	active_zones.append({
		"type": zone_type,
		"pos": pos,
		"start_pos": start_pos,
		"radius": radius,
		"duration": duration,
		"time_left": duration,
		"owner_id": owner_id,
		"extra_text": extra_text,
		"region": extra_text if zone_type == "disturbance_ring" else ""
	})
	queue_redraw()

func get_inspection_target(pos: Vector2, max_distance: float = 100.0) -> Dictionary:
	# 1. Secluded Old-World Archive cache spawns
	for spawn in C.ARCHIVE_CACHE_SPAWNS:
		var c_pos: Vector2 = spawn["pos"]
		if pos.distance_to(c_pos) <= max_distance:
			var is_active: bool = (game_manager != null and game_manager.archive_active_spawn_id == String(spawn["id"]))
			var is_opened: bool = (game_manager != null and game_manager.archive_opened)
			var lbl: String = "Opened Archive Container" if (is_active and is_opened) else "Secluded Bedrock Alcove"
			return {
				"kind": "archive_cache",
				"id": "cache:" + String(spawn["id"]),
				"spawn_id": String(spawn["id"]),
				"label": lbl,
				"pos": c_pos,
				"region": String(spawn["region"]),
				"is_active": is_active,
				"is_opened": (is_active and is_opened)
			}

	var pad: Dictionary = get_nearest_pad(pos, max_distance)
	if not pad.is_empty():
		return {"kind": "pad", "id": String(pad["id"]), "label": String(pad["label"]), "pos": pad["pos"], "region": String(pad["region"]), "pad": pad}
	var best_zone: Dictionary = {}
	var best_dist: float = max_distance
	for zone in active_zones:
		if zone["type"] not in ["disturbance_ring", "root_snare"]:
			continue
		var d: float = pos.distance_to(zone["pos"])
		if d <= best_dist:
			best_dist = d
			best_zone = zone
	if not best_zone.is_empty():
		var kind: String = "disturbance" if best_zone["type"] == "disturbance_ring" else "zone"
		var zone_region: String = String(best_zone.get("region", get_region_name_at(best_zone["pos"])))
		return {"kind": kind, "id": "%s:%s" % [kind, zone_region], "label": "Regional disturbance site" if kind == "disturbance" else "Briar Patch site", "pos": best_zone["pos"], "region": zone_region, "zone": best_zone}
	for reg in regions:
		var rect: Rect2 = reg["rect"]
		var center: Vector2 = rect.position + rect.size * 0.5
		if pos.distance_to(center) <= max_distance:
			return {"kind": "landmark", "id": "landmark:%s" % String(reg["name"]), "label": String(reg["name"]) + " landmark", "pos": center, "region": String(reg["name"])}
	return {}

func complete_site_inspection(resident: Node, target: Dictionary) -> Dictionary:
	if resident == null or game_manager == null or target.is_empty():
		return {}
	var region_name: String = String(target.get("region", "Town Corridors"))
	var stamp: String = game_manager.get_current_phase_clock_text()
	var trace_text: String = "Physical inspection at %s confirmed a recent site visit at %s." % [String(target.get("label", "site")), stamp]

	if target.get("kind", "") == "archive_cache":
		var is_active: bool = bool(target.get("is_active", false))
		if is_active:
			if not game_manager.archive_opened:
				var res_entry: Dictionary = game_manager.open_archive(resident, target)
				inspection_rings.append({"pos": target["pos"], "time_left": 15.0})
				queue_redraw()
				return res_entry
			else:
				trace_text = "Old-World Archive accessed and failsafe key extracted at %s." % game_manager.archive_open_time
		else:
			trace_text = "Weathered bedrock alcove inspected at %s. No pre-collapse cache present." % stamp
		var cache_entry: Dictionary = game_manager.add_private_trace(int(resident.resident_id), trace_text, region_name, stamp)
		inspection_rings.append({"pos": target["pos"], "time_left": 12.0})
		game_manager.record_inspection_complete(resident, target, cache_entry, self, all_residents)
		queue_redraw()
		return cache_entry

	if target.get("kind", "") == "pad":
		var pad: Dictionary = target["pad"]
		var action: String = String(pad.get("last_action", ""))
		var action_time: String = String(pad.get("last_action_clock", ""))
		if action_time != "":
			stamp = action_time
		match String(pad.get("task_type", "")):
			"pump":
				trace_text = "Fresh bypass wiring and mechanical tool marks on %s at %s." % [String(target["label"]), stamp] if action == "jammed" else "Recent vibration and tool marks recorded on %s at %s." % [String(target["label"]), stamp]
			"greenhouse":
				trace_text = "Organic soil stimulant residue and accelerated root clusters at %s at %s." % [String(target["label"]), stamp] if action == "snared" else "Fresh soil disturbance and root residue at %s at %s." % [String(target["label"]), stamp]
			"salvage":
				trace_text = "Inventory log mismatch: a high-conductivity relay is missing at %s at %s." % [String(target["label"]), stamp]
			"generator_objective":
				trace_text = "Subterranean generator telemetry confirms recent alignment calibration at %s." % stamp
			"beacon_objective":
				trace_text = "Emergency beacon radio spectrum logs show recent frequency modulation at %s." % stamp
			"cw_eco":
				trace_text = "Ecological stabilization filtration manifold shows fresh water throughput at %s." % stamp
			"cw_tech":
				trace_text = "Engineering component array confirms newly fitted scrap relays at %s." % stamp
			"cw_struct":
				trace_text = "Structural assembly seismic bracing shows high-tensile torque marks at %s." % stamp
			"ratify_eco":
				trace_text = "Ecological Charter ratification terminal logs show signed accord at %s." % stamp
			"ratify_tech":
				trace_text = "Technology Charter ratification terminal logs show verified accord at %s." % stamp
			"hazard_clear":
				trace_text = "Emergency hazard containment station shows recent filter flush at %s." % stamp
			_:
				trace_text = "Structural test confirms recent changes to %s at %s." % [String(target["label"]), stamp]
		var trace_entry: Dictionary = game_manager.add_private_trace(int(resident.resident_id), trace_text, region_name, stamp)
		inspection_rings.append({"pos": target["pos"], "time_left": 12.0})
		game_manager.record_inspection_complete(resident, target, trace_entry, self, all_residents)
		queue_redraw()
		return trace_entry
	if target.get("kind", "") == "disturbance":
		trace_text = "Physical residue confirms an unusual disturbance occurred near %s at %s." % [region_name, stamp]
	elif target.get("kind", "") == "zone":
		trace_text = "Organic root expansion and disturbed soil confirm recent growth in %s at %s." % [region_name, stamp]
	else:
		trace_text = "Structural test at the %s landmark found recent surface disturbance at %s." % [region_name, stamp]
	var result: Dictionary = game_manager.add_private_trace(int(resident.resident_id), trace_text, region_name, stamp)
	inspection_rings.append({"pos": target["pos"], "time_left": 12.0})
	game_manager.record_inspection_complete(resident, target, result, self, all_residents)
	queue_redraw()
	return result

func trigger_tracker_scent_snapshot(caster: Node2D, all_residents: Array, scan_radius: float = 320.0, duration: float = 5.0) -> int:
	var found_count := 0
	var now_time: float = 0.0 if game_manager == null else float(game_manager.match_elapsed)

	var pad_traces: Array[Dictionary] = []
	for pad in task_pads:
		if caster.global_position.distance_to(pad["pos"]) <= scan_radius:
			var trace_str := "No Recent Trace"
			if float(pad["last_use_time"]) >= 0.0 and String(pad["last_user_name"]) != "None":
				var ago: float = maxf(0.0, now_time - float(pad["last_use_time"]))
				trace_str = "Last Touch: %s (%.0fs ago)" % [pad["last_user_name"], ago]
				found_count += 1
			pad_traces.append({
				"pos": pad["pos"],
				"label": pad["label"],
				"trace": trace_str
			})

	var footprints: Array[Dictionary] = []
	for other in all_residents:
		if other == null or other == caster or other.is_incapacitated:
			continue
		if caster.global_position.distance_to(other.global_position) <= scan_radius:
			found_count += 1
			footprints.append({
				"pos": other.global_position,
				"angle": other.facing_angle,
				"name": other.resident_name
			})

	# Strictly private to the casting Tracker: only render on screen if local player is the caster
	if caster.get("is_player"):
		private_scent_markers.clear()
		private_scent_markers.append({
			"origin": caster.global_position,
			"radius": scan_radius,
			"duration": duration,
			"time_left": duration,
			"pad_traces": pad_traces,
			"footprints": footprints
		})
		queue_redraw()

	return found_count

func is_inside_mulch_mist(pos: Vector2) -> bool:
	for z in active_zones:
		if z["type"] == "mulch_mist" and pos.distance_to(z["pos"]) <= float(z["radius"]):
			return true
	return false

func is_slowed_by_root_snare(pos: Vector2, res_id: int) -> bool:
	for z in active_zones:
		if z["type"] == "root_snare" and int(z["owner_id"]) != res_id and pos.distance_to(z["pos"]) <= float(z["radius"]):
			return true
	return false

func is_protected_by_thorn_guard(pos: Vector2) -> bool:
	for z in active_zones:
		if z["type"] == "thorn_guard" and pos.distance_to(z["pos"]) <= float(z["radius"]):
			return true
	return false

func record_pad_interaction(pad: Dictionary, actor_name: String, action: String = "used") -> void:
	if pad.is_empty():
		return
	pad["last_user_name"] = actor_name
	pad["last_use_time"] = 0.0 if game_manager == null else float(game_manager.match_elapsed)
	pad["last_action"] = action
	pad["last_action_clock"] = "" if game_manager == null else game_manager.get_current_phase_clock_text()

func get_region_name_at(pos: Vector2) -> String:
	for reg in regions:
		if reg["rect"].has_point(pos):
			return reg["name"]
	return "Town Corridors"

func get_region_alert_anchor_at(pos: Vector2) -> Vector2:
	for reg in regions:
		if reg["rect"].has_point(pos):
			var r: Rect2 = reg["rect"]
			return r.position + r.size * 0.5
	var wp_id := get_nearest_waypoint_id(pos)
	return waypoints[wp_id]["pos"]

func _sync_hazard_pads() -> void:
	if game_manager == null or not game_manager.holdout_active:
		hazard_pads.clear()
		return
	var active_ids: Array[String] = []
	for h in game_manager.active_hazards:
		var hid: String = String(h["id"])
		active_ids.append(hid)
		if not hazard_pads.has(hid):
			hazard_pads[hid] = {
				"id": "hazard:" + hid,
				"hazard_id": hid,
				"label": "Mitigate " + String(h["label"]),
				"effect_tag": "CRISIS HAZARD CLEAR",
				"task_type": "hazard_clear",
				"region": String(h["region"]),
				"pos": Vector2(h["pos"]),
				"console_offset": Vector2(0, -32),
				"color": Color(0.95, 0.45, 0.35) if String(h["kind"]) == "blight" else Color(0.95, 0.70, 0.35),
				"cooldown": 0.0,
				"jammed_timer": 0.0,
				"overclocked": false,
				"channel_duration": C.HOLDOUT_HAZARD_CLEAR_DURATION,
				"active_user": null,
				"reserved_by": null,
				"last_user_name": "None",
				"last_use_time": -1.0,
				"last_action": "",
				"last_action_clock": ""
			}
	var to_remove: Array[String] = []
	for hid in hazard_pads.keys():
		if not active_ids.has(hid):
			to_remove.append(hid)
	for hid in to_remove:
		hazard_pads.erase(hid)

func get_nearest_pad(pos: Vector2, max_dist: float = PAD_INTERACT_RADIUS) -> Dictionary:
	_sync_hazard_pads()
	var best_pad: Dictionary = {}
	var best_dist: float = max_dist
	for pad in task_pads:
		var d: float = pos.distance_to(pad["pos"])
		if d <= best_dist:
			best_dist = d
			best_pad = pad
	for hid in hazard_pads.keys():
		var hpad: Dictionary = hazard_pads[hid]
		var d: float = pos.distance_to(hpad["pos"])
		if d <= best_dist:
			best_dist = d
			best_pad = hpad
	return best_pad

func is_pad_available_for_bot(pad: Dictionary, bot: Node2D) -> bool:
	if pad.is_empty():
		return false
	if pad["cooldown"] > 0.0 or pad["jammed_timer"] > 0.0:
		return false
	if pad["active_user"] != null and pad["active_user"] != bot:
		return false
	if pad["reserved_by"] != null and pad["reserved_by"] != bot:
		return false
	if game_manager != null and not game_manager.can_perform_task(pad["task_type"]):
		return false
	var task_t: String = String(pad.get("task_type", ""))
	if task_t == "ratify_eco":
		var align: String = game_manager.get_resident_alignment(bot) if game_manager != null else ""
		if align != "ecology" and bot.get("secret_role") != "ecology":
			return false
	elif task_t == "ratify_tech":
		var align: String = game_manager.get_resident_alignment(bot) if game_manager != null else ""
		if align != "technology" and bot.get("secret_role") != "technology":
			return false
	return true

func reserve_pad(pad: Dictionary, bot: Node2D) -> bool:
	if not is_pad_available_for_bot(pad, bot):
		return false
	release_reservations_for(bot)
	pad["reserved_by"] = bot
	return true

func release_reservations_for(resident: Node2D) -> void:
	for pad in task_pads:
		if pad["reserved_by"] == resident:
			pad["reserved_by"] = null
		if pad["active_user"] == resident:
			pad["active_user"] = null
	for hid in hazard_pads.keys():
		var hpad: Dictionary = hazard_pads[hid]
		if hpad["reserved_by"] == resident:
			hpad["reserved_by"] = null
		if hpad["active_user"] == resident:
			hpad["active_user"] = null

func start_using_pad(pad: Dictionary, resident: Node2D) -> bool:
	if pad.is_empty() or pad["cooldown"] > 0.0 or pad["jammed_timer"] > 0.0:
		return false
	if pad["active_user"] != null and pad["active_user"] != resident:
		return false
	if game_manager != null and not game_manager.can_perform_task(pad["task_type"]):
		return false
	pad["active_user"] = resident
	pad["reserved_by"] = resident
	record_resident_action(resident, "accessed " + String(pad["label"]))
	check_sensor_beacon(resident, resident.global_position, String(pad["label"]))
	queue_redraw()
	return true

func finish_using_pad(pad: Dictionary, resident: Node2D, is_player: bool) -> void:
	if pad.is_empty():
		return
	var was_overclocked: bool = bool(pad["overclocked"])
	pad["overclocked"] = false
	pad["active_user"] = null
	pad["reserved_by"] = null
	pad["cooldown"] = PAD_COOLDOWN
	record_pad_interaction(pad, resident.get("resident_name"), "worked")
	if game_manager != null:
		var p_task: String = String(pad.get("task_type", ""))
		if game_manager.current_phase == game_manager.Phase.FINALE and game_manager.finale_route == C.FINALE_ROUTE_CONFRONTATION and p_task == "generator_objective":
			pad["cooldown"] = 1.0
			game_manager.record_generator_tug(resident)
		elif p_task == "ratify_eco":
			pad["cooldown"] = 1.0
			game_manager.record_charter_ratification(resident, "ratify_eco")
		elif p_task == "ratify_tech":
			pad["cooldown"] = 1.0
			game_manager.record_charter_ratification(resident, "ratify_tech")
		elif p_task == "hazard_clear":
			pad["cooldown"] = 1.0
			game_manager.clear_holdout_hazard(String(pad.get("hazard_id", "")), resident.get("resident_name"))
		else:
			game_manager.execute_task(p_task, resident.get("resident_name"), is_player, was_overclocked)
	queue_redraw()

func check_sensor_beacon(resident: Node, pos: Vector2, site_name: String) -> void:
	if game_manager == null or not game_manager.sensor_beacons_active or game_manager.current_phase != game_manager.Phase.ESCALATION:
		return
	var beacon_sites: Array[Dictionary] = [
		{"name": "Pump Station Sensor Beacon", "region": "Pump & Generator Station", "pos": Vector2(-360, 600)},
		{"name": "Greenhouse Sensor Beacon", "region": "Greenhouse & Fields", "pos": Vector2(-930, -650)}
	]
	for beacon in beacon_sites:
		if pos.distance_to(beacon["pos"]) <= 160.0:
			game_manager.record_beacon_access(resident, String(beacon["region"]), site_name)

func record_resident_action(resident: Node, action_label: String) -> void:
	if resident == null or game_manager == null:
		return
	game_manager.record_observed_sighting(resident, resident.global_position, self, all_residents, action_label)

func get_nearest_waypoint_id(pos: Vector2) -> String:
	var best_id := "hub_center"
	var best_dist := INF
	for wp_id in waypoints.keys():
		var d: float = pos.distance_to(waypoints[wp_id]["pos"])
		if d < best_dist:
			best_dist = d
			best_id = wp_id
	return best_id

func find_waypoint_path(from_pos: Vector2, target_wp_id: String) -> Array[Vector2]:
	var start_id := get_nearest_waypoint_id(from_pos)
	if start_id == target_wp_id:
		return [waypoints[target_wp_id]["pos"]]

	var queue: Array[String] = [start_id]
	var came_from: Dictionary = { start_id: "" }

	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == target_wp_id:
			break
		for neighbor in waypoints[current]["links"]:
			if not came_from.has(neighbor):
				came_from[neighbor] = current
				queue.append(neighbor)

	var path: Array[Vector2] = []
	if not came_from.has(target_wp_id):
		path.append(waypoints[target_wp_id]["pos"])
		return path

	var step := target_wp_id
	while step != "":
		path.push_front(waypoints[step]["pos"])
		step = came_from[step]
	return path

func _draw() -> void:
	var font := ThemeDB.fallback_font

	# 1. Base ground & subtle grid
	draw_rect(Rect2(-1200, -900, 2400, 1800), Color(0.10, 0.11, 0.13, 1.0), true)
	for x in range(-1100, 1200, 100):
		draw_line(Vector2(x, -860), Vector2(x, 860), Color(1, 1, 1, 0.025), 1.0)
	for y in range(-800, 900, 100):
		draw_line(Vector2(-1160, y), Vector2(1160, y), Color(1, 1, 1, 0.025), 1.0)

	# 2. Paved Road Network & Colored Utility Conduit Guides
	for wp_id in waypoints.keys():
		var p1: Vector2 = waypoints[wp_id]["pos"]
		for linked_id in waypoints[wp_id]["links"]:
			var p2: Vector2 = waypoints[linked_id]["pos"]
			draw_line(p1, p2, Color(0.19, 0.21, 0.25, 0.65), 34.0)

	var water_pipe_pts: PackedVector2Array = [
		Vector2(-360, 660), Vector2(-360, 480), Vector2(0, 480),
		Vector2(0, 60), Vector2(-420, -240), Vector2(-680, -450), Vector2(-930, -650)
	]
	draw_polyline(water_pipe_pts, Color(0.24, 0.62, 0.88, 0.42), 6.0)

	var salvage_track_pts: PackedVector2Array = [
		Vector2(930, -650), Vector2(680, -450), Vector2(420, -240), Vector2(190, -80)
	]
	draw_polyline(salvage_track_pts, Color(0.85, 0.58, 0.28, 0.40), 6.0)

	# 3. Four Regions Base Floors & Headers
	for reg in regions:
		var r: Rect2 = reg["rect"]
		draw_rect(r, reg["floor_color"], true)
		draw_rect(r, reg["border_color"], false, 3.5)
		draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 64), Color(0, 0, 0, 0.32), true)
		draw_string(font, r.position + Vector2(20, 32), reg["name"].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, reg["border_color"].lightened(0.30))
		draw_string(font, r.position + Vector2(20, 54), reg["subtitle"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.82, 0.86, 0.92, 0.90))

	# 4. Standout Regional Landmarks
	_draw_greenhouse_landmarks(font)
	_draw_salvage_landmarks(font)
	_draw_pump_station_landmarks(font)
	_draw_town_square_landmarks(font)

	# 5. Active Field Zones (Mulch Mist, Root Snare, Thorn Guard, Spark Trail, Disturbance Ring)
	_draw_active_zones(font)
	for ring in inspection_rings:
		var ring_pos: Vector2 = ring["pos"]
		var ring_alpha: float = clampf(float(ring["time_left"]) / 12.0, 0.15, 1.0)
		draw_arc(ring_pos, 58.0, 0.0, TAU, 36, Color(0.50, 0.90, 1.0, ring_alpha), 2.5)
		draw_string(font, ring_pos + Vector2(-56, -66), "INSPECTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.66, 0.94, 1.0, ring_alpha))
	if game_manager != null and game_manager.sensor_beacons_active and game_manager.current_phase == game_manager.Phase.ESCALATION:
		for beacon in [{"pos": Vector2(-360, 600), "name": "PUMP SENSOR"}, {"pos": Vector2(-930, -650), "name": "GREENHOUSE SENSOR"}]:
			var bpos: Vector2 = beacon["pos"]
			draw_circle(bpos, 16.0 + sin(anim_time * 4.0) * 2.0, Color(1.0, 0.78, 0.32, 0.20))
			draw_arc(bpos, 25.0, 0.0, TAU, 28, Color(1.0, 0.82, 0.42, 0.90), 2.0)
			draw_string(font, bpos + Vector2(22, -14), String(beacon["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.86, 0.50))

	# 6. Solid Walls & Core Structures
	for i in range(wall_rects.size()):
		var wr: Rect2 = wall_rects[i]
		if i == wall_rects.size() - 2:
			_draw_common_works_building(wr, font)
		elif i == wall_rects.size() - 1:
			_draw_buried_generator_hatch(wr, font)
		else:
			draw_rect(wr, Color(0.26, 0.29, 0.34, 1.0), true)
			draw_rect(Rect2(wr.position + Vector2(4, 4), wr.size - Vector2(8, 8)), Color(0.21, 0.24, 0.28, 1.0), true)
			draw_rect(wr, Color(0.45, 0.50, 0.58, 1.0), false, 2.0)

	# 7. Crossroads Directional Signposts around Town Square exits
	_draw_signpost(Vector2(-420, -232), "↖ GREENHOUSE", "Tend Crops (+Stability)", Color(0.42, 0.88, 0.52), font)
	_draw_signpost(Vector2(252, -232), "↗ SALVAGE YARD", "Gather Scrap (+Parts)", Color(0.95, 0.68, 0.34), font)
	_draw_signpost(Vector2(-84, 246), "↓ PUMP STATION", "Repair Pump (+Water)", Color(0.38, 0.78, 0.98), font)

	# 8. Interactive Task Stations
	for pad in task_pads:
		_draw_task_station(pad, font)

	# 8b. Active Holdout Hazards (Peace Route Holdout)
	_draw_holdout_hazards(font)

	# 9. Secluded Old-World Archive Caches
	_draw_archive_caches(font)

	# 10. Private Tracker Scent Trail Snapshot Overlay (Local Tracker Player Only)
	_draw_private_scent_markers(font)

func _draw_active_zones(font: Font) -> void:
	for z in active_zones:
		var z_type: String = z["type"]
		var pos: Vector2 = z["pos"]
		var rad: float = z["radius"]
		var rem: float = z["time_left"]
		match z_type:
			"mulch_mist":
				draw_circle(pos, rad, Color(0.32, 0.88, 0.52, 0.18))
				draw_arc(pos, rad, 0.0, TAU, 36, Color(0.45, 0.96, 0.62, 0.75), 2.5)
				draw_string(font, pos + Vector2(-58, -rad - 8), "Mulch Mist (+8 Stam/s) %.1fs" % rem, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.62, 1.0, 0.72))
			"root_snare":
				draw_circle(pos, rad, Color(0.28, 0.48, 0.20, 0.28))
				draw_arc(pos, rad, 0.0, TAU, 36, Color(0.58, 0.85, 0.34, 0.88), 3.0)
				for b in range(6):
					var a := float(b) * (TAU / 6.0) + anim_time * 0.6
					draw_line(pos + Vector2(cos(a), sin(a)) * 22.0, pos + Vector2(cos(a + 0.5), sin(a + 0.5)) * (rad - 8.0), Color(0.48, 0.76, 0.28, 0.75), 2.5)
				draw_string(font, pos + Vector2(-56, -rad - 8), "Root Snare (-45%% Spd) %.1fs" % rem, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.96, 0.48))
			"thorn_guard":
				draw_circle(pos, rad, Color(0.22, 0.62, 0.42, 0.22))
				draw_arc(pos, rad, 0.0, TAU, 36, Color(0.42, 0.98, 0.68, 0.92), 3.5)
				draw_string(font, pos + Vector2(-64, rad + 18), "Thorn Guard (Protected) %.1fs" % rem, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.58, 1.0, 0.78))
			"spark_trail":
				var s_pos: Vector2 = z["start_pos"]
				draw_line(s_pos, pos, Color(0.38, 0.86, 1.0, 0.65), 5.0)
				draw_circle(pos, 14.0, Color(0.55, 0.92, 1.0, 0.45))
				draw_string(font, (s_pos + pos) * 0.5 + Vector2(-42, -12), "Spark Trail (%.1fs)" % rem, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.92, 1.0))
			"disturbance_ring":
				var pulse := 0.5 + 0.5 * sin(anim_time * 6.0)
				draw_arc(pos, rad, 0.0, TAU, 48, Color(1.0, 0.76, 0.32, 0.42 + 0.32 * pulse), 2.5)
				draw_string(font, pos + Vector2(-86, -rad - 10), "Regional Disturbance Reported (%.1fs)" % rem, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.84, 0.45))

func _draw_private_scent_markers(font: Font) -> void:
	for scan in private_scent_markers:
		var origin: Vector2 = scan["origin"]
		var rad: float = scan["radius"]
		var rem: float = scan["time_left"]
		var alpha: float = clampf(rem / float(scan["duration"]), 0.2, 1.0)

		draw_arc(origin, rad, 0.0, TAU, 48, Color(0.45, 0.98, 0.68, 0.45 * alpha), 2.0)

		for pt in scan["pad_traces"]:
			var p_pos: Vector2 = pt["pos"]
			var tag_rect := Rect2(p_pos.x - 98, p_pos.y + 52, 196, 22)
			draw_rect(tag_rect, Color(0.06, 0.16, 0.12, 0.94 * alpha), true)
			draw_rect(tag_rect, Color(0.45, 0.98, 0.68, 0.9 * alpha), false, 1.5)
			draw_string(font, tag_rect.position + Vector2(8, 15), String(pt["trace"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 1.0, 0.82, alpha))

		for fp in scan["footprints"]:
			var f_pos: Vector2 = fp["pos"]
			var ang: float = fp["angle"]
			var dir := Vector2(cos(ang), sin(ang))
			var side := Vector2(-dir.y, dir.x)
			var tip := f_pos + dir * 28.0
			draw_line(f_pos, tip, Color(0.48, 1.0, 0.68, 0.92 * alpha), 3.0)
			draw_line(tip, tip - dir * 10.0 + side * 6.0, Color(0.48, 1.0, 0.68, 0.92 * alpha), 2.5)
			draw_line(tip, tip - dir * 10.0 - side * 6.0, Color(0.48, 1.0, 0.68, 0.92 * alpha), 2.5)
			draw_string(font, f_pos + Vector2(-38, -24), "Scent: %s" % String(fp["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 1.0, 0.78, alpha))

func _draw_greenhouse_landmarks(font: Font) -> void:
	var beds: Array[Rect2] = [
		Rect2(-1080, -735, 290, 56),
		Rect2(-1080, -560, 250, 56),
		Rect2(-830, -535, 280, 56),
		Rect2(-1060, -370, 320, 52)
	]
	for bed in beds:
		draw_rect(bed, Color(0.24, 0.18, 0.13, 0.95), true)
		draw_rect(bed, Color(0.45, 0.68, 0.42, 0.85), false, 2.0)
		var leaf_x := bed.position.x + 22.0
		while leaf_x < bed.end.x - 16.0:
			draw_circle(Vector2(leaf_x, bed.position.y + 18.0), 8.5, Color(0.26, 0.72, 0.38, 0.9))
			draw_circle(Vector2(leaf_x + 6.0, bed.position.y + 36.0), 8.5, Color(0.34, 0.82, 0.45, 0.9))
			leaf_x += 32.0

	for gx in range(-1080, -520, 110):
		draw_line(Vector2(gx, -750), Vector2(gx + 50, -280), Color(0.55, 0.90, 0.68, 0.12), 3.0)
	draw_string(font, Vector2(-1075, -280), "HYDROPONIC CROP DOMES", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.52, 0.86, 0.60, 0.75))

func _draw_salvage_landmarks(font: Font) -> void:
	var rail_rect := Rect2(545, -735, 530, 390)
	draw_rect(rail_rect, Color(0.88, 0.62, 0.28, 0.25), false, 4.0)
	draw_line(Vector2(790, -735), Vector2(790, -345), Color(0.92, 0.68, 0.30, 0.35), 8.0)

	var heaps: Array[Vector2] = [Vector2(595, -670), Vector2(1035, -510), Vector2(835, -340)]
	for hp in heaps:
		draw_circle(hp, 38.0, Color(0.30, 0.24, 0.20, 0.95))
		draw_arc(hp, 38.0, 0.0, TAU, 16, Color(0.68, 0.50, 0.34, 0.85), 2.5)
		draw_circle(hp, 14.0, Color(0.18, 0.15, 0.13, 0.95))
		draw_arc(hp, 24.0, 0.4, 2.6, 10, Color(0.88, 0.64, 0.34, 0.75), 3.0)
	draw_string(font, Vector2(555, -280), "GANTRY BAY & COMPONENT YARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.90, 0.68, 0.42, 0.75))

func _draw_pump_station_landmarks(font: Font) -> void:
	var basin := Rect2(-560, 685, 620, 110)
	draw_rect(basin, Color(0.08, 0.24, 0.38, 0.95), true)
	draw_rect(basin, Color(0.36, 0.74, 0.96, 0.85), false, 2.5)
	for wx in range(-520, 20, 90):
		var wave_off := sin(anim_time * 2.2 + float(wx) * 0.02) * 6.0
		draw_line(Vector2(wx + wave_off, 720), Vector2(wx + 48 + wave_off, 720), Color(0.48, 0.85, 1.0, 0.45), 2.5)
		draw_line(Vector2(wx - wave_off, 760), Vector2(wx + 48 - wave_off, 760), Color(0.48, 0.85, 1.0, 0.35), 2.5)
	draw_string(font, Vector2(-540, 710), "AQUIFER INTAKE BASIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.62, 0.88, 1.0, 0.85))

func _draw_town_square_landmarks(font: Font) -> void:
	var ring_center := Vector2(0, 120)
	draw_circle(ring_center, 115.0, Color(0.20, 0.23, 0.28, 0.85))
	draw_arc(ring_center, 115.0, 0.0, TAU, 48, Color(0.55, 0.64, 0.76, 0.65), 2.5)
	for b in range(4):
		var a0 := float(b) * (PI * 0.5) + 0.28
		var a1 := float(b + 1) * (PI * 0.5) - 0.28
		draw_arc(ring_center, 86.0, a0, a1, 16, Color(0.52, 0.40, 0.28, 0.90), 8.0)
	draw_circle(ring_center, 22.0, Color(0.28, 0.33, 0.40, 0.95))
	draw_arc(ring_center, 22.0, 0.0, TAU, 24, Color(0.72, 0.80, 0.90, 0.8), 2.0)
	draw_string(font, ring_center + Vector2(-48, 106), "COUNCIL RING", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.78, 0.85, 0.92, 0.75))

	if game_manager != null and game_manager.current_phase == game_manager.Phase.COURT:
		var pulse: float = 0.5 + 0.5 * sin(anim_time * 3.5)
		var aura_col := Color(0.95, 0.82, 0.35, 0.22 + 0.14 * pulse)
		var edge_col := Color(1.0, 0.88, 0.45, 0.75 + 0.25 * pulse)
		draw_circle(ring_center, 34.0 + 4.0 * pulse, aura_col)
		draw_arc(ring_center, 36.0 + 4.0 * pulse, 0.0, TAU, 32, edge_col, 2.5)
		draw_string(font, ring_center + Vector2(-48, -32), "COURT PODIUM", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, edge_col)

func _draw_common_works_building(wr: Rect2, font: Font) -> void:
	var cw_pct: float = 0.0 if game_manager == null else float(game_manager.common_works)
	var cw_eco: float = 0.0 if game_manager == null else float(game_manager.common_works_eco)
	var cw_tech: float = 0.0 if game_manager == null else float(game_manager.common_works_tech)
	var cw_struct: float = 0.0 if game_manager == null else float(game_manager.common_works_struct)

	draw_rect(wr, Color(0.24, 0.21, 0.34, 1.0), true)
	draw_rect(Rect2(wr.position + Vector2(10, 8), Vector2(wr.size.x - 20, 22)), Color(0.32, 0.28, 0.46, 1.0), true)
	var border_col := Color(0.52, 0.96, 0.72, 1.0) if cw_pct >= 50.0 else Color(0.76, 0.62, 0.98, 1.0)
	draw_rect(wr, border_col, false, 3.0)
	draw_string(font, wr.position + Vector2(16, 44), "COMMON WORKS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.90, 1.0))

	if game_manager != null and game_manager.current_phase == game_manager.Phase.FINALE and game_manager.finale_route == C.FINALE_ROUTE_PEACE:
		var eco_rat: String = "[ECO: RATIFIED]" if game_manager.charter_eco_ratified else "[ECO: PENDING]"
		var tech_rat: String = "[TECH: RATIFIED]" if game_manager.charter_tech_ratified else "[TECH: PENDING]"
		draw_string(font, wr.position + Vector2(16, 62), "%s  %s" % [eco_rat, tech_rat], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.95, 0.98))
		if game_manager.holdout_active:
			draw_string(font, wr.position + Vector2(16, 78), "HOLDOUT: %.0fs • Integrity: %d%%" % [game_manager.holdout_timer, int(cw_pct)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.72, 1.0))
		else:
			draw_string(font, wr.position + Vector2(16, 78), "AWAITING RATIFICATION CONSOLES", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.85, 0.55))
	else:
		draw_string(font, wr.position + Vector2(16, 62), "Total: %d%% • %s" % [int(cw_pct), ("STAGE 1" if cw_pct >= 33.0 else "STAGE 0")], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.78, 0.98, 0.82))
		draw_string(font, wr.position + Vector2(16, 78), "E:%d%%  T:%d%%  S:%d%%" % [int(cw_eco), int(cw_tech), int(cw_struct)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.88, 0.95))

	var bar_bg := Rect2(wr.position.x + 16, wr.end.y - 16, wr.size.x - 32, 8)
	draw_rect(bar_bg, Color(0.12, 0.12, 0.16, 0.95), true)
	draw_rect(Rect2(bar_bg.position, Vector2(bar_bg.size.x * clampf(cw_pct / 100.0, 0.0, 1.0), 8)), border_col, true)

func _draw_buried_generator_hatch(wr: Rect2, font: Font) -> void:
	draw_rect(wr, Color(0.24, 0.17, 0.17, 1.0), true)
	var center := wr.position + wr.size * 0.5 + Vector2(0, 12)
	draw_circle(center, 26.0, Color(0.18, 0.13, 0.13, 1.0))
	draw_arc(center, 26.0, 0.0, TAU, 24, Color(0.88, 0.44, 0.38, 0.9), 2.5)
	draw_rect(wr, Color(0.88, 0.44, 0.38, 1.0), false, 3.0)
	draw_string(font, wr.position + Vector2(10, 26), "BURIED GENERATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.72, 0.66))

	var status_text: String = "SEALED HATCH"
	if game_manager != null:
		if game_manager.current_phase == game_manager.Phase.FINALE and game_manager.finale_route == C.FINALE_ROUTE_CONFRONTATION:
			var tug: float = game_manager.generator_tug_meter
			status_text = "TUG-OF-WAR: %.0f%%" % tug
			var bar_r := Rect2(wr.position.x + 12, wr.position.y + 40, wr.size.x - 24, 12)
			draw_rect(bar_r, Color(0.10, 0.10, 0.14, 0.95), true)
			var fill_w: float = bar_r.size.x * clampf(tug / 100.0, 0.0, 1.0)
			draw_rect(Rect2(bar_r.position, Vector2(fill_w, bar_r.size.y)), Color(0.38, 0.82, 0.98), true)
			draw_line(Vector2(bar_r.position.x + bar_r.size.x * 0.5, bar_r.position.y - 2), Vector2(bar_r.position.x + bar_r.size.x * 0.5, bar_r.end.y + 2), Color(1.0, 1.0, 1.0, 0.9), 2.0)
			draw_rect(bar_r, Color(0.88, 0.55, 0.45), false, 1.5)
		else:
			var gen_t: int = int(game_manager.generator_tech_primed)
			var gen_e: int = int(game_manager.generator_eco_stabilized)
			if gen_t > 0 or gen_e > 0:
				status_text = "E:%d%% | T:%d%%" % [gen_e, gen_t]
			elif game_manager.current_phase >= game_manager.Phase.ESCALATION:
				status_text = "UNSEALED [ACTIVE]"
	draw_string(font, wr.position + Vector2(18, 98), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.92, 0.78, 0.72))

func _draw_signpost(pos: Vector2, title: String, sub: String, col: Color, font: Font) -> void:
	var sign_rect := Rect2(pos, Vector2(168, 42))
	draw_rect(sign_rect, Color(0.11, 0.13, 0.17, 0.92), true)
	draw_rect(sign_rect, col.darkened(0.15), false, 2.0)
	draw_string(font, pos + Vector2(10, 18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col.lightened(0.25))
	draw_string(font, pos + Vector2(10, 34), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.82, 0.86, 0.92, 0.9))

func _draw_archive_caches(font: Font) -> void:
	for spawn in C.ARCHIVE_CACHE_SPAWNS:
		var pos: Vector2 = spawn["pos"]
		var is_active: bool = (game_manager != null and game_manager.archive_active_spawn_id == String(spawn["id"]))
		var is_opened: bool = (game_manager != null and game_manager.archive_opened)

		# Stone alcove floor recess
		draw_rect(Rect2(pos - Vector2(26, 26), Vector2(52, 52)), Color(0.13, 0.15, 0.18, 0.95), true)
		draw_rect(Rect2(pos - Vector2(26, 26), Vector2(52, 52)), Color(0.38, 0.44, 0.52, 0.85), false, 2.0)

		if is_active and is_opened:
			# Opened container with broken seals (only drawn once unsealed)
			draw_rect(Rect2(pos - Vector2(16, 12), Vector2(32, 24)), Color(0.24, 0.20, 0.16, 0.95), true)
			draw_rect(Rect2(pos - Vector2(16, 12), Vector2(32, 24)), Color(0.85, 0.72, 0.38, 0.95), false, 2.0)
			draw_line(pos + Vector2(-16, -12), pos + Vector2(-22, -20), Color(0.85, 0.72, 0.38), 2.5)
			draw_string(font, pos + Vector2(-70, -34), "ARCHIVE (OPENED)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.92, 0.82, 0.45))
		else:
			# Sealed alcove - all 4 alcoves look identical so the active cache is not visually leaked
			draw_circle(pos, 6.0, Color(0.25, 0.28, 0.34, 0.85))
			draw_string(font, pos + Vector2(-42, -34), "ALCOVE [V]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.50, 0.55, 0.62, 0.65))

func _draw_task_station(pad: Dictionary, font: Font) -> void:
	if pad["task_type"] == "ratify_eco" or pad["task_type"] == "ratify_tech":
		if game_manager == null or game_manager.current_phase != game_manager.Phase.FINALE or game_manager.finale_route != C.FINALE_ROUTE_PEACE:
			return

	var pos: Vector2 = pad["pos"]
	var base_col: Color = pad["color"]
	var on_cd: bool = pad["cooldown"] > 0.0
	var is_jammed: bool = pad["jammed_timer"] > 0.0
	var is_overclocked: bool = bool(pad["overclocked"])
	var is_busy: bool = pad["active_user"] != null
	var can_do: bool = true if game_manager == null else game_manager.can_perform_task(pad["task_type"])

	# 1. Physical Console Fixture beside the pad
	var console_pos: Vector2 = pos + pad["console_offset"]
	var console_rect := Rect2(console_pos - Vector2(24, 16), Vector2(48, 32))
	draw_rect(console_rect, Color(0.20, 0.23, 0.28, 0.98), true)
	draw_rect(console_rect, base_col.darkened(0.1), false, 2.2)
	var lamp_col := Color(1.0, 0.35, 0.30) if is_jammed else (Color(0.45, 0.48, 0.52) if on_cd else (Color(1.0, 0.90, 0.35) if is_busy else (base_col if can_do else Color(0.95, 0.45, 0.35))))
	draw_circle(console_pos, 6.0, lamp_col)
	draw_line(pos, console_pos, base_col * Color(1, 1, 1, 0.45), 3.0)

	# 2. Floor Pad Circle & State Ring
	var fill_col := Color(0.24, 0.11, 0.12, 0.92) if is_jammed else (Color(0.15, 0.16, 0.19, 0.90) if (on_cd or not can_do) else Color(base_col.r * 0.24, base_col.g * 0.24, base_col.b * 0.24, 0.90))
	var ring_col := Color(1.0, 0.38, 0.32, 0.95) if is_jammed else (Color(0.45, 0.48, 0.52, 0.75) if on_cd else (Color(1.0, 0.92, 0.42, 1.0) if is_busy else (base_col if can_do else Color(0.92, 0.48, 0.36, 0.85))))

	draw_circle(pos, 46.0, fill_col)
	draw_arc(pos, 46.0, 0.0, TAU, 36, ring_col, 3.5)

	if is_overclocked:
		draw_arc(pos, 53.0, 0.0, TAU, 36, Color(0.42, 0.96, 1.0, 0.9), 2.5)

	if is_jammed:
		var j_ang := anim_time * 8.0
		draw_arc(pos, 51.0, j_ang, j_ang + 1.4, 12, Color(1.0, 0.45, 0.32, 0.95), 3.0)
		draw_arc(pos, 51.0, j_ang + PI, j_ang + PI + 1.4, 12, Color(1.0, 0.45, 0.32, 0.95), 3.0)
	elif not on_cd and can_do and not is_busy:
		var pulse_r := 50.0 + sin(anim_time * 3.2) * 3.5
		draw_arc(pos, pulse_r, 0.0, TAU, 36, Color(base_col.r, base_col.g, base_col.b, 0.32), 2.0)
	elif is_busy:
		var rot := anim_time * 4.0
		draw_arc(pos, 52.0, rot, rot + PI * 0.8, 20, Color(1.0, 0.92, 0.42, 0.95), 3.5)
		draw_arc(pos, 52.0, rot + PI, rot + PI * 1.8, 20, Color(1.0, 0.92, 0.42, 0.95), 3.5)

	# 3. Distinct Vector Icon inside the Pad
	var icon_col := ring_col.lightened(0.25)
	_draw_station_icon(pos, pad["task_type"], icon_col)

	# 4. State Text & Cooldown Sweep + Clean Overhead Banner
	var status_tag := "READY [E]"
	var status_col := ring_col.lightened(0.35)
	if is_jammed:
		status_tag = "JAMMED %.1fs" % pad["jammed_timer"]
		status_col = Color(1.0, 0.52, 0.45)
	elif on_cd:
		var pad_cd: float = float(pad.get("channel_duration", PAD_COOLDOWN))
		var ratio: float = clampf(1.0 - (pad["cooldown"] / PAD_COOLDOWN), 0.0, 1.0)
		draw_arc(pos, 40.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 32, base_col, 4.5)
		status_tag = "WAIT %.1fs" % pad["cooldown"]
		status_col = Color(0.90, 0.92, 0.95)
	elif is_busy:
		status_tag = "WORKING"
		status_col = Color(1.0, 0.94, 0.55)
	elif not can_do:
		if pad["task_type"] == "ratify_eco":
			status_tag = "RATIFIED" if (game_manager != null and game_manager.charter_eco_ratified) else "LOCKED (Eco)"
			status_col = Color(0.45, 0.95, 0.62) if (game_manager != null and game_manager.charter_eco_ratified) else Color(0.70, 0.70, 0.75)
		elif pad["task_type"] == "ratify_tech":
			status_tag = "RATIFIED" if (game_manager != null and game_manager.charter_tech_ratified) else "LOCKED (Tech)"
			status_col = Color(0.42, 0.82, 0.98) if (game_manager != null and game_manager.charter_tech_ratified) else Color(0.70, 0.70, 0.75)
		elif (pad["task_type"] == "generator_objective" or pad["task_type"] == "beacon_objective"):
			status_tag = "LOCKED (Escalation)"
			status_col = Color(0.88, 0.65, 0.52)
		elif pad["task_type"] == "cw_eco":
			status_tag = "NEEDS WATER"
			status_col = Color(0.98, 0.65, 0.50)
		elif pad["task_type"] == "cw_tech":
			status_tag = "NEEDS SCRAP"
			status_col = Color(0.98, 0.65, 0.50)
		else:
			status_tag = "COMPLETE" if (game_manager != null and game_manager.common_works >= 99.9) else "NEEDS RESOURCE"
			status_col = Color(0.98, 0.65, 0.50)
	elif is_overclocked:
		status_tag = "OVERCLOCK +50%"
		status_col = Color(0.48, 0.98, 1.0)

	var lbl_w := 204.0
	var lbl_rect := Rect2(pos.x - lbl_w * 0.5, pos.y - 86, lbl_w, 34)
	draw_rect(lbl_rect, Color(0.08, 0.10, 0.13, 0.90), true)
	draw_rect(lbl_rect, ring_col * Color(1, 1, 1, 0.60), false, 1.2)
	draw_string(font, lbl_rect.position + Vector2(8, 14), pad["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.97, 1.0))
	draw_string(font, lbl_rect.position + Vector2(8, 28), "%s  •  %s" % [pad["effect_tag"], status_tag], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, status_col)

func _draw_station_icon(center: Vector2, task_type: String, col: Color) -> void:
	match task_type:
		"pump":
			var pts := PackedVector2Array([
				center + Vector2(0, -14),
				center + Vector2(10, 2),
				center + Vector2(6, 11),
				center + Vector2(-6, 11),
				center + Vector2(-10, 2)
			])
			draw_colored_polygon(pts, col)
		"greenhouse":
			draw_line(center + Vector2(0, 12), center + Vector2(0, -10), col, 2.5)
			draw_circle(center + Vector2(-7, -2), 6.5, col)
			draw_circle(center + Vector2(7, -5), 6.5, col)
		"salvage":
			draw_arc(center, 9.0, 0.0, TAU, 16, col, 3.0)
			for i in range(6):
				var a := float(i) * (TAU / 6.0)
				var v := Vector2(cos(a), sin(a))
				draw_line(center + v * 8.0, center + v * 14.0, col, 3.0)
		"cw_eco":
			draw_circle(center, 9.0, col * Color(1, 1, 1, 0.35))
			draw_arc(center, 9.0, 0.0, TAU, 16, col, 2.5)
			draw_line(center + Vector2(0, 7), center + Vector2(0, -6), col, 2.5)
			draw_circle(center + Vector2(-4, -2), 4.5, col)
			draw_circle(center + Vector2(4, -4), 4.5, col)
		"cw_tech":
			draw_arc(center, 8.0, 0.0, TAU, 16, col, 2.5)
			for i in range(4):
				var a := float(i) * (TAU / 4.0)
				var v := Vector2(cos(a), sin(a))
				draw_line(center + v * 6.0, center + v * 12.0, col, 2.5)
		"cw_struct":
			draw_rect(Rect2(center + Vector2(-9, -9), Vector2(18, 18)), col, false, 2.2)
			draw_line(center + Vector2(-9, -9), center + Vector2(9, 9), col, 2.0)
			draw_line(center + Vector2(-9, 9), center + Vector2(9, -9), col, 2.0)
		"generator_objective":
			draw_circle(center, 10.0, col * Color(1, 1, 1, 0.35))
			draw_arc(center, 10.0, 0.0, TAU, 20, col, 2.5)
			draw_line(center + Vector2(-6, -4), center + Vector2(1, -1), col, 3.0)
			draw_line(center + Vector2(1, -1), center + Vector2(-2, 2), col, 3.0)
			draw_line(center + Vector2(-2, 2), center + Vector2(6, 6), col, 3.0)
		"beacon_objective":
			draw_line(center + Vector2(0, 10), center + Vector2(0, -10), col, 3.0)
			draw_arc(center + Vector2(0, -8), 7.0, -PI * 0.75, -PI * 0.25, 10, col, 2.5)
			draw_arc(center + Vector2(0, -8), 12.0, -PI * 0.75, -PI * 0.25, 12, col, 2.0)
		"ratify_eco", "ratify_tech":
			draw_circle(center, 9.0, col * Color(1, 1, 1, 0.35))
			draw_arc(center, 9.0, 0.0, TAU, 16, col, 2.0)
			draw_line(center + Vector2(-5, 4), center + Vector2(5, -4), col, 2.5)
			draw_line(center + Vector2(5, -4), center + Vector2(2, -6), col, 2.0)
		"hazard_clear":
			draw_circle(center, 10.0, col * Color(1, 1, 1, 0.35))
			draw_arc(center, 10.0, 0.0, TAU, 16, col, 2.5)
			draw_line(center + Vector2(-6, -6), center + Vector2(6, 6), col, 2.5)
			draw_line(center + Vector2(-6, 6), center + Vector2(6, -6), col, 2.5)
		"common_works":
			draw_rect(Rect2(center + Vector2(-11, -8), Vector2(5, 18)), col, true)
			draw_rect(Rect2(center + Vector2(6, -8), Vector2(5, 18)), col, true)
			var dia := PackedVector2Array([
				center + Vector2(0, -12),
				center + Vector2(7, -3),
				center + Vector2(0, 6),
				center + Vector2(-7, -3)
			])
			draw_colored_polygon(dia, col)

func _draw_holdout_hazards(font: Font) -> void:
	if game_manager == null or not game_manager.holdout_active:
		return
	for h in game_manager.active_hazards:
		var pos: Vector2 = Vector2(h["pos"])
		var kind: String = String(h["kind"])
		var label: String = String(h["label"])
		var pulse: float = 0.5 + 0.5 * sin(anim_time * 6.0)

		if kind == "blight":
			var b_col := Color(0.95, 0.38, 0.28, 0.35 + 0.25 * pulse)
			draw_circle(pos, 36.0, b_col)
			draw_arc(pos, 36.0, 0.0, TAU, 28, Color(1.0, 0.45, 0.35, 0.95), 3.0)
			for i in range(5):
				var a := float(i) * (TAU / 5.0) + anim_time * 2.0
				draw_line(pos, pos + Vector2(cos(a), sin(a)) * 26.0, Color(0.95, 0.30, 0.20, 0.85), 2.5)
			_draw_station_icon(pos, "hazard_clear", Color(1.0, 0.85, 0.40))
		else:
			var s_col := Color(0.65, 0.88, 1.0, 0.30 + 0.25 * pulse)
			draw_circle(pos, 36.0, s_col)
			draw_arc(pos, 36.0, 0.0, TAU, 28, Color(0.75, 0.95, 1.0, 0.95), 3.0)
			for i in range(4):
				var a := float(i) * (TAU / 4.0) - anim_time * 2.5
				draw_arc(pos + Vector2(cos(a), sin(a)) * 12.0, 14.0, a, a + PI * 0.8, 10, Color(0.85, 0.95, 1.0, 0.6), 2.0)
			_draw_station_icon(pos, "hazard_clear", Color(0.80, 0.95, 1.0))

		var tag_rect := Rect2(pos.x - 105, pos.y - 68, 210, 30)
		draw_rect(tag_rect, Color(0.12, 0.08, 0.10, 0.92), true)
		draw_rect(tag_rect, Color(1.0, 0.45, 0.35, 0.85), false, 1.5)
		draw_string(font, tag_rect.position + Vector2(8, 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.90, 0.85))
		var sub_txt: String = "STABILITY DRAIN x3 [E to Clear]" if kind == "blight" else "WATER DRAIN x3 [E to Clear]"
		draw_string(font, tag_rect.position + Vector2(8, 26), sub_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.60, 0.45))
