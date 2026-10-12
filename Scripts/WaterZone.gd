extends Node3D
## Estanque caminable: simula un campo de altura 2D (ecuación de onda) y lo
## proyecta en el shader. Cada pisada estampa un impulso.

const SIM := 96
const DAMPING := 0.982
const SPREAD := 0.22

@export var zone_size: Vector2 = Vector2(12.0, 8.0)

var _curr: PackedFloat32Array
var _prev: PackedFloat32Array
var _next: PackedFloat32Array
var _bytes: PackedByteArray
var _image: Image
var _texture: ImageTexture
var _material: ShaderMaterial
var _half: Vector2
var _energy: float = 1.0


func setup(center: Vector3, size: Vector2) -> void:
	global_position = Vector3(center.x, 0.04, center.z)
	zone_size = size
	_half = size * 0.5
	add_to_group("water_zone")
	_init_sim()
	_build_mesh()


func contains_xz(world_pos: Vector3) -> bool:
	var local := Vector2(world_pos.x - global_position.x, world_pos.z - global_position.z)
	return absf(local.x) <= _half.x and absf(local.y) <= _half.y


func try_splash(world_pos: Vector3, strength: float = 1.0) -> void:
	if not contains_xz(world_pos):
		return
	var uv := Vector2(
		(world_pos.x - global_position.x) / zone_size.x + 0.5,
		(world_pos.z - global_position.z) / zone_size.y + 0.5
	)
	_stamp(uv, strength)
	_energy = 1.0


func _physics_process(delta: float) -> void:
	_step_wave(delta)
	_upload()


func _init_sim() -> void:
	var cells := SIM * SIM
	_curr.resize(cells)
	_prev.resize(cells)
	_next.resize(cells)
	_bytes.resize(cells * 3)
	_curr.fill(0.0)
	_prev.fill(0.0)
	_next.fill(0.0)
	_image = Image.create(SIM, SIM, false, Image.FORMAT_RGB8)
	_image.fill(Color(0.5, 0.5, 0.5))
	_texture = ImageTexture.create_from_image(_image)


func _build_mesh() -> void:
	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = zone_size
	plane.subdivide_width = 48
	plane.subdivide_depth = 48
	mesh_instance.mesh = plane
	_material = ShaderMaterial.new()
	_material.shader = load("res://Shaders/water.gdshader") as Shader
	_material.set_shader_parameter("ripples", _texture)
	mesh_instance.material_override = _material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)


func _stamp(uv: Vector2, strength: float) -> void:
	var cx := int(clampf(uv.x, 0.0, 1.0) * float(SIM - 1))
	var cy := int(clampf(uv.y, 0.0, 1.0) * float(SIM - 1))
	var radius := 7
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var x := cx + dx
			var y := cy + dy
			if x <= 0 or y <= 0 or x >= SIM - 1 or y >= SIM - 1:
				continue
			var dist := sqrt(float(dx * dx + dy * dy))
			if dist > float(radius):
				continue
			var impulse := strength * (1.0 - dist / float(radius)) * 1.35
			_curr[y * SIM + x] += impulse


func _step_wave(_delta: float) -> void:
	if _energy < 0.0008:
		return
	var peak := 0.0
	for y in range(1, SIM - 1):
		var row := y * SIM
		for x in range(1, SIM - 1):
			var i := row + x
			var lap := _curr[i - 1] + _curr[i + 1] + _curr[i - SIM] + _curr[i + SIM] - 4.0 * _curr[i]
			var value := (2.0 * _curr[i] - _prev[i] + lap * SPREAD) * DAMPING
			value = clampf(value, -1.0, 1.0)
			_next[i] = value
			peak = maxf(peak, absf(value))
	var tmp := _prev
	_prev = _curr
	_curr = _next
	_next = tmp
	_energy = peak


func _upload() -> void:
	if _energy < 0.0008:
		return
	var cells := SIM * SIM
	for i in cells:
		var v := int(clampf(_curr[i] * 0.5 + 0.5, 0.0, 1.0) * 255.0)
		var o := i * 3
		_bytes[o] = v
		_bytes[o + 1] = v
		_bytes[o + 2] = v
	_image.set_data(SIM, SIM, false, Image.FORMAT_RGB8, _bytes)
	_texture.update(_image)
