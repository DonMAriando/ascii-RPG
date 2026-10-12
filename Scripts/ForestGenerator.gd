extends Node3D
## Esparce árboles, rocas, pasto y arbustos Kenney (CC0) alrededor de claros y agua.

const NATURE := "res://Models/nature/"
const TREE_SCALE := 5.2
const ROCK_SCALE := 4.4
const GRASS_SCALE := 2.6
const BUSH_SCALE := 3.8

var water_rects: Array[Rect2] = []
var _rng := RandomNumberGenerator.new()
var _occupied: Array[Vector2] = []


func generate(parent: Node3D, waters: Array[Rect2]) -> void:
	water_rects = waters
	_rng.seed = 20261012
	_occupied.clear()
	_occupied.append(Vector2.ZERO)

	_scatter_trees(parent, 78)
	_scatter_rocks(parent, 36)
	_scatter_bushes(parent, 42)
	_scatter_grass(parent, 160)
	_scatter_flowers(parent, 36)
	_place_campfire(parent)
	_place_lilies()


func _scatter_trees(parent: Node3D, count: int) -> void:
	var files := [
		"tree_pineTallA_detailed.glb", "tree_pineTallB_detailed.glb", "tree_pineTallC_detailed.glb",
		"tree_pineTallA.glb", "tree_pineTallB.glb", "tree_oak.glb", "tree_oak_dark.glb",
		"tree_detailed.glb", "tree_tall.glb", "tree_pineDefaultA.glb", "tree_pineRoundA.glb",
	]
	for i in count:
		var pos := _find_spot(3.2, 5.5)
		if pos == Vector2.INF:
			continue
		var path: String = NATURE + files[i % files.size()]
		_spawn_prop(parent, path, pos, TREE_SCALE, 0.42, 5.0, true)


func _scatter_rocks(parent: Node3D, count: int) -> void:
	var files := [
		"rock_largeA.glb", "rock_largeB.glb", "rock_largeC.glb",
		"rock_tallA.glb", "rock_tallB.glb",
		"rock_smallA.glb", "rock_smallB.glb", "rock_smallFlatA.glb",
	]
	for i in count:
		var pos := _find_spot(1.6, 2.4)
		if pos == Vector2.INF:
			continue
		var large := i % 3 != 2
		_spawn_prop(parent, NATURE + files[i % files.size()], pos, ROCK_SCALE, 0.55 if large else 0.28, 1.2 if large else 0.5, large)


func _scatter_bushes(parent: Node3D, count: int) -> void:
	var files := ["plant_bush.glb", "plant_bushDetailed.glb", "plant_bushLarge.glb", "plant_bushSmall.glb"]
	for i in count:
		var pos := _find_spot(1.3, 2.0)
		if pos == Vector2.INF:
			continue
		_spawn_prop(parent, NATURE + files[i % files.size()], pos, BUSH_SCALE, 0.0, 0.0, false)


func _scatter_grass(parent: Node3D, count: int) -> void:
	var files := ["grass.glb", "grass_large.glb", "grass_leafs.glb", "grass_leafsLarge.glb"]
	for i in count:
		var pos := _find_spot(0.55, 0.7)
		if pos == Vector2.INF:
			continue
		_spawn_prop(parent, NATURE + files[i % files.size()], pos, GRASS_SCALE, 0.0, 0.0, false)


func _scatter_flowers(parent: Node3D, count: int) -> void:
	var files := ["flower_redA.glb", "flower_yellowA.glb", "flower_purpleA.glb"]
	for i in count:
		var pos := _find_spot(0.7, 1.0)
		if pos == Vector2.INF:
			continue
		_spawn_prop(parent, NATURE + files[i % files.size()], pos, 3.0, 0.0, 0.0, false)


func _place_campfire(parent: Node3D) -> void:
	_spawn_prop(parent, NATURE + "campfire_stones.glb", Vector2(2.4, -2.1), 3.2, 0.35, 0.4, true)
	var light := OmniLight3D.new()
	light.name = "CampfireLight"
	light.add_to_group("campfire_light")
	light.position = Vector3(2.4, 0.7, -2.1)
	light.light_color = Color(1.0, 0.52, 0.18)
	light.light_energy = 0.2
	light.omni_range = 9.0
	light.shadow_enabled = true
	parent.add_child(light)


func _place_lilies() -> void:
	var files := ["lily_large.glb", "lily_small.glb"]
	for rect in water_rects:
		for i in 5:
			var pos := Vector2(
				_rng.randf_range(rect.position.x + 0.8, rect.end.x - 0.8),
				_rng.randf_range(rect.position.y + 0.8, rect.end.y - 0.8)
			)
			var inst := _instance_model(NATURE + files[i % files.size()], pos, 3.4)
			if inst:
				inst.position.y = 0.06
				add_child(inst)


func _spawn_prop(parent: Node3D, path: String, pos: Vector2, scale: float, col_radius: float, col_height: float, blocking: bool) -> void:
	var visual := _instance_model(path, pos, scale)
	if visual == null:
		return
	if blocking and col_radius > 0.0:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = Vector3(pos.x, 0.0, pos.y)
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = col_radius
		cyl.height = maxf(col_height, 0.4)
		shape.shape = cyl
		shape.position.y = cyl.height * 0.5
		body.add_child(shape)
		visual.position = Vector3.ZERO
		body.add_child(visual)
		parent.add_child(body)
	else:
		parent.add_child(visual)


func _instance_model(path: String, pos: Vector2, scale: float) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var inst := packed.instantiate() as Node3D
	inst.position = Vector3(pos.x, 0.0, pos.y)
	inst.scale = Vector3.ONE * scale
	inst.rotate_y(_rng.randf_range(0.0, TAU))
	return inst


func _find_spot(min_sep: float, clear_spawn: float) -> Vector2:
	for _try in 40:
		var pos := Vector2(_rng.randf_range(-34.0, 34.0), _rng.randf_range(-34.0, 34.0))
		if pos.length() < clear_spawn:
			continue
		if _inside_water(pos, 1.1):
			continue
		var ok := true
		for other in _occupied:
			if pos.distance_to(other) < min_sep:
				ok = false
				break
		if ok:
			_occupied.append(pos)
			return pos
	return Vector2.INF


func _inside_water(pos: Vector2, pad: float) -> bool:
	for rect in water_rects:
		if Rect2(rect.position - Vector2(pad, pad), rect.size + Vector2(pad, pad) * 2.0).has_point(pos):
			return true
	return false
