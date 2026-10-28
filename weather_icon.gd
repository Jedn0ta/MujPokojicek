extends Control
## Obrázkové tlačítko počasí (děti nemusí umět číst).

signal tapped

var kind := 0
var selected := false

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit()

func _cloud(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c + Vector2(-r * 0.6, 0), r * 0.55, col)
	draw_circle(c + Vector2(r * 0.15, -r * 0.3), r * 0.7, col)
	draw_circle(c + Vector2(r * 0.75, 0.05 * r), r * 0.5, col)
	draw_rect(Rect2(c + Vector2(-r * 0.6, 0), Vector2(r * 1.35, r * 0.55)), col)

func _draw() -> void:
	var sb := StyleBoxFlat.new(); sb.set_corner_radius_all(24)
	sb.bg_color = Color("1d2350") if kind == 4 else Color.WHITE
	sb.border_color = Data.PINK if selected else Data.LILAC; sb.set_border_width_all(7 if selected else 4)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var c := size / 2.0; var r := size.x * 0.3
	match kind:
		0:
			for k in 8:
				var a := TAU * k / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * r * 0.85, c + Vector2(cos(a), sin(a)) * r * 1.25, Color("ffb020"), 6)
			draw_circle(c, r * 0.65, Color("ffc93c"))
		1:
			_cloud(c + Vector2(0, -r * 0.3), r, Color("8d96a6"))
			for k in 4:
				var x := c.x - r * 0.6 + k * r * 0.42
				draw_line(Vector2(x, c.y + r * 0.45), Vector2(x - 6, c.y + r * 0.95), Color("3a8dde"), 5)
		2:
			_cloud(c + Vector2(0, -r * 0.35), r, Color("c7d3e6"))
			for k in 3:
				var p := Vector2(c.x - r * 0.55 + k * r * 0.55, c.y + r * 0.7)
				for a in 3:
					var v := Vector2(cos(a * PI / 3), sin(a * PI / 3)) * 9
					draw_line(p - v, p + v, Color("6fa8ff"), 3)
		3:
			for k in 3:
				var y := c.y - r * 0.6 + k * r * 0.6
				draw_line(Vector2(c.x - r, y), Vector2(c.x + r * 0.5, y), Color("1fb3b1"), 6)
				draw_arc(Vector2(c.x + r * 0.5, y - r * 0.2), r * 0.2, PI / 2, PI * 2.2, 12, Color("1fb3b1"), 6)
		4:
			draw_circle(c, r * 0.7, Color("ffe9a0"))
			draw_circle(c + Vector2(r * 0.35, -r * 0.2), r * 0.6, Color("1d2350"))
			for p in [Vector2(-0.8, -0.7), Vector2(0.8, 0.6), Vector2(-0.6, 0.8)]:
				draw_circle(c + p * r, 4, Color("fffbe0"))
		5:
			var rc := [Color("ff4d4d"), Color("ff9a3c"), Color("ffe14d"), Color("5fd16a"), Color("4da3ff"), Color("9b6bff")]
			for k in rc.size():
				draw_arc(c + Vector2(0, r * 0.5), r * 1.1 - k * 7, PI, TAU, 24, rc[k], 7)
