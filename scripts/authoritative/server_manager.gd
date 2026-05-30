extends Node
## ServerManager — Authoritative game logic singleton.
## MultiplayerSpawner handles entity replication; this handles input routing & validation.

signal player_joined(peer_id: int)
signal player_left(peer_id: int)

func _ready():
	if not multiplayer.is_server():
		return
	print("ServerManager: Authoritative server active")
	multiplayer.peer_connected.connect(func(id): player_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id): player_left.emit(id))
