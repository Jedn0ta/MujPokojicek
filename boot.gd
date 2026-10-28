extends Node
## Spouštěč: nejdřív načte staženou aktualizaci (user://update.pck), pak hru.
## Číslo nainstalované APK se čte z res://apk_code.txt ještě PŘED načtením aktualizace,
## aby aktualizace nemohla zamaskovat, že je potřeba nová APK.

func _ready() -> void:
	var apk := 0
	if FileAccess.file_exists("res://apk_code.txt"):
		apk = int(FileAccess.get_file_as_string("res://apk_code.txt").strip_edges())
	Engine.set_meta("apk_code", apk)
	var info_path := "user://update.json"
	if FileAccess.file_exists("user://update.pck") and FileAccess.file_exists(info_path):
		var info = JSON.parse_string(FileAccess.get_file_as_string(info_path))
		if info is Dictionary and int(info.get("min_apk", 0)) <= apk:
			if ProjectSettings.load_resource_pack("user://update.pck", true):
				Engine.set_meta("content_loaded", int(info.get("content", 0)))
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")
