class_name HeadShape
## Tvar hlavy podle obrysu zepředu (jako na náčrtu: fazolka, kapka, trojlístek…).
## Obrys se vyhladí a "nafoukne" do 3D jako polštářek.
## Vlasy, čepice a obvazy jsou stejný tvar o kousek větší, jen vybraná část.

const C := Vector3(0, 0.745, 0)   # střed hlavy
const R := 0.26                   # základní poloměr

# Obrysy v jednotkách (y nahoru), pořadí jako v Data.OPT["headshape"]; poslední volba je vlastní
const SHAPES := [
	[Vector2(1, 0), Vector2(0.71, 0.71), Vector2(0, 1), Vector2(-0.71, 0.71), Vector2(-1, 0), Vector2(-0.71, -0.71), Vector2(0, -1), Vector2(0.71, -0.71)],
	[Vector2(-0.95, 0.05), Vector2(-0.8, 0.6), Vector2(-0.4, 0.62), Vector2(0.05, 0.9), Vector2(0.55, 1.0), Vector2(0.92, 0.6), Vector2(0.98, -0.1), Vector2(0.62, -0.75), Vector2(0.0, -0.95), Vector2(-0.62, -0.78)],
	[Vector2(-0.98, 0.72), Vector2(-0.45, 0.98), Vector2(0.45, 0.98), Vector2(0.98, 0.72), Vector2(0.62, -0.05), Vector2(0.22, -0.8), Vector2(0, -0.96), Vector2(-0.22, -0.8), Vector2(-0.62, -0.05)],
	[Vector2(-0.56, 0.85), Vector2(-0.4, 1.2), Vector2(0.4, 1.2), Vector2(0.56, 0.85), Vector2(0.58, 0.0), Vector2(0.56, -0.85), Vector2(0.4, -1.2), Vector2(-0.4, -1.2), Vector2(-0.56, -0.85), Vector2(-0.58, 0.0)],
	[Vector2(-1.0, 0.3), Vector2(-0.82, 0.82), Vector2(-0.35, 0.78), Vector2(0.1, 0.9), Vector2(0.62, 0.88), Vector2(1.0, 0.45), Vector2(0.82, -0.02), Vector2(0.42, -0.28), Vector2(0.32, -0.78), Vector2(0, -0.96), Vector2(-0.38, -0.8), Vector2(-0.5, -0.28), Vector2(-0.92, -0.12)],
	[Vector2(-0.9, 0.82), Vector2(-0.6, 0.94), Vector2(0.6, 0.94), Vector2(0.9, 0.82), Vector2(0.95, 0.6), Vector2(0.95, -0.6), Vector2(0.9, -0.82), Vector2(0.6, -0.94), Vector2(-0.6, -0.94), Vector2(-0.9, -0.82), Vector2(-0.95, -0.6), Vector2(-0.95, 0.6)],
	[Vector2(-0.98, -0.7), Vector2(-0.62, -0.96), Vector2(0.62, -0.96), Vector2(0.98, -0.7), Vector2(0.62, 0.08), Vector2(0.22, 0.82), Vector2(0, 0.96), Vector2(-0.22, 0.82), Vector2(-0.62, 0.08)],
	[Vector2(-0.98, 0.55), Vector2(-0.55, 0.95), Vector2(0.55, 0.95), Vector2(0.98, 0.55), Vector2(0.8, -0.3), Vector2(0.38, -0.85), Vector2(0, -0.95), Vector2(-0.38, -0.85), Vector2(-0.8, -0.3)],
]

# Modelína: hlava jako koule, každý bod se dá vytáhnout nebo zatlačit.
const LAT := 26
const LON := 40
var sculpt := false
var off := PackedFloat32Array()   # o kolik je bod vytažený (0 = koule)
var radii := Vector3(0.262, 0.25, 0.235)

# Úpravy míst na hlavě: každé místo jde nafouknout/splasknout (i), protáhnout (t)
# a zvětšit/zmenšit plochu (s). Vliv slábne plynule (Gauss), takže nevznikají hrany.
# místo: [středy (směr od středu hlavy), směr protažení pro každý střed, velikost]
const REGIONS := {
	"brada": [[Vector3(0, -0.85, 0.52)], [Vector3(0, -1, 0.25)], 0.55],
	"tvare": [[Vector3(0.72, -0.3, 0.62), Vector3(-0.72, -0.3, 0.62)], [Vector3(1, -0.1, 0.2), Vector3(-1, -0.1, 0.2)], 0.45],
	"celo": [[Vector3(0, 0.55, 0.83)], [Vector3(0, 0.6, 0.8)], 0.5],
	"oci": [[Vector3(0.36, 0.08, 0.93), Vector3(-0.36, 0.08, 0.93)], [Vector3(0, 0, 1), Vector3(0, 0, 1)], 0.32],
	"lebka": [[Vector3(0, 0.72, -0.69)], [Vector3(0, 0.55, -0.85)], 0.75],
	"cumak": [[Vector3(0, -0.3, 0.95)], [Vector3(0, -0.1, 1)], 0.42],
}
var mods := {}   # místo -> [nafouknutí, protažení, velikost]

func set_mods(h: Dictionary) -> void:
	mods.clear()
	for r in REGIONS:
		var i := float(h.get("m_%s_i" % r, 0.0)); var t := float(h.get("m_%s_t" % r, 0.0)); var s := float(h.get("m_%s_s" % r, 1.0))
		if i != 0.0 or t != 0.0: mods[r] = [i, t, s]

## Posune bod hlavy podle úprav míst (vše plynule).
func deform(p: Vector3) -> Vector3:
	if mods.is_empty(): return p
	var q := p - C
	if q.length() < 0.001: return p
	var n := Vector3(q.x / 0.262, q.y / 0.25, q.z / 0.235).normalized()
	var out := q.normalized()
	var move := Vector3.ZERO
	for r in mods:
		var m: Array = mods[r]
		var reg: Array = REGIONS[r]
		var size: float = reg[2] * float(m[2])
		for k in reg[0].size():
			var c: Vector3 = (reg[0][k] as Vector3).normalized()
			var ang := acos(clampf(n.dot(c), -1, 1))
			var w := exp(-pow(ang / size, 2) * 2.2)
			if w < 0.002: continue
			move += (out * float(m[0]) + (reg[1][k] as Vector3).normalized() * float(m[1])) * w * 0.25
	return p + move

var pts := PackedVector2Array()   # vyhlazený obrys kolem středu
var polar := PackedFloat32Array() # poloměr obrysu v 72 směrech
var depth := 0.235

const CUSTOM := 8   # vlastní hlava, kterou si dítě vymodeluje

## Výchozí body pro vlastní hlavu: 12 teček do kolečka.
static func circle_points(n := 12) -> Array:
	var out := []
	for k in n: out.append([cos(TAU * k / n), sin(TAU * k / n)])
	return out

func setup(kind: int, w := 1.0, h := 1.0, d := 1.0, sculpt_data: Array = []) -> void:
	if kind >= CUSTOM:
		setup_sculpt(sculpt_data, w, h, d)
		return
	sculpt = false
	var cp: Array = SHAPES[clampi(kind, 0, SHAPES.size() - 1)]
	pts = PackedVector2Array()
	var n := cp.size()
	var steps := 8
	for i in n:
		var p0: Vector2 = cp[(i - 1 + n) % n]; var p1: Vector2 = cp[i]
		var p2: Vector2 = cp[(i + 1) % n]; var p3: Vector2 = cp[(i + 2) % n]
		for s in steps:
			var t := float(s) / steps
			var q := 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t)
			pts.append(Vector2(q.x * R * w, q.y * R * 0.96 * h))
	depth = 0.235 * d
	# vysoká hlava roste nahoru, ne do trička
	var low := 9.0
	for p in pts: low = min(low, p.y)
	if C.y + low < 0.53:
		var up := 0.53 - (C.y + low)
		for i in pts.size(): pts[i].y += up
	polar = PackedFloat32Array()
	for k in 72:
		var a := TAU * k / 72.0
		var dir := Vector2(cos(a), sin(a))
		var best := 0.05
		for i in pts.size():
			var a2 := pts[i]; var b2 := pts[(i + 1) % pts.size()]
			var hit = Geometry2D.segment_intersects_segment(Vector2.ZERO, dir * 2.0, a2, b2)
			if hit != null: best = max(best, (hit as Vector2).length())
		polar.append(best)

# ---------- modelína ----------

func setup_sculpt(data: Array, w := 1.0, h := 1.0, d := 1.0) -> void:
	sculpt = true
	radii = Vector3(0.262 * w, 0.25 * h, 0.235 * d)
	off = PackedFloat32Array(); off.resize((LAT + 1) * LON)
	for i in off.size(): off[i] = float(data[i]) if i < data.size() else 0.0
	# poloha středu tak, aby spodek hlavy neležel v tričku
	pts = PackedVector2Array()

static func dir_of(i: int, j: int) -> Vector3:
	var th := -PI / 2 + PI * i / LAT
	var ph := TAU * j / LON
	return Vector3(cos(th) * sin(ph), sin(th), cos(th) * cos(ph))

func off_at(d: Vector3) -> float:
	var fi := (asin(clampf(d.y, -1, 1)) + PI / 2) / PI * LAT
	var fj := fposmod(atan2(d.x, d.z), TAU) / TAU * LON
	var i0 := clampi(int(fi), 0, LAT - 1); var j0 := int(fj) % LON
	var ti: float = clampf(fi - i0, 0, 1); var tj: float = fj - floor(fj)
	var a := lerpf(off[i0 * LON + j0], off[i0 * LON + (j0 + 1) % LON], tj)
	var b := lerpf(off[(i0 + 1) * LON + j0], off[(i0 + 1) * LON + (j0 + 1) % LON], tj)
	return lerpf(a, b, ti)

func point(d: Vector3, grow := 0.0) -> Vector3:
	return C + d * radii * (1.0 + off_at(d)) + d * grow

## Paprsek (v souřadnicích panenky) proti hlavě; vrací směr bodu na hlavě, nebo null.
func ray(o: Vector3, dir: Vector3):
	var maxr := 0.0
	for v in off: maxr = max(maxr, v)
	var big: float = radii[radii.max_axis_index()] * (1.0 + maxr) + 0.02
	var oc := o - C
	var b := oc.dot(dir); var c := oc.dot(oc) - big * big
	var disc := b * b - c
	if disc < 0: return null
	var t := -b - sqrt(disc)
	var t_end := -b + sqrt(disc)
	t = max(t, 0.0)
	while t < t_end:
		var q := o + dir * t
		var p := (q - C) / radii
		var l := p.length()
		if l > 0.0001:
			var d := p / l
			if l <= 1.0 + off_at(d): return d
		t += 0.004
	return null

## Štětec: mode "pull" vytáhne, "push" zatlačí, "smooth" uhladí. Se zrcadlem i druhou stranu.
func brush(at: Vector3, mode: String, size: float, mirror: bool) -> void:
	var spots := [at]
	if mirror and abs(at.x) > 0.02: spots.append(Vector3(-at.x, at.y, at.z))
	var old := off.duplicate()
	for i in LAT + 1:
		for j in LON:
			var v := dir_of(i, j)
			var k := i * LON + j
			for s in spots:
				var ang := acos(clampf(v.dot(s), -1, 1))
				if ang >= size: continue
				var w := pow(1.0 - ang / size, 2)
				match mode:
					"pull": off[k] = minf(off[k] + 0.05 * w, 1.2)
					"push": off[k] = maxf(off[k] - 0.05 * w, -0.55)
					"smooth":
						var avg := (old[clampi(i - 1, 0, LAT) * LON + j] + old[clampi(i + 1, 0, LAT) * LON + j] + old[i * LON + (j + 1) % LON] + old[i * LON + (j - 1 + LON) % LON]) / 4.0
						off[k] = lerpf(off[k], avg, 0.6 * w)
	for j in LON:
		pass
	# póly musí mít jednu hodnotu, jinak tam vznikne špička
	for pole in [0, LAT]:
		var avg := 0.0
		for j in LON: avg += off[pole * LON + j]
		avg /= LON
		for j in LON: off[pole * LON + j] = avg

func data() -> Array:
	var out := []
	for v in off: out.append(snappedf(v, 0.001))
	return out

## Obrys zepředu v daném úhlu (kvůli uším).
func rim(a: float) -> float:
	if sculpt:
		var d := Vector3(cos(a), sin(a), 0.0)
		var p := point(d)
		return Vector2(p.x - C.x, p.y - C.y).length()
	var r := radius_dir(a)
	var p := deform(C + Vector3(cos(a) * r, sin(a) * r, 0))
	return Vector2(p.x - C.x, p.y - C.y).length()

func radius_dir(a: float) -> float:
	var f := fposmod(a, TAU) / TAU * 72.0
	var i := int(f)
	return lerpf(polar[i % 72], polar[(i + 1) % 72], f - i)

## Bod na přední ploše hlavy nad (x, y).
func surface(x: float, y: float, out := 0.0) -> Vector3:
	if sculpt:
		var u := (x - C.x) / radii.x; var v := (y - C.y) / radii.y
		var k := 1.0
		var d := Vector3(0, 0, 1)
		for it in 4:
			var uu := u / k; var vv := v / k
			d = Vector3(uu, vv, sqrt(max(0.03, 1.0 - uu * uu - vv * vv))).normalized()
			k = 1.0 + off_at(d)
		return Vector3(x, y, point(d).z + out)
	var rel := Vector2(x, y - C.y)
	var r := radius_dir(atan2(rel.y, rel.x))
	var t := clampf(rel.length() / r, 0.0, 0.995)
	return deform(Vector3(x, y, depth * sqrt(1.0 - t * t))) + Vector3(0, 0, out)

func _sculpt_extent(axis: int, sgn: float) -> float:
	var m := -9.0
	for i in LAT + 1:
		for j in LON:
			var p := point(dir_of(i, j))
			m = max(m, p[axis] * sgn)
	return m

func _rim_points() -> Array:
	var out := []
	for p in pts: out.append(deform(C + Vector3(p.x, p.y, 0)))
	return out

func top() -> float:
	if sculpt: return _sculpt_extent(1, 1.0)
	var m := -9.0
	for p in _rim_points(): m = max(m, p.y)
	return m

func bottom() -> float:
	if sculpt: return -_sculpt_extent(1, -1.0)
	var m := 9.0
	for p in _rim_points(): m = min(m, p.y)
	return m

func half_width() -> float:
	if sculpt: return max(_sculpt_extent(0, 1.0), _sculpt_extent(0, -1.0))
	var m := 0.0
	for p in _rim_points(): m = max(m, abs(p.x - C.x))
	return m

## 3D tvar. grow = o kolik větší; keep(bod) = které trojúhelníky nechat (vlasy jen nahoře…).
func mesh(grow := 0.0, keep := Callable()) -> ArrayMesh:
	if sculpt: return _sculpt_mesh(grow, keep)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# vlasy a čepice (keep) potřebují jemnější síť, jinak má okraj zuby
	var fine := keep.is_valid()
	var rings := 48 if fine else 22
	var src := pts
	if fine:
		src = PackedVector2Array()
		for i in pts.size():
			var p0 := pts[i]; var p1 := pts[(i + 1) % pts.size()]
			src.append(p0); src.append(p0.lerp(p1, 1.0 / 3.0)); src.append(p0.lerp(p1, 2.0 / 3.0))
	var n := src.size()
	var avg := 0.0
	for p in src: avg += p.length()
	avg /= n
	var k := 1.0 + grow / avg
	var grid := []
	for j in rings + 1:
		var phi := -PI / 2 + PI * j / rings
		var row := []
		for i in n:
			var o := src[i] * k
			row.append(C + Vector3(o.x * cos(phi), o.y * cos(phi), (depth + grow) * sin(phi)))
	# filtr (vlasy, čepice) se řídí základním tvarem, úpravy se přidají až potom
		grid.append(row)
	var count := 0
	for j in rings:
		for i in n:
			var a: Vector3 = grid[j][i]; var b: Vector3 = grid[j][(i + 1) % n]
			var c: Vector3 = grid[j + 1][i]; var d: Vector3 = grid[j + 1][(i + 1) % n]
			for tri in [[a, b, c], [b, d, c]]:
				var cen: Vector3 = (tri[0] + tri[1] + tri[2]) / 3.0
				if keep.is_valid() and not keep.call(cen): continue
				tri = [deform(tri[0]), deform(tri[1]), deform(tri[2])]
				cen = (tri[0] + tri[1] + tri[2]) / 3.0
				var nrm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0])
				var outward := cen - C
				if nrm.dot(outward) > 0:
					st.add_vertex(tri[0]); st.add_vertex(tri[2]); st.add_vertex(tri[1])
				else:
					st.add_vertex(tri[0]); st.add_vertex(tri[1]); st.add_vertex(tri[2])
				count += 1
	if count == 0: return ArrayMesh.new()
	st.index()
	st.generate_normals()
	return st.commit()

func _sculpt_mesh(grow: float, keep: Callable) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid := []
	for i in LAT + 1:
		var row := []
		for j in LON: row.append(point(dir_of(i, j), grow))
		grid.append(row)
	var count := 0
	for i in LAT:
		for j in LON:
			var a: Vector3 = grid[i][j]; var b: Vector3 = grid[i][(j + 1) % LON]
			var c: Vector3 = grid[i + 1][j]; var d: Vector3 = grid[i + 1][(j + 1) % LON]
			for tri in [[a, b, c], [b, d, c]]:
				var cen: Vector3 = (tri[0] + tri[1] + tri[2]) / 3.0
				if keep.is_valid() and not keep.call(cen): continue
				var nrm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0])
				if nrm.length() < 1e-9: continue
				if nrm.dot(cen - C) > 0:
					st.add_vertex(tri[0]); st.add_vertex(tri[2]); st.add_vertex(tri[1])
				else:
					st.add_vertex(tri[0]); st.add_vertex(tri[1]); st.add_vertex(tri[2])
				count += 1
	if count == 0: return ArrayMesh.new()
	st.index()
	st.generate_normals()
	return st.commit()
