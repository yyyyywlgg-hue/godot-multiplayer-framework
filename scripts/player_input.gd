class_name PlayerInput
extends Node

var _direction: Vector3 = Vector3.ZERO
var _wants_jump: bool = false
var _input_timer: float = 0.0
const _INPUT_RATE: float = 1.0 / 30.0
var _is_local: bool = false

func _ready():
	_refresh_local()

	var camera = get_parent().get_node_or_null("Camera3D")
	if camera:
		camera.current = _is_local

func _refresh_local():
	var my_id = multiplayer.get_unique_id()
	var entity_name = str(get_parent().name)
	_is_local = (entity_name == str(my_id))
	print("PlayerInput: my_id=%d, entity=%s, is_local=%s" % [my_id, entity_name, _is_local])

func _process(delta):
	if not _is_local:
		return
	if not multiplayer.multiplayer_peer:
		return

	_direction = Vector3.ZERO
	if Input.is_action_pressed("forward"):   _direction.z -= 1.0
	if Input.is_action_pressed("backward"):  _direction.z += 1.0
	if Input.is_action_pressed("left"):      _direction.x -= 1.0
	if Input.is_action_pressed("right"):     _direction.x += 1.0
	_direction = _direction.normalized()

	if Input.is_action_just_pressed("jump"):
		_wants_jump = true

	_input_timer += delta
	if _input_timer >= _INPUT_RATE:
		_input_timer -= _INPUT_RATE
		_send_input()

func _send_input():
	if not multiplayer.multiplayer_peer:
		return

	var data := {
		"direction_x": _direction.x,
		"direction_z": _direction.z,
		"jump": _wants_jump,
		"run": Input.is_action_pressed("run")
	}
	_wants_jump = false

	if multiplayer.is_server():
		get_parent()._on_client_input(data)
	else:
		_send_input_rpc.rpc_id(1, data)

@rpc("any_peer", "unreliable_ordered")
func _send_input_rpc(data: Dictionary):
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var mm = NetworkManager._get_multiplayer_manager()
	if mm:
		var player = mm.get_player(sender_id)
		if player and is_instance_valid(player) and player.has_method("_on_client_input"):
			player._on_client_input(data)
