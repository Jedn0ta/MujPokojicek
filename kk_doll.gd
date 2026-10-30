class_name KKDoll
extends Node3D
## Postavička složená z dílů balíčků KayKit Adventurers a Skeletons (CC0).
## Všechny mají stejnou kostru, takže hlava, tělo, ruce, nohy, klobouk a plášť
## jdou libovolně kombinovat. Animace (chůze, sezení, ležení…) jsou z rytíře.

signal arrived(cmd: Dictionary)

const SCALE := 0.42
const SPEED := 0.8
const SRC := ["Knight", "Mage", "Barbarian", "Rogue", "Rogue_Hooded", "Skeleton_Minion", "Skeleton_Mage", "Skeleton_Rogue", "Skeleton_Warrior"]
# díly: [soubor, [jména meshů]]
const HEADS := [["Knight", ["Knight_Head"]], ["Mage", ["Mage_Head"]], ["Barbarian", ["Barbarian_Head"]], ["Rogue", ["Rogue_Head"]], ["Rogue_Hooded", ["Rogue_Head_Hooded"]],
	["Skeleton_Minion", ["Skeleton_Minion_Head", "Skeleton_Minion_Eyes", "Skeleton_Minion_Jaw"]], ["Skeleton_Mage", ["Skeleton_Mage_Skull", "Skeleton_Mage_Eyes", "Skeleton_Mage_Jaw"]],
	["Skeleton_Rogue", ["Skeleton_Rogue_Head", "Skeleton_Rogue_Eyes", "Skeleton_Rogue_Jaw"]], ["Skeleton_Warrior", ["Skeleton_Warrior_Head", "Skeleton_Warrior_Eyes", "Skeleton_Warrior_Jaw"]]]
const HATS := [[], ["Knight", ["Knight_Helmet"]], ["Mage", ["Mage_Hat"]], ["Barbarian", ["Barbarian_Hat"]], ["Skeleton_Mage", ["Skeleton_Mage_Hat"]], ["Skeleton_Rogue", ["Skeleton_Rogue_Hood"]], ["Skeleton_Warrior", ["Skeleton_Warrior_Helmet"]]]
const CAPES := [[], ["Knight", ["Knight_Cape"]], ["Mage", ["Mage_Cape"]], ["Barbarian", ["Barbarian_Cape"]], ["Rogue", ["Rogue_Cape"]], ["Skeleton_Minion", ["Skeleton_Minion_Cloak"]], ["Skeleton_Rogue", ["Skeleton_Rogue_Cape"]], ["Skeleton_Warrior", ["Skeleton_Warrior_Cloak"]]]
const TINT := [Color(1, 1, 1), Color("ffb3c8"), Color("b3d4ff"), Color("c8f0b0"), Color("ffe08a"), Color("d6c2ff"), Color("ffc49a"), Color("9ae6e0")]

static var _scenes := {}
static var _parts := {}   # "soubor/mesh" -> [mesh, skin, bone, transform]

var cmd: Dictionary = {}
var walking := false
var target := Vector3.ZERO
var waypoints: Array = []
var t := 0.0
var act_t := 0.0
var rig: Node3D
var skel: Skeleton3D
var player: AnimationPlayer
var _anim := ""

static func _scene(n: String) -> PackedScene:
	if not _scenes.has(n): _scenes[n] = load("res://models/chars/%s.glb" % n)
	return _scenes[n]

static func _part(file: String, mesh: String) -> Array:
	var key := file + "/" + mesh
	if _parts.has(key): return _parts[key]
	var inst: Node = _scene(file).instantiate()
	var found := inst.find_children(mesh, "MeshInstance3D", true, false)
	var mi: MeshInstance3D = found[0] if not found.is_empty() else null
	var out := []
	if mi:
		var bone := ""
		var xf: Transform3D = mi.transform
		if mi.get_parent() is BoneAttachment3D:
			# doplněk je v souboru vlastní kost pod hlavou / hrudí: připneme ho na rodičovskou kost
			var ba := mi.get_parent() as BoneAttachment3D
			var sk := ba.get_parent() as Skeleton3D
			var bi := sk.find_bone(ba.bone_name)
			var parent := sk.get_bone_parent(bi)
			bone = sk.get_bone_name(parent) if parent >= 0 else ba.bone_name
			xf = sk.get_bone_rest(bi) * mi.transform
		out = [mi.mesh, mi.skin, bone, xf]
	inst.free()
	_parts[key] = out
	return out

static func names(kind: String) -> int:
	match kind:
		"kkhead", "kkbody", "kkarms", "kklegs": return SRC.size()
		"kkhat": return HATS.size()
		"kkcape": return CAPES.size()
		"kktint", "kkhattint": return TINT.size()
	return 0

func build(h: Dictionary) -> void:
	for c in get_children(): c.free()
	rig = _scene("Knight").instantiate(); add_child(rig)
	rig.scale = Vector3.ONE * SCALE
	skel = rig.find_child("Skeleton3D", true, false)
	player = rig.find_child("AnimationPlayer", true, false)
	for mi in rig.find_children("*", "MeshInstance3D", true, false): mi.free()
	var tint: Color = TINT[int(h.get("kktint", 0)) % TINT.size()]
	var htint: Color = TINT[int(h.get("kkhattint", 0)) % TINT.size()]
	var src := func(key: String) -> String: return SRC[int(h.get(key, 0)) % SRC.size()]
	_add(HEADS[int(h.get("kkhead", 0)) % HEADS.size()], Color.WHITE)
	_add([src.call("kkbody"), [src.call("kkbody") + "_Body"]], tint)
	_add([src.call("kkarms"), [src.call("kkarms") + "_ArmLeft", src.call("kkarms") + "_ArmRight"]], tint)
	_add([src.call("kklegs"), [src.call("kklegs") + "_LegLeft", src.call("kklegs") + "_LegRight"]], tint)
	_add(HATS[int(h.get("kkhat", 0)) % HATS.size()], htint)
	_add(CAPES[int(h.get("kkcape", 0)) % CAPES.size()], tint)
	for a in ["Idle", "Walking_A", "Sit_Chair_Idle", "Lie_Idle", "Sit_Floor_Idle", "Cheer", "Interact", "Use_Item", "Spellcasting", "Blocking", "Unarmed_Idle"]:
		if player.has_animation(a): player.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_play("Idle")

func _add(spec: Array, tint: Color) -> void:
	if spec.is_empty(): return
	for mname in spec[1]:
		var p := _part(spec[0], mname)
		if p.is_empty(): continue
		var mi := MeshInstance3D.new(); mi.mesh = p[0]
		if tint != Color.WHITE:
			var mat: StandardMaterial3D = (p[0] as Mesh).surface_get_material(0).duplicate()
			mat.albedo_color = tint; mi.material_override = mat
		if p[1] != null:
			mi.skin = p[1]; skel.add_child(mi); mi.skeleton = NodePath("..")
		else:
			var ba := BoneAttachment3D.new(); skel.add_child(ba); ba.bone_name = p[2]
			mi.transform = p[3]; ba.add_child(mi)

func _play(a: String, blend := 0.2) -> void:
	if player == null or a == _anim or not player.has_animation(a): return
	_anim = a; player.play(a, blend)

func _seq(first: String, then: String) -> void:
	if _anim == then or _anim == first: return
	_anim = first; player.play(first, 0.15)
	player.queue(then)
	await player.animation_finished
	if _anim == first: _anim = then

# ---------- pohyb (stejné rozhraní jako panenka) ----------

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
		if rig: rig.position = Vector3.ZERO
		_play("Walking_A")

func _arrive(emit: bool) -> void:
	walking = false
	position = Vector3(float(cmd.get("px", position.x)), 0, float(cmd.get("pz", position.z)))
	if cmd.has("ry"): rotation.y = float(cmd["ry"])
	_start_act()
	if emit: arrived.emit(cmd)

func _start_act() -> void:
	if rig == null: return
	rig.position = Vector3.ZERO; rig.rotation = Vector3.ZERO
	match str(cmd.get("act", "idle")):
		"sit", "toilet": _seq("Sit_Chair_Down", "Sit_Chair_Idle"); rig.position = Vector3(0, -0.02, 0.06)
		"lie": _seq("Lie_Down", "Lie_Idle"); rig.position = Vector3(0, 0.3, 0)
		"play", "draw", "bath": _seq("Sit_Floor_Down", "Sit_Floor_Idle")
		"dance", "wish", "alarm", "open": _play("Cheer")
		"eat", "drink", "brush", "comb", "feed", "dry", "wash": _play("Use_Item")
		"lamp", "tidy", "pet", "smell", "cook": _play("Interact")
		"hug": _play("Blocking")
		"kick": _play("Unarmed_Melee_Attack_Kick")
		"read": _play("Spellcasting")
		_: _play("Idle")

func _process(d: float) -> void:
	if rig == null: return
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
		return
	act_t += d
	match str(cmd.get("act", "idle")):
		"hide": visible = act_t > 2.0
		"dance": rotation.y += d * 2.0
		"kick": if act_t > 1.0: _play("Idle")
