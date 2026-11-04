extends Control
## Malování vlastní tapety: mřížka čtverečků (25 × 25 nebo 40 × 40). Prstem se maluje vybranou barvou,
## lupou se plátno přibližuje a ručičkou posouvá.

signal changed

const N := 25          # výchozí velikost (kvůli starším uloženým tapetám)
const SIZES := [25, 40]
const PALETTE := [Color("ffffff"), Color("ff5d73"), Color("ff8ab3"), Color("ffc93c"), Color("ffe14d"), Color("4fbf6e"), Color("5cc6b8"), Color("6fa8ff"), Color("9b7cff"), Color("b5784a"), Color("4a3a6a"), Color("231c2a"),
	Color("ffd6e0"), Color("d9f5d0"), Color("cfe6ff"), Color("ff9a3c"), Color("2f9e44"), Color("1c5fae"), Color("e0d4ff"), Color("8a98a8")]

var n := N
var pix: Array = []     # n*n čísel: -1 = barva stěny, jinak index do PALETTE
var brush := 1
var base := Color("ffe8c2")
var zoom := 1.0
var offset := Vector2.ZERO
var hand := false
var _painting := false
var _last := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	if pix.size() == 0:
		pix.resize(n * n); pix.fill(-1)
	n = int(round(sqrt(pix.size())))

func cell_size() -> float:
	return minf(size.x, size.y) / n * zoom

func _cell(p: Vector2) -> int:
	var s := cell_size()
	var q := p - offset
	var x := int(floor(q.x / s)); var y := int(floor(q.y / s))
	if x < 0 or y < 0 or x >= n or y >= n: return -1
	return y * n + x

func _paint(p: Vector2) -> void:
	var c := _cell(p)
	if c >= 0 and pix[c] != brush:
		pix[c] = brush; queue_redraw(); changed.emit()

func _clamp_offset() -> void:
	var full := cell_size() * n
	var view := minf(size.x, size.y)
	offset.x = clampf(offset.x, minf(0.0, view - full), 0.0)
	offset.y = clampf(offset.y, minf(0.0, view - full), 0.0)

func set_zoom(z: float) -> void:
	var view := minf(size.x, size.y)
	var center := (Vector2(view, view) * 0.5 - offset) / cell_size()     # střed v čtverečcích
	zoom = clampf(z, 1.0, 4.0)
	offset = Vector2(view, view) * 0.5 - center * cell_size()
	_clamp_offset(); queue_redraw()

func resize_grid(nn: int) -> void:
	if nn == n: return
	var np := []; np.resize(nn * nn)
	for y in nn:
		for x in nn:
			np[y * nn + x] = pix[int(y * n / nn) * n + int(x * n / nn)]
	pix = np; n = nn; offset = Vector2.ZERO; zoom = 1.0
	queue_redraw(); changed.emit()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_painting = e.pressed; _last = e.position
		if e.pressed and not hand: _paint(e.position)
		accept_event()
	elif e is InputEventMouseMotion and _painting:
		if hand:
			offset += e.position - _last; _clamp_offset(); queue_redraw()
		else:
			# i rychlý tah prstem namaluje souvislou čáru
			var steps := int(ceil(_last.distance_to(e.position) / maxf(cell_size() * 0.5, 1.0)))
			for k in steps + 1: _paint(_last.lerp(e.position, float(k) / maxi(steps, 1)))
		_last = e.position
		accept_event()

func fill_all() -> void:
	pix.fill(brush); queue_redraw(); changed.emit()

func clear() -> void:
	pix.fill(-1); queue_redraw(); changed.emit()

func _draw() -> void:
	var s := cell_size()
	draw_rect(Rect2(offset, Vector2(s * n, s * n)), base)
	for i in n * n:
		var v := int(pix[i])
		if v >= 0:
			draw_rect(Rect2(offset + Vector2((i % n) * s, (i / n) * s), Vector2(s, s)), PALETTE[v % PALETTE.size()])
	for k in n + 1:
		var c := Color(0, 0, 0, 0.1 if k % 5 else 0.25)
		draw_line(offset + Vector2(k * s, 0), offset + Vector2(k * s, n * s), c, 1)
		draw_line(offset + Vector2(0, k * s), offset + Vector2(n * s, k * s), c, 1)

static func make_texture(p: Array, base_col: Color) -> ImageTexture:
	var nn := maxi(1, int(round(sqrt(p.size())))) if p.size() > 0 else N
	var img := Image.create(nn, nn, false, Image.FORMAT_RGBA8)
	for i in nn * nn:
		var v := int(p[i]) if i < p.size() else -1
		img.set_pixel(i % nn, i / nn, base_col if v < 0 else PALETTE[v % PALETTE.size()])
	return ImageTexture.create_from_image(img)
