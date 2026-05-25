extends CharacterBody2D

signal player_spotted
signal player_lost
signal player_captured

enum State { PATROL, ALERT, CHASE, SEARCH, RETURN }

@export var patrol_speed := 50.0
@export var chase_speed := 80.0
@export var alert_confirm_time := 0.35
@export var lose_sight_grace_time := 0.6
@export var search_duration := 1.8
@export var view_distance := 180.0
@export var view_angle_degrees := 55.0
@export var capture_distance := 22.0

var current_state = State.PATROL
var direction := 1
var has_spotted_player := false
var alert_timer := 0.0
var lose_sight_timer := 0.0
var search_timer := 0.0
var last_seen_position := Vector2.ZERO
var home_position := Vector2.ZERO
var gravity := ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var vision_ray = $VisionRayCast2D
@onready var edge_ray = $EdgeRayCast2D
@onready var sprite = $Sprite2D
@onready var player = get_parent().get_node_or_null("Player")

func _ready():
	# Recordamos el punto de patrulla para poder volver a el tras perder al jugador.
	home_position = global_position
	last_seen_position = home_position
	_apply_state_visual()
	_update_facing_rays()

func set_patrol_home(position: Vector2):
	# El punto de retorno debe seguir el spawn final aplicado por el nivel.
	home_position = position
	last_seen_position = position

func _physics_process(delta):
	if player == null:
		player = get_parent().get_node_or_null("Player")

	if not is_on_floor():
		velocity.y += gravity * delta

	_update_facing_rays()
	var can_see_player = _can_see_player()
	if can_see_player and player != null:
		# Guardamos la ultima posicion vista para buscar aunque ya no lo vea.
		last_seen_position = player.global_position

	match current_state:
		State.PATROL:
			_patrol_logic(can_see_player)
		State.ALERT:
			_alert_logic(delta, can_see_player)
		State.CHASE:
			_chase_logic(delta, can_see_player)
		State.SEARCH:
			_search_logic(delta, can_see_player)
		State.RETURN:
			_return_logic(can_see_player)

	_try_capture_player()

	move_and_slide()

func _patrol_logic(can_see_player: bool):
	# Patrulla basica: avanza, gira al llegar al borde y pasa a alerta si detecta algo.
	if is_on_wall() or not edge_ray.is_colliding():
		_flip_guard()

	velocity.x = direction * patrol_speed

	if can_see_player:
		_enter_alert_state()

func _alert_logic(delta: float, can_see_player: bool):
	# En alerta el guardia se detiene, confirma la vista y decide si persigue.
	velocity.x = move_toward(velocity.x, 0.0, patrol_speed)

	if player != null:
		var to_player = player.global_position.x - global_position.x
		if not is_zero_approx(to_player):
			direction = sign(to_player)
			_flip_to_direction(direction)

	if can_see_player:
		alert_timer += delta
		if alert_timer >= alert_confirm_time:
			_enter_chase_state()
		return

	_enter_search_state()

func _chase_logic(delta: float, can_see_player: bool):
	# En persecucion corre hacia la ultima posicion conocida del jugador.
	if player == null:
		_enter_return_state()
		return

	var target_x = last_seen_position.x if not can_see_player else player.global_position.x
	_move_towards_x(target_x, chase_speed)

	if can_see_player:
		lose_sight_timer = 0.0
		return

	lose_sight_timer += delta
	if lose_sight_timer >= lose_sight_grace_time:
		_enter_search_state()

func _search_logic(delta: float, can_see_player: bool):
	# Si perdio al jugador, revisa la zona y luego vuelve a casa.
	if can_see_player:
		_enter_chase_state()
		return

	search_timer -= delta
	_move_towards_x(last_seen_position.x, patrol_speed)

	if search_timer <= 0.0 or absf(global_position.x - last_seen_position.x) <= 10.0:
		_enter_return_state()

func _return_logic(can_see_player: bool):
	# Tras la busqueda, el guardia regresa a su ruta original.
	if can_see_player:
		_enter_alert_state()
		return

	_move_towards_x(home_position.x, patrol_speed)
	if absf(global_position.x - home_position.x) <= 8.0:
		velocity.x = 0.0
		current_state = State.PATROL
		has_spotted_player = false
		_apply_state_visual()

func _flip_guard():
	direction *= -1
	_flip_to_direction(direction)

func _flip_to_direction(target_direction: float):
	if is_zero_approx(target_direction):
		return

	scale.x = abs(scale.x) * sign(target_direction)
	direction = sign(target_direction)
	_update_facing_rays()

func _move_towards_x(target_x: float, move_speed: float):
	var delta_x = target_x - global_position.x
	if is_zero_approx(delta_x):
		velocity.x = 0.0
		return

	direction = sign(delta_x)
	_flip_to_direction(direction)
	velocity.x = direction * move_speed

func _can_see_player() -> bool:
	# La deteccion combina distancia, angulo de vision y linea de vision real.
	if player == null:
		return false

	var to_player = player.global_position - global_position
	if to_player.length() > view_distance:
		return false

	if to_player.length() < 0.001:
		return true

	var facing_vector = Vector2(direction, 0.0)
	var facing_dot = clamp(facing_vector.normalized().dot(to_player.normalized()), -1.0, 1.0)
	var angle_to_player = rad_to_deg(acos(facing_dot))
	if angle_to_player > view_angle_degrees * 0.5:
		return false

	return _has_line_of_sight_to_player()

func _has_line_of_sight_to_player() -> bool:
	if player == null:
		return false

	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.collision_mask = 3
	query.exclude = [self]
	var result = get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false

	return result.get("collider") == player

func _try_capture_player():
	# La derrota no depende de ver al jugador, sino de alcanzarlo fisicamente.
	if player == null:
		return

	if current_state != State.ALERT and current_state != State.CHASE:
		return

	var close_enough = global_position.distance_to(player.global_position) <= capture_distance
	var same_level = absf(global_position.y - player.global_position.y) <= 32.0
	if close_enough and same_level:
		player_captured.emit()

func _enter_alert_state():
	# La primera deteccion activa la alarma visual y la senal de aviso.
	if current_state == State.ALERT:
		return

	current_state = State.ALERT
	alert_timer = 0.0
	lose_sight_timer = 0.0
	search_timer = search_duration
	if not has_spotted_player:
		has_spotted_player = true
		player_spotted.emit()
	_apply_state_visual()

func _enter_chase_state():
	# La persecucion mantiene el objetivo fijo hasta que se pierde de vista.
	current_state = State.CHASE
	lose_sight_timer = 0.0
	_apply_state_visual()

func _enter_search_state():
	# La busqueda dura un tiempo corto antes de volver a patrulla.
	current_state = State.SEARCH
	search_timer = search_duration
	velocity.x = 0.0
	_apply_state_visual()

func _enter_return_state():
	# Si no encuentra nada, vuelve a su punto de patrulla.
	current_state = State.RETURN
	velocity.x = 0.0
	if has_spotted_player:
		has_spotted_player = false
		player_lost.emit()
	_apply_state_visual()

func _apply_state_visual():
	# El color del sprite sirve como lectura rapida del estado de IA.
	match current_state:
		State.PATROL:
			sprite.modulate = Color(1.0, 0.2, 0.2, 1.0)
		State.ALERT:
			sprite.modulate = Color(1.0, 0.65, 0.2, 1.0)
		State.CHASE:
			sprite.modulate = Color(1.0, 0.35, 0.1, 1.0)
		State.SEARCH:
			sprite.modulate = Color(1.0, 0.85, 0.2, 1.0)
		State.RETURN:
			sprite.modulate = Color(0.85, 0.45, 0.2, 1.0)

func _update_facing_rays():
	# Los rayos se actualizan cuando el guardia cambia de direccion.
	vision_ray.target_position = Vector2(view_distance * direction, 0.0)
	edge_ray.target_position = Vector2(10 * direction, 20)
