extends Node3D
## Bosque, agua caminable y clic-to-move.

const CLICK_ACTION := &"clic_izquierdo"

@onready var _nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var _forest: Node3D = $Forest
@onready var _waters: Node3D = $Waters

var _water_rects: Array[Rect2] = [
	Rect2(-4.0, 5.0, 11.0, 8.0),
	Rect2(-20.0, -6.5, 24.0, 3.8),
	Rect2(14.0, -16.0, 8.0, 7.0),
]


func _ready() -> void:
	_ensure_click_action()
	_spawn_water()
	if _forest.has_method("generate"):
		_forest.call("generate", _nav_region, _water_rects)
	_bake_navigation()
	if OS.get_cmdline_user_args().has("--test-walk"):
		call_deferred("_run_walk_test")
	if OS.get_cmdline_user_args().has("--test-click"):
		call_deferred("_run_click_test")


func _input(event: InputEvent) -> void:
	if not _is_left_click(event):
		return
	_send_click_to_player(get_viewport().get_mouse_position())


func _is_left_click(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	return event.is_action_pressed(CLICK_ACTION)


func _send_click_to_player(screen_pos: Vector2) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("move_to_screen_position"):
		player.call("move_to_screen_position", screen_pos)


func _spawn_water() -> void:
	var script := load("res://Scripts/WaterZone.gd") as Script
	for rect in _water_rects:
		var zone := Node3D.new()
		zone.set_script(script)
		_waters.add_child(zone)
		var center := Vector3(rect.position.x + rect.size.x * 0.5, 0.0, rect.position.y + rect.size.y * 0.5)
		zone.call("setup", center, rect.size)


func _bake_navigation() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 1.75
	nav_mesh.agent_max_climb = 0.25
	nav_mesh.agent_max_slope = 45.0
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	_nav_region.navigation_mesh = nav_mesh
	_nav_region.bake_navigation_mesh(false)


func _ensure_click_action() -> void:
	if not InputMap.has_action(CLICK_ACTION):
		InputMap.add_action(CLICK_ACTION)
	if InputMap.action_get_events(CLICK_ACTION).is_empty():
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(CLICK_ACTION, mouse)


func _run_walk_test() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("move_to"):
		player.call("move_to", Vector3(2.0, 0.0, 8.0))


func _run_click_test() -> void:
	var screen := Vector2(1080, 160)
	get_viewport().warp_mouse(screen)
	_send_click_to_player(screen)
