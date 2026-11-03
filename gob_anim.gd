extends Node
## Zvířátka Gobkit mají jednu animační stopu: idle 0–29, útok 30–59, konec 60–89, chůze 90–119 (24 fps).
## Podle toho, jestli se rodič zrovna pohybuje, přehrává chůzi nebo odpočinek.

var ap: AnimationPlayer
var clip := ""
var body: Node3D
var _last := Vector3.ZERO
var _t := 0.0
var always_idle := false

func _ready() -> void:
	body = get_parent()
	ap = body.find_child("AnimationPlayer", true, false)
	if ap and ap.get_animation_list().size() > 0:
		clip = ap.get_animation_list()[0]
		ap.play(clip); ap.pause()
	_last = body.position

func _process(d: float) -> void:
	if ap == null: return
	_t += d
	var moving := not always_idle and body.position.distance_to(_last) > 0.0005
	_last = body.position
	var a := 90.0 / 24.0 if moving else 0.0
	ap.seek(a + fmod(_t, 29.0 / 24.0), true)
