extends CharacterBody3D
## Enemigo del MVP: usa el bárbaro KayKit como cuerpo.

const BARBARIAN := "res://Models/characters/Barbarian.glb"


func _ready() -> void:
	_hide_placeholders()
	_load_model()


func _physics_process(delta: float) -> void:
	var gravity := 9.8
	if ProjectSettings.has_setting("physics/3d/default_gravity"):
		gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if velocity.y < 0.0:
			velocity.y = 0.0
	move_and_slide()


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
	var player := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player and player.has_animation("Idle"):
		var idle := player.get_animation("Idle")
		if idle:
			idle.loop_mode = Animation.LOOP_LINEAR
		player.play("Idle")
