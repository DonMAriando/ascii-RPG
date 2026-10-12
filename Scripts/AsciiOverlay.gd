extends ColorRect
## Genera el atlas de glifos ASCII y lo inyecta en el ShaderMaterial del ColorRect.

const GLYPH_W := 8
const GLYPH_H := 8
const GLYPH_COUNT := 10

# Filas 8x8, bit 7 = columna izquierda. Densidad creciente:  . : + * ? % S # @
var _glyph_rows: Array[PackedInt32Array] = [
	PackedInt32Array([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]), # espacio
	PackedInt32Array([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18]), # .
	PackedInt32Array([0x00, 0x18, 0x18, 0x00, 0x00, 0x18, 0x18, 0x00]), # :
	PackedInt32Array([0x00, 0x18, 0x18, 0x7E, 0x7E, 0x18, 0x18, 0x00]), # +
	PackedInt32Array([0x00, 0x24, 0x18, 0x7E, 0x18, 0x24, 0x00, 0x00]), # *
	PackedInt32Array([0x3C, 0x66, 0x06, 0x0C, 0x18, 0x00, 0x18, 0x18]), # ?
	PackedInt32Array([0x62, 0x66, 0x0C, 0x18, 0x30, 0x66, 0x46, 0x00]), # %
	PackedInt32Array([0x3C, 0x66, 0x60, 0x3C, 0x06, 0x66, 0x3C, 0x00]), # S
	PackedInt32Array([0x00, 0x36, 0x7F, 0x36, 0x36, 0x7F, 0x36, 0x00]), # #
	PackedInt32Array([0x3C, 0x66, 0x6E, 0x6E, 0x60, 0x62, 0x3C, 0x00]), # @
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_force_pass_scroll_events = true
	var material_ref := material as ShaderMaterial
	if material_ref == null:
		return
	material_ref.set_shader_parameter("ascii_atlas", _build_atlas())
	material_ref.set_shader_parameter("glyph_count", GLYPH_COUNT)


func _build_atlas() -> ImageTexture:
	var image := Image.create(GLYPH_COUNT * GLYPH_W, GLYPH_H, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 1))

	for glyph_index in GLYPH_COUNT:
		var rows: PackedInt32Array = _glyph_rows[glyph_index]
		for y in GLYPH_H:
			var bits: int = rows[y]
			for x in GLYPH_W:
				if (bits & (1 << (7 - x))) != 0:
					image.set_pixel(glyph_index * GLYPH_W + x, y, Color.WHITE)

	return ImageTexture.create_from_image(image)
