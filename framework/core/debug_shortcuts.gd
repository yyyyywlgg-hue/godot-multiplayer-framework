class_name DebugShortcuts
extends Node

@export var enabled: bool = true
@export var restart_key: Key = KEY_R
@export var pause_key: Key = KEY_P
@export var frame_advance_key: Key = KEY_PERIOD
@export var speed_up_key: Key = KEY_SHIFT
@export var quit_key: Key = KEY_Q
@export var stats_key: Key = KEY_F3
@export var speed_up_factor: float = 2.0
@export var require_modifier: bool = true

var _paused: bool = false
var _waiting_frame: bool = false
var _stats_visible: bool = false
var _stats_panel: Panel
var _canvas: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("release"):
		enabled = false
		queue_free()
		return
	_setup_stats_panel()

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if not event is InputEventKey:
		return
	var key_event = event as InputEventKey
	if not key_event.pressed:
		return

	if require_modifier:
		if not (key_event.ctrl_pressed and key_event.shift_pressed):
			return

	if key_event.keycode == restart_key:
		_restart_scene()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == pause_key:
		_toggle_pause()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == frame_advance_key:
		_advance_frame()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == quit_key:
		get_tree().quit()
	elif key_event.keycode == stats_key:
		_toggle_stats()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not enabled:
		return
	if require_modifier:
		if Input.is_key_pressed(KEY_CTRL) and Input.is_key_pressed(KEY_SHIFT):
			Engine.time_scale = speed_up_factor
		else:
			Engine.time_scale = 1.0
	else:
		if Input.is_key_pressed(speed_up_key):
			Engine.time_scale = speed_up_factor
		else:
			Engine.time_scale = 1.0
	if _stats_visible and is_instance_valid(_stats_panel):
		_update_stats()

func _restart_scene() -> void:
	get_tree().reload_current_scene()

func _toggle_pause() -> void:
	_paused = not _paused
	if _paused:
		get_tree().paused = true
		print("[Debug] Paused - Ctrl+Shift+P to resume, Ctrl+Shift+. to advance frame")
	else:
		get_tree().paused = false
		_waiting_frame = false

func _advance_frame() -> void:
	if not _paused:
		return
	_waiting_frame = true
	get_tree().paused = false
	await get_tree().process_frame
	if _paused:
		get_tree().paused = true
	_waiting_frame = false

func _setup_stats_panel() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 101
	get_tree().root.add_child(_canvas)

	_stats_panel = Panel.new()
	_stats_panel.name = "DebugStats"
	_stats_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_stats_panel.offset_right = 300
	_stats_panel.offset_bottom = 120
	_stats_panel.modulate.a = 0.7
	var label = Label.new()
	label.name = "StatsLabel"
	label.position = Vector2(8, 4)
	label.add_theme_font_size_override("font_size", 14)
	_stats_panel.add_child(label)
	_stats_panel.visible = false
	_canvas.add_child(_stats_panel)

func _toggle_stats() -> void:
	_stats_visible = not _stats_visible
	if is_instance_valid(_stats_panel):
		_stats_panel.visible = _stats_visible

func _update_stats() -> void:
	var label: Label = _stats_panel.get_node_or_null("StatsLabel")
	if not label:
		return
	var fps = Engine.get_frames_per_second()
	var objs = Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var mem = Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0
	var net_info = ""
	if multiplayer.multiplayer_peer:
		net_info = "\nMultiplayer: connected (peers=%d)" % (multiplayer.get_peers().size() + 1)
	else:
		net_info = "\nMultiplayer: offline"
	label.text = "FPS: %d\nObjects: %d | Nodes: %d\nBufferMem: %.1f MB%s" % [fps, objs, nodes, mem, net_info]
