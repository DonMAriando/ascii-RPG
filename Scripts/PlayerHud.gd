extends CanvasLayer
## HUD de vitales: orbes de vida/maná y acceso al árbol de magia.

const TREE_ACTION := &"arbol_magia"
const HUD_ACTION := &"hud_toggle"

var _hp_mat: ShaderMaterial
var _mp_mat: ShaderMaterial
var _hp_value: Label
var _mp_value: Label
var _hp_caption: Label
var _mp_caption: Label
var _essence_label: Label
var _tree_subtitle: Label
var _toast: Label
var _rune_marks: Array[Label] = []
var _tree_panel: Control
var _body: Control
var _toggle_btn: Button
var _hud_visible: bool = false
var _tree_open: bool = false
var _hp_flash: float = 0.0
var _mp_flash: float = 0.0
var _last_hp: int = -1
var _last_mp: int = -1


func _ready() -> void:
	layer = 30
	add_to_group("player_hud")
	_ensure_input_actions()
	_build()
	set_hud_visible(false)
	set_process(true)


func toggle_hud() -> void:
	set_hud_visible(not _hud_visible)


func set_hud_visible(shown: bool) -> void:
	_hud_visible = shown
	if _body:
		_body.visible = shown
	if not shown and _tree_open:
		toggle_magic_tree()
	_refresh_toggle_label()
	if shown:
		_sync_from_player()


func toggle_magic_tree() -> void:
	_tree_open = not _tree_open
	if _tree_panel:
		_tree_panel.visible = _tree_open
		var graph := _tree_panel.get_node_or_null("Graph") as Control
		if graph and _tree_open:
			graph.queue_redraw()
	var hint := get_node_or_null("Root/Body/Hint") as Label
	if hint:
		hint.visible = not _tree_open


func set_hint(text: String) -> void:
	var hint := get_node_or_null("Root/Body/Hint") as Label
	if hint:
		hint.text = text


func show_toast(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.55)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(HUD_ACTION):
		toggle_hud()
		get_viewport().set_input_as_handled()
		return
	if not _hud_visible:
		return
	if event.is_action_pressed(TREE_ACTION):
		toggle_magic_tree()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _hud_visible:
		return
	_hp_flash = maxf(_hp_flash - delta * 3.2, 0.0)
	_mp_flash = maxf(_mp_flash - delta * 3.2, 0.0)
	_sync_from_player()


func _sync_from_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var hp := int(player.get("hp"))
	var max_hp := maxi(int(player.get("max_hp")), 1)
	var mp := int(player.get("mp"))
	var max_mp := maxi(int(player.get("max_mp")), 1)
	if _last_hp >= 0 and hp < _last_hp:
		_hp_flash = 1.0
	if _last_mp >= 0 and mp < _last_mp:
		_mp_flash = 1.0
	_last_hp = hp
	_last_mp = mp
	var hp_ratio := float(hp) / float(max_hp)
	var mp_ratio := float(mp) / float(max_mp)
	_apply_orb(_hp_mat, hp_ratio, _hp_flash, 1.0 if hp_ratio < 0.35 else 0.0)
	_apply_orb(_mp_mat, mp_ratio, _mp_flash, 0.0)
	if _hp_value:
		_hp_value.text = "%d" % hp
	if _mp_value:
		_mp_value.text = "%d" % mp
	if _hp_caption:
		_hp_caption.text = "VIDA  %d / %d" % [hp, max_hp]
	if _mp_caption:
		_mp_caption.text = "MANÁ  %d / %d" % [mp, max_mp]
	var essence := int(player.get("essence"))
	if _essence_label:
		_essence_label.text = "ESENCIA  %d" % essence
	if _tree_subtitle:
		if player.has_method("has_rune") and player.call("has_rune", "fuego"):
			_tree_subtitle.text = "Fuego despierto · tecla 1 para lanzar"
		else:
			_tree_subtitle.text = "Esencia %d  ·  Fuego cuesta 12 para despertar" % essence
	_refresh_rune_slots(player)


func _apply_orb(mat: ShaderMaterial, ratio: float, flash: float, pulse: float) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("fill", clampf(ratio, 0.0, 1.0))
	mat.set_shader_parameter("flash", flash)
	mat.set_shader_parameter("pulse", pulse)


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_body = Control.new()
	_body.name = "Body"
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.visible = false
	_body.add_child(_make_plate())
	_body.add_child(_make_orb_cluster())
	_body.add_child(_make_hint())
	_body.add_child(_make_legend())
	_tree_panel = _make_tree_panel()
	_tree_panel.visible = false
	_body.add_child(_tree_panel)
	root.add_child(_body)
	root.add_child(_make_toggle_button())
	root.add_child(_make_toast())


func _make_plate() -> ColorRect:
	var plate := ColorRect.new()
	plate.name = "Plate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.anchor_left = 0.0
	plate.anchor_top = 1.0
	plate.anchor_right = 0.0
	plate.anchor_bottom = 1.0
	plate.offset_left = 16.0
	plate.offset_top = -196.0
	plate.offset_right = 454.0
	plate.offset_bottom = -14.0
	var mat := ShaderMaterial.new()
	mat.shader = load("res://Shaders/hud_plate.gdshader") as Shader
	plate.material = mat
	return plate


func _make_orb_cluster() -> Control:
	var box := Control.new()
	box.name = "Vitals"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.anchor_left = 0.0
	box.anchor_top = 1.0
	box.anchor_right = 0.0
	box.anchor_bottom = 1.0
	box.offset_left = 28.0
	box.offset_top = -188.0
	box.offset_right = 438.0
	box.offset_bottom = -22.0

	var hp_orb := _make_orb(
		"HpOrb",
		Vector2(8, 8),
		Color(0.8, 0.11, 0.16, 1.0),
		Color(0.2, 0.02, 0.05, 1.0),
		Color(1.0, 0.3, 0.22, 0.75),
		0.18
	)
	_hp_mat = hp_orb.material as ShaderMaterial
	box.add_child(hp_orb)
	_hp_value = _make_orb_number(Vector2(8, 48), Color(1.0, 0.86, 0.82))
	box.add_child(_hp_value)
	_hp_caption = _make_caption(Vector2(8, 136), Color(0.92, 0.55, 0.48))
	box.add_child(_hp_caption)

	var mp_orb := _make_orb(
		"MpOrb",
		Vector2(150, 8),
		Color(0.28, 0.48, 0.98, 1.0),
		Color(0.08, 0.1, 0.38, 1.0),
		Color(0.45, 0.7, 1.0, 0.8),
		0.55
	)
	_mp_mat = mp_orb.material as ShaderMaterial
	if _mp_mat:
		_mp_mat.set_shader_parameter("rim", Color(0.72, 0.84, 1.0, 1.0))
	box.add_child(mp_orb)
	_mp_value = _make_orb_number(Vector2(150, 48), Color(0.82, 0.92, 1.0))
	box.add_child(_mp_value)
	_mp_caption = _make_caption(Vector2(150, 136), Color(0.55, 0.75, 1.0))
	box.add_child(_mp_caption)

	box.add_child(_make_tree_button())
	box.add_child(_make_rune_row())
	_essence_label = _make_caption(Vector2(292, 8), Color(0.82, 0.7, 1.0))
	_essence_label.size = Vector2(108, 18)
	_essence_label.text = "ESENCIA  0"
	box.add_child(_essence_label)
	return box


func _make_orb(orb_name: String, pos: Vector2, liquid: Color, deep: Color, glow: Color, sparkle: float) -> ColorRect:
	var orb := ColorRect.new()
	orb.name = orb_name
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.position = pos
	orb.size = Vector2(128, 128)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://Shaders/hud_orb.gdshader") as Shader
	mat.set_shader_parameter("liquid", liquid)
	mat.set_shader_parameter("liquid_deep", deep)
	mat.set_shader_parameter("glow", glow)
	mat.set_shader_parameter("sparkle", sparkle)
	mat.set_shader_parameter("fill", 1.0)
	orb.material = mat
	return orb


func _make_orb_number(pos: Vector2, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = Vector2(128, 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.92))
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "0"
	return label


func _make_caption(pos: Vector2, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = Vector2(128, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_tree_button() -> Button:
	var button := Button.new()
	button.name = "TreeButton"
	button.text = "ÁRBOL  [T]"
	button.position = Vector2(292, 28)
	button.size = Vector2(108, 36)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(0.93, 0.84, 0.52))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.72))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.05, 0.92)
	style.border_color = Color(0.78, 0.62, 0.28, 0.95)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.13, 0.07, 0.95)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(toggle_magic_tree)
	return button


func _make_rune_row() -> Control:
	var row := Control.new()
	row.name = "RuneSlots"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(292, 76)
	row.size = Vector2(108, 72)
	var marks: Array[String] = ["I", "II", "III", "IV"]
	_rune_marks.clear()
	for i in 4:
		var slot := ColorRect.new()
		slot.position = Vector2(float(i % 2) * 54.0, float(i / 2) * 36.0)
		slot.size = Vector2(50, 32)
		slot.color = Color(0.06, 0.07, 0.09, 0.88)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(slot)
		var mark := Label.new()
		mark.text = marks[i]
		mark.position = slot.position
		mark.size = slot.size
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.add_theme_font_size_override("font_size", 11)
		mark.add_theme_color_override("font_color", Color(0.62, 0.56, 0.38, 0.85))
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mark)
		_rune_marks.append(mark)
	return row


func _make_hint() -> Label:
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "Clic en un bárbaro para atacar   ·   clic en el suelo para moverte"
	hint.anchor_left = 0.0
	hint.anchor_top = 1.0
	hint.anchor_right = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 470.0
	hint.offset_top = -30.0
	hint.offset_right = -24.0
	hint.offset_bottom = -8.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.78, 0.82, 0.7, 0.8))
	hint.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	hint.add_theme_constant_override("outline_size", 4)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return hint


func _make_legend() -> Label:
	var legend := Label.new()
	legend.name = "Legend"
	legend.text = "1  fuego   ·   T  árbol"
	legend.anchor_left = 1.0
	legend.anchor_top = 0.0
	legend.anchor_right = 1.0
	legend.anchor_bottom = 0.0
	legend.offset_left = -188.0
	legend.offset_top = 14.0
	legend.offset_right = -16.0
	legend.offset_bottom = 36.0
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	legend.add_theme_font_size_override("font_size", 13)
	legend.add_theme_color_override("font_color", Color(0.8, 0.74, 0.5, 0.85))
	legend.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	legend.add_theme_constant_override("outline_size", 4)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return legend


func _make_tree_panel() -> Control:
	var panel := ColorRect.new()
	panel.name = "MagicTree"
	panel.anchor_left = 1.0
	panel.anchor_top = 0.5
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.5
	panel.offset_left = -412.0
	panel.offset_top = -288.0
	panel.offset_right = -20.0
	panel.offset_bottom = 288.0
	var mat := ShaderMaterial.new()
	mat.shader = load("res://Shaders/hud_plate.gdshader") as Shader
	mat.set_shader_parameter("fill_color", Color(0.03, 0.035, 0.05, 0.92))
	mat.set_shader_parameter("edge_color", Color(0.55, 0.72, 1.0, 0.9))
	panel.material = mat
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var title := Label.new()
	title.text = "ÁRBOL DE MAGIA"
	title.position = Vector2(20, 18)
	title.size = Vector2(352, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	title.add_theme_constant_override("outline_size", 6)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Clic en Fuego para despertarlo (12 esencia)."
	subtitle.position = Vector2(24, 52)
	subtitle.size = Vector2(344, 36)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.68, 0.74, 0.86, 0.9))
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(subtitle)
	_tree_subtitle = subtitle

	var graph := Control.new()
	graph.name = "Graph"
	graph.position = Vector2(20, 100)
	graph.size = Vector2(352, 400)
	graph.mouse_filter = Control.MOUSE_FILTER_STOP
	graph.draw.connect(_draw_magic_tree)
	graph.gui_input.connect(_on_tree_gui_input)
	panel.add_child(graph)

	var close_btn := Button.new()
	close_btn.text = "Cerrar"
	close_btn.position = Vector2(136, 520)
	close_btn.size = Vector2(120, 34)
	close_btn.pressed.connect(toggle_magic_tree)
	panel.add_child(close_btn)
	return panel


func _tree_nodes() -> Array[Dictionary]:
	var player := get_tree().get_first_node_in_group("player")
	var fuego := false
	if player != null and player.has_method("has_rune"):
		fuego = bool(player.call("has_rune", "fuego"))
	var nodes: Array[Dictionary] = [
		{"id": "nucleo", "name": "Núcleo", "pos": Vector2(176, 186), "open": true},
		{"id": "fuego", "name": "Fuego", "pos": Vector2(176, 52), "open": fuego},
		{"id": "rayo", "name": "Rayo", "pos": Vector2(58, 122), "open": false},
		{"id": "hielo", "name": "Hielo", "pos": Vector2(294, 122), "open": false},
		{"id": "sangre", "name": "Sangre", "pos": Vector2(58, 262), "open": false},
		{"id": "vacio", "name": "Vacío", "pos": Vector2(294, 262), "open": false},
		{"id": "vida", "name": "Vida", "pos": Vector2(176, 332), "open": false},
	]
	return nodes


func _on_tree_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	var rune_id := _rune_at(mouse.position)
	if rune_id != "fuego":
		return
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("try_unlock_rune"):
		player.call("try_unlock_rune", "fuego")
	var graph := _tree_panel.get_node_or_null("Graph") as Control
	if graph:
		graph.queue_redraw()
	_sync_from_player()


func _rune_at(local: Vector2) -> String:
	for node in _tree_nodes():
		var pos: Vector2 = node["pos"]
		var radius := 34.0 if bool(node["open"]) else 24.0
		if local.distance_to(pos) <= radius + 8.0:
			return str(node["id"])
	return ""


func _refresh_rune_slots(player: Node) -> void:
	if _rune_marks.is_empty():
		return
	var fuego := player.has_method("has_rune") and bool(player.call("has_rune", "fuego"))
	if fuego:
		_rune_marks[0].text = "1"
		_rune_marks[0].add_theme_color_override("font_color", Color(1.0, 0.55, 0.2))
	else:
		_rune_marks[0].text = "I"
		_rune_marks[0].add_theme_color_override("font_color", Color(0.62, 0.56, 0.38, 0.85))


func _make_toast() -> Label:
	var toast := Label.new()
	toast.name = "Toast"
	toast.anchor_left = 0.5
	toast.anchor_top = 0.0
	toast.anchor_right = 0.5
	toast.anchor_bottom = 0.0
	toast.offset_left = -180.0
	toast.offset_top = 18.0
	toast.offset_right = 180.0
	toast.offset_bottom = 48.0
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 20)
	toast.add_theme_color_override("font_color", Color(0.86, 0.72, 1.0))
	toast.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	toast.add_theme_constant_override("outline_size", 7)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.modulate.a = 0.0
	_toast = toast
	return toast


func _draw_magic_tree() -> void:
	var graph := _tree_panel.get_node_or_null("Graph") as Control
	if graph == null:
		return
	var nodes: Array[Dictionary] = _tree_nodes()
	var links: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(0, 5), Vector2i(0, 6),
	]
	for link in links:
		var a: Vector2 = nodes[link.x]["pos"]
		var b: Vector2 = nodes[link.y]["pos"]
		graph.draw_line(a, b, Color(0.38, 0.52, 0.76, 0.5), 2.0, true)
	var font := ThemeDB.fallback_font
	for node in nodes:
		var pos: Vector2 = node["pos"]
		var unlocked: bool = node["open"]
		var rune_id := str(node["id"])
		var radius := 32.0 if unlocked else 22.0
		var fill := Color(0.22, 0.48, 0.92, 0.96) if unlocked else Color(0.07, 0.08, 0.1, 0.96)
		var edge := Color(0.9, 0.95, 1.0, 1.0) if unlocked else Color(0.58, 0.5, 0.34, 0.95)
		if rune_id == "fuego":
			fill = Color(0.92, 0.38, 0.1, 0.96) if unlocked else fill
			edge = Color(1.0, 0.62, 0.28, 1.0) if unlocked else edge
		graph.draw_circle(pos, radius + 4.0, Color(edge, 0.18))
		graph.draw_circle(pos, radius, fill)
		graph.draw_arc(pos, radius, 0.0, TAU, 36, edge, 2.4, true)
		if not unlocked:
			graph.draw_string(font, pos + Vector2(-5.0, 5.0), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.62, 0.56, 0.4, 0.85))
		var label: String = str(node["name"])
		var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var text_color := Color(0.88, 0.93, 1.0) if unlocked else Color(0.72, 0.68, 0.52)
		graph.draw_string(font, pos + Vector2(-size.x * 0.5, radius + 18.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, text_color)
		if rune_id == "fuego" and not unlocked:
			graph.draw_string(font, pos + Vector2(-10.0, radius + 34.0), "12", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.7, 0.4))


func _make_toggle_button() -> Button:
	var button := Button.new()
	button.name = "HudToggle"
	button.anchor_left = 0.0
	button.anchor_top = 1.0
	button.anchor_right = 0.0
	button.anchor_bottom = 1.0
	button.offset_left = 16.0
	button.offset_top = -48.0
	button.offset_right = 128.0
	button.offset_bottom = -14.0
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(0.93, 0.84, 0.52))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.72))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.05, 0.92)
	style.border_color = Color(0.78, 0.62, 0.28, 0.95)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.13, 0.07, 0.95)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(toggle_hud)
	_toggle_btn = button
	_refresh_toggle_label()
	return button


func _refresh_toggle_label() -> void:
	if _toggle_btn == null:
		return
	if _hud_visible:
		_toggle_btn.text = "OCULTAR  [H]"
		_toggle_btn.offset_left = 16.0
		_toggle_btn.offset_top = -230.0
		_toggle_btn.offset_right = 148.0
		_toggle_btn.offset_bottom = -196.0
	else:
		_toggle_btn.text = "HUD  [H]"
		_toggle_btn.offset_left = 16.0
		_toggle_btn.offset_top = -48.0
		_toggle_btn.offset_right = 128.0
		_toggle_btn.offset_bottom = -14.0


func _ensure_input_actions() -> void:
	if not InputMap.has_action(TREE_ACTION):
		InputMap.add_action(TREE_ACTION)
	if InputMap.action_get_events(TREE_ACTION).is_empty():
		var key := InputEventKey.new()
		key.physical_keycode = KEY_T
		InputMap.action_add_event(TREE_ACTION, key)
	if not InputMap.has_action(HUD_ACTION):
		InputMap.add_action(HUD_ACTION)
	if InputMap.action_get_events(HUD_ACTION).is_empty():
		var hud_key := InputEventKey.new()
		hud_key.physical_keycode = KEY_H
		InputMap.action_add_event(HUD_ACTION, hud_key)
