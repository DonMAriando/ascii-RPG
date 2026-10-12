extends Node3D
## Rig isométrico: la cámara permanece centrada en el jugador con interpolación suave.

@export var target_path: NodePath
@export var follow_speed: float = 5.5
@export var iso_pitch_degrees: float = -35.264
@export var iso_yaw_degrees: float = 45.0
@export var camera_distance: float = 26.0
@export var ortho_size: float = 11.5

@onready var _camera: Camera3D = $Camera3D

var _target: Node3D
var _outline: MeshInstance3D
var _outline_mesh: QuadMesh


func _ready() -> void:
	rotation_degrees = Vector3(iso_pitch_degrees, iso_yaw_degrees, 0.0)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = ortho_size
	_camera.near = 0.05
	_camera.far = 120.0
	_camera.position = Vector3(0.0, 0.0, camera_distance)
	_camera.current = true
	_install_depth_outline()
	_resolve_target()
	_snap_to_target()


func _process(delta: float) -> void:
	_fit_outline_to_camera()
	if _target == null:
		_resolve_target()
		if _target == null:
			return

	var weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(_target.global_position, weight)


func _resolve_target() -> void:
	if target_path != NodePath() and has_node(target_path):
		_target = get_node(target_path)
		return
	_target = get_tree().get_first_node_in_group("player")


func _snap_to_target() -> void:
	if _target:
		global_position = _target.global_position


func _install_depth_outline() -> void:
	_outline_mesh = QuadMesh.new()
	_outline = MeshInstance3D.new()
	_outline.name = "DepthOutline"
	_outline.mesh = _outline_mesh
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outline.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_outline.extra_cull_margin = 32.0
	var material := ShaderMaterial.new()
	material.shader = load("res://Shaders/depth_outline.gdshader") as Shader
	_outline.material_override = material
	_camera.add_child(_outline)
	_fit_outline_to_camera()


func _fit_outline_to_camera() -> void:
	if _outline == null or _outline_mesh == null:
		return
	var viewport := get_viewport()
	var aspect := 16.0 / 9.0
	if viewport != null:
		var size: Vector2 = viewport.get_visible_rect().size
		if size.y > 0.0:
			aspect = size.x / size.y
	_outline_mesh.size = Vector2(_camera.size * aspect, _camera.size)
	_outline.position = Vector3(0.0, 0.0, -(_camera.near + 0.04))
