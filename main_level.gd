extends Node2D

const LevelData = preload("res://level_data.gd")
const LevelBuilder = preload("res://level_builder.gd")
const EnvironmentController = preload("res://environment_controller.gd")
const MissionController = preload("res://mission_controller.gd")
const SoundController = preload("res://sound_controller.gd")
const TransitionController = preload("res://transition_controller.gd")

@export var level_id := "facility_branching"

@onready var level_root = $LevelRoot
@onready var terminal = $Terminal
@onready var terminal_prompt = $Terminal/Prompt
@onready var exit_door = $ExitDoor
@onready var exit_prompt = $ExitDoor/Prompt
@onready var exit_barrier_shape = $ExitDoor/Barrier/CollisionShape2D
@onready var player = $Player
@onready var guard = $Guard
@onready var camera = $Player/Camera2D
@onready var hud_status = $HUD/StatusLabel
@onready var hud_message = $HUD/MessageLabel
@onready var hud_hint = $HUD/HintLabel
@onready var hud_alert = $HUD/AlertLabel
@onready var hud_context = $HUD/ContextLabel
@onready var overlay_root = $HUD/OverlayShade
@onready var overlay_title = $HUD/OverlayShade/OverlayPanel/OverlayTitle
@onready var overlay_body = $HUD/OverlayShade/OverlayPanel/OverlayBody
@onready var overlay_hint = $HUD/OverlayShade/OverlayPanel/OverlayHint
@onready var flash_rect = $HUD/FlashRect

var level_builder = LevelBuilder.new()
var environment_controller = EnvironmentController.new()
var mission_controller = MissionController.new()
var sound_controller = SoundController.new()
var transition_controller = TransitionController.new()
var level_data: Dictionary = {}
var build_result: Dictionary = {}
var flash_tween: Tween

func _ready():
	print("Navy Moves Redux: POC Iniciada")
	_validate_scene_contracts()
	_ensure_input_actions()
	sound_controller.setup(self)

	# Cargamos la definicion del nivel y construimos el mundo desde datos.
	level_data = LevelData.get_level(level_id)
	build_result = level_builder.build(level_root, level_data)
	_validate_level_contracts(build_result)
	_apply_spawns(build_result)
	_apply_camera_limits(build_result)

	# La mision controla HUD, terminal, pausa, victoria y derrota.
	mission_controller.setup(player, guard, terminal, terminal_prompt, exit_door, exit_prompt, exit_barrier_shape, hud_status, hud_message, hud_hint, hud_alert, hud_context, overlay_root, overlay_title, overlay_body, overlay_hint)
	mission_controller.game_state_changed.connect(_on_game_state_changed)
	mission_controller.feedback_requested.connect(_on_feedback_requested)
	mission_controller.reset()

	# El entorno procesa interruptores, puertas, camaras y elevadores construidos desde datos.
	environment_controller.setup(
		player,
		Callable(self, "_on_player_relocated"),
		Callable(mission_controller, "show_environment_alert"),
		Callable(mission_controller, "clear_environment_alert"),
		Callable(self, "_on_feedback_requested")
	)
	environment_controller.configure(build_result)

	# Las transiciones entre pantallas se generan a partir de la matriz.
	transition_controller.setup(player, guard, Callable(self, "_on_player_transition"))
	transition_controller.build(level_data, build_result.get("cell_nodes", {}))
	transition_controller.set_enabled(mission_controller.is_playing())

func _process(_delta):
	var mission_consumed = mission_controller.process_frame()
	if mission_controller.is_playing() and not mission_consumed:
		environment_controller.process_frame()

func _unhandled_input(event):
	if event.is_action_pressed("restart"):
		_restart_level()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		if mission_controller.is_playing():
			mission_controller.pause_game()
			get_viewport().set_input_as_handled()
			return
		if mission_controller.is_paused():
			mission_controller.resume_game()
			get_viewport().set_input_as_handled()
			return

func _on_game_state_changed(_next_state):
	transition_controller.set_enabled(mission_controller.is_playing())

func _ensure_input_actions():
	_ensure_action_key("jump", KEY_SPACE)
	_ensure_action_key("interact", KEY_E)
	_ensure_action_key("restart", KEY_R)

func _ensure_action_key(action_name: String, keycode: Key):
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	# Evitamos duplicar la tecla si ya estaba asignada.
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return

	var input_event := InputEventKey.new()
	input_event.physical_keycode = keycode
	InputMap.action_add_event(action_name, input_event)

func _validate_scene_contracts():
	# La escena principal debe seguir este contrato para que la arquitectura modular funcione.
	assert(level_root != null, "MainLevel requires a LevelRoot node.")
	assert(terminal != null, "MainLevel requires a Terminal node.")
	assert(terminal_prompt != null, "MainLevel requires Terminal/Prompt.")
	assert(exit_door != null, "MainLevel requires an ExitDoor node.")
	assert(exit_prompt != null, "MainLevel requires ExitDoor/Prompt.")
	assert(exit_barrier_shape != null, "MainLevel requires ExitDoor/Barrier/CollisionShape2D.")
	assert(player != null, "MainLevel requires a Player node.")
	assert(guard != null, "MainLevel requires a Guard node.")
	assert(camera != null, "MainLevel requires Player/Camera2D.")
	assert(hud_status != null and hud_message != null and hud_hint != null, "MainLevel requires HUD labels.")
	assert(hud_alert != null and hud_context != null, "MainLevel requires alert and context labels.")
	assert(overlay_root != null and overlay_title != null and overlay_body != null and overlay_hint != null, "MainLevel requires overlay nodes.")
	assert(flash_rect != null, "MainLevel requires a flash rect.")
	assert(player.has_method("set_controls_enabled"), "Player script must implement set_controls_enabled().")
	assert(guard.has_signal("player_spotted"), "Guard script must define player_spotted.")
	assert(guard.has_signal("player_lost"), "Guard script must define player_lost.")
	assert(guard.has_signal("player_captured"), "Guard script must define player_captured.")

func _validate_level_contracts(result: Dictionary):
	# El nivel jugable actual necesita spawns de jugador, terminal, salida y guardia.
	assert(not level_data.is_empty(), "Level data could not be loaded.")
	assert(result.get("columns", 0) > 0 and result.get("rows", 0) > 0, "Level matrix must contain at least one screen.")
	assert(result.get("has_player_spawn", false), "Level data requires a player_spawn.")
	assert(result.get("has_guard_spawn", false), "Level data requires a guard_spawn.")
	assert(result.get("has_terminal_spawn", false), "Level data requires a terminal_spawn.")
	assert(result.get("has_exit_spawn", false), "Level data requires an exit_spawn.")
	assert(result.get("cell_nodes", {}).size() > 0, "Level builder must create at least one cell.")

func _apply_spawns(result: Dictionary):
	# Cada spawn se aplica solo si alguna celda lo definio.
	if result.get("has_player_spawn", false):
		player.global_position = result.get("player_spawn", Vector2.ZERO)
	if result.get("has_guard_spawn", false):
		guard.global_position = result.get("guard_spawn", Vector2.ZERO)
		if guard.has_method("set_patrol_home"):
			guard.set_patrol_home(guard.global_position)
	if result.get("has_terminal_spawn", false):
		terminal.global_position = result.get("terminal_spawn", Vector2.ZERO)
	if result.get("has_exit_spawn", false):
		exit_door.global_position = result.get("exit_spawn", Vector2.ZERO)

func _apply_camera_limits(result: Dictionary):
	# La camara se limita al tamano total de la matriz, no a una sola pantalla.
	var screen_width: float = level_data.get("screen_width", 640.0)
	var screen_height: float = level_data.get("screen_height", 360.0)
	var total_width = max(1, result.get("columns", 1)) * screen_width
	var total_height = max(1, result.get("rows", 1)) * screen_height
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(total_width - 1)
	camera.limit_bottom = int(total_height - 1)

func _restart_level():
	get_tree().reload_current_scene()

func _on_player_transition():
	mission_controller.clear_interactions()
	environment_controller.clear_interactions()
	_on_feedback_requested("transition")

func _on_player_relocated():
	mission_controller.clear_interactions()
	environment_controller.clear_interactions()

func _on_feedback_requested(cue_name: String):
	sound_controller.play_cue(cue_name)

	match cue_name:
		"hack":
			_flash_feedback(Color(0.3, 1.0, 0.45, 0.28), 0.22)
		"locked":
			_flash_feedback(Color(0.85, 0.7, 0.2, 0.18), 0.16)
		"guard_alert", "failure":
			_flash_feedback(Color(1.0, 0.2, 0.2, 0.28), 0.28)
		"camera_alert":
			_flash_feedback(Color(0.25, 0.75, 1.0, 0.2), 0.24)
		"switch":
			_flash_feedback(Color(0.4, 1.0, 0.55, 0.18), 0.18)
		"elevator", "transition":
			_flash_feedback(Color(0.55, 0.85, 1.0, 0.2), 0.16)
		"success":
			_flash_feedback(Color(0.45, 1.0, 0.55, 0.26), 0.3)
		"pause":
			_flash_feedback(Color(0.3, 0.35, 0.45, 0.16), 0.14)

func _flash_feedback(color: Color, duration: float):
	if flash_tween != null and flash_tween.is_valid():
		flash_tween.kill()
	flash_rect.color = color
	flash_rect.visible = true
	flash_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
	flash_tween = create_tween()
	flash_tween.tween_property(flash_rect, "modulate:a", 0.0, duration)
	flash_tween.finished.connect(_on_flash_finished)

func _on_flash_finished():
	flash_rect.visible = false
	flash_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
