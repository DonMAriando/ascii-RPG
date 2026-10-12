extends Node3D
## Barra de vida billboard sobre el personaje.

var _fill: MeshInstance3D
var _max_hp: float = 1.0


func _ready() -> void:
	var bg := _make_quad(Color(0.08, 0.08, 0.1), 1.05, -0.002)
	add_child(bg)
	_fill = _make_quad(Color(0.25, 0.85, 0.32), 1.0, 0.0)
	add_child(_fill)


func setup(max_hp: float) -> void:
	_max_hp = maxf(max_hp, 1.0)
	set_ratio(1.0)


func set_ratio(ratio: float) -> void:
	var r := clampf(ratio, 0.0, 1.0)
	if _fill == null:
		return
	_fill.scale.x = maxf(r, 0.02)
	_fill.position.x = (r - 1.0) * 0.5
	var mat := _fill.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color = Color(0.85, 0.18, 0.14) if r < 0.35 else Color(0.25, 0.85, 0.32)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		look_at(camera.global_position, Vector3.UP, true)


func _make_quad(color: Color, width: float, z: float) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, 0.1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position.z = z
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst
