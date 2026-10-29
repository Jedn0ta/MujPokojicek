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
	_music.volume_db = _db(music_vol) - 6.0
	_music.finished.connect(_next_song)
	for k in 6:
		var p := AudioStreamPlayer.new(); add_child(p); _pool.append(p)
	if music_on: _next_song()

const SONGS := 9
var _song := -1

## Další písnička (náhodně, ale nikdy stejná dvakrát po sobě).
func _next_song() -> void:
	if not music_on: return
	var k := randi() % SONGS
	if k == _song: k = (k + 1) % SONGS
	_song = k
	var st = load("res://music/hudba%d.ogg" % (k + 1))
	if st == null: return
	st.loop = false
	_music.stream = st; _music.play()

static var music_vol := 0.7
static var sfx_vol := 0.9

static func _db(v: float) -> float:
	return -80.0 if v <= 0.01 else linear_to_db(v)

static func set_volumes(mv: float, sv: float) -> void:
	music_vol = mv; sfx_vol = sv
	if inst: inst._music.volume_db = _db(mv) - 6.0

static func set_music(on: bool) -> void:
	music_on = on
	if inst == null: return
	if on: inst._next_song()
	if not on: inst._music.stop()

static func play(name: String, pitch_rand := 0.08, vol := 0.0) -> void:
	if inst == null or not sfx_on or name == "": return
	if not inst._cache.has(name):
		var path := "res://sounds/%s.ogg" % name
		if not ResourceLoader.exists(path): path = "res://sounds/%s.wav" % name
		inst._cache[name] = load(path) if ResourceLoader.exists(path) else null
	if inst._cache[name] == null: return
	for p in inst._pool:
		if not p.playing:
			p.stream = inst._cache[name]; p.volume_db = vol + _db(sfx_vol)
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
