class_name Snd
extends Node
## Hudba a veselé zvuky. Snd.play("pop") odkudkoli.

static var inst: Snd
static var music_on := true
static var sfx_on := true
var _music: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _cache := {}

func _ready() -> void:
	inst = self
	_music = AudioStreamPlayer.new(); add_child(_music)
	var s: AudioStreamWAV = load("res://sounds/hudba.wav")
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD; s.loop_begin = 0; s.loop_end = s.data.size() / 2
	_music.stream = s; _music.volume_db = -9.0
	for k in 6:
		var p := AudioStreamPlayer.new(); add_child(p); _pool.append(p)
	if music_on: _music.play()

static func set_music(on: bool) -> void:
	music_on = on
	if inst == null: return
	if on and not inst._music.playing: inst._music.play()
	if not on: inst._music.stop()

static func play(name: String, pitch_rand := 0.08, vol := 0.0) -> void:
	if inst == null or not sfx_on or name == "": return
	if not inst._cache.has(name):
		var path := "res://sounds/%s.wav" % name
		inst._cache[name] = load(path) if ResourceLoader.exists(path) else null
	if inst._cache[name] == null: return
	for p in inst._pool:
		if not p.playing:
			p.stream = inst._cache[name]; p.volume_db = vol
			p.pitch_scale = 1.0 + randf_range(-pitch_rand, pitch_rand); p.play(); return

## Zvuk pro věc, se kterou si panenka hraje (jen u věcí, které zvuk opravdu vydávají).
static func for_item(id: String, act: String) -> String:
	match id:
		"kocicka": return "mnau"
		"mic": return "boing"
		"kostky", "domecek": return "klap"
		"autick": return "brm"
		"dino1", "dino2": return "rrr"
		"panenka": return "hihi"
		"akvarko", "kulate", "zelvicka": return "bublinky"
		"zalivacka": return "bublinky"
		"masozravka": return "klap"
		"hvezdicka", "hvezdy", "hvezdnalampa", "kufr": return "trpyt"
		"xylofon", "bubinek", "kytara", "klavir", "trumpetka", "tamburina": return id
	match act:
		"hug": return "piskani"
		"lamp": return "cvak"
		"open": return "pop"
		"eat": return "chroup"
		"feed": return "cvrlik"
		"bath", "wash", "brush": return "bublinky"
		"kick": return "boing"
	return ""
