class_name SceneManager
extends Node

enum Transition {
	NONE,
	FADE,
	SLIDE_LEFT,
	SLIDE_RIGHT,
}

signal scene_change_started
signal scene_change_finished
signal load_progress_updated(progress: float)

var _loading_in_progress: bool = false
var _current_scene_data: Dictionary = {}
var _scene_history: Array = []
var _max_history: int = 10
var _transition_in_done: bool = false
var _transition_out_done: bool = false
var _overlay: CanvasLayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func change_scene(scene_path: String, params: Dictionary = {}, transition: Transition = Transition.FADE) -> void:
	if _loading_in_progress:
		push_warning("SceneManager: already loading a scene")
		return
	_loading_in_progress = true
	scene_change_started.emit()

	if not _current_scene_data.is_empty():
		_scene_history.append(_current_scene_data.duplicate())
		if _scene_history.size() > _max_history:
			_scene_history.pop_front()

	_overlay = _create_transition_overlay()
	get_tree().root.add_child(_overlay)
	_transition_in_done = false
	_transition_out_done = false

	if transition != Transition.NONE:
		_play_transition_in(transition)
		await _wait_transition_in()

	if not ResourceLoader.exists(scene_path):
		push_error("SceneManager: resource does not exist '%s'" % scene_path)
		_cleanup()
		return

	var err = ResourceLoader.load_threaded_request(scene_path)
	if err != OK:
		push_error("SceneManager: failed to start loading '%s'" % scene_path)
		_cleanup()
		return

	var progress = []
	while true:
		var status = ResourceLoader.load_threaded_get_status(scene_path, progress)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				break
			ResourceLoader.THREAD_LOAD_FAILED:
				push_error("SceneManager: failed to load '%s'" % scene_path)
				_cleanup()
				return
			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("SceneManager: invalid resource '%s'" % scene_path)
				_cleanup()
				return
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				load_progress_updated.emit(progress[0])
				await get_tree().create_timer(0.05).timeout

	var packed = ResourceLoader.load_threaded_get(scene_path)
	var new_scene = packed.instantiate()

	var outgoing = get_tree().current_scene
	_current_scene_data = {"path": scene_path, "params": params}

	if outgoing:
		if outgoing.has_method("get_data") and new_scene.has_method("receive_data"):
			new_scene.receive_data(outgoing.get_data())
		outgoing.queue_free()

	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene

	if new_scene.has_method("init_scene"):
		new_scene.init_scene()

	if transition != Transition.NONE:
		_play_transition_out(transition)
		await _wait_transition_out()

	_cleanup_overlay()

	if new_scene.has_method("start_scene"):
		new_scene.start_scene()

	_loading_in_progress = false
	scene_change_finished.emit()

func change_scene_instant(scene_path: String, params: Dictionary = {}) -> void:
	change_scene(scene_path, params, Transition.NONE)

func go_back(transition: Transition = Transition.FADE) -> void:
	if _scene_history.is_empty():
		push_warning("SceneManager: no scene history to go back to")
		return
	var prev = _scene_history.pop_back()
	change_scene(prev.path, prev.params, transition)

func restart_scene() -> void:
	if _current_scene_data.is_empty():
		return
	var saved = _current_scene_data.duplicate()
	change_scene(saved.path, saved.params, Transition.NONE)

func is_changing_scene() -> bool:
	return _loading_in_progress

func get_current_scene_data() -> Dictionary:
	return _current_scene_data

func has_history() -> bool:
	return not _scene_history.is_empty()

func _create_transition_overlay() -> CanvasLayer:
	var layer = CanvasLayer.new()
	layer.layer = 100

	var color = ColorRect.new()
	color.name = "FadeColor"
	color.color = Color.BLACK
	color.mouse_filter = Control.MOUSE_FILTER_STOP
	color.set_anchors_preset(Control.PRESET_FULL_RECT)
	color.modulate.a = 0.0
	layer.add_child(color)

	var slide = ColorRect.new()
	slide.name = "SlideColor"
	slide.color = Color.BLACK
	slide.mouse_filter = Control.MOUSE_FILTER_STOP
	slide.set_anchors_preset(Control.PRESET_FULL_RECT)
	slide.visible = false
	layer.add_child(slide)

	return layer

func _play_transition_in(transition: Transition) -> void:
	var fade: ColorRect = _overlay.get_node("FadeColor")
	var slide: ColorRect = _overlay.get_node("SlideColor")
	var tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	match transition:
		Transition.FADE:
			fade.visible = true
			tween.tween_property(fade, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
		Transition.SLIDE_LEFT:
			slide.visible = true
			slide.anchor_left = -1.0
			slide.anchor_right = 0.0
			slide.offset_left = 0.0
			slide.offset_right = 0.0
			tween.tween_property(slide, "anchor_left", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(slide, "anchor_right", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
		Transition.SLIDE_RIGHT:
			slide.visible = true
			slide.anchor_left = 1.0
			slide.anchor_right = 2.0
			slide.offset_left = 0.0
			slide.offset_right = 0.0
			tween.tween_property(slide, "anchor_left", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(slide, "anchor_right", 1.0, 0.3).set_trans(Tween.TRANS_SINE)

	tween.finished.connect(func(): _transition_in_done = true)

func _play_transition_out(transition: Transition) -> void:
	var fade: ColorRect = _overlay.get_node("FadeColor")
	var slide: ColorRect = _overlay.get_node("SlideColor")
	var tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	match transition:
		Transition.FADE:
			tween.tween_property(fade, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
		Transition.SLIDE_LEFT:
			tween.tween_property(slide, "anchor_left", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(slide, "anchor_right", 2.0, 0.3).set_trans(Tween.TRANS_SINE)
		Transition.SLIDE_RIGHT:
			tween.tween_property(slide, "anchor_left", -1.0, 0.3).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(slide, "anchor_right", 0.0, 0.3).set_trans(Tween.TRANS_SINE)

	tween.finished.connect(func(): _transition_out_done = true)

func _wait_transition_in() -> void:
	while not _transition_in_done:
		await get_tree().process_frame

func _wait_transition_out() -> void:
	while not _transition_out_done:
		await get_tree().process_frame

func _cleanup_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null

func _cleanup() -> void:
	_cleanup_overlay()
	_loading_in_progress = false
