extends Control

signal leave_pressed
signal start_game_pressed

class PlayerState:
	var peer_id: int
	var ready: bool = false
	func _init(id: int): peer_id = id
	func display_name() -> String: return "Player %d %s" % [peer_id, "✓" if ready else "..."]

@onready var _player_list: ItemList = $VBoxContainer/PlayerList
@onready var _start_button: Button = $VBoxContainer/StartButton
@onready var _ready_button: Button = $VBoxContainer/ReadyButton
@onready var _leave_button: Button = $VBoxContainer/LeaveButton
@onready var _status_label: Label = $VBoxContainer/StatusLabel
@onready var _room_code_label: Label = $VBoxContainer/RoomCodeLabel

var _players: Dictionary = {}

func _ready():
	print("Lobby ready, is_server=%s, peer_id=%d" % [multiplayer.is_server(), multiplayer.get_unique_id()])
	NetworkManager.hide_loading()
	_leave_button.pressed.connect(_on_leave)
	start_game_pressed.connect(_on_start_game_impl)

	if multiplayer.is_server():
		_start_button.visible = true
		_start_button.disabled = true
		_start_button.pressed.connect(_on_host_start)
		_ready_button.visible = false
		multiplayer.peer_connected.connect(_on_peer_connected_host)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_add_player(1)
		_set_ready(1, true)
		_show_room_code()
		_update_start_button()
	else:
		_start_button.visible = false
		_ready_button.visible = true
		_ready_button.pressed.connect(_on_ready_toggled)
		_status_label.text = "Connected! Click Ready when ready."
		NetworkManager.game_state = NetworkManager.GameState.LOBBY
		_request_player_list.rpc_id(1)
		if Engine.has_singleton("NetworkTime"): Engine.get_singleton("NetworkTime").stop()

func _show_room_code():
	var enet_node = NetworkManager.active_network_node
	var pub_ip = ""
	if enet_node and enet_node.has_method("get_public_ip"):
		pub_ip = enet_node.get_public_ip()
	
	if pub_ip == "":
		var ips = IP.get_local_addresses()
		for ip in ips:
			if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
				pub_ip = ip
				break
		if pub_ip == "" and ips.size() > 0:
			pub_ip = ips[0]
	
	if pub_ip != "":
		var room_code = RoomCode.encode(pub_ip, 8080)
		_room_code_label.text = "Room: %s" % room_code
		if enet_node and enet_node.has_method("is_upnp_active") and not enet_node.is_upnp_active():
			_room_code_label.text += " (LAN)"
		_status_label.text = "Share this code with friends!"
	else:
		_room_code_label.text = "Room: ---"
		_status_label.text = "Could not determine IP"

func _on_peer_connected_host(peer_id: int):
	_add_player(peer_id)
	var data = _serialize_players()
	for pid in multiplayer.get_peers():
		if pid != peer_id:
			_sync_players.rpc_id(pid, data)
	_update_start_button()

func _on_peer_disconnected(peer_id: int):
	_players.erase(peer_id)
	_refresh_list()
	_sync_players.rpc(_serialize_players())
	_update_start_button()

func _add_player(peer_id: int):
	if not _players.has(peer_id):
		_players[peer_id] = PlayerState.new(peer_id)
	_refresh_list()

func _set_ready(peer_id: int, ready: bool):
	if _players.has(peer_id):
		_players[peer_id].ready = ready
	_refresh_list()

func _on_ready_toggled():
	var my_id = multiplayer.get_unique_id()
	var p: PlayerState = _players.get(my_id)
	var new_ready = not (p and p.ready)
	_toggle_ready.rpc_id(1, my_id, new_ready)
	_ready_button.text = "Ready ✓" if new_ready else "Ready?"

func _on_leave():
	leave_pressed.emit()
	NetworkManager.disconnect_from_game()

func _on_host_start():
	start_game_pressed.emit()

func _on_start_game_impl():
	print("Host starting game!")
	NetworkManager.game_state = NetworkManager.GameState.IN_GAME
	NetworkManager.show_loading()
	_start_game.rpc()
	await get_tree().create_timer(0.3).timeout
	SceneManager.change_scene_instant("res://scenes/game.tscn")

@rpc("any_peer", "call_remote", "reliable")
func _toggle_ready(peer_id: int, ready: bool):
	if multiplayer.is_server():
		_set_ready(peer_id, ready)
		_refresh_list()
		_sync_players.rpc(_serialize_players())
		_update_start_button()

@rpc("any_peer", "call_remote", "reliable")
func _request_player_list():
	if multiplayer.is_server():
		_reply_player_list.rpc_id(multiplayer.get_remote_sender_id(), _serialize_players())

@rpc("authority", "call_remote", "reliable")
func _reply_player_list(data: Dictionary):
	_deserialize_players(data)

func _update_start_button():
	if not multiplayer.is_server():
		return
	var all_ready = true
	for p in _players.values():
		if not p.ready:
			all_ready = false
			break
	var can_start = _players.size() >= 1 and all_ready
	_start_button.disabled = not can_start
	
	if can_start:
		_status_label.text = "%d player(s) — All ready!" % _players.size()
	elif _players.size() > 1:
		_status_label.text = "%d player(s) — Waiting..." % _players.size()

func _serialize_players() -> Dictionary:
	var data := {}
	for pid in _players:
		data[pid] = _players[pid].ready
	return data

func _deserialize_players(data: Dictionary):
	_players.clear()
	for pid in data:
		var p = PlayerState.new(int(pid))
		p.ready = data[pid]
		_players[int(pid)] = p
	_refresh_list()

@rpc("authority", "call_remote", "reliable")
func _sync_players(data: Dictionary):
	if not multiplayer.is_server():
		_deserialize_players(data)

func _refresh_list():
	_player_list.clear()
	for pid in _players:
		var p: PlayerState = _players[pid]
		_player_list.add_item(p.display_name())

@rpc("authority", "call_remote", "reliable")
func _start_game():
	print("Client: received start signal, loading game...")
	NetworkManager.show_loading()
	await get_tree().create_timer(0.3).timeout
	SceneManager.change_scene_instant("res://scenes/game.tscn")
