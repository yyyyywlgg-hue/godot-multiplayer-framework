class_name BasePopup
extends UIView

## Base popup — extends UIView for fade transitions.
## Override _on_open() to configure content.
## Use setup_ok(title, body) for simple message dialogs.

signal dismissed

@onready var _panel: Panel = $Panel
@onready var _title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var _body_label: Label = $Panel/VBoxContainer/BodyLabel
@onready var _button_container: HBoxContainer = $Panel/VBoxContainer/ButtonContainer

var _auto_dismiss := true

func add_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	_button_container.add_child(btn)
	return btn

func setup_ok(title: String, body: String) -> Button:
	_title_label.text = title
	_body_label.text = body
	return add_button("OK", _on_dismiss)

func _on_dismiss():
	dismissed.emit()
	if _auto_dismiss:
		close()

func _on_close():
	super._on_close()
	queue_free()
