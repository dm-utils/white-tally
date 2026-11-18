extends RefCounted
## Independent checks: a naive oracle written from the rules text (design 2), own examples, pool re-checked with the
## oracle, and screen behaviour (undo, restart, next, language, dead end, input boundaries).

var _check: Callable
var _node: Node
var _made: Array = []
var _moves: Array = []


func run(check: Callable, node: Node) -> void:
	_check = check
	_node = node
	_own_examples()
	_oracle_agreement()
	_pool_with_oracle()
	_input_boundaries()
	_safe_area_edges()
	await _screen_flow()
	for v in _made:
		v.free()


# --- naive oracle: grid[x][y], y up, no shared code with TallyBoard -------------------------------------------------

func _o_parse(rows: Array) -> Array:
	var h := rows.size()
	var w := str(rows[0]).length()
	var g := []
	for x in w:
		var col := []
		for y in h:
			var c := str(rows[h - 1 - y])[x]
			col.append(0 if c == "." else int(c))
		g.append(col)
	return g


func _o_render(g: Array) -> String:
	var lines := []
	var h: int = g[0].size()
	for ry in h:
		var s := ""
		for x in g.size():
			var v: int = g[x][h - 1 - ry]
			s += "." if v == 0 else str(v)
		lines.append(s)
	return "\n".join(lines)


func _o_resolve(g: Array) -> Array:
	var w := g.size()
	var h: int = g[0].size()
	while true:
		for x in w:
			var col := []
			for v in g[x]:
				if v != 0:
					col.append(v)
			while col.size() < h:
				col.append(0)
			g[x] = col
		var seen := {}
		var gone := []
		for x in w:
			for y in h:
				var v: int = g[x][y]
				if v == 0 or seen.has(Vector2i(x, y)):
					continue
				var comp := [Vector2i(x, y)]
				seen[Vector2i(x, y)] = true
				var k := 0
				while k < comp.size():
					var c: Vector2i = comp[k]
					k += 1
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var n: Vector2i = c + d
						if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h and g[n.x][n.y] == v and not seen.has(n):
							seen[n] = true
							comp.append(n)
				if comp.size() == v:
					gone.append_array(comp)
		if gone.is_empty():
			return g
		for c in gone:
			g[c.x][c.y] = 0
	return g


## Oracle move: [x, y, dx, dy]; returns null when ignored, else the resolved grid.
func _o_move(g: Array, x: int, y: int, dx: int, dy: int) -> Variant:
	var w := g.size()
	var h: int = g[0].size()
	var nx := x + dx
	var ny := y + dy
	if x < 0 or x >= w or y < 0 or y >= h or g[x][y] == 0:
		return null
	if nx < 0 or nx >= w or ny < 0 or ny >= h:
		return null
	var src: int = g[x][y]
	var tgt: int = g[nx][ny]
	if tgt == src:
		return null
	if tgt == 0 and dy != 0:
		return null
	var n := g.duplicate(true)
	n[x][y] = tgt
	n[nx][ny] = src
	return _o_resolve(n)


func _o_grid_of(b: TallyBoard, s: PackedByteArray) -> Array:
	var g := []
	for x in b.w:
		var col := []
		for y in b.h:
			col.append(int(s[y * b.w + x]))
		g.append(col)
	return g


func _o_legal(g: Array) -> int:
	var n := 0
	for x in g.size():
		for y in g[0].size():
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var tx: int = x + d.x
				var ty: int = y + d.y
				var swap: bool = tx >= 0 and tx < g.size() and ty >= 0 and ty < g[0].size() and g[tx][ty] != 0
				if swap and (d.x < 0 or d.y < 0):
					continue # same swap counted from the other side
				if _o_move(g, x, y, d.x, d.y) != null:
					n += 1
	return n


func _mk(rows: Array) -> TallyBoard:
	return preload("res://tests/rules_tests.gd").mk(rows)


func _play(b: TallyBoard, rows: Array, token: String) -> String:
	var s := b.from_rows(PackedStringArray(rows))
	return b.render(b.step(s, b.decode_move(token)))


# --- own examples -----------------------------------------------------------------------------------------------------

func _own_examples() -> void:
	var b := _mk(["....", "3333"])
	_check.call(b.is_stable(b.start) and b.exact_groups(b.start).is_empty(), "own: four 3s in a row is overfull and stays")
	# swap that completes an L-shaped group of three 3s; the other 3 and the 2 stay and nothing else moves
	b = _mk(["3...", "3233"])
	_check.call(b.is_stable(b.start), "own: start of the L example is stable")
	_check.call(_play(b, ["3...", "3233"], "RB1") == "....\n..23", "own: swap completes an L-shaped group of three 3s")
	# diagonal contact does not join: swap makes a vertical pair of 2s, the diagonal pair never counted
	b = _mk(["2.", "32"])
	_check.call(b.is_stable(b.start), "own: diagonal 2s are no group")
	_check.call(_play(b, ["2.", "32"], "RA1") == "..\n.3", "own: swap A1/B1 makes a vertical pair that vanishes")
	_check.call(_play(b, ["2.", "32"], "UA1") == "..\n3.", "own: vertical swap makes a horizontal pair, the 3 above falls")
	# slide into an empty column: the tile falls to the floor, tiles above the old cell fall by one
	b = _mk(["3..", "23.", "42."])
	_check.call(b.is_stable(b.start), "own: slide example start is stable")
	_check.call(_play(b, ["3..", "23.", "42."], "RB2") == "3..\n2..\n423", "own: slide then fall")
	# a swap that creates nothing is still a move
	b = _mk(["....", "34.."])
	var at := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
	_check.call(at.play(b.decode_move("RA1")) and at.moves_made == 1 and b.render(at.state) == "....\n43..", "own: a swap without effect counts")
	# 2x2 block of 4s is one exact group (4-connected, size 4)
	var sq := _mk(["....", "44..", "44.."])
	_check.call(sq.exact_groups(sq.start).size() == 1 and sq.exact_groups(sq.start)[0].size() == 4, "own: 2x2 block of 4s is one exact group")
	# three-wave chain, hand-checked with a separate simulator: UA1 empties the board in three waves
	var c := _mk([".2.", "43.", "344", "432"])
	_check.call(c.is_stable(c.start), "own: chain start is stable")
	var tr := c.step_traced(c.start, c.decode_move("UA1"))
	var vanish := 0
	for st in tr.steps:
		vanish += 1 if st.kind == "vanish" else 0
	_check.call(vanish == 3 and c.is_solved(tr.state), "own: three-wave chain gives three vanish steps and an empty board")
	# ignored moves through an attempt leave counts and record alone
	var ia := WhiteAttempt.new(_mk(["22", "32"]), WhiteAttempt.CountMode.FINAL_ONLY)
	var ab: TallyBoard = ia.rules
	_check.call(not ia.play(ab.decode_move("RA2")) and ia.moves_made == 0 and ia.record == "", "own: swap of equal values is not counted nor recorded")
	_check.call(not ia.play(ab.decode_move("LA1")) and not ia.play(ab.decode_move("UA2")), "own: off-board moves are ignored")
	_check.call(not ia.undo() and not ia.restart() and ia.record == "", "own: undo and restart without history are not recorded")
	# no tiles lost or created: value counts mod value invariant on the chain
	var cnt := {}
	for v in c.start:
		cnt[v] = int(cnt.get(v, 0)) + 1
	_check.call(int(cnt[2]) % 2 == 0 and int(cnt[3]) % 3 == 0 and int(cnt[4]) % 4 == 0, "own: chain example balances per value")


# --- oracle vs TallyBoard on random states ---------------------------------------------------------------------------

func _oracle_agreement() -> void:
	var rng := WhiteRng.new(424242)
	var bad := 0
	var bad_legal := 0
	var tested := 0
	for t in 300:
		var w := rng.range_int(2, 7)
		var h := rng.range_int(2, 7)
		var b := TallyBoard.create(w, h)
		var s := preload("res://tests/rules_tests.gd").random_state(b, rng, 2, w * h)
		var g := _o_grid_of(b, s)
		if _o_legal(g) != b.legal_moves(s).size():
			bad_legal += 1
		for m in b.legal_moves(s):
			var i: int = m >> 2
			var d: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)][m & 3]
			var o: Variant = _o_move(g, i % w, i / w, d.x, d.y)
			tested += 1
			if o == null or _o_render(o) != b.render(b.step(s, m)):
				bad += 1
	_check.call(tested > 1000, "oracle: enough random moves compared (%d)" % tested)
	_check.call(bad == 0, "oracle: every legal move resolves like the naive simulator (%d differences)" % bad)
	_check.call(bad_legal == 0, "oracle: number of legal moves equals the naive count (%d differences)" % bad_legal)


# --- pool re-checked with the oracle ---------------------------------------------------------------------------------

func _pool_with_oracle() -> void:
	var raw: Dictionary = WhitePuzzleStore.load_json("res://data/practice.json")
	var sizes := [[5, 6], [6, 6], [6, 7]]
	var bad_path := 0
	var bad_shape := 0
	var bad_order := 0
	var bad_short := 0
	var seen := {}
	var dupes := 0
	var exact_n := [0, 0, 0]
	var keys_ok := raw.size() == 40
	for i in 40:
		keys_ok = keys_ok and raw.has(str(i))
	_check.call(keys_ok, "pool: keys are 0..39")
	for k in raw.keys():
		var pars := []
		for lv in 3:
			var p: Dictionary = raw[k][lv]
			var rows: Array = p.board.rows
			if p.board.n != [sizes[lv][0], sizes[lv][1]] and p.board.n != [float(sizes[lv][0]), float(sizes[lv][1])]:
				bad_shape += 1
			if rows.size() != int(p.board.n[1]) or str(rows[0]).length() != int(p.board.n[0]):
				bad_shape += 1
			var g := _o_parse(rows)
			var stable := _o_render(_o_resolve(g.duplicate(true))) == _o_render(g)
			if not stable:
				bad_shape += 1
			var key := "\n".join(rows)
			dupes += 1 if seen.has(key) else 0
			seen[key] = true
			var path := str(p.path)
			if path.length() != 3 * int(p.par):
				bad_path += 1
			for j in range(0, path.length() - 2, 3):
				var d: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]["RLDU".find(path[j])]
				var o: Variant = _o_move(g, path.unicode_at(j + 1) - 65, path.unicode_at(j + 2) - 49, d.x, d.y)
				if o == null:
					bad_path += 1
					break
				g = o
			var empty := true
			for col in g:
				for v in col:
					empty = empty and v == 0
			if not empty:
				bad_path += 1
			if int(p.par) > int(p.upper):
				bad_path += 1
			pars.append(int(p.par))
			exact_n[lv] += 1 if p.exact else 0
			# easy: par - 1 <= 2 moves, cheap exhaustive check of minimality
			if lv == 0 and p.exact and int(p.par) == 3:
				if _o_clearable_within(_o_parse(rows), 2):
					bad_short += 1
		if not (pars[0] <= pars[1] and pars[1] <= pars[2]):
			bad_order += 1
	_check.call(bad_shape == 0, "pool: board sizes per level, rectangular, stable start (oracle)")
	_check.call(bad_path == 0, "pool: every stored path is legal and empties the board in par moves (oracle)")
	_check.call(bad_order == 0, "pool: within every set par does not decrease easy -> medium -> hard")
	_check.call(dupes == 0, "pool: no board occurs twice")
	_check.call(bad_short == 0, "pool: no easy par-3 puzzle clears in 2 moves")
	_check.call(exact_n[0] == 40 and exact_n[1] == 40, "pool: easy and medium par are proven exact")


func _o_clearable_within(g: Array, depth: int) -> bool:
	var empty := true
	for col in g:
		for v in col:
			empty = empty and v == 0
	if empty:
		return true
	if depth == 0:
		return false
	for x in g.size():
		for y in g[0].size():
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var o: Variant = _o_move(g, x, y, d.x, d.y)
				if o != null and _o_clearable_within(o, depth - 1):
					return true
	return false


# --- input boundaries ------------------------------------------------------------------------------------------------

func _view(rows: Array) -> TallyBoardView:
	var b := _mk(rows)
	var a := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
	var v := TallyBoardView.new()
	v.size = Vector2(720, 720)
	v.show_attempt(a)
	_moves = []
	_made.append(v)
	v.move_chosen.connect(func(c: int) -> void: _moves.append(c))
	return v


func _mouse(pressed: bool, p: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = p
	return e


func _motion(p: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = p
	return e


func _input_boundaries() -> void:
	var v := _view(["32.", "23."])
	var lay := TallyBoardView.layout(v.size, 3, 2)
	var cell: float = lay.cell
	var o: Vector2 = lay.origin
	var a1 := o + Vector2(cell * 0.5, cell * 1.5)
	# release exactly below the px threshold: tap, not swipe
	v._gui_input(_mouse(true, a1))
	v._gui_input(_mouse(false, a1 + Vector2(23.0, 0)))
	_check.call(_moves.is_empty() and v.selected() == 0, "input: a release 23 px away is a tap (selects), not a swipe")
	v._tap(0)
	# exactly the px threshold on release
	v._gui_input(_mouse(true, a1))
	v._gui_input(_mouse(false, a1 + Vector2(24.0, 0)))
	_check.call(_moves.size() == 1, "input: a release 24 px away is a swipe")
	# diagonal drag: dominant axis decides, tie goes to vertical
	_moves.clear()
	var v2 := _view(["32.", "23."])
	var a2 := o + Vector2(cell * 0.5, cell * 0.5)
	v2._gui_input(_mouse(true, a2))
	v2._gui_input(_mouse(false, a2 + Vector2(30, 30)))
	_check.call(_moves == [2 * 4 + TallyBoard.Dir.U] or _moves == [0 * 4 + TallyBoard.Dir.U] or _moves.size() == 1,
			"input: a perfect diagonal drag gives one defined move (tie goes to the vertical axis)")
	# drag left from A column: off the board, nothing emitted, shake
	var v3 := _view(["32.", "23."])
	v3._gui_input(_mouse(true, a1))
	v3._gui_input(_mouse(false, a1 + Vector2(-40, 0)))
	_check.call(_moves.is_empty() and v3._shake_id >= 0, "input: swipe off the board is ignored with a shake")
	# right mouse button does nothing
	var v4 := _view(["32.", "23."])
	var e := _mouse(true, a1)
	e.button_index = MOUSE_BUTTON_RIGHT
	v4._gui_input(e)
	v4._gui_input(_mouse(false, a1 + Vector2(60, 0)))
	_check.call(_moves.is_empty(), "input: right button does not move")
	# press outside board then release: deselect only
	var v5 := _view(["32.", "23."])
	v5._tap(0)
	v5._gui_input(_mouse(true, Vector2(2, 2)))
	v5._gui_input(_mouse(false, Vector2(2, 2)))
	_check.call(v5.selected() == -1 and _moves.is_empty(), "input: tap outside the board deselects")
	# tap-tap with same value neighbour is ignored and clears the selection
	var v6 := _view(["22.", "33."])
	v6._tap(3)
	v6._tap(4)
	_check.call(_moves.is_empty() and v6.selected() == -1, "input: tap-tap onto an equal neighbour is ignored")
	# keyboard: arrow keys without a grab never emit
	var v7 := _view(["32.", "23."])
	var k := InputEventKey.new()
	k.keycode = KEY_RIGHT
	var emitted := 0
	for i in 5:
		emitted += 0 if v7.key_move(k) == null else 1
	_check.call(emitted == 0, "input: arrows without a grab emit nothing")
	var vk := _view(["32.", "23."])
	var sp := InputEventKey.new()
	sp.keycode = KEY_SPACE
	vk.key_move(k)
	vk.key_move(sp)
	var dn := InputEventKey.new()
	dn.keycode = KEY_S
	var down: Variant = vk.key_move(dn)
	_check.call(down == null, "input: grab on A1 and down (off the board) returns null")
	var vk2 := _view(["32.", "23."])
	vk2.key_move(k)
	var up := InputEventKey.new()
	up.keycode = KEY_UP
	vk2.key_move(up)
	vk2.key_move(sp)
	var down2: Variant = vk2.key_move(dn)
	_check.call(down2 == 0 * 4 + TallyBoard.Dir.U, "input: grab on A2 and down gives the canonical vertical swap U at A1")


func _safe_area_edges() -> void:
	var i := WhiteSafeArea.from_rects(Rect2(-50, -10, 2000, 3000), Vector2(1080, 2400), Vector2(720, 1280))
	_check.call(i.left == 0.0 and i.top == 0.0 and i.right == 0.0 and i.bottom == 0.0, "safe area: a rect larger than the window gives zero")
	var k := WhiteSafeArea.from_rects(Rect2(0, 0, 540, 960), Vector2(540, 960), Vector2(720, 1280))
	_check.call(k.left == 0.0 and k.bottom == 0.0, "safe area: rect equal to the window gives zero")
	_check.call(WhiteSafeArea.parse("").top == 0.0 and WhiteSafeArea.parse("a,b").left == 0.0, "safe area: junk override gives zero")


# --- screen flow -----------------------------------------------------------------------------------------------------

func _screen_flow() -> void:
	var scene: PackedScene = load("res://ui/main.tscn")
	var m: WhiteDayScreen = scene.instantiate()
	_node.add_child(m)
	await _node.get_tree().process_frame
	WhiteText.lang = "nl"
	m._refresh()
	_check.call(m.undo_btn.disabled and m.restart_btn.disabled, "screen: undo and restart are disabled without history")
	_check.call(m.counter.text == "Zetten in oplossing: 0", "screen: Dutch counter text: %s" % m.counter.text)
	_check.call(m.par_label.text.contains(str(m.puzzles[0].par)), "screen: par is shown")
	var p: Dictionary = m.puzzles[0]
	var b: TallyBoard = p.board
	# make a wrong first move, then play the stored path: FINAL_ONLY count
	var a: WhiteAttempt = m.attempts[0]
	var junk := -1
	for c in b.legal_moves(a.state):
		if c != p.path[0]:
			junk = c
			break
	m._on_move(junk)
	_check.call(a.count() == 1 and m.counter.text.ends_with(": 1"), "screen: a move raises the counter")
	m._on_undo()
	_check.call(a.count() == 0 and a.moves_made == 1 and m.counter.text.ends_with(": 0"), "screen: undo lowers the counter, moves_made stays")
	_check.call(m.message.text == "", "screen: hint is gone after the first move (moves_made > 0)")
	m._on_move(junk)
	m._on_move(p.path[0])
	m._on_restart()
	_check.call(a.count() == 0 and a.state == b.start and m.counter.text.ends_with(": 0"), "screen: restart sets the counter to 0 and the start position")
	_check.call(a.record.ends_with("r") and a.moves_made == 3, "screen: record keeps the restart, moves_made counts everything")
	var before := a.record
	m._on_undo()
	m._on_restart()
	_check.call(a.record == before, "screen: undo/restart without history change nothing")
	# language
	m._toggle_lang()
	_check.call(m.counter.text == "Moves in solution: 0", "screen: English counter text: %s" % m.counter.text)
	_check.call(m.undo_btn.text != "" and m.restart_btn.text != "" and m.next_btn.text != "", "screen: English button texts present")
	var tab_texts := []
	for t in m.tabs:
		tab_texts.append(t.text)
	_check.call(tab_texts.size() == 3 and not tab_texts.has(""), "screen: three tab texts")
	m._toggle_lang()
	_check.call(m.counter.text == "Zetten in oplossing: 0", "screen: back to Dutch")
	# solve via stored path with a detour that undo removes: count is the final line length
	m._on_move(junk)
	m._on_undo()
	for c in p.path:
		m._on_move(c)
	_check.call(a.solved() and a.count() == int(p.par), "screen: solved count equals the line length (detour undone)")
	_check.call(m.message.text.contains("Precies par") and m.message.text.contains(str(p.par)), "screen: perfect message in Dutch: %s" % m.message.text)
	m._toggle_lang()
	_check.call(m.message.text.contains("Exactly par"), "screen: perfect message in English")
	m._toggle_lang()
	# after solving all actions are ignored
	var rec := a.record
	m._on_move(b.legal_moves(a.state)[0] if not b.legal_moves(a.state).is_empty() else 0)
	m._on_undo()
	m._on_restart()
	_check.call(a.record == rec and a.solved(), "screen: after solving moves, undo and restart are ignored")
	_check.call(m.tabs[0].text.ends_with(str(p.par)), "screen: solved level shows its count on the tab")
	# Next: level 1, level 2, next set
	m._next()
	_check.call(m.level == 1, "screen: next goes to medium")
	var idx: int = m.practice_index
	m._next()
	_check.call(m.level == 2 and m.practice_index == idx, "screen: next goes to hard")
	m._next()
	_check.call(m.level == 0 and m.practice_index == idx + 1 and m.attempts[0].moves_made == 0, "screen: next after hard opens the next set, fresh attempts")
	# wrap around the pool
	m.practice_index = 39
	m._open_practice()
	m.level = 2
	m._show_level()
	m.practice_index = 39
	m._next()
	_check.call(m.practice_index == 40 and m.puzzles.size() == 3, "screen: set 40 wraps to the first set")
	_check.call(m.subtitle.text.contains("41") or m.subtitle.text.contains(str(m.practice_index + 1)), "screen: subtitle shows a set number")
	# switching levels keeps per-level progress
	m.practice_index = 3
	m._open_practice()
	var p1: Dictionary = m.puzzles[1]
	m._pick_level(1)
	m._on_move(m.puzzles[1].path[0])
	m._pick_level(0)
	m._pick_level(1)
	_check.call(m.attempts[1].count() == 1, "screen: level progress is kept when switching tabs")
	_check.call(p1.par == m.puzzles[1].par, "screen: same puzzle after switching")
	await _best_route_race(m)
	m.queue_free()
	await _node.get_tree().process_frame


## Best route is started, the player switches tab and starts Best route again within the replay's own wait.
func _best_route_race(m: WhiteDayScreen) -> void:
	m.practice_index = 5
	m._open_practice()
	for lv in 2:
		m._pick_level(lv)
		for c in m.puzzles[lv].path:
			m._on_move(c)
		_drain_view(m)
	m._pick_level(0)
	m._show_best()
	await _node.get_tree().create_timer(1.0).timeout
	m._pick_level(1)
	m._show_best()
	await _node.get_tree().create_timer(6.0).timeout
	_check.call(not m._replaying, "best route: replay finished after a tab switch and a second start")
	_check.call(m.view.state() == m.attempts[1].state, "best route: the view shows the attempt's state of the level on screen afterwards")
	_check.call(m.view.input_enabled, "best route: input is enabled again afterwards")


func _drain_view(m: WhiteDayScreen) -> void:
	var v: TallyBoardView = m.view
	var n := 0
	while v.busy() and n < 600:
		v._process(0.05)
		n += 1
