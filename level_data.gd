extends RefCounted

const LEVELS_DIR := "res://levels"

# Catalogo base para niveles rapidos o fallback local.
const BUILTIN_LEVELS := {
	"demo_facility": {
		"id": "demo_facility",
		"screen_width": 640.0,
		"screen_height": 360.0,
		"floor_height": 40.0,
		"matrix": [
			[
				{
					"id": "dock_start",
					"floor": true,
					"player_spawn": Vector2(100, 280),
					"platforms": [
						{
							"position": Vector2(280, 240),
							"size": Vector2(160, 20),
							"color": Color(0.48, 0.38, 0.28, 1.0)
						}
					]
				},
				{
					"id": "hall_a",
					"floor": true,
					"platforms": [
						{
							"position": Vector2(180, 250),
							"size": Vector2(120, 20),
							"color": Color(0.46, 0.36, 0.27, 1.0)
						}
					]
				},
				{
					"id": "terminal_room",
					"floor": true,
					"terminal_spawn": Vector2(150, 300),
					"platforms": [
						{
							"position": Vector2(460, 220),
							"size": Vector2(140, 20),
							"color": Color(0.46, 0.36, 0.27, 1.0)
						}
					]
				},
				{
					"id": "hall_b",
					"floor": true,
					"platforms": [
						{
							"position": Vector2(170, 235),
							"size": Vector2(150, 20),
							"color": Color(0.44, 0.35, 0.26, 1.0)
						}
					]
				},
				{
					"id": "guard_post",
					"floor": true,
					"guard_spawn": Vector2(390, 180),
					"exit_spawn": Vector2(540, 292),
					"platforms": [
						{
							"position": Vector2(390, 240),
							"size": Vector2(160, 20),
							"color": Color(0.44, 0.34, 0.25, 1.0)
						}
					]
				}
			]
		]
	},
	"training_grid": {
		"id": "training_grid",
		"screen_width": 640.0,
		"screen_height": 360.0,
		"floor_height": 40.0,
		"matrix": [
			[
				{
					"id": "upper_start",
					"floor": true,
					"player_spawn": Vector2(120, 280),
					"platforms": [
						{
							"position": Vector2(420, 220),
							"size": Vector2(150, 20),
							"color": Color(0.48, 0.38, 0.28, 1.0)
						}
					]
				},
				null,
				{
					"id": "upper_terminal",
					"floor": true,
					"terminal_spawn": Vector2(500, 300)
				}
			],
			[
				{
					"id": "lower_guard",
					"floor": true,
					"guard_spawn": Vector2(300, 280)
				},
				{
					"id": "lower_bridge",
					"floor": true,
					"platforms": [
						{
							"position": Vector2(320, 200),
							"size": Vector2(220, 20),
							"color": Color(0.44, 0.35, 0.26, 1.0)
						}
					]
				},
				{
					"id": "lower_exit",
					"floor": true,
					"exit_spawn": Vector2(520, 292)
				}
			]
		]
	}
}

static func get_level(level_id: String) -> Dictionary:
	var external_level := _load_external_level(level_id)
	if not external_level.is_empty():
		return external_level

	if BUILTIN_LEVELS.has(level_id):
		return BUILTIN_LEVELS[level_id].duplicate(true)

	var fallback_level := _load_external_level("facility_branching")
	if not fallback_level.is_empty():
		return fallback_level

	return BUILTIN_LEVELS["demo_facility"].duplicate(true)

static func _load_external_level(level_id: String) -> Dictionary:
	var file_path := "%s/%s.json" % [LEVELS_DIR, level_id]
	if not FileAccess.file_exists(file_path):
		return {}

	var raw_text := FileAccess.get_file_as_string(file_path)
	var json := JSON.new()
	if json.parse(raw_text) != OK:
		push_warning("Could not parse level file: %s" % file_path)
		return {}

	if typeof(json.data) != TYPE_DICTIONARY:
		push_warning("Level file must contain a dictionary: %s" % file_path)
		return {}

	return _normalize_level(json.data, level_id)

static func _normalize_level(raw_level: Dictionary, fallback_id: String) -> Dictionary:
	var normalized_level := {
		"id": str(raw_level.get("id", fallback_id)),
		"screen_width": float(raw_level.get("screen_width", 640.0)),
		"screen_height": float(raw_level.get("screen_height", 360.0)),
		"floor_height": float(raw_level.get("floor_height", 40.0))
	}

	var raw_templates: Dictionary = raw_level.get("templates", {})
	var resolved_templates := {}
	for template_id in raw_templates.keys():
		resolved_templates[template_id] = _resolve_template(raw_templates[template_id], raw_templates, [])

	normalized_level["matrix"] = _normalize_matrix(raw_level.get("matrix", []), resolved_templates)
	return normalized_level

static func _normalize_matrix(raw_matrix: Array, templates: Dictionary) -> Array:
	var normalized_matrix: Array = []

	for raw_row in raw_matrix:
		if typeof(raw_row) != TYPE_ARRAY:
			continue

		var normalized_row: Array = []
		for raw_cell in raw_row:
			if raw_cell == null:
				normalized_row.append(null)
				continue

			if typeof(raw_cell) != TYPE_DICTIONARY:
				continue

			var resolved_cell = _apply_template(raw_cell, templates)
			normalized_row.append(_normalize_cell(resolved_cell))
		normalized_matrix.append(normalized_row)

	return normalized_matrix

static func _resolve_template(raw_template: Dictionary, raw_templates: Dictionary, chain: Array) -> Dictionary:
	var template_copy: Dictionary = raw_template.duplicate(true)
	var template_id := str(template_copy.get("template", ""))
	if template_id == "":
		template_copy.erase("template")
		return template_copy

	if chain.has(template_id):
		push_warning("Template recursion detected for: %s" % template_id)
		template_copy.erase("template")
		return template_copy

	var parent_template: Dictionary = raw_templates.get(template_id, {})
	var resolved_parent := _resolve_template(parent_template, raw_templates, chain + [template_id])
	return _deep_merge(resolved_parent, template_copy)

static func _apply_template(raw_cell: Dictionary, templates: Dictionary) -> Dictionary:
	var template_id := str(raw_cell.get("template", ""))
	if template_id == "":
		return raw_cell.duplicate(true)

	var template_cell: Dictionary = templates.get(template_id, {})
	return _deep_merge(template_cell, raw_cell)

static func _deep_merge(base_data: Dictionary, override_data: Dictionary) -> Dictionary:
	var result: Dictionary = base_data.duplicate(true)
	for key in override_data.keys():
		var override_value = override_data[key]
		if result.has(key) and typeof(result[key]) == TYPE_DICTIONARY and typeof(override_value) == TYPE_DICTIONARY:
			result[key] = _deep_merge(result[key], override_value)
		else:
			result[key] = override_value

	result.erase("template")
	return result

static func _normalize_cell(raw_cell: Dictionary) -> Dictionary:
	var cell: Dictionary = raw_cell.duplicate(true)
	cell["id"] = str(cell.get("id", "cell"))
	cell["floor"] = bool(cell.get("floor", true))

	for spawn_key in ["player_spawn", "guard_spawn", "terminal_spawn", "exit_spawn"]:
		if cell.has(spawn_key):
			cell[spawn_key] = _as_vector2(cell[spawn_key])

	cell["platforms"] = _normalize_platforms(cell.get("platforms", []))
	cell["doors"] = _normalize_doors(cell.get("doors", []))
	cell["switches"] = _normalize_switches(cell.get("switches", []))
	cell["cameras"] = _normalize_cameras(cell.get("cameras", []))
	cell["elevators"] = _normalize_elevators(cell.get("elevators", []))
	return cell

static func _normalize_platforms(raw_platforms: Array) -> Array:
	var normalized: Array = []
	for raw_platform in raw_platforms:
		if typeof(raw_platform) != TYPE_DICTIONARY:
			continue
		normalized.append({
			"position": _as_vector2(raw_platform.get("position", Vector2.ZERO)),
			"size": _as_vector2(raw_platform.get("size", Vector2(160, 20))),
			"color": _as_color(raw_platform.get("color", Color(0.5, 0.4, 0.3, 1.0)))
		})
	return normalized

static func _normalize_doors(raw_doors: Array) -> Array:
	var normalized: Array = []
	for raw_door in raw_doors:
		if typeof(raw_door) != TYPE_DICTIONARY:
			continue
		normalized.append({
			"id": str(raw_door.get("id", "door")),
			"position": _as_vector2(raw_door.get("position", Vector2.ZERO)),
			"size": _as_vector2(raw_door.get("size", Vector2(28, 96))),
			"open": bool(raw_door.get("open", false)),
			"color": _as_color(raw_door.get("color", Color(0.35, 0.42, 0.6, 1.0)))
		})
	return normalized

static func _normalize_switches(raw_switches: Array) -> Array:
	var normalized: Array = []
	for raw_switch in raw_switches:
		if typeof(raw_switch) != TYPE_DICTIONARY:
			continue
		normalized.append({
			"id": str(raw_switch.get("id", "switch")),
			"position": _as_vector2(raw_switch.get("position", Vector2.ZERO)),
			"size": _as_vector2(raw_switch.get("size", Vector2(36, 48))),
			"prompt": str(raw_switch.get("prompt", "Press E to toggle")),
			"unlock_doors": _as_string_array(raw_switch.get("unlock_doors", [])),
			"disable_cameras": _as_string_array(raw_switch.get("disable_cameras", []))
		})
	return normalized

static func _normalize_cameras(raw_cameras: Array) -> Array:
	var normalized: Array = []
	for raw_camera in raw_cameras:
		if typeof(raw_camera) != TYPE_DICTIONARY:
			continue
		normalized.append({
			"id": str(raw_camera.get("id", "camera")),
			"position": _as_vector2(raw_camera.get("position", Vector2.ZERO)),
			"size": _as_vector2(raw_camera.get("size", Vector2(220, 140))),
			"color": _as_color(raw_camera.get("color", Color(0.3, 0.85, 1.0, 0.12)))
		})
	return normalized

static func _normalize_elevators(raw_elevators: Array) -> Array:
	var normalized: Array = []
	for raw_elevator in raw_elevators:
		if typeof(raw_elevator) != TYPE_DICTIONARY:
			continue
		normalized.append({
			"id": str(raw_elevator.get("id", "elevator")),
			"position": _as_vector2(raw_elevator.get("position", Vector2.ZERO)),
			"size": _as_vector2(raw_elevator.get("size", Vector2(72, 84))),
			"target_cell": _as_vector2i(raw_elevator.get("target_cell", Vector2i.ZERO)),
			"target_position": _as_vector2(raw_elevator.get("target_position", Vector2.ZERO)),
			"prompt": str(raw_elevator.get("prompt", "Press E to ride"))
		})
	return normalized

static func _as_string_array(raw_value) -> Array:
	var result: Array = []
	if typeof(raw_value) != TYPE_ARRAY:
		return result

	for entry in raw_value:
		result.append(str(entry))
	return result

static func _as_vector2(raw_value) -> Vector2:
	if raw_value is Vector2:
		return raw_value
	if typeof(raw_value) == TYPE_ARRAY and raw_value.size() >= 2:
		return Vector2(float(raw_value[0]), float(raw_value[1]))
	if typeof(raw_value) == TYPE_DICTIONARY:
		return Vector2(float(raw_value.get("x", 0.0)), float(raw_value.get("y", 0.0)))
	return Vector2.ZERO

static func _as_vector2i(raw_value) -> Vector2i:
	if raw_value is Vector2i:
		return raw_value
	if typeof(raw_value) == TYPE_ARRAY and raw_value.size() >= 2:
		return Vector2i(int(raw_value[0]), int(raw_value[1]))
	if typeof(raw_value) == TYPE_DICTIONARY:
		return Vector2i(int(raw_value.get("x", 0)), int(raw_value.get("y", 0)))
	return Vector2i.ZERO

static func _as_color(raw_value) -> Color:
	if raw_value is Color:
		return raw_value
	if typeof(raw_value) == TYPE_ARRAY and raw_value.size() >= 3:
		var alpha := 1.0
		if raw_value.size() >= 4:
			alpha = float(raw_value[3])
		return Color(float(raw_value[0]), float(raw_value[1]), float(raw_value[2]), alpha)
	if typeof(raw_value) == TYPE_DICTIONARY:
		return Color(
			float(raw_value.get("r", 0.0)),
			float(raw_value.get("g", 0.0)),
			float(raw_value.get("b", 0.0)),
			float(raw_value.get("a", 1.0))
		)
	return Color(1.0, 1.0, 1.0, 1.0)
