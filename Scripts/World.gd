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
	_spawn_camp_mobs()
	_bake_navigation()
	if OS.get_cmdline_user_args().has("--test-walk"):
		call_deferred("_run_walk_test")
	if OS.get_cmdline_user_args().has("--test-click"):
		call_deferred("_run_click_test")
	if OS.get_cmdline_user_args().has("--test-combat"):
		call_deferred("_run_combat_test")
	if OS.get_cmdline_user_args().has("--test-hud"):
		call_deferred("_run_hud_test")
	if OS.get_cmdline_user_args().has("--test-magic"):
		call_deferred("_run_magic_test")


func _input(event: InputEvent) -> void:
	if not _is_left_click(event):
		return
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
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


func _spawn_camp_mobs() -> void:
	var packed := load("res://Scenes/Mob.tscn") as PackedScene
	if packed == null:
		return
	var spots: Array[Vector3] = [
		Vector3(2.8, 0.0, 2.5),
		Vector3(10.5, 0.0, 3.2),
		Vector3(-9.5, 0.0, -10.0),
	]
	for i in spots.size():
		var mob := packed.instantiate() as Node3D
		mob.name = "CampMob%d" % (i + 1)
		add_child(mob)
		mob.global_position = spots[i]


func _run_hud_test() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.set("hp", 28)
		player.set("mp", 16)
		if player.has_method("_refresh_hp"):
			player.call("_refresh_hp")
	var hud := get_tree().get_first_node_in_group("player_hud")
	if hud != null and hud.has_method("set_hud_visible"):
		hud.call("set_hud_visible", true)
	get_tree().create_timer(0.55).timeout.connect(_dump_hud_orbs)


func _dump_hud_orbs() -> void:
	_save_hud_png("user://hud_orbs.png")
	var hud := get_tree().get_first_node_in_group("player_hud")
	if hud != null and hud.has_method("toggle_magic_tree"):
		hud.call("toggle_magic_tree")
	get_tree().create_timer(0.35).timeout.connect(_dump_hud_tree)


func _dump_hud_tree() -> void:
	_save_hud_png("user://hud_tree.png")
	get_tree().quit()


func _save_hud_png(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	if image:
		image.save_png(path)
		print("HUD_TEST saved=", ProjectSettings.globalize_path(path))


func _run_magic_test() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var enemy := get_node_or_null("CampMob1") as Node3D
	if enemy == null:
		enemy = get_tree().get_first_node_in_group("enemy") as Node3D
	if player != null:
		player.set("essence", 12)
		if player.has_method("try_unlock_rune"):
			player.call("try_unlock_rune", "fuego")
		if enemy != null:
			player.global_position = enemy.global_position + Vector3(-2.2, 0.05, 0.4)
			if player.has_method("request_firebolt"):
				player.call("request_firebolt")
	get_tree().create_timer(2.2).timeout.connect(_dump_magic_frame)


func _dump_magic_frame() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var enemy := get_node_or_null("CampMob1")
	var mp := 0
	var essence := 0
	var enemy_hp := 0
	var fuego := false
	if player != null:
		mp = int(player.get("mp"))
		essence = int(player.get("essence"))
		if player.has_method("has_rune"):
			fuego = bool(player.call("has_rune", "fuego"))
	if enemy != null:
		enemy_hp = int(enemy.get("hp"))
	print("MAGIC_TEST mp=%d essence=%d fuego=%s enemy_hp=%d" % [mp, essence, fuego, enemy_hp])
	var image := get_viewport().get_texture().get_image()
	if image:
		image.save_png("user://magic_test.png")
		print("MAGIC_TEST saved=", ProjectSettings.globalize_path("user://magic_test.png"))
	get_tree().quit()


func _run_combat_test() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var enemy := get_node_or_null("CampMob1") as Node3D
	if enemy == null:
		enemy = get_tree().get_first_node_in_group("enemy") as Node3D
	if player != null and enemy != null and player.has_method("attack_node"):
		player.call("attack_node", enemy)
	get_tree().create_timer(5.0).timeout.connect(_dump_combat_frame)


func _dump_combat_frame() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var enemy := get_node_or_null("CampMob1")
	var player_hp := 0
	var enemy_hp := 0
	if player != null:
		player_hp = int(player.get("hp"))
	if enemy != null:
		enemy_hp = int(enemy.get("hp"))
	print("COMBAT_TEST player_hp=%d enemy_hp=%d" % [player_hp, enemy_hp])
	var image := get_viewport().get_texture().get_image()
	if image:
		image.save_png("user://combat_test.png")
		print("COMBAT_TEST saved=", ProjectSettings.globalize_path("user://combat_test.png"))
	get_tree().quit()
