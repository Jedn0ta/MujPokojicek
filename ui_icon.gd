extends Control
## Roztomilé grafické tlačítko pro malé děti: obrázek místo textu.
## Ukazuje buď nakreslenou ikonu (kind), obrázek (tex), nebo barvu (col).

signal tapped

var kind := ""
var tex: Texture2D
var col := Color(0, 0, 0, 0)
var selected := false
var round_btn := false
var text := ""
var tint := Color.WHITE
var _press := 0.0

func _init(k := "", t: Texture2D = null, c := Color(0, 0, 0, 0), sz := 96.0) -> void:
	kind = k; tex = t; col = c
	custom_minimum_size = Vector2(sz, sz)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(e: InputEvent) -> void:
	var down: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
	if down:
		_press = 1.0
		tapped.emit()
		accept_event()

func _process(d: float) -> void:
	if _press > 0.0:
		_press = max(0.0, _press - d * 5.0)
		queue_redraw()

func _draw() -> void:
	var s := size
	var k := 1.0 - 0.08 * sin(_press * PI)
	draw_set_transform(s * (1.0 - k) / 2.0, 0, Vector2(k, k))
	var r := Rect2(Vector2.ZERO, s)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(s.x / 2) if round_btn else 22)
	sb.bg_color = col if col.a > 0 else (tint if not selected else Color("fff0f6"))
	sb.border_color = Data.PINK if selected else Data.LILAC
	sb.set_border_width_all(7 if selected else 4)
	sb.shadow_color = Color(0.4, 0.3, 0.6, 0.18); sb.shadow_size = 5; sb.shadow_offset = Vector2(0, 4)
	draw_style_box(sb, r)
	if tex:
		var m := s.x * 0.08
		draw_texture_rect(tex, Rect2(Vector2(m, m), s - Vector2(m, m) * 2), false)
	elif kind != "":
		_icon(kind, s / 2.0, s.x * 0.32)
	elif text != "":
		var f := get_theme_default_font(); var fs := int(s.y * 0.4)
		draw_string(f, Vector2(0, s.y / 2 + fs * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, s.x, fs, Data.INK)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _icon(k: String, c: Vector2, R: float) -> void:
	var ink := Data.INK
	var pink := Data.PINK
	var mint := Data.MINT
	var yel := Color("ffc93c")
	match k:
		"doll":
			draw_circle(c + Vector2(0, -R * 0.25), R * 0.62, Color("ffdcc2"))
			draw_arc(c + Vector2(0, -R * 0.25), R * 0.64, PI * 1.05, PI * 1.95, 16, Color("9a6634"), R * 0.3)
			draw_circle(c + Vector2(-R * 0.22, -R * 0.25), R * 0.09, ink); draw_circle(c + Vector2(R * 0.22, -R * 0.25), R * 0.09, ink)
			draw_arc(c + Vector2(0, -R * 0.12), R * 0.18, 0.3, PI - 0.3, 8, ink, 3)
			draw_rect(Rect2(c + Vector2(-R * 0.45, R * 0.38), Vector2(R * 0.9, R * 0.6)), pink)
		"house":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-R, -R * 0.05), c + Vector2(0, -R * 0.95), c + Vector2(R, -R * 0.05)]), pink)
			draw_rect(Rect2(c + Vector2(-R * 0.75, -R * 0.08), Vector2(R * 1.5, R * 1.0)), Color("ffe8c2"))
			draw_rect(Rect2(c + Vector2(-R * 0.18, R * 0.35), Vector2(R * 0.36, R * 0.57)), Color("b5784a"))
			draw_rect(Rect2(c + Vector2(R * 0.3, R * 0.1), Vector2(R * 0.3, R * 0.28)), Color("a8dcff"))
		"friends":
			for sx in [-1.0, 1.0]:
				var p := c + Vector2(sx * R * 0.45, 0)
				draw_circle(p + Vector2(0, -R * 0.2), R * 0.42, Color("ffdcc2") if sx < 0 else Color("b98058"))
				draw_circle(p + Vector2(-R * 0.13, -R * 0.22), R * 0.06, ink); draw_circle(p + Vector2(R * 0.13, -R * 0.22), R * 0.06, ink)
				draw_rect(Rect2(p + Vector2(-R * 0.32, R * 0.25), Vector2(R * 0.64, R * 0.6)), pink if sx < 0 else mint)
			_heart(c + Vector2(0, -R * 0.85), R * 0.25, Color("ff5d73"))
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-R * 0.5, -R * 0.75), c + Vector2(R * 0.8, 0), c + Vector2(-R * 0.5, R * 0.75)]), mint)
		"edit":
			draw_rect(Rect2(c + Vector2(-R * 0.15, -R * 0.2), Vector2(R * 0.3, R * 1.1)), Color("b5784a"))
			draw_rect(Rect2(c + Vector2(-R * 0.75, -R * 0.85), Vector2(R * 1.5, R * 0.65)), Color("9b7cff"))
			draw_rect(Rect2(c + Vector2(-R * 0.75, -R * 0.85), Vector2(R * 0.5, R * 0.65)), Color("b9a2e6"))
		"rotate":
			draw_arc(c, R * 0.7, -PI * 0.1, PI * 1.5, 24, mint, R * 0.22)
			var t := c + Vector2(cos(-PI * 0.1), sin(-PI * 0.1)) * R * 0.7
			draw_colored_polygon(PackedVector2Array([t + Vector2(-R * 0.35, -R * 0.1), t + Vector2(R * 0.3, -R * 0.1), t + Vector2(0, R * 0.4)]), mint)
		"trash":
			draw_rect(Rect2(c + Vector2(-R * 0.55, -R * 0.45), Vector2(R * 1.1, R * 1.2)), Color("ff5d73"))
			draw_rect(Rect2(c + Vector2(-R * 0.75, -R * 0.7), Vector2(R * 1.5, R * 0.2)), Color("e8343a"))
			for x in [-0.25, 0.0, 0.25]: draw_line(c + Vector2(R * x, -R * 0.25), c + Vector2(R * x, R * 0.55), Color.WHITE, 4)
		"plus", "minus":
			draw_circle(c, R * 0.9, mint)
			draw_rect(Rect2(c - Vector2(R * 0.55, R * 0.12), Vector2(R * 1.1, R * 0.24)), Color.WHITE)
			if k == "plus": draw_rect(Rect2(c - Vector2(R * 0.12, R * 0.55), Vector2(R * 0.24, R * 1.1)), Color.WHITE)
		"back":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-R * 0.9, 0), c + Vector2(-R * 0.1, -R * 0.7), c + Vector2(-R * 0.1, R * 0.7)]), pink)
			draw_rect(Rect2(c + Vector2(-R * 0.15, -R * 0.25), Vector2(R * 1.0, R * 0.5)), pink)
		"dice":
			var sb := StyleBoxFlat.new(); sb.bg_color = Color.WHITE; sb.border_color = Color("9b7cff"); sb.set_border_width_all(4); sb.set_corner_radius_all(int(R * 0.3))
			draw_style_box(sb, Rect2(c - Vector2(R, R) * 0.85, Vector2(R, R) * 1.7))
			for p in [Vector2(-0.45, -0.45), Vector2(0.45, -0.45), Vector2(0, 0), Vector2(-0.45, 0.45), Vector2(0.45, 0.45)]:
				draw_circle(c + p * R, R * 0.14, [Color("ff5d73"), Color("6fa8ff"), Color("ffc93c"), Color("4fbf6e"), Color("9b7cff")][int((p.x + p.y + 1.0) * 2) % 5])
		"invite":
			_icon("house", c + Vector2(0, R * 0.15), R * 0.8)
			_heart(c + Vector2(R * 0.55, -R * 0.65), R * 0.35, Color("ff5d73"))
		"search":
			draw_arc(c + Vector2(-R * 0.15, -R * 0.15), R * 0.55, 0, TAU, 24, Color("6fa8ff"), R * 0.18)
			draw_line(c + Vector2(R * 0.25, R * 0.25), c + Vector2(R * 0.8, R * 0.8), Color("6fa8ff"), R * 0.25)
		"home":
			_icon("house", c, R)
		"reset":
			draw_arc(c, R * 0.7, 0, TAU, 24, Data.LILAC, R * 0.15)
			draw_circle(c, R * 0.2, pink)
			for a in 4:
				var v := Vector2(cos(a * PI / 2), sin(a * PI / 2))
				draw_line(c + v * R * 0.45, c + v * R * 0.95, ink, 4)
		"star":
			_star(c, R, yel)
		"level1", "level2", "level3", "level4":
			var n := int(k.substr(5))
			for i in n:
				var p := c + Vector2((i - (n - 1) / 2.0) * R * 0.55, 0)
				_star(p, R * 0.32, yel)
		"window":
			draw_rect(Rect2(c - Vector2(R, R) * 0.8, Vector2(R, R) * 1.6), Color("a8dcff"))
			draw_rect(Rect2(c - Vector2(R * 0.06, R * 0.8), Vector2(R * 0.12, R * 1.6)), Color.WHITE)
			draw_rect(Rect2(c - Vector2(R * 0.8, R * 0.06), Vector2(R * 1.6, R * 0.12)), Color.WHITE)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-R, -R), c + Vector2(-R * 0.45, -R), c + Vector2(-R * 0.7, R)]), pink)
			draw_colored_polygon(PackedVector2Array([c + Vector2(R, -R), c + Vector2(R * 0.45, -R), c + Vector2(R * 0.7, R)]), pink)
		"face":
			draw_circle(c, R * 0.85, Color("ffdcc2"))
			draw_circle(c + Vector2(-R * 0.3, -R * 0.1), R * 0.12, ink); draw_circle(c + Vector2(R * 0.3, -R * 0.1), R * 0.12, ink)
			draw_arc(c + Vector2(0, R * 0.1), R * 0.3, 0.4, PI - 0.4, 10, ink, 4)
		"pencil":
			var a := c + Vector2(-R * 0.7, R * 0.7); var b := c + Vector2(R * 0.55, -R * 0.55)
			draw_line(a + Vector2(R * 0.15, -R * 0.15), b, Color("ffc93c"), R * 0.42)
			draw_colored_polygon(PackedVector2Array([a, a + Vector2(R * 0.42, 0), a + Vector2(0, -R * 0.42)]), Color("f5d0a0"))
			draw_circle(b, R * 0.21, Data.PINK)
			draw_circle(a + Vector2(0.06 * R, -0.06 * R), R * 0.07, ink)
		"mirror":
			draw_line(c + Vector2(0, -R), c + Vector2(0, R), Data.LILAC.darkened(0.2), 4)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-R * 0.15, -R * 0.6), c + Vector2(-R * 0.9, 0), c + Vector2(-R * 0.15, R * 0.6)]), pink)
			draw_colored_polygon(PackedVector2Array([c + Vector2(R * 0.15, -R * 0.6), c + Vector2(R * 0.9, 0), c + Vector2(R * 0.15, R * 0.6)]), pink if selected else Data.LILAC)
		"puff", "unpuff":
			var rr := R * (0.85 if k == "puff" else 0.5)
			draw_circle(c, rr, Color("ffdcc2"))
			draw_circle(c + Vector2(-rr * 0.35, -rr * 0.1), rr * 0.12, ink); draw_circle(c + Vector2(rr * 0.35, -rr * 0.1), rr * 0.12, ink)
			for a in 8:
				var v := Vector2(cos(a * PI / 4), sin(a * PI / 4))
				if k == "puff": draw_line(c + v * R * 0.95, c + v * R * 1.15, mint, 4)
				else: draw_line(c + v * R * 1.1, c + v * R * 0.75, mint, 4)
		"addpoint":
			draw_arc(c, R * 0.75, 0, TAU, 24, Data.LILAC.darkened(0.15), 4)
			for a in 5: draw_circle(c + Vector2(cos(a * TAU / 5), sin(a * TAU / 5)) * R * 0.75, R * 0.14, pink)
			draw_circle(c + Vector2(R * 0.55, R * 0.55), R * 0.35, mint)
			draw_rect(Rect2(c + Vector2(R * 0.55 - R * 0.2, R * 0.55 - R * 0.05), Vector2(R * 0.4, R * 0.1)), Color.WHITE)
			draw_rect(Rect2(c + Vector2(R * 0.55 - R * 0.05, R * 0.55 - R * 0.2), Vector2(R * 0.1, R * 0.4)), Color.WHITE)
		"hand":
			draw_circle(c + Vector2(0, R * 0.2), R * 0.55, Color("ffdcc2"))
			for k2 in 4: draw_rect(Rect2(c + Vector2(-R * 0.5 + k2 * R * 0.27, -R * 0.75), Vector2(R * 0.2, R * 0.8)), Color("ffdcc2"))
			draw_arc(c, R * 1.0, PI * 1.1, PI * 1.9, 12, mint, 5)
		"pull", "push":
			draw_circle(c, R * 0.55, Color("b9a2e6"))
			for a in 4:
				var v := Vector2(cos(a * PI / 2 + PI / 4), sin(a * PI / 2 + PI / 4))
				var p0 := c + v * R * (0.6 if k == "pull" else 1.05); var p1 := c + v * R * (1.05 if k == "pull" else 0.62)
				draw_line(p0, p1, Data.PINK, 6)
				var side := Vector2(-v.y, v.x) * R * 0.16
				draw_colored_polygon(PackedVector2Array([p1 + v * R * 0.12 * (1 if k == "pull" else -1), p1 + side, p1 - side]), Data.PINK)
		"smooth":
			for i in 3:
				var pts := PackedVector2Array()
				for s2 in 9: pts.append(c + Vector2(-R * 0.8 + s2 * R * 0.2, -R * 0.45 + i * R * 0.45 + sin(s2 * 0.9) * R * 0.12))
				draw_polyline(pts, mint, 6)
		"brush_s", "brush_b":
			draw_circle(c, R * (0.3 if k == "brush_s" else 0.8), Color("b9a2e6"))
		"up", "down":
			var d2 := -1.0 if k == "up" else 1.0
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, d2 * R * 0.8), c + Vector2(-R * 0.75, -d2 * R * 0.3), c + Vector2(R * 0.75, -d2 * R * 0.3)]), Color("6fa8ff"))
		"wider", "narrower":
			for s2 in [-1.0, 1.0]:
				var out := k == "wider"
				var tip := c + Vector2(s2 * R * (0.95 if out else 0.2), 0)
				var base := c + Vector2(s2 * R * (0.35 if out else 0.85), 0)
				draw_colored_polygon(PackedVector2Array([tip, base + Vector2(0, -R * 0.45), base + Vector2(0, R * 0.45)]), Color("6fa8ff"))
		"bigger", "smaller":
			draw_circle(c, R * (0.9 if k == "bigger" else 0.4), Color("ffc93c"))
			draw_rect(Rect2(c - Vector2(R * 0.3, R * 0.07), Vector2(R * 0.6, R * 0.14)), Color.WHITE)
			if k == "bigger": draw_rect(Rect2(c - Vector2(R * 0.07, R * 0.3), Vector2(R * 0.14, R * 0.6)), Color.WHITE)
		"reg_brada", "reg_tvare", "reg_celo", "reg_oci", "reg_lebka", "reg_cumak":
			draw_circle(c, R * 0.85, Color("ffdcc2"))
			var hi := Color(1.0, 0.45, 0.65, 0.75)
			match k:
				"reg_brada": draw_circle(c + Vector2(0, R * 0.7), R * 0.32, hi)
				"reg_tvare":
					for sx in [-1.0, 1.0]: draw_circle(c + Vector2(sx * R * 0.55, R * 0.25), R * 0.25, hi)
				"reg_celo": draw_circle(c + Vector2(0, -R * 0.5), R * 0.34, hi)
				"reg_oci":
					for sx in [-1.0, 1.0]: draw_circle(c + Vector2(sx * R * 0.32, -R * 0.08), R * 0.22, hi)
				"reg_lebka": draw_arc(c, R * 0.78, PI * 1.15, PI * 1.85, 16, hi, R * 0.28)
				"reg_cumak": draw_circle(c + Vector2(0, R * 0.35), R * 0.3, hi)
			draw_circle(c + Vector2(-R * 0.32, -R * 0.08), R * 0.09, ink); draw_circle(c + Vector2(R * 0.32, -R * 0.08), R * 0.09, ink)
			draw_arc(c + Vector2(0, R * 0.3), R * 0.18, 0.4, PI - 0.4, 8, ink, 3)
		"longer", "shorter":
			var L := R * (0.95 if k == "longer" else 0.45)
			draw_rect(Rect2(c - Vector2(R * 0.12, L * 0.6), Vector2(R * 0.24, L * 1.2)), Color("b9a2e6"))
			for sy in [-1.0, 1.0]:
				var tip := c + Vector2(0, sy * L)
				draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-R * 0.4, -sy * R * 0.4), tip + Vector2(R * 0.4, -sy * R * 0.4)]), Color("6fa8ff"))
		"update":
			draw_circle(c + Vector2(-R * 0.35, R * 0.05), R * 0.45, Color("bfe0ff"))
			draw_circle(c + Vector2(R * 0.25, -R * 0.15), R * 0.55, Color("bfe0ff"))
			draw_circle(c + Vector2(R * 0.65, R * 0.15), R * 0.35, Color("bfe0ff"))
			draw_rect(Rect2(c + Vector2(-R * 0.35, R * 0.05), Vector2(R * 1.0, R * 0.45)), Color("bfe0ff"))
			draw_rect(Rect2(c + Vector2(-R * 0.1, -R * 0.35), Vector2(R * 0.2, R * 0.7)), mint)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, R * 0.75), c + Vector2(-R * 0.38, R * 0.3), c + Vector2(R * 0.38, R * 0.3)]), mint)
		"check":
			draw_circle(c, R * 0.9, mint)
			draw_polyline(PackedVector2Array([c + Vector2(-R * 0.45, 0), c + Vector2(-R * 0.1, R * 0.35), c + Vector2(R * 0.5, -R * 0.35)]), Color.WHITE, R * 0.22)
		"wifi":
			for i in 3: draw_arc(c + Vector2(0, R * 0.6), R * (0.4 + i * 0.4), PI * 1.25, PI * 1.75, 12, Color("6fa8ff"), R * 0.15)
			draw_circle(c + Vector2(0, R * 0.6), R * 0.14, Color("6fa8ff"))

func _star(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2 + PI * k / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, color)

func _heart(c: Vector2, r: float, color: Color) -> void:
	draw_circle(c + Vector2(-r * 0.45, -r * 0.2), r * 0.5, color)
	draw_circle(c + Vector2(r * 0.45, -r * 0.2), r * 0.5, color)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.93, 0), c + Vector2(r * 0.93, 0), c + Vector2(0, r)]), color)
