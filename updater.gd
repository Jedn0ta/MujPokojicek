extends Node
## Aktualizace z GitHubu (repozitář musí být veřejný).
## V repozitáři: updates/version.json, updates/pokojicek.pck; APK v GitHub Releases.
## version.json: {"content": 7, "apk": 5, "min_apk": 5, "apk_url": "https://github.com/…/MujPokojicek.apk"}

signal status(kind: String, text: String)   # kind: checking, downloading, done, latest, apk, error

const REPO := "Jedn0ta/MujPokojicek"
const BRANCH := "main"
const CONTENT := 4   # číslo obsahu v téhle verzi; zvyšuje se s každou aktualizací

var base := ""   # jen pro zkoušku; prázdné = GitHub
var _http: HTTPRequest
var _info := {}

static func current_content() -> int:
	return max(CONTENT, int(Engine.get_meta("content_loaded", 0)))

func _raw(path: String) -> String:
	if base != "": return base + "/" + path
	return "https://raw.githubusercontent.com/%s/%s/%s" % [REPO, BRANCH, path]

func check() -> void:
	if _http: _http.queue_free()
	_http = HTTPRequest.new(); add_child(_http)
	_http.request_completed.connect(_on_info)
	status.emit("checking", "")
	var err := _http.request(_raw("updates/version.json?t=%d" % Time.get_unix_time_from_system()))
	if err != OK: status.emit("error", "Bez internetu")

func _on_info(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		status.emit("error", "Aktualizace nenalezena")
		return
	var info = JSON.parse_string(body.get_string_from_utf8())
	if not info is Dictionary:
		status.emit("error", "Špatný soubor verze")
		return
	_info = info
	var apk := int(Engine.get_meta("apk_code", 0))
	if int(info.get("min_apk", 0)) > apk:
		# nový obsah potřebuje novější aplikaci (třeba nová oprávnění) — jen tehdy APK
		status.emit("apk", str(info.get("apk_url", "")))
		return
	if int(info.get("content", 0)) <= current_content():
		status.emit("latest", "")
		return
	_download()

func _download() -> void:
	if _http: _http.queue_free()
	_http = HTTPRequest.new(); add_child(_http)
	_http.download_file = "user://update_new.pck"
	_http.request_completed.connect(_on_pck)
	status.emit("downloading", "")
	_http.request(_raw(str(_info.get("pck", "updates/pokojicek.pck"))))

func progress() -> float:
	if _http == null or _http.get_body_size() <= 0: return 0.0
	return float(_http.get_downloaded_bytes()) / _http.get_body_size()

func _on_pck(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		status.emit("error", "Stažení se nepovedlo")
		return
	var d := DirAccess.open("user://")
	if d.file_exists("update.pck"): d.remove("update.pck")
	d.rename("update_new.pck", "update.pck")
	var f := FileAccess.open("user://update.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_info))
	status.emit("done", "")

## Spustí hru znovu, aby se načetla nová verze.
func restart() -> void:
	if OS.has_feature("android") or OS.has_feature("mobile"):
		get_tree().quit()
	else:
		OS.set_restart_on_exit(true)
		get_tree().quit()
