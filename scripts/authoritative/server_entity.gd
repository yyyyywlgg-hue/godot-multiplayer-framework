extends Node3D
## ServerEntity — Base class for all server-authoritative entities.
## Only instantiated and simulated on the server.

class_name ServerEntity

var _owner_peer_id: int = 0
var _entity_type: String = ""

## Called by ServerManager when entity is spawned
func _server_init(spawn_data: Dictionary):
	_owner_peer_id = spawn_data.get("owner_id", 0)
	_entity_type = spawn_data.get("type", "")
	_setup_from_data(spawn_data)

## Override to configure entity from spawn data
func _setup_from_data(data: Dictionary):
	pass

## Called every physics frame on the server
func _server_tick(delta: float, tick: int):
	pass

## Override to process client input (received via RPC)
func _on_client_input(input_data: Dictionary):
	pass

## Override to return the network state to sync to clients
func _get_network_state() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"rotation": [global_rotation.x, global_rotation.y, global_rotation.z],
	}
