class_name MainMenu
extends Control

## Entry scene — connects UI view signals to NetworkManager (the bridge layer).

@export var host_game_button: Button
@export var join_game_button: Button
@export var direct_ip_button: Button

const ROOM_MENU = preload("res://scenes/menus/room_menu.tscn")
const ENET_MENU = preload("res://scenes/menus/enet_menu.tscn")
const POPUP = preload("res://scenes/popups/base_popup.tscn")
const DEFAULT_PORT := 8080

func _ready():
	print("Main menu ready...")
	NetworkManager.connection_failed.connect(_on_connection_failed)

	if OS.has_feature("dedicated_server"):
		NetworkManager.host_game(NetworkConnectionConfigs.new("127.0.0.1"))
		return

func create_room():
	NetworkManager.set_selected_network(NetworkManager.AvailableNetworks.ROOM)
	var view = await UI.open(ROOM_MENU, {"is_hosting": true})
	if view:
		view.host_requested.connect(_on_host)

func join_room():
	NetworkManager.set_selected_network(NetworkManager.AvailableNetworks.ROOM)
	var view = await UI.open(ROOM_MENU, {"is_hosting": false})
	if view:
		view.join_requested.connect(_on_join)

func direct_ip():
	NetworkManager.set_selected_network(NetworkManager.AvailableNetworks.ENET)
	var view = await UI.open(ENET_MENU, {"is_hosting": false})
	if view:
		view.join_requested.connect(_on_join)

func _on_host(_unused = null):
	var configs = NetworkConnectionConfigs.new("127.0.0.1")
	configs.host_port = DEFAULT_PORT
	NetworkManager.host_game(configs)

func _on_join(ip: String, port: int):
	var configs = NetworkConnectionConfigs.new(ip)
	configs.host_port = port
	NetworkManager.join_game(configs)

func _on_connection_failed(reason: String):
	var popup = UI.overlay(POPUP)
	if popup:
		popup.setup_ok("Connection Failed", reason)

func exit_game():
	get_tree().quit(0)
