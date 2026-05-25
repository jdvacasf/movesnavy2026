extends RefCounted

const INTERACTION_COOLDOWN := 0.2

var player: CharacterBody2D
var on_player_relocated: Callable = Callable()
var on_camera_alert: Callable = Callable()
var on_camera_alert_cleared: Callable = Callable()
var on_feedback_requested: Callable = Callable()

var active_switch: Dictionary = {}
var active_elevator: Dictionary = {}
var active_camera_count := 0
var interaction_locked := false

var doors_by_id := {}
var cameras_by_id := {}
var switches: Array = []
var elevators: Array = []

func setup(player_node: CharacterBody2D, player_relocated_callback: Callable, camera_alert_callback: Callable, camera_alert_cleared_callback: Callable, feedback_callback: Callable):
	player = player_node
	on_player_relocated = player_relocated_callback
	on_camera_alert = camera_alert_callback
	on_camera_alert_cleared = camera_alert_cleared_callback
	on_feedback_requested = feedback_callback

func configure(build_result: Dictionary):
	doors_by_id.clear()
	cameras_by_id.clear()
	switches.clear()
	elevators.clear()
	active_switch = {}
	active_elevator = {}
	active_camera_count = 0
	interaction_locked = false

	for door_state in build_result.get("doors", []):
		doors_by_id[door_state["id"]] = door_state
		_apply_door_visual_state(door_state)

	for switch_state in build_result.get("switches", []):
		switches.append(switch_state)
		var switch_node: Area2D = switch_state["node"]
		switch_node.body_entered.connect(_on_switch_body_entered.bind(switch_state))
		switch_node.body_exited.connect(_on_switch_body_exited.bind(switch_state))

	for camera_state in build_result.get("cameras", []):
		cameras_by_id[camera_state["id"]] = camera_state
		var camera_node: Area2D = camera_state["node"]
		camera_node.body_entered.connect(_on_camera_body_entered.bind(camera_state))
		camera_node.body_exited.connect(_on_camera_body_exited.bind(camera_state))

	for elevator_state in build_result.get("elevators", []):
		elevators.append(elevator_state)
		var elevator_node: Area2D = elevator_state["node"]
		elevator_node.body_entered.connect(_on_elevator_body_entered.bind(elevator_state))
		elevator_node.body_exited.connect(_on_elevator_body_exited.bind(elevator_state))

func process_frame() -> bool:
	if interaction_locked or player == null:
		return false

	if not Input.is_action_just_pressed("interact"):
		return false

	if not active_switch.is_empty() and not active_switch.get("activated", false):
		_activate_switch(active_switch)
		return true

	if not active_elevator.is_empty():
		_use_elevator(active_elevator)
		return true

	return false

func clear_interactions():
	if not active_switch.is_empty():
		active_switch["prompt_label"].visible = false
	if not active_elevator.is_empty():
		active_elevator["prompt_label"].visible = false
	active_switch = {}
	active_elevator = {}

func _on_switch_body_entered(body, switch_state: Dictionary):
	if body != player:
		return

	active_switch = switch_state
	if not switch_state.get("activated", false):
		switch_state["prompt_label"].visible = true

func _on_switch_body_exited(body, switch_state: Dictionary):
	if body != player:
		return

	switch_state["prompt_label"].visible = false
	if active_switch == switch_state:
		active_switch = {}

func _activate_switch(switch_state: Dictionary):
	switch_state["activated"] = true
	switch_state["visual"].color = Color(0.2, 0.9, 0.35, 0.95)
	switch_state["prompt_label"].visible = true
	switch_state["prompt_label"].text = "Systems rerouted"

	for door_id in switch_state.get("unlock_doors", []):
		if doors_by_id.has(door_id):
			var door_state: Dictionary = doors_by_id[door_id]
			door_state["open"] = true
			_apply_door_visual_state(door_state)

	for camera_id in switch_state.get("disable_cameras", []):
		if cameras_by_id.has(camera_id):
			_set_camera_enabled(cameras_by_id[camera_id], false)

	if on_feedback_requested.is_valid():
		on_feedback_requested.call("switch")
	_lock_interaction()

func _apply_door_visual_state(door_state: Dictionary):
	var is_open: bool = door_state.get("open", false)
	door_state["collision_shape"].disabled = is_open
	door_state["visual"].color = Color(0.2, 0.8, 0.3, 0.85) if is_open else Color(0.35, 0.42, 0.6, 1.0)

func _set_camera_enabled(camera_state: Dictionary, is_enabled: bool):
	if camera_state.get("active", true) == is_enabled:
		return

	camera_state["active"] = is_enabled
	if not is_enabled and camera_state.get("player_inside", false):
		active_camera_count = maxi(0, active_camera_count - 1)
		camera_state["player_inside"] = false
		_refresh_camera_alert()

	camera_state["node"].monitoring = is_enabled
	camera_state["visual"].color = Color(0.3, 0.85, 1.0, 0.12) if is_enabled else Color(0.35, 0.35, 0.35, 0.1)

func _on_camera_body_entered(body, camera_state: Dictionary):
	if body != player or not camera_state.get("active", true):
		return

	if camera_state.get("player_inside", false):
		return

	camera_state["player_inside"] = true
	active_camera_count += 1
	_refresh_camera_alert()

func _on_camera_body_exited(body, camera_state: Dictionary):
	if body != player:
		return

	if not camera_state.get("player_inside", false):
		return

	camera_state["player_inside"] = false
	active_camera_count = maxi(0, active_camera_count - 1)
	_refresh_camera_alert()

func _refresh_camera_alert():
	if active_camera_count > 0:
		if on_camera_alert.is_valid():
			on_camera_alert.call()
		return

	if on_camera_alert_cleared.is_valid():
		on_camera_alert_cleared.call()

func _on_elevator_body_entered(body, elevator_state: Dictionary):
	if body != player:
		return

	active_elevator = elevator_state
	elevator_state["prompt_label"].visible = true

func _on_elevator_body_exited(body, elevator_state: Dictionary):
	if body != player:
		return

	elevator_state["prompt_label"].visible = false
	if active_elevator == elevator_state:
		active_elevator = {}

func _use_elevator(elevator_state: Dictionary):
	player.global_position = elevator_state.get("target_position", player.global_position)
	elevator_state["prompt_label"].visible = false
	active_elevator = {}

	if on_player_relocated.is_valid():
		on_player_relocated.call()
	if on_feedback_requested.is_valid():
		on_feedback_requested.call("elevator")

	_lock_interaction()

func _lock_interaction():
	interaction_locked = true
	await player.get_tree().create_timer(INTERACTION_COOLDOWN).timeout
	interaction_locked = false
