extends Node3D
## Proyectil de Fuego: vuela al objetivo y aplica daño.

var damage: int = 26
var speed: float = 18.0
var _from: Node3D
var _target: Node3D
var _last: Vector3 = Vector3.ZERO
var _life: float = 2.4


func setup(from: Node3D, target: Node3D, amount: int) -> void:
	_from = from
	_target = target
	damage = amount
	if target:
		_last = target.global_position + Vector3(0.0, 1.15, 0.0)
	_build_visual()
	set_process(true)


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if _target != null and is_instance_valid(_target):
		_last = _target.global_position + Vector3(0.0, 1.15, 0.0)
	var to := _last - global_position
	var step := speed * delta
	if to.length() <= step + 0.18:
		_impact()
		return
	global_position += to.normalized() * step


func _impact() -> void:
	if _target != null and is_instance_valid(_target) and _target.has_method("take_damage"):
		_target.call("take_damage", damage, _from)
	queue_free()


func _build_visual() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.42, 0.08)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.35, 0.05)
	mat.emission_energy_multiplier = 3.2
	var ball := MeshInstance3D.new()
	ball.mesh = mesh
	ball.material_override = mat
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ball)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.45, 0.12)
	glow.light_energy = 2.6
	glow.omni_range = 4.5
	add_child(glow)
