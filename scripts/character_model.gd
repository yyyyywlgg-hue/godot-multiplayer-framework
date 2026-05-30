class_name CharacterModel
extends Node3D

const TURN_SPEED: float = 12.0

const ANIM_MAP: Dictionary = {
	"idle": "CharacterArmature|Idle",
	"walk": "CharacterArmature|Walk",
	"run": "CharacterArmature|Walk",
	"jump": "CharacterArmature|PickUp",
}

const FORWARD: String = "forward"
const BACKWARD: String = "backward"
const LEFT: String = "left"
const RIGHT: String = "right"
const RUN_ACTION: String = "run"

var _anim_player: AnimationPlayer
var _machine: StateMachine
var _is_local_player: bool = false

func _ready() -> void:
	await get_tree().process_frame
	_setup_animation()
	_setup_state_machine()

func _process(delta: float) -> void:
	_update_rotation(delta)

func setup_local() -> void:
	_is_local_player = true

func setup_remote() -> void:
	_is_local_player = false

func drive_from_input() -> void:
	if not _is_local_player:
		return
	if _machine and _machine.current_state():
		_machine.current_state().update(get_process_delta_time())

func drive_from_synced_state(moving: bool, running: bool, on_floor: bool) -> void:
	if _is_local_player:
		return
	if not _machine:
		return
	var current = _machine.current_state()
	if current == null:
		return
	var target: StringName = &"idle"
	if not on_floor:
		target = &"jump"
	elif running and moving:
		target = &"run"
	elif moving:
		target = &"walk"
	if _machine.current_state_name() != target:
		_machine.force_transition(target)

func play_animation(anim_key: String, loop: bool, speed: float) -> void:
	var anim_name: String = ANIM_MAP.get(anim_key, "")
	if anim_name == "" or _anim_player == null:
		return
	if not _anim_player.has_animation(anim_name):
		return
	_anim_player.play(anim_name, -1, speed)
	if _anim_player.is_playing():
		_anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE

func _update_rotation(delta: float) -> void:
	if _is_local_player:
		var direction := Vector3(
			Input.get_axis(LEFT, RIGHT),
			0.0,
			Input.get_axis(FORWARD, BACKWARD)
		)
		if direction.length_squared() < 0.01:
			return
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), TURN_SPEED * delta)
	else:
		var vel = _get_parent_velocity()
		if Vector2(vel.x, vel.z).length() < 0.5:
			return
		rotation.y = lerp_angle(rotation.y, atan2(vel.x, vel.z), TURN_SPEED * delta)

func _is_moving() -> bool:
	return Vector2(
		Input.get_axis(LEFT, RIGHT),
		Input.get_axis(FORWARD, BACKWARD)
	).length() > 0.1

func _is_running() -> bool:
	return Input.is_action_pressed(RUN_ACTION)

func _jump_pressed() -> bool:
	if not _is_local_player:
		return false
	return Input.is_action_just_pressed("jump")

func _get_parent_velocity() -> Vector3:
	var p = get_parent()
	if p and p.has_method("get_effective_velocity"):
		return p.get_effective_velocity()
	return Vector3.ZERO

func _get_parent_on_floor() -> bool:
	var p = get_parent()
	if p and p.has_method("get_effective_is_on_floor"):
		return p.get_effective_is_on_floor()
	return true

func _get_parent_is_running() -> bool:
	var p = get_parent()
	if p and p.has_method("get_effective_is_running"):
		return p.get_effective_is_running()
	return false

func _setup_state_machine() -> void:
	_machine = StateMachine.new()
	_machine.name = "AnimStateMachine"
	add_child(_machine)

	var idle = AnimIdleState.new()
	var walk = AnimWalkState.new()
	var run = AnimRunState.new()
	var jump = AnimJumpState.new()

	_machine.add_state(idle)
	_machine.add_state(walk)
	_machine.add_state(run)
	_machine.add_state(jump)

	_machine.add_transition(&"idle", &"walk")
	_machine.add_transition(&"idle", &"run")
	_machine.add_transition(&"idle", &"jump")
	_machine.add_transition(&"walk", &"idle")
	_machine.add_transition(&"walk", &"run")
	_machine.add_transition(&"walk", &"jump")
	_machine.add_transition(&"run", &"idle")
	_machine.add_transition(&"run", &"walk")
	_machine.add_transition(&"run", &"jump")
	_machine.add_transition(&"jump", &"idle")
	_machine.add_transition(&"jump", &"walk")
	_machine.add_transition(&"jump", &"run")

	_machine.force_transition(&"idle")

func _setup_animation() -> void:
	_anim_player = _find_animation_player($CharacterMesh)
	if _anim_player == null:
		push_warning("CharacterModel: No AnimationPlayer found!")
		return
	var anim_names: Array = []
	if _anim_player.has_animation_library(""):
		anim_names.assign(_anim_player.get_animation_library("").get_animation_list())
	print("CharacterModel: Available animations: ", anim_names)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_animation_player(child)
		if found:
			return found
	return null


class AnimIdleState extends State:
	func _init():
		state_name = &"idle"
	func enter():
		var model = _get_model()
		if model:
			model.play_animation("idle", true, 1.0)
	func update(_delta: float):
		var model = _get_model()
		if not model:
			return
		if model._jump_pressed():
			transition_to(&"jump")
		elif model._is_running() and model._is_moving():
			transition_to(&"run")
		elif model._is_moving():
			transition_to(&"walk")
	func _get_model() -> CharacterModel:
		if _machine and _machine.get_parent() is CharacterModel:
			return _machine.get_parent()
		return null


class AnimWalkState extends State:
	func _init():
		state_name = &"walk"
	func enter():
		var model = _get_model()
		if model:
			model.play_animation("walk", true, 0.8)
	func update(_delta: float):
		var model = _get_model()
		if not model:
			return
		if model._jump_pressed():
			transition_to(&"jump")
		elif model._is_running() and model._is_moving():
			transition_to(&"run")
		elif not model._is_moving():
			transition_to(&"idle")
	func _get_model() -> CharacterModel:
		if _machine and _machine.get_parent() is CharacterModel:
			return _machine.get_parent()
		return null


class AnimRunState extends State:
	func _init():
		state_name = &"run"
	func enter():
		var model = _get_model()
		if model:
			model.play_animation("run", true, 1.2)
	func update(_delta: float):
		var model = _get_model()
		if not model:
			return
		if model._jump_pressed():
			transition_to(&"jump")
		elif not model._is_running() and model._is_moving():
			transition_to(&"walk")
		elif not model._is_moving():
			transition_to(&"idle")
	func _get_model() -> CharacterModel:
		if _machine and _machine.get_parent() is CharacterModel:
			return _machine.get_parent()
		return null


class AnimJumpState extends State:
	var _anim_done: bool = false

	func _init():
		state_name = &"jump"
	func enter():
		_anim_done = false
		var model = _get_model()
		if not model or not model._anim_player:
			return
		if not model._anim_player.animation_finished.is_connected(_on_anim_finished):
			model._anim_player.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)
		model.play_animation("jump", false, 1.0)
	func update(_delta: float):
		if _anim_done:
			var model = _get_model()
			if not model:
				return
			if model._is_moving():
				if model._is_running():
					transition_to(&"run")
				else:
					transition_to(&"walk")
			else:
				transition_to(&"idle")
	func exit():
		_anim_done = false
	func _on_anim_finished(_anim_name: String):
		_anim_done = true
	func _get_model() -> CharacterModel:
		if _machine and _machine.get_parent() is CharacterModel:
			return _machine.get_parent()
		return null
