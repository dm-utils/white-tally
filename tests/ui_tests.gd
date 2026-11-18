extends RefCounted
## UI logic that needs no screen: layout, gestures, keys, animation phases, the view's state handling, texts and the
## main screen in practice mode (design 10, 13.1 UI).

const VANISH_TOTAL := 0.18 + 0.06 ## kit vanish_time + vanish_pause

var _check: Callable
var _node: Node
var _moves: Array = []
var _made: Array = []


func run(check: Callable, node: Node) -> void:
	_check = check
	_node = node
	_layout()
	_gestures()
	_phases()
	_view_steps()
	_view_moves()
	_view_ignored()
	_tap_tap()
	_keyboard()
	_pointer()
	_texts()
	_safe_area()
	await _screen()
	for v in _made:
		v.free()


func _mk(rows: Array) -> TallyBoard:
	return preload("res://tests/rules_tests.gd").mk(rows)


func _view(rows: Array) -> Array:
	var b := _mk(rows)
	var a := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
	var v := TallyBoardView.new()
	v.size = Vector2(720, 720)
	v.show_attempt(a)
	_moves = []
	_made.append(v)
	v.move_chosen.connect(func(c: int) -> void: _moves.append(c))
	return [v, a, b]


func _drain(v: TallyBoardView) -> int:
	var frames := 0
	while v.busy() and frames < 400:
		v._process(0.05)
		frames += 1
	return frames


func _layout() -> void:
	var lay := WhiteTileView.layout(Vector2(660, 800), 6, 7, 0.3)
	var cell: float = lay.cell
	var o: Vector2 = lay.origin
	_check.call(cell == floorf(cell) and cell * 6 <= 660 and cell * 7 <= 800, "layout: whole-pixel cells that fit the area")
	_check.call(is_equal_approx(o.x, (660 - 6 * cell) / 2.0) and is_equal_approx(o.y, (800 - 7 * cell) / 2.0),
			"layout: board centred")
	var a1 := TallyBoardView.cell_at(o + Vector2(cell * 0.5, cell * 6.5), lay, 6, 7)
	var top_right := TallyBoardView.cell_at(o + Vector2(cell * 5.5, cell * 0.5), lay, 6, 7)
	_check.call(a1 == 0, "cell_at: bottom-left on screen is A1 (index 0)")
	_check.call(top_right == 6 * 7 - 1, "cell_at: top-right on screen is the last cell (y counts upwards)")
	_check.call(TallyBoardView.cell_at(o - Vector2(1, 1), lay, 6, 7) == -1, "cell_at: outside the board is -1")
	_check.call(TallyBoardView.cell_at(o + Vector2(cell * 6.0 + 1, 5), lay, 6, 7) == -1, "cell_at: right of the board is -1")
	var tall := WhiteTileView.layout(Vector2(300, 1000), 5, 6, 0.3)
	_check.call(tall.cell * 5 <= 300, "layout: the narrow side decides")


func _gestures() -> void:
	_check.call(TallyBoardView.drag_dir(Vector2(30, 5)) == TallyBoard.Dir.R, "drag right is R")
	_check.call(TallyBoardView.drag_dir(Vector2(-30, 5)) == TallyBoard.Dir.L, "drag left is L")
	_check.call(TallyBoardView.drag_dir(Vector2(5, 30)) == TallyBoard.Dir.D, "drag down on screen is D")
	_check.call(TallyBoardView.drag_dir(Vector2(5, -30)) == TallyBoard.Dir.U, "drag up on screen is U")
	_check.call(TallyBoardView.neighbour_dir(5, 6, 4) == TallyBoard.Dir.R, "neighbour to the right")
	_check.call(TallyBoardView.neighbour_dir(5, 4, 4) == TallyBoard.Dir.L, "neighbour to the left")
	_check.call(TallyBoardView.neighbour_dir(5, 9, 4) == TallyBoard.Dir.U, "neighbour above (index + w)")
	_check.call(TallyBoardView.neighbour_dir(5, 1, 4) == TallyBoard.Dir.D, "neighbour below (index - w)")
	_check.call(TallyBoardView.neighbour_dir(5, 10, 4) == -1, "diagonal is no neighbour")
	_check.call(TallyBoardView.neighbour_dir(3, 4, 4) == -1, "end of row and start of next row are no neighbours")
	_check.call(TallyBoardView.key_dir(KEY_W) == TallyBoard.Dir.U and TallyBoardView.key_dir(KEY_DOWN) == TallyBoard.Dir.D,
			"keys: WASD and arrows")
	_check.call(TallyBoardView.key_dir(KEY_Q) == -1, "keys: others are no direction")
	_check.call(TallyBoardView.step_cell(0, TallyBoard.Dir.L, 4, 3) == 0 and TallyBoardView.step_cell(0, TallyBoard.Dir.D, 4, 3) == 0,
			"cursor stops at the edge")
	_check.call(TallyBoardView.step_cell(3, TallyBoard.Dir.R, 4, 3) == 3 and TallyBoardView.step_cell(11, TallyBoard.Dir.U, 4, 3) == 11,
			"cursor stops at the far edges")
	_check.call(TallyBoardView.step_cell(5, TallyBoard.Dir.U, 4, 3) == 9, "cursor up adds a row")


func _kinds(phases: Array) -> Array:
	var out := []
	for p in phases:
		out.append(p.kind)
	return out


func _phases() -> void:
	var b := _mk(["3..", "42.", "233"])
	var ids := PackedInt32Array()
	ids.resize(9)
	for i in 9:
		ids[i] = i if b.start[i] != 0 else -1
	var tr := b.step_traced(b.start, b.decode_move("RA2"))
	var built := WhiteTileView.build_phases(3, ids, TallyBoardView.to_steps(tr.steps), VANISH_TOTAL)
	_check.call(_kinds(built.phases) == ["move", "vanish", "move", "vanish", "move"],
			"chain (example 3): swap, then each wave as vanish and fall, one after another")
	var ok := true
	for i in 9:
		var id: int = built.ids[i]
		ok = ok and ((id >= 0) == (tr.state[i] != 0))
		ok = ok and (id < 0 or b.start[id] == tr.state[i])
	_check.call(ok, "phase ids end on the cells and values of the resolved state")
	var fall: Dictionary = built.phases[2]
	_check.call(is_equal_approx(fall.dur, 2.0 / TallyBoardView.FALL_SPEED), "fall of two cells lasts two cells at constant speed")
	_check.call(built.phases[0].dur == TallyBoardView.SWAP_TIME, "swap lasts 120 ms")
	_check.call(is_equal_approx(built.phases[1].dur, VANISH_TOTAL),
			"vanish is a fade plus a short pause")
	var bs := _mk(["2..", "3.."])
	var ids2 := PackedInt32Array([0, -1, -1, 3, -1, -1])
	ids2[0] = 0
	var built2 := WhiteTileView.build_phases(3, ids2, TallyBoardView.to_steps(bs.step_traced(bs.start, bs.decode_move("RA2")).steps), VANISH_TOTAL)
	_check.call(_kinds(built2.phases) == ["move", "move"], "slide into an empty cell: slide phase, then the fall")
	_check.call(built2.ids[1] == 3 and built2.ids[3] == -1, "the slid tile keeps its id and lands one row lower")


func _view_steps() -> void:
	var b := _mk(["2..", "3.."])
	var steps := TallyBoardView.to_steps(b.step_traced(b.start, b.decode_move("RA2")).steps)
	_check.call(steps.size() == 2 and steps[0].kind == "move" and steps[0].time == TallyBoardView.SLIDE_TIME and steps[0].ease,
			"to_steps: a slide is an eased move of 100 ms")
	_check.call(steps[1].kind == "move" and steps[1].speed == TallyBoardView.FALL_SPEED and not steps[1].has("ease"),
			"to_steps: a fall moves at constant speed")


func _view_moves() -> void:
	var r := _view(["3..", "42.", "233"])
	var v: TallyBoardView = r[0]
	var a: WhiteAttempt = r[1]
	var b: TallyBoard = r[2]
	var done := [0]
	v.finished.connect(func() -> void: done[0] += 1)
	a.play(b.decode_move("RA2"))
	v.update_attempt(a)
	_check.call(v.busy(), "a move starts an animation")
	_check.call(v.state() == a.state, "the view's logical state is the attempt's state at once")
	_check.call(_drain(v) > 3, "the chain takes several frames")
	_check.call(not v.busy() and done[0] == 1, "the animation ends once and signals it")
	# undo and restart show the state at once
	a.undo()
	v.update_attempt(a)
	_check.call(not v.busy() and v.state() == a.state and v.state() == b.start, "undo shows the start at once")
	a.play(b.decode_move("RA2"))
	v.update_attempt(a)
	a.restart()
	v.update_attempt(a)
	_check.call(not v.busy() and v.state() == b.start, "restart during an animation shows the start at once")
	# a move during an animation jumps the running one to its end
	var r2 := _view(["4...", "3433", "2423"])
	var v2: TallyBoardView = r2[0]
	var a2: WhiteAttempt = r2[1]
	var b2: TallyBoard = r2[2]
	var c1 := b2.legal_moves(a2.state)[0]
	a2.play(c1)
	v2.update_attempt(a2)
	var c2 := b2.legal_moves(a2.state)
	if not c2.is_empty():
		a2.play(c2[0])
		v2.update_attempt(a2)
	_drain(v2)
	_check.call(v2.state() == a2.state, "two moves in a row end on the attempt's state")


func _view_ignored() -> void:
	var r := _view(["22", "32"])
	var v: TallyBoardView = r[0]
	_check.call(v._cell_move(2, TallyBoard.Dir.R) == -1, "swap of equal values is ignored")
	_check.call(v._shake_id >= 0, "an ignored move shakes the source tile")
	_check.call(v._cell_move(1, TallyBoard.Dir.R) == -1, "move off the board is ignored")
	_check.call(v._cell_move(0, TallyBoard.Dir.U) == 0 * 4 + TallyBoard.Dir.U, "swap upwards from the lower cell stays as it is")
	_check.call(v._cell_move(2, TallyBoard.Dir.D) == 0 * 4 + TallyBoard.Dir.U, "swap downwards becomes U from the lower cell")
	var r2 := _view(["2.", "32"])
	var v2: TallyBoardView = r2[0]
	_check.call(v2._cell_move(3, TallyBoard.Dir.L) == -1 and v2._shake_id == -1, "move from an empty cell is ignored without a shake")
	_check.call(v2._cell_move(1, TallyBoard.Dir.U) == -1, "lifting a tile into an empty cell is ignored")
	_check.call(v2._cell_move(2, TallyBoard.Dir.R) == 2 * 4 + TallyBoard.Dir.R, "slide into an empty cell is a move")
	_check.call(_moves.is_empty(), "_cell_move itself emits nothing")


func _tap_tap() -> void:
	var r := _view(["3..", "42.", "233"])
	var v: TallyBoardView = r[0]
	var b: TallyBoard = r[2]
	v._tap(5) # empty cell C2? index 5 = y1 x2
	_check.call(v.selected() == -1, "tap on an empty cell selects nothing")
	v._tap(3) # A2 holds 4
	_check.call(v.selected() == 3, "tap on a tile selects it")
	v._tap(3)
	_check.call(v.selected() == -1, "tap on the selected tile deselects")
	v._tap(3)
	v._tap(0) # A1 holds 2, A2 is 4 above it: neighbour below
	_check.call(_moves == [b.canonical(b.start, 3 * 4 + TallyBoard.Dir.D)] and v.selected() == -1,
			"tap on a neighbour tile makes the swap and clears the selection")
	_moves.clear()
	v._tap(3)
	v._tap(4) # B2 holds 2, right of A2
	_check.call(_moves == [3 * 4 + TallyBoard.Dir.R], "tap on the right neighbour swaps right")
	_moves.clear()
	v._tap(3)
	v._tap(2) # C1 holds a tile, not a neighbour: selected instead
	_check.call(v.selected() == 2 and _moves.is_empty(), "tap on a far tile selects that one instead")
	v._tap(8) # C3 is empty and not a neighbour
	_check.call(v.selected() == -1, "tap on a far empty cell deselects")
	v._tap(3)
	v._tap(-1)
	_check.call(v.selected() == -1, "tap outside the board deselects")
	v._tap(4) # B2 holds 2
	v._tap(5) # C2 empty, right neighbour: slide
	_check.call(_moves == [4 * 4 + TallyBoard.Dir.R], "tap on an empty neighbour slides")
	_moves.clear()
	v._tap(3)
	v._tap(6) # A3 holds 3, above A2
	_check.call(_moves == [3 * 4 + TallyBoard.Dir.U], "tap on the tile above swaps up")


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _keyboard() -> void:
	var r := _view(["3..", "42.", "233"])
	var v: TallyBoardView = r[0]
	var a: WhiteAttempt = r[1]
	_check.call(v.key_move(_key(KEY_RIGHT)) == null, "first arrow only shows the cursor")
	_check.call(v._cursor == 0, "the cursor starts at A1")
	v.key_move(_key(KEY_RIGHT))
	v.key_move(_key(KEY_UP))
	_check.call(v._cursor == 4, "arrows move the cursor (B2)")
	_check.call(v.key_move(_key(KEY_SPACE)) == null and v.selected() == 4, "space grabs the tile under the cursor")
	_check.call(v.key_move(_key(KEY_ESCAPE)) == null and v.selected() == -1, "escape releases the grab")
	v.key_move(_key(KEY_ENTER))
	var code: Variant = v.key_move(_key(KEY_LEFT))
	_check.call(code == 3 * 4 + TallyBoard.Dir.R, "grab + left on B2 over A2 gives the canonical swap R at A2")
	_check.call(v.selected() == -1, "a move releases the grab")
	a.play(code)
	v.update_attempt(a)
	_check.call(v._cursor == 4, "the grabbed tile vanished: the cursor stays where it was")
	_drain(v)
	var r2 := _view(["2.", "2."])
	var v2: TallyBoardView = r2[0]
	v2.key_move(_key(KEY_UP))
	v2.key_move(_key(KEY_SPACE))
	_check.call(v2.key_move(_key(KEY_UP)) == null, "grab + move off the board is ignored")
	_check.call(v2._shake_id >= 0 and v2.selected() == 0, "an ignored key move shakes and keeps the grab")
	var r3 := _view(["2.", "3."])
	var v3: TallyBoardView = r3[0]
	v3.key_move(_key(KEY_UP))
	_check.call(v3.key_move(_key(KEY_SPACE)) == null, "grab on a tile")
	var up: Variant = v3.key_move(_key(KEY_UP))
	_check.call(up == 0 * 4 + TallyBoard.Dir.U, "grab + up swaps with the tile above")
	var a3: WhiteAttempt = r3[1]
	a3.play(up)
	v3.update_attempt(a3)
	_check.call(v3._cursor == 2, "after a swap the cursor follows the grabbed tile (now on A2)")


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


func _pointer() -> void:
	var r := _view(["3..", "42.", "233"])
	var v: TallyBoardView = r[0]
	var lay := WhiteTileView.layout(v.size, 3, 3, 0.3)
	var cell: float = lay.cell
	var o: Vector2 = lay.origin
	var a2 := o + Vector2(cell * 0.5, cell * 1.5) # A2 (row 2 from the bottom)
	v._gui_input(_mouse(true, a2))
	v._gui_input(_motion(a2 + Vector2(cell * 0.2, 0)))
	_check.call(_moves.is_empty(), "a short drag does not fire yet")
	v._gui_input(_motion(a2 + Vector2(cell * 0.45, 3)))
	_check.call(_moves == [3 * 4 + TallyBoard.Dir.R], "a drag of 40% of a cell fires the swipe (swap A2 right)")
	v._gui_input(_motion(a2 + Vector2(cell * 0.9, 0)))
	v._gui_input(_mouse(false, a2 + Vector2(cell * 0.9, 0)))
	_check.call(_moves.size() == 1, "one gesture fires only once")
	# release-only swipe of at least 24 px, from A1 upwards
	_moves.clear()
	var a1 := o + Vector2(cell * 0.5, cell * 2.5)
	v._gui_input(_mouse(true, a1))
	v._gui_input(_mouse(false, a1 + Vector2(0, -30)))
	_check.call(_moves == [0 * 4 + TallyBoard.Dir.U], "a swipe of 30 px on release counts (swap A1 up)")
	# tap
	_moves.clear()
	v._gui_input(_mouse(true, a2))
	v._gui_input(_mouse(false, a2 + Vector2(2, 2)))
	_check.call(v.selected() == 3, "a press and release on one tile is a tap and selects it")
	# press on an empty cell and swipe does nothing
	v._tap(3)
	_moves.clear()
	var empty := o + Vector2(cell * 2.5, cell * 0.5)
	v._gui_input(_mouse(true, empty))
	v._gui_input(_motion(empty + Vector2(-cell * 0.8, 0)))
	v._gui_input(_mouse(false, empty + Vector2(-cell * 0.8, 0)))
	_check.call(_moves.is_empty(), "a swipe starting on an empty cell does nothing")
	v.input_enabled = false
	v._gui_input(_mouse(true, a2))
	v._gui_input(_motion(a2 + Vector2(cell, 0)))
	_check.call(_moves.is_empty(), "no input while the view is locked")


func _texts() -> void:
	var nl: Dictionary = TallyStrings.TEXT.nl
	var en: Dictionary = TallyStrings.TEXT.en
	var same := nl.keys() == en.keys()
	_check.call(same, "Dutch and English define the same keys")
	for key in ["count", "count_final", "solved", "perfect", "hint", "dead_end", "best_route", "share_line"]:
		same = same and nl.has(key)
	_check.call(same, "all keys of design 10.6 are present")
	var fmt_ok := true
	for lang in ["nl", "en"]:
		var t: Dictionary = TallyStrings.TEXT[lang]
		fmt_ok = fmt_ok and str(t.count_final) % 3 != "" and str(t.solved) % [3, 2, "0:10"] != ""
	_check.call(fmt_ok, "format texts take their arguments")


func _safe_area() -> void:
	var i := WhiteSafeArea.from_rects(Rect2(0, 80, 1080, 2200), Vector2(1080, 2400), Vector2(720, 1280))
	_check.call(is_equal_approx(i.top, 80.0 * 1280.0 / 2400.0), "safe area: top inset in viewport units")
	_check.call(is_equal_approx(i.bottom, 120.0 * 1280.0 / 2400.0) and i.left == 0.0, "safe area: bottom inset, no side inset")
	_check.call(WhiteSafeArea.from_rects(Rect2(), Vector2(540, 960), Vector2(720, 1280)).top == 0.0, "safe area: no rect gives zero insets")
	_check.call(WhiteSafeArea.parse("40,20,30,10").right == 30.0 and WhiteSafeArea.parse("5").bottom == 0.0, "safe area: debug override")


func _screen() -> void:
	var scene: PackedScene = load("res://ui/main.tscn")
	var m: WhiteDayScreen = scene.instantiate()
	_node.add_child(m)
	await _node.get_tree().process_frame
	_check.call(m.practice and not m.mode_btn.visible, "the screen opens on a practice set without a mode button")
	_check.call(m.puzzles.size() == 3 and m.tabs.size() == 3, "three levels on the tabs")
	_check.call(m.counter.text.ends_with(": 0") and m.par_label.text != "", "counter and par are shown")
	_check.call(m.message.text == WhiteText.t("hint"), "the hint shows before the first move")
	var p: Dictionary = m.puzzles[0]
	for code in p.path:
		m._on_move(code)
	var a: WhiteAttempt = m.attempts[0]
	_check.call(a.solved() and a.count() == int(p.par) and a.record.length() == 3 * int(p.par), "playing the stored path solves level 0 in par moves")
	m._on_debug_extra()
	_check.call(m.next_btn.visible and m.best_btn.visible and not m.undo_btn.visible, "solved: Next and Best route, no Undo")
	_check.call(m.message.text.contains(str(p.par)), "the solved message shows count and par")
	m._next()
	_check.call(m.level == 1 and not m.attempts[1].solved(), "Next goes to the next level")
	m.level = 2
	m._show_level()
	var before: int = m.practice_index
	m._next()
	_check.call(m.practice_index == before + 1 and m.level == 0, "Next after hard goes to the next set, easy")
	# dead end notice on a board without moves (example 6), only after a move was made
	var dead := _mk(["......", "222222"])
	var da := WhiteAttempt.new(dead, WhiteAttempt.CountMode.FINAL_ONLY)
	m.view.show_attempt(da)
	_check.call(m._play_message(da) == "", "no dead-end notice before a move")
	da.moves_made = 1
	_check.call(m._play_message(da) == WhiteText.t("dead_end"), "dead-end notice on a board without a move")
	var wide: Dictionary = m._insets_for(Vector2(2276, 1280))
	_check.call(wide.left == 778 and wide.right == 778 and wide.top == 24, "wide screen: the column is at most 720 px, centred")
	_check.call(m._insets_for(Vector2(720, 1280)).left == 24, "phone width: normal margins")
	m.queue_free()
