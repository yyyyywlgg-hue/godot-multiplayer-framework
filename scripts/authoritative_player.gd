class_name AuthoritativePlayer
extends CharacterBody3D

@export var move_speed: float = 5.0
@export var jump_velocity: float = 8.0
@export var gravity: float = 20.0
@export var remote_smooth_rate: float = 15.0

var _input_direction: Vector3 = Vector3.ZERO
var _wants_jump: bool = false
var _is_running: bool = false
var _target_position: Vector3
var _synced_velocity: Vector3 = Vector3.ZERO
var _synced_is_on_floor: bool = true
var _synced_is_running: bool = false

@onready var _model: CharacterModel = $CharacterModel

func _ready():
	print("AuthoritativePlayer ready, name=%s, is_server=%s" % [name, multiplayer.is_server()])
	if not multiplayer.is_server():
		set_physics_process(false)
		_target_position = position

func _physics_process(delta):
	if not multiplayer.is_server():
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	var horizontal = _input_direction * move_speed
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if _wants_jump and is_on_floor():
		velocity.y = jump_velocity

	_wants_jump = false
	move_and_slide()
	_on_physics_tick(delta)

func _on_physics_tick(_delta: float) -> void:
	pass

func _process(delta):
	if not multiplayer.multiplayer_peer:
		return
	if multiplayer.is_server():
		return
	position = position.lerp(_target_position, minf(delta * remote_smooth_rate, 1.0))

func apply_remote_state(state: Dictionary):
	_target_position = state.get("p", position)
	_synced_velocity = state.get("v", Vector3.ZERO)
	_synced_is_on_floor = state.get("f", true)
	_synced_is_running = state.get("r", false)
	if position.distance_squared_to(_target_position) > 25.0:
		position = _target_position

func get_effective_velocity() -> Vector3:
	if multiplayer.is_server():
		return velocity
	return _synced_velocity

func get_effective_is_on_floor() -> bool:
	if multiplayer.is_server():
		return is_on_floor()
	return _synced_is_on_floor

func get_effective_is_running() -> bool:
	if multiplayer.is_server():
		return _is_running
	return _synced_is_running

func _on_client_input(input_data: Dictionary):
	_input_direction = Vector3(
		input_data.get("direction_x", 0.0),
		0.0,
		input_data.get("direction_z", 0.0)
	)
	_wants_jump = input_data.get("jump", false)
	_is_running = input_data.get("run", false)
