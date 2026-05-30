class_name CharacterModel
extends Node3D

const TURN_SPEED: float = 12.0

# Animation name mapping - BaseCharacter uses "CharacterArmature|" prefix
const ANIM_MAP: Dictionary = {
	"idle": "CharacterArmature|Idle",
	"walk": "CharacterArmature|Walk",
	"run": "CharacterArmature|Walk",
	"jump": "CharacterArmature|PickUp",
}

class State:
	var model: CharacterModel
	func enter(): pass
	func exit(): pass
	func update(_delta: float): pass

	func _play(anim_key: String, loop: bool, speed: float) -> void:
		var anim_name: String = ANIM_MAP.get(anim_key, "")
		if anim_name == "":
			return
		if model._anim_player == null or not model._anim_player.has_animation(anim_name):
			return
		model._anim_player.play(anim_name, -1, speed)
		if model._anim_player.is_playing():
			model._anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE

	func _transition_from_input(moving: bool, running: bool) -> void:
		if model._jump_pressed():
			model._change_state(StateType.JUMP)
		elif running and moving:
			model._change_state(StateType.RUN)
		elif moving:
			model._change_state(StateType.WALK)
		else:
			model._change_state(StateType.IDLE)

class IdleState extends State:
	func enter(): _play("idle", true, 1.0)
	func update(_delta: float) -> void:
		_transition_from_input(model._is_moving(), model._is_running())

class WalkState extends State:
	func enter(): _play("walk", true, 0.8)
	func update(_delta: float) -> void:
		_transition_from_input(model._is_moving(), model._is_running())

class RunState extends State:
	func enter(): _play("run", true, 1.2)
	func update(_delta: float) -> void:
		_transition_from_input(model._is_moving(), model._is_running())

class JumpState extends State:
	func enter():
		model._jumping = true
		if not model._anim_player.animation_finished.is_connected(model._on_jump_done):
			model._anim_player.animation_finished.connect(model._on_jump_done, CONNECT_ONE_SHOT)
		_play("jump", false, 1.0)
	func update(_delta: float) -> void:
		if not model._jumping:
			_transition_from_input(model._is_moving(), model._is_running())

enum StateType { IDLE, WALK, RUN, JUMP }

var _anim_player: AnimationPlayer
var _states: Dictionary = {}
var _current: State
var _jumping: bool = false
var _remote_anim: String = ""

const FORWARD: String = "forward"
const BACKWARD: String = "backward"
const LEFT: String = "left"
const RIGHT: String = "right"
const RUN_ACTION: String = "run"

func _ready() -> void:
	await get_tree().process_frame
	_setup_animation()
	_setup_states()
	_change_state(StateType.IDLE)

func _process(delta: float) -> void:
	_update_rotation(delta)
	if _is_local():
		if _current:
			_current.update(delta)
	else:
		_update_remote_animation()

func _update_rotation(delta: float) -> void:
	if _is_local():
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

func _is_local() -> bool:
	var p = get_parent()
	if not (p is CharacterBody3D):
		return false
	return str(p.name) == str(multiplayer.get_unique_id())

func _is_moving() -> bool:
	return Vector2(
		Input.get_axis(LEFT, RIGHT),
		Input.get_axis(FORWARD, BACKWARD)
	).length() > 0.1

func _is_running() -> bool:
	return Input.is_action_pressed(RUN_ACTION)

func _jump_pressed() -> bool:
	if not _is_local():
		return false
	return Input.is_action_just_pressed("jump") and not _jumping

func _on_jump_done(_name: String) -> void:
	_jumping = false

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

func _update_remote_animation() -> void:
	var vel = _get_parent_velocity()
	var on_floor = _get_parent_on_floor()
	var is_running = _get_parent_is_running()
	var horizontal_speed = Vector2(vel.x, vel.z).length()

	var target_key: String
	var loop: bool
	var speed: float

	if not on_floor:
		target_key = "jump"
		loop = false
		speed = 1.0
	elif is_running and horizontal_speed > 0.5:
		target_key = "run"
		loop = true
		speed = 1.2
	elif horizontal_speed > 0.5:
		target_key = "walk"
		loop = true
		speed = 0.8
	else:
		target_key = "idle"
		loop = true
		speed = 1.0

	if target_key != _remote_anim:
		_remote_anim = target_key
		_play_direct(target_key, loop, speed)

func _play_direct(anim_key: String, loop: bool, speed: float) -> void:
	var anim_name: String = ANIM_MAP.get(anim_key, "")
	if anim_name == "" or _anim_player == null:
		return
	if not _anim_player.has_animation(anim_name):
		return
	_anim_player.play(anim_name, -1, speed)
	if _anim_player.is_playing():
		_anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE

func _setup_states() -> void:
	_states = {
		StateType.IDLE: IdleState.new(),
		StateType.WALK: WalkState.new(),
		StateType.RUN: RunState.new(),
		StateType.JUMP: JumpState.new(),
	}
	for s in _states.values():
		s.model = self

func _change_state(type: StateType) -> void:
	if _current:
		_current.exit()
	_current = _states[type]
	if _current:
		_current.enter()

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
