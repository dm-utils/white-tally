extends RefCounted
## Every shipped puzzle is re-checked (design 13.1 Pool); full re-solving is tools/verify_puzzles.gd.

var _check: Callable


func run(check: Callable, _node: Node) -> void:
	_check = check
	var store := TallyGame.store()
	_check.call(store.practice_count() == 40, "the pool has 40 sets")
	var all_ok := true
	var sizes_ok := true
	var fallbacks := 0
	for i in store.practice_count():
		var set := store.practice_set(i)
		sizes_ok = sizes_ok and set.size() == 3
		for level in set.size():
			var p: Dictionary = set[level]
			var why := _problem(p, level)
			if not why.is_empty():
				all_ok = false
				print("pool set %d level %d: %s" % [i, level, why])
			fallbacks += 1 if p.fallback else 0
	_check.call(sizes_ok, "every set has three puzzles")
	_check.call(all_ok, "every pool puzzle is stable, balanced, in band and cleared by its path in par moves")
	_check.call(fallbacks <= 2, "at most two flagged fallback puzzles in the pool")


func _problem(p: Dictionary, level: int) -> String:
	var b: TallyBoard = p.board
	var s := b.start
	if b.is_solved(s) or not b.is_stable(s):
		return "start is empty or not stable"
	for v in [2, 3, 4]:
		var n := 0
		for c in s:
			n += 1 if c == v else 0
		if n % v != 0:
			return "count of %d is not a multiple" % v
	var band: Array = TallyGenerator.LEVELS[level].band
	if not p.fallback and (p.par < band[0] or p.par > band[1]):
		return "par %d outside the band" % p.par
	if p.par > p.upper or p.path.size() != p.par:
		return "par, upper or path length inconsistent"
	for m in p.path:
		var n: Variant = b.apply(s, m)
		if n == null:
			return "path has an ignored move"
		s = n
	return "" if b.is_solved(s) else "path does not empty the board"
