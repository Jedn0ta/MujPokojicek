extends Node3D
## Animovaná panenka. Výška asi 1 jednotka, nohy na y = 0.
## Hlava a tělo jsou soustružené tvary z profilů. Ruce a nohy visí na kloubech,
## aby panenka mohla chodit, sedět, ležet, objímat a tančit.

signal arrived(cmd: Dictionary)

const HEAD := [Vector2(0, 0.5), Vector2(0.12, 0.505), Vector2(0.2, 0.54), Vector2(0.245, 0.6), Vector2(0.262, 0.68), Vector2(0.262, 0.76), Vector2(0.245, 0.84), Vector2(0.205, 0.91), Vector2(0.14, 0.965), Vector2(0.06, 0.99), Vector2(0, 0.995)]
const BODY := [Vector2(0, 0.215), Vector2(0.1, 0.22), Vector2(0.155, 0.25), Vector2(0.175, 0.31), Vector2(0.168, 0.38), Vector2(0.14, 0.45), Vector2(0.1, 0.5), Vector2(0.07, 0.53), Vector2(0.06, 0.56), Vector2(0, 0.57)]
const BODY_DEPTH := 0.82
const ARM := [Vector2(0, -0.27), Vector2(0.03, -0.265), Vector2(0.048, -0.24), Vector2(0.05, -0.21), Vector2(0.042, -0.18), Vector2(0.044, -0.1), Vector2(0.05, -0.03), Vector2(0.042, 0.0), Vector2(0, 0.012)]
const LEG := [Vector2(0, -0.2), Vector2(0.055, -0.19), Vector2(0.065, -0.14), Vector2(0.066, -0.05), Vector2(0.06, 0.0), Vector2(0, 0.02)]
const HIP := Vector3(0.075, 0.25, 0)
const SHOULDER := Vector3(0.13, 0.49, 0)
const SPEED := 0.8

var pose: Node3D        # vše kromě pozice ve světě; kvůli pózám (ležení)
var legs: Array = []
var arms: Array = []
var head_k := Vector2(1, 1)  # šířka, výška hlavy (kvůli rozmístění obličeje)
var head_depth := 0.9
var hs := HeadShape.new()
var cmd: Dictionary = {}
var walking := false
var target := Vector3.ZERO
var waypoints: Array = []
var t := 0.0
var act_t := 0.0

# ---------- vzhled ----------

# Obličej se přizpůsobí hlavě: střed a velikost podle tvaru (fc, fs),
# a každá skupina (oči, nos, pusa) jde posunout a zvětšit (h["eyes_dy"]…).
var fc := Vector2(0, 0.7475)
var fs := 1.0
var _g: Dictionary = {}
var _gstart := 0
var head_mi: MeshInstance3D

func face(x: float, y: float, out := 0.0) -> Vector3:
	var gx := fc.x + x * float(_g.get("sp", 1.0)) * fs
	var gy := fc.y + (y + float(_g.get("dy", 0.0)) - 0.7475) * fs
	return hs.surface(gx, gy, out)

func _begin(g: Dictionary) -> void:
	_g = g; _gstart = pose.get_child_count()

func _end() -> void:
	var sc := float(_g.get("s", 1.0)) * fs
	for k in range(_gstart, pose.get_child_count()):
		var n = pose.get_child(k)
		if n.has_meta("noscale"): continue
		n.scale *= sc
	_g = {}

## Uši: posadí se na okraj hlavy; ears_a je posune výš/níž, ears_s je zvětší.
func _place_ears(from: int, da: float, s: float) -> void:
	var C := HeadShape.C
	for k in range(from, pose.get_child_count()):
		var n: Node3D = pose.get_child(k)
		var p := n.position
		var sgn := 1.0 if p.x >= 0 else -1.0
		var a0 := atan2(p.y - C.y, p.x)
		var r0 := Vector2(p.x, p.y - C.y).length()
		var a1 := a0 + da * sgn
		var rr: float = hs.rim(a1) * r0 / max(hs.rim(a0), 0.05)
		n.position = Vector3(cos(a1) * rr, C.y + sin(a1) * rr, p.z)
		n.rotation.z += a1 - a0
		n.scale *= s

## Modelína: kam na hlavě míří prst (globální paprsek z kamery).
func sculpt_ray(origin: Vector3, dir: Vector3):
	var inv := pose.global_transform.affine_inverse()
	return hs.ray(inv * origin, (inv.basis * dir).normalized())

func sculpt_brush(at: Vector3, mode: String, size: float, mirror: bool) -> void:
	hs.brush(at, mode, size, mirror)
	head_mi.mesh = hs.mesh()

## Část hlavy o kousek větší (vlasy, čepice, obvazy); keep vybírá, kterou část.
func head_part(c: Color, by: float, keep: Callable) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = hs.mesh(by, keep); mi.set_meta("noscale", true)
	var m: StandardMaterial3D = Yarn.mat(c).duplicate(); m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m; pose.add_child(mi)
	return mi

static func grow(profile: Array, by: float, y_from := -9.0, y_to := 9.0) -> Array:
	var out := []
	for p in profile:
		if p.y >= y_from and p.y <= y_to:
			out.append(Vector2(p.x + by, p.y))
	return out

func build(h: Dictionary) -> void:
	for c in get_children(): c.free()
	pose = Node3D.new(); add_child(pose)
	legs.clear(); arms.clear()
	for s in [-1, 1]:
		var l := Node3D.new(); l.position = Vector3(HIP.x * s, HIP.y, 0); pose.add_child(l); legs.append(l)
		var a := Node3D.new(); a.position = Vector3(SHOULDER.x * s, SHOULDER.y, 0); a.rotation.z = 0.32 * s; pose.add_child(a); arms.append(a)
	var fig := int(h.get("figure", 1))
	scale = [Vector3(0.88, 0.85, 0.88), Vector3.ONE, Vector3(0.95, 1.12, 0.95), Vector3(1.15, 0.97, 1.12)][clampi(fig, 0, 3)]
	var sizes := [0.82, 0.91, 1.0, 1.1, 1.2]
	var depth_k: float = [0.8, 1.0, 1.2][clampi(int(h.get("headd", 1)), 0, 2)] * float(h.get("puff", 1.0))
	hs.set_mods(h)
	hs.setup(int(h.get("headshape", 0)), sizes[clampi(int(h.get("headw", 2)), 0, 4)], sizes[clampi(int(h.get("headh", 2)), 0, 4)], depth_k, h.get("sculpt", []))
	head_k = Vector2(hs.half_width() / 0.262, (hs.top() - HeadShape.C.y) / 0.25)
	var ht := hs.top(); var hb := hs.bottom()
	fc = Vector2(0, (ht + hb) / 2.0)
	fs = clampf(min(hs.half_width() / 0.262, (ht - hb) / 2.0 / 0.2475), 0.75, 1.35)
	head_depth = 0.9
	var sk: Color = Data.pick(Data.SKIN, h.get("skin", 0))
	var hc: Color = Data.pick(Data.HAIRC, h.get("hairc", 0))
	var tc: Color = Data.pick(Data.YARN, h.get("topc", 0))
	var bc: Color = Data.pick(Data.YARN, h.get("botc", 0))
	var shc: Color = Data.pick(Data.YARN, h.get("shoes", 0))
	var hatc: Color = Data.pick(Data.YARN, h.get("hatc", 0))
	var dark := Color("231c2a")
	var top := int(h.get("top", 0))
	var bottom := int(h.get("bottom", 0))
	var hat := int(h.get("hat", 0))
	# tělo, ruce, nohy
	Yarn.lathe(pose, BODY, Vector3.ZERO, sk, true, Vector3.ZERO, BODY_DEPTH)
	for i in 2:
		var s := -1 if i == 0 else 1
		Yarn.lathe(legs[i], LEG, Vector3.ZERO, sk, true, Vector3.ZERO, 1.0, 20)
		Yarn.lathe(arms[i], ARM, Vector3.ZERO, sk, true, Vector3.ZERO, 1.0, 20)
		Yarn.ball(legs[i], Vector3(0.003 * s, -0.215, 0.025), Vector3(0.14, 0.075, 0.2), shc)
		Yarn.cyl(legs[i], Vector3(0.003 * s, -0.18, 0.01), 0.066, 0.07, 0.025, shc.lightened(0.3))
	# spodek
	match bottom:
		0, 2:
			Yarn.lathe(pose, grow(BODY, 0.012, 0.215, 0.32) + [Vector2(0.18, 0.33)], Vector3.ZERO, bc, true, Vector3.ZERO, BODY_DEPTH)
			for i in 2:
				var leg: Array = grow(LEG, 0.012, -0.19, 0.02) if bottom == 0 else [Vector2(0.075, -0.1), Vector2(0.08, -0.08), Vector2(0.078, 0.0), Vector2(0.07, 0.02)]
				Yarn.lathe(legs[i], leg, Vector3.ZERO, bc, true, Vector3.ZERO, 1.0, 20)
				var l0: Vector2 = leg[0]
				Yarn.cyl(legs[i], Vector3(0, l0.y, 0), l0.x + 0.006, l0.x + 0.006, 0.025, bc.darkened(0.12))
		1:
			Yarn.lathe(pose, [Vector2(0.26, 0.15), Vector2(0.255, 0.17), Vector2(0.21, 0.24), Vector2(0.18, 0.3), Vector2(0.17, 0.33)], Vector3.ZERO, bc, true, Vector3.ZERO, BODY_DEPTH)
			Yarn.cyl(pose, Vector3(0, 0.155, 0), 0.262, 0.265, 0.02, bc.lightened(0.35)).scale = Vector3(1, 1, BODY_DEPTH)
	# vršek
	match top:
		0, 1:
			Yarn.lathe(pose, [Vector2(0.18, 0.27)] + grow(BODY, 0.014, 0.3, 0.53), Vector3.ZERO, tc, true, Vector3.ZERO, BODY_DEPTH)
			Yarn.cyl(pose, Vector3(0, 0.27, 0), 0.19, 0.19, 0.03, tc.darkened(0.12)).scale = Vector3(1, 1, BODY_DEPTH)
		_:
			Yarn.lathe(pose, [Vector2(0.27, 0.13), Vector2(0.265, 0.15), Vector2(0.21, 0.27)] + grow(BODY, 0.014, 0.3, 0.53), Vector3.ZERO, tc, true, Vector3.ZERO, BODY_DEPTH)
			Yarn.cyl(pose, Vector3(0, 0.135, 0), 0.272, 0.275, 0.02, Color("fffaf4")).scale = Vector3(1, 1, BODY_DEPTH)
	if top == 1:
		Yarn.cyl(pose, Vector3(0, 0.54, 0), 0.075, 0.09, 0.05, tc.lightened(0.2))
	for i in 2:
		Yarn.lathe(arms[i], grow(ARM, 0.012, -0.17 if top == 1 else -0.08, 0.02), Vector3.ZERO, tc, true, Vector3.ZERO, 1.0, 20)
	# hlava
	var head := MeshInstance3D.new(); head.mesh = hs.mesh(); head.material_override = Yarn.mat(sk); pose.add_child(head)
	head.set_meta("noscale", true); head_mi = head
	var crown := hs.top()                 # temeno
	var hw := hs.half_width()             # půlka šířky hlavy
	var cy := HeadShape.C.y
	# uši
	var ears_from := pose.get_child_count()
	match int(h.get("ears", 0)):
		0:
			for s in [-1, 1]:
				Yarn.ball(pose, Vector3(hw * 0.65 * s, crown - 0.06, -0.02), Vector3(0.12, 0.12, 0.06), sk)
				Yarn.ball(pose, Vector3(hw * 0.65 * s, crown - 0.06, 0.0), Vector3(0.065, 0.065, 0.03), sk.darkened(0.12))
		1:
			for s in [-1, 1]: Yarn.cyl(pose, Vector3(hw * 0.5 * s, crown - 0.01, -0.02), 0.0, 0.07, 0.15, sk, true, Vector3(0, 0, -0.35 * s))
		2:
			for s in [-1, 1]:
				Yarn.ball(pose, Vector3(0.08 * s, crown + 0.1, -0.02), Vector3(0.085, 0.32, 0.05), sk, true, Vector3(0, 0, -0.12 * s))
				Yarn.ball(pose, Vector3(0.08 * s, crown + 0.1, 0.0), Vector3(0.045, 0.22, 0.03), Color("ffb3c6"), true, Vector3(0, 0, -0.12 * s))
		3:
			for s in [-1, 1]: Yarn.ball(pose, Vector3((hw + 0.02) * s, 0.72, -0.02), Vector3(0.08, 0.26, 0.12), sk.darkened(0.18), true, Vector3(0, 0, 0.25 * s))
		6:
			for s in [-1, 1]: Yarn.cyl(pose, Vector3((hw + 0.04) * s, 0.74, -0.02), 0.0, 0.05, 0.16, sk, true, Vector3(0, 0, -1.25 * s))
		7:
			for s in [-1, 1]:
				Yarn.cyl(pose, Vector3(hw * 0.75 * s, crown + 0.02, -0.02), 0.0, 0.1, 0.24, sk.darkened(0.1), true, Vector3(0, 0, -0.45 * s)).scale = Vector3(1, 1, 0.35)
		4:
			for s in [-1, 1]:
				Yarn.ball(pose, Vector3((hw - 0.02) * s, crown - 0.08, -0.02), Vector3(0.17, 0.17, 0.04), sk, true, Vector3(0, 0, -0.4 * s))
				Yarn.ball(pose, Vector3((hw - 0.02) * s, crown - 0.08, -0.002), Vector3(0.1, 0.1, 0.02), Color("ffb3c6"), true, Vector3(0, 0, -0.4 * s))
	_place_ears(ears_from, float(h.get("ears_a", 0.0)), float(h.get("ears_s", 1.0)))
	# vlasy
	var hair := int(h.get("hair", 0))
	var fringe := hair in [1, 2, 3, 4, 5, 6] and hat != 1
	if hair in [1, 2, 4, 5, 6]:
		var line := crown - 0.15
		head_part(hc, 0.016, func(p: Vector3): return p.y > line or (p.z < 0.03 and p.y > cy - 0.2))
	if fringe:
		for x in [-0.13, -0.045, 0.045, 0.13]:
			Yarn.ball(pose, hs.surface(x * head_k.x, crown - 0.135, 0.004), Vector3(0.12, 0.08, 0.07), hc, true, Vector3(-0.6, 0, -x * 1.5))
	match hair:
		2:
			for s in [-1, 1]:
				Yarn.lathe(pose, [Vector2(0, -0.2), Vector2(0.04, -0.19), Vector2(0.065, -0.15), Vector2(0.06, -0.08), Vector2(0.035, -0.02), Vector2(0, 0)], Vector3((hw - 0.01) * s, 0.82, -0.08), hc, true, Vector3(0, 0, 0.5 * s), 1.0, 18)
				Yarn.ball(pose, Vector3((hw - 0.01) * s, 0.82, -0.08), Vector3(0.05, 0.05, 0.05), Data.PINK)
		3:
			for a in 11:
				var ang := -PI * 0.08 + PI * 1.16 * a / 10.0
				Yarn.ball(pose, Vector3(cos(ang) * hw * 0.95, 0.79 + sin(ang) * (crown - 0.79), -0.08), Vector3(0.13, 0.13, 0.13), hc)
		4:
			# dlouhé vlasy na záda
			Yarn.lathe(pose, [Vector2(0.2, 0.4), Vector2(0.25, 0.5), Vector2(0.27, 0.62)], Vector3(0, 0, -0.04), hc, true, Vector3.ZERO, head_depth * 0.8, 24, Vector3.ONE, PI * 0.45, PI * 1.55)
		5:
			Yarn.ball(pose, Vector3(0, crown - 0.04, -0.2), Vector3(0.08, 0.08, 0.08), Data.PINK)
			Yarn.lathe(pose, [Vector2(0, -0.32), Vector2(0.05, -0.3), Vector2(0.08, -0.22), Vector2(0.075, -0.1), Vector2(0.05, -0.02), Vector2(0, 0)], Vector3(0, crown - 0.04, -0.22), hc, true, Vector3(0.5, 0, 0), 1.0, 18)
		6:
			head_part(hc, 0.035, func(p: Vector3): return p.y > cy - 0.17 and p.y < cy + 0.02 and (p.z < 0.06 or abs(p.x) > hw * 0.7))
		7:
			for a in 7:
				var x := (a - 3) * 0.06
				Yarn.cyl(pose, Vector3(x, crown + 0.02, -0.03 - abs(x) * 0.3), 0.0, 0.05, 0.12, hc, true, Vector3(-0.3, 0, -x * 2.5))
	# obličej
	var gloss := Color("231c2a")
	var ey := 0.75
	var g_eyes := {"sp": float(h.get("eyes_sp", 1.0)), "dy": float(h.get("eyes_dy", 0.0)), "s": float(h.get("eyes_s", 1.0))}
	_begin(g_eyes)
	match int(h.get("eyes", 0)):
		0:
			for s in [-1, 1]: Yarn.ball(pose, face(0.09 * s, ey), Vector3(0.05, 0.055, 0.03), gloss, false)
		1:
			for s in [-1, 1]:
				Yarn.ball(pose, face(0.095 * s, ey, -0.004), Vector3(0.075, 0.085, 0.045), gloss, false)
				Yarn.ball(pose, face(0.105 * s, ey + 0.02, 0.012), Vector3(0.022, 0.022, 0.01), Color.WHITE, false)
				Yarn.ball(pose, face(0.08 * s, ey - 0.015, 0.012), Vector3(0.011, 0.011, 0.006), Color.WHITE, false)
		2:
			for s in [-1, 1]: Yarn.ball(pose, face(0.095 * s, ey - 0.01), Vector3(0.075, 0.02, 0.02), gloss, false)
		3:
			Yarn.ball(pose, face(-0.095, ey, -0.004), Vector3(0.075, 0.085, 0.045), gloss, false)
			Yarn.ball(pose, face(-0.085, ey + 0.02, 0.012), Vector3(0.022, 0.022, 0.01), Color.WHITE, false)
			Yarn.ball(pose, face(0.095, ey - 0.005), Vector3(0.075, 0.02, 0.02), gloss, false, Vector3(0, 0, 0.3))
		4:
			Yarn.ball(pose, face(0, ey + 0.01, -0.01), Vector3(0.15, 0.15, 0.07), Color.WHITE, false)
			Yarn.ball(pose, face(0, ey + 0.005, 0.012), Vector3(0.08, 0.09, 0.04), gloss, false)
			Yarn.ball(pose, face(0.02, ey + 0.03, 0.028), Vector3(0.025, 0.025, 0.01), Color.WHITE, false)
		5:
			for p in [Vector2(-0.11, ey - 0.01), Vector2(0.11, ey - 0.01), Vector2(0, ey + 0.06)]:
				Yarn.ball(pose, face(p.x, p.y, -0.004), Vector3(0.06, 0.07, 0.04), gloss, false)
				Yarn.ball(pose, face(p.x + 0.01, p.y + 0.015, 0.01), Vector3(0.018, 0.018, 0.008), Color.WHITE, false)
		6:
			for s in [-1, 1]:
				for r in [0.785, -0.785]:
					Yarn.box(pose, face(0.095 * s, ey, 0.004), Vector3(0.07, 0.016, 0.012), gloss).rotation.z = r
		7:
			var btn_c := Color("ff5d73")
			for s in [-1, 1]:
				Yarn.cyl(pose, face(0.095 * s, ey, 0.004), 0.04, 0.04, 0.014, btn_c if s < 0 else Color("6fa8ff"), false, Vector3(PI / 2, 0, 0)).rotation.y = -0.35 * s
				for q in [Vector2(-0.01, -0.01), Vector2(0.01, -0.01), Vector2(-0.01, 0.01), Vector2(0.01, 0.01)]:
					Yarn.ball(pose, face(0.095 * s + q.x, ey + q.y, 0.012), Vector3(0.008, 0.008, 0.004), gloss, false)
		8:
			for s in [-1, 1]:
				var c := face(0.095 * s, ey, 0.0)
				Yarn.ball(pose, c + Vector3(-0.015, 0.01, 0), Vector3(0.04, 0.04, 0.03), Color("ff3b5c"), false)
				Yarn.ball(pose, c + Vector3(0.015, 0.01, 0), Vector3(0.04, 0.04, 0.03), Color("ff3b5c"), false)
				Yarn.cyl(pose, c + Vector3(0, -0.012, 0), 0.0, 0.028, 0.035, Color("ff3b5c"), false, Vector3(PI, 0, 0)).scale = Vector3(1, 1, 0.5)
		9:
			for s in [-1, 1]:
				var g := Yarn.ball(pose, face(0.095 * s, ey, -0.004), Vector3(0.075, 0.06, 0.04), Color("7dff6a"), false)
				g.material_override = Props.glow(Color("7dff6a"))
				Yarn.ball(pose, face(0.095 * s, ey, 0.012), Vector3(0.02, 0.045, 0.01), gloss, false)
		10:
			Yarn.ball(pose, face(-0.1, ey + 0.005, -0.006), Vector3(0.1, 0.11, 0.05), Color.WHITE, false)
			Yarn.ball(pose, face(-0.1, ey, 0.012), Vector3(0.05, 0.055, 0.03), gloss, false)
			Yarn.ball(pose, face(0.095, ey, 0.0), Vector3(0.04, 0.045, 0.03), gloss, false)
		11:
			for s in [-1, 1]:
				Yarn.cyl(pose, face(0.095 * s, ey, -0.002), 0.045, 0.045, 0.012, Color.WHITE, false, Vector3(PI / 2, 0, 0)).rotation.y = -0.35 * s
				for r in [0.035, 0.022, 0.01]:
					var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = r - 0.004; tm.outer_radius = r; tm.rings = 16; tm.ring_segments = 4
					ring.mesh = tm; ring.position = face(0.095 * s + (0.035 - r) * 0.2, ey, 0.008); ring.rotation = Vector3(PI / 2, -0.35 * s, 0)
					ring.material_override = Yarn.mat(gloss); pose.add_child(ring)
	_brows(int(h.get("brows", 0)), hc, ey)
	_end()
	_begin({"dy": float(h.get("nose_dy", 0.0)), "s": float(h.get("nose_s", 1.0))})
	_nose(int(h.get("nose", 0)), sk)
	_end()
	_begin({"dy": float(h.get("mouth_dy", 0.0)), "s": float(h.get("mouth_s", 1.0))})
	_mouth(int(h.get("mouth", 0)))
	_end()
	_begin({})
	for s in [-1, 1]: Yarn.ball(pose, face(0.16 * s, 0.68, -0.006), Vector3(0.07, 0.045, 0.02), Color("ff9fb5"))
	var extra := int(h.get("extra", 0))
	if extra in [1, 3]:
		for p in [Vector2(-0.15, 0.71), Vector2(-0.12, 0.69), Vector2(-0.17, 0.685), Vector2(0.15, 0.71), Vector2(0.12, 0.69), Vector2(0.17, 0.685)]:
			Yarn.ball(pose, face(p.x, p.y, 0.001), Vector3(0.012, 0.012, 0.006), sk.darkened(0.3), false)
	_end()
	_begin(g_eyes)
	if extra in [2, 3]:
		for s in [-1, 1]:
			var g := Yarn.cyl(pose, face(0.095 * s, ey, 0.012), 0.052, 0.052, 0.012, gloss, false, Vector3(PI / 2, 0, 0))
			var inner := Yarn.cyl(pose, face(0.095 * s, ey, 0.014), 0.04, 0.04, 0.014, Color(0.85, 0.93, 1.0), false, Vector3(PI / 2, 0, 0))
			g.rotation.y = -0.35 * s; inner.rotation.y = -0.35 * s
		Yarn.box(pose, face(0, ey + 0.01, 0.018), Vector3(0.06, 0.012, 0.012), gloss)
	match extra:
		4:
			Yarn.box(pose, face(0.15, 0.7, 0.003), Vector3(0.012, 0.09, 0.008), Color("8a3a4a"), false).rotation.z = 0.3
			for k in 4:
				Yarn.box(pose, face(0.15 + (k - 1.5) * 0.008, 0.665 + k * 0.022, 0.006), Vector3(0.04, 0.007, 0.006), Color("3a2a30"), false).rotation.z = 0.3
		5:
			var pc := Color("f5d0a0")
			Yarn.box(pose, face(-0.15, 0.69, 0.006), Vector3(0.09, 0.03, 0.008), pc, false).rotation.z = 0.6
			Yarn.box(pose, face(-0.15, 0.69, 0.008), Vector3(0.09, 0.03, 0.008), pc, false).rotation.z = -0.6
		6:
			for k in 3:
				var y := 0.62 + k * 0.12
				var mid := k == 1
				var tilt := 0.25 * (k - 1)
				head_part(Color("f2ede0"), 0.01, func(p: Vector3): return abs(p.y - y - p.x * tilt) < 0.028 and not (mid and p.z > 0.05 and abs(p.x) < 0.17))
		7:
			var patch := Yarn.cyl(pose, face(0.095, ey, 0.014), 0.05, 0.05, 0.014, gloss, false, Vector3(PI / 2, 0, 0)); patch.rotation.y = -0.35
		8:
			for s in [-1, 1]:
				Yarn.ball(pose, face(0.035 * s, 0.675, 0.01), Vector3(0.07, 0.025, 0.03), hc.darkened(0.2), true, Vector3(0, 0, 0.3 * s))
	_end()
	_horns(int(h.get("horns", 0)), crown, hw)
	_tail(int(h.get("tail", 0)), sk)
	_wings(int(h.get("wings", 0)))
	# čepice
	match hat:
		1:
			var brim := crown - 0.15
			head_part(hatc, 0.032, func(p: Vector3): return p.y > brim)
			head_part(hatc.darkened(0.12), 0.045, func(p: Vector3): return p.y > brim - 0.02 and p.y < brim + 0.035)
			Yarn.ball(pose, Vector3(0, crown + 0.04, 0), Vector3(0.13, 0.13, 0.13), Color("f6f2ff"))
		2:
			for s in [-1, 1]: Yarn.ball(pose, Vector3(0.12 + 0.06 * s, crown - 0.04, 0.07), Vector3(0.1, 0.075, 0.05), hatc, true, Vector3(0, 0, 0.3 * s))
			Yarn.ball(pose, Vector3(0.12, crown - 0.04, 0.08), Vector3(0.045, 0.045, 0.045), hatc.darkened(0.15))
	_apply_pose()

func _nose(kind: int, sk: Color) -> void:
	match kind:
		0: Yarn.ball(pose, face(0, 0.7, -0.005), Vector3(0.05, 0.038, 0.035), sk.darkened(0.08))
		1: Yarn.ball(pose, face(0, 0.7, 0.01), Vector3(0.075, 0.07, 0.06), Color("ff3b5c"))
		2:
			Yarn.cyl(pose, face(0, 0.695, 0.01), 0.04, 0.042, 0.04, Color("ffb3c6"), true, Vector3(PI / 2, 0, 0))
			for s in [-1, 1]: Yarn.ball(pose, face(0.014 * s, 0.695, 0.032), Vector3(0.014, 0.018, 0.01), Color("8a3a4a"), false)
		3: Yarn.cyl(pose, face(0, 0.695, -0.004), 0.0, 0.025, 0.04, Color("231c2a"), false, Vector3(PI / 2, 0, PI)).scale = Vector3(1, 0.4, 1)
		4: Yarn.ball(pose, face(0, 0.7, 0.0), Vector3(0.07, 0.045, 0.045), Color("3a2a30"), false)
		5: pass
		6:
			Yarn.ball(pose, face(0, 0.67, -0.02), Vector3(0.2, 0.14, 0.14), sk.lightened(0.15))
			Yarn.ball(pose, face(0, 0.705, 0.035), Vector3(0.07, 0.05, 0.05), Color("2a1e24"), false)
			Yarn.box(pose, face(0, 0.665, 0.04), Vector3(0.008, 0.04, 0.008), Color("2a1e24"), false)
		7:
			Yarn.cyl(pose, face(0, 0.7, 0.008), 0.0, 0.03, 0.03, Color("ff8fb0"), false, Vector3(PI / 2, 0, PI)).scale = Vector3(1, 0.5, 1)
			for s in [-1, 1]:
				for k2 in 3:
					var w := Yarn.box(pose, face(0.09 * s, 0.68 + (k2 - 1) * 0.015, 0.01), Vector3(0.1, 0.004, 0.004), Color("3a2a30"), false)
					w.rotation.z = (k2 - 1) * 0.15 * s
		8:
			Yarn.ball(pose, face(0, 0.665, -0.02), Vector3(0.17, 0.12, 0.12), Color("f2dcc0"))
			Yarn.ball(pose, face(0, 0.695, 0.03), Vector3(0.065, 0.045, 0.04), Color("3a2a30"), false)
		9:
			Yarn.cyl(pose, face(0, 0.69, 0.02), 0.0, 0.035, 0.08, Color("ffb020"), false, Vector3(PI / 2, 0, 0))
		10:
			Yarn.ball(pose, face(0, 0.69, 0.005), Vector3(0.03, 0.03, 0.03), Color("ff8fb0"), false)
			for s in [-1, 1]:
				for k2 in 2:
					var w := Yarn.box(pose, face(0.07 * s, 0.685 + k2 * 0.012, 0.008), Vector3(0.09, 0.003, 0.003), Color("6a5a6a"), false)
					w.rotation.z = (k2 - 0.5) * 0.2 * s

func _mouth(kind: int) -> void:
	var mc := Color("7a2e44")
	match kind:
		0:
			for i in 5:
				var u := (i - 2) / 2.0
				Yarn.ball(pose, face(u * 0.03, 0.645 + u * u * 0.012, -0.002), Vector3(0.016, 0.016, 0.012), mc, false)
		1:
			Yarn.ball(pose, face(0, 0.64, -0.008), Vector3(0.1, 0.06, 0.03), Color("5a1a2a"), false)
			Yarn.ball(pose, face(0, 0.625, -0.004), Vector3(0.05, 0.025, 0.02), Color("ff7a9a"), false)
			Yarn.box(pose, face(0, 0.665, 0.0), Vector3(0.08, 0.012, 0.012), Color.WHITE, false)
		2: Yarn.ball(pose, face(0, 0.64, -0.005), Vector3(0.045, 0.055, 0.03), Color("5a1a2a"), false)
		3:
			for i in 5:
				var u := (i - 2) / 2.0
				Yarn.ball(pose, face(u * 0.035, 0.65 + u * u * 0.012, -0.002), Vector3(0.016, 0.016, 0.012), mc, false)
			for s in [-1, 1]: Yarn.cyl(pose, face(0.025 * s, 0.635, 0.004), 0.008, 0.0, 0.03, Color.WHITE, false)
		4:
			Yarn.ball(pose, face(0, 0.64, -0.01), Vector3(0.13, 0.05, 0.03), Color("5a1a2a"), false)
			for k in 5:
				Yarn.cyl(pose, face(-0.04 + k * 0.02, 0.652, 0.006), 0.0, 0.009, 0.02, Color.WHITE, false, Vector3(PI, 0, 0))
		5:
			Yarn.box(pose, face(0, 0.645, 0.002), Vector3(0.1, 0.008, 0.008), Color("3a2a30"), false)
			for k in 5:
				Yarn.box(pose, face(-0.04 + k * 0.02, 0.645, 0.006), Vector3(0.006, 0.03, 0.006), Color("3a2a30"), false)
		6:
			for i in 5:
				var u := (i - 2) / 2.0
				Yarn.ball(pose, face(u * 0.03, 0.645 + u * u * 0.012, -0.002), Vector3(0.016, 0.016, 0.012), mc, false)
			Yarn.ball(pose, face(0.015, 0.625, 0.01), Vector3(0.035, 0.045, 0.025), Color("ff7a9a"))
		7:
			for i in 5:
				var u := (i - 2) / 2.0
				Yarn.ball(pose, face(u * 0.03, 0.648 + u * u * 0.012, -0.002), Vector3(0.016, 0.016, 0.012), mc, false)
			Yarn.box(pose, face(0, 0.632, 0.004), Vector3(0.03, 0.022, 0.01), Color.WHITE, false)

func _brows(kind: int, hc: Color, ey: float) -> void:
	var c := hc.darkened(0.25)
	match kind:
		1:
			for s in [-1, 1]: Yarn.box(pose, face(0.095 * s, ey + 0.07, 0.004), Vector3(0.06, 0.013, 0.012), c, false)
		2:
			for s in [-1, 1]: Yarn.box(pose, face(0.09 * s, ey + 0.06, 0.006), Vector3(0.065, 0.016, 0.012), c, false).rotation.z = -0.4 * s
		3:
			for s in [-1, 1]: Yarn.box(pose, face(0.1 * s, ey + 0.09, 0.004), Vector3(0.055, 0.013, 0.012), c, false).rotation.z = 0.3 * s
		4:
			Yarn.box(pose, face(0, ey + 0.07, 0.004), Vector3(0.25, 0.025, 0.014), c, false)

func _horns(kind: int, crown: float, hw: float) -> void:
	match kind:
		1:
			for s in [-1, 1]: Yarn.cyl(pose, Vector3(0.1 * s, crown - 0.01, 0.03), 0.0, 0.035, 0.12, Color("e8343a"), true, Vector3(0.2, 0, -0.35 * s))
		2:
			var horn := Yarn.cyl(pose, Vector3(0, crown + 0.02, 0.1), 0.0, 0.04, 0.2, Color("ffd84a"), true, Vector3(0.45, 0, 0))
			for k in 3:
				Yarn.cyl(pose, Vector3(0, crown - 0.005 + k * 0.045, 0.09 + k * 0.022), 0.03 - k * 0.008, 0.032 - k * 0.008, 0.01, Color("ff8ab3"), false, Vector3(0.45, 0, 0))
		3:
			for s in [-1, 1]:
				Yarn.cyl(pose, Vector3(0.07 * s, crown + 0.08, 0), 0.006, 0.006, 0.18, Color("3a2a30"), false, Vector3(0, 0, -0.3 * s))
				Yarn.ball(pose, Vector3(0.1 * s, crown + 0.17, 0), Vector3(0.05, 0.05, 0.05), Color("ff8ab3"))
		4:
			for s in [-1, 1]:
				Yarn.cyl(pose, Vector3((hw + 0.02) * s, 0.6, -0.02), 0.022, 0.022, 0.06, Color("9aa4b0"), false, Vector3(0, 0, PI / 2))
				Yarn.cyl(pose, Vector3((hw + 0.05) * s, 0.6, -0.02), 0.035, 0.035, 0.02, Color("6a7480"), false, Vector3(0, 0, PI / 2))
		5:
			for s in [-1, 1]: Yarn.cyl(pose, Vector3((hw - 0.02) * s, crown - 0.06, 0), 0.0, 0.04, 0.16, Color("f2ede0"), true, Vector3(0, 0, -1.1 * s))

func _tail(kind: int, sk: Color) -> void:
	match kind:
		1:
			Yarn.cyl(pose, Vector3(0, 0.22, -0.2), 0.012, 0.012, 0.22, Color("e8343a"), false, Vector3(-0.9, 0, 0))
			Yarn.cyl(pose, Vector3(0, 0.29, -0.3), 0.0, 0.04, 0.06, Color("e8343a"), false, Vector3(-0.9, 0, 0)).scale = Vector3(1, 1, 0.4)
		2:
			for k in 7:
				var a := k * 0.25
				Yarn.ball(pose, Vector3(0, 0.22 + sin(a) * 0.12, -0.16 - (1 - cos(a)) * 0.05 - k * 0.012), Vector3(0.04, 0.04, 0.04), sk.darkened(0.1))
		3:
			Yarn.ball(pose, Vector3(0, 0.25, -0.16), Vector3(0.07, 0.07, 0.07), sk.darkened(0.1))
		4:
			Yarn.cyl(pose, Vector3(0, 0.2, -0.25), 0.01, 0.05, 0.22, Color("5cc6b8"), true, Vector3(-1.2, 0, 0))
			for k in 3:
				Yarn.cyl(pose, Vector3(0, 0.25 - k * 0.02, -0.18 - k * 0.06), 0.0, 0.02, 0.05, Color("ffc93c"), false)

func _wings(kind: int) -> void:
	if kind == 0: return
	for s in [-1, 1]:
		var w := Node3D.new(); w.position = Vector3(0.06 * s, 0.42, -0.13); w.rotation.y = 0.5 * s; pose.add_child(w)
		match kind:
			1:
				var mi := MeshInstance3D.new(); var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
				var pts := [Vector3(0, 0.04, 0), Vector3(0.28 * s, 0.14, 0), Vector3(0.22 * s, 0.02, 0), Vector3(0.16 * s, -0.04, 0), Vector3(0.08 * s, -0.06, 0)]
				for k in 3:
					st.add_vertex(pts[0]); st.add_vertex(pts[k + 1]); st.add_vertex(pts[k + 2])
				st.generate_normals(); mi.mesh = st.commit()
				var m := Yarn.mat(Color("4a3a6a")).duplicate(); m.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.material_override = m; w.add_child(mi)
			2:
				Yarn.ball(w, Vector3(0.12 * s, 0.07, 0), Vector3(0.2, 0.17, 0.015), Color("ff8ab3"), false)
				Yarn.ball(w, Vector3(0.09 * s, -0.07, 0), Vector3(0.14, 0.12, 0.015), Color("9b7cff"), false)
				Yarn.ball(w, Vector3(0.13 * s, 0.07, 0.005), Vector3(0.07, 0.06, 0.01), Color("ffe14d"), false)
			3:
				for k in 4:
					Yarn.ball(w, Vector3((0.06 + k * 0.045) * s, 0.06 - k * 0.025, 0), Vector3(0.07, 0.2 - k * 0.03, 0.02), Color("fdfcff"), true, Vector3(0, 0, -0.5 * s))

# ---------- pohyb ----------

## Příkaz: dojdi na (ax, az), pak se postav na (px, pz) natočená ry a udělej act.
func command(c: Dictionary, instant := false, route: Array = []) -> void:
	cmd = c
	act_t = 0.0
	visible = true
	var a := Vector3(float(c.get("ax", position.x)), 0, float(c.get("az", position.z)))
	if instant or position.distance_to(a) < 0.02:
		position = a
		_arrive(not instant)
	else:
		waypoints = route.duplicate() if not route.is_empty() else [a]
		if (waypoints[-1] as Vector3).distance_to(a) > 0.01: waypoints.append(a)
		target = waypoints.pop_front()
		walking = true
		_rest()

func _arrive(emit: bool) -> void:
	walking = false
	position = Vector3(float(cmd.get("px", position.x)), 0, float(cmd.get("pz", position.z)))
	if cmd.has("ry"): rotation.y = float(cmd["ry"])
	_rest()
	_apply_pose()
	if emit: arrived.emit(cmd)

func _rest() -> void:
	if pose == null: return
	pose.position = Vector3.ZERO; pose.rotation = Vector3.ZERO
	for l in legs: l.rotation.x = 0
	for i in arms.size(): arms[i].rotation = Vector3(0, 0, 0.32 * (-1 if i == 0 else 1))

func _process(d: float) -> void:
	if pose == null: return
	t += d
	if walking:
		var to := target - position
		to.y = 0
		var step := SPEED * d
		if to.length() <= step:
			position = target
			if waypoints.is_empty():
				_arrive(true)
				return
			target = waypoints.pop_front()
			return
		position += to.normalized() * step
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), min(1.0, d * 10.0))
		var sw := sin(t * 11.0) * 0.7
		legs[0].rotation.x = sw; legs[1].rotation.x = -sw
		arms[0].rotation.x = -sw * 0.8; arms[1].rotation.x = sw * 0.8
		pose.position.y = abs(sin(t * 11.0)) * 0.025
		return
	act_t += d
	_apply_pose()

func _apply_pose() -> void:
	if pose == null: return
	match str(cmd.get("act", "idle")):
		"sit":
			for l in legs: l.rotation.x = -PI / 2
			for a in arms: a.rotation.x = -0.8
			pose.position.y = 0.03
		"lie":
			pose.rotation.x = -PI / 2
			pose.position = Vector3(0, 0.4, 0.5)
		"hug":
			for i in 2: arms[i].rotation = Vector3(-1.3, 0, 0.12 * (-1 if i == 0 else 1))
			pose.rotation.z = sin(t * 3.0) * 0.06
		"kick":
			legs[1].rotation.x = -sin(min(act_t * 6.0, PI)) * 1.1
		"dance":
			rotation.y += get_process_delta_time() * 4.0
			pose.position.y = abs(sin(t * 8.0)) * 0.06
			for i in 2: arms[i].rotation = Vector3(0, 0, (2.4 + sin(t * 8.0) * 0.3) * (-1 if i == 0 else 1))
		"smell":
			pose.rotation.x = 0.35 * min(act_t * 3.0, 1.0)
		"lamp":
			arms[1].rotation = Vector3(-2.4 if act_t < 0.7 else 0.0, 0, 0.32)
		"hide":
			visible = act_t > 2.0
		"read":
			for i in 2: arms[i].rotation = Vector3(-1.0, 0, 0.15 * (-1 if i == 0 else 1))
			pose.rotation.x = 0.12
		"eat":
			arms[1].rotation = Vector3(-1.9 - sin(t * 6.0) * 0.4, 0, 0.5)
		"cook":
			arms[1].rotation = Vector3(-1.2, sin(t * 6.0) * 0.5, 0.2)
			arms[0].rotation = Vector3(-0.9, 0, -0.2)
		"look":
			pose.rotation.x = -0.08
			arms[0].rotation = Vector3(0, 0, -0.6); arms[1].rotation = Vector3(-2.4 if fmod(act_t, 2.0) < 1.0 else -2.0, 0, 0.3)
		"play":
			for l in legs: l.rotation.x = -PI / 2
			pose.position.y = -0.2
			for i in 2: arms[i].rotation = Vector3(-0.9 + sin(t * 5.0 + i * 2.0) * 0.35, 0, 0.2 * (-1 if i == 0 else 1))
		"brush":
			arms[1].rotation = Vector3(-2.0, sin(t * 14.0) * 0.35, 0.55)
		"wash":
			for i in 2: arms[i].rotation = Vector3(-1.1 + sin(t * 10.0 + i * PI) * 0.15, 0, -0.25 * (-1 if i == 0 else 1))
			pose.rotation.x = 0.08
		"dry":
			for i in 2: arms[i].rotation = Vector3(-2.2 + sin(t * 8.0 + i * PI) * 0.2, 0, 0.35 * (-1 if i == 0 else 1))
		"comb":
			arms[1].rotation = Vector3(-2.9, 0, 0.6 + sin(t * 6.0) * 0.3)
		"toilet":
			for l in legs: l.rotation.x = -PI / 2
			pose.position.y = -0.05
			for a in arms: a.rotation.x = -0.4
		"bath":
			for l in legs: l.rotation.x = -PI / 2
			pose.position.y = 0.02
			for i in 2: arms[i].rotation = Vector3(-0.3, 0, (1.2 + sin(t * 4.0 + i) * 0.3) * (-1 if i == 0 else 1))
		"drink":
			arms[1].rotation = Vector3(-2.0, 0, 0.45)
			pose.rotation.x = -0.1
		"tidy":
			pose.rotation.x = 0.45 * min(act_t * 3.0, 1.0)
			arms[1].rotation = Vector3(-0.6 + sin(t * 4.0) * 0.3, 0, 0.3)
		"draw":
			for l in legs: l.rotation.x = -PI / 2
			pose.position.y = -0.2
			pose.rotation.x = 0.25
			arms[1].rotation = Vector3(-1.0, sin(t * 7.0) * 0.4, 0.3)
		"alarm", "wish", "open":
			pose.position.y = abs(sin(t * 6.0)) * 0.05 if str(cmd.get("act")) == "alarm" else 0.0
			for i in 2: arms[i].rotation = Vector3(0, 0, (2.6 + sin(t * 5.0) * 0.15) * (-1 if i == 0 else 1))
		"pet":
			pose.rotation.x = 0.35
			arms[1].rotation = Vector3(-1.2 + sin(t * 5.0) * 0.25, 0, 0.3)
		"feed":
			arms[1].rotation = Vector3(-1.8 + sin(t * 9.0) * 0.1, 0, 0.3)
		"window":
			pose.position.y = sin(t * 2.0) * 0.006
			arms[1].rotation = Vector3(-0.6, 0, 0.3)
		_:
			pose.position.y = sin(t * 2.0) * 0.006
			for a in arms: a.rotation.x = sin(t * 2.0) * 0.05
