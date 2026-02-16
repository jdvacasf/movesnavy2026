Proyecto: Navy Moves Redux (POC)Este documento detalla la implementación de una prueba de concepto funcional con dos pantallas de scroll, un sistema de movimiento para el jugador y una IA de guardia con estados.1. Configuración del Proyecto (Godot 4.x)Resolución y RenderizadoWindow Size: $640 \times 360$ (para un look retro escalable).Stretch Mode: canvas_items / Aspect: keep.Texture Filter: Nearest (evita que los píxeles se vean borrosos).Capas de Colisión (Physics Layers)Configurar en Project Settings -> Layer Names -> 2D Physics:Layer 1: PlayerLayer 2: World (Suelo y Paredes)Layer 3: Enemies2. Escena del Jugador (player.tscn)Jerarquía:CharacterBody2D (Script: player.gd)Sprite2D (Placeholder: Cuadrado Blanco)CollisionShape2D (Rectángulo)Camera2D (Position Smoothing: Enabled)Código: player.gdGDScriptextends CharacterBody2D

const SPEED = 120.0
const JUMP_VELOCITY = -300.0

@onready var sprite = $Sprite2D
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta):
	# Aplicar Gravedad
	if not is_on_floor():
		velocity.y += gravity * delta

	# Manejo de Salto
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movimiento Horizontal
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		sprite.flip_h = (direction < 0)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
3. Escena del Guardia (guard.tscn)Jerarquía:CharacterBody2D (Script: guard.gd)Sprite2D (Placeholder: Cuadrado Rojo)CollisionShape2DVisionRayCast2D (Target: x=120, y=0 / Mask: Layer 1)EdgeRayCast2D (Target: x=10, y=20 / Mask: Layer 2)Código: guard.gdGDScriptextends CharacterBody2D

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
4. Escena de Nivel (main_level.tscn)Instrucciones de diseño:Añade un nodo TileMap o StaticBody2D para el suelo.Crea un pasillo largo que mida al menos $1280$ píxeles de ancho (equivale a 2 pantallas de $640$px).Coloca al Player en un extremo y al Guard en una plataforma elevada.Script de Nivel: main_level.gdGDScriptextends Node2D

func _ready():
	print("Navy Moves Redux: POC Iniciada")
	# Aquí podrías limitar la cámara si el nivel es cerrado
	# $Player/Camera2D.limit_right = 1280
	# $Player/Camera2D.limit_bottom = 360
5. Próximos Pasos SugeridosFaseObjetivoElemento clavePaso 1InteracciónAñadir el Area2D para terminales de hacking.Paso 2SigiloImplementar el cono de luz visual para el guardia.Paso 3PeligroAñadir cámaras de seguridad fijas que activen alarmas.