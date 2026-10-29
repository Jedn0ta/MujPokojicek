class_name Paths
## Hledání cesty kolem nábytku (mřížka 10 × 10 cm přes celou podlahu).
## Velký nábytek je překážka, koberce a malé věci ne (malé věci panenka odstrčí).

const CELL := 0.1
const HALF := Vector2(3.35, 2.0)
const MARGIN := 0.11   # půlka šířky panenky

var grid := AStarGrid2D.new()

static func is_small(e: Dictionary) -> bool:
	return max(float(e["w"]), float(e["d"])) < 0.36 and not e.has("lift") and not e.get("flat", false)

static func is_obstacle(e: Dictionary) -> bool:
	return not is_small(e) and not e.get("flat", false) and not e.has("lift")

func build(items: Array) -> void:
	grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, int(HALF.x * 2 / CELL), int(HALF.y * 2 / CELL))
	grid.cell_size = Vector2.ONE * CELL
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for it in items:
		var e := Catalog.get_item(str(it[0]))
		if not is_obstacle(e): continue
		var p := Vector2(float(it[1]), float(it[2]))
		var rot := deg_to_rad(float(it[3]) if it.size() > 3 else 0.0)
		var hw := float(e["w"]) / 2.0 + MARGIN
		var hd := float(e["d"]) / 2.0 + MARGIN
		var r := ceili(max(hw, hd) * 1.5 / CELL)
		var c := to_cell(Vector3(p.x, 0, p.y))
		for x in range(c.x - r, c.x + r + 1):
			for y in range(c.y - r, c.y + r + 1):
				var cell := Vector2i(x, y)
				if not grid.is_in_boundsv(cell): continue
				var w := to_world(cell)
				var local := Vector2(w.x - p.x, w.z - p.y).rotated(rot)
				if abs(local.x) <= hw and abs(local.y) <= hd:
					grid.set_point_solid(cell, true)

func to_cell(v: Vector3) -> Vector2i:
	return Vector2i(clampi(int((v.x + HALF.x) / CELL), 0, grid.region.size.x - 1), clampi(int((v.z + HALF.y) / CELL), 0, grid.region.size.y - 1))

func to_world(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL - HALF.x, 0, (c.y + 0.5) * CELL - HALF.y)

func _free_near(c: Vector2i) -> Vector2i:
	if not grid.is_point_solid(c): return c
	for r in range(1, 25):
		for x in range(c.x - r, c.x + r + 1):
			for y in [c.y - r, c.y + r]:
				var q := Vector2i(x, y)
				if grid.is_in_boundsv(q) and not grid.is_point_solid(q): return q
		for y in range(c.y - r + 1, c.y + r):
			for x in [c.x - r, c.x + r]:
				var q := Vector2i(x, y)
				if grid.is_in_boundsv(q) and not grid.is_point_solid(q): return q
	return c

func _clear_line(a: Vector3, b: Vector3) -> bool:
	var n := int(a.distance_to(b) / (CELL * 0.5)) + 1
	for k in n + 1:
		if grid.is_point_solid(to_cell(a.lerp(b, float(k) / n))): return false
	return true

## Zastávky z from do to (bez from). Když je cíl v nábytku (postel, židle),
## dojde se k nejbližšímu volnému místu a poslední krok vede rovnou do cíle.
func route(from: Vector3, to: Vector3) -> Array:
	var a := _free_near(to_cell(from))
	var b := _free_near(to_cell(to))
	var ids := grid.get_id_path(a, b)
	var pts: Array = []
	for id in ids: pts.append(to_world(id))
	if pts.is_empty(): return [to]
	pts[pts.size() - 1] = to if not grid.is_point_solid(to_cell(to)) else pts[pts.size() - 1]
	if grid.is_point_solid(to_cell(to)): pts.append(to)
	# zkrátit cestu: vynechat zastávky, kam je vidět rovně
	var out: Array = []
	var cur := from
	var k := 0
	while k < pts.size():
		var far := k
		for j in range(pts.size() - 1, k, -1):
			if _clear_line(cur, pts[j]) or (j == pts.size() - 1 and grid.is_point_solid(to_cell(to)) and false):
				far = j; break
		out.append(pts[far]); cur = pts[far]; k = far + 1
	return out
