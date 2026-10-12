extends CharacterBody3D
## Bárbaro enemigo: idle, agro, persecución, ataque y muerte.

const BARBARIAN := "res://Models/characters/Barbarian.glb"
const IDLE_CLIP := "Idle"
const WALK_CLIP := "Walking_A"
const ATTACK_CLIP := "1H_Melee_Attack_Chop"
const DEATH_CLIP := "Death_A"

@export var move_speed: float = 3.4
@export var rotation_speed: float = 10.0
@export var max_hp: int = 42
@export var attack_damage: int = 8
@export var attack_range: float = 1.9
@export var aggro_range: float = 8.5
@export var leash_range: float = 16.0
@export var essence_reward: int = 8
@export var respawn_seconds: float = 12.0

var hp: int = 42
var _spawn: Vector3 = Vector3.ZERO
var _anim: AnimationPlayer
var _player: Node3D
var _attacking: bool = false
var _dead: bool = false
var _hp_bar: Node


func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	_spawn = global_position
	_hide_placeholders()
	_load_model()
	_create_hp_bar()


func is_alive() -> bool:
	return not _dead and hp > 0


func take_damage(amount: int, from: Node3D) -> void:
	if _dead:
		return
	hp = maxi(hp - amount, 0)
	if _hp_bar and _hp_bar.has_method("set_ratio"):
		_hp_bar.call("set_ratio", float(hp) / float(max_hp))
	_spawn_popup(amount)
	if from is Node3D:
		_player = from
	if hp <= 0:
		_die()


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	if _dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	_player = _resolve_player()
	if _player == null:
		_idle()
		move_and_slide()
		return

	var to_player := _planar_to(_player.global_position)
	var dist := to_player.length()
	var from_spawn := _planar_to(_spawn).length()

	if from_spawn > leash_range:
		_return_home(delta)
		return

	if dist <= attack_range:
		_face_direction(to_player.normalized(), delta)
		velocity.x = 0.0
		velocity.z = 0.0
		_play_if_free(IDLE_CLIP)
		move_and_slide()
		if not _attacking:
			_start_attack()
		return

	if dist <= aggro_range or hp < max_hp:
		_chase(to_player, delta)
		return

	_idle()
	move_and_slide()


func _chase(to_player: Vector3, delta: float) -> void:
	if _attacking:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var walk := to_player.normalized()
	_face_direction(walk, delta)
	_play_if_free(WALK_CLIP)
	velocity.x = walk.x * move_speed
	velocity.z = walk.z * move_speed
	move_and_slide()


func _return_home(delta: float) -> void:
	var home := _planar_to(_spawn)
	if home.length() < 0.4:
		_player = null
		_idle()
		move_and_slide()
		return
	var walk := home.normalized()
	_face_direction(walk, delta)
	_play_if_free(WALK_CLIP)
	velocity.x = walk.x * move_speed
	velocity.z = walk.z * move_speed
	move_and_slide()


func _start_attack() -> void:
	if _anim == null or not _anim.has_animation(ATTACK_CLIP):
		return
	_attacking = true
	_anim.play(ATTACK_CLIP)
	var duration := _anim.get_animation(ATTACK_CLIP).length
	get_tree().create_timer(duration * 0.4).timeout.connect(_deal_attack)
	get_tree().create_timer(duration).timeout.connect(_finish_attack)


func _deal_attack() -> void:
	if _dead or _player == null or not is_instance_valid(_player):
		return
	if _planar_to(_player.global_position).length() > attack_range + 0.4:
		return
	if _player.has_method("take_damage"):
		_player.call("take_damage", attack_damage, self)


func _finish_attack() -> void:
	_attacking = false
	if not _dead:
		_play_if_free(IDLE_CLIP)


func _idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_play_if_free(IDLE_CLIP)


func _die() -> void:
	_dead = true
	_attacking = false
	collision_layer = 0
	_play_forced(DEATH_CLIP)
	_grant_essence()
	get_tree().create_timer(2.8).timeout.connect(_begin_respawn)


func _grant_essence() -> void:
	var player := _resolve_player()
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
	if player != null and player.has_method("gain_essence"):
		player.call("gain_essence", essence_reward)
	var popup := Label3D.new()
	popup.text = "+%d esencia" % essence_reward
	popup.modulate = Color(0.78, 0.55, 1.0)
	popup.font_size = 40
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.position = Vector3(0.0, 2.25, 0.0)
	popup.no_depth_test = true
	add_child(popup)
	var tween := create_tween()
	tween.tween_property(popup, "position:y", 3.0, 0.7)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.7)
	tween.tween_callback(popup.queue_free)


func _begin_respawn() -> void:
	visible = false
	get_tree().create_timer(respawn_seconds).timeout.connect(_respawn)


func _respawn() -> void:
	_dead = false
	_attacking = false
	hp = max_hp
	collision_layer = 2
	global_position = _spawn
	visible = true
	if _hp_bar and _hp_bar.has_method("set_ratio"):
		_hp_bar.call("set_ratio", 1.0)
	_play_forced(IDLE_CLIP)


func _play_if_free(clip: String) -> void:
	if _attacking or _anim == null or not _anim.has_animation(clip):
		return
	if _anim.current_animation == clip:
		return
	_anim.play(clip)


func _play_forced(clip: String) -> void:
	if _anim and _anim.has_animation(clip):
		_anim.play(clip)


func _face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var target := Basis.looking_at(direction, Vector3.UP, true)
	global_transform.basis = global_transform.basis.slerp(target, clampf(rotation_speed * delta, 0.0, 1.0)).orthonormalized()


func _apply_gravity(delta: float) -> void:
	var gravity := 9.8
	if ProjectSettings.has_setting("physics/3d/default_gravity"):
		gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0


func _resolve_player() -> Node3D:
	if _player != null and is_instance_valid(_player) and _player.has_method("is_alive") and _player.call("is_alive"):
		return _player
	var found := get_tree().get_first_node_in_group("player")
	if found is Node3D and found.has_method("is_alive") and found.call("is_alive"):
		return found as Node3D
	return null


func _planar_to(world_pos: Vector3) -> Vector3:
	return Vector3(world_pos.x - global_position.x, 0.0, world_pos.z - global_position.z)


func _hide_placeholders() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false


func _load_model() -> void:
	if not ResourceLoader.exists(BARBARIAN):
		return
	var packed := load(BARBARIAN) as PackedScene
	if packed == null:
		return
	var inst := packed.instantiate() as Node3D
	inst.name = "Barbarian"
	inst.scale = Vector3.ONE * 1.35
	add_child(inst)
	_anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for clip in [IDLE_CLIP, WALK_CLIP]:
			if _anim.has_animation(clip):
				var animation := _anim.get_animation(clip)
				if animation:
					animation.loop_mode = Animation.LOOP_LINEAR
		if _anim.has_animation(IDLE_CLIP):
			_anim.play(IDLE_CLIP)
	_setup_gear(inst)


func _setup_gear(root: Node3D) -> void:
	for node_name in ["2H_Axe", "1H_Axe_Offhand", "Mug"]:
		var extra := root.find_child(node_name, true, false) as Node3D
		if extra:
			extra.visible = false
	for node_name in ["1H_Axe", "Barbarian_Round_Shield"]:
		var gear := root.find_child(node_name, true, false) as Node3D
		if gear:
			gear.visible = true


func _create_hp_bar() -> void:
	var bar_script := load("res://Scripts/HealthBar3D.gd") as Script
	_hp_bar = Node3D.new()
	_hp_bar.set_script(bar_script)
	_hp_bar.position = Vector3(0.0, 2.05, 0.0)
	add_child(_hp_bar)
	_hp_bar.call("setup", float(max_hp))


func _spawn_popup(amount: int) -> void:
	var popup := Label3D.new()
	popup.text = str(amount)
	popup.modulate = Color(1.0, 0.85, 0.25)
	popup.font_size = 48
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.position = Vector3(0.0, 2.0, 0.0)
	popup.no_depth_test = true
	add_child(popup)
	var tween := create_tween()
	tween.tween_property(popup, "position:y", 2.7, 0.5)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.5)
	tween.tween_callback(popup.queue_free)
