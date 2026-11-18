class_name TallyGame
extends RefCounted
## Game constants and the puzzle store.

const GAME_ID := "white-tally"
const DAILY := "res://data/daily.json"
const PRACTICE := "res://data/practice.json"

static var _store: WhitePuzzleStore


## Raw puzzle object (design 6.3) to {"board", "par", "exact", "upper", "path"}.
static func convert(raw: Dictionary) -> Dictionary:
	var board := TallyBoard.from_dict(raw.board)
	return {"board": board, "par": int(raw.par), "exact": bool(raw.exact), "upper": int(raw.upper),
			"path": decode_path(board, str(raw.path)), "fallback": bool(raw.get("fallback", false))}


static func decode_path(board: TallyBoard, text: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in range(0, text.length() - 2, 3):
		var m: Variant = board.decode_move(text.substr(i, 3))
		if m == null:
			return PackedInt32Array()
		out.append(m)
	return out


static func store() -> WhitePuzzleStore:
	if _store == null:
		_store = WhitePuzzleStore.new(DAILY, PRACTICE, convert)
	return _store
