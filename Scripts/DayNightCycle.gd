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
	_apply(0.0)


func _process(delta: float) -> void:
	_time += delta
	_apply(_time)


func _apply(elapsed: float) -> void:
	if _campfire == null:
		_find_campfire()
	if _sun == null or _world_env == null or _world_env.environment == null:
		return

	var cycle := day_seconds + night_seconds
	var t := fmod(elapsed, cycle)
	var is_day := t < day_seconds
	var phase_t := t / day_seconds if is_day else (t - day_seconds) / night_seconds
	var day_factor := _day_factor(is_day, phase_t)
	var env := _world_env.environment

	var sun_color := _sample_sun_color(day_factor, is_day, phase_t)
	_sun.light_color = sun_color
	_sun.light_energy = lerpf(0.22, 1.45, day_factor)
	_sun.rotation_degrees = Vector3(
		lerpf(-22.0, -58.0, day_factor),
		lerpf(-70.0, 130.0, phase_t if is_day else 1.0 - phase_t),
		0.0
	)

	env.background_color = _day_sky.lerp(_night_sky, 1.0 - day_factor)
	env.ambient_light_color = _day_ambient.lerp(_night_ambient, 1.0 - day_factor)
	env.ambient_light_energy = lerpf(0.48, 0.18, 1.0 - day_factor)
	env.fog_enabled = true
	env.fog_light_color = env.background_color
	env.fog_density = lerpf(0.0006, 0.0035, 1.0 - day_factor)

	if _campfire:
		_campfire.light_energy = lerpf(0.15, 2.4, 1.0 - day_factor)
		_campfire.light_color = Color(1.0, 0.52, 0.18)

	if _label:
		_label.text = _phase_name(is_day, phase_t, day_factor)
		_label.modulate = Color(0.85, 0.9, 0.7, 0.85)


func _day_factor(is_day: bool, phase_t: float) -> float:
	var fade := twilight_seconds / maxf(day_seconds if is_day else night_seconds, 0.001)
	if is_day:
		if phase_t < fade:
			return smoothstep(0.0, 1.0, phase_t / fade)
		if phase_t > 1.0 - fade:
			return smoothstep(0.0, 1.0, (1.0 - phase_t) / fade)
		return 1.0
	if phase_t < fade:
		return 1.0 - smoothstep(0.0, 1.0, phase_t / fade)
	if phase_t > 1.0 - fade:
		return smoothstep(0.0, 1.0, (phase_t - (1.0 - fade)) / fade)
	return 0.0


func _sample_sun_color(day_factor: float, is_day: bool, phase_t: float) -> Color:
	var fade := twilight_seconds / maxf(day_seconds if is_day else night_seconds, 0.001)
	if is_day and phase_t < fade:
		return _dawn_sun.lerp(_noon_sun, day_factor)
	if is_day and phase_t > 1.0 - fade:
		return _dusk_sun.lerp(_noon_sun, day_factor)
	if day_factor > 0.5:
		return _noon_sun
	return _moon.lerp(_dusk_sun, day_factor * 2.0)


func _phase_name(is_day: bool, phase_t: float, day_factor: float) -> String:
	if day_factor > 0.85:
		return "DIA"
	if day_factor < 0.15:
		return "NOCHE"
	if is_day and phase_t < 0.5:
		return "AMANECER"
	if is_day:
		return "ATARDECER"
	if phase_t > 0.5:
		return "AMANECER"
	return "ATARDECER"


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
