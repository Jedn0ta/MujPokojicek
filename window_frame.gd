extends Control
## Rámeček okna přes výhled ven. Okenní tabulky (cols × rows) jsou zároveň
## políčka minihry "Co se změnilo?". Záclony se umí zatáhnout a roztáhnout.

var cols := 2
var rows := 2
var curtain := 0.0        # 0 = roztažené, 1 = zatažené
var highlight := -1       # tabulka, kterou ukázat (nápověda)
var flash := -1           # tabulka, kam dítě ťuklo špatně
var flash_t := 0.0
var _t := 0.0
var _stars: Array = []    # [pozice, rychlost, život]

const B := 26.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func inner() -> Rect2:
	return Rect2(B, B, size.x - 2 * B, size.y - B - B * 1.6)

func pane_rect(i: int) -> Rect2:
	var r := inner()
	var w := r.size.x / cols; var h := r.size.y / rows
	return Rect2(r.position + Vector2((i % cols) * w, (i / cols) * h), Vector2(w, h))

func pane_at(p: Vector2) -> int:
	var r := inner()
	if not r.has_point(p): return -1
	var cx := int((p.x - r.position.x) / (r.size.x / cols))
	var cy := int((p.y - r.position.y) / (r.size.y / rows))
	return clampi(cy, 0, rows - 1) * cols + clampi(cx, 0, cols - 1)

func celebrate(at: Vector2) -> void:
	for k in 14:
		var a := TAU * k / 14.0
		_stars.append([at, Vector2(cos(a), sin(a)) * randf_range(180, 360), 1.0])

func _process(d: float) -> void:
	_t += d
	flash_t = max(0.0, flash_t - d)
	for s in _stars:
		s[0] += s[1] * d; s[1].y += 400 * d; s[2] -= d * 0.9
	_stars = _stars.filter(func(s): return s[2] > 0)
	queue_redraw()

func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2 + PI * k / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)

func _draw() -> void:
	var w := size.x; var h := size.y
	var white := Color.WHITE
	var r := inner()
	# zatažené záclony (přes výhled)
	if curtain > 0.001:
		for s in [0, 1]:
			var cw := r.size.x / 2.0 * curtain + 4
			var x0 := r.position.x if s == 0 else r.end.x - cw
			draw_rect(Rect2(x0, r.position.y, cw, r.size.y), Data.PINK)
			var folds := 7
			for f in folds:
				var fx := x0 + cw * (f + 0.5) / folds
				draw_rect(Rect2(fx - 3, r.position.y, 6, r.size.y), Data.PINK.darkened(0.1))
	# rám a příčky
	draw_rect(Rect2(0, 0, w, B), white); draw_rect(Rect2(0, h - B * 1.6, w, B * 1.6), white)
	draw_rect(Rect2(0, 0, B, h), white); draw_rect(Rect2(w - B, 0, B, h), white)
	for c in range(1, cols):
		var x := r.position.x + r.size.x * c / cols
		draw_rect(Rect2(x - 7, r.position.y, 14, r.size.y), white)
	for c in range(1, rows):
		var y := r.position.y + r.size.y * c / rows
		draw_rect(Rect2(r.position.x, y - 7, r.size.x, 14), white)
	draw_rect(Rect2(0, h - B * 1.6, w, 10), Color("e7d9c9"))
	# ozdobné záclonky po stranách
	for s in [0, 1]:
		var x0 := 0.0 if s == 0 else w
		var dir := 1.0 if s == 0 else -1.0
		var pts := PackedVector2Array([Vector2(x0, 0), Vector2(x0 + dir * w * 0.07, 0), Vector2(x0 + dir * w * 0.045, h * 0.5), Vector2(x0 + dir * w * 0.06, h - B * 1.6), Vector2(x0, h - B * 1.6)])
		draw_colored_polygon(pts, Data.PINK)
		draw_circle(Vector2(x0 + dir * w * 0.045, h * 0.5), 10, Color("ffd25a"))
	draw_rect(Rect2(0, 0, w, 14), Color("b5784a"))
	if highlight >= 0:
		var pr := pane_rect(highlight).grow(-10)
		var a := 0.5 + 0.5 * sin(_t * 8.0)
		draw_rect(pr, Color(1, 0.85, 0.2, 0.25 + 0.25 * a))
		draw_rect(pr, Color("ffc93c"), false, 8)
	if flash >= 0 and flash_t > 0:
		draw_rect(pane_rect(flash).grow(-10), Color(1, 0.4, 0.45, flash_t * 0.6))
	for s in _stars:
		_star(s[0], 18, Color(1, 0.85, 0.2, s[2]))
