extends Node3D
## ClientEntity — Base class for client-side representation of server entities.
## Applies server state and does local interpolation/prediction.

class_name ClientEntity

var _entity_id: int = 0
var _target_state: Dictionary = {}
var _current_state: Dictionary = {}

## Called by ClientManager when entity is created locally
func _client_init(entity_id: int, spawn_data: Dictionary):
	_entity_id = entity_id
	_setup_from_data(spawn_data)

func _setup_from_data(data: Dictionary):
	pass

## Apply authoritative state from server snapshot
func _apply_server_state(state: Dictionary):
	_target_state = state
	
	# Smoothly interpolate position
	if state.has("position"):
		var pos = state["position"]
		var target_pos = Vector3(pos[0], pos[1], pos[2])
		global_position = global_position.lerp(target_pos, 0.3)
	
	if state.has("rotation"):
		var rot = state["rotation"]
		var target_rot = Vector3(rot[0], rot[1], rot[2])
		global_rotation = global_rotation.lerp(target_rot, 0.3)
