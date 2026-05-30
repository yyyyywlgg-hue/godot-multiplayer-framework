extends Node

signal connection_failed(reason: String)

enum GameState { MENU, LOBBY, IN_GAME }

const GAME_SCENE = "res://scenes/game.tscn"
const LOBBY_SCENE = "res://scenes/lobby.tscn"
const MAIN_MENU_SCENE = "res://scenes/menus/main_menu.tscn"
const DEDICATED_SERVER_FEATURE_NAME = "dedicated_server"
const CONNECT_TIMEOUT := 5.0

enum AvailableNetworks {ROOM, ENET, NORAY, STEAM}

var _available_networks: Dictionary = {
	0: {"scene":"res://scenes/network/enet_network.tscn", "menu":"res://scenes/menus/room_menu.tscn"},
	1: {"scene":"res://scenes/network/enet_network.tscn", "menu":"res://scenes/menus/enet_menu.tscn"},
	2: {"scene":"res://scenes/network/noray_network.tscn", "menu":"res://scenes/menus/noray_menu.tscn"},
	3: {"scene":"res://scenes/network/steam_network.tscn", "menu":"res://scenes/menus/steam_menu.tscn"}
}

var selected_network: AvailableNetworks = AvailableNetworks.ROOM
var selected_network_configuration: Dictionary = _available_networks[0]
var game_state: GameState = GameState.MENU

var _loading_scene = preload("res://scenes/loading.tscn")
var _active_loading_scene
var active_network_node
var is_hosting_game = false
var active_host_ip = ""
var active_game_id = ""

# --- Position sync ---

func broadcast_player_states(states: Dictionary):
	_broadcast_player_states_rpc.rpc(states)

@rpc("authority", "call_remote", "unreliable_ordered")
func _broadcast_player_states_rpc(states: Dictionary):
	var mm = _get_multiplayer_manager()
	if not mm:
		return
	for peer_id in states:
		var p = mm.get_player(peer_id)
		if p and is_instance_valid(p):
			p.apply_remote_state(states[peer_id])

# --- Despawn sync ---

func broadcast_despawn(peer_id: int):
	_despawn_clients_rpc.rpc(peer_id)

@rpc("authority", "call_remote", "reliable")
func _despawn_clients_rpc(peer_id: int):
	var mm = _get_multiplayer_manager()
	if not mm:
		return
	mm.remove_player(peer_id)

func _get_multiplayer_manager():
	var game = get_tree().root.get_node_or_null("Game")
	if game:
		return game.get_node_or_null("MultiplayerManager")
	return null

# --- Host / Join ---

func host_game(network_connection_configs: NetworkConnectionConfigs):
	print("Host game via %s" % AvailableNetworks.keys()[selected_network])
	if not OS.has_feature(DEDICATED_SERVER_FEATURE_NAME):
		show_loading()

	is_hosting_game = true
	active_host_ip = network_connection_configs.host_ip

	var network_scene = load(selected_network_configuration.scene)
	active_network_node = network_scene.instantiate()
	add_child(active_network_node)

	await active_network_node.create_server_peer(network_connection_configs)

	if not multiplayer.multiplayer_peer:
		printerr("NetworkManager: Failed to create server!")
		hide_loading()
		connection_failed.emit("Failed to create server. Port may be in use.")
		return

	game_state = GameState.LOBBY
	_load_lobby_scene()

func join_game(network_connection_configs: NetworkConnectionConfigs):
	print("Join game via %s to %s:%d" % [AvailableNetworks.keys()[selected_network], network_connection_configs.host_ip, network_connection_configs.host_port])
	show_loading()

	var network_scene = load(selected_network_configuration.scene)
	active_network_node = network_scene.instantiate()
	add_child(active_network_node)

	if active_network_node.has_signal("network_client_failed"):
		active_network_node.network_client_failed.connect(_on_client_failed)
	active_network_node.network_server_disconnected.connect(_on_server_disconnected)

	active_network_node.create_client_peer(network_connection_configs)

	var elapsed := 0.0
	while elapsed < CONNECT_TIMEOUT:
		await get_tree().create_timer(0.3).timeout
		elapsed += 0.3

		if game_state != GameState.MENU:
			return

		var peer = multiplayer.multiplayer_peer
		if peer == null:
			continue

		var status = peer.get_connection_status()
		if status == MultiplayerPeer.CONNECTION_CONNECTED:
			var uid = multiplayer.get_unique_id()
			print("NetworkManager: Connected as peer %d" % uid)
			_request_game_state.rpc_id(1)
			var reply_timer = get_tree().create_timer(CONNECT_TIMEOUT - elapsed)
			await reply_timer.timeout
			if game_state == GameState.MENU:
				print("NetworkManager: No reply from server!")
				_on_join_failed()
			return

		if status == MultiplayerPeer.CONNECTION_DISCONNECTED:
			print("NetworkManager: Connection refused!")
			break

	print("NetworkManager: Connection failed (timeout)!")
	_on_join_failed()

func _on_client_failed():
	print("NetworkManager: Client connection failed immediately!")
	_on_join_failed()

func _on_join_failed():
	hide_loading()
	game_state = GameState.MENU
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if active_network_node:
		active_network_node.queue_free()
		active_network_node = null
	reset_selected_network()
	reset_network_properties()
	connection_failed.emit("Invalid room code")
	_load_main_menu_scene()

func _on_server_disconnected():
	print("NetworkManager: Server disconnected!")
	if game_state == GameState.MENU:
		return
	disconnect_from_game()

# --- RPCs ---

@rpc("any_peer", "call_remote", "reliable")
func _request_game_state():
	var requester = multiplayer.get_remote_sender_id()
	_reply_game_state.rpc_id(requester, game_state)

@rpc("authority", "call_remote", "reliable")
func _reply_game_state(state: int):
	var gs = state as GameState
	print("Client: server reports game_state=%s" % GameState.keys()[gs])
	game_state = gs

	if gs == GameState.IN_GAME:
		_load_game_scene()
	else:
		_load_lobby_scene()

func enter_game_state():
	game_state = GameState.IN_GAME
	_load_game_scene()

func set_selected_network(network_selected: AvailableNetworks):
	selected_network = network_selected
	selected_network_configuration = _available_networks[network_selected]

func disconnect_from_game():
	if Engine.has_singleton("NetworkTime"):
		Engine.get_singleton("NetworkTime").stop()

	multiplayer.multiplayer_peer = null
	game_state = GameState.MENU

	for child in get_children():
		child.queue_free()

	reset_selected_network()
	reset_network_properties()

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	hide_loading()
	_load_main_menu_scene()

func reset_network_properties():
	is_hosting_game = false
	active_host_ip = ""
	active_game_id = ""
	if active_network_node:
		active_network_node.queue_free()
		active_network_node = null

func reset_selected_network():
	selected_network = AvailableNetworks.ROOM
	selected_network_configuration = _available_networks[0]

func _load_lobby_scene():
	UI.clear()
	print("NetworkManager: Loading lobby...")
	SceneManager.change_scene_instant(LOBBY_SCENE)

func _load_game_scene():
	UI.clear()
	print("NetworkManager: Loading game scene...")
	SceneManager.change_scene_instant(GAME_SCENE)

func _load_main_menu_scene():
	SceneManager.change_scene_instant(MAIN_MENU_SCENE)

func show_loading():
	print("Show loading")
	_active_loading_scene = _loading_scene.instantiate()
	get_tree().root.add_child(_active_loading_scene)

func hide_loading():
	print("Hide loading")
	if _active_loading_scene != null and is_instance_valid(_active_loading_scene):
		get_tree().root.remove_child(_active_loading_scene)
		_active_loading_scene.queue_free()
		_active_loading_scene = null
