extends RefCounted

signal game_state_changed(next_state)
signal feedback_requested(cue_name)

enum GameState { PLAYING, SUCCESS, FAILED, PAUSED }
enum ObjectiveState { HACK_TERMINAL, ESCAPE }

var player: CharacterBody2D
var guard: CharacterBody2D
var terminal: Area2D
var terminal_prompt: Label
var exit_door: Area2D
var exit_prompt: Label
var exit_barrier_shape: CollisionShape2D
var hud_status: Label
var hud_message: Label
var hud_hint: Label
var hud_alert: Label
var hud_context: Label
var overlay_root: Control
var overlay_title: Label
var overlay_body: Label
var overlay_hint: Label

var game_state := GameState.PLAYING
var previous_game_state := GameState.PLAYING
var objective_state := ObjectiveState.HACK_TERMINAL
var player_in_terminal_range := false
var player_in_exit_range := false
var terminal_hacked := false
var exit_unlocked := false
var guard_alerted := false
var environment_alerted := false

func setup(player_node: CharacterBody2D, guard_node: CharacterBody2D, terminal_node: Area2D, terminal_prompt_label: Label, exit_door_node: Area2D, exit_prompt_label: Label, exit_barrier_shape_node: CollisionShape2D, hud_status_label: Label, hud_message_label: Label, hud_hint_label: Label, hud_alert_label: Label, hud_context_label: Label, overlay_root_node: Control, overlay_title_label: Label, overlay_body_label: Label, overlay_hint_label: Label):
	# Guardamos referencias para centralizar la logica de mision en un solo sitio.
	player = player_node
	guard = guard_node
	terminal = terminal_node
	terminal_prompt = terminal_prompt_label
	exit_door = exit_door_node
	exit_prompt = exit_prompt_label
	exit_barrier_shape = exit_barrier_shape_node
	hud_status = hud_status_label
	hud_message = hud_message_label
	hud_hint = hud_hint_label
	hud_alert = hud_alert_label
	hud_context = hud_context_label
	overlay_root = overlay_root_node
	overlay_title = overlay_title_label
	overlay_body = overlay_body_label
	overlay_hint = overlay_hint_label

	terminal.body_entered.connect(_on_terminal_body_entered)
	terminal.body_exited.connect(_on_terminal_body_exited)
	exit_door.body_entered.connect(_on_exit_body_entered)
	exit_door.body_exited.connect(_on_exit_body_exited)
	guard.player_spotted.connect(_on_guard_player_spotted)
	guard.player_lost.connect(_on_guard_player_lost)
	guard.player_captured.connect(_on_guard_player_captured)

func reset():
	# Reiniciamos el estado global de la mision sin reconstruir la escena.
	game_state = GameState.PLAYING
	previous_game_state = GameState.PLAYING
	objective_state = ObjectiveState.HACK_TERMINAL
	player_in_terminal_range = false
	player_in_exit_range = false
	terminal_hacked = false
	exit_unlocked = false
	guard_alerted = false
	environment_alerted = false
	terminal.modulate = Color(0.2, 0.8, 0.9, 1.0)
	terminal_prompt.visible = false
	terminal_prompt.text = "Press E to hack"
	exit_door.modulate = Color(0.7, 0.5, 0.2, 1.0)
	exit_prompt.visible = false
	exit_prompt.text = "Exit locked"
	exit_barrier_shape.disabled = false
	_set_overlay(false, "", "", "")
	_resume_actors()
	_show_current_objective()
	game_state_changed.emit(game_state)

func process_frame() -> bool:
	# La interaccion con terminal se resuelve en el controlador de mision.
	if game_state != GameState.PLAYING:
		return false

	if player_in_terminal_range and Input.is_action_just_pressed("interact"):
		_hack_terminal()
		return true

	if player_in_exit_range and Input.is_action_just_pressed("interact"):
		_try_use_exit()
		return true

	return false

func pause_game():
	if game_state != GameState.PLAYING:
		return

	previous_game_state = game_state
	_set_game_state(GameState.PAUSED)

func resume_game():
	if game_state != GameState.PAUSED:
		return

	game_state = previous_game_state
	if game_state != GameState.PLAYING:
		game_state = GameState.PLAYING
	feedback_requested.emit("resume")
	_resume_actors()
	_show_current_objective()
	_set_overlay(false, "", "", "")
	game_state_changed.emit(game_state)

func is_playing() -> bool:
	return game_state == GameState.PLAYING

func is_paused() -> bool:
	return game_state == GameState.PAUSED

func clear_interactions():
	player_in_terminal_range = false
	player_in_exit_range = false
	terminal_prompt.visible = false
	exit_prompt.visible = false

func show_environment_alert():
	if game_state != GameState.PLAYING:
		return

	environment_alerted = true
	if guard_alerted:
		return

	feedback_requested.emit("camera_alert")
	hud_context.text = "A camera zone is active. Back out of the blue cone or use a switch to shut it down."
	_update_hud("Alert: camera spotted you", "Status: surveillance", "Use a switch or leave the camera zone")

func clear_environment_alert():
	if game_state != GameState.PLAYING:
		return
	if not environment_alerted:
		return

	environment_alerted = false
	if guard_alerted:
		return

	_show_current_objective()

func _on_terminal_body_entered(body):
	if body == player and game_state == GameState.PLAYING:
		player_in_terminal_range = true
		terminal_prompt.visible = true
		terminal_prompt.text = "Press E to hack"

func _on_terminal_body_exited(body):
	if body == player:
		player_in_terminal_range = false
		if game_state == GameState.PLAYING:
			terminal_prompt.visible = false

func _on_exit_body_entered(body):
	if body != player or game_state != GameState.PLAYING:
		return

	player_in_exit_range = true
	exit_prompt.visible = true
	exit_prompt.text = "Press E to escape" if exit_unlocked else "Exit locked"

func _on_exit_body_exited(body):
	if body != player:
		return

	player_in_exit_range = false
	if game_state == GameState.PLAYING:
		exit_prompt.visible = false

func _hack_terminal():
	if game_state != GameState.PLAYING:
		return

	if terminal_hacked:
		return

	terminal_hacked = true
	exit_unlocked = true
	objective_state = ObjectiveState.ESCAPE
	player_in_terminal_range = false
	terminal_prompt.visible = true
	terminal_prompt.text = "Terminal hacked"
	terminal.modulate = Color(0.2, 1.0, 0.2, 1.0)
	exit_door.modulate = Color(0.25, 0.9, 0.35, 1.0)
	exit_barrier_shape.disabled = true
	feedback_requested.emit("hack")
	_show_current_objective()

func _try_use_exit():
	if not exit_unlocked:
		exit_prompt.visible = true
		exit_prompt.text = "Exit locked"
		feedback_requested.emit("locked")
		hud_context.text = "The exit stays locked until the terminal is hacked. Follow the cyan objective first."
		_update_hud("Objective: hack the terminal first", "Status: exit locked", "Find the terminal, then come back here")
		return

	player_in_exit_range = false
	exit_prompt.visible = true
	exit_prompt.text = "Extraction complete"
	_set_game_state(GameState.SUCCESS)

func _on_guard_player_spotted():
	if game_state != GameState.PLAYING:
		return

	if guard_alerted:
		return

	# La alerta avisa al jugador, pero aun no termina la partida.
	guard_alerted = true
	player_in_terminal_range = false
	player_in_exit_range = false
	terminal_prompt.visible = false
	exit_prompt.visible = false
	feedback_requested.emit("guard_alert")
	hud_context.text = "The guard confirmed your position. Break line of sight and keep moving until the alert clears."
	_update_hud("Alert: guard spotted you", "Status: detected", "Break line of sight and keep moving")

func _on_guard_player_lost():
	if game_state != GameState.PLAYING:
		return
	if not guard_alerted:
		return

	guard_alerted = false
	if environment_alerted:
		show_environment_alert()
		return
	_show_current_objective()

func _on_guard_player_captured():
	if game_state != GameState.PLAYING:
		return

	# La derrota solo ocurre cuando el guardia captura de verdad al jugador.
	guard_alerted = false
	environment_alerted = false
	player_in_terminal_range = false
	player_in_exit_range = false
	terminal_prompt.visible = false
	exit_prompt.visible = false
	terminal.modulate = Color(1.0, 0.35, 0.35, 1.0)
	_set_game_state(GameState.FAILED)

func _set_game_state(next_state: int):
	# El estado global decide que actores se congelan y que texto muestra el HUD.
	game_state = next_state

	match game_state:
		GameState.PLAYING:
			_resume_actors()
			_set_overlay(false, "", "", "")
			_show_current_objective()
		GameState.SUCCESS:
			_freeze_actors()
			feedback_requested.emit("success")
			_set_overlay(true, "Mission Complete", "You hacked the terminal and reached extraction.", "Press R to restart")
			_update_hud("Objective complete", "Status: mission success", "Press R to restart")
			_complete_level()
		GameState.FAILED:
			_freeze_actors()
			feedback_requested.emit("failure")
			_set_overlay(true, "Mission Failed", "The guard reached you before extraction.", "Press R to restart")
			_update_hud("ALARM: guard captured you", "Status: mission failed", "Press R to restart")
			_complete_level()
		GameState.PAUSED:
			_freeze_actors()
			feedback_requested.emit("pause")
			_set_overlay(true, "Paused", "Review the objective and resume when ready.", "Press Esc to resume | R to restart")
			_update_hud("Paused", "Status: paused", "Press Esc to resume | R to restart")

	game_state_changed.emit(game_state)

func _complete_level():
	if game_state == GameState.FAILED:
		print("Alarm triggered: player captured.")
	else:
		print("Objective complete: terminal hacked and exit reached.")
	_freeze_actors()

func _freeze_actors():
	# Cuando la partida termina, se desactivan control y fisica de ambos actores.
	player.set_controls_enabled(false)
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	guard.velocity = Vector2.ZERO
	guard.set_physics_process(false)

func _resume_actors():
	# Al volver a jugar, restauramos control y fisica normal.
	player.set_controls_enabled(true)
	player.set_physics_process(true)
	guard.set_physics_process(true)

func _update_hud(message_text: String, status_text: String, hint_text: String):
	hud_message.text = message_text
	hud_status.text = status_text
	hud_hint.text = hint_text
	_update_alert_badge()

func _update_alert_badge():
	if guard_alerted:
		hud_alert.text = "ALERT: Guard"
		hud_alert.modulate = Color(1.0, 0.35, 0.25, 1.0)
		return

	if environment_alerted:
		hud_alert.text = "ALERT: Cameras"
		hud_alert.modulate = Color(0.35, 0.85, 1.0, 1.0)
		return

	hud_alert.text = "ALERT: Clear"
	hud_alert.modulate = Color(0.45, 1.0, 0.55, 1.0)

func _show_current_objective():
	var objective_text = "Objective: escape through the exit" if objective_state == ObjectiveState.ESCAPE else "Objective: hack the terminal"
	var hint_text = "Move with arrows | Space jump | E interact | Esc pause"
	if objective_state == ObjectiveState.ESCAPE:
		hud_context.text = "Head back to the green exit. If a blue camera sees you, disable it or leave its cone."
	else:
		hud_context.text = "Find the cyan terminal, stand close, and press E. Red guard and blue camera zones mean danger."
	_update_hud(objective_text, "Status: playing", hint_text)

func _set_overlay(is_visible: bool, title_text: String, body_text: String, hint_text: String):
	overlay_root.visible = is_visible
	overlay_title.text = title_text
	overlay_body.text = body_text
	overlay_hint.text = hint_text
