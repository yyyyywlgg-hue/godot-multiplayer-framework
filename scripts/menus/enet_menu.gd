class_name EnetMenu
extends UIView

## Direct IP connect menu. Emits signals for caller to handle networking.

signal join_requested(ip: String, port: int)
signal host_requested(port: int)
signal cancelled

@export var go_button: Button
@export var back_button: Button
@export var host_ip_input: LineEdit
@export var host_port_input: LineEdit
@export var option_label: RichTextLabel

var _is_hosting: bool = false

func set_data(data: Dictionary) -> void:
	_is_hosting = data.get("is_hosting", false)

func _on_will_open() -> void:
	go_button.pressed.connect(_on_go_pressed)
	back_button.pressed.connect(_on_back_pressed)

	if _is_hosting:
		option_label.text = "[b]Host Game[/b]\nShare your IP and port with friends:"
		host_ip_input.visible = false
	else:
		option_label.text = "[b]Join Game[/b]\nEnter host IP and port:"

func _on_go_pressed():
	var port_str = host_port_input.text.strip_edges()
	if port_str == "":
		return
	var port = int(port_str)

	if _is_hosting:
		host_requested.emit(port)
		close()
		return

	var ip = host_ip_input.text.strip_edges()
	if ip == "":
		return
	join_requested.emit(ip, port)

func _on_back_pressed():
	cancelled.emit()
	close()

func _on_close():
	super._on_close()
