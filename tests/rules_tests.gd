extends RefCounted
## Rules of design 2: the six examples, canonical form, fast vs reference, notation, attempt and record.

var _check: Callable


func run(check: Callable, _node: Node) -> void:
	_check = check
	_examples()
	_canonical()
	_random_agreement()
	_traced()
	_invariants()
	_notation()
	_attempt()


static func mk(rows: Array) -> TallyBoard:
	var b := TallyBoard.create(str(rows[0]).length(), rows.size())
	b.start = b.from_rows(PackedStringArray(rows))
	return b


func _play(b: TallyBoard, s: PackedByteArray, token: String) -> PackedByteArray:
	return b.step(s, b.decode_move(token))


## Random stable state: random column heights and values, then resolved.
static func random_state(b: TallyBoard, rng: WhiteRng, min_tiles: int, max_tiles: int) -> PackedByteArray:
	while true:
		var s := PackedByteArray()
		s.resize(b.w * b.h)
		for x in b.w:
			for y in rng.range_int(0, b.h):
				s[y * b.w + x] = rng.range_int(2, 4)
		s = b.resolve(s)
		var n := b.count_tiles(s)
		if n >= min_tiles and n <= max_tiles:
			return s
	return PackedByteArray()


func _examples() -> void:
	var b := mk(["2...", "34..", "3232"])
	_check.call(b.is_stable(b.start), "example 1 start is stable")
	var s := _play(b, b.start, "RB1")
	_check.call(b.render(s) == "....\n....\n24..", "example 1: swap makes two exact groups that vanish together")
	b = mk([".2.2", "2233"])
	_check.call(b.is_stable(b.start) and b.exact_groups(b.start).is_empty(), "example 2 start: three 2s are overfull")
	s = _play(b, b.start, "RB2")
	_check.call(b.render(s) == "....\n..33", "example 2: slide breaks the overfull group and completes two pairs")
	b = mk(["3..", "42.", "233"])
	s = _play(b, b.start, "RA2")
	_check.call(b.render(s) == "...\n...\n.4.", "example 3: chain resolves in two waves")
	b = mk(["3.", "2.", "4."])
	s = _play(b, b.start, "RA2")
	_check.call(b.render(s) == "..\n3.\n42", "example 4: slide out of the middle of a stack")
	b = mk(["....", "..2.", "3233"])
	s = _play(b, b.start, "RB1")
	_check.call(b.render(s) == "....\n....\n33.3", "example 5: swap makes the 2s vanish")
	s = _play(b, s, "LD1")
	_check.call(b.is_solved(s), "example 5: RB1 LD1 empties the board")
	s = _play(_b5(), _b5().start, "LC2")
	s = _play(_b5(), s, "RA1")
	_check.call(_b5().is_solved(s), "example 5: LC2 RA1 is a second solution")
	var single := true
	for m in b.legal_moves(b.start):
		if b.is_solved(b.step(b.start, m)):
			single = false
	_check.call(single, "example 5: no single move empties the board")
	var e6 := mk(["......", "222222"])
	_check.call(e6.is_dead_end(e6.start) and e6.legal_moves(e6.start).is_empty(), "example 6 is a dead end")
	for rows in [["2...", "34..", "3232"], [".2.2", "2233"], ["3..", "42.", "233"], ["3.", "2.", "4."], ["....", "..2.", "3233"]]:
		var eb := mk(rows)
		_check.call(not eb.is_dead_end(eb.start), "no dead end at the start of examples 1-5")


func _b5() -> TallyBoard:
	return mk(["....", "..2.", "3233"])


func _canonical() -> void:
	var b := mk(["...", "22.", "232"])
	var c := func(t: String) -> int: return b.canonical(b.start, b.decode_move(t))
	_check.call(c.call("DB2") == b.decode_move("UB1"), "D over a tile becomes U at the lower cell")
	_check.call(c.call("LC1") == b.decode_move("RB1"), "L over a tile becomes R at the left cell")
	_check.call(c.call("RA2") == -1, "swap of equal values is ignored")
	_check.call(c.call("RA3") == -1, "move from an empty cell is ignored")
	_check.call(c.call("LA1") == -1, "move off the board is ignored")
	_check.call(c.call("UA3") == -1 and c.call("UB2") == -1, "up from the top row or into an empty cell is ignored")
	var s := _b5()
	var d := func(t: String) -> int: return s.canonical(s.start, s.decode_move(t))
	_check.call(d.call("LC2") == s.decode_move("LC2"), "L into an empty cell stays a slide")
	_check.call(d.call("UD1") == -1, "U into an empty cell is ignored")
	_check.call(d.call("DC2") == s.decode_move("UC1"), "D swap is spelled as U from the lower cell")
	_check.call(s.apply(s.start, s.decode_move("RC3")) == null, "apply returns null for an ignored action")
	var before: PackedByteArray = s.start.duplicate()
	s.apply(s.start, s.decode_move("RB1"))
	_check.call(s.start == before, "apply does not modify its argument")
	_check.call(s.apply(s.start, s.decode_move("DB1")) == null, "D at the floor is ignored")
	var ok := true
	for m in s.legal_moves(s.start):
		if s.canonical(s.start, m) != m:
			ok = false
	_check.call(ok, "legal moves are canonical")


func _random_agreement() -> void:
	var rng := WhiteRng.new(12345)
	var b := TallyBoard.create(6, 7)
	var bad := 0
	var n := 0
	for k in 10000:
		var s := random_state(b, rng, 6, 30)
		var moves := b.legal_moves(s)
		if moves.is_empty():
			continue
		var m := moves[rng.range_int(0, moves.size() - 1)]
		var f := b.step(s, m)
		n += 1
		if not b.is_stable(f) or f != b.step_reference(s, m) or b.step_traced(s, m).state != f:
			bad += 1
	_check.call(n >= 9000, "random pairs were tested")
	_check.call(bad == 0, "step is stable and equals step_reference and step_traced on random pairs")
	var w := TallyBoard.create(3, 5)
	bad = 0
	for k in 2000:
		var s := random_state(w, rng, 3, 14)
		for m in w.legal_moves(s):
			if w.step(s, m) != w.step_reference(s, m):
				bad += 1
	_check.call(bad == 0, "fast and reference agree on every move of narrow boards")


func _traced() -> void:
	var b := mk(["3..", "42.", "233"])
	var r := b.step_traced(b.start, b.decode_move("RA2"))
	var vanishes: Array = r.steps.filter(func(st: Dictionary) -> bool: return st.kind == "vanish")
	_check.call(vanishes.size() == 2, "example 3 yields exactly two vanish steps")
	_check.call(r.steps[0].kind == "swap", "traced steps start with the swap")
	var s := mk(["3.", "2.", "4."])
	var t := s.step_traced(s.start, s.decode_move("RA2"))
	_check.call(t.steps[0].kind == "slide" and t.steps[1].kind == "fall", "slide is followed by a fall")


func _invariants() -> void:
	var rng := WhiteRng.new(99)
	var b := TallyBoard.create(5, 6)
	var ok := true
	for _k in 500:
		var s := random_state(b, rng, 6, 24)
		var moves := b.legal_moves(s)
		if moves.is_empty():
			continue
		var f := b.step(s, moves[rng.range_int(0, moves.size() - 1)])
		for v in [2, 3, 4]:
			if _count(s, v) % v != _count(f, v) % v:
				ok = false
		if b.count_tiles(f) > b.count_tiles(s):
			ok = false
	_check.call(ok, "per value the count modulo the value is invariant and tiles never appear")
	var a := PackedByteArray([2, 3, 0])
	var c := PackedByteArray([2, 3, 0])
	var d := {a: 1}
	_check.call(d.has(c), "equal packed arrays hit the same dictionary key")
	var bd := mk(["....", "..2.", "3233"])
	_check.call(TallyBoard.from_dict(bd.to_dict(bd.start)).start == bd.start, "from_dict(to_dict) round-trips")
	_check.call(bd.to_dict(bd.start).rows == ["....", "..2.", "3233"], "to_dict gives top-first rows")


func _count(s: PackedByteArray, v: int) -> int:
	var n := 0
	for x in s:
		if x == v:
			n += 1
	return n


func _notation() -> void:
	var b := TallyBoard.create(8, 9)
	var rx := RegEx.create_from_string("^[RLUD][A-H][1-9]$")
	var ok := true
	for m in 8 * 9 * 4:
		var t := b.encode_move(m)
		if rx.search(t) == null or b.decode_move(t) != m:
			ok = false
	_check.call(ok, "encode and decode round-trip every code on 8x9 with valid tokens")
	for t in ["rb1", "XB1", "RJ1", "RB0", "RB", "RB10"]:
		_check.call(b.decode_move(t) == null, "decode_move rejects " + t)
	var s := TallyBoard.create(4, 3)
	_check.call(s.decode_move("RE1") == null and s.decode_move("RA4") == null, "decode_move rejects cells off the board")
	_check.call(b.move_len() == 3, "tokens have three characters")


func _attempt() -> void:
	var b := mk(["....", "..2.", "3233"])
	var a := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
	a.apply_record("RA1zRB1LD1")
	_check.call(a.solved() and a.count() == 2 and a.moves_made == 3, "record RA1zRB1LD1: solved, count 2 in final-only")
	var e := WhiteAttempt.new(b, WhiteAttempt.CountMode.EVERY_MOVE)
	e.apply_record("RA1zRB1LD1")
	_check.call(e.count() == 3, "record RA1zRB1LD1 counts 3 in every-move mode")
	_check.call(e.record == "RA1zRB1LD1", "record is replayed to the same text")
	var f := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
	_check.call(not f.play(b.decode_move("RC1")) and f.record == "", "ignored action is not counted or recorded")
	_check.call(not f.undo() and not f.restart(), "impossible undo and restart are ignored")
	f.play(b.decode_move("RB1"))
	f.play(b.decode_move("LD1"))
	_check.call(f.solved() and not f.play(b.decode_move("RA1")), "after solving every action is ignored")
	var g := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
	g.play(b.decode_move("RA1"))
	_check.call(g.count() == 1, "one move counts one")
	g.undo()
	_check.call(g.count() == 0 and g.moves_made == 1, "undo lowers the count, moves_made keeps everything")
	g.play(b.decode_move("RB1"))
	g.restart()
	_check.call(g.count() == 0 and g.state == b.start, "restart sets the count to 0")
	var h := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
	var k := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
	h.apply_record("DB2zRB1")
	k.apply_record("UB1zRB1")
	_check.call(h.state == k.state, "DB2 plays like UB1")
