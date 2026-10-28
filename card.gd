extends Control
## Jedna kartička pexesa: rub s otazníkem, líc s barevným tvarem.

signal tapped

const COLORS := [Color("ff5d73"), Color("3a8dde"), Color("4fbf6e"), Color("ffb020"), Color("ff7ab8"), Color("9b7cff"), Color("ff8a3c"), Color("1fb3b1")]
var face := 0
var shown := false
var matched := false

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new(); sb.set_corner_radius_all(18)
	if not shown:
		sb.bg_color = Data.PINK
		draw_style_box(sb, r)
		draw_string(get_theme_default_font(), Vector2(0, size.y * 0.68), "?", HORIZONTAL_ALIGNMENT_CENTER, size.x, int(size.y * 0.5), Color.WHITE)
		return
	var col: Color = COLORS[face]
	sb.bg_color = Color("f3fff6") if matched else Color.WHITE
	sb.border_color = col; sb.set_border_width_all(5)
	draw_style_box(sb, r)
	var c := size / 2.0
	var R := size.x * 0.3
	match face:
		0: draw_circle(c, R, col)
		1: draw_rect(Rect2(c - Vector2(R, R) * 0.85, Vector2(R, R) * 1.7), col)
		2: draw_colored_polygon(PackedVector2Array([c + Vector2(0, -R), c + Vector2(R, R * 0.8), c + Vector2(-R, R * 0.8)]), col)
		3:
			var pts := PackedVector2Array()
			for k in 10:
				var a := -PI / 2 + PI * k / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * (R if k % 2 == 0 else R * 0.45))
			draw_colored_polygon(pts, col)
		4:
			draw_circle(c + Vector2(-R * 0.45, -R * 0.2), R * 0.5, col)
			draw_circle(c + Vector2(R * 0.45, -R * 0.2), R * 0.5, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-R * 0.93, 0), c + Vector2(R * 0.93, 0), c + Vector2(0, R)]), col)
		5: draw_colored_polygon(PackedVector2Array([c + Vector2(0, -R), c + Vector2(R * 0.75, 0), c + Vector2(0, R), c + Vector2(-R * 0.75, 0)]), col)
		6:
			draw_rect(Rect2(c - Vector2(R, R * 0.32), Vector2(R * 2, R * 0.64)), col)
			draw_rect(Rect2(c - Vector2(R * 0.32, R), Vector2(R * 0.64, R * 2)), col)
		_: draw_arc(c, R * 0.72, 0, TAU, 32, col, R * 0.45)
