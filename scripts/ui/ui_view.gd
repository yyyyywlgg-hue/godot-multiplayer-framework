class_name UIView
extends Control

## Base class for all UI panels. Provides fade-in/out transitions.
## Override _on_open() / _on_close() for init/cleanup.
## Views emit signals for user intent — never call data services directly.

signal opened
signal closed

@export var transition_duration: float = 0.15
@export var close_on_back: bool = true

var _tween: Tween
var _is_open: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	modulate.a = 0.0
	hide()

func open() -> void:
	if _is_open:
		return
	_is_open = true
	show()
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, transition_duration)
	_tween.tween_callback(_on_open)
	_on_will_open()

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, transition_duration)
	_tween.tween_callback(_do_close)

func _do_close() -> void:
	hide()
	_on_close()
	closed.emit()

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null

func _on_will_open() -> void:
	pass

func _on_open() -> void:
	opened.emit()

func _on_close() -> void:
	pass

func _input(event: InputEvent) -> void:
	if not _is_open or not close_on_back:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
