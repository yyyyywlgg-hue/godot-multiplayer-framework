extends Node

## Autoload — manages UI view stack with fade transitions.
## Registered as "UI" in project.godot.
## Usage: await UI.open(view_scene, data) / UI.back()

signal view_changed(current: UIView)

var _stack: Array[UIView] = []
var _current: UIView
var _canvas: CanvasLayer

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_canvas = CanvasLayer.new()
	_canvas.name = "UICanvas"
	_canvas.layer = 128
	add_child(_canvas)

func open(view_scene: PackedScene, data: Dictionary = {}) -> UIView:
	if Engine.is_editor_hint():
		return null
	if _current:
		_current.close()
		await _current.closed

	var view: UIView = view_scene.instantiate()
	_canvas.add_child(view)

	if data and view.has_method("set_data"):
		view.set_data(data)

	_stack.append(view)
	_current = view
	view.open()
	view_changed.emit(view)
	return view

func replace(view_scene: PackedScene, data: Dictionary = {}) -> UIView:
	if _current:
		_current.close()
		await _current.closed
		_stack.pop_back()
	return await open(view_scene, data)

func back() -> void:
	if _stack.size() <= 1:
		return
	var old = _stack.pop_back()
	old.close()
	await old.closed
	old.queue_free()
	_current = _stack.back()
	_current.open()
	view_changed.emit(_current)

func back_to_root() -> void:
	while _stack.size() > 1:
		var old = _stack.pop_back()
		old.close()
		old.queue_free()
	if _current:
		_current.open()
		view_changed.emit(_current)

func clear() -> void:
	for view in _stack:
		if is_instance_valid(view):
			view.queue_free()
	_stack.clear()
	_current = null
	# Also clear any overlay views not in stack
	for child in _canvas.get_children():
		if is_instance_valid(child):
			child.queue_free()
	view_changed.emit(null)

func overlay(view_scene: PackedScene, data: Dictionary = {}) -> UIView:
	var view: UIView = view_scene.instantiate()
	_canvas.add_child(view)
	if data and view.has_method("set_data"):
		view.set_data(data)
	view.open()
	return view

func current() -> UIView:
	return _current

func stack_depth() -> int:
	return _stack.size()
