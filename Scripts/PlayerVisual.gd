extends Node3D
## Caballero KayKit: frente +Z, idle/walk y arma/escudo del propio GLB.

const KNIGHT := "res://Models/characters/Knight.glb"
const IDLE_CLIP := "Idle"
const WALK_CLIP := "Walking_A"
const SHOW_GEAR := ["1H_Sword", "Round_Shield"]
const HIDE_GEAR := [
	"2H_Sword", "1H_Sword_Offhand", "Badge_Shield",
	"Rectangle_Shield", "Spike_Shield",
]

var _anim: AnimationPlayer
var _moving: bool = false


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


func set_moving(moving: bool) -> void:
	if _moving == moving:
		return
	_moving = moving
	if moving:
		play_walk()
	else:
		play_idle()


func play_idle() -> void:
	_play(IDLE_CLIP)


func play_walk() -> void:
	_play(WALK_CLIP)


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
