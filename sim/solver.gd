class_name TallySolver
extends RefCounted
## Par search: iterative deepening dfs with a transposition table, beam and greedy fallbacks. All limits are
## counts, never time.

const TABLE_MAX := 4000000

var _board: TallyBoard
var _table := {}
var _expansions := 0
var _max_expansions := 0
var _capped := false
var _line := PackedInt32Array()


## {"par", "exact", "path", "expansions", "capped"}; upper_path must empty the board.
static func solve(board: TallyBoard, state: PackedByteArray, upper_path: PackedInt32Array,
		max_expansions: int) -> Dictionary:
	var sv := TallySolver.new()
	sv._board = board
	sv._max_expansions = max_expansions
	var upper := upper_path.size()
	var best := upper_path
	var exact := true
	for d in range(1, upper):
		sv._line = PackedInt32Array()
		if sv._dfs(state, d):
			best = sv._line
			break
		if sv._capped:
			exact = false
			break
	if not exact:
		var b := beam(board, state, 200, upper - 1)
		if not b.is_empty() and b.size() < upper:
			best = b
	return {"par": best.size(), "exact": exact, "path": best, "expansions": sv._expansions, "capped": sv._capped}


# children as [code, state], more tiles removed first, then ascending code
func _children(state: PackedByteArray, only_empty: bool) -> Array:
	var keys := PackedInt64Array()
	var by_code := {}
	for m in _board.legal_moves(state):
		var c := _board.step(state, m)
		var n := _board.count_tiles(c)
		if only_empty and n != 0:
			continue
		keys.append(n * 1024 + m)
		by_code[m] = c
	keys.sort()
	var kids: Array = []
	for k in keys:
		var m := k & 1023
		kids.append([m, by_code[m]])
	return kids


# true when a line of at most r moves empties the board; the line is left in _line
func _dfs(state: PackedByteArray, r: int) -> bool:
	if _board.is_solved(state):
		return true
	if r == 0:
		return false
	if _table.get(state, 0) >= r:
		return false
	if _expansions >= _max_expansions:
		_capped = true
		return false
	_expansions += 1
	for k in _children(state, r == 1):
		_line.append(k[0])
		if _dfs(k[1], r - 1):
			return true
		_line.resize(_line.size() - 1)
		if _capped:
			return false
	if _table.size() < TABLE_MAX or _table.has(state):
		_table[state] = maxi(_table.get(state, 0), r)
	return false


## Breadth-first by depth keeping the width fewest-tile distinct states. Empty array when nothing found.
static func beam(board: TallyBoard, state: PackedByteArray, width: int, max_depth: int) -> PackedInt32Array:
	var level: Array = [[state, PackedInt32Array()]]
	var seen := {state: true}
	for depth in max_depth:
		var next: Array = []
		for node in level:
			var st: PackedByteArray = node[0]
			for m in board.legal_moves(st):
				var c := board.step(st, m)
				if seen.has(c):
					continue
				seen[c] = true
				var p: PackedInt32Array = node[1].duplicate()
				p.append(m)
				if board.is_solved(c):
					return p
				next.append([c, p, board.count_tiles(c), next.size()])
		if next.is_empty():
			break
		# stable by discovery order: ties on tiles keep the index
		next.sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2] or (a[2] == b[2] and a[3] < b[3]))
		level = next.slice(0, width)
	return PackedInt32Array()


## Plays the move removing most tiles (ties: lowest code); gives up when none removes anything.
static func greedy(board: TallyBoard, state: PackedByteArray, max_moves: int) -> Dictionary:
	var s := state
	var path := PackedInt32Array()
	while not board.is_solved(s) and path.size() < max_moves:
		var cur := board.count_tiles(s)
		var best_m := -1
		var best_s := s
		var best_n := cur
		for m in board.legal_moves(s):
			var c := board.step(s, m)
			var n := board.count_tiles(c)
			if n < best_n:
				best_n = n
				best_m = m
				best_s = c
		if best_m < 0:
			break
		path.append(best_m)
		s = best_s
	return {"solved": board.is_solved(s), "moves": path.size(), "path": path}
