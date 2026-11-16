extends Node

signal progress_changed(progress)
signal load_finished

var loading_screen: PackedScene = preload("uid://b27qm5kt2fm23")
var loaded_resource: PackedScene
var scene_path: String
var progress: Array = []

func _ready() -> void:
	set_process(false)

func load_scene(new_scene_path: String) -> void:
	scene_path = new_scene_path
	
	var new_load_screen = loading_screen.instantiate()
	add_child(new_load_screen)
	progress_changed.connect(new_load_screen._on_progress_changed)
	load_finished.connect(new_load_screen._on_load_finished)
	
	await new_load_screen.loading_screen_ready
	
	start_load()

func start_load() -> void:
	var state = ResourceLoader.load_threaded_request(scene_path, "", true)
	if state == OK:
		set_process(true)

func _process(_delta: float) -> void:
	var load_state = ResourceLoader.load_threaded_get_status(scene_path, progress)
	progress_changed.emit(progress[0])
	match load_state:
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, ResourceLoader.THREAD_LOAD_FAILED:
			set_process(false)
		ResourceLoader.THREAD_LOAD_LOADED:
			loaded_resource = ResourceLoader.load_threaded_get(scene_path)
			get_tree().change_scene_to_packed(loaded_resource)
			load_finished.emit()
