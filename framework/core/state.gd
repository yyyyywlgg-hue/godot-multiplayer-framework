class_name State
extends Node

@export var state_name: StringName = &""

var _machine: StateMachine = null

func _ready() -> void:
	if state_name == &"":
		state_name = StringName(name)
	set_process(false)
	set_physics_process(false)

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func transition_to(to: StringName) -> bool:
	if _machine:
		return _machine.transition(to)
	return false

func force_transition_to(to: StringName) -> void:
	if _machine:
		_machine.force_transition(to)

func push_state(to: StringName) -> bool:
	if _machine:
		return _machine.push(to)
	return false

func pop_state() -> bool:
	if _machine:
		return _machine.pop()
	return false
