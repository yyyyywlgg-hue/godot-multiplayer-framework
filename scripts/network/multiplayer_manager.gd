class_name MultiplayerManager
extends Node

@export var _player_spawn_point: Node3D
@export var _authoritative_player_scene: PackedScene

var _players_in_game: Dictionary = {}
var _sync_timer: float = 0.0

const _SYNC_RATE: float = 1.0 / 20.0

func _ready():
	print("MultiplayerManager ready!")
	if not multiplayer.multiplayer_peer:
		return

	NetworkManager.hide_loading()

	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		if not OS.has_feature("dedicated_server"):
			_spawn_player_local(1)
	else:
		if Engine.has_singleton("NetworkTime"): Engine.get_singleton("NetworkTime").stop()
		_client_ready.rpc_id(1)

func _process(delta):
	if not multiplayer.multiplayer_peer:
		return
	if not multiplayer.is_server():
		return

	_sync_timer += delta
	if _sync_timer >= _SYNC_RATE:
		_sync_timer = fmod(_sync_timer, _SYNC_RATE)
		_sync_to_clients()

func _sync_to_clients():
	var states := {}
	for peer_id in _players_in_game:
		var p = _players_in_game[peer_id]
		if is_instance_valid(p):
			states[peer_id] = {
				"p": p.position,
				"v": p.velocity,
				"f": p.is_on_floor(),
				"r": p._is_running
			}
	if states.is_empty():
		return
	NetworkManager.broadcast_player_states(states)

func get_player(peer_id: int):
	return _players_in_game.get(peer_id)

func remove_player(peer_id: int):
	if _players_in_game.has(peer_id):
		var p = _players_in_game[peer_id]
		if is_instance_valid(p):
			p.queue_free()
		_players_in_game.erase(peer_id)

func _on_peer_connected(peer_id: int):
	print("Peer %d connected" % peer_id)

func _on_peer_disconnected(peer_id: int):
	print("Peer %d disconnected" % peer_id)
	if _players_in_game.has(peer_id):
		_remove_player_local(peer_id)
		NetworkManager.broadcast_despawn(peer_id)

func _remove_player_local(peer_id: int):
	if _players_in_game.has(peer_id):
		var p = _players_in_game[peer_id]
		if is_instance_valid(p):
			p.queue_free()
		_players_in_game.erase(peer_id)

@rpc("any_peer", "call_remote", "reliable")
func _client_ready():
	if not multiplayer.is_server():
		return
	var new_id = multiplayer.get_remote_sender_id()
	print("Client %d is ready, spawning new player" % new_id)
	_spawn_player_local(new_id)

	for pid in _players_in_game:
		var p = _players_in_game[pid]
		if is_instance_valid(p):
			_spawn_on_client.rpc_id(new_id, pid, p.position, p.velocity, p.is_on_floor(), p._is_running)

func _spawn_player_local(peer_id: int):
	if _players_in_game.has(peer_id):
		return
	if not _authoritative_player_scene or not _player_spawn_point:
		return
	var player = _authoritative_player_scene.instantiate()
	player.name = str(peer_id)
	player.position = Vector3(randi_range(-3, 3), 1.0, randi_range(-3, 3))
	_player_spawn_point.add_child(player, true)
	_players_in_game[peer_id] = player
	print("Server: spawned player for peer %d" % peer_id)

@rpc("authority", "call_remote", "reliable")
func _spawn_on_client(peer_id: int, pos: Vector3, vel: Vector3 = Vector3.ZERO, on_floor: bool = true, running: bool = false):
	if _players_in_game.has(peer_id):
		return
	var player = _authoritative_player_scene.instantiate()
	player.name = str(peer_id)
	player.position = pos
	player._target_position = pos
	player._synced_velocity = vel
	player._synced_is_on_floor = on_floor
	player._synced_is_running = running
	var spawn_point = get_node_or_null("/root/Game/World/PlayerSpawnPoint")
	if not spawn_point:
		spawn_point = get_node_or_null("../World/PlayerSpawnPoint")
	if spawn_point:
		spawn_point.add_child(player, true)
	else:
		printerr("MultiplayerManager: PlayerSpawnPoint not found on client!")
		add_child(player)
	_players_in_game[peer_id] = player
	print("Client: spawned player %d" % peer_id)
