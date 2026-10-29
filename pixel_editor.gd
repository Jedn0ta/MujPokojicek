extends Control
## Malování vlastní tapety: mřížka 25 × 25 čtverečků. Prstem se maluje vybranou barvou.

signal changed

const N := 25
const PALETTE := [Color("ffffff"), Color("ff5d73"), Color("ff8ab3"), Color("ffc93c"), Color("ffe14d"), Color("4fbf6e"), Color("5cc6b8"), Color("6fa8ff"), Color("9b7cff"), Color("b5784a"), Color("4a3a6a"), Color("231c2a")]

var pix: Array = []     # N*N čísel: -1 = barva stěny, jinak index do PALETTE
var brush := 1
var base := Color("ffe8c2")
var _painting := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(300, 300)
	if pix.size() != N * N:
		pix = []; pix.resize(N * N); pix.fill(-1)

func _cell(p: Vector2) -> int:
	var s: float = min(size.x, size.y) / N
	var x := int(p.x / s); var y := int(p.y / s)
	if x < 0 or y < 0 or x >= N or y >= N: return -1
	return y * N + x

func _paint(p: Vector2) -> void:
	var c := _cell(p)
	if c >= 0 and pix[c] != brush:
		pix[c] = brush; queue_redraw(); changed.emit()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_painting = e.pressed
		if e.pressed: _paint(e.position)
		accept_event()
	elif e is InputEventMouseMotion and _painting:
		_paint(e.position)
		accept_event()

func fill_all() -> void:
	pix.fill(brush); queue_redraw(); changed.emit()

func clear() -> void:
	pix.fill(-1); queue_redraw(); changed.emit()

func _draw() -> void:
	var s: float = min(size.x, size.y) / N
	draw_rect(Rect2(Vector2.ZERO, Vector2(s * N, s * N)), base)
	for i in N * N:
		var v := int(pix[i])
		if v >= 0:
			draw_rect(Rect2((i % N) * s, (i / N) * s, s, s), PALETTE[v])
	for k in N + 1:
		var c := Color(0, 0, 0, 0.12 if k % 5 else 0.25)
		draw_line(Vector2(k * s, 0), Vector2(k * s, N * s), c, 1)
		draw_line(Vector2(0, k * s), Vector2(N * s, k * s), c, 1)

static func make_texture(pix: Array, base: Color) -> ImageTexture:
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for i in N * N:
		var v := int(pix[i]) if i < pix.size() else -1
		img.set_pixel(i % N, i / N, base if v < 0 else PALETTE[v])
	return ImageTexture.create_from_image(img)
