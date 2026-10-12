extends Node
## Ciclo de 2 minutos: 60 s de día y 60 s de noche, con transiciones de crepúsculo.

@export var day_seconds: float = 60.0
@export var night_seconds: float = 60.0
@export var twilight_seconds: float = 8.0

@onready var _sun: DirectionalLight3D = $"../DirectionalLight3D"
@onready var _world_env: WorldEnvironment = $"../WorldEnvironment"

var _time: float = 10.0
var _label: Label
var _campfire: OmniLight3D


func _ready() -> void:
	_make_label()
	_find_campfire()
	_apply(_time)


func _process(delta: float) -> void:
	_time += delta
	_apply(_time)


func _apply(elapsed: float) -> void:
	if _campfire == null:
		_find_campfire()
	if _sun == null or _world_env == null or _world_env.environment == null:
		return

	var cycle := day_seconds + night_seconds
	var t := fposmod(elapsed, cycle)
	var day_factor := _day_factor(t)
	var clock := t / cycle
	var env := _world_env.environment

	_sun.light_color = _sample_sun_color(t, day_factor)
	_sun.light_energy = lerpf(0.18, 1.45, day_factor)
	_sun.rotation_degrees = Vector3(
		lerpf(-18.0, -58.0, day_factor),
		lerpf(-70.0, 290.0, clock),
		0.0
	)

	env.background_color = _night_sky.lerp(_day_sky, day_factor)
	env.ambient_light_color = _night_ambient.lerp(_day_ambient, day_factor)
	env.ambient_light_energy = lerpf(0.16, 0.48, day_factor)
	env.fog_enabled = true
	env.fog_light_color = env.background_color
	env.fog_density = lerpf(0.0035, 0.0006, day_factor)

	if _campfire:
		_campfire.light_energy = lerpf(2.4, 0.15, day_factor)
		_campfire.light_color = Color(1.0, 0.52, 0.18)

	if _label:
		_label.text = _phase_name(t, day_factor)
		_label.modulate = Color(0.85, 0.9, 0.7, 0.85)


func _day_factor(t: float) -> float:
	var fade := minf(twilight_seconds, day_seconds * 0.45)
	if t < fade:
		return smoothstep(0.0, fade, t)
	if t < day_seconds - fade:
		return 1.0
	if t < day_seconds:
		return smoothstep(0.0, fade, day_seconds - t)
	return 0.0


func _sample_sun_color(t: float, day_factor: float) -> Color:
	var fade := minf(twilight_seconds, day_seconds * 0.45)
	if t < fade:
		return _dawn_sun.lerp(_noon_sun, day_factor)
	if t >= day_seconds - fade and t < day_seconds:
		return _dusk_sun.lerp(_noon_sun, day_factor)
	if day_factor > 0.5:
		return _noon_sun
	return _moon


func _phase_name(t: float, _day_factor: float) -> String:
	var fade := minf(twilight_seconds, day_seconds * 0.45)
	if t < fade:
		return "AMANECER"
	if t < day_seconds - fade:
		return "DIA"
	if t < day_seconds:
		return "ATARDECER"
	return "NOCHE"


func _make_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	var label := Label.new()
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 22)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)
	add_child(layer)
	_label = label


func _find_campfire() -> void:
	var lights := get_tree().get_nodes_in_group("campfire_light")
	if lights.size() > 0 and lights[0] is OmniLight3D:
		_campfire = lights[0] as OmniLight3D


const _noon_sun := Color(1.0, 0.96, 0.82)
const _dawn_sun := Color(1.0, 0.72, 0.48)
const _dusk_sun := Color(1.0, 0.42, 0.2)
const _moon := Color(0.42, 0.55, 0.92)
const _day_sky := Color(0.42, 0.62, 0.82)
const _night_sky := Color(0.02, 0.03, 0.07)
const _day_ambient := Color(0.42, 0.5, 0.38)
const _night_ambient := Color(0.08, 0.12, 0.22)
