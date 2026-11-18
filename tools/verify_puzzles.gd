extends SceneTree
## Re-solves every puzzle of a file with its level's budget; exit 1 on any mismatch.
##   godot --headless --path . -s res://tools/verify_puzzles.gd -- --file=build/practice.json


func _init() -> void:
	var file := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--file="):
			file = a.get_slice("=", 1)
	var json := JSON.new()
	if file.is_empty() or json.parse(FileAccess.get_file_as_string(file)) != OK or not json.data is Dictionary:
		printerr("usage: --file=<puzzle json>")
		quit(1)
		return
	var bad := 0
	for key in json.data:
		var notes := PackedStringArray()
		var level := 0
		for raw in json.data[key]:
			var why := _check(raw, level)
			if not why.is_empty():
				notes.append("level %d: %s" % [level, why])
			level += 1
		print("%s %s" % [key, "ok" if notes.is_empty() else "MISMATCH " + "; ".join(notes)])
		bad += 0 if notes.is_empty() else 1
	print("verify: %d of %d keys ok" % [json.data.size() - bad, json.data.size()])
	quit(1 if bad > 0 else 0)


func _check(raw: Dictionary, level: int) -> String:
	var p := TallyGame.convert(raw)
	var b: TallyBoard = p.board
	if p.path.is_empty() or p.path.size() != p.par:
		return "path length differs from par"
	var s := b.start
	for m in p.path:
		var n: Variant = b.apply(s, m)
		if n == null:
			return "path has an ignored move"
		s = n
	if not b.is_solved(s) or not b.is_stable(b.start):
		return "path does not empty a stable board"
	var r := TallySolver.solve(b, b.start, p.path, TallyGenerator.LEVELS[level].budget)
	if r.par != p.par or r.exact != p.exact:
		return "stored par %d exact %s, solver par %d exact %s" % [p.par, p.exact, r.par, r.exact]
	return ""
