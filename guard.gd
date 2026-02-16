extends CharacterBody2D

enum State { PATROL, CHASE }
var current_state = State.PATROL

@export var speed = 50.0
var direction = 1 

@onready var vision_ray = $VisionRayCast2D
@onready var edge_ray = $EdgeRayCast2D
@onready var sprite = $Sprite2D

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += 980 * delta

	match current_state:
		State.PATROL:
			_patrol_logic()
		State.CHASE:
			_chase_logic()

	move_and_slide()

func _patrol_logic():
	# Detectar fin de plataforma o colisión frontal
	if is_on_wall() or not edge_ray.is_colliding():
		_flip_guard()

	velocity.x = direction * speed
	
	# Detectar Jugador
	if vision_ray.is_colliding():
		var obj = vision_ray.get_collider()
		if obj and obj.name == "Player":
			current_state = State.CHASE

func _chase_logic():
	velocity.x = direction * (speed * 1.6)
	
	# Si pierde de vista al jugador, vuelve a patrullar
	if not vision_ray.is_colliding():
		current_state = State.PATROL

func _flip_guard():
	direction *= -1
	scale.x = abs(scale.x) * direction # Voltea todo el nodo (incluidos rayos)
