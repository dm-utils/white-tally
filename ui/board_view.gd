class_name TallyBoardView
extends WhiteTileView
## Draws the board and animates moves (design 10). Mechanics, input and animation come from WhiteTileView;
## this class holds the look of the tiles (colours, pips, joins) and turns TallyBoard.step_traced into view steps.

const TILE_COLORS := {2: Color("4C7FD6"), 3: Color("E3943A"), 4: Color("3FA58A")}
const PIP := Color(0.110, 0.122, 0.141, 0.85)
const PIPS := {
	2: [Vector2(0.3, 0.3), Vector2(0.7, 0.7)],
	3: [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)],
	4: [Vector2(0.3, 0.3), Vector2(0.7, 0.3), Vector2(0.3, 0.7), Vector2(0.7, 0.7)],
}
const JOIN_WIDTH := 0.4 ## join bar, in cells
const PIP_DIAMETER := 0.16 ## in cells
const SWAP_TIME := 0.12
const SLIDE_TIME := 0.10
const FALL_SPEED := 16.0 ## cells per second

var board: TallyBoard


# --- steps -------------------------------------------------------------------------------------------------------

## View steps for the steps of TallyBoard.step_traced.
static func to_steps(traced: Array) -> Array:
	var out: Array = []
	for s in traced:
		match str(s.kind):
			"swap":
				out.append({"kind": "move", "moves": [[s.a, s.b], [s.b, s.a]], "time": SWAP_TIME, "ease": true})
			"slide":
				out.append({"kind": "move", "moves": [[s.from, s.to]], "time": SLIDE_TIME, "ease": true})
			"fall":
				out.append({"kind": "move", "moves": s.moves, "speed": FALL_SPEED})
			"vanish":
				out.append({"kind": "vanish", "cells": s.cells})
	return out


# --- state -------------------------------------------------------------------------------------------------------

## Shows the attempt's state at once (no animation).
func show_attempt(a: WhiteAttempt) -> void:
	board = a.rules as TallyBoard
	show_cells(board.w, board.h, a.state)


func clear() -> void:
	board = null
	super.clear()


## After a move: animates it; after undo or restart: shows the state at once.
func update_attempt(a: WhiteAttempt) -> void:
	var rec := a.record
	var is_move := rec.length() >= 3 and rec.right(1).is_valid_int() and not a.history.is_empty()
	var code: Variant = board.decode_move(rec.right(3)) if is_move else null
	finish_animation()
	if code == null:
		show_values(a.state)
		return
	var before: PackedByteArray = a.history.back()
	if before != shown():
		show_values(before)
	play_move(code)


## Animates a canonical move from the shown state (also used by Best route).
func play_move(code: int) -> void:
	finish_animation()
	animate(to_steps(board.step_traced(shown(), code).steps))


func show_state(s: PackedByteArray) -> void:
	finish_animation()
	show_values(s)


func state() -> PackedByteArray:
	return shown()


# --- hooks -------------------------------------------------------------------------------------------------------

func _resolve_cell_move(cell: int, dir: int) -> int:
	return board.canonical(shown(), cell * 4 + dir)


func _draw_tile_body(rect: Rect2, value: int, alpha: float) -> void:
	var col: Color = TILE_COLORS[value]
	col.a = alpha
	_box.bg_color = col
	_box.set_corner_radius_all(int(cell_px * tile_radius))
	draw_style_box(_box, rect)


func _draw_links(tiles: Array) -> void:
	for ai in tiles.size():
		for bi in range(ai + 1, tiles.size()):
			var a: Dictionary = tiles[ai]
			var b: Dictionary = tiles[bi]
			if a.value != b.value:
				continue
			var d: Vector2 = b.pos - a.pos
			var horizontal := absf(absf(d.x) - 1.0) < 0.02 and absf(d.y) < 0.02
			var vertical := absf(absf(d.y) - 1.0) < 0.02 and absf(d.x) < 0.02
			if not (horizontal or vertical):
				continue
			var col: Color = TILE_COLORS[a.value]
			col.a = minf(a.alpha, b.alpha)
			var ca: Vector2 = a.center
			var cb: Vector2 = b.center
			var thick: float = cell_px * JOIN_WIDTH * minf(a.scale, b.scale)
			var r := Rect2(ca.min(cb) - Vector2(thick, thick) / 2.0, (ca - cb).abs() + Vector2(thick, thick))
			draw_rect(r, col)


func _draw_tile_face(rect: Rect2, value: int, alpha: float, scale_f: float) -> void:
	var col := PIP
	col.a *= alpha
	for q in PIPS[value]:
		draw_circle(rect.position + rect.size * (q as Vector2), cell_px * PIP_DIAMETER / 2.0 * scale_f, col)
