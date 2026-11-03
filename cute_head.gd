class_name CuteHead
## Roztomilá hlava modelovaná z hladkých tvarů (SDF): temeno, tvářičky, bradička, čumáček.
## Tvary se slévají měkce (smooth union), takže nikdy nevzniknou dloubance.
## Síť vznikne promítnutím koule na povrch, obličej se maluje přímo do textury hlavy
## (velké lesklé oči, tvářenky, pusinka), vlasy jsou slupka nad hlavou s ofinou.
##
## Parametry (0–1, výchozí 0.5): w šířka, h výška, crown temeno, cheeks tváře, chin brada,
## jaw čelist, snout čumáček (0 = žádný).

const RINGS := 40
const SEGS := 56
const TEX_W := 2048
const TEX_H := 1024

const EYES := ["velke", "rasy", "modre", "zelene", "hvezdicky", "radost", "ospale", "tecky", "srdicka", "kocici", "spirala", "krizky"]
const MOUTHS := ["usmev", "smich", "kocici", "o", "zoubek", "jazyk", "zuby", "pusinka"]
const BROWS := ["", "obycejne", "zvednute", "zamracene", "smutne"]
const HAIRS := ["žádné", "krátké", "mikádo", "copánky", "dlouhé", "culík", "drdol", "ježek", "kudrny"]
## Tvary hlavy jako hotové kombinace parametrů.
const SHAPES := [{}, {"cheeks": 0.95, "jaw": 0.75, "w": 0.6}, {"h": 0.8, "w": 0.35, "chin": 0.75, "cheeks": 0.3},
	{"w": 0.9, "h": 0.3, "jaw": 0.6}, {"cheeks": 0.25, "chin": 0.95, "jaw": 0.15, "crown": 0.75}, {"crown": 0.95, "h": 0.35, "cheeks": 0.75, "chin": 0.2}]

## Čepice: slupka nad hlavou nad danou výškou (jako kulich).
static func cap_mesh(line: float, thick: float, p: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 64; var rr := 12
	var cols := []
	for j in segs + 1:
		var lon := -PI + TAU * float(j) / segs
		var col := []
		var d0 := _dir(lon, line)
		col.append(d0 * (radius(d0, p) + 0.004))
		for k in rr + 1:
			var el := lerpf(line, PI / 2.0 - 0.0001, float(k) / rr)
			var dv := _dir(lon, el)
			col.append(dv * (radius(dv, p) + thick))
		cols.append(col)
	for j in segs:
		var A: Array = cols[j]; var B: Array = cols[j + 1]
		for k in A.size() - 1:
			st.add_vertex(A[k]); st.add_vertex(B[k]); st.add_vertex(A[k + 1])
			st.add_vertex(B[k]); st.add_vertex(B[k + 1]); st.add_vertex(A[k + 1])
	st.generate_normals()
	return st.commit()

static var _mesh_cache := {}
static var _img_cache := {}

# ---------- tvar ----------

static func _ell(q: Vector3, r: Vector3) -> float:
	return (Vector3(q.x / r.x, q.y / r.y, q.z / r.z).length() - 1.0) * minf(r.x, minf(r.y, r.z))

static func _smin(a: float, b: float, k: float) -> float:
	var h := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) - k * h * (1.0 - h)

static func sdf(q: Vector3, p: Dictionary) -> float:
	var w := float(p.get("w", 0.5)); var hh := float(p.get("h", 0.5))
	var crown := float(p.get("crown", 0.5)); var cheeks := float(p.get("cheeks", 0.5))
	var chin := float(p.get("chin", 0.5)); var jaw := float(p.get("jaw", 0.5)); var snout := float(p.get("snout", 0.0))
	# velké temeno (chibi), nižší a širší spodek obličeje
	var cr := Vector3(0.265 * (0.88 + 0.24 * w), 0.25 * (0.88 + 0.24 * hh), 0.245) * (0.94 + 0.12 * crown)
	var d := _ell(q - Vector3(0, 0.035 + 0.03 * crown, -0.012), cr)
	d = _smin(d, _ell(q - Vector3(0, -0.075, 0.03), Vector3(0.19 * (0.86 + 0.28 * jaw) * (0.9 + 0.2 * w), 0.145, 0.185)), 0.09)
	for s in [-1.0, 1.0]:
		d = _smin(d, _ell(q - Vector3(0.12 * s * (0.9 + 0.2 * w), -0.085, 0.1), Vector3.ONE * (0.06 + 0.05 * cheeks)), 0.09)
	if float(p.get("nose", 0.0)) > 0.01:
		d = _smin(d, _ell(q - Vector3(0, -0.06, 0.235), Vector3(0.03, 0.022, 0.025)), 0.02)
	d = _smin(d, _ell(q - Vector3(0, -0.15 - 0.035 * chin, 0.095), Vector3(0.05, 0.035 + 0.03 * chin, 0.045)), 0.06)
	if snout > 0.01:
		d = _smin(d, _ell(q - Vector3(0, -0.07, 0.19 + 0.03 * snout), Vector3(0.1, 0.075, 0.07) * (0.7 + 0.5 * snout)), 0.07)
	return d

## Poloměr povrchu ve směru dir (hlava je hvězdicovitá ze středu).
static func radius(dir: Vector3, p: Dictionary) -> float:
	var lo := 0.02; var hi := 0.6
	for i in 22:
		var mid := (lo + hi) * 0.5
		if sdf(dir * mid, p) < 0.0: lo = mid
		else: hi = mid
	return (lo + hi) * 0.5

static func surface(lon: float, el: float, p: Dictionary) -> Vector3:
	var d := _dir(lon, el)
	return d * radius(d, p)

static func _dir(lon: float, el: float) -> Vector3:
	return Vector3(sin(lon) * cos(el), sin(el), cos(lon) * cos(el))

static func _key(p: Dictionary) -> String:
	var ks := ["w", "h", "crown", "cheeks", "chin", "jaw", "snout", "nose"]
	var s := ""
	for k in ks: s += "%.2f," % float(p.get(k, 0.0 if k in ["snout", "nose"] else 0.5))
	return s

## Síť hlavy (s UV pro malovaný obličej).
static func head_mesh(p: Dictionary) -> ArrayMesh:
	var key := _key(p)
	if _mesh_cache.has(key): return _mesh_cache[key]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := []
	for i in RINGS + 1:
		var el := PI / 2.0 - PI * float(i) / RINGS
		var row := []
		for j in SEGS + 1:
			var lon := -PI + TAU * float(j) / SEGS
			var dvec := _dir(lon, el)
			var pos := dvec * radius(dvec, p)
			var e := 0.002
			var n := Vector3(sdf(pos + Vector3(e, 0, 0), p) - sdf(pos - Vector3(e, 0, 0), p),
				sdf(pos + Vector3(0, e, 0), p) - sdf(pos - Vector3(0, e, 0), p),
				sdf(pos + Vector3(0, 0, e), p) - sdf(pos - Vector3(0, 0, e), p)).normalized()
			row.append([pos, n, Vector2(float(j) / SEGS, float(i) / RINGS)])
		rows.append(row)
	for i in RINGS:
		for j in SEGS:
			var a: Array = rows[i][j]; var b: Array = rows[i][j + 1]; var c: Array = rows[i + 1][j]; var d: Array = rows[i + 1][j + 1]
			for v in [a, b, c, b, d, c]:
				st.set_normal(v[1]); st.set_uv(v[2]); st.add_vertex(v[0])
	var m := st.commit()
	_mesh_cache[key] = m
	return m

# ---------- malovaný obličej ----------

static func _sprite(name: String) -> Image:
	if not _img_cache.has(name):
		var path := "res://face/%s.png" % name
		var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
		_img_cache[name] = tex.get_image() if tex else null
	return _img_cache[name]

## Úhel (lon, el) → pixel v textuře hlavy.
static func _px(lon: float, el: float) -> Vector2:
	return Vector2((lon + PI) / TAU * TEX_W, (PI / 2.0 - el) / PI * TEX_H)

static func _stamp(img: Image, name: String, lon: float, el: float, size_rad: float, flip := false, tint := Color.WHITE) -> void:
	var src := _sprite(name)
	if src == null: return
	var s := src.duplicate() as Image
	if s.is_compressed(): s.decompress()
	if s.get_format() != Image.FORMAT_RGBA8: s.convert(Image.FORMAT_RGBA8)
	var px := int(size_rad / TAU * TEX_W / maxf(cos(el), 0.3))
	var py := int(size_rad / PI * TEX_H)
	s.resize(maxi(px, 2), maxi(py, 2), Image.INTERPOLATE_BILINEAR)
	if flip: s.flip_x()
	if tint != Color.WHITE:
		for y in s.get_height():
			for x in s.get_width():
				var c := s.get_pixel(x, y)
				if c.a > 0.0: s.set_pixel(x, y, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))
	var c := _px(lon, el)
	img.blend_rect(s, Rect2i(0, 0, s.get_width(), s.get_height()), Vector2i(int(c.x) - s.get_width() / 2, int(c.y) - s.get_height() / 2))

## Textura hlavy: kůže + oči, obočí, pusa, tvářenky.
static func face_texture(f: Dictionary, skin: Color) -> ImageTexture:
	var img := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	img.fill(skin)
	var eyes := str(f.get("eyes", "velke")); var mouth := str(f.get("mouth", "usmev"))
	var brows := str(f.get("brows", "")); var gap := 0.36 + 0.08 * (float(f.get("eyegap", 0.5)) - 0.5)
	var ey := -0.1 + 0.1 * (float(f.get("eyey", 0.5)) - 0.5)
	var esz := 0.5 * (0.85 + 0.3 * float(f.get("eyesize", 0.5)))
	var snout := float(f.get("snout", 0.0))
	if f.get("blush", true): for s in [-1.0, 1.0]: _stamp(img, "x_tvarenky", 0.55 * s, ey - 0.3, 0.42)
	if f.get("freckles", false): for s in [-1.0, 1.0]: _stamp(img, "x_pihy", 0.5 * s, ey - 0.25, 0.24)
	for s in [-1.0, 1.0]:
		_stamp(img, "eye_" + eyes, gap * s, ey, esz, s > 0)
		if brows != "": _stamp(img, "brow_" + brows, gap * s * 1.05, ey + esz * 0.75, esz * 0.8, s > 0)
	if f.get("whiskers", false): for s in [-1.0, 1.0]: _stamp(img, "x_fousky", 0.5 * s, ey - 0.34, 0.3, s > 0)
	var my := ey - 0.38 - 0.06 * snout
	_stamp(img, "mouth_" + mouth, 0.0, my, 0.3 + 0.06 * snout)
	if snout > 0.01:
		_stamp(img, "eye_tecky", 0.0, ey - 0.2, 0.16)   # čumáček na konci čenichu
	var t := ImageTexture.create_from_image(img)
	return t

# ---------- vlasy ----------

## Hranice vlasů: nad touto výškou (el) jsou vlasy, podle úhlu kolem hlavy (lon, 0 = vepředu).
## Ofina je z kulatých pramínků (špičky dolů, mezi nimi zářezy nahoru).
static func _hairline(style: int, lon: float) -> float:
	var back := (1.0 - cos(lon)) * 0.5          # 0 vepředu, 1 vzadu
	var al := absf(lon)
	match style:
		1, 7, 8:   # krátké, ježek, kudrny
			var l := lerpf(0.44, -0.5, smoothstep(0.1, 0.9, back))
			if al < 1.15: l -= 0.1 * pow(absf(cos(lon * 4.2)), 0.7) * (1.0 - al / 1.15)
			if al > 1.05 and al < 1.75: l = minf(l, 0.02 - 0.12 * sin((al - 1.05) / 0.7 * PI))
			return l
		2, 4:      # mikádo / dlouhé: rovná ofina z pramínků, po stranách až k bradě
			if al < 0.95: return 0.3 - 0.06 * pow(absf(cos(lon * 5.5)), 0.8)
			return lerpf(0.24, -0.85, smoothstep(0.95, 1.6, al))
		3, 5, 6:   # copánky, culík, drdol: ofina sčesaná na stranu
			var l3 := lerpf(0.38, -0.55, smoothstep(0.1, 0.9, back))
			if al < 1.2: l3 += 0.13 * sin(lon * 1.3 + 0.7) * (1.0 - al / 1.2) - 0.06 * pow(absf(cos(lon * 3.5)), 0.8)
			return l3
	return 9.0

static var _hair_tex := {}

## Textura vlasů: linky pramenů a lesklý proužek (kreslený "andělský kroužek").
static func hair_texture(col: Color) -> ImageTexture:
	var key := col.to_html()
	if _hair_tex.has(key): return _hair_tex[key]
	var w := 512; var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var locks := 16.0
	for y in h:
		var v := float(y) / h          # 0 = okraj (vlasová linie), 1 = temeno
		for x in w:
			var u := float(x) / w * locks
			var fr: float = u - floor(u)
			var groove := pow(absf(fr - 0.5) * 2.0, 6.0)        # tmavší rýha mezi prameny
			var c := col.darkened(0.22 * groove + 0.08 * (1.0 - v))
			# lesklý proužek: v každém pramenu kousek světla
			var band := exp(-pow((v - 0.62 - 0.05 * sin(u * 0.9)) / 0.05, 2.0)) * (1.0 - groove) * smoothstep(0.1, 0.35, fr) * smoothstep(0.9, 0.65, fr)
			c = c.lerp(col.lightened(0.55), clampf(band * 0.85, 0.0, 1.0))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_hair_tex[key] = t
	return t

static func hair_mesh(style: int, p: Dictionary) -> ArrayMesh:
	# Každý sloupec (úhel kolem hlavy) začíná přesně na vlasové linii a končí na temeni,
	# takže okraj ofiny je hladký. Prameny vystupují jako hřebínky sbíhající se k temeni.
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 128; var rr := 20
	var locks := 16.0
	var thick := 0.034 * (1.3 if style == 2 or style == 4 else 1.0)
	var cols := []
	for j in segs + 1:
		var lon := -PI + TAU * float(j) / segs
		var line := clampf(_hairline(style, lon), -1.3, PI / 2.0 - 0.05)
		var fr := float(j) / segs * locks
		fr -= floor(fr)
		var ridge := 0.78 + 0.22 * sqrt(sin(fr * PI))              # pramen je uprostřed nejtlustší
		var col := []
		var d0 := _dir(lon, line)
		col.append([d0 * (radius(d0, p) + 0.002), Vector2(float(j) / segs, 0.0)])
		for k in rr + 1:
			var u := float(k) / rr
			var el := lerpf(line, PI / 2.0 - 0.0001, pow(u, 0.85))
			var dv := _dir(lon, el)
			var t := thick * lerpf(0.85, 1.25, u) * lerpf(ridge, 1.0, u * u)
			if k == 0: t *= 0.8                                      # zaoblený okraj pramínku
			if style == 8: t += 0.022 * maxf(0.0, sin(lon * 9.0) * sin(el * 10.0))
			col.append([dv * (radius(dv, p) + t), Vector2(float(j) / segs, 0.04 + 0.96 * u)])
		cols.append(col)
	for j in segs:
		var A: Array = cols[j]; var B: Array = cols[j + 1]
		for k in A.size() - 1:
			for v in [A[k], B[k], A[k + 1], B[k], B[k + 1], A[k + 1]]:
				st.set_uv(v[1]); st.add_vertex(v[0])
	st.generate_normals()
	return st.commit()

static func _blob(parent: Node3D, pos: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radial_segments = 32; sm.rings = 16
	mi.mesh = sm; mi.position = pos; mi.scale = size; mi.rotation = rot
	var m := StandardMaterial3D.new(); m.albedo_texture = hair_texture(col); m.roughness = 0.45
	m.rim_enabled = true; m.rim = 0.3
	mi.material_override = m; parent.add_child(mi)
	return mi

## Doplňky vlasů (copánky, culík, drdol, ježek, dlouhé vlasy vzadu) jako koule a kužely.
static func hair_extras(parent: Node3D, style: int, p: Dictionary, col: Color) -> void:
	var top := surface(0.0, PI / 2.0 - 0.01, p).y
	var tie := Color("ff5d8f")
	match style:
		3:   # copánky: gumička a tři zužující se buclaté pramínky
			for s in [-1.0, 1.0]:
				var base := surface(1.8 * s, 0.0, p) * 1.06
				_blob(parent, base, Vector3(0.085, 0.085, 0.085), tie.lerp(Color.WHITE, 0.1))
				for k in 3:
					_blob(parent, base + Vector3(0.035 * s * (k + 1), -0.09 - k * 0.1, -0.02), Vector3(0.12, 0.15, 0.12) * (1.0 - k * 0.18), col, Vector3(0, 0, 0.25 * s))
		4:   # dlouhé vlasy na záda a dva prameny vepředu
			var back := surface(PI, -0.25, p)
			_blob(parent, back + Vector3(0, -0.13, -0.02), Vector3(0.48, 0.56, 0.16), col)
			for s in [-1.0, 1.0]:
				var side := surface(1.75 * s, -0.55, p)
				_blob(parent, side * 1.04 + Vector3(0, -0.12, -0.02), Vector3(0.11, 0.34, 0.12), col, Vector3(0, 0, 0.12 * s))
		5:   # culík
			var b5 := surface(PI, 0.4, p) * 1.05
			_blob(parent, b5, Vector3(0.08, 0.08, 0.08), tie)
			_blob(parent, b5 + Vector3(0, -0.1, -0.08), Vector3(0.14, 0.2, 0.14), col, Vector3(-0.5, 0, 0))
			_blob(parent, b5 + Vector3(0, -0.24, -0.1), Vector3(0.1, 0.16, 0.1), col, Vector3(-0.2, 0, 0))
		6:   # drdol na temeni
			_blob(parent, Vector3(0, top + 0.07, -0.03), Vector3(0.19, 0.17, 0.19), col)
			_blob(parent, Vector3(0, top + 0.005, -0.02), Vector3(0.13, 0.04, 0.13), tie)
		7:   # rozcuchané chumáčky nahoře
			for k in 6:
				var lon := -0.9 + k * 0.36
				var pnt := surface(lon, 0.72 + 0.12 * sin(k * 1.7), p)
				_blob(parent, pnt * 1.05, Vector3(0.13, 0.1, 0.13), col, Vector3(-0.4, lon * 0.5, 0))

## Celá hlava jako uzel: hlava s obličejem, vlasy, doplňky.
static func build(parent: Node3D, f: Dictionary, skin: Color, hair_col: Color) -> Node3D:
	var root := Node3D.new(); parent.add_child(root)
	var mi := MeshInstance3D.new(); mi.mesh = head_mesh(f); root.add_child(mi)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = face_texture(f, skin)
	mat.roughness = 0.85; mat.metallic_specular = 0.2
	mat.rim_enabled = true; mat.rim = 0.18; mat.rim_tint = 0.7
	mi.material_override = mat
	var hs := int(f.get("hair", 1))
	if hs > 0:
		var hm := MeshInstance3D.new(); hm.mesh = hair_mesh(hs, f); root.add_child(hm)
		var hmat := StandardMaterial3D.new(); hmat.albedo_texture = hair_texture(hair_col); hmat.roughness = 0.45
		hmat.rim_enabled = true; hmat.rim = 0.3; hmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		hm.material_override = hmat
		hair_extras(root, hs, f, hair_col)
	return root
