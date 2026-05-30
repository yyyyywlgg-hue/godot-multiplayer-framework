class_name StateMachine
extends Node

signal state_changed(from: StringName, to: StringName)

var _states: Dictionary = {}
var _transitions: Dictionary = {}
var _current: State = null
var _stack: Array[State] = []
var _max_stack: int = 8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func add_state(state: State) -> void:
	if _states.has(state.name):
		push_warning("StateMachine: state '%s' already exists" % state.name)
		return
	_states[state.name] = state
	state._machine = self
	if state.get_parent() == null:
		add_child(state)

func add_transition(from: StringName, to: StringName) -> void:
	if not _transitions.has(from):
		_transitions[from] = []
	if not _transitions[from].has(to):
		_transitions[from].append(to)

func can_transition(to: StringName) -> bool:
	if _current == null:
		return true
	if _transitions.is_empty():
		return true
	var from = _current.name
	if not _transitions.has(from):
		return false
	return _transitions[from].has(to)

func transition(to: StringName) -> bool:
	if not _states.has(to):
		push_error("StateMachine: state '%s' does not exist" % to)
		return false
	if not can_transition(to):
		return false
	var from_state = _current
	var to_state = _states[to]
	var from_name = StringName("") if from_state == null else from_state.name
	if from_state:
		from_state.exit()
	if not _stack.is_empty() and _stack[-1] == from_state:
		_stack[-1] = to_state
	_current = to_state
	state_changed.emit(from_name, to)
	_current.enter()
	return true

func force_transition(to: StringName) -> void:
	if not _states.has(to):
		push_error("StateMachine: state '%s' does not exist" % to)
		return
	var from_state = _current
	var from_name = StringName("") if from_state == null else from_state.name
	if from_state:
		from_state.exit()
	_current = _states[to]
	state_changed.emit(from_name, to)
	_current.enter()

func push(to: StringName) -> bool:
	if not _states.has(to):
		return false
	if _current:
		_current.exit()
		if _stack.size() < _max_stack:
			_stack.append(_current)
	var from_name = StringName("") if _current == null else _current.name
	_current = _states[to]
	state_changed.emit(from_name, to)
	_current.enter()
	return true

func pop() -> bool:
	if _stack.is_empty():
		return false
	if _current:
		_current.exit()
	var from_name = _current.name
	_current = _stack.pop_back()
	state_changed.emit(from_name, _current.name)
	_current.enter()
	return true

func _process(delta: float) -> void:
	if _current:
		_current.update(delta)

func current_state() -> State:
	return _current

func current_state_name() -> StringName:
	if _current == null:
		return &""
	return _current.name

func is_in_state(state_name: StringName) -> bool:
	return _current != null and _current.name == state_name

func has_state(state_name: StringName) -> bool:
	return _states.has(state_name)

func get_state(state_name: StringName) -> State:
	return _states.get(state_name)

func stack_size() -> int:
	return _stack.size()

func clear_stack() -> void:
	_stack.clear()
