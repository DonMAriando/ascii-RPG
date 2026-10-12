extends CharacterBody3D
## Point-and-click: moverse, seleccionar enemigo y atacar al entrar en rango.

const TERRAIN_MASK := 1
const ACTOR_MASK := 2
const SPELL_ACTION := &"hechizo_1"
const FIREBOLT := "res://Scripts/Firebolt.gd"

@export var move_speed: float = 6.5
@export var rotation_speed: float = 12.0
@export var stop_distance: float = 0.28
@export var attack_range: float = 2.05
@export var attack_damage: int = 18
@export var max_hp: int = 80
@export var max_mp: int = 50
@export var mp_regen: float = 4.0
@export var spell_range: float = 12.5
@export var firebolt_cost: int = 12
@export var firebolt_damage: int = 26
@export var click_ray_length: float = 800.0
@export var step_distance: float = 0.52

@onready var _nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _visual: Node = get_node_or_null("Visual")

var hp: int = 80
var mp: int = 50
var essence: int = 0
var unlocked_runes: Array[String] = ["nucleo"]
var _mp_frac: float = 0.0
var _destination: Vector3 = Vector3.ZERO
var _has_destination: bool = false
var _queued_screen: Vector2 = Vector2.ZERO
var _has_queued_click: bool = false
var _marker: MeshInstance3D
var _last_step: Vector3 = Vector3.ZERO
var _attack_target: Node3D
var _attacking: bool = false
var _casting: bool = false
var _cast_queued: bool = false
var _dead: bool = false
var _hp_bar: Node


func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	mp = max_mp
	_nav_agent.path_desired_distance = 0.4
	_nav_agent.target_desired_distance = stop_distance
	_nav_agent.radius = 0.5
	_nav_agent.height = 1.75
	_nav_agent.avoidance_enabled = false
	_create_destination_marker()
	_create_hp_bar()
	_ensure_spell_action()
	_last_step = global_position
	var capsule := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if capsule:
		capsule.visible = false


func is_alive() -> bool:
	return not _dead and hp > 0


func handle_click(screen_pos: Vector2) -> void:
	if _dead:
		return
	_queued_screen = screen_pos
	_has_queued_click = true


func move_to_screen_position(screen_pos: Vector2) -> void:
	handle_click(screen_pos)


func has_rune(rune_id: String) -> bool:
	return unlocked_runes.has(rune_id)


func rune_cost(rune_id: String) -> int:
	if rune_id == "fuego":
		return 12
	return 0


func gain_essence(amount: int) -> void:
	if amount <= 0:
		return
	essence += amount
	_spawn_popup(amount, Color(0.78, 0.55, 1.0))
	var hud := get_tree().get_first_node_in_group("player_hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", "+%d esencia" % amount)


func try_unlock_rune(rune_id: String) -> bool:
	if has_rune(rune_id) or rune_id != "fuego":
		return false
	var cost := rune_cost(rune_id)
	if cost <= 0 or essence < cost:
		return false
	essence -= cost
	unlocked_runes.append(rune_id)
	var hud := get_tree().get_first_node_in_group("player_hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", "Fuego despierto · tecla 1")
	return true


func request_firebolt() -> void:
	if _dead or not has_rune("fuego"):
		return
	var target := _spell_target()
	if target == null:
		return
	_attack_target = target
	_cast_queued = true
	_has_destination = true
	_show_marker(target.global_position, Color(1.0, 0.45, 0.12, 0.85))


func move_to(world_pos: Vector3) -> void:
	if _dead:
		return
	_attack_target = null
	_cast_queued = false
	_destination = world_pos
	_has_destination = true
	_nav_agent.target_position = world_pos
	_show_marker(world_pos, Color(0.35, 0.95, 0.45, 0.75))


func attack_node(enemy: Node3D) -> void:
	if _dead or enemy == null or not is_instance_valid(enemy):
		return
	_cast_queued = false
	_attack_target = enemy
	_has_destination = true
	_show_marker(enemy.global_position, Color(0.95, 0.28, 0.22, 0.8))


func spend_mana(amount: int) -> bool:
	if amount <= 0:
		return true
	if mp < amount:
		return false
	mp -= amount
	return true


func take_damage(amount: int, _from: Node3D) -> void:
	if _dead:
		return
	hp = maxi(hp - amount, 0)
	_refresh_hp()
	_spawn_popup(amount, Color(1.0, 0.35, 0.3))
	if hp <= 0:
		_die()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(SPELL_ACTION):
		request_firebolt()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if _has_queued_click:
		_has_queued_click = false
		_resolve_click(_queued_screen)

	_apply_gravity(delta)
	if _dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	_regen_mana(delta)

	if _attack_target != null:
		_chase_or_attack(delta)
		return

	if not _has_destination:
		velocity.x = 0.0
		velocity.z = 0.0
		_set_visual_moving(false)
		move_and_slide()
		return

	var to_dest := _planar_to(_destination)
	if to_dest.length() <= stop_distance:
		_arrive()
		move_and_slide()
		return

	_walk_towards(to_dest, delta)


func _chase_or_attack(delta: float) -> void:
	if _attack_target == null or not is_instance_valid(_attack_target) or not _attack_target.has_method("is_alive") or not _attack_target.call("is_alive"):
		_attack_target = null
		_arrive()
		move_and_slide()
		return

	var to_enemy := _planar_to(_attack_target.global_position)
	var distance := to_enemy.length()
	if to_enemy.length_squared() > 0.0001:
		_face_direction(to_enemy.normalized(), delta)

	if _attacking or _casting:
		velocity.x = 0.0
		velocity.z = 0.0
		_set_visual_moving(false)
		move_and_slide()
		return

	if _cast_queued and has_rune("fuego"):
		if distance <= spell_range:
			velocity.x = 0.0
			velocity.z = 0.0
			_set_visual_moving(false)
			move_and_slide()
			_start_cast()
			return
		_walk_towards(to_enemy, delta)
		_show_marker(_attack_target.global_position, Color(1.0, 0.45, 0.12, 0.85))
		return

	if distance <= attack_range:
		velocity.x = 0.0
		velocity.z = 0.0
		_set_visual_moving(false)
		move_and_slide()
		_start_attack()
		return

	_walk_towards(to_enemy, delta)
	_show_marker(_attack_target.global_position, Color(0.95, 0.28, 0.22, 0.8))


func _start_cast() -> void:
	if _casting or _attacking:
		return
	if not spend_mana(firebolt_cost):
		_cast_queued = false
		return
	_casting = true
	_cast_queued = false
	var duration := 0.7
	if _visual != null and _visual.has_method("play_cast"):
		duration = maxf(float(_visual.call("play_cast")), 0.4)
	get_tree().create_timer(duration * 0.42).timeout.connect(_spawn_firebolt)
	get_tree().create_timer(duration).timeout.connect(_finish_cast)


func _spawn_firebolt() -> void:
	if _dead or _attack_target == null or not is_instance_valid(_attack_target):
		return
	var bolt := Node3D.new()
	bolt.set_script(load(FIREBOLT) as Script)
	get_parent().add_child(bolt)
	var origin := global_position + Vector3(0.0, 1.2, 0.0) + global_transform.basis.z * 0.8
	bolt.global_position = origin
	bolt.call("setup", self, _attack_target, firebolt_damage)


func _finish_cast() -> void:
	_casting = false


func _spell_target() -> Node3D:
	if _attack_target != null and is_instance_valid(_attack_target) and _attack_target.has_method("is_alive") and _attack_target.call("is_alive"):
		return _attack_target
	var nearest: Node3D = null
	var best := spell_range
	for node in get_tree().get_nodes_in_group("enemy"):
		if not (node is Node3D):
			continue
		var enemy := node as Node3D
		if not enemy.has_method("is_alive") or not enemy.call("is_alive"):
			continue
		var dist := _planar_to(enemy.global_position).length()
		if dist < best:
			best = dist
			nearest = enemy
	return nearest


func _ensure_spell_action() -> void:
	if not InputMap.has_action(SPELL_ACTION):
		InputMap.add_action(SPELL_ACTION)
	if InputMap.action_get_events(SPELL_ACTION).is_empty():
		var key := InputEventKey.new()
		key.physical_keycode = KEY_1
		InputMap.action_add_event(SPELL_ACTION, key)


func _start_attack() -> void:
	if _attacking or _casting:
		return
	_attacking = true
	var duration := 0.7
	if _visual != null and _visual.has_method("play_attack"):
		duration = maxf(float(_visual.call("play_attack")), 0.35)
	get_tree().create_timer(duration * 0.38).timeout.connect(_deal_attack_damage)
	get_tree().create_timer(duration).timeout.connect(_finish_attack)


func _deal_attack_damage() -> void:
	if _dead or _attack_target == null or not is_instance_valid(_attack_target):
		return
	if _planar_to(_attack_target.global_position).length() > attack_range + 1.15:
		return
	if _attack_target.has_method("take_damage"):
		_attack_target.call("take_damage", attack_damage, self)


func _finish_attack() -> void:
	_attacking = false


func _resolve_click(screen_pos: Vector2) -> void:
	var enemy := _pick_enemy(screen_pos)
	if enemy:
		attack_node(enemy)
		return

	var hit: Vector3 = _pick_ground_point(screen_pos)
	if hit.is_finite():
		move_to(hit)


func _pick_enemy(screen_pos: Vector2) -> Node3D:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * click_ray_length)
	query.collision_mask = ACTOR_MASK
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	var collider: Object = result.collider
	if collider is Node3D and (collider as Node3D).is_in_group("enemy"):
		return collider as Node3D
	return null


func _walk_towards(to_dest: Vector3, delta: float) -> void:
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
		var via_nav := _planar_to(next)
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
	if _marker and _attack_target == null:
		_marker.visible = false


func _die() -> void:
	_dead = true
	_attack_target = null
	_has_destination = false
	_cast_queued = false
	_casting = false
	if _visual and _visual.has_method("play_death"):
		_visual.call("play_death")
	get_tree().create_timer(3.0).timeout.connect(_respawn)


func _respawn() -> void:
	_dead = false
	hp = max_hp
	mp = max_mp
	_mp_frac = 0.0
	global_position = Vector3(0.0, 0.05, 0.0)
	_refresh_hp()
	if _visual and _visual.has_method("reset_alive"):
		_visual.call("reset_alive")


func _planar_to(world_pos: Vector3) -> Vector3:
	return Vector3(world_pos.x - global_position.x, 0.0, world_pos.z - global_position.z)


func _show_marker(world_pos: Vector3, color: Color) -> void:
	if _marker == null:
		return
	_marker.global_position = Vector3(world_pos.x, 0.05, world_pos.z)
	_marker.visible = true
	var material := _marker.material_override as StandardMaterial3D
	if material:
		material.albedo_color = color


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


func _create_hp_bar() -> void:
	var bar_script := load("res://Scripts/HealthBar3D.gd") as Script
	_hp_bar = Node3D.new()
	_hp_bar.set_script(bar_script)
	_hp_bar.position = Vector3(0.0, 2.15, 0.0)
	add_child(_hp_bar)
	_hp_bar.call("setup", float(max_hp))


func _regen_mana(delta: float) -> void:
	if mp >= max_mp:
		_mp_frac = 0.0
		return
	_mp_frac += mp_regen * delta
	if _mp_frac < 1.0:
		return
	var add := int(_mp_frac)
	_mp_frac -= float(add)
	mp = mini(mp + add, max_mp)


func _refresh_hp() -> void:
	if _hp_bar and _hp_bar.has_method("set_ratio"):
		_hp_bar.call("set_ratio", float(hp) / float(max_hp))


func _spawn_popup(amount: int, color: Color) -> void:
	var popup := Label3D.new()
	popup.text = str(amount)
	popup.modulate = color
	popup.font_size = 48
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.position = Vector3(0.0, 2.0, 0.0)
	popup.no_depth_test = true
	add_child(popup)
	var tween := create_tween()
	tween.tween_property(popup, "position:y", 2.7, 0.55)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.55)
	tween.tween_callback(popup.queue_free)
