extends RefCounted

const TRANSITION_THICKNESS := 20.0
const TRANSITION_INSET := 48.0
const TRANSITION_COOLDOWN := 0.18
const TRANSITION_COLLISION_MASK := 5

var player: Node2D
var guard: Node2D
var on_player_transition: Callable = Callable()
var enabled := true
var transition_locked := false
var matrix: Array = []
var screen_width := 640.0
var screen_height := 360.0

func setup(player_node: Node2D, guard_node: Node2D, player_transition_callback: Callable):
	player = player_node
	guard = guard_node
	on_player_transition = player_transition_callback

func build(level_data: Dictionary, cell_nodes: Dictionary):
	# Leemos la matriz para crear portales solo donde existan celdas vecinas.
	matrix = level_data.get("matrix", [])
	screen_width = level_data.get("screen_width", 640.0)
	screen_height = level_data.get("screen_height", 360.0)

	for row_index in range(matrix.size()):
		var row: Array = matrix[row_index]
		for col_index in range(row.size()):
			var cell = row[col_index]
			if cell == null:
				continue

			var cell_root: Node2D = cell_nodes.get(_cell_key(col_index, row_index))
			if cell_root == null:
				continue

			_add_transition(cell_root, col_index, row_index, Vector2i(1, 0))
			_add_transition(cell_root, col_index, row_index, Vector2i(-1, 0))
			_add_transition(cell_root, col_index, row_index, Vector2i(0, 1))
			_add_transition(cell_root, col_index, row_index, Vector2i(0, -1))

func set_enabled(is_enabled: bool):
	enabled = is_enabled
	if is_enabled:
		transition_locked = false

func _add_transition(cell_root: Node2D, col_index: int, row_index: int, direction: Vector2i):
	# Cada portal conecta una celda con su vecina en una direccion concreta.
	var target_col = col_index + direction.x
	var target_row = row_index + direction.y

	if not _has_cell_at(target_col, target_row):
		return

	var portal = Area2D.new()
	portal.name = "Transition_%d_%d_to_%d_%d" % [col_index, row_index, target_col, target_row]
	portal.collision_layer = 0
	portal.collision_mask = TRANSITION_COLLISION_MASK
	portal.monitoring = true
	portal.set_meta("target_col", target_col)
	portal.set_meta("target_row", target_row)
	portal.set_meta("direction", direction)
	portal.body_entered.connect(_on_transition_body_entered.bind(portal))

	if direction.x != 0:
		portal.position = Vector2(
			(screen_width - TRANSITION_THICKNESS * 0.5) if direction.x > 0 else (TRANSITION_THICKNESS * 0.5),
			screen_height * 0.5
		)
	else:
		portal.position = Vector2(
			screen_width * 0.5,
			(screen_height - TRANSITION_THICKNESS * 0.5) if direction.y > 0 else (TRANSITION_THICKNESS * 0.5)
		)

	cell_root.add_child(portal)

	var shape = CollisionShape2D.new()
	var rectangle = RectangleShape2D.new()
	if direction.x != 0:
		rectangle.size = Vector2(TRANSITION_THICKNESS, screen_height)
	else:
		rectangle.size = Vector2(screen_width, TRANSITION_THICKNESS)
	shape.shape = rectangle
	portal.add_child(shape)

	var hint = ColorRect.new()
	if direction.x != 0:
		hint.offset_left = -TRANSITION_THICKNESS * 0.5
		hint.offset_top = -screen_height * 0.5
		hint.offset_right = TRANSITION_THICKNESS * 0.5
		hint.offset_bottom = screen_height * 0.5
	else:
		hint.offset_left = -screen_width * 0.5
		hint.offset_top = -TRANSITION_THICKNESS * 0.5
		hint.offset_right = screen_width * 0.5
		hint.offset_bottom = TRANSITION_THICKNESS * 0.5
	hint.color = Color(0.2, 0.8, 1.0, 0.08)
	portal.add_child(hint)

func _has_cell_at(col_index: int, row_index: int) -> bool:
	if row_index < 0 or row_index >= matrix.size():
		return false

	var row: Array = matrix[row_index]
	if col_index < 0 or col_index >= row.size():
		return false

	return row[col_index] != null

func _on_transition_body_entered(body, portal: Area2D):
	# Solo el jugador y el guardia usan estas transiciones.
	if not enabled:
		return
	if transition_locked:
		return
	if body != player and body != guard:
		return

	var direction: Vector2i = portal.get_meta("direction")
	var target_col = int(portal.get_meta("target_col"))
	var target_row = int(portal.get_meta("target_row"))
	var target_origin = Vector2(target_col * screen_width, target_row * screen_height)
	var target_position = _get_transition_target_position(body, direction, target_origin)

	transition_locked = true
	body.global_position = target_position
	if body == player and on_player_transition.is_valid():
		# Al cambiar de pantalla, limpiamos el estado de interaccion del terminal.
		on_player_transition.call()
	await body.get_tree().create_timer(TRANSITION_COOLDOWN).timeout
	transition_locked = false

func _get_transition_target_position(body: Node2D, direction: Vector2i, target_origin: Vector2) -> Vector2:
	# Colocamos al cuerpo cerca del borde de entrada de la pantalla destino.
	if direction.x != 0:
		var target_x = target_origin.x + (TRANSITION_INSET if direction.x > 0 else screen_width - TRANSITION_INSET)
		var target_y = clamp(body.global_position.y, target_origin.y + 40.0, target_origin.y + screen_height - 60.0)
		return Vector2(target_x, target_y)

	var target_y = target_origin.y + (TRANSITION_INSET if direction.y > 0 else screen_height - TRANSITION_INSET)
	var target_x = clamp(body.global_position.x, target_origin.x + 40.0, target_origin.x + screen_width - 40.0)
	return Vector2(target_x, target_y)

func _cell_key(col_index: int, row_index: int) -> String:
	return "%d,%d" % [col_index, row_index]
