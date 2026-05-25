extends CharacterBody2D

const SPEED = 120.0
const JUMP_VELOCITY = -300.0

@onready var sprite = $Sprite2D
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var controls_enabled = true

func _physics_process(delta):
	if not controls_enabled:
		# Cuando el juego se pausa o termina, el jugador conserva solo la fisica basica.
		velocity.x = move_toward(velocity.x, 0, SPEED)
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		return

	# Aplicar Gravedad
	if not is_on_floor():
		velocity.y += gravity * delta

	# Manejo de Salto
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movimiento Horizontal
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		sprite.flip_h = (direction < 0)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func set_controls_enabled(enabled: bool):
	controls_enabled = enabled
	if not enabled:
		velocity.x = 0
