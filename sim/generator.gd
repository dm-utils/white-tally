class_name TallyGenerator
extends RefCounted
## Reverse-building puzzle generator: grows a board backwards from empty, so every puzzle is solvable and the
## number of reverse steps bounds par. Draws only from WhiteRng seeded with the seed.

const RETRIES := 50

# gap -1: no greedy filter; i/q ranges inclusive; band par range inclusive
const LEVELS: Array[Dictionary] = [
	{"w": 5, "h": 6, "i": [3, 4], "q": [0, 1], "chain": 0, "values": 2, "overfull": 1, "gap": -1,
		"band": [3, 5], "candidates": 400, "budget": 100000},
	{"w": 6, "h": 6, "i": [5, 6], "q": [1, 2], "chain": 20, "values": 3, "overfull": 1, "gap": 1,
		"band": [5, 8], "candidates": 600, "budget": 300000},
	{"w": 6, "h": 7, "i": [7, 9], "q": [2, 3], "chain": 30, "values": 3, "overfull": 1, "gap": 2,
		"band": [8, 12], "candidates": 900, "budget": 1000000},
]


## {"board": TallyBoard, "par", "exact", "upper", "path", "tried", "fallback"}
static func generate(seed_value: int, level: int) -> Dictionary:
	return generate_with(seed_value, LEVELS[level])


static func generate_with(seed_value: int, cfg: Dictionary) -> Dictionary:
	var rng := WhiteRng.new(seed_value)
	var board := TallyBoard.create(cfg.w, cfg.h)
	var band: Array = cfg.band
	var fb := {}
	var fb_key := []
	var tried := 0
	for t in cfg.candidates:
		tried += 1
		var cand := _candidate(board, rng, cfg)
		if cand.is_empty():
			continue
		var start: PackedByteArray = cand.start
		var path: PackedInt32Array = cand.path
		var upper := path.size()
		if not _cheap_ok(board, start, cfg):
			continue
		var par := upper
		var exact := false
		var sol_path := path
		if upper >= band[0]:
			var r := TallySolver.solve(board, start, path, cfg.budget)
			par = r.par
			exact = r.exact
			sol_path = r.path
		var res := {"start": start, "par": par, "exact": exact, "upper": upper, "path": sol_path}
		var dist := maxi(0, maxi(band[0] - par, par - band[1]))
		var key := [dist, 0 if exact else 1, board.count_tiles(start)]
		if fb.is_empty() or _less(key, fb_key):
			fb = res
			fb_key = key
		# phase 1 accepts bounded par
		if upper < band[0] or dist > 0:
			continue
		if cfg.gap >= 0:
			var g := TallySolver.greedy(board, start, 3 * upper)
			if g.solved and g.moves < par + cfg.gap:
				continue
		return _result(board, res, tried, false)
	if fb.is_empty():
		return _result(board, {"start": board.start, "par": 0, "exact": false, "upper": 0,
				"path": PackedInt32Array()}, tried, true)
	return _result(board, fb, tried, true)


static func _less(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return false


static func _result(board: TallyBoard, res: Dictionary, tried: int, fallback: bool) -> Dictionary:
	board.start = res.start
	return {"board": board, "par": res.par, "exact": res.exact, "upper": res.upper, "path": res.path,
			"tried": tried, "fallback": fallback}


## The puzzle object of design 6.3.
static func to_json(result: Dictionary) -> Dictionary:
	var b: TallyBoard = result.board
	var tokens := ""
	for m in result.path:
		tokens += b.encode_move(m)
	var d := {"board": b.to_dict(b.start), "par": result.par, "exact": result.exact, "upper": result.upper,
			"path": tokens}
	if result.fallback:
		d["fallback"] = true
	return d


static func _cheap_ok(board: TallyBoard, s: PackedByteArray, cfg: Dictionary) -> bool:
	if board.is_solved(s) or not board.is_stable(s):
		return false
	var counts := {2: 0, 3: 0, 4: 0}
	for v in s:
		if v != 0:
			counts[v] += 1
	var kinds := 0
	for v in counts:
		if counts[v] % v != 0:
			return false
		if counts[v] > 0:
			kinds += 1
	if kinds < cfg.values:
		return false
	var over := 0
	for g in board.groups(s):
		if g.size() > s[g[0]]:
			over += 1
	return over >= cfg.overfull


# --- building ----------------------------------------------------------------------------------------------------

# {"start", "path"} or {} when a step fails all its retries
static func _candidate(board: TallyBoard, rng: WhiteRng, cfg: Dictionary) -> Dictionary:
	var n_ins := rng.range_int(cfg.i[0], cfg.i[1])
	var n_quiet := rng.range_int(cfg.q[0], cfg.q[1])
	var rest: Array = []
	for k in n_ins - 1:
		rest.append(0)
	for k in n_quiet:
		rest.append(1)
	rng.shuffle(rest)
	var steps: Array = [0]
	steps.append_array(rest)
	var c := PackedByteArray()
	c.resize(board.w * board.h)
	var rev := PackedInt32Array() # forward moves, last executed step first
	for kind in steps:
		var out := {}
		for r in RETRIES:
			out = _quiet_step(board, rng, c) if kind == 1 else _insert_step(board, rng, c, cfg)
			if not out.is_empty():
				break
		if out.is_empty():
			return {}
		c = out.p
		rev.append(out.m)
	rev.reverse()
	return {"start": c, "path": rev}


static func _heights(board: TallyBoard, s: PackedByteArray) -> PackedInt32Array:
	var hs := PackedInt32Array()
	hs.resize(board.w)
	for x in board.w:
		var n := 0
		while n < board.h and s[n * board.w + x] != 0:
			n += 1
		hs[x] = n
	return hs


# {"state", "cells"} or {}; the new tiles form one run per column
static func _insert_group(board: TallyBoard, rng: WhiteRng, b: PackedByteArray, v: int) -> Dictionary:
	var w := board.w
	var k := rng.range_int(1, mini(v, w))
	var c0 := rng.range_int(0, w - k)
	var cuts: Array = []
	for i in range(1, v):
		cuts.append(i)
	rng.shuffle(cuts)
	cuts = cuts.slice(0, k - 1)
	cuts.sort()
	var runs: Array = []
	var prev := 0
	for c in cuts:
		runs.append(c - prev)
		prev = c
	runs.append(v - prev)
	var hs := _heights(board, b)
	var s := b.duplicate()
	var cells := PackedInt32Array()
	var py := 0
	var pr := 0
	for j in k:
		var x := c0 + j
		var r: int = runs[j]
		var lo := 0
		var hi := hs[x]
		if hs[x] + r > board.h:
			return {}
		if j > 0:
			lo = maxi(lo, py - r + 1) # y0 + r - 1 >= py
			hi = mini(hi, py + pr - 1)
		if lo > hi:
			return {}
		var y0 := rng.range_int(lo, hi)
		for y in range(hs[x] - 1, y0 - 1, -1):
			s[(y + r) * w + x] = s[y * w + x]
		for y in range(y0, y0 + r):
			s[y * w + x] = v
			cells.append(y * w + x)
		py = y0
		pr = r
	return {"state": s, "cells": cells}


# true when the component of cells[0] is exactly cells
static func _is_group(board: TallyBoard, s: PackedByteArray, cells: PackedInt32Array) -> bool:
	if cells.is_empty():
		return false
	for g in board.groups(s):
		if g.has(cells[0]):
			if g.size() != cells.size():
				return false
			for c in cells:
				if not g.has(c):
					return false
			return true
	return false


static func _insert_step(board: TallyBoard, rng: WhiteRng, c: PackedByteArray, cfg: Dictionary) -> Dictionary:
	var x: PackedByteArray
	if rng.range_int(0, 99) < cfg.chain:
		var g2 := _insert_group(board, rng, c, rng.range_int(2, 4))
		if g2.is_empty() or not _is_group(board, g2.state, g2.cells) or board.resolve(g2.state) != c:
			return {}
		var v1 := rng.range_int(2, 4)
		var g1 := _insert_group(board, rng, g2.state, v1)
		if g1.is_empty():
			return {}
		x = g1.state
		if not _is_group(board, x, g1.cells):
			return {}
		# where the g2 tiles ended up after g1 pushed columns up
		var moved := PackedInt32Array()
		for cell in g2.cells:
			var cx: int = cell % board.w
			var cy: int = cell / board.w
			moved.append((cy + _shift(board, g1.cells, cx, cy)) * board.w + cx)
		if _is_group(board, x, moved):
			return {}
	else:
		var g := _insert_group(board, rng, c, rng.range_int(2, 4))
		if g.is_empty() or not _is_group(board, g.state, g.cells):
			return {}
		x = g.state
	if board.resolve(x) != c:
		return {}
	return _reverse_move(board, rng, x, c, false)


static func _quiet_step(board: TallyBoard, rng: WhiteRng, c: PackedByteArray) -> Dictionary:
	return _reverse_move(board, rng, c, c, true)


static func _run_len(board: TallyBoard, cells: PackedInt32Array, x: int) -> int:
	var n := 0
	for gc in cells:
		if gc % board.w == x:
			n += 1
	return n


static func _run_start(board: TallyBoard, cells: PackedInt32Array, x: int) -> int:
	var lo := board.h
	for gc in cells:
		if gc % board.w == x:
			lo = mini(lo, gc / board.w)
	return lo


# rows a tile at (x, y) of the board before a group insertion moves up
static func _shift(board: TallyBoard, cells: PackedInt32Array, x: int, y: int) -> int:
	var n := _run_len(board, cells, x)
	if n == 0:
		return 0
	return n if y >= _run_start(board, cells, x) else 0


# {"p", "m"}: a stable predecessor of x with a forward move reaching t, picked uniformly among the valid ones
static func _reverse_move(board: TallyBoard, rng: WhiteRng, x: PackedByteArray, t: PackedByteArray,
		quiet: bool) -> Dictionary:
	var w := board.w
	var cands: Array = [] # [p, m]
	for y in board.h:
		for cx in w:
			var i := y * w + cx
			var v := x[i]
			if v == 0:
				continue
			if cx + 1 < w and x[i + 1] != 0 and x[i + 1] != v:
				var p := x.duplicate()
				p[i] = x[i + 1]
				p[i + 1] = v
				cands.append([p, i * 4 + TallyBoard.Dir.R])
			if y + 1 < board.h and x[i + w] != 0 and x[i + w] != v:
				var p := x.duplicate()
				p[i] = x[i + w]
				p[i + w] = v
				cands.append([p, i * 4 + TallyBoard.Dir.U])
	var hs := _heights(board, x)
	for xs in w: # x' of the spec
		if hs[xs] < 1:
			continue
		for xd in [xs - 1, xs + 1]:
			if xd < 0 or xd >= w or hs[xd] + 1 > board.h:
				continue
			var top := (hs[xs] - 1) * w + xs
			var v := x[top]
			for y in range(maxi(0, hs[xs] - 1), hs[xd] + 1):
				var p := x.duplicate()
				p[top] = 0
				for yy in range(hs[xd] - 1, y - 1, -1):
					p[(yy + 1) * w + xd] = p[yy * w + xd]
				p[y * w + xd] = v
				cands.append([p, (y * w + xd) * 4 + (TallyBoard.Dir.R if xs == xd + 1 else TallyBoard.Dir.L)])
	while not cands.is_empty():
		var j := rng.range_int(0, cands.size() - 1)
		var cand: Array = cands[j]
		cands[j] = cands[cands.size() - 1]
		cands.resize(cands.size() - 1)
		var p: PackedByteArray = cand[0]
		if quiet and p == t:
			continue
		if board.is_stable(p) and board.step(p, cand[1]) == t:
			return {"p": p, "m": cand[1]}
	return {}
