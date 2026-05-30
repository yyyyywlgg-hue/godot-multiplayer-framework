class_name RoomMenu
extends UIView

## Room code / host menu. Emits signals for caller to handle networking.

signal host_requested
signal join_requested(ip: String, port: int)
signal cancelled

@onready var _code_input: LineEdit = $VBoxContainer/CodeInput
@onready var _go_button: Button = $VBoxContainer/GoButton
@onready var _back_button: Button = $VBoxContainer/BackButton
@onready var _status_label: Label = $VBoxContainer/StatusLabel

var _is_hosting: bool = false

func set_data(data: Dictionary) -> void:
	_is_hosting = data.get("is_hosting", false)

func _on_will_open() -> void:
	_go_button.pressed.connect(_on_go)
	_back_button.pressed.connect(_on_back)
	_code_input.text_submitted.connect(_on_go)

	if _is_hosting:
		_code_input.visible = false
		_go_button.text = "Create Room"
		_status_label.text = ""
	else:
		_code_input.visible = true
		_go_button.text = "Join Room"
		_status_label.text = "Enter room code:"
		_code_input.grab_focus()

func _on_go(_unused = null):
	if _is_hosting:
		host_requested.emit()
		close()
		return

	var code = _code_input.text.strip_edges().to_upper()
	if code == "":
		return

	var ip: String
	var port: int
	var info = RoomCode.decode(code)
	
	if info.is_empty():
		# Raw IP input
		ip = code
		port = 8080
	else:
		ip = info["ip"]
		port = info["port"]

	_go_button.disabled = true
	_status_label.text = "Connecting..."
	join_requested.emit(ip, port)
	close()

func _on_back():
	cancelled.emit()
	close()

func _on_close():
	super._on_close()
