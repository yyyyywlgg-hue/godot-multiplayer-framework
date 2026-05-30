class_name EventBus
extends Node

var _events: Dictionary = {}

func register(event_name: String, data_type: int = TYPE_NIL) -> void:
	if _events.has(event_name):
		return
	_events[event_name] = {
		"subscribers": {},
		"data_type": data_type,
	}

func emit_event(event_name: String, data: Variant = null) -> void:
	if not _events.has(event_name):
		return

	var event = _events[event_name]
	if event.data_type != TYPE_NIL and data != null:
		if typeof(data) != event.data_type:
			push_error("EventBus: event '%s' expects type %d but got type %d" % [event_name, event.data_type, typeof(data)])
			return

	var snapshot = event.subscribers.keys()
	for callable in snapshot:
		if not event.subscribers.has(callable):
			continue
		if not is_callable_valid(callable):
			event.subscribers.erase(callable)
			continue
		_invoke_safe(callable, data)

func subscribe(event_name: String, callable: Callable) -> void:
	if not _events.has(event_name):
		register(event_name)
	_events[event_name].subscribers[callable] = true

func unsubscribe(event_name: String, callable: Callable) -> void:
	if not _events.has(event_name):
		return
	_events[event_name].subscribers.erase(callable)

func has_subscribers(event_name: String) -> bool:
	if not _events.has(event_name):
		return false
	return _events[event_name].subscribers.size() > 0

func clear_event(event_name: String) -> void:
	_events.erase(event_name)

func clear_all() -> void:
	_events.clear()

func _invoke_safe(callable: Callable, data: Variant) -> void:
	if data == null:
		callable.call()
	else:
		callable.call(data)

func is_callable_valid(callable: Callable) -> bool:
	var obj = callable.get_object()
	if obj == null:
		return false
	if obj is RefCounted:
		return true
	return is_instance_valid(obj)
