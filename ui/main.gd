extends WhiteDayScreen
## White Tally screen: the kit day screen in practice mode with the tile board and the best route.
## Debug (screenshots, nothing saved): -- --shot=<png> --practice [--level=N] [--keys=RB1zLD1] [--lang=en] [--best]
## [--sel=<cell index>] [--safe=l,t,r,b]

var best_btn: Button


func _game_id() -> String:
	return TallyGame.GAME_ID


func _game_title() -> String:
	return "WHITE TALLY"


func _first_day() -> String:
	return WhiteDaily.today() # kit needs a value; no daily puzzle in phase 1


func _texts() -> Dictionary:
	return TallyStrings.TEXT


func _practice_only() -> bool:
	return true


func _load_practice(index: int) -> Array:
	return TallyGame.store().practice_set(index)


func _practice_count() -> int:
	return TallyGame.store().practice_count()


func _load_day(_d: String) -> Array:
	return []


func _count_mode(_is_practice: bool) -> int:
	return WhiteAttempt.CountMode.FINAL_ONLY


func _new_attempt(puzzle: Dictionary, mode: int) -> WhiteAttempt:
	return WhiteAttempt.new(puzzle.board, mode)


func _make_view() -> Control:
	var v := TallyBoardView.new()
	v.move_chosen.connect(_on_move)
	v.finished.connect(_on_view_finished)
	_apply_safe_area.call_deferred()
	return v


func _apply_safe_area() -> void:
	for c in get_children():
		if c is MarginContainer:
			TallySafeArea.apply(c, str(_debug.get("safe", "")))


func _view_show(a: WhiteAttempt) -> void:
	view.show_attempt(a)


func _view_clear() -> void:
	view.clear()


func _view_update(a: WhiteAttempt) -> void:
	view.update_attempt(a)


func _extra_buttons() -> Array[Button]:
	best_btn = WhiteUi.button("", _show_best)
	refreshed.connect(func() -> void: best_btn.text = WhiteText.t("best_route"))
	return [best_btn]


func _hint_text() -> String:
	return WhiteText.t("hint")


## Dead end notice (design 2.8), shown when the animation is done.
func _play_message(a: WhiteAttempt) -> String:
	if view.busy():
		return ""
	var b := a.rules as TallyBoard
	if a.moves_made > 0 and b.is_dead_end(a.state):
		return WhiteText.t("dead_end")
	return ""


func _key_move(event: InputEventKey) -> Variant:
	return view.key_move(event)


func _on_view_finished() -> void:
	if not puzzles.is_empty() and not _replaying:
		_refresh()


func _on_debug_extra() -> void:
	if _debug.has("sel"):
		view.debug_select(int(_debug.sel))
	if _debug.has("best"):
		for m in puzzles[level].path:
			_on_move(m)


## Plays the stored solution from the start; the attempt itself is not changed.
func _show_best() -> void:
	if _replaying:
		return
	_replaying = true
	view.input_enabled = false
	var p: Dictionary = puzzles[level]
	view.show_state((p.board as TallyBoard).start)
	await get_tree().create_timer(0.6).timeout
	for m in p.path:
		if not _replaying:
			break
		view.play_move(m)
		while view.busy() and _replaying:
			await get_tree().process_frame
		await get_tree().create_timer(0.35).timeout
	view.input_enabled = true
	if _replaying:
		_replaying = false
		view.show_state(attempts[level].state)
