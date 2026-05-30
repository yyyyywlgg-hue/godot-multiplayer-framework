class_name SteamNetwork
extends Node

## Steam Multiplayer Peer network adapter.
## Requires steam-multiplayer-peer GDExtension to be compiled and the Steam SDK placed in the addons directory.

var _steam_peer = null

signal network_server_disconnected

func create_server_peer(configs: NetworkConnectionConfigs):
	print("SteamNetwork: Creating Steam server peer...")
	_steam_peer = _create_steam_peer()
	if _steam_peer == null:
		push_error("SteamNetwork: SteamMultiplayerPeer not available. Is the GDExtension compiled and Steam running?")
		return
	
	# Steam uses Steam IDs, not IP/port
	_steam_peer.create_host()
	multiplayer.multiplayer_peer = _steam_peer
	print("SteamNetwork: Server created via Steam Sockets")

func create_client_peer(configs: NetworkConnectionConfigs):
	print("SteamNetwork: Creating Steam client peer...")
	_steam_peer = _create_steam_peer()
	if _steam_peer == null:
		push_error("SteamNetwork: SteamMultiplayerPeer not available.")
		return
	
	# Connect to host via Steam ID
	_steam_peer.create_client(configs.steam_host_id)
	multiplayer.multiplayer_peer = _steam_peer
	
	_steam_peer.connection_failed.connect(_on_connection_failed)
	print("SteamNetwork: Client connecting via Steam Sockets to ID: %s" % configs.steam_host_id)

func _create_steam_peer():
	if ClassDB.class_exists("SteamMultiplayerPeer"):
		return SteamMultiplayerPeer.new()
	else:
		push_warning("SteamNetwork: SteamMultiplayerPeer class not found. Steam GDExtension may not be loaded.")
		return null

func _on_connection_failed():
	print("SteamNetwork: Connection failed")
	network_server_disconnected.emit()
