extends Control

signal secondary_menu_completed(network_connection_configs: NetworkConnectionConfigs)
signal secondary_menu_cancelled

## Noray relay server — change this to your public server IP when deploying
const NORAY_SERVER := "127.0.0.1"

@onready var _code_input: LineEdit = $VBoxContainer/CodeInput
@onready var _go_button: Button = $VBoxContainer/GoButton
@onready var _back_button: Button = $VBoxContainer/BackButton
@onready var _status_label: Label = $VBoxContainer/StatusLabel

var menu_config_options: Dictionary = {}
var _is_hosting: bool = false

func _ready():
	_go_button.pressed.connect(_on_go)
	_back_button.pressed.connect(_on_back)
	_code_input.text_submitted.connect(_on_go)

	if menu_config_options.get("is_hosting", false):
		_is_hosting = true
		_code_input.visible = false
		_status_label.text = ""
		_go_button.text = "Create Room"
	else:
		_is_hosting = false
		_code_input.visible = true
		_code_input.placeholder_text = "Room code"
		_status_label.text = "Enter room code shared by host:"
		_go_button.text = "Join Room"
		_code_input.grab_focus()

func _on_go(_unused = null):
	if _is_hosting:
		var configs = NetworkConnectionConfigs.new(NORAY_SERVER)
		secondary_menu_completed.emit(configs)
		return

	var code = _code_input.text.strip_edges()
	if code == "":
		_status_label.text = "[color=red]Please enter a room code.[/color]"
		return

	var configs = NetworkConnectionConfigs.new(NORAY_SERVER)
	configs.game_id = code
	secondary_menu_completed.emit(configs)

func _on_back():
	secondary_menu_cancelled.emit()
