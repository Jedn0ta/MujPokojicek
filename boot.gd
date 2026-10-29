extends Node
## Spouštěč: nejdřív načte staženou aktualizaci (user://update.pck), pak hru.

## Číslo nainstalované APK. Tenhle skript se načte z APK ještě před aktualizací,
## takže číslo vždy patří k opravdu nainstalované aplikaci.
const APK_CODE := 7

func _ready() -> void:
	var apk := APK_CODE
	Engine.set_meta("apk_code", apk)
	var info_path := "user://update.json"
	# obsah zabalený přímo v nainstalované APK (načte se ještě před aktualizací)
	var built_in: int = load("res://updater.gd").CONTENT
	if FileAccess.file_exists("user://update.pck") and FileAccess.file_exists(info_path):
		var info = JSON.parse_string(FileAccess.get_file_as_string(info_path))
		var ok: bool = info is Dictionary and int(info.get("min_apk", 0)) <= apk and int(info.get("content", 0)) > built_in
		if ok and ProjectSettings.load_resource_pack("user://update.pck", true):
			Engine.set_meta("content_loaded", int(info.get("content", 0)))
		elif not ok:
			# stažená aktualizace je starší než nainstalovaná hra: pryč s ní
			DirAccess.remove_absolute("user://update.pck")
			DirAccess.remove_absolute(info_path)
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")
