extends Node

signal network_client_connected
signal network_server_disconnected
signal network_client_failed

const SERVER_PORT = 8080

var _upnp: UPNPManager = null
var _is_upnp_active: bool = false

func create_server_peer(network_connection_configs: NetworkConnectionConfigs):
	# Try UPnP port mapping for NAT traversal
	_upnp = UPNPManager.new()
	_is_upnp_active = _upnp.open_port(SERVER_PORT, "Godot 3D Multiplayer")
	
	if _is_upnp_active:
		print("ENet: UPnP enabled! Public IP: %s, Port: %d" % [_upnp.get_public_ip(), SERVER_PORT])
	else:
		print("ENet: UPnP failed. LAN / direct IP only.")
	
	var enet_network_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err = enet_network_peer.create_server(SERVER_PORT)
	if err != OK:
		printerr("ENet: create_server failed with error %d — port %d may be in use. Try again in a moment." % [err, SERVER_PORT])
		_cleanup_upnp()
		return
	
	multiplayer.multiplayer_peer = enet_network_peer
	print("ENet: Server listening on port %d" % SERVER_PORT)

func create_client_peer(network_connection_configs: NetworkConnectionConfigs):
	setup_client_connection_signals()
	
	var enet_network_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err = enet_network_peer.create_client(network_connection_configs.host_ip, network_connection_configs.host_port)
	if err != OK:
		print("ENet: create_client failed with error %d for %s:%d" % [err, network_connection_configs.host_ip, network_connection_configs.host_port])
		network_client_failed.emit()
		return
	
	multiplayer.multiplayer_peer = enet_network_peer

func get_public_ip() -> String:
	if _upnp and _is_upnp_active:
		return _upnp.get_public_ip()
	return ""

func is_upnp_active() -> bool:
	return _is_upnp_active

func _connected_to_server():
	print("Client connected to server/host, on peer %s" % multiplayer.get_unique_id())
	network_client_connected.emit()

func _server_disconnected():
	print("Server disconnected!")
	network_server_disconnected.emit()
	_cleanup_upnp()

func setup_client_connection_signals():
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.server_disconnected.connect(_server_disconnected)

func _cleanup_upnp():
	if _upnp:
		_upnp.close_port()
		_upnp = null
	_is_upnp_active = false

func _exit_tree():
	_cleanup_upnp()
