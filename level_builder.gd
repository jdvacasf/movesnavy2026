extends RefCounted

func build(level_root: Node2D, level_data: Dictionary) -> Dictionary:
	# Limpiamos el nivel anterior para reconstruir todo desde la matriz.
	_clear_level_root(level_root)

	var matrix: Array = level_data.get("matrix", [])
	var screen_width: float = level_data.get("screen_width", 640.0)
	var screen_height: float = level_data.get("screen_height", 360.0)
	var floor_height: float = level_data.get("floor_height", 40.0)
	var world_columns := 0
	var world_rows := matrix.size()
	var player_spawn := Vector2.ZERO
	var guard_spawn := Vector2.ZERO
	var terminal_spawn := Vector2.ZERO
	var exit_spawn := Vector2.ZERO
	var has_player_spawn := false
	var has_guard_spawn := false
	var has_terminal_spawn := false
	var has_exit_spawn := false
	var cell_nodes := {}
	var doors: Array = []
	var switches: Array = []
	var cameras: Array = []
	var elevators: Array = []

	for row_index in range(matrix.size()):
		var row: Array = matrix[row_index]
		world_columns = maxi(world_columns, row.size())

		for col_index in range(row.size()):
			var cell = row[col_index]
			if cell == null:
				continue

			world_columns = maxi(world_columns, col_index + 1)
			var cell_origin = Vector2(col_index * screen_width, row_index * screen_height)
			var cell_root = _create_cell(level_root, cell, cell_origin, col_index, row_index, screen_width, screen_height, floor_height, doors, switches, cameras, elevators)
			cell_nodes[_cell_key(col_index, row_index)] = cell_root

			if cell.has("player_spawn"):
				player_spawn = cell_origin + cell["player_spawn"]
				has_player_spawn = true

			if cell.has("guard_spawn"):
				guard_spawn = cell_origin + cell["guard_spawn"]
				has_guard_spawn = true

			if cell.has("terminal_spawn"):
				terminal_spawn = cell_origin + cell["terminal_spawn"]
				has_terminal_spawn = true

			if cell.has("exit_spawn"):
				exit_spawn = cell_origin + cell["exit_spawn"]
				has_exit_spawn = true

	return {
		"columns": world_columns,
		"rows": world_rows,
		"player_spawn": player_spawn,
		"guard_spawn": guard_spawn,
		"terminal_spawn": terminal_spawn,
		"exit_spawn": exit_spawn,
		"has_player_spawn": has_player_spawn,
		"has_guard_spawn": has_guard_spawn,
		"has_terminal_spawn": has_terminal_spawn,
		"has_exit_spawn": has_exit_spawn,
		"cell_nodes": cell_nodes,
		"doors": doors,
		"switches": switches,
		"cameras": cameras,
		"elevators": elevators
	}

func _create_cell(level_root: Node2D, cell: Dictionary, cell_origin: Vector2, col_index: int, row_index: int, screen_width: float, screen_height: float, floor_height: float, doors: Array, switches: Array, cameras: Array, elevators: Array) -> Node2D:
	var cell_root = Node2D.new()
	cell_root.name = "%s_%d_%d" % [str(cell.get("id", "cell")), col_index, row_index]
	cell_root.position = cell_origin
	level_root.add_child(cell_root)

	if cell.get("floor", true):
		_add_floor(cell_root, screen_width, screen_height, floor_height)

	for platform_def in cell.get("platforms", []):
		_add_platform(cell_root, platform_def)

	for door_def in cell.get("doors", []):
		doors.append(_add_door(cell_root, door_def))

	for switch_def in cell.get("switches", []):
		switches.append(_add_switch(cell_root, switch_def))

	for camera_def in cell.get("cameras", []):
		cameras.append(_add_camera(cell_root, camera_def))

	for elevator_def in cell.get("elevators", []):
		elevators.append(_add_elevator(cell_root, elevator_def, screen_width, screen_height))

	return cell_root

func _add_floor(cell_root: Node2D, screen_width: float, screen_height: float, floor_height: float):
	var floor = StaticBody2D.new()
	floor.name = "Ground"
	floor.collision_layer = 2
	floor.collision_mask = 0
	floor.position = Vector2(screen_width * 0.5, screen_height - floor_height * 0.5)
	cell_root.add_child(floor)

	var collision_shape = CollisionShape2D.new()
	var floor_shape = RectangleShape2D.new()
	floor_shape.size = Vector2(screen_width, floor_height)
	collision_shape.shape = floor_shape
	floor.add_child(collision_shape)

	var visual = ColorRect.new()
	visual.offset_left = -screen_width * 0.5
	visual.offset_top = -floor_height * 0.5
	visual.offset_right = screen_width * 0.5
	visual.offset_bottom = floor_height * 0.5
	visual.color = Color(0.4, 0.3, 0.2, 1.0)
	floor.add_child(visual)

func _add_platform(cell_root: Node2D, platform_def: Dictionary):
	var platform_size: Vector2 = platform_def.get("size", Vector2(160, 20))
	var platform_position: Vector2 = platform_def.get("position", Vector2.ZERO)
	var platform_color: Color = platform_def.get("color", Color(0.5, 0.4, 0.3, 1.0))

	var platform = StaticBody2D.new()
	platform.name = "Platform"
	platform.collision_layer = 2
	platform.collision_mask = 0
	platform.position = platform_position
	cell_root.add_child(platform)

	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = platform_size
	collision_shape.shape = shape
	platform.add_child(collision_shape)

	var visual = ColorRect.new()
	visual.offset_left = -platform_size.x * 0.5
	visual.offset_top = -platform_size.y * 0.5
	visual.offset_right = platform_size.x * 0.5
	visual.offset_bottom = platform_size.y * 0.5
	visual.color = platform_color
	platform.add_child(visual)

func _add_door(cell_root: Node2D, door_def: Dictionary) -> Dictionary:
	var door_size: Vector2 = door_def.get("size", Vector2(28, 96))
	var door_position: Vector2 = door_def.get("position", Vector2.ZERO)
	var door_color: Color = door_def.get("color", Color(0.35, 0.42, 0.6, 1.0))
	var is_open: bool = door_def.get("open", false)

	var door_root = Node2D.new()
	door_root.name = "Door_%s" % str(door_def.get("id", "door"))
	door_root.position = door_position
	cell_root.add_child(door_root)

	var body = StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	door_root.add_child(body)

	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = door_size
	collision_shape.shape = shape
	collision_shape.disabled = is_open
	body.add_child(collision_shape)

	var visual = ColorRect.new()
	visual.offset_left = -door_size.x * 0.5
	visual.offset_top = -door_size.y * 0.5
	visual.offset_right = door_size.x * 0.5
	visual.offset_bottom = door_size.y * 0.5
	visual.color = Color(0.2, 0.8, 0.3, 0.85) if is_open else door_color
	body.add_child(visual)

	return {
		"id": str(door_def.get("id", "door")),
		"node": door_root,
		"collision_shape": collision_shape,
		"visual": visual,
		"open": is_open
	}

func _add_switch(cell_root: Node2D, switch_def: Dictionary) -> Dictionary:
	var switch_size: Vector2 = switch_def.get("size", Vector2(36, 48))
	var switch_position: Vector2 = switch_def.get("position", Vector2.ZERO)

	var switch_node = Area2D.new()
	switch_node.name = "Switch_%s" % str(switch_def.get("id", "switch"))
	switch_node.position = switch_position
	switch_node.collision_layer = 0
	switch_node.collision_mask = 1
	cell_root.add_child(switch_node)

	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = switch_size
	collision_shape.shape = shape
	switch_node.add_child(collision_shape)

	var visual = ColorRect.new()
	visual.offset_left = -switch_size.x * 0.5
	visual.offset_top = -switch_size.y * 0.5
	visual.offset_right = switch_size.x * 0.5
	visual.offset_bottom = switch_size.y * 0.5
	visual.color = Color(0.9, 0.75, 0.2, 0.95)
	switch_node.add_child(visual)

	var prompt = Label.new()
	prompt.visible = false
	prompt.offset_left = -110.0
	prompt.offset_top = -56.0
	prompt.offset_right = 110.0
	prompt.offset_bottom = -28.0
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.text = str(switch_def.get("prompt", "Press E to toggle"))
	switch_node.add_child(prompt)

	return {
		"id": str(switch_def.get("id", "switch")),
		"node": switch_node,
		"prompt_label": prompt,
		"visual": visual,
		"unlock_doors": switch_def.get("unlock_doors", []).duplicate(),
		"disable_cameras": switch_def.get("disable_cameras", []).duplicate(),
		"activated": false
	}

func _add_camera(cell_root: Node2D, camera_def: Dictionary) -> Dictionary:
	var camera_size: Vector2 = camera_def.get("size", Vector2(220, 140))
	var camera_position: Vector2 = camera_def.get("position", Vector2.ZERO)
	var camera_color: Color = camera_def.get("color", Color(0.3, 0.85, 1.0, 0.12))

	var camera_node = Area2D.new()
	camera_node.name = "Camera_%s" % str(camera_def.get("id", "camera"))
	camera_node.position = camera_position
	camera_node.collision_layer = 0
	camera_node.collision_mask = 1
	cell_root.add_child(camera_node)

	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = camera_size
	collision_shape.shape = shape
	camera_node.add_child(collision_shape)

	var detection_rect = ColorRect.new()
	detection_rect.offset_left = -camera_size.x * 0.5
	detection_rect.offset_top = -camera_size.y * 0.5
	detection_rect.offset_right = camera_size.x * 0.5
	detection_rect.offset_bottom = camera_size.y * 0.5
	detection_rect.color = camera_color
	camera_node.add_child(detection_rect)

	var mast = ColorRect.new()
	mast.offset_left = -8.0
	mast.offset_top = -camera_size.y * 0.5 - 16.0
	mast.offset_right = 8.0
	mast.offset_bottom = -camera_size.y * 0.5
	mast.color = Color(0.75, 0.85, 0.95, 1.0)
	camera_node.add_child(mast)

	return {
		"id": str(camera_def.get("id", "camera")),
		"node": camera_node,
		"visual": detection_rect,
		"active": true,
		"player_inside": false
	}

func _add_elevator(cell_root: Node2D, elevator_def: Dictionary, screen_width: float, screen_height: float) -> Dictionary:
	var elevator_size: Vector2 = elevator_def.get("size", Vector2(72, 84))
	var elevator_position: Vector2 = elevator_def.get("position", Vector2.ZERO)
	var target_cell: Vector2i = elevator_def.get("target_cell", Vector2i.ZERO)
	var target_position: Vector2 = elevator_def.get("target_position", Vector2.ZERO)
	var target_global = Vector2(target_cell.x * screen_width, target_cell.y * screen_height) + target_position

	var elevator_node = Area2D.new()
	elevator_node.name = "Elevator_%s" % str(elevator_def.get("id", "elevator"))
	elevator_node.position = elevator_position
	elevator_node.collision_layer = 0
	elevator_node.collision_mask = 1
	cell_root.add_child(elevator_node)

	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = elevator_size
	collision_shape.shape = shape
	elevator_node.add_child(collision_shape)

	var cabin = ColorRect.new()
	cabin.offset_left = -elevator_size.x * 0.5
	cabin.offset_top = -elevator_size.y * 0.5
	cabin.offset_right = elevator_size.x * 0.5
	cabin.offset_bottom = elevator_size.y * 0.5
	cabin.color = Color(0.45, 0.55, 0.7, 0.95)
	elevator_node.add_child(cabin)

	var prompt = Label.new()
	prompt.visible = false
	prompt.offset_left = -120.0
	prompt.offset_top = -60.0
	prompt.offset_right = 120.0
	prompt.offset_bottom = -30.0
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.text = str(elevator_def.get("prompt", "Press E to ride"))
	elevator_node.add_child(prompt)

	return {
		"id": str(elevator_def.get("id", "elevator")),
		"node": elevator_node,
		"prompt_label": prompt,
		"target_position": target_global
	}

func _clear_level_root(level_root: Node2D):
	for child in level_root.get_children():
		child.queue_free()

func _cell_key(col_index: int, row_index: int) -> String:
	return "%d,%d" % [col_index, row_index]
