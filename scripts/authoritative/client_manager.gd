extends Node
## ClientManager — Client-side prediction and state reconciliation singleton.
## Receives snapshots from the server, interpolates remote entities,
## and manages client-side prediction for the local player.

# ClientManager — accessed as autoload singleton

signal connected_to_server
signal disconnected_from_server

var _local_entities: Dictionary = {}       # entity_id -> ClientEntity
var _pending_inputs: Array[Dictionary] = [] # inputs awaiting server ack
var _last_snapshot_tick: int = 0
var _server_connection: ENetMultiplayerPeer = null

func _ready():
	pass

## Connect to an authoritative server
func connect_to_server(address: String, port: int):
	print("ClientManager: Connecting to %s:%d" % [address, port])
	_server_connection = ENetMultiplayerPeer.new()
	var err = _server_connection.create_client(address, port)
	if err != OK:
		printerr("ClientManager: Failed to connect: %d" % err)
		return
	
	multiplayer.multiplayer_peer = _server_connection
	connected_to_server.emit()

## Send input to the server for validation
func send_input(input_data: Dictionary):
	input_data["timestamp"] = Time.get_ticks_msec()
	_pending_inputs.append(input_data)
	ServerManager._receive_client_input.rpc(input_data)

## Server calls this to spawn an entity locally on the client
func _spawn_entity_local(scene_path: String, entity_id: int, spawn_data: Dictionary):
	var scene = load(scene_path)
	if scene == null:
		printerr("ClientManager: Failed to load scene: %s" % scene_path)
		return
	
	var entity = scene.instantiate()
	entity.name = "ClientEntity_%d" % entity_id
	entity._client_init(entity_id, spawn_data)
	
	_local_entities[entity_id] = entity
	add_child(entity)

## Server calls this to despawn an entity locally on the client
func _despawn_entity_local(entity_id: int):
	if _local_entities.has(entity_id):
		var entity = _local_entities[entity_id]
		if is_instance_valid(entity):
			entity.queue_free()
		_local_entities.erase(entity_id)

## Server calls this to send state snapshots
func _receive_snapshot(snapshot: Dictionary):
	_last_snapshot_tick = snapshot.get("tick", 0)
	var entity_states: Dictionary = snapshot.get("entities", {})
	
	for entity_id in entity_states:
		if _local_entities.has(entity_id):
			var entity = _local_entities[entity_id]
			if is_instance_valid(entity):
				entity._apply_server_state(entity_states[entity_id])
	
	# Prune old inputs — the server processed them
	_prune_acknowledged_inputs(_last_snapshot_tick)

func _prune_acknowledged_inputs(server_tick: int):
	# Remove inputs older than what the server has processed
	# In practice, the server would include last_processed_input in the snapshot
	while _pending_inputs.size() > 60: # Keep a reasonable buffer
		_pending_inputs.pop_front()

func _on_server_disconnected():
	print("ClientManager: Disconnected from server")
	disconnected_from_server.emit()
	multiplayer.multiplayer_peer = null
	_server_connection = null
