extends Node3D
## Caballero KayKit: frente +Z, idle/walk/ataque y arma/escudo del GLB.

const KNIGHT := "res://Models/characters/Knight.glb"
const IDLE_CLIP := "Idle"
const WALK_CLIP := "Walking_A"
const ATTACK_CLIP := "1H_Melee_Attack_Chop"
const CAST_CLIP := "Spellcast_Shoot"
const DEATH_CLIP := "Death_A"
const SHOW_GEAR := ["1H_Sword", "Round_Shield"]
const HIDE_GEAR := [
	"2H_Sword", "1H_Sword_Offhand", "Badge_Shield",
	"Rectangle_Shield", "Spike_Shield",
]

var _anim: AnimationPlayer
var _moving: bool = false
var _busy: bool = false


func _ready() -> void:
	var knight := _instantiate(KNIGHT)
	if knight == null:
		return
	knight.name = "Knight"
	scale = Vector3.ONE * 1.45
	add_child(knight)
	_setup_gear(knight)
	_setup_animations(knight)
	play_idle()


func is_busy() -> bool:
	return _busy


func set_moving(moving: bool) -> void:
	_moving = moving
	if _busy:
		return
	if moving:
		play_walk()
	else:
		play_idle()


func play_idle() -> void:
	if _busy:
		return
	_play(IDLE_CLIP)


func reset_alive() -> void:
	_busy = false
	_moving = false
	_play(IDLE_CLIP)


func play_walk() -> void:
	if _busy:
		return
	_play(WALK_CLIP)


func play_attack() -> float:
	return _play_busy(ATTACK_CLIP, 0.55)


func play_cast() -> float:
	if _anim != null and _anim.has_animation(CAST_CLIP):
		return _play_busy(CAST_CLIP, 0.7)
	if _anim != null and _anim.has_animation("Spellcast_Raise"):
		return _play_busy("Spellcast_Raise", 0.7)
	return _play_busy(ATTACK_CLIP, 0.55)


func _play_busy(clip: String, fallback: float) -> float:
	if _anim == null or not _anim.has_animation(clip):
		return fallback
	_busy = true
	_anim.play(clip)
	if not _anim.animation_finished.is_connected(_on_anim_finished):
		_anim.animation_finished.connect(_on_anim_finished)
	return _anim.get_animation(clip).length


func play_death() -> void:
	_busy = true
	_play(DEATH_CLIP)


func _on_anim_finished(clip: StringName) -> void:
	if String(clip) == DEATH_CLIP:
		return
	_busy = false
	if _moving:
		play_walk()
	else:
		play_idle()


func _play(clip: String) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	if _anim.current_animation == clip:
		return
	_anim.play(clip)


func _instantiate(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as Node3D


func _setup_animations(root: Node3D) -> void:
	_anim = root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null:
		return
	for clip in [IDLE_CLIP, WALK_CLIP, "Walking_B", "Walking_C", "Running_A"]:
		if not _anim.has_animation(clip):
			continue
		var animation := _anim.get_animation(clip)
		if animation:
			animation.loop_mode = Animation.LOOP_LINEAR


func _setup_gear(root: Node3D) -> void:
	for node_name in HIDE_GEAR:
		var extra := root.find_child(node_name, true, false) as Node3D
		if extra:
			extra.visible = false
	for node_name in SHOW_GEAR:
		var gear := root.find_child(node_name, true, false) as Node3D
		if gear:
			gear.visible = true
