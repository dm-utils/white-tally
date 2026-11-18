extends SceneTree
## Phase 1 trial (design 5.7).
##   godot --headless --path . -s res://tools/measure.gd -- [--seeds=50] [--level=N] [--skip-m1]
## M1: step() and solver throughput. M2: per level over the trial seeds, prints the figures and checks P1, P2.

const NAMES := ["easy", "medium", "hard"]


func _init() -> void:
	var seeds := 50
	var only := -1
	var m1 := true
	var budget := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = int(a.get_slice("=", 1))
		elif a.begins_with("--level="):
			only = int(a.get_slice("=", 1))
		elif a.begins_with("--budget="):
			budget = int(a.get_slice("=", 1))
		elif a == "--skip-m1":
			m1 = false
	if m1:
		_m1()
	var medians := []
	var total_s := 0.0
	var ok := true
	for level in 3:
		if only >= 0 and level != only:
			continue
		var r := _m2(level, seeds, budget)
		medians.append(r.par_median)
		total_s += r.total_s
		ok = ok and r.ok
	if only < 0:
		var inc: bool = medians[0] < medians[1] and medians[1] < medians[2]
		print("P2 median par strictly increasing %s (%s)" % ["ok" if inc else "FAIL", medians])
		print("P3 estimate for 40 sets: %.0f s from %.0f s per %d seeds x 3 levels" % [
			total_s * 40.0 / seeds, total_s, seeds])
		ok = ok and inc
	print("trial " + ("ok" if ok else "FAILED"))
	quit(0 if ok else 1)


func _m1() -> void:
	var b := TallyBoard.create(6, 7)
	var rng := WhiteRng.new(7)
	var states: Array = []
	var rules := preload("res://tests/rules_tests.gd")
	while states.size() < 200:
		var s: PackedByteArray = rules.random_state(b, rng, 20, 28)
		var mv := b.legal_moves(s)
		if not mv.is_empty():
			states.append([s, mv])
	var n := 0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 3000000:
		for e in states:
			for m in e[1]:
				b.step(e[0], m)
				n += 1
	print("M1 step(): %.0f per second (6x7, 20-28 tiles)" % (n / ((Time.get_ticks_usec() - t0) / 1e6)))
	# solver throughput on a mid-size generated puzzle
	var r := TallyGenerator.generate(WhiteSeed.fnv1a64("white-tally-trial|0|1"), 1)
	var pb: TallyBoard = r.board
	var t1 := Time.get_ticks_usec()
	var sol := TallySolver.solve(pb, pb.start, r.path, 20000)
	var dt := (Time.get_ticks_usec() - t1) / 1e6
	print("M1 solver: %.0f expansions per second (%d expansions)" % [sol.expansions / dt, sol.expansions])


func _m2(level: int, seeds: int, budget: int) -> Dictionary:
	var cfg: Dictionary = TallyGenerator.LEVELS[level].duplicate()
	if budget >= 0:
		cfg.budget = budget
	var pars := PackedInt32Array()
	var uppers := PackedInt32Array()
	var tiles := PackedInt32Array()
	var tried := PackedInt32Array()
	var times := PackedFloat64Array()
	var fallback := 0
	var exact := 0
	var total := 0.0
	for n in seeds:
		var t0 := Time.get_ticks_usec()
		var r := TallyGenerator.generate_with(WhiteSeed.fnv1a64("white-tally-trial|%d|%d" % [n, level]), cfg)
		var dt := (Time.get_ticks_usec() - t0) / 1e6
		total += dt
		times.append(dt)
		var b: TallyBoard = r.board
		pars.append(r.par)
		uppers.append(r.upper)
		tiles.append(b.count_tiles(b.start))
		tried.append(r.tried)
		fallback += 1 if r.fallback else 0
		print("  %s seed %d: par %d upper %d exact %s tried %d fallback %s %.1f s" % [
			NAMES[level], n, r.par, r.upper, r.exact, r.tried, r.fallback, dt])
		exact += 1 if r.exact else 0
	var nonfb := seeds - fallback
	var need := ceili(seeds * 0.8)
	print("M2 %-6s board %dx%d  non-fallback %d/%d  exact %d/%d  tiles med %d  U med %d  par med %d (%s)  tried med %d max %d  build s med %.1f max %.1f" % [
		NAMES[level], cfg.w, cfg.h, nonfb, seeds, exact, seeds, _median_i(tiles), _median_i(uppers), _median_i(pars),
		_spread(pars), _median_i(tried), _max_i(tried), _median_f(times), _max_f(times)])
	var ok := nonfb >= need
	print("P1 %s: %d of %d non-fallback (need %d)" % [NAMES[level], nonfb, seeds, need])
	return {"ok": ok, "par_median": _median_i(pars), "total_s": total}


func _spread(a: PackedInt32Array) -> String:
	var d := {}
	for v in a:
		d[v] = d.get(v, 0) + 1
	var keys := d.keys()
	keys.sort()
	return " ".join(keys.map(func(k: int) -> String: return "%d:%d" % [k, d[k]]))


func _median_i(a: PackedInt32Array) -> int:
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]


func _max_i(a: PackedInt32Array) -> int:
	return a[Array(a).find(Array(a).max())]


func _median_f(a: PackedFloat64Array) -> float:
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]


func _max_f(a: PackedFloat64Array) -> float:
	return Array(a).max()
