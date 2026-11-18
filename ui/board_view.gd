class_name TallyBoardView
extends Control
## Draws the board and animates moves (design 10). Turns swipe, tap-tap and keys into canonical move codes.
## Tiles have stable ids; an animation is a list of phases built from TallyBoard.step_traced.

signal move_chosen(code: int)
signal finished ## last phase of an animation done (or jumped to its end)

const BOARD_BG := Color("232933")
const GRID := Color("2C333F")
const TILE_COLORS := {2: Color("4C7FD6"), 3: Color("E3943A"), 4: Color("3FA58A")}
const PIP := Color(0.110, 0.122, 0.141, 0.85)
const OUTLINE := WhiteTheme.ACCENT
const PIPS := {
	2: [Vector2(0.3, 0.3), Vector2(0.7, 0.7)],
	3: [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)],
	4: [Vector2(0.3, 0.3), Vector2(0.7, 0.3), Vector2(0.3, 0.7), Vector2(0.7, 0.7)],
}
const FIT := 0.3 ## board margin in cells, added to w and h when sizing
const GAP := 0.08 ## gap between tiles, in cells
const RADIUS := 0.18 ## corner radius, in cells
const JOIN_WIDTH := 0.4 ## join bar, in cells
const PIP_DIAMETER := 0.16 ## in cells
const OUTLINE_PX := 4.0
const SWAP_TIME := 0.12
const SLIDE_TIME := 0.10
const FALL_SPEED := 16.0 ## cells per second
const VANISH_TIME := 0.18
const VANISH_PAUSE := 0.06
const VANISH_SCALE := 0.7
const SHAKE_TIME := 0.15
const SHAKE_CYCLES := 3
const SHAKE_PX := 4.0
const SWIPE_FRAC := 0.4 ## drag as part of a cell that fires a swipe
const SWIPE_MIN_PX := 24.0 ## drag in px that counts on release

var board: TallyBoard
var input_enabled := true

var _state := PackedByteArray()
var _ids := PackedInt32Array() ## cell -> tile id, -1 empty (state after the running animation)
var _val := PackedByteArray()
var _pos := PackedVector2Array() ## cells, y up
var _scale := PackedFloat32Array()
var _alpha := PackedFloat32Array()
var _alive := PackedByteArray()
var _phases: Array = []
var _pi := 0
var _pt := 0.0
var _sel := -1
var _grab := false
var _cursor := 0
var _cursor_on := false
var _follow := -1
var _shake_id := -1
var _shake_t := 0.0
var _press := -2 ## cell under the press, -1 outside the board, -2 no press
var _press_pos := Vector2.ZERO
var _fired := false
var _box := StyleBoxFlat.new()


# --- pure helpers (tested) ---------------------------------------------------------------------------------------

## {cell, origin} in px for a board of w x h in a control of this size.
static func layout(area: Vector2, w: int, h: int) -> Dictionary:
	var cell := floorf(minf(area.x / (w + FIT), area.y / (h + FIT)))
	cell = maxf(cell, 1.0)
	return {"cell": cell, "origin": (area - Vector2(w, h) * cell) / 2.0}


## Cell index under a point, -1 outside the board.
static func cell_at(p: Vector2, lay: Dictionary, w: int, h: int) -> int:
	var q: Vector2 = (p - lay.origin) / lay.cell
	var x := floori(q.x)
	var y := h - 1 - floori(q.y)
	if q.x < 0.0 or q.y < 0.0 or x >= w or y < 0 or y >= h:
		return -1
	return y * w + x


## Direction of a drag on the screen (dominant axis), as TallyBoard.Dir; screen down is D.
static func drag_dir(d: Vector2) -> int:
	if absf(d.x) > absf(d.y):
		return TallyBoard.Dir.R if d.x > 0.0 else TallyBoard.Dir.L
	return TallyBoard.Dir.D if d.y > 0.0 else TallyBoard.Dir.U


## Direction from cell a to an orthogonal neighbour b, -1 when they are not neighbours.
static func neighbour_dir(a: int, b: int, w: int) -> int:
	var dx := (b % w) - (a % w)
	var dy := (b / w) - (a / w)
	if dy == 0 and dx == 1:
		return TallyBoard.Dir.R
	if dy == 0 and dx == -1:
		return TallyBoard.Dir.L
	if dx == 0 and dy == 1:
		return TallyBoard.Dir.U
	if dx == 0 and dy == -1:
		return TallyBoard.Dir.D
	return -1


## Direction for an arrow or WASD key, -1 for other keys. Screen down is D.
static func key_dir(keycode: int) -> int:
	match keycode:
		KEY_RIGHT, KEY_D:
			return TallyBoard.Dir.R
		KEY_LEFT, KEY_A:
			return TallyBoard.Dir.L
		KEY_DOWN, KEY_S:
			return TallyBoard.Dir.D
		KEY_UP, KEY_W:
			return TallyBoard.Dir.U
	return -1


## Cell after a keyboard cursor step, unchanged at the edge.
static func step_cell(i: int, d: int, w: int, h: int) -> int:
	var x := i % w
	var y := i / w
	match d:
		TallyBoard.Dir.R:
			x = mini(x + 1, w - 1)
		TallyBoard.Dir.L:
			x = maxi(x - 1, 0)
		TallyBoard.Dir.U:
			y = mini(y + 1, h - 1)
		_:
			y = maxi(y - 1, 0)
	return y * w + x


## Animation phases for the steps of step_traced. ids: cell -> tile id before the move.
## Returns {"phases": [{kind, dur, ids, from, to}], "ids": cell -> tile id after the move}.
static func build_phases(w: int, ids: PackedInt32Array, steps: Array) -> Dictionary:
	var cur := ids.duplicate()
	var phases: Array = []
	for s in steps:
		match str(s.kind):
			"swap":
				var a: int = s.a
				var b: int = s.b
				phases.append({"kind": "swap", "dur": SWAP_TIME, "ids": [cur[a], cur[b]],
						"from": [_at(a, w), _at(b, w)], "to": [_at(b, w), _at(a, w)]})
				var t := cur[a]
				cur[a] = cur[b]
				cur[b] = t
			"slide":
				var f: int = s.from
				var to: int = s.to
				phases.append({"kind": "slide", "dur": SLIDE_TIME, "ids": [cur[f]],
						"from": [_at(f, w)], "to": [_at(to, w)]})
				cur[to] = cur[f]
				cur[f] = -1
			"fall":
				var pid: Array = []
				var pf: Array = []
				var pt: Array = []
				var far := 1.0
				for m in s.moves:
					pid.append(cur[m[0]])
					pf.append(_at(m[0], w))
					pt.append(_at(m[1], w))
					far = maxf(far, float(m[0] / w - m[1] / w))
					cur[m[1]] = cur[m[0]]
					cur[m[0]] = -1
				phases.append({"kind": "fall", "dur": far / FALL_SPEED, "ids": pid, "from": pf, "to": pt})
			"vanish":
				var vid: Array = []
				for c in s.cells:
					vid.append(cur[c])
					cur[c] = -1
				phases.append({"kind": "vanish", "dur": VANISH_TIME + VANISH_PAUSE, "ids": vid, "from": [], "to": []})
	return {"phases": phases, "ids": cur}


static func _at(i: int, w: int) -> Vector2:
	return Vector2(i % w, i / w)


# --- state -------------------------------------------------------------------------------------------------------

## Shows the attempt's state at once (no animation).
func show_attempt(a: WhiteAttempt) -> void:
	board = a.rules as TallyBoard
	_show_state(a.state)
	_cursor = 0
	_cursor_on = false


func clear() -> void:
	board = null
	_phases.clear()
	queue_redraw()


## After a move: animates it; after undo or restart: shows the state at once.
func update_attempt(a: WhiteAttempt) -> void:
	var rec := a.record
	var is_move := rec.length() >= 3 and rec.right(1).is_valid_int() and not a.history.is_empty()
	var code: Variant = board.decode_move(rec.right(3)) if is_move else null
	_finish_anim()
	_sel = -1
	_grab = false
	if code == null:
		_show_state(a.state)
		return
	var before: PackedByteArray = a.history.back()
	if before != _state:
		_show_state(before)
	var follow := _follow
	_follow = -1
	play_move(code)
	var at := _ids.find(follow) if follow >= 0 else -1
	if at >= 0 and _cursor_on:
		_cursor = at


## Animates a canonical move from the shown state (also used by Best route).
func play_move(code: int) -> void:
	_finish_anim()
	var traced := board.step_traced(_state, code)
	var built := build_phases(board.w, _ids, traced.steps)
	_state = traced.state
	_ids = built.ids
	_phases = built.phases
	_pi = 0
	_pt = 0.0
	set_process(true)
	queue_redraw()


func show_state(s: PackedByteArray) -> void:
	_finish_anim()
	_show_state(s)


func state() -> PackedByteArray:
	return _state


func busy() -> bool:
	return not _phases.is_empty()


func selected() -> int:
	return _sel


func debug_select(i: int) -> void:
	_sel = i
	queue_redraw()


func _show_state(s: PackedByteArray) -> void:
	_phases.clear()
	_state = s.duplicate()
	var n := _state.size()
	_ids.resize(n)
	_val.resize(n)
	_pos.resize(n)
	_scale.resize(n)
	_alpha.resize(n)
	_alive.resize(n)
	_alive.fill(0)
	var w := board.w
	for i in n:
		_ids[i] = -1
		if _state[i] != 0:
			_ids[i] = i
			_val[i] = _state[i]
			_pos[i] = _at(i, w)
			_scale[i] = 1.0
			_alpha[i] = 1.0
			_alive[i] = 1
	_sel = -1
	_grab = false
	queue_redraw()


# --- animation ---------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var redraw := false
	if _shake_id >= 0:
		_shake_t += delta
		if _shake_t >= SHAKE_TIME:
			_shake_id = -1
		redraw = true
	if not _phases.is_empty():
		_advance(delta)
		redraw = true
	if redraw:
		queue_redraw()
	elif _phases.is_empty():
		set_process(false)


func _advance(delta: float) -> void:
	while delta > 0.0 and _pi < _phases.size():
		var p: Dictionary = _phases[_pi]
		var dur := maxf(float(p.dur), 0.001)
		var left := dur - _pt
		if delta >= left:
			_apply(p, dur)
			delta -= left
			_pi += 1
			_pt = 0.0
		else:
			_pt += delta
			_apply(p, _pt)
			delta = 0.0
	if _pi >= _phases.size():
		_phases.clear()
		finished.emit()


func _finish_anim() -> void:
	if _phases.is_empty():
		return
	while _pi < _phases.size():
		var p: Dictionary = _phases[_pi]
		_apply(p, maxf(float(p.dur), 0.001))
		_pi += 1
	_phases.clear()
	_pt = 0.0
	queue_redraw()
	finished.emit()


## Sets tile positions or fade for phase p after sec seconds.
func _apply(p: Dictionary, sec: float) -> void:
	var dur := maxf(float(p.dur), 0.001)
	var ids: Array = p.ids
	if p.kind == "vanish":
		var f := clampf(sec / VANISH_TIME, 0.0, 1.0)
		for id in ids:
			_scale[id] = lerpf(1.0, VANISH_SCALE, f)
			_alpha[id] = 1.0 - f
			if sec >= dur:
				_alive[id] = 0
		return
	var t := clampf(sec / dur, 0.0, 1.0)
	if p.kind != "fall":
		t = 1.0 - (1.0 - t) * (1.0 - t)
	for k in ids.size():
		_pos[ids[k]] = (p.from[k] as Vector2).lerp(p.to[k], t)


func _start_shake(id: int) -> void:
	_shake_id = id
	_shake_t = 0.0
	set_process(true)
	queue_redraw()


# --- drawing -----------------------------------------------------------------------------------------------------

func _draw() -> void:
	if board == null:
		return
	var lay := layout(size, board.w, board.h)
	var cell: float = lay.cell
	var o: Vector2 = lay.origin
	var grid := Vector2(board.w, board.h) * cell
	var rim := cell * 0.1
	_box.bg_color = BOARD_BG
	_box.set_corner_radius_all(int(cell * RADIUS))
	draw_style_box(_box, Rect2(o - Vector2(rim, rim), grid + Vector2(rim, rim) * 2.0))
	for x in range(1, board.w):
		draw_line(o + Vector2(x * cell, 0), o + Vector2(x * cell, grid.y), GRID, 2.0)
	for y in range(1, board.h):
		draw_line(o + Vector2(0, y * cell), o + Vector2(grid.x, y * cell), GRID, 2.0)
	var live: Array[int] = []
	for id in _alive.size():
		if _alive[id] == 1:
			live.append(id)
	_box.set_corner_radius_all(int(cell * RADIUS))
	for id in live:
		var r := _tile_rect(id, o, cell)
		var col: Color = TILE_COLORS[_val[id]]
		col.a = _alpha[id]
		_box.bg_color = col
		draw_style_box(_box, r)
	_draw_joins(live, o, cell)
	for id in live:
		_draw_pips(id, o, cell)
	_draw_marks(o, cell)


func _tile_rect(id: int, o: Vector2, cell: float) -> Rect2:
	var c := _center(_pos[id], o, cell)
	if id == _shake_id:
		var k := _shake_t / SHAKE_TIME
		c.x += sin(k * TAU * SHAKE_CYCLES) * SHAKE_PX * (1.0 - k)
	var side := cell * (1.0 - GAP) * _scale[id]
	return Rect2(c - Vector2(side, side) / 2.0, Vector2(side, side))


func _center(p: Vector2, o: Vector2, cell: float) -> Vector2:
	return o + Vector2(p.x + 0.5, board.h - 1.0 - p.y + 0.5) * cell


func _draw_joins(live: Array[int], o: Vector2, cell: float) -> void:
	for ai in live.size():
		for bi in range(ai + 1, live.size()):
			var a := live[ai]
			var b := live[bi]
			if _val[a] != _val[b]:
				continue
			var d := _pos[b] - _pos[a]
			var horizontal := absf(absf(d.x) - 1.0) < 0.02 and absf(d.y) < 0.02
			var vertical := absf(absf(d.y) - 1.0) < 0.02 and absf(d.x) < 0.02
			if not (horizontal or vertical):
				continue
			var k := minf(_scale[a], _scale[b])
			var col: Color = TILE_COLORS[_val[a]]
			col.a = minf(_alpha[a], _alpha[b])
			var ca := _center(_pos[a], o, cell)
			var cb := _center(_pos[b], o, cell)
			var thick := cell * JOIN_WIDTH * k
			var r := Rect2(ca.min(cb) - Vector2(thick, thick) / 2.0, (ca - cb).abs() + Vector2(thick, thick))
			draw_rect(r, col)


func _draw_pips(id: int, o: Vector2, cell: float) -> void:
	var r := _tile_rect(id, o, cell)
	var col := PIP
	col.a *= _alpha[id]
	for q in PIPS[_val[id]]:
		draw_circle(r.position + r.size * (q as Vector2), cell * PIP_DIAMETER / 2.0 * _scale[id], col)


func _draw_marks(o: Vector2, cell: float) -> void:
	_box.draw_center = false
	_box.border_color = OUTLINE
	_box.set_border_width_all(int(OUTLINE_PX))
	_box.set_corner_radius_all(int(cell * RADIUS))
	if _sel >= 0:
		draw_style_box(_box, _cell_rect(_sel, o, cell))
	_box.draw_center = true
	_box.set_border_width_all(0)
	if _cursor_on and _sel != _cursor:
		var r := _cell_rect(_cursor, o, cell)
		var tl := r.position
		var tr := Vector2(r.end.x, r.position.y)
		var br := r.end
		var bl := Vector2(r.position.x, r.end.y)
		for e in [[tl, tr], [tr, br], [br, bl], [bl, tl]]:
			draw_dashed_line(e[0], e[1], OUTLINE, OUTLINE_PX, 10.0)


func _cell_rect(i: int, o: Vector2, cell: float) -> Rect2:
	var c := _center(_at(i, board.w), o, cell)
	var side := cell * (1.0 - GAP)
	return Rect2(c - Vector2(side, side) / 2.0, Vector2(side, side))


# --- input -------------------------------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if board == null or not input_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = _cell_under(event.position)
			_press_pos = event.position
			_fired = false
			_cursor_on = false
		elif _press != -2:
			_release(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _press != -2 and not _fired and _press >= 0:
		var d: Vector2 = event.position - _press_pos
		var cell: float = layout(size, board.w, board.h).cell
		if _press_has_tile() and d.length() >= cell * SWIPE_FRAC:
			_fire_swipe(d)
		accept_event()


func _cell_under(p: Vector2) -> int:
	var i := cell_at(p, layout(size, board.w, board.h), board.w, board.h)
	return i if i >= 0 else -1


func _press_has_tile() -> bool:
	return _press >= 0 and _ids[_press] >= 0


func _release(p: Vector2) -> void:
	var from := _press
	_press = -2
	if _fired:
		return
	var d := p - _press_pos
	if d.length() >= SWIPE_MIN_PX:
		_press = from
		if _press_has_tile():
			_fire_swipe(d)
		_press = -2
		return
	_tap(from)


func _fire_swipe(d: Vector2) -> void:
	_fired = true
	_finish_anim()
	var c := _try_move(_press * 4 + drag_dir(d))
	if c >= 0:
		move_chosen.emit(c)


## Tap-tap selection (design 10.4).
func _tap(i: int) -> void:
	_finish_anim()
	if i < 0 or _sel == i:
		_sel = -1
	elif _sel < 0:
		_sel = i if _ids[i] >= 0 else -1
	else:
		var d := neighbour_dir(_sel, i, board.w)
		if d >= 0:
			var c := _try_move(_sel * 4 + d)
			_sel = -1
			if c >= 0:
				move_chosen.emit(c)
		else:
			_sel = i if _ids[i] >= 0 else -1
	queue_redraw()


## Raw code to canonical code; -1 and a shake of the source tile when the move is ignored.
func _try_move(raw: int) -> int:
	_finish_anim()
	var c := board.canonical(_state, raw)
	if c < 0:
		if _ids[raw >> 2] >= 0:
			_start_shake(_ids[raw >> 2])
		return -1
	_sel = -1
	_grab = false
	return c


## Keyboard (design 10.4): returns a canonical code or null. Cursor and grab are drawn by the view.
func key_move(event: InputEventKey) -> Variant:
	if board == null or not input_enabled:
		return null
	var d := key_dir(event.keycode)
	if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_finish_anim()
		_cursor_on = true
		if _grab:
			_grab = false
			_sel = -1
		elif _ids[_cursor] >= 0:
			_grab = true
			_sel = _cursor
		queue_redraw()
		return null
	if event.keycode == KEY_ESCAPE:
		_grab = false
		_sel = -1
		queue_redraw()
		return null
	if d < 0:
		return null
	_finish_anim()
	if not _cursor_on:
		_cursor_on = true
		queue_redraw()
		return null
	if not _grab:
		_cursor = step_cell(_cursor, d, board.w, board.h)
		queue_redraw()
		return null
	var c := _try_move(_cursor * 4 + d)
	if c >= 0:
		_follow = _ids[_cursor]
	return c if c >= 0 else null


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
