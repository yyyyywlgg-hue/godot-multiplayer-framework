extends Control

@onready var _host_button = $VBoxContainer/HostButton
@onready var _client_button = $VBoxContainer/ClientButton
@onready var _steam_id_input = $VBoxContainer/SteamIDInput
@onready var _back_button = $VBoxContainer/BackButton
@onready var _status_label = $VBoxContainer/StatusLabel

func _ready():
	NetworkManager.set_selected_network(NetworkManager.AvailableNetworks.STEAM)
	
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		_status_label.text = "WARNING: SteamMultiplayerPeer not found!\nThe Steam GDExtension needs to be compiled.\nSee addons/steam-multiplayer-peer/README.md"
		_host_button.disabled = true
		_client_button.disabled = true
	
	_host_button.pressed.connect(_on_host_pressed)
	_client_button.pressed.connect(_on_client_pressed)
	_back_button.pressed.connect(_on_back_pressed)

func _on_host_pressed():
	var configs = NetworkConnectionConfigs.new()
	NetworkManager.host_game(configs)

func _on_client_pressed():
	var steam_id_str = _steam_id_input.text.strip_edges()
	if steam_id_str.is_empty():
		_status_label.text = "Please enter the host's Steam ID."
		return
	
	var steam_id = int(steam_id_str)
	if steam_id == 0:
		_status_label.text = "Invalid Steam ID."
		return
	
	var configs = NetworkConnectionConfigs.for_steam(steam_id)
	NetworkManager.join_game(configs)

func _on_back_pressed():
	NetworkManager.reset_selected_network()
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
