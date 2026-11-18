class_name TallyBoard
extends WhiteRules
## Board, moves and resolution. State: PackedByteArray w * h, index y * w + x, y up, 0 empty or 2..4.
## Move code m = i * 4 + d, d in R 0, L 1, D 2, U 3. Token: direction, column letter, row digit ("RB1").

enum Dir { R, L, D, U }

const DIR_LETTERS := "RLDU"
const GLYPHS := ".234"

var w := 0
var h := 0
var start := PackedByteArray()

# scratch for flood fills, stamp avoids clearing
var _seen := PackedInt32Array()
var _stamp := 0
var _stack := PackedInt32Array()


static func create(width: int, height: int) -> TallyBoard:
	var b := TallyBoard.new()
	b.w = width
	b.h = height
	b.start = PackedByteArray()
	b.start.resize(width * height)
	b._seen.resize(width * height)
	return b


static func from_dict(d: Dictionary) -> TallyBoard:
	var n: Array = d.n
	var b := TallyBoard.create(int(n[0]), int(n[1]))
	var rows := PackedStringArray()
	for r in d.rows:
		rows.append(str(r))
	b.start = b.from_rows(rows)
	return b


func to_dict(state: PackedByteArray) -> Dictionary:
	return {"n": [w, h], "rows": Array(render(state).split("\n"))}


## Rows top first, chars ".234".
func from_rows(rows: PackedStringArray) -> PackedByteArray:
	var s := PackedByteArray()
	s.resize(w * h)
	for ry in h:
		var y := h - 1 - ry
		for x in w:
			var c := GLYPHS.find(rows[ry][x])
			s[y * w + x] = 0 if c <= 0 else c + 1
	return s


func render(state: PackedByteArray) -> String:
	var rows := PackedStringArray()
	for ry in h:
		var y := h - 1 - ry
		var line := ""
		for x in w:
			var v := state[y * w + x]
			line += "." if v == 0 else str(v)
		rows.append(line)
	return "\n".join(rows)


func cell_name(i: int) -> String:
	return char(65 + i % w) + str(i / w + 1)


# --- White Kit interface -----------------------------------------------------------------------------------------

func start_state() -> Variant:
	return start


func apply(state: Variant, move: Variant) -> Variant:
	if not move is int:
		return null
	var c := canonical(state, move)
	return null if c < 0 else step(state, c)


func is_solved(state: Variant) -> bool:
	for v in (state as PackedByteArray):
		if v != 0:
			return false
	return true


func move_len() -> int:
	return 3


func encode_move(move: Variant) -> String:
	var m: int = move
	return DIR_LETTERS[m & 3] + cell_name(m >> 2)


func decode_move(token: String) -> Variant:
	if token.length() != 3:
		return null
	var d := DIR_LETTERS.find(token[0])
	var x := token.unicode_at(1) - 65
	var y := token.unicode_at(2) - 49
	if d < 0 or x < 0 or x >= w or y < 0 or y >= h:
		return null
	return (y * w + x) * 4 + d


# --- rules -------------------------------------------------------------------------------------------------------

## Canonical code of m in this state, -1 when the move is ignored.
func canonical(state: PackedByteArray, m: int) -> int:
	var i := m >> 2
	var d := m & 3
	if i < 0 or i >= w * h or state[i] == 0:
		return -1
	var x := i % w
	var y := i / w
	var j := 0
	match d:
		Dir.R:
			if x + 1 >= w:
				return -1
			j = i + 1
		Dir.L:
			if x == 0:
				return -1
			j = i - 1
		Dir.D:
			if y == 0:
				return -1
			j = i - w
		_:
			if y + 1 >= h:
				return -1
			j = i + w
	var t := state[j]
	if t == state[i]:
		return -1
	if t != 0:
		match d:
			Dir.R:
				return m
			Dir.L:
				return j * 4 + Dir.R
			Dir.D:
				return j * 4 + Dir.U
			_:
				return m
	if d == Dir.R or d == Dir.L:
		return m
	return -1


## All canonical codes, ascending.
func legal_moves(state: PackedByteArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	for y in h:
		for x in w:
			var i := y * w + x
			var v := state[i]
			if v == 0:
				continue
			if x + 1 < w:
				var t := state[i + 1]
				if t != v:
					out.append(i * 4 + Dir.R)
			if x > 0 and state[i - 1] == 0:
				out.append(i * 4 + Dir.L)
			if y + 1 < h:
				var t := state[i + w]
				if t != 0 and t != v:
					out.append(i * 4 + Dir.U)
	return out


func count_tiles(state: PackedByteArray) -> int:
	var n := 0
	for v in state:
		if v != 0:
			n += 1
	return n


func is_dead_end(state: PackedByteArray) -> bool:
	return not is_solved(state) and legal_moves(state).is_empty()


## Moves tiles of a canonical move, no settling. Returns [col_a, col_b].
func _move_only(s: PackedByteArray, m: int) -> Vector2i:
	var i := m >> 2
	var x := i % w
	match m & 3:
		Dir.R:
			var j := i + 1
			if s[j] == 0:
				s[j] = s[i]
				s[i] = 0
			else:
				var t := s[j]
				s[j] = s[i]
				s[i] = t
			return Vector2i(x, x + 1)
		Dir.L:
			s[i - 1] = s[i]
			s[i] = 0
			return Vector2i(x, x - 1)
		_:
			var j := i + w
			var t := s[j]
			s[j] = s[i]
			s[i] = t
			return Vector2i(x, x)


## Legal canonical move plus full resolution (fast: only touched columns are settled and scanned).
func step(state: PackedByteArray, m: int) -> PackedByteArray:
	var s := state.duplicate()
	var cols := _move_only(s, m)
	var ymin := PackedInt32Array()
	ymin.resize(w)
	ymin.fill(h)
	ymin[cols.x] = 0
	ymin[cols.y] = 0
	_waves(s, ymin)
	return s


## Settle and resolve everything (used for arbitrary boards).
func resolve(state: PackedByteArray) -> PackedByteArray:
	var s := state.duplicate()
	var ymin := PackedInt32Array()
	ymin.resize(w)
	ymin.fill(0)
	_waves(s, ymin)
	return s


# ymin[x]: lowest row that changed in column x (h = untouched); cells below are a settled stack
func _waves(s: PackedByteArray, ymin: PackedInt32Array) -> void:
	var w := self.w
	var h := self.h
	while true:
		# settle touched columns
		for x in w:
			var y0 := ymin[x]
			if y0 >= h:
				continue
			var wr := y0
			for y in range(y0, h):
				var v := s[y * w + x]
				if v != 0:
					if wr != y:
						s[wr * w + x] = v
						s[y * w + x] = 0
					wr += 1
		# scan from touched columns and their neighbours
		_stamp += 1
		var gone := PackedInt32Array()
		for x in w:
			var lo := ymin[x]
			if x > 0 and ymin[x - 1] < lo:
				lo = ymin[x - 1]
			if x + 1 < w and ymin[x + 1] < lo:
				lo = ymin[x + 1]
			if lo >= h:
				continue
			var i := maxi(0, lo - 1) * w + x
			while i < w * h and s[i] != 0:
				if _seen[i] != _stamp:
					_flood(s, i, gone)
				i += w
		if gone.is_empty():
			return
		ymin.fill(h)
		for i in gone:
			s[i] = 0
			var x := i % w
			ymin[x] = mini(ymin[x], i / w)


# flood the whole component of i (marks all cells); appends its cells to out when exact
func _flood(s: PackedByteArray, i: int, out: PackedInt32Array) -> void:
	var v := s[i]
	var n := 0
	var first := out.size()
	_stack.clear()
	_stack.append(i)
	_seen[i] = _stamp
	while not _stack.is_empty():
		var c: int = _stack[_stack.size() - 1]
		_stack.resize(_stack.size() - 1)
		out.append(c)
		n += 1
		var x := c % w
		if x + 1 < w and s[c + 1] == v and _seen[c + 1] != _stamp:
			_seen[c + 1] = _stamp
			_stack.append(c + 1)
		if x > 0 and s[c - 1] == v and _seen[c - 1] != _stamp:
			_seen[c - 1] = _stamp
			_stack.append(c - 1)
		if c + w < w * h and s[c + w] == v and _seen[c + w] != _stamp:
			_seen[c + w] = _stamp
			_stack.append(c + w)
		if c >= w and s[c - w] == v and _seen[c - w] != _stamp:
			_seen[c - w] = _stamp
			_stack.append(c - w)
	if n != v:
		out.resize(first)


## Every tile falls straight down.
func settle(state: PackedByteArray) -> PackedByteArray:
	var s := state.duplicate()
	for x in w:
		var wr := 0
		for y in h:
			var v := s[y * w + x]
			if v != 0:
				s[y * w + x] = 0
				s[wr * w + x] = v
				wr += 1
	return s


func _components(state: PackedByteArray) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	var seen := PackedByteArray()
	seen.resize(w * h)
	for i in w * h:
		if state[i] == 0 or seen[i] != 0:
			continue
		var comp := PackedInt32Array([i])
		seen[i] = 1
		var k := 0
		while k < comp.size():
			var c := comp[k]
			k += 1
			var x := c % w
			var nb := PackedInt32Array()
			if x + 1 < w:
				nb.append(c + 1)
			if x > 0:
				nb.append(c - 1)
			if c + w < w * h:
				nb.append(c + w)
			if c >= w:
				nb.append(c - w)
			for n in nb:
				if state[n] == state[i] and seen[n] == 0:
					seen[n] = 1
					comp.append(n)
		out.append(comp)
	return out


## All groups (4-connected components of equal value).
func groups(state: PackedByteArray) -> Array[PackedInt32Array]:
	return _components(state)


func exact_groups(state: PackedByteArray) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	for g in _components(state):
		if g.size() == state[g[0]]:
			out.append(g)
	return out


func is_settled(state: PackedByteArray) -> bool:
	return settle(state) == state


func is_stable(state: PackedByteArray) -> bool:
	return is_settled(state) and exact_groups(state).is_empty()


## Same result as step(), written plainly: whole-board settle and scan each wave.
func step_reference(state: PackedByteArray, m: int) -> PackedByteArray:
	var s := state.duplicate()
	_move_only(s, m)
	while true:
		s = settle(s)
		var ex := exact_groups(s)
		if ex.is_empty():
			return s
		for g in ex:
			for i in g:
				s[i] = 0
	return s


## Result plus animation steps: swap/slide, then per settle fall, per wave vanish.
func step_traced(state: PackedByteArray, m: int) -> Dictionary:
	var s := state.duplicate()
	var steps: Array = []
	var i := m >> 2
	var j := i + 1 if (m & 3) == Dir.R else i - 1 if (m & 3) == Dir.L else i + w
	if s[j] == 0:
		steps.append({"kind": "slide", "from": i, "to": j})
	else:
		steps.append({"kind": "swap", "a": i, "b": j})
	_move_only(s, m)
	while true:
		var moves: Array = []
		for x in w:
			var wr := 0
			for y in h:
				var c := y * w + x
				var v := s[c]
				if v != 0:
					if wr != y:
						moves.append([c, wr * w + x])
						s[wr * w + x] = v
						s[c] = 0
					wr += 1
		if not moves.is_empty():
			steps.append({"kind": "fall", "moves": moves})
		var ex := exact_groups(s)
		if ex.is_empty():
			break
		var cells := PackedInt32Array()
		for g in ex:
			cells.append_array(g)
		cells.sort()
		for c in cells:
			s[c] = 0
		steps.append({"kind": "vanish", "cells": cells})
	return {"state": s, "steps": steps}
