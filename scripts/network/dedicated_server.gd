extends Node

## Dedicated server launcher.
## Run with standard Godot: godot --headless -- dedicated_server
##
## Supports flags:
##   --port <N>        Server port (default: 10567)
##   --max-players <N> Max players (default: 32)

const DEFAULT_PORT = 10567
const DEFAULT_MAX_PLAYERS = 32

func _ready():
	print("=".repeat(50))
	print("  Godot 3D Multiplayer — Authoritative Dedicated Server")
	print("  Powered by: netfox + steam-multiplayer-peer")
	print("=".repeat(50))

	var args = OS.get_cmdline_args()
	var port = DEFAULT_PORT
	var max_players = DEFAULT_MAX_PLAYERS

	for i in range(args.size()):
		if args[i] == "--port" and i + 1 < args.size():
			port = int(args[i + 1])
		elif args[i] == "--max-players" and i + 1 < args.size():
			max_players = int(args[i + 1])

	print("Starting authoritative server on port %d (max %d players)..." % [port, max_players])

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, max_players)

	if error != OK:
		printerr("Failed to create server: %d" % error)
		get_tree().quit(1)
		return

	multiplayer.multiplayer_peer = peer
	print("Server started! Authoritative simulation active.")
	print("Listening on port %d — waiting for players..." % port)

	# Load game scene — ServerManager and MultiplayerManager handle the rest
	get_tree().change_scene_to_file("res://scenes/game.tscn")
