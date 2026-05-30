class_name InGameMenu
extends UIView

## In-game pause menu overlay. Toggle with in-game-menu action (ESC).
## Can be opened via UIManager.overlay() or instanced directly in game.tscn.

signal resume_pressed
signal disconnect_pressed
signal quit_pressed
signal copy_ip_pressed(ip: String)
signal copy_game_id_pressed(game_id: String)

@export var active_host_label: RichTextLabel
@export var game_id_label: RichTextLabel

var _host_ip: String = ""
var _game_id: String = ""

func set_data(data: Dictionary) -> void:
	_host_ip = data.get("host_ip", "")
	_game_id = data.get("game_id", "")

func _on_will_open() -> void:
	# If data wasn't set via set_data, read from NetworkManager (scene-instanced path)
	if _host_ip == "":
		_host_ip = NetworkManager.active_host_ip
	if _game_id == "":
		_game_id = NetworkManager.active_game_id
	
	active_host_label.text = _host_ip
	game_id_label.text = _game_id
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_close() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	super._on_close()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("in-game-menu"):
		if _is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	super._input(event)

func _on_resume_pressed() -> void:
	resume_pressed.emit()
	close()

func _on_main_menu_pressed():
	disconnect_pressed.emit()
	close()

func _on_quit_pressed() -> void:
	quit_pressed.emit()

func _on_copy_ip_pressed():
	copy_ip_pressed.emit(_host_ip)

func _on_copy_game_id_pressed():
	copy_game_id_pressed.emit(_game_id)
