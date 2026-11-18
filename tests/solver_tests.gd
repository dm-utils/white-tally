extends RefCounted
## Solver, generator and determinism (design 5.4, 5.5, 13.1).

const SMALL := {"w": 4, "h": 3, "i": [2, 3], "q": [0, 1], "chain": 20, "values": 1, "overfull": 0, "gap": -1,
	"band": [1, 8], "candidates": 60, "budget": 200000}

var _check: Callable


func run(check: Callable, _node: Node) -> void:
	_check = check
	_example_5()
	_beam_greedy()
	_small_boards_against_bfs()
	_generator()
	_no_forbidden_rng()


func _example_5() -> void:
	var b := TallyBoard.create(4, 3)
	b.start = b.from_rows(PackedStringArray(["....", "..2.", "3233"]))
	var up := PackedInt32Array([b.decode_move("RB1"), b.decode_move("LD1")])
	var r := TallySolver.solve(b, b.start, up, 1000)
	_check.call(r.par == 2 and r.exact and not r.capped, "solve: example 5 has exact par 2")
	_check.call(_clears(b, r.path) and r.path.size() == 2, "solve: the returned path empties the board")
	var c := TallySolver.solve(b, b.start, up, 0)
	_check.call(c.capped and not c.exact and c.par == 2, "solve: zero budget is capped, bounded, par from upper path")
	var s := b.step(b.start, b.decode_move("LC2"))
	var d := TallySolver.solve(b, s, PackedInt32Array([b.decode_move("RA1")]), 1000)
	_check.call(d.par == 1 and d.exact, "solve: upper path of one move is returned as exact")


func _clears(b: TallyBoard, path: PackedInt32Array) -> bool:
	var s := b.start
	for m in path:
		var n: Variant = b.apply(s, m)
		if n == null:
			return false
		s = n
	return b.is_solved(s)


func _beam_greedy() -> void:
	var b := TallyBoard.create(4, 3)
	b.start = b.from_rows(PackedStringArray(["....", "..2.", "3233"]))
	var p := TallySolver.beam(b, b.start, 50, 3)
	_check.call(p.size() == 2 and _clears(b, p), "beam finds the two-move solution")
	_check.call(TallySolver.beam(b, b.start, 50, 1).is_empty(), "beam returns nothing when the depth is too small")
	var g := TallySolver.greedy(b, b.start, 6)
	_check.call(g.solved and g.moves == 2, "greedy solves example 5 in two moves")
	var dead := TallyBoard.create(6, 2)
	dead.start = dead.from_rows(PackedStringArray(["......", "222222"]))
	var h := TallySolver.greedy(dead, dead.start, 6)
	_check.call(not h.solved and h.moves == 0, "greedy gives up when nothing can be removed")


# plain bfs over reachable states, test helper
func _bfs(b: TallyBoard) -> int:
	var seen := {b.start: true}
	var level: Array = [b.start]
	var depth := 0
	while not level.is_empty():
		var next: Array = []
		for s in level:
			if b.is_solved(s):
				return depth
			for m in b.legal_moves(s):
				var c := b.step(s, m)
				if not seen.has(c):
					seen[c] = true
					next.append(c)
		level = next
		depth += 1
	return -1


func _small_boards_against_bfs() -> void:
	var found := 0
	var agree := 0
	var sd := 0
	while found < 20 and sd < 400:
		var r := TallyGenerator.generate_with(WhiteSeed.fnv1a64("white-tally-test|%d" % sd), SMALL)
		sd += 1
		var b: TallyBoard = r.board
		if b.count_tiles(b.start) > 8 or r.fallback or r.par == 0:
			continue
		found += 1
		var truth := _bfs(b)
		if truth == r.par and r.exact:
			agree += 1
	_check.call(found == 20, "twenty small boards found for the bfs comparison")
	_check.call(agree == found, "solver par equals breadth-first search on small boards")


func _generator() -> void:
	var a := TallyGenerator.generate(WhiteSeed.fnv1a64("white-tally-test|det"), 0)
	var b := TallyGenerator.generate(WhiteSeed.fnv1a64("white-tally-test|det"), 0)
	_check.call(TallyGenerator.to_json(a) == TallyGenerator.to_json(b), "generate twice gives the same puzzle")
	var ok := true
	var mult := true
	for sd in 6:
		var r := TallyGenerator.generate_with(WhiteSeed.fnv1a64("white-tally-test|g%d" % sd), SMALL)
		var bd: TallyBoard = r.board
		ok = ok and bd.is_stable(bd.start) and not bd.is_solved(bd.start) and _clears(bd, r.path) \
				and r.path.size() == r.par and r.par <= r.upper
		for v in [2, 3, 4]:
			var n := 0
			for c in bd.start:
				if c == v:
					n += 1
			mult = mult and n % v == 0
	_check.call(ok, "generated start is stable and its path empties the board in par moves, par <= upper")
	_check.call(mult, "value counts are multiples of the value")
	var j := TallyGenerator.to_json(a)
	var conv := TallyBoard.from_dict(j.board)
	_check.call(conv.start == (a.board as TallyBoard).start and j.path.length() == 3 * j.par, "puzzle json converts back")


func _no_forbidden_rng() -> void:
	var bad := false
	var d := DirAccess.open("res://sim")
	for f in d.get_files():
		if not f.ends_with(".gd"):
			continue
		var t := FileAccess.get_file_as_string("res://sim/" + f)
		for w in ["RandomNumberGenerator", "randi(", "randf(", "randomize(", "next_float"]:
			if t.contains(w):
				bad = true
	_check.call(not bad, "sim/ uses no engine randomness")
