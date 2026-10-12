extends CharacterBody3D
## Point-and-click: el clic lo despacha World; aquí se resuelve el raycast
## y se camina en línea recta al punto (NavigationAgent3D solo si hay path).

const TERRAIN_MASK := 1

@export var move_speed: float = 6.5
@export var rotation_speed: float = 12.0
@export var stop_distance: float = 0.28
@export var click_ray_length: float = 800.0

@onready var _nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _visual: Node = get_node_or_null("Visual")

var _destination: Vector3 = Vector3.ZERO
var _has_destination: bool = false
var _queued_screen: Vector2 = Vector2.ZERO
var _has_queued_click: bool = false
var _marker: MeshInstance3D
var _last_step: Vector3 = Vector3.ZERO
@export var step_distance: float = 0.52


func _ready() -> void:
	add_to_group("player")
	_nav_agent.path_desired_distance = 0.4
	_nav_agent.target_desired_distance = stop_distance
	_nav_agent.radius = 0.5
	_nav_agent.height = 1.75
	_nav_agent.avoidance_enabled = false
	_create_destination_marker()
	_last_step = global_position
	var capsule := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if capsule:
		capsule.visible = false


func move_to_screen_position(screen_pos: Vector2) -> void:
	_queued_screen = screen_pos
	_has_queued_click = true


func move_to(world_pos: Vector3) -> void:
	_destination = world_pos
	_has_destination = true
	_nav_agent.target_position = world_pos
	if _marker:
		_marker.global_position = Vector3(world_pos.x, 0.05, world_pos.z)
		_marker.visible = true


func _physics_process(delta: float) -> void:
	if _has_queued_click:
		_has_queued_click = false
		var hit: Vector3 = _pick_ground_point(_queued_screen)
		if hit.is_finite():
			move_to(hit)

	_apply_gravity(delta)

	if not _has_destination:
		velocity.x = 0.0
		velocity.z = 0.0
		_set_visual_moving(false)
		move_and_slide()
		return

	var to_dest := Vector3(_destination.x - global_position.x, 0.0, _destination.z - global_position.z)
	if to_dest.length() <= stop_distance:
		_arrive()
		move_and_slide()
		return

	var walk := _walk_vector(to_dest)
	_face_direction(walk, delta)
	_set_visual_moving(true)
	velocity.x = walk.x * move_speed
	velocity.z = walk.z * move_speed
	move_and_slide()
	_emit_footstep()


func _walk_vector(to_dest: Vector3) -> Vector3:
	var path: PackedVector3Array = _nav_agent.get_current_navigation_path()
	if path.size() > 1 and not _nav_agent.is_navigation_finished():
		var next: Vector3 = _nav_agent.get_next_path_position()
		var via_nav := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
		if via_nav.length() > 0.05:
			return via_nav.normalized()
	return to_dest.normalized()


func _pick_ground_point(screen_pos: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(NAN, NAN, NAN)

	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	if direction.length_squared() < 0.000001:
		return Vector3(NAN, NAN, NAN)

	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * click_ray_length)
	query.collision_mask = TERRAIN_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var point: Vector3 = result.position as Vector3
		point.y = 0.0
		return point

	if absf(direction.y) > 0.0001:
		var t := -origin.y / direction.y
		if t > 0.0:
			var plane_hit := origin + direction * t
			plane_hit.y = 0.0
			return plane_hit
	return Vector3(NAN, NAN, NAN)


func _face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	# KayKit mira por +Z; looking_at sin use_model_front alinea -Z y el PJ anda de espaldas.
	var target := Basis.looking_at(direction, Vector3.UP, true)
	global_transform.basis = global_transform.basis.slerp(target, clampf(rotation_speed * delta, 0.0, 1.0)).orthonormalized()


func _set_visual_moving(moving: bool) -> void:
	if _visual and _visual.has_method("set_moving"):
		_visual.call("set_moving", moving)


func _apply_gravity(delta: float) -> void:
	var gravity := 9.8
	if ProjectSettings.has_setting("physics/3d/default_gravity"):
		gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0


func _emit_footstep() -> void:
	if global_position.distance_to(_last_step) < step_distance:
		return
	_last_step = global_position
	get_tree().call_group("water_zone", "try_splash", global_position, 1.15)


func _arrive() -> void:
	_has_destination = false
	velocity.x = 0.0
	velocity.z = 0.0
	_set_visual_moving(false)
	if _marker:
		_marker.visible = false


func _create_destination_marker() -> void:
	_marker = MeshInstance3D.new()
	_marker.name = "DestinationMarker"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.42
	mesh.height = 0.06
	mesh.radial_segments = 20
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.35, 0.95, 0.45, 0.75)
	_marker.mesh = mesh
	_marker.material_override = material
	_marker.visible = false
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)
	_marker.top_level = true
